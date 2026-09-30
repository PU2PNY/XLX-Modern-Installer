#!/usr/bin/env python3
"""
XLX Modern Transmission Analyzer V1.

Passive YSF transport analyzer. It never modifies, delays, retransmits or
rewrites reflector traffic. It receives a copy of local UDP traffic through
a raw socket and publishes bounded local state plus anomaly-only logs.

V1 does not decode AMBE/AMBE+2 audio and therefore does not claim acoustic
noise, clipping, EQ or intelligibility measurements.
"""
from __future__ import annotations

import argparse
import collections
import dataclasses
import json
import os
import pathlib
import signal
import socket
import struct
import tempfile
import time
from typing import Deque, Dict, Optional, Tuple

STATE_DIR = pathlib.Path(os.environ.get(
    "XLX_ANALYZER_STATE_DIR", "/var/lib/xlx-modern-transmission-analyzer"
))
STATE_FILE = STATE_DIR / "state.json"
EVENT_LOG = pathlib.Path(os.environ.get(
    "XLX_ANALYZER_EVENT_LOG", "/var/log/xlx-modern-transmission-analyzer/events.log"
))
YSF_PORT = int(os.environ.get("XLX_ANALYZER_YSF_PORT", "42000"))
SESSION_TTL = float(os.environ.get("XLX_ANALYZER_SESSION_TTL", "45"))
BURST_RESET_S = float(os.environ.get("XLX_ANALYZER_BURST_RESET_S", "1.0"))
STATE_INTERVAL_S = float(os.environ.get("XLX_ANALYZER_STATE_INTERVAL_S", "1.0"))
RECENT_EVENT_LIMIT = 80
STATION_TTL_S = 3600.0
STOP = False


def _stop(_signum, _frame):
    global STOP
    STOP = True


def clean_call(raw: bytes) -> str:
    return raw.decode("ascii", "replace").replace("\x00", " ").strip()


def atomic_json(path: pathlib.Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=path.name + ".", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, ensure_ascii=False, separators=(",", ":"))
            handle.write("\n")
        os.chmod(tmp, 0o640)
        os.replace(tmp, path)
    finally:
        try:
            os.unlink(tmp)
        except FileNotFoundError:
            pass


def append_event(event: dict) -> None:
    EVENT_LOG.parent.mkdir(parents=True, exist_ok=True)
    with EVENT_LOG.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(event, ensure_ascii=False, separators=(",", ":")) + "\n")


def parse_ipv4_udp(packet: bytes):
    if len(packet) < 28 or packet[0] >> 4 != 4:
        return None
    ihl = (packet[0] & 0x0F) * 4
    if ihl < 20 or len(packet) < ihl + 8 or packet[9] != socket.IPPROTO_UDP:
        return None
    total_len = struct.unpack("!H", packet[2:4])[0]
    if total_len < ihl + 8:
        return None
    total_len = min(total_len, len(packet))
    src_ip = socket.inet_ntoa(packet[12:16])
    dst_ip = socket.inet_ntoa(packet[16:20])
    src_port, dst_port, udp_len, _checksum = struct.unpack("!HHHH", packet[ihl:ihl + 8])
    if udp_len < 8:
        return None
    end = min(ihl + udp_len, total_len)
    return src_ip, dst_ip, src_port, dst_port, packet[ihl + 8:end]


@dataclasses.dataclass
class Flow:
    last_at: float = 0.0
    last_seq: Optional[int] = None
    last_eot: bool = False
    frames: int = 0
    likely_missing: int = 0
    gap_events: int = 0
    counter_jumps: int = 0
    duplicates: int = 0
    reordered: int = 0
    max_iat_ms: float = 0.0
    jitter_ewma_ms: float = 0.0
    burst_id: int = 0


@dataclasses.dataclass
class Station:
    callsign: str
    protocol: str = "YSF"
    first_seen: float = 0.0
    last_seen: float = 0.0
    frames: int = 0
    likely_missing: int = 0
    gap_events: int = 0
    counter_jumps: int = 0
    duplicates: int = 0
    reordered: int = 0
    reconnects: int = 0
    max_iat_ms: float = 0.0
    jitter_ewma_ms: float = 0.0
    gateway: str = ""
    destination: str = ""
    active_endpoint_count: int = 0
    anomaly_times: Deque[float] = dataclasses.field(
        default_factory=lambda: collections.deque(maxlen=128)
    )


