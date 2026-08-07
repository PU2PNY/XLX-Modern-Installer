#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

SOURCE_PANEL="${SOURCE_PANEL:-/var/www/html/xlxd-novo}"
REPO_DIR="${REPO_DIR:-/root/XLX-Modern-Installer}"
TARGET_BRANCH="${TARGET_BRANCH:-release/global-dashboard-v1}"
BACKUP_DIR="${BACKUP_DIR:-/root/xlx-modern-dashboard-backups}"
STAMP="$(date +%Y%m%d_%H%M%S)"
STAGE="/root/xlx-global-dashboard-stage-${STAMP}"
DASHBOARD_DIR="${REPO_DIR}/dashboard"
REPORT="${REPO_DIR}/dashboard-publication-report.txt"

red=$'\033[31m'; green=$'\033[32m'; yellow=$'\033[33m'; blue=$'\033[34m'; reset=$'\033[0m'
info(){ printf '%s[INFO]%s %s\n' "$blue" "$reset" "$*"; }
ok(){ printf '%s[OK]%s %s\n' "$green" "$reset" "$*"; }
warn(){ printf '%s[ATENCAO]%s %s\n' "$yellow" "$reset" "$*"; }
fatal(){ printf '%s[ERRO]%s %s\n' "$red" "$reset" "$*" >&2; exit 1; }

cleanup(){ rm -rf "$STAGE"; }
trap cleanup EXIT

[ "$(id -u)" -eq 0 ] || fatal "Execute como root."
[ -d "$SOURCE_PANEL" ] || fatal "Painel de origem nao encontrado: $SOURCE_PANEL"
[ -d "$REPO_DIR/.git" ] || fatal "Repositorio local nao encontrado: $REPO_DIR"

for cmd in git rsync tar sha256sum python3 grep find php; do
  command -v "$cmd" >/dev/null 2>&1 || fatal "Comando ausente: $cmd"
done

info "Validando producao em modo somente leitura."
php -l "$SOURCE_PANEL/index.php" >/dev/null
[ "$(systemctl is-active xlxd 2>/dev/null || true)" = "active" ] || fatal "XLXD nao esta ativo."
[ "$(systemctl is-active apache2 2>/dev/null || true)" = "active" ] || fatal "Apache nao esta ativo."
ok "Producao valida. Nenhum arquivo sera modificado no painel em execucao."

info "Atualizando apenas o clone Git local."
git -C "$REPO_DIR" fetch --prune origin
git -C "$REPO_DIR" checkout "$TARGET_BRANCH"
git -C "$REPO_DIR" reset --hard "origin/$TARGET_BRANCH"

mkdir -p "$BACKUP_DIR"
if [ -d "$DASHBOARD_DIR" ]; then
  BACKUP_FILE="$BACKUP_DIR/github-dashboard-${STAMP}.tar.gz"
  tar -C "$REPO_DIR" -czpf "$BACKUP_FILE" dashboard
  sha256sum "$BACKUP_FILE" > "$BACKUP_FILE.sha256"
  sha256sum -c "$BACKUP_FILE.sha256" >/dev/null
  ok "Backup da copia Git atual: $BACKUP_FILE"
fi

mkdir -p "$STAGE/dashboard"

info "Copiando producao para area temporaria; origem permanece intocada."
rsync -a \
  --exclude='.git/' \
  --exclude='.env' --exclude='.env.*' \
  --exclude='*.log' --exclude='*.db' --exclude='*.sqlite' --exclude='*.sqlite3' \
  --exclude='*.pid' --exclude='*.sock' \
  --exclude='*.bak' --exclude='*.backup' \
  --exclude='cache/' --exclude='tmp/' --exclude='temp/' --exclude='sessions/' \
  --exclude='node_modules/' \
  --exclude='support-native.php' --exclude='support.php' --exclude='suporte.php' \
  --exclude='api/ham-news.php' \
  --exclude='assets/ham-news-widget.css' --exclude='assets/ham-news-widget.js' \
  "$SOURCE_PANEL/" "$STAGE/dashboard/"

info "Removendo componentes exclusivos do XLX026 da copia temporaria."
rm -f \
  "$STAGE/dashboard/support-native.php" \
  "$STAGE/dashboard/support.php" \
  "$STAGE/dashboard/suporte.php" \
  "$STAGE/dashboard/api/ham-news.php" \
  "$STAGE/dashboard/assets/ham-news-widget.css" \
  "$STAGE/dashboard/assets/ham-news-widget.js"

