#!/usr/bin/env bash
# Reproducible isolated SoftAMBE source/build compatibility check.
# LAB-only. Never changes installed XLXD, xuvd, Helix or systemd.
set -Eeuo pipefail

readonly INSTALLER_REPOSITORY='https://github.com/PP5PK/XLX-SoftAMBE_Installer.git'
readonly INSTALLER_COMMIT='eff797298744f3b2e1db7bb5b9424db18a03827b'
readonly XLXD_REPOSITORY='https://github.com/PP5PK/xlxd.git'
readonly XLXD_COMMIT='f10f91bdc5c19ad5b435d96a6595f945403e093a'
readonly PATCH_GIT_BLOB='dca3f9015edf017458f192b744c5b78889769258'

usage() {
  printf '%s\n' 'Usage: lab-verify.sh [--plan | --build]' '' \
    '  --plan  (default) show pinned sources/checks; no network or changes' \
    '  --build clone fixed sources, verify patch, build in temporary directory' \
    '          no installation, no service start, no radio port opened'
}

mode="--plan"
if (($# > 0)); then mode="$1"; fi
if (($# > 1)); then usage >&2; exit 2; fi
case "$mode" in
  --help|-h) usage; exit 0 ;;
  --plan) ;;
  --build) ;;
  *) usage >&2; exit 2 ;;
esac

printf 'SOURCE_INSTALLER=%s@%s\n' "$INSTALLER_REPOSITORY" "$INSTALLER_COMMIT"
printf 'SOURCE_XLXD=%s@%s\n' "$XLXD_REPOSITORY" "$XLXD_COMMIT"
printf 'SOURCE_PATCH_GIT_BLOB=%s\n' "$PATCH_GIT_BLOB"
printf '%s\n' 'SOFTAMBE_SOLVES_DMR_YSF=NO' 'CORE_RUNTIME_UNCHANGED=YES'

if [[ "$mode" == --plan ]]; then
  printf '%s\n' 'PLAN_ONLY=YES' 'BUILDS_OR_STARTS_SERVICE=NO'
  exit 0
fi

if (( EUID == 0 )); then
  printf '%s\n' 'REFUSED: isolated build must run as non-root.' >&2
  exit 77
fi
if [[ "$(hostname -s 2>/dev/null || true)" == xlx026 ]]; then
  printf '%s\n' 'REFUSED: known production host.' >&2
  exit 78
fi
if command -v systemctl >/dev/null 2>&1; then
  if systemctl is-active --quiet xlxd.service 2>/dev/null || \
     systemctl is-active --quiet xlx-unified-voice.service 2>/dev/null; then
    printf '%s\n' 'REFUSED: active radio services; use an idle lab host.' >&2
    exit 78
  fi
fi
for tool in git make c++ mktemp; do
  command -v "$tool" >/dev/null 2>&1 || {
    printf 'MISSING_TOOL=%s\n' "$tool" >&2
    exit 69
  }
done

work="$(mktemp -d "/tmp/xlx-softambe-lab.XXXXXXXX")"
cleanup() {
  if [[ -n "$work" && -d "$work" ]]; then
    rm -r -- "$work"
  fi
}
trap cleanup EXIT

printf 'LAB_TEMP_DIRECTORY=%s\n' "$work"
git clone --quiet "$INSTALLER_REPOSITORY" "$work/installer"
git -C "$work/installer" checkout --quiet --detach "$INSTALLER_COMMIT"
[[ "$(git -C "$work/installer" rev-parse HEAD)" == "$INSTALLER_COMMIT" ]] || {
  printf '%s\n' 'FAIL: upstream installer commit mismatch' >&2; exit 1;
}
patch="$work/installer/patches/xlxd-ambed-softambe.patch"
[[ -f "$patch" ]] || { printf '%s\n' 'FAIL: SoftAMBE patch absent' >&2; exit 1; }
[[ "$(git -C "$work/installer" hash-object "$patch")" == "$PATCH_GIT_BLOB" ]] || {
  printf '%s\n' 'FAIL: SoftAMBE patch differs from pinned Git blob' >&2; exit 1;
}

git clone --quiet "$XLXD_REPOSITORY" "$work/xlxd"
git -C "$work/xlxd" checkout --quiet --detach "$XLXD_COMMIT"
[[ "$(git -C "$work/xlxd" rev-parse HEAD)" == "$XLXD_COMMIT" ]] || {
  printf '%s\n' 'FAIL: XLXD source commit mismatch' >&2; exit 1;
}
git -C "$work/xlxd" apply --check --whitespace=nowarn "$patch"
printf '%s\n' 'PATCH_APPLY_CHECK=PASS'
git -C "$work/xlxd" apply --whitespace=nowarn "$patch"
[[ -f "$work/xlxd/ambed/csoftambeinterface.cpp" ]] || {
  printf '%s\n' 'FAIL: software vocoder sources missing after patch' >&2; exit 1;
}

make -C "$work/xlxd/ambed" -j2 NO_FTDI=1
[[ -x "$work/xlxd/ambed/ambed" ]] || {
  printf '%s\n' 'FAIL: expected standalone build artifact absent' >&2; exit 1;
}
printf '%s\n' 'SOFTAMBE_BUILD=PASS' 'SERVICE_STARTED=NO' 'LIVE_AUDIO_TEST=NOT_RUN' 'PRODUCTION_DEPLOY=NO'
