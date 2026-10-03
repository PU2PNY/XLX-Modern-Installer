#!/usr/bin/env python3
"""Stereo Tool 11.05 no-key shadow worker for XLX HXP1 PCM copies.

The worker discards processed PCM. It is intentionally incapable of returning
or committing audio to xuvd. Native library failure can only kill this observer.
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import math
import os
import signal
import socket
import stat
import struct
import time
from dataclasses import dataclass
from pathlib import Path

MAGIC = b"HXP1"
VERSION = 1
HEADER_LEN = 24
RESET_STREAM = 0x02
MAX_SAMPLES = 960
EXPECTED_SOFTWARE_VERSION = 11050
EXPECTED_API_VERSION = 256

# Verified against Thimeo Generic Plugin SDK 11.05 ParameterEnum.h.
PARAM_PREAMP = 6
PARAM_LOWPASS_ENABLED = 98
PARAM_LOWPASS_FREQUENCY = 99
PARAM_HIGHPASS_FREQUENCY = 100


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def remove_socket(path: Path) -> None:
    try:
        mode = path.lstat().st_mode
    except FileNotFoundError:
        return
    if not stat.S_ISSOCK(mode):
        raise RuntimeError(f"refusing to replace non-socket path: {path}")
    path.unlink()


class StereoApi:
    def __init__(self, path: Path, expected_sha256: str):
        actual = sha256(path)
        if actual.lower() != expected_sha256.lower():
            raise RuntimeError(f"Stereo Tool artifact SHA-256 mismatch: {actual}")
        self.lib = ctypes.CDLL(str(path))
        L = self.lib
        L.stereoTool_EnableInternalSoundCard.argtypes = [ctypes.c_bool]
        L.stereoTool_EnableInternalSoundCard.restype = None
        L.stereoTool_GetSoftwareVersion.restype = ctypes.c_int
        L.stereoTool_GetApiVersion.restype = ctypes.c_int
        L.stereoTool_Create3.argtypes = [ctypes.c_bool, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_bool]
        L.stereoTool_Create3.restype = ctypes.c_void_p
        L.stereoTool_Delete.argtypes = [ctypes.c_void_p]
        L.stereoTool_Delete.restype = None
        L.stereoTool_Process.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_float), ctypes.c_int32, ctypes.c_int32, ctypes.c_int32]
        L.stereoTool_Process.restype = None
        L.stereoTool_SetStsValue.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_char_p]
        L.stereoTool_SetStsValue.restype = ctypes.c_bool
        L.stereoTool_GetUnlicensedUsedFeatures.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
        L.stereoTool_GetUnlicensedUsedFeatures.restype = ctypes.c_bool
        L.stereoTool_CheckLicenseValid.argtypes = [ctypes.c_void_p]
        L.stereoTool_CheckLicenseValid.restype = ctypes.c_bool
        L.stereoTool_GetLatency2.argtypes = [ctypes.c_void_p, ctypes.c_int32, ctypes.c_bool]
        L.stereoTool_GetLatency2.restype = ctypes.c_int
        L.stereoTool_EnableInternalSoundCard(False)
        sw = int(L.stereoTool_GetSoftwareVersion())
        api = int(L.stereoTool_GetApiVersion())
        if sw != EXPECTED_SOFTWARE_VERSION or api != EXPECTED_API_VERSION:
            raise RuntimeError(f"unsupported Stereo Tool SDK/runtime: software={sw} api={api}")
        self.software_version = sw
        self.api_version = api

    def create(self, name: str) -> int:
        ptr = self.lib.stereoTool_Create3(False, None, name.encode(), b"/tmp", False)
        if not ptr:
            raise RuntimeError("stereoTool_Create3 failed")
        # Conservative, no-key radio profile verified in the 11.05 SDK lab:
        # unity input gain + 200 Hz high-pass + 3.4 kHz low-pass.
        settings = (
            (PARAM_PREAMP, b"1"),
            (PARAM_HIGHPASS_FREQUENCY, b"200"),
            (PARAM_LOWPASS_ENABLED, b"1"),
            (PARAM_LOWPASS_FREQUENCY, b"3400"),
        )
        for param, value in settings:
            if not self.lib.stereoTool_SetStsValue(ptr, param, 0, value):
                self.lib.stereoTool_Delete(ptr)
                raise RuntimeError(f"Stereo Tool rejected profile parameter {param}")
        return int(ptr)

    def delete(self, ptr: int) -> None:
        if ptr:
            self.lib.stereoTool_Delete(ctypes.c_void_p(ptr))

    def process(self, ptr: int, pcm: tuple[int, ...], sample_rate: int) -> tuple[float, float, int]:
        n = len(pcm)
        Buf = ctypes.c_float * n
        buf = Buf(*(float(v) / 32768.0 for v in pcm))
        in_sq = sum(float(x) * float(x) for x in buf)
        self.lib.stereoTool_Process(ctypes.c_void_p(ptr), buf, n, 1, sample_rate)
        out_sq = sum(float(x) * float(x) for x in buf)
        return in_sq, out_sq, n

    def free_gate(self, ptr: int) -> tuple[bool, str, bool]:
        text = ctypes.create_string_buffer(8192)
        ok = bool(self.lib.stereoTool_GetUnlicensedUsedFeatures(ctypes.c_void_p(ptr), text, len(text)))
        message = text.value.decode("utf-8", "replace").strip()
        license_valid = bool(self.lib.stereoTool_CheckLicenseValid(ctypes.c_void_p(ptr)))
        return ok and not message, message, license_valid

    def latency(self, ptr: int, sample_rate: int) -> int:
        return int(self.lib.stereoTool_GetLatency2(ctypes.c_void_p(ptr), sample_rate, False))


@dataclass
class Context:
    ptr: int
    last_seen: float
    frames: int = 0
    gated: bool = False


def parse_hxp1(data: bytes):
    if len(data) < HEADER_LEN or data[:4] != MAGIC or data[4] != VERSION:
        return None
    count = struct.unpack_from("<H", data, 6)[0]
    stream_id = struct.unpack_from("<I", data, 8)[0]
    sample_rate = struct.unpack_from("<I", data, 12)[0]
    if not 1 <= count <= MAX_SAMPLES or len(data) != HEADER_LEN + count * 2:
        return None
    if sample_rate != 8000:
        return None
    pcm = struct.unpack_from(f"<{count}h", data, HEADER_LEN)
    return stream_id, sample_rate, bool(data[5] & RESET_STREAM), pcm


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--socket", required=True)
    ap.add_argument("--lib", required=True)
    ap.add_argument("--sha256", required=True)
    ap.add_argument("--max-contexts", type=int, default=1)
    ap.add_argument("--idle-seconds", type=float, default=3.0)
    ap.add_argument("--stats-interval", type=int, default=60)
    args = ap.parse_args()
    if args.max_contexts < 1 or args.max_contexts > 2:
        raise SystemExit("--max-contexts must be 1..2 for free shadow V1")

    api = StereoApi(Path(args.lib), args.sha256)
    sock_path = Path(args.socket)
    sock_path.parent.mkdir(parents=True, exist_ok=True)
    remove_socket(sock_path)
    rx = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    rx.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 262144)
    rx.bind(str(sock_path))
    os.chmod(sock_path, 0o660)

    running = True
    disabled = False
    contexts: dict[int, Context] = {}
    stats = {
        "received": 0, "processed": 0, "invalid": 0, "context_full": 0,
        "free_gate_failures": 0, "native_errors": 0, "samples": 0,
    }
    in_sq = 0.0
    out_sq = 0.0
    last_stats = time.monotonic()

    def destroy(stream_id: int) -> None:
        ctx = contexts.pop(stream_id, None)
        if ctx:
            api.delete(ctx.ptr)

    def stop(_signum, _frame):
        nonlocal running
        running = False
        try:
            rx.close()
        except OSError:
            pass

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    print(json.dumps({
        "component": "xlx-stereotoold", "mode": "shadow", "no_key": True,
        "software_version": api.software_version, "api_version": api.api_version,
        "max_contexts": args.max_contexts,
    }, sort_keys=True), flush=True)

    try:
        while running:
            try:
                data = rx.recv(HEADER_LEN + MAX_SAMPLES * 2 + 1)
            except OSError:
                if not running:
                    break
                raise
            stats["received"] += 1
            parsed = parse_hxp1(data)
            if not parsed:
                stats["invalid"] += 1
                continue
            if disabled:
                continue
            stream_id, sample_rate, reset, pcm = parsed
            now = time.monotonic()
            for sid, ctx in list(contexts.items()):
                if now - ctx.last_seen > args.idle_seconds:
                    destroy(sid)
            if reset:
                destroy(stream_id)
            ctx = contexts.get(stream_id)
            if ctx is None:
                if len(contexts) >= args.max_contexts:
                    stats["context_full"] += 1
                    continue
                try:
                    ptr = api.create(f"XLX026-SHADOW-{stream_id}")
                    ctx = Context(ptr=ptr, last_seen=now)
                    contexts[stream_id] = ctx
                except Exception as exc:
                    stats["native_errors"] += 1
                    print(json.dumps({"component": "xlx-stereotoold", "event": "context_create_failed", "error": str(exc)[:200]}), flush=True)
                    continue
            ctx.last_seen = now
            try:
                a, b, n = api.process(ctx.ptr, pcm, sample_rate)
                in_sq += a
                out_sq += b
                stats["samples"] += n
                stats["processed"] += 1
                ctx.frames += 1
                if not ctx.gated:
                    free_ok, message, license_valid = api.free_gate(ctx.ptr)
                    if not free_ok:
                        stats["free_gate_failures"] += 1
                        disabled = True
                        print(json.dumps({
                            "component": "xlx-stereotoold", "event": "free_gate_failed",
                            "message": message[:300], "license_valid": license_valid,
                        }, sort_keys=True), flush=True)
                        destroy(stream_id)
                        continue
                    ctx.gated = True
                    latency = api.latency(ctx.ptr, sample_rate)
                    print(json.dumps({
                        "component": "xlx-stereotoold", "event": "free_gate_pass",
                        "license_valid": license_valid, "latency_samples": latency,
                        "latency_ms": round(latency * 1000.0 / sample_rate, 3),
                    }, sort_keys=True), flush=True)
            except Exception as exc:
                stats["native_errors"] += 1
                print(json.dumps({"component": "xlx-stereotoold", "event": "process_error", "error": str(exc)[:200]}), flush=True)
                destroy(stream_id)

            if now - last_stats >= max(10, args.stats_interval):
                samples = max(1, stats["samples"])
                payload = {
                    "component": "xlx-stereotoold", "mode": "shadow", "disabled": disabled,
                    "contexts": len(contexts), **stats,
                    "input_rms": round(math.sqrt(in_sq / samples), 7),
                    "output_rms": round(math.sqrt(out_sq / samples), 7),
                }
                print(json.dumps(payload, sort_keys=True), flush=True)
                last_stats = now
    finally:
        for sid in list(contexts):
            destroy(sid)
        try:
            rx.close()
        except OSError:
            pass
        remove_socket(sock_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
