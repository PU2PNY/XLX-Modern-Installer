#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit('uso: genericize-xlx-control.py INDEX.php')

p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8')


def once(old: str, new: str) -> None:
    global s
    count = s.count(old)
    if count != 1:
        raise SystemExit(f'genericização recusada: esperado 1, encontrado {count}: {old[:120]}')
    s = s.replace(old, new, 1)


once("const CTRL_VER='1.1.1';", "const CTRL_VER='1.3.0';")
once("const CFG='/etc/xlx026-control/config.php';", "const CFG='/etc/xlx-modern-control/config.php';")
once("const STATE='/var/lib/xlx026-control';", "const STATE='/var/lib/xlx-modern-control';")
once("const HELPER='/usr/local/sbin/xlx026-control-helper';", "const HELPER='/usr/local/sbin/xlx-modern-control-helper';")
once("const BASE='https://xlx026.net';\n", "")

once(
    "header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');",
    "header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');\n"
    "header('Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=(), usb=()');\n"
    "header('Cross-Origin-Opener-Policy: same-origin');\n"
    "$ua=strtolower((string)($_SERVER['HTTP_USER_AGENT']??''));\n"
    "if($ua!==''&&preg_match('/(?:googlebot|bingbot|yandexbot|baiduspider|duckduckbot|slurp|semrushbot|ahrefsbot|mj12bot|dotbot|petalbot|bytespider|gptbot|oai-searchbot|chatgpt-user|facebookexternalhit|crawler|spider)/i',$ua)){http_response_code(404);exit;}"
)

once("exit('Controle XLX026 indisponível.');", "exit('Controle administrativo indisponível.');")
once(
    "foreach(['username','password_hash','expected_core_sha','expected_core_version'] as $k){if(empty($cfg[$k])||!is_string($cfg[$k])){http_response_code(503);exit('Configuração inválida.');}}",
    "foreach(['username','password_hash','expected_core_sha','expected_core_version','base_url','title','admin_slug'] as $k){if(empty($cfg[$k])||!is_string($cfg[$k])){http_response_code(503);exit('Configuração inválida.');}}\n"
    "$baseUrl=rtrim($cfg['base_url'],'/');$title=$cfg['title'];$adminSlug=trim($cfg['admin_slug'],'/');\n"
    "if(!preg_match('/^[a-z0-9][a-z0-9-]{1,31}$/',$adminSlug)){http_response_code(503);exit('Rota administrativa inválida.');}\n"
    "$adminPath='/'.$adminSlug.'/';$testPaths=is_array($cfg['test_paths']??null)?$cfg['test_paths']:[];"
)

once("session_name('XLX026CTRL');", "session_name('XLXMODERNCTRL');")
once("'path'=>'/controle/'", "'path'=>$adminPath")

once(
    "$allowed=['status','listeners','logs','backups','restart','radioid-status','radioid-search','radioid-save','radioid-delete','radioid-refresh','radioid-check'];",
    "$allowed=['status','listeners','logs','backups','restart','radioid-status','radioid-search','radioid-save','radioid-delete','radioid-refresh','radioid-check','access-status','access-add-white','access-delete-white','access-add-black','access-delete-black','interlink-status','interlink-save'];"
)

once(
    "$msg='';$bad=false;$tests=[];$restart='';$radioRows=[];$radioSearchTerm='';$radioSearchField='callsign';$radioActionResult=[];",
    "$msg='';$bad=false;$tests=[];$restart='';$radioRows=[];$radioSearchTerm='';$radioSearchField='callsign';$radioActionResult=[];$access=[];$accessOk=false;"
)

once(
    "if(isset($_GET['logout'])){audit('logout');$_SESSION=[];session_destroy();header('Location:/controle/');exit;}",
    "if(isset($_GET['logout'])){audit('logout');$_SESSION=[];session_destroy();header('Location:'.$adminPath);exit;}"
)
once("header('Location:/controle/');exit;", "header('Location:'.$adminPath);exit;")

# Security/meta and generic identity on both login and authenticated shells.
s = s.replace('content="noindex,nofollow,noarchive"', 'content="noindex,nofollow,noarchive,nosnippet,noimageindex"')
s = s.replace('<title>Controle XLX026</title>', '<title><?=h($title)?></title>')
s = s.replace('<div class="t">Controle XLX026</div>', '<div class="t"><?=h($title)?></div>')
s = s.replace('<div class="title">Controle XLX026</div>', '<div class="title"><?=h($title)?></div>')

