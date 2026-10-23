import subprocess,time,hashlib,json
from pathlib import Path
root=Path('/opt/xlx-vw-lab-20261023')
ports={10001,10002,10100,42000,12345,12346,40000,30001,30051,20001,62030,21110,8880}
def run(*args):return subprocess.run(args,check=True,capture_output=True,text=True).stdout.strip()
results=[]
for label,tree,enabled in [('baseline','pinned','0'),('candidate','candidate','1'),('restore','pinned','0')]:
 unit='xlx-vw-test-'+label
 binary=str(root/tree/'src/xlxd')
 cmd='printf "*\\n" > /xlxd/xlxd.whitelist; touch /xlxd/xlxd.blacklist /xlxd/xlxd.interlink /xlxd/dmrid.dat; exec '+binary+' XLX999 127.0.0.1 127.0.0.1'
 run('systemd-run','--quiet','--collect','--unit='+unit,'-p','Type=forking','-p','PrivateNetwork=yes','-p','TemporaryFileSystem=/xlxd','-p','TemporaryFileSystem=/var/log','-p','RuntimeMaxSec=110','--setenv=XLX_YSF_VW='+enabled,'/bin/bash','-c',cmd)
 try:
  for _ in range(180):
   pid=run('systemctl','show',unit,'-p','MainPID','--value')
   if pid!='0':
    got=run('nsenter','-t',pid,'-n','ss','-lun')
    found={port for port in ports if any(':'+str(port)+' ' in line for line in got.splitlines())}
    if found==ports:break
   time.sleep(.5)
  else:raise RuntimeError(label+' missing listeners: '+str(ports-found))
  actual=hashlib.sha256(Path('/proc/'+pid+'/exe').read_bytes()).hexdigest()
  expected=hashlib.sha256(Path(binary).read_bytes()).hexdigest()
  assert actual==expected
  results.append({'stage':label,'binary_sha256':actual,'udp_listeners':len(found),'private_network':True,'temporary_runtime_files':True})
 finally:
  subprocess.run(['systemctl','stop',unit],check=False,capture_output=True)
assert results[0]['binary_sha256']==results[2]['binary_sha256']
(root/'restore-evidence.json').write_text(json.dumps(results,indent=2))
print(json.dumps({'restore_env':'PASS','stages':results}))
