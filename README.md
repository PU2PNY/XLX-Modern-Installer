# XLX Modern Installer

A safety-focused installer for XLX multiprotocol amateur-radio reflectors on Debian 12, with a modern dashboard designed for reusable international deployments.

> This project builds on the XLX ecosystem and uses a reviewed, pinned revision of the PP5PK/XLX_Installer project as the installation base. Review the configuration and test on a clean or disposable VPS before production use.

## Project status

- `main` — stable published line.
- `release/global-dashboard-v1` — release candidate for the current international dashboard.
- `development/v2-native-installer` — future native modular installer; not the production path yet.

## Supported platform

- Debian 12
- x86_64
- root/sudo access
- public FQDN pointing to the VPS
- outbound HTTPS access

## What the installer does

`install.sh` performs preflight validation, verifies the reviewed upstream installer by pinned commit and SHA-256, creates a preventive backup when necessary, requires explicit confirmation before production changes, runs the XLX installation, deploys the XLX Modern Dashboard, and validates essential services at the end.

The dashboard installer builds and validates a staging copy before touching the active web directory. It then creates a verified backup and rollback path, publishes the dashboard, installs the persistent Ranking V2 collector and systemd timer, prepares runtime/cache directories, and validates Apache, XLXD, PHP and the generated ranking JSON.

## Dashboard included in this release

The international dashboard includes:

- Live / last transmissions
- Connected stations
- Modules A–E
- Persistent ranking: today, rolling 7 days, and current civil month
- XLX reflector directory
- Weather and amateur-radio propagation information based on the server location
- Responsive/mobile interface
- PWA manifest and install prompt
- Persistent ranking collector using the XLXD systemd journal and SQLite

The distributed dashboard intentionally **does not include**:

- the private XLX026 Support implementation;
- Brazilian ANATEL/LABRE News integration;
- production logs, databases, credentials, backups, private keys, or certificates.

## Reflector identifiers

The dashboard supports the XLX identifier model used by the installer: `XLX` plus exactly three alphanumeric characters, for example:

- `XLX123`
- `XLXUS1`
- `XLXBRA`

Protocol labels derived from the reflector code are generated at runtime. DTMF forms that require a numeric reflector code are shown only when the three-character code is fully numeric.

## Installation

Clone the repository and run the read-only validation first:

```bash
git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
sudo bash install.sh --check
```

If all checks pass, start the real installation:

```bash
sudo bash install.sh
```

The installer clearly requests confirmation before production-changing actions.

## Dashboard-only installer

For a server where XLXD and Apache are already correctly installed and you only intend to deploy the modern dashboard from this repository:

```bash
sudo bash dashboard/install/install-dashboard.sh --check
sudo bash dashboard/install/install-dashboard.sh
```

The dashboard installer tries to detect the active XLX web directory from common XLX paths and enabled Apache `DocumentRoot` entries. The fallback destination is `/var/www/html/xlxd`, and `INSTALL_DIR` can be used to override it explicitly.

It can also auto-detect the current XLX identifier and Apache `ServerName` when available, then asks for deployment-specific values such as sysop, location, country, locale, YSF ID and DMR TGs. Runtime configuration is written to `config/site.json` on the installed server; that file is intentionally excluded from Git.

## Dashboard configuration

An example is provided at:

```text
dashboard/config/site.example.json
```

Important deployment fields include reflector ID/code, domain, sysop callsign, location, country, locale, YSF ID, DMR TGs, default DMR module, module descriptions, XLXD XML status path, log path and user database path.

## Ranking architecture

The ranking collector is installed as:

```text
/usr/local/sbin/xlx-ranking-collector.py
```

with:

```text
xlx-ranking.service
xlx-ranking.timer
```

The timer runs every two minutes and is persistent across reboot. Statistics are stored under `/var/lib/xlx-ranking`. The public dashboard API reads only the generated JSON snapshot; the SQLite database is not exposed by the web server.

The ranking periods are:

- today, beginning at local midnight;
- trailing seven days;
- current civil month, beginning on day 1.

## Safety model

The release follows these principles:

- no overwrite of an already active XLX installation by the top-level installer;
- detection of common XLX dashboard paths, including `/var/www/html/xlxd`, `/var/www/xlxd` and `/var/www/html/xlx-dashboard`;
- preventive backup before production installation;
- reviewed upstream commit + SHA-256 verification;
- staging validation before dashboard replacement;
- PHP/JavaScript/JSON validation;
- deterministic Ranking V2 collector self-test;
- systemd service/timer validation;
- Apache configuration test;
- verified dashboard backup and rollback script;
- no secrets or production databases in the repository.

## Validation in GitHub Actions

The repository CI checks:

- shell syntax;
- PHP syntax;
- JavaScript syntax;
- JSON validity;
- Ranking V2 collector self-test;
- installer/runtime contract;
- distribution scope and secret patterns;
- exclusion of private Support and country-specific News components;
- exclusion of XLX026 production identity;
- developer attribution integrity;
- documentation contract.

## Security

Do not publish production credentials, SSH keys, certificates, database files, API tokens, private logs, backups, or `dashboard/config/site.json`.

See `SECURITY.md` for reporting guidance.

## Developer

**PU2PNY · Página Certa Digital**

- Website: https://paginacertadigital.com.br/
- Email: contato@paginacertadigital.com.br

The international dashboard displays this developer attribution in the footer and links the developer website and contact email.

## Credits

- XLX ecosystem and upstream contributors
- Daniel K. — PP5PK, author/maintainer of the upstream installer base used by this project
- PU2PNY / Página Certa Digital — modifications, safety wrapper, dashboard integration, validation and international release work

## License

No additional license is asserted here beyond the licenses and terms of the upstream components. Review upstream licensing before redistribution or public release.