old_tests = "if($a==='tests'){$tg=[['/ao-vivo',200,'h'],['/conectados',200,'h'],['/suporte',200,'h'],['/aprs-dprs',200,'h'],['/ranking',200,'h'],['/certificado',200,'h'],['/simulado-anatel/',200,'h'],['/refletores',200,'h'],['/noticias',200,'h'],['/api/status.php',200,'j'],['/api/live.php',200,'j'],['/api/mtr.php',400,'j']];foreach($tg as[$p,$e,$k]){[$c,$b]=probe(BASE.$p);$ok=$c===$e&&($k==='h'||is_array(json_decode($b,true)));$tests[]=[$p,$c,$e,$ok];}audit('tests');}"
new_tests = "if($a==='tests'){foreach($testPaths as$t){if(!is_array($t)||count($t)<3)continue;[$p,$e,$k]=$t;$p=(string)$p;$e=(int)$e;$k=(string)$k;[$c,$b]=probe($baseUrl.$p);$ok=$c===$e&&($k==='html'||$k==='h'||is_array(json_decode($b,true)));$tests[]=[$p,$c,$e,$ok];}audit('tests');}"
once(old_tests, new_tests)

access_post = r''' if(in_array($a,['access-add-white','access-delete-white','access-add-black','access-delete-black'],true)){
  $p=(string)($_POST['access_password']??'');$c=($_POST['confirm_access']??'')==='yes';$rule=strtoupper(posted('access_rule',9));
  if(!$c||!password_verify($p,$cfg['password_hash'])){$msg='Alteração cancelada: confirmação ou senha inválida.';$bad=true;audit('access_denied');}
  elseif($rule===''){$msg='Informe um indicativo ou prefixo.';$bad=true;}
  else{[$aok,$aj,$detail]=jr($a,[$rule]);if($aok){$access=$aj;$accessOk=true;$msg='Configuração de acesso salva. Reinicie o XLXD somente depois de conferir as regras.';audit($a);}else{$msg='Não foi possível salvar: '.mb_substr($detail,0,140);$bad=true;audit('access_fail');}}
 }
 if($a==='interlink-save'){
  $p=(string)($_POST['access_password']??'');$c=($_POST['confirm_access']??'')==='yes';$address=posted('interlink_address',253);$modules=strtoupper(preg_replace('/[^A-Za-z*]/','',(string)($_POST['interlink_modules']??''))??'');
  if(!$c||!password_verify($p,$cfg['password_hash'])){$msg='Alteração cancelada: confirmação ou senha inválida.';$bad=true;audit('interlink_denied');}
  else{[$aok,$aj,$detail]=jr('interlink-save',[$address,$modules]);if($aok){$access=$aj;$accessOk=true;$msg='XLX Interlink salvo. Reinicie o XLXD somente se quiser aplicar imediatamente.';audit('interlink_save');}else{$msg='Não foi possível salvar: '.mb_substr($detail,0,140);$bad=true;audit('interlink_fail');}}
 }
'''
once(" if($a==='radioid_search'){", access_post + " if($a==='radioid_search'){")

once(
    "[$ok,$st]=runh('status');$s=kv($st);[$code,$body]=probe(BASE.'/api/status.php?history_hours=24&control=1');$api=json_decode($body,true);if(!is_array($api))$api=[];[, $listeners]=runh('listeners');[, $logs]=runh('logs');[, $backups]=runh('backups');[$radioStatusOk,$radioStatus]=jr('radioid-status');$token=csrf();",
    "[$ok,$st]=runh('status');$s=kv($st);[$code,$body]=probe($baseUrl.'/api/status.php?history_hours=24&control=1');$api=json_decode($body,true);if(!is_array($api))$api=[];[, $listeners]=runh('listeners');[, $logs]=runh('logs');[, $backups]=runh('backups');[$radioStatusOk,$radioStatus]=jr('radioid-status');if(!$access){[$accessOk,$access]=jr('access-status');}$token=csrf();"
)

# Public pages are linked only after authentication. The Admin route itself is
# intentionally absent from the public dashboard menu, sitemap and robots.txt.
quick = r'''<section class="p" id="quick-links"><div class="section-head"><div><h2>Quick links</h2><p class="sub">Shortcuts to the reflector public pages.</p></div><span class="badge">After login only</span></div><div class="actions"><a class="btn" href="/ao-vivo">Live</a><a class="btn secondary" href="/conectados">Connected</a><a class="btn secondary" href="/ranking">Ranking</a><a class="btn secondary" href="/refletores">Reflectors</a><?php if(is_dir(dirname(__DIR__).'/aprs-dprs')):?><a class="btn secondary" href="/aprs-dprs/">APRS / D-PRS</a><?php endif;?></div></section>
'''
once('<section class="p"><h2>Integridade e testes</h2>', quick + '<section class="p"><h2>Integridade e testes</h2>')

