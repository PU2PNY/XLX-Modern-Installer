#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C
umask 077

EXPECTED_SHA="a79a3bf8d883bd35911a34648d71e6980726b4e8"
UPSTREAM="https://github.com/ik4nzd/XLXD-2.6.0.git"
BASE="/root/backups-xlx026"
LABROOT="/root/xlx026-lab"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/XLX026_GOLDEN_BASELINE_V2_${STAMP}"
LAB="$LABROOT/XLXD-2.6.0_${STAMP}"
LOG="$OUT/execution.log"

[[ "$(id -u)" -eq 0 ]] || { echo "[ERRO] execute como root" >&2; exit 1; }
mkdir -p "$OUT" "$LABROOT"
chmod 700 "$OUT" "$LABROOT"
exec > >(tee -a "$LOG") 2>&1

fail(){ echo "[ERRO] $*" >&2; }
ok(){ echo "[OK] $*"; }
warn(){ echo "[ATENÇÃO] $*"; }
section(){ printf '\n======================================================================\n%s\n======================================================================\n' "$*"; }

PROD_BIN="/xlxd/xlxd"
SRC="/usr/src/xlxd"
WEB="/var/www/html/xlxd-novo"
XML="/var/log/xlxd.xml"

section "1/10 — PRÉ-CHECAGEM"
for p in "$PROD_BIN" /xlxd "$SRC" "$WEB"; do
  [[ -e "$p" ]] || { fail "ausente: $p"; exit 10; }
  ok "$p"
done
for c in tar gzip sha256sum git make g++ curl ss systemctl; do
  command -v "$c" >/dev/null 2>&1 || { fail "comando obrigatório ausente: $c"; exit 11; }
done
PROD_SHA_BEFORE="$(sha256sum "$PROD_BIN" | awk '{print $1}')"
echo "production_sha_before=$PROD_SHA_BEFORE"
df -hP / "$BASE" 2>/dev/null || true
free -m || true

section "2/10 — INVENTÁRIO SOMENTE LEITURA"
{
  date --iso-8601=seconds
  hostname -f 2>/dev/null || hostname
  uname -a
  cat /etc/os-release 2>/dev/null || true
} > "$OUT/system.txt"
ps auxww > "$OUT/processes.txt" || true
ss -lntup > "$OUT/listeners.txt" 2>&1 || true
systemctl status xlxd.service --no-pager -l > "$OUT/xlxd-status.txt" 2>&1 || true
systemctl cat xlxd.service > "$OUT/xlxd-service.txt" 2>&1 || true
journalctl -u xlxd.service -n 300 --no-pager > "$OUT/xlxd-journal.txt" 2>&1 || true
for s in DMRGateway YSFGateway dmr-gateway ysf-gateway apache2 nginx php8.2-fpm fail2ban certbot unattended-upgrades; do
  systemctl status "$s" --no-pager -l > "$OUT/service-${s}.txt" 2>&1 || true
done

section "3/10 — ESTADO GIT/FONTES"
if [[ -d "$SRC/.git" ]]; then
  git -C "$SRC" rev-parse HEAD > "$OUT/current-source-head.txt" 2>&1 || true
  git -C "$SRC" status --short --branch > "$OUT/current-source-status.txt" 2>&1 || true
  git -C "$SRC" log -n 30 --oneline --decorate > "$OUT/current-source-log.txt" 2>&1 || true
  git -C "$SRC" diff > "$OUT/current-source-diff.patch" 2>&1 || true
  git -C "$SRC" remote -v | sed -E 's#(https?://)[^/@]+@#\1***@#g' > "$OUT/current-source-remotes.txt" 2>&1 || true
else
  warn "$SRC não é git"
fi

section "4/10 — XML, CONFIG E HTTP"
if [[ -f "$XML" ]]; then
  cp -a "$XML" "$OUT/xlxd.xml.snapshot"
  sha256sum "$XML" > "$OUT/xlxd.xml.sha256"
  python3 - "$XML" > "$OUT/xml-parse.txt" 2>&1 <<'PY' || true
