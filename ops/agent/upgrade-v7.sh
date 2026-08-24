#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

SOURCE_REF="b4f19164471c9af9a196f0f60e78a6fb19651377"
RAW="https://raw.githubusercontent.com/PU2PNY/XLX-Modern-Installer/${SOURCE_REF}"
EXPECTED_PROD_SHA="ffd01e4546ba12069f9181c6fe4d6fba620f7188dc39cde94fa572ec06fe4347"

FINALIZER_BLOB="aa707756b6af9ac30ff0a2fefbd62243b3e5f671"
PRECHECK_BLOB="07e2956c77269ccd07f46d9b3d5b9f29517362dd"
RELEASE_BLOB="81298c3e64579eac0e6ff4f253762b38b3443d82"
PANEL_BLOB="83fc804783b289b0ee505fa272b61674e2e80205"
FINISH_BLOB="38b199ad7f18ded263d2d7b937af904a616e61a8"

TMP="$(mktemp -d /tmp/xlx026-agent-v7.XXXXXX)"
PRE=""
MUTATED=0
TIMER_WAS_ACTIVE=0
PATH_WAS_ACTIVE=0

ok(){ echo "[OK] $*"; }
fail(){ echo "[ERRO] $*" >&2; }

restore_previous(){
  local rc="$1"
  trap - EXIT
  set +e
  if [[ "$MUTATED" -eq 1 ]]; then
    echo "[ATENÇÃO] Falha na V7; restaurando wrappers anteriores..." >&2
    rm -f \
      /usr/local/sbin/xlx026-core-260-candidate-finalize-v1 \
      /usr/local/sbin/xlx026-core-260-prepublish-v1 \
      /usr/local/sbin/xlx026-core-260-release-v1 \
      /usr/local/sbin/xlx026-panel-footer-v1 \
      /usr/local/sbin/xlx026-finish-project-v1
    if [[ -n "$PRE" && -f "$PRE/wrappers-pre-v7.tar.gz" ]]; then
      tar -C / -xzf "$PRE/wrappers-pre-v7.tar.gz" || true
    fi
  fi
  if [[ "$TIMER_WAS_ACTIVE" -eq 1 ]]; then systemctl start xlx026-github-agent.timer 2>/dev/null || true; fi
  if [[ "$PATH_WAS_ACTIVE" -eq 1 ]]; then systemctl start xlx026-github-executor.path 2>/dev/null || true; fi
  rm -rf "$TMP"
  exit "$rc"
}
trap 'rc=$?; if [[ $rc -ne 0 ]]; then restore_previous "$rc"; else rm -rf "$TMP"; fi' EXIT

[[ "$(id -u)" -eq 0 ]] || { fail "execute como root"; exit 1; }
for c in bash curl git install pgrep rm sha256sum systemctl tar; do
  command -v "$c" >/dev/null 2>&1 || { fail "comando ausente: $c"; exit 2; }
done

fetch_verify_blob(){
  local rel="$1" expected="$2" out got
  out="$TMP/$(basename "$rel")"
  curl --fail --silent --show-error --location --connect-timeout 10 --max-time 45 "$RAW/$rel" -o "$out"
  got="$(git hash-object "$out")"
  [[ "$got" == "$expected" ]] || {
    fail "Git blob divergente em $rel"
    echo "esperado=$expected" >&2
    echo "obtido=$got" >&2
    exit 3
  }
  echo "$out"
}

FINALIZER="$(fetch_verify_blob ops/root/xlx026-core-260-candidate-finalize-v1.sh "$FINALIZER_BLOB")"
PRECHECK="$(fetch_verify_blob ops/root/xlx026-core-260-prepublish-v1.sh "$PRECHECK_BLOB")"
RELEASE="$(fetch_verify_blob ops/root/xlx026-core-260-release-v1.sh "$RELEASE_BLOB")"
PANEL="$(fetch_verify_blob ops/root/xlx026-panel-footer-v1.sh "$PANEL_BLOB")"
FINISH="$(fetch_verify_blob ops/root/xlx026-finish-project-v1.sh "$FINISH_BLOB")"
for f in "$FINALIZER" "$PRECHECK" "$RELEASE" "$PANEL" "$FINISH"; do bash -n "$f"; done

if [[ "${XLX026_UPGRADE_V7_VERIFY_ONLY:-0}" == "1" ]]; then
  ok "Upgrade V7 verify-only: blobs imutáveis e sintaxe aprovados."
  exit 0
fi

