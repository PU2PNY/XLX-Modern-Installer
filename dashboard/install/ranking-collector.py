#!/usr/bin/env python3
"""Persistent statistics collector for XLX Modern Dashboard Ranking V2.

The collector reads the local systemd journal for the ``xlxd`` service,
pairs stream-open/stream-close events by module, stores completed TX events
in SQLite, and atomically publishes a small JSON snapshot consumed by the
public dashboard API.

No network access is required and the SQLite database is never exposed by
the web server.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import sys
import tempfile
import time
from typing import Iterable

DATA_DIR = Path(os.environ.get("XLX_RANK_DIR", "/var/lib/xlx-ranking"))
DB_PATH = DATA_DIR / "ranking.sqlite3"
JSON_PATH = DATA_DIR / "ranking.json"
SERVICE_NAME = os.environ.get("XLX_RANK_SERVICE", "xlxd")
RETENTION_DAYS = 400
OVERLAP_SECONDS = 7200
MAX_TX_SECONDS = 7200

OPEN_RE = re.compile(
    r"Opening stream on module\s+(\S+)\s+for client\s+(\S+)"
    r"(?:\s+\S+)?\s+with sid\s+(\d+)",
    re.IGNORECASE,
)
CLOSE_RE = re.compile(r"Closing stream of module\s+(\S+)", re.IGNORECASE)


def local_now() -> dt.datetime:
    return dt.datetime.now().astimezone()


def local_midnight(now: dt.datetime | None = None) -> dt.datetime:
    current = now or local_now()
    return current.replace(hour=0, minute=0, second=0, microsecond=0)


def run_journal(start_ts: int) -> list[tuple[int, str]]:
    """Return XLXD journal messages from start_ts with a safety overlap."""
    since_ts = max(0, int(start_ts) - OVERLAP_SECONDS)
    since = dt.datetime.fromtimestamp(since_ts).strftime("%Y-%m-%d %H:%M:%S")
    proc = subprocess.run(
        [
            "journalctl",
            "-u",
            SERVICE_NAME,
            "--since",
            since,
            "--no-pager",
            "-o",
            "json",
        ],
        text=True,
        capture_output=True,
        timeout=120,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "journalctl failed")

    events: list[tuple[int, str]] = []
    for line in proc.stdout.splitlines():
        try:
            payload = json.loads(line)
            timestamp = int(payload.get("__REALTIME_TIMESTAMP", "0")) // 1_000_000
            message = str(payload.get("MESSAGE", ""))
        except (TypeError, ValueError, json.JSONDecodeError):
            continue
        if timestamp > 0 and message:
            events.append((timestamp, message))
    return events


def first_journal_timestamp() -> int:
    """Read the oldest available XLXD journal record without loading it all."""
    proc = subprocess.Popen(
        ["journalctl", "-u", SERVICE_NAME, "--no-pager", "-o", "json"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    try:
        if proc.stdout is None:
            return 0
        line = proc.stdout.readline()
        if not line:
            return 0
        payload = json.loads(line)
        return int(payload.get("__REALTIME_TIMESTAMP", "0")) // 1_000_000
    except (TypeError, ValueError, json.JSONDecodeError):
        return 0
    finally:
        try:
            proc.terminate()
            proc.wait(timeout=2)
        except Exception:
            try:
                proc.kill()
            except Exception:
                pass


def init_db(conn: sqlite3.Connection) -> None:
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    conn.execute("PRAGMA busy_timeout=30000")
    conn.execute("CREATE TABLE IF NOT EXISTS meta(k TEXT PRIMARY KEY,v TEXT NOT NULL)")
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS tx(
            id TEXT PRIMARY KEY,
            start_ts INTEGER NOT NULL,
            end_ts INTEGER NOT NULL,
            duration INTEGER NOT NULL,
            callsign TEXT NOT NULL,
            module TEXT NOT NULL,
            sid INTEGER NOT NULL
        )
        """
    )
    conn.execute("CREATE INDEX IF NOT EXISTS tx_start_idx ON tx(start_ts)")
    conn.commit()


def meta_get(conn: sqlite3.Connection, key: str) -> str | None:
    row = conn.execute("SELECT v FROM meta WHERE k=?", (key,)).fetchone()
    return str(row[0]) if row else None


