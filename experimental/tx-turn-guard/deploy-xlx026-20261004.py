from pathlib import Path
import os,shutil,subprocess,time,json,urllib.request,hashlib
stage=Path('/opt/xlx-turn-deploy-final-20261004')
backup=Path('/opt/xlx026-backups/TX_TURN_WAIT_20261004_2120')
def run(*args):return subprocess.run(args,check=True,capture_output=True,text=True).stdout.strip()
def active():
 x=json.load(urllib.request.urlopen('http://127.0.0.1:8092/snapshot',timeout=2))
 return int(x['active_count'])
idle=0
for _ in range(120):
 if active()==0:idle+=1
 else:idle=0
 if idle>=3:break
 time.sleep(1)
else:raise RuntimeError('No idle window; production unchanged')
manifest=json.loads((backup/'manifest.json').read_text())
for dest,x in manifest.items():
 assert hashlib.sha256(Path(dest).read_bytes()).hexdigest()==x['sha256'],'baseline changed '+dest
before={s:run('systemctl','show','-p','MainPID','--value',s).strip() for s in ['xlxd','xlx-unified-voice','xlx026-live-core-v2']}
def install(src,dest,mode=0o644):
 p=Path(dest);p.parent.mkdir(parents=True,exist_ok=True)
 tmp=str(p)+'.txturn-new';shutil.copyfile(src,tmp);os.chmod(tmp,mode);os.replace(tmp,p)
try:
 install(stage/'xlxd','/xlxd/xlxd',0o755)
 install(stage/'app.js','/var/www/html/xlxd/assets/app.js')
 install(stage/'server.js','/opt/xlx026-live-hub/server.js')
 install(stage/'tx-turn-state.js','/opt/xlx026-live-hub/tx-turn-state.js')
 install('/opt/xlx-turn-live-v2-stage-20261004/xlx026-live-core-v2','/usr/local/bin/xlx026-live-core-v2',0o755)
 install(stage/'xlx-tx-turn-ai-monitor.py','/usr/local/lib/xlx-modern/xlx-tx-turn-ai-monitor.py',0o755)
 for n in ['xlx-tx-turn-ai-monitor.service','xlx-tx-turn-ai-monitor.timer']:install(stage/n,'/etc/systemd/system/'+n)
 drop=Path('/etc/systemd/system/xlxd.service.d/tx-turn-wait.conf');drop.parent.mkdir(exist_ok=True)
 drop.write_text('[Service]\nRuntimeDirectory=xlx-tx-turn-state\nRuntimeDirectoryMode=0755\nEnvironment=XLX_TX_TURN_GUARD=1\nEnvironment=XLX_TX_TURN_TRIGGER_MS=2000\nEnvironment=XLX_TX_TURN_COOLDOWN_MS=7000\nEnvironment=XLX_TX_TURN_RESET_MS=60000\nEnvironment=XLX_TX_TURN_STATE_DIR=/run/xlx-tx-turn-state\n')
 envfile=Path('/etc/xlx-ai-monitor.env');content=envfile.read_text()
 # Reuse explicitly provisioned observer model without exposing credentials.
 if not any(x.startswith('OPENAI_TX_TURN_MODEL=') for x in content.splitlines()):
  model=next(x.split('=',1)[1] for x in content.splitlines() if x.startswith('OPENAI_MODEL='))
  envfile.write_text(content.rstrip()+'\nOPENAI_TX_TURN_MODEL='+model+'\n');envfile.chmod(0o600)
 run('systemctl','daemon-reload')
 run('systemctl','restart','xlxd')
 run('systemctl','restart','xlx026-live-core-v2')
 run('systemctl','restart','xlx026-live-hub')
 run('systemctl','enable','--now','xlx-tx-turn-ai-monitor.timer')
 for s in ['xlxd','xlx026-live-core-v2','xlx026-live-hub','xlx-unified-voice']:
  assert run('systemctl','is-active',s).strip()=='active',s
 pid=run('systemctl','show','-p','MainPID','--value','xlxd').strip()
 assert hashlib.sha256(Path('/proc/'+pid+'/exe').read_bytes()).hexdigest()=='9dce43475fed2fa464e8b76f1363167827b5cb80e33981523d2e701ea3d0b9f0'
 expected_ports=[10001,10002,10100,42000,12345,12346,40000,30001,30051,20001,62030,21110,8880]
 for attempt in range(180):
  ports=run('ss','-lunp')
  missing=[port for port in expected_ports if not any((':'+str(port)+' ') in line and ('pid='+pid+',') in line for line in ports.splitlines())]
  if not missing:break
  assert run('systemctl','is-active','xlxd')=='active','core died during startup'
  time.sleep(.5)
 else:raise RuntimeError('Listeners absent after 90s: '+str(missing))
 print('startup_listeners_ready_seconds='+str(attempt*.5))
 assert before['xlx-unified-voice']==run('systemctl','show','-p','MainPID','--value','xlx-unified-voice').strip()
 snapshot=json.load(urllib.request.urlopen('http://127.0.0.1:8092/snapshot',timeout=2))
 assert snapshot['ok'] and 'tx_turn_wait' in snapshot
 event={'deploy':'PASS','time':time.time(),'xlxd_pid':pid,'before':before,'binary_sha256':'9dce43475fed2fa464e8b76f1363167827b5cb80e33981523d2e701ea3d0b9f0','listeners':13,'tot180':'preserved','active_count':snapshot['active_count'],'waits':snapshot['tx_turn_wait']}
 (backup/'deploy-result.json').write_text(json.dumps(event,indent=2))
 print(json.dumps(event))
except Exception:
 run('python3',str(backup/'rollback.py'))
 print('ROLLBACK executed after failed deploy validation')
 raise