access_ui = r'''<section class="p" id="access"><div class="section-head"><div><h2>XLXD Access Control</h2><p class="sub">Manage XLXD whitelist, blacklist and XLX Interlink settings. Every change creates a backup and audit record.</p></div><span class="badge">Automatic backup · password confirmation</span></div><?php if(!$accessOk):?><div class="msg bad">Unable to read access settings.</div><?php else:?><div class="maintenance"><div class="mini"><h3>Whitelist</h3><p class="muted">Active rules: <strong><?=h(implode(', ',(array)($access['whitelist']??[]))?:'none')?></strong></p><?php if(in_array('*',(array)($access['whitelist']??[]),true)):?><p class="warn">Open access: rule <code>*</code> allows everyone.</p><?php endif;?><form method="post"><input type="hidden" name="csrf" value="<?=h($token)?>"><input type="hidden" name="action" value="access-add-white"><input name="access_rule" maxlength="9" placeholder="PU2PNY ou PU2*" required><input class="password" type="password" name="access_password" placeholder="Confirm your password" required><label class="confirm"><input type="checkbox" name="confirm_access" value="yes" required> I confirm this change.</label><button class="good">Add rule</button></form><details class="new"><summary>Remove rule</summary><form method="post"><input type="hidden" name="csrf" value="<?=h($token)?>"><input type="hidden" name="action" value="access-delete-white"><input name="access_rule" maxlength="9" required placeholder="Exact rule"><input class="password" type="password" name="access_password" placeholder="Confirm your password" required><label class="confirm"><input type="checkbox" name="confirm_access" value="yes" required> I confirm removal.</label><button class="danger">Remover</button></form></details></div><div class="mini"><h3>Blacklist</h3><p class="muted">Active blocks: <strong><?=h(implode(', ',(array)($access['blacklist']??[]))?:'none')?></strong></p><form method="post"><input type="hidden" name="csrf" value="<?=h($token)?>"><input type="hidden" name="action" value="access-add-black"><input name="access_rule" maxlength="9" placeholder="PU5BIF ou PU5*" required><input class="password" type="password" name="access_password" placeholder="Confirm your password" required><label class="confirm"><input type="checkbox" name="confirm_access" value="yes" required> I confirm this block.</label><button class="danger">Block</button></form><details class="new"><summary>Remove block</summary><form method="post"><input type="hidden" name="csrf" value="<?=h($token)?>"><input type="hidden" name="action" value="access-delete-black"><input name="access_rule" maxlength="9" required placeholder="Exact rule"><input class="password" type="password" name="access_password" placeholder="Confirm your password" required><label class="confirm"><input type="checkbox" name="confirm_access" value="yes" required> I confirm removal.</label><button class="danger">Remover</button></form></details></div><div class="mini"><h3>XLX Interlink</h3><p class="muted">Address: <strong><?=h((string)($access['interlink']['address']??''))?:'default'?></strong> · modules: <strong><?=h((string)($access['interlink']['modules']??'*'))?></strong></p><form method="post"><input type="hidden" name="csrf" value="<?=h($token)?>"><input type="hidden" name="action" value="interlink-save"><label>IP, host or announced address<input name="interlink_address" maxlength="253" value="<?=h((string)($access['interlink']['address']??''))?>" placeholder="vazio = default"></label><label>Allowed modules<input name="interlink_modules" maxlength="27" value="<?=h((string)($access['interlink']['modules']??'*'))?>" placeholder="ABCDE ou *" required></label><input class="password" type="password" name="access_password" placeholder="Confirm your password" required><label class="confirm"><input type="checkbox" name="confirm_access" value="yes" required> I confirm this change.</label><button>Save Interlink</button></form></div></div><p class="sub">Changes are saved with a backup. Use the protected XLXD restart only after reviewing the configuration.</p><?php endif;?></section>
'''
once('<section class="p" id="radioid">', access_ui + '<section class="p" id="radioid">')

# Small generic wording changes; UI/functionality remains the XLX026 control.
s = s.replace('Controle XLX026', 'Controle do refletor')
s = s.replace('XLX026', 'REFLETOR')
# The substitutions above must not touch PHP identity placeholders; restore no
# hard-coded production identifiers by validating below rather than injecting a
# different fixed reflector name.

required = [
    "const CTRL_VER='1.3.0'",
    "const CFG='/etc/xlx-modern-control/config.php'",
    "'access-status'",
    "if($a==='radioid_search')",
    "if($a==='radioid_save')",
    "if($a==='radioid_delete')",
    'XLXD Access Control',
    'Quick links',
    'X-Robots-Tag: noindex, nofollow, noarchive, nosnippet',
    'googlebot|bingbot',
    '$adminPath',
    '$baseUrl',
]
for needle in required:
    if needle not in s:
        raise SystemExit(f'marcador final ausente: {needle}')

for forbidden in ('xlx026.net', '/etc/xlx026-control', '/var/lib/xlx026-control', '/usr/local/sbin/xlx026-control-helper', 'Controle XLX026'):
    if forbidden in s:
        raise SystemExit(f'identidade/caminho de produção remanescente: {forbidden}')

p.write_text(s, encoding='utf-8')

# XLX724 Admin: replace the legacy terminal label with Interlink.
s = s.replace('XLX Interlink', 'XLX Interlink')
s = s.replace('Configuração do terminal', 'XLX Interlink configuration')
s = s.replace('Save Interlink', 'Save Interlink')
s = s.replace('Terminal', 'Interlink')
