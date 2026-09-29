#!/usr/bin/env python3
import json
import os
import pathlib
import tempfile
import time
import urllib.error
import urllib.request

STATE_DIR = pathlib.Path("/var/lib/xlx-ai-monitor")
PUBLIC = STATE_DIR / "public.json"
ACTION = STATE_DIR / "last-action.json"
MODELS_URL = "https://api.openai.com/v1/models"

ALLOWED_ACTIONS = {"recommendation", "ai_applied", "analyzing"}


def atomic_json(path: pathlib.Path, payload: dict, mode: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=path.name + ".", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, ensure_ascii=False, separators=(",", ":"))
            handle.write("\n")
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    finally:
        try:
            os.unlink(tmp)
        except FileNotFoundError:
            pass


def recent_action(now: int):
    try:
        raw = json.loads(ACTION.read_text(encoding="utf-8"))
    except Exception:
        return None
    if not isinstance(raw, dict):
        return None
    kind = str(raw.get("type", ""))
    at = int(raw.get("at", 0) or 0)
    if kind not in ALLOWED_ACTIONS or at <= 0 or abs(now - at) > 900:
        return None
    return {
        "type": kind,
        "message": str(raw.get("message", ""))[:120],
        "at": at,
    }


def validate_key(key: str):
    req = urllib.request.Request(
        MODELS_URL,
        headers={
            "Authorization": "Bearer " + key,
            "User-Agent": "XLX-Modern-AI-Monitor/1",
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=8) as response:
            ok = 200 <= int(response.status) < 300
            return ok, "IA conectada • monitoramento inteligente ativo" if ok else "Falha ao validar API"
    except urllib.error.HTTPError as exc:
        if exc.code in (401, 403):
            return False, "Chave OpenAI recusada"
        return False, "API OpenAI temporariamente indisponível"
    except Exception:
        return False, "Não foi possível validar a API OpenAI"


def main() -> int:
    now = int(time.time())
    key = os.environ.get("OPENAI_API_KEY", "").strip()
    action = recent_action(now)

    if not key:
        payload = {
            "configured": False,
            "api_connected": False,
            "state": "ready",
            "message": "Monitoramento local ativo • IA preparada",
            "updated_at": now,
            "last_action": action,
        }
        atomic_json(PUBLIC, payload, 0o644)
        return 0

    connected, message = validate_key(key)
    state = "monitoring" if connected else "error"

    if action and connected:
        state = action["type"]

    payload = {
        "configured": True,
        "api_connected": connected,
        "state": state,
        "message": message,
        "updated_at": now,
        "last_action": action,
    }
    atomic_json(PUBLIC, payload, 0o644)
    return 0 if connected else 2


if __name__ == "__main__":
    raise SystemExit(main())
