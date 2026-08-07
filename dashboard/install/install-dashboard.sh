#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 027

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/xlx-reflector}"
RANK_COLLECTOR_SRC="$ROOT/install/ranking-collector.py"
RANK_SERVICE_SRC="$ROOT/install/xlx-ranking.service"
RANK_TIMER_SRC="$ROOT/install/xlx-ranking.timer"
RANK_COLLECTOR_DST="/usr/local/sbin/xlx-ranking-collector.py"
RANK_SERVICE_DST="/etc/systemd/system/xlx-ranking.service"
RANK_TIMER_DST="/etc/systemd/system/xlx-ranking.timer"
RANK_DATA_DIR="/var/lib/xlx-ranking"
CACHE_DIR="/var/cache/xlx-dashboard"
MODE="install"

for arg in "$@"; do
    case "$arg" in
        --check|--dry-run) MODE="check" ;;
        -h|--help)
            cat <<'HELP'
XLX Modern Dashboard installer

Usage:
  sudo bash dashboard/install/install-dashboard.sh --check
  sudo bash dashboard/install/install-dashboard.sh

Optional environment variables:
  INSTALL_DIR           Override detected Apache/XLX dashboard directory.
  XLX_REFLECTOR         XLX identifier, for example XLX123 or XLXUS1.
  XLX_DOMAIN            Public FQDN.
  XLX_SYSOP_CALLSIGN    Sysop callsign.
  XLX_LOCATION          City / region used by the weather widget.
  XLX_COUNTRY           Country name.
  XLX_LOCALE            BCP-47 locale, default pt-BR.
  XLX_YSF_ID            Optional YSF reflector ID.
  XLX_DMR_TG            Optional DMR network TG.
  XLX_DMR_RADIO_TG      Optional DMR radio-side TG.
  XLX_DMR_MODULE        Optional default DMR module A-E.
  XLX_XML_PATH          Override XLXD XML status file.
  XLX_LOG_PATH          Override XLXD text log used by live/history API.
  XLX_USERS_DB          Override user database path.
HELP
            exit 0
            ;;
        *) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BLUE=$'\033[34m'; RESET=$'\033[0m'
