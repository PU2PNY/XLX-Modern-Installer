#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DASH="${XLX_DASHBOARD_DIR:-${INSTALL_DIR:-/var/www/html/xlxd}}"
UI_LANG="${XLX_UI_LANG:-pt-BR}"
MODE=install
for a in "$@"; do
  case "$a" in
    --check|--dry-run) MODE=check ;;
    --dashboard-dir=*) DASH="${a#*=}" ;;
    *) printf '[ERROR] unknown option: %s\n' "$a" >&2; exit 2 ;;
  esac
done
say(){ [[ "$UI_LANG" == en ]] && printf '%s' "$2" || printf '%s' "$1"; }
ok(){ printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
fail(){ printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" -eq 0 ]] || fail "$(say 'Execute como root.' 'Run as root.')"
[[ -f "$DASH/config/site.php" ]] || fail "$(say 'Configuração do painel ausente.' 'Dashboard configuration missing.')"
DOMAIN="$(php -r '$c=require $argv[1];echo strtolower((string)($c["reflector"]["domain"]??""));' "$DASH/config/site.php")"
TIMEZONE="$(php -r '$c=require $argv[1];echo (string)($c["timezone"]??"UTC");' "$DASH/config/site.php")"
[[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]] || fail "$(say 'Domínio inválido.' 'Invalid domain.')"
[[ "$DASH" = /* ]] || fail "$(say 'Diretório do painel inválido.' 'Invalid dashboard directory.')"

if [[ "$MODE" == check ]]; then
  for f in "$DASH/index.php" "$DASH/api/status.php" "$DASH/api/live.php"; do [[ -s "$f" ]] || fail "$(say "Arquivo ausente: $f" "Missing file: $f")"; done
  ok "$(say 'Pré-validação Nginx/PHP-FPM concluída.' 'Nginx/PHP-FPM pre-check passed.')"
  exit 0
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq nginx php8.2-fpm php8.2-cli php8.2-curl php8.2-mbstring php8.2-sqlite3 php8.2-xml certbot >/dev/null

# Match the production-proven PHP-FPM pool limits without creating a second pool.
POOL=/etc/php/8.2/fpm/pool.d/www.conf
[[ -f "$POOL" ]] || fail "$(say 'Pool PHP-FPM não encontrado.' 'PHP-FPM pool not found.')"
cp -an "$POOL" "$POOL.xlx-modern.orig" 2>/dev/null || true
set_pool(){
  local key="$1" value="$2"
  if grep -Eq "^[;[:space:]]*${key//./\\.}[[:space:]]*=" "$POOL"; then
    sed -ri "s|^[;[:space:]]*${key//./\\.}[[:space:]]*=.*|$key = $value|" "$POOL"
  else
    printf '%s = %s\n' "$key" "$value" >> "$POOL"
  fi
}
set_pool pm dynamic
set_pool pm.max_children 16
set_pool pm.start_servers 4
set_pool pm.min_spare_servers 2
set_pool pm.max_spare_servers 6
set_pool pm.max_requests 1000
set_pool request_terminate_timeout 30s
if grep -Eq '^;?[[:space:]]*php_admin_value\[date.timezone\]' "$POOL"; then
  sed -ri "s|^;?[[:space:]]*php_admin_value\[date.timezone\].*|php_admin_value[date.timezone] = $TIMEZONE|" "$POOL"
else
  printf 'php_admin_value[date.timezone] = %s\n' "$TIMEZONE" >> "$POOL"
fi

install -d -m 0755 /var/www/certbot /var/cache/nginx/xlx-modern/fpm
cat >/etc/nginx/conf.d/xlx-modern-fpm-cache.conf <<'NGINX'
fastcgi_cache_path /var/cache/nginx/xlx-modern/fpm levels=1:2 keys_zone=xlxmodern_fpm_api:8m inactive=1h max_size=64m use_temp_path=off;
NGINX

cat >/etc/nginx/xlx-modern-fastcgi.conf <<'NGINX'
include fastcgi_params;
fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
fastcgi_connect_timeout 2s;
fastcgi_send_timeout 15s;
fastcgi_read_timeout 15s;
fastcgi_pass unix:/run/php/php8.2-fpm.sock;
NGINX

write_http_site(){
cat >/etc/nginx/sites-available/xlx-modern.conf <<NGINX
map \$arg_page \$xlxmodern_old_page_redirect {
    default "";
    ao-vivo /ao-vivo;
    modulos /modulos;
    conectados /conectados;
    ranking /ranking;
    refletores /refletores;
    certificado /certificado;
    digital-lab /aprs-dprs;
}
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name $DOMAIN;
    server_tokens off;
    root $DASH;
    index index.php index.html;
    keepalive_timeout 15s;
    keepalive_requests 1000;
    client_max_body_size 32m;
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_comp_level 5;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss image/svg+xml;
    location ^~ /.well-known/acme-challenge/ { root /var/www/certbot; default_type text/plain; try_files \$uri =404; }
    location = / { return 301 /ao-vivo; }
    location = /digital-lab { return 301 /aprs-dprs; }
    location = /digital-lab/ { return 301 /aprs-dprs; }
    location ~ ^/(ao-vivo|modulos|conectados|ranking|refletores|certificado|aprs-dprs)/\$ { return 301 /\$1; }
    location = /index.php {
        if (\$xlxmodern_old_page_redirect != "") { return 301 \$xlxmodern_old_page_redirect; }
        include /etc/nginx/xlx-modern-fastcgi.conf;
        fastcgi_param HTTPS off;
        fastcgi_param HTTP_X_FORWARDED_PROTO http;
    }
    location ~ ^/(ao-vivo|modulos|conectados|ranking|refletores|certificado)\$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root/index.php;
        fastcgi_param SCRIPT_NAME /index.php;
        fastcgi_param QUERY_STRING page=\$1&\$args;
        fastcgi_param HTTPS off;
        fastcgi_param HTTP_X_FORWARDED_PROTO http;
        fastcgi_connect_timeout 2s; fastcgi_send_timeout 15s; fastcgi_read_timeout 15s;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    }
    location = /aprs-dprs {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root/index.php;
        fastcgi_param SCRIPT_NAME /index.php;
        fastcgi_param QUERY_STRING page=digital-lab&\$args;
        fastcgi_param HTTPS off;
        fastcgi_param HTTP_X_FORWARDED_PROTO http;
        fastcgi_connect_timeout 2s; fastcgi_send_timeout 15s; fastcgi_read_timeout 15s;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    }
    location = /api/status.php { include /etc/nginx/xlx-modern-fastcgi.conf; fastcgi_cache xlxmodern_fpm_api; fastcgi_cache_key "\$uri|history=\$arg_history|hours=\$arg_history_hours"; fastcgi_cache_valid 200 1s; fastcgi_cache_lock on; fastcgi_ignore_headers Cache-Control Expires; }
    location = /api/mtr.php { include /etc/nginx/xlx-modern-fastcgi.conf; fastcgi_cache xlxmodern_fpm_api; fastcgi_cache_key "\$uri|\$arg_key|\$arg_module|\$arg_callsign|\$arg_suffix"; fastcgi_cache_valid 200 10s; fastcgi_cache_lock on; fastcgi_ignore_headers Cache-Control Expires; }
    location = /api/repeater.php { include /etc/nginx/xlx-modern-fastcgi.conf; fastcgi_cache xlxmodern_fpm_api; fastcgi_cache_key "\$uri|\$arg_callsign"; fastcgi_cache_valid 200 1h; fastcgi_cache_valid 404 10m; fastcgi_cache_lock on; fastcgi_ignore_headers Cache-Control Expires; }
    location ~* \\.(?:css|js|png|jpe?g|gif|svg|ico|webp|avif|woff2?|ttf)\$ { try_files \$uri =404; expires 7d; access_log off; add_header Cache-Control "public, max-age=604800, immutable"; }
    location ~ \\.php\$ { try_files \$uri =404; include /etc/nginx/xlx-modern-fastcgi.conf; fastcgi_param HTTPS off; fastcgi_param HTTP_X_FORWARDED_PROTO http; }
    location / { try_files \$uri \$uri/ =404; }
    location ~ /\\. { deny all; }
}
NGINX
}

write_https_site(){
cat >/etc/nginx/sites-available/xlx-modern.conf <<NGINX
map \$arg_page \$xlxmodern_old_page_redirect {
    default "";
    ao-vivo /ao-vivo;
    modulos /modulos;
    conectados /conectados;
    ranking /ranking;
    refletores /refletores;
    certificado /certificado;
    digital-lab /aprs-dprs;
}
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name $DOMAIN;
    server_tokens off;
    location ^~ /.well-known/acme-challenge/ { root /var/www/certbot; default_type text/plain; try_files \$uri =404; }
    location / { return 301 https://$DOMAIN\$request_uri; }
}
server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;
    server_name $DOMAIN;
    server_tokens off;
    root $DASH;
    index index.php index.html;
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:XLXSSL:10m;
    ssl_session_timeout 1h;
    keepalive_timeout 15s;
    keepalive_requests 1000;
    client_max_body_size 32m;
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_comp_level 5;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss image/svg+xml;
    location = / { return 301 https://$DOMAIN/ao-vivo; }
    location = /digital-lab { return 301 https://$DOMAIN/aprs-dprs; }
    location = /digital-lab/ { return 301 https://$DOMAIN/aprs-dprs; }
    location ~ ^/(ao-vivo|modulos|conectados|ranking|refletores|certificado|aprs-dprs)/\$ { return 301 https://$DOMAIN/\$1; }
    location = /index.php {
        if (\$xlxmodern_old_page_redirect != "") { return 301 https://$DOMAIN\$xlxmodern_old_page_redirect; }
        include /etc/nginx/xlx-modern-fastcgi.conf;
        fastcgi_param HTTPS on; fastcgi_param SERVER_PORT 443; fastcgi_param HTTP_X_FORWARDED_PROTO https;
    }
    location ~ ^/(ao-vivo|modulos|conectados|ranking|refletores|certificado)\$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root/index.php;
        fastcgi_param SCRIPT_NAME /index.php;
        fastcgi_param QUERY_STRING page=\$1&\$args;
        fastcgi_param HTTPS on; fastcgi_param SERVER_PORT 443; fastcgi_param HTTP_X_FORWARDED_PROTO https;
        fastcgi_connect_timeout 2s; fastcgi_send_timeout 15s; fastcgi_read_timeout 15s;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    }
    location = /aprs-dprs {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root/index.php;
        fastcgi_param SCRIPT_NAME /index.php;
        fastcgi_param QUERY_STRING page=digital-lab&\$args;
        fastcgi_param HTTPS on; fastcgi_param SERVER_PORT 443; fastcgi_param HTTP_X_FORWARDED_PROTO https;
        fastcgi_connect_timeout 2s; fastcgi_send_timeout 15s; fastcgi_read_timeout 15s;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    }
    location = /api/live.php { include /etc/nginx/xlx-modern-fastcgi.conf; fastcgi_param HTTPS on; fastcgi_param SERVER_PORT 443; fastcgi_param HTTP_X_FORWARDED_PROTO https; add_header X-XLX-Modern-Edge nginx-fpm always; }
    location = /api/status.php { include /etc/nginx/xlx-modern-fastcgi.conf; fastcgi_param HTTPS on; fastcgi_param SERVER_PORT 443; fastcgi_param HTTP_X_FORWARDED_PROTO https; fastcgi_cache xlxmodern_fpm_api; fastcgi_cache_key "\$uri|history=\$arg_history|hours=\$arg_history_hours"; fastcgi_cache_valid 200 1s; fastcgi_cache_lock on; fastcgi_ignore_headers Cache-Control Expires; add_header X-XLX-Modern-Edge-Cache \$upstream_cache_status always; }
    location = /api/mtr.php { include /etc/nginx/xlx-modern-fastcgi.conf; fastcgi_param HTTPS on; fastcgi_param SERVER_PORT 443; fastcgi_param HTTP_X_FORWARDED_PROTO https; fastcgi_cache xlxmodern_fpm_api; fastcgi_cache_key "\$uri|\$arg_key|\$arg_module|\$arg_callsign|\$arg_suffix"; fastcgi_cache_valid 200 10s; fastcgi_cache_lock on; fastcgi_ignore_headers Cache-Control Expires; add_header X-XLX-Modern-Edge-Cache \$upstream_cache_status always; }
    location = /api/repeater.php { include /etc/nginx/xlx-modern-fastcgi.conf; fastcgi_param HTTPS on; fastcgi_param SERVER_PORT 443; fastcgi_param HTTP_X_FORWARDED_PROTO https; fastcgi_cache xlxmodern_fpm_api; fastcgi_cache_key "\$uri|\$arg_callsign"; fastcgi_cache_valid 200 1h; fastcgi_cache_valid 404 10m; fastcgi_cache_lock on; fastcgi_ignore_headers Cache-Control Expires; add_header X-XLX-Modern-Edge-Cache \$upstream_cache_status always; }
    location ~* \\.(?:css|js|png|jpe?g|gif|svg|ico|webp|avif|woff2?|ttf)\$ { try_files \$uri =404; expires 7d; access_log off; add_header Cache-Control "public, max-age=604800, immutable"; }
    location ~ \\.php\$ { try_files \$uri =404; include /etc/nginx/xlx-modern-fastcgi.conf; fastcgi_param HTTPS on; fastcgi_param SERVER_PORT 443; fastcgi_param HTTP_X_FORWARDED_PROTO https; }
    location / { try_files \$uri \$uri/ =404; }
    location ~ /\\. { deny all; }
}
NGINX
}

write_http_site
ln -sfn /etc/nginx/sites-available/xlx-modern.conf /etc/nginx/sites-enabled/xlx-modern.conf
rm -f /etc/nginx/sites-enabled/default
systemctl enable --now php8.2-fpm

# The upstream base installer leaves Apache active on port 80. Stop it BEFORE
# starting Nginx, otherwise a clean installation deterministically fails with
# "bind() to 0.0.0.0:80 failed (98: Address already in use)".
# Apache remains installed only for compatibility with the upstream base installer;
# production parity uses Nginx + PHP-FPM as the web edge.
systemctl disable --now apache2 >/dev/null 2>&1 || true

nginx -t
systemctl enable --now nginx

# Replace the legacy Apache Certbot retry with a webroot-based Nginx-safe retry.
HTTPS_RETRY=/usr/local/sbin/xlx-modern-https-retry
cat >"$HTTPS_RETRY" <<'RETRY'
#!/usr/bin/env bash
set -Eeuo pipefail
DOMAIN="${1:-}"
EMAIL="${2:-}"
[[ -n "$DOMAIN" && -n "$EMAIL" ]] || { echo "Usage: xlx-modern-https-retry DOMAIN EMAIL" >&2; exit 2; }
certbot certonly --webroot -w /var/www/certbot --non-interactive --agree-tos --email "$EMAIL" -d "$DOMAIN"
[[ -s "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" && -s "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]] || exit 3
# Re-run the idempotent Nginx layer so it switches to the HTTPS vhost.
XLX_DASHBOARD_DIR="${XLX_DASHBOARD_DIR:-/var/www/html/xlxd}" bash /usr/local/lib/xlx-modern/70-nginx.sh --dashboard-dir="${XLX_DASHBOARD_DIR:-/var/www/html/xlxd}"
install -d -m 0755 /var/lib/xlx-modern
printf 'HTTPS_OK domain=%s\n' "$DOMAIN" > /var/lib/xlx-modern/https-status
systemctl disable --now xlx-modern-https-retry.timer >/dev/null 2>&1 || true
RETRY
chmod 0755 "$HTTPS_RETRY"
install -d -m 0755 /usr/local/lib/xlx-modern
install -m 0755 "$ROOT/modules/70-nginx.sh" /usr/local/lib/xlx-modern/70-nginx.sh

# If a certificate already exists (normally issued by the first-pass installer),
# immediately switch to the production HTTPS layout.
if [[ -s "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" && -s "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]]; then
  write_https_site
  nginx -t
  systemctl reload nginx
fi

# Make any pre-existing retry unit depend on the actual production web stack.
if [[ -f /etc/systemd/system/xlx-modern-https-retry.service ]]; then
  sed -ri 's/After=network-online.target apache2\.service/After=network-online.target nginx.service php8.2-fpm.service/' /etc/systemd/system/xlx-modern-https-retry.service
  systemctl daemon-reload
fi

nginx -t >/dev/null
systemctl is-active --quiet nginx || fail "$(say 'Nginx inativo.' 'Nginx inactive.')"
systemctl is-active --quiet php8.2-fpm || fail "$(say 'PHP-FPM inativo.' 'PHP-FPM inactive.')"
if systemctl is-active --quiet apache2; then fail "$(say 'Apache permaneceu ativo após a migração.' 'Apache remained active after migration.')"; fi
ok "$(say 'Nginx + PHP-FPM configurados como camada web de produção.' 'Nginx + PHP-FPM configured as the production web edge.')"
