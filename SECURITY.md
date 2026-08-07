# Security Policy

## Scope

This repository installs software that can operate directly on an XLX reflector VPS. Treat changes as infrastructure changes, not only as dashboard/UI changes.

## Never publish

Do not commit or post in issues/pull requests:

- passwords or API tokens;
- SSH private keys;
- private TLS keys or certificates;
- cookies or authenticated sessions;
- production `.env` files;
- user databases or database dumps;
- operational logs containing private data;
- production backups;
- raw XLXD connection-IP caches;
- private Calling Home credentials;
- any secret required to administer a reflector.

The repository `.gitignore` and GitHub Actions checks are additional safeguards; they do not replace manual review.

## Installer safety principles

Production-changing steps should, where applicable:

1. validate prerequisites before changing files;
2. build and validate a staging copy first;
3. create and verify a backup before replacement;
4. validate syntax and service state after publication;
5. preserve the running XLXD service whenever possible;
6. provide a rollback path for persistent changes, including previous systemd timer state;
7. use least privilege for runtime components;
8. avoid exposing internal server data through public APIs.

## Dashboard distribution

The global dashboard deliberately excludes reflector-specific private Support code and country-specific News integrations used during development. Runtime configuration is generated locally as `dashboard/config/site.json` and is not committed.

The developer attribution for **PU2PNY · Página Certa Digital** is intentional public metadata and is isolated in `dashboard/config/developer.php`.

The Ranking V2 SQLite database remains under `/var/lib/xlx-ranking`; only the generated JSON snapshot is read by the public dashboard API.

### Connection and MTR privacy

XLXD connection records can include endpoint IP addresses. The dashboard keeps those values only in a private cache under `/var/cache/xlx-dashboard`, outside the web root. Public status/history/live payloads remove IP fields. The MTR endpoint resolves the target server-side and returns metrics only; it never returns the measured IP address. Gateway labels that are themselves IP addresses are also rejected from public responses.

### External reflector links

Dashboard URLs received from external reflector-directory data are accepted only when the parsed URL uses the `http` or `https` scheme and contains a host. Other URI schemes are discarded before the browser receives them.

## Upstream dependency

The top-level installer uses a reviewed PP5PK/XLX_Installer revision pinned by commit and SHA-256. Any change to the upstream commit or expected hash requires dedicated review before merge.

## Reporting a vulnerability

Do not publish exploitable details involving credentials, remote execution, private data exposure, or service disruption in a public issue. Use an available private GitHub contact/security channel for the repository maintainer and provide only the information required to reproduce the issue safely.
