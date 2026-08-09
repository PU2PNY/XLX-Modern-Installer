#!/usr/bin/env python3
"""XLX Registry Monitor.

Read-only health monitor for XLXD/YSF and external registry state.
Uses only the Python standard library. It never changes XLXD, firewall,
DNS, or remote registry records and never triggers validation probes.
"""
from __future__ import annotations

import argparse
import configparser
import datetime as dt
import json
import os
import pathlib
import socket
import subprocess
import tempfile
import urllib.error
import urllib.request
from typing import Any

VERSION = "0.1.0"
DEFAULT_CONFIG = "/etc/xlx-registry-monitor/config.ini"
DEFAULT_CREDENTIALS = "/etc/xlx-registry-monitor/credentials"
DEFAULT_STATUS = "/var/lib/xlx-registry-monitor/status.json"
USER_AGENT = f"XLX-Registry-Monitor/{VERSION}"


def utcnow() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def load_config(path: str) -> configparser.ConfigParser:
    cfg = configparser.ConfigParser()
    if not cfg.read(path):
        raise RuntimeError(f"config not found: {path}")
    return cfg


def load_token(path: str) -> str | None:
    p = pathlib.Path(path)
    if not p.exists():
        return None
    for raw in p.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line.startswith("DVREF_TOKEN="):
            token = line.split("=", 1)[1].strip()
            return token or None
    return None


def check_service(service: str) -> dict[str, Any]:
    try:
        cp = subprocess.run(
            ["systemctl", "is-active", service],
            text=True,
            capture_output=True,
            timeout=5,
            check=False,
        )
        state = (cp.stdout or cp.stderr).strip() or "unknown"
        return {"ok": cp.returncode == 0 and state == "active", "state": state}
    except Exception as exc:
        return {"ok": False, "state": "error", "error": str(exc)}


def resolve_dns(host: str) -> dict[str, Any]:
    v4: set[str] = set()
    v6: set[str] = set()
    try:
        for family, _, _, _, sockaddr in socket.getaddrinfo(host, None, 0, socket.SOCK_DGRAM):
            if family == socket.AF_INET:
                v4.add(sockaddr[0])
            elif family == socket.AF_INET6:
                addr = sockaddr[0]
                if not addr.lower().startswith("::ffff:"):
                    v6.add(addr)
        return {"ok": bool(v4 or v6), "ipv4": sorted(v4), "ipv6": sorted(v6)}
    except OSError as exc:
        return {"ok": False, "ipv4": [], "ipv6": [], "error": str(exc)}


def check_ysfs(host: str, port: int, timeout: float) -> dict[str, Any]:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(timeout)
    try:
        sock.sendto(b"YSFS", (host, port))
        data, peer = sock.recvfrom(4096)
        structural_ok = data.startswith(b"YSFS") and len(data) == 42
        return {
            "ok": structural_ok,
            "peer": f"{peer[0]}:{peer[1]}",
            "bytes": len(data),
            "ascii": data.decode("ascii", errors="replace"),
        }
    except Exception as exc:
        return {"ok": False, "error": str(exc)}
    finally:
        sock.close()


