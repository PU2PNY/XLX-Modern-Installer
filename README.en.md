# 🌐 XLX Modern Installer — Install, Update and Recover XLX Reflectors on Debian 12

<div align="center">

![Debian 12](https://img.shields.io/badge/Debian-12-red?logo=debian&logoColor=white)
![Architecture](https://img.shields.io/badge/Architecture-x86__64-blue)
![XLX](https://img.shields.io/badge/XLX-D--STAR%20%7C%20DMR%20%7C%20C4FM%2FYSF-00c8ff)
![Dashboard](https://img.shields.io/badge/Dashboard-Modern-success)
![License](https://img.shields.io/badge/License-MIT-yellow)
![Maintenance](https://img.shields.io/badge/Maintenance-Backup%20%7C%20Diagnostics%20%7C%20Rollback-brightgreen)

**Controlled installer and maintenance toolkit for XLX reflectors on Debian 12, with a modern dashboard, preventive backups, diagnostics, recovery guidance and bilingual documentation.**

D-STAR • DMR • C4FM/YSF • XLX Echo • Modern Dashboard • Debian 12

🇺🇸 **English** | 🇧🇷 [Documentação em Português](README.md)

[Install](#-quick-install) • [Usage modes](#-installation-and-maintenance-modes) • [Firewall](#-firewall-and-required-ports) • [File locations](#-file-locations) • [Update](#-update) • [Recovery](#-backup-diagnostics-and-recovery) • [Languages](#-universal-dashboard-and-languages) • [Credits](#-credits-and-related-projects) • [License](#-license)

</div>

---

## 📖 About the project

**XLX Modern Installer** is designed to make installation, updating, maintenance and recovery of a **multi-protocol XLX reflector** on Debian 12 safer and easier to audit.

The project uses the installer maintained by **Daniel K. — PP5PK** as a reviewed technical base and adds its own operational safety layer, documentation, modern dashboard integration and maintenance workflows.

This repository is organized to answer searches such as:

- how to install XLX on Debian 12;
- how to install XLXD on a VPS;
- how to deploy a D-STAR, DMR and C4FM/YSF reflector;
- how to install only the XLX dashboard;
- how to update an XLX server;
- how to recover an XLXD server that does not start;
- which firewall ports XLX requires;
- where XLX configuration files and logs are stored;
- how to back up and roll back an XLX reflector.

> **Goal:** help an amateur radio operator install, maintain and recover an XLX reflector with clear, reproducible and documented procedures.

---

## ✨ Main features

| Feature | Status | Description |
|---|---:|---|
| 🆕 Full new installation | ✅ | Installs the XLX core and modern dashboard |
| 🔎 Pre-flight validation / dry-run | ✅ | Checks Debian, architecture, resources, network and existing installations |
| 🖥️ Dashboard-only installation | ✅ | Installs or reinstalls only the dashboard |
| 💾 Preventive backup | ✅ | Creates a backup before real changes |
| 🧾 Installation logs | ✅ | Stores execution logs for later diagnostics |
| 🛡️ Overwrite protection | ✅ | Stops if an active XLXD installation is detected |
| 🔄 Git-based updates | ✅ | Controlled repository updates |
| 📡 D-STAR / DMR / C4FM-YSF | ✅ | Multi-protocol XLX base |
| 🔊 XLX Echo | ✅ | Optional echo/parrot test service |
| 🌍 PT/EN documentation | ✅ | Main documentation in two languages |
| 🌐 Multilingual dashboard | 🚧 | Internationalization architecture in development |
| 🧰 Core-only reinstall | 🚧 | Requires a dedicated recovery workflow |

---

## 📋 Requirements

Recommended environment:

- Debian 12;
- x86_64 architecture;
- root or sudo access;
- fixed public IP for production;
- DNS/FQDN pointing to the server;
- HTTPS access to GitHub;
- at least 768 MB RAM;
- at least 4 GB free disk space;
- ability to manage firewall/NAT when required.

---

# 🚀 Quick install

## 1. Update the system and install Git

```bash
sudo apt update
sudo apt install -y git
```

## 2. Clone the repository

```bash
cd /usr/src
sudo git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
```

## 3. Run pre-flight validation first

```bash
sudo bash install.sh --check
```

`--check` validates the environment **without performing the real installation**.

## 4. Run the full installation

```bash
sudo bash install.sh
```

Before real changes, the installer creates a preventive backup and requires explicit confirmation.

---

# 🧭 Installation and maintenance modes

## 🆕 New installation — XLXD + dashboard

Use on a clean VPS/server:

```bash
cd /usr/src/XLX-Modern-Installer
sudo bash install.sh --check
sudo bash install.sh
```

Expected workflow:

```text
VALIDATION → INVENTORY → BACKUP → XLXD → SYSTEMD → DASHBOARD → APACHE/HTTPS → TESTS
```

## 🖥️ Install or reinstall only the dashboard

If XLXD is already operational and only the dashboard needs work:

```bash
cd /usr/src/XLX-Modern-Installer
sudo bash modules/60-dashboard-modern.sh
```

The dashboard module is separated from the core and backs up an existing dashboard before replacement.

## 📡 Reinstall only the XLXD core

The new-installation `install.sh` **must not overwrite a production XLXD server**. This protection exists to preserve:

- reflector identity;
- whitelist and blacklist;
- interlinks;
- user databases;
- Calling Home;
- systemd services;
- Apache;
- dashboard;
- local configuration.

A safe core rebuild should follow:

```text
DIAGNOSE → VERIFIED BACKUP → REBUILD CORE → VALIDATE → KEEP ROLLBACK AVAILABLE
```

---

# 🔥 Firewall and required ports

The ports actually required depend on enabled protocols and services. **Do not expose ports you do not use.** With NAT, router/provider forwarding may also be required.

| Port | Transport | Typical use |
|---:|:---:|---|
| 22 | TCP | Administrative SSH |
| 80 | TCP | HTTP / certificate issuance or renewal |
| 443 | TCP | HTTPS dashboard |
| 8080 | TCP | RepNet when used |
| 20001-20005 | TCP/UDP | DPlus depending on configuration |
| 40001 | TCP | Icom G3 when applicable |
| 8880 | UDP | DMR+ DMO |
| 10001 | UDP | XLX Core JSON interface |
| 10002 | UDP | XLX interlink |
| 10100 | UDP | AMBE controller |
| 10101-10199 | UDP | AMBE transcoding |
| 12345-12346 | UDP | Icom Terminal presence/request |
| 21110 | UDP | Yaesu IMRS |
| 30001 | UDP | DExtra |
| 30051 | UDP | DCS |
| 40000 | UDP | Icom Terminal DV |
| 42000 | UDP | YSF, common/configurable value |
| 62030 | UDP | MMDVM/DMR |

### Show listening ports

```bash
sudo ss -lntup
```

### UFW inspection

```bash
sudo ufw status verbose
```

> The project follows a **least exposure necessary** approach: open only the services your reflector actually provides.

Upstream protocol/port reference: [LX3JL/xlxd](https://github.com/LX3JL/xlxd).

---

# 📂 File locations

These paths are useful for maintenance, backup and recovery. Optional components may not exist unless installed.

| Purpose | Path |
|---|---|
| XLXD core | `/xlxd/` |
| User database/files | `/xlxd/users_db/` |
| Calling Home | `/xlxd/callinghome.php` |
| Whitelist | `/xlxd/xlxd.whitelist` |
| Blacklist | `/xlxd/xlxd.blacklist` |
| Interlinks | `/xlxd/xlxd.interlink` |
| Terminals | `/xlxd/xlxd.terminal` |
| Local project repository | `/usr/src/XLX-Modern-Installer/` |
| Controlled wrapper area | `/opt/xlx-modern-installer/` |
| Modern dashboard | `/var/www/html/xlx-dashboard/` |
| General web content | `/var/www/html/` |
| XLXD service | `/etc/systemd/system/xlxd.service` |
| XLXEcho service | `/etc/systemd/system/xlxecho.service` |
| Apache configuration | `/etc/apache2/` |
| Preventive backups | `/var/backups/xlx-reflector/` |
| Installer logs | `/var/log/xlx-reflector/installer/` |
| XLX logs | `/var/log/xlx*` and environment-specific files |

### Quickly locate XLX-related files

```bash
sudo find /xlxd /usr/src /var/www/html /etc/systemd/system -maxdepth 3 \
  \( -iname '*xlx*' -o -iname '*dstar*' \) -print 2>/dev/null
```

---

# 🔄 Update

## Update only project files

```bash
cd /usr/src/XLX-Modern-Installer
git status
git pull --ff-only
sudo bash install.sh --check
```

> Updating Git **does not mean** running a full new installation over a production XLXD instance.

## Update/reinstall only the dashboard

```bash
sudo bash modules/60-dashboard-modern.sh
```

---

# 💾 Backup, diagnostics and recovery

## Minimum paths worth preserving

```text
/xlxd/
/xlxd/users_db/
/xlxd/callinghome.php
/xlxd/xlxd.blacklist
/xlxd/xlxd.whitelist
/xlxd/xlxd.interlink
/xlxd/xlxd.terminal
/etc/systemd/system/xlxd.service
/etc/systemd/system/xlxecho.service
/etc/apache2/
/var/www/html/
```

## Recommended sequence

```text
1. DIAGNOSE
2. INVENTORY
3. CREATE AND VERIFY BACKUP
4. IDENTIFY ROOT CAUSE
5. MAKE THE SMALLEST POSSIBLE CHANGE
6. VALIDATE SERVICES
7. VALIDATE DASHBOARD
8. KEEP ROLLBACK AVAILABLE
```

## Useful commands

```bash
sudo systemctl status xlxd.service --no-pager
sudo journalctl -u xlxd.service -n 100 --no-pager
sudo journalctl -u xlxd.service -f
sudo systemctl cat xlxd.service
sudo apache2ctl configtest
sudo ss -lntup
ps aux | grep '[x]lxd'
```

---

# 🎯 Optional post-install steps

These steps are not required for every reflector. Use them only when appropriate for your architecture.

## 📡 YSF publication/registration

If you want to publish a compatible YSF service according to your reflector architecture, see:

- [DVRef — reflector directory and registration](https://dvref.com/)

> XLX can also operate as a YSF Master with its own room architecture. Confirm that external registration is appropriate before publishing.

## 🔒 Manual HTTPS setup

If HTTPS was not configured automatically:

1. confirm DNS points to the server;
2. confirm TCP 80 and 443 through firewall/NAT;
3. validate Apache;
4. use the official [Certbot](https://certbot.eff.org/) instructions.

Before requesting a certificate:

```bash
sudo apache2ctl configtest
sudo ss -lntp | grep -E ':(80|443)\b'
```

## 🔊 XLX Echo / Parrot

For deployments using audio loopback testing, see:

- [narspt/XLXEcho](https://github.com/narspt/XLXEcho)

---

# 🌐 Universal dashboard and languages

The project is preparing an internationalization architecture so the dashboard can have an installation-time default language and later allow each visitor to select a preferred language.

Priority languages:

- 🇧🇷 Português (Brasil)
- 🇺🇸 English
- 🇪🇸 Español
- 🇫🇷 Français
- 🇩🇪 Deutsch
- 🇮🇹 Italiano

Proposed installer selection:

```text
Choose dashboard language / Escolha o idioma do painel
1) Português (Brasil)
2) English
3) Español
4) Français
5) Deutsch
6) Italiano
7) Automatic / Automático
```

The implementation will use **translation keys**, not six separate copies of the dashboard.

Full architecture: **[docs/INTERNATIONALIZATION.md](docs/INTERNATIONALIZATION.md)**.

---

# 🧱 Project structure

```text
XLX-Modern-Installer/
├── install.sh
├── LICENSE
├── THIRD_PARTY_NOTICES.md
├── README.md
├── README.en.md
├── config/
├── dashboard/
│   └── install/
│       └── install-dashboard.sh
├── docs/
├── modules/
│   └── 60-dashboard-modern.sh
├── references/
├── scripts/
└── tests/
```

---

# 🔗 Credits and related projects

This project does not hide its technical origins. Each upstream component keeps its own credit and license.

| Project / service | Author / organization | Relationship |
|---|---|---|
| [XLX / XLXD](https://github.com/LX3JL/xlxd) | LX3JL / LX1IQ and contributors | Upstream multi-protocol core |
| [PP5PK/XLX_Installer](https://github.com/PP5PK/XLX_Installer) | Daniel K. — PP5PK | Reviewed installer technical base |
| [XLXEcho](https://github.com/narspt/XLXEcho) | narspt | Optional echo/parrot service |
| [Certbot](https://certbot.eff.org/) | EFF / Certbot community | HTTPS/SSL |
| [DVRef](https://dvref.com/) | digital radio community | YSF registration/directory reference |
| [XLX Modern Installer](https://github.com/PU2PNY/XLX-Modern-Installer) | Dario — PU2PNY | Integration, operational safety, documentation and modern dashboard |

Detailed notices: **[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)**.

---

# 📄 License

**Original components authored for this repository** are provided under the **MIT License**, allowing use, study, modification and redistribution under the license terms.

Read: **[LICENSE](LICENSE)**.

⚠️ **Important:** third-party components retain their original licenses. XLXD upstream, for example, is distributed under GPL licensing. This project's MIT license does not replace upstream licenses.

Also see **[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)**.

---

# ❓ Frequently asked questions

## How do I install XLX on Debian 12?

```bash
sudo apt update && sudo apt install -y git
cd /usr/src
sudo git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
sudo bash install.sh --check
sudo bash install.sh
```

## How do I install only the dashboard?

```bash
cd /usr/src/XLX-Modern-Installer
sudo bash modules/60-dashboard-modern.sh
```

## Can I run `install.sh` over a working XLXD server?

No. The overwrite protection is intentional.

## Where can I find required firewall ports?

See **Firewall and required ports** in this README and the upstream XLXD documentation.

## Where are the important files located?

See **File locations** in this page.

## Will the dashboard support multiple languages?

Yes. The multilingual architecture is documented and will use translation keys, with a default language selected during installation and a visitor language selector planned later.

---

# 🔎 Related search terms

XLX reflector installer, install XLX Debian 12, install XLXD VPS, D-STAR reflector server, DMR reflector server, C4FM YSF reflector, XLX dashboard, XLX firewall ports, XLXD ports, update XLX reflector, recover XLXD, reinstall XLX dashboard, amateur radio reflector, ham radio digital voice server.

---

## 🇧🇷 Português

Complete Portuguese version: **[README.md](README.md)**.
