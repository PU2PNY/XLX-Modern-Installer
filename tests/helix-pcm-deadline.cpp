#include "experimental/helix-bridge/helix_pcm_client.hpp"
#include <chrono>
#include <future>
#include <iostream>
#include <thread>

using Clock = std::chrono::steady_clock;

static int listener(const std::string& path) {
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    sockaddr_un sa{};
    sa.sun_family = AF_UNIX;
    std::memcpy(sa.sun_path, path.c_str(), path.size() + 1);
    if (fd < 0 || bind(fd, reinterpret_cast<sockaddr*>(&sa), sizeof(sa)) ||
        listen(fd, 1))
        std::abort();
    return fd;
}

static void server(const std::string& path, int scenario, std::promise<void> ready) {
    int fd = listener(path);
    ready.set_value();
    int peer = accept(fd, nullptr, nullptr);
    if (peer < 0) std::abort();
    std::array<std::uint8_t, 344> wire{};
    std::size_t got = 0;
    while (got < wire.size()) {
        auto n = recv(peer, wire.data() + got, wire.size() - got, 0);
        if (n <= 0) std::abort();
        got += static_cast<std::size_t>(n);
    }
    wire[5] |= xuv::HELIX_PCM_OK;
    if (scenario == 0) {
        // A peer sending a byte every 3 ms must not renew the 5 ms budget.
        for (auto byte : wire) {
            if (send(peer, &byte, 1, MSG_NOSIGNAL) != 1) break;
            std::this_thread::sleep_for(std::chrono::milliseconds(3));
        }
    } else if (scenario == 1) {
        std::this_thread::sleep_for(std::chrono::milliseconds(30));
    } else {
        // Corrupt each header invariant, or disconnect after a valid header.
        const int offsets[] = {0, 4, 5, 6, 8, 12, 16};
        if (scenario == 10) wire[5] |= 0x40;
        if (scenario < 9) wire[offsets[scenario - 2]] ^= scenario == 4 ? 0x80 : 1;
        auto size = scenario == 9 ? xuv::HELIX_PCM_HEADER_LEN : wire.size();
        (void)send(peer, wire.data(), size, MSG_NOSIGNAL);
    }
    close(peer);
    close(fd);
    unlink(path.c_str());
}

int main(int argc, char** argv) {
    if (argc != 2) return 2;
    for (int scenario = 0; scenario < 11; ++scenario) {
        std::string path = std::string(argv[1]) + "/case.sock";
        std::promise<void> ready;
        auto started = ready.get_future();
        std::thread worker(server, path, scenario, std::move(ready));
        started.wait();
        std::array<std::int16_t, 160> pcm{};
        pcm.fill(1000);
        const auto original = pcm;
        // Upper clamp is tested using an intentionally huge requested budget.
        xuv::HelixPcmClient client(path, 1000);
        auto begin = Clock::now();
        bool ok = client.process(7, 8000, 160, pcm.data(), pcm.size(), true, true, true);
        double ms = std::chrono::duration<double, std::milli>(Clock::now() - begin).count();
        worker.join();
        if (ok || pcm != original || ms > 25) {
            std::cerr << "FAIL scenario=" << scenario << " ms=" << ms << "\n";
            return 3;
        }
        std::cout << "deadline_case=" << scenario << " fail_open=PASS ms=" << ms << "\n";
    }
    // Filling a Unix listener backlog used to leave blocking connect() unbounded.
    std::string path = std::string(argv[1]) + "/backlog.sock";
    int fd = listener(path);
    std::array<int, 8> peers{};
    peers.fill(-1);
    bool saturated = false;
    for (auto& peer : peers) {
        peer = socket(AF_UNIX, SOCK_STREAM | SOCK_NONBLOCK, 0);
        sockaddr_un sa{};
        sa.sun_family = AF_UNIX;
        std::memcpy(sa.sun_path, path.c_str(), path.size() + 1);
        if (connect(peer, reinterpret_cast<sockaddr*>(&sa), sizeof(sa)) < 0 &&
            errno == EAGAIN) { saturated = true; break; }
    }
    std::array<std::int16_t, 160> pcm{};
    pcm.fill(1000);
    const auto original = pcm;
    xuv::HelixPcmClient client(path, 1000);
    auto begin = Clock::now();
    bool ok = client.process(7, 8000, 0, pcm.data(), pcm.size(), true, true, true);
    double ms = std::chrono::duration<double, std::milli>(Clock::now() - begin).count();
    for (int peer : peers) if (peer >= 0) close(peer);
    close(fd);
    unlink(path.c_str());
    if (!saturated || ok || pcm != original || ms > 25) return 4;
    std::cout << "saturated_connect=PASS ms=" << ms << "\nhelix_total_deadline=PASS\n";
}
