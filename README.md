# XLX Modern Dashboard

Standalone modern web dashboard for XLX/xlxd reflectors.

This branch contains only the dashboard and its dashboard-specific installation helpers. It is intended to be safe for public distribution and does not contain a private server configuration, credentials, reflector-specific operational data, xlxd source code, CrossMode code, or the full XLX server installer.

## Features

- Live transmissions and connected stations
- XLX reflector list and activity ranking
- Responsive layout
- Accessibility controls
- PWA support
- Dashboard languages: Portuguese (Brazil), English, Spanish, French, German and Italian
- Generic reflector configuration through placeholders and `config/site.php`

## Public configuration model

The repository ships only with the neutral example file:

`config/site.example.php`

Example values use `XLX000`, `N0CALL`, `xlx.example.org` and `sysop@example.org`. A real installation must create its own `config/site.php` locally. That file is ignored by Git and must not be committed.

## Installation

Run the dashboard installer as root on the XLX server:

```bash
sudo bash install/install-dashboard.sh
```

To preselect the dashboard language:

```bash
sudo bash install/install-dashboard.sh --lang=en
```

The installer asks for the reflector identity, display name, sysop callsign, location, country, domain, contact email and YSF ID, then renders the generic placeholders for that server.

## Security and privacy

Before publishing changes, do not commit:

- `config/site.php`
- `.env` files
- passwords, API keys or tokens
- private IP addresses or infrastructure notes
- TLS private keys or certificates
- reflector-specific backups or logs

The files under `config/` already ignore local and secret configuration variants.

## Scope

This dashboard is independent from the xlxd daemon. It reads the normal XLX/xlxd status and log data expected on the server but does not replace or modify the xlxd core.

## License

Use and redistribution must follow the license terms of the repository and any third-party assets included with the dashboard.
