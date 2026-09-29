#pragma once
#include "adapter.hpp"
#include "voice_dsp.hpp"
#include "adaptive_gain.hpp"
#include "mbelib.h"
#include "ambe.h"
#include "p25p2_vf.h"
#include "imbe_vocoder/imbe_vocoder.h"
#include "ambe_encoder.h"
#include "software_imbe_decoder.h"
typedef unsigned char uint8;
#include "cysfutils.h"
#include <array>
#include <algorithm>
#include <cstdint>
#include <cmath>
#include <cstring>
#include <memory>
#include <unordered_map>

namespace dmrnorm {
constexpr int NSAMP=160;
struct DecodeState {
    p25p2_vf interleaver; software_imbe_decoder decoder;
    mbe_parms cur{},prev{},enh{}; mbe_errs errs{};
    uint64_t frames=0,bad=0,concealed=0,muted=0,fec_sum=0; size_t fec_max=0; double er_max=0.0; int repeat=0;
    DecodeState(){mbe_initMbeParms(&cur,&prev,&enh);mbe_initErrParms(&errs);}
    std::array<int16_t,NSAMP> synth(){
        int K=12; if(cur.L<=36) K=(static_cast<float>(cur.L)+2.0f)/3.0f;
        decoder.decode_tap(cur.L,K,cur.w0,&cur.Vl[1],&cur.Ml[1]); auto*s=decoder.audio();
        std::array<int16_t,NSAMP> pcm{}; for(int i=0;i<NSAMP;i++){if(s&&!s->empty()){pcm[i]=(int16_t)s->front();s->pop_front();}}
        if(s)s->clear(); mbe_moveMbeParms(&cur,&prev); mbe_moveMbeParms(&cur,&enh); return pcm;
    }
    bool decode(const xuv::XlxVoice9& raw,std::array<int16_t,NSAMP>&pcm){
        auto d=xuv::ambe2_bytes_to_dibits(raw); int b[9]{},u[4]{}; size_t fec=interleaver.process_vcw(&errs,d.data(),b,u);
        frames++; fec_sum+=fec; fec_max=std::max(fec_max,fec); er_max=std::max(er_max,errs.ER);
        int rc=mbe_dequantizeAmbe2250Parms(&cur,&prev,&errs,b); bool isbad=(rc!=0)||(fec>4)||(errs.ER>0.096);
        if(isbad){bad++; if(++repeat<=3){mbe_useLastMbeParms(&cur,&prev);concealed++;pcm=synth();return true;} muted++;pcm.fill(0);return true;}
        repeat=0; pcm=synth(); return true;
    }
};
struct StreamState {
    enum class NaturalMode { Learn, Bypass, Process };

    DecodeState dec;
    ambe_encoder enc;
    xlx026::VoiceNormalizer dsp;
    xlx026::AdaptiveGain adaptive;
    NaturalMode mode = NaturalMode::Learn;
    std::array<double,12> learn_db{};
    size_t learn_count = 0;
    size_t learn_frames = 0;
    double learned_median_dbfs = -120.0;
    double last_rms_dbfs = -120.0;
    double last_peak_dbfs = -120.0;
    bool gain_override_active = false;
    bool adaptive_gain_active = false;

    explicit StreamState(const xlx026::VoiceProfile&p)
        : dsp(p),
          adaptive(xlx026::AdaptiveGainConfig{
              p.adaptive_target_rms_dbfs, p.adaptive_deadband_db,
              p.adaptive_max_gain_db, p.adaptive_speech_gate_dbfs, 12, 30}) {}

    static double pcm_dbfs(const std::array<int16_t,NSAMP>& pcm) {
        long double ss = 0.0;
        for (auto v : pcm) {
            const long double x = static_cast<long double>(v) / 32768.0L;
            ss += x*x;
        }
        const long double rms = std::sqrt(ss / static_cast<long double>(pcm.size()));
        if (rms <= 1e-12L) return -120.0;
        return 20.0 * std::log10(static_cast<double>(rms));
    }

    static double pcm_peak_dbfs(const std::array<int16_t,NSAMP>& pcm) {
        int peak = 0;
        for (auto v : pcm) peak = std::max(peak, std::abs(static_cast<int>(v)));
        if (peak <= 0) return -120.0;
        return 20.0 * std::log10(static_cast<double>(peak) / 32768.0);
    }

    bool measure_only(const uint8_t* nine) {
        xuv::XlxVoice9 in{};
        std::copy(nine,nine+9,in.begin());
        std::array<int16_t,NSAMP> pcm{};
        if(!dec.decode(in,pcm)) return false;
        last_rms_dbfs = pcm_dbfs(pcm);
        last_peak_dbfs = pcm_peak_dbfs(pcm);
        return true;
    }

    void observe_adaptive() {
        adaptive.observe(last_rms_dbfs);
        adaptive_gain_active = adaptive.ready();
    }
    bool adaptive_ready() const { return adaptive.ready(); }
    float adaptive_correction_db() const { return static_cast<float>(adaptive.correction_db()); }

