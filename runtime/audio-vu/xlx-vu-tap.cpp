#include <arpa/inet.h>
#include <netinet/ip.h>
#include <netinet/udp.h>
#include <poll.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <unistd.h>
#include <signal.h>
#include <cmath>
#include <array>
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>
#include <cstdlib>

#include "adapter.hpp"
#include "mbelib.h"
#include "ambe.h"
#include "p25p2_vf.h"
#include "imbe_vocoder/imbe_vocoder.h"
#include "software_imbe_decoder.h"

using uint8 = unsigned char;
#include "/usr/src/xlxd/src/cysffich.h"
class CYsfUtils { public: static void DecodeVD2Vchs(uint8*, uint8**); };

namespace {
constexpr int NSAMP=160;
constexpr uint8_t YSF_FI_COMMUNICATIONS=0x01;
constexpr uint8_t YSF_DT_VD_MODE2=0x02;
volatile sig_atomic_t g_run=1;
void onsig(int){g_run=0;}

struct Decoder {
    p25p2_vf interleaver;
    software_imbe_decoder decoder;
    mbe_parms cur{},prev{},enh{};
    mbe_errs errs{};
    int repeat=0;
    double dstar_energy_db=-120.0;
    Decoder(){mbe_initMbeParms(&cur,&prev,&enh);mbe_initErrParms(&errs);}
    std::array<int16_t,NSAMP> synth(){
        int K=12; if(cur.L<=36) K=(static_cast<float>(cur.L)+2.0f)/3.0f;
        decoder.decode_tap(cur.L,K,cur.w0,&cur.Vl[1],&cur.Ml[1]);
        auto*s=decoder.audio(); std::array<int16_t,NSAMP> pcm{};
        for(int i=0;i<NSAMP;i++){if(s&&!s->empty()){pcm[i]=(int16_t)s->front();s->pop_front();}}
        if(s)s->clear(); mbe_moveMbeParms(&cur,&prev); mbe_moveMbeParms(&cur,&enh); return pcm;
    }
    bool dstar(const uint8_t nine[9], std::array<int16_t,NSAMP>&pcm){
        xuv::XlxVoice9 raw{}; std::copy(nine,nine+9,raw.begin());
        auto bits=xuv::dstar_bytes_to_bits(raw); std::array<uint8_t,72> cw{}; std::copy(bits.begin(),bits.end(),cw.begin());
        int b[9]{}; interleaver.decode_dstar(cw.data(),b,true); if(b[0]>=120)return false;
        if(mbe_dequantizeAmbe2400Parms(&cur,&prev,&errs,b)!=0)return false;
        {
            long double ss=0.0;
            const int L=std::max(1,cur.L);
            for(int k=1;k<=L;k++) ss+=(long double)cur.Ml[k]*(long double)cur.Ml[k];
            dstar_energy_db=10.0*std::log10((double)(ss/L)+1e-18);
        }
        repeat=0; pcm=synth(); return true;
    }
    bool ambe2(const uint8_t nine[9], std::array<int16_t,NSAMP>&pcm){
        xuv::XlxVoice9 raw{}; std::copy(nine,nine+9,raw.begin()); auto d=xuv::ambe2_bytes_to_dibits(raw);
        int b[9]{},u[4]{}; size_t fec=interleaver.process_vcw(&errs,d.data(),b,u);
        int rc=mbe_dequantizeAmbe2250Parms(&cur,&prev,&errs,b); bool bad=(rc!=0)||(fec>4)||(errs.ER>0.096);
        if(bad){ if(++repeat<=3){mbe_useLastMbeParms(&cur,&prev);pcm=synth();return true;} return false; }
        repeat=0; pcm=synth(); return true;
    }
};

struct Meter {
    std::array<double,10> power{};
    std::array<double,10> peak{};
    size_t pos=0,count=0;
    bool add(const std::array<int16_t,NSAMP>&pcm,double&rmsdb,double&peakdb){
        long double ss=0; int mx=0;
        for(auto v:pcm){ long double x=(long double)v/32768.0L; ss+=x*x; mx=std::max(mx,std::abs((int)v)); }
        double rms=std::sqrt((double)(ss/NSAMP)); double pk=(double)mx/32768.0;
        if(rms<=1e-9||pk<=1e-9)return false;
        double rdb=20*std::log10(rms), pdb=20*std::log10(pk);
        // Silence/QRM tail must never replace the last useful speech reading.
        if(rdb < -50.0 || pdb < -45.0) return false;
        power[pos]=rms*rms; peak[pos]=pk; pos=(pos+1)%power.size(); if(count<power.size())count++;
        double ps=0,pmax=0; for(size_t i=0;i<count;i++){ps+=power[i];pmax=std::max(pmax,peak[i]);}
        rmsdb=20*std::log10(std::sqrt(ps/count)); peakdb=20*std::log10(std::max(pmax,1e-9)); return true;
    }
    bool add_db(double dbfs,double peakfs,double&rmsdb,double&peakdb){
        if(dbfs < -50.0 || peakfs < -45.0) return false;
        const double r=std::pow(10.0,dbfs/20.0);
        const double p=std::pow(10.0,peakfs/20.0);
        power[pos]=r*r; peak[pos]=p; pos=(pos+1)%power.size(); if(count<power.size())count++;
        double ps=0,pmax=0; for(size_t i=0;i<count;i++){ps+=power[i];pmax=std::max(pmax,peak[i]);}
        rmsdb=20*std::log10(std::sqrt(ps/count)); peakdb=20*std::log10(std::max(pmax,1e-9)); return true;
    }
};

struct SourceState {
    std::unique_ptr<Decoder> dec=std::make_unique<Decoder>();
    Meter meter;
    uint32_t stream=0;
    std::chrono::steady_clock::time_point seen=std::chrono::steady_clock::now();
    void reset_decoder(){dec=std::make_unique<Decoder>(); meter=Meter{};}
};

std::unordered_map<uint64_t,SourceState> states;
std::string ipstr(uint32_t be){in_addr a{};a.s_addr=be;char b[INET_ADDRSTRLEN]{};inet_ntop(AF_INET,&a,b,sizeof(b));return b;}
std::string safeip(std::string s){for(char&c:s)if(c=='.')c='_';return s;}
std::string level(double rms,const char* proto){
    // Codec-specific calibration. AMBE+2 (YSF) uses the same decoded scale as DMR.
    // D-STAR AMBE+ gets a slightly wider lower edge until more live station samples accumulate.
    double low=-33.0;
    double high=-20.0;
    if(rms<low)return "low"; if(rms>high)return "high"; return "ideal";
}
void publish(const char*family,uint32_t src,double rms,double peak){
    const char* envdir=std::getenv("XLX_VU_DIR");
    std::string dir=(envdir&&*envdir)?envdir:"/run/xlx-vu-tap";
    ::mkdir(dir.c_str(),0755);
    std::string ip=ipstr(src), fn=dir+"/vu-"+std::string(family)+"-"+safeip(ip)+".json";
    std::string tmp=fn+".tmp."+std::to_string(getpid());
    auto ms=std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count();
    std::ofstream f(tmp,std::ios::trunc); if(!f)return;
    const char* proto=(std::strcmp(family,"dstar")==0)?"DSTAR":((std::strcmp(family,"dmr")==0)?"DMR":"YSF");
    f<<std::fixed<<std::setprecision(1)<<"{\"ts_ms\":"<<ms<<",\"rms_dbfs\":"<<rms<<",\"peak_dbfs\":"<<peak
     <<",\"level\":\""<<level(rms,proto)<<"\",\"protocol\":\""<<proto<<"\",\"mode\":\"passive\"}\n";
    f.close(); ::chmod(tmp.c_str(),0644); ::rename(tmp.c_str(),fn.c_str());
}
uint64_t key(uint32_t src,uint16_t fam){return (uint64_t(fam)<<32)|uint64_t(ntohl(src));}

void extract33(const uint8_t*f,uint8_t*d){
    std::memcpy(d,f,14); d[13]=(d[13]&0xF0)|(f[19]&0x0F); std::memcpy(d+14,f+20,13);
}
void swap34(uint8_t*p){for(int i=0;i<34;i+=2)std::swap(p[i],p[i+1]);}
void feed_dmr(uint32_t src,uint16_t dport,const uint8_t*p,size_t n){
    uint8_t d[27]{}; uint32_t sid=0;
    if(dport==62030){
        if(n!=55||std::memcmp(p,"DMRD",4)!=0)return;
        uint8_t ft=(p[15]&0x30)>>4; bool slot2=(p[15]&0x80)!=0, group=(p[15]&0x40)==0;
        if(!slot2||!group||!(ft==0||ft==1))return;
        std::memcpy(&sid,p+16,4); extract33(p+20,d);
    } else if(dport==8880){
        if(n!=72)return; uint8_t typ=p[8];
        if(!(typ==1||typ==3)||p[16]!=0x22||p[62]!=1||(p[20]&0x0F)!=1)return;
        uint8_t fr[34]{}; std::memcpy(fr,p+26,34); swap34(fr); extract33(fr,d);
        sid=1;
    } else return;
    auto&st=states[key(src,3)]; auto now=std::chrono::steady_clock::now();
    if(st.stream!=sid||now-st.seen>std::chrono::seconds(2)){st.stream=sid;st.reset_decoder();}
    st.seen=now;
    double r=0,pk=0; bool got=false;
    for(int i=0;i<3;i++){
        std::array<int16_t,NSAMP> pcm{};
        if(st.dec->ambe2(d+i*9,pcm)&&st.meter.add(pcm,r,pk))got=true;
    }
    if(got)publish("dmr",src,r,pk);
}

void feed_ysf(uint32_t src,const uint8_t*p,size_t n){
    if(n!=155||std::memcmp(p,"YSFD",4)!=0)return;
    CYSFFICH fich; if(!fich.decode(p+40)||fich.getFI()!=YSF_FI_COMMUNICATIONS||fich.getDT()!=YSF_DT_VD_MODE2)return;
    auto&st=states[key(src,1)]; auto now=std::chrono::steady_clock::now(); if(now-st.seen>std::chrono::seconds(2))st.reset_decoder(); st.seen=now;
    uint8_t frames[5][9]{}; uint8_t* ptr[5]={frames[0],frames[1],frames[2],frames[3],frames[4]}; CYsfUtils::DecodeVD2Vchs((uint8_t*)p+35,ptr);
    double r=0,pk=0; bool got=false; for(auto &fr:frames){std::array<int16_t,NSAMP>pcm{};if(st.dec->ambe2(fr,pcm)&&st.meter.add(pcm,r,pk))got=true;} if(got)publish("ysf",src,r,pk);
}
double dstar_equiv_dbfs(double e){
    // Calibration against the server's AMBE+ encoder/decoder path:
    // source -38 dBFS -> energy 63.64; -27 -> 75.88; -18 -> 79.72.
    // Piecewise mapping avoids the misleading PCM saturation of AMBE+.
    if(e<=75.88) return std::max(-60.0,std::min(-27.0,0.89873*e-95.204));
    return std::max(-27.0,std::min(-6.0,2.34357*e-204.82));
}
void feed_dstar(uint32_t src,uint16_t dport,const uint8_t*p,size_t n){
    const uint8_t*ambe=nullptr; uint16_t sid=0;
    if(dport==20001){ if(n!=29||p[0]!=0x1D||p[1]!=0x80||std::memcmp(p+2,"DSVT",4)||p[6]!=0x20||p[10]!=0x20)return; sid=(uint16_t)p[14]|((uint16_t)p[15]<<8); ambe=p+17; }
    else if(dport==30001){ if(n!=27||std::memcmp(p,"DSVT",4)||p[4]!=0x20||p[8]!=0x20||(p[14]&0x40))return; sid=(uint16_t)p[12]|((uint16_t)p[13]<<8); ambe=p+15; }
    else if(dport==30051){ if(n<100||std::memcmp(p,"0001",4))return; sid=(uint16_t)p[43]|((uint16_t)p[44]<<8); ambe=p+46; }
    else return;
    auto&st=states[key(src,2)]; auto now=std::chrono::steady_clock::now(); if(st.stream!=sid||now-st.seen>std::chrono::seconds(2)){st.stream=sid;st.reset_decoder();} st.seen=now;
    std::array<int16_t,NSAMP>pcm{}; double r=0,pk=0;
    if(st.dec->dstar(ambe,pcm)){
        const double eq=dstar_equiv_dbfs(st.dec->dstar_energy_db);
        const double eqPeak=std::min(-0.5,eq+9.0);
        if(st.meter.add_db(eq,eqPeak,r,pk)) publish("dstar",src,r,pk);
    }
}
void cleanup(){auto now=std::chrono::steady_clock::now();for(auto it=states.begin();it!=states.end();){if(now-it->second.seen>std::chrono::seconds(15))it=states.erase(it);else ++it;}}
}

