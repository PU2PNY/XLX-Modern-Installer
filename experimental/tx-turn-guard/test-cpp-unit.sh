#!/usr/bin/env bash
set -Eeuo pipefail

SRC="${1:-}"
if [[ -z "$SRC" || ! -d "$SRC/src" ]]; then
  echo "Uso: $0 /caminho/para/checkout/xlxd-ja-patcheado" >&2
  exit 2
fi

ROOT="$(cd -- "$SRC" && pwd)"
BUILD="$ROOT/src"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# The normal candidate build must exist first. This test never installs it.
[[ -x "$BUILD/xlxd" ]] || { echo "ERRO: compile primeiro com apply-and-build.sh" >&2; exit 3; }

cat > "$TMP/txturn_unit.cpp" <<'CPP'
#include "main.h"
#define protected public
#include "creflector.h"
#include "cpacketstream.h"
#undef protected
#include <cassert>
#include <cstdlib>
#include <iostream>

static CDvHeaderPacket header_for(const char *user, char module, uint16 sid)
{
    CCallsign my(user);
    CCallsign ur("CQCQCQ");
    CCallsign rpt1("XLX026");
    CCallsign rpt2("XLX026");
    rpt1.SetModule(module);
    rpt2.SetModule(module);
    return CDvHeaderPacket(my, ur, rpt1, rpt2, sid, 0);
}

int main()
{
    setenv("XLX_TX_TURN_GUARD", "1", 1);
    setenv("XLX_TX_TURN_TRIGGER_MS", "2000", 1);
    setenv("XLX_TX_TURN_COOLDOWN_MS", "7000", 1);
    setenv("XLX_TX_TURN_RESET_MS", "60000", 1);

    CReflector reflector;
    const int c = reflector.GetModuleIndex('C');
    const int d = reflector.GetModuleIndex('D');
    assert(c >= 0 && d >= 0);

    auto a = header_for("PU2AAA", 'C', 1);
    auto b = header_for("PY2BBB", 'C', 2);
    auto third = header_for("PY2CCC", 'C', 3);
    auto a_d = header_for("PU2AAA", 'D', 4);

    // Seed the state immediately before the third transmission of A -> B -> A.
    auto &state = reflector.m_TxTurnGuard[c];
    state.previousUser = "PU2AAA";
    state.lastUser = "PY2BBB";
    state.lastTransitionFast = true;
    state.haveLastClose = true;
    state.lastCloseAt = std::chrono::steady_clock::now() - std::chrono::milliseconds(500);

    assert(reflector.TxTurnGuardAdmit(&a));
    assert(state.pairActive);
    assert(state.pairA == "PU2AAA" && state.pairB == "PY2BBB");

    CPacketStream *stream_c = &reflector.m_Streams[c];
    stream_c->m_DvHeader = a;
    reflector.TxTurnGuardClosed(stream_c);
    const auto deadline = state.cooldownUntil;
    assert(deadline > std::chrono::steady_clock::now());

    // Both members are denied during the window; retries must not extend it.
    assert(!reflector.TxTurnGuardAdmit(&b));
    assert(!reflector.TxTurnGuardAdmit(&a));
    assert(state.cooldownUntil == deadline);

    // Any third station is immediately eligible and breaks the pair.
    assert(reflector.TxTurnGuardAdmit(&third));
    assert(!state.pairActive);

    // Module isolation.
    assert(reflector.TxTurnGuardAdmit(&a_d));
    assert(!reflector.m_TxTurnGuard[d].pairActive);

    // OFF is a hard local bypass.
    state.pairActive = true;
    state.pairA = "PU2AAA";
    state.pairB = "PY2BBB";
    state.cooldownUntil = std::chrono::steady_clock::now() + std::chrono::seconds(30);
    unsetenv("XLX_TX_TURN_GUARD");
    assert(reflector.TxTurnGuardAdmit(&a));

    // Deadline reached/expired is eligible.
    setenv("XLX_TX_TURN_GUARD", "1", 1);
    state.pairActive = true;
    state.pairA = "PU2AAA";
    state.pairB = "PY2BBB";
    state.pairExpiresAt = std::chrono::steady_clock::now() + std::chrono::seconds(30);
    state.cooldownUntil = std::chrono::steady_clock::now() - std::chrono::milliseconds(1);
    assert(reflector.TxTurnGuardAdmit(&b));

    // DMR IDs that cannot resolve to a callsign still get a local identity fallback.
    CCallsign ur("CQCQCQ");
    CCallsign rpt1("XLX026");
    CCallsign rpt2("XLX026");
    rpt1.SetModule('C');
    rpt2.SetModule('C');
    CDvHeaderPacket dmr_only(7246058U, ur, rpt1, rpt2, 10, 0, 0);
    const std::string dmr_identity = CReflector::TxTurnGuardIdentity(dmr_only.GetMyCallsign());
    assert(!dmr_identity.empty());

    std::cout << "tx_turn_guard_cpp_unit=PASS\n";
    return 0;
}
CPP

# main.cpp owns globals needed by the XLXD objects. Rename only its entry point.
g++ -c -std=c++11 -pthread -I"$BUILD" -Dmain=xlxd_original_main "$BUILD/main.cpp" -o "$TMP/main-test.o"
g++ -c -std=c++11 -pthread -I"$BUILD" "$TMP/txturn_unit.cpp" -o "$TMP/txturn_unit.o"

objects=()
while IFS= read -r obj; do
  [[ "$(basename "$obj")" == "main.o" ]] && continue
  objects+=("$obj")
done < <(find "$BUILD" -maxdepth 1 -type f -name '*.o' | sort)

[[ ${#objects[@]} -gt 10 ]] || { echo "ERRO: objetos do build XLXD não encontrados" >&2; exit 4; }
g++ -std=c++11 -pthread "$TMP/txturn_unit.o" "$TMP/main-test.o" "${objects[@]}" -o "$TMP/txturn_unit"
"$TMP/txturn_unit"
