# 🌐 XLX Modern Installer — Install, Update and Recover XLX Reflectors on Debian 12

<div align="center">

![Debian 12](https://img.shields.io/badge/Debian-12-red?logo=debian&logoColor=white)
![Architecture](https://img.shields.io/badge/Architecture-x86__64-blue)
![XLX](https://img.shields.io/badge/XLX-D--STAR%20%7C%20DMR%20%7C%20C4FM%2FYSF-00c8ff)
![Dashboard](https://img.shields.io/badge/Dashboard-Modern-success)
![Languages](https://img.shields.io/badge/Dashboard-6%20languages-blueviolet)
![License](https://img.shields.io/badge/Project-MIT-yellow)

**Installer and maintenance toolkit for XLX reflectors on Debian 12 with pre-flight validation, preventive backup, modern dashboard, bilingual documentation, internationalization, diagnostics and recovery guidance.**

D-STAR • DMR • C4FM/YSF • XLX Echo • Modern Dashboard • Debian 12

🇺🇸 **English** | 🇧🇷 [Português](README.md) | 📚 [Documentation](docs/README.md)

[Install](#-quick-installation) • [What do you want to do?](#-what-do-you-want-to-do) • [Dashboard](#-modern-dashboard) • [Languages](#-dashboard-languages) • [Firewall](#-firewall-and-ports) • [Recovery](#-backup-diagnostics-and-recovery) • [Credits](#-credits-and-related-projects)

</div>

---

## 🖥️ Real dashboard

The screenshot below is a real **XLX Modern Dashboard** running in production-like use. It shows the multi-protocol header, recent transmissions, live/standby monitor, server operational state, connected stations, local weather and amateur-radio propagation conditions.

<p align="center">
  <img src="docs/images/xlx-modern-dashboard.webp" alt="Real XLX Modern Dashboard showing D-STAR, DMR, C4FM YSF, latest transmissions, live monitor, connected stations, local weather and propagation conditions" width="900">
</p>

> Appearance and displayed data depend on each reflector configuration. This is a real dashboard capture, not a mockup.

---

## 📖 What is XLX Modern Installer?

**XLX Modern Installer** is designed to make the installation, updating, maintenance and recovery of an **XLX multi-protocol reflector** on Debian 12 easier to reproduce and safer to operate.

The project uses the installer maintained by **Daniel K. — PP5PK** as a reviewed technical base and adds its own validation, backup, modern dashboard, documentation, internationalization and maintenance layer.

It is organized around real search intents such as:

- how to install an XLX reflector on Debian 12;
- how to install XLXD on a VPS;
- how to deploy a D-STAR, DMR and C4FM/YSF reflector;
- how to install or reinstall only an XLX dashboard;
- how to choose an XLX dashboard language;
- how to update an XLX server;
- how to recover XLXD when it does not start;
- which firewall ports an XLX reflector needs;
- where XLX files and logs are stored;
- how to configure HTTPS and post-installation tasks.

> **Operational principle:** diagnose before changing, back up before changes, validate afterwards and keep rollback available.

---

## ✨ Main features

| Feature | Status | Description |
|---|:---:|---|
| 🆕 New XLX + dashboard installation | ✅ | Installs the XLX core and then the modern dashboard |
| 🔎 Pre-flight validation / dry-run | ✅ | Checks Debian, architecture, resources, network and existing installations |
| 🖥️ Dashboard-only installation | ✅ | Installs or reinstalls the dashboard separately |
| 🌍 Dashboard in 6 languages | ✅ | `pt-BR`, `en`, `es`, `fr`, `de`, `it`, selected at installation time |
| 💾 Preventive backup | ✅ | Protects existing files before real changes |
| 🧾 Installation logs | ✅ | Stores execution logs for later diagnostics |
| 🛡️ Production protection | ✅ | Blocks a full install over an active XLXD deployment |
| 📡 D-STAR / DMR / C4FM-YSF | ✅ | Multi-protocol XLX base |
| 🔊 XLX Echo | ✅ | Supports the optional echo service when installed |
| 🔄 Git-based project updates | ✅ | Controlled repository updates |
| 🔐 CI and basic secret guard | ✅ | Validates Shell, PHP, translations and common private-key/token patterns |
| 🧰 Automated core-only reinstall | 🚧 | Still requires a dedicated recovery workflow; `install.sh` does not overwrite production |

---

# 🚀 Quick installation

Use a clean VPS/server running **Debian 12 x86_64**.

### 1. Install Git

```bash
sudo apt update
sudo apt install -y git
```

### 2. Clone the project

```bash
cd /usr/src
sudo git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
```

### 3. Run pre-flight validation

```bash
sudo bash install.sh --check
```

`--check` validates the environment without performing a real installation.

### 4. Install

```bash
sudo bash install.sh
```

The installer creates a preventive backup and asks for explicit confirmation before the real change.

### Install with a predefined dashboard language

```bash
sudo bash install.sh --lang=en
```

Available codes:

```text
pt-BR  en  es  fr  de  it
```

---

# 🧭 What do you want to do?

| Goal | Command / documentation |
|---|---|
| Check whether a server is ready | `sudo bash install.sh --check` |
| New complete installation | `sudo bash install.sh` |
| New installation with English dashboard | `sudo bash install.sh --lang=en` |
| Install/reinstall only the dashboard | `sudo bash modules/60-dashboard-modern.sh` |
| Install only the dashboard in Spanish | `sudo bash modules/60-dashboard-modern.sh --lang=es` |
| Update project files | `git pull --ff-only`, then `sudo bash install.sh --check` |
| Troubleshoot/recover XLX | [Update and recovery guide](docs/UPDATE-RECOVER-XLX.en.md) |
| Check firewall and ports | [XLX firewall ports](docs/XLX-FIREWALL-PORTS.en.md) |
| Find files and logs | [XLX files and logs](docs/XLX-FILES-LOGS.en.md) |
| HTTPS, YSF and post-installation | [Post-installation guide](docs/XLX-POST-INSTALL.en.md) |
| Understand dashboard languages | [Internationalization](docs/INTERNATIONALIZATION.md) |

---

# 🖥️ Modern dashboard

If XLXD is already operational and you only need to install or reinstall the **dashboard**:

```bash
cd /usr/src/XLX-Modern-Installer
sudo bash modules/60-dashboard-modern.sh
```

The dashboard installer is separate from the XLXD core. When an existing dashboard is found at the destination, it creates a backup before copying the new version.

The installer collects information such as:

- reflector identifier;
- displayed name;
- short description;
- sysop callsign;
- city/region;
- country;
- domain;
- contact email;
- dashboard language.

## 🌍 Dashboard languages

The installer offers:

```text
Dashboard Language / Idioma do Painel
1) Português (Brasil)
2) English
3) Español
4) Français
5) Deutsch
6) Italiano
```

A language can also be specified directly:

```bash
sudo bash modules/60-dashboard-modern.sh --lang=de
```

Translation is applied to the deployed dashboard copy, including the main visible areas and language/SEO metadata. The project keeps one codebase with separate translation catalogs.

> Per-visitor language switching without reinstalling is a future enhancement. Today the default language is selected during installation.

Details: [docs/INTERNATIONALIZATION.md](docs/INTERNATIONALIZATION.md).

---

# 🔥 Firewall and ports

There is no universal port list that every reflector should expose. Enable only protocols and services that your deployment actually uses.

Start by checking the server:

```bash
sudo ss -lntup
sudo ufw status verbose
```

Detailed table, NAT guidance and diagnostic examples:

**[📘 XLX firewall ports](docs/XLX-FIREWALL-PORTS.en.md)**

---

# 📂 Files and logs

Important paths commonly include:

```text
/xlxd/
/xlxd/users_db/
/xlxd/callinghome.php
/xlxd/xlxd.whitelist
/xlxd/xlxd.blacklist
/xlxd/xlxd.interlink
/xlxd/xlxd.terminal
/etc/systemd/system/xlxd.service
/etc/systemd/system/xlxecho.service
/etc/apache2/
/var/www/html/
/usr/src/XLX-Modern-Installer/
/var/backups/xlx-reflector/
/var/log/xlx-reflector/installer/
```

Full guide: **[Where XLX files and logs are stored](docs/XLX-FILES-LOGS.en.md)**.

---

# 🔄 Updating

Update only the local repository files:

```bash
cd /usr/src/XLX-Modern-Installer
git status
git pull --ff-only
sudo bash install.sh --check
```

> **Do not run `install.sh` again over a working XLXD deployment just because the Git repository was updated.** The installer intentionally blocks production overwrite.

To update/reinstall only the dashboard:

```bash
sudo bash modules/60-dashboard-modern.sh
```

---

# 💾 Backup, diagnostics and recovery

Before repairing an existing server, preserve every relevant path that actually exists, especially:

```text
/xlxd/
/xlxd/users_db/
/xlxd/callinghome.php
/xlxd/xlxd.whitelist
/xlxd/xlxd.blacklist
/xlxd/xlxd.interlink
/xlxd/xlxd.terminal
/etc/systemd/system/xlxd.service
/etc/systemd/system/xlxecho.service
/etc/apache2/
/var/www/html/
```

Recommended workflow:

```text
DIAGNOSE → INVENTORY → VERIFIED BACKUP → MINIMAL CHANGE → VALIDATE → ROLLBACK
```

Useful commands:

```bash
sudo systemctl status xlxd.service --no-pager
sudo journalctl -u xlxd.service -n 100 --no-pager
sudo systemctl cat xlxd.service
sudo apache2ctl configtest
sudo ss -lntup
ps aux | grep '[x]lxd'
```

Full guide: **[Update, troubleshoot and recover XLX](docs/UPDATE-RECOVER-XLX.en.md)**.

---

# 🎯 Post-installation and optional tasks

Depending on the architecture, additional tasks can include:

- compatible YSF service publication/registration — [DVRef](https://dvref.com/);
- manual HTTPS — [Certbot](https://certbot.eff.org/);
- echo/parrot testing — [narspt/XLXEcho](https://github.com/narspt/XLXEcho);
- DNS, Apache and firewall validation;
- validated post-installation backup;
- local documentation of modules, protocols and ports in use.

See **[XLX post-installation guide](docs/XLX-POST-INSTALL.en.md)**.

---

# 🧪 Quality and validation

The repository includes GitHub Actions checks for:

- Bash syntax;
- dashboard PHP syntax;
- translation-key parity across all six catalogs;
- generation of a dashboard build for every supported language;
- common private-key and token patterns.

Automated validation complements but does not replace testing on a staging VPS before important production changes.

---

# 🧱 Project structure

```text
XLX-Modern-Installer/
├── install.sh
├── LICENSE
├── SECURITY.md
├── CONTRIBUTING.md
├── THIRD_PARTY_NOTICES.md
├── README.md
├── README.en.md
├── dashboard/
│   ├── i18n/
│   │   ├── bootstrap.php
│   │   ├── build.php
│   │   └── locales/
│   └── install/
├── docs/
│   └── images/
├── modules/
├── scripts/
├── references/
├── tests/
└── .github/workflows/
```

---

# 🔗 Credits and related projects

| Project / resource | Relationship |
|---|---|
| [LX3JL/xlxd](https://github.com/LX3JL/xlxd) | XLXD reflector core and upstream protocol reference |
| [PP5PK/XLX_Installer](https://github.com/PP5PK/XLX_Installer) | Reviewed technical base used by the controlled installer |
| [narspt/XLXEcho](https://github.com/narspt/XLXEcho) | Related echo/parrot service |
| [Certbot](https://certbot.eff.org/) | Official HTTPS certificate reference |
| [DVRef](https://dvref.com/) | Directory/service related to compatible reflector publication |
| **Dario — PU2PNY** | Maintenance of this version, documentation, safety layer and modern dashboard |

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

---

# 📄 License

Original portions of this repository are provided under the **MIT License**. Third-party projects and code remain governed by their own licenses — the upstream XLXD project, for example, keeps its own license.

Read [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) before redistributing third-party components.

---

# 🔐 Security and contributions

- [Security Policy](SECURITY.md)
- [Contributing Guide](CONTRIBUTING.md)

Never publish passwords, tokens, private keys, real user databases or production backups in issues, commits or public logs.

---

# ❓ Frequently asked questions

### How do I install XLX on Debian 12?

Clone this repository, run `sudo bash install.sh --check`, and if validation succeeds, run `sudo bash install.sh`.

### Can I install only the dashboard?

Yes:

```bash
sudo bash modules/60-dashboard-modern.sh
```

### Can I select the dashboard language?

Yes. Choose it interactively or pass a code, for example:

```bash
sudo bash modules/60-dashboard-modern.sh --lang=en
```

### Can I run `install.sh` over a working XLXD server?

No. That situation is intentionally blocked to avoid overwriting production.

### Where are the firewall, file-location and recovery guides?

See the documentation index: **[docs/README.md](docs/README.md)**.

---

## 🔎 Related search terms

XLX reflector installer, install XLX reflector Debian 12, install XLXD VPS, D-STAR reflector server, DMR reflector server, C4FM YSF reflector, XLX dashboard, XLX firewall ports, update XLX reflector, recover XLXD server, XLX backup, amateur radio digital reflector, ham radio reflector.

---

<div align="center">

**XLX Modern Installer — documented installation, controlled maintenance and a modern dashboard for the amateur-radio community.**

🇧🇷 [Leia a versão completa em Português](README.md)

</div>
