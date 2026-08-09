# GitHub About, Website and Topics / Metadados do repositório

Use these values for the public repository metadata.

## About description

```text
Universal XLX reflector installer for Debian 12 with a modern multilingual dashboard, persistent callsign corrections and verifiable participation certificates — D-STAR, DMR and C4FM/YSF.
```

## Website

The project itself is generic and should not be represented as belonging to a single production reflector. Prefer the repository URL or a dedicated future project website.

```text
https://github.com/PU2PNY/XLX-Modern-Installer
```

The real XLX026 deployment may still be cited in screenshots/documentation as a production example, but it should not be the universal project's identity.

## Recommended topics

```text
xlx
xlxd
xlx-reflector
dstar
dmr
c4fm
ysf
ham-radio
amateur-radio
debian
debian12
digital-radio
reflector
xlx-dashboard
xlx-installer
dstar-reflector
dmr-reflector
callsign-database
sqlite
certificate
qr-code
hmac
```

## Why these fields matter

The GitHub **About** block is one of the first pieces of context visitors see. The description should make clear that this is a universal installer rather than the configuration repository of one specific reflector.

The README and documentation now cover:

- clean Debian 12 installation;
- generic reflector identity/configuration;
- dashboard-only installation;
- Ao Vivo, Conectados, Módulos A–E and Ranking;
- six dashboard languages;
- persistent callsign corrections and aliases;
- safe main user-database refresh with backup/integrity check/rollback;
- activity-based participation certificates;
- local QR generation and HMAC validation;
- backup and recovery of the new persistent data.

## Suggested release title

```text
XLX Modern Installer v1.0.0 — Debian 12 XLXD + Universal Dashboard + Callsigns + Certificates
```

Do not publish a release tag until a clean Debian 12 installation has been tested end-to-end in a disposable/homologation VPS, including dashboard, callsign directory, certificate issuance/validation, firewall, HTTPS and recovery backup.
