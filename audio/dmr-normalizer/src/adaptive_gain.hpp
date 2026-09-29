#pragma once
#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>

namespace xlx026 {

struct AdaptiveGainConfig {
    double target_dbfs = -30.0;
    double deadband_db = 3.5;
    double hard_limit_db = 1.0;
    double coded_gain_per_pcm_db = 0.125;
    double speech_gate_dbfs = -50.0;
    std::size_t min_samples = 40;
    std::size_t max_frames = 100;
};

class AdaptiveGain {
public:
    explicit AdaptiveGain(const AdaptiveGainConfig& cfg = AdaptiveGainConfig()) : cfg_(cfg) {}

    void reset() {
        samples_.fill(0.0);
        count_ = 0;
        frames_ = 0;
        ready_ = false;
        median_dbfs_ = -120.0;
        correction_db_ = 0.0;
    }

    void observe(double rms_dbfs) {
        if (ready_) return;
        ++frames_;
        if (std::isfinite(rms_dbfs) && rms_dbfs >= cfg_.speech_gate_dbfs && count_ < samples_.size())
            samples_[count_++] = rms_dbfs;

        const std::size_t needed = std::max<std::size_t>(1, std::min(cfg_.min_samples, samples_.size()));
        if (count_ >= needed) {
            std::array<double, 64> tmp = samples_;
            std::sort(tmp.begin(), tmp.begin() + static_cast<long>(count_));
            median_dbfs_ = (count_ & 1U) ? tmp[count_ / 2U]
                : 0.5 * (tmp[count_ / 2U - 1U] + tmp[count_ / 2U]);
            const double err = cfg_.target_dbfs - median_dbfs_;
            const double deadband = std::max(0.0, cfg_.deadband_db);
            // AMBE b2 "dB" is not 1:1 with decoded PCM level. Offline XLX026
            // calibration showed ±3 was far too aggressive. Keep the coded
            // adjustment within ±1.0 and scale PCM error conservatively.
            const double hard = std::min(1.0, std::max(0.0, std::abs(cfg_.hard_limit_db)));
            const double scale = std::max(0.0, cfg_.coded_gain_per_pcm_db);
            const double requested = err * scale;
            correction_db_ = (std::abs(err) <= deadband) ? 0.0
                : std::max(-hard, std::min(hard, requested));
            ready_ = true;
        } else if (frames_ >= std::max<std::size_t>(needed, cfg_.max_frames)) {
            correction_db_ = 0.0; // fail open
            ready_ = true;
        }
    }

    bool ready() const { return ready_; }
    double correction_db() const { return correction_db_; }
    double measured_median_dbfs() const { return median_dbfs_; }

private:
    AdaptiveGainConfig cfg_;
    std::array<double, 64> samples_{};
    std::size_t count_ = 0;
    std::size_t frames_ = 0;
    bool ready_ = false;
    double median_dbfs_ = -120.0;
    double correction_db_ = 0.0;
};

} // namespace xlx026
