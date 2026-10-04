#!/usr/bin/env python3
"""Executable reference model for TURN-001..006 acceptance semantics."""
from dataclasses import dataclass, field

TRIGGER = 2.0
COOLDOWN = 7.0
RESET = 60.0


@dataclass
class State:
    previous: str = ''
    last: str = ''
    last_transition_fast: bool = False
    last_close: float | None = None
    pair: tuple[str, str] | None = None
    cooldown_until: float = 0.0
    pair_expires: float = 0.0


@dataclass
class Guard:
    modules: dict[str, State] = field(default_factory=dict)

    def _state(self, module: str) -> State:
        return self.modules.setdefault(module, State())

    def admit(self, module: str, user: str, now: float) -> bool:
        s = self._state(module)
        if s.last_close is not None and now - s.last_close > RESET:
            self.modules[module] = s = State()
        if s.pair and now >= s.pair_expires:
            s.pair = None
        if s.pair:
            if user not in s.pair:
                s.pair = None
                s.previous = ''
                s.last = ''
                s.last_transition_fast = False
            elif now < s.cooldown_until:
                return False
        fast = s.last_close is not None and 0 <= now - s.last_close <= TRIGGER
        if not s.pair and fast and s.last_transition_fast and s.previous == user and s.last and s.last != user:
            s.pair = (user, s.last)
            s.pair_expires = now + RESET
            s.cooldown_until = now
        s.previous, s.last = s.last, user
        s.last_transition_fast = fast
        return True

    def close(self, module: str, user: str, now: float) -> None:
        s = self._state(module)
        s.last_close = now
        if s.pair and user in s.pair:
            s.cooldown_until = now + COOLDOWN
            s.pair_expires = now + RESET


def tx(g: Guard, module: str, user: str, start: float, end: float) -> None:
    assert g.admit(module, user, start), (module, user, start)
    g.close(module, user, end)


def main() -> int:
    g = Guard()
    tx(g, 'C', 'A', 0.0, 10.0)
    tx(g, 'C', 'B', 10.5, 20.0)
    tx(g, 'C', 'A', 20.5, 30.0)
    assert g.modules['C'].pair == ('A', 'B')
    assert not g.admit('C', 'B', 31.0)  # blocked inside 7 s
    before = g.modules['C'].cooldown_until
    assert not g.admit('C', 'A', 32.0)  # denied retry does not extend
    assert g.modules['C'].cooldown_until == before
    assert g.admit('C', 'C', 32.1)      # third station is always free
    assert g.modules['C'].pair is None   # and breaks the pair state

    # Same pair on another independent module is unaffected.
    assert g.admit('D', 'A', 32.2)

    # Slow exchanges do not arm the guard.
    h = Guard()
    tx(h, 'C', 'A', 0.0, 5.0)
    tx(h, 'C', 'B', 8.5, 12.0)
    tx(h, 'C', 'A', 15.5, 19.0)
    assert h.modules['C'].pair is None

    # Exact boundary: 7.000 s is allowed.
    j = Guard()
    tx(j, 'C', 'A', 0.0, 5.0)
    tx(j, 'C', 'B', 5.5, 10.0)
    tx(j, 'C', 'A', 10.5, 15.0)
    assert not j.admit('C', 'B', 21.999)
    assert j.admit('C', 'B', 22.000)

    print('tx_turn_guard_policy=PASS')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