def meta_set(conn: sqlite3.Connection, key: str, value: object) -> None:
    conn.execute(
        "INSERT INTO meta(k,v) VALUES(?,?) "
        "ON CONFLICT(k) DO UPDATE SET v=excluded.v",
        (key, str(value)),
    )


def ingest(conn: sqlite3.Connection, events: Iterable[tuple[int, str]]) -> int:
    """Pair open/close journal lines and insert completed TX rows idempotently."""
    active: dict[str, tuple[int, str, int]] = {}
    inserted = 0

    for timestamp, message in events:
        opened = OPEN_RE.search(message)
        if opened:
            module = opened.group(1).upper()[:1]
            callsign = opened.group(2).upper().strip()
            sid = int(opened.group(3))
            if module and callsign:
                active[module] = (timestamp, callsign, sid)
            continue

        closed = CLOSE_RE.search(message)
        if not closed:
            continue

        module = closed.group(1).upper()[:1]
        if module not in active:
            continue

        start_ts, callsign, sid = active.pop(module)
        duration = timestamp - start_ts
        if duration < 0 or duration > MAX_TX_SECONDS:
            continue

        uid = hashlib.sha1(
            f"{start_ts}|{timestamp}|{module}|{callsign}|{sid}".encode("utf-8")
        ).hexdigest()
        before = conn.total_changes
        conn.execute(
            "INSERT OR IGNORE INTO tx(id,start_ts,end_ts,duration,callsign,module,sid) "
            "VALUES(?,?,?,?,?,?,?)",
            (uid, start_ts, timestamp, duration, callsign, module, sid),
        )
        if conn.total_changes > before:
            inserted += 1

    return inserted


def top(
    conn: sqlite3.Connection,
    start_ts: int,
    field: str,
    *,
    sum_duration: bool = False,
    limit: int = 10,
) -> list[dict[str, int | str]]:
    if field not in {"callsign", "module"}:
        raise ValueError("invalid ranking field")
    metric = "SUM(duration)" if sum_duration else "COUNT(*)"
    query = (
        f"SELECT {field},{metric} AS value FROM tx WHERE start_ts>=? "
        f"GROUP BY {field} ORDER BY value DESC,{field} ASC LIMIT ?"
    )
    return [
        {"label": str(label), "value": int(value)}
        for label, value in conn.execute(query, (int(start_ts), int(limit)))
    ]


def period(conn: sqlite3.Connection, start_ts: int) -> dict[str, object]:
    row = conn.execute(
        "SELECT COUNT(*),COALESCE(SUM(duration),0),COUNT(DISTINCT callsign) "
        "FROM tx WHERE start_ts>=?",
        (int(start_ts),),
    ).fetchone()
    hour_counts: dict[str, int] = {}
    for (timestamp,) in conn.execute("SELECT start_ts FROM tx WHERE start_ts>=?", (int(start_ts),)):
        label = dt.datetime.fromtimestamp(int(timestamp)).strftime("%H:00")
        hour_counts[label] = hour_counts.get(label, 0) + 1

    return {
        "start_ts": int(start_ts),
        "tx_count": int(row[0]),
        "airtime_seconds": int(row[1]),
        "unique_callsigns": int(row[2]),
        "top_tx": top(conn, start_ts, "callsign"),
        "top_airtime": top(conn, start_ts, "callsign", sum_duration=True),
        "hours": [
            {"label": label, "value": value}
            for label, value in sorted(
                hour_counts.items(), key=lambda item: (-item[1], item[0])
            )[:8]
        ],
        "modules": top(conn, start_ts, "module", limit=8),
    }


def period_starts(now: dt.datetime | None = None) -> dict[str, int]:
    current = now or local_now()
    today = local_midnight(current)
    week = current - dt.timedelta(days=7)
    month = today.replace(day=1)
    return {
        "today": int(today.timestamp()),
        "week": int(week.timestamp()),
        "month": int(month.timestamp()),
    }


