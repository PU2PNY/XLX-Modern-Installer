#!/usr/bin/env python3
import argparse, datetime as dt, hashlib, json, os, re, socket, sqlite3, struct, subprocess, tempfile, time
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
DB='/var/lib/xlx-aprs-dprs/digital-lab.sqlite'
STATE='/var/lib/xlx-modern-dmr-data/state.json'
BPTC_HELPER='/opt/xlx-modern-dmr-data-monitor/dmr_bptc_decode'
DPF_NAMES={0:'UDT',1:'RESPONSE',2:'UNCONFIRMED',3:'CONFIRMED',13:'DEFINED_SHORT',14:'DEFINED_RAW',15:'PROPRIETARY'}
UDT_FORMATS={0:'BINARY',1:'MS_OR_TG_ADDRESS',2:'BCD_4BIT',3:'ISO_7BIT',4:'ISO_8BIT',5:'NMEA',6:'IP_ADDRESS',7:'UNICODE_16',8:'MANUFACTURER',9:'MANUFACTURER',10:'MIXED'}
DMRID='/xlxd/dmrid.dat'
TYPE_NAMES={3:'CSBK',6:'DATA_HEADER',7:'RATE_1_2',8:'RATE_3_4',10:'RATE_1'}
CALL_RE=re.compile(r'^[A-Z0-9]{3,8}$')

def iso(): return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace('+00:00','Z')
def bits_byte(b): return [bool(b & (0x80>>i)) for i in range(8)]
def byte_bits(bits):
    v=0
    for i,x in enumerate(bits[:8]):
        if x:v|=0x80>>i
    return v

def qr_codeword(value):
    # QR(16,7,6) 15-bit systematic word used by DMR EMB, generator 0x139.
    p=(value & 0x7f)<<8
    rem=p
    while rem.bit_length()>8:
        rem ^= 0x139 << (rem.bit_length()-9)
    return p | rem
QR_WORDS=[qr_codeword(v) for v in range(128)]
def qr_decode(emb0,emb1):
    recv=(emb0<<7)|(emb1>>1)
    best_v=None;best_d=99
    for v,cw in enumerate(QR_WORDS):
        d=(recv^cw).bit_count()
        if d<best_d: best_v,best_d=v,d
    if best_d>2:return None
    return {'value':best_v,'distance':best_d,'cc':(best_v>>3)&0x0f,'pi':bool((best_v>>2)&1),'lcss':best_v&3}
def qr_encode(cc,lcss,pi=False):
    value=((cc&0xf)<<3)|((1 if pi else 0)<<2)|(lcss&3)
    cw=qr_codeword(value)
    return (cw>>7)&0xff, ((cw&0x7f)<<1)&0xfe

def hamming16114_decode(d):
    c0=d[0]^d[1]^d[2]^d[3]^d[5]^d[7]^d[8]
    c1=d[1]^d[2]^d[3]^d[4]^d[6]^d[8]^d[9]
    c2=d[2]^d[3]^d[4]^d[5]^d[7]^d[9]^d[10]
    c3=d[0]^d[1]^d[2]^d[4]^d[6]^d[7]^d[10]
    c4=d[0]^d[2]^d[5]^d[6]^d[8]^d[9]^d[10]
    n=(1 if c0!=d[11] else 0)|(2 if c1!=d[12] else 0)|(4 if c2!=d[13] else 0)|(8 if c3!=d[14] else 0)|(16 if c4!=d[15] else 0)
    mp={1:11,2:12,4:13,8:14,16:15,0x19:0,0x0b:1,0x1f:2,0x07:3,0x0e:4,0x15:5,0x1a:6,0x0d:7,0x13:8,0x16:9,0x1c:10}
    if n==0:return True
    if n not in mp:return False
    d[mp[n]]=not d[mp[n]];return True
def hamming16114_encode(d):
    d[11]=d[0]^d[1]^d[2]^d[3]^d[5]^d[7]^d[8]
    d[12]=d[1]^d[2]^d[3]^d[4]^d[6]^d[8]^d[9]
    d[13]=d[2]^d[3]^d[4]^d[5]^d[7]^d[9]^d[10]
    d[14]=d[0]^d[1]^d[2]^d[4]^d[6]^d[7]^d[10]
    d[15]=d[0]^d[2]^d[5]^d[6]^d[8]^d[9]^d[10]

