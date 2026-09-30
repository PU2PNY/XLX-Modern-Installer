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
grep -q 'timeout_ms_ > 5' "$ROOT/experimental/helix-bridge/helix_pcm_client.hpp"
echo "PASS | static off/shadow/process/fallback/timeout contract"

if ! command -v g++ >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
    echo "SKIP | compiled Unix-socket test requires g++ and python3"
    echo "helix_pcm_fallback=PASS_STATIC"
    exit 0
fi

cat >"$TMP/client_test.cpp" <<'CPP'
#include <array>
#include <cstdint>
#include <iostream>
#include <string>
#include "experimental/helix-bridge/helix_pcm_client.hpp"

static bool same(const std::array<std::int16_t,3>& a,
                 const std::array<std::int16_t,3>& b) {
    return a == b;
}

int main(int argc, char** argv) {
    if (argc != 3) return 2;
    const std::string mode = argv[1];
    const std::string socket = argv[2];

    std::array<std::int16_t,3> samples{100, -200, 300};
    const auto original = samples;
    xuv::HelixPcmClient client(socket, 5);

    const bool commit_output = mode != "shadow";
    const bool ok = client.process(
        7, 8000, 160, samples.data(), samples.size(),
        true, true, commit_output
    );

    if (mode == "missing" || mode == "invalid") {
        if (ok || !same(samples, original)) {
            std::cerr << "fallback contract failed\n";
            return 3;
        }
        return 0;
    }

    if (mode == "valid") {
        const std::array<std::int16_t,3> expected{200, -400, 600};
        if (!ok || !same(samples, expected)) {
            std::cerr << "valid response not committed\n";
            return 4;
        }
        return 0;
    }

    if (mode == "shadow") {
        if (!ok || !same(samples, original)) {
            std::cerr << "shadow mode changed PCM\n";
            return 5;
        }
        return 0;
    }

    return 6;
}
CPP

g++ -std=c++17 -Wall -Wextra -Werror -I"$ROOT"     "$TMP/client_test.cpp" -o "$TMP/client_test"

cat >"$TMP/server.py" <<'PY'
import os
import socket
import struct
import sys

path, mode = sys.argv[1], sys.argv[2]
try:
    os.unlink(path)
except FileNotFoundError:
    pass

srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
srv.bind(path)
srv.listen(1)
conn, _ = srv.accept()

def recv_exact(n):
    out = bytearray()
    while len(out) < n:
        chunk = conn.recv(n - len(out))
        if not chunk:
            raise SystemExit(2)
        out.extend(chunk)
    return bytes(out)

header = bytearray(recv_exact(24))
count = struct.unpack_from("<H", header, 6)[0]
body = recv_exact(count * 2)

if mode == "invalid":
    header[0:4] = b"BAD!"
    conn.sendall(header + body)
else:
    header[5] |= 0x80
    samples = list(struct.unpack("<" + "h" * count, body))
    doubled = [max(-32768, min(32767, value * 2)) for value in samples]
    out = struct.pack("<" + "h" * count, *doubled)
    conn.sendall(header + out)

conn.close()
srv.close()
PY

MISSING="$TMP/missing.sock"
"$TMP/client_test" missing "$MISSING"
echo "PASS | missing Helix keeps PCM unchanged"

run_server_case() {
    local server_mode="$1"
    local client_mode="$2"
    local socket="$TMP/${server_mode}-${client_mode}.sock"
    rm -f "$socket"
    python3 "$TMP/server.py" "$socket" "$server_mode" &
    local pid=$!
    for _ in {1..200}; do
        [[ -S "$socket" ]] && break
        sleep 0.025
    done
    [[ -S "$socket" ]] || { kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; return 1; }
    "$TMP/client_test" "$client_mode" "$socket"
    wait "$pid"
}

run_server_case valid valid
echo "PASS | valid Helix response is committed"

run_server_case valid shadow
echo "PASS | shadow response is discarded"

run_server_case invalid invalid
echo "PASS | malformed Helix response keeps PCM unchanged"

echo "PASS | compiled transcoder/client fallback contract"

echo "helix_pcm_fallback=PASS"
