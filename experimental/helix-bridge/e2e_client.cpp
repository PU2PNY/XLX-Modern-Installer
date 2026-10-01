// Laboratory synthetic AMBE+2 corpus generator; OP25 stays an external build input.
#include "adapter.hpp"
#include "mbelib.h"
#include "p25p2_vf.h"
#include "imbe_vocoder/imbe_vocoder.h"
#include "ambe_encoder.h"
#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <vector>
#include <chrono>
#include <thread>

static uint16_t rd16(const uint8_t* p){return uint16_t(p[0])|(uint16_t(p[1])<<8);}
static void wr16(uint8_t* p,uint16_t v){p[0]=v&255;p[1]=(v>>8)&255;}

struct S {
 int fd=-1; sockaddr_in ctl{}; uint16_t id=0,port=0; ambe_encoder enc;
 bool open(char module){
  fd=socket(AF_INET,SOCK_DGRAM,0); if(fd<0)return false;
  timeval tv{1,0}; setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof(tv));
  ctl.sin_family=AF_INET;ctl.sin_port=htons(10100);inet_pton(AF_INET,"127.0.0.1",&ctl.sin_addr);
  uint8_t q[18]{}; memcpy(q,"AMBEDOS",7); memcpy(q+7,"XLX999  ",8); q[15]=2;q[16]=1;q[17]=module;
  if(sendto(fd,q,sizeof(q),0,(sockaddr*)&ctl,sizeof(ctl))!=(ssize_t)sizeof(q))return false;
  uint8_t r[32]{};socklen_t sl=sizeof(ctl);auto n=recvfrom(fd,r,sizeof(r),0,(sockaddr*)&ctl,&sl);
  if(n!=14||memcmp(r,"AMBEDSTD",8)!=0)return false;
  id=rd16(r+8);port=rd16(r+10); return true;
 }
 bool one(int idx,std::array<uint8_t,11>& out){
  int16_t pcm[160];
  for(int i=0;i<160;i++){
    double t=(idx*160+i)/8000.0;
    pcm[i]=(int16_t)std::lround(4500.0*std::sin(2.0*M_PI*700.0*t));
  }
  uint8_t raw[72]{};enc.encode(pcm,raw);
  xuv::Dibits36 d{};for(int i=0;i<36;i++)d[i]=raw[i];
  auto packed=xuv::ambe2_dibits_to_bytes(d);
  uint8_t p[11]{};p[0]=2;p[1]=idx&255;memcpy(p+2,packed.data(),9);
  sockaddr_in dst{};dst.sin_family=AF_INET;dst.sin_port=htons(port);inet_pton(AF_INET,"127.0.0.1",&dst.sin_addr);
  if(sendto(fd,p,sizeof(p),0,(sockaddr*)&dst,sizeof(dst))!=(ssize_t)sizeof(p))return false;
  socklen_t sl=sizeof(dst);auto n=recvfrom(fd,out.data(),out.size(),0,(sockaddr*)&dst,&sl);
  return n==11 && out[0]==1;
 }
 void close_stream(){
  if(fd<0)return; uint8_t q[9]{};memcpy(q,"AMBEDCS",7);wr16(q+7,id);
  sendto(fd,q,sizeof(q),0,(sockaddr*)&ctl,sizeof(ctl));close(fd);fd=-1;
 }
};

int main(int argc,char**argv){
 int streams=argc>1?std::atoi(argv[1]):1;
 int frames=argc>2?std::atoi(argv[2]):40;
 int pause_ms=argc>3?std::atoi(argv[3]):20;
 if(streams<1||streams>2)return 2;
 std::vector<S> ss(streams);
 for(int i=0;i<streams;i++)if(!ss[i].open('C')){std::cerr<<"openfail\n";return 3;}
 for(int f=0;f<frames;f++)for(int i=0;i<streams;i++){
   std::array<uint8_t,11> out{};
   auto started=std::chrono::steady_clock::now();
   if(!ss[i].one(f,out)){std::cerr<<"framefail "<<i<<" "<<f<<"\n";return 4;}
   double ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-started).count();
   fwrite(out.data(),1,out.size(),stdout);
   std::cerr << "FRAME " << i << " " << f << " " << ms << "\n";
   if(i==streams-1) std::this_thread::sleep_for(std::chrono::milliseconds(pause_ms));
 }
 for(auto& s:ss)s.close_stream();
 return 0;
}
