# 🌐 XLX Modern Installer — Install, Configure and Recover XLX Reflectors on Debian 12

<div align="center">

![Debian 12](https://img.shields.io/badge/Debian-12-red?logo=debian&logoColor=white)
![Architecture](https://img.shields.io/badge/Architecture-x86__64-blue)
![XLX](https://img.shields.io/badge/XLX-D--STAR%20%7C%20DMR%20%7C%20C4FM%2FYSF-00c8ff)
![Dashboard](https://img.shields.io/badge/Dashboard-Modern-success)
![Languages](https://img.shields.io/badge/Dashboard-6%20languages-blueviolet)
![Callsigns](https://img.shields.io/badge/Callsigns-Persistent%20overrides-2ea44f)
![Certificates](https://img.shields.io/badge/Certificates-QR%20%2B%20HMAC-d4a72c)
![License](https://img.shields.io/badge/Project-MIT-yellow)

**Installer and maintenance toolkit for XLX reflectors on Debian 12 with pre-flight validation, preventive backup, a modern dashboard, persistent callsign corrections, verifiable participation certificates, internationalization, diagnostics and recovery guidance.**

D-STAR • DMR • C4FM/YSF • XLX Echo • Modern Dashboard • Callsigns • Certificates • Debian 12

🇺🇸 **English** | 🇧🇷 [Português](README.pt-BR.md) | 📚 [Documentation](docs/README.md)

</div>

---

## What is XLX Modern Installer?

**XLX Modern Installer** helps deploy, configure, maintain and recover a multi-protocol XLX reflector on Debian 12 x86_64.

The project uses the installer maintained by **Daniel K. — PP5PK** as a reviewed technical base and adds operational safety, a modern dashboard, six-language build support, persistent callsign corrections, participation certificates and recovery documentation.

The installer is generic. A new deployment uses the identity supplied by the installer — reflector name/title, domain, country, sysop callsign, YSF ID, DMR TG and other site-specific data — instead of inheriting XLX026 branding.

---

## Main features

| Feature | Status | Description |
|---|:---:|---|
| Fresh XLX + dashboard installation | ✅ | Installs XLXD and then the modern dashboard |
| Pre-flight validation | ✅ | Validates Debian, architecture, resources, network and existing installs |
| Dashboard-only installation | ✅ | Installs/reinstalls the dashboard separately |
| Live monitor | ✅ | Live transmission monitor and server status |
| 24-hour activity | ✅ | All activity available from the last 24 hours |
| Connected stations | ✅ | Callsign, protocol, module, location and activity data |
| Modules A–Z | ✅ | Select the number of active modules during installation |
| Activity ranking | ✅ | Ranking based on server data sources |
| Six dashboard languages | ✅ | `pt-BR`, `en`, `es`, `fr`, `de`, `it` |
| Persistent callsign directory | ✅ | Local corrections separated from the upstream/main user database |
| Callsign aliases | ✅ | Administrative old → new callsign mapping |
| SQLite safety | ✅ | Backup, integrity check and rollback when refreshing the main database |
| Participation certificates | ✅ | Activity-based issuance, local QR and HMAC validation |
| Automatic campaigns | ✅ | Global campaigns plus country-specific campaigns |
| Preventive backup | ✅ | Protects files before real changes |
| GitHub CI / public audit | ✅ | Validates Bash, PHP, JavaScript, translations, generic installs, callsigns and certificates |

---

# Quick installation

Use a clean **Debian 12 x86_64** VPS/server.

```bash
sudo apt update
sudo apt install -y git
cd /usr/src
sudo git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
sudo bash install.sh
```

The normal command performs the complete pre-flight validation automatically. If it passes, it continues to the final confirmation before making real changes.

Use `--check` only when you want a read-only diagnostic that intentionally stops after the validation:

```bash
sudo bash install.sh --check
```

Install with a predefined dashboard language:

```bash
sudo bash install.sh --lang=en
```

Available languages:

```text
pt-BR  en  es  fr  de  it
```

---

# How installation works

The complete flow is:

```text
PRE-FLIGHT VALIDATION
    ↓
PREVENTIVE BACKUP
    ↓
XLXD CORE INSTALLATION
    ↓
MODERN DASHBOARD
    ↓
DASHBOARD POST-INSTALL
    ↓
PERSISTENT CALLSIGN DIRECTORY
    ↓
CERTIFICATE SYSTEM
    ↓
FINAL VALIDATION
```

The dashboard installer uses the identity configured for the current reflector. Generic builds are tested to avoid fixed strings such as `BR-XLX999` or `XLX999 Brasil`.

---

# Modern dashboard

To install or reinstall only the dashboard:

```bash
cd /usr/src/XLX-Modern-Installer
sudo bash modules/60-dashboard-modern.sh
```

This flow also installs/checks the persistent callsign directory and certificate module.

The installer collects values such as:

- reflector identifier, for example `XLX724`;
- display title;
- description;
- sysop callsign;
- city/region;
- country;
- domain;
- contact email;
- YSF ID;
- DMR module mapping and voice TG;
- dashboard language;
- server timezone;
- optional reflector anniversary for certificate campaigns.

---

# Persistent callsign directory

The main XLX user database remains:

```text
/xlxd/users_db/users.db
```

Local corrections are stored separately:

```text
/var/lib/xlx-user-directory/overrides.db
```

Examples:

```bash
sudo xlx-user-directory --help
sudo xlx-user-directory lookup N0CALL
sudo xlx-user-directory set N0CALL "Operator Name" "City, Region"
sudo xlx-user-directory alias OLDCALL NEWCALL
sudo xlx-user-directory delete N0CALL
sudo xlx-user-directory check
sudo xlx-user-directory refresh
```

`refresh` performs:

```text
BACKUP CURRENT DATABASE
        ↓
VALIDATE BACKUP
        ↓
RUN XLX USER DATABASE GENERATOR
        ↓
PRAGMA integrity_check
        ↓
SUCCESS → keep new database
FAILURE → restore previous database
```

Local overrides remain separate and are not removed by `refresh`.

> Callsign aliases do **not** change what a radio actually transmits. Radio/hotspot programming must still be corrected separately.

Detailed guide: [docs/CALLSIGNS-CERTIFICATES.en.md](docs/CALLSIGNS-CERTIFICATES.en.md).

---

# Participation certificates

User page:

```text
https://YOUR-DOMAIN/certificado.php
```

A certificate is available only when an actual transmission is found during the active campaign period. Being present in the user database alone is not enough.

User flow:

1. Open `certificado.php`.
2. Enter the callsign.
3. The server checks eligible activity.
4. If eligible, a preview is shown.
5. Issue the certificate.
6. The server stores the issuance and returns a unique ID and QR code.
7. The user can print or save as PDF from the browser.

Issuance is unique per:

```text
campaign + callsign
```

Issuance records:

```text
/var/lib/xlx-certificates/emissoes.jsonl
```

Private HMAC key:

```text
/etc/xlx-certificates/hmac.key
```

QR codes are generated locally with `qrencode` and point to:

```text
/certificado-validar.php?id=...&sig=...
```

## Campaigns

For all countries:

- daily participation certificate;
- World Amateur Radio Day — April 18;
- reflector anniversary week when configured.

Brazil-only campaigns are enabled only when the configured country is Brazil:

- Mother's Day;
- Father's Day;
- Brazil Independence Day;
- Brazilian Amateur Radio Day.

A reflector configured in Portugal or another country does not inherit Brazilian campaigns.

Detailed guide: [docs/CALLSIGNS-CERTIFICATES.en.md](docs/CALLSIGNS-CERTIFICATES.en.md).

---

# Important files and persistent data

```text
/xlxd/
/xlxd/users_db/users.db
/etc/systemd/system/xlxd.service
/etc/systemd/system/xlxecho.service
/etc/apache2/
/var/www/html/xlx-dashboard/
/usr/src/XLX-Modern-Installer/
/var/lib/xlx-user-directory/overrides.db
/var/backups/xlx-reflector/callsign-directory/
/var/lib/xlx-certificates/emissoes.jsonl
/etc/xlx-certificates/hmac.key
/var/backups/xlx-reflector/
/var/log/xlx-reflector/installer/
```

Do not publish real user databases, override databases, issuance records, HMAC keys, production backups, passwords or tokens.

---

# Backup and disaster recovery

A full recovery backup should include the normal XLX files plus:

```text
/var/lib/xlx-user-directory/
/var/lib/xlx-certificates/
/etc/xlx-certificates/
```

The HMAC key is especially important because previously issued certificates depend on it for future validation.

Recommended workflow:

```text
DIAGNOSE → INVENTORY → VERIFIED BACKUP → MINIMAL CHANGE → VALIDATE → ROLLBACK
```

---

# Project structure

```text
XLX-Modern-Installer/
├── install.sh
├── README.md
├── README.en.md
├── dashboard/
│   ├── api/
│   ├── assets/
│   ├── config/
│   ├── i18n/
│   └── install/
├── extras/
│   └── certificados/
├── modules/
│   ├── 60-dashboard-modern.sh
│   ├── 65-callsign-directory.sh
│   └── 66-certificates.sh
├── tools/
│   └── xlx-user-directory.sh
├── docs/
├── scripts/
├── tests/
└── .github/workflows/
```

---

# Documentation

- [Documentation index](docs/README.md)
- [Callsign directory and certificates](docs/CALLSIGNS-CERTIFICATES.en.md)
- [Install XLX on Debian 12](docs/INSTALL-XLX-DEBIAN-12.en.md)
- [Update and recover XLX](docs/UPDATE-RECOVER-XLX.en.md)
- [Firewall and ports](docs/XLX-FIREWALL-PORTS.en.md)
- [Files and logs](docs/XLX-FILES-LOGS.en.md)
- [Post-installation](docs/XLX-POST-INSTALL.en.md)
- [Internationalization](docs/INTERNATIONALIZATION.md)

---

# Security

Never publish:

- passwords or access tokens;
- private keys;
- `/etc/xlx-certificates/hmac.key`;
- real `users.db` or `overrides.db` files;
- real `emissoes.jsonl` files;
- production backups;
- sensitive production logs.

See [SECURITY.md](SECURITY.md).

---

# Credits

| Project / resource | Relationship |
|---|---|
| [LX3JL/xlxd](https://github.com/LX3JL/xlxd) | XLXD core and protocol reference |
| [PP5PK/XLX_Installer](https://github.com/PP5PK/XLX_Installer) | Reviewed installer base |
| [narspt/XLXEcho](https://github.com/narspt/XLXEcho) | Echo/parrot service |
| [Certbot](https://certbot.eff.org/) | HTTPS certificate tooling |
| [DVRef](https://dvref.com/) | Related reflector directory/service |
| **Dario — PU2PNY** | Maintenance, documentation, safety layer and modern dashboard |

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

---

<div align="center">

**XLX Modern Installer — universal installation, modern dashboard, persistent callsign data and verifiable certificates for the amateur-radio community.**

🇧🇷 [Leia em Português](README.md)

</div>
