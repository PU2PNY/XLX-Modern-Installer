# Callsign directory, user database and certificates

This guide documents the generic operator-data and certificate features included with XLX Modern Installer.

## Callsign directory

The upstream/main XLX user database remains:

```text
/xlxd/users_db/users.db
```

Local corrections are kept separately in:

```text
/var/lib/xlx-user-directory/overrides.db
```

This prevents local fixes from being lost when the main database is rebuilt.

Administration tool:

```bash
sudo xlx-user-directory --help
sudo xlx-user-directory lookup N0CALL
sudo xlx-user-directory set N0CALL "Operator Name" "City, Region"
sudo xlx-user-directory alias OLDCALL NEWCALL
sudo xlx-user-directory delete N0CALL
sudo xlx-user-directory check
sudo xlx-user-directory refresh
```

`refresh` creates a backup of the current main database, validates the backup, runs the XLX database generator, runs SQLite `PRAGMA integrity_check`, and restores the previous database if validation fails.

Backups are stored under:

```text
/var/backups/xlx-reflector/callsign-directory/
```

An alias does not modify the callsign transmitted by a radio. Radio/hotspot programming must still be corrected separately.

## Certificates

The certificate module uses the identity configured for the installed reflector: reflector name/title, domain, country, sysop callsign, timezone and optional anniversary.

User page:

```text
https://YOUR-DOMAIN/certificado.php
```

Validation page:

```text
https://YOUR-DOMAIN/certificado-validar.php?id=...&sig=...
```

A certificate is eligible only when an actual transmission is found in XLX activity for the active campaign period. Existing membership in the user database alone is not enough.

The system enforces one issuance per `campaign + callsign` and stores issuance records in:

```text
/var/lib/xlx-certificates/emissoes.jsonl
```

Each server creates its own private HMAC key:

```text
/etc/xlx-certificates/hmac.key
```

The key must never be committed to GitHub and should be included in private disaster-recovery backups. Existing certificates may no longer validate if the key is lost.

QR codes are generated locally with `qrencode` and point back to the configured reflector domain.

## Automatic campaigns

For all countries:

- daily participation certificate;
- World Amateur Radio Day — April 18;
- reflector anniversary week when an anniversary is configured.

Brazil-only campaigns are enabled only when the reflector country is configured as Brazil:

- Mother's Day;
- Father's Day;
- Brazil Independence Day;
- Brazilian Amateur Radio Day.

A reflector configured in Portugal, Germany, the United States or any other country does not automatically inherit Brazilian campaigns.

## Integrated installation

A normal dashboard install now runs:

```text
Dashboard
  ↓
Dashboard post-install
  ↓
Persistent callsign directory
  ↓
Certificates
```

Command:

```bash
sudo bash modules/60-dashboard-modern.sh
```

A complete fresh installation uses:

```bash
sudo bash install.sh --check
sudo bash install.sh
```

## Persistent data to back up

```text
/var/lib/xlx-user-directory/
/var/lib/xlx-certificates/
/etc/xlx-certificates/
```

Do not publish real user databases, override databases, issuance records, HMAC keys, production logs, backups, passwords or tokens.