#pragma once
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <sstream>
#include <string>

namespace xlx026 {

constexpr double kFs = 8000.0;
constexpr double kFullScale = 32768.0;
inline double db_to_lin(double db) { return std::pow(10.0, db / 20.0); }
inline double lin_to_db(double x) { return 20.0 * std::log10(std::max(x, 1e-12)); }
inline double dbfs_from_rms(double rms) { return lin_to_db(rms / kFullScale); }
inline double clampd(double v, double lo, double hi) { return std::max(lo, std::min(hi, v)); }

struct VoiceProfile {
    double target_rms_dbfs = -25.0;
    double target_low_share = 0.34;
    double target_mid_share = 0.46;
    double target_high_share = 0.20;
    double tone_max_db = 0.0;
    double agc_up_max_db = 9.0;
    double agc_down_max_db = -12.0;
    double compressor_threshold_dbfs = -13.0;
    double compressor_ratio = 2.5;
    double expander_threshold_dbfs = -45.0;
    double expander_ratio = 1.35;
    double expander_floor_db = -9.0;
    double limiter_dbfs = -3.0;
    double active_gate_dbfs = -48.0;
    double adaptive_target_rms_dbfs = -30.0;
    double adaptive_deadband_db = 3.0;
    double adaptive_max_gain_db = 1.0;
    double adaptive_coded_gain_per_pcm_db = 0.125;
    double adaptive_speech_gate_dbfs = -50.0;

    bool save(const std::string& path) const {
        std::ofstream f(path);
        if (!f) return false;
        f << "target_rms_dbfs=" << target_rms_dbfs << "\n";
        f << "target_low_share=" << target_low_share << "\n";
        f << "target_mid_share=" << target_mid_share << "\n";
        f << "target_high_share=" << target_high_share << "\n";
        f << "tone_max_db=" << tone_max_db << "\n";
        f << "agc_up_max_db=" << agc_up_max_db << "\n";
        f << "agc_down_max_db=" << agc_down_max_db << "\n";
        f << "compressor_threshold_dbfs=" << compressor_threshold_dbfs << "\n";
        f << "compressor_ratio=" << compressor_ratio << "\n";
        f << "expander_threshold_dbfs=" << expander_threshold_dbfs << "\n";
        f << "expander_ratio=" << expander_ratio << "\n";
        f << "expander_floor_db=" << expander_floor_db << "\n";
        f << "limiter_dbfs=" << limiter_dbfs << "\n";
        f << "active_gate_dbfs=" << active_gate_dbfs << "\n";
        f << "adaptive_target_rms_dbfs=" << adaptive_target_rms_dbfs << "\n";
        f << "adaptive_deadband_db=" << adaptive_deadband_db << "\n";
        f << "adaptive_max_gain_db=" << adaptive_max_gain_db << "\n";
        f << "adaptive_coded_gain_per_pcm_db=" << adaptive_coded_gain_per_pcm_db << "\n";
        f << "adaptive_speech_gate_dbfs=" << adaptive_speech_gate_dbfs << "\n";
        return true;
    }

