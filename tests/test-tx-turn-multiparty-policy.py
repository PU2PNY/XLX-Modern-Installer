#!/usr/bin/env python3
"""Reference behavior for optional TURN-013..TURN-017. No production I/O."""
from dataclasses import dataclass, field

TRIGGER_MS = 3000
PENALTY_MS = 7000
RESET_MS = 60000
CAP = 128


@dataclass
class State:
    participants: list[str] = field(default_factory=list)
    penalty_until: dict[str, int] = field(default_factory=dict)
    last_close: int | None = None


class Guard:
    def __init__(self) -> None:
        self.modules: dict[str, State] = {}

    def admit(self, module: str, callsign: str, at: int) -> bool:
        s = self.modules.setdefault(module, State())
        if s.last_close is not None and at - s.last_close > RESET_MS:
            self.modules[module] = s = State()
        s.penalty_until = {u: deadline for u, deadline in s.penalty_until.items() if deadline > at}
        if s.penalty_until.get(callsign, 0) > at:
            return False
        if callsign in s.participants and s.last_close is not None:
            if 0 <= at - s.last_close < TRIGGER_MS:
                s.penalty_until[callsign] = at + PENALTY_MS
                return False
        return True

    def close(self, module: str, callsign: str, at: int) -> None:
        s = self.modules.setdefault(module, State())
        if s.last_close is not None and at - s.last_close > RESET_MS:
            self.modules[module] = s = State()
        if callsign not in s.participants:
            if len(s.participants) >= CAP:
                old = s.participants.pop(0)
                s.penalty_until.pop(old, None)
            s.participants.append(callsign)
        s.last_close = at


def run() -> None:
    g = Guard()
    t = 0
    for station in ("A", "B", "C", "D"):
        assert g.admit("C", station, t)
        g.close("C", station, t + 1000)
        t += 1000
    assert not g.admit("C", "A", t + 1)
    deadline = g.modules["C"].penalty_until["A"]
    assert not g.admit("C", "A", t + 2)
    assert g.modules["C"].penalty_until["A"] == deadline
    assert not g.admit("C", "B", t + 2)
    assert g.admit("C", "NEW", t + 2)  # first QSO entry always free
    g.close("C", "NEW", t + 1003)
    assert not g.admit("C", "NEW", t + 1004)
    assert g.admit("D", "A", t + 1004)  # independent module
    assert g.admit("C", "C", t + 4003)  # 3 s boundary is allowed
    assert not g.admit("C", "D", t + 2999)  # before 3 s forbidden
    assert g.admit("C", "A", deadline)  # expires without extending penalty
    assert g.admit("C", "B", t + RESET_MS + 1100)  # QSO resets after idle
    assert not g.modules["C"].participants
    g = Guard()
    for i in range(135):
        station = f"U{i}"
        assert g.admit("C", station, i)
        g.close("C", station, i + 1)
    assert len(g.modules["C"].participants) == CAP
    assert "U0" not in g.modules["C"].participants
    print("tx_turn_multi_policy=PASS")


if __name__ == "__main__":
    run()