def crc5_payload(bits72):
    return sum(byte_bits(bits72[i:i+8]) for i in range(0,72,8))%31

class Embedded:
    def __init__(self): self.raw=[False]*128; self.state=0
    def reset(self): self.raw=[False]*128; self.state=0
    def add(self,burst,lcss):
        if len(burst)!=33:return None
        rb=[]
        for x in burst[14:19]: rb.extend(bits_byte(x))
        block=rb[4:36]
        if lcss==1:
            self.raw[0:32]=block;self.state=1;return None
        if lcss==3 and self.state==1:
            self.raw[32:64]=block;self.state=2;return None
        if lcss==3 and self.state==2:
            self.raw[64:96]=block;self.state=3;return None
        if lcss==2 and self.state==3:
            self.raw[96:128]=block;self.state=0
            return self.decode()
        return None
    def decode(self):
        matrix=[False]*128;b=0
        for a in range(128):
            matrix[b]=self.raw[a];b+=16
            if b>127:b-=127
        for a in range(0,112,16):
            row=matrix[a:a+16]
            if not hamming16114_decode(row):return None
            matrix[a:a+16]=row
        for a in range(16):
            if matrix[a]^matrix[a+16]^matrix[a+32]^matrix[a+48]^matrix[a+64]^matrix[a+80]^matrix[a+96]^matrix[a+112]:return None
        payload=[]
        for start,end in ((0,11),(16,27),(32,42),(48,58),(64,74),(80,90),(96,106)):payload.extend(matrix[start:end])
        crc=(16 if matrix[42] else 0)+(8 if matrix[58] else 0)+(4 if matrix[74] else 0)+(2 if matrix[90] else 0)+(1 if matrix[106] else 0)
        if crc5_payload(payload)!=crc:return None
        raw=bytes(byte_bits(payload[i:i+8]) for i in range(0,72,8))
        return {'flco':raw[0]&0x3f,'raw':raw}

def encode_embedded(raw9,cc=1):
    # Self-test generator: inverse of the decoder, matching ETSI embedded LC layout.
    p=[]
    for x in raw9:p.extend(bits_byte(x))
    m=[False]*128;crc=crc5_payload(p)
    m[106]=bool(crc&1);m[90]=bool(crc&2);m[74]=bool(crc&4);m[58]=bool(crc&8);m[42]=bool(crc&16)
    b=0
    for start,end in ((0,11),(16,27),(32,42),(48,58),(64,74),(80,90),(96,106)):
        for a in range(start,end):m[a]=p[b];b+=1
    for a in range(0,112,16):
        row=m[a:a+16];hamming16114_encode(row);m[a:a+16]=row
    for a in range(16):m[a+112]=m[a]^m[a+16]^m[a+32]^m[a+48]^m[a+64]^m[a+80]^m[a+96]
    packed=[False]*128;b=0
    for a in range(128):
        packed[a]=m[b];b+=16
        if b>127:b-=127
    out=[]
    for n,lcss in enumerate((1,3,3,2)):
        rb=[False]*40;rb[4:36]=packed[n*32:(n+1)*32]
        five=[byte_bits(rb[i:i+8]) for i in range(0,40,8)]
        burst=bytearray(33);burst[14:19]=bytes(five)
        e0,e1=qr_encode(cc,lcss)
        burst[13]=(burst[13]&0xf0)|((e0>>4)&0x0f)
        burst[14]=(burst[14]&0x0f)|((e0<<4)&0xf0)
        burst[18]=(burst[18]&0xf0)|((e1>>4)&0x0f)
        burst[19]=(burst[19]&0x0f)|((e1<<4)&0xf0)
        out.append(bytes(burst))
    return out

