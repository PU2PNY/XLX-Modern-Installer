#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077
# CI validation marker: CONTROL_V2_PERMISSION_FIX

V1_COMMIT="e342cb5a48f87bb7018489478774fe706fb040d2"
V1_BLOB="7430cfc0293fb55335fcdfea298b2a260cda9378"
V1_URL="https://raw.githubusercontent.com/PU2PNY/XLX-Modern-Installer/${V1_COMMIT}/ops/root/install-xlx026-control-v1.sh"

TMP="$(mktemp -d /tmp/xlx026-control-v2.XXXXXX)"
V1="$TMP/install-v1.sh"
V2="$TMP/install-v2-patched.sh"
trap 'rm -rf "$TMP"' EXIT

ok(){ printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
fail(){ printf '\033[0;31m[ERRO]\033[0m %s\n' "$*" >&2; }
section(){ printf '\n======================================================================\n%s\n======================================================================\n' "$*"; }

[[ "$(id -u)" -eq 0 ]] || { fail "execute como root"; exit 1; }
for c in bash curl git grep python3; do command -v "$c" >/dev/null 2>&1 || { fail "comando ausente: $c"; exit 2; }; done

section "1/4 — VALIDAR INSTALADOR V1 IMUTÁVEL"
curl --fail --silent --show-error --location --connect-timeout 10 --max-time 60 "$V1_URL" -o "$V1"
GOT="$(git hash-object "$V1")"
echo "v1_blob_expected=$V1_BLOB"
echo "v1_blob_obtained=$GOT"
[[ "$GOT" == "$V1_BLOB" ]] || { fail "V1 divergente"; exit 10; }
bash -n "$V1"
ok "V1 íntegra"

section "2/4 — APLICAR CORREÇÃO DETERMINÍSTICA DE PERMISSÃO"
python3 - "$V1" "$V2" <<'PY'
import sys
src,dst=sys.argv[1:]
text=open(src,encoding='utf-8').read()
old='mkdir -p "$CONTROL_DIR" "$CFG_DIR" "$STATE_DIR"\ninstall -o root -g root -m 0644 "$INDEX_SRC" "$CONTROL_DIR/index.php"'
new='install -d -o root -g root -m 0755 "$CONTROL_DIR"\nmkdir -p "$CFG_DIR" "$STATE_DIR"\ninstall -o root -g root -m 0644 "$INDEX_SRC" "$CONTROL_DIR/index.php"'
count=text.count(old)
if count != 1:
    raise SystemExit(f'[ERRO] ponto de patch inesperado: count={count}')
text=text.replace(old,new,1)
open(dst,'w',encoding='utf-8',newline='').write(text)
PY
bash -n "$V2"
grep -Fq 'install -d -o root -g root -m 0755 "$CONTROL_DIR"' "$V2"
if grep -Fq 'mkdir -p "$CONTROL_DIR" "$CFG_DIR" "$STATE_DIR"' "$V2"; then
  fail "linha antiga de criação do diretório ainda presente"
  exit 20
fi
ok "Correção 0755 preparada; configuração privada permanece separada"

section "3/4 — EXECUTAR INSTALAÇÃO COMPLETA CORRIGIDA"
bash "$V2"

section "4/4 — VALIDAR PERMISSÃO E URL"
MODE="$(stat -c '%a' /var/www/html/xlxd-novo/controle)"
OWNER="$(stat -c '%U:%G' /var/www/html/xlxd-novo/controle)"
echo "control_dir_mode=$MODE"
echo "control_dir_owner=$OWNER"
[[ "$MODE" == "755" ]] || { fail "permissão inesperada em /controle: $MODE"; exit 30; }
[[ "$OWNER" == "root:root" ]] || { fail "dono inesperado em /controle: $OWNER"; exit 31; }
CODE="$(curl --silent --show-error --location --connect-timeout 8 --max-time 25 -o "$TMP/final.html" -w '%{http_code}' https://xlx026.net/controle/)"
echo "control_http=$CODE"
[[ "$CODE" == "200" ]] || { fail "/controle/ não retornou HTTP 200 após instalação"; exit 32; }
grep -Fq 'Controle XLX026' "$TMP/final.html" || { fail "assinatura da página ausente"; exit 33; }
grep -Fq 'Acesso restrito' "$TMP/final.html" || { fail "tela de login ausente"; exit 34; }
ok "CONTROLE XLX026 V2 INSTALADO E ACESSÍVEL"
echo "url=https://xlx026.net/controle/"
