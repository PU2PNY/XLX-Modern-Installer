#include "main.h"
#define protected public
#include "creflector.h"
#include "cpacketstream.h"
#undef protected
#include <cassert>
#include <cstdlib>
#include <iostream>
#include <chrono>
#include <string>
#include <cstdio>
using Clock=std::chrono::steady_clock;
static CDvHeaderPacket hdr(const char *who, char module, uint16 sid) {
  CCallsign my(who),ur("CQCQCQ"),rpt1("XLX026"),rpt2("XLX026");
  rpt1.SetModule(module); rpt2.SetModule(module);
  return CDvHeaderPacket(my,ur,rpt1,rpt2,sid,0);
}
static void close_tx(CReflector &r, char mod, const CDvHeaderPacket &h) {
  int n=r.GetModuleIndex(mod);
  r.m_Streams[n].m_DvHeader=h;
  r.TxTurnGuardClosed(&r.m_Streams[n]);
}
int main(){
  setenv("XLX_TX_TURN_GUARD","1",1);
  setenv("XLX_TX_TURN_POLICY","participants",1);
  setenv("XLX_TX_TURN_TRIGGER_MS","3000",1);
  setenv("XLX_TX_TURN_COOLDOWN_MS","7000",1);
  setenv("XLX_TX_TURN_RESET_MS","60000",1);
  unsetenv("XLX_TX_TURN_STATE_DIR");
  CReflector r;
  int c=r.GetModuleIndex('C'),d=r.GetModuleIndex('D');
  assert(c>=0&&d>=0);
  auto A=hdr("PU2AAA",'C',10),B=hdr("PY2BBB",'C',11),C=hdr("PU2CCC",'C',12),D=hdr("PY2DDD",'C',13), E=hdr("PY2EEE",'C',14);
  for (auto h: {A,B,C,D}) {assert(r.TxTurnGuardAdmit(&h));close_tx(r,'C',h);}
  auto &s=r.m_TxTurnParticipants[c];
  assert(s.participants.size()==4);
  assert(!r.TxTurnGuardAdmit(&A));
  assert(!r.TxTurnGuardAdmit(&B));
  assert(s.penaltyUntil.size()==2);
  auto first=s.penaltyUntil.at("PU2AAA"),second=s.penaltyUntil.at("PY2BBB");
  assert(!r.TxTurnGuardAdmit(&A));
  assert(s.penaltyUntil.at("PU2AAA")==first);
  assert(s.penaltyUntil.at("PY2BBB")==second);
  assert(r.TxTurnGuardAdmit(&E));
  close_tx(r,'C',E);
  assert(s.participants.size()==5);
  assert(!r.TxTurnGuardAdmit(&E));
  auto other=hdr("PU2AAA",'D',21);
  assert(r.TxTurnGuardAdmit(&other));
  s.lastCloseAt=Clock::now()-std::chrono::milliseconds(3001);
  assert(r.TxTurnGuardAdmit(&C));
  close_tx(r,'C',C);
  s.lastCloseAt=Clock::now()-std::chrono::milliseconds(2990);
  assert(!r.TxTurnGuardAdmit(&D));
  s.penaltyUntil["PU2AAA"]=Clock::now()-std::chrono::milliseconds(1);
  s.lastCloseAt=Clock::now()-std::chrono::milliseconds(3001);
  assert(r.TxTurnGuardAdmit(&A));
  s.lastCloseAt=Clock::now()-std::chrono::milliseconds(61000);
  assert(r.TxTurnGuardAdmit(&B));
  assert(s.participants.empty());
  assert(s.penaltyUntil.empty());
  for(int i=0;i<12;i++){
     char name[12];std::snprintf(name,sizeof(name),"PU2X%03d",i);
     auto x=hdr(name,'C',100+i);
     assert(r.TxTurnGuardAdmit(&x));
     close_tx(r,'C',x);
  }
  assert(s.participants.size()==12);
  auto original=hdr("PU2X000",'C',100);
  assert(!r.TxTurnGuardAdmit(&original));
  for(int i=12;i<135;i++){
     char name[12];std::snprintf(name,sizeof(name),"PU2X%03d",i);
     auto x=hdr(name,'C',100+i);
     assert(r.TxTurnGuardAdmit(&x));
     close_tx(r,'C',x);
  }
  assert(s.participants.size()==128);
  unsetenv("XLX_TX_TURN_POLICY");
  auto legacy=hdr("PY2LMN",'D',200);
  assert(r.TxTurnGuardAdmit(&legacy));
  setenv("XLX_TX_TURN_POLICY","participants",1);
  unsetenv("XLX_TX_TURN_GUARD");
  assert(r.TxTurnGuardAdmit(&A));
  CPacketStream tot;
  tot.m_OpenTime.Now();
  assert(!tot.IsMaxDurationReached());
  tot.m_OpenTime.m_TimePoint=Clock::now()-std::chrono::seconds(181);
  assert(tot.IsMaxDurationReached());
  std::cout<<"tx_turn_multi_cpp=PASS\n";
  return 0;
}
