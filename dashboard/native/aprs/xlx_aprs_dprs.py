#!/usr/bin/env python3
"""XLX APRS/D-PRS Gateway

Read-only DExtra client for XLX module B + APRS-IS command service.
The DExtra side never transmits DV frames: it only links, keeps the link alive,
and decodes D-STAR slow-data received from the module.

Runtime dependencies: Python standard library only.
"""
from __future__ import annotations

import argparse
import contextlib
import dataclasses
import datetime as dt
import hashlib
import json
import logging
import math
import os
import queue
import re
import signal
import socket
import sqlite3
import threading
import time
from pathlib import Path
from typing import Any, Callable, Iterable, Optional

VERSION = "1.1.1"
SOFTWARE = "XLX-APRS-DPRS"

SCRAMBLER = (0x70, 0x4F, 0x93)
SLOW_DATA_TYPE_MASK = 0xF0
SLOW_DATA_TYPE_GPS = 0x30
SLOW_DATA_TYPE_TEXT = 0x40
DATA_SYNC_BYTES = b"\x55\x2D\x16"

CALL_RE = re.compile(r"^[A-Z0-9]{3,8}(?:-[0-9]{1,2})?$")
BRAZIL_CALL_RE = re.compile(r"^(?:P[A-Z0-9]|Z[VW]|P[QRTU])[0-9][A-Z]{1,4}(?:-[0-9]{1,2})?$", re.I)
APRS_MSG_RE = re.compile(r"^:([^:]{9}):(.+)$")
TNC2_RE = re.compile(r"^([^>]+)>([^:]+):(.*)$")


def utcnow() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def iso_utc(ts: Optional[float] = None) -> str:
    d = dt.datetime.fromtimestamp(ts, dt.timezone.utc) if ts is not None else utcnow()
    return d.replace(microsecond=0).isoformat().replace("+00:00", "Z")


def safe_callsign(value: str) -> str:
    v = re.sub(r"[^A-Z0-9-]", "", (value or "").upper().strip())[:11]
    return v if CALL_RE.fullmatch(v) else ""


def base_callsign(value: str) -> str:
    return safe_callsign(value).split("-", 1)[0]


