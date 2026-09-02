# Architecture

## Independence rule

XLX Modern Installer is self-orchestrated. It does not execute, vendor, source, clone or call another reflector installer.

The only external project sources used for reflector functionality are the actual software components that are built or installed directly:

- XLXD core: `LX3JL/xlxd`, pinned by `modules/40-xlxd.sh`;
- optional Echo/Parrot: `narspt/XLXEcho`, pinned by `modules/50-echo.sh`;
- Debian packages installed through APT.

The Modern Dashboard is shipped in this repository and installed locally. It is never cloned from an external dashboard repository.

## Clean-install execution flow

1. Select installer language: Portuguese (Brazil) or English.
2. Select public dashboard language: `pt-BR`, `en`, `es`, `fr`, `de` or `it`.
3. Validate root, Debian 12 x86_64, resources, DNS and HTTPS access.
4. Detect active XLX installations and refuse an unsafe full overwrite.
5. Collect reflector identity, modules, YSF and optional Echo/HTTPS choices.
6. Create and verify a preventive backup of existing relevant paths.
7. Require the explicit confirmation word `INSTALL`.
8. Install required Debian packages through `modules/30-packages.sh`.
9. Fetch the pinned XLXD source, patch only the required build constants, compile and install through `modules/40-xlxd.sh`.
10. Install the repository-owned `xlxd.service` and validate the core process/listeners.
11. Install optional Echo independently through `modules/50-echo.sh`.
12. Install the local XLX Modern Dashboard at `/var/www/html/xlxd`.
13. Configure Apache and optional HTTPS.
14. Install runtime RadioID data, daily update timer and TX/RX log bridge.
15. Install dedicated CallingHome and its timer.
16. Install the hidden private Admin and restricted helpers.
17. Optionally install APRS/D-PRS.
18. Run final service, listener, database, Admin and local HTTP/HTTPS validation.

## Main modules

- `install.sh` — top-level orchestration and interactive configuration.
- `modules/30-packages.sh` — dependencies.
- `modules/40-xlxd.sh` — independent XLXD source/build/systemd installation.
- `modules/50-echo.sh` — independent optional XLXEcho installation.
- `modules/60-dashboard-modern.sh` — Modern Dashboard integration.
- `modules/64-runtime-data.sh` — RadioID database, refresh timer and log bridge.
- `modules/69-admin-page.sh` — hidden Admin installation/upgrade.
- `modules/67-aprs-dprs.sh` — optional APRS/D-PRS.
- `dashboard/install/install-dashboard.sh` — dashboard rendering, Apache, HTTPS and CallingHome.

## Canonical paths

- Core runtime: `/xlxd`
- XLXD source: `/usr/src/xlxd`
- Optional Echo source: `/usr/src/XLXEcho`
- Dashboard: `/var/www/html/xlxd`
- Modern control configuration: `/etc/xlx-modern-control`
- CallingHome configuration: `/etc/xlx-modern`
- Backups: `/var/backups/xlx-reflector`

Retired webroots such as `/var/www/html/xlxd-novo` and `/var/www/html/xlx-dashboard` are not valid clean-install targets.

## Update safety

`--dashboard-only` preserves an existing XLXD core. Full installation refuses to overwrite an active XLXD. Mutable Modern-layer operations use backup and validation, and critical configuration writers use atomic replacement/rollback where possible.
