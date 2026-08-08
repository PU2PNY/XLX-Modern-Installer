# Where XLX files and logs are stored on Debian 12

[🇧🇷 Versão em Português](ARQUIVOS-LOGS-XLX.pt-BR.md) • [Back to documentation index](README.md)

This guide lists the main locations used by an XLX installation to make **backup, troubleshooting, updating and recovery** easier.

## Main directories and files

| Purpose | Typical path |
|---|---|
| XLXD core | `/xlxd/` |
| XLXD binary | `/xlxd/xlxd` |
| User database/files | `/xlxd/users_db/` |
| Calling Home | `/xlxd/callinghome.php` |
| Whitelist | `/xlxd/xlxd.whitelist` |
| Blacklist | `/xlxd/xlxd.blacklist` |
| Interlinks | `/xlxd/xlxd.interlink` |
| Terminal definitions | `/xlxd/xlxd.terminal` |
| XLXD systemd service | `/etc/systemd/system/xlxd.service` |
| XLXEcho service | `/etc/systemd/system/xlxecho.service` |
| Apache configuration | `/etc/apache2/` |
| Web content | `/var/www/html/` |
| Modern dashboard | `/var/www/html/xlx-dashboard/` |
| Local project repository | `/usr/src/XLX-Modern-Installer/` |
| Controlled wrapper area | `/opt/xlx-modern-installer/` |
| Preventive backups | `/var/backups/xlx-reflector/` |
| Installer logs | `/var/log/xlx-reflector/installer/` |

Some paths can vary depending on the upstream base, local customization or installed version.

## Find XLX-related files

```bash
sudo find /xlxd /usr/src /var/www/html /etc/systemd/system -maxdepth 3 \
  \( -iname '*xlx*' -o -iname '*dstar*' \) -print 2>/dev/null
```

## Inspect the actual XLXD service

```bash
sudo systemctl cat xlxd.service
```

This is important because it shows the `ExecStart` command that systemd is actually using.

## Service status

```bash
sudo systemctl status xlxd.service --no-pager
```

## Recent logs

```bash
sudo journalctl -u xlxd.service -n 100 --no-pager
```

## Live logs

```bash
sudo journalctl -u xlxd.service -f
```

## Search for log files

```bash
sudo find /var/log /xlxd -maxdepth 3 -type f \
  \( -iname '*xlx*.log' -o -iname '*xlxd*.log' -o -iname '*.xml' \) \
  -print 2>/dev/null
```

## Files to preserve before a repair

Back up at least every path below that actually exists on the server:

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

## Validate the dashboard

```bash
sudo find /var/www/html/xlx-dashboard -type f -name '*.php' -print0 \
  | xargs -0 -r -n1 php -l
```

## Validate Apache

```bash
sudo apache2ctl configtest
sudo systemctl status apache2.service --no-pager
```

## Check ports and processes

```bash
sudo ss -lntup
ps aux | grep '[x]lxd'
```

## Recommended troubleshooting order

```text
FILES → SYSTEMD SERVICE → LOGS → PROCESS → PORTS → APACHE/DASHBOARD → MINIMAL FIX
```

## Related documentation

- [Install XLX on Debian 12](INSTALL-XLX-DEBIAN-12.en.md)
- [Update and recover XLX](UPDATE-RECOVER-XLX.en.md)
- [Firewall and ports](XLX-FIREWALL-PORTS.en.md)
- [Post-installation tasks](XLX-POST-INSTALL.en.md)

## Related search terms

XLX files, XLXD logs, xlxd.service location, XLX backup, callinghome.php XLX, XLX whitelist, XLX blacklist, recover XLX reflector, Debian 12 XLXD logs.
