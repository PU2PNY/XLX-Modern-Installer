#!/usr/bin/env python3
import hashlib, json, os, pathlib, re, socket, stat, subprocess, tempfile, time, urllib.request, urllib.error

RUNTIME = pathlib.Path('/run/xlx-helix-monitor')
STATE_DIR = pathlib.Path('/var/lib/xlx-helix-monitor')
PUBLIC = RUNTIME / 'public.json'
STATE = STATE_DIR / 'state.json'
XUVD = pathlib.Path('/opt/xlx-unified-voice/bin/xuvd')
EXPECTED_XUVD = '559f580b5edf58883eb81293d8fbdc044e13eff9ca4dc6437e6b16014f75a243'
SHADOW_SOCKET = pathlib.Path('/run/helix-voice/observe.sock')
PROCESS_SOCKET = pathlib.Path('/run/helix-voice/pcm.sock')
AI_PUBLIC = pathlib.Path('/run/xlx-ai-monitor/public.json')
RESPONSES_URL = 'https://api.openai.com/v1/responses'
MODEL = os.environ.get('OPENAI_MONITOR_MODEL', 'gpt-5.6-luna').strip() or 'gpt-5.6-luna'

def atomic_json(path, payload, mode=0o644):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=path.name+'.', dir=str(path.parent))
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            json.dump(payload, f, ensure_ascii=False, separators=(',',':'))
            f.write('\n')
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    finally:
        try: os.unlink(tmp)
        except FileNotFoundError: pass

def run(args, timeout=3):
    try:
        p=subprocess.run(args, capture_output=True, text=True, timeout=timeout, check=False)
        return p.returncode, p.stdout.strip()
    except Exception:
        return 255, ''

def unit(name):
    rc,out=run(['systemctl','show',name,'-p','ActiveState','-p','MainPID','--value'])
    lines=out.splitlines()
    active='active' in lines
    pid=0
    for line in lines:
        try:
            n=int(line)
            if n>0: pid=n
        except Exception: pass
    return active,pid

def rss_kb(pid):
    if pid<=0: return 0
    try:
        for line in pathlib.Path(f'/proc/{pid}/status').read_text().splitlines():
            if line.startswith('VmRSS:'): return int(line.split()[1])
    except Exception: pass
    return 0

def sha256(path):
    try:
        h=hashlib.sha256()
        with open(path,'rb') as f:
            for chunk in iter(lambda:f.read(131072),b''): h.update(chunk)
        return h.hexdigest()
    except Exception:
        return ''

def ai_connectivity():
    try:
        d=json.loads(AI_PUBLIC.read_text(encoding='utf-8'))
        fresh=abs(int(time.time())-int(d.get('updated_at',0))) <= 1800
        return bool(d.get('api_connected')) and fresh
    except Exception:
        return False

def recent_helix_counters():
    rc,out=run(['journalctl','-u','xlx-unified-voice.service','--since','3 minutes ago','-o','cat','--no-pager'],5)
    latest=None
    if rc not in (0,1): return 'off',0,0,0
    rx=re.compile(r'helix=(shadow|process).*?helix_ok=(\d+).*?helix_fallback=(\d+)')
    for line in out.splitlines():
        m=rx.search(line)
        if m:
            latest=(m.group(1),int(m.group(2)),int(m.group(3)))
    if not latest: return 'off',0,0,0
    return latest[0],latest[1],latest[2],int(time.time())

def load_state():
    try:
        x=json.loads(STATE.read_text(encoding='utf-8'))
        return x if isinstance(x,dict) else {}
    except Exception:
        return {}

def extract_output_text(data):
    texts=[]
    for item in data.get('output',[]) if isinstance(data,dict) else []:
        if not isinstance(item,dict): continue
        for c in item.get('content',[]) or []:
            if isinstance(c,dict) and isinstance(c.get('text'),str):
                texts.append(c['text'].strip())
    return ' '.join(t for t in texts if t)[:240]

