# XLX Modern Installer

Independent installer and maintenance layer for **XLX reflectors on Debian 12 x86_64**, maintained by **Dario — PU2PNY**.

The repository owns the complete installation orchestration: environment checks, configuration collection, preventive backup, XLXD build, systemd units, Modern Dashboard, Apache/HTTPS, RadioID runtime data, CallingHome, private Admin, validation and recovery logic. It does **not** execute, vendor or call another reflector installer.

Português: [README.pt-BR.md](README.pt-BR.md) · English: [README.en.md](README.en.md)

## Sources actually used

The installer obtains only the software components it really needs:

- XLXD core: `https://github.com/LX3JL/xlxd.git`, pinned in `modules/40-xlxd.sh`;
- optional Echo/Parrot: `https://github.com/narspt/XLXEcho.git`, pinned in `modules/50-echo.sh`;
- Debian packages through APT.

The **XLX Modern Dashboard is included in this repository**. It is not cloned from an external dashboard project.

## Canonical paths

```text
XLXD runtime:       /xlxd
XLXD source:        /usr/src/xlxd
Modern Dashboard:  /var/www/html/xlxd
Admin config:       /etc/xlx-modern-control
CallingHome config: /etc/xlx-modern
Backups:            /var/backups/xlx-reflector
```

Retired webroots such as `/var/www/html/xlxd-novo` and `/var/www/html/xlx-dashboard` are not clean-install targets.

## Clean installation

```bash
sudo apt update
sudo apt install -y git
cd /usr/src
sudo git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
sudo bash install.sh --check
sudo bash install.sh
```

The real installation requires the explicit confirmation word:

```text
INSTALL
```

The installer performs its own flow:

1. language selection;
2. Debian 12 x86_64, resource, DNS and HTTPS validation;
3. active-installation/remnant detection;
4. reflector, domain, sysop, timezone, module and YSF configuration;
5. preventive verified backup;
6. Debian dependency installation;
7. pinned XLXD source download, build and installation;
8. repository-owned `xlxd.service` installation and validation;
9. optional independent Echo/Parrot installation;
10. local Modern Dashboard installation;
11. Apache and optional Let's Encrypt HTTPS;
12. RadioID database, update timer and TX/RX log bridge;
13. dedicated CallingHome client/timer;
14. hidden private Admin;
15. optional APRS/D-PRS;
16. final services/listeners/database/Admin/HTTP validation.

## Languages

Installer interface:

```text
1) Português (Brasil)
2) English
```

Public dashboard:

```text
1) Português (Brasil)
2) English
3) Español
4) Français
5) Deutsch
6) Italiano
```

The private operational Admin has two fully audited interfaces: **Português (Brasil)** and **English**. When the public dashboard uses Spanish, French, German or Italian, the Admin uses English rather than a partially translated safety interface.

## Existing XLXD — dashboard only

A full installation refuses to overwrite an active XLXD. To install/update only the Modern Dashboard while preserving the existing core:

```bash
sudo bash install.sh --dashboard-only
```

## XLXD core

`modules/40-xlxd.sh` independently:

- fetches the pinned official XLXD source;
- validates the exact commit;
- configures module count, YSF UDP port/frequency and auto-link;
- builds XLXD locally;
- installs `/xlxd/xlxd` and the native configuration files;
- configures `/xlxd/xlxd.terminal`;
- renders and installs the repository-owned `runtime/xlxd.service.in`;
- starts/validates systemd and required UDP listeners.

No external installer script is used in this process.

## Optional Echo / Parrot

When selected, `modules/50-echo.sh` fetches the pinned XLXEcho source directly, compiles it, installs the repository-owned systemd unit and safely manages the native Interlink entry:

```text
ECHO 127.0.0.1 E
```

When Echo is not selected, the reflector remains valid without requiring `xlxecho.service`.

## Modern Dashboard

The dashboard is installed from the local `dashboard/` directory directly into:

```text
/var/www/html/xlxd
```

Important public routes include:

```text
/ao-vivo
/conectados
/ranking
/refletores
/api/status.php
/api/live.php
```

The universal public package intentionally does not publish XLX026-specific Support, ANATEL simulator or News content on other reflectors.

## Private Admin

Install or repair the Admin independently on an already functional XLX Modern server:

```bash
sudo bash install-control.sh
```

The route defaults to `admin` and can be changed. It is not added to the public menu, sitemap, robots or AI indexing files.

Functions include:

- XLXD status, version, SHA, PID and listeners;
- logs, backups and HTTP/API tests;
- password-confirmed XLXD restart with post-restart validation;
- RadioID search/add/edit/delete/check/refresh;
- whitelist and blacklist;
- XLX Interlink peer management;
- audit, CSRF, secure cookies and login rate limiting.

There is no generic web terminal and no arbitrary shell command endpoint.

### Native Interlink

The Admin manages:

```text
/xlxd/xlxd.interlink
```

using the native format:

```text
PEER ADDRESS MODULES
```

It changes one peer at a time, preserves comments and unrelated entries, creates a backup, validates the complete file and publishes atomically. XLXD monitors the Interlink list and reloads changes automatically, so a peer edit normally does not require an XLXD restart.

## RadioID

The runtime layer maintains:

```text
/xlxd/users_db/users_base.csv
/xlxd/users_db/users.db
```

Database refreshes build and validate a candidate before publication. Local Admin additions/corrections/deletions are stored separately and reapplied after future refreshes.

## CallingHome

CallingHome is implemented by this repository and is independent from any retired dashboard. The installer creates a protected local configuration plus a dedicated systemd service/timer.

## Optional modules

APRS/D-PRS can be selected explicitly:

```bash
sudo bash install.sh --with-aprs-dprs
```

or skipped:

```bash
sudo bash install.sh --without-aprs-dprs
```

Certificates remain optional and are **not** part of the standard public installation.

## Safety and acceptance

The repository tests syntax, translations, canonical paths, independent source pins, Admin privilege boundaries, Interlink atomic updates and persistent RadioID behavior.

Source-level CI cannot prove provider firewall, DNS propagation or real D-STAR/DMR/YSF traffic. A release is considered field-validated only after a clean Debian 12 VPS installation and real protocol tests.

See [ARCHITECTURE.md](ARCHITECTURE.md), [control/README.md](control/README.md), [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and the guides under `docs/`.
