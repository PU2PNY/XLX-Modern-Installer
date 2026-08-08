# How to install an XLX reflector on Debian 12

[🇧🇷 Versão em Português](INSTALACAO-XLX-DEBIAN-12.pt-BR.md) • [Back to documentation index](README.md)

This guide explains how to install an **XLX multi-protocol reflector** on Debian 12 using **XLX Modern Installer**. It is intended for a new deployment on a clean VPS or server.

## What the installation prepares

The installer prepares an XLXD-based reflector environment for the protocols supported by the project base, including D-STAR, DMR and C4FM/YSF, plus the modern dashboard and optional auxiliary services where applicable.

## Requirements

- Debian 12;
- x86_64 architecture;
- root or sudo access;
- internet access;
- DNS/FQDN for production use;
- a suitable public IP for the environment;
- at least 768 MB RAM;
- at least 4 GB free disk space.

## 1. Update Debian and install Git

```bash
sudo apt update
sudo apt install -y git
```

## 2. Clone the installer

```bash
cd /usr/src
sudo git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
```

## 3. Run pre-flight validation

```bash
sudo bash install.sh --check
```

Pre-flight validation checks the operating system, architecture, memory, disk space, DNS, HTTPS access, required tools and whether an active XLX installation already exists.

## 4. Run the full installation

```bash
sudo bash install.sh
```

The real installation requires explicit confirmation and creates a preventive backup when relevant paths exist.

## 5. Verify services after installation

```bash
systemctl is-active xlxd
systemctl is-active apache2
systemctl is-active xlxecho
```

For more detail:

```bash
sudo systemctl status xlxd.service --no-pager
sudo journalctl -u xlxd.service -n 100 --no-pager
```

## Install or reinstall only the dashboard

If XLXD is already running and you only want to install or reinstall the modern dashboard:

```bash
cd /usr/src/XLX-Modern-Installer
sudo bash modules/60-dashboard-modern.sh
```

Do not use `install.sh` to overwrite an active XLXD server.

## Verify that the server is responding

```bash
sudo ss -lntup
sudo systemctl cat xlxd.service
sudo apache2ctl configtest
```

## Common troubleshooting checks

Before reinstalling anything, verify:

1. `systemctl status xlxd`;
2. `journalctl -u xlxd -n 100`;
3. the IP configured in the service;
4. firewall and ports;
5. existence of `/xlxd/xlxd`;
6. permissions and local configuration;
7. Apache and dashboard independently.

## Next steps

After installation, read [How to update, troubleshoot and recover an XLX server](UPDATE-RECOVER-XLX.en.md).

## Related search terms

Install XLX reflector Debian 12, install XLXD VPS, D-STAR reflector server, DMR reflector server, C4FM YSF reflector, amateur radio digital reflector, XLX dashboard, XLX reflector installer.
