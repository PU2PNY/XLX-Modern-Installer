#!/usr/bin/env python3
import argparse
import json
import os
import re
import socket
import ssl
import subprocess
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta
from html import escape
from pathlib import Path
from zoneinfo import ZoneInfo

CONFIG = Path("/etc/xlx-modern-health/config.json")
STATE_DIR = Path("/var/lib/xlx-modern-health-monitor")
STATE_FILE = STATE_DIR / "state.json"
INTERVAL = 60
FAIL_CONFIRMATIONS = 3
REMINDER_SECONDS = 6 * 3600
SUMMARY_HOUR = 8
TIMEZONE = ZoneInfo("UTC")
LAYOUT_VERSION = "LAYOUT_V3_0800_PRIVADO"
OPERATIONAL_VERSION = "XLX_MODERN_OPERATIONAL_HEALTH_V2"
OPERATIONAL_FILE = STATE_DIR / "operational.json"
FLIGHT_DIR = STATE_DIR / "flight-recorder"
FLIGHT_RETENTION_DAYS = 30

SERVICES = {
    'XLXD': 'xlxd.service',
    'Echo': 'xlxecho.service',
    'Web': 'nginx.service',
    'PHP-FPM': 'php8.2-fpm.service',
    'XLX log': 'xlx_log.service',
}

UDP_PORTS = [
    8880, 10001, 10002, 10100, 12345, 12346, 20001,
    21110, 30001, 30051, 40000, 42000, 62030,
]


def runtime_config():
    try:
        x=json.loads(CONFIG.read_text(encoding="utf-8"))
        return x if isinstance(x,dict) else {}
    except Exception:
        return {}

RUNTIME_CONFIG=runtime_config()
DOMAIN=str(RUNTIME_CONFIG.get("domain", "localhost")).strip().lower() or "localhost"
PUBLIC_URL=str(RUNTIME_CONFIG.get("base_url", "https://"+DOMAIN)).rstrip("/")
try:
    TIMEZONE = ZoneInfo(str(RUNTIME_CONFIG.get("timezone", "UTC")))
except Exception:
    TIMEZONE = ZoneInfo("UTC")
try:
    MODULE_COUNT = max(1, min(26, int(RUNTIME_CONFIG.get("module_count", 5))))
except Exception:
    MODULE_COUNT = 5
MODULE_LETTERS = list("ABCDEFGHIJKLMNOPQRSTUVWXYZ"[:MODULE_COUNT])

_DASHBOARD_STATUS_CACHE = {}
_DASHBOARD_STATUS_CACHE_TTL = 45.0
FLIGHT_INCIDENT_DIR = STATE_DIR / "flight-incidents"

def dashboard_status(history24=False):
    now = time.monotonic()

    full = _DASHBOARD_STATUS_CACHE.get("full")
    if full and now - full[0] < _DASHBOARD_STATUS_CACHE_TTL:
        return full[1]

    key = "full" if history24 else "base"
    cached = _DASHBOARD_STATUS_CACHE.get(key)
    if cached and now - cached[0] < _DASHBOARD_STATUS_CACHE_TTL:
        return cached[1]

    url = (
        PUBLIC_URL + '/api/status.php?history_hours=24'
        if history24
        else PUBLIC_URL + '/api/runtime.php'
    )
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "XLX Modern-Health-Monitor/1.0",
        },
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        data = json.loads(response.read().decode("utf-8", errors="replace"))

    if not isinstance(data, dict) or not data.get("ok"):
        raise RuntimeError("dashboard_status_invalid")

    _DASHBOARD_STATUS_CACHE[key] = (now, data)
    if history24:
        _DASHBOARD_STATUS_CACHE["base"] = (now, data)
    return data

def parse_unified_voice(minutes=15):
    """TRANSCODER_HEALTH_V2: correlaciona OPEN/CLOSE por rota de codec e módulo."""
    raw = recent_journal("xlx-unified-voice.service", minutes)
    totals={"streams_open":0,"streams_close":0,"frames":0,"failures":0,"bad":0,"concealed":0,"muted":0,"severe_streams":0}
    opens={}; routes={}

    for line in raw.splitlines():
        if "OPEN stream=" in line:
            totals["streams_open"] += 1
            sid_m=re.search(r"\bstream=(\d+)",line)
            codec_m=re.search(r"\bcodec=(\d+)->(\d+)",line)
            module_m=re.search(r"\bmodule=([A-Z])",line)
            clean_m=re.search(r"\bcleanC=([A-Z]+)",line,re.I)
            if sid_m:
                opens[sid_m.group(1)]={
                    "codec": f"{codec_m.group(1)}->{codec_m.group(2)}" if codec_m else "?",
                    "module": module_m.group(1) if module_m else "?",
                    "clean": clean_m.group(1).upper() if clean_m else "?",
                }
        if "CLOSE stream=" not in line:
            continue
        totals["streams_close"] += 1
        row={}
        for key in ("frames","failures","bad","concealed","muted"):
            match=re.search(rf"\b{key}=(\d+)",line)
            value=int(match.group(1)) if match else 0
            row[key]=value; totals[key]+=value
        if row["frames"] >= 100 and row["bad"] / row["frames"] >= 0.80:
            totals["severe_streams"] += 1
        sid_m=re.search(r"\bstream=(\d+)",line)
        meta=opens.get(sid_m.group(1),{}) if sid_m else {}
        route=f"codec_{meta.get('codec','?')}_module_{meta.get('module','?')}"
        rr=routes.setdefault(route,{"codec":meta.get("codec","?"),"module":meta.get("module","?"),"clean":meta.get("clean","?"),"streams":0,"frames":0,"failures":0,"bad":0,"concealed":0,"muted":0,"severe_streams":0})
        rr["streams"] += 1
        for key in ("frames","failures","bad","concealed","muted"):
            rr[key] += row[key]
        if row["frames"] >= 100 and row["bad"] / row["frames"] >= 0.80:
            rr["severe_streams"] += 1

    frames=totals["frames"]
    totals["bad_ratio"]=totals["bad"]/frames if frames else 0.0
    totals["failure_ratio"]=totals["failures"]/frames if frames else 0.0
    totals["concealed_ratio"]=totals["concealed"]/frames if frames else 0.0
    totals["muted_ratio"]=totals["muted"]/frames if frames else 0.0
    for rr in routes.values():
        f=rr["frames"]
        rr["bad_ratio"]=rr["bad"]/f if f else 0.0
        rr["failure_ratio"]=rr["failures"]/f if f else 0.0
        rr["muted_ratio"]=rr["muted"]/f if f else 0.0
        rr["degraded"]=bool(f>=100 and (rr["failure_ratio"]>=0.02 or rr["bad_ratio"]>=0.10 or rr["severe_streams"]>=1))
        if rr["codec"] == "2->1":
            rr["meaning"]="AMBE2 -> AMBE (tipicamente DMR/YSF para D-STAR)"
        elif rr["codec"] == "1->2":
            rr["meaning"]="AMBE -> AMBE2 (tipicamente D-STAR para DMR/YSF)"
        else:
            rr["meaning"]="rota de codec observada"
    totals["routes"]=routes
    totals["version"]="TRANSCODER_HEALTH_V2"
    return totals

def crossmode_peer_health(interlink=None, transcoder=None):
    interlink = interlink if isinstance(interlink, dict) else interlink_health(5)
    transcoder = transcoder if isinstance(transcoder, dict) else parse_unified_voice(15)
    service_active = systemd_active("xlx-unified-voice.service")
    frames = int(transcoder.get("frames", 0) or 0)
    failure_ratio = float(transcoder.get("failure_ratio", 0) or 0)
    bad_ratio = float(transcoder.get("bad_ratio", 0) or 0)
    degraded = bool(
        service_active and frames >= 100 and (
            failure_ratio >= 0.02 or bad_ratio >= 0.10 or int(transcoder.get("severe_streams",0) or 0) >= 3
        )
    )
    if not service_active:
        cross_state, cross_label = "failure", "FALHA"
    elif degraded:
        cross_state, cross_label = "degraded", "ATENÇÃO"
    else:
        cross_state, cross_label = "ok", "OK"
    peer_state = str(interlink.get("state", "not_configured"))
    peer_label = str(interlink.get("state_label", "—"))
    overall_ok = cross_state == "ok" and bool(interlink.get("ok", True))
    return {
        "ok": overall_ok,
        "crossmode": {
            "state": cross_state,
            "label": cross_label,
            "service_active": service_active,
            "frames": frames,
            "failure_ratio": failure_ratio,
            "bad_ratio": bad_ratio,
            "streams_open": int(transcoder.get("streams_open",0) or 0),
            "streams_close": int(transcoder.get("streams_close",0) or 0),
        },
        "peer": {
            "state": peer_state,
            "label": peer_label,
            "configured": int(interlink.get("configured",0) or 0),
            "ack": int(interlink.get("ack",0) or 0),
            "nack": int(interlink.get("nack",0) or 0),
            "attempts": int(interlink.get("connect_attempts",0) or 0),
        },
        "detail": f"CrossMode={cross_label}; Interlink={peer_label}",
    }

