#!/usr/bin/env python3
"""Advisory TX Turn Guard monitor. Never participates in stream admission."""
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import time
import urllib.request

RUNTIME = pathlib.Path('/run/xlx-tx-turn-monitor')
STATE_DIR = pathlib.Path('/var/lib/xlx-tx-turn-monitor')
PUBLIC = RUNTIME / 'public.json'
STATE = STATE_DIR / 'state.json'
RESPONSES_URL = 'https://api.openai.com/v1/responses'
MODEL = os.environ.get('OPENAI_TX_TURN_MODEL', 'gpt-6-luna').strip() or 'gpt-6-luna'
AI_INTERVAL = 900
EVENT_RE = re.compile(r'^TXTURN event=(pair_detected|blocked|cooldown_started|third_party_break) module=([A-Z])(?:\s+.*)?$')


def atomic_json(path, payload, mode=0o644):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=path.name + '.', dir=str(path.parent))
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as handle:
            json.dump(payload, handle, ensure_ascii=False, separators=(',', ':'))
            handle.write('\n')
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    finally:
        try:
            os.unlink(tmp)
        except FileNotFoundError:
            pass


def read_events(lines):
    counts = {'pair_detected': 0, 'blocked': 0, 'cooldown_started': 0, 'third_party_break': 0}
    modules = set()
    for raw in lines:
        line = raw.strip()
        match = EVENT_RE.match(line)
        if not match:
            continue
        counts[match.group(1)] += 1
        modules.add(match.group(2))
    return counts, sorted(modules)


def journal_lines():
    try:
        proc = subprocess.run(
            ['journalctl', '-u', 'xlxd.service', '--since', '20 minutes ago', '-o', 'cat', '--no-pager'],
            capture_output=True, text=True, timeout=5, check=False,
        )
        if proc.returncode not in (0, 1):
            return []
        return proc.stdout.splitlines()
    except Exception:
        return []


def local_assessment(counts):
    detected = counts['pair_detected']
    blocked = counts['blocked']
    breaks = counts['third_party_break']
    if blocked >= 8 or detected >= 4:
        return 'elevated'
    if blocked >= 3 or detected >= 2:
        return 'watch'
    if breaks > 0 or detected > 0 or blocked > 0:
        return 'observed'
    return 'quiet'


def load_state():
    try:
        data = json.loads(STATE.read_text(encoding='utf-8'))
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def extract_output_text(data):
    texts = []
    for item in data.get('output', []) if isinstance(data, dict) else []:
        if not isinstance(item, dict):
            continue
        for content in item.get('content', []) or []:
            if isinstance(content, dict) and isinstance(content.get('text'), str):
                texts.append(content['text'].strip())
    return ' '.join(text for text in texts if text)[:320]


