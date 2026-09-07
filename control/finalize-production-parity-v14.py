#!/usr/bin/env python3
from pathlib import Path
import re
import sys

if len(sys.argv) not in (3, 4):
    raise SystemExit('usage: finalize-production-parity-v14.py DASHBOARD_INDEX ADMIN_INDEX [locale]')

dashboard = Path(sys.argv[1])
admin = Path(sys.argv[2])
locale = (sys.argv[3] if len(sys.argv) == 4 else 'en').lower()
if not dashboard.is_file() or not admin.is_file():
    raise SystemExit('dashboard/admin index missing')

pt = locale in {'pt','pt-br','pt_br'}
module_label = 'Módulos' if pt else 'Modules'
connected_label = 'Conectados' if pt else 'Connected'

# ---------------------------------------------------------------------------
# Public dashboard: restore the production-validated separation between the
# Modules page and the Connected stations page. No reflector identity is used.
# ---------------------------------------------------------------------------
s = dashboard.read_text(encoding='utf-8')
s = s.replace("// Módulos fazem parte da página Conectados; o endereço antigo continua válido.\nif ($page === 'modulos') $page = 'conectados';\n", '')
s = s.replace("$allowed = ['ao-vivo','conectados','ranking','refletores'];", "$allowed = ['ao-vivo','modulos','conectados','ranking','refletores'];")
s = s.replace("$authorizedPage = in_array($page, ['ao-vivo','conectados','ranking'], true);", "$authorizedPage = in_array($page, ['ao-vivo','modulos','conectados','ranking'], true);")

nav_re = re.compile(r"('ao-vivo'\s*=>\s*'[^']+',\n)(\s*'conectados'\s*=>\s*'[^']+',)")
if "'modulos' =>" not in s:
    s, n = nav_re.subn(r"\1    'modulos' => '" + module_label + r"',\n\2", s, count=1)
    if n != 1:
        raise SystemExit('could not add Modules navigation item')

# The source already has a dedicated modulos branch. Remove only the duplicated
# module overview that had been prepended to the Connected branch.
connected_start = "<?php elseif ($page === 'conectados'): ?>"
connected_heading = '<section class="page-heading heading-with-tools connected-stations-heading">'
if connected_start in s and connected_heading in s:
    a = s.index(connected_start) + len(connected_start)
    b = s.index(connected_heading, a)
    between = s[a:b]
    if 'connected-modules-heading' in between or 'moduleOverview' in between or 'module-reference' in between:
        s = s[:a] + "\n " + s[b:]

for required in (
    "$allowed = ['ao-vivo','modulos','conectados','ranking','refletores'];",
    "<?php elseif ($page === 'modulos'): ?>",
    "<?php elseif ($page === 'conectados'): ?>",
    "'modulos' =>",
):
    if required not in s:
        raise SystemExit(f'public parity marker missing: {required}')

dashboard.write_text(s, encoding='utf-8')

# ---------------------------------------------------------------------------
# Admin: keep the protected workflow, but use the validated XLXD file formats:
# whitelist/blacklist = one callsign/prefix per line;
# interlink = XLXnnn address modules, one entry per line.
# Browser never runs arbitrary sudo and no shell/terminal is exposed.
# ---------------------------------------------------------------------------
a = admin.read_text(encoding='utf-8')
a = a.replace("const CTRL_VER='1.3.0';", "const CTRL_VER='1.4.0';")
a = a.replace("'interlink-status','interlink-save'];", "'interlink-status','interlink-save','interlink-delete'];")

# Protected quick links: keep Modules and Connected distinct.
if 'href="/modulos"' not in a:
    a = a.replace(
        '<a class="btn secondary" href="/conectados">Connected</a>',
        f'<a class="btn secondary" href="/modulos">{module_label}</a><a class="btn secondary" href="/conectados">{connected_label}</a>',
        1,
    )