[[ -x /xlxd/xlxd ]] || { fail "/xlxd/xlxd ausente"; exit 10; }
CURRENT_PROD_SHA="$(sha256sum /xlxd/xlxd | awk '{print $1}')"
[[ "$CURRENT_PROD_SHA" == "$EXPECTED_PROD_SHA" ]] || {
  fail "SHA do XLXD de produção mudou; V7 abortada"
  echo "esperado=$EXPECTED_PROD_SHA" >&2
  echo "obtido=$CURRENT_PROD_SHA" >&2
  exit 11
}
pgrep -x xlxd >/dev/null 2>&1 || { fail "XLXD de produção não está ativo"; exit 12; }

systemctl is-active --quiet xlx026-github-agent.timer 2>/dev/null && TIMER_WAS_ACTIVE=1 || true
systemctl is-active --quiet xlx026-github-executor.path 2>/dev/null && PATH_WAS_ACTIVE=1 || true

STAMP="$(date +%Y%m%d_%H%M%S)"
PRE="/root/backups-xlx026/AGENT_V7_PRE_${STAMP}"
mkdir -p "$PRE"
chmod 700 "$PRE"
MAN="$PRE/existing-wrappers.txt"
: > "$MAN"
TARGETS=(
  /usr/local/sbin/xlx026-core-260-candidate-finalize-v1
  /usr/local/sbin/xlx026-core-260-prepublish-v1
  /usr/local/sbin/xlx026-core-260-release-v1
  /usr/local/sbin/xlx026-panel-footer-v1
  /usr/local/sbin/xlx026-finish-project-v1
)
for p in "${TARGETS[@]}"; do [[ -e "$p" ]] && printf '%s\n' "${p#/}" >> "$MAN"; done
if [[ -s "$MAN" ]]; then
  tar -C / -czpf "$PRE/wrappers-pre-v7.tar.gz" -T "$MAN"
  sha256sum "$PRE/wrappers-pre-v7.tar.gz" > "$PRE/wrappers-pre-v7.tar.gz.sha256"
  (cd "$PRE" && sha256sum -c wrappers-pre-v7.tar.gz.sha256)
fi

systemctl stop xlx026-github-agent.timer 2>/dev/null || true
systemctl stop xlx026-github-agent.service 2>/dev/null || true
systemctl stop xlx026-github-executor.path 2>/dev/null || true
systemctl stop xlx026-github-executor.service 2>/dev/null || true
MUTATED=1

install -o root -g root -m 0750 "$FINALIZER" /usr/local/sbin/xlx026-core-260-candidate-finalize-v1
install -o root -g root -m 0750 "$PRECHECK" /usr/local/sbin/xlx026-core-260-prepublish-v1
install -o root -g root -m 0750 "$RELEASE" /usr/local/sbin/xlx026-core-260-release-v1
install -o root -g root -m 0750 "$PANEL" /usr/local/sbin/xlx026-panel-footer-v1
install -o root -g root -m 0750 "$FINISH" /usr/local/sbin/xlx026-finish-project-v1

[[ "$(git hash-object /usr/local/sbin/xlx026-core-260-candidate-finalize-v1)" == "$FINALIZER_BLOB" ]]
[[ "$(git hash-object /usr/local/sbin/xlx026-core-260-prepublish-v1)" == "$PRECHECK_BLOB" ]]
[[ "$(git hash-object /usr/local/sbin/xlx026-core-260-release-v1)" == "$RELEASE_BLOB" ]]
[[ "$(git hash-object /usr/local/sbin/xlx026-panel-footer-v1)" == "$PANEL_BLOB" ]]
[[ "$(git hash-object /usr/local/sbin/xlx026-finish-project-v1)" == "$FINISH_BLOB" ]]

CURRENT_PROD_SHA_AFTER="$(sha256sum /xlxd/xlxd | awk '{print $1}')"
[[ "$CURRENT_PROD_SHA_AFTER" == "$EXPECTED_PROD_SHA" ]] || { fail "produção mudou durante V7"; exit 20; }
pgrep -x xlxd >/dev/null 2>&1 || { fail "XLXD deixou de estar ativo durante V7"; exit 21; }

MUTATED=0
cat <<OUT
[OK] BUNDLE V7 instalado por blobs imutáveis.
[OK] Finalizador, prepublish, release, rodapé e finish-project instalados.
[OK] Agente remoto pausado para evitar concorrência durante a finalização local.
[OK] Backup pré-V7: $PRE
[OK] SHA produção permaneceu: $CURRENT_PROD_SHA_AFTER
[OK] Nenhum restart/publicação do XLXD ocorreu na V7.
[OK] Próxima ação local fixa: /usr/local/sbin/xlx026-finish-project-v1
OUT