def decode_gps(raw):
    if len(raw)!=9 or (raw[0]&0x3f)!=8:return None
    err=(raw[2]&0x0e)>>1
    errtxt={0:'<2m',1:'<20m',2:'<200m',3:'<2km',4:'<20km',5:'<200km',6:'>200km'}.get(err,'unknown')
    lv=((raw[2]&1)<<24)|(raw[3]<<16)|(raw[4]<<8)|raw[5]
    if lv&(1<<24):lv-=1<<25
    av=(raw[6]<<16)|(raw[7]<<8)|raw[8]
    if av&(1<<23):av-=1<<24
    lon=lv*(360.0/(1<<25));lat=av*(180.0/(1<<24))
    if not(-90<=lat<=90 and -180<=lon<=180):return None
    if abs(lat)<1e-7 and abs(lon)<1e-7:return None
    return {'lat':lat,'lon':lon,'error':errtxt}
def encode_gps(lat,lon):
    raw=bytearray(9);raw[0]=8
    lv=round(lon/(360.0/(1<<25))) & ((1<<25)-1)
    av=round(lat/(180.0/(1<<24))) & ((1<<24)-1)
    raw[2]|=(lv>>24)&1;raw[3]=(lv>>16)&255;raw[4]=(lv>>8)&255;raw[5]=lv&255
    raw[6]=(av>>16)&255;raw[7]=(av>>8)&255;raw[8]=av&255
    return bytes(raw)

class TalkerAlias:
    def __init__(self):self.buf=bytearray(32);self.blocks=set()
    def add(self,bid,data7):
        if bid not in range(4) or len(data7)!=7:return None
        self.buf[bid*7:bid*7+7]=data7;self.blocks.add(bid)
        size=(self.buf[0]>>1)&0x1f;fmt=(self.buf[0]>>6)&3
        if size==0 or size>31:return None
        if fmt in (1,2):
            avail=max(self.blocks)*7+7 if self.blocks else 0
            if avail<1+size:return None
            raw=bytes(self.buf[1:1+size]);txt=raw.decode('latin1' if fmt==1 else 'utf-8','replace')
        elif fmt==3:
            need=1+size*2
            if (max(self.blocks)*7+7 if self.blocks else 0)<need:return None
            chars=[]
            for i in range(size):
                hi=self.buf[2*i+1];lo=self.buf[2*i+2];chars.append(chr(lo) if hi==0 else '?')
            txt=''.join(chars)
        else:
            # Same 7-bit bitstream convention as MMDVMHost: skip first decoded septet.
            bits=[]
            for x in self.buf:bits.extend(bits_byte(x))
            sept=[]
            for i in range(0,len(bits)-6,7):sept.append(sum((1<<(6-j)) if bits[i+j] else 0 for j in range(7)))
            txt=''.join(chr(x) for x in sept[1:1+size])
        txt=''.join(ch for ch in txt if ch.isprintable()).strip()
        return txt if len(txt)>=size and txt else None

def udp_payload(frame):
    if len(frame)<42:return None
    off=14;et=struct.unpack('!H',frame[12:14])[0]
    if et==0x8100:
        if len(frame)<46:return None
        et=struct.unpack('!H',frame[16:18])[0];off=18
    if et!=0x0800:return None
    ihl=(frame[off]&15)*4
    if len(frame)<off+ihl+8 or frame[off+9]!=17:return None
    u=off+ihl;sport,dport,ln,_=struct.unpack('!HHHH',frame[u:u+8])
    if dport!=PORT:return None
    return frame[u+8:u+ln]
def parse_dmr(p):
    if len(p)!=55 or p[:4]!=b'DMRD':return None
    bit=p[15]
    return {'src':int.from_bytes(p[5:8],'big'),'dst':int.from_bytes(p[8:11],'big'),'rpt':int.from_bytes(p[11:15],'big'),
            'frame_type':(bit&0x30)>>4,'slot':2 if bit&0x80 else 1,'private':bool(bit&0x40),'subtype':bit&0x0f,
            'stream':p[16:20].hex(),'burst':p[20:53],'raw':p}
def module_for_tg(tg):return chr(ord('A')+tg-4001) if 4001<=tg<=4005 else ''
def bptc_decode(mode,burst):
    try:
        r=subprocess.run([BPTC_HELPER,mode,bytes(burst).hex()],capture_output=True,text=True,timeout=1)
        line=(r.stdout or '').strip()
        if r.returncode!=0 or not line.startswith('VALID '):return None
        out={}
        for tok in line.split()[1:]:
            if '=' not in tok:continue
            k,v=tok.split('=',1);out[k]=v
        return out
    except Exception:
        return None

