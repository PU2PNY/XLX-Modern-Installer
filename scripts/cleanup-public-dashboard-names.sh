#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

REPO_DIR="${REPO_DIR:-/root/XLX-Modern-Installer}"
DASHBOARD_DIR="${REPO_DIR}/dashboard"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_BRANCH="backup/dashboard-cleanup-${STAMP}"
REPORT="${REPO_DIR}/dashboard-cleanup-report.txt"

red=$'\033[31m'; green=$'\033[32m'; yellow=$'\033[33m'; blue=$'\033[34m'; reset=$'\033[0m'
info(){ printf '%s[INFO]%s %s\n' "$blue" "$reset" "$*"; }
ok(){ printf '%s[OK]%s %s\n' "$green" "$reset" "$*"; }
warn(){ printf '%s[ATENÇÃO]%s %s\n' "$yellow" "$reset" "$*"; }
fatal(){ printf '%s[ERRO]%s %s\n' "$red" "$reset" "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fatal "Execute como root."
[ -d "$REPO_DIR/.git" ] || fatal "Repositório não encontrado em: $REPO_DIR"
[ -d "$DASHBOARD_DIR" ] || fatal "Dashboard não encontrado em: $DASHBOARD_DIR"

for cmd in git python3 grep find php bash; do
  command -v "$cmd" >/dev/null 2>&1 || fatal "Comando ausente: $cmd"
done

info "Atualizando repositório local."
git -C "$REPO_DIR" fetch origin main
git -C "$REPO_DIR" checkout main
git -C "$REPO_DIR" reset --hard origin/main

info "Criando branch de segurança: $BACKUP_BRANCH"
git -C "$REPO_DIR" branch "$BACKUP_BRANCH"

info "Renomeando arquivos residuais."
if [ -f "$DASHBOARD_DIR/assets/logo-xlx026.jpeg" ]; then
  git -C "$REPO_DIR" mv dashboard/assets/logo-xlx026.jpeg dashboard/assets/logo-reflector.jpeg
fi

info "Removendo arquivos exclusivos da antiga área de suporte."
for path in \
  dashboard/assets/support-native.css \
  dashboard/assets/support-native.js \
  dashboard/common_refletores_otimizado.zip
  do
  if [ -e "$REPO_DIR/$path" ]; then
    git -C "$REPO_DIR" rm -f -- "$path"
  fi
done

info "Atualizando referências internas."
python3 - "$DASHBOARD_DIR" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
exts = {
    '.php', '.html', '.htm', '.js', '.jsx', '.ts', '.tsx', '.css', '.scss',
    '.json', '.xml', '.md', '.txt', '.yml', '.yaml', '.conf', '.ini'
}

replacements = [
    ('assets/logo-xlx026.jpeg', 'assets/logo-reflector.jpeg'),
    ('logo-xlx026.jpeg', 'logo-reflector.jpeg'),
    ('support-native.css', ''),
    ('support-native.js', ''),
    ('common_refletores_otimizado.zip', ''),
]

line_patterns = [
    re.compile(r'(?im)^.*support-native\.(?:css|js).*$\n?'),
    re.compile(r'(?im)^.*common_refletores_otimizado\.zip.*$\n?'),
]

for path in root.rglob('*'):
    if not path.is_file() or path.suffix.lower() not in exts:
        continue
    try:
        text = path.read_text(encoding='utf-8')
    except UnicodeDecodeError:
        continue
    original = text
    for old, new in replacements:
        text = text.replace(old, new)
    for rx in line_patterns:
        text = rx.sub('', text)
    if text != original:
        path.write_text(text, encoding='utf-8')
PY

: > "$REPORT"

info "Validando referências e nomes residuais."
{
  find "$DASHBOARD_DIR" -type f \
    \( -iname '*xlx026*' -o -iname '*support-native*' -o -iname '*common_refletores_otimizado*' \)
  grep -RniE --binary-files=without-match \
    --exclude='dashboard-cleanup-report.txt' \
    '(logo-xlx026|support-native|common_refletores_otimizado|xlx026\.net|PU2PNY|Santa[[:space:]]+Isabel)' \
    "$DASHBOARD_DIR" 2>/dev/null || true
} > "$REPORT"

if [ -s "$REPORT" ]; then
  cat "$REPORT"
  fatal "Limpeza bloqueada: ainda existem nomes ou referências residuais."
fi

info "Validando sintaxe PHP e Shell."
find "$DASHBOARD_DIR" -type f -name '*.php' -print0 | xargs -0 -r -n1 php -l >/dev/null
find "$REPO_DIR" -type f -name '*.sh' -print0 | xargs -0 -r -n1 bash -n

info "Preparando commit."
git -C "$REPO_DIR" add dashboard scripts/cleanup-public-dashboard-names.sh

if git -C "$REPO_DIR" diff --cached --quiet; then
  warn "Nenhuma alteração nova foi encontrada."
  exit 0
fi

git -C "$REPO_DIR" config user.name "Dario PU2PNY"
git -C "$REPO_DIR" config user.email "pu2pny@users.noreply.github.com"
git -C "$REPO_DIR" commit -m "Padroniza nomes públicos do dashboard"
git -C "$REPO_DIR" push origin main

ok "Limpeza concluída e publicada."
printf 'BACKUP_BRANCH=%s\n' "$BACKUP_BRANCH"
printf 'COMMIT=%s\n' "$(git -C "$REPO_DIR" rev-parse HEAD)"
