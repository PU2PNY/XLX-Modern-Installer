# PP5PK installer base pin

The XLX core installation phase in this project is intentionally based on the upstream installer maintained by **Daniel K. — PP5PK**.

Reviewed upstream repository:

```text
https://github.com/PP5PK/XLX_Installer
```

Reviewed upstream commit:

```text
20b48934505b1939317bf71b30ddc32b1ced0035
```

At that commit, `installer.sh` has Git blob SHA:

```text
266217ee910742710b9c5c9f30009c8a0f0fcaf7
```

The vendored `vendor/pp5pk-installer/installer.sh` is byte-identical to that reviewed upstream blob. Its SHA-256 is pinned by the root `install.sh` and verified by `tests/test-vendored-installer.sh` before release.

The Modern wrapper keeps the upstream XLXD core build, module/YSF configuration, systemd service setup, terminal-options configuration and optional XLX Echo path. It deliberately suppresses the upstream legacy dashboard/Apache/SSL/user-database presentation layer at runtime and replaces those responsibilities with the audited Modern components:

- `dashboard/install/install-dashboard.sh` — modern dashboard, Apache, HTTPS and CallingHome;
- `modules/64-runtime-data.sh` — RadioID database, daily refresh timer and TX/RX log bridge;
- `modules/69-admin-page.sh` — hidden private Admin;
- `modules/67-aprs-dprs.sh` — optional APRS/D-PRS;
- `modules/66-certificates.sh` — optional certificates.

This pin is a compatibility baseline, not an instruction to copy future upstream changes automatically. Any later upstream change must be reviewed, diffed, tested and repinned explicitly before entering the public installer.
