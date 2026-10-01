// Deterministic compatibility corpus for the experimental Helix/XUV bridge.
//
// This file contains no OP25/mbelib implementation. It is a small harness that
// is compiled by test-prod-equivalence.sh against an operator-supplied,
// license-reviewed OP25 source tree.
//
// SPDX-License-Identifier: MIT

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

namespace {

std::uint16_t read_le16(const std::uint8_t* p) {
    return static_cast<std::uint16_t>(p[0]) |
           (static_cast<std::uint16_t>(p[1]) << 8);
}

void write_le16(std::uint8_t* p, std::uint16_t value) {
    p[0] = static_cast<std::uint8_t>(value & 0xff);
    p[1] = static_cast<std::uint8_t>((value >> 8) & 0xff);
}

void make_pcm(int frame, std::int16_t* pcm) {
    constexpr double kPi = 3.14159265358979323846;
    constexpr double freqs[] = {180.0, 300.0, 700.0, 1200.0, 1800.0, 2600.0, 3200.0};
    constexpr double amps[] = {350.0, 1200.0, 3500.0, 7000.0, 12000.0, 22000.0};

    const double f1 = freqs[frame % 7];
    const double f2 = freqs[(frame * 3 + 2) % 7];
    const double amp = amps[(frame / 7) % 6];
    std::uint32_t noise_state = 0x9e3779b9u ^ static_cast<std::uint32_t>(frame * 2654435761u);

    for (int index = 0; index < 160; ++index) {
        const double t = static_cast<double>(frame * 160 + index) / 8000.0;
        noise_state ^= noise_state << 13;
        noise_state ^= noise_state >> 17;
        noise_state ^= noise_state << 5;
        const double noise =
            (static_cast<double>(static_cast<int>(noise_state & 0xffff) - 32768) / 32768.0) *
            0.015 * amp;
        double value =
            0.72 * amp * std::sin(2.0 * kPi * f1 * t) +
            0.28 * amp * std::sin(2.0 * kPi * f2 * t) +
            noise;
        if ((frame % 29) == 0) {
            value *= 0.08;
        }
        if (value > 32767.0) value = 32767.0;
        if (value < -32768.0) value = -32768.0;
        pcm[index] = static_cast<std::int16_t>(std::lround(value));
    }
}

} // namespace

int main(int argc, char** argv) {
    if (argc != 4) {
        std::cerr << "usage: helix-equivalence-corpus <in-codec> <out-codec> <module>\n";
        return 2;
    }

    const int in_codec = std::atoi(argv[1]);
    const int out_codec = std::atoi(argv[2]);
    const char module = argv[3][0];
    if (!((in_codec == 1 && out_codec == 2) || (in_codec == 2 && out_codec == 1))) {
        return 2;
    }

    const int fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (fd < 0) return 3;

    timeval timeout{1, 0};
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));

    sockaddr_in control{};
    control.sin_family = AF_INET;
    control.sin_port = htons(10100);
    inet_pton(AF_INET, "127.0.0.1", &control.sin_addr);

    std::uint8_t open_packet[18]{};
    std::memcpy(open_packet, "AMBEDOS", 7);
    std::memcpy(open_packet + 7, "XLX999  ", 8);
    open_packet[15] = static_cast<std::uint8_t>(in_codec);
    open_packet[16] = static_cast<std::uint8_t>(out_codec);
    open_packet[17] = static_cast<std::uint8_t>(module);

    if (sendto(fd, open_packet, sizeof(open_packet), 0,
               reinterpret_cast<sockaddr*>(&control), sizeof(control)) !=
        static_cast<ssize_t>(sizeof(open_packet))) {
        close(fd);
        return 4;
    }

    std::uint8_t response[32]{};
    socklen_t address_len = sizeof(control);
    const ssize_t open_len = recvfrom(
        fd, response, sizeof(response), 0,
        reinterpret_cast<sockaddr*>(&control), &address_len);
    if (open_len != 14 || std::memcmp(response, "AMBEDSTD", 8) != 0) {
        close(fd);
        return 5;
    }

    const std::uint16_t stream_id = read_le16(response + 8);
    const std::uint16_t stream_port = read_le16(response + 10);

    ambe_encoder encoder;
    if (in_codec == 1) {
        encoder.set_dstar_mode();
        encoder.set_alt_dstar_interleave(true);
    }

    sockaddr_in stream_address{};
    stream_address.sin_family = AF_INET;
    stream_address.sin_port = htons(stream_port);
    inet_pton(AF_INET, "127.0.0.1", &stream_address.sin_addr);

    for (int frame = 0; frame < 140; ++frame) {
        std::int16_t pcm[160]{};
        make_pcm(frame, pcm);

        std::uint8_t raw[72]{};
        encoder.encode(pcm, raw);

        xuv::XlxVoice9 packed{};
        if (in_codec == 2) {
            xuv::Dibits36 dibits{};
            for (std::size_t index = 0; index < dibits.size(); ++index) {
                dibits[index] = raw[index];
            }
            packed = xuv::ambe2_dibits_to_bytes(dibits);
        } else {
            xuv::Bits72 bits{};
            for (std::size_t index = 0; index < bits.size(); ++index) {
                bits[index] = raw[index] & 1;
            }
            packed = xuv::dstar_bits_to_bytes(bits);
        }

        // Limited deterministic corruption exercises FEC/PLC boundaries.
        if (frame % 17 == 5) packed[(frame / 17) % 9] ^= 0x01;
        if (frame % 31 == 9) packed[(frame / 31 + 3) % 9] ^= 0x04;
        if (frame % 47 == 11) packed[(frame / 47 + 5) % 9] ^= 0x10;

        std::uint8_t packet[11]{};
        packet[0] = static_cast<std::uint8_t>(in_codec);
        packet[1] = static_cast<std::uint8_t>(frame & 0xff);
        std::memcpy(packet + 2, packed.data(), packed.size());

        if (sendto(fd, packet, sizeof(packet), 0,
                   reinterpret_cast<sockaddr*>(&stream_address),
                   sizeof(stream_address)) != static_cast<ssize_t>(sizeof(packet))) {
            close(fd);
            return 6;
        }

        std::array<std::uint8_t, 11> output{};
        address_len = sizeof(stream_address);
        const ssize_t received = recvfrom(
            fd, output.data(), output.size(), 0,
            reinterpret_cast<sockaddr*>(&stream_address), &address_len);
        if (received != static_cast<ssize_t>(output.size()) ||
            output[0] != static_cast<std::uint8_t>(out_codec)) {
            close(fd);
            return 7;
        }

        std::fwrite(output.data(), 1, output.size(), stdout);
    }

    std::uint8_t close_packet[9]{};
    std::memcpy(close_packet, "AMBEDCS", 7);
    write_le16(close_packet + 7, stream_id);
    sendto(fd, close_packet, sizeof(close_packet), 0,
           reinterpret_cast<sockaddr*>(&control), sizeof(control));

    close(fd);
    return 0;
}