def capability_matrix_v2(ysf, dstar, dmr, streams, data_health):
    """CAPABILITY_MATRIX_V2: separa suportado, configurado, observado e validado."""
    sp=streams.get("protocols",{}) if isinstance(streams,dict) else {}
    dhp=data_health.get("pipelines",{}) if isinstance(data_health,dict) else {}
    yobs=((ysf.get("observed_modes",{}) or {}).get("modes",{}) if isinstance(ysf,dict) else {})
    dmr_emb=(dmr.get("embedded_monitor",{}) or {}) if isinstance(dmr,dict) else {}

    items={
        "YSF_DN_VD2": {
            "protocol":"YSF/C4FM","feature":"Voz DN / VD Mode 2",
            "supported":bool((ysf.get("voice",{}) or {}).get("dn_vd_mode2",False)),
            "configured":bool(ysf.get("listener",False)),
            "observed":int(((yobs.get("2",{}) or {}).get("frames",0) or 0))>0,
            "validated":bool((sp.get("C4FM/YSF",{}) or {}).get("activity_seen_24h",False)),
        },
        "YSF_WIRESX": {
            "protocol":"YSF/C4FM","feature":"Wires-X commands",
            "supported":bool((ysf.get("wires_x",{}) or {}).get("supported",False)),
            "configured":bool(ysf.get("listener",False)),
            "observed":int(((yobs.get("1",{}) or {}).get("frames",0) or 0))>0,
            "validated":bool((ysf.get("wires_x",{}) or {}).get("supported",False) and ysf.get("listener",False)),
        },
        "YSF_GPS": {
            "protocol":"YSF/C4FM","feature":"GPS YSF por sidecar",
            "supported":bool((ysf.get("data",{}) or {}).get("gps_rx_extract",False)),
            "configured":bool((((ysf.get("data",{}) or {}).get("gps_rx_sidecar",{}) or {}).get("active",False))),
            "observed":int(((dhp.get("ysf_data",{}) or {}).get("event_count",0) or 0))>0,
            "validated":str((dhp.get("ysf_data",{}) or {}).get("state",""))=="ok",
        },
        "DMR_GROUP_VOICE": {
            "protocol":"DMR","feature":"Group Call",
            "supported":bool((dmr.get("voice",{}) or {}).get("group_call",False)),
            "configured":all(bool((x or {}).get("active",False)) for x in (dmr.get("listeners",{}) or {}).values()),
            "observed":int((sp.get("DMR",{}) or {}).get("tx_24h",0) or 0)>0,
            "validated":bool(((sp.get("DMR",{}) or {}).get("lifecycle_1h",{}) or {}).get("ok",True)),
        },
        "DMR_TA_RX": {
            "protocol":"DMR","feature":"Talker Alias RX passivo",
            "supported":bool(dmr_emb.get("sidecar",False)),
            "configured":bool(dmr_emb.get("active",False)),
            "observed":int(dmr_emb.get("ta_complete",0) or 0)>0,
            "validated":str(dmr_emb.get("state",""))=="validated",
        },
        "DMR_GPS_RX": {
            "protocol":"DMR","feature":"GPS DMR RX passivo",
            "supported":bool(dmr_emb.get("sidecar",False)),
            "configured":bool(dmr_emb.get("active",False)),
            "observed":int(dmr_emb.get("gps",0) or 0)>0,
            "validated":str(dmr_emb.get("state",""))=="validated",
        },
        "DSTAR_DV": {
            "protocol":"D-STAR","feature":"DV DPlus/DExtra/DCS",
            "supported":bool(dstar.get("dv_voice",False)),
            "configured":all(bool((x or {}).get("active",False)) for x in (dstar.get("listeners",{}) or {}).values()),
            "observed":int((sp.get("D-STAR",{}) or {}).get("tx_24h",0) or 0)>0,
            "validated":bool(((sp.get("D-STAR",{}) or {}).get("lifecycle_1h",{}) or {}).get("ok",True)),
        },
        "DSTAR_DPRS": {
            "protocol":"D-STAR","feature":"D-PRS/GPS",
            "supported":bool((dstar.get("dprs_gps",{}) or {}).get("decode",False)),
            "configured":bool((dstar.get("dprs_gps",{}) or {}).get("decode",False)),
            "observed":int((dhp.get("digital_lab",{}) or {}).get("events",0) or 0)>0,
            "validated":str((dhp.get("aprs_dprs",{}) or {}).get("state",""))=="ok",
        },
    }
    summary={}
    for proto in ("YSF/C4FM","DMR","D-STAR"):
        rows=[v for v in items.values() if v["protocol"]==proto]
        summary[proto]={k:sum(1 for r in rows if r[k]) for k in ("supported","configured","observed","validated")}
        summary[proto]["total"]=len(rows)
    return {"version":"CAPABILITY_MATRIX_V2","legend":{"supported":"recurso existe no código/arquitetura","configured":"está habilitado no XLX Modern","observed":"tráfego/dado real foi visto","validated":"há evidência operacional suficiente para considerar funcional"},"items":items,"summary":summary}

def _last_jsonl_record(directory):
    try:
        files = sorted(directory.glob("*.jsonl"))
        if not files:
            return {}
        path = files[-1]
        with path.open("rb") as f:
            f.seek(0, os.SEEK_END)
            size = f.tell()
            if size <= 0:
                return {}
            step = min(size, 65536)
            f.seek(-step, os.SEEK_END)
            chunk = f.read().decode("utf-8", errors="replace")
        lines = [x for x in chunk.splitlines() if x.strip()]
        return json.loads(lines[-1]) if lines else {}
    except Exception:
        return {}

def _connected_total(snapshot):
    protocols = (snapshot.get("stream_health", {}) or {}).get("protocols", {})
    if not isinstance(protocols, dict):
        return 0
    return sum(int((row or {}).get("connected_now", 0) or 0) for row in protocols.values() if isinstance(row, dict))

def _flight_incident(snapshot, previous):
    if not isinstance(previous, dict) or not previous:
        return None
    now_x = snapshot.get("xlxd", {}) or {}
    old_x = previous.get("xlxd", {}) or {}
    activity = snapshot.get("activity_15m", {}) or {}
    incidents = []

    old_pid = int(old_x.get("pid", 0) or 0)
    new_pid = int(now_x.get("pid", 0) or 0)
    if old_pid and new_pid and old_pid != new_pid:
        incidents.append(("critical", "xlxd_restart", "XLXD reiniciou", f"PID mudou de {old_pid} para {new_pid}", "reinício do processo XLXD"))
    elif not bool(now_x.get("ok", False)) and bool(old_x.get("ok", False)):
        incidents.append(("critical", "xlxd_down", "XLXD ficou indisponível", "processo/serviço deixou de ficar saudável", "falha do processo ou serviço"))

    old_total = _connected_total(previous)
    new_total = _connected_total(snapshot)
    drop = max(0, old_total - new_total)
    threshold = max(5, int(old_total * 0.20)) if old_total else 999999
    if drop >= threshold:
        keepalive = int(activity.get("keepalive_timeout", 0) or 0)
        same_pid = old_pid and new_pid and old_pid == new_pid
        if same_pid and bool(now_x.get("ok", False)) and keepalive > 0:
            cause = "provável perda de conectividade/UDP ou keepalive; XLXD permaneceu ativo"
        elif same_pid and bool(now_x.get("ok", False)):
            cause = "queda concentrada de clientes sem reinício do XLXD; investigar rede/NAT/caminho de protocolo"
        else:
            cause = "queda de clientes associada ao estado do XLXD"
        incidents.append(("warning", "mass_disconnect", "Queda concentrada de clientes", f"conectados {old_total}->{new_total}; queda={drop}; keepalive_15m={keepalive}", cause))

    inter = snapshot.get("interlink_5m", {}) or {}
    old_inter = previous.get("interlink_5m", {}) or {}
    state = str(inter.get("state", ""))
    old_state = str(old_inter.get("state", ""))
    if state in ("rejected", "waiting") and state != old_state:
        cause = "peer rejeitou a ligação" if state == "rejected" else "peer não respondeu ACK/NACK"
        incidents.append(("warning", "interlink", "Mudança no Interlink", str(inter.get("detail", "")), cause))

    tr = snapshot.get("transcoder_15m", {}) or {}
    old_tr = previous.get("transcoder_15m", {}) or {}
    if bool(tr.get("degraded", False)) and not bool(old_tr.get("degraded", False)):
        incidents.append(("warning", "transcoder", "Transcoder entrou em atenção", f"frames={tr.get('frames',0)} bad={tr.get('bad',0)} muted={tr.get('muted',0)} failures={tr.get('failures',0)}", "qualidade degradada detectada; correlacionar por direção/protocolo"))

    ch = snapshot.get("callinghome", {}) or {}
    old_ch = previous.get("callinghome", {}) or {}
    if not bool(ch.get("ok", False)) and bool(old_ch.get("ok", False)):
        incidents.append(("warning", "callinghome", "CallingHome falhou", f"result={ch.get('result','')} exit={ch.get('exit_code','')}", "falha na publicação/rotina CallingHome"))

    if not incidents:
        return None
    severity_order = {"info": 0, "warning": 1, "critical": 2}
    top = max(incidents, key=lambda x: severity_order.get(x[0], 0))
    categories = [x[1] for x in incidents]
    return {
        "ts": snapshot.get("generated_at") or snapshot.get("ts"),
        "severity": top[0],
        "category": "+".join(categories),
        "title": top[2] if len(incidents) == 1 else f"{len(incidents)} eventos correlacionados",
        "detail": " | ".join(x[3] for x in incidents),
        "probable_cause": " | ".join(dict.fromkeys(x[4] for x in incidents)),
        "evidence": {
            "xlxd_pid": new_pid,
            "connected_before": old_total,
            "connected_now": new_total,
            "keepalive_15m": int(activity.get("keepalive_timeout", 0) or 0),
            "interlink_state": state,
            "transcoder_degraded": bool(tr.get("degraded", False)),
        },
    }

def now_text():
    return datetime.now(TIMEZONE).strftime(
        "%d/%m/%Y às %H:%M:%S"
    )


def load_state():
    try:
        return json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except Exception:
        return {"checks": {}, "pending": [], "log_positions": {}}