def build_snapshot(
    conn: sqlite3.Connection,
    coverage_start_ts: int,
    *,
    now: dt.datetime | None = None,
) -> dict[str, object]:
    starts = period_starts(now)
    return {
        "ok": True,
        "generated_at": int(time.time()),
        "coverage": {
            "journal_first_ts": int(coverage_start_ts),
            "today_complete": bool(coverage_start_ts and coverage_start_ts <= starts["today"]),
            "week_complete": bool(coverage_start_ts and coverage_start_ts <= starts["week"]),
            "month_complete": bool(coverage_start_ts and coverage_start_ts <= starts["month"]),
        },
        "periods": {name: period(conn, start) for name, start in starts.items()},
    }


def atomic_json(path: Path, data: dict[str, object]) -> None:
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    with temporary.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, ensure_ascii=False, separators=(",", ":"))
        handle.flush()
        os.fsync(handle.fileno())
    os.chmod(temporary, 0o644)
    os.replace(temporary, path)


def collect() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    os.chmod(DATA_DIR, 0o755)

    conn = sqlite3.connect(DB_PATH, timeout=30)
    try:
        init_db(conn)
        starts = period_starts()
        earliest_required = min(starts["week"], starts["month"])
        last_scan = meta_get(conn, "last_scan")
        scan_start = (
            earliest_required
            if not last_scan
            else max(earliest_required, int(last_scan) - OVERLAP_SECONDS)
        )

        journal_first = meta_get(conn, "coverage_start_ts")
        if journal_first is None:
            first = first_journal_timestamp()
            coverage_start = first if first > 0 else int(time.time())
            meta_set(conn, "coverage_start_ts", coverage_start)
        else:
            coverage_start = int(journal_first)

        ingest(conn, run_journal(scan_start))
        now_ts = int(time.time())
        meta_set(conn, "last_scan", now_ts)
        conn.execute(
            "DELETE FROM tx WHERE start_ts < ?",
            (now_ts - RETENTION_DAYS * 86400,),
        )
        conn.commit()

        atomic_json(JSON_PATH, build_snapshot(conn, coverage_start))
        os.chmod(DB_PATH, 0o600)
        wal = Path(str(DB_PATH) + "-wal")
        shm = Path(str(DB_PATH) + "-shm")
        if wal.exists():
            os.chmod(wal, 0o600)
        if shm.exists():
            os.chmod(shm, 0o600)
    finally:
        conn.close()


def self_test() -> None:
    global DATA_DIR, DB_PATH, JSON_PATH

    with tempfile.TemporaryDirectory(prefix="xlx-ranking-test-") as directory:
        DATA_DIR = Path(directory)
        DB_PATH = DATA_DIR / "ranking.sqlite3"
        JSON_PATH = DATA_DIR / "ranking.json"

        conn = sqlite3.connect(DB_PATH)
        try:
            init_db(conn)
            now = local_now()
            today = local_midnight(now)
            test_now = today + dt.timedelta(hours=12)
            coverage_start = int(today.replace(day=1).timestamp()) - 86400
            base = int(today.timestamp()) + 60
            events = [
                (base, "Opening stream on module C for client N0CALL with sid 10"),
                (base + 30, "Closing stream of module C"),
                (base + 40, "Opening stream on module D for client N1TEST A with sid 11"),
                (base + 70, "Closing stream of module D"),
                # Replaying the same records must not duplicate statistics.
                (base, "Opening stream on module C for client N0CALL with sid 10"),
                (base + 30, "Closing stream of module C"),
            ]
            inserted = ingest(conn, events)
            conn.commit()
            snapshot = build_snapshot(
                conn,
                coverage_start,
                now=test_now,
            )

            assert inserted == 2, inserted
            current = snapshot["periods"]["today"]
            assert current["tx_count"] == 2, current
            assert current["airtime_seconds"] == 60, current
            assert current["unique_callsigns"] == 2, current
            assert snapshot["coverage"]["today_complete"] is True
            assert snapshot["coverage"]["month_complete"] is True
        finally:
            conn.close()

    print("ranking collector self-test: OK")


def main() -> int:
    parser = argparse.ArgumentParser(description="XLX Ranking V2 collector")
    parser.add_argument("--self-test", action="store_true", help="run an isolated deterministic self-test")
    args = parser.parse_args()
    if args.self_test:
        self_test()
    else:
        collect()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pragma: no cover - operational guardrail
        print(f"ranking collector error: {exc}", file=sys.stderr)
        raise SystemExit(1)
