#!/usr/bin/env python3
"""Bounded, evidence-based RadioID reconciliation outside the Live request path."""
import csv, datetime as dt, fcntl, ipaddress, json, os, re, sqlite3, subprocess, sys, tempfile, time, urllib.parse, urllib.request
from xml.etree import ElementTree as ET
from radioid_profiles import store_profile
META='/var/lib/xlx026-dmr-meta/metadata.json'
XML='/var/log/xlxd.xml'
CSV='/xlxd/users_db/users_base.csv'
DB='/xlxd/users_db/users.db'
ALIAS='/var/lib/xlx026-identity/radioid-aliases.json'
STATE='/var/lib/xlx026-identity/reconcile-state.json'
LOCK='/run/lock/xlx026-radioid-reconcile.lock'
HELPER='/usr/local/sbin/xlx026-radioid-helper-v111'
CALL=re.compile(r'^[A-Z0-9]{3,8}$')

def load(path,default):
    try:
        with open(path) as f: return json.load(f)
    except (OSError,ValueError): return default

def atomic(path,obj):
    os.makedirs(os.path.dirname(path),exist_ok=True)
    fd,tmp=tempfile.mkstemp(dir=os.path.dirname(path),prefix='.radioid-')
    try:
        with os.fdopen(fd,'w') as f:
            json.dump(obj,f,ensure_ascii=False,separators=(',',':'));f.flush();os.fsync(f.fileno())
        os.chmod(tmp,0o644 if path==ALIAS else 0o600)
        os.replace(tmp,path)
    finally:
        if os.path.exists(tmp):os.unlink(tmp)

def candidates(meta,xml,now):
    by_ip={}
    for k,v in meta.get('devices',{}).items():
        if not isinstance(v,dict) or not str(k).isdigit() or not re.fullmatch(r'\d{7}',str(k)):continue
        ip=v.get('source_ip')
        try: ipaddress.ip_address(ip)
        except (ValueError,TypeError):continue
        try:seen=dt.datetime.fromisoformat(v['last_seen'].replace('Z','+00:00')).timestamp()
        except (KeyError,ValueError,TypeError):continue
        if seen>now+60 or now-seen>86400:continue
        by_ip.setdefault(ip,[]).append(str(k))
    # A shared NAT address cannot prove one numeric identity: skip it.
    unique={ip:ids[0] for ip,ids in by_ip.items() if len(set(ids))==1}
    out={}
    for fragment in re.findall(r'<NODE>.*?</NODE>',xml,re.S|re.I):
        try:node=ET.fromstring(fragment)
        except ET.ParseError:continue
        raw=(node.findtext('Callsign') or '').strip().upper()
        call=raw.split()[0] if raw else ''
        ip=(node.findtext('IP') or '').strip()
        proto=(node.findtext('Protocol') or '').upper()
        rid=unique.get(ip)
        if rid and CALL.fullmatch(call) and 'DMR' in proto:
            if call in out and out[call]!=rid:out[call]=None
            elif call not in out:out[call]=rid
    return {call:rid for call,rid in out.items() if rid}

def local_row(rid):
    with open(CSV,encoding='utf-8',errors='strict',newline='') as f:
        rows=[r for r in csv.reader(f) if len(r)>=7 and r[0].strip()==rid]
    return rows[0] if len(rows)==1 else None

def official(rid):
    qs=urllib.parse.urlencode({'id':rid,'id_sel':'=','page':1,'per_page':2})
    req=urllib.request.Request('https://radioid.net/api/users?'+qs,headers={
        'Accept':'application/json','User-Agent':'XLX026-Identity-Reconcile/1.0 (+https://xlx026.net)'})
    with urllib.request.urlopen(req,timeout=5) as resp:
        data=json.load(resp)
    matches=[r for r in data.get('results',[]) if str(r.get('radio_id',r.get('id','')))==rid]
    if len(matches)!=1:raise ValueError('RadioID ID ambiguous or missing')
    row=matches[0];call=str(row.get('callsign','')).strip().upper()
    if not CALL.fullmatch(call):raise ValueError('RadioID callsign invalid')
    return row,call

def safe_text(value):
    s=str(value or '').strip().replace('\n',' ').replace('\r',' ')
    return s if len(s)<=80 and ',' not in s else ''

def update_one(old,rid,aliases,dry=False):
    existing=local_row(rid)
    if existing and existing[1].strip().upper()==old:return 'already_current'
    row,current=official(rid)
    # A new DMR ID with its current callsign still needs a local record.
    first=safe_text(existing[2] if existing and existing[2] else row.get('fname') or row.get('name'))
    last=safe_text(existing[3] if existing else row.get('surname'))
    city=safe_text(row.get('city') or (existing[4] if existing else ''))
    state=safe_text(row.get('state') or (existing[5] if existing else ''))
    country=safe_text(row.get('country') or (existing[6] if existing else ''))
    if not (first and city and state and country):raise ValueError('required RadioID fields unavailable')
    if dry:return 'would_update_'+old+'_to_'+current
    if not existing or existing[1].strip().upper()!=current:
        args=[HELPER,'radioid-save',rid if existing else '',existing[1].strip().upper() if existing else '',rid,current,first,last,city,state,country]
        result=subprocess.run(args,capture_output=True,text=True,timeout=40)
        if result.returncode or not load_result(result.stdout):raise RuntimeError('atomic DB helper failed, rc='+str(result.returncode))
    with sqlite3.connect('file:'+DB+'?mode=ro',uri=True) as db:
        found=db.execute('select name,city_state from users where callsign=?',(current,)).fetchone()
    if not found:raise RuntimeError('new SQL entry not visible')
    aliases[old]={'id':rid,'callsign':current,'name':found[0],'location':found[1]}
    atomic(ALIAS,aliases)
    try:store_profile(row)
    except Exception as exc:print('CHECK RadioID profile: '+type(exc).__name__,file=sys.stderr,flush=True)
    return 'updated_'+old+'_to_'+current

