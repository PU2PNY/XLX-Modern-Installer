#pragma once

#include <poll.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#include <algorithm>
#include <array>
#include <cerrno>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <string>

namespace xuv {

constexpr std::size_t HELIX_PCM_MAX_SAMPLES = 960;
constexpr std::size_t HELIX_PCM_HEADER_LEN = 24;
constexpr std::size_t HELIX_PCM_MAX_PACKET =
    HELIX_PCM_HEADER_LEN + HELIX_PCM_MAX_SAMPLES * sizeof(std::int16_t);
constexpr std::uint8_t HELIX_PCM_VERSION = 1;
constexpr std::uint8_t HELIX_PCM_APPLY_DSP = 0x01;
constexpr std::uint8_t HELIX_PCM_RESET_STREAM = 0x02;
constexpr std::uint8_t HELIX_PCM_OK = 0x80;

class HelixPcmClient {
public:
    explicit HelixPcmClient(const std::string& socket_path, int timeout_ms = 1)
        : socket_path_(socket_path),
          timeout_ms_(timeout_ms < 1 ? 1 : (timeout_ms > 5 ? 5 : timeout_ms)) {}

    ~HelixPcmClient() { disconnect(); }

    HelixPcmClient(const HelixPcmClient&) = delete;
    HelixPcmClient& operator=(const HelixPcmClient&) = delete;

    bool process(
        std::uint32_t stream_id,
        std::uint32_t sample_rate_hz,
        std::uint64_t timestamp_samples,
        std::int16_t* samples,
        std::size_t sample_count,
        bool reset_stream,
        bool apply_dsp,
        bool commit_output
    ) {
        if (!samples || sample_count == 0 || sample_count > HELIX_PCM_MAX_SAMPLES)
            return false;
        if (sample_rate_hz < 8000 || sample_rate_hz > 48000)
            return false;

        std::array<std::int16_t, HELIX_PCM_MAX_SAMPLES> original{};
        std::copy(samples, samples + sample_count, original.begin());

        if (!ensure_connected())
            return false;

        std::array<std::uint8_t, HELIX_PCM_MAX_PACKET> wire{};
        std::memcpy(wire.data(), "HXP1", 4);
        wire[4] = HELIX_PCM_VERSION;
        wire[5] = static_cast<std::uint8_t>(
            (apply_dsp ? HELIX_PCM_APPLY_DSP : 0) |
            (reset_stream ? HELIX_PCM_RESET_STREAM : 0)
        );
        write_le16(&wire[6], static_cast<std::uint16_t>(sample_count));
        write_le32(&wire[8], stream_id);
        write_le32(&wire[12], sample_rate_hz);
        write_le64(&wire[16], timestamp_samples);

        for (std::size_t i = 0; i < sample_count; ++i) {
            write_le16(
                &wire[HELIX_PCM_HEADER_LEN + i * 2],
                static_cast<std::uint16_t>(original[i])
            );
        }

        const std::size_t packet_len = HELIX_PCM_HEADER_LEN + sample_count * 2;
        if (!write_all(wire.data(), packet_len)) {
            disconnect();
            return false;
        }

        std::array<std::uint8_t, HELIX_PCM_MAX_PACKET> response{};
        if (!read_all(response.data(), HELIX_PCM_HEADER_LEN)) {
            disconnect();
            return false;
        }

        if (std::memcmp(response.data(), "HXP1", 4) != 0 ||
            response[4] != HELIX_PCM_VERSION ||
            (response[5] & HELIX_PCM_OK) == 0 ||
            static_cast<std::size_t>(read_le16(&response[6])) != sample_count ||
            read_le32(&response[8]) != stream_id ||
            read_le32(&response[12]) != sample_rate_hz ||
            read_le64(&response[16]) != timestamp_samples) {
            disconnect();
            return false;
        }

        if (!read_all(&response[HELIX_PCM_HEADER_LEN], sample_count * 2)) {
            disconnect();
            return false;
        }

        if (commit_output) {
            for (std::size_t i = 0; i < sample_count; ++i) {
                const std::uint16_t bits =
                    read_le16(&response[HELIX_PCM_HEADER_LEN + i * 2]);
                samples[i] = static_cast<std::int16_t>(bits);
            }
        }
        return true;
    }

    void disconnect() {
        if (fd_ >= 0) {
            close(fd_);
            fd_ = -1;
        }
    }

private:
    bool ensure_connected() {
        if (fd_ >= 0)
            return true;
        if (socket_path_.empty() || socket_path_.size() >= sizeof(sockaddr_un::sun_path))
            return false;

        const int fd = socket(AF_UNIX, SOCK_STREAM, 0);
        if (fd < 0)
            return false;

        sockaddr_un sa{};
        sa.sun_family = AF_UNIX;
        std::memcpy(sa.sun_path, socket_path_.c_str(), socket_path_.size() + 1);
        if (connect(fd, reinterpret_cast<sockaddr*>(&sa), sizeof(sa)) != 0) {
            close(fd);
            return false;
        }
        fd_ = fd;
        return true;
    }

    bool wait_ready(short events) const {
        pollfd pfd{fd_, events, 0};
        int rc;
        do {
            rc = poll(&pfd, 1, timeout_ms_);
        } while (rc < 0 && errno == EINTR);
        return rc > 0 && (pfd.revents & events) != 0;
    }

    bool write_all(const std::uint8_t* data, std::size_t len) {
        std::size_t done = 0;
        while (done < len) {
            if (!wait_ready(POLLOUT))
                return false;
            const ssize_t n = send(fd_, data + done, len - done, MSG_NOSIGNAL);
            if (n <= 0)
                return false;
            done += static_cast<std::size_t>(n);
        }
        return true;
    }

    bool read_all(std::uint8_t* data, std::size_t len) {
        std::size_t done = 0;
        while (done < len) {
            if (!wait_ready(POLLIN))
                return false;
            const ssize_t n = recv(fd_, data + done, len - done, 0);
            if (n <= 0)
                return false;
            done += static_cast<std::size_t>(n);
        }
        return true;
    }

    static void write_le16(std::uint8_t* p, std::uint16_t value) {
        p[0] = static_cast<std::uint8_t>(value & 0xff);
        p[1] = static_cast<std::uint8_t>((value >> 8) & 0xff);
    }

    static std::uint16_t read_le16(const std::uint8_t* p) {
        return static_cast<std::uint16_t>(p[0]) |
               (static_cast<std::uint16_t>(p[1]) << 8);
    }

    static void write_le32(std::uint8_t* p, std::uint32_t value) {
        for (int i = 0; i < 4; ++i)
            p[i] = static_cast<std::uint8_t>((value >> (8 * i)) & 0xff);
    }

    static std::uint32_t read_le32(const std::uint8_t* p) {
        std::uint32_t value = 0;
        for (int i = 0; i < 4; ++i)
            value |= static_cast<std::uint32_t>(p[i]) << (8 * i);
        return value;
    }

    static void write_le64(std::uint8_t* p, std::uint64_t value) {
        for (int i = 0; i < 8; ++i)
            p[i] = static_cast<std::uint8_t>((value >> (8 * i)) & 0xff);
    }

    static std::uint64_t read_le64(const std::uint8_t* p) {
        std::uint64_t value = 0;
        for (int i = 0; i < 8; ++i)
            value |= static_cast<std::uint64_t>(p[i]) << (8 * i);
        return value;
    }

    std::string socket_path_;
    int timeout_ms_ = 1;
    int fd_ = -1;
};

} // namespace xuv
