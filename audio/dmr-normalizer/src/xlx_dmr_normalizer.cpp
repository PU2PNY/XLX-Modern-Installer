#include "dmr_audio_core.hpp"
#include <libnetfilter_queue/libnetfilter_queue.h>
#include <libnfnetlink/libnfnetlink.h>
#include <arpa/inet.h>
#include <netinet/ip.h>
#include <netinet/udp.h>
#include <csignal>
#include <cerrno>
#include <cstring>
#include <iostream>
#include <vector>
#include <chrono>
#include <unistd.h>
#include <poll.h>
#include <fstream>
#include <iomanip>
#include <unordered_map>
#include <string>
#include <sstream>
#include <cstdio>
#include <sys/stat.h>

static constexpr uint32_t kNfAccept=1U; // NF_ACCEPT
static volatile sig_atomic_t g_run=1;
static dmrnorm::Processor* g_proc=nullptr;
static uint64_t g_queued=0,g_modified=0,g_mmdvm=0,g_plus=0,g_parse_errors=0;
static std::chrono::steady_clock::time_point g_lastlog;
static std::unordered_map<uint32_t,std::chrono::steady_clock::time_point> g_vu_last_write;
static void sig(int){g_run=0;}

static void write_vu_telemetry(uint32_t saddr_network,uint64_t key){
    if(!g_proc) return;
    double rms=-120.0, peak=-120.0; int mode=0;
    if(!g_proc->telemetry(key,rms,peak,mode)) return;
    // Do not let tail/silence frames overwrite the last useful speech level.
    if(rms < -55.0 && peak < -45.0) return;

    const auto now=std::chrono::steady_clock::now();
    auto it=g_vu_last_write.find(saddr_network);
    if(it!=g_vu_last_write.end() && now-it->second<std::chrono::milliseconds(100)) return;
    g_vu_last_write[saddr_network]=now;

    char ipbuf[INET_ADDRSTRLEN]{};
    if(!inet_ntop(AF_INET,&saddr_network,ipbuf,sizeof(ipbuf))) return;
    std::string slug(ipbuf);
    for(char& c:slug) if(c=='.') c='_';

    const auto epoch_ms=std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
    const char* level=(rms<-33.0)?"low":((rms>-20.0)?"high":"ideal");
    const char* mode_name=(mode==1)?"natural":((mode==2)?"processed":((mode==4)?"calibrated":((mode==5)?"adaptive-gain":((mode==6)?"natural-global":"learn"))));

    const std::string dir="/run/xlx-dmr-normalizer";
    const std::string path=dir+"/vu-"+slug+".json";
    const std::string tmp=path+".tmp."+std::to_string(getpid());
    std::ofstream f(tmp,std::ios::trunc);
    if(!f) return;
    f<<"{\"ts_ms\":"<<epoch_ms
     <<",\"rms_dbfs\":"<<std::fixed<<std::setprecision(1)<<rms
     <<",\"peak_dbfs\":"<<std::fixed<<std::setprecision(1)<<peak
     <<",\"level\":\""<<level<<"\""
     <<",\"mode\":\""<<mode_name<<"\"}";
    f.close();
    if(!f) { std::remove(tmp.c_str()); return; }
    ::chmod(tmp.c_str(),0644);
    if(::rename(tmp.c_str(),path.c_str())!=0) std::remove(tmp.c_str());
}

static uint16_t udp_checksum(const uint8_t* packet,size_t len,size_t ihl){
    if(len<ihl+8)return 0; const auto* ip=reinterpret_cast<const iphdr*>(packet); const auto* udp=reinterpret_cast<const udphdr*>(packet+ihl);
    uint16_t ulen=ntohs(udp->len); if(ulen<8||ihl+ulen>len)return 0; uint32_t sum=0;
    auto add=[&](const uint8_t*p,size_t n){size_t i=0;for(;i+1<n;i+=2)sum+=(uint16_t(p[i])<<8)|p[i+1];if(i<n)sum+=uint16_t(p[i])<<8;};
    add(reinterpret_cast<const uint8_t*>(&ip->saddr),4); add(reinterpret_cast<const uint8_t*>(&ip->daddr),4); sum+=IPPROTO_UDP; sum+=ulen;
    std::vector<uint8_t> tmp(packet+ihl,packet+ihl+ulen); tmp[6]=tmp[7]=0; add(tmp.data(),tmp.size());
    while(sum>>16)sum=(sum&0xffff)+(sum>>16); uint16_t c=uint16_t(~sum); if(c==0)c=0xffff; return htons(c);
}

