#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

grep -q 'XLX_HELIX_MODE' "$ROOT/experimental/helix-bridge/xuvd.cpp"
grep -q 'HelixMode::Off' "$ROOT/experimental/helix-bridge/xuvd.cpp"
grep -q 'HelixMode::Shadow' "$ROOT/experimental/helix-bridge/xuvd.cpp"
grep -q 'HelixMode::Process' "$ROOT/experimental/helix-bridge/xuvd.cpp"
grep -q 'helix_fallback' "$ROOT/experimental/helix-bridge/xuvd.cpp"
grep -q 'HelixPcmObserver' "$ROOT/experimental/helix-bridge/xuvd.cpp"
grep -q 'SOCK_NONBLOCK' "$ROOT/experimental/helix-bridge/helix_pcm_client.hpp"
grep -q 'parsed > 10' "$ROOT/experimental/helix-bridge/xuvd.cpp"
grep -q 'helix_disabled_for_stream' "$ROOT/experimental/helix-bridge/xuvd.cpp"
grep -q 'prime()' "$ROOT/experimental/helix-bridge/helix_pcm_client.hpp"
echo "PASS | static off/shadow/process/fallback/nonblocking/timeout/stream-sticky contract"

if ! command -v g++ >/dev/null 2>&1; then
    echo "SKIP | compiled Unix-socket test requires g++"
    echo "helix_pcm_fallback=PASS_STATIC"
    exit 0
fi

cat >"$TMP/contract_test.cpp" <<'CPP'
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#include <array>
#include <condition_variable>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "experimental/helix-bridge/helix_pcm_client.hpp"

struct Ready {
    std::mutex mutex;
    std::condition_variable cv;
    bool value = false;

    void signal() {
        {
            std::lock_guard<std::mutex> lock(mutex);
            value = true;
        }
        cv.notify_one();
    }

    void wait() {
        std::unique_lock<std::mutex> lock(mutex);
        cv.wait(lock, [this] { return value; });
    }
};

static bool read_exact(int fd, std::uint8_t* data, std::size_t len) {
    std::size_t done = 0;
    while (done < len) {
        const ssize_t n = recv(fd, data + done, len - done, 0);
        if (n <= 0)
            return false;
        done += static_cast<std::size_t>(n);
    }
    return true;
}

static void stream_server(const std::string& path, bool invalid, Ready& ready) {
    unlink(path.c_str());
    const int server = socket(AF_UNIX, SOCK_STREAM, 0);
    if (server < 0)
        std::abort();

    sockaddr_un sa{};
    sa.sun_family = AF_UNIX;
    std::memcpy(sa.sun_path, path.c_str(), path.size() + 1);
    if (bind(server, reinterpret_cast<sockaddr*>(&sa), sizeof(sa)) != 0 ||
        listen(server, 1) != 0)
        std::abort();

    ready.signal();
    const int client = accept(server, nullptr, nullptr);
    if (client < 0)
        std::abort();

    std::array<std::uint8_t, xuv::HELIX_PCM_MAX_PACKET> wire{};
    if (!read_exact(client, wire.data(), xuv::HELIX_PCM_HEADER_LEN))
        std::abort();

    const std::size_t count =
        static_cast<std::size_t>(wire[6]) |
        (static_cast<std::size_t>(wire[7]) << 8);
    const std::size_t body_len = count * 2;
    if (!read_exact(client, &wire[xuv::HELIX_PCM_HEADER_LEN], body_len))
        std::abort();

    if (invalid) {
        std::memcpy(wire.data(), "BAD!", 4);
    } else {
        wire[5] |= xuv::HELIX_PCM_OK;
        for (std::size_t i = 0; i < count; ++i) {
            const std::size_t p = xuv::HELIX_PCM_HEADER_LEN + i * 2;
            const std::uint16_t bits =
                static_cast<std::uint16_t>(wire[p]) |
                (static_cast<std::uint16_t>(wire[p + 1]) << 8);
            const auto sample = static_cast<std::int16_t>(bits);
            int value = static_cast<int>(sample) * 2;
            if (value > 32767) value = 32767;
            if (value < -32768) value = -32768;
            const auto out = static_cast<std::uint16_t>(
                static_cast<std::int16_t>(value));
            wire[p] = static_cast<std::uint8_t>(out & 0xff);
            wire[p + 1] = static_cast<std::uint8_t>((out >> 8) & 0xff);
        }
    }

    const std::size_t packet_len = xuv::HELIX_PCM_HEADER_LEN + body_len;
    if (send(client, wire.data(), packet_len, MSG_NOSIGNAL) !=
        static_cast<ssize_t>(packet_len))
        std::abort();

    close(client);
    close(server);
    unlink(path.c_str());
}