    bool load(const std::string& path) {
        std::ifstream f(path);
        if (!f) return false;
        std::string line;
        while (std::getline(f, line)) {
            if (line.empty() || line[0] == '#') continue;
            const auto p = line.find('=');
            if (p == std::string::npos) continue;
            const std::string k = line.substr(0, p);
            const double v = std::stod(line.substr(p + 1));
            if (k == "target_rms_dbfs") target_rms_dbfs = v;
            else if (k == "target_low_share") target_low_share = v;
            else if (k == "target_mid_share") target_mid_share = v;
            else if (k == "target_high_share") target_high_share = v;
            else if (k == "tone_max_db") tone_max_db = v;
            else if (k == "agc_up_max_db") agc_up_max_db = v;
            else if (k == "agc_down_max_db") agc_down_max_db = v;
            else if (k == "compressor_threshold_dbfs") compressor_threshold_dbfs = v;
            else if (k == "compressor_ratio") compressor_ratio = v;
            else if (k == "expander_threshold_dbfs") expander_threshold_dbfs = v;
            else if (k == "expander_ratio") expander_ratio = v;
            else if (k == "expander_floor_db") expander_floor_db = v;
            else if (k == "limiter_dbfs") limiter_dbfs = v;
            else if (k == "active_gate_dbfs") active_gate_dbfs = v;
            else if (k == "adaptive_target_rms_dbfs") adaptive_target_rms_dbfs = v;
            else if (k == "adaptive_deadband_db") adaptive_deadband_db = v;
            else if (k == "adaptive_max_gain_db") adaptive_max_gain_db = v;
            else if (k == "adaptive_coded_gain_per_pcm_db") adaptive_coded_gain_per_pcm_db = v;
            else if (k == "adaptive_speech_gate_dbfs") adaptive_speech_gate_dbfs = v;
        }
        const double s = target_low_share + target_mid_share + target_high_share;
        if (s <= 0.01) return false;
        target_low_share /= s;
        target_mid_share /= s;
        target_high_share /= s;
        return true;
    }
};

struct DspStats {
    uint64_t frames = 0;
    uint64_t active_frames = 0;
    uint64_t limiter_hits = 0;
    double last_input_rms_dbfs = -120.0;
    double last_input_peak_dbfs = -120.0;
    double last_output_rms_dbfs = -120.0;
    double agc_db = 0.0;
    double low_gain_db = 0.0;
    double mid_gain_db = 0.0;
    double high_gain_db = 0.0;
};

class VoiceNormalizer {
public:
    explicit VoiceNormalizer(const VoiceProfile& p = VoiceProfile()) : p_(p) {
        hp_a_ = std::exp(-2.0 * M_PI * 180.0 / kFs);
        lp700_alpha_ = 1.0 - std::exp(-2.0 * M_PI * 700.0 / kFs);
        lp1800_alpha_ = 1.0 - std::exp(-2.0 * M_PI * 1800.0 / kFs);
        comp_attack_ = std::exp(-1.0 / (0.004 * kFs));
        comp_release_ = std::exp(-1.0 / (0.090 * kFs));
        limiter_release_ = std::exp(-1.0 / (0.060 * kFs));
        limiter_gain_ = 1.0;
    }

    void reset() {
        *this = VoiceNormalizer(p_);
    }

    void set_profile(const VoiceProfile& p) { p_ = p; }
    const DspStats& stats() const { return stats_; }
    bool passthrough_pause() const { return confirmed_pause_; }