def save_state(state):
    STATE_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
    temporary = STATE_FILE.with_suffix(".tmp")
    temporary.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")
    os.chmod(temporary, 0o600)
    os.replace(temporary, STATE_FILE)


def systemd_active(unit):
    try:
        result = subprocess.run(
            ["/usr/bin/systemctl", "is-active", "--quiet", unit],
            timeout=10,
            check=False,
        )
        return result.returncode == 0
    except Exception:
        return False


def udp_open_ports():
    found = set()
    for filename in ("/proc/net/udp", "/proc/net/udp6"):
        try:
            lines = Path(filename).read_text(encoding="ascii", errors="ignore").splitlines()[1:]
            for line in lines:
                parts = line.split()
                if len(parts) >= 4 and ":" in parts[1]:
                    found.add(int(parts[1].rsplit(":", 1)[1], 16))
        except Exception:
            continue
    return found


def check_default_route():
    try:
        result = subprocess.run(
            ["/usr/sbin/ip", "route", "show", "default"],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        return result.returncode == 0 and bool(result.stdout.strip())
    except Exception:
        return False


def check_dns():
    try:
        return bool(socket.getaddrinfo(DOMAIN,443,type=socket.SOCK_STREAM))
    except Exception:
        return False

def check_https():
    try:
        request=urllib.request.Request(PUBLIC_URL+'/',headers={'User-Agent':'XLX-Modern-Health/2.0'})
        with urllib.request.urlopen(request,timeout=20) as response:
            status=int(getattr(response,'status',200))
        return 200 <= status < 400, f'HTTP {status}'
    except urllib.error.HTTPError as error:
        return False, f'HTTP {error.code}'
    except Exception as error:
        return False, type(error).__name__

def certificate_days():
    try:
        context=ssl.create_default_context()
        with socket.create_connection((DOMAIN,443),timeout=15) as raw:
            with context.wrap_socket(raw,server_hostname=DOMAIN) as secure:
                certificate=secure.getpeercert()
        expires=ssl.cert_time_to_seconds(certificate['notAfter'])
        return int((expires-time.time())//86400)
    except Exception:
        return None

def file_age(path):
    try:
        return max(0, int(time.time() - Path(path).stat().st_mtime))
    except Exception:
        return None


def memory_metrics():
    values = {}
    try:
        for line in Path("/proc/meminfo").read_text().splitlines():
            key, value = line.split(":", 1)
            values[key] = int(value.strip().split()[0])
        total = values.get("MemTotal", 0)
        available = values.get("MemAvailable", 0)
        swap_total = values.get("SwapTotal", 0)
        swap_free = values.get("SwapFree", 0)
        ram_available_pct = (available * 100 / total) if total else 0
        swap_used_pct = ((swap_total - swap_free) * 100 / swap_total) if swap_total else 0
        return ram_available_pct, swap_used_pct
    except Exception:
        return 0, 100


def disk_used_percent():
    stats = os.statvfs("/")
    total = stats.f_blocks * stats.f_frsize
    available = stats.f_bavail * stats.f_frsize
    return ((total - available) * 100 / total) if total else 100



# ----------------------------------------------------------------------
# XLX Modern_OPERATIONAL_HEALTH_V1
# Camada operacional adicional.
# Somente leitura das fontes do sistema/XLXD.
# ----------------------------------------------------------------------

PROTOCOL_PORTS = {
    "D-Star DPlus": 20001,
    "D-Star DExtra": 30001,
    "D-Star DCS": 30051,
    "DMR MMDVM": 62030,
    "DMR+": 8880,
    "C4FM/YSF": 42000,
    "IMRS": 21110,
    "XLX Interlink": 10002,
    "AMBE": 10100,
    "XLX JSON": 10001,
    "Icom Terminal Presence": 12345,
    "Icom Terminal Request": 12346,
    "Terminal DV": 40000,
}


def systemctl_show(unit, properties):
    command = [
        "/usr/bin/systemctl",
        "show",
        unit,
    ]

    for name in properties:
        command.extend(["-p", name])

    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=12,
            check=False,
        )
    except Exception:
        return {}

    values = {}

    for line in result.stdout.splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key] = value.strip()

    return values


def recent_journal(unit, minutes=5):
    try:
        result = subprocess.run(
            [
                "/usr/bin/journalctl",
                "-u",
                unit,
                "--since",
                f"-{int(minutes)} minutes",
                "--no-pager",
                "-o",
                "cat",
            ],
            capture_output=True,
            text=True,
            timeout=15,
            check=False,
        )

        if result.returncode not in (0, 1):
            return ""

        return result.stdout[-500000:]

    except Exception:
        return ""


def effective_config_lines(path):
    try:
        lines = Path(path).read_text(
            encoding="utf-8",
            errors="replace",
        ).splitlines()
    except Exception:
        return []

    return [
        line.strip()
        for line in lines
        if line.strip() and not line.lstrip().startswith("#")
    ]


def process_health(unit, process_name=None):
    data = systemctl_show(
        unit,
        [
            "ActiveState",
            "SubState",
            "MainPID",
            "Result",
            "ExecMainStartTimestamp",
        ],
    )

    try:
        pid = int(data.get("MainPID", "0") or 0)
    except Exception:
        pid = 0

    alive = (
        data.get("ActiveState") == "active"
        and pid > 0
        and Path(f"/proc/{pid}").exists()
    )

    if alive and process_name:
        try:
            comm = Path(f"/proc/{pid}/comm").read_text().strip()
            alive = comm == process_name
        except Exception:
            alive = False

    return {
        "ok": alive,
        "pid": pid,
        "active": data.get("ActiveState", ""),
        "sub": data.get("SubState", ""),
        "result": data.get("Result", ""),
        "started": data.get("ExecMainStartTimestamp", ""),
    }


def protocol_activity(minutes=15):
    raw = recent_journal(
        "xlxd.service",
        minutes,
    )

    definitions = {
        "dmr": r"DMRmmdvm|DMRplus",
        "ysf": r"\bYSF\b|C4FM",
        "dstar": r"DPlus|DExtra|DCS|DStar|D-STAR",
        "imrs": r"\bIMRS\b",
        "interlink": r"XLX peer|XLX ack|XLX nack",
        "gatekeeper_block": r"Gatekeeper blocking",
        "keepalive_timeout": r"keepalive timeout",
        "new_client": r"New client ",
        "stream": r"stream|header",
    }

    result = {}

    for key, pattern in definitions.items():
        result[key] = len(
            re.findall(
                pattern,
                raw,
                flags=re.I,
            )
        )

    return result


def interlink_health(minutes=5):
    """INTERLINK_HEALTH_V2: configuração + resposta + diagnóstico local seguro."""
    configured_all = effective_config_lines("/xlxd/xlxd.interlink")
    remote = []
    local_entries = []

    for line in configured_all:
        parts = line.split()
        if len(parts) < 3:
            continue
        call, address, modules = parts[0].upper(), parts[1], parts[2].upper()
        item = {"callsign": call, "address": address, "modules": modules}
        if call == "ECHO" or address in ("127.0.0.1", "::1", "localhost"):
            local_entries.append(item)
        elif call.startswith("XLX"):
            remote.append(item)

    raw = recent_journal("xlxd.service", minutes)
    peers=[]; total_ack=0; total_nack=0; total_connect=0
    for item in remote:
        call = re.escape(item["callsign"])
        connect=len(re.findall(rf"Sending connect packet to XLX peer\s+{call}\b",raw,flags=re.I))
        ack=len(re.findall(rf"XLX ack packet from\s+{call}\b",raw,flags=re.I))
        nack=len(re.findall(rf"XLX nack packet from\s+{call}\b",raw,flags=re.I))
        address=item["address"]
        resolved=[]; resolve_ok=False; address_type="domain"
        try:
            socket.inet_pton(socket.AF_INET,address); address_type="ipv4"; resolved=[address]; resolve_ok=True
        except OSError:
            try:
                socket.inet_pton(socket.AF_INET6,address); address_type="ipv6"; resolved=[address]; resolve_ok=True
            except OSError:
                try:
                    resolved=sorted({x[4][0] for x in socket.getaddrinfo(address,10002,type=socket.SOCK_DGRAM)})
                    resolve_ok=bool(resolved)
                except Exception:
                    resolve_ok=False
        attempts_per_min=round(connect/max(1,minutes),2)
        if nack>0:
            state="rejected"; label="NACK"; ok=False; diagnosis="peer respondeu NACK; revisar reciprocidade, módulos e Gatekeeper remoto"
        elif ack>0:
            state="connected"; label="ACK"; ok=True; diagnosis="peer respondeu ACK; interlink operacional no período"
        elif connect>0:
            state="waiting"; label="AGUARDANDO"; ok=False
            diagnosis=("endereço não resolve" if not resolve_ok else "peer silencioso: sem ACK/NACK; verificar cadastro recíproco, UDP 10002/firewall, serviço remoto e endereço")
        else:
            state="idle"; label="SEM ATIVIDADE"; ok=True; diagnosis="sem tentativa no período; nenhuma falha confirmada"
        peer=dict(item)
        peer.update({
            "connect_attempts":connect,"attempts_per_minute":attempts_per_min,
            "ack":ack,"nack":nack,"ok":ok,"state":state,"state_label":label,
            "address_type":address_type,"resolve_ok":resolve_ok,"resolved":resolved,
            "response":"nack" if nack else ("ack" if ack else "none"),
            "reciprocity":"not_verifiable_locally","diagnosis":diagnosis,
        })
        peers.append(peer); total_connect+=connect; total_ack+=ack; total_nack+=nack

    gatekeeper=len(re.findall(r"Gatekeeper blocking",raw,flags=re.I))
    if not remote:
        ok=True; state="not_configured"; label="NÃO CONFIGURADO"; detail="nenhum interlink XLX remoto configurado"
    elif total_nack:
        ok=False; state="rejected"; label="NACK"; detail=f"{len(remote)} peer(s); NACK={total_nack}; ACK={total_ack}; tentativas={total_connect}"
    elif total_connect>0 and total_ack==0:
        ok=False; state="waiting"; label="AGUARDANDO"; detail=f"{len(remote)} peer(s); sem ACK/NACK; tentativas={total_connect}"
    else:
        ok=True; state="connected" if total_ack>0 else "idle"; label="ACK" if total_ack>0 else "SEM ATIVIDADE"; detail=f"{len(remote)} peer(s); NACK=0; ACK={total_ack}; tentativas={total_connect}"

    return {
        "ok":ok,"version":"INTERLINK_HEALTH_V2","state":state,"state_label":label,
        "configured":len(remote),"local_entries":len(local_entries),"peers":peers,
        "ack":total_ack,"nack":total_nack,"connect_attempts":total_connect,
        "gatekeeper_blocks":gatekeeper,"gatekeeper_role":"security_policy",
        "diagnostic_scope":"local_observation_no_remote_scan","detail":detail,
    }