info(){ printf '%s[INFO]%s %s\n' "$BLUE" "$RESET" "$*"; }
ok(){ printf '%s[OK]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn(){ printf '%s[ATTENTION]%s %s\n' "$YELLOW" "$RESET" "$*"; }
fatal(){ printf '%s[ERROR]%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }
section(){ printf '\n============================================================\n%s\n============================================================\n' "$*"; }

require_command(){ command -v "$1" >/dev/null 2>&1 || fatal "Required command missing: $1"; }

first_existing(){
    local path
    for path in "$@"; do
        if [ -e "$path" ]; then printf '%s' "$path"; return 0; fi
    done
    return 1
}

detect_destination(){
    if [ -n "${INSTALL_DIR:-}" ]; then
        printf '%s' "$INSTALL_DIR"
        return
    fi

    local candidate docroot
    for candidate in /var/www/html/xlxd /var/www/xlxd /var/www/html/xlx-dashboard; do
        if [ -d "$candidate" ]; then
            printf '%s' "$candidate"
            return
        fi
    done

    while IFS= read -r docroot; do
        [ -n "$docroot" ] || continue
        case "$docroot" in
            *xlx*|*XLX*)
                printf '%s' "$docroot"
                return
                ;;
        esac
    done < <(
        grep -RhsE '^[[:space:]]*DocumentRoot[[:space:]]+' /etc/apache2/sites-enabled 2>/dev/null \
            | awk '{print $2}' | tr -d '"' | sort -u
    )

    printf '%s' /var/www/html/xlxd
}

detect_reflector(){
    if [ -n "${XLX_REFLECTOR:-}" ]; then printf '%s' "$XLX_REFLECTOR"; return; fi
    local exec_line detected
    exec_line="$(systemctl show -p ExecStart --value xlxd 2>/dev/null || true)"
    detected="$(printf '%s\n' "$exec_line" | grep -oE 'XLX[A-Za-z0-9]{3}' | head -n1 || true)"
    if [ -n "$detected" ]; then printf '%s' "$detected"; return; fi
    grep -RhoE 'XLX[A-Za-z0-9]{3}' /etc/systemd/system/xlxd.service /lib/systemd/system/xlxd.service 2>/dev/null | head -n1 || true
}

detect_domain(){
    if [ -n "${XLX_DOMAIN:-}" ]; then printf '%s' "$XLX_DOMAIN"; return; fi
    grep -RhsE '^[[:space:]]*ServerName[[:space:]]+' /etc/apache2/sites-enabled 2>/dev/null \
        | awk '{print $2}' | grep -Ev '^(localhost|127\.)' | head -n1 || true
}

prompt_value(){
    local variable="$1" label="$2" default_value="${3:-}" allow_empty="${4:-no}" current=""
    current="${!variable:-}"
    if [ -n "$current" ]; then return; fi
    if [ "$MODE" = "check" ]; then printf -v "$variable" '%s' "$default_value"; return; fi
    if [ ! -t 0 ]; then
        if [ "$allow_empty" = "yes" ]; then printf -v "$variable" '%s' "$default_value"; return; fi
        [ -n "$default_value" ] || fatal "Missing required value: $variable"
        printf -v "$variable" '%s' "$default_value"
        return
    fi
    if [ -n "$default_value" ]; then
        read -r -p "$label [$default_value]: " current
        current="${current:-$default_value}"
    else
        read -r -p "$label: " current
    fi
    if [ "$allow_empty" != "yes" ] && [ -z "$current" ]; then
        fatal "$label cannot be empty."
    fi
    printf -v "$variable" '%s' "$current"
}

validate_reflector(){
    REFLECTOR="${REFLECTOR^^}"
    [[ "$REFLECTOR" =~ ^XLX[A-Z0-9]{3}$ ]] || fatal "Invalid XLX identifier: $REFLECTOR"
    REFLECTOR_CODE="${REFLECTOR:3:3}"
}

validate_domain(){
    DOMAIN="${DOMAIN#http://}"; DOMAIN="${DOMAIN#https://}"; DOMAIN="${DOMAIN%%/*}"
    [[ "$DOMAIN" =~ ^([A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]] \
        || fatal "Invalid public domain: $DOMAIN"
}

validate_module(){
    if [ -n "$DMR_MODULE" ]; then
        DMR_MODULE="${DMR_MODULE^^}"
        [[ "$DMR_MODULE" =~ ^[A-E]$ ]] || fatal "DMR module must be A, B, C, D, E, or empty."
    fi
}

install_dependencies(){
    local packages=() module
    command -v rsync >/dev/null 2>&1 || packages+=(rsync)
    command -v curl >/dev/null 2>&1 || packages+=(curl)
    command -v python3 >/dev/null 2>&1 || packages+=(python3)
    command -v php >/dev/null 2>&1 || packages+=(php-cli)

    if command -v php >/dev/null 2>&1; then
        for module in curl mbstring sqlite3; do
            php -m 2>/dev/null | grep -qiE "^${module}$" || packages+=("php-${module}")
        done
    fi

    if [ "${#packages[@]}" -eq 0 ]; then
        ok "Dashboard runtime dependencies are available."
        return
    fi

    if [ "$MODE" = "check" ]; then
        warn "Missing packages: ${packages[*]}"
        return
    fi

    info "Installing dashboard dependencies: ${packages[*]}"
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}"
}

validate_source_tree(){
    local file
    for file in \
        "$ROOT/index.php" \
        "$ROOT/config.php" \
        "$ROOT/config/site.example.json" \
        "$ROOT/config/developer.php" \
        "$ROOT/api/status.php" \
        "$ROOT/api/ranking-v2.php" \
        "$ROOT/ranking-v2-view.php" \
        "$RANK_COLLECTOR_SRC" \
        "$RANK_SERVICE_SRC" \
        "$RANK_TIMER_SRC"; do
        [ -f "$file" ] || fatal "Required dashboard source file missing: $file"
    done

    find "$ROOT" -path "$ROOT/install" -prune -o -type f -name '*.php' -print0 \
        | xargs -0 -r -n1 php -l >/dev/null
    python3 -m py_compile "$RANK_COLLECTOR_SRC"
    python3 "$RANK_COLLECTOR_SRC" --self-test >/dev/null

    if command -v node >/dev/null 2>&1; then
        find "$ROOT/assets" -type f -name '*.js' -print0 | xargs -0 -r -n1 node --check >/dev/null
    fi

    python3 -m json.tool "$ROOT/config/site.example.json" >/dev/null
    python3 -m json.tool "$ROOT/site.webmanifest" >/dev/null

    if find "$ROOT" -path "$ROOT/install" -prune -o -type f \( -iname '*support-native*' -o -iname '*ham-news*' \) -print | grep -q .; then
        fatal "Excluded Support/News implementation found in dashboard runtime source."
    fi
    ok "Dashboard source tree validated."
}

build_site_config(){
    local output="$1"
    python3 - "$output" "$REFLECTOR" "$REFLECTOR_CODE" "$DOMAIN" "$SYSOP" "$LOCATION" "$COUNTRY" "$LOCALE" "$YSF_ID" "$DMR_TG" "$DMR_RADIO_TG" "$DMR_MODULE" "$XML_PATH" "$LOG_PATH" "$USERS_DB" <<'PY'
import json, sys
from pathlib import Path
(
    output, reflector, code, domain, sysop, location, country, locale,
    ysf_id, dmr_tg, dmr_radio_tg, dmr_module, xml_path, log_path, users_db
) = sys.argv[1:]
modules = {}
for letter in "ABCDE":
    protocol = "D-STAR"
    module_dmr_tg = ""
    if dmr_module and letter == dmr_module:
        protocol = "DMR"
        module_dmr_tg = dmr_tg
    modules[letter] = {
        "name": f"Module {letter}",
        "protocol": protocol,
        "access": f"{reflector}-{letter}",
        "dmr_tg": module_dmr_tg,
        "ysf_dgid": "",
    }
config = {
    "server_name": reflector,
    "reflector_code": code,
    "domain": domain,
    "sysop_callsign": sysop,
    "location": location,
    "country": country,
    "locale": locale,
    "ysf_id": ysf_id,
    "dmr_tg": dmr_tg,
    "dmr_radio_tg": dmr_radio_tg,
    "dmr_default_module": dmr_module,
    "xml_path": xml_path,
    "log_path": log_path,
    "users_db": users_db,
    "ranking_json": "/var/lib/xlx-ranking/ranking.json",
    "history_limit": 30,
    "modules": modules,
}
path = Path(output)
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
}

build_manifest(){
    local manifest="$1"
    python3 - "$manifest" "$REFLECTOR" "$LOCALE" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
name = sys.argv[2]
locale = sys.argv[3]
data = json.loads(path.read_text(encoding="utf-8"))
data["name"] = f"{name} Modern Dashboard"
data["short_name"] = name
data["description"] = f"Modern dashboard for the {name} XLX reflector."
data["lang"] = locale
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
}

validate_staging(){
    local stage="$1" php_file
    php -r '$c=require $argv[1]; if(!is_array($c)||empty($c["server_name"])) exit(1);' "$stage/config.php"
    while IFS= read -r -d '' php_file; do php -l "$php_file" >/dev/null; done < <(find "$stage" -type f -name '*.php' -print0)
    if command -v node >/dev/null 2>&1; then
        find "$stage/assets" -type f -name '*.js' -print0 | xargs -0 -r -n1 node --check >/dev/null
    fi
    python3 -m json.tool "$stage/config/site.json" >/dev/null
    python3 -m json.tool "$stage/site.webmanifest" >/dev/null
    if find "$stage" -type f \( -iname '*support-native*' -o -iname '*ham-news*' \) -print | grep -q .; then
        fatal "Excluded local component found in staging."
    fi
}

check_apache_mapping(){
    local dest="$1" mapped="no" docroot
    while IFS= read -r docroot; do
        [ -n "$docroot" ] || continue
        [ "$(readlink -m "$docroot")" = "$(readlink -m "$dest")" ] && mapped="yes"
    done < <(
        grep -RhsE '^[[:space:]]*DocumentRoot[[:space:]]+' /etc/apache2/sites-enabled 2>/dev/null \
            | awk '{print $2}' | tr -d '"' | sort -u
    )
    if [ "$mapped" != "yes" ]; then
        warn "No enabled Apache DocumentRoot currently points exactly to $dest."
        warn "The dashboard will be installed there, but verify the vhost if the site does not open."
    fi
}

create_backup(){
    local dest="$1" backup="$2"
    mkdir -p "$backup"
    chmod 700 "$backup"
    if [ -d "$dest" ]; then
        tar -C "$(dirname "$dest")" -czpf "$backup/dashboard.tar.gz" "$(basename "$dest")"
        sha256sum "$backup/dashboard.tar.gz" > "$backup/dashboard.tar.gz.sha256"
        sha256sum -c "$backup/dashboard.tar.gz.sha256" >/dev/null
        printf '1\n' > "$backup/had-dashboard"
    else
        printf '0\n' > "$backup/had-dashboard"
    fi

    for spec in \
        "$RANK_COLLECTOR_DST:collector" \
        "$RANK_SERVICE_DST:service" \
        "$RANK_TIMER_DST:timer"; do
        local source="${spec%%:*}" name="${spec##*:}"
        if [ -f "$source" ]; then cp -a "$source" "$backup/$name"; printf '1\n' > "$backup/had-$name"; else printf '0\n' > "$backup/had-$name"; fi
    done

    if [ -d "$RANK_DATA_DIR" ]; then
        tar -C /var/lib -czpf "$backup/ranking-data.tar.gz" xlx-ranking
        sha256sum "$backup/ranking-data.tar.gz" > "$backup/ranking-data.tar.gz.sha256"
        sha256sum -c "$backup/ranking-data.tar.gz.sha256" >/dev/null
        printf '1\n' > "$backup/had-ranking-data"
    else
        printf '0\n' > "$backup/had-ranking-data"
    fi
    ok "Backup created and verified: $backup"
}

write_rollback(){
    local dest="$1" backup="$2" rollback="$backup/rollback.sh"
    cat > "$rollback" <<ROLLBACK
#!/usr/bin/env bash
set -Eeuo pipefail
DEST=$(printf '%q' "$dest")
BACKUP=$(printf '%q' "$backup")
rm -rf "\$DEST"
if [ "\$(cat "\$BACKUP/had-dashboard")" = "1" ]; then
  tar -C "\$(dirname "\$DEST")" -xzpf "\$BACKUP/dashboard.tar.gz"
fi
restore_file(){
  local marker="\$1" saved="\$2" target="\$3"
  if [ "\$(cat "\$BACKUP/had-\$marker")" = "1" ]; then
    install -o root -g root -m 0644 "\$BACKUP/\$saved" "\$target"
  else
    rm -f "\$target"
  fi
}
if [ "\$(cat "\$BACKUP/had-collector")" = "1" ]; then
  install -o root -g root -m 0755 "\$BACKUP/collector" "$RANK_COLLECTOR_DST"
else
  rm -f "$RANK_COLLECTOR_DST"
fi
restore_file service service "$RANK_SERVICE_DST"
restore_file timer timer "$RANK_TIMER_DST"
rm -rf "$RANK_DATA_DIR"
if [ "\$(cat "\$BACKUP/had-ranking-data")" = "1" ]; then
  tar -C /var/lib -xzpf "\$BACKUP/ranking-data.tar.gz"
fi
systemctl daemon-reload
if [ -f "$RANK_TIMER_DST" ]; then systemctl enable --now xlx-ranking.timer >/dev/null 2>&1 || true; fi
apache2ctl configtest
printf '[OK] Dashboard rollback completed.\n'
ROLLBACK
    chmod 700 "$rollback"
    printf '%s' "$rollback"
}

post_install_validate(){
    local dest="$1"
    find "$dest" -type f -name '*.php' -print0 | xargs -0 -r -n1 php -l >/dev/null
    python3 "$RANK_COLLECTOR_DST" --self-test >/dev/null
    systemctl start xlx-ranking.service
    systemctl enable --now xlx-ranking.timer >/dev/null
    systemctl is-active --quiet xlx-ranking.timer || fatal "Ranking timer is not active."
    [ -s "$RANK_DATA_DIR/ranking.json" ] || fatal "Ranking JSON was not generated."
    python3 -m json.tool "$RANK_DATA_DIR/ranking.json" >/dev/null
    apache2ctl configtest >/dev/null
    systemctl is-active --quiet apache2 || fatal "Apache is not active."
    systemctl is-active --quiet xlxd || fatal "XLXD is not active."
}

main(){
    section "XLX MODERN DASHBOARD — GLOBAL INSTALLER"
    [ "$(id -u)" -eq 0 ] || fatal "Run as root."

    for command_name in bash grep awk sed find tar sha256sum systemctl apache2ctl readlink; do require_command "$command_name"; done
    install_dependencies
    for command_name in rsync php python3; do require_command "$command_name"; done

    [ -d "$ROOT" ] || fatal "Dashboard source directory not found."
    systemctl is-active --quiet xlxd || fatal "XLXD must be active before installing the dashboard."
    systemctl is-active --quiet apache2 || fatal "Apache must be active before installing the dashboard."
    apache2ctl configtest >/dev/null || fatal "Apache configuration is invalid before installation."

    validate_source_tree

    DEST="$(detect_destination)"
    REFLECTOR="$(detect_reflector)"
    DOMAIN="$(detect_domain)"
    SYSOP="${XLX_SYSOP_CALLSIGN:-}"
    LOCATION="${XLX_LOCATION:-}"
    COUNTRY="${XLX_COUNTRY:-}"
    LOCALE="${XLX_LOCALE:-pt-BR}"
    YSF_ID="${XLX_YSF_ID:-}"
    DMR_TG="${XLX_DMR_TG:-}"
    DMR_RADIO_TG="${XLX_DMR_RADIO_TG:-}"
    DMR_MODULE="${XLX_DMR_MODULE:-}"
    XML_PATH="${XLX_XML_PATH:-$(first_existing /var/log/xlxd.xml /tmp/xlxd.xml /xlxd/xlxd.xml 2>/dev/null || true)}"
    LOG_PATH="${XLX_LOG_PATH:-$(first_existing /var/log/xlx.log /var/log/xlxd.log /xlxd/xlxd.log 2>/dev/null || true)}"
    USERS_DB="${XLX_USERS_DB:-$(first_existing /xlxd/users_db/users.db /xlxd/users.db 2>/dev/null || true)}"

    prompt_value REFLECTOR "XLX reflector identifier" "${REFLECTOR:-XLX000}"
    prompt_value DOMAIN "Public domain" "${DOMAIN:-}"
    prompt_value SYSOP "Sysop callsign" "${SYSOP:-N0CALL}"
    prompt_value LOCATION "City / region" "${LOCATION:-City / Region}"
    prompt_value COUNTRY "Country" "${COUNTRY:-Country}"
    prompt_value LOCALE "Locale" "${LOCALE:-pt-BR}"
    prompt_value YSF_ID "YSF ID (optional)" "${YSF_ID:-}" yes
    prompt_value DMR_TG "DMR TG (optional)" "${DMR_TG:-}" yes
    prompt_value DMR_RADIO_TG "DMR radio-side TG (optional)" "${DMR_RADIO_TG:-}" yes
    prompt_value DMR_MODULE "Default DMR module A-E (optional)" "${DMR_MODULE:-}" yes
    prompt_value XML_PATH "XLXD XML status path" "${XML_PATH:-/var/log/xlxd.xml}"
    prompt_value LOG_PATH "XLXD text log path" "${LOG_PATH:-/var/log/xlx.log}"
    prompt_value USERS_DB "XLXD users database" "${USERS_DB:-/xlxd/users_db/users.db}"

    validate_reflector
    validate_domain
    validate_module
    check_apache_mapping "$DEST"

    section "INSTALLATION PLAN"
    printf 'Dashboard destination : %s\n' "$DEST"
    printf 'Reflector             : %s\n' "$REFLECTOR"
    printf 'Domain                : %s\n' "$DOMAIN"
    printf 'Sysop                 : %s\n' "$SYSOP"
    printf 'Location              : %s\n' "$LOCATION"
    printf 'Country / locale      : %s / %s\n' "$COUNTRY" "$LOCALE"
    printf 'Ranking               : persistent SQLite + systemd timer every 2 minutes\n'
    printf 'Excluded              : private Support and country-specific News modules\n'
    printf 'Developer credit      : PU2PNY · Página Certa Digital\n'

    if [ "$MODE" = "check" ]; then
        ok "Preflight completed. No dashboard files were changed."
        exit 0
    fi

    STAMP="$(date +%Y%m%d_%H%M%S)"
    BACKUP="$BACKUP_ROOT/dashboard-$STAMP"
    STAGE="$(mktemp -d /tmp/xlx-dashboard-stage.XXXXXX)"
    NEW_DEST="${DEST}.new-${STAMP}"
    PREVIOUS_DEST="${DEST}.previous-${STAMP}"
    SWAPPED="no"

    cleanup(){ rm -rf "$STAGE" "$NEW_DEST"; }
    rollback_on_error(){
        local rc=$?
        if [ "$SWAPPED" = "yes" ]; then
            warn "Installation failed after publication; restoring previous dashboard automatically."
            rm -rf "$DEST"
            if [ -d "$PREVIOUS_DEST" ]; then mv "$PREVIOUS_DEST" "$DEST"; fi
        fi
        cleanup
        exit "$rc"
    }
    trap rollback_on_error ERR INT TERM
    trap cleanup EXIT

    section "STAGING"
    rsync -a --delete \
        --exclude='install/' \
        --exclude='config/site.json' \
        --exclude='config/site.example.json' \
        "$ROOT/" "$STAGE/"
    mkdir -p "$STAGE/config"
    build_site_config "$STAGE/config/site.json"
    build_manifest "$STAGE/site.webmanifest"
    validate_staging "$STAGE"
    ok "Staging validated. Production dashboard has not been changed yet."

    section "BACKUP"
    create_backup "$DEST" "$BACKUP"
    ROLLBACK_SCRIPT="$(write_rollback "$DEST" "$BACKUP")"

    section "PUBLISH DASHBOARD"
    rm -rf "$NEW_DEST" "$PREVIOUS_DEST"
    mkdir -p "$NEW_DEST"
    rsync -a --delete "$STAGE/" "$NEW_DEST/"
    find "$NEW_DEST" -type d -exec chmod 0755 {} +
    find "$NEW_DEST" -type f -exec chmod 0644 {} +
    chown -R root:www-data "$NEW_DEST"
    chmod 0640 "$NEW_DEST/config/site.json"

    if [ -d "$DEST" ]; then mv "$DEST" "$PREVIOUS_DEST"; fi
    mv "$NEW_DEST" "$DEST"
    SWAPPED="yes"

    install -d -o www-data -g www-data -m 0750 "$CACHE_DIR"
    install -d -o root -g root -m 0755 "$RANK_DATA_DIR"
    install -o root -g root -m 0755 "$RANK_COLLECTOR_SRC" "$RANK_COLLECTOR_DST"
    install -o root -g root -m 0644 "$RANK_SERVICE_SRC" "$RANK_SERVICE_DST"
    install -o root -g root -m 0644 "$RANK_TIMER_SRC" "$RANK_TIMER_DST"
    systemctl daemon-reload

    section "POST-INSTALL VALIDATION"
    post_install_validate "$DEST"

    SWAPPED="no"
    rm -rf "$PREVIOUS_DEST"
    trap - ERR INT TERM
    cleanup

    section "INSTALLATION COMPLETE"
    ok "XLX Modern Dashboard installed and validated."
    ok "Ranking V2 collector and timer are active."
    info "Backup: $BACKUP"
    info "Rollback: sudo bash $ROLLBACK_SCRIPT"
    info "Dashboard: https://$DOMAIN/"
}

main "$@"
