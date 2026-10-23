#include "main.h"
#define protected public
#include "creflector.h"
#include "cysfprotocol.h"
#include "cysfclient.h"
#include "cdmrmmdvmprotocol.h"
#include "cdcsprotocol.h"
#undef protected
#include <cassert>
#include <thread>
#include <memory>
#include <fstream>
#include <cstring>

struct Receiver {
 int fd; CIp ip;
 Receiver() : ip("127.0.0.1") {
  fd=socket(AF_INET,SOCK_DGRAM,0); assert(fd>=0);
  sockaddr_in a={};a.sin_family=AF_INET;a.sin_addr.s_addr=htonl(INADDR_LOOPBACK);
  assert(bind(fd,(sockaddr*)&a,sizeof(a))==0);socklen_t n=sizeof(a);
  assert(getsockname(fd,(sockaddr*)&a,&n)==0);ip.SetPort(a.sin_port);
  timeval timeout={0,200000};setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof(timeout));
 }
 ~Receiver(){close(fd);}
 void expect(const CBuffer &b){uint8 data[200];auto n=recv(fd,data,sizeof(data),0);assert(n==(int)b.size());assert(memcmp(data,b.data(),n)==0);}
 void silent(){uint8 b[200];assert(recv(fd,b,sizeof(b),0)<0);}
};
static void key(const char *v){std::ofstream f("/etc/xlx-modern/ysf-vw.conf");f<<v;f.close();assert(f.good());}
class TestPeer : public CYsfClient { public: TestPeer(const CIp &ip):CYsfClient(CCallsign("PU2PRR"),ip,'C'){} bool IsPeer(void) const {return true;} };
static CBuffer vw(CYsfProtocol &ysf,const CDvHeaderPacket &h,uint8 fi) {
 CBuffer b;assert(ysf.EncodeDvHeaderPacket(h,&b));CYSFFICH f;
 assert(f.decode(b.data()+40));f.setDT(YSF_DT_VOICE_FR_MODE);f.setFI(fi);
 f.encode(b.data()+40);return b;
}
static void deliver(CYsfProtocol &ysf){
 for(int k=0;k<500;++k){
  ysf.m_Queue.Lock();bool ready=!ysf.m_Queue.empty();ysf.m_Queue.Unlock();
  if(ready){ysf.HandleQueue();return;}std::this_thread::sleep_for(std::chrono::milliseconds(2));
 } assert(false);
}
int main(){
 key("0\n");
 unsetenv("XLX_YSF_VW");assert(!CYsfProtocol::VwEnabledFromEnvironment());
 for(const char *bad:{"0","true","yes","2",""}){setenv("XLX_YSF_VW",bad,1);assert(!CYsfProtocol::VwEnabledFromEnvironment());}
 setenv("XLX_YSF_VW","1",1);assert(CYsfProtocol::VwEnabledFromEnvironment());
 unsetenv("XLX_TX_TURN_GUARD");
 g_Reflector.SetCallsign(CCallsign("XLX999"));g_Reflector.SetListenIp(CIp("127.0.0.1"));
 for(auto &p:g_Reflector.m_Protocols.m_Protocols)p=new CProtocol;
 auto *ysf=new CYsfProtocol;delete g_Reflector.m_Protocols.m_Protocols[6];g_Reflector.m_Protocols.m_Protocols[6]=ysf;
 assert(ysf->AcceptsYsfVw());assert(!CDcsProtocol().AcceptsYsfVw());assert(!CDmrmmdvmProtocol().AcceptsYsfVw());
 ysf->m_ReflectorCallsign=CCallsign("YSF999");assert(ysf->m_Socket.Open(0));
 Receiver tx,rx,other,peer;
 auto add=[&](const char *call,Receiver &r,char module){auto*c=new CYsfClient(CCallsign(call),r.ip,module);g_Reflector.GetClients()->AddClient(c);g_Reflector.ReleaseClients();return c;};
 add("PU2TST",tx,'C');add("PU2RXA",rx,'C');add("PU2RXB",other,'B');
 g_Reflector.GetClients()->AddClient(new TestPeer(peer.ip));g_Reflector.ReleaseClients();
 CCallsign my("PU2AAA"),ur("CQCQCQ"),rpt1("PU2TST"),rpt2("XLX999");rpt1.SetModule('B');rpt2.SetModule('C');
 CDvHeaderPacket base(my,ur,rpt1,rpt2,ysf->IpToStreamId(tx.ip),0);
 CBuffer header=vw(*ysf,base,YSF_FI_HEADER);CYSFFICH fich;
 assert(!ysf->IsValidDvPacket(header,&fich));ysf->m_VwEnabled=true;assert(!ysf->IsValidDvPacket(header,&fich));key("junk");assert(!ysf->IsValidDvPacket(header,&fich));key("1\n");assert(ysf->IsValidDvPacket(header,&fich));
 CBuffer bad(header);bad.resize(154);assert(!ysf->IsValidDvPacket(bad,&fich));
 CDvHeaderPacket *parsed=nullptr;CDvFramePacket *frames[5]={};
 assert(ysf->IsValidDvHeaderPacket(tx.ip,fich,header,&parsed,frames));delete frames[0];delete frames[1];
 parsed->SetYsfVwWire(header.data(),tx.ip);
 auto clone=std::unique_ptr<CPacket>(parsed->Duplicate());assert(clone->IsYsfVw());assert(clone->GetYsfVwWire()==parsed->GetYsfVwWire());
 g_Reflector.m_bStopThreads=false;auto *stream=&g_Reflector.m_Streams[g_Reflector.GetModuleIndex('C')];
 std::thread router([&]{CReflector::RouterThread(&g_Reflector,stream);});
 assert(ysf->OnDvHeaderPacketIn(parsed,tx.ip));assert(stream->IsYsfVw());assert(stream->m_CodecStream==nullptr);
 deliver(*ysf);rx.expect(header);tx.silent();other.silent();peer.silent();
 key("0\n");assert(!ysf->IsValidDvPacket(header,&fich));
 CBuffer dn;assert(ysf->EncodeDvHeaderPacket(base,&dn));assert(ysf->IsValidDvPacket(dn,&fich));
 for(int i=0;i<g_Reflector.m_Protocols.Size();++i)if(i!=6){auto*q=g_Reflector.m_Protocols.GetProtocol(i)->GetQueue();assert(q->empty());g_Reflector.m_Protocols.GetProtocol(i)->ReleaseQueue();}
 // A DN EOT must not tear down the VW stream.
 auto *dnlast=new CDvLastFramePacket;dnlast->SetStreamId(stream->GetStreamId());ysf->OnDvLastFramePacketIn(dnlast,&tx.ip);assert(stream->IsOpen());
 CBuffer voice=vw(*ysf,base,YSF_FI_COMMUNICATIONS);assert(fich.decode(voice.data()+40));
 ysf->OnVwPacketIn(voice,tx.ip,fich);deliver(*ysf);rx.expect(voice);tx.silent();other.silent();peer.silent();
 CBuffer last=vw(*ysf,base,YSF_FI_TERMINATOR);assert(fich.decode(last.data()+40));ysf->OnVwPacketIn(last,tx.ip,fich);rx.expect(last);assert(!stream->IsOpen());tx.silent();
 ysf->m_Streams.clear();
 key("1\n");auto *totHeader=new CDvHeaderPacket(base);totHeader->SetYsfVwWire(header.data(),tx.ip);
 assert(ysf->OnDvHeaderPacketIn(totHeader,tx.ip));deliver(*ysf);rx.expect(header);
 stream->m_OpenTime.m_TimePoint=std::chrono::steady_clock::now()-std::chrono::seconds(181);
 ysf->CheckStreamsTimeout();assert(!stream->IsOpen());assert(g_Reflector.IsTotBlocked(base.GetStreamId(),&tx.ip));
 assert(fich.decode(last.data()+40));ysf->OnVwPacketIn(last,tx.ip,fich);assert(!g_Reflector.IsTotBlocked(base.GetStreamId(),&tx.ip,false));
 g_Reflector.m_bStopThreads=true;router.join();ysf->m_Streams.clear();
 std::cout<<"vw_env_transport=PASS: opt-in, bad length, wire cloning, real router isolation, header/voice/EOT UDP bit identity, owner/module isolation, DN EOT rejection, no transcoder"<<std::endl;
}