    void finish_learning_if_ready() {
        // Classify once per TX. A wide natural dead-band means normal stations
        // stay bit-exact and never get another AMBE generation.
        if (mode != NaturalMode::Learn) return;
        if (learn_count >= learn_db.size()) {
            auto tmp = learn_db;
            std::sort(tmp.begin(), tmp.end());
            learned_median_dbfs = 0.5 * (tmp[5] + tmp[6]);
            // Only true outliers are processed. Mid-level stations remain raw.
            mode = (learned_median_dbfs < -33.0 || learned_median_dbfs > -20.0)
                ? NaturalMode::Process : NaturalMode::Bypass;
        } else if (learn_frames >= 30) {
            // If usable speech evidence never arrived in ~600 ms, favor
            // naturalness and transparency rather than processing noise.
            mode = NaturalMode::Bypass;
        }
    }

    bool frame(uint8_t* nine){
        // VU telemetry needs the received PCM level even in Natural Bypass.
        // We decode for measurement only; natural-mode AMBE bytes remain untouched.
        xuv::XlxVoice9 in{};
        std::copy(nine,nine+9,in.begin());
        std::array<int16_t,NSAMP> pcm{};
        if(!dec.decode(in,pcm)) return false;

        const double raw_db = pcm_dbfs(pcm);
        last_rms_dbfs = raw_db;
        last_peak_dbfs = pcm_peak_dbfs(pcm);

        if (mode == NaturalMode::Bypass) return true;
        if (mode == NaturalMode::Learn) {
            ++learn_frames;
            // Ignore only near-silence while learning; speech and realistic
            // station noise remain measurable. The first ~240 ms are always
            // sent raw, so onset cannot be clipped or synthesized.
            if (raw_db > -55.0 && learn_count < learn_db.size()) {
                learn_db[learn_count++] = raw_db;
            }
            // Warm DSP state on a copy so an outlier does not jump abruptly
            // when processing begins after classification.
            auto warm = pcm;
            dsp.process(warm.data(), warm.size());
            finish_learning_if_ready();
            return true; // learning window is always byte-exact passthrough
        }

        dsp.process(pcm.data(),pcm.size());
        // Pauses/non-speech remain the original AMBE frame. No QRM pumping and
        // no vocoder generation added between words.
        if (dsp.passthrough_pause()) return true;

        // OP25 AMBE+2 encoder calibration used by XLX026 module C.
        for(auto &v: pcm) v = static_cast<int16_t>(static_cast<int32_t>(v) / 8);
        std::array<uint8_t,72> raw{};
        enc.encode(pcm.data(),raw.data());
        xuv::Dibits36 d{};
        for(size_t i=0;i<36;i++) d[i]=raw[i];
        auto out=xuv::ambe2_dibits_to_bytes(d);
        std::copy(out.begin(),out.end(),nine);
        return true;
    }
};
class Processor {
    xlx026::VoiceProfile profile_; std::unordered_map<uint64_t,std::unique_ptr<StreamState>> streams_;
    std::unordered_map<uint32_t,float> radio_gain_overrides_;
    bool global_natural_dmr_ = false;
    bool adaptive_gain_dmr_ = false;
    static void extract33(const uint8_t*f,uint8_t*d){std::memcpy(d,f,14);d[13]=(d[13]&0xF0)|(f[19]&0x0F);std::memcpy(d+14,f+20,13);}
    static void repack33(uint8_t*f,const uint8_t*d){std::memcpy(f,d,13);f[13]=(f[13]&0x0F)|(d[13]&0xF0);f[19]=(f[19]&0xF0)|(d[13]&0x0F);std::memcpy(f+20,d+14,13);}
    static void swap34(uint8_t*p){for(int i=0;i<34;i+=2)std::swap(p[i],p[i+1]);}
    StreamState* st(uint64_t key){auto it=streams_.find(key);if(it!=streams_.end())return it->second.get();if(streams_.size()>=32)return nullptr;it=streams_.emplace(key,std::make_unique<StreamState>(profile_)).first;return it->second.get();}
public:
    uint64_t packets=0,changed=0,frames=0,failed=0;
    explicit Processor(const xlx026::VoiceProfile&p):profile_(p){}
    void set_gain_override(uint32_t radio_id,float db) {
        if(radio_id>0 && db!=0.0f) radio_gain_overrides_[radio_id]=db;
        else radio_gain_overrides_.erase(radio_id);
    }
    size_t gain_override_count() const { return radio_gain_overrides_.size(); }
    void set_global_natural(bool enabled) { global_natural_dmr_ = enabled; }
    bool global_natural() const { return global_natural_dmr_; }
    void set_adaptive_gain(bool enabled) { adaptive_gain_dmr_ = enabled; }
    bool adaptive_gain() const { return adaptive_gain_dmr_; }
    void erase(uint64_t k){streams_.erase(k);} size_t active_streams() const{return streams_.size();}
    bool telemetry(uint64_t key, double& rms, double& peak, int& mode) const {
        auto it=streams_.find(key);
        if(it==streams_.end() || !it->second) return false;
        rms=it->second->last_rms_dbfs;
        peak=it->second->last_peak_dbfs;
        mode=global_natural_dmr_ ? 6 : (it->second->gain_override_active ? 4 : (adaptive_gain_dmr_ ? 5 : static_cast<int>(it->second->mode)));
        return rms > -119.0;
    }
    bool process_mmdvm(uint8_t*p,size_t n,uint64_t key){
        if(n!=55||std::memcmp(p,"DMRD",4)!=0)return false; uint8_t ft=(p[15]&0x30)>>4; bool slot2=(p[15]&0x80)!=0, group=(p[15]&0x40)==0;
        if(!slot2||!group||!(ft==0||ft==1))return false; uint8_t d[27];extract33(p+20,d); auto*s=st(key); if(!s)return false; bool any=false;

        const uint32_t src_id=(uint32_t(p[5])<<16)|(uint32_t(p[6])<<8)|uint32_t(p[7]);
        if(global_natural_dmr_) {
            // Global anti-robotization path: decode only for metering.
            // Network AMBE+2 bytes remain exactly as received: no DSP, no gain rewrite,
            // no vocoder generation added by this sidecar.
            s->gain_override_active = false;
            s->mode = StreamState::NaturalMode::Bypass;
            for(int i=0;i<3;i++) {
                if(!s->measure_only(d+i*9)) failed++; else frames++;
            }
            packets++;
            return true;
        }
        const auto ov=radio_gain_overrides_.find(src_id);
        if(ov!=radio_gain_overrides_.end()) {
            // Per-RadioID calibration changes only AMBE+2 gain parameter/FEC.
            // It deliberately bypasses PCM DSP and AMBE re-encoding to preserve
            // voice naturalness for a station that is already known/calibrated.
            s->gain_override_active = true;
            for(int i=0;i<3;i++) {
                uint8_t before[9]; std::memcpy(before,d+i*9,9);
                if(!s->measure_only(d+i*9)) failed++; else frames++;
                CYsfUtils::AdjustAmbeGain(d+i*9,ov->second);
                if(std::memcmp(before,d+i*9,9)!=0) any=true;
            }
            repack33(p+20,d); packets++; if(any)changed++; return true;
        }
        if(adaptive_gain_dmr_) {
            s->gain_override_active = false;
            for(int i=0;i<3;i++) {
                uint8_t before[9]; std::memcpy(before,d+i*9,9);
                if(!s->measure_only(d+i*9)) { failed++; continue; }
                frames++; s->observe_adaptive();
                if(s->adaptive_ready()) {
                    const float db=s->adaptive_correction_db();
                    if(std::abs(db)>=0.05f) CYsfUtils::AdjustAmbeGain(d+i*9,db);
                }
                if(std::memcmp(before,d+i*9,9)!=0) any=true;
            }
            repack33(p+20,d); packets++; if(any)changed++; return true;
        }

        for(int i=0;i<3;i++){uint8_t before[9];std::memcpy(before,d+i*9,9);if(s->frame(d+i*9)){frames++;if(std::memcmp(before,d+i*9,9)!=0)any=true;}else failed++;}
        repack33(p+20,d); packets++; if(any)changed++; return true;
    }
    bool process_dmrplus(uint8_t*p,size_t n,uint64_t key){
        if(n!=72)return false; uint8_t typ=p[8]; if(!(typ==1||typ==3))return false; bool slot2=(p[16]==0x22),group=(p[62]==1),cc=((p[20]&0x0F)==1);
        if(!slot2||!group||!cc)return false; uint8_t fr[34];std::memcpy(fr,p+26,34);swap34(fr);uint8_t d[27];extract33(fr,d);auto*s=st(key);if(!s)return false;bool any=false;
        if(global_natural_dmr_) {
            s->gain_override_active = false;
            s->mode = StreamState::NaturalMode::Bypass;
            for(int i=0;i<3;i++) { if(!s->measure_only(d+i*9)) failed++; else frames++; }
            packets++;
            if(typ==3) erase(key);
            return true;
        }
        if(adaptive_gain_dmr_) {
            s->gain_override_active = false;
            for(int i=0;i<3;i++) {
                uint8_t before[9]; std::memcpy(before,d+i*9,9);
                if(!s->measure_only(d+i*9)) { failed++; continue; }
                frames++; s->observe_adaptive();
                if(s->adaptive_ready()) {
                    const float db=s->adaptive_correction_db();
                    if(std::abs(db)>=0.05f) CYsfUtils::AdjustAmbeGain(d+i*9,db);
                }
                if(std::memcmp(before,d+i*9,9)!=0) any=true;
            }
            repack33(fr,d);swap34(fr);std::memcpy(p+26,fr,34);packets++;if(any)changed++;if(typ==3)erase(key);return true;
        }
        for(int i=0;i<3;i++){uint8_t before[9];std::memcpy(before,d+i*9,9);if(s->frame(d+i*9)){frames++;if(std::memcmp(before,d+i*9,9)!=0)any=true;}else failed++;}
        repack33(fr,d);swap34(fr);std::memcpy(p+26,fr,34);packets++;if(any)changed++;if(typ==3)erase(key);return true;
    }
};
}