post_pattern = re.compile(
    r" if\(\$a==='interlink-save'\)\{\n.*?\n \}\n",
    re.S,
)
post_block = r''' if($a==='interlink-save'){
  $p=(string)($_POST['access_password']??'');$c=($_POST['confirm_access']??'')==='yes';
  $reflector=strtoupper(preg_replace('/[^A-Za-z0-9]/','',posted('interlink_reflector',6))??'');
  $address=posted('interlink_address',253);$modules=strtoupper(preg_replace('/[^A-Za-z]/','',(string)($_POST['interlink_modules']??''))??'');
  if(!$c||!password_verify($p,$cfg['password_hash'])){$msg='Interlink change cancelled: invalid confirmation or password.';$bad=true;audit('interlink_denied');}
  elseif(!preg_match('/^XLX[A-Z0-9]{3}$/',$reflector)){$msg='Use a remote reflector in the format XLX123.';$bad=true;}
  elseif($address===''){$msg='Enter the remote reflector IP address or domain.';$bad=true;}
  elseif($modules===''){$msg='Enter the shared modules, for example C or BCD.';$bad=true;}
  else{[$aok,$aj,$detail]=jr('interlink-save',[$reflector,$address,$modules]);if($aok){$access=$aj;$accessOk=true;$msg='XLX Interlink saved. Restart XLXD only after reviewing the configuration.';audit('interlink_save');}else{$msg='Could not save: '.mb_substr($detail,0,180);$bad=true;audit('interlink_fail');}}
 }
 if($a==='interlink-delete'){
  $p=(string)($_POST['access_password']??'');$c=($_POST['confirm_access']??'')==='yes';$reflector=strtoupper(posted('interlink_reflector',6));
  if(!$c||!password_verify($p,$cfg['password_hash'])){$msg='Interlink removal cancelled: invalid confirmation or password.';$bad=true;audit('interlink_delete_denied');}
  else{[$aok,$aj,$detail]=jr('interlink-delete',[$reflector]);if($aok){$access=$aj;$accessOk=true;$msg='XLX Interlink removed with backup.';audit('interlink_delete');}else{$msg='Could not remove: '.mb_substr($detail,0,180);$bad=true;audit('interlink_delete_fail');}}
 }
'''
a, n = post_pattern.subn(post_block, a, count=1)
if n != 1:
    raise SystemExit('could not replace Interlink POST handler')

ui_pattern = re.compile(
    r'<div class="mini"><h3>XLX Interlink</h3>.*?</form></div>',
    re.S,
)
ui = r'''<div class="mini"><h3>XLX Interlink</h3><p class="muted">One connection per line: <code>XLX123 host-or-IP BCD</code>.</p><?php $links=is_array($access['interlinks']??null)?$access['interlinks']:[]; if($links):?><div class="interlink-list"><?php foreach($links as $link):?><div class="interlink-row"><code><?=h((string)($link['reflector']??''))?> <?=h((string)($link['address']??''))?> <?=h((string)($link['modules']??''))?></code><form method="post"><input type="hidden" name="csrf" value="<?=h($token)?>"><input type="hidden" name="action" value="interlink-delete"><input type="hidden" name="interlink_reflector" value="<?=h((string)($link['reflector']??''))?>"><input class="password" type="password" name="access_password" placeholder="Confirm your password" required><label class="confirm"><input type="checkbox" name="confirm_access" value="yes" required> I confirm removal.</label><button class="danger">Remove</button></form></div><?php endforeach;?></div><?php else:?><p class="muted">No XLX Interlink configured.</p><?php endif;?><form method="post"><input type="hidden" name="csrf" value="<?=h($token)?>"><input type="hidden" name="action" value="interlink-save"><label>Remote XLX reflector<input name="interlink_reflector" maxlength="6" placeholder="XLX123" required></label><label>IP address or domain<input name="interlink_address" maxlength="253" placeholder="82.152.174.236" required></label><label>Shared modules<input name="interlink_modules" maxlength="26" placeholder="C or BCD" required></label><input class="password" type="password" name="access_password" placeholder="Confirm your password" required><label class="confirm"><input type="checkbox" name="confirm_access" value="yes" required> I confirm this change.</label><button>Save Interlink</button></form></div>'''
a, n = ui_pattern.subn(ui, a, count=1)
if n != 1:
    raise SystemExit('could not replace Interlink UI')

# Explicitly refuse legacy terminal exposure markers if an older source appears.
for forbidden in ('Terminal XLXD', 'Terminal SSH', 'shell_exec($_POST', 'passthru($_POST'):
    if forbidden in a:
        raise SystemExit(f'forbidden admin terminal marker present: {forbidden}')

for required in (
    "const CTRL_VER='1.4.0'",
    "'interlink-delete'",
    'interlink_reflector',
    "jr('interlink-save',[$reflector,$address,$modules])",
    'One connection per line:',
):
    if required not in a:
        raise SystemExit(f'admin parity marker missing: {required}')

admin.write_text(a, encoding='utf-8')
