import subprocess,os,time,json,urllib.request,pathlib,socket,base64,struct
binary=os.environ['XLX_TURN_TEST_LIVE_BINARY']
os.chmod(binary,0o755)
p=subprocess.Popen([binary],env={**os.environ,'XLX026_BIND':'127.0.0.1:8093'},stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
f=pathlib.Path('/run/xlx-tx-turn-state/module-C.json')
def snapshot():
 return json.load(urllib.request.urlopen('http://127.0.0.1:8093/snapshot',timeout=2))
def put(x):
 q=f.with_suffix('.tmp');q.write_text(json.dumps(x));q.replace(f)
def frame(s):
 h=s.recv(2);assert len(h)==2
 n=h[1]&127
 if n==126:n=struct.unpack('!H',s.recv(2))[0]
 if n==127:n=struct.unpack('!Q',s.recv(8))[0]
 b=b''
 while len(b)<n:b+=s.recv(n-len(b))
 return json.loads(b)
try:
 time.sleep(1); assert p.poll() is None
 s=socket.create_connection(('127.0.0.1',8093),2);s.settimeout(3)
 s.sendall(b'GET /ws HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: '+base64.b64encode(os.urandom(16))+b'\r\n\r\n')
 head=b''
 while not head.endswith(b'\r\n\r\n'):head+=s.recv(1)
 assert b'101' in head;assert frame(s)['type']=='hello'
 until=time.monotonic_ns()//1000000+7000
 put({'module':'C','until_ms':until,'callsigns':['PU2AAA','PY2BBB']})
 msg=frame(s);assert msg['type']=='state';row=msg['data']['tx_turn_wait'][0]
 assert row['callsigns']==['PU2AAA','PY2BBB'] and 0<row['remaining_ms']<=7000
 assert snapshot()['tx_turn_wait'][0]['until_ms']==until
 put({'module':'C','until_ms':0,'callsigns':['','']})
 assert frame(s)['data']['tx_turn_wait']==[]
 put({'module':'C','until_ms':time.monotonic_ns()//1000000+250,'callsigns':['PU2AAA','PY2BBB']})
 assert frame(s)['data']['tx_turn_wait'];assert frame(s)['data']['tx_turn_wait']==[]
 put({'module':'D','until_ms':until,'callsigns':['<script>','PY2BBB']})
 time.sleep(.2);assert snapshot()['tx_turn_wait']==[]
 s.close();print('live_v2_wait_ws_snapshot_expiry_third_invalid=PASS')
finally:
 f.unlink(missing_ok=True);p.terminate()
 try:p.wait(timeout=3)
 except subprocess.TimeoutExpired:p.kill();p.wait()