def callinghome_runtime_health():
    timer_ok = systemd_active(
        "xlx-callinghome.timer"
    )

    data = systemctl_show(
        "xlx-callinghome.service",
        [
            "Result",
            "ExecMainStatus",
            "ExecMainStartTimestamp",
            "ExecMainExitTimestamp",
        ],
    )

    result = data.get("Result", "")

    exit_code = data.get(
        "ExecMainStatus",
        "",
    )

    service_ok = (
        result in ("success", "")
        and exit_code in ("0", "")
    )

    return {
        "ok": timer_ok and service_ok,
        "timer_active": timer_ok,
        "result": result,
        "exit_code": exit_code,
        "started": data.get(
            "ExecMainStartTimestamp",
            "",
        ),
        "finished": data.get(
            "ExecMainExitTimestamp",
            "",
        ),
    }


def database_file_health():
    candidates = [
        Path("/xlxd/users_db/users.db"),
        Path("/xlxd/users_db/dmrid.dat"),
        Path("/xlxd/users_db/users_base.csv"),
    ]

    files = []

    for path in candidates:
        try:
            stat = path.stat()
        except Exception:
            continue

        files.append({
            "path": str(path),
            "size": stat.st_size,
            "age_seconds": max(
                0,
                int(time.time() - stat.st_mtime),
            ),
        })

    return files


def radioid_data_health():
    csv = Path("/xlxd/users_db/users_base.csv")
    db = Path("/xlxd/users_db/users.db")
    timer = systemd_active("update_XLX_db.timer")
    items = {}
    now = time.time()

    for name, path in (("csv", csv), ("db", db)):
        try:
            st = path.stat()
            items[name] = {
                "path": str(path),
                "size": st.st_size,
                "age_seconds": max(0, int(now - st.st_mtime)),
                "ok": st.st_size > 1024 * 1024 and now - st.st_mtime <= 48 * 3600,
            }
        except Exception:
            items[name] = {"path": str(path), "size": 0, "age_seconds": None, "ok": False}

    ok = timer and all(v["ok"] for v in items.values())
    return {
        "ok": ok,
        "timer_active": timer,
        "csv": items["csv"],
        "db": items["db"],
        "legacy_dmrid_dat": {
            "path": "/xlxd/dmrid.dat",
            "role": "legacy_unreferenced",
            "health_critical": False,
        },
        "detail": "users_base.csv e users.db atualizados" if ok else "verificar atualização da base RadioID",
    }


# XLX Modern_IDENTITY_HEALTH_V1
def identity_health_summary():
    """IDENTITY_ENGINE_V2: proveniência + enriquecimento + evidência MMDVM."""
    try:
        data = dashboard_status(history24=True)
    except Exception as error:
        return {"ok": False, "version":"IDENTITY_ENGINE_V2", "detail": type(error).__name__}
    history=data.get("history",[]) if isinstance(data,dict) else []
    if not isinstance(history,list): history=[]

    metadata_by_call={}
    try:
        mp=Path("/var/lib/xlx-modern-dmr-meta/metadata.json")
        md=json.loads(mp.read_text(encoding="utf-8")) if mp.exists() else {}
        devices=md.get("devices",{}) if isinstance(md,dict) else {}
        if isinstance(devices,dict):
            for row in devices.values():
                if not isinstance(row,dict): continue
                c=str(row.get("callsign","") or "").strip().upper()
                if c: metadata_by_call.setdefault(c,[]).append(row)
    except Exception:
        metadata_by_call={}

    total=len(history); station=0; gateway_different=0; unsafe=0; exact=0; log_client=0
    enriched=0; dmr_rows=0; dmr_meta_rows=0; by_source={}; by_confidence={}; unique_calls=set(); dmr_calls=set()
    for item in history:
        if not isinstance(item,dict): continue
        source=str(item.get("identity_source","") or "none")
        conf=str(item.get("identity_confidence","") or "legacy")
        by_source[source]=by_source.get(source,0)+1; by_confidence[conf]=by_confidence.get(conf,0)+1
        if source.startswith("xlxd-station"): station+=1
        origin=str(item.get("origin_match",""))
        if origin=="exata": exact+=1
        if origin=="log-client": log_client+=1
        call=str(item.get("callsign","")).split()[0].upper()
        gateway=str(item.get("gateway","")).split()[0].upper()
        if call: unique_calls.add(call)
        if item.get("name") or item.get("location"): enriched+=1
        proto=str(item.get("protocol","") or "")
        if proto=="DMR":
            dmr_rows+=1
            if call: dmr_calls.add(call)
            if call in metadata_by_call: dmr_meta_rows+=1
        if call and gateway and call!=gateway:
            gateway_different+=1
            if not source.startswith("xlxd-station"): unsafe+=1
    coverage=(station*100.0/total) if total else 0.0
    enrichment=(enriched*100.0/total) if total else 0.0
    dmr_meta_cov=(dmr_meta_rows*100.0/dmr_rows) if dmr_rows else 0.0
    dmr_unique_meta=sum(1 for c in dmr_calls if c in metadata_by_call)
    low_conf=sum(v for k,v in by_confidence.items() if k not in ("station-strict","station"))
    return {
        "ok":unsafe==0,
        "version":"IDENTITY_ENGINE_V2",
        "history_24h":total,
        "unique_callsigns":len(unique_calls),
        "station_resolved":station,
        "station_coverage_pct":round(coverage,2),
        "gateway_different":gateway_different,
        "unsafe_gateway_different":unsafe,
        "origin_exact":exact,
        "origin_log_client":log_client,
        "radioid_enriched_rows":enriched,
        "radioid_enrichment_pct":round(enrichment,2),
        "dmr_rows":dmr_rows,
        "dmr_metadata_rows":dmr_meta_rows,
        "dmr_metadata_coverage_pct":round(dmr_meta_cov,2),
        "dmr_unique_callsigns":len(dmr_calls),
        "dmr_unique_with_metadata":dmr_unique_meta,
        "metadata_confidence":"self-declared complemento; nunca prova única",
        "low_confidence_rows":low_conf,
        "by_source":by_source,
        "by_confidence":by_confidence,
        "detail":f"{station}/{total} com STATION; gateway diferente={gateway_different}; sem prova={unsafe}; enriquecidos={enriched}; DMR+metadata={dmr_meta_rows}/{dmr_rows}",
    }


# XLX Modern_YSF_CAPABILITY_AUDIT_V1
def ysf_capability_health():
    mode_stats_file = Path('/var/lib/xlx-aprs-dprs/ysf-mode-stats.json')
    mode_observed = {
        'available': False,
        'age_seconds': None,
        'total_frames': 0,
        'modes': {},
    }
    try:
        if mode_stats_file.is_file():
            raw = json.loads(mode_stats_file.read_text(encoding='utf-8'))
            if isinstance(raw, dict):
                mode_observed['available'] = True
                mode_observed['total_frames'] = int(raw.get('total_frames') or 0)
                mode_observed['modes'] = raw.get('modes') if isinstance(raw.get('modes'), dict) else {}
                mode_observed['updated_at'] = str(raw.get('updated_at') or '')
                mode_observed['started_at'] = str(raw.get('started_at') or '')
                mode_observed['age_seconds'] = max(0, int(time.time() - mode_stats_file.stat().st_mtime))
    except Exception as exc:
        mode_observed['error'] = type(exc).__name__
    """Runtime + audited capability matrix for the active XLXD YSF build."""
    listener = 42000 in udp_open_ports()
    binary = Path("/xlxd/xlxd")
    try:
        blob = binary.read_bytes()
    except Exception:
        blob = b""

    wires_markers = (
        b"Wires-X DX_REQ command from",
        b"Wires-X ALL_REQ command from",
        b"Wires-X CONN_REQ command to link on module",
        b"Wires-X DISC_REQ command from",
    )
    wires_x = bool(blob) and all(x in blob for x in wires_markers)

    modules = []
    try:
        data = dashboard_status(history24=False)
        raw_modules = data.get("modules", {}) if isinstance(data, dict) else {}
        if isinstance(raw_modules, dict):
            modules = sorted(
                str(k).strip().upper()[:1]
                for k in raw_modules.keys()
                if re.fullmatch(r"[A-Z]", str(k).strip().upper()[:1])
            )
    except Exception:
        modules = []
    if not modules:
        modules = MODULE_LETTERS.copy()

    dg_map = {
        module: 10 + idx
        for idx, module in enumerate(modules)
    }

    return {
        "ok": listener and wires_x,
        "listener": listener,
        "port": 42000,
        "autolink_module": "C",
        "modules": modules,
        "dg_id": {
            "supported": True,
            "mapping": dg_map,
            "detail": ", ".join(f"{m}={v}" for m, v in dg_map.items()),
        },
        "wires_x": {
            "supported": wires_x,
            "commands": ["DX", "ALL", "SEARCH", "CONNECT", "DISCONNECT"] if wires_x else [],
        },
        "voice": {
            "dn_vd_mode2": True,
            "vw_voice_fr": False,
            "detail": "Core ativo aceita YSF VD Mode 2; Voice FR/VW não entra no fluxo DV atual",
        },
        "data": {
            "dw_data_fr": False,
            "gps_rx_extract_core": False,
            "gps_rx_extract": systemd_active("xlx-modern-ysf-data-monitor.service"),
            "gps_rx_sidecar": {
                "service": "xlx-modern-ysf-data-monitor.service",
                "active": systemd_active("xlx-modern-ysf-data-monitor.service"),
                "source": "YSF_GPS",
            },
            "detail": (
                "GPS YSF extraído pelo sidecar passivo; core XLXD permanece sem publicação nativa"
                if systemd_active("xlx-modern-ysf-data-monitor.service")
                else "GPS YSF não publicado; sidecar inativo"
            ),
        },
        "crossmode_safe": {
            "dn_vd_mode2": True,
            "vw_voice_fr": False,
            "dw_data_fr": False,
        },
        "observed_modes": mode_observed,
        "audit_version": "YSF_CAPABILITY_AUDIT_V2",
    }


