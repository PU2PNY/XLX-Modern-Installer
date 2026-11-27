#!/usr/bin/env bash
# Rebuild the production-reference core in a new checkout, without installation.
set -Eeuo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $# == 1 || $# == 2 ]] || { printf 'Usage: %s NEW_CHECKOUT [generic|xlx026]\n' "$0" >&2; exit 2; }
[[ $EUID != 0 ]] || { echo 'Run as an unprivileged user on Debian 12.' >&2; exit 77; }
checkout="$1"
profile="${2:-generic}"
case "$profile" in generic|xlx026) ;; *) echo "Unknown XLXD profile: $profile" >&2; exit 2 ;; esac
[[ ! -e "$checkout" && ! -L "$checkout" ]] || { echo 'Checkout path already exists.' >&2; exit 2; }

git clone --no-checkout https://github.com/PP5PK/xlxd.git "$checkout"
git -C "$checkout" checkout --quiet --detach e69f2dcdd9cf004d5ad199f85c27f1fa1e7e5004
bash "$root/experimental/ysf-vw/apply-and-build.sh" "$checkout" "$profile"
