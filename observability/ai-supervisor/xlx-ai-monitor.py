#!/usr/bin/env python3
"""Bounded connectivity probe; never controls radio or claims an AI analysis."""
import json
import os
import pathlib
import random
import tempfile
import time
import urllib.error
import urllib.request

STATE_DIR = pathlib.Path(os.environ.get('XLX_AI_STATE_DIR', '/run/xlx-ai-monitor'))
PUBLIC = STATE_DIR / 'public.json'
ACTION = STATE_DIR / 'last-action.json'
MODELS_URL = 'https://api.openai.com/v1/models'

def atomic_json(path, payload, mode=0o644):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=path.name+'.', dir=str(path.parent))
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            json.dump(payload, f, ensure_ascii=False, separators=(',', ':'))
            f.write('\n')
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)

def read_json(path):
    try:
        value = json.loads(path.read_text())
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError): return {}

def validate_key(key):
    """Retry transient failures once; never retry invalid credentials or 429."""
    for attempt in range(2):
        req = urllib.request.Request(MODELS_URL, headers={
            'Authorization': 'Bearer '+key,
            'User-Agent': 'XLX-Modern-OpenAI-Connectivity/2'})
        retry = True
        try:
            with urllib.request.urlopen(req, timeout=12) as response:
                if 200 <= response.status < 300:
                    return True, 'API OpenAI conectada; verificação de conectividade.', '', 0
                code = 'http_'+str(response.status)
        except urllib.error.HTTPError as exc:
            code = 'http_'+str(exc.code)
            retry = exc.code in (408, 409) or exc.code >= 500
            if exc.code in (401, 403):
                return False, 'Chave OpenAI recusada; confira a configuração privada.', code, 900
            if exc.code == 429:
                try: delay = max(120, min(86400, int(exc.headers.get('Retry-After', '900'))))
                except (ValueError, TypeError): delay = 900
                return False, 'Limite da API OpenAI; monitor local continua ativo.', code, delay
        except (TimeoutError, urllib.error.URLError, OSError):
            code = 'connection_timeout'
        if not retry: break
        if attempt == 0: time.sleep(1.5+random.random())
    return False, 'API OpenAI indisponível; monitor local continua ativo.', code, 120

def main():
    now = int(time.time())
    key = os.environ.get('OPENAI_API_KEY', '').strip()
    old = read_json(PUBLIC)
    action = read_json(ACTION)
    try: fresh = 0 <= now-int(action.get('at', 0)) <= 900
    except (TypeError, ValueError): fresh = False
    if not fresh or action.get('type') not in ('recommendation', 'ai_applied', 'analyzing'):
        action = None
    # A one-minute local timer recovers failures quickly without probing healthy
    # OpenAI every minute. Keep timestamps of observations, never refresh a lie.
    if key and now < int(old.get('next_probe_at', 0)):
        return 0
    connected, message, error, delay = validate_key(key) if key else (
        False, 'Monitor local ativo; API OpenAI não configurada.', '', 900)
    state = 'monitoring' if connected else ('error' if key else 'ready')
    if connected and action: state = action['type']
    atomic_json(PUBLIC, {
        'configured': bool(key), 'api_connected': connected, 'state': state,
        'message': message, 'updated_at': int(time.time()), 'last_action': action,
        'error_code': error, 'last_success_at': int(time.time()) if connected else old.get('last_success_at', 0),
        'next_probe_at': int(time.time())+(900 if connected else delay)})
    return 0 if connected or not key else 2

if __name__ == '__main__': raise SystemExit(main())