def record_data_header(state,d,h,now):
    dh=state.setdefault('data_headers',{})
    stats=dh.setdefault('stats',{'valid':0,'invalid':0,'by_dpf':{},'by_udt_format':{}})
    stats['valid']=int(stats.get('valid',0))+1
    dpf=int(h.get('dpf','-1')); name=DPF_NAMES.get(dpf,f'DPF_{dpf}')
    bd=stats.setdefault('by_dpf',{});bd[name]=int(bd.get(name,0))+1
    fmt=int(h.get('format','-1'));fmt_name=UDT_FORMATS.get(fmt,f'FORMAT_{fmt}') if dpf==0 else ''
    if fmt_name:
        bf=stats.setdefault('by_udt_format',{});bf[fmt_name]=int(bf.get(fmt_name,0))+1
    dh['last']={'last_seen':now,'dmr_id':d['src'],'callsign':'','dst':int(h.get('dst',d['dst'])),'slot':d['slot'],'private':d['private'],'dpf':name,'blocks':int(h.get('blocks','0')),'sap':int(h.get('sap','0')),'udt_format':fmt_name}
    return dh['last']

def load_ids():
    d={}
    try:
        with open(DMRID,'r',encoding='ascii',errors='ignore') as f:
            for line in f:
                a=line.strip().strip('\r').split(';')
                if len(a)>=2 and a[0].isdigit():
                    c=a[1].strip().upper()
                    if CALL_RE.fullmatch(c):d[int(a[0])]=c
    except Exception:pass
    return d
def load_state():
    try:
        d=json.load(open(STATE));return d if isinstance(d,dict) else {}
    except:return {}
def save_state(d):
    os.makedirs(os.path.dirname(STATE),exist_ok=True);d['generated_at']=iso()
    fd,tmp=tempfile.mkstemp(prefix='.state.',dir=os.path.dirname(STATE))
    try:
        with os.fdopen(fd,'w') as f:json.dump(d,f,ensure_ascii=False,separators=(',',':'));f.flush();os.fsync(f.fileno())
        os.chmod(tmp,0o640);os.replace(tmp,STATE)
    finally:
        try:os.unlink(tmp)
        except:pass
def write_gps(call,src,dst,gps,raw):
    now=iso();mod=module_for_tg(dst);h=hashlib.sha256(raw).hexdigest();detail=f"DMR ID {src} · TG {dst} · Embedded GPS · precisão {gps['error']}"
    c=sqlite3.connect(DB,timeout=3)
    try:
        c.execute('PRAGMA busy_timeout=3000')
        c.execute("""INSERT INTO stations(callsign,lat,lon,source,protocol,module,format,speed_knots,course,last_seen,raw_hash,symbol_table,symbol_code)
          VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(callsign) DO UPDATE SET lat=excluded.lat,lon=excluded.lon,source=excluded.source,protocol=excluded.protocol,module=excluded.module,format=excluded.format,last_seen=excluded.last_seen,raw_hash=excluded.raw_hash""",
          (call,gps['lat'],gps['lon'],'DMR_GPS','DMR',mod,'DMR Embedded GPS',None,None,now,h,None,None))
        c.execute('INSERT INTO events(ts,kind,callsign,source,module,detail) VALUES(?,?,?,?,?,?)',(now,'beacon',call,'DMR_GPS',mod,detail[:180]));c.commit()
    finally:c.close()
def write_ta(call,src,dst,alias):
    c=sqlite3.connect(DB,timeout=3);now=iso();mod=module_for_tg(dst)
    try:
        c.execute('PRAGMA busy_timeout=3000');c.execute('INSERT INTO events(ts,kind,callsign,source,module,detail) VALUES(?,?,?,?,?,?)',(now,'talker-alias',call or None,'DMR_TA',mod,f"DMR ID {src} · TG {dst} · Talker Alias: {alias}"[:180]));c.commit()
    finally:c.close()
