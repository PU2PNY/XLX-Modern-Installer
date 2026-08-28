#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

readonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BACKUP_ROOT="/var/backups/xlx-reflector"
readonly CONFIRMATION="CONFIRMO_ATUALIZACAO_XLX_MODERN"

MODE="check"
DASHBOARD=""
SITE_CONFIG_SOURCE=""
PRESERVED_LOCAL_FILES=0
PRESERVED_INDEX=0
PRESERVED_EXTRA_ROUTES=""

RED=$'\033[31m'; YELLOW=$'\033[33m'; GREEN=$'\033[32m'; BLUE=$'\033[34m'; RESET=$'\033[0m'
info(){ printf '%s[INFO]%s %s\n' "$BLUE" "$RESET" "$*"; }
ok(){ printf '%s[OK]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn(){ printf '%s[ATENÇÃO]%s %s\n' "$YELLOW" "$RESET" "$*"; }
fatal(){ printf '%s[ERRO]%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }
section(){ printf '\n============================================================\n%s\n============================================================\n' "$*"; }

for arg in "$@"; do
    case "$arg" in
        --check|--dry-run) MODE="check" ;;
        --apply) MODE="apply" ;;
        --dashboard-dir=*) DASHBOARD="${arg#*=}" ;;
        --site-config=*) SITE_CONFIG_SOURCE="${arg#*=}" ;;
        -h|--help)
            cat <<'HELP'
XLX Modern Updater — dashboard existente

Uso:
  sudo bash update.sh --check
  sudo bash update.sh --check --dashboard-dir=/var/www/html/xlxd-novo
  sudo bash update.sh --apply --dashboard-dir=/var/www/html/xlx-dashboard

Opções:
  --check              Somente pré-validação. É o padrão.
  --apply              Publica o candidato após confirmação explícita.
  --dashboard-dir=DIR  Define o dashboard existente.
  --site-config=FILE   Usa um config/site.php já preparado para migrar um
                       dashboard legado que ainda não possua esse arquivo.

Proteções de compatibilidade:
- arquivos locais que não pertencem ao núcleo universal são preservados;
- se o index.php atual possuir rotas extras, o index.php local é preservado
  neste ciclo para impedir perda de páginas personalizadas;
- config/site.php é sempre tratado separadamente e validado.

O atualizador não executa git pull, não recompila o XLXD e não altera bancos
ou credenciais do APRS/D-PRS.
HELP
            exit 0
            ;;
        *) fatal "Opção desconhecida: $arg" ;;
    esac
done

[ "$(id -u)" -eq 0 ] || fatal "Execute como root."
[ -d "$ROOT_DIR/dashboard" ] || fatal "Fonte dashboard ausente: $ROOT_DIR/dashboard"

for cmd in bash find grep mv php rsync sha256sum sort tar; do
    command -v "$cmd" >/dev/null 2>&1 || fatal "Comando obrigatório ausente: $cmd"
done

resolve_dashboard(){
    local candidates=() d
    if [ -n "$DASHBOARD" ]; then
        [ -d "$DASHBOARD" ] || fatal "Dashboard não encontrado: $DASHBOARD"
        return
    fi

    for d in /var/www/html/xlx-dashboard /var/www/html/xlxd-novo; do
        [ -d "$d" ] && candidates+=("$d")
    done

    case "${#candidates[@]}" in
        0) fatal "Nenhum dashboard existente detectado." ;;
        1) DASHBOARD="${candidates[0]}" ;;
        *) fatal "Mais de um dashboard detectado. Informe --dashboard-dir=DIR para evitar ambiguidade." ;;
    esac
}

validate_site_config(){
    local file="$1"
    [ -f "$file" ] || fatal "Configuração do site ausente: $file"
    php -l "$file" >/dev/null
    php -r '
      $c=require $argv[1];
      if(!is_array($c)) exit(1);
      foreach([
        ["reflector","name"],
        ["reflector","title"],
        ["reflector","description"],
        ["reflector","sysop_callsign"],
        ["reflector","location"],
        ["reflector","country"],
        ["reflector","domain"],
        ["reflector","contact_email"],
        ["radio","reflector_number"],
        ["radio","reflector_short_number"],
        ["radio","ysf_id"],
        ["radio","dmr_tg"]
      ] as $p){
        if(trim((string)($c[$p[0]][$p[1]]??""))==="") exit(2);
      }
    ' "$file" || fatal "config/site.php incompleto ou inválido."
}

