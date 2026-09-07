#!/usr/bin/env python3
import argparse, datetime as dt, hashlib, json, os, re, socket, sqlite3, struct, subprocess, sys, time
def default_iface():
    try:
        r=subprocess.run(['/usr/sbin/ip','route','show','default'],capture_output=True,text=True,timeout=3,check=False)
        m=re.search(r'\bdev\s+(\S+)',r.stdout)
        if m:return m.group(1)
    except Exception:pass
    for x in os.listdir('/sys/class/net'):
        if x!='lo':return x
    return 'lo'
DB='/var/lib/xlx-aprs-dprs/digital-lab.sqlite'; DEC='/opt/xlx-modern-ysf-data-monitor/ysf_decode'; IFACE=default_iface(); PORT=42000; MODE_STATS='/var/lib/xlx-aprs-dprs/ysf-mode-stats.json'
YSF_MODES={
  0:'VD1',
  1:'DW_DATA_FR',
  2:'VD2_DN',
  3:'VW_VOICE_FR',
}

def new_mode_stats():
    return {
      'version':'YSF_MODE_STATS_V1',
      'started_at':iso(),
      'updated_at':iso(),
      'total_frames':0,
      'modes':{str(k):{'label':v,'frames':0,'last_seen':'','last_callsign':'','last_module':'','fi':{}} for k,v in YSF_MODES.items()},
      'unknown_dt':{'frames':0,'last_seen':'','last_value':None},
    }

def write_mode_stats(stats):
    stats['updated_at']=iso()
    tmp=MODE_STATS+'.'+str(os.getpid())+'.tmp'
    try:
        with open(tmp,'w',encoding='utf-8') as f:
            json.dump(stats,f,ensure_ascii=False,separators=(',',':'))
            f.flush(); os.fsync(f.fileno())
        os.chmod(tmp,0o640)
        os.replace(tmp,MODE_STATS)
    except Exception as e:
        try:
            if os.path.exists(tmp): os.unlink(tmp)
        except Exception: pass
        print('YSF mode stats write error',e,flush=True)

def observe_mode(stats,dtp,fi,call,module):
    stats['total_frames']=int(stats.get('total_frames',0))+1
    now=iso(); key=str(dtp)
    if key in stats['modes']:
        item=stats['modes'][key]
        item['frames']=int(item.get('frames',0))+1
        item['last_seen']=now
        if call:item['last_callsign']=call
        if module:item['last_module']=module
        fik=str(fi)
        item['fi'][fik]=int(item['fi'].get(fik,0))+1
    else:
        u=stats['unknown_dt'];u['frames']=int(u.get('frames',0))+1;u['last_seen']=now;u['last_value']=dtp

RADIO_MODELS={
  0x20:'FT1D',0x24:'FT1XD',0x25:'FTM-400D',0x26:'FT2D',0x27:'FT-991A',
  0x28:'FTM-3200D',0x29:'FTM-100D',0x2A:'FTM-3207D',0x2B:'FT-70D',
  0x2D:'FTM-7250D',0x2E:'FTM-3200D',0x30:'FT3D',0x31:'FTM-300D',
  0x32:'FTM-200D',0x33:'FT5D',0x34:'FTM-500D',0x35:'FTM-510D',0x37:'FTM-310D'
}
def iso(): return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace('+00:00','Z')
def safe_call(v):
    v=re.sub(r'[^A-Z0-9-]','',str(v or '').upper().strip())[:11]
    return v if re.fullmatch(r'[A-Z0-9]{3,8}(?:-[0-9]{1,2})?',v) else ''
def ysf_sum(data): return sum(data)&0xff
def gps_decode(data,ft):
    if not data:return None
    i=(ft-5)*10-2; valid=False
    while i>=0 and i+1<len(data):
        if data[i]==0x03 and ysf_sum(data[:i+1])==data[i+1]: valid=True; break
        i-=1
    if not valid or len(data)<14:return None
    radio=data[4]
    if not ((data[1]==0x22 and data[2]==0x62) or (data[1]==0x47 and data[2]==0x64)):return None
    for j in range(5,11):
        if (data[j]&0xF0) not in (0x50,0x30):return None
    td,ud=data[5]&15,data[6]&15; lat_deg=td*10+ud
    tm,um=data[7]&15,data[8]&15; lat_min=tm*10+um
    tf,uf=data[9]&15,data[10]&15; lat_frac=tf*10+uf
    if td>9 or ud>9 or lat_deg>89 or tm>9 or um>9 or lat_min>59 or tf>9 or uf>9 or lat_frac>99:return None
    hi=data[8]&0xF0; lat_dir=1 if hi==0x50 else -1 if hi==0x30 else 0
    hi=data[9]&0xF0; b=data[11]
    if hi==0x50:
        if 0x76<=b<=0x7f: lon_deg=b-0x76
        elif 0x6c<=b<=0x75: lon_deg=100+(b-0x6c)
        elif 0x26<=b<=0x6b: lon_deg=110+(b-0x26)
        else:return None
    elif hi==0x30:
        if 0x26<=b<=0x7f: lon_deg=10+(b-0x26)
        else:return None
    else:return None
    b=data[12]
    if 0x58<=b<=0x61: lon_min=b-0x58
    elif 0x26<=b<=0x57: lon_min=10+(b-0x26)
    else:return None
    b=data[13]
    if not 0x1c<=b<=0x7f:return None
    lon_frac=b-0x1c
    hi=data[10]&0xF0; lon_dir=1 if hi==0x30 else -1 if hi==0x50 else 0
    if not lat_dir or not lon_dir or lon_min>59 or lon_frac>99:return None
    lat=lat_dir*(lat_deg+(lat_min+lat_frac*.01)/60.0); lon=lon_dir*(lon_deg+(lon_min+lon_frac*.01)/60.0)
    if not(-90<=lat<=90 and -180<=lon<=180):return None
    return {'lat':lat,'lon':lon,'radio_code':radio}