def atomic_json_write(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    raw = json.dumps(payload, ensure_ascii=False, separators=(",", ":"), sort_keys=False)
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(raw)
        fh.flush()
        os.fsync(fh.fileno())
    os.replace(tmp, path)
    with contextlib.suppress(OSError):
        os.chmod(path, 0o640)


def icom_crc(data: bytes) -> int:
    crc = 0xFFFF
    for byte in data:
        ch = byte
        for _ in range(8):
            xorflag = ((crc ^ ch) & 0x01) == 0x01
            crc >>= 1
            if xorflag:
                crc ^= 0x8408
            ch >>= 1
    return (~crc) & 0xFFFF


def nmea_checksum_ok(sentence: str) -> bool:
    sentence = sentence.strip("\r\n")
    if not sentence.startswith("$") or "*" not in sentence:
        return False
    body, checksum = sentence[1:].rsplit("*", 1)
    if len(checksum) < 2:
        return False
    value = 0
    for ch in body:
        value ^= ord(ch)
    try:
        return value == int(checksum[:2], 16)
    except ValueError:
        return False


def nmea_coord(raw: str, hemi: str, lon: bool = False) -> Optional[float]:
    try:
        deg_len = 3 if lon else 2
        degrees = int(raw[:deg_len])
        minutes = float(raw[deg_len:])
        value = degrees + minutes / 60.0
        if hemi.upper() in ("S", "W"):
            value = -value
        if not (-180 <= value <= 180 if lon else -90 <= value <= 90):
            return None
        return value
    except (ValueError, TypeError):
        return None


def parse_nmea(sentence: str) -> Optional[dict[str, Any]]:
    sentence = sentence.strip("\r\n")
    if not nmea_checksum_ok(sentence):
        return None
    fields = sentence.split("*")[0].split(",")
    kind = fields[0]
    if kind in ("$GPGGA", "$GNGGA") and len(fields) >= 7:
        if fields[6] == "0":
            return None
        lat = nmea_coord(fields[2], fields[3], False)
        lon = nmea_coord(fields[4], fields[5], True)
        if lat is None or lon is None:
            return None
        return {"lat": lat, "lon": lon, "kind": "GGA", "speed_knots": None, "course": None}
    if kind in ("$GPRMC", "$GNRMC") and len(fields) >= 9:
        if fields[2].upper() != "A":
            return None
        lat = nmea_coord(fields[3], fields[4], False)
        lon = nmea_coord(fields[5], fields[6], True)
        if lat is None or lon is None:
            return None
        try:
            speed = float(fields[7]) if fields[7] else None
        except ValueError:
            speed = None
        try:
            course = float(fields[8]) if fields[8] else None
        except ValueError:
            course = None
        return {"lat": lat, "lon": lon, "kind": "RMC", "speed_knots": speed, "course": course}
    return None


def parse_aprs_position(info: str) -> Optional[dict[str, Any]]:
    """Parse common uncompressed APRS position formats (!, =, /, @)."""
    if not info:
        return None
    payload = info
    if payload[0] in "/@":
        if len(payload) < 9:
            return None
        payload = "!" + payload[8:]
    if payload[0] not in "!=":
        return None
    # !DDMM.mmN/DDDMM.mmWsymbol...
    if len(payload) < 19:
        return None
    lat_raw = payload[1:8]
    lat_hemi = payload[8:9]
    lon_raw = payload[10:18]
    lon_hemi = payload[18:19]
    if not (re.fullmatch(r"\d{4}\.\d{2}", lat_raw) and re.fullmatch(r"\d{5}\.\d{2}", lon_raw)):
        return None
    lat = nmea_coord(lat_raw, lat_hemi, False)
    lon = nmea_coord(lon_raw, lon_hemi, True)
    if lat is None or lon is None:
        return None
    return {"lat": lat, "lon": lon}


def parse_tnc2(line: str) -> Optional[dict[str, Any]]:
    m = TNC2_RE.match(line.strip())
    if not m:
        return None
    source = safe_callsign(m.group(1))
    if not source:
        return None
    route = m.group(2)
    parts = route.split(",")
    destination = parts[0][:9]
    path = parts[1:]
    return {"source": source, "destination": destination, "path": path, "info": m.group(3)}


def parse_aprs_message(info: str) -> Optional[dict[str, str]]:
    m = APRS_MSG_RE.match(info)
    if not m:
        return None
    addressee = m.group(1).strip().upper()
    body = m.group(2)
    msg_id = ""
    # APRS message id follows final { and is normally <=5 chars.
    pos = body.rfind("{")
    if pos >= 0 and 0 < len(body) - pos - 1 <= 5:
        candidate = body[pos + 1 :]
        if re.fullmatch(r"[A-Za-z0-9]+", candidate):
            msg_id = candidate
            body = body[:pos]
    return {"addressee": addressee, "body": body.strip(), "msg_id": msg_id}


def aprs_passcode(callsign: str) -> int:
    """Generate the standard APRS-IS 15-bit passcode from the base callsign."""
    call = base_callsign(callsign)
    if not call:
        raise ValueError("invalid APRS callsign")
    value = 0x73E2
    for i, ch in enumerate(call):
        value ^= (ord(ch) << 8) if i % 2 == 0 else ord(ch)
    return value & 0x7FFF


def build_aprs_message(source: str, dest: str, text: str, msg_id: str = "") -> str:
    source = safe_callsign(source)
    dest = safe_callsign(dest)
    if not source or not dest:
        raise ValueError("invalid APRS callsign")
    clean = re.sub(r"[\r\n\x00-\x1f]", " ", text).strip()[:67]
    ident = "{" + re.sub(r"[^A-Za-z0-9]", "", msg_id)[:5] if msg_id else ""
    return f"{source}>APDLAB,TCPIP*::{dest:<9}:{clean}{ident}"


def build_dextra_connect(base_call: str, client_module: str, reflector_module: str) -> bytes:
    base = base_callsign(base_call)
    if not base or len(client_module) != 1 or len(reflector_module) != 1:
        raise ValueError("invalid DExtra identity/module")
    return base.ljust(8)[:8].encode("ascii") + client_module.upper().encode("ascii") + reflector_module.upper().encode("ascii") + b"\x00"


def build_dextra_keepalive(base_call: str) -> bytes:
    base = base_callsign(base_call)
    if not base:
        raise ValueError("invalid DExtra callsign")
    return base.ljust(8)[:8].encode("ascii") + b"\x00"


def build_dextra_disconnect(base_call: str, client_module: str) -> bytes:
    base = base_callsign(base_call)
    if not base or len(client_module) != 1:
        raise ValueError("invalid DExtra identity/module")
    return base.ljust(8)[:8].encode("ascii") + client_module.upper().encode("ascii") + b" " + b"\x00"


def parse_dextra_header(packet: bytes) -> Optional[dict[str, Any]]:
    if len(packet) != 56 or packet[:4] != b"DSVT" or packet[4] != 0x10 or packet[8] != 0x20:
        return None
    def txt(start: int, length: int) -> str:
        return packet[start : start + length].decode("ascii", "ignore").strip()
    # XLXD's DExtra encoder appends stream id little-endian at [12:14].
    stream_id = int.from_bytes(packet[12:14], "little")
    return {
        "stream_id": stream_id,
        "rpt2": txt(18, 8),
        "rpt1": txt(26, 8),
        "your": txt(34, 8),
        "mycall": safe_callsign(txt(42, 8)),
        "suffix": txt(50, 4),
    }


def parse_dextra_frame(packet: bytes) -> Optional[dict[str, Any]]:
    if len(packet) != 27 or packet[:4] != b"DSVT" or packet[4] != 0x20 or packet[8] != 0x20:
        return None
    return {
        "stream_id": int.from_bytes(packet[12:14], "little"),
        "seq": packet[14] & 0x1F,
        "end": bool(packet[14] & 0x40),
        "ambe": packet[15:24],
        "slow": packet[24:27],
    }


@dataclasses.dataclass
class SlowEvent:
    kind: str
    data: dict[str, Any]


class SlowDataDecoder:
    """D-STAR slow-data decoder, matching the G4KLX APRSCollector format."""

    def __init__(self) -> None:
        self.half: Optional[bytes] = None
        self.gps_buffer = bytearray()
        self.text_blocks: dict[int, bytes] = {}
        self.last_gga: Optional[dict[str, Any]] = None
        self.last_rmc: Optional[dict[str, Any]] = None
        self.last_emitted: dict[str, float] = {}

    def sync(self) -> None:
        # G4KLX APRSCollector::sync() resets only the 3-byte half state.
        self.half = None

    def reset(self) -> None:
        self.half = None
        self.gps_buffer.clear()
        self.text_blocks.clear()
        self.last_gga = None
        self.last_rmc = None
        self.last_emitted.clear()

    def _dedupe(self, key: str, ttl: float = 8.0) -> bool:
        now = time.monotonic()
        last = self.last_emitted.get(key, 0.0)
        self.last_emitted[key] = now
        return now - last < ttl

    def feed(self, raw3: bytes) -> list[SlowEvent]:
        if len(raw3) != 3:
            return []
        # A sync frame is not scrambled and marks block boundary.
        if raw3 == DATA_SYNC_BYTES:
            self.sync()
            return []
        decoded = bytes(raw3[i] ^ SCRAMBLER[i] for i in range(3))
        if self.half is None:
            self.half = decoded
            return []
        block = self.half + decoded
        self.half = None
        kind = block[0] & SLOW_DATA_TYPE_MASK
        nibble = block[0] & 0x0F
        if kind == SLOW_DATA_TYPE_GPS:
            n = min(nibble, 5)
            if n:
                self.gps_buffer.extend(block[1 : 1 + n])
            return self._extract_gps()
        if kind == SLOW_DATA_TYPE_TEXT and 0 <= nibble <= 3:
            self.text_blocks[nibble] = block[1:6]
            if all(i in self.text_blocks for i in range(4)):
                text = b"".join(self.text_blocks[i] for i in range(4)).decode("ascii", "ignore").strip(" \x00")
                self.text_blocks.clear()
                if text and not self._dedupe("text:" + text):
                    return [SlowEvent("text", {"text": text})]
        return []

    def _extract_gps(self) -> list[SlowEvent]:
        events: list[SlowEvent] = []
        # Bound malformed streams.
        if len(self.gps_buffer) > 4096:
            del self.gps_buffer[:-1024]

        while True:
            raw = bytes(self.gps_buffer)
            starts = [(raw.find(b"$$CRC"), "crc"), (raw.find(b"$GPGGA"), "nmea"), (raw.find(b"$GNGGA"), "nmea"),
                      (raw.find(b"$GPRMC"), "nmea"), (raw.find(b"$GNRMC"), "nmea")]
            starts = [(p, k) for p, k in starts if p >= 0]
            if not starts:
                if len(self.gps_buffer) > 256:
                    del self.gps_buffer[:-128]
                break
            pos, typ = min(starts, key=lambda x: x[0])
            if pos > 0:
                del self.gps_buffer[:pos]
                raw = bytes(self.gps_buffer)
            endbyte = b"\r" if typ == "crc" else b"\n"
            end = raw.find(endbyte)
            if end < 0:
                break
            record = raw[: end + 1]
            del self.gps_buffer[: end + 1]
            if typ == "crc":
                ev = self._parse_crc_record(record)
                if ev:
                    events.append(ev)
            else:
                sentence = record.decode("ascii", "ignore")
                parsed = parse_nmea(sentence)
                if parsed:
                    if parsed["kind"] == "GGA":
                        self.last_gga = parsed
                    else:
                        self.last_rmc = parsed
                    key = f"nmea:{parsed['lat']:.5f}:{parsed['lon']:.5f}:{parsed['kind']}"
                    if not self._dedupe(key):
                        events.append(SlowEvent("position", {**parsed, "format": "NMEA"}))
        return events

    def _parse_crc_record(self, record: bytes) -> Optional[SlowEvent]:
        # $$CRC + 4 hex + comma = 10 bytes, then APRS TNC2 payload through CR.
        if len(record) < 12 or not record.startswith(b"$$CRC"):
            return None
        try:
            expected = int(record[5:9].decode("ascii"), 16)
        except ValueError:
            return None
        if record[9:10] not in (b",", b":", b" "):
            return None
        crc_payload = record[10:]
        if icom_crc(crc_payload) != expected:
            return None
        packet = crc_payload.rstrip(b"\r\n").decode("ascii", "ignore").strip()
        tnc = parse_tnc2(packet)
        if not tnc:
            return None
        pos = parse_aprs_position(tnc["info"])
        key = "crc:" + hashlib.sha1(packet.encode("ascii", "ignore")).hexdigest()
        if self._dedupe(key):
            return None
        data: dict[str, Any] = {"packet": packet, "format": "GPS-A", "source": tnc["source"]}
        if pos:
            data.update(pos)
        return SlowEvent("dprs", data)


class StateDB:
    def __init__(self, db_path: Path, public_path: Path, retention_days: int = 7) -> None:
        self.db_path = db_path
        self.public_path = public_path
        self.retention_days = max(1, min(int(retention_days), 90))
        self.lock = threading.RLock()
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self.conn = sqlite3.connect(str(db_path), check_same_thread=False, timeout=10)
        self.conn.row_factory = sqlite3.Row
        with self.conn:
            self.conn.execute("PRAGMA journal_mode=WAL")
            self.conn.execute("PRAGMA synchronous=NORMAL")
            self.conn.executescript(
                """
                CREATE TABLE IF NOT EXISTS status (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS stations (
                    callsign TEXT PRIMARY KEY,
                    lat REAL,
                    lon REAL,
                    source TEXT NOT NULL,
                    protocol TEXT NOT NULL,
                    module TEXT,
                    format TEXT,
                    speed_knots REAL,
                    course REAL,
                    last_seen TEXT NOT NULL,
                    raw_hash TEXT
                );
                CREATE TABLE IF NOT EXISTS events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    ts TEXT NOT NULL,
                    kind TEXT NOT NULL,
                    callsign TEXT,
                    source TEXT NOT NULL,
                    module TEXT,
                    detail TEXT
                );
                CREATE INDEX IF NOT EXISTS idx_events_ts ON events(ts DESC);
                CREATE INDEX IF NOT EXISTS idx_events_call_ts ON events(callsign, ts DESC);
                CREATE TABLE IF NOT EXISTS messages (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    ts TEXT NOT NULL,
                    direction TEXT NOT NULL,
                    peer TEXT NOT NULL,
                    body TEXT NOT NULL,
                    msg_id TEXT,
                    command TEXT,
                    status TEXT NOT NULL
                );
                CREATE INDEX IF NOT EXISTS idx_messages_ts ON messages(ts DESC);
                """
            )
        self.set_status("gateway", "starting")

    def close(self) -> None:
        with self.lock:
            with contextlib.suppress(Exception):
                self.conn.close()

    def set_status(self, key: str, value: Any) -> None:
        now = iso_utc()
        encoded = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
        with self.lock, self.conn:
            self.conn.execute(
                "INSERT INTO status(key,value,updated_at) VALUES(?,?,?) "
                "ON CONFLICT(key) DO UPDATE SET value=excluded.value,updated_at=excluded.updated_at",
                (key, encoded, now),
            )

    def add_event(self, kind: str, callsign: str = "", source: str = "gateway", module: str = "", detail: str = "") -> None:
        now = iso_utc()
        call = safe_callsign(callsign)
        detail = re.sub(r"[\x00-\x1f]", " ", detail)[:180]
        with self.lock, self.conn:
            self.conn.execute(
                "INSERT INTO events(ts,kind,callsign,source,module,detail) VALUES(?,?,?,?,?,?)",
                (now, kind[:32], call or None, source[:32], module[:1] or None, detail),
            )

    def update_station(self, callsign: str, lat: float, lon: float, source: str, protocol: str,
                       module: str = "", fmt: str = "", speed_knots: Optional[float] = None,
                       course: Optional[float] = None, raw_hash: str = "") -> None:
        call = safe_callsign(callsign)
        if not call or not (-90 <= lat <= 90) or not (-180 <= lon <= 180):
            return
        now = iso_utc()
        with self.lock, self.conn:
            self.conn.execute(
                """INSERT INTO stations(callsign,lat,lon,source,protocol,module,format,speed_knots,course,last_seen,raw_hash)
                   VALUES(?,?,?,?,?,?,?,?,?,?,?)
                   ON CONFLICT(callsign) DO UPDATE SET
                   lat=excluded.lat,lon=excluded.lon,source=excluded.source,protocol=excluded.protocol,
                   module=excluded.module,format=excluded.format,speed_knots=excluded.speed_knots,
                   course=excluded.course,last_seen=excluded.last_seen,raw_hash=excluded.raw_hash""",
                (call, float(lat), float(lon), source[:32], protocol[:16], module[:1], fmt[:16], speed_knots, course, now, raw_hash[:64]),
            )
            self.conn.execute(
                "INSERT INTO events(ts,kind,callsign,source,module,detail) VALUES(?,?,?,?,?,?)",
                (now, "beacon", call, source[:32], module[:1] or None, fmt[:32]),
            )

    def last_event_for(self, callsign: str) -> Optional[dict[str, Any]]:
        call = safe_callsign(callsign)
        if not call:
            return None
        with self.lock:
            row = self.conn.execute(
                "SELECT ts,kind,callsign,source,module,detail FROM events WHERE callsign=? ORDER BY id DESC LIMIT 1", (call,)
            ).fetchone()
        return dict(row) if row else None

    def add_message(self, direction: str, peer: str, body: str, msg_id: str = "", command: str = "", status: str = "seen") -> None:
        call = safe_callsign(peer)
        if not call:
            return
        clean = re.sub(r"[\r\n\x00-\x1f]", " ", body).strip()[:200]
        with self.lock, self.conn:
            self.conn.execute(
                "INSERT INTO messages(ts,direction,peer,body,msg_id,command,status) VALUES(?,?,?,?,?,?,?)",
                (iso_utc(), direction[:8], call, clean, msg_id[:8], command[:16], status[:16]),
            )

    def update_outgoing_status(self, peer: str, msg_id: str, status: str) -> bool:
        call = safe_callsign(peer)
        mid = re.sub(r"[^A-Za-z0-9]", "", str(msg_id))[:8]
        if not call or not mid:
            return False
        with self.lock, self.conn:
            row = self.conn.execute(
                "SELECT id FROM messages "
                "WHERE direction='out' AND peer=? AND msg_id=? "
                "ORDER BY id DESC LIMIT 1",
                (call, mid),
            ).fetchone()
            if not row:
                return False
            self.conn.execute(
                "UPDATE messages SET status=? WHERE id=?",
                (status[:16], row["id"]),
            )
        return True

    def status_value(self, key: str) -> Any:
        with self.lock:
            row = self.conn.execute(
                "SELECT value FROM status WHERE key=? LIMIT 1",
                (key,),
            ).fetchone()

        if not row:
            return None

        try:
            return json.loads(row["value"])
        except Exception:
            return row["value"]

    def recent_station_count(self, minutes: int = 15) -> int:
        minutes = max(1, min(int(minutes), 1440))

        cutoff = (
            utcnow() - dt.timedelta(minutes=minutes)
        ).replace(
            microsecond=0
        ).isoformat().replace("+00:00", "Z")

        with self.lock:
            row = self.conn.execute(
                "SELECT COUNT(*) AS total "
                "FROM stations WHERE last_seen >= ?",
                (cutoff,),
            ).fetchone()

        return int(row["total"] if row else 0)

    def operator_messages(self, limit: int = 30) -> list[dict[str, Any]]:
        limit = max(1, min(int(limit), 50))
        with self.lock:
            rows = self.conn.execute(
                "SELECT id,ts,direction,peer,body,msg_id,command,status "
                "FROM messages ORDER BY id DESC LIMIT ?",
                (limit,),
            ).fetchall()
        return [dict(x) for x in rows]

    def cleanup(self) -> None:
        cutoff = (utcnow() - dt.timedelta(days=self.retention_days)).replace(microsecond=0).isoformat().replace("+00:00", "Z")
        with self.lock, self.conn:
            self.conn.execute("DELETE FROM events WHERE ts < ?", (cutoff,))
            self.conn.execute("DELETE FROM messages WHERE ts < ?", (cutoff,))

    def publish(self, public_config: dict[str, Any]) -> None:
        with self.lock:
            status_rows = self.conn.execute("SELECT key,value,updated_at FROM status").fetchall()
            stations = self.conn.execute(
                "SELECT callsign,lat,lon,source,protocol,module,format,speed_knots,course,last_seen FROM stations ORDER BY last_seen DESC LIMIT 60"
            ).fetchall()
            events = self.conn.execute(
                "SELECT ts,kind,callsign,source,module,detail FROM events WHERE kind IN ('beacon','text','command','connect','disconnect') ORDER BY id DESC LIMIT 50"
            ).fetchall()
            # Only command-classified APRS messages are public. Arbitrary message contents remain private in SQLite.
            commands = self.conn.execute(
                "SELECT ts,direction,peer,command,status FROM messages WHERE command <> '' ORDER BY id DESC LIMIT 30"
            ).fetchall()
        statuses: dict[str, Any] = {}
        status_updated: dict[str, str] = {}
        for row in status_rows:
            try:
                statuses[row["key"]] = json.loads(row["value"])
            except Exception:
                statuses[row["key"]] = row["value"]
            status_updated[row["key"]] = row["updated_at"]
        payload = {
            "schema": 1,
            "generated_at": iso_utc(),
            "version": VERSION,
            "config": public_config,
            "status": statuses,
            "status_updated": status_updated,
            "stations": [dict(x) for x in stations],
            "events": [dict(x) for x in events],
            "commands": [dict(x) for x in commands],
        }
        atomic_json_write(self.public_path, payload)


class SnapshotPublisher(threading.Thread):
    daemon = True
    def __init__(self, db: StateDB, public_config: dict[str, Any], stop: threading.Event, interval: float = 2.0) -> None:
        super().__init__(name="snapshot")
        self.db = db
        self.public_config = public_config
        self.stop = stop
        self.interval = max(1.0, interval)

    def run(self) -> None:
        while not self.stop.is_set():
            try:
                self.db.set_status("heartbeat", iso_utc())
                self.db.publish(self.public_config)
            except Exception:
                logging.exception("snapshot publish failed")
            self.stop.wait(self.interval)


class DExtraModuleClient(threading.Thread):
    daemon = True

    def __init__(self, config: dict[str, Any], db: StateDB, stop: threading.Event) -> None:
        super().__init__(name="dextra-b")
        self.cfg = config
        self.site_name = str(config.get("site_name", "XLX")).strip().upper()[:12] or "XLX"
        self.db = db
        self.stop = stop
        self.sock: Optional[socket.socket] = None
        self.connected = False
        self.last_server_packet = 0.0
        self.streams: dict[int, dict[str, Any]] = {}
        self.decoders: dict[int, SlowDataDecoder] = {}

    def _identity(self) -> tuple[str, str, str]:
        return (
            str(self.cfg.get("client_callsign", "")),
            str(self.cfg.get("client_module", "G"))[:1] or "G",
            str(self.cfg.get("module", "B"))[:1] or "B",
        )

    def _set_status(self, state: str, detail: str = "") -> None:
        self.db.set_status("module_b", {"state": state, "detail": detail, "module": str(self.cfg.get("module", "B"))[:1]})

    def run(self) -> None:
        if not self.cfg.get("enabled", False):
            self._set_status("disabled", "Aguardando configuração")
            return
        host = str(self.cfg.get("host", "127.0.0.1"))
        port = int(self.cfg.get("port", 30001))
        call, client_mod, module = self._identity()
        try:
            connect_pkt = build_dextra_connect(call, client_mod, module)
            keepalive = build_dextra_keepalive(call)
            disconnect = build_dextra_disconnect(call, client_mod)
        except ValueError as exc:
            self._set_status("error", str(exc))
            logging.error("DExtra config invalid: %s", exc)
            return

        while not self.stop.is_set():
            try:
                self._session(host, port, connect_pkt, keepalive)
            except Exception as exc:
                logging.warning("DExtra session ended: %s", exc)
                self._set_status("reconnecting", str(exc)[:100])
            finally:
                self.connected = False
                if self.sock:
                    with contextlib.suppress(Exception):
                        self.sock.send(disconnect)
                    with contextlib.suppress(Exception):
                        self.sock.close()
                self.sock = None
                self.streams.clear()
                self.decoders.clear()
            self.stop.wait(5.0)

    def _session(self, host: str, port: int, connect_pkt: bytes, keepalive: bytes) -> None:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(0.5)
        sock.connect((host, port))
        self.sock = sock
        self._set_status("connecting", f"{host}:{port}")
        sock.send(connect_pkt)
        time.sleep(0.15)
        sock.send(connect_pkt)
        deadline = time.monotonic() + 5.0
        while time.monotonic() < deadline and not self.stop.is_set():
            try:
                pkt = sock.recv(2048)
            except socket.timeout:
                continue
            if len(pkt) == 14 and pkt[10:13] == b"ACK":
                self.connected = True
                self.last_server_packet = time.monotonic()
                self._set_status("connected", "DExtra RX passivo")
                self.db.add_event("connect", base_callsign(str(self.cfg.get("client_callsign", ""))), "DExtra", str(self.cfg.get("module", "B"))[:1], "Data Gateway")
                break
            if len(pkt) == 14 and pkt[10:13] == b"NAK":
                raise ConnectionError("XLXD recusou conexão ao módulo")
        if not self.connected:
            raise TimeoutError("sem ACK DExtra")

        next_keep = 0.0
        while not self.stop.is_set():
            now = time.monotonic()
            if now >= next_keep:
                sock.send(keepalive)
                next_keep = now + 2.0  # below XLXD 3-second keepalive period
            if self.last_server_packet and now - self.last_server_packet > 20.0:
                raise TimeoutError("sem tráfego/keepalive do XLXD")
            try:
                pkt = sock.recv(2048)
            except socket.timeout:
                continue
            self.last_server_packet = time.monotonic()
            self._handle_packet(pkt)

    def _handle_packet(self, pkt: bytes) -> None:
        if len(pkt) == 9:
            return
        hdr = parse_dextra_header(pkt)
        if hdr:
            sid = int(hdr["stream_id"])
            self.streams[sid] = hdr
            self.decoders[sid] = SlowDataDecoder()
            call = hdr.get("mycall", "")
            if call:
                self.db.add_event("stream", call, "DSTAR", str(self.cfg.get("module", "B"))[:1], "DV header")
            return
        frame = parse_dextra_frame(pkt)
        if not frame:
            return
        sid = int(frame["stream_id"])
        decoder = self.decoders.get(sid)
        hdr = self.streams.get(sid, {})
        if not decoder:
            decoder = self.decoders.setdefault(sid, SlowDataDecoder())
        if frame["seq"] == 0:
            decoder.sync()
        for ev in decoder.feed(frame["slow"]):
            self._handle_slow_event(hdr, ev)
        if frame["end"]:
            self.decoders.pop(sid, None)
            self.streams.pop(sid, None)

    def _handle_slow_event(self, hdr: dict[str, Any], ev: SlowEvent) -> None:
        module = str(self.cfg.get("module", "B"))[:1]
        header_call = safe_callsign(str(hdr.get("mycall", "")))
        if ev.kind == "dprs":
            data = ev.data
            call = safe_callsign(str(data.get("source", ""))) or header_call
            if "lat" in data and "lon" in data and call:
                self.db.update_station(call, float(data["lat"]), float(data["lon"]), "DPRS_MODULE_B", "DSTAR", module, str(data.get("format", "GPS-A")), raw_hash=hashlib.sha256(str(data.get("packet", "")).encode()).hexdigest())
            elif call:
                self.db.add_event("dprs", call, "DPRS_MODULE_B", module, "GPS-A validado sem posição decodificada")
        elif ev.kind == "position":
            data = ev.data
            if header_call:
                self.db.update_station(header_call, float(data["lat"]), float(data["lon"]), "DPRS_MODULE_B", "DSTAR", module, str(data.get("format", "NMEA")), data.get("speed_knots"), data.get("course"))
        elif ev.kind == "text" and header_call:
            # Do not expose arbitrary text content in the public snapshot.
            self.db.add_event("text", header_call, "DSTAR_SLOW_DATA", module, "Texto DV recebido")


class APRSISClient(threading.Thread):
    daemon = True

    def __init__(self, config: dict[str, Any], db: StateDB, stop: threading.Event) -> None:
        super().__init__(name="aprs-is")
        self.cfg = config
        self.db = db
        self.stop = stop
        self.sock: Optional[socket.socket] = None
        self.file = None
        self.verified = False
        self.msg_counter = 0
        self.send_lock = threading.Lock()
        self.last_auto_reply = 0.0
        self.auto_reply_by_peer: dict[str, float] = {}

    def _set_status(self, state: str, detail: str = "") -> None:
        self.db.set_status("aprs_is", {"state": state, "detail": detail, "tx_enabled": bool(self.cfg.get("tx_enabled", False) and self.verified)})

    def run(self) -> None:
        if not self.cfg.get("enabled", False):
            self._set_status("disabled", "Aguardando configuração")
            return
        login = safe_callsign(str(self.cfg.get("login", "")))
        if not login:
            self._set_status("error", "Indicativo APRS inválido")
            return
        while not self.stop.is_set():
            try:
                self._session(login)
            except Exception as exc:
                logging.warning("APRS-IS session ended: %s", exc)
                self._set_status("reconnecting", str(exc)[:100])
            finally:
                self.verified = False
                if self.file:
                    with contextlib.suppress(Exception):
                        self.file.close()
                self.file = None
                if self.sock:
                    with contextlib.suppress(Exception):
                        self.sock.close()
                self.sock = None
            self.stop.wait(5.0)

    def _session(self, login: str) -> None:
        host = str(self.cfg.get("host", "rotate.aprs2.net"))
        port = int(self.cfg.get("port", 14580))
        passcode = str(self.cfg.get("passcode", "-1") or "-1")
        if passcode.lower() == "auto":
            passcode = str(aprs_passcode(login))
        filt = re.sub(r"[\r\n]", " ", str(self.cfg.get("filter", ""))).strip()[:200]
        self._set_status("connecting", f"{host}:{port}")
        sock = socket.create_connection((host, port), timeout=10)
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        sock.settimeout(30)
        self.sock = sock
        login_line = f"user {login} pass {passcode} vers {SOFTWARE} {VERSION}"
        if filt:
            login_line += " filter " + filt
        sock.sendall((login_line + "\r\n").encode("ascii", "ignore"))
        f = sock.makefile("r", encoding="utf-8", errors="replace", newline="\n")
        self.file = f
        last_rx = time.monotonic()
        for line in f:
            if self.stop.is_set():
                break
            last_rx = time.monotonic()
            line = line.rstrip("\r\n")
            if not line:
                continue
            if line.startswith("#"):
                low = line.lower()
                if "logresp" in low:
                    self.verified = "verified" in low and "unverified" not in low
                    tx_ok = bool(self.cfg.get("tx_enabled", False) and self.verified)
                    self._set_status("connected", "verified" if self.verified else "receive-only")
                    self.db.set_status("aprs_tx", {"enabled": tx_ok})
                continue
            self._handle_packet(line, login)
        if time.monotonic() - last_rx > 40:
            raise TimeoutError("APRS-IS sem dados")
        raise ConnectionError("APRS-IS desconectou")

    def _send_line(self, line: str) -> bool:
        clean = line.replace("\r", "").replace("\n", "")[:510]
        with self.send_lock:
            if not self.sock or not self.verified or not self.cfg.get("tx_enabled", False):
                return False
            try:
                self.sock.sendall((clean + "\r\n").encode("ascii", "ignore"))
                return True
            except OSError:
                return False

    def _next_id(self) -> str:
        self.msg_counter = (self.msg_counter + 1) % 1000
        return str(self.msg_counter)

    def _send_message(self, source: str, dest: str, text: str) -> bool:
        mid = self._next_id()
        try:
            line = build_aprs_message(source, dest, text, mid)
        except ValueError:
            return False
        ok = self._send_line(line)
        if ok:
            self.db.add_message("out", dest, text, mid, self._command_name(text), "sent")
        return ok

    def send_operator_message(self, dest: str, text: str) -> dict[str, Any]:
        target = safe_callsign(dest)
        clean = str(text).strip()

        if not target or len(target) > 9:
            return {"ok": False, "error": "invalid_destination"}

        if not clean or "{" in clean or "}" in clean:
            return {"ok": False, "error": "invalid_message"}

        try:
            raw = clean.encode("ascii")
        except UnicodeEncodeError:
            return {"ok": False, "error": "ascii_only"}

        if len(raw) > 60:
            return {"ok": False, "error": "message_too_long"}

        if not self.verified:
            return {"ok": False, "error": "aprs_not_verified"}

        if not self.cfg.get("tx_enabled", False):
            return {"ok": False, "error": "tx_disabled"}

        mid = self._next_id()

        try:
            line = build_aprs_message(
                safe_callsign(str(self.cfg.get("login", ""))),
                target,
                clean,
                mid,
            )
        except ValueError:
            return {"ok": False, "error": "packet_invalid"}

        if not self._send_line(line):
            return {"ok": False, "error": "send_failed"}

        self.db.add_message(
            "out",
            target,
            clean,
            mid,
            self._command_name(clean),
            "awaiting_ack",
        )

        return {
            "ok": True,
            "peer": target,
            "msg_id": mid,
            "status": "awaiting_ack",
        }

    @staticmethod
    def _command_name(body: str) -> str:
        cmd = body.strip().upper().split(maxsplit=1)[0] if body.strip() else ""
        return cmd if cmd in {
            "PING",
            "HELP",
            "STATUS",
            "LAST",
            "MYLAST",
            "ONLINE",
            "MODULE",
            "INFO",
        } else ""

    def _handle_packet(self, line: str, login: str) -> None:
        packet = parse_tnc2(line)
        if not packet:
            return
        source = packet["source"]
        pos = parse_aprs_position(packet["info"])
        if pos:
            self.db.update_station(source, pos["lat"], pos["lon"], "APRS_IS", "APRS", "", "APRS")
        msg = parse_aprs_message(packet["info"])
        if not msg:
            return
        # Keep the service SSID isolated from the operator's other APRS identities.
        if safe_callsign(msg["addressee"]) != safe_callsign(login):
            return
        body = msg["body"].strip()

        ack_match = re.fullmatch(
            r"(?i:ack)([A-Za-z0-9]{1,5})",
            body,
        )
        if ack_match:
            self.db.update_outgoing_status(
                source,
                ack_match.group(1),
                "acked",
            )
            return

        rej_match = re.fullmatch(
            r"(?i:rej)([A-Za-z0-9]{1,5})",
            body,
        )
        if rej_match:
            self.db.update_outgoing_status(
                source,
                rej_match.group(1),
                "rejected",
            )
            return

        # Do not publish arbitrary message contents; only the command name appears publicly.
        command = self._command_name(body)
        self.db.add_message(
            "in",
            source,
            body,
            msg["msg_id"],
            command,
            "received",
        )
        if msg["msg_id"] and self.verified and self.cfg.get("tx_enabled", False):
            ack = build_aprs_message(login, source, "ack" + msg["msg_id"])
            self._send_line(ack)
        if not command:
            return

        self.db.add_event("command", source, "APRS_IS", "", command)

        # Proteção contra flood de respostas automáticas.
        now = time.monotonic()
        peer_last = self.auto_reply_by_peer.get(source, 0.0)

        if now - peer_last < 15.0 or now - self.last_auto_reply < 2.0:
            return

        response = self._command_response(command, body, source)

        if response and self._send_message(login, source, response):
            self.last_auto_reply = now
            self.auto_reply_by_peer[source] = now

            if len(self.auto_reply_by_peer) > 256:
                self.auto_reply_by_peer = {
                    k: v for k, v in self.auto_reply_by_peer.items()
                    if now - v < 3600
                }

    def _command_response(self, command: str, body: str, source: str) -> str:
        if command == "PING":
            return f"PONG {self.site_name} APRS DPRS"

        if command == "HELP":
            return "CMD PING STATUS LAST MYLAST ONLINE MODULE INFO HELP"

        if command == "STATUS":
            status = self.db.status_value("module_b")
            state = (
                str(status.get("state", "unknown")).upper()
                if isinstance(status, dict)
                else "UNKNOWN"
            )
            return f"{self.site_name} ONLINE | B {state}"

        if command == "LAST":
            parts = body.strip().upper().split(maxsplit=1)
            target = safe_callsign(parts[1]) if len(parts) > 1 else source

            row = self.db.last_event_for(target)

            if not row:
                return f"SEM ATIVIDADE LOCAL: {target}"

            return (
                f"LAST {target} "
                f"{row.get('kind','').upper()} "
                f"{row.get('ts','')[-9:-1]}Z"
            )

        if command == "MYLAST":
            row = self.db.last_event_for(source)

            if not row:
                return f"SEM ATIVIDADE LOCAL: {source}"

            return (
                f"MYLAST {row.get('kind','').upper()} "
                f"{row.get('ts','')[-9:-1]}Z"
            )

        if command == "ONLINE":
            total = self.db.recent_station_count(15)
            return f"ONLINE 15M: {total} ESTACOES"

        if command == "MODULE":
            status = self.db.status_value("module_b")

            state = (
                str(status.get("state", "unknown")).upper()
                if isinstance(status, dict)
                else "UNKNOWN"
            )

            return f"MODULE B {state}"

        if command == "INFO":
            return f"{self.site_name} APRS DPRS GPS MODULE B"

        return ""


# DIGITAL LAB V1.1 OPERATOR IPC
class OperatorSocketServer(threading.Thread):
    daemon = True

    def __init__(
        self,
        path: Path,
        aprs: APRSISClient,
        db: StateDB,
        stop: threading.Event,
    ) -> None:
        super().__init__(name="operator-ipc")
        self.path = path
        self.aprs = aprs
        self.db = db
        self.stop = stop
        self.server: Optional[socket.socket] = None

    @staticmethod
    def _send_json(conn: socket.socket, payload: dict[str, Any]) -> None:
        raw = (
            json.dumps(
                payload,
                ensure_ascii=False,
                separators=(",", ":"),
            )
            + "\n"
        ).encode("utf-8")

        conn.sendall(raw)

    def _process(self, req: dict[str, Any]) -> dict[str, Any]:
        action = str(req.get("action", "")).strip().lower()

        if action == "status":
            return {
                "ok": True,
                "connected": bool(
                    self.aprs.sock is not None
                    and self.aprs.verified
                ),
                "tx_enabled": bool(
                    self.aprs.cfg.get("tx_enabled", False)
                    and self.aprs.verified
                ),
                "service": safe_callsign(
                    str(self.aprs.cfg.get("login", ""))
                ),
                "messages": self.db.operator_messages(30),
            }

        if action == "send":
            return self.aprs.send_operator_message(
                str(req.get("dest", "")),
                str(req.get("message", "")),
            )

        return {"ok": False, "error": "unknown_action"}

    def run(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)

        with contextlib.suppress(FileNotFoundError):
            self.path.unlink()

        srv = socket.socket(
            socket.AF_UNIX,
            socket.SOCK_STREAM,
        )

        self.server = srv

        try:
            srv.bind(str(self.path))
            self.path.chmod(0o660)
            srv.listen(8)
            srv.settimeout(1.0)

            while not self.stop.is_set():
                try:
                    conn, _ = srv.accept()
                except socket.timeout:
                    continue

                with conn:
                    conn.settimeout(2.0)
                    data = b""

                    try:
                        while len(data) < 8192:
                            chunk = conn.recv(4096)

                            if not chunk:
                                break

                            data += chunk

                            if b"\n" in data:
                                break

                        line = data.split(b"\n", 1)[0]

                        req = json.loads(
                            line.decode(
                                "utf-8",
                                "replace",
                            )
                        )

                        if not isinstance(req, dict):
                            raise ValueError(
                                "request must be object"
                            )

                        reply = self._process(req)

                    except Exception as exc:
                        reply = {
                            "ok": False,
                            "error": "ipc_error",
                            "detail": str(exc)[:120],
                        }

                    with contextlib.suppress(Exception):
                        self._send_json(conn, reply)

        finally:
            with contextlib.suppress(Exception):
                srv.close()

            self.server = None

            with contextlib.suppress(FileNotFoundError):
                self.path.unlink()


class Housekeeper(threading.Thread):
    daemon = True
    def __init__(self, db: StateDB, stop: threading.Event) -> None:
        super().__init__(name="cleanup")
        self.db = db
        self.stop = stop

    def run(self) -> None:
        while not self.stop.is_set():
            try:
                self.db.cleanup()
            except Exception:
                logging.exception("cleanup failed")
            self.stop.wait(3600)


def default_config() -> dict[str, Any]:
    return {
        "database": "/var/lib/xlx-aprs-dprs/digital-lab.sqlite",
        "public_snapshot": "/var/lib/xlx-aprs-dprs/public.json",
        "operator_socket": "/var/lib/xlx-aprs-dprs/operator.sock",
        "retention_days": 7,
        "snapshot_interval": 2,
        "reflector": {
            "enabled": False,
            "host": "127.0.0.1",
            "port": 30001,
            "module": "B",
            "client_callsign": "",
            "client_module": "G"
        },
        "aprs": {
            "enabled": False,
            "host": "rotate.aprs2.net",
            "port": 14580,
            "login": "",
            "passcode": "-1",
            "filter": "",
            "tx_enabled": False
        },
        "site": {
            "title": "XLX APRS/D-PRS",
            "reflector": "XLX",
            "module": "B"
        }
    }


def merge_dict(base: dict[str, Any], custom: dict[str, Any]) -> dict[str, Any]:
    out = dict(base)
    for key, value in custom.items():
        if isinstance(value, dict) and isinstance(out.get(key), dict):
            out[key] = merge_dict(out[key], value)
        else:
            out[key] = value
    return out


def load_config(path: Path) -> dict[str, Any]:
    cfg = default_config()
    if path.exists():
        with open(path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
        if not isinstance(data, dict):
            raise ValueError("config root must be object")
        cfg = merge_dict(cfg, data)
    return cfg


def validate_config(cfg: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    r = cfg.get("reflector", {})
    a = cfg.get("aprs", {})
    if r.get("enabled"):
        if not base_callsign(str(r.get("client_callsign", ""))):
            errors.append("reflector.client_callsign inválido")
        if str(r.get("module", ""))[:1] < "A" or str(r.get("module", ""))[:1] > "Z":
            errors.append("reflector.module inválido")
        try:
            p = int(r.get("port", 0))
            if not 1 <= p <= 65535:
                raise ValueError
        except Exception:
            errors.append("reflector.port inválido")
    if a.get("enabled"):
        if not safe_callsign(str(a.get("login", ""))):
            errors.append("aprs.login inválido")
        try:
            p = int(a.get("port", 0))
            if not 1 <= p <= 65535:
                raise ValueError
        except Exception:
            errors.append("aprs.port inválido")
        if a.get("tx_enabled") and str(a.get("passcode", "-1")).lower() in ("", "-1"):
            errors.append("APRS TX exige passcode verificado ou valor auto")
    return errors


def run_service(config_path: Path) -> int:
    cfg = load_config(config_path)
    errors = validate_config(cfg)
    if errors:
        for e in errors:
            logging.error("CONFIG: %s", e)
        return 2
    db = StateDB(Path(cfg["database"]), Path(cfg["public_snapshot"]), int(cfg.get("retention_days", 7)))
    stop = threading.Event()

    def handle_signal(signum, _frame):
        logging.info("signal %s; stopping", signum)
        stop.set()

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    public_cfg = {
        "reflector": str(cfg.get("site", {}).get("reflector", "XLX")),
        "module": str(cfg.get("site", {}).get("module", "B"))[:1],
        "aprs_service": safe_callsign(str(cfg.get("aprs", {}).get("login", ""))),
        "aprs_tx_configured": bool(cfg.get("aprs", {}).get("tx_enabled", False)),
    }
    aprs_cfg = dict(cfg.get("aprs", {}))
    aprs_cfg["site_name"] = str(cfg.get("site", {}).get("reflector", "XLX"))
    aprs_client = APRSISClient(
        aprs_cfg,
        db,
        stop,
    )

    operator_ipc = OperatorSocketServer(
        Path(
            str(
                cfg.get(
                    "operator_socket",
                    "/var/lib/xlx-aprs-dprs/operator.sock",
                )
            )
        ),
        aprs_client,
        db,
        stop,
    )

    threads: list[threading.Thread] = [
        SnapshotPublisher(
            db,
            public_cfg,
            stop,
            float(cfg.get("snapshot_interval", 2)),
        ),
        DExtraModuleClient(
            cfg.get("reflector", {}),
            db,
            stop,
        ),
        aprs_client,
        operator_ipc,
        Housekeeper(db, stop),
    ]
    db.set_status("gateway", "running")
    for t in threads:
        t.start()
    logging.info("XLX APRS/D-PRS %s started", VERSION)
    try:
        while not stop.wait(1.0):
            # Core watchdog: a dead worker is visible, not silently ignored.
            for t in threads:
                if not t.is_alive() and t.name in ("snapshot", "cleanup", "operator-ipc"):
                    logging.error("critical worker stopped: %s", t.name)
                    stop.set()
                    break
    finally:
        stop.set()
        for t in threads:
            t.join(timeout=3)
        db.set_status("gateway", "stopped")
        with contextlib.suppress(Exception):
            db.publish(public_cfg)
        db.close()
    return 0


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="XLX APRS/D-PRS gateway")
    parser.add_argument("-c", "--config", default="/etc/xlx-aprs-dprs/config.json")
    parser.add_argument("--check-config", action="store_true")
    parser.add_argument("--print-default-config", action="store_true")
    parser.add_argument("--log-level", default="INFO", choices=["DEBUG", "INFO", "WARNING", "ERROR"])
    args = parser.parse_args(argv)
    logging.basicConfig(level=getattr(logging, args.log_level), format="%(asctime)s %(levelname)s %(threadName)s %(message)s")
    if args.print_default_config:
        print(json.dumps(default_config(), indent=2, ensure_ascii=False))
        return 0
    path = Path(args.config)
    try:
        cfg = load_config(path)
        errors = validate_config(cfg)
    except Exception as exc:
        print(f"ERRO: {exc}")
        return 2
    if args.check_config:
        if errors:
            for e in errors:
                print("ERRO:", e)
            return 2
        print("OK: configuração válida")
        return 0
    return run_service(path)


if __name__ == "__main__":
    raise SystemExit(main())