int main(){
    signal(SIGTERM,onsig);signal(SIGINT,onsig);
    int fd=socket(AF_INET,SOCK_RAW,IPPROTO_UDP); if(fd<0){std::cerr<<"[ERRO] raw socket: "<<strerror(errno)<<"\n";return 2;}
    int rcv=4*1024*1024;setsockopt(fd,SOL_SOCKET,SO_RCVBUF,&rcv,sizeof(rcv));
    std::cout<<"[OK] XLX026 VU TAP passive DMR+YSF+DSTAR\n";
    alignas(16) uint8_t buf[65536]; auto lastclean=std::chrono::steady_clock::now();
    while(g_run){pollfd pfd{fd,POLLIN,0};int pr=poll(&pfd,1,500);if(pr<0){if(errno==EINTR)continue;break;}if(pr==0){cleanup();continue;}if(!(pfd.revents&POLLIN))continue;
        sockaddr_in from{};socklen_t fl=sizeof(from);ssize_t n=recvfrom(fd,buf,sizeof(buf),0,(sockaddr*)&from,&fl);if(n<28)continue;
        auto*ip=(iphdr*)buf;size_t ihl=ip->ihl*4U;if(ip->version!=4||ip->protocol!=IPPROTO_UDP||ihl<20||(size_t)n<ihl+8)continue;
        auto*udp=(udphdr*)(buf+ihl);uint16_t dport=ntohs(udp->dest),ulen=ntohs(udp->len);if(ulen<8||ihl+ulen>(size_t)n)continue;const uint8_t*p=buf+ihl+8;size_t plen=ulen-8;
        if(dport==62030||dport==8880)feed_dmr(ip->saddr,dport,p,plen); else if(dport==42000)feed_ysf(ip->saddr,p,plen); else if(dport==20001||dport==30001||dport==30051)feed_dstar(ip->saddr,dport,p,plen);
        auto now=std::chrono::steady_clock::now();if(now-lastclean>std::chrono::seconds(5)){cleanup();lastclean=now;}
    }
    close(fd);std::cout<<"[OK] stop\n";return 0;
}