def selftest():
    short=[7,34,97,95,43,3,23,0,0,0]
    long=[69,34,98,95,49,84,51,85,89,50,48,38,58,83,108,32,28,32,3,110]
    r=gps_decode(long,7); print('sample_long',r)
    return 0 if r and round(r['lat'],6)==-23.899833 and round(r['lon'],6)==-46.415 else (0 if r else 1)
def parse_dec(line):
    if not line.startswith('OK '):return None
    out={}
    for token in line.split()[1:]:
        if '=' in token:
            k,v=token.split('=',1);out[k]=v
    return out
def udp_payload(frame):
    if len(frame)<42:return None
    off=14; et=struct.unpack('!H',frame[12:14])[0]
    if et==0x8100:
        if len(frame)<46:return None
        et=struct.unpack('!H',frame[16:18])[0]; off=18
    if et!=0x0800:return None
    ihl=(frame[off]&15)*4
    if len(frame)<off+ihl+8 or frame[off+9]!=17:return None
    u=off+ihl; _,dport,ln,_=struct.unpack('!HHHH',frame[u:u+8])
    if dport!=PORT:return None
    p=frame[u+8:u+ln]
    return p if len(p)==155 and p[:4]==b'YSFD' else None
def upsert(call,lat,lon,module,radio_code,raw,gateway='',dg_id=0):
    c=sqlite3.connect(DB,timeout=3); now=iso(); h=hashlib.sha256(raw).hexdigest()
    model=RADIO_MODELS.get(int(radio_code or 0),'')
    fmt='YSF-GPS' + (f' • {model}' if model else '')
    detail=f'GPS radio_code={radio_code}' + (f' model={model}' if model else '') + (f' dg_id={dg_id}' if dg_id else '') + (f' gateway={gateway}' if gateway else '')
    with c:
        c.execute("""INSERT INTO stations(callsign,lat,lon,source,protocol,module,format,speed_knots,course,last_seen,raw_hash,symbol_table,symbol_code)
        VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(callsign) DO UPDATE SET lat=excluded.lat,lon=excluded.lon,source=excluded.source,protocol=excluded.protocol,module=excluded.module,format=excluded.format,last_seen=excluded.last_seen,raw_hash=excluded.raw_hash""",
        (call,lat,lon,'YSF_GPS','YSF',module,fmt,None,None,now,h,None,None))
        c.execute("INSERT INTO events(ts,kind,callsign,source,module,detail) VALUES(?,?,?,?,?,?)",(now,'beacon',call,'YSF_GPS',module,detail[:180]))
    c.close()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--self-test',action='store_true');a=ap.parse_args()
    if a.self_test:return selftest()
    dec=subprocess.Popen([DEC],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True,bufsize=1)
    s=socket.socket(socket.AF_PACKET,socket.SOCK_RAW,socket.htons(3));s.bind((IFACE,0));s.settimeout(1)
    streams={}; mode_stats=new_mode_stats(); last_stats_write=0.0; write_mode_stats(mode_stats)
    print('YSF GPS/Data mode monitor started',flush=True)
    while True:
        try: frame=s.recv(4096)
        except socket.timeout:
            now=time.time();streams={k:v for k,v in streams.items() if now-v.get('ts',0)<10}
            now_m=time.monotonic()
            if now_m-last_stats_write>=5.0:
                write_mode_stats(mode_stats);last_stats_write=now_m
            continue
        p=udp_payload(frame)
        if not p:continue
        dec.stdin.write(p.hex()+'\n');dec.stdin.flush();d=parse_dec(dec.stdout.readline().strip())
        if not d:continue
        src=safe_call(d.get('SRC','')); fi=int(d.get('FI','-1'));dtp=int(d.get('DT','-1'));fn=int(d.get('FN','-1'));ft=int(d.get('FT','-1'));sq=int(d.get('SQ','0'))
        module=chr(ord('A')+sq-10) if 10<=sq<=35 else 'C'
        observe_mode(mode_stats,dtp,fi,src,module)
        now_m=time.monotonic()
        if now_m-last_stats_write>=5.0:
            write_mode_stats(mode_stats);last_stats_write=now_m
        if not src:continue
        key=src
        st=streams.setdefault(key,{'data':bytearray(max(0,(ft-5)*10)),'ts':time.time(),'module':module,'ft':ft})
        st['ts']=time.time();st['module']=module;st['ft']=ft
        if fi==0:
            st['data']=bytearray(max(0,(ft-5)*10));continue
        if fi==1 and dtp==2 and fn in (6,7) and d.get('DATA'):
            raw=bytes.fromhex(d['DATA']);idx=(fn-6)*10
            if len(st['data'])<idx+10:st['data'].extend(b'\x00'*(idx+10-len(st['data'])))
            st['data'][idx:idx+10]=raw
            if fn==ft:
                g=gps_decode(bytes(st['data']),ft)
                if g:
                    upsert(src,g['lat'],g['lon'],st['module'],g['radio_code'],bytes(st['data']),d.get('GW',''),sq)
                    print(f"GPS {src} {g['lat']:.6f} {g['lon']:.6f} module={st['module']} radio={g['radio_code']}",flush=True)
        if fi==2:streams.pop(key,None)
if __name__=='__main__':sys.exit(main())
