# SoftAMBE PP5PK — LAB-only compatibility study

**Status of this script: LAB-only, no installation. PROD state changed independently by explicit operator authorization on 2026-11-03; see [PRODUCTION-20261103.md](PRODUCTION-20261103.md).**
Source decision: [Issue #92](https://github.com/PU2PNY/XLX-Modern-Installer/issues/92).
The authoritative installer remains start.sh / install.sh. Nothing in this directory changes XLXD, xuvd, Helix, Nginx, PHP-FPM, the dashboard, APRS, CallHome or any running systemd service.

## 1. Pinned provenance (DOC, 2026-11-03)

| Source | Exact commit | Purpose |
| --- | --- | --- |
| [PP5PK/XLX-SoftAMBE_Installer](https://github.com/PP5PK/XLX-SoftAMBE_Installer) | eff797298744f3b2e1db7bb5b9424db18a03827b | Complete installer + SoftAMBE patch |
| [PP5PK/xlxd](https://github.com/PP5PK/xlxd) | f10f91bdc5c19ad5b435d96a6595f945403e093a | XLXD source used for isolated build |
| [Our XLX Modern Installer](https://github.com/PU2PNY/XLX-Modern-Installer) | 55732025a7649dd131234542be4b1d113f17e889 | Comparison baseline |

SoftAMBE patch Git blob: **dca3f9015edf017458f192b744c5b78889769258**. The reviewed patch is about 563 kB, changes 65 files and adds about 14,892 lines, mostly software vocoder code derived from DroidStar, mbelib/OP25 and IMBE implementations.

The same PP5PK/xlxd project serves as the base, but the XLXD binary used in production is not identical by implication: our core has separate YSF VW, turn-guard/TOT and operational customizations. Compare actual binaries, hashes and code before any future change.

## 2. Actual codec capabilities

| Flow | Existing XLX026 | PP5PK SoftAMBE candidate |
| --- | --- | --- |
| D-STAR AMBE to DMR/YSF DN AMBE+2 | Software transcoding via xuvd | Software transcoding via ambed |
| DMR/YSF DN AMBE+2 to D-STAR AMBE | Software transcoding via xuvd | Software transcoding via ambed |
| **DMR to YSF DN and YSF DN to DMR** | Same AMBE+2 codec, frame adaptation (not a PCM EQ path) | **NO separate DMR↔YSF EQ or gain** |
| YSF VW ↔ native YSF VW | Optional native transport already documented | No crossmode VW to DMR support |
| Helix | Shadow observer on xuvd | Integration not demonstrated |

The SoftAMBE audio controls are named by **the D-STAR↔DMR/YSF destination codec**, not by a DMR↔YSF conversion direction. No software change in this candidate can be claimed to resolve [DMR↔YSF audio Issue #91](https://github.com/PU2PNY/XLX-Modern-Installer/issues/91) without separate evidence.

### Upstream audio configuration (not applied here)

- Gain: AMBED_SOFT_GAIN_DSTAR_TO_DMR=-20, AMBED_SOFT_GAIN_DMR_TO_DSTAR=19.
- EQ: AMBED_SOFT_EQ_DSTAR_TO_DMR=0, AMBED_SOFT_EQ_DMR_TO_DSTAR=0; **off by default**.
- Gate: AMBED_SOFT_GATE_DSTAR_TO_DMR=0, AMBED_SOFT_GATE_DMR_TO_DSTAR=-50.
- EQ shape: LOWCUT_HZ=250, PEAK_HZ=1800; software pairs may be configured from 1 to 16.

The upstream claims approximately 3 ms per 20 ms audio frame and ~8% of one core per stream, but those are **upstream measurements only**. No such benchmark was recorded in our environment.

## 3. Integration hazards; do not run the upstream installer on XLX026

1. **Control port collision**: ambed/main.h uses UDP 10100; our experimental/helix-bridge/xuvd.cpp also binds 127.0.0.1:10100. Only one may own that endpoint.
2. **Incompatible web stack**: upstream installer deploys Apache/certbot --apache; our production standard is Nginx + PHP-FPM.
3. **Destructive broad install**: upstream installer builds and overwrites XLXD, unit files, permissions, the dashboard and web configuration. It is not an additive transcoder package.
4. **Service coupling**: upstream ambed.service has BindsTo=xlxd.service, Before=xlxd.service, User=root and Restart=always. It is not a fail-open isolated replacement for xuvd.
5. **Code mismatch risk**: Git patch applicability to pristine PP5PK/xlxd does not prove applicability to our customized production core.
6. **Licensing**: the installer repo's root Unlicense does not override GPL and other copyrights included in its large third-party patch. Verify each embedded source license and applicable AMBE/AMBE+2 patent implications before redistributing or enabling; this document is not a legal opinion.

## 4. Non-destructive evaluation

Run inside a checkout of our installer:

1. Read-only, offline inventory: **bash experimental/softambe/lab-verify.sh --plan**
2. On an **idle isolated LAB host only**, as a normal NON-root user: **bash experimental/softambe/lab-verify.sh --build**
3. Local contract verification without network: **bash tests/test-softambe-lab-only.sh**

The explicit --build mode clones and checks out the two pinned source commits; confirms the Git blob SHA of the patch; executes git apply --check; patches the **temporary checkout only** and compiles the isolated ambed with make NO_FTDI=1. It cleans the temp directory on exit. It does not install software, change services, run a daemon, bind UDP 10100 or alter the live XLXD. It requires GitHub connectivity, git, make, C++ and normal compiler dependencies. Refuses root, host xlx026 and already-running radio services. --plan has no network access requirement.

A successful build would prove **only compilation in that environment**, not audio quality, codec correctness, installation, rollback or production readiness.

## 5. Remaining promotion gates

- Restore the WartyWallaby lab (or obtain a fresh disposable Debian 12 x86_64 environment).
- Build against the pinned PP5PK source, verify patch applicability and audit licensing. Log hashes and failures without copying secrets.
- Design an **exclusive alternative process**, with disabled-by-default selection and a tested rollback, if justified by benchmarks. Preserve xuvd as the preferred known-good fallback and never share its UDP 10100 endpoint.
- A/B test xuvd vs SoftAMBE on identical codec corpora in D-STAR→DMR, DMR→D-STAR, D-STAR→YSF DN and YSF DN→D-STAR, 1/2/4 parallel streams, CPU, RAM, latency p95/p99, jitter, clipping, intelligibility and voice quality.
- Independently test unmodified DMR↔YSF DN, D-STAR, native YSF VW, interlinks, CallHome, Echo, 180 s TOT, TX turn guard, dashboard Live and identities.
- Before any production proposal: verified backups **and actual restore test**, HW audio check, controlled canary, explicit acceptance and rollback.
- Do not interpret the 2026-11-03 SentinelX connection loss for the WartyWallaby or production agent as proof of service failure.

**Evidence on 2026-11-03:** initial DOC/SW LAB study followed by a separately authorized production switch, verified backup and real transcoder rollback, isolated software build and short PROD health check. ENV on WartyWallaby and RF/HW A/B remain pending. See PRODUCTION-20261103.md for exact evidence; CI is not HW or PROD validation.

## Source references

- [PP5PK SoftAMBE installer README](https://github.com/PP5PK/XLX-SoftAMBE_Installer/blob/eff797298744f3b2e1db7bb5b9424db18a03827b/README.md)
- [PP5PK source patch](https://github.com/PP5PK/XLX-SoftAMBE_Installer/blob/eff797298744f3b2e1db7bb5b9424db18a03827b/patches/xlxd-ambed-softambe.patch)
- [PP5PK config template](https://github.com/PP5PK/XLX-SoftAMBE_Installer/blob/eff797298744f3b2e1db7bb5b9424db18a03827b/templates/ambed.conf)
- [PP5PK systemd unit](https://github.com/PP5PK/xlxd/blob/f10f91bdc5c19ad5b435d96a6595f945403e093a/scripts/ambed.service)
- [DroidStar upstream vocoder](https://github.com/nostar/DroidStar)
- [Our xuvd/Helix source](https://github.com/PU2PNY/XLX-Modern-Installer/blob/main/experimental/helix-bridge/xuvd.cpp)