# XLX Modern_DSTAR_CAPABILITY_AUDIT_V1
def dstar_capability_summary():
    ports = udp_open_ports()
    dprs_active = systemd_active("xlx-aprs-dprs.service")
    listeners = {
        "DPlus": {"port": 20001, "active": 20001 in ports},
        "DExtra": {"port": 30001, "active": 30001 in ports},
        "DCS": {"port": 30051, "active": 30051 in ports},
    }
    return {
        "ok": all(item["active"] for item in listeners.values()),
        "listeners": listeners,
        "modules": MODULE_LETTERS.copy(),
        "dv_voice": True,
        "slow_data": {
            "passthrough": True,
            "bytes_per_frame": 3,
            "protocols": ["DPlus", "DExtra", "DCS"],
            "detail": "DVDATA de 3 bytes preservado nos quadros DV nativos",
        },
        "dprs_gps": {
            "decode": dprs_active,
            "all_modules": dprs_active,
            "service": "xlx-aprs-dprs.service",
            "detail": "GPS-A/NMEA/D-PRS decodificado por coletor passivo em todos os módulos publicados",
        },
        "images": {
            "conventional_dv_transport": True,
            "live_validated": False,
            "dv_fast_data": False,
            "detail": "DV convencional preserva slow data; DV Fast Data não possui tratamento explícito no core e permanece não garantido",
        },
        "dd_mode": {
            "supported": False,
            "detail": "D-STAR DD/128 kbps não implementado no núcleo DV atual",
        },
        "link_control": {
            "server_dtmf_decode": False,
            "urcall_header_preserved": True,
            "detail": "URCALL é preservado; seleção por URCALL/DTMF é função do gateway/cliente, não um decoder DTMF do XLXD",
        },
        "peer_links": {
            "dextra": True,
            "dplus": True,
            "detail": "Peer linking, keepalive e reconnect presentes no core",
        },
        "audit_version": "DSTAR_CAPABILITY_AUDIT_V1",
    }


# XLX Modern_DMR_MMDVM_META_HEALTH_V1
def dmr_metadata_health():
    path = Path("/var/lib/xlx-modern-dmr-meta/metadata.json")
    active = systemd_active("xlx-dmr-meta-monitor.service")
    total = 0
    hotspots = 0
    repeater_candidates = 0
    latest = ""
    try:
        payload = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
        devices = payload.get("devices", {}) if isinstance(payload, dict) else {}
        if isinstance(devices, dict):
            total = len(devices)
            for row in devices.values():
                if not isinstance(row, dict): continue
                hint = str(row.get("declared_class_hint", ""))
                if hint == "hotspot": hotspots += 1
                elif hint == "repeater-candidate": repeater_candidates += 1
                seen = str(row.get("last_seen", ""))
                if seen > latest: latest = seen
    except Exception as error:
        read_error = type(error).__name__
    else:
        read_error = ""
    return {
        "active": active,
        "devices": total,
        "hotspot_hints": hotspots,
        "repeater_candidate_hints": repeater_candidates,
        "latest": latest,
        "confidence": "self-declared",
        "read_error": read_error,
        "detail": f"sidecar={'ativo' if active else 'inativo'}; equipamentos={total}; hotspot-hints={hotspots}; repeater-candidates={repeater_candidates}" + (f"; read_error={read_error}" if read_error else ""),
    }


# XLX Modern_DMR_DATA_HEALTH_V1
def dmr_data_health():
    path = Path("/var/lib/xlx-modern-dmr-data/state.json")
    active = systemd_active("xlx-dmr-data-monitor.service")
    data = {}
    read_error = ""
    try:
        data = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
        if not isinstance(data, dict): data = {}
    except Exception as error:
        read_error = type(error).__name__
        data = {}
    metrics = data.get("metrics", {}) if isinstance(data.get("metrics", {}), dict) else {}
    counters = data.get("counters", {}) if isinstance(data.get("counters", {}), dict) else {}
    gps_rows = data.get("gps", {}) if isinstance(data.get("gps", {}), dict) else {}
    ta_rows = data.get("talker_alias", {}) if isinstance(data.get("talker_alias", {}), dict) else {}
    dmrd = int(metrics.get("dmrd", 0) or 0)
    voice = int(metrics.get("voice", 0) or 0)
    valid = int(metrics.get("embedded_valid", 0) or 0)
    qr_ok = int(metrics.get("qr_ok", 0) or 0)
    qr_fail = int(metrics.get("qr_fail", 0) or 0)
    data_total = 0
    by_type = {}
    for name, row in counters.items():
        if not isinstance(row, dict): continue
        count = int(row.get("count", 0) or 0)
        by_type[str(name)] = {"count": count, "last_seen": str(row.get("last_seen", ""))}
        data_total += count
    if not active:
        state = "inactive"
    elif read_error:
        state = "read_error"
    elif valid > 0:
        state = "validated"
    elif dmrd == 0:
        state = "awaiting_traffic"
    elif voice > 0:
        state = "validating"
    else:
        state = "observing"
    labels = {"inactive":"inativo","read_error":"erro de leitura","awaiting_traffic":"aguardando tráfego","validating":"em validação","validated":"validado","observing":"observando"}
    dh = data.get("data_headers", {}) if isinstance(data.get("data_headers", {}), dict) else {}
    dhs = dh.get("stats", {}) if isinstance(dh.get("stats", {}), dict) else {}
    last_header = dh.get("last", {}) if isinstance(dh.get("last", {}), dict) else {}
    last_session = dh.get("last_session", {}) if isinstance(dh.get("last_session", {}), dict) else {}
    return {
        "active": active,
        "state": state,
        "state_label": labels.get(state, state),
        "generated_at": str(data.get("generated_at", "")),
        "dmrd": dmrd,
        "voice_bursts": voice,
        "embedded_valid": valid,
        "qr_ok": qr_ok,
        "qr_fail": qr_fail,
        "lcss": metrics.get("lcss", {}) if isinstance(metrics.get("lcss", {}), dict) else {},
        "flco": metrics.get("flco", {}) if isinstance(metrics.get("flco", {}), dict) else {},
        "gps": len(gps_rows),
        "ta_complete": len(ta_rows),
        "data_bursts": data_total,
        "by_type": by_type,
        "data_header_valid": int(dhs.get("valid", 0) or 0),
        "data_header_invalid": int(dhs.get("invalid", 0) or 0),
        "data_header_by_dpf": dhs.get("by_dpf", {}) if isinstance(dhs.get("by_dpf", {}), dict) else {},
        "data_header_by_udt_format": dhs.get("by_udt_format", {}) if isinstance(dhs.get("by_udt_format", {}), dict) else {},
        "last_data_header": last_header,
        "last_data_session": last_session,
        "read_error": read_error,
        "core_native": False,
        "sidecar": True,
        "implementation": "xlx-dmr-data-monitor",
        "detail": f"sidecar={'ativo' if active else 'inativo'}; estado={labels.get(state,state)}; voz={voice}; LC válido={valid}; QR ok/fail={qr_ok}/{qr_fail}; GPS={len(gps_rows)}; TA={len(ta_rows)}; dados={data_total}; headers={int(dhs.get('valid',0) or 0)}/{int(dhs.get('invalid',0) or 0)}" + (f"; read_error={read_error}" if read_error else ""),
    }