import sys, xml.etree.ElementTree as ET
p=sys.argv[1]
r=ET.parse(p).getroot()
print('root='+r.tag)
print('children='+str(len(list(r))))
for tag in ('Version','XLX','Node','Peer','User'):
    print(tag+'='+str(len(r.findall('.//'+tag))))
PY
fi
find /xlxd -maxdepth 2 -type f -printf '%p\n' 2>/dev/null | sort > "$OUT/xlxd-files.txt" || true
find "$WEB" -maxdepth 3 -type f -printf '%p\n' 2>/dev/null | sort > "$OUT/web-files.txt" || true
for u in \
  'https://xlx026.net/' \
  'https://xlx026.net/conectados' \
  'https://xlx026.net/refletores' \
  'https://xlx026.net/ranking' \
  'https://xlx026.net/api/status.php' \
  'https://xlx026.net/api/live.php'; do
  code="$(curl -L -sS -o /dev/null -w '%{http_code}' --connect-timeout 8 --max-time 20 "$u" || true)"
  printf '%s %s\n' "$code" "$u" >> "$OUT/http-before.txt"
done

section "5/10 — HASHES ANTES"
sha256sum "$PROD_BIN" > "$OUT/production-binary.sha256"
find /xlxd -xdev -type f -print0 2>/dev/null | sort -z | xargs -0 -r sha256sum > "$OUT/xlxd-tree.sha256"
find "$SRC" -xdev -type f -print0 2>/dev/null | sort -z | xargs -0 -r sha256sum > "$OUT/source-tree.sha256"
find "$WEB" -xdev -type f -print0 2>/dev/null | sort -z | xargs -0 -r sha256sum > "$OUT/web-tree.sha256"

section "6/10 — GOLDEN BACKUP"
make_archive(){
  local name="$1" path="$2"
  if [[ -e "$path" ]]; then
    tar --one-file-system --ignore-failed-read -czpf "$OUT/${name}.tar.gz" "$path"
    gzip -t "$OUT/${name}.tar.gz"
    sha256sum "$OUT/${name}.tar.gz" >> "$OUT/SHA256SUMS"
    ok "$name"
  fi
}
: > "$OUT/SHA256SUMS"
make_archive 01-xlxd /xlxd
make_archive 02-current-source "$SRC"
make_archive 03-web "$WEB"
make_archive 04-etc /etc
[[ ! -d /usr/local || -z "$(find /usr/local -mindepth 1 -print -quit 2>/dev/null)" ]] || make_archive 05-usr-local /usr/local
[[ ! -d /opt || -z "$(find /opt -mindepth 1 -print -quit 2>/dev/null)" ]] || make_archive 06-opt /opt
[[ ! -d /srv || -z "$(find /srv -mindepth 1 -print -quit 2>/dev/null)" ]] || make_archive 07-srv /srv
(cd "$OUT" && sha256sum -c SHA256SUMS)

section "7/10 — CLONE PINADO 2.6.0"
git clone --no-checkout "$UPSTREAM" "$LAB/repo"
git -C "$LAB/repo" checkout --detach "$EXPECTED_SHA"
ACTUAL_SHA="$(git -C "$LAB/repo" rev-parse HEAD)"
[[ "$ACTUAL_SHA" == "$EXPECTED_SHA" ]] || { fail "SHA inesperado: $ACTUAL_SHA"; exit 20; }
ok "SHA 2.6.0 confirmado: $ACTUAL_SHA"
git -C "$LAB/repo" status --short --branch > "$OUT/lab-git-status.txt"
git -C "$LAB/repo" log -1 --format=fuller > "$OUT/lab-commit.txt"

