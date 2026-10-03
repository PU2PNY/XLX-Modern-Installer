#!/usr/bin/env python3
"""Best-effort HXP1 shadow fanout.

Receives the existing xuvd one-way Helix shadow datagram and forwards an exact
copy to independent observers. It never returns PCM to xuvd and never queues
voice. A missing/slow target only increments a counter.
"""
from __future__ import annotations

import argparse
import json
import os
import signal
import socket
import stat
import struct
import time
from pathlib import Path

MAGIC = b"HXP1"
VERSION = 1
HEADER_LEN = 24
MAX_SAMPLES = 960
MAX_PACKET = HEADER_LEN + MAX_SAMPLES * 2


def valid_hxp1(data: bytes) -> bool:
    if len(data) < HEADER_LEN or len(data) > MAX_PACKET:
        return False
    if data[:4] != MAGIC or data[4] != VERSION:
        return False
    sample_count = struct.unpack_from("<H", data, 6)[0]
    sample_rate = struct.unpack_from("<I", data, 12)[0]
    if not 1 <= sample_count <= MAX_SAMPLES:
        return False
    if not 8000 <= sample_rate <= 48000:
        return False
    return len(data) == HEADER_LEN + sample_count * 2


def remove_socket(path: Path) -> None:
    try:
        mode = path.lstat().st_mode
    except FileNotFoundError:
        return
    if not stat.S_ISSOCK(mode):
        raise RuntimeError(f"refusing to replace non-socket path: {path}")
    path.unlink()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--target", action="append", default=[], required=True)
    ap.add_argument("--stats-interval", type=int, default=60)
    args = ap.parse_args()

    input_path = Path(args.input)
    targets = [Path(p) for p in args.target]
    input_path.parent.mkdir(parents=True, exist_ok=True)
    remove_socket(input_path)

    rx = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    tx = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    rx.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 262144)
    tx.setblocking(False)
    rx.bind(str(input_path))
    os.chmod(input_path, 0o660)

    running = True

    def stop(_signum, _frame):
        nonlocal running
        running = False
        try:
            rx.close()
        except OSError:
            pass

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    counters = {"received": 0, "invalid": 0}
    for p in targets:
        counters[f"forwarded:{p}"] = 0
        counters[f"dropped:{p}"] = 0
    last_stats = time.monotonic()

    try:
        while running:
            try:
                data = rx.recv(MAX_PACKET + 1)
            except OSError:
                if not running:
                    break
                raise
            counters["received"] += 1
            if not valid_hxp1(data):
                counters["invalid"] += 1
                continue
            for target in targets:
                try:
                    sent = tx.sendto(data, str(target))
                    if sent == len(data):
                        counters[f"forwarded:{target}"] += 1
                    else:
                        counters[f"dropped:{target}"] += 1
                except (BlockingIOError, FileNotFoundError, ConnectionRefusedError, OSError):
                    counters[f"dropped:{target}"] += 1
            now = time.monotonic()
            if now - last_stats >= max(10, args.stats_interval):
                print(json.dumps({"component": "xlx-pcm-shadow-router", **counters}, sort_keys=True), flush=True)
                last_stats = now
    finally:
        try:
            tx.close()
        except OSError:
            pass
        remove_socket(input_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
