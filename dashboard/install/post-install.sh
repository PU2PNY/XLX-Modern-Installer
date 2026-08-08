#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

DEST="${INSTALL_DIR:-/var/www/html/xlx-dashboard}"
APP="$DEST/assets/app.js"
PROJECT_LINK="$DEST/assets/project-link.js"
MARKER='XLX_PROJECT_LINK_BUNDLE_V1'

[ -d "$DEST" ] || { echo "ERROR / ERRO: dashboard not found / painel não encontrado: $DEST" >&2; exit 1; }
[ -f "$APP" ] || { echo "ERROR / ERRO: app.js not found: $APP" >&2; exit 1; }
[ -f "$PROJECT_LINK" ] || { echo "ERROR / ERRO: project-link.js not found: $PROJECT_LINK" >&2; exit 1; }

if ! grep -Fq "$MARKER" "$APP"; then
    {
        printf '\n;/* %s */\n' "$MARKER"
        cat "$PROJECT_LINK"
        printf '\n'
    } >> "$APP"
fi

printf 'GitHub dashboard link integration: OK\n'