class Analyzer:
    def __init__(self, now_fn=time.time):
        self.now_fn = now_fn
        self.flows: Dict[Tuple[str, int, str, str], Flow] = {}
        self.stations: Dict[str, Station] = {}
        self.sessions: Dict[Tuple[str, str, int], float] = {}
        self.recent_events = collections.deque(maxlen=RECENT_EVENT_LIMIT)
        self.total_ysfd = 0
        self.total_ysfp = 0
        self.started_at = self.now_fn()

    def _station(self, callsign: str, now: float) -> Station:
        key = callsign or "UNKNOWN"
        station = self.stations.get(key)
        if station is None:
            station = Station(callsign=key, first_seen=now, last_seen=now)
            self.stations[key] = station
        station.last_seen = now
        return station

    def _event(self, station: Station, kind: str, severity: str, now: float, **detail) -> None:
        event = {
            "at": round(now, 3),
            "protocol": "YSF",
            "callsign": station.callsign,
            "type": kind,
            "severity": severity,
            "detail": detail,
        }
        self.recent_events.append(event)
        station.anomaly_times.append(now)
        try:
            append_event(event)
        except OSError:
            pass

    def _refresh_endpoint_count(self, callsign: str, now: float, station: Station) -> None:
        active = {
            (ip, port)
            for (cs, ip, port), seen in self.sessions.items()
            if cs == callsign and now - seen <= SESSION_TTL
        }
        previous = station.active_endpoint_count
        station.active_endpoint_count = len(active)
        if previous <= 1 < station.active_endpoint_count:
            self._event(
                station,
                "concurrent_endpoints",
                "warning",
                now,
                endpoint_count=station.active_endpoint_count,
            )

    def process_ysf(self, payload: bytes, src_ip: str, src_port: int, now: Optional[float] = None) -> None:
        now = self.now_fn() if now is None else float(now)

        if payload.startswith(b"YSFP") and len(payload) == 14:
            self.total_ysfp += 1
            callsign = clean_call(payload[4:14]) or "UNKNOWN"
            key = (callsign, src_ip, int(src_port))
            was = self.sessions.get(key)
            if was is not None and now - was > SESSION_TTL:
                station = self._station(callsign, now)
                station.reconnects += 1
                self._event(station, "reconnect", "info", now)
            self.sessions[key] = now
            station = self._station(callsign, now)
            self._refresh_endpoint_count(callsign, now, station)
            return

        if not (payload.startswith(b"YSFD") and len(payload) == 155):
            return

        self.total_ysfd += 1
        gateway = clean_call(payload[4:14]) or "UNKNOWN"
        source = clean_call(payload[14:24]) or gateway
        destination = clean_call(payload[24:34])
        fid = payload[34]
        seq = (fid >> 1) & 0x7F
        eot = bool(fid & 0x01)

        station = self._station(source, now)
        station.gateway = gateway
        station.destination = destination
        station.frames += 1

        self.sessions[(gateway, src_ip, int(src_port))] = now
        self._refresh_endpoint_count(gateway, now, self._station(gateway, now))
        if source != gateway:
            self._refresh_endpoint_count(source, now, station)

        key = (src_ip, int(src_port), gateway, source)
        flow = self.flows.setdefault(key, Flow())
        flow.frames += 1

        if eot:
            # The YSF terminator uses the low EOT bit and resets the network
            # frame counter. Never evaluate it as a continuity jump.
            pass
        elif flow.last_seq is None or flow.last_eot or now - flow.last_at > BURST_RESET_S:
            flow.burst_id += 1
        else:
            dt_ms = (now - flow.last_at) * 1000.0
            flow.max_iat_ms = max(flow.max_iat_ms, dt_ms)
            station.max_iat_ms = max(station.max_iat_ms, dt_ms)
            delta = (seq - flow.last_seq) % 128

            if delta == 1:
                jitter = abs(dt_ms - 100.0)
                flow.jitter_ewma_ms = (
                    jitter
                    if flow.jitter_ewma_ms == 0.0
                    else flow.jitter_ewma_ms * 0.85 + jitter * 0.15
                )
                station.jitter_ewma_ms = max(
                    station.jitter_ewma_ms * 0.92,
                    flow.jitter_ewma_ms,
                )
                if dt_ms >= 240.0:
                    flow.gap_events += 1
                    station.gap_events += 1
                    self._event(
                        station,
                        "timing_gap",
                        "warning",
                        now,
                        inter_arrival_ms=round(dt_ms, 1),
                        sequence_delta=delta,
                    )
            elif delta == 0:
                flow.duplicates += 1
                station.duplicates += 1
                self._event(
                    station,
                    "duplicate_frame",
                    "warning",
                    now,
                    sequence=seq,
                    inter_arrival_ms=round(dt_ms, 1),
                )
            else:
                expected_ms = delta * 100.0
                timing_matches_loss = (
                    2 <= delta <= 10
                    and expected_ms * 0.65 <= dt_ms <= expected_ms * 1.75
                )

                if timing_matches_loss:
                    missing = delta - 1
                    flow.likely_missing += missing
                    station.likely_missing += missing
                    flow.gap_events += 1
                    station.gap_events += 1
                    self._event(
                        station,
                        "likely_missing_frames",
                        "warning",
                        now,
                        estimated_missing=missing,
                        previous_sequence=flow.last_seq,
                        sequence=seq,
                        inter_arrival_ms=round(dt_ms, 1),
                    )
                elif delta >= 96:
                    flow.reordered += 1
                    station.reordered += 1
                    self._event(
                        station,
                        "out_of_order_or_reset",
                        "warning",
                        now,
                        previous_sequence=flow.last_seq,
                        sequence=seq,
                        inter_arrival_ms=round(dt_ms, 1),
                    )
                else:
                    flow.counter_jumps += 1
                    station.counter_jumps += 1
                    self._event(
                        station,
                        "counter_jump",
                        "warning",
                        now,
                        previous_sequence=flow.last_seq,
                        sequence=seq,
                        sequence_delta=delta,
                        inter_arrival_ms=round(dt_ms, 1),
                    )

        flow.last_at = now
        flow.last_seq = seq
        flow.last_eot = eot

    def expire(self, now: Optional[float] = None) -> None:
        now = self.now_fn() if now is None else float(now)

        for key, seen in list(self.sessions.items()):
            if now - seen > SESSION_TTL * 4:
                self.sessions.pop(key, None)

        for key, flow in list(self.flows.items()):
            if now - flow.last_at > STATION_TTL_S:
                self.flows.pop(key, None)

        for key, station in list(self.stations.items()):
            if now - station.last_seen > STATION_TTL_S:
                self.stations.pop(key, None)
                continue

            while station.anomaly_times and now - station.anomaly_times[0] > 300:
                station.anomaly_times.popleft()

            self._refresh_endpoint_count(key, now, station)

    @staticmethod
    def _health(station: Station, now: float) -> str:
        recent = sum(1 for stamp in station.anomaly_times if now - stamp <= 60)

        if station.likely_missing >= 5 or station.jitter_ewma_ms >= 80:
            return "critical"

        if (
            recent
            or station.active_endpoint_count > 1
            or station.counter_jumps
            or station.gap_events
            or station.duplicates
            or station.reordered
            or station.jitter_ewma_ms >= 30
        ):
            return "warning"

        return "ok"

    def snapshot(self, now: Optional[float] = None) -> dict:
        now = self.now_fn() if now is None else float(now)
        stations = {}

        for key, station in sorted(self.stations.items()):
            stations[key] = {
                "protocol": station.protocol,
                "health": self._health(station, now),
                "last_seen": round(station.last_seen, 3),
                "gateway": station.gateway,
                "destination": station.destination,
                "frames": station.frames,
                "likely_missing_frames": station.likely_missing,
                "timing_gap_events": station.gap_events,
                "counter_jumps": station.counter_jumps,
                "duplicate_frames": station.duplicates,
                "out_of_order_or_reset": station.reordered,
                "reconnects": station.reconnects,
                "active_endpoint_count": station.active_endpoint_count,
                "jitter_ewma_ms": round(station.jitter_ewma_ms, 2),
                "max_inter_arrival_ms": round(station.max_iat_ms, 2),
            }

        return {
            "version": 1,
            "mode": "passive",
            "audio_path_modified": False,
            "scope": ["YSF_transport"],
            "started_at": round(self.started_at, 3),
            "updated_at": round(now, 3),
            "ysf_port": YSF_PORT,
            "packets": {
                "YSFD": self.total_ysfd,
                "YSFP": self.total_ysfp,
            },
            "stations": stations,
            "recent_events": list(self.recent_events),
        }


