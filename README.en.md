# XLX Modern Installer

**Current release: v1.2.14**

Public, reproducible installer for a fresh **Debian 12 x86_64** server. It installs the XLXD core, Echo Test when selected, the modern multi-protocol dashboard, private Admin, native APRS/D-PRS, native verifiable certificates, CallingHome and operational observability.

This repository publishes the XLX Modern installer and dashboard stack derived from the production-validated **XLX026 Brasil** environment. During setup, the operator enters the identity of the new reflector, so each installation receives its own reflector ID, domain, location and operating parameters. XLX026 is the production reference and live demonstration; its credentials, secrets and private production data are not distributed.

**Live production example:** [XLX026 Brasil — xlx026.net](https://xlx026.net/)

[Português (Brasil)](README.pt-BR.md) · [English](README.en.md) · [Changelog](CHANGELOG.md) · [Features](docs/FEATURES.md)

## Quick install

Use a clean Debian 12 VPS. Minimal images may not include Git.

```bash
apt-get update
apt-get install -y git ca-certificates
cd /usr/src
git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
bash install.sh
```

`install.sh --check` performs the read-only preflight without installing.

## Installation behavior

The normal installer asks for all required site data in one questionnaire, shows one complete review screen and waits for **ENTER** once to start. A question number edits that answer; `X` cancels. No second `INSTALL` confirmation and no late city/Admin/YSF questionnaire is expected.

The collected data includes reflector ID, FQDN, sysop email/callsign, country, timezone, public description/title/footer, HTTPS choice, Echo Test, number of active modules, YSF UDP/frequency/autolink, city/region, YSF reflector ID and the private Admin username/slug/password. The Admin password must be at least 8 characters and is never displayed in the summary.

The installer does **not** run a mandatory full OS upgrade. It updates package indexes and installs only required dependencies using `apt-get`.

## Installed server components

| Component | What it does |
|---|---|
| XLXD core | Multi-protocol reflector service and configured active modules |
| XLX Echo | Optional echo test service on module E when selected |
| Apache + PHP | Serves the dashboard and APIs |
| Callsign database | Builds and refreshes the RadioID/callsign directory with persistent local overrides |
| CallingHome | Timer-based reflector registration/heartbeat using the actually available HTTP/HTTPS scheme |
| Native APRS/D-PRS | D-PRS/GPS observation, APRS-IS integration, messaging/ACK state and account management |
| Native certificates | Activity-based participation certificates with public QR verification and HMAC authenticity |
| Observability | Health, DMR data/meta, YSF data, history collector and regression self-test services/timers |
| Private Admin | Status, ports, logs, backups, Health, RadioID, whitelist/blacklist, Interlink and protected XLXD restart |

## Dashboard

The public dashboard keeps these areas independent:

- **Live** — low-latency TX/RX boxes react quickly to the start and end of transmissions, showing callsign, protocol, module and, when available, the operator's public profile photo. The activity table covers the last **24 hours** and consolidates repeated activity by callsign with an expandable submenu for that operator's transmissions, avoiding repetitive rows. When observed APRS/D-PRS/GPS data is available, the activity is identified and the location action opens the reflector's own APRS/D-PRS page with the operator/location context.
- **Connected** — filters plus a real-time connected-station table with callsign, protocol, module and connection time; it remains independent from Modules.
- **Modules** — access-identification table followed by module cards. Active modules follow the configured count and use NATO names Alfa–Zulu where applicable.
- **Ranking** — shows the station connected for the longest time, who generated the most PTT/TX events, who accumulated the most airtime, busiest hours, most-used modules and currently connected protocols. Statistical views include today, 7 days and the current month when coverage is available.
- **Reflectors** — worldwide XLX reflector directory with search/filter controls to narrow the displayed list.
- **APRS / D-PRS** — native Digital Lab associated with **module B**, reserved in this deployment model for beacons, APRS and D-PRS traffic. It supports observed GPS/location data plus sending and receiving APRS radio messages and acknowledgements through the server interface.
- **Certificates** — generates participation certificates from eligible recorded activity, including TX information, accumulated airtime, modules and protocols represented in that activity, with public QR Code and HMAC authenticity verification.

The standard public package intentionally excludes **Support**, **ANATEL simulator** and **News**.

### Live identity and status semantics

The dashboard follows the production-validated identity rules:

- the callsign from the XLXD log is the transmitting source;
- a different gateway/repeater is shown only when supported by exact station/gateway evidence;
- `Online` means actually connected;
- `Link` is used only when a verified gateway relationship exists for an otherwise offline operator;
- Talker Alias is supplemental radio-reported metadata and never replaces RadioID identity;
- registered hotspot/repeater coordinates are not treated as live operator GPS;
- APRS/D-PRS/GPS indicators only use observed position data.

Visible history is limited to the last **24 hours**.

## APRS / D-PRS accounts

APRS/D-PRS is native and mandatory in the normal installation. The web interface and APIs ship inside `dashboard/`; only the background gateway/service and SQLite state are provisioned outside the webroot. The runtime connects the Digital Lab to **module B**, used as the dedicated beacon/APRS/D-PRS module, and enables APRS-IS transmit/receive operation so authenticated operators can exchange APRS messages and acknowledgements from the reflector interface.

Account behavior follows the validated XLX026 model:

- callsign is normalized and validated;
- self-registration requires a recent qualifying APRS/D-PRS activity check;
- the user provides the real **day and month** of birth and explicit consent;
- the password is generated with cryptographic randomness;
- only `password_hash()` output is stored;
- the generated password is displayed only at creation/reset time;
- password resets validate callsign + day/month through an authorized Admin/Collaborator workflow;
- a reset generates a new password, increments the authentication version and revokes remembered tokens;
- raw birthday values are not written into the audit-event detail payload.

The APRS service callsign is derived from the configured sysop using the dedicated `-10` SSID, rather than a fixed production callsign.

## Native certificates and QR validation

Certificates are part of this repository and dashboard; the normal install does **not** download or execute a second certificate-generator repository.

A certificate is issued only when eligible activity exists for the active campaign. Each issuance has a unique ID and a keyed HMAC token. The QR points back to the same installed dashboard, for example:

```text
https://YOUR-DOMAIN/?page=certificado&validar=ID&token=SIGNATURE
```

Validation retrieves the stored issuance, recomputes the token and uses `hash_equals()` for constant-time comparison. A changed token is rejected. The HMAC secret is created outside the webroot under `/etc/xlx-certificates/`.

## Private Admin

The Admin is not linked from public navigation and does not depend on a fixed `/admin/` URL. Its **private slug is configurable during installation**, reducing exposure of the management entry point. It includes:

- XLXD/service status and listeners;
- logs and backups;
- Health status;
- RadioID status, check, refresh, search, save and delete;
- whitelist and blacklist management;
- Interlink add/delete/status;
- protected XLXD restart;
- CSRF, session protection, rate limiting and audit controls;
- no browser SSH/Linux terminal and no XLXD terminal UI.

Functional validation uses stable code/DOM markers such as `id="access"`, `id="radioid"`, `access-interlink-add` and `radioid_save`; translated UI wording is not used as an installation contract.

## HTTPS and Let's Encrypt

HTTPS is requested when selected, but an ACME failure does not destroy an otherwise valid reflector installation. The installer records the real Certbot/ACME diagnostics and leaves the public dashboard available over HTTP while the certificate is pending.

For repeated development tests, use Let's Encrypt staging rather than repeatedly issuing production certificates. The retry helper is installed as:

```bash
xlx-modern-https-retry YOUR-DOMAIN YOUR-EMAIL
```

Private session cookies are Secure; do not treat HTTP fallback as a replacement for HTTPS for authenticated use.

## Languages

- Installer: Portuguese (Brazil) or English.
- Private Admin: Portuguese (Brazil) or English.
- Dashboard: Portuguese (Brazil), English, Spanish, French, German and Italian.

Routes, filenames, IDs, API paths and other technical contracts are protected from translation.

## Backups, diagnostics and failure reporting

Changes create preventive backups under `/var/backups/xlx-reflector/`. Critical scripts use `set -Eeuo pipefail` and report unexpected failures with file, line, return code and failing command instead of silently returning to the shell. Component-level rollback is used where applicable.

A successful full installation must reach **INSTALLATION COMPLETE** after post-install validation. The validation checks essential services, Apache configuration, XLXD binary, required dashboard files, VirtualHost, CallingHome and the locally reachable dashboard protocol.

## Persistent callsign corrections

The main generated database remains under `/xlxd/users_db/`. Local corrections and aliases are stored separately in `/var/lib/xlx-user-directory/overrides.db`, so refreshing upstream data does not erase local changes.

Useful command:

```bash
xlx-user-directory --help
```

## Testing and release gate

Before a public tag, the repository runs Bash/PHP syntax checks, installer-flow regressions, Admin PT/EN builds, six dashboard-language builds, public-release secret/identity audit, native APRS/certificate checks and production-parity regressions.

A release candidate is not considered operationally complete until a clean Debian 12 install reaches the final success message. Reinstallation/idempotence is also part of the expected release validation.

## Security boundaries

- no fixed Admin password is stored in Git;
- no production credentials/private data are shipped;
- no broad `777` permission model;
- private Admin actions use limited sudo helpers rather than arbitrary browser sudo;
- Certificate HMAC secrets stay outside the webroot;
- APRS passwords are hashed;
- Support/ANATEL simulator/News are not part of the public installer distribution.

## Project layout

```text
install.sh                 top-level installer
vendor/pp5pk-installer/    reviewed XLXD base installer
dashboard/                 native public dashboard, APRS/D-PRS and certificates
control/                   private Admin source/builders/helpers
modules/                   controlled installation/provisioning stages
observability/             Health, DMR/YSF/history/self-test components
tests/                     regression suite
scripts/                   audits, backup and maintenance helpers
docs/                      technical documentation
```

## License and credits

See [LICENSE](LICENSE), [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and [CONTRIBUTING.md](CONTRIBUTING.md). The XLXD base lineage and upstream projects retain their respective licenses and attribution.


## HTTPS and final readiness

If Let's Encrypt returns a rate limit, the installer keeps the dashboard available over HTTP, records the `retry after` time and automatically schedules Certbot for another attempt. Completion is shown only after validating the dashboard, APIs, APRS/D-PRS, Health, private Admin, Apache, XLXD and Echo.
