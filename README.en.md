# XLX Modern Installer

A conservative installer and maintenance layer for **XLX reflectors on Debian 12 x86_64**, maintained by **Dario — PU2PNY** and based on the reviewed installer by **Daniel K. — PP5PK**.

The project keeps the proven PP5PK XLXD core installation flow and replaces the legacy dashboard/data layer with the XLX Modern Dashboard, persistent RadioID management, a hidden private Admin, dedicated CallingHome, and optional APRS/D-PRS / Certificate modules.

> **Canonical paths**
>
> - XLXD core, native lists and runtime data: `/xlxd`
> - Modern dashboard webroot: `/var/www/html/xlxd`
> - The retired `/var/www/html/xlxd-novo` path is not a clean-install target.

Português: [README.pt-BR.md](README.pt-BR.md)

## Clean installation

A successful clean installation is designed to provide the reviewed PP5PK XLXD core flow, configurable reflector identity, 1–26 modules, configurable YSF port/frequency/auto-link, optional XLX Echo, systemd services, the Modern Dashboard at `/var/www/html/xlxd`, Apache/optional HTTPS, daily RadioID refresh with persistent local corrections, the TX/RX log bridge, dedicated CallingHome, the hidden Admin, and optional APRS/D-PRS / Certificates.

The public package intentionally does not copy XLX026-only Support, ANATEL simulator or News content into other reflectors.

## Reviewed PP5PK base

- repository: `PP5PK/XLX_Installer`
- reviewed commit: `20b48934505b1939317bf71b30ddc32b1ced0035`
- upstream `installer.sh` Git blob: `266217ee910742710b9c5c9f30009c8a0f0fcaf7`

The vendored core installer is checked by SHA-256 before use. See [vendor/pp5pk-installer/UPSTREAM.md](vendor/pp5pk-installer/UPSTREAM.md) and [docs/PP5PK-COMPATIBILITY-MATRIX.md](docs/PP5PK-COMPATIBILITY-MATRIX.md).

## Quick start

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

### Languages

Without `--lang`, the installer first asks for the installer interface language:

```text
1) Português (Brasil)
2) English
```

It then asks separately for the public dashboard language:

```text
1) Português (Brasil)
2) English
3) Español
4) Français
5) Deutsch
6) Italiano
```

The public dashboard is built/tested in all six languages. The private operational Admin has two complete interfaces: Portuguese (Brazil) and English. For Spanish/French/German/Italian public dashboards, the private Admin uses English instead of a partially translated safety screen.

Use English directly with:

```bash
sudo bash install.sh --lang=en
```

## Existing XLXD

A full installation is intentionally blocked over an active XLXD installation. Update/reinstall only the Modern dashboard with:

```bash
sudo bash install.sh --dashboard-only
```

This path preserves the XLXD core and creates a preventive backup.

## Private Admin

Install or repair it independently with:

```bash
sudo bash install-control.sh
```

Its canonical dashboard target is `/var/www/html/xlxd`. The route defaults to `admin` but can be renamed. It is hidden from the public menu, sitemap/robots/AI files and known crawlers.

Functions include status/version/SHA/PID, listeners, logs, backups, API tests, password-protected XLXD restart, RadioID search/add/edit/delete/check/refresh, whitelist/blacklist, and native XLX Interlink peer management. There is no generic web terminal or arbitrary shell command.

### XLX Interlink

The Admin manages `/xlxd/xlxd.interlink` in the native XLXD format:

```text
PEER ADDRESS MODULES
```

It changes one peer at a time, preserves unrelated entries/comments, creates a backup, validates the complete file and publishes atomically. XLXD monitors the peer list and reloads it automatically, so an Interlink peer edit normally does not require an XLXD restart.

See [control/README.md](control/README.md).

## RadioID

The Modern runtime layer maintains `/xlxd/users_db/users_base.csv` and `/xlxd/users_db/users.db`, publishes a candidate only after SQLite integrity validation, and reapplies local Admin corrections/deletions after upstream refreshes.

## CallingHome

CallingHome is independent from the retired dashboard. The Modern installer deploys a dedicated client/timer using the reflector identity, dashboard URL, XLXD version, country/comment and Interlink list. Temporary failures are retried by systemd.

## Optional APRS/D-PRS

```bash
sudo bash install.sh --with-aprs-dprs
```

Or skip it with:

```bash
sudo bash install.sh --without-aprs-dprs
```

## Optional Certificates

Certificates are **not part of the standard public installation**. They are installed only when explicitly enabled through the supported Certificate workflow.

## Network/firewall

The installer cannot prove provider firewall, NAT or DNS reachability from source-level CI. Follow the port/firewall documentation in `docs/` and perform live protocol tests on the clean VPS.

## CI and acceptance

CI validates Bash/Python/PHP/JavaScript syntax, six dashboard locales, PT-BR/English Admin builds, RadioID persistence, restricted privileges, canonical paths, the reviewed PP5PK pin and an end-to-end Interlink write/delete test through the `www-data → sudo → helper` boundary.

CI cannot prove live D-STAR/DMR/YSF traffic or external firewall/DNS behavior. Field acceptance requires a clean Debian 12 VPS installation and real protocol testing.

## Credits

- XLXD: Jean-Luc Deltombe — LX3JL and contributors
- Base installer: Daniel K. — PP5PK
- XLX Modern Installer / Modern Dashboard integration: Dario — PU2PNY

See [CREDITS.md](CREDITS.md), [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and [LICENSE](LICENSE).