def ask_ai(telemetry, key):
    prompt=(
      'Você monitora o Helix Voice de um refletor XLX em modo shadow ou process de teste controlado. '
      'Receba somente telemetria técnica; nenhum áudio é enviado. '
      'Responda em português em uma linha, começando exatamente por OK: ou ATENCAO:. '
      'Não recomende tornar process permanente. Não recomende aumentar timeout acima de 5 ms. '
      'Se todos os serviços estão ativos, socket pronto, hash esperado e fallback recente zero, responda OK. '
      'Telemetria: '+json.dumps(telemetry,separators=(',',':'))
    )
    body=json.dumps({'model':MODEL,'input':prompt,'max_output_tokens':100}).encode()
    req=urllib.request.Request(RESPONSES_URL,data=body,method='POST',headers={
      'Authorization':'Bearer '+key,'Content-Type':'application/json',
      'User-Agent':'XLX-Helix-Monitor/1'
    })
    try:
        with urllib.request.urlopen(req,timeout=8) as r:
            data=json.loads(r.read().decode('utf-8','replace'))
        text=extract_output_text(data)
        return True, text or 'OK: análise concluída sem texto adicional.'
    except Exception:
        return False, 'Análise remota indisponível; monitoramento local continua ativo.'

def main():
    now=int(time.time())
    shadow_active,shadow_pid=unit('helix-voice-shadow.service')
    process_active,process_pid=unit('helix-voice-process-test.service')
    xuvd_active,xuvd_pid=unit('xlx-unified-voice.service')
    xlxd_active,xlxd_pid=unit('xlxd.service')
    try:
        shadow_socket_ready=SHADOW_SOCKET.exists() and stat.S_ISSOCK(SHADOW_SOCKET.stat().st_mode)
    except Exception:
        shadow_socket_ready=False
    try:
        process_socket_ready=PROCESS_SOCKET.exists() and stat.S_ISSOCK(PROCESS_SOCKET.stat().st_mode)
    except Exception:
        process_socket_ready=False
    mode='process' if process_active and process_socket_ready else ('shadow' if shadow_active and shadow_socket_ready else 'off')
    helix_active=process_active if mode=='process' else shadow_active
    helix_pid=process_pid if mode=='process' else shadow_pid
    socket_ready=process_socket_ready if mode=='process' else shadow_socket_ready
    xhash=sha256(XUVD)
    candidate_ok=(xhash==EXPECTED_XUVD)
    counter_mode,helix_ok,helix_fallback,last_observed=recent_helix_counters()
    ai_connected=ai_connectivity()
    telemetry={
      'mode':mode,
      'helix_active':helix_active,'socket_ready':socket_ready,
      'xuvd_active':xuvd_active,'xlxd_active':xlxd_active,
      'candidate_ok':candidate_ok,
      'helix_rss_kb':rss_kb(helix_pid),'xuvd_rss_kb':rss_kb(xuvd_pid),
      'recent_helix_ok':helix_ok,'recent_fallback':helix_fallback
    }
    anomaly=not all([helix_active,socket_ready,xuvd_active,xlxd_active,candidate_ok]) or helix_fallback>0
    state=load_state()
    signature=json.dumps({k:telemetry[k] for k in ('mode','helix_active','socket_ready','xuvd_active','xlxd_active','candidate_ok','recent_fallback')},sort_keys=True)
    last_ai=int(state.get('last_ai_at',0) or 0)
    old_sig=str(state.get('last_signature',''))
    ai_due=ai_connected and (last_ai<=0 or now-last_ai>=900 or signature!=old_sig)
    ai_ok=bool(state.get('ai_last_ok',False))
    ai_summary=str(state.get('ai_summary','Monitoramento local ativo.'))[:240]
    if ai_due:
        key=os.environ.get('OPENAI_API_KEY','').strip()
        if key:
            ai_ok,ai_summary=ask_ai(telemetry,key)
            last_ai=now
    state.update({'last_ai_at':last_ai,'last_signature':signature,'ai_last_ok':ai_ok,'ai_summary':ai_summary})
    atomic_json(STATE,state,0o600)
    payload={
      'ok':True,'mode':mode,
      'shadow_active':mode=='shadow' and helix_active and socket_ready and xuvd_active and candidate_ok,
      'process_active':mode=='process' and helix_active and socket_ready and xuvd_active and candidate_ok,
      'helix_active':helix_active,'socket_ready':socket_ready,'xuvd_active':xuvd_active,'xlxd_active':xlxd_active,
      'candidate_ok':candidate_ok,'helix_rss_kb':telemetry['helix_rss_kb'],'xuvd_rss_kb':telemetry['xuvd_rss_kb'],
      'recent_helix_ok':helix_ok,'recent_fallback':helix_fallback,'last_observed_at':last_observed,
      'ai_connected':ai_connected,'ai_last_analysis_at':last_ai,'ai_last_ok':ai_ok,
      'ai_summary':ai_summary,'anomaly':anomaly,'updated_at':now
    }
    atomic_json(PUBLIC,payload,0o644)
    return 0

if __name__=='__main__':
    raise SystemExit(main())