python3 - "$STAGE/dashboard" <<'PY'
import json,re,sys
from pathlib import Path

root=Path(sys.argv[1])
exts={'.php','.html','.htm','.js','.jsx','.ts','.tsx','.css','.scss','.json','.xml','.md','.txt','.yml','.yaml','.conf','.ini','.webmanifest'}

# Primeiro remove blocos de pagina locais no index, com verificacao forte.
index=root/'index.php'
if not index.exists():
    raise SystemExit('[ERRO] index.php ausente na copia')
s=index.read_text(encoding='utf-8')

# Remove slugs de listas simples e itens de navegacao/SEO em linha.
s=re.sub(r"(['\"])(suporte|noticias)\1\s*,?",'',s,flags=re.I)
s=re.sub(r"(?m)^\s*['\"](?:suporte|noticias)['\"]\s*=>.*?\n",'',s,flags=re.I)

# Remove blocos elseif completos para suporte/noticias quando existirem.
# O lookahead para no proximo elseif/else/endif do mesmo template.
for slug in ('suporte','noticias'):
    rx=re.compile(
        r"<\?php\s+elseif\s*\(\$page\s*===\s*['\"]"+slug+r"['\"]\)\s*:\s*\?>.*?"
        r"(?=<\?php\s+(?:elseif|else|endif)\b)",
        re.I|re.S,
    )
    s,n=rx.subn('',s)
    if n>1:
        raise SystemExit(f'[ERRO] Estrutura inesperada: {n} blocos {slug}')

# Remove inclusoes/scripts condicionais residuais dessas paginas.
s=re.sub(r"<\?php\s+if\s*\(\$page\s*===\s*['\"]suporte['\"]\)\s*:\s*\?>.*?<\?php\s+endif;?\s*\?>",'',s,flags=re.I|re.S)
s=re.sub(r"<\?php\s+if\s*\(\$page\s*===\s*['\"]noticias['\"]\)\s*:\s*\?>.*?<\?php\s+endif;?\s*\?>",'',s,flags=re.I|re.S)

# Se o template antigo terminava em `else => suporte`, nao publicamos silenciosamente.
if re.search(r"include\s+__DIR__\s*\.\s*['\"]/support-native\.php",s,re.I):
    raise SystemExit('[ERRO] index.php ainda depende de support-native.php; ajuste estrutural manual necessario')

index.write_text(s,encoding='utf-8')

# Sanitizacao internacional: nunca altera producao, somente a copia de publicacao.
repls=[
    (re.compile(r'XLX026\s+Brasil',re.I),'{{REFLECTOR_TITLE}}'),
    (re.compile(r'XLX026D?',re.I),'{{REFLECTOR_NAME}}'),
    (re.compile(r'XRF026',re.I),'{{XRF_NAME}}'),
    (re.compile(r'PU2PNY',re.I),'{{SYSOP_CALLSIGN}}'),
    (re.compile(r'xlx026\.net',re.I),'{{DOMAIN}}'),
    (re.compile(r'Santa\s+Isabel\s*(?:[-–—]\s*)?SP',re.I),'{{LOCATION}}'),
    (re.compile(r'https?://t\.me/xlx026_connection_state',re.I),''),
    (re.compile(r'xlx026_reflectors_cache_v1',re.I),'xlx_reflectors_cache_v1'),
    (re.compile(r'xlx026_pwa_install_decision_v1',re.I),'xlx_pwa_install_decision_v1'),
]

for p in root.rglob('*'):
    if not p.is_file() or p.suffix.lower() not in exts:
        continue
    try:
        text=p.read_text(encoding='utf-8')
    except UnicodeDecodeError:
        continue
    original=text
    for rx,val in repls:
        text=rx.sub(val,text)
    if text!=original:
        p.write_text(text,encoding='utf-8')

# Manifesto PWA sem identidade brasileira fixa.
manifest=root/'site.webmanifest'
if manifest.exists():
    try:
        data=json.loads(manifest.read_text(encoding='utf-8'))
    except Exception:
        data={}
    data['name']='{{REFLECTOR_TITLE}}'
    data['short_name']='{{REFLECTOR_NAME}}'
    data['description']='{{REFLECTOR_DESCRIPTION}}'
    manifest.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
PY

# Arquivos locais exclusivos nunca entram na distribuicao global.
find "$STAGE/dashboard" -type f \( \
  -iname '*support*' -o -iname '*suporte*' -o -iname '*ham-news*' -o -iname '*noticia*' \
\) -print -delete

