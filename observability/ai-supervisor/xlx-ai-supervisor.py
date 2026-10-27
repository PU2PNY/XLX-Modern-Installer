#!/usr/bin/env python3
"""Technical AI supervision plus a deterministic, bounded recovery policy.

AI output is plain advisory text and is NEVER executed. No radio-path changes.
"""
import fcntl
import hashlib
import json
import os
import pathlib
import subprocess
import time
import urllib.request
from importlib.machinery import SourceFileLoader

helper = SourceFileLoader('ai_connectivity', str(pathlib.Path(__file__).with_name('xlx-ai-monitor.py'))).load_module()
RUNTIME = pathlib.Path('/run/xlx-ai-supervisor')
STATE = pathlib.Path('/var/lib/xlx-ai-supervisor/state.json')
WATCH = ('xlxd.service', 'xlx-unified-voice.service', 'helix-voice-shadow.service',
         'nginx.service', 'php8.2-fpm.service', 'xlx026-live-core-v2.service',
         'xlx026-live-hub.service', 'xlx026-health-monitor.service')
# May START only these auxiliary daemons after two consecutive failed samples.
# Never restart an active daemon, start a deliberately stopped one, or touch RF.
RECOVER = frozenset(('xlx026-live-core-v2.service', 'xlx026-live-hub.service',
                     'xlx026-health-monitor.service'))

def command(args):
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=5, check=False)
        return p.returncode, p.stdout.strip()
    except (OSError, subprocess.TimeoutExpired): return 255, ''

def service_status(name):
    rc, out = command(['/usr/bin/systemctl', 'show', name, '-p', 'ActiveState', '-p', 'LoadState'])
    values = dict(x.split('=', 1) for x in out.splitlines() if '=' in x)
    if rc or values.get('LoadState') != 'loaded': return 'unknown'
    return values.get('ActiveState', 'unknown')

def recovery_allowed(name, status, previous_count, last_attempt, attempts_today, now):
    return (name in RECOVER and status == 'failed' and previous_count >= 1
            and now-last_attempt >= 1800 and attempts_today < 3)

def local_health():
    services = {name: service_status(name) for name in WATCH}
    disk = os.statvfs('/')
    disk_pct = round(100*(1-disk.f_bavail/max(disk.f_blocks, 1)), 1)
    mem = {}
    for line in pathlib.Path('/proc/meminfo').read_text().splitlines():
        if ':' in line: mem[line.split(':')[0]] = int(line.split()[1])
    memory_pct = round(100*(1-mem.get('MemAvailable', 0)/max(mem.get('MemTotal', 1), 1)), 1)
    return {'services': services, 'disk_used_pct': disk_pct, 'memory_used_pct': memory_pct,
            'load_per_cpu': round(os.getloadavg()[0]/max(os.cpu_count() or 1, 1), 2)}

def signature(health):
    value = {'services': health['services'], 'disk_high': health['disk_used_pct'] >= 90,
             'memory_high': health['memory_used_pct'] >= 90, 'load_high': health['load_per_cpu'] >= 2}
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()

def analyze(health):
    key = os.environ.get('OPENAI_API_KEY', '').strip()
    model = os.environ.get('OPENAI_MODEL', '').strip()
    if not key or not model: return False, 'API ou modelo não configurado.'
    prompt = ('Supervisione um servidor XLX com base exclusivamente nesta telemetria técnica agregada. '
              'Responda em português em até 3 frases, descrevendo o estado e uma ação útil se necessária. '
              'Não afirme qualidade de áudio/RF. Não invente ações executadas. Não forneça comandos. '
              'O rádio continua independente da IA. Recuperação local só inicia auxiliares em failed, '
              'duas amostras consecutivas, intervalo 30min, até 3/dia por serviço. '
              'Não altere TOT, codecs, protocolos, rede ou segurança. Dados: '+json.dumps(health))
    req = urllib.request.Request('https://api.openai.com/v1/responses', method='POST',
        headers={'Authorization': 'Bearer '+key, 'Content-Type': 'application/json', 'User-Agent': 'XLX-AI-Supervisor/1'},
        data=json.dumps({'model': model, 'input': prompt, 'max_output_tokens': 300, 'store': False}).encode())
    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            data = json.loads(response.read(131072))
        parts = [c['text'] for item in data.get('output', []) if isinstance(item, dict)
                 for c in item.get('content', []) if isinstance(c, dict) and isinstance(c.get('text'), str)]
        text = ' '.join(parts).strip()[:900]
        if data.get('status') != 'completed' or not text: return False, 'Análise incompleta; monitor local ativo.'
        return True, text
    except Exception:
        return False, 'Análise remota indisponível; supervisão local ativa.'

def main():
    RUNTIME.mkdir(parents=True, exist_ok=True)
    with (RUNTIME/'lock').open('w') as lock:
        try: fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError: return 0
        now = int(time.time())
        state = helper.read_json(STATE)
        health = local_health()
        day = time.strftime('%Y-%m-%d', time.gmtime(now))
        if state.get('day') != day: state.update(day=day, attempts={})
        failures = state.setdefault('failures', {})
        attempts = state.setdefault('attempts', {})
        last = state.setdefault('last_recovery', {})
        events = state.get('events', [])[-19:]
        for name, status in health['services'].items():
            if recovery_allowed(name, status, failures.get(name, 0), last.get(name, 0), attempts.get(name, 0), now):
                last[name] = now
                attempts[name] = attempts.get(name, 0)+1
                rc, _ = command(['/usr/bin/systemctl', 'start', name])
                after = service_status(name)
                events.append({'at': now, 'service': name, 'action': 'start', 'ok': rc == 0 and after == 'active'})
                print(json.dumps(events[-1]), flush=True)
                health['services'][name] = after
            failures[name] = min(failures.get(name, 0)+1, 2) if status == 'failed' else 0
        sig = signature(health)
        elapsed = now-int(state.get('last_ai_attempt_at', 0))
        # No anomaly bypass of the 15 minute absolute minimum. Healthy steady
        # state is summarized hourly; failure retries obey the same minimum.
        due = elapsed >= 900 and (sig != state.get('last_signature') or elapsed >= 3600 or not state.get('ai_ok'))
        if due:
            state['last_ai_attempt_at'] = now
            state['ai_ok'], summary = analyze(health)
            state['last_error'] = '' if state['ai_ok'] else summary
            if state['ai_ok']:
                state.update(ai_summary=summary, ai_last_analysis_at=int(time.time()), last_signature=sig)
        state['events'] = events[-20:]
        helper.atomic_json(STATE, state, 0o600)
        helper.atomic_json(RUNTIME/'public.json', {
            'updated_at': int(time.time()), 'local_supervision': True,
            'ai_ok': state.get('ai_ok', False), 'ai_summary': state.get('ai_summary', ''),
            'ai_last_analysis_at': state.get('ai_last_analysis_at', 0),
            'last_ai_attempt_at': state.get('last_ai_attempt_at', 0), 'last_error': state.get('last_error', ''),
            'health': health, 'recovery_scope': sorted(RECOVER), 'events': events[-5:]})
    return 0

if __name__ == '__main__': raise SystemExit(main())