def selftest():
    # QR must correct up to three bit errors in the 15-bit protected word.
    e0,e1=qr_encode(1,3);q=qr_decode(e0,e1);assert q and q['cc']==1 and q['lcss']==3,q
    # Exhaustive correction contract: every codeword, every 1-bit and 2-bit corruption.
    for v,cw in enumerate(QR_WORDS):
        for i in range(15):
            r=cw^(1<<i);qq=qr_decode((r>>7)&255,((r&127)<<1)&254);assert qq and qq['value']==v,(v,i,qq)
        for i in range(15):
            for j in range(i+1,15):
                r=cw^(1<<i)^(1<<j);qq=qr_decode((r>>7)&255,((r&127)<<1)&254);assert qq and qq['value']==v,(v,i,j,qq)
    lat,lon=-23.3121,-46.2248;raw=encode_gps(lat,lon);emb=Embedded();got=None
    for burst,lcss in zip(encode_embedded(raw,1),(1,3,3,2)):got=emb.add(burst,lcss) or got
    assert got and got['flco']==8,got
    gps=decode_gps(got['raw']);assert gps and abs(gps['lat']-lat)<0.001 and abs(gps['lon']-lon)<0.001,gps
    alias='N0CALL';ctrl=((1<<6)|(len(alias)<<1));ta_raw=bytes([4,0,ctrl])+alias.encode('ascii')
    ta_raw=ta_raw.ljust(9,b'\0');emb=Embedded();decoded=None
    for burst,lcss in zip(encode_embedded(ta_raw,1),(1,3,3,2)):decoded=emb.add(burst,lcss) or decoded
    assert decoded and decoded['flco']==4,decoded
    ta=TalkerAlias();txt=ta.add(0,decoded['raw'][2:9]);assert txt==alias,(txt,decoded)
    raw2=encode_gps(43.986667,10.509167);emb2=Embedded();got2=None
    for burst,lcss in zip(encode_embedded(raw2,1),(1,3,3,2)):got2=emb2.add(burst,lcss) or got2
    gps2=decode_gps(got2['raw']);assert gps2 and abs(gps2['lat']-43.986667)<0.001 and abs(gps2['lon']-10.509167)<0.001,gps2
    print(json.dumps({'gps_negative':gps,'gps_positive':gps2,'talker_alias':txt,'qr_exhaustive':'1-2 bit errors OK'},ensure_ascii=False));return 0
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--self-test',action='store_true');args=ap.parse_args()
    if args.self_test:return selftest()
    ids=load_ids();state=load_state();state.setdefault('counters',{});state.setdefault('talker_alias',{});state.setdefault('gps',{});state.setdefault('data_headers',{});state.setdefault('metrics',{})
    metrics=state['metrics']
    for k in ('dmrd','voice','voice_sync','qr_ok','qr_fail','embedded_valid'): metrics.setdefault(k,0)
    metrics.setdefault('lcss',{});metrics.setdefault('flco',{})
    streams={};tas={};data_sessions={};lastsave=0;last_id_check=0
    try:id_mtime=os.path.getmtime(DMRID)
    except OSError:id_mtime=0
    def housekeeping(force=False):
        nonlocal ids,id_mtime,lastsave,last_id_check
        now_t=time.time()
        if force or now_t-lastsave>=60:
            save_state(state);lastsave=now_t
        if force or now_t-last_id_check>=60:
            last_id_check=now_t
            try:new_mtime=os.path.getmtime(DMRID)
            except OSError:new_mtime=0
            if new_mtime!=id_mtime:
                new_ids=load_ids()
                if new_ids:
                    ids=new_ids;id_mtime=new_mtime
                    print(f'DMRID map reloaded ids={len(ids)}',flush=True)
    s=socket.socket(socket.AF_PACKET,socket.SOCK_RAW,socket.htons(3));s.bind((IFACE,0));s.settimeout(1)
    print(f'DMR data monitor started ids={len(ids)}',flush=True)
    housekeeping(force=True)
    while True:
        try:frame=s.recv(4096)
        except socket.timeout:
            housekeeping();continue
        housekeeping()
        p=udp_payload(frame)
        if not p:continue
        d=parse_dmr(p)
        if not d:continue
        metrics['dmrd']+=1
        now=iso();metrics['last_seen']=now;key=f"{d['src']}:{d['stream']}:{d['slot']}"
        if d['frame_type']==2 and d['subtype'] in TYPE_NAMES:
            name=TYPE_NAMES[d['subtype']];c=state['counters'].setdefault(name,{'count':0,'last_seen':''});c['count']+=1;c['last_seen']=now
            if d['subtype']==6:
                h=bptc_decode('header',d['burst'])
                if h:
                    meta=record_data_header(state,d,h,now);meta['callsign']=ids.get(d['src'],'')
                    data_sessions[key]={'header':meta,'blocks_seen':0,'expected':int(h.get('blocks','0')),'last_seen':time.time()}
                    print(f"DATA_HEADER {meta['callsign'] or d['src']} {meta['dpf']} {meta['udt_format'] or '-'} blocks={meta['blocks']} dst={meta['dst']}",flush=True)
                else:
                    st=state.setdefault('data_headers',{}).setdefault('stats',{'valid':0,'invalid':0,'by_dpf':{},'by_udt_format':{}});st['invalid']=int(st.get('invalid',0))+1
            elif d['subtype']==7 and key in data_sessions:
                blk=bptc_decode('block',d['burst'])
                if blk:
                    sess=data_sessions[key];sess['blocks_seen']=int(sess.get('blocks_seen',0))+1;sess['last_seen']=time.time()
                    state.setdefault('data_headers',{})['last_session']={'last_seen':now,'callsign':sess['header'].get('callsign',''),'dmr_id':d['src'],'dpf':sess['header'].get('dpf',''),'udt_format':sess['header'].get('udt_format',''),'expected_blocks':sess.get('expected',0),'blocks_seen':sess['blocks_seen'],'complete':bool(sess.get('expected',0) and sess['blocks_seen']>=sess.get('expected',0))}
            # Remove stale data sessions without retaining payload content.
            for sk in list(data_sessions):
                if time.time()-data_sessions[sk].get('last_seen',0)>30:data_sessions.pop(sk,None)
        if d['frame_type'] not in (0,1):
            if time.time()-lastsave>10:save_state(state);lastsave=time.time()
            continue
        metrics['voice']+=1
        if d['frame_type']==1: metrics['voice_sync']+=1
        burst=d['burst'];e0=((burst[13]<<4)&0xf0)|((burst[14]>>4)&0x0f);e1=((burst[18]<<4)&0xf0)|((burst[19]>>4)&0x0f);q=qr_decode(e0,e1)
        if not q:
            metrics['qr_fail']+=1;continue
        metrics['qr_ok']+=1;lk=str(q['lcss']);metrics['lcss'][lk]=metrics['lcss'].get(lk,0)+1
        emb=streams.setdefault(key,Embedded());decoded=emb.add(burst,q['lcss'])
        if not decoded:continue
        metrics['embedded_valid']+=1
        flco=decoded['flco'];fk=str(flco);metrics['flco'][fk]=metrics['flco'].get(fk,0)+1
        raw=decoded['raw'];call=ids.get(d['src'],'')
        if flco==8:
            gps=decode_gps(raw)
            if gps:
                rec={'dmr_id':d['src'],'callsign':call,'tg':d['dst'],'module':module_for_tg(d['dst']),'lat':round(gps['lat'],6),'lon':round(gps['lon'],6),'error':gps['error'],'last_seen':now}
                state['gps'][str(d['src'])]=rec
                if call:write_gps(call,d['src'],d['dst'],gps,d['raw']);print(f"GPS {call} {gps['lat']:.6f},{gps['lon']:.6f} TG{d['dst']} {gps['error']}",flush=True)
                else:print(f"GPS DMRID={d['src']} unresolved {gps['lat']:.6f},{gps['lon']:.6f}",flush=True)
        elif 4<=flco<=7:
            ta=tas.setdefault(d['src'],TalkerAlias());alias=ta.add(flco-4,raw[2:9])
            if alias:
                old=state['talker_alias'].get(str(d['src']),{}).get('alias')
                state['talker_alias'][str(d['src'])]={'dmr_id':d['src'],'callsign':call,'alias':alias,'tg':d['dst'],'module':module_for_tg(d['dst']),'last_seen':now,'confidence':'radio-reported'}
                if alias!=old:write_ta(call,d['src'],d['dst'],alias);print(f"TA {call or d['src']} = {alias}",flush=True)
        if len(streams)>512:
            streams.clear()
        if time.time()-lastsave>10:save_state(state);lastsave=time.time()
if __name__=='__main__':raise SystemExit(main())
