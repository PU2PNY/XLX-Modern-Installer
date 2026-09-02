# XLX Modern Installer

Independent installer and maintenance layer for **XLX reflectors on Debian 12 x86_64**, maintained by **Dario — PU2PNY**.

XLX Modern Installer owns the complete installation orchestration: environment checks, configuration collection, preventive backup, XLXD build, systemd units, Modern Dashboard, Apache/HTTPS, RadioID runtime data, CallingHome, hidden private Admin, validation and recovery logic. It does **not** execute, vendor or call another reflector installer.

Português: [README.pt-BR.md](README.pt-BR.md)

## Actual external sources

Only the software components that are really required are fetched:

- XLXD core: `https://github.com/LX3JL/xlxd.git`, pinned by `modules/40-xlxd.sh`;
- optional Echo/Parrot: `https://github.com/narspt/XLXEcho.git`, pinned by `modules/50-echo.sh`;
- Debian packages through APT.

The **XLX Modern Dashboard is shipped inside this repository** and is never cloned from an external dashboard repository.

## Canonical paths

```text
XLXD runtime:       /xlxd
XLXD source:        /usr/src/xlxd
Modern Dashboard:  /var/www/html/xlxd
Admin config:       /etc/xlx-modern-control
CallingHome config: /etc/xlx-modern
Backups:            /var/backups/xlx-reflector
```

Retired paths such as `/var/www/html/xlxd-novo` and `/var/www/html/xlx-dashboard` are not clean-install targets.

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

The real installation requires the explicit confirmation word `INSTALL`.

The installer then independently performs dependency installation, pinned XLXD checkout/build/install, repository-owned systemd setup, optional Echo, the local Modern Dashboard, Apache/optional HTTPS, RadioID/update timer/log bridge, dedicated CallingHome, hidden Admin, optional APRS/D-PRS and final validation.

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

The private operational Admin has two complete audited interfaces: Portuguese (Brazil) and English. Spanish/French/German/Italian public dashboards use the English Admin rather than a partially translated safety interface.

## Existing XLXD

A full installation refuses to overwrite an active XLXD. Preserve the existing core and install/update only the Modern Dashboard with:

```bash
sudo bash install.sh --dashboard-only
```

## Independent XLXD core

`modules/40-xlxd.sh` fetches the pinned official XLXD source, verifies the exact revision, configures module/YSF build constants, compiles XLXD, installs the native runtime files, configures `xlxd.terminal`, renders the repository-owned systemd unit and validates the resulting process/listeners.

No external installer script participates in this flow.

## Optional Echo / Parrot

`modules/50-echo.sh` independently fetches a pinned XLXEcho revision when Echo is selected, compiles it, installs the local systemd unit and safely manages the native Interlink `ECHO` peer entry. Echo is optional; its absence is not a validation failure when the operator selected no Echo.

## Modern Dashboard

The local `dashboard/` tree is installed directly into `/var/www/html/xlxd`. The universal package intentionally does not distribute XLX026-specific Support, ANATEL simulator or News content to other reflectors.

## Private Admin

Install/repair it independently with:

```bash
sudo bash install-control.sh
```

The route defaults to `admin` and can be renamed. It is not advertised through public navigation or indexing files.

Admin capabilities include XLXD status/listeners/logs/backups/tests, password-confirmed restart, RadioID management, whitelist/blacklist and native XLX Interlink peer management. There is no general web terminal or arbitrary shell command.

Interlink uses `/xlxd/xlxd.interlink` and the native `PEER ADDRESS MODULES` format. Peer changes preserve unrelated lines, create a backup, validate the complete file and publish atomically. XLXD reloads the peer list automatically.

## RadioID and CallingHome

The runtime layer maintains `/xlxd/users_db/users_base.csv` and `/xlxd/users_db/users.db`, validates candidate databases before publication and reapplies persistent local Admin changes after refreshes.

CallingHome is implemented by this repository with a protected local configuration and dedicated systemd service/timer, independent of any retired dashboard.

## Optional modules

```bash
sudo bash install.sh --with-aprs-dprs
sudo bash install.sh --without-aprs-dprs
```

Certificates remain optional and are not part of the standard public installation.

## Acceptance

CI validates syntax, translations, canonical paths, independent source pins, Admin privilege boundaries, Interlink atomic changes and RadioID persistence. A clean Debian 12 VPS field test is still required to prove provider firewall/DNS behavior and real D-STAR/DMR/YSF traffic.

See [ARCHITECTURE.md](ARCHITECTURE.md), [control/README.md](control/README.md) and the documentation under `docs/`.