validate_source(){
    section "VALIDANDO FONTE DO UPDATE"
    while IFS= read -r -d '' file; do
        bash -n "$file"
    done < <(find "$ROOT_DIR" -maxdepth 3 -type f -name '*.sh' -print0)

    while IFS= read -r -d '' file; do
        php -l "$file" >/dev/null
    done < <(find "$ROOT_DIR/dashboard" -type f -name '*.php' -print0)

    if command -v node >/dev/null 2>&1; then
        while IFS= read -r -d '' file; do
            # Template JavaScript may contain installation placeholders that
            # are deliberately not valid identifier text before rendering.
            # The fully rendered candidate is validated with node --check in
            # build_candidate(), so raw template files are deferred here.
            if grep -Eq '\{\{[A-Z0-9_]+\}\}' "$file"; then
                continue
            fi
            node --check "$file" >/dev/null
        done < <(find "$ROOT_DIR/dashboard/assets" -type f -name '*.js' -print0)
    fi
    ok "Fonte validada."
}

extract_index_routes(){
    local file="$1"
    php -r '
      $s=@file_get_contents($argv[1]);
      if($s===false) exit(2);
      $allowed="\$allowed";
      if(!preg_match("/\\$allowed\\s*=\\s*\\[(.*?)\\]\\s*;/s",$s,$m)) exit(3);
      preg_match_all("/[\\x27\\x22]([a-z0-9][a-z0-9-]*)[\\x27\\x22]/i",$m[1],$x);
      foreach(array_values(array_unique($x[1])) as $r) echo $r,"\n";
    ' "$file"
}

preserve_local_extensions(){
    local work="$1"
    local before after current_routes candidate_routes route extra_routes=()

    [ -f "$DASHBOARD/index.php" ] || fatal "index.php atual ausente: $DASHBOARD/index.php"
    [ -f "$work/index.php" ] || fatal "index.php candidato ausente: $work/index.php"

    if ! candidate_routes="$(extract_index_routes "$work/index.php")"; then
        fatal "Não foi possível identificar as rotas do index.php do núcleo universal."
    fi

    if current_routes="$(extract_index_routes "$DASHBOARD/index.php" 2>/dev/null)"; then
        while IFS= read -r route; do
            [ -n "$route" ] || continue
            if ! grep -Fxq -- "$route" <<<"$candidate_routes"; then
                extra_routes+=("$route")
            fi
        done <<<"$current_routes"

        if [ "${#extra_routes[@]}" -gt 0 ]; then
            PRESERVED_EXTRA_ROUTES="$(IFS=,; printf '%s' "${extra_routes[*]}")"
            cp -a "$DASHBOARD/index.php" "$work/index.php"
            PRESERVED_INDEX=1
            warn "Rotas locais extras detectadas: $PRESERVED_EXTRA_ROUTES"
            warn "index.php atual preservado neste ciclo para impedir regressão funcional."
        fi
    else
        cp -a "$DASHBOARD/index.php" "$work/index.php"
        PRESERVED_INDEX=1
        PRESERVED_EXTRA_ROUTES="PARSE_INDISPONIVEL"
        warn "Não foi possível interpretar as rotas do index.php atual."
        warn "Por segurança, o index.php atual será preservado neste ciclo."
    fi

    before="$(find "$work" -type f | wc -l | tr -d ' ')"

    # Preserva somente arquivos/caminhos que não existem no candidato do núcleo.
    # Arquivos gerenciados pelo núcleo continuam vindo da nova versão.
    # config/site.php fica fora desta cópia porque é tratado e validado acima.
    rsync -a --ignore-existing \
        --exclude='.git/' \
        --exclude='config/site.php' \
        "$DASHBOARD/" "$work/"

    after="$(find "$work" -type f | wc -l | tr -d ' ')"
    PRESERVED_LOCAL_FILES=$((after-before))

    if [ "$PRESERVED_LOCAL_FILES" -gt 0 ]; then
        info "Arquivos locais exclusivos preservados: $PRESERVED_LOCAL_FILES"
    else
        info "Nenhum arquivo local exclusivo precisou ser preservado."
    fi
}

