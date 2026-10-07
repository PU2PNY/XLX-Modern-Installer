#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
python3 - "$ROOT" "$WORK" <<'PY'
import io,json,pathlib,sqlite3,subprocess,sys,tarfile,hashlib
root=pathlib.Path(sys.argv[1]);work=pathlib.Path(sys.argv[2]);fixture=work/'fixture'
(fixture/'xlxd').mkdir(parents=True)
(fixture/'xlxd/xlxd').write_bytes(b'SYNTHETIC_EXECUTABLE_FOR_RESTORE_TEST')
(fixture/'etc/nginx').mkdir(parents=True)
(fixture/'etc/nginx/nginx.conf').write_text('server_name xlx-lab.example.org;')
(fixture/'etc/xlx-modern').mkdir(parents=True)
(fixture/'etc/xlx-modern/callinghome.php').write_text('fixture ownership configuration retained')
(fixture/'var/lib/xlx-modern-history').mkdir(parents=True)
db=fixture/'var/lib/xlx-modern-history/history.sqlite'
with sqlite3.connect(db) as connection:
 connection.execute('PRAGMA journal_mode=WAL');connection.execute('CREATE TABLE tx(n INTEGER)')
 connection.execute('INSERT INTO tx VALUES(7)');connection.commit()
 archive=work/'recovery.tar.gz'
 subprocess.run([sys.executable,str(root/'scripts/backup-production.py'),'--root',str(fixture),'--output',str(archive)],check=True)
stage=work/'restore'
subprocess.run([sys.executable,str(root/'scripts/restore-production.py'),'--archive',str(archive),'--destination',str(stage)],check=True)
assert (stage/'xlxd/xlxd').read_bytes()==(fixture/'xlxd/xlxd').read_bytes()
assert (stage/'etc/xlx-modern/callinghome.php').read_bytes()==(fixture/'etc/xlx-modern/callinghome.php').read_bytes()
with sqlite3.connect(stage/'var/lib/xlx-modern-history/history.sqlite') as conn:
 assert conn.execute('SELECT n FROM tx').fetchone()[0]==7
assert archive.stat().st_mode & 0o077 == 0
# A checksum-valid hostile archive must still be rejected before writing out.
hostile=work/'hostile.tar.gz'
with tarfile.open(hostile,'w:gz') as tar:
 data=b'hostile'; info=tarfile.TarInfo('../escape');info.size=len(data);tar.addfile(info,io.BytesIO(data))
hostile.with_name(hostile.name+'.sha256').write_text(hashlib.sha256(hostile.read_bytes()).hexdigest()+'  hostile.tar.gz\n')
result=subprocess.run([sys.executable,str(root/'scripts/restore-production.py'),'--archive',str(hostile),'--destination',str(work/'unsafe')],capture_output=True)
assert result.returncode!=0 and not (work/'escape').exists()
source=(root/'runtime/prepare-xlxd-source.sh').read_text()
assert 'e69f2dcdd9cf004d5ad199f85c27f1fa1e7e5004' in source and 'apply --check' in source
nginx=(root/'modules/70-nginx.sh').read_text()
assert nginx.count('location ^~ /api/live-v2/')==2
assert nginx.count('location = /api/live-stream')==2
assert nginx.count('fastcgi_param XLXMODERN_LIVE_HUB 1;')==2
admin=(root/'control/current-production-admin.php').read_text()
for view in ['home','health','access','radioid']: assert "$view==='"+view+"'" in admin
for bad in ['xlx026.net','/controle/','PU2PNY','82.152.']: assert bad not in admin
assert 'csrf_ok' in admin and 'password_verify' in admin and '$adminPath' in admin
print('COMPLETE_RECOVERY=PASS (fixtures, contracts, safe extraction; not RF or operational restore)')
PY
node --check "$ROOT/runtime/live-hub/server.js"
node --check "$ROOT/runtime/live-hub/tx-turn-state.js"
