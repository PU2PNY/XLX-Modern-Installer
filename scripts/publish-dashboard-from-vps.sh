#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

SOURCE_PANEL="${SOURCE_PANEL:-/var/www/html/xlxd-novo}"
REPO_DIR="${REPO_DIR:-/root/XLX-Modern-Installer}"
BACKUP_DIR="${BACKUP_DIR:-/root/xlx-modern-dashboard-backups}"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="${BACKUP_DIR}/xlxd-novo-${STAMP}.tar.gz"
DASHBOARD_DIR="${REPO_DIR}/dashboard"
REPORT="${REPO_DIR}/dashboard-publication-report.txt"

red=$'\033[31m'; green=$'\033[32m'; yellow=$'\033[33m'; blue=$'\033[34m'; reset=$'\033[0m'
info(){ printf '%s[INFO]%s %s\n' "$blue" "$reset" "$*"; }
ok(){ printf '%s[OK]%s %s\n' "$green" "$reset" "$*"; }
warn(){ printf '%s[ATENÇÃO]%s %s\n' "$yellow" "$reset" "$*"; }
fatal(){ printf '%s[ERRO]%s %s\n' "$red" "$reset" "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fatal "Execute como root."
[ -d "$SOURCE_PANEL" ] || fatal "Painel não encontrado: $SOURCE_PANEL"
[ -d "$REPO_DIR/.git" ] || fatal "Repositório não encontrado em: $REPO_DIR"

for cmd in git rsync tar sha256sum python3 grep find php; do
  command -v "$cmd" >/dev/null 2>&1 || fatal "Comando ausente: $cmd"
done

info "Atualizando repositório local."
git -C "$REPO_DIR" fetch origin main
git -C "$REPO_DIR" checkout main
git -C "$REPO_DIR" reset --hard origin/main

info "Criando backup do painel atual."
mkdir -p "$BACKUP_DIR"
tar -C "$(dirname "$SOURCE_PANEL")" -czpf "$BACKUP_FILE" "$(basename "$SOURCE_PANEL")"
sha256sum "$BACKUP_FILE" > "${BACKUP_FILE}.sha256"
sha256sum -c "${BACKUP_FILE}.sha256" >/dev/null
ok "Backup criado: $BACKUP_FILE"

info "Copiando painel para a área pública do repositório."
rm -rf "$DASHBOARD_DIR"
mkdir -p "$DASHBOARD_DIR"
rsync -a --delete \
  --exclude='.git/' \
  --exclude='.env' \
  --exclude='.env.*' \
  --exclude='*.log' \
  --exclude='*.db' \
  --exclude='*.sqlite' \
  --exclude='*.sqlite3' \
  --exclude='*.pid' \
  --exclude='*.sock' \
  --exclude='*.bak' \
  --exclude='*.backup' \
  --exclude='cache/' \
  --exclude='tmp/' \
  --exclude='temp/' \
  --exclude='sessions/' \
  --exclude='node_modules/' \
  "$SOURCE_PANEL/" "$DASHBOARD_DIR/"

info "Sanitizando nomes, descrições e menu Suporte na cópia pública."
python3 - "$DASHBOARD_DIR" <<'PY'
import re, sys
from pathlib import Path
root = Path(sys.argv[1])
exts = {'.php','.html','.htm','.js','.jsx','.ts','.tsx','.css','.scss','.json','.xml','.md','.txt','.yml','.yaml','.conf','.ini'}
repls = [
    (re.compile(r'\bXLX026D?\b', re.I), '{{REFLECTOR_NAME}}'),
    (re.compile(r'\bXRF026\b', re.I), '{{REFLECTOR_NAME}}'),
    (re.compile(r'\bPU2PNY\b', re.I), '{{SYSOP_CALLSIGN}}'),
    (re.compile(r'\bxlx026\.net\b', re.I), '{{DOMAIN}}'),
    (re.compile(r'\bSanta\s+Isabel\s*(?:[-–—]\s*)?SP\b', re.I), '{{LOCATION}}'),
]
support_lines = [
    re.compile(r'(?im)^.*href\s*=\s*["\'][^"\']*(?:suporte|support)[^"\']*["\'].*$\n?'),
    re.compile(r'(?im)^.*>\s*(?:suporte|support)\s*<.*$\n?'),
    re.compile(r'(?im)^.*["\'](?:label|title|name|text)["\']\s*(?:=>|:)\s*["\'](?:suporte|support)["\'].*$\n?'),
]
for p in root.rglob('*'):
    if not p.is_file() or p.suffix.lower() not in exts:
        continue
    try:
        text = p.read_text(encoding='utf-8')
    except UnicodeDecodeError:
        continue
    original = text
    for rx, value in repls:
        text = rx.sub(value, text)
    for rx in support_lines:
        text = rx.sub('', text)
    if text != original:
        p.write_text(text, encoding='utf-8')
PY

mkdir -p "$DASHBOARD_DIR/config" "$DASHBOARD_DIR/includes" "$DASHBOARD_DIR/install"
cat > "$DASHBOARD_DIR/config/site.example.php" <<'PHP'
<?php

declare(strict_types=1);

return [
    'reflector' => [
        'name' => 'XLX000',
        'title' => 'XLX000 Reflector',
        'description' => 'Multiprotocol amateur radio reflector',
        'sysop_callsign' => 'N0CALL',
        'location' => 'City / State',
        'country' => 'Country',
        'domain' => 'xlx.example.org',
        'contact_email' => 'sysop@example.org',
    ],
    'branding' => [
        'header_title' => 'XLX000 Reflector',
        'header_subtitle' => 'Multiprotocol amateur radio reflector',
        'footer_text' => '',
    ],
    'features' => [
        'show_support_menu' => false,
        'show_contact_email' => true,
        'show_location' => true,
        'show_sysop_callsign' => true,
    ],
];
PHP

cat > "$DASHBOARD_DIR/config/.gitignore" <<'EOF'
site.php
.env
.env.*
*.local.php
*.secret.php
EOF

cat > "$DASHBOARD_DIR/install/install-dashboard.sh" <<'INSTALL'
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${INSTALL_DIR:-/var/www/html/xlx-dashboard}"
BACKUPS="${BACKUP_ROOT:-/var/backups/xlx-reflector}"

ask(){ local n="$1" p="$2" v=""; while [ -z "$v" ]; do read -r -p "$p: " v; done; printf -v "$n" '%s' "$v"; }
escape(){ printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e "s/'/\\\\'/g"; }

[ "$(id -u)" -eq 0 ] || { echo "Execute como root." >&2; exit 1; }
ask REFLECTOR_NAME "Identificação do refletor"
ask REFLECTOR_TITLE "Nome exibido"
ask REFLECTOR_DESCRIPTION "Descrição curta"
ask SYSOP_CALLSIGN "Indicativo do responsável"
ask LOCATION "Cidade e estado/região"
ask COUNTRY "País"
ask DOMAIN "Domínio"
ask CONTACT_EMAIL "E-mail de contato"

if [ -e "$DEST" ]; then
  stamp="$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$BACKUPS"
  tar -C "$(dirname "$DEST")" -czpf "$BACKUPS/dashboard-${stamp}.tar.gz" "$(basename "$DEST")"
fi

mkdir -p "$DEST"
rsync -a --delete --exclude='install/' --exclude='config/site.php' "$ROOT/" "$DEST/"
mkdir -p "$DEST/config"
cat > "$DEST/config/site.php" <<PHP
<?php

declare(strict_types=1);

return [
    'reflector' => [
        'name' => '$(escape "$REFLECTOR_NAME")',
        'title' => '$(escape "$REFLECTOR_TITLE")',
        'description' => '$(escape "$REFLECTOR_DESCRIPTION")',
        'sysop_callsign' => '$(escape "$SYSOP_CALLSIGN")',
        'location' => '$(escape "$LOCATION")',
        'country' => '$(escape "$COUNTRY")',
        'domain' => '$(escape "$DOMAIN")',
        'contact_email' => '$(escape "$CONTACT_EMAIL")',
    ],
    'branding' => [
        'header_title' => '$(escape "$REFLECTOR_TITLE")',
        'header_subtitle' => '$(escape "$REFLECTOR_DESCRIPTION")',
        'footer_text' => '',
    ],
    'features' => [
        'show_support_menu' => false,
        'show_contact_email' => true,
        'show_location' => true,
        'show_sysop_callsign' => true,
    ],
];
PHP
find "$DEST" -type d -exec chmod 755 {} \;
find "$DEST" -type f -exec chmod 644 {} \;
chown -R root:www-data "$DEST"
chmod 640 "$DEST/config/site.php"
find "$DEST" -type f -name '*.php' -print0 | xargs -0 -r -n1 php -l >/dev/null
printf 'XLX Modern Dashboard instalado em %s\n' "$DEST"
INSTALL
chmod 755 "$DASHBOARD_DIR/install/install-dashboard.sh"

: > "$REPORT"
grep -RniE --binary-files=without-match \
  --exclude='site.example.php' \
  --exclude='dashboard-publication-report.txt' \
  '(XLX026|XRF026|PU2PNY|xlx026\.net|Santa[[:space:]]+Isabel|BEGIN[[:space:]]+(RSA|OPENSSH|EC)[[:space:]]+PRIVATE[[:space:]]+KEY|authorization:[[:space:]]*bearer)' \
  "$DASHBOARD_DIR" > "$REPORT" 2>/dev/null || true

if [ -s "$REPORT" ]; then
  cat "$REPORT"
  fatal "Publicação bloqueada: ainda existem dados privados ou específicos."
fi

find "$DASHBOARD_DIR" -type f -name '*.php' -print0 | xargs -0 -r -n1 php -l >/dev/null
bash -n "$DASHBOARD_DIR/install/install-dashboard.sh"

info "Criando módulo de integração."
cat > "$REPO_DIR/modules/60-dashboard-modern.sh" <<'MODULE'
#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
exec bash "$ROOT/dashboard/install/install-dashboard.sh"
MODULE
chmod 755 "$REPO_DIR/modules/60-dashboard-modern.sh"

info "Atualizando install.sh para chamar o painel moderno."
python3 - "$REPO_DIR/install.sh" <<'PY'
import sys
from pathlib import Path
p = Path(sys.argv[1])
t = p.read_text(encoding='utf-8')
if 'readonly ROOT_DIR=' not in t:
    t = t.replace('umask 077\n', 'umask 077\n\nreadonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"\n', 1)
needle = '    section "VALIDAÇÃO PÓS-INSTALAÇÃO"\n'
call = '    section "INSTALANDO XLX MODERN DASHBOARD"\n    bash "$ROOT_DIR/modules/60-dashboard-modern.sh"\n\n'
if call not in t:
    if needle not in t:
        raise SystemExit('Ponto de integração não encontrado em install.sh')
    t = t.replace(needle, call + needle, 1)
p.write_text(t, encoding='utf-8')
PY
bash -n "$REPO_DIR/install.sh"

git -C "$REPO_DIR" add dashboard modules/60-dashboard-modern.sh install.sh
git -C "$REPO_DIR" config user.name "Dario PU2PNY"
git -C "$REPO_DIR" config user.email "pu2pny@users.noreply.github.com"

if git -C "$REPO_DIR" diff --cached --quiet; then
  warn "Nenhuma alteração nova para publicar."
  exit 0
fi

git -C "$REPO_DIR" commit -m "Integra painel moderno ao instalador"
git -C "$REPO_DIR" push origin main
ok "Painel publicado e integrado ao instalador."
