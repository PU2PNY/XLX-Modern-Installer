#!/usr/bin/env python3
import argparse, datetime as dt, json, os, re, socket, struct, subprocess, tempfile, time
def default_iface():
    try:
        r=subprocess.run(['/usr/sbin/ip','route','show','default'],capture_output=True,text=True,timeout=3,check=False)
        m=re.search(r'\bdev\s+(\S+)',r.stdout)
        if m:return m.group(1)
    except Exception:pass
    for x in os.listdir('/sys/class/net'):
        if x!='lo':return x
    return 'lo'
IFACE=default_iface(); PORT=62030
STATE='/var/lib/xlx-modern-dmr-meta/metadata.json'
CALL_RE=re.compile(r'^[A-Z0-9]{3,8}$')
def iso(): return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace('+00:00','Z')
def clean_ascii(b): return b.decode('ascii','ignore').replace('\x00','').strip()
def num_int(b):
    s=clean_ascii(b)
    try:return int(s)
    except:return None
def num_float(b):
    s=clean_ascii(b)
    try:return float(s)
    except:return None
def parse_rptc(p):
    if len(p)!=302 or p[:4]!=b'RPTC': return None
    call=clean_ascii(p[8:16]).upper()
    if not CALL_RE.fullmatch(call): return None
    rid=int.from_bytes(p[4:8],'big')
    result={
      'dmr_id':rid,'callsign':call,
      'rx_frequency':num_int(p[16:25]),'tx_frequency':num_int(p[25:34]),
      'power':num_int(p[34:36]),'color_code':num_int(p[36:38]),
      'latitude':num_float(p[38:46]),'longitude':num_float(p[46:55]),
      'height':num_int(p[55:58]),'location':clean_ascii(p[58:78]),
      'description':clean_ascii(p[78:97]),'slots':clean_ascii(p[97:98]),
      'url':clean_ascii(p[98:222]),'version':clean_ascii(p[222:262]),
      'software':clean_ascii(p[262:302]),'confidence':'self-declared','source':'MMDVM_RPTC',
      'last_seen':iso()
    }
    # Sanity only; retain unknown/zero as null rather than inventing values.
    if result['latitude'] is not None and not -90<=result['latitude']<=90: result['latitude']=None
    if result['longitude'] is not None and not -180<=result['longitude']<=180: result['longitude']=None
    if result['latitude'] is not None and result['longitude'] is not None and abs(result['latitude']) < 0.000001 and abs(result['longitude']) < 0.000001:
        result['latitude']=None; result['longitude']=None
    sw=(result.get('software') or '').upper()
    if any(x in sw for x in ('_HS_', 'HOTSPOT', 'HAT')):
        result['declared_class_hint']='hotspot'
    elif 'REPEATER' in sw:
        result['declared_class_hint']='repeater-candidate'
    else:
        result['declared_class_hint']='unknown'
    for k in ('rx_frequency','tx_frequency'):
        v=result[k]
        if v is not None and not 1000000<=v<=10000000000: result[k]=None
    return result
def parse_rptg(p):
    if len(p)!=25 or p[:4]!=b'RPTG': return None
    rid=int.from_bytes(p[4:8],'big')
    try:
        txt=p[8:25].decode('ascii'); lat=float(txt[:8]); lon=float(txt[8:17])
    except Exception:return None
    if not(-90<=lat<=90 and -180<=lon<=180):return None
    return {'dmr_id':rid,'latitude':lat,'longitude':lon,'last_position':iso()}
def udp_payload(frame):
    if len(frame)<42:return None
    off=14; et=struct.unpack('!H',frame[12:14])[0]
    if et==0x8100:
        if len(frame)<46:return None
        et=struct.unpack('!H',frame[16:18])[0];off=18
    if et!=0x0800:return None
    ihl=(frame[off]&15)*4
    if len(frame)<off+ihl+8 or frame[off+9]!=17:return None
    u=off+ihl; sport,dport,ln,_=struct.unpack('!HHHH',frame[u:u+8])
    if dport!=PORT:return None
    return frame[u+8:u+ln]
def load_state():
    try:
        d=json.load(open(STATE)); return d if isinstance(d,dict) else {'schema':1,'devices':{}}
    except:return {'schema':1,'devices':{}}
def save_state(d):
    d['generated_at']=iso(); os.makedirs(os.path.dirname(STATE),exist_ok=True)
    fd,tmp=tempfile.mkstemp(prefix='.metadata.',dir=os.path.dirname(STATE));
    try:
        with os.fdopen(fd,'w') as f: json.dump(d,f,ensure_ascii=False,separators=(',',':'));f.flush();os.fsync(f.fileno())
        os.chmod(tmp,0o640);os.replace(tmp,STATE)
    finally:
        try: os.unlink(tmp)
        except: pass
def selftest():
    rid=7241234; cfg=(f"{'N0CALL':<8}{'438800000':>9}{'431200000':>9}{'10':>2}{'01':>2}{'-23.3121':>8}{'-46.2248':>9}{'750':>3}{'Example City':<20.20}{'XLX Modern test':<19.19}{'4'}{'https://example.invalid':<124.124}{'20260907':<40.40}{'MMDVM':<40.40}").encode('ascii')
    p=b'RPTC'+rid.to_bytes(4,'big')+cfg
    assert len(p)==302,len(p)
    x=parse_rptc(p); assert x and x['callsign']=='N0CALL' and x['dmr_id']==rid and x['color_code']==1 and x['location']=='Example City',x
    assert abs(x['latitude']+23.3121)<1e-6 and abs(x['longitude']+46.2248)<1e-6,x
    g=b'RPTG'+rid.to_bytes(4,'big')+b'-23.3121-046.2248'
    y=parse_rptg(g);assert y and y['dmr_id']==rid,y
    print(json.dumps(x,ensure_ascii=False));return 0
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--self-test',action='store_true');a=ap.parse_args()
    if a.self_test:return selftest()
    s=socket.socket(socket.AF_PACKET,socket.SOCK_RAW,socket.htons(3));s.bind((IFACE,0));s.settimeout(1)
    print('MMDVM metadata monitor started',flush=True)
    while True:
        try:f=s.recv(4096)
        except socket.timeout:continue
        p=udp_payload(f)
        if not p:continue
        x=parse_rptc(p)
        if x:
            d=load_state();dev=d.setdefault('devices',{});dev[str(x['dmr_id'])]=x;save_state(d)
            print(f"RPTC {x['dmr_id']} {x['callsign']} {x['location']} CC{x['color_code']}",flush=True);continue
        g=parse_rptg(p)
        if g:
            d=load_state();dev=d.setdefault('devices',{});k=str(g['dmr_id']);row=dev.setdefault(k,{'dmr_id':g['dmr_id'],'confidence':'self-declared','source':'MMDVM_RPTG'});row.update(g);save_state(d)
if __name__=='__main__': raise SystemExit(main())
