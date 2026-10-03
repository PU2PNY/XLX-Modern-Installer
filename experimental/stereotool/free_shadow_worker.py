#!/usr/bin/env python3
"""Stereo Tool 11.05 no-key shadow worker for XLX HXP1 PCM copies.

Processed PCM is always discarded. The single DSP context is created and
free-feature-gated before the socket is exposed, then reset between PTTs using
the official SDK reset contract. There is no application voice queue.
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
ID_SAVE_PROCESSING = 20709


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
        L.stereoTool_Reset.argtypes = [ctypes.c_void_p, ctypes.c_int]
        L.stereoTool_Reset.restype = None
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

    def create(self) -> int:
        ptr = self.lib.stereoTool_Create3(False, None, b"XLX026-FREE-SHADOW", b"/tmp", False)
        if not ptr:
            raise RuntimeError("stereoTool_Create3 failed")
        return int(ptr)

    def delete(self, ptr: int) -> None:
        if ptr:
            self.lib.stereoTool_Delete(ctypes.c_void_p(ptr))

    def apply_profile(self, ptr: int, reset: bool) -> None:
        p = ctypes.c_void_p(ptr)
        if reset:
            self.lib.stereoTool_Reset(p, ID_SAVE_PROCESSING)
        # Conservative no-key radio profile verified with SDK 11.05:
        # unity gain, 200 Hz high-pass, 3.4 kHz low-pass.
        for param, value in (
            (PARAM_PREAMP, b"1"),
            (PARAM_HIGHPASS_FREQUENCY, b"200"),
            (PARAM_LOWPASS_ENABLED, b"1"),
            (PARAM_LOWPASS_FREQUENCY, b"3400"),
        ):
            if not self.lib.stereoTool_SetStsValue(p, param, 0, value):
                raise RuntimeError(f"Stereo Tool rejected profile parameter {param}")

    def process(self, ptr: int, pcm: tuple[int, ...], sample_rate: int) -> tuple[float, float, int]:
        n = len(pcm)
        Buf = ctypes.c_float * n
        buf = Buf(*(float(v) / 32768.0 for v in pcm))
        in_sq = sum(float(x) * float(x) for x in buf)
        self.lib.stereoTool_Process(ctypes.c_void_p(ptr), buf, n, 1, sample_rate)
        out_sq = sum(float(x) * float(x) for x in buf)
        return in_sq, out_sq, n

    def warm(self, ptr: int, sample_rate: int = 8000, frames: int = 40) -> None:
        # A non-zero voice-band signal forces lazy DSP initialization before
        # the live observer socket is exposed. The generated samples never
        # leave this process and all processed output is discarded.
        phase = 0.0
        step = 2.0 * math.pi * 700.0 / sample_rate
        for _ in range(frames):
            pcm = []
            for _i in range(160):
                pcm.append(int(1200.0 * math.sin(phase)))
                phase += step
            self.process(ptr, tuple(pcm), sample_rate)

    def free_gate(self, ptr: int) -> tuple[bool, str, bool]:
        text = ctypes.create_string_buffer(8192)
        ok = bool(self.lib.stereoTool_GetUnlicensedUsedFeatures(ctypes.c_void_p(ptr), text, len(text)))
        message = text.value.decode("utf-8", "replace").strip()
        license_valid = bool(self.lib.stereoTool_CheckLicenseValid(ctypes.c_void_p(ptr)))
        return ok and not message, message, license_valid

    def latency(self, ptr: int, sample_rate: int) -> int:
        return int(self.lib.stereoTool_GetLatency2(ctypes.c_void_p(ptr), sample_rate, False))


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
    ap.add_argument("--idle-seconds", type=float, default=1.0)
    ap.add_argument("--stats-interval", type=int, default=60)
    args = ap.parse_args()
    if args.max_contexts != 1:
        raise SystemExit("free shadow V1 intentionally supports exactly one prewarmed context")
    if args.idle_seconds < 0.25:
        raise SystemExit("--idle-seconds must be >= 0.25")

    api = StereoApi(Path(args.lib), args.sha256)
    ptr = api.create()
    api.apply_profile(ptr, reset=False)
    api.warm(ptr)
    free_ok, message, license_valid = api.free_gate(ptr)
    if not free_ok:
        api.delete(ptr)
        raise SystemExit(f"no-key free-feature gate failed: {message[:300]}")
    latency = api.latency(ptr, 8000)

    sock_path = Path(args.socket)
    sock_path.parent.mkdir(parents=True, exist_ok=True)
    remove_socket(sock_path)
    rx = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    # Keep the kernel queue bounded. There is deliberately no application queue.
    rx.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 8192)
    rx.settimeout(0.2)
    rx.bind(str(sock_path))
    os.chmod(sock_path, 0o660)

    running = True
    disabled = False
    owner_stream: int | None = None
    last_seen = 0.0
    frames_on_owner = 0
    stats = {
        "received": 0, "processed": 0, "invalid": 0, "context_full": 0,
        "free_gate_failures": 0, "native_errors": 0, "resets": 0, "samples": 0,
    }
    in_sq = 0.0
    out_sq = 0.0
    last_stats = time.monotonic()

    def prepare_idle() -> None:
        nonlocal owner_stream, frames_on_owner
        api.apply_profile(ptr, reset=True)
        owner_stream = None
        frames_on_owner = 0
        stats["resets"] += 1

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
        "max_contexts": 1, "free_gate": "PASS", "license_valid": license_valid,
        "latency_samples": latency, "latency_ms": round(latency * 1000.0 / 8000, 3),
        "profile": "radio-free-v1",
    }, sort_keys=True), flush=True)

    try:
        while running:
            now = time.monotonic()
            try:
                data = rx.recv(HEADER_LEN + MAX_SAMPLES * 2 + 1)
            except socket.timeout:
                if owner_stream is not None and now - last_seen > args.idle_seconds:
                    try:
                        prepare_idle()
                    except Exception as exc:
                        stats["native_errors"] += 1
                        disabled = True
                        print(json.dumps({"component": "xlx-stereotoold", "event": "reset_failed", "error": str(exc)[:200]}), flush=True)
                continue
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

            if owner_stream is not None and now - last_seen > args.idle_seconds:
                try:
                    prepare_idle()
                except Exception as exc:
                    stats["native_errors"] += 1
                    disabled = True
                    print(json.dumps({"component": "xlx-stereotoold", "event": "reset_failed", "error": str(exc)[:200]}), flush=True)
                    continue

            if owner_stream is None:
                owner_stream = stream_id
                frames_on_owner = 0
            elif stream_id != owner_stream:
                stats["context_full"] += 1
                continue
            elif reset and frames_on_owner > 0:
                # Very short PTT gap: reset synchronously rather than leak DSP state.
                try:
                    api.apply_profile(ptr, reset=True)
                    stats["resets"] += 1
                    frames_on_owner = 0
                except Exception as exc:
                    stats["native_errors"] += 1
                    disabled = True
                    print(json.dumps({"component": "xlx-stereotoold", "event": "reset_failed", "error": str(exc)[:200]}), flush=True)
                    continue

            last_seen = now
            try:
                a, b, n = api.process(ptr, pcm, sample_rate)
                in_sq += a
                out_sq += b
                stats["samples"] += n
                stats["processed"] += 1
                frames_on_owner += 1
                if stats["processed"] % 250 == 0:
                    gate_ok, gate_message, gate_license = api.free_gate(ptr)
                    if not gate_ok:
                        stats["free_gate_failures"] += 1
                        disabled = True
                        print(json.dumps({
                            "component": "xlx-stereotoold", "event": "free_gate_failed",
                            "message": gate_message[:300], "license_valid": gate_license,
                        }, sort_keys=True), flush=True)
            except Exception as exc:
                stats["native_errors"] += 1
                disabled = True
                print(json.dumps({"component": "xlx-stereotoold", "event": "process_error", "error": str(exc)[:200]}), flush=True)

            if now - last_stats >= max(10, args.stats_interval):
                samples = max(1, stats["samples"])
                print(json.dumps({
                    "component": "xlx-stereotoold", "mode": "shadow", "disabled": disabled,
                    "context_busy": owner_stream is not None, **stats,
                    "input_rms": round(math.sqrt(in_sq / samples), 7),
                    "output_rms": round(math.sqrt(out_sq / samples), 7),
                }, sort_keys=True), flush=True)
                last_stats = now
    finally:
        try:
            rx.close()
        except OSError:
            pass
        remove_socket(sock_path)
        api.delete(ptr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