build_candidate(){
    local work="$1" site_config="$2" locale

    mkdir -p "$work"
    rsync -a --delete \
        --exclude='install/' \
        --exclude='config/site.php' \
        "$ROOT_DIR/dashboard/" "$work/"

    mkdir -p "$work/config"
    install -m 0640 -o root -g www-data "$site_config" "$work/config/site.php"

    locale="$(php -r '$c=require $argv[1]; echo (string)($c["locale"]["default"]??"pt-BR");' "$work/config/site.php")"
    case "$locale" in pt-BR|en|es|fr|de|it) ;; *) locale='pt-BR' ;; esac

    php "$work/i18n/build.php" "$work" "$locale"
    php "$ROOT_DIR/dashboard/install/render-placeholders.php" "$work"
    if [ -f "$ROOT_DIR/dashboard/install/render-template.php" ]; then
        php "$ROOT_DIR/dashboard/install/render-template.php" "$work"
    fi

    preserve_local_extensions "$work"

    find "$work" -type d -exec chmod 755 {} \;
    find "$work" -type f -exec chmod 644 {} \;
    chown -R root:www-data "$work"
    chmod 640 "$work/config/site.php"

    while IFS= read -r -d '' file; do
        php -l "$file" >/dev/null
    done < <(find "$work" -type f -name '*.php' -print0)

    if command -v node >/dev/null 2>&1; then
        while IFS= read -r -d '' file; do
            node --check "$file" >/dev/null
        done < <(find "$work/assets" -type f -name '*.js' -print0)
    fi

    # Os catálogos em i18n/locales são fonte de build e preservam placeholders
    # deliberadamente para futuras compilações. A verificação final deve seguir
    # a mesma exclusão usada pelo renderizador oficial.
    if grep -REn '\{\{[A-Z0-9_]+\}\}' "$work" \
        --exclude-dir='locales' \
        --include='*.php' --include='*.js' --include='*.css' --include='*.html' \
        --include='*.json' --include='*.xml' --include='*.txt' >/dev/null 2>&1
    then
        fatal "O candidato contém placeholders não resolvidos em arquivos publicáveis."
    fi
}

resolve_dashboard
section "XLX MODERN UPDATER"
info "Dashboard: $DASHBOARD"

CURRENT_SITE="$DASHBOARD/config/site.php"
if [ -n "$SITE_CONFIG_SOURCE" ]; then
    validate_site_config "$SITE_CONFIG_SOURCE"
    SITE_TO_USE="$SITE_CONFIG_SOURCE"
elif [ -f "$CURRENT_SITE" ]; then
    validate_site_config "$CURRENT_SITE"
    SITE_TO_USE="$CURRENT_SITE"
else
    warn "Dashboard legado detectado: config/site.php não existe."
    fatal "Nenhuma atualização será aplicada. Prepare um arquivo universal e repita com --site-config=FILE."
fi

validate_source

STAMP="$(date +%Y%m%d_%H%M%S)"
PARENT="$(dirname "$DASHBOARD")"
NAME="$(basename "$DASHBOARD")"
CANDIDATE="$PARENT/.${NAME}.candidate-${STAMP}"
OLD="$PARENT/.${NAME}.pre-update-${STAMP}"
BACKUP_DIR="$BACKUP_ROOT/dashboard-update-${STAMP}"
ARCHIVE="$BACKUP_DIR/${NAME}.tar.gz"

rm -rf "$CANDIDATE"
build_candidate "$CANDIDATE" "$SITE_TO_USE"
ok "Candidato construído e validado: $CANDIDATE"

CURRENT_INDEX_SHA="$(sha256sum "$DASHBOARD/index.php" | awk '{print $1}')"
CANDIDATE_INDEX_SHA="$(sha256sum "$CANDIDATE/index.php" | awk '{print $1}')"
info "index.php atual    : $CURRENT_INDEX_SHA"
info "index.php candidato: $CANDIDATE_INDEX_SHA"
info "arquivos locais preservados: $PRESERVED_LOCAL_FILES"
if [ "$PRESERVED_INDEX" -eq 1 ]; then
    warn "index.php local preservado; rotas extras: $PRESERVED_EXTRA_ROUTES"
