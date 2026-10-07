#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DASH="${XLX_DASHBOARD_DIR:-/var/www/html/xlxd}"
LANGUAGE="${XLX_UI_LANG:-pt-BR}"
say(){ [[ "$LANGUAGE" == en ]] && printf '%s\n' "$2" || printf '%s\n' "$1"; }
DOMAIN="$(php -r '$c=require $argv[1]; echo $c["reflector"]["domain"]??"";' "$DASH/config/site.php")"
[[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]] || { echo 'ERROR: invalid domain' >&2; exit 2; }
say 'Compilando o motor Ao Vivo com fontes fixadas; o XLXD permanece ativo.' 'Building the pinned Live engine; XLXD remains active.'
# `file` is required by modules/71-observability.sh to validate the shipped
# protocol helper architecture. Minimal Debian 12 images do not guarantee it.
apt-get install -y -qq nodejs mtr-tiny build-essential pkg-config curl ca-certificates file >/dev/null
# Install a dedicated toolchain outside HOME. cargo/rustc from Debian 12 are
# too old for the exact production-proven Axum/Tokio dependency lock.
export RUSTUP_HOME=/opt/xlx-modern-rustup CARGO_HOME=/opt/xlx-modern-cargo
if [[ ! -x "$CARGO_HOME/bin/cargo" ]]; then
  installer="$(mktemp)"
  curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 https://sh.rustup.rs -o "$installer"
  sh "$installer" -y --no-modify-path --profile minimal --default-toolchain 1.90.0
  rm -f "$installer"
fi
export PATH="$CARGO_HOME/bin:$PATH"
rustup toolchain install 1.90.0 --profile minimal
BUILD="$(mktemp -d /opt/xlx-modern-live-build.XXXXXX)"
trap 'rm -rf "$BUILD"' EXIT
cp -a "$ROOT/runtime/live-core/." "$BUILD/"
cargo +1.90.0 build --manifest-path "$BUILD/Cargo.toml" --locked --release --jobs 1
install -m 0755 "$BUILD/target/release/xlx-modern-live-core" /usr/local/bin/xlx-modern-live-core
install -d -m 0755 /usr/local/lib/xlx-modern/live-hub /etc/xlx-modern-live
install -d -m 0750 -o www-data -g www-data /var/cache/xlx-dashboard
install -m 0644 "$ROOT/runtime/live-hub/server.js" "$ROOT/runtime/live-hub/tx-turn-state.js" /usr/local/lib/xlx-modern/live-hub/
node --check /usr/local/lib/xlx-modern/live-hub/server.js
SCHEME=http; PORT=80
if [[ -s "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" && -s "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]]; then SCHEME=https; PORT=443; fi
cat >/etc/xlx-modern-live/hub.env <<ENV
XLX_LIVE_SOURCE_SCHEME=$SCHEME
XLX_LIVE_SOURCE_HOST=127.0.0.1
XLX_LIVE_SOURCE_PORT=$PORT
XLX_LIVE_SOURCE_SERVERNAME=$DOMAIN
XLX_LIVE_SOURCE_PATH=/api/live-hub-source
XLX_LIVE_SNAPSHOT_FILE=/run/xlx-modern-live-hub/latest.json
ENV
install -m 0644 "$ROOT/runtime/live-core/xlx-modern-live-core.service" /etc/systemd/system/
install -m 0644 "$ROOT/runtime/live-hub/xlx-modern-live-hub.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now xlx-modern-live-core.service xlx-modern-live-hub.service
for port in 8092 8091; do
  ready=no
  for attempt in {1..20}; do
    if curl --fail --silent --max-time 2 "http://127.0.0.1:$port/health" >/dev/null; then ready=yes; break; fi
    sleep 1
  done
  [[ "$ready" == yes ]] || { echo "ERROR: Live service on $port did not become ready" >&2; exit 1; }
done
say '[OK] WebSocket e SSE ativos; CallHome e núcleo não foram reiniciados.' '[OK] WebSocket and SSE active; CallHome and core were not restarted.'