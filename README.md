# XLX Modern Installer

A conservative installer and maintenance layer for **XLX reflectors on Debian 12 x86_64**, maintained by **Dario — PU2PNY** and based on the reviewed installer by **Daniel K. — PP5PK**.

The project keeps the proven PP5PK XLXD core installation flow and replaces the legacy dashboard/data layer with the XLX Modern Dashboard, persistent RadioID management, a hidden private Admin, dedicated CallingHome, and optional APRS/D-PRS / Certificate modules.

> **Canonical paths**
>
> - XLXD core, native lists and runtime data: `/xlxd`
> - Modern dashboard webroot: `/var/www/html/xlxd`
> - The retired `/var/www/html/xlxd-novo` path is not a clean-install target.

Português: [README.pt-BR.md](README.pt-BR.md)

---

## What a clean installation provides

A successful clean installation is designed to provide:

- XLXD core compiled and installed from the reviewed PP5PK base flow;
- D-STAR, DMR and C4FM/YSF core configuration supported by XLXD;
- configurable XLX reflector ID, domain, sysop information and timezone;
- 1–26 XLXD modules;
- configurable YSF UDP port, Wires-X frequency and optional YSF auto-link;
- optional XLX Echo service;
- `xlxd.service` under systemd;
- modern dashboard directly in `/var/www/html/xlxd`;
- Apache VirtualHost and optional Let's Encrypt HTTPS;
- daily RadioID/users database refresh with SQLite validation;
- persistent local RadioID corrections/deletions that survive refreshes;
- TX/RX log bridge and `xlx_log.service`;
- dedicated CallingHome client/timer independent of the legacy dashboard;
- hidden private Admin with local credentials and a configurable route;
- optional APRS/D-PRS;
- optional XLX Certificate Generator;
- preventive backups, syntax/integrity checks and rollback on Modern-layer failures.

The public installer intentionally does **not** copy XLX026-only Support, ANATEL simulator or News content into other reflectors.

---

## Reviewed PP5PK base

The core installer is pinned to the reviewed upstream project:

- repository: `PP5PK/XLX_Installer`
- reviewed commit: `20b48934505b1939317bf71b30ddc32b1ced0035`
- upstream `installer.sh` Git blob: `266217ee910742710b9c5c9f30009c8a0f0fcaf7`

The vendored core installer is checked by SHA-256 before use. See [vendor/pp5pk-installer/UPSTREAM.md](vendor/pp5pk-installer/UPSTREAM.md) and [docs/PP5PK-COMPATIBILITY-MATRIX.md](docs/PP5PK-COMPATIBILITY-MATRIX.md).

The Modern wrapper deliberately keeps the PP5PK core build, module/YSF configuration, systemd setup, terminal-options file and optional Echo path. It deliberately replaces the old dashboard, old users-db presentation layer and old dashboard CallingHome implementation.

---

## Quick start — clean Debian 12 VPS

Install Git and clone the repository:

```bash
sudo apt update
sudo apt install -y git
cd /usr/src
sudo git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
```

Run the read-only pre-check first:

```bash
sudo bash install.sh --check
```

Then run the real installer:

```bash
sudo bash install.sh
```

The real installation requires the explicit confirmation word:

```text
INSTALL
```

### Language flow

When `--lang` is not supplied, the installer first asks for the **installer language**:

```text
1) Português (Brasil)
2) English
```

It then asks separately for the **dashboard language**:

```text
1) Português (Brasil)
2) English
3) Español
4) Français
5) Deutsch
6) Italiano
```

The public dashboard is built and tested in all six languages. The private Admin has two complete operational interfaces: **Português (Brasil)** and **English**. When the public dashboard uses Spanish, French, German or Italian, the private Admin uses English rather than a partially translated safety interface.

You can preselect the dashboard/installer English flow with:

```bash
sudo bash install.sh --lang=en
```

---

## Existing XLXD: dashboard-only update

A full install is intentionally blocked when an active XLXD installation is detected. To install/update only the Modern dashboard while preserving the existing XLXD core:

```bash
sudo bash install.sh --dashboard-only
```

This path creates a preventive backup and does not reinstall the XLXD binary.

---

## Canonical dashboard

The only clean-install dashboard destination is:

```text
/var/www/html/xlxd
```

The dashboard installer:

- reuses reflector identity captured by the base installer;
- creates `config/site.php`;
- builds the selected locale;
- renders generic placeholders;
- provisions required cache directories;
- configures Apache;
- requests HTTPS with Certbot when selected;
- installs CallingHome;
- installs the hidden Admin;
- validates required APIs and runtime data.

Important public routes include:

```text
/ao-vivo
/conectados
/ranking
/refletores
/api/status.php
/api/live.php
```

---

## Private Admin

The Admin is intentionally hidden from public navigation and search-engine files. Its default route is `admin`, but the operator can choose another valid route during installation.

Install or repair the Admin independently on an already functional XLX Modern installation:

```bash
sudo bash install-control.sh
```

The isolated installer uses `/var/www/html/xlxd` by default.

Admin features include:

- XLXD status, version, SHA, PID and process count;
- UDP listeners;
- recent logs and backups;
- general HTTP/API tests;
- protected XLXD restart with password confirmation and post-restart SHA/version validation;
- RadioID search, add, edit, delete, integrity check and refresh;
- whitelist and blacklist management;
- XLX Interlink peer management;
- audit records, CSRF protection, login rate limiting and secure cookies.

No general web terminal or arbitrary shell command is exposed.

### Interlink

The Admin edits the native XLXD peer-list format in:

```text
/xlxd/xlxd.interlink
```

Each active entry follows:

```text
PEER ADDRESS MODULES
```

Example:

```text
XLX123 peer.example.net ABCDE
```

The Admin adds/updates/removes one peer at a time while preserving comments and unrelated entries such as an Echo line. Every change creates a backup and uses validation plus atomic publication. XLXD's gatekeeper monitors the peer list and reloads file changes automatically, so an Interlink edit does not normally require an XLXD restart.

See [control/README.md](control/README.md).

---

## RadioID / callsign database

The Modern runtime layer maintains:

```text
/xlxd/users_db/users_base.csv
/xlxd/users_db/users.db
```

The daily refresh uses a candidate database, checks SQLite integrity, and only then publishes it. Local Admin changes are stored separately and reapplied after upstream refreshes, so a manual correction is not silently lost the next day.

The final Modern-layer validation requires `users.db` to exist, pass `PRAGMA integrity_check`, and contain a meaningful record set before installation is reported successful.

---

## CallingHome

CallingHome is independent of the retired dashboard implementation. The Modern installer creates a protected local configuration and installs a dedicated systemd timer/client. It uses the reflector identity, dashboard URL, country, comment, XLXD version and native Interlink list when registering with the XLX directory.

The timer retries automatically if a temporary network/directory failure occurs.

---

## Optional components

### APRS / D-PRS

APRS/D-PRS is optional. It can be selected during installation or explicitly requested with:

```bash
sudo bash install.sh --with-aprs-dprs
```

Skip the prompt/module with:

```bash
sudo bash install.sh --without-aprs-dprs
```

### Certificates

Certificates are **not part of the standard public installation**. They remain an optional module and are installed only when explicitly enabled through the supported Certificate workflow.

---

## Firewall and network reachability

Like the PP5PK base, this project does not claim that a VPS/provider firewall has been opened merely because XLXD is running. Provider firewall, NAT/port-forwarding and DNS are external to the installer and must be verified on the real host.

See the firewall documentation in `docs/` before public protocol testing.

---

## Safety model

The project follows these rules:

- read-only `--check` before real installation;
- no full overwrite of an active XLXD installation;
- explicit `INSTALL` confirmation;
- preventive backup before Modern-layer publication;
- SHA/syntax/config/integrity validation;
- restricted sudo actions in the Admin;
- no plaintext Admin password in the repository or webroot;
- no public Admin link;
- no `NOPASSWD: ALL`;
- no web shell;
- local RadioID persistence;
- automatic rollback where a Modern mutable operation can be validated atomically.

---

## CI and release acceptance

GitHub Actions validates Bash/Python/PHP/JavaScript syntax, generic dashboard builds, all six dashboard locales, PT-BR/English Admin builds, RadioID persistence, restricted privileges, retired-path guards, the PP5PK vendor pin and an end-to-end Interlink write/delete test through the `www-data → sudo → helper` boundary.

CI is necessary but cannot prove real DNS propagation, provider firewall configuration or live D-STAR/DMR/YSF radio traffic. A release is only considered field-validated after a clean Debian 12 VPS installation and real protocol tests.

---

## Credits

- XLXD: Jean-Luc Deltombe — LX3JL and contributors
- Base installer: Daniel K. — PP5PK
- XLX Modern Installer / Modern Dashboard integration: Dario — PU2PNY

See [CREDITS.md](CREDITS.md), [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and [LICENSE](LICENSE).
