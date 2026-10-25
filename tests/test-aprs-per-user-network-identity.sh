#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
GW="$ROOT/dashboard/native/aprs/xlx_aprs_dprs.py"
API="$ROOT/dashboard/api/digital-lab-operator.php"
JS="$ROOT/dashboard/assets/digital-lab-operator.js"
HTML="$ROOT/dashboard/digital-lab-native.php"

python3 -m py_compile "$GW"
php -l "$API" >/dev/null
node --check "$JS"

grep -F "'actor' => \$actor" "$API" >/dev/null
grep -F "'network_identity'" "$API" >/dev/null
grep -F "identity_max_sessions" "$GW" >/dev/null
grep -F "identity_idle_seconds" "$GW" >/dev/null
grep -F "local_identity" "$GW" >/dev/null
grep -F "digital-lab-operator.js?v=1.2.11" "$HTML" >/dev/null

python3 - "$GW" <<'PY'
from __future__ import annotations

import importlib.util
import re
import socket
import sys
import tempfile
import threading
import time
from pathlib import Path

gw_path=Path(sys.argv[1])
spec=importlib.util.spec_from_file_location("xlx_aprs_identity_test",gw_path)
mod=importlib.util.module_from_spec(spec)
sys.modules[spec.name]=mod
spec.loader.exec_module(mod)

assert mod.operator_aprs_identity("PU4CAO")=="PU4CAO-10"
assert mod.operator_aprs_identity("pu1tmr")=="PU1TMR-10"
assert mod.operator_aprs_identity("PY2ABCD")=="PY2ABCD"
assert len(mod.operator_aprs_identity("PY2ABCD"))<=9

tmp=Path(tempfile.mkdtemp(prefix="xlx-aprs-identity-"))
db=mod.StateDB(tmp/"gateway.sqlite",tmp/"public.json",7)

listener=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
listener.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
listener.bind(("127.0.0.1",0))
listener.listen(2)
host,port=listener.getsockname()

observed={}
server_done=threading.Event()

def fake_server():
    conn,_=listener.accept()
    conn.settimeout(5)
    f=conn.makefile("r",encoding="ascii",errors="replace",newline="\n")
    login=f.readline().strip()
    observed["login"]=login
    assert login.startswith("user PU4CAO-10 pass "),login
    assert " vers XLX-APRS-DPRS 1.2.0" in login,login

    conn.sendall(b"# logresp PU4CAO-10 verified, server TEST\r\n")

    sent=f.readline().strip()
    observed["sent"]=sent
    assert sent.startswith("PU4CAO-10>APDLAB,TCPIP*::PKTQSO  :join{"),sent
    mid=sent.rsplit("{",1)[1]
    observed["mid"]=mid

    ack=(
        f"PKTQSO>APRS,TCPIP*::PU4CAO-10:ack{mid}\r\n"
    ).encode("ascii")
    conn.sendall(ack)

    inbound=(
        "PKTQSO>APRS,TCPIP*::PU4CAO-10:hello from test{77\r\n"
    ).encode("ascii")
    conn.sendall(inbound)

    ack_back=f.readline().strip()
    observed["ack_back"]=ack_back
    assert ack_back.startswith(
        "PU4CAO-10>APDLAB,TCPIP*::PKTQSO  :ack77"
    ),ack_back

    server_done.set()
    time.sleep(.2)
    conn.close()

threading.Thread(target=fake_server,daemon=True).start()

class DummyService:
    def __init__(self):
        self.cfg={"login":"PU2PNY-10","tx_enabled":True}
        self.sock=object()
        self.verified=True
        self.sent=[]
    def send_operator_message(self,dest,text):
        self.sent.append((dest,text))
        return {
            "ok":True,
            "peer":dest,
            "msg_id":"S1",
            "status":"awaiting_ack",
            "source":"PU2PNY-10",
        }

parent_stop=threading.Event()
service=DummyService()
cfg={
    "enabled":True,
    "host":host,
    "port":port,
    "login":"PU2PNY-10",
    "passcode":"auto",
    "filter":"",
    "tx_enabled":True,
    "identity_max_sessions":1,
    "identity_idle_seconds":300,
    "site_name":"XLX026",
}
manager=mod.APRSIdentitySessionManager(
    cfg,db,parent_stop,service
)
manager.start()

result=manager.send("PU4CAO","PKTQSO","join")
assert result["ok"] is True,result
assert result["source"]=="PU4CAO-10",result
assert result["identity_mode"]=="dedicated",result

deadline=time.time()+4
acked=False
inbound=False
while time.time()<deadline:
    with db.lock:
        rows=db.conn.execute(
            """
            select direction,peer,body,msg_id,status,local_identity
            from messages
            order by id asc
            """
        ).fetchall()
    acked=any(
        r["direction"]=="out"
        and r["peer"]=="PKTQSO"
        and r["status"]=="acked"
        and r["local_identity"]=="PU4CAO-10"
        for r in rows
    )
    inbound=any(
        r["direction"]=="in"
        and r["peer"]=="PKTQSO"
        and r["body"]=="hello from test"
        and r["local_identity"]=="PU4CAO-10"
        for r in rows
    )
    if acked and inbound and server_done.is_set():
        break
    time.sleep(.05)

assert acked,rows
assert inbound,rows
assert server_done.is_set(),observed

# With cap=1, a second direct identity must not create another session.
cap=manager.send("PU1TMR","PKTQSO","test")
assert cap.get("error")=="identity_capacity",cap

# The sysop identity reuses the main service connection instead of duplicating it.
sysop=manager.send("PU2PNY","PKTQSO","sysop")
assert sysop["ok"] is True,sysop
assert sysop["source"]=="PU2PNY-10",sysop
assert sysop["identity_mode"]=="service",sysop
assert service.sent==[("PKTQSO","sysop")],service.sent

parent_stop.set()
manager.join(timeout=3)
listener.close()
db.close()

print("identity_login=PASS")
print("network_source=PU4CAO-10 PASS")
print("ack_isolation=PASS")
print("personal_inbound=PASS")
print("session_capacity=PASS")
print("sysop_session_reuse=PASS")
PY

echo "aprs_per_user_network_identity=PASS"