section "8/10 — AUDITORIA DE PROTOCOLOS"
{
  grep -RniE 'M17|NXDN|P25|YSF|DMR|DExtra|DPlus|DCS|IMRS|G3|NB_OF_PROTOCOLS' "$LAB/repo/src" || true
} > "$OUT/lab-protocol-references.txt"
if [[ -f "$LAB/repo/src/cprotocols.cpp" ]]; then cp -a "$LAB/repo/src/cprotocols.cpp" "$OUT/lab-cprotocols.cpp"; fi
if [[ -f "$LAB/repo/src/main.h" ]]; then cp -a "$LAB/repo/src/main.h" "$OUT/lab-main.h"; fi
if [[ -f "$LAB/repo/src/creflector.cpp" ]]; then cp -a "$LAB/repo/src/creflector.cpp" "$OUT/lab-creflector.cpp"; fi
if [[ -f "$LAB/repo/src/makefile" ]]; then cp -a "$LAB/repo/src/makefile" "$OUT/lab-makefile"; fi

section "9/10 — BUILD ISOLADO (SEM MAKE INSTALL)"
BUILD_RESULT="BUILD_FAILED"
set +e
(
  cd "$LAB/repo/src"
  make clean
  nice -n 10 make -j1
) > "$OUT/lab-build.log" 2>&1
BRC=$?
set -e
if [[ $BRC -eq 0 && -x "$LAB/repo/src/xlxd" ]]; then
  BUILD_RESULT="BUILD_OK"
  sha256sum "$LAB/repo/src/xlxd" > "$OUT/lab-binary.sha256"
  file "$LAB/repo/src/xlxd" > "$OUT/lab-binary.file"
  ldd "$LAB/repo/src/xlxd" > "$OUT/lab-binary.ldd" 2>&1 || true
  strings "$LAB/repo/src/xlxd" | grep -E 'M17|NXDN|P25|YSF|DMR|DExtra|DPlus|DCS|IMRS' | sort -u > "$OUT/lab-binary-protocol-strings.txt" || true
  ok "build isolado concluído"
else
  warn "build isolado falhou; produção permanece intacta"
fi

diff -rq "$SRC" "$LAB/repo" > "$OUT/current-vs-26.diff-rq.txt" 2>&1 || true

section "10/10 — VALIDAÇÃO FINAL DE PRODUÇÃO"
PROD_SHA_AFTER="$(sha256sum "$PROD_BIN" | awk '{print $1}')"
[[ "$PROD_SHA_AFTER" == "$PROD_SHA_BEFORE" ]] || { fail "binário de produção mudou"; exit 30; }
if systemctl is-active --quiet xlxd.service || pgrep -x xlxd >/dev/null 2>&1; then
  XLXD_FINAL="ACTIVE"
else
  XLXD_FINAL="NOT_ACTIVE"
  fail "xlxd não está ativo"
  exit 31
fi
for u in \
  'https://xlx026.net/' \
  'https://xlx026.net/api/status.php' \
  'https://xlx026.net/api/live.php'; do
  code="$(curl -L -sS -o /dev/null -w '%{http_code}' --connect-timeout 8 --max-time 20 "$u" || true)"
  printf '%s %s\n' "$code" "$u" >> "$OUT/http-after.txt"
done
(cd "$OUT" && sha256sum -c SHA256SUMS)
cat > "$OUT/RESTORE-INFO.txt" <<RESTORE
Golden baseline only. No production replacement or restart was performed.
Production binary before/after: $PROD_SHA_BEFORE
Archives and SHA256SUMS are in: $OUT
Do not restore blindly; diagnose first and restore only the affected component.
RESTORE
cat > "$OUT/COMPLETE" <<COMPLETE
status=COMPLETE
path=$OUT
lab=$LAB/repo
lab_result=$BUILD_RESULT
upstream_sha=$ACTUAL_SHA
production_binary_sha=$PROD_SHA_AFTER
xlxd_final=$XLXD_FINAL
COMPLETE
chmod 600 "$OUT"/* 2>/dev/null || true
cat "$OUT/COMPLETE"
echo "[OK] GOLDEN/LAB concluído sem alterar o binário de produção"
