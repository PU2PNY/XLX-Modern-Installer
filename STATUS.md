# Project Status

## Current baseline

- Declared version: **1.4.6**.
- Authoritative web stack: **Nginx + PHP-FPM**.
- XLX026 production baseline reported healthy by the operator on 2026-09-21 remains protected.
- Dashboard performance/low-consumption hotfix dated 2026-09-22 is being validated on branch `fix/performance-low-consumption-20260922`.
- The hotfix changes dashboard/runtime/monitoring efficiency only; it does not change XLXD core, protocol ports, transcoder/audio or radio routing.

## Evidence for the 2026-09-22 hotfix

- **PROD:** XLX026 Nginx, PHP-FPM, XLXD, Health Monitor and APRS/D-PRS were active after deployment.
- **PROD:** principal public routes returned HTTP 200 during smoke validation.
- **PROD:** the APRS internal runtime read moved from the full status payload to the compact runtime endpoint.
- **SW:** JavaScript/PHP/Python syntax checks used by the hotfix passed before publication.
- **Pending evidence:** long-duration browser soak on the operator workstation and CI/PR validation of the canonical generic implementation.

## Repository documentation gap

The expected `PROJECT_START_HERE.md`, `PROJECT_MASTER_SPEC.md`, `PROJECT_RELEASE_STATUS.md` and `PROJECT_TEST_MATRIX.md` files were not present on `main` when this incident began. This status file records the fact; it does not invent their contents.