def run_capture() -> int:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    EVENT_LOG.parent.mkdir(parents=True, exist_ok=True)

    analyzer = Analyzer()
    sock = socket.socket(socket.AF_INET, socket.SOCK_RAW, socket.IPPROTO_UDP)
    sock.settimeout(1.0)
    last_write = 0.0

    while not STOP:
        try:
            packet, _addr = sock.recvfrom(65535)
        except socket.timeout:
            packet = b""
        except InterruptedError:
            continue

        now = time.time()

        if packet:
            parsed = parse_ipv4_udp(packet)
            if parsed is not None:
                src_ip, _dst_ip, src_port, dst_port, payload = parsed
                if dst_port == YSF_PORT:
                    analyzer.process_ysf(payload, src_ip, src_port, now)

        if now - last_write >= STATE_INTERVAL_S:
            analyzer.expire(now)
            atomic_json(STATE_FILE, analyzer.snapshot(now))
            last_write = now

    atomic_json(STATE_FILE, analyzer.snapshot())
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--print-state", action="store_true")
    args = parser.parse_args()

    if args.print_state:
        try:
            print(STATE_FILE.read_text(encoding="utf-8"), end="")
            return 0
        except FileNotFoundError:
            return 1

    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)
    return run_capture()


if __name__ == "__main__":
    raise SystemExit(main())
