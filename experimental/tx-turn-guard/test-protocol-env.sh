#!/usr/bin/env bash
set -Eeuo pipefail

SRC="${1:-}"
if [[ -z "$SRC" || ! -d "$SRC/src" ]]; then
  echo "Uso: $0 /caminho/para/checkout/xlxd-ja-patcheado" >&2
  exit 2
fi

ROOT="$(cd -- "$SRC" && pwd)"
BUILD="$ROOT/src"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# The normal candidate build must exist first. This test never installs it.
[[ -x "$BUILD/xlxd" ]] || { echo "ERRO: compile primeiro com apply-and-build.sh" >&2; exit 3; }

cat > "$TMP/txturn_unit.cpp" <<'CPP'
#include "main.h"
#define protected public
#include "creflector.h"
#include "cpacketstream.h"
#include "cdcsprotocol.h"
#include "cysfprotocol.h"
#include "cdmrmmdvmprotocol.h"
#include "cdcsclient.h"
#include "cysfclient.h"
#include "cdmrmmdvmclient.h"
#undef protected
#include <cassert>
#include <atomic>
#include <thread>
#include <functional>
#include <cstring>
#include "cdmriddirhttp.h"
static CDvHeaderPacket header(const char* user, unsigned id, unsigned sid) {
 CCallsign my(user,id),ur("CQCQCQ"),rpt1("PU2TST",7246000),rpt2("XLX026");
 rpt1.SetModule('B');rpt2.SetModule('C');return CDvHeaderPacket(my,ur,rpt1,rpt2,sid,0);
}
static void drain(CPacketStream* stream) {
 stream->Lock();while(!stream->empty()){delete stream->front();stream->pop();}stream->Unlock();
}
static void eot(CProtocol &p,CPacketStream *stream,const CIp &ip){
 std::atomic<bool> done(false);
 std::thread router([&]{while(!done){drain(stream);std::this_thread::yield();}});
 struct dstar_dvframe f={};auto *last=new CDvLastFramePacket(&f,stream->GetStreamId(),0x40);
 p.OnDvLastFramePacketIn(last,&ip);
 done=true;router.join();assert(!stream->IsOpen());p.m_Streams.clear();
}
int main(){
 setenv("XLX_TX_TURN_GUARD","1",1);g_Reflector.SetCallsign(CCallsign("XLX026"));
 const char *ids="7246001;PU2AAA\n7246002;PY2BBB\n7246003;PY2CCC\n7246000;PU2TST\n";
 CBuffer db;db.Set((const uint8*)ids,strlen(ids)+1);assert(g_DmridDir.RefreshContent(db));
 CDcsProtocol dcs;CYsfProtocol ysf;CDmrmmdvmProtocol dmr;
 dcs.m_ReflectorCallsign=ysf.m_ReflectorCallsign=dmr.m_ReflectorCallsign=CCallsign("XLX026");
 CIp ip("127.0.0.1");ip.SetPort(htons(15000));
 auto run=[&](int proto,CProtocol &base,std::function<CDvHeaderPacket*(CDvHeaderPacket&)> decode,std::function<bool(CDvHeaderPacket*)> admit){
  const int c=g_Reflector.GetModuleIndex('C');g_Reflector.m_TxTurnGuard[c]=CReflector::STxTurnGuardState();
  CClient *client=nullptr;
  if(proto==PROTOCOL_DCS)client=new CDcsClient(CCallsign("PU2TST"),ip,'C');
  if(proto==PROTOCOL_YSF)client=new CYsfClient(CCallsign("PU2TST"),ip,'C');
  if(proto==PROTOCOL_DMRMMDVM)client=new CDmrmmdvmClient(CCallsign("PU2TST",7246000),ip,'C');
  g_Reflector.GetClients()->AddClient(client);g_Reflector.ReleaseClients();
  auto one=[&](const char*name,unsigned id,unsigned sid,bool accepted){
   auto h=header(name,id,sid);auto parsed=decode(h);assert(parsed);
   assert(admit(parsed)==accepted);
   if(accepted){assert(client->IsAMaster());eot(base,&g_Reflector.m_Streams[c],ip);}
   else assert(!client->IsAMaster());
  };
  one("PU2AAA",7246001,101,true);one("PY2BBB",7246002,102,true);one("PU2AAA",7246001,103,true);
  auto deadline=g_Reflector.m_TxTurnGuard[c].cooldownUntil;
  one("PY2BBB",7246002,104,false);one("PU2AAA",7246001,105,false);
  assert(g_Reflector.m_TxTurnGuard[c].cooldownUntil==deadline);
  client->Alive();assert(client->IsAlive()); // keepalive remains independent while blocked
  one("PY2CCC",7246003,106,true);assert(!g_Reflector.m_TxTurnGuard[c].pairActive);
  // Authoritative inactivity and TOT teardown use the same protocol path.
  for(bool tot:{false,true}){
   auto h=header("PU2AAA",7246001,tot?108:107);assert(admit(decode(h)));
   auto *stream=&g_Reflector.m_Streams[c];const auto actualSid=stream->GetStreamId();drain(stream);
   if(tot)stream->m_OpenTime.m_TimePoint=std::chrono::steady_clock::now()-std::chrono::seconds(181);
   else stream->m_LastPacketTime.m_TimePoint=std::chrono::steady_clock::now()-std::chrono::seconds(3);
   base.CheckStreamsTimeout();assert(!stream->IsOpen());assert(!client->IsAMaster());
   if(tot){assert(g_Reflector.IsTotBlocked(actualSid,&ip));g_Reflector.ReleaseTotBlock(actualSid,&ip);}
  }
  g_Reflector.GetClients()->RemoveClient(client);g_Reflector.ReleaseClients();
  std::cout<<"protocol_decode_admit_eot_timeout_tot=PASS protocol="<<proto<<std::endl;
 };
 run(PROTOCOL_DCS,dcs,[&](CDvHeaderPacket&h){
  struct dstar_dvframe v={};CDvFramePacket frame(&v,h.GetStreamId(),0);CBuffer b;dcs.EncodeDvPacket(h,frame,0,&b);
  CDvHeaderPacket *out=nullptr;CDvFramePacket *f=nullptr;assert(dcs.IsValidDvPacket(b,&out,&f));delete f;
  CBuffer last;dcs.EncodeDvLastPacket(h,frame,1,&last);CDvHeaderPacket *lh=nullptr;assert(dcs.IsValidDvPacket(last,&lh,&f));assert(f->IsLastPacket());delete f;delete lh;return out;
 },[&](CDvHeaderPacket*h){return dcs.OnDvHeaderPacketIn(h,ip);});
 run(PROTOCOL_YSF,ysf,[&](CDvHeaderPacket&h){
  CBuffer b;assert(ysf.EncodeDvHeaderPacket(h,&b));CYSFFICH fich;assert(ysf.IsValidDvPacket(b,&fich));
  CDvHeaderPacket*out=nullptr;CDvFramePacket*frames[5]={};assert(ysf.IsValidDvHeaderPacket(ip,fich,b,&out,frames));delete frames[0];delete frames[1];
  CBuffer last;assert(ysf.EncodeDvLastPacket(h,&last));assert(ysf.IsValidDvPacket(last,&fich));assert(ysf.IsValidDvLastFramePacket(ip,fich,last,frames));delete frames[0];delete frames[1];return out;
 },[&](CDvHeaderPacket*h){return ysf.OnDvHeaderPacketIn(h,ip);});
 run(PROTOCOL_DMRMMDVM,dmr,[&](CDvHeaderPacket&h){
  CBuffer b;assert(dmr.EncodeDvHeaderPacket(h,0,&b));CDvHeaderPacket*out=nullptr;uint8 cmd=0,call=0;assert(dmr.IsValidDvHeaderPacket(b,&out,&cmd,&call));assert(call==DMR_GROUP_CALL);
  CBuffer last;dmr.EncodeDvLastPacket(h,1,&last);CDvLastFramePacket*f=nullptr;assert(dmr.IsValidDvLastFramePacket(last,&f));delete f;return out;
 },[&](CDvHeaderPacket*h){return dmr.OnDvHeaderPacketIn(h,ip,0,DMR_GROUP_CALL);});
 std::cout<<"tx_turn_protocol_synthetic_env=PASS\n";
}

CPP

# main.cpp owns globals needed by the XLXD objects. Rename only its entry point.
g++ -c -std=c++11 -pthread -iquote "$BUILD" -Dmain=xlxd_original_main "$BUILD/main.cpp" -o "$TMP/main-test.o"
g++ -c -std=c++11 -pthread -iquote "$BUILD" "$TMP/txturn_unit.cpp" -o "$TMP/txturn_unit.o"

objects=()
while IFS= read -r obj; do
  [[ "$(basename "$obj")" == "main.o" ]] && continue
  objects+=("$obj")
done < <(find "$BUILD" -maxdepth 1 -type f -name '*.o' | sort)

[[ ${#objects[@]} -gt 10 ]] || { echo "ERRO: objetos do build XLXD não encontrados" >&2; exit 4; }
g++ -std=c++11 -pthread "$TMP/txturn_unit.o" "$TMP/main-test.o" "${objects[@]}" -o "$TMP/txturn_unit"
"$TMP/txturn_unit"
