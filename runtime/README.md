# Reproducible runtime

The canonical `install.sh` now obtains PP5PK/xlxd at the reviewed commit
`e69f2dcdd9cf004d5ad199f85c27f1fa1e7e5004`, applies the combined TOT180/turn
patch before the operator's module/frequency settings, and builds it. TOT180
is preserved; turn admission remains OFF unless explicitly configured.

`live-core/` contains the observed Rust/WebSocket source and exact Cargo lock.
`live-hub/` contains the SSE fallback hub. Both bind to loopback and share the
existing PHP contract. Paths and service identities are generic. Installation
does not require XLX026's domain, callsign, RadioID, passwords or API key.

The default dashboard remains the generic multilingual distribution. Support,
News and the ANATEL simulator remain excluded from its public navigation per
the existing distribution policy; the private recovery backup preserves them
when installed. An unchanged public distribution is not a substitute for the
private database/configuration backup of an existing reflector.

Helix bridge and its fail-open/shadow sources remain in `experimental/helix-bridge`.
Stereo Tool is not redistributed or enabled. A source checkout on disk is not
automatically the source of the running ELF: recovery records actual binaries
and service configuration separately. See `docs/RECOVERY.md`.