    void process(int16_t* samples, size_t n) {
        if (!samples || n == 0) return;
        ++stats_.frames;

        std::array<double, 320> low{};
        std::array<double, 320> mid{};
        std::array<double, 320> high{};
        if (n > low.size()) n = low.size();

        double in_sumsq = 0.0;
        double in_peak = 0.0;
        double e_low = 0.0, e_mid = 0.0, e_high = 0.0;

        for (size_t i = 0; i < n; ++i) {
            const double x0 = static_cast<double>(samples[i]);
            const double hp = hp_a_ * (hp_y1_ + x0 - hp_x1_);
            hp_x1_ = x0;
            hp_y1_ = hp;

            lp700_ += lp700_alpha_ * (hp - lp700_);
            lp1800_ += lp1800_alpha_ * (hp - lp1800_);
            const double l = lp700_;
            const double m = lp1800_ - lp700_;
            const double h = hp - lp1800_;
            low[i] = l; mid[i] = m; high[i] = h;
            e_low += l*l; e_mid += m*m; e_high += h*h;
            in_sumsq += hp*hp;
            in_peak = std::max(in_peak, std::abs(hp));
        }

        const double in_rms = std::sqrt(in_sumsq / static_cast<double>(n));
        const double in_dbfs = dbfs_from_rms(in_rms);
        stats_.last_input_rms_dbfs = in_dbfs;
        stats_.last_input_peak_dbfs = dbfs_from_rms(in_peak);

        // SAFE V4 speech detector: robust speech reference, immune to isolated
        // AMBE level spikes. Only confirmed speech updates the reference;
        // inter-word QRM therefore cannot drag the detector or AGC toward noise.
        auto update_speech_reference = [&](double v) {
            ref_window_[ref_pos_] = v;
            ref_pos_ = (ref_pos_ + 1) % ref_window_.size();
            if (ref_count_ < ref_window_.size()) ++ref_count_;

            std::array<double, 25> tmp{};
            for (size_t i = 0; i < ref_count_; ++i) tmp[i] = ref_window_[i];
            std::sort(tmp.begin(), tmp.begin() + static_cast<long>(ref_count_));
            // 75th percentile: follows normal speech energy but rejects one-off peaks.
            const size_t idx = (ref_count_ - 1) * 3 / 4;
            speech_ref_dbfs_ = tmp[idx];
            if (ref_count_ >= 12) level_ref_ready_ = true; // ~240 ms of usable audio
        };

        const bool startup_phase = !level_ref_ready_;
        if (!level_ref_ready_ && in_dbfs >= -55.0) {
            // Startup is transparent: collect evidence but never attenuate it.
            update_speech_reference(in_dbfs);
        }

        double speech_threshold_dbfs = -48.0;
        bool speech_detected = false;
        if (level_ref_ready_) {
            speech_threshold_dbfs = std::max(-46.0, speech_ref_dbfs_ - 6.0);
            speech_detected = in_dbfs >= speech_threshold_dbfs;
            if (speech_detected && !startup_phase) {
                update_speech_reference(in_dbfs);
                speech_threshold_dbfs = std::max(-46.0, speech_ref_dbfs_ - 6.0);
            }
        }

        if (speech_detected) {
            ever_speech_detected_ = true;
            speech_active_ = true;
            speech_hold_frames_ = 4; // 80 ms: protect word endings, never hard-gate.
        } else if (speech_hold_frames_ > 0) {
            --speech_hold_frames_;
        } else {
            speech_active_ = false;
        }

        // Permissive level estimator is available only during startup or an
        // already-confirmed speech context. It cannot restart itself from QRM.
        const double level_threshold_dbfs = level_ref_ready_
            ? std::max(-48.0, speech_ref_dbfs_ - 10.0)
            : p_.active_gate_dbfs;
        const bool agc_active = (startup_phase && in_dbfs >= p_.active_gate_dbfs) ||
            speech_detected || (speech_active_ && in_dbfs >= level_threshold_dbfs);
        confirmed_pause_ = !speech_detected;
        const bool active = agc_active;
        if (active) ++stats_.active_frames;

        const double et = e_low + e_mid + e_high + 1e-9;
        const double s_low = e_low / et;
        const double s_mid = e_mid / et;
        const double s_high = e_high / et;

        if (active) {
            if (!spectral_ready_) {
                cur_low_share_ = s_low; cur_mid_share_ = s_mid; cur_high_share_ = s_high;
                spectral_ready_ = true;
            } else {
                constexpr double a = 0.035; // ~0.6 s at 20 ms frames
                cur_low_share_ += a * (s_low - cur_low_share_);
                cur_mid_share_ += a * (s_mid - cur_mid_share_);
                cur_high_share_ += a * (s_high - cur_high_share_);
            }
        }

        auto tone_db = [&](double target, double current) {
            // Energy-share ratio -> required amplitude dB is 10*log10(target/current).
            return clampd(10.0 * std::log10(std::max(target, 1e-6) / std::max(current, 1e-6)),
                          -p_.tone_max_db, p_.tone_max_db);
        };

        double goal_l = spectral_ready_ ? tone_db(p_.target_low_share, cur_low_share_) : 0.0;
        double goal_m = spectral_ready_ ? tone_db(p_.target_mid_share, cur_mid_share_) : 0.0;
        double goal_h = spectral_ready_ ? tone_db(p_.target_high_share, cur_high_share_) : 0.0;
        // Remove common gain: EQ should change tonal balance, not overall loudness.
        const double common = (goal_l + goal_m + goal_h) / 3.0;
        goal_l -= common; goal_m -= common; goal_h -= common;
        constexpr double eq_smooth = 0.025;
        eq_l_db_ += eq_smooth * (goal_l - eq_l_db_);
        eq_m_db_ += eq_smooth * (goal_m - eq_m_db_);
        eq_h_db_ += eq_smooth * (goal_h - eq_h_db_);
        stats_.low_gain_db = eq_l_db_;
        stats_.mid_gain_db = eq_m_db_;
        stats_.high_gain_db = eq_h_db_;

        const double gl = db_to_lin(eq_l_db_);
        const double gm = db_to_lin(eq_m_db_);
        const double gh = db_to_lin(eq_h_db_);

        std::array<double, 320> eq{};
        double eq_sumsq = 0.0;
        for (size_t i = 0; i < n; ++i) {
            eq[i] = low[i]*gl + mid[i]*gm + high[i]*gh;
            eq_sumsq += eq[i]*eq[i];
        }
        const double eq_rms = std::sqrt(eq_sumsq / static_cast<double>(n));
        const double eq_dbfs = dbfs_from_rms(eq_rms);

        double desired_agc_db = agc_db_;
        if (active) {
            desired_agc_db = clampd(p_.target_rms_dbfs - eq_dbfs,
                                    p_.agc_down_max_db, p_.agc_up_max_db);
            const double a = (desired_agc_db < agc_db_) ? 0.22 : 0.030; // down fast, up deliberately slow
            agc_db_ += a * (desired_agc_db - agc_db_);
        }
        // On an inter-word pause AGC is FROZEN. It never chases QRM upward.
        stats_.agc_db = agc_db_;
        const double agc = db_to_lin(agc_db_);

        double exp_db = 0.0;
        if (ever_speech_detected_ && !speech_detected && speech_hold_frames_ == 0) {
            // Soft pause expander. First cancel any positive AGC boost so
            // background noise is never louder than it entered. Then add a
            // small amount of attenuation proportional to the gap below the
            // speech threshold. No mute is used, so starts/ends are preserved.
            const double gap_db = std::max(0.0, speech_threshold_dbfs - eq_dbfs);
            const double cancel_boost_db = std::max(0.0, agc_db_);
            const double pause_atten_db = std::min(18.0,
                std::max(cancel_boost_db + 9.0, gap_db * 1.25));
            exp_db = -pause_atten_db;
        } else if (eq_dbfs < p_.expander_threshold_dbfs) {
            // Very low-level material still gets the legacy gentle expansion.
            exp_db = -(p_.expander_threshold_dbfs - eq_dbfs) * (p_.expander_ratio - 1.0);
            exp_db = std::max(exp_db, p_.expander_floor_db);
        }

        if (speech_detected) {
            // Fast release on a new syllable: at most a tiny fraction of the
            // previous pause attenuation survives the first 20 ms frame.
            expander_db_ *= 0.12;
        } else if (speech_hold_frames_ > 0) {
            // Hold the tail intact for 80 ms; drift gently back toward unity.
            expander_db_ += 0.35 * (0.0 - expander_db_);
        } else {
            // Smooth attenuation during the actual pause; never a hard cut.
            expander_db_ += 0.72 * (exp_db - expander_db_);
        }
        const double exp_gain = db_to_lin(expander_db_);

        const double limit = kFullScale * db_to_lin(p_.limiter_dbfs);
        double out_sumsq = 0.0;

        for (size_t i = 0; i < n; ++i) {
            double y = eq[i] * agc * exp_gain;

            // Envelope compressor, soft in time, no hard frame-to-frame pumping.
            const double a = std::abs(y);
            if (a > comp_env_)
                comp_env_ = comp_attack_ * comp_env_ + (1.0 - comp_attack_) * a;
            else
                comp_env_ = comp_release_ * comp_env_ + (1.0 - comp_release_) * a;

            double comp_gain = 1.0;
            const double env_dbfs = dbfs_from_rms(comp_env_);
            if (env_dbfs > p_.compressor_threshold_dbfs) {
                const double over = env_dbfs - p_.compressor_threshold_dbfs;
                const double out_over = over / std::max(1.01, p_.compressor_ratio);
                const double gr_db = out_over - over;
                comp_gain = db_to_lin(gr_db);
            }
            y *= comp_gain;

            // Fast limiter attack and slow release; final clamp is a safety net.
            const double ay = std::abs(y);
            double wanted = 1.0;
            if (ay > limit && ay > 1.0) wanted = limit / ay;
            if (wanted < limiter_gain_) limiter_gain_ = wanted;
            else limiter_gain_ = limiter_release_ * limiter_gain_ + (1.0 - limiter_release_);
            y *= limiter_gain_;
            if (std::abs(y) > limit) {
                y = std::copysign(limit, y);
                ++stats_.limiter_hits;
            }

            y = clampd(y, -32768.0, 32767.0);
            samples[i] = static_cast<int16_t>(std::lrint(y));
            out_sumsq += y*y;
        }

        stats_.last_output_rms_dbfs = dbfs_from_rms(std::sqrt(out_sumsq / static_cast<double>(n)));
    }

private:
    VoiceProfile p_;
    DspStats stats_{};
    double hp_a_=0, hp_x1_=0, hp_y1_=0;
    double lp700_alpha_=0, lp1800_alpha_=0, lp700_=0, lp1800_=0;
    bool spectral_ready_=false;
    double cur_low_share_=0.34, cur_mid_share_=0.46, cur_high_share_=0.20;
    double eq_l_db_=0, eq_m_db_=0, eq_h_db_=0;
    double agc_db_=0, expander_db_=0;
    bool level_ref_ready_=false, speech_active_=false, ever_speech_detected_=false, confirmed_pause_=false;
    int speech_hold_frames_=0;
    std::array<double,25> ref_window_{};
    size_t ref_count_=0, ref_pos_=0;
    double speech_ref_dbfs_=-120.0;
    double comp_env_=0, comp_attack_=0, comp_release_=0;
    double limiter_gain_=1, limiter_release_=0;
};

} // namespace xlx026