static int cb(nfq_q_handle* qh,nfgenmsg*,nfq_data* nfa,void*){
    auto* ph=nfq_get_msg_packet_hdr(nfa); uint32_t id=ph?ntohl(ph->packet_id):0; unsigned char* raw=nullptr; int n=nfq_get_payload(nfa,&raw); g_queued++;
    if(n<=0||!raw){g_parse_errors++;return nfq_set_verdict(qh,id,kNfAccept,0,nullptr);} std::vector<uint8_t> pkt(raw,raw+n); bool modified=false;
    if(pkt.size()>=28){
        auto* ip=reinterpret_cast<iphdr*>(pkt.data()); size_t ihl=ip->ihl*4U;
        if(ip->version==4&&ip->protocol==IPPROTO_UDP&&ihl>=20&&pkt.size()>=ihl+8){
            auto* udp=reinterpret_cast<udphdr*>(pkt.data()+ihl); uint16_t dport=ntohs(udp->dest),sport=ntohs(udp->source),ulen=ntohs(udp->len);
            if(ulen>=8&&ihl+ulen<=pkt.size()){
                uint8_t* p=pkt.data()+ihl+8; size_t plen=ulen-8; uint32_t src=ntohl(ip->saddr); uint64_t key=(uint64_t(src)<<32)^(uint64_t(sport)<<16);
                if(dport==62030&&plen==55&&std::memcmp(p,"DMRD",4)==0){
                    uint32_t sid=0;std::memcpy(&sid,p+16,4);key^=uint64_t(sid); uint8_t ft=(p[15]&0x30)>>4;bool slot2=p[15]&0x80;uint8_t st=p[15]&0x0f;
                    if(ft==2&&slot2&&st==2)g_proc->erase(key);
                    if(g_proc->process_mmdvm(p,plen,key)){modified=true;g_mmdvm++;write_vu_telemetry(ip->saddr,key);}
                } else if(dport==8880&&plen==72){
                    if(g_proc->process_dmrplus(p,plen,key)){modified=true;g_plus++;write_vu_telemetry(ip->saddr,key);}
                }
                if(modified){if(udp->check!=0)udp->check=udp_checksum(pkt.data(),pkt.size(),ihl);g_modified++;}
            }
        }
    }
    auto now=std::chrono::steady_clock::now(); if(now-g_lastlog>std::chrono::seconds(60)){
        std::cout<<"[OK] queued="<<g_queued<<" modified="<<g_modified<<" mmdvm="<<g_mmdvm<<" dmrplus="<<g_plus<<" active="<<g_proc->active_streams()<<" parse_errors="<<g_parse_errors<<std::endl;g_lastlog=now;
    }
    return modified?nfq_set_verdict(qh,id,kNfAccept,pkt.size(),pkt.data()):nfq_set_verdict(qh,id,kNfAccept,0,nullptr);
}

int main(int argc,char**argv){
    if(argc!=3){std::cerr<<"usage: xlx-dmr-normalizer profile.conf queue_num\n";return 1;} xlx026::VoiceProfile prof;if(!prof.load(argv[1])){std::cerr<<"[ERRO] perfil invalido\n";return 2;} int qnum=std::stoi(argv[2]);if(qnum<0||qnum>65535)return 3;
    ::mkdir("/run/xlx-dmr-normalizer",0755);
    dmrnorm::Processor proc(prof);
    {
        std::ifstream cfg(argv[1]); std::string line;
        while(std::getline(cfg,line)) {
            const auto eq=line.find('='); if(eq==std::string::npos) continue;
            try {
                if(line.rfind("radio_gain_",0)==0) {
                    const uint32_t rid=static_cast<uint32_t>(std::stoul(line.substr(11,eq-11)));
                    const float db=std::stof(line.substr(eq+1));
                    if(rid>0 && db>=-3.0f && db<=3.0f && db!=0.0f) proc.set_gain_override(rid,db);
                } else if(line.rfind("global_natural_dmr",0)==0) {
                    proc.set_global_natural(std::stoi(line.substr(eq+1))!=0);
                } else if(line.rfind("adaptive_gain_dmr",0)==0) {
                    proc.set_adaptive_gain(std::stoi(line.substr(eq+1))!=0);
                }
            } catch(...) {}
        }
    }
    g_proc=&proc;signal(SIGTERM,sig);signal(SIGINT,sig);g_lastlog=std::chrono::steady_clock::now();
    nfq_handle*h=nfq_open();if(!h){std::cerr<<"[ERRO] nfq_open\n";return 4;} if(nfq_bind_pf(h,AF_INET)<0&&errno!=EBUSY){std::cerr<<"[ERRO] nfq_bind_pf: "<<strerror(errno)<<"\n";nfq_close(h);return 5;}
    nfq_q_handle*qh=nfq_create_queue(h,qnum,&cb,nullptr);if(!qh){std::cerr<<"[ERRO] nfq_create_queue "<<qnum<<"\n";nfq_close(h);return 6;} nfq_set_mode(qh,NFQNL_COPY_PACKET,0xffff);nfq_set_queue_maxlen(qh,1024);nfnl_rcvbufsiz(nfq_nfnlh(h),4*1024*1024);
    std::cout<<"[OK] XLX026 DMR Normalizer NATURAL V7 GLOBAL queue="<<qnum<<" target_internal="<<prof.target_rms_dbfs<<" tone_max_db="<<prof.tone_max_db<<" up_max_db="<<prof.agc_up_max_db<<" down_max_db="<<prof.agc_down_max_db<<" global_natural="<<(proc.global_natural()?1:0)<<" adaptive_gain="<<(proc.adaptive_gain()?1:0)<<" gain_overrides="<<proc.gain_override_count()<<std::endl;
    int fd=nfq_fd(h);alignas(16) char buf[65536];
    while(g_run){
        pollfd pfd{fd,POLLIN,0}; int pr=poll(&pfd,1,500);
        if(pr<0){if(errno==EINTR)continue;std::cerr<<"[ERRO] poll: "<<strerror(errno)<<std::endl;break;}
        if(pr==0)continue; if(!(pfd.revents&POLLIN))continue;
        int rv=recv(fd,buf,sizeof(buf),0);if(rv>=0){nfq_handle_packet(h,buf,rv);continue;}
        if(errno==EINTR)continue;if(errno==ENOBUFS){g_parse_errors++;continue;}std::cerr<<"[ERRO] recv: "<<strerror(errno)<<std::endl;break;
    }
    std::cout<<"[OK] stop queued="<<g_queued<<" modified="<<g_modified<<" mmdvm="<<g_mmdvm<<" dmrplus="<<g_plus<<" errors="<<g_parse_errors<<std::endl;nfq_destroy_queue(qh);nfq_close(h);return 0;
}
