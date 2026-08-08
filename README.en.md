# 🌐 XLX Modern Installer — Install, Update and Recover XLX Reflectors on Debian 12

<div align="center">

![Debian 12](https://img.shields.io/badge/Debian-12-red?logo=debian&logoColor=white)
![Architecture](https://img.shields.io/badge/Architecture-x86__64-blue)
![XLX](https://img.shields.io/badge/XLX-D--STAR%20%7C%20DMR%20%7C%20C4FM%2FYSF-00c8ff)
![Dashboard](https://img.shields.io/badge/Dashboard-Modern-success)
![Maintenance](https://img.shields.io/badge/Maintenance-Backup%20%7C%20Diagnostics%20%7C%20Rollback-brightgreen)

**Controlled installer and maintenance toolkit for XLX reflectors on Debian 12, with a modern dashboard, preventive backups, diagnostics and recovery guidance.**

D-STAR • DMR • C4FM/YSF • XLX Echo • Modern Dashboard • Debian 12

🇺🇸 **English** | 🇧🇷 [Documentação em Português](README.md)

[Quick install](#-how-to-install-an-xlx-reflector-on-debian-12) • [Installation modes](#-installation-and-maintenance-modes) • [Update](#-how-to-update-xlx-modern-installer) • [Dashboard](#-install-or-reinstall-only-the-xlx-dashboard) • [Backups](#-backup-and-rollback) • [Troubleshooting](#-diagnostics-and-troubleshooting) • [FAQ](#-frequently-asked-questions)

</div>

---

## 📖 What is XLX Modern Installer?

**XLX Modern Installer** is designed to make installation, updating, maintenance and recovery of an **XLX multi-protocol reflector** on Debian 12 safer and easier to audit.

The project uses the installer maintained by **Daniel K. — PP5PK** as its technical base and adds a controlled operational layer with pre-flight validation, preventive backup, logs, separation between the XLXD core and the modern dashboard, and documented maintenance procedures.

This repository is intended for users searching for topics such as:

- how to install an XLX reflector on Debian 12;
- how to install XLXD on a VPS;
- how to deploy a D-STAR, DMR and C4FM/YSF reflector;
- how to install or reinstall only an XLX dashboard;
- how to update an XLX reflector installation;
- how to troubleshoot an XLX reflector that does not start;
- how to back up and roll back an XLXD installation;
- how to recover an existing XLX server without accidentally overwriting production data.

> **Core principle:** diagnose first, back up before changes, validate afterwards, and keep rollback available.

---

## ✨ Main features

| Feature | Status | Description |
|---|---:|---|
| 🆕 Full new installation | ✅ | Installs the XLX core and then the modern dashboard |
| 🔎 Pre-flight validation / dry-run | ✅ | Checks Debian, architecture, resources, network and existing installations |
| 🖥️ Dashboard-only installation | ✅ | Installs or reinstalls only the XLX Modern Dashboard |
| 💾 Preventive backup | ✅ | Creates a backup before real installation changes |
| 🧾 Installation logs | ✅ | Stores execution logs for later diagnostics |
| 🛡️ Overwrite protection | ✅ | Stops if an active XLXD installation is detected |
| 🔄 Repository update | ✅ | Controlled update through Git |
| 📡 D-STAR / DMR / C4FM-YSF | ✅ | Multi-protocol XLX base |
| 🔊 XLX Echo | ✅ | Optional service when installed |
| 🧰 Core-only reinstall | 🚧 | Requires a dedicated recovery workflow instead of `install.sh` |

---

## 📋 Requirements

Recommended environment:

- Debian 12;
- x86_64 architecture;
- root or sudo access;
- fixed public IP for production use;
- DNS/FQDN for the dashboard;
- HTTPS access to GitHub;
- at least 768 MB RAM;
- at least 4 GB free disk space.

The installer performs automatic validation before a real installation starts.

---

# 🚀 How to install an XLX reflector on Debian 12

Use this procedure for a **new XLX installation on a clean VPS or server**.

### 1. Update the system and install Git

```bash
sudo apt update
sudo apt install -y git
```

### 2. Clone XLX Modern Installer

```bash
cd /usr/src
sudo git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
```

### 3. Run pre-flight validation first

```bash
sudo bash install.sh --check
```

The `--check` mode does not install XLX. It validates the environment before any real change.

### 4. Run the full new installation

```bash
sudo bash install.sh
```

Before the real installation, the wrapper creates a preventive backup and requires explicit confirmation.

---

# 🧭 Installation and maintenance modes

## A. New installation — XLX server + dashboard

Use this on a server that does not already have an active XLXD installation.

```bash
cd /usr/src/XLX-Modern-Installer
sudo bash install.sh --check
sudo bash install.sh
```

Main workflow:

1. validate Debian 12 and architecture;
2. validate memory, disk, DNS and HTTPS;
3. confirm that no active XLX production installation exists;
4. validate the reviewed technical base;
5. create a preventive backup;
6. install the XLX core;
7. install XLX Modern Dashboard;
8. validate essential services.

---

# 🖥️ Install or reinstall only the XLX dashboard

If XLXD is already running and you only need to install, update or reinstall the modern dashboard:

```bash
cd /usr/src/XLX-Modern-Installer
sudo bash modules/60-dashboard-modern.sh
```

The dashboard installer is separate from the XLXD core. If a dashboard already exists at the destination, it creates a backup before copying the new version.

The installer asks for information such as:

- reflector identifier;
- displayed name;
- short description;
- sysop callsign;
- location;
- country;
- domain;
- contact email.

---

# 📡 Reinstall only the XLXD server core

The new-installation `install.sh` **must not be used to overwrite a running XLXD server**.

The wrapper intentionally stops when it detects an existing installation in order to protect:

- reflector identity;
- whitelist and blacklist;
- interlinks;
- local configuration;
- user databases;
- systemd configuration;
- dashboard files;
- production data.

Before rebuilding only the core, preserve at least:

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
/var/www/html/
```

A safe core rebuild should follow:

```text
DIAGNOSE → BACKUP → VALIDATE → REBUILD → TEST → KEEP ROLLBACK AVAILABLE
```

---

# 🔄 How to update XLX Modern Installer

To update only the local repository files:

```bash
cd /usr/src/XLX-Modern-Installer
git status
git pull --ff-only
```

Then run:

```bash
sudo bash install.sh --check
```

> On an already-installed XLXD server, do not run `sudo bash install.sh` again just because the Git repository was updated. Use the dashboard-specific module when only the dashboard needs updating.

---

# 💾 Backup and rollback

Default preventive backup directory:

```text
/var/backups/xlx-reflector
```

Before real installation, the wrapper can create:

```text
pre-installation.tar.gz
pre-installation.tar.gz.sha256
manifest.txt
```

Important paths to preserve include:

```text
/etc/apache2
/etc/systemd/system
/etc/ufw
/etc/nftables.conf
/var/www/html
/xlxd
/usr/src/xlxd
/usr/src/XLXEcho
/usr/src/XLX_Dark_Dashboard
```

Recommended maintenance rule:

```text
DIAGNOSE → BACKUP → CHANGE → VALIDATE → ROLLBACK
```

---

# 🔍 Diagnostics and troubleshooting

## Check main services

```bash
sudo systemctl status xlxd.service --no-pager
sudo systemctl status apache2.service --no-pager
sudo systemctl status xlxecho.service --no-pager
```

## Check if services are active

```bash
systemctl is-active xlxd
systemctl is-active apache2
systemctl is-active xlxecho
```

## Recent XLXD logs

```bash
sudo journalctl -u xlxd.service -n 100 --no-pager
```

## Follow XLXD logs in real time

```bash
sudo journalctl -u xlxd.service -f
```

## Validate Apache configuration

```bash
sudo apache2ctl configtest
```

## Inspect XLXD service definition

```bash
sudo systemctl cat xlxd.service
```

## Show listening TCP/UDP ports

```bash
sudo ss -lntup
```

## Show the XLXD process

```bash
ps aux | grep '[x]lxd'
```

---

# 🚨 XLX reflector not starting: quick checklist

1. check `systemctl status xlxd`;
2. check `journalctl -u xlxd -n 100`;
3. inspect `ExecStart` in `xlxd.service`;
4. confirm `/xlxd/xlxd` exists;
5. verify the IP configured for the service;
6. verify firewall and required ports;
7. verify configuration files;
8. verify permissions;
9. validate Apache independently;
10. create a backup before the first corrective change.

---

# 📂 Important locations

| Purpose | Path |
|---|---|
| Controlled installer | `/opt/xlx-modern-installer` |
| XLXD core | `/xlxd/` |
| Local project source | `/usr/src/XLX-Modern-Installer` |
| Preventive backups | `/var/backups/xlx-reflector` |
| Installer logs | `/var/log/xlx-reflector/installer` |
| Modern dashboard | `/var/www/html/xlx-dashboard` |

---

# 🧱 Project structure

```text
XLX-Modern-Installer/
├── install.sh
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

# ❓ Frequently asked questions

## How do I install XLX on Debian 12?

Clone this repository, run `sudo bash install.sh --check`, and if validation succeeds, run `sudo bash install.sh`.

## How do I install a D-STAR, DMR and C4FM/YSF reflector?

XLX is multi-protocol. The installer uses the XLXD base and prepares the reflector deployment for the protocols supported by the reviewed project base.

## How do I reinstall only the XLX dashboard?

```bash
sudo bash modules/60-dashboard-modern.sh
```

## How do I update XLX Modern Installer?

```bash
cd /usr/src/XLX-Modern-Installer
git pull --ff-only
sudo bash install.sh --check
```

## Can I run `install.sh` over a working XLXD server?

No. The installer intentionally blocks that situation to protect the existing production installation.

## How do I troubleshoot an XLX server that stopped working?

Start with systemd status, journal logs, service configuration, ports, IP, firewall and the XLXD binary before attempting a reinstall.

## Where are backups stored?

By default, under `/var/backups/xlx-reflector`.

---

# 🔎 Related search terms

XLX reflector installer, install XLX reflector Debian 12, install XLXD VPS, D-STAR reflector server, DMR reflector server, C4FM YSF reflector, XLX dashboard, update XLX reflector, reinstall XLX dashboard, recover XLXD server, amateur radio digital reflector.

---

# 🤝 Credits

- **XLX / XLXD:** original XLX community / LX3JL project;
- **installer technical base:** Daniel K. — **PP5PK**;
- **related concepts and components:** N5AMD, Narspt and the authors of components actually used by the project;
- **modified version and maintenance:** **Dario — PU2PNY**.

This project preserves credit for its technical base while adding its own controlled installation, documentation, dashboard and maintenance layer.

---

## 🇧🇷 Português

For the complete Portuguese version, open **[README.md](README.md)**.
