#include "adapter.hpp"
#include "helix_pcm_client.hpp"

#include <arpa/inet.h>
#include <poll.h>
#include <sys/socket.h>
#include <unistd.h>

#include <algorithm>
#include <array>
#include <cerrno>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <map>
#include <memory>
#include <vector>

#include "mbelib.h"
#include "ambe.h"
#include "p25p2_vf.h"
#include "imbe_vocoder/imbe_vocoder.h"
#include "ambe_encoder.h"
#include "software_imbe_decoder.h"
#include <cmath>
#include <cstdlib>
#include <string>

namespace {

constexpr uint8_t CODEC_DSTAR = 1;
constexpr uint8_t CODEC_AMBE2 = 2;
constexpr uint16_t CONTROL_PORT = 10100;
constexpr uint16_t STREAM_FIRST = 10101;
constexpr uint16_t STREAM_LAST  = 10199;
constexpr size_t MAX_STREAMS = 4;
constexpr int NSAMP = 160;
using xuv::XlxVoice9;
using xuv::Bits72;
using xuv::Dibits36;

enum class HelixMode { Off, Shadow, Process };
HelixMode helix_mode_from_env() { const char* value = std::getenv("XLX_HELIX_MODE"); if (!value || !*value || std::strcmp(value, "off") == 0) return HelixMode::Off; if (std::strcmp(value, "shadow") == 0) return HelixMode::Shadow; if (std::strcmp(value, "process") == 0) return HelixMode::Process; return HelixMode::Off; }
const char* helix_mode_name(HelixMode mode) { switch (mode) { case HelixMode::Shadow: return "shadow"; case HelixMode::Process: return "process"; default: return "off"; } }
std::string helix_socket_from_env() { const char* value = std::getenv("XLX_HELIX_SOCKET"); if (value && *value) return value; return "/run/helix-voice/pcm.sock"; }
std::string helix_observe_socket_from_env() { const char* value = std::getenv("XLX_HELIX_OBSERVE_SOCKET"); if (value && *value) return value; return "/run/helix-voice/observe.sock"; }
int helix_timeout_from_env() { const char* value = std::getenv("XLX_HELIX_TIMEOUT_MS"); if (!value || !*value) return 5; const int parsed = std::atoi(value); if (parsed < 1) return 1; if (parsed > 5) return 5; return parsed; }
xuv::HelixPcmClient* shared_helix_client() { static std::unique_ptr<xuv::HelixPcmClient> client; static bool initialized = false; if (!initialized) { initialized = true; if (helix_mode_from_env() == HelixMode::Process) { client = std::make_unique<xuv::HelixPcmClient>(helix_socket_from_env(), helix_timeout_from_env()); (void)client->prime(); } } return client.get(); }
xuv::HelixPcmObserver* shared_helix_observer() { static std::unique_ptr<xuv::HelixPcmObserver> observer; static bool initialized = false; if (!initialized) { initialized = true; if (helix_mode_from_env() == HelixMode::Shadow) observer = std::make_unique<xuv::HelixPcmObserver>(helix_observe_socket_from_env()); } return observer.get(); }
uint16_t read_le16(const uint8_t* p) { return static_cast<uint16_t>(p[0]) | (static_cast<uint16_t>(p[1]) << 8); }
void write_le16(uint8_t* p, uint16_t v) { p[0] = static_cast<uint8_t>(v & 0xff); p[1] = static_cast<uint8_t>((v >> 8) & 0xff); }

enum class AudioProfile { Legacy, UnifiedV1 };
AudioProfile audio_profile_from_env() { const char* value = std::getenv("XLX_AUDIO_PROFILE"); if (value && std::strcmp(value, "unified-v1") == 0) return AudioProfile::UnifiedV1; return AudioProfile::Legacy; }
const char* audio_profile_name(AudioProfile profile) { return profile == AudioProfile::UnifiedV1 ? "unified-v1" : "legacy"; }

struct UnifiedAudioProcessor {
    double hp_x1 = 0.0, hp_y1 = 0.0, lp_y1 = 0.0, presence_lp = 0.0, low_mid_lo = 0.0, low_mid_hi = 0.0, gain = 1.0;
    bool gain_initialized = false;
    static double clampd(double value, double low, double high) { return std::max(low, std::min(value, high)); }
    void process(std::array<int16_t, NSAMP>& pcm, uint8_t in_codec, uint8_t out_codec) {
        const bool to_dstar = out_codec == CODEC_DSTAR;
        // Unified V1.3 — anti-box / anti-muffle profile.
        // PROD operator sample showed dominant 500-1000 Hz energy and recessed 1-2.4 kHz presence.
        const double hp_alpha = to_dstar ? 0.7000 : 0.6900;
        const double lp_alpha = to_dstar ? 0.9000 : 0.8900;
        const double low_mid_lo_alpha = to_dstar ? 0.1100 : 0.1200;
        const double low_mid_hi_alpha = to_dstar ? 0.6200 : 0.6000;
        const double low_mid_cut = to_dstar ? 0.82 : 0.78;
        const double presence_alpha = to_dstar ? 0.5400 : 0.5600;
        const double presence_mix = to_dstar ? 0.58 : 0.52;
        double sumsq = 0.0;
        for (auto& sample : pcm) {
            const double x = static_cast<double>(sample);
            const double hp = hp_alpha * (hp_y1 + x - hp_x1); hp_x1 = x; hp_y1 = hp;
            const double lp = lp_y1 + lp_alpha * (hp - lp_y1); lp_y1 = lp;
            low_mid_lo += low_mid_lo_alpha * (lp - low_mid_lo);
            low_mid_hi += low_mid_hi_alpha * (lp - low_mid_hi);
            const double low_mid = low_mid_hi - low_mid_lo;
            presence_lp += presence_alpha * (lp - presence_lp);
            const double presence = lp - presence_lp;
            const double y = lp - (low_mid_cut * low_mid) + (presence_mix * presence);
            sample = static_cast<int16_t>(clampd(std::lround(y), -32768.0, 32767.0));
            sumsq += y * y;
        }
        const double rms = std::sqrt(sumsq / static_cast<double>(pcm.size()));
        const double target_rms = to_dstar ? 160.0 : 150.0;
        if (rms >= 45.0) {
            const double desired = clampd(target_rms / rms, 0.06, 1.00);
            if (!gain_initialized) { gain = desired; gain_initialized = true; }
            else { const double alpha = desired < gain ? 0.55 : 0.03; gain += alpha * (desired - gain); gain = std::min(gain, 1.0); }
        }
        double expander = 1.0;
        if (rms < 20.0) expander = 0.42;
        else if (rms < 45.0) expander = 0.42 + ((rms - 20.0) / 25.0) * 0.58;
        const double compress_threshold = to_dstar ? 900.0 : 800.0;
        const double limit = to_dstar ? 1220.0 : 1080.0;
        constexpr double compress_ratio = 3.0;
        for (auto& sample : pcm) {
            double y = static_cast<double>(sample) * gain * expander;
            const double sign = y < 0.0 ? -1.0 : 1.0;
            double mag = std::abs(y);
            if (mag > compress_threshold) mag = compress_threshold + (mag - compress_threshold) / compress_ratio;
            mag = std::min(mag, limit);
            sample = static_cast<int16_t>(std::lround(sign * mag));
        }
        (void)in_codec;
    }
};

// Archived V1.3 candidate: full working source remains preserved in the corresponding ENV artifact and branch history.
// This file intentionally records the exact DSP candidate block and surrounding runtime contract before rollback.

} // namespace
