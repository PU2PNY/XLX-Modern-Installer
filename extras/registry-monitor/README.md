# XLX Registry Monitor

Read-only health and registry monitor for XLXD/YSF servers.

## Goals

- verify that the XLXD systemd service is active;
- resolve the configured reflector FQDN;
- perform a local YSF `YSFS` status request on the configured UDP port;
- retrieve the operator-owned YSF record from the authenticated DVRef API;
- verify whether the YSF designator is currently present in the DVRef public reflector list;
- write one atomic machine-readable JSON status file for dashboards, alerts, or other local tooling.

The monitor **does not** modify XLXD, firewall rules, DNS, DVRef records, or hostfiles. It **does not trigger DVRef validation probes**.

## Why validation is not automated

DVRef validation is an active external operation and is rate-limited. The monitor deliberately separates continuous observation from manual validation. A failed listing should first preserve evidence and alert the administrator rather than repeatedly issuing validation requests.

## Supported languages

The standalone installer currently provides installation prompts in:

- `pt-BR` — Português (Brasil)
- `en` — English
- `es` — Español
- `fr` — Français
- `de` — Deutsch
- `it` — Italiano

The runtime status is language-neutral JSON so any dashboard can translate it independently.

## Standalone installation

From the XLX Modern Installer repository:

```bash
sudo bash modules/67-registry-monitor.sh --check
sudo bash modules/67-registry-monitor.sh
```

Non-default language example:

```bash
sudo bash modules/67-registry-monitor.sh --lang=en
```

Pre-filled identity example:

```bash
sudo bash modules/67-registry-monitor.sh \
  --lang=en \
  --domain=reflector.example.net \
  --ysf-id=12345 \
  --slug=ysf-12345-example
```

The DVRef token is entered with terminal echo disabled. It is stored outside the web root in:

```text
/etc/xlx-registry-monitor/credentials
```

The service runs under the dedicated unprivileged account `xlxmonitor`.

## Files installed

```text
/etc/xlx-registry-monitor/config.ini
/etc/xlx-registry-monitor/credentials
/usr/local/lib/xlx-registry-monitor/xlx_registry_monitor.py
/var/lib/xlx-registry-monitor/status.json
/etc/systemd/system/xlx-registry-monitor.service
/etc/systemd/system/xlx-registry-monitor.timer
```

## Schedule

The systemd timer runs every 15 minutes with a small randomized delay. This is intentionally conservative compared with DVRef's published API limits.

## Status JSON

Example:

```json
{
  "overall": "warning",
  "local": {
    "ok": true,
    "state": "active"
  },
  "dns": {
    "ok": true,
    "ipv4": ["192.0.2.10"],
    "ipv6": []
  },
  "ysf": {
    "ok": true,
    "bytes": 42
  },
  "registry": {
    "enabled": true,
    "ok": true,
    "public_present": false
  }
}
```

`overall` values:

- `ok`: local XLXD/YSF/DNS are healthy and the designator is in the public registry list;
- `warning`: the local reflector is healthy but the registry check reports a problem or the designator is absent from the public list;
- `critical`: a local prerequisite such as XLXD, DNS, or YSF status response failed.

The process exits successfully after producing the JSON even when the reflector health is `warning` or `critical`. Health state belongs in the status data; a non-zero systemd exit is reserved for monitor execution failures.

## Security model

- no token is embedded in GitHub, JavaScript, PHP, or the status JSON;
- credentials are installed with group-readable permissions only for `xlxmonitor`;
- the systemd service uses `NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome=true`, `PrivateTmp=true`, and a restricted writable path;
- runtime uses only Python's standard library;
- no raw packet capture is part of the scheduled service;
- no automatic POST/PUT/PATCH/DELETE calls are made to DVRef.

## RefCheck hostfiles

RefCheck hostfile integration is intentionally deferred from v0.1.0. RefCheck publishes separate access-token, hourly request, attribution, and redistribution requirements. When implemented, it must cache locally and must never turn this project into an unauthorized hostfile mirror.

## Project status

`v0.1.0` is the first implementation branch. It must pass CI and isolated installation tests before being wired into the default full-server installation flow.
