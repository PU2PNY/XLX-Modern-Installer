#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

V1_COMMIT="e342cb5a48f87bb7018489478774fe706fb040d2"
V1_BLOB="7430cfc0293fb55335fcdfea298b2a260cda9378"
V1_URL="https://raw.githubusercontent.com/PU2PNY/XLX-Modern-Installer/${V1_COMMIT}/ops/root/install-xlx026-control-v1.sh"
CONTROL_USERNAME="queuspa"

TMP="$(mktemp -d /tmp/xlx026-control-v3.XXXXXX)"
V1="$TMP/install-v1.sh"
V3="$TMP/install-v3-patched.sh"
trap 'unset XLX026_CONTROL_PASSWORD 2>/dev/null || true; rm -rf "$TMP"' EXIT

ok(){ printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[ATENÇÃO]\033[0m %s\n' "$*"; }
fail(){ printf '\033[0;31m[ERRO]\033[0m %s\n' "$*" >&2; }
section(){ printf '\n======================================================================\n%s\n======================================================================\n' "$*"; }

[[ "$(id -u)" -eq 0 ]] || { fail "execute como root"; exit 1; }
for c in bash curl git grep php python3 stat; do command -v "$c" >/dev/null 2>&1 || { fail "comando ausente: $c"; exit 2; }; done

section "1/5 — CREDENCIAL LOCAL"
if [[ -z "${XLX026_CONTROL_PASSWORD:-}" ]]; then
  printf 'Digite a senha escolhida para o usuário %s: ' "$CONTROL_USERNAME" >&2
  IFS= read -r -s XLX026_CONTROL_PASSWORD
  printf '\n' >&2
fi
[[ ${#XLX026_CONTROL_PASSWORD} -ge 10 ]] || { fail "senha deve ter ao menos 10 caracteres"; exit 3; }
export XLX026_CONTROL_PASSWORD
ok "Usuário definido: $CONTROL_USERNAME"
ok "Senha recebida localmente e não será gravada no GitHub nem exibida"

section "2/5 — VALIDAR V1 IMUTÁVEL"
curl --fail --silent --show-error --location --connect-timeout 10 --max-time 60 "$V1_URL" -o "$V1"
GOT="$(git hash-object "$V1")"
echo "v1_blob_expected=$V1_BLOB"
echo "v1_blob_obtained=$GOT"
[[ "$GOT" == "$V1_BLOB" ]] || { fail "V1 divergente"; exit 10; }
bash -n "$V1"
ok "V1 íntegra"

section "3/5 — APLICAR PATCH DETERMINÍSTICO V3"
python3 - "$V1" "$V3" "$CONTROL_USERNAME" <<'PY'
import sys
src,dst,username=sys.argv[1:]
text=open(src,encoding='utf-8').read()
patches=[
(
 'USERNAME="xlx026"',
 f'USERNAME="{username}"'
),
(
 'mkdir -p "$CONTROL_DIR" "$CFG_DIR" "$STATE_DIR"\ninstall -o root -g root -m 0644 "$INDEX_SRC" "$CONTROL_DIR/index.php"',
 'install -d -o root -g root -m 0755 "$CONTROL_DIR"\nmkdir -p "$CFG_DIR" "$STATE_DIR"\ninstall -o root -g root -m 0644 "$INDEX_SRC" "$CONTROL_DIR/index.php"'
),
(
 'PASSWORD="$(openssl rand -hex 12)"',
 '[[ -n "${XLX026_CONTROL_PASSWORD:-}" ]] || { fail "senha local ausente"; exit 29; }\nPASSWORD="$XLX026_CONTROL_PASSWORD"'
),
(
 "printf 'action=login&username=%s&password=%s' \"$USERNAME\" \"$PASSWORD\" > \"$POST\"; chmod 0600 \"$POST\"",
 "printf '%s' \"$PASSWORD\" | php -r '$p=stream_get_contents(STDIN); $u=$argv[1]; $f=$argv[2]; file_put_contents($f,http_build_query([\"action\"=>\"login\",\"username\"=>$u,\"password\"=>$p]));' \"$USERNAME\" \"$POST\"; chmod 0600 \"$POST\""
),
(
 'echo " Senha   : $PASSWORD"',
 'echo " Senha   : definida pelo operador (não exibida)"'
),
(
 'echo "[ATENÇÃO] Guarde a senha agora. O servidor conserva somente o hash."',
 'echo "[OK] A senha escolhida foi aplicada; o servidor conserva somente o hash."'
),
]
for old,new in patches:
    c=text.count(old)
    if c != 1:
        raise SystemExit(f'[ERRO] patch inesperado count={c}: {old[:80]}')
    text=text.replace(old,new,1)
open(dst,'w',encoding='utf-8',newline='').write(text)
PY
bash -n "$V3"
grep -Fq 'USERNAME="queuspa"' "$V3"
grep -Fq 'install -d -o root -g root -m 0755 "$CONTROL_DIR"' "$V3"
grep -Fq 'PASSWORD="$XLX026_CONTROL_PASSWORD"' "$V3"
! grep -Fq 'PASSWORD="$(openssl rand -hex 12)"' "$V3"
! grep -Fq 'echo " Senha   : $PASSWORD"' "$V3"
ok "V3 preparada: usuário fixo, senha local, diretório 0755 e login de teste URL-encoded"

section "4/5 — EXECUTAR INSTALAÇÃO COMPLETA"
bash "$V3"

section "5/5 — VALIDAR CREDENCIAL E URL"
MODE="$(stat -c '%a' /var/www/html/xlxd-novo/controle)"
OWNER="$(stat -c '%U:%G' /var/www/html/xlxd-novo/controle)"
echo "control_dir_mode=$MODE"
echo "control_dir_owner=$OWNER"
[[ "$MODE" == "755" ]] || { fail "permissão inesperada em /controle: $MODE"; exit 40; }
[[ "$OWNER" == "root:root" ]] || { fail "dono inesperado em /controle: $OWNER"; exit 41; }

CFG=/etc/xlx026-control/config.php
grep -Fq "'username' => 'queuspa'" "$CFG" || { fail "usuário final não confirmado"; exit 42; }
if grep -Fq "$XLX026_CONTROL_PASSWORD" "$CFG"; then
  fail "senha em texto puro detectada na configuração"
  exit 43
fi

COOKIE="$TMP/cookie-final.jar"
POST="$TMP/login-final.post"
printf '%s' "$XLX026_CONTROL_PASSWORD" | php -r '$p=stream_get_contents(STDIN); $u=$argv[1]; $f=$argv[2]; file_put_contents($f,http_build_query(["action"=>"login","username"=>$u,"password"=>$p]));' "$CONTROL_USERNAME" "$POST"
chmod 0600 "$POST"
curl --silent --show-error --location --connect-timeout 8 --max-time 25 -c "$COOKIE" -b "$COOKIE" --data-binary "@$POST" https://xlx026.net/controle/ -o "$TMP/auth-final.html"
grep -Fq 'Integridade e testes' "$TMP/auth-final.html" || { fail "login final com credencial escolhida falhou"; exit 44; }
rm -f "$POST" "$COOKIE"
unset XLX026_CONTROL_PASSWORD
ok "LOGIN FINAL APROVADO"
echo "url=https://xlx026.net/controle/"
echo "username=$CONTROL_USERNAME"
echo "password=definida_pelo_operador_nao_exibida"
