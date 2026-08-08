# How to update, troubleshoot and recover an XLX server

[🇧🇷 Versão em Português](ATUALIZAR-RECUPERAR-XLX.pt-BR.md) • [Back to documentation index](README.md)

This guide covers safe procedures to **update XLX Modern Installer**, update only the dashboard, troubleshoot XLXD failures, and prepare a controlled recovery with backup and rollback.

## Update the repository

```bash
cd /usr/src/XLX-Modern-Installer
git status
git pull --ff-only
```

Then run:

```bash
sudo bash install.sh --check
```

On an already-installed XLXD server, do not run a full installation only because the Git repository was updated.

## Update or reinstall only the dashboard

```bash
cd /usr/src/XLX-Modern-Installer
sudo bash modules/60-dashboard-modern.sh
```

The dashboard has a separate installation routine from the XLXD core and creates a backup when an existing dashboard is found at the destination.

## XLXD diagnostics

### Service status

```bash
sudo systemctl status xlxd.service --no-pager
```

### Recent logs

```bash
sudo journalctl -u xlxd.service -n 100 --no-pager
```

### Live logs

```bash
sudo journalctl -u xlxd.service -f
```

### systemd configuration

```bash
sudo systemctl cat xlxd.service
```

### Listening ports

```bash
sudo ss -lntup
```

### Process

```bash
ps aux | grep '[x]lxd'
```

### Apache

```bash
sudo apache2ctl configtest
sudo systemctl status apache2.service --no-pager
```

## Back up before fixing

Preserve at least:

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

Default project backup directory:

```text
/var/backups/xlx-reflector
```

## Recommended recovery workflow

```text
1. DIAGNOSE
2. INVENTORY
3. VERIFIED BACKUP
4. IDENTIFY ROOT CAUSE
5. MINIMAL CHANGE
6. VALIDATE SERVICES
7. VALIDATE DASHBOARD
8. KEEP ROLLBACK AVAILABLE
```

## When not to reinstall

Avoid a full reinstall when the problem is limited to:

- systemd service configuration;
- incorrect IP address;
- Apache;
- dashboard;
- permissions;
- firewall;
- local configuration;
- one database or file.

Reinstalling without diagnosis can remove evidence that would help identify the original cause.

## XLX server not appearing in the public list

Check first:

1. whether `xlxd.service` is active;
2. the IP used in `ExecStart`;
3. DNS and outbound connectivity;
4. ports and firewall;
5. XLXD logs;
6. Calling Home and environment-specific configuration.

Do not change several possible causes at the same time. Make one change, validate the result, and preserve rollback.

## Related search terms

Update XLX reflector, update XLXD, repair XLX server, recover XLX reflector, XLX not starting, XLX not listed, XLXD backup, reinstall XLX dashboard, XLX Debian 12 troubleshooting.
