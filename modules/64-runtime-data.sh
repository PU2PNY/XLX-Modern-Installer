#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/xlx-reflector}"
USERS_DIR="/xlxd/users_db"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="$BACKUP_ROOT/runtime-data-$STAMP"

RED=$'\033[31m'; GREEN=$'\033[32m'; BLUE=$'\033[34m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
info(){ printf '%s[INFO]%s %s\n' "$BLUE" "$RESET" "$*"; }
ok(){ printf '%s[OK]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn(){ printf '%s[ATENÇÃO]%s %s\n' "$YELLOW" "$RESET" "$*"; }
fatal(){ printf '%s[ERRO]%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fatal 'Execute como root.'
[ -x /xlxd/xlxd ] || fatal 'XLXD não encontrado em /xlxd/xlxd.'
for cmd in systemctl php sqlite3 curl install tar sha256sum runuser; do
    command -v "$cmd" >/dev/null 2>&1 || fatal "Comando obrigatório ausente: $cmd"
done
getent group www-data >/dev/null 2>&1 || fatal 'Grupo www-data não encontrado.'

for file in \
    "$ROOT/tools/create-user-db.php" \
    "$ROOT/tools/xlx-modern-users-refresh.sh" \
    "$ROOT/runtime/update_XLX_db.service" \
    "$ROOT/runtime/update_XLX_db.timer" \
    "$ROOT/runtime/xlx_log.sh" \
    "$ROOT/runtime/xlx_log.service" \
    "$ROOT/runtime/xlx_logrotate.conf"
do
    [ -f "$file" ] || fatal "Componente ausente: $file"
done

mkdir -p "$BACKUP"
chmod 0700 "$BACKUP"
manifest="$BACKUP/manifest.txt"
: > "$manifest"
for path in \
    "$USERS_DIR" \
    /usr/local/bin/update_db.sh \
    /usr/local/sbin/xlx-modern-users-refresh \
    /usr/local/sbin/xlx-modern-log-bridge \
    /etc/systemd/system/update_XLX_db.service \
    /etc/systemd/system/update_XLX_db.timer \
    /etc/systemd/system/xlx_log.service \
    /etc/logrotate.d/xlx_logrotate.conf \
    /var/log/xlx.log
do
    [ ! -e "$path" ] || printf '%s\n' "$path" >> "$manifest"
done

if [ -s "$manifest" ]; then
    tar --ignore-failed-read -czpf "$BACKUP/before.tar.gz" -T "$manifest"
    sha256sum "$BACKUP/before.tar.gz" > "$BACKUP/before.tar.gz.sha256"
    sha256sum -c "$BACKUP/before.tar.gz.sha256" >/dev/null
    ok "Backup verificado: $BACKUP/before.tar.gz"
else
    rmdir "$BACKUP" 2>/dev/null || true
fi

install -d -m 0755 -o root -g www-data "$USERS_DIR"
install -m 0644 -o root -g www-data "$ROOT/tools/create-user-db.php" "$USERS_DIR/create_user_db.php"
install -m 0750 -o root -g root "$ROOT/tools/xlx-modern-users-refresh.sh" /usr/local/sbin/xlx-modern-users-refresh
install -m 0644 -o root -g root "$ROOT/runtime/update_XLX_db.service" /etc/systemd/system/update_XLX_db.service
install -m 0644 -o root -g root "$ROOT/runtime/update_XLX_db.timer" /etc/systemd/system/update_XLX_db.timer
install -m 0750 -o root -g root "$ROOT/runtime/xlx_log.sh" /usr/local/sbin/xlx-modern-log-bridge
install -m 0644 -o root -g root "$ROOT/runtime/xlx_log.service" /etc/systemd/system/xlx_log.service
install -m 0644 -o root -g root "$ROOT/runtime/xlx_logrotate.conf" /etc/logrotate.d/xlx_logrotate.conf

systemctl daemon-reload

info 'Criando/atualizando a base principal de indicativos...'
/usr/local/sbin/xlx-modern-users-refresh
[ -s "$USERS_DIR/users.db" ] || fatal 'users.db não foi criado.'
[ "$(sqlite3 "$USERS_DIR/users.db" 'PRAGMA integrity_check;' 2>/dev/null)" = 'ok' ] || fatal 'users.db falhou na integridade.'
rows="$(sqlite3 "$USERS_DIR/users.db" 'SELECT COUNT(*) FROM users;' 2>/dev/null || echo 0)"
[[ "$rows" =~ ^[0-9]+$ ]] || rows=0
[ "$rows" -ge 1000 ] || fatal "users.db possui poucos registros: $rows"
ok "Base de indicativos pronta: $rows registros."

systemctl enable --now update_XLX_db.timer >/dev/null
systemctl is-active --quiet update_XLX_db.timer || fatal 'update_XLX_db.timer não ficou ativo.'
ok 'Atualização automática diária de indicativos ativada.'

# Não reinicia o XLXD. Apenas instala/reinicia a ponte de leitura do journal.
systemctl enable xlx_log.service >/dev/null
systemctl restart xlx_log.service
systemctl is-active --quiet xlx_log.service || fatal 'xlx_log.service não ficou ativo.'

for _ in 1 2 3 4 5; do
    [ -e /var/log/xlx.log ] && break
    sleep 1
done
[ -e /var/log/xlx.log ] || fatal '/var/log/xlx.log não foi criado.'
chown root:www-data /var/log/xlx.log
chmod 0640 /var/log/xlx.log
sudo_read="$(runuser -u www-data -- test -r /var/log/xlx.log && echo yes || echo no)"
[ "$sudo_read" = yes ] || fatal 'www-data não consegue ler /var/log/xlx.log.'
ok 'Ponte de log TX/RX ativa; XLXD não foi reiniciado.'

printf 'USERS_DB_ROWS=%s\n' "$rows"
printf 'USERS_TIMER=ACTIVE\n'
printf 'XLX_LOG_SERVICE=ACTIVE\n'
printf 'STATUS=RUNTIME_DATA_OK\n'
