#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ADMIN="$ROOT/control/current-production-admin.php"
fail(){ printf 'FAIL | %s\n' "$*" >&2; exit 1; }
ok(){ printf 'OK | %s\n' "$*"; }

php -l "$ADMIN" >/dev/null || fail "Admin PHP syntax invalid"

python3 - "$ADMIN" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
flash="$msg=(string)($_SESSION['flash_msg']??'');$bad=(bool)($_SESSION['flash_bad']??false);unset($_SESSION['flash_msg'],$_SESSION['flash_bad']);"
assert flash in s, 'flash message restore missing'
redirect="header('Location:'.$adminPath.'#radioid',true,303);exit;"
positions=[]
for action,next_action in [
    ("radioid_save","radioid_delete"),
    ("radioid_delete","radioid_refresh"),
    ("radioid_refresh","radioid_check"),
]:
    start=s.index("if($a==='"+action+"')")
    end=s.index("if($a==='"+next_action+"')", start)
    block=s[start:end]
    assert redirect in block, f'{action}: 303 redirect missing'
    assert "$_SESSION['flash_msg']=$msg" in block, f'{action}: flash message not persisted'
    assert "$_SESSION['flash_bad']=$bad" in block, f'{action}: flash error state not persisted'
    positions.append(start + block.index(redirect))

save_start=s.index("if($a==='radioid_save')")
save_end=s.index("if($a==='radioid_delete')", save_start)
save=s[save_start:save_end]
assert "jr('radioid-search'" not in save, 'radioid_save still performs a second CSV search before redirect'

diag=s.index("[$ok,$st]=runh('status')")
assert all(p < diag for p in positions), 'RadioID mutation redirects must happen before expensive dashboard diagnostics'
print('admin_radioid_prg_contract=OK')
PY

ok "RadioID mutations use Post/Redirect/Get before heavy Admin diagnostics"