# XLX Modern_DMR_EMBEDDED_HEALTH_V1
def dmr_embedded_health():
    path = Path("/var/lib/xlx-modern-dmr-embedded/summary.json")
    active = systemd_active("xlx-dmr-embedded-monitor.service")
    data = {}
    read_error = ""
    try:
        data = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
        if not isinstance(data, dict): data = {}
    except Exception as error:
        read_error = type(error).__name__
        data = {}
    dmrd = int(data.get("dmrd", 0) or 0)
    voice = int(data.get("voice_bursts", 0) or 0)
    valid = int(data.get("embedded_valid", 0) or 0)
    normal = int(data.get("normal_lc", 0) or 0)
    gps = int(data.get("gps", 0) or 0)
    ta_blocks = int(data.get("ta_blocks", 0) or 0)
    ta_complete = int(data.get("ta_complete", 0) or 0)
    if not active:
        state = "inactive"
    elif read_error:
        state = "read_error"
    elif dmrd == 0:
        state = "awaiting_traffic"
    elif voice > 0 and valid == 0:
        state = "validating"
    elif valid > 0:
        state = "validated"
    else:
        state = "observing"
    labels = {"inactive":"inativo","read_error":"erro de leitura","awaiting_traffic":"aguardando tráfego","validating":"em validação","validated":"validado","observing":"observando"}
    return {
        "active": active, "state": state, "state_label": labels.get(state,state),
        "generated_at": str(data.get("generated_at", "")), "dmrd": dmrd, "voice_bursts": voice,
        "lcss": data.get("lcss", {}) if isinstance(data.get("lcss", {}), dict) else {},
        "embedded_valid": valid, "normal_lc": normal, "gps": gps,
        "ta_blocks": ta_blocks, "ta_complete": ta_complete, "read_error": read_error,
        "core_native": False, "sidecar": True,
        "detail": f"sidecar={'ativo' if active else 'inativo'}; estado={labels.get(state,state)}; voz={voice}; LC válido={valid}; GPS={gps}; TA={ta_complete}" + (f"; read_error={read_error}" if read_error else ""),
    }


# XLX Modern_DMR_CAPABILITY_AUDIT_V1
def dmr_capability_summary():
    ports = udp_open_ports()
    mmdvm = 62030 in ports
    dmrplus = 8880 in ports
    aprs_bridge = systemd_active("xlx-aprs-dprs.service")
    return {
        "ok": mmdvm and dmrplus,
        "listeners": {
            "MMDVM": {"port": 62030, "active": mmdvm},
            "DMRPlus": {"port": 8880, "active": dmrplus},
        },
        "radio": {"slot": 2, "color_code": 1},
        "tg_module": {
            "mapping": {"A": 4001, "B": 4002, "C": 4003, "D": 4004, "E": 4005},
            "unlink": 4000,
            "detail": "TG 4001-4005 selecionam A-E; TG 4000 desconecta",
        },
        "voice": {
            "group_call": True,
            "private_call_parsed": True,
            "private_call_forwarded": False,
            "detail": "Streams do refletor são abertos apenas para Group Call",
        },
        "talker_alias": {
            "active": False,
            "candidate_validated": True,
            "scope": "módulo C",
            "detail": "Patch candidato existe, mas não está no binário XLXD ativo; ativação exigiria troca de binário/restart",
        },
        "embedded_monitor": dmr_data_health(),
        "data_monitor": dmr_data_health(),
        "native_data": {
            "data_types_known": ["CSBK", "DATA_HEADER", "RATE_1/2", "RATE_3/4", "RATE_1"],
            "sms_decode": False,
            "gps_decode": False,
            "csbk_service": False,
            "generic_data_forward": False,
            "detail": "Constantes existem no core comum; adaptador DMRmmdvm ativo não decodifica blocos de dados como serviço",
        },
        "aprs": {
            "external_bridge": aprs_bridge,
            "detail": "APRS de apps como Z3DMR é acompanhado via APRS-IS; não é decodificação nativa do payload DMR",
        },
        "mmdvm_config": {
            "rptc_length": 302,
            "core_parses_metadata": False,
            "passive_capture_possible": True,
            "passive_monitor": dmr_metadata_health(),
            "confidence": "self-declared",
            "fields": ["callsign", "rx_frequency", "tx_frequency", "power", "color_code", "latitude", "longitude", "height", "location", "description", "slots", "url", "version", "software"],
            "detail": "RPTC contém metadados autodeclarados do MMDVM; usar como complemento, nunca como prova única de repetidora",
        },
        "audit_version": "DMR_CAPABILITY_AUDIT_V1",
    }


# XLX Modern_STREAM_HEALTH_V1
def stream_health_summary():
    """STREAM_HEALTH_V2: infraestrutura + ciclo real observado dos streams."""
    try:
        data = dashboard_status(history24=True)
    except Exception as error:
        return {"ok": False, "version": "STREAM_HEALTH_V2.2", "detail": type(error).__name__, "protocols": {}}

    history = data.get("history", []) if isinstance(data, dict) else []
    connections = data.get("connections", []) if isinstance(data, dict) else []
    if not isinstance(history, list): history=[]
    if not isinstance(connections, list): connections=[]

    now=int(time.time())
    recent_cutoff=now-3600
    definitions={
        "DMR": {"match": ("DMR",), "ports": (62030,8880)},
        "C4FM/YSF": {"match": ("C4FM/YSF","C4FM ou DMR"), "ports": (42000,)},
        "D-STAR": {"prefix": "D-STAR/", "ports": (20001,30001,30051)},
        "IMRS": {"match": ("IMRS",), "ports": (21110,)},
    }
    open_ports=udp_open_ports()
    result={}
    overall_lifecycle_ok=True
    for label,rule in definitions.items():
        def matches(proto):
            proto=str(proto or "")
            if "prefix" in rule and proto.startswith(rule["prefix"]): return True
            return proto in rule.get("match",())
        tx=[x for x in history if isinstance(x,dict) and matches(x.get("protocol"))]
        clients=[x for x in connections if isinstance(x,dict) and matches(x.get("protocol"))]
        recent=[x for x in tx if int(x.get("started_at",0) or 0) >= recent_cutoff]
        last=max((int(x.get("started_at",0) or 0) for x in tx),default=0)
        ports_ok=all(port in open_ports for port in rule["ports"])

        ended=0; active=0; invalid_time=0; zero_duration=0; ids={}; id_windows={}
        for row in recent:
            started=int(row.get("started_at",0) or 0)
            ended_at=int(row.get("ended_at",0) or 0)
            state=str(row.get("state","") or "")
            duration=int(row.get("duration",0) or 0)
            sid=str(row.get("stream_id","") or "")
            if state == "ended" or ended_at:
                ended += 1
            else:
                active += 1
            if ended_at and started and ended_at < started:
                invalid_time += 1
            if ended_at and started and duration <= 0:
                zero_duration += 1
            if sid:
                ids[sid]=ids.get(sid,0)+1
                id_windows.setdefault(sid,[]).append((started,ended_at or now))
        reused={sid:count for sid,count in ids.items() if count>1}
        overlapping={}
        for sid,windows in id_windows.items():
            ordered=sorted(windows)
            collisions=0
            for pos,(start,end) in enumerate(ordered):
                if any(start <= previous_end for _,previous_end in ordered[:pos]):
                    collisions += 1
            if collisions:
                overlapping[sid]=collisions
        reuse_is_suspicious = label in ("DMR", "C4FM/YSF") and bool(overlapping)
        lifecycle_ok=(invalid_time==0 and not reuse_is_suspicious)
        overall_lifecycle_ok = overall_lifecycle_ok and lifecycle_ok
        result[label]={
            "listener_ok": ports_ok,
            "ports": list(rule["ports"]),
            "connected_now": len(clients),
            "tx_24h": len(tx),
            "last_tx_at": last,
            "last_tx_age_seconds": (max(0,now-last) if last else None),
            "activity_seen_24h": bool(tx),
            "status": "active" if tx or clients else ("ready" if ports_ok else "down"),
            "lifecycle_1h": {
                "observed": len(recent),
                "ended": ended,
                "active": active,
                "invalid_time": invalid_time,
                "zero_duration": zero_duration,
                "unique_stream_ids": len(ids),
                "reused_stream_ids": reused,
                "overlapping_stream_ids": overlapping,
                "reuse_suspicious": reuse_is_suspicious,
                "reuse_policy": "reuso sequencial: informativo; sobreposição DMR/YSF: alertar",
                "ok": lifecycle_ok,
            },
        }
    infra_ok=all(x["listener_ok"] for x in result.values())
    return {
        "ok": infra_ok and overall_lifecycle_ok,
        "version": "STREAM_HEALTH_V2.2",
        "evidence_source": "api/status history + listeners",
        "end_to_end_test": False,
        "protocols": result,
        "lifecycle_ok": overall_lifecycle_ok,
        "detail": "; ".join(
            f"{name}: {item['connected_now']} cliente(s), {item['tx_24h']} TX/24h, ciclo1h={item['lifecycle_1h']['observed']}"
            for name,item in result.items()
        ),
    }



