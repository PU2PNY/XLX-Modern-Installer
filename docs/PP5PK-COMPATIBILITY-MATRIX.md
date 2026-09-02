# XLX Modern Installer × PP5PK/XLX_Installer compatibility matrix

Reviewed upstream: `PP5PK/XLX_Installer` commit `20b48934505b1939317bf71b30ddc32b1ced0035`.

The vendored `installer.sh` used by XLX Modern is byte-identical to the reviewed upstream installer. XLX Modern therefore keeps PP5PK as the XLXD core-installation baseline and replaces only the legacy web/data layer with explicit modern components.

| Area | PP5PK baseline | XLX Modern implementation | Release requirement |
|---|---|---|---|
| Platform | Debian-family installer | Debian 12 x86_64 is explicitly preflighted | Must pass before install |
| Reflector ID | 3-character XLX suffix | Same PP5PK input and validation | Required |
| FQDN | Prompt + validation | Same PP5PK input, normalized to lowercase and reused by modern dashboard | Required |
| Sysop e-mail/callsign/country/timezone | PP5PK prompts | Same base inputs, reused in `config/site.php` | Required |
| XLX list comment | PP5PK prompt | Same base input, reused by CallingHome | Required |
| Dashboard title/footer | PP5PK prompts | Same base inputs are captured; modern dashboard renders neutral site identity | Required |
| SSL/HTTPS | PP5PK Certbot path | Legacy dashboard/SSL block is skipped; modern dashboard owns Apache/Certbot | Must validate Apache and certificate when selected |
| Echo Test | Optional PP5PK XLXEcho | Preserved from PP5PK core path | Must validate service when selected |
| Modules | 1–26, minimum 5 when Echo uses E | Preserved in PP5PK build and persisted to modern dashboard config | Must match core/dashboard |
| YSF UDP port | PP5PK configurable | Preserved in PP5PK core build | Required |
| YSF Wires-X frequency | PP5PK configurable | Preserved in PP5PK core build | Required |
| YSF auto-link/module | PP5PK configurable | Preserved in PP5PK core build | Required |
| XLXD compilation | clone/build/install | Preserved from reviewed PP5PK base | Blocking validation |
| `xlxd.service` | systemd unit from XLXD source | Preserved from PP5PK base | Must be active |
| Terminal options | `/xlxd/xlxd.terminal`, public IP + enabled modules | Preserved as a **core configuration file** from PP5PK | Not exposed as a web-Admin command |
| Interlink | `/xlxd/xlxd.interlink` peer list | Preserved by core; private Admin manages native `PEER ADDRESS MODULES` entries safely | Backup, atomic write, validation, no unrelated-line loss |
| Interlink reload | XLXD gatekeeper watches peer-list changes | Admin relies on native automatic reload, normally within ~30 seconds | No restart required for a peer edit |
| Whitelist/blacklist | Native XLXD files | Private Admin adds backup, lock, validation and audit | Required |
| DMR ID file | PP5PK initial download | Core path retained; modern RadioID database layer adds daily refresh and persistence | Required |
| Users database | PP5PK dashboard ships users DB/update timer | Legacy dashboard portion skipped; `modules/64-runtime-data.sh` creates/repairs DB, daily timer and validation | Timer active + SQLite integrity required |
| Local RadioID edits | Upstream terminal User Manager | Modern private Admin supports search/add/edit/delete/check/refresh; local patches survive refresh | Required |
| TX/RX log service | PP5PK `xlx_log.service` | Modern runtime-data installs compatible log bridge/service | Must be active |
| Legacy dashboard | PP5PK XLX Dark Dashboard | Intentionally not installed | Removed by design |
| Modern dashboard | Not in PP5PK | Installed at canonical `/var/www/html/xlxd` | Required |
| Dashboard language | PP5PK dashboard is not six-language Modern UI | `pt-BR`, `en`, `es`, `fr`, `de`, `it` build catalogs | All six CI builds must pass |
| Installer UI language | PP5PK base is English | XLX Modern asks PT-BR/English first; dashboard language is chosen separately | PT/EN flow must remain coherent |
| Admin | Upstream User Manager is terminal based | Hidden private web Admin, PT-BR/English, hashed password, CSRF, rate-limit, restricted sudo | Required |
| Admin route | Not upstream | Configurable hidden slug, default `admin`; absent from public nav/SEO files | Required |
| CallingHome | Legacy dashboard CallingHome | Dedicated root-owned config + systemd timer/client independent of legacy dashboard | Timer active; registration attempted/retried |
| APRS/D-PRS | Not PP5PK base | Optional independent module | Must not be installed unless selected |
| Certificates | Not PP5PK base | Optional independent module | Not part of public default installation |
| Firewall | PP5PK documentation requires ports to be opened by operator/provider | XLX Modern documents/diagnoses; it does not silently rewrite provider or host firewall | Never report external reachability without a real test |
| Existing production | Upstream can invoke uninstaller | XLX Modern blocks full overwrite; `--dashboard-only` preserves existing core | Required safety rule |
| Backup/rollback | Upstream has uninstall/cleanup | XLX Modern adds preventive verified backups and rollback around its own mutable layers | Required |

## Deliberate differences

The following are intentional and must not be “fixed” by copying PP5PK blindly:

1. **Do not restore the PP5PK legacy dashboard.** `/var/www/html/xlxd` belongs to the Modern dashboard.
2. **Do not restore the legacy dashboard's users-db/update block.** The Modern runtime-data module owns that responsibility.
3. **Do not expose a terminal web function.** Native `/xlxd/xlxd.terminal` remains a core config file, but the private Admin exposes only fixed audited actions.
4. **Do not make Certificates part of the public default install.** It is optional.
5. **Do not make APRS/D-PRS mandatory.** It is optional.
6. **Do not require an XLXD restart for an Interlink peer edit.** XLXD monitors and reloads the peer list.
7. **Do not reintroduce `xlxd-novo` or use `xlx-dashboard` as a clean-install default.** The canonical dashboard path is `/var/www/html/xlxd`.

## Acceptance rule

CI validates source integrity, syntax, translations, native Interlink format, sudo privilege boundaries, persistent RadioID behavior and the PP5PK pin. A clean Debian 12 VPS test is still required before claiming real-world D-STAR/DMR/YSF/HTTPS/public-network acceptance, because GitHub CI cannot prove provider firewall, DNS propagation or radio-protocol traffic.
