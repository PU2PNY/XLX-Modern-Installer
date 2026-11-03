#!/usr/bin/env bash
# Offline contract tests. No external network or privileged operations.
set -Eeuo pipefail
root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
script="$root/experimental/softambe/lab-verify.sh"
[[ -f "$script" ]]
bash -n "$script"
plan="$(bash "$script" --plan)"
for expected in \
  'PLAN_ONLY=YES' \
  'BUILDS_OR_STARTS_SERVICE=NO' \
  'SOFTAMBE_SOLVES_DMR_YSF=NO' \
  'CORE_RUNTIME_UNCHANGED=YES' \
  'eff797298744f3b2e1db7bb5b9424db18a03827b' \
  'f10f91bdc5c19ad5b435d96a6595f945403e093a' \
  'dca3f9015edf017458f192b744c5b78889769258'; do
  grep -F "$expected" <<<"$plan" >/dev/null
done
if bash "$script" --not-a-mode >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: unknown mode accepted' >&2
  exit 1
fi
if grep -nE '(^|[[:space:]])(sudo[[:space:]]|systemctl[[:space:]]+(restart|start|enable)|make[[:space:]]+install)' "$script"; then
  printf '%s\n' 'FAIL: privileged install/service mutation detected' >&2
  exit 1
fi
if [[ $EUID -eq 0 ]]; then
  set +e
  bash "$script" --build >/dev/null 2>&1
  result=$?
  set -e
  [[ $result -eq 77 ]] || {
    printf 'FAIL: root build must be refused (code=%s)\n' "$result" >&2
    exit 1
  }
fi
printf '%s\n' 'softambe_lab_only_contract=PASS' 'upstream_network_build=NOT_RUN' 'ENV_AUDIO=NOT_RUN'