# XLX Modern_DATA_HEALTH_V1
def data_health_summary():
    now = time.time()

    def file_age(path):
        p = Path(path)
        if not p.exists():
            return None
        try:
            return max(0, int(now - p.stat().st_mtime))
        except Exception:
            return None

    def service_row(unit, path=None, heartbeat=False):
        active = systemd_active(unit)
        age = file_age(path) if path else None
        readable = bool(path and Path(path).is_file() and os.access(path, os.R_OK)) if path else True
        if not active:
            state = "failure"
            label = "FALHA"
        elif path and not readable:
            state = "warning"
            label = "ATENÇÃO"
        elif heartbeat and age is not None and age > 180:
            state = "warning"
            label = "ATENÇÃO"
        else:
            state = "ok"
            label = "OK"
        return {
            "active": active,
            "readable": readable,
            "age_seconds": age,
            "state": state,
            "label": label,
        }

    dmr_data = service_row(
        "xlx-dmr-data-monitor.service",
        "/var/lib/xlx-modern-dmr-data/state.json",
        False,
    )
    try:
        d = dmr_data_health()
        dmr_data.update({
            "state_detail": d.get("state_label", ""),
            "dmrd": int(d.get("dmrd", 0) or 0),
            "gps": int(d.get("gps", 0) or 0),
            "talker_alias": int(d.get("ta_complete", 0) or 0),
        })
    except Exception as error:
        dmr_data["read_error"] = type(error).__name__
        if dmr_data["active"]:
            dmr_data["state"] = "warning"
            dmr_data["label"] = "ATENÇÃO"

    dmr_meta = service_row(
        "xlx-dmr-meta-monitor.service",
        "/var/lib/xlx-modern-dmr-meta/metadata.json",
        False,
    )
    try:
        m = dmr_metadata_health()
        dmr_meta.update({
            "devices": int(m.get("devices", 0) or 0),
            "latest": str(m.get("latest", "")),
            "confidence": str(m.get("confidence", "self-declared")),
        })
    except Exception as error:
        dmr_meta["read_error"] = type(error).__name__

    aprs = service_row(
        "xlx-aprs-dprs.service",
        "/var/lib/xlx-aprs-dprs/public.json",
        True,
    )
    try:
        payload = json.loads(
            Path("/var/lib/xlx-aprs-dprs/public.json").read_text(encoding="utf-8")
        )
        status = payload.get("status", {}) if isinstance(payload, dict) else {}
        ai = status.get("aprs_is", {}) if isinstance(status, dict) else {}
        aprs.update({
            "gateway": str(status.get("gateway", "")) if isinstance(status, dict) else "",
            "aprs_is": str(ai.get("state", "")) if isinstance(ai, dict) else "",
            "tx_enabled": bool(ai.get("tx_enabled", False)) if isinstance(ai, dict) else False,
            "generated_at": str(payload.get("generated_at", "")) if isinstance(payload, dict) else "",
        })
    except Exception as error:
        aprs["read_error"] = type(error).__name__
        if aprs["active"]:
            aprs["state"] = "warning"
            aprs["label"] = "ATENÇÃO"

    ysf = {
        "active": systemd_active("xlx-modern-ysf-data-monitor.service"),
        "state": "ok",
        "label": "OK",
        "latest_event": "",
        "event_count": 0,
        "detail": "monitor ativo; aguardando dados YSF" ,
    }
    if not ysf["active"]:
        ysf["state"] = "failure"
        ysf["label"] = "FALHA"
        ysf["detail"] = "monitor inativo"
    else:
        try:
            import sqlite3
            db = sqlite3.connect(
                "file:/var/lib/xlx-aprs-dprs/digital-lab.sqlite?mode=ro",
                uri=True,
                timeout=1.5,
            )
            row = db.execute(
                "SELECT COUNT(*),COALESCE(MAX(ts),'') FROM events "
                "WHERE source LIKE 'YSF%' OR detail LIKE '%YSF%'"
            ).fetchone()
            db.close()
            ysf["event_count"] = int(row[0] or 0)
            ysf["latest_event"] = str(row[1] or "")
            if ysf["event_count"] > 0:
                ysf["detail"] = f"monitor ativo; eventos YSF={ysf['event_count']}; último={ysf['latest_event']}"
        except Exception as error:
            ysf["state"] = "warning"
            ysf["label"] = "ATENÇÃO"
            ysf["read_error"] = type(error).__name__
            ysf["detail"] = f"monitor ativo; banco indisponível: {type(error).__name__}"

    digital_lab = {
        "readable": False,
        "state": "warning",
        "label": "ATENÇÃO",
        "stations": 0,
        "events": 0,
    }
    try:
        import sqlite3
        db = sqlite3.connect(
            "file:/var/lib/xlx-aprs-dprs/digital-lab.sqlite?mode=ro",
            uri=True,
            timeout=1.5,
        )
        digital_lab["stations"] = int(db.execute("SELECT COUNT(*) FROM stations").fetchone()[0])
        digital_lab["events"] = int(db.execute("SELECT COUNT(*) FROM events").fetchone()[0])
        db.close()
        digital_lab.update({"readable": True, "state": "ok", "label": "OK"})
    except Exception as error:
        digital_lab["read_error"] = type(error).__name__

    history = {
        "timer_active": systemd_active("xlx-modern-history-collector.timer"),
        "readable": False,
        "rows": 0,
        "coverage_since": 0,
        "state": "warning",
        "label": "ATENÇÃO",
    }
    try:
        import sqlite3
        hp = Path("/var/lib/xlx-modern-history/history.sqlite")
        if hp.is_file() and os.access(hp, os.R_OK):
            db = sqlite3.connect(
                "file:/var/lib/xlx-modern-history/history.sqlite?mode=ro&immutable=1",
                uri=True,
                timeout=1.5,
            )
            history["rows"] = int(db.execute("SELECT COUNT(*) FROM history").fetchone()[0])
            history["coverage_since"] = int(db.execute("SELECT COALESCE(MIN(started_at),0) FROM history").fetchone()[0])
            db.close()
            history["readable"] = True
    except Exception as error:
        history["read_error"] = type(error).__name__
    if history["timer_active"] and history["readable"]:
        history["state"] = "ok"
        history["label"] = "OK"
    elif not history["timer_active"]:
        history["state"] = "failure"
        history["label"] = "FALHA"

    pipelines = {
        "dmr_data": dmr_data,
        "dmr_meta": dmr_meta,
        "ysf_data": ysf,
        "aprs_dprs": aprs,
        "digital_lab": digital_lab,
        "history": history,
    }
    failures = [name for name,row in pipelines.items() if row.get("state") == "failure"]
    warnings = [name for name,row in pipelines.items() if row.get("state") == "warning"]
    ok = not failures
    state = "failure" if failures else ("warning" if warnings else "ok")
    return {
        "ok": ok,
        "state": state,
        "label": "FALHA" if failures else ("ATENÇÃO" if warnings else "OK"),
        "failures": failures,
        "warnings": warnings,
        "pipelines": pipelines,
        "detail": (
            f"pipelines={len(pipelines)}; falhas={len(failures)}; avisos={len(warnings)}"
        ),
    }



# XLX Modern_INTERLINK_HEALTH_V1
def build_operational_snapshot(checks):
    xlxd = process_health(
        "xlxd.service",
        "xlxd",
    )

    voice = parse_unified_voice(15)
    activity = protocol_activity(15)
    interlink = interlink_health(5)
    callinghome = callinghome_runtime_health()
    streams = stream_health_summary()
    ysf = ysf_capability_health()
    dstar = dstar_capability_summary()
    dmr = dmr_capability_summary()
    data_health = data_health_summary()
    open_ports = udp_open_ports()

    protocol_ports = {}

    for label, port in PROTOCOL_PORTS.items():
        protocol_ports[label] = {
            "port": port,
            "listener": port in open_ports,
        }

    voice_active = systemd_active(
        "xlx-unified-voice.service"
    )

    voice_degraded = (
        voice_active
        and voice["frames"] >= 100
        and (
            voice["failure_ratio"] >= 0.02
            or voice["bad_ratio"] >= 0.10
            or voice["severe_streams"] >= 3
        )
    )

    return {
        "schema": 1,
        "version": OPERATIONAL_VERSION,
        "generated_at": datetime.now(
            TIMEZONE
        ).isoformat(),
        "xlxd": xlxd,
        "protocol_ports": protocol_ports,
        "activity_15m": activity,
        "interlink_5m": interlink,
        "callinghome": callinghome,
        "transcoder_15m": {
            **voice,
            "service_active": voice_active,
            "degraded": voice_degraded,
        },
        "crossmode_peer_health": crossmode_peer_health(interlink, voice),
        "database_files": database_file_health(),
        "radioid_data": radioid_data_health(),
        "identity_health": identity_health_summary(),
        "stream_health": streams,
        "ysf_capabilities": ysf,
        "dstar_capabilities": dstar,
        "dmr_capabilities": dmr,
        "dmr_metadata": dmr_metadata_health(),
        "data_health": data_health,
        "capability_matrix": capability_matrix_v2(ysf, dstar, dmr, streams, data_health),
        "flight_recorder": flight_recorder_status(),
        "checks": {
            key: {
                "ok": bool(value.get("ok")),
                "label": str(
                    value.get("label", "")
                ),
                "detail": str(
                    value.get("detail", "")
                ),
            }
            for key, value in checks.items()
        },
    }

def save_flight_snapshot(snapshot):
    """FLIGHT_RECORDER_V2: snapshot + correlação de incidentes por transição."""
    FLIGHT_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
    FLIGHT_INCIDENT_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
    now = datetime.now(TIMEZONE)
    previous = _last_jsonl_record(FLIGHT_DIR)
    path = FLIGHT_DIR / f"{now.date().isoformat()}.jsonl"
    data = {
        "ts": snapshot.get("generated_at"),
        "xlxd": snapshot.get("xlxd", {}),
        "activity_15m": snapshot.get("activity_15m", {}),
        "interlink_5m": snapshot.get("interlink_5m", {}),
        "callinghome": snapshot.get("callinghome", {}),
        "transcoder_15m": snapshot.get("transcoder_15m", {}),
        "crossmode_peer_health": snapshot.get("crossmode_peer_health", {}),
        "stream_health": snapshot.get("stream_health", {}),
        "radioid_data": snapshot.get("radioid_data", {}),
    }
    incident = _flight_incident(data, previous)
    if incident:
        incident_path = FLIGHT_INCIDENT_DIR / f"{now.date().isoformat()}.jsonl"
        with incident_path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(incident, ensure_ascii=False, separators=(",", ":")) + "\n")
        os.chmod(incident_path, 0o600)
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(data, ensure_ascii=False, separators=(",", ":")) + "\n")
    os.chmod(path, 0o600)
    cutoff = now.date() - timedelta(days=FLIGHT_RETENTION_DAYS)
    for directory in (FLIGHT_DIR, FLIGHT_INCIDENT_DIR):
        for old_path in directory.glob("*.jsonl"):
            try:
                day = datetime.strptime(old_path.stem, "%Y-%m-%d").date()
                if day < cutoff:
                    old_path.unlink()
            except Exception:
                continue