static void datagram_server(
    const std::string& path,
    Ready& ready,
    bool& valid
) {
    unlink(path.c_str());
    const int server = socket(AF_UNIX, SOCK_DGRAM, 0);
    if (server < 0)
        std::abort();

    sockaddr_un sa{};
    sa.sun_family = AF_UNIX;
    std::memcpy(sa.sun_path, path.c_str(), path.size() + 1);
    if (bind(server, reinterpret_cast<sockaddr*>(&sa), sizeof(sa)) != 0)
        std::abort();

    ready.signal();
    std::array<std::uint8_t, xuv::HELIX_PCM_MAX_PACKET> wire{};
    const ssize_t n = recv(server, wire.data(), wire.size(), 0);
    valid =
        n >= static_cast<ssize_t>(xuv::HELIX_PCM_HEADER_LEN) &&
        std::memcmp(wire.data(), "HXP1", 4) == 0;

    close(server);
    unlink(path.c_str());
}

int main(int argc, char** argv) {
    if (argc != 2)
        return 2;
    const std::string dir = argv[1];
    const std::array<std::int16_t, 3> original{100, -200, 300};

    {
        auto samples = original;
        xuv::HelixPcmClient client(dir + "/missing.sock", 5);
        const bool ok = client.process(
            7, 8000, 160, samples.data(), samples.size(), true, true, true);
        if (ok || samples != original)
            return 3;
    }

    {
        const std::string path = dir + "/valid.sock";
        Ready ready;
        std::thread server(stream_server, path, false, std::ref(ready));
        ready.wait();

        auto samples = original;
        xuv::HelixPcmClient client(path, 5);
        const bool ok = client.process(
            7, 8000, 160, samples.data(), samples.size(), true, true, true);
        server.join();

        const std::array<std::int16_t, 3> expected{200, -400, 600};
        if (!ok || samples != expected)
            return 4;
    }

    {
        const std::string path = dir + "/invalid.sock";
        Ready ready;
        std::thread server(stream_server, path, true, std::ref(ready));
        ready.wait();

        auto samples = original;
        xuv::HelixPcmClient client(path, 5);
        const bool ok = client.process(
            7, 8000, 160, samples.data(), samples.size(), true, true, true);
        server.join();

        if (ok || samples != original)
            return 5;
    }

    {
        xuv::HelixPcmObserver observer(dir + "/missing-observe.sock");
        if (observer.observe(
                7, 8000, 160, original.data(), original.size(), true, true))
            return 6;
    }

    {
        const std::string path = dir + "/observe.sock";
        Ready ready;
        bool received_valid = false;
        std::thread server(
            datagram_server, path, std::ref(ready), std::ref(received_valid));
        ready.wait();

        xuv::HelixPcmObserver observer(path);
        const bool ok = observer.observe(
            7, 8000, 160, original.data(), original.size(), true, true);
        server.join();

        if (!ok || !received_valid)
            return 7;
    }

    std::cout << "compiled_contract=PASS\n";
    return 0;
}
CPP

g++ -std=c++17 -Wall -Wextra -Werror -pthread -I"$ROOT" \
    "$TMP/contract_test.cpp" -o "$TMP/contract_test"

"$TMP/contract_test" "$TMP"
echo "PASS | request/reply fail-open and non-blocking shadow datagram"
echo "helix_pcm_fallback=PASS"