fi

if [ "$MODE" = "check" ]; then
    rm -rf "$CANDIDATE"
    ok "Pré-validação concluída. Produção não foi alterada."
    echo "PRESERVED_LOCAL_FILES=$PRESERVED_LOCAL_FILES"
    echo "PRESERVED_INDEX=$PRESERVED_INDEX"
    echo "PRESERVED_EXTRA_ROUTES=$PRESERVED_EXTRA_ROUTES"
    echo "STATUS=UPDATE_CHECK_OK"
    exit 0
fi

printf '\nDigite exatamente para publicar:\n%s\n\n> ' "$CONFIRMATION"
read -r typed
[ "$typed" = "$CONFIRMATION" ] || { rm -rf "$CANDIDATE"; fatal "Confirmação incorreta. Nada foi publicado."; }

section "BACKUP"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
tar -C "$PARENT" -czpf "$ARCHIVE" "$NAME"
sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"
sha256sum -c "$ARCHIVE.sha256" >/dev/null

cat > "$BACKUP_DIR/ROLLBACK.sh" <<ROLLBACK
#!/usr/bin/env bash
set -Eeuo pipefail
DEST='$DASHBOARD'
PARENT='$PARENT'
ARCHIVE='$ARCHIVE'
STAMP="\$(date +%Y%m%d_%H%M%S)"
[ "\$(id -u)" -eq 0 ] || { echo 'Execute como root.' >&2; exit 1; }
sha256sum -c '\$ARCHIVE.sha256'
if [ -e "\$DEST" ]; then mv "\$DEST" "\$DEST.failed-\$STAMP"; fi
tar -C "\$PARENT" -xzpf "\$ARCHIVE"
echo 'ROLLBACK_OK'
ROLLBACK
chmod 700 "$BACKUP_DIR/ROLLBACK.sh"
ok "Backup verificado: $ARCHIVE"

section "PUBLICAÇÃO ATÔMICA"
[ ! -e "$OLD" ] || fatal "Caminho temporário inesperado já existe: $OLD"
mv "$DASHBOARD" "$OLD"
if ! mv "$CANDIDATE" "$DASHBOARD"; then
    mv "$OLD" "$DASHBOARD" || true
    fatal "Falha ao publicar candidato; restauração imediata tentada."
fi

post_fail=0
while IFS= read -r -d '' file; do
    php -l "$file" >/dev/null || post_fail=1
done < <(find "$DASHBOARD" -type f -name '*.php' -print0)

if command -v apache2ctl >/dev/null 2>&1; then
    apache2ctl configtest >/dev/null || post_fail=1
fi

if [ "$post_fail" -ne 0 ]; then
    warn "Validação pós-publicação falhou; revertendo imediatamente."
    rm -rf "$DASHBOARD.failed-${STAMP}"
    mv "$DASHBOARD" "$DASHBOARD.failed-${STAMP}"
    mv "$OLD" "$DASHBOARD"
    fatal "Rollback automático executado."
fi

FINAL_SHA="$(sha256sum "$DASHBOARD/index.php" | awk '{print $1}')"
[ "$FINAL_SHA" = "$CANDIDATE_INDEX_SHA" ] || {
    mv "$DASHBOARD" "$DASHBOARD.failed-${STAMP}"
    mv "$OLD" "$DASHBOARD"
    fatal "Hash final divergente; rollback automático executado."
}

rm -rf "$OLD"
ok "Dashboard atualizado e validado."
info "Backup : $ARCHIVE"
info "Rollback: sudo bash $BACKUP_DIR/ROLLBACK.sh"
echo "PRESERVED_LOCAL_FILES=$PRESERVED_LOCAL_FILES"
echo "PRESERVED_INDEX=$PRESERVED_INDEX"
echo "PRESERVED_EXTRA_ROUTES=$PRESERVED_EXTRA_ROUTES"
echo "STATUS=UPDATE_APPLY_OK"