def ask_ai(telemetry, key):
    prompt = (
        'Você é um observador consultivo de disciplina de câmbio em um refletor XLX. '
        'A decisão de bloquear transmissão é determinística e local; você NUNCA decide liberação ou bloqueio. '
        'Receba apenas contadores técnicos agregados, sem áudio, voz, indicativos, RadioID, IP ou payload. '
        'Avalie se a frequência de detecções/bloqueios sugere comportamento ping-pong recorrente ou possível limiar agressivo. '
        'Responda em português, uma linha, começando por OK: ou ATENCAO:. '
        'Não peça dados pessoais e não recomende desativar TOT. Telemetria: ' +
        json.dumps(telemetry, separators=(',', ':'))
    )
    body = json.dumps({'model': MODEL, 'input': prompt, 'max_output_tokens': 120}).encode()
    request = urllib.request.Request(
        RESPONSES_URL, data=body, method='POST',
        headers={
            'Authorization': 'Bearer ' + key,
            'Content-Type': 'application/json',
            'User-Agent': 'XLX-TX-Turn-Monitor/1',
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=8) as response:
            data = json.loads(response.read().decode('utf-8', 'replace'))
        text = extract_output_text(data)
        return True, text or 'OK: análise consultiva concluída.'
    except Exception:
        return False, 'IA remota indisponível; a regra local continua independente.'


def self_test():
    sample = [
        'TXTURN event=pair_detected module=C trigger_ms=2000 cooldown_ms=7000',
        'TXTURN event=cooldown_started module=C cooldown_ms=7000',
        'TXTURN event=blocked module=C remaining_ms=6120',
        'TXTURN event=third_party_break module=C',
        'Opening stream on module C for client GATEWAY with sid 42',
    ]
    counts, modules = read_events(sample)
    assert counts == {'pair_detected': 1, 'blocked': 1, 'cooldown_started': 1, 'third_party_break': 1}
    assert modules == ['C']
    assert local_assessment(counts) == 'observed'
    # Event contract intentionally contains no user identity fields.
    assert all('callsign=' not in line and 'station=' not in line and 'radioid=' not in line for line in sample[:4])
    quiet = {'pair_detected': 0, 'blocked_attempts': 0}
    active = {'pair_detected': 1, 'blocked_attempts': 1}
    assert not ai_should_run(1000, {}, quiet)[0]
    due, fingerprint = ai_should_run(1000, {}, active)
    assert due
    saved = {'last_ai_at': 1000, 'last_ai_fingerprint': fingerprint}
    assert not ai_should_run(2000, saved, active)[0]
    changed = {'pair_detected': 2, 'blocked_attempts': 4}
    assert not ai_should_run(1100, saved, changed)[0]
    assert ai_should_run(1900, saved, changed)[0]
    print('tx_turn_ai_monitor_self_test=PASS')
    return 0



def ai_should_run(now, state, telemetry):
    # Never call the remote observer for a quiet or unchanged summary.
    fingerprint = json.dumps(telemetry, sort_keys=True, separators=(',', ':'))
    last_ai = int(state.get('last_ai_at', 0) or 0)
    has_events = any(telemetry.get(field, 0) for field in (
        'pair_detected', 'blocked_attempts', 'cooldown_started', 'third_party_breaks'))
    due = (has_events and fingerprint != state.get('last_ai_fingerprint')
           and (last_ai <= 0 or now - last_ai >= AI_INTERVAL))
    return due, fingerprint


def main():
    if '--self-test' in sys.argv:
        return self_test()

    now = int(time.time())
    counts, modules = read_events(journal_lines())
    assessment = local_assessment(counts)
    telemetry = {
        'window_seconds': 1200,
        'pair_detected': counts['pair_detected'],
        'blocked_attempts': counts['blocked'],
        'cooldown_started': counts['cooldown_started'],
        'third_party_breaks': counts['third_party_break'],
        'modules_with_events': len(modules),
        'local_assessment': assessment,
        'tot_seconds_unchanged': 180,
        'trigger_ms': 2000,
        'cooldown_ms': 7000,
    }

    state = load_state()
    last_ai = int(state.get('last_ai_at', 0) or 0)
    ai_due, fingerprint = ai_should_run(now, state, telemetry)
    ai_ok = bool(state.get('ai_last_ok', False))
    ai_summary = str(state.get('ai_summary', 'Observador local ativo.'))[:320]
    key = os.environ.get('OPENAI_API_KEY', '').strip()
    if ai_due and key:
        ai_ok, ai_summary = ask_ai(telemetry, key)
        last_ai = now
        state['last_ai_fingerprint'] = fingerprint

    state.update({
        'last_assessment': assessment,
        'last_ai_at': last_ai,
        'ai_last_ok': ai_ok,
        'ai_summary': ai_summary,
    })
    atomic_json(STATE, state, 0o600)
    atomic_json(PUBLIC, {
        'ok': True,
        'advisory_only': True,
        'api_key_present': bool(key),
        'ai_last_ok': ai_ok,
        'ai_last_analysis_at': last_ai,
        'ai_summary': ai_summary,
        'telemetry': telemetry,
        'updated_at': now,
    }, 0o644)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