def load_result(raw):
    try:return json.loads(raw).get('ok') is True
    except (ValueError,TypeError):return False


def reconcile_new_calls(xml, now, state, dry=False):
    """One bounded lookup of a currently connected but unknown callsign."""
    if now-float(state.get('_new_calls_last',0))<60:return 'rate_limited'
    calls=[]
    for fragment in re.findall(r'<NODE>.*?</NODE>',xml,re.S|re.I):
        try:node=ET.fromstring(fragment)
        except ET.ParseError:continue
        call=(node.findtext('Callsign') or '').strip().upper().split(' ')[0]
        if CALL.fullmatch(call) and re.search(r'\d',call) and not call.startswith(('XLX','XRF','REF','DCS','YSF','FCS')) and call not in calls:
            calls.append(call)
    with sqlite3.connect('file:'+DB+'?mode=ro',uri=True,timeout=3) as db:
        for call in calls:
            if now-float(state.get('new_call:'+call,0))<86400:continue
            if db.execute('SELECT 1 FROM users WHERE callsign=? LIMIT 1',(call,)).fetchone():continue
            if not dry:
                state['_new_calls_last']=now
                state['new_call:'+call]=now
                atomic(STATE,state)
            try:
                query=urllib.parse.urlencode({'callsign':call,'callsign_sel':'=','page':1,'per_page':5})
                req=urllib.request.Request('https://radioid.net/api/users?'+query,headers={
                    'Accept':'application/json','User-Agent':'XLX026-Identity/1.0 (+https://xlx026.net)'})
                with urllib.request.urlopen(req,timeout=5) as response: data=json.load(response)
                rows=[r for r in data.get('results',[]) if isinstance(r,dict) and str(r.get('callsign','')).strip().upper()==call]
                if len(rows)!=1:return 'ambiguous_or_missing_'+call
                row=rows[0];rid=str(row.get('radio_id',row.get('id','')))
                if not re.fullmatch(r'\d{7}',rid):return 'invalid_id_'+call
                values=[safe_text(row.get(key)) for key in ('fname','surname','city','state','country')]
                if not (values[0] and values[2] and values[3] and values[4]):return 'incomplete_'+call
                if local_row(rid):return 'id_already_registered_'+call
                if dry:return 'would_add_'+call
                proc=subprocess.run([HELPER,'radioid-save','','',rid,call,*values],capture_output=True,text=True,timeout=40)
                if proc.returncode or not load_result(proc.stdout):raise RuntimeError('atomic save failed')
                with sqlite3.connect('file:'+DB+'?mode=ro',uri=True,timeout=3) as check:
                    if not check.execute('SELECT 1 FROM users WHERE callsign=? LIMIT 1',(call,)).fetchone():
                        raise RuntimeError('saved record not visible')
                try:store_profile(row)
                except Exception as exc:print('CHECK RadioID profile: '+type(exc).__name__,file=sys.stderr,flush=True)
                return 'added_'+call
            except Exception as exc:
                print('CHECK new RadioID '+call+': '+str(exc),file=sys.stderr,flush=True)
                return 'lookup_failed_'+call
    return None

def main():
    dry='--dry-run' in sys.argv
    with open(LOCK,'a+') as lock:
        try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:return 0
        meta=load(META,{});now=time.time()
        with open(XML,encoding='utf-8',errors='replace') as f:xml=f.read()
        matches=candidates(meta,xml,now)
        aliases=load(ALIAS,{})
        state=load(STATE,{})
        numeric_attempted=False
        for old,rid in list(matches.items())[:30]:
            if old in aliases and aliases[old].get('id')==rid:continue
            key=old+':'+rid
            if now-float(state.get(key,0))<300:continue
            if not dry:state[key]=now;atomic(STATE,state)
            try:
                outcome=update_one(old,rid,aliases,dry)
                if not dry and outcome in ('already_current','source_matches_network'):
                    state[key]=now+3300;atomic(STATE,state)
                print(outcome,flush=True)
            except Exception as e:print('CHECK '+old+' ID '+rid+': '+str(e),file=sys.stderr,flush=True)
            # One external lookup per run; next scheduled tick handles others.
            numeric_attempted=True
            break
        if not numeric_attempted:
            outcome=reconcile_new_calls(xml,now,state,dry)
            if outcome and outcome!="rate_limited":print(outcome,flush=True)
    return 0
if __name__=='__main__':raise SystemExit(main())