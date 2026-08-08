# XLX post-installation: YSF, HTTPS, validation and optional tasks

[🇧🇷 Versão em Português](POS-INSTALACAO-XLX.pt-BR.md) • [Back to documentation index](README.md)

After installing XLX on Debian 12, additional steps may be needed depending on the protocols and services you selected. This guide collects useful optional tasks without assuming that every reflector uses the same architecture.

## 1. Validate the main services

```bash
sudo systemctl status xlxd.service --no-pager
sudo systemctl status apache2.service --no-pager
```

If XLXEcho is installed:

```bash
sudo systemctl status xlxecho.service --no-pager
```

## 2. Validate Apache

```bash
sudo apache2ctl configtest
```

## 3. Check listening ports

```bash
sudo ss -lntup
```

Compare the result with the protocols that are actually enabled. See [XLX firewall ports](XLX-FIREWALL-PORTS.en.md).

## 4. Configure HTTPS manually

If the installer did not configure HTTPS automatically:

1. confirm that DNS resolves to the correct public IP;
2. confirm TCP 80 and 443 through firewall/NAT;
3. validate Apache;
4. use the official [Certbot](https://certbot.eff.org/) instructions.

Before running Certbot:

```bash
getent hosts your-domain.example
sudo apache2ctl configtest
sudo ss -lntp | grep -E ':(80|443)\b'
```

## 5. YSF publication/registration

If your installation provides a YSF service that should be listed in compatible directories, see:

- [DVRef](https://dvref.com/)

Confirm that the registration type matches your XLX/YSF architecture. Not every XLX deployment needs the same registration.

## 6. XLXEcho / audio test

For echo/parrot operation, see:

- [narspt/XLXEcho](https://github.com/narspt/XLXEcho)

Validate the service afterwards:

```bash
systemctl is-active xlxecho
sudo systemctl status xlxecho.service --no-pager
```

## 7. Choose the dashboard language

XLX Modern Dashboard can be installed in:

```text
pt-BR  en  es  fr  de  it
```

English example:

```bash
sudo bash modules/60-dashboard-modern.sh --lang=en
```

Spanish example:

```bash
sudo bash modules/60-dashboard-modern.sh --lang=es
```

For a full installation:

```bash
sudo bash install.sh --lang=en
```

## 8. Create a validated post-install backup

After the reflector has been tested, create a backup according to your local policy. Preserve especially:

```text
/xlxd/
/etc/systemd/system/xlxd.service
/etc/systemd/system/xlxecho.service
/etc/apache2/
/var/www/html/
```

## 9. Document the deployment

Record:

- reflector identifier;
- domain;
- public IP;
- enabled modules;
- enabled protocols;
- ports in use;
- optional services;
- installer version/commit;
- date of the latest validated backup.

Do not publish passwords, tokens, private keys or real user databases.

## 10. Final quick check

```bash
systemctl is-active xlxd
systemctl is-active apache2
sudo apache2ctl configtest
sudo ss -lntup
```

## Related documentation

- [Install XLX on Debian 12](INSTALL-XLX-DEBIAN-12.en.md)
- [Update and recover XLX](UPDATE-RECOVER-XLX.en.md)
- [Firewall and ports](XLX-FIREWALL-PORTS.en.md)
- [Files and logs](XLX-FILES-LOGS.en.md)
- [Dashboard internationalization](INTERNATIONALIZATION.md)

## Related search terms

XLX post installation, register YSF reflector, configure XLX HTTPS, Certbot XLX, XLXEcho, XLX parrot, update XLX dashboard, XLX dashboard language, Debian 12 amateur radio reflector.