def api_get(url: str, token: str, timeout: float) -> tuple[int | None, Any]:
    req = urllib.request.Request(
        url,
        headers={"Authorization": f"Token {token}", "Accept": "application/json", "User-Agent": USER_AGENT},
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            body = response.read().decode("utf-8", errors="replace")
            return response.status, json.loads(body)
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            body: Any = json.loads(raw)
        except Exception:
            body = {"raw": raw[:2000]}
        return exc.code, body
    except Exception as exc:
        return None, {"error": str(exc)}


def find_designator(obj: Any, designator: str) -> bool:
    if isinstance(obj, dict):
        if str(obj.get("designator", "")).strip() == designator:
            return True
        return any(find_designator(value, designator) for value in obj.values())
    if isinstance(obj, list):
        return any(find_designator(value, designator) for value in obj)
    return False


def check_dvref(base: str, slug: str, designator: str, token: str | None, timeout: float) -> dict[str, Any]:
    if not token:
        return {"enabled": False, "ok": None, "reason": "token_not_configured"}

    base = base.rstrip("/")
    detail_url = f"{base}/api/v2/ysf/reflectors/{slug}/"
    list_url = f"{base}/api/v2/ysf/reflectors/"
    detail_status, detail_body = api_get(detail_url, token, timeout)
    list_status, list_body = api_get(list_url, token, timeout)

    reflector = None
    if isinstance(detail_body, dict):
        reflector = detail_body.get("data", {}).get("reflector")
        if reflector is None:
            reflector = detail_body.get("reflector")

    public_present = list_status == 200 and find_designator(list_body, designator)
    ok = detail_status == 200 and isinstance(reflector, dict)
    return {
        "enabled": True,
        "ok": ok,
        "detail_http": detail_status,
        "public_list_http": list_status,
        "public_present": public_present,
        "reflector": reflector,
    }


def determine_overall(local: dict[str, Any], dns: dict[str, Any], ysf: dict[str, Any], registry: dict[str, Any]) -> str:
    if not local.get("ok") or not dns.get("ok") or not ysf.get("ok"):
        return "critical"
    if registry.get("enabled") and (not registry.get("ok") or not registry.get("public_present")):
        return "warning"
    return "ok"


def atomic_write_json(path: str, payload: dict[str, Any]) -> None:
    target = pathlib.Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{target.name}.", dir=str(target.parent), text=True)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, ensure_ascii=False, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp_name, target)
    finally:
        try:
            os.unlink(tmp_name)
        except FileNotFoundError:
            pass


def run(args: argparse.Namespace) -> int:
    cfg = load_config(args.config)
    reflector = cfg["reflector"]
    monitor = cfg["monitor"]
    dvref = cfg["dvref"]

    domain = reflector.get("domain", "").strip()
    designator = reflector.get("ysf_designator", "").strip()
    slug = reflector.get("dvref_slug", "").strip()
    port = reflector.getint("ysf_port", fallback=42000)
    service = reflector.get("xlxd_service", "xlxd.service").strip()
    timeout = monitor.getfloat("network_timeout_seconds", fallback=5.0)
    status_path = monitor.get("status_file", DEFAULT_STATUS).strip()
    credentials_path = monitor.get("credentials_file", DEFAULT_CREDENTIALS).strip()

    if not domain or not designator or not slug:
        raise RuntimeError("domain, ysf_designator and dvref_slug are required")

    service_result = check_service(service)
    dns_result = resolve_dns(domain)
    ysf_target = dns_result.get("ipv4", [domain])[0] if dns_result.get("ipv4") else domain
    ysf_result = check_ysfs(ysf_target, port, timeout)
    token = load_token(credentials_path)
    registry_result = check_dvref(dvref.get("base_url", "https://dvref.com"), slug, designator, token, timeout)

    payload = {
        "schema_version": 1,
        "monitor_version": VERSION,
        "generated_at": utcnow(),
        "reflector": {"domain": domain, "ysf_designator": designator, "ysf_port": port, "dvref_slug": slug},
        "local": service_result,
        "dns": dns_result,
        "ysf": ysf_result,
        "registry": registry_result,
    }
    payload["overall"] = determine_overall(service_result, dns_result, ysf_result, registry_result)

    if args.stdout:
        print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True))
    if not args.no_write:
        atomic_write_json(status_path, payload)

    return 0 if payload["overall"] == "ok" else 1


def main() -> int:
    parser = argparse.ArgumentParser(description="Read-only XLX registry and YSF health monitor")
    parser.add_argument("--config", default=DEFAULT_CONFIG)
    parser.add_argument("--stdout", action="store_true", help="print JSON status")
    parser.add_argument("--no-write", action="store_true", help="do not update the status file")
    parser.add_argument("--version", action="version", version=VERSION)
    return run(parser.parse_args())


if __name__ == "__main__":
    raise SystemExit(main())