# Nao distribuir logo especifico do refletor de producao.
find "$STAGE/dashboard/assets" -maxdepth 1 -type f \( -iname '*xlx026*' -o -iname '*026*logo*' \) -delete 2>/dev/null || true

info "Executando auditoria de privacidade e internacionalizacao."
: > "$REPORT"
grep -RniE --binary-files=without-match \
  --exclude='dashboard-publication-report.txt' \
  '(XLX026|XRF026|PU2PNY|xlx026\.net|Santa[[:space:]]+Isabel|t\.me/xlx026_connection_state|BEGIN[[:space:]]+(RSA|OPENSSH|EC)[[:space:]]+PRIVATE[[:space:]]+KEY|authorization:[[:space:]]*bearer|password[[:space:]]*[=:][[:space:]]*[^<{[:space:]]+)' \
  "$STAGE/dashboard" > "$REPORT" 2>/dev/null || true

if [ -s "$REPORT" ]; then
  cat "$REPORT"
  fatal "Publicacao bloqueada: foram encontrados dados especificos ou potencialmente privados."
fi

# Suporte e noticias devem estar totalmente ausentes do pacote global.
FORBIDDEN_LOCAL_REGEX="support-native|ham-news|page.?=.?(suporte|noticias)|[\"'](suporte|noticias)[\"'][[:space:]]*=>"
if grep -RniE --binary-files=without-match \
  "$FORBIDDEN_LOCAL_REGEX" \
  "$STAGE/dashboard" >/tmp/xlx-global-forbidden-${STAMP}.txt 2>/dev/null; then
  cat /tmp/xlx-global-forbidden-${STAMP}.txt
  rm -f /tmp/xlx-global-forbidden-${STAMP}.txt
  fatal "Publicacao bloqueada: referencias a Suporte ou Noticias permanecem."
fi
rm -f /tmp/xlx-global-forbidden-${STAMP}.txt

info "Validando PHP e JavaScript copiados."
find "$STAGE/dashboard" -type f -name '*.php' -print0 | xargs -0 -r -n1 php -l >/dev/null
if command -v node >/dev/null 2>&1; then
  find "$STAGE/dashboard" -type f -name '*.js' -print0 | xargs -0 -r -n1 node --check >/dev/null
else
  warn "Node.js ausente; validacao de sintaxe JS sera feita posteriormente pelo CI/navegador."
fi

# O Ranking V2 deve estar presente na copia atualizada.
[ -f "$STAGE/dashboard/ranking-v2-view.php" ] || fatal "Ranking V2 atual nao encontrado na producao."
[ -f "$STAGE/dashboard/api/ranking-v2.php" ] || fatal "API Ranking V2 atual nao encontrada na producao."

info "Promovendo somente a copia validada para dashboard/ no clone Git."
rm -rf "$DASHBOARD_DIR"
mkdir -p "$DASHBOARD_DIR"
rsync -a --delete "$STAGE/dashboard/" "$DASHBOARD_DIR/"

# Preserva instalador generico do dashboard mantido pelo repositorio.
git -C "$REPO_DIR" checkout "origin/$TARGET_BRANCH" -- dashboard/install dashboard/config 2>/dev/null || true

# Confirma novamente que o staging Git nao contem as paginas excluidas.
if grep -RniE --binary-files=without-match \
  "$FORBIDDEN_LOCAL_REGEX" \
  "$DASHBOARD_DIR" >/dev/null 2>&1; then
  fatal "Copia Git ainda contem referencias locais proibidas."
fi

find "$DASHBOARD_DIR" -type f -name '*.php' -print0 | xargs -0 -r -n1 php -l >/dev/null

git -C "$REPO_DIR" add dashboard
git -C "$REPO_DIR" config user.name "Dario PU2PNY"
git -C "$REPO_DIR" config user.email "pu2pny@users.noreply.github.com"

if git -C "$REPO_DIR" diff --cached --quiet; then
  ok "Dashboard global ja esta sincronizado; nenhuma alteracao para commit."
  exit 0
fi

info "Resumo das alteracoes que serao publicadas na branch:"
git -C "$REPO_DIR" diff --cached --stat

git -C "$REPO_DIR" commit -m "Atualiza dashboard global a partir da producao validada"
git -C "$REPO_DIR" push origin "$TARGET_BRANCH"

ok "Dashboard global publicado na branch $TARGET_BRANCH."
ok "Painel de producao nao foi modificado."
info "Proximo passo: revisar diff/PR antes de qualquer merge na main."
