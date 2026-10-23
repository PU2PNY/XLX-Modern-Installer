# Native YSF VW switch

User request: 2026-10-23. Optional addition to PP5PK/xlxd 2.5.3 at
`e69f2dcdd9cf004d5ad199f85c27f1fa1e7e5004`, after the existing combined TOT180/TX Turn Guard patch.

## Behavior

- Default OFF. `XLX_YSF_VW=1` is a startup fallback.
- Persistent administrator key: `/etc/xlx-modern/ysf-vw.conf`, exactly `1\n` or `0\n`.
- The key is read only when a VW header arrives. A malformed existing file disables VW.
- Changing the key admits/refuses new VW PTTs without polling or restarting XLXD. A PTT already admitted finishes normally.
- Native YSF clients on the same module receive the original 155-byte header/voice/terminator. The source and peers are excluded.
- The router does not send tagged VW to D-Star, DMR, XLX interlink, IMRS or the AMBE+2 transcoder.
- Existing module admission, TOT180, gatekeeper and TX Turn Guard remain authoritative.
- DN remains the mode for cross-protocol conversations. VW-to-DN/DMR/D-Star conversion is not implemented.
- No late entry or VW peer capability negotiation in V1. RF/audio quality still requires two real VW-capable stations.

## Build and test

`apply-and-build.sh /clean/checkout` applies both patches and builds only; it never installs or activates anything.
Use a disposable VPS for `test-env.sh /patched/checkout`: it uses a network namespace, modifies a temporary laboratory key and restores the previous key on exit.
The separate existing guard C++/protocol tests must also pass.
`restore-test.py` is the recorded site-specific ENV procedure, not a production deploy command.

## Control page integration

`xlx026-ysf-vw-helper` exposes only status and set 0/1. It writes the root-owned key atomically.
`integrate-control.py STAGING_DIRECTORY` patches a copy of the existing XLX026 control page and limited wrapper using exact anchors; unexpected layouts fail closed.
The existing authenticated session, CSRF check, password confirmation, audit trail and sudo wrapper remain required. No arbitrary terminal or service-management action is added.

## Production gate and recovery

Reproduce the active baseline first. On 2026-10-23 the documented five-module/433125000/autolink-C/keepalive configuration plus the existing guard patch reproduced exactly
`9dce43475fed2fa464e8b76f1363167827b5cb80e33981523d2e701ea3d0b9f0`.
Do not use the divergent tree in /usr/src/xlxd.

Before deployment: test VW transport, legacy protocol admission/EOT/timeout/TOT, guard, isolated service startup and restoration; record executable hashes; back up binary, private configuration and affected control files root-only.
Install only during an idle window. Validate all 13 expected listeners, active ELF hash, public Live, control authentication and the unchanged transcoder.
Rollback restores the previous files/configuration and restarts only XLXD; the local key alone disables new VW admissions without a restart.
Do not commit private configuration, backup, session cookies, production logs or captured voice.

## XLX026 activation — 2026-10-23

Production startup/control/endpoints validated with the candidate SHA above, 13 listeners and unchanged transcoder/Helix processes. The key is ON. The limited helper was tested as www-data for status → OFF → ON with the same XLXD PID; install only the three exact sudo rules in `sudoers.example` and validate using visudo.
The private page is `/controle/`, Home → YSF · Voz larga (VW). Authenticated browser visual testing remains pending because the selected browser requested login.
Synthetic native VW transport/TOT, existing DCS/YSF/DMR/guard regression and isolated service restoration passed. Two regular stream open/close cycles were observed after activation with no fatal signature in that canary sample. This is not RF/audio validation or a long soak.
See [sanitized evidence](../../docs/evidence/ysf-vw-20261023.json).