def flight_recorder_status():
    try:
        files = sorted(FLIGHT_DIR.glob("*.jsonl"))
        incident_files = sorted(FLIGHT_INCIDENT_DIR.glob("*.jsonl"))
        total = sum(x.stat().st_size for x in files)
        incidents = 0
        for item in incident_files:
            with item.open("rb") as f:
                incidents += sum(1 for line in f if line.strip())
        latest_incident = _last_jsonl_record(FLIGHT_INCIDENT_DIR)
        return {
            "enabled": True,
            "version": "FLIGHT_RECORDER_V2",
            "retention_days": FLIGHT_RETENTION_DAYS,
            "files": len(files),
            "bytes": total,
            "latest": str(files[-1]) if files else "",
            "incidents": incidents,
            "latest_incident": latest_incident,
        }
    except Exception:
        return {"enabled": False, "version": "FLIGHT_RECORDER_V2", "retention_days": FLIGHT_RETENTION_DAYS}


def save_operational_snapshot(snapshot):
    STATE_DIR.mkdir(
        parents=True,
        exist_ok=True,
        mode=0o700,
    )

    temporary = OPERATIONAL_FILE.with_suffix(
        ".tmp"
    )

    temporary.write_text(
        json.dumps(
            snapshot,
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )

    os.chmod(
        temporary,
        0o600,
    )

    os.replace(
        temporary,
        OPERATIONAL_FILE,
    )

def collect_checks():
    checks = {}
    for label, unit in SERVICES.items():
        ok = systemd_active(unit)
        checks[f"service:{unit}"] = {
            "ok": ok,
            "label": label,
            "detail": "ativo" if ok else "INATIVO",
        }

    open_ports = udp_open_ports()
    missing = [port for port in UDP_PORTS if port not in open_ports]
    checks["udp_ports"] = {
        "ok": not missing,
        "label": "Portas UDP do XLXD",
        "detail": "todas abertas" if not missing else "ausentes: " + ", ".join(map(str, missing)),
    }

    route_ok = check_default_route()
    checks["default_route"] = {
        "ok": route_ok,
        "label": "Rota de internet",
        "detail": "presente" if route_ok else "não encontrada",
    }

    dns_ok = check_dns()
    checks["dns"] = {
        "ok": dns_ok,
        "label": f"DNS de {DOMAIN}",
        "detail": "respondeu" if dns_ok else "falhou",
    }

    https_ok, https_detail = check_https()
    checks["https"] = {
        "ok": https_ok,
        "label": "Painel HTTPS",
        "detail": https_detail,
    }

    days = certificate_days()
    checks["certificate"] = {
        "ok": days is not None and days >= 21,
        "label": "Certificado HTTPS",
        "detail": "consulta falhou" if days is None else f"vence em {days} dias",
    }

    xml_age = file_age("/var/log/xlxd.xml")
    checks["xlxd_xml"] = {
        "ok": xml_age is not None and xml_age <= 300,
        "label": "Atualização xlxd.xml",
        "detail": "arquivo ausente" if xml_age is None else f"há {xml_age}s",
    }

    callinghome = callinghome_runtime_health()
    checks["callinghome"] = {
        "ok": callinghome["ok"],
        "label": "CallingHome",
        "detail": (
            "timer ativo; última execução concluída"
            if callinghome["ok"]
            else (
                f"timer={'ativo' if callinghome['timer_active'] else 'inativo'}; "
                f"resultado={callinghome['result'] or 'desconhecido'}; "
                f"exit={callinghome['exit_code'] or 'desconhecido'}"
            )
        ),
    }

    disk = disk_used_percent()
    checks["disk"] = {
        "ok": disk < 85,
        "label": "Disco raiz",
        "detail": f"{disk:.1f}% usado",
    }

    ram_available, swap_used = memory_metrics()
    checks["ram"] = {
        "ok": ram_available >= 10,
        "label": "Memória RAM",
        "detail": f"{ram_available:.1f}% disponível",
    }
    checks["swap"] = {
        "ok": swap_used < 90,
        "label": "Swap",
        "detail": f"{swap_used:.1f}% usada",
    }

    load1 = os.getloadavg()[0]
    cpus = os.cpu_count() or 1
    load_limit = max(4.0, cpus * 2.0)
    checks["load"] = {
        "ok": load1 < load_limit,
        "label": "Carga do servidor",
        "detail": f"{load1:.2f} (limite {load_limit:.2f})",
    }

    # --------------------------------------------------------------
    # HEALTH OPERACIONAL V1
    # --------------------------------------------------------------

    xlxd_health = process_health(
        "xlxd.service",
        "xlxd",
    )

    checks["xlxd_process"] = {
        "ok": xlxd_health["ok"],
        "label": "Processo real do XLXD",
        "detail": (
            f"PID {xlxd_health['pid']} saudável"
            if xlxd_health["ok"]
            else "processo/PID não saudável"
        ),
    }

    for label, unit in (
        (
            "Gateway APRS/D-PRS",
            "xlx-aprs-dprs.service",
        ),
    ):
        active = systemd_active(unit)

        checks[f"operational_service:{unit}"] = {
            "ok": active,
            "label": label,
            "detail": (
                "ativo"
                if active
                else "INATIVO"
            ),
        }

    ports = udp_open_ports()

    for label, port in PROTOCOL_PORTS.items():
        present = port in ports

        checks[f"protocol_port:{port}"] = {
            "ok": present,
            "label": label,
            "detail": (
                "listener presente"
                if present
                else "listener AUSENTE"
            ),
        }

    interlink = interlink_health(5)

    checks["interlink_runtime"] = {
        "ok": interlink["ok"],
        "label": "XLX Interlink",
        "detail": interlink["detail"],
    }

    callinghome_runtime = callinghome_runtime_health()

    checks["callinghome_runtime"] = {
        "ok": callinghome_runtime["ok"],
        "label": "CallingHome execução",
        "detail": (
            "timer ativo e última execução válida"
            if callinghome_runtime["ok"]
            else
            "timer ou última execução com falha"
        ),
    }

    rid = radioid_data_health()
    checks["radioid_data"] = {
        "ok": rid["ok"],
        "label": "Base RadioID",
        "detail": rid["detail"],
    }

    identity = identity_health_summary()
    checks["identity_engine"] = {
        "ok": bool(identity.get("ok")),
        "label": "Identity Engine",
        "detail": str(identity.get("detail", "indisponível")),
    }

    ysf = ysf_capability_health()
    checks["ysf_capabilities"] = {
        "ok": bool(ysf.get("ok")),
        "label": "C4FM/YSF capabilities",
        "detail": f"DG-ID {ysf.get('dg_id',{}).get('detail','—')} · Wires-X {'OK' if ysf.get('wires_x',{}).get('supported') else 'não'} · DN/VD2 OK · VW/DW não habilitados",
    }

    streams = stream_health_summary()
    checks["stream_health"] = {
        "ok": bool(streams.get("ok")),
        "label": "Stream Health",
        "detail": str(streams.get("detail", "indisponível")),
    }

    dstar = dstar_capability_summary()
    checks["dstar_capabilities"] = {
        "ok": bool(dstar.get("ok")),
        "label": "D-STAR capabilities",
        "detail": "DPlus/DExtra/DCS ativos; slow data preservado; DV Fast Data e DD não garantidos",
    }

    dmr = dmr_capability_summary()
    checks["dmr_capabilities"] = {
        "ok": bool(dmr.get("ok")),
        "label": "DMR capabilities",
        "detail": "MMDVM/DMR+ ativos; TG 4001-4005; voz Group Call; TA e dados nativos ainda não ativos",
    }

    return checks


def scan_new_log_events(state):
    definitions = {
        "/var/log/nginx/error.log": re.compile(
            r"database is locked|SQLite3::(?:prepare|query)|segfault|out of memory",
            re.I,
        ),
        "/var/log/xlx.log": re.compile(
            r"segfault|fatal error|out of memory|cannot bind|address already in use",
            re.I,
        ),
    }
    events = []
    positions = state.setdefault("log_positions", {})

    for filename, pattern in definitions.items():
        path = Path(filename)
        try:
            size = path.stat().st_size
            previous = positions.get(filename)
            if previous is None:
                positions[filename] = size
                continue
            if previous > size:
                previous = 0
            with path.open("rb") as stream:
                stream.seek(previous)
                chunk = stream.read(1024 * 1024)
            positions[filename] = size
            for raw_line in chunk.splitlines():
                line = raw_line.decode("utf-8", errors="replace")
                if pattern.search(line):
                    clean = re.sub(r"\s+", " ", line).strip()
                    events.append(f"{path.name}: {clean[-300:]}")
        except Exception:
            continue
    return events[-8:]


def run_once(state):
    checks=collect_checks()
    snapshot=build_operational_snapshot(checks)
    save_operational_snapshot(snapshot)
    save_flight_snapshot(snapshot)
    bad=sum(1 for item in checks.values() if not item.get('ok'))
    print(f"[OK] checks={len(checks)} warnings_or_failures={bad}",flush=True)
    save_state(state)


def main():
    parser=argparse.ArgumentParser();parser.add_argument("--test",action="store_true");args=parser.parse_args()
    state=load_state()
    if args.test:
        run_once(state); raise SystemExit(0)
    while True:
        started=time.monotonic()
        try: run_once(state)
        except Exception as error: print(f"[ERROR] cycle: {type(error).__name__}: {error}",flush=True)
        elapsed=time.monotonic()-started
        time.sleep(max(5,INTERVAL-elapsed))


if __name__ == "__main__":
    main()
