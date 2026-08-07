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

`install.sh` performs preflight validation, verifies the reviewed upstream installer by pinned commit and SHA-256, creates a preventive backup when necessary, requires explicit confirmation before production changes, runs the XLX installation, replaces the stock web interface with the XLX Modern Dashboard, and validates essential services at the end.

The dashboard installer builds a staging copy first, validates PHP/JavaScript/configuration, creates a rollback path, installs the persistent ranking collector, prepares cache directories, then swaps the web directory only after staging validation.

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

The installer will clearly request confirmation before production-changing actions.

## Dashboard-only installer

For a server where XLXD is already correctly installed and you only intend to deploy the modern dashboard from this repository:

```bash
sudo bash dashboard/install/install-dashboard.sh
```

Default destination: `/var/www/html/xlxd`.

The dashboard installer can auto-detect the current XLX identifier and Apache `ServerName` when available, then asks for the remaining deployment-specific values. Runtime configuration is written to `dashboard/config/site.json` on the installed server; that file is intentionally not committed.

## Dashboard configuration

An example is provided at:

```text
dashboard/config/site.example.json
```

Important deployment fields include reflector ID/code, domain, sysop callsign, location, country, locale, YSF ID, DMR TGs, default DMR module, and module descriptions.

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

Statistics are stored under `/var/lib/xlx-ranking`. The public dashboard API reads the generated JSON only; the SQLite database is not exposed by the web server.

## Safety model

The release follows these principles:

- no overwrite of an already active XLX installation by the top-level installer;
- preventive backup before production installation;
- reviewed upstream commit + SHA-256 verification;
- staging validation before dashboard replacement;
- PHP/JavaScript/config validation;
- systemd service validation;
- Apache configuration test;
- dashboard rollback script;
- no secrets or production databases in the repository.

## Validation in GitHub Actions

The repository CI checks shell syntax, PHP syntax, JavaScript syntax, JSON validity, the ranking collector self-test, and verifies that the distributed dashboard does not contain the excluded Support/News implementation or XLX026 production identity.

## Security

Do not publish production credentials, SSH keys, certificates, database files, API tokens, private logs, or `dashboard/config/site.json`.

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
