#!/usr/bin/env python3
import hashlib
import json
import os
import re
import sqlite3
import subprocess
import tempfile
from collections import Counter
from datetime import datetime, timedelta
from pathlib import Path

D = Path(os.getenv("XLX_RANK_DIR", "/var/lib/xlx-ranking"))
DB = D / "ranking.sqlite3"
OUT = D / "ranking.json"
JOURNAL_UNIT = os.getenv("XLX_RANK_JOURNAL_UNIT", "xlxd")
OPEN = re.compile(r"Opening stream on module\s+(\S+)\s+for client\s+(\S+)(?:\s+\S+)?\s+with sid\s+(\d+)", re.I)
CLOSE = re.compile(r"Closing stream of module\s+(\S+)", re.I)


def first_journal():
    p = subprocess.Popen(
        ["journalctl", "-u", JOURNAL_UNIT, "--no-pager", "-o", "json"],
        stdout=subprocess.PIPE,
        text=True,
    )
    try:
        line = p.stdout.readline()
        if not line:
            return None
        return int(json.loads(line)["__REALTIME_TIMESTAMP"]) // 1000000
    finally:
        p.terminate()


def journal(since):
    tz = datetime.now().astimezone().tzinfo
    text = datetime.fromtimestamp(max(0, since - 7200), tz).strftime("%Y-%m-%d %H:%M:%S")
    p = subprocess.Popen(
        ["journalctl", "-u", JOURNAL_UNIT, "--since", text, "--no-pager", "-o", "json"],
        stdout=subprocess.PIPE,
        text=True,
    )
    active = {}
    result = []
    for line in p.stdout:
        try:
            obj = json.loads(line)
            msg = str(obj.get("MESSAGE", ""))
            micro = int(obj["__REALTIME_TIMESTAMP"])
        except (ValueError, KeyError, TypeError, json.JSONDecodeError):
            continue
        ts = micro / 1000000
        match = OPEN.search(msg)
        if match:
            module = match.group(1).upper()
            active[module] = (ts, micro, match.group(2).upper(), match.group(3))
            continue
        match = CLOSE.search(msg)
        if match:
            module = match.group(1).upper()
            opened = active.pop(module, None)
            if not opened:
                continue
            duration = int(round(ts - opened[0]))
            if duration < 0 or duration > 7200:
                continue
            key = f"{opened[1]}|{module}|{opened[2]}|{opened[3]}"
            result.append(
                (
                    hashlib.sha1(key.encode()).hexdigest(),
                    int(opened[0]),
                    int(ts),
                    duration,
                    opened[2],
                    module,
                    opened[3],
                )
            )
    p.wait()
    if p.returncode:
        raise RuntimeError("journalctl failed")
    return result


def top(counter, limit=10):
    return [{"label": key, "value": int(value)} for key, value in counter.most_common(limit)]


def stats(conn, start, tz):
    tx = Counter()
    airtime = Counter()
    hours = Counter()
    modules = Counter()
    total = 0
    rows = conn.execute(
        "SELECT start_ts,duration,callsign,module FROM tx WHERE start_ts>=?",
        (start,),
    )
    for started, duration, callsign, module in rows:
        tx[callsign] += 1
        airtime[callsign] += duration
        total += duration
        hours[datetime.fromtimestamp(started, tz).strftime("%H:00")] += 1
        if module:
            modules["Módulo " + module] += 1
    return {
        "start_ts": start,
        "tx_count": sum(tx.values()),
        "airtime_seconds": total,
        "unique_callsigns": len(tx),
        "top_tx": top(tx),
        "top_airtime": top(airtime),
        "hours": top(hours, 8),
        "modules": top(modules, 8),
    }


def atomic(data):
    fd, tmp = tempfile.mkstemp(dir=D, prefix="ranking-", suffix=".tmp")
    with os.fdopen(fd, "w", encoding="utf8") as handle:
        json.dump(data, handle, ensure_ascii=False, separators=(",", ":"))
        handle.flush()
        os.fsync(handle.fileno())
    os.chmod(tmp, 0o644)
    os.replace(tmp, OUT)


def main():
    D.mkdir(parents=True, exist_ok=True)
    os.chmod(D, 0o755)

    now = datetime.now().astimezone()
    tz = now.tzinfo
    now_ts = int(now.timestamp())
    today = now.replace(hour=0, minute=0, second=0, microsecond=0)
    week = now - timedelta(days=7)
    month = today.replace(day=1)
    year = today.replace(month=1, day=1)

    conn = sqlite3.connect(DB)
    conn.executescript(
        """
        PRAGMA journal_mode=WAL;
        CREATE TABLE IF NOT EXISTS tx(
          id TEXT PRIMARY KEY,start_ts INTEGER,end_ts INTEGER,duration INTEGER,
          callsign TEXT,module TEXT,sid TEXT);
        CREATE INDEX IF NOT EXISTS tx_start ON tx(start_ts);
        CREATE TABLE IF NOT EXISTS meta(k TEXT PRIMARY KEY,v TEXT);
        """
    )

    def get(key):
        row = conn.execute("SELECT v FROM meta WHERE k=?", (key,)).fetchone()
        return row[0] if row else None

    def put(key, value):
        conn.execute(
            "INSERT INTO meta VALUES(?,?) ON CONFLICT(k) DO UPDATE SET v=excluded.v",
            (key, str(value)),
        )

    first = get("first_journal")
    if first is None:
        first = first_journal()
        if first is not None:
            put("first_journal", first)

    last = get("last_scan")
    earliest_required = min(
        int(week.timestamp()),
        int(month.timestamp()),
        int(year.timestamp()),
    )
    start = earliest_required if not last else max(earliest_required, int(last) - 7200)

    for event in journal(start):
        conn.execute("INSERT OR IGNORE INTO tx VALUES(?,?,?,?,?,?,?)", event)

    conn.execute("DELETE FROM tx WHERE start_ts<?", (now_ts - 400 * 86400,))
    put("last_scan", now_ts)
    conn.commit()

    source_start = int(first) if first else None
    payload = {
        "ok": True,
        "version": 3,
        "generated_at": now_ts,
        "coverage": {
            "source_start": source_start,
            "today_complete": bool(source_start and source_start <= int(today.timestamp())),
            "week_complete": bool(source_start and source_start <= int(week.timestamp())),
            "month_complete": bool(source_start and source_start <= int(month.timestamp())),
            "year_complete": bool(source_start and source_start <= int(year.timestamp())),
        },
        "periods": {
            "today": stats(conn, int(today.timestamp()), tz),
            "week": stats(conn, int(week.timestamp()), tz),
            "month": stats(conn, int(month.timestamp()), tz),
            "year": stats(conn, int(year.timestamp()), tz),
        },
    }
    atomic(payload)
    os.chmod(DB, 0o600)
    print(
        "Today:", payload["periods"]["today"]["tx_count"],
        "| 7 days:", payload["periods"]["week"]["tx_count"],
        "| Month:", payload["periods"]["month"]["tx_count"],
        "| Year:", payload["periods"]["year"]["tx_count"],
    )
    conn.close()


if __name__ == "__main__":
    main()
