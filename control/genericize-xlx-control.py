#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) not in (2, 3):
    raise SystemExit('usage: genericize-xlx-control.py INDEX.php [locale]')

p = Path(sys.argv[1])
locale = sys.argv[2].lower() if len(sys.argv) == 3 else 'en'
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

# The reusable baseline is Portuguese. The private Admin intentionally offers
# exactly two complete interfaces: Portuguese and English. Other dashboard
# locales use English here rather than a partially translated safety screen.
if locale not in ('pt', 'pt-br'):
    english = {
        'Controle do refletor': 'Reflector control',
        'Controle administrativo indisponível.': 'Administrative control unavailable.',
        'Configuração inválida.': 'Invalid configuration.',
        'Rota administrativa inválida.': 'Invalid administrative route.',
        'Muitas tentativas. Aguarde ': 'Too many attempts. Wait ',
        'Usuário ou senha inválidos.': 'Invalid username or password.',
        'Acesso restrito': 'Restricted access',
        'Usuário': 'Username', 'Senha': 'Password', 'Entrar': 'Sign in',
        'Requisição inválida.': 'Invalid request.',
        'Reinício cancelado: confirmação ou senha inválida.': 'Restart canceled: confirmation or password is invalid.',
        'XLXD reiniciado e validado com sucesso.': 'XLXD restarted and validated successfully.',
        'Falha no reinício/validação.': 'Restart or validation failed.',
        'Informe um filtro e um termo de pesquisa.': 'Enter a field and a search term.',
        'Não foi possível pesquisar a base RadioID.': 'Could not search the RadioID database.',
        'Não foi possível salvar. Nenhuma alteração incompleta foi mantida.': 'Could not save. No incomplete change was kept.',
        'Excluir cadastro': 'Delete record', 'Pesquisar cadastro': 'Search directory',
        'Pesquisar': 'Search', 'Indicativo': 'Callsign', 'Cidade': 'City', 'País': 'Country',
        'Nome': 'Name', 'Estado': 'State', 'Ação': 'Action', 'Editar': 'Edit',
        'Salvar e sincronizar': 'Save and synchronize', 'Adicionar e sincronizar': 'Add and synchronize',
        'Verificar integridade': 'Check integrity', 'Verificar agora': 'Check now',
        'Atualizar banco de indicativos': 'Update callsign database',
        'Executar testes gerais': 'Run general tests', 'Integridade e testes': 'Integrity and tests',
        'Área técnica privada': 'Private technical area', 'Sair': 'Sign out',
        'Conectados': 'Connected', 'TX ativa': 'Active TX', 'Processos': 'Processes',
        'Listeners UDP': 'UDP listeners', 'Logs recentes': 'Recent logs', 'Backups recentes': 'Recent backups',
        'Reiniciar XLXD': 'Restart XLXD', 'não indexado': 'not indexed',
        'Atualizar': 'Refresh', 'Teste': 'Test', 'Esperado': 'Expected', 'Resultado': 'Result', 'FALHOU': 'FAILED',
        'Registros RadioID': 'RadioID records', 'Base CSV': 'CSV database', 'Banco SQL': 'SQL database',
        'Não foi possível ler o estado da base RadioID.': 'Could not read the RadioID database status.',
        'Digite indicativo, Radio ID, nome...': 'Enter callsign, Radio ID, or name...', 'DMR / Radio ID': 'DMR / Radio ID',
        'Sobrenome': 'Last name', 'Confirme sua senha': 'Confirm your password', 'Confirmo a exclusão deste cadastro.': 'I confirm deletion of this record.',
        'Adicionar novo cadastro': 'Add new record', '7 dígitos': '7 digits', 'Atualizar banco de indicativos': 'Update callsign database',
        'Cria um novo <strong>users.db</strong> separado, valida a integridade e só então publica o arquivo pronto. Se falhar, mantém a base anterior.': 'Creates a separate <strong>users.db</strong>, validates it, and only then publishes it. If it fails, the previous database is kept.',
        'Confirmo a atualização da base de indicativos.': 'I confirm the callsign database update.',
        'Executa uma verificação segura do banco SQL sem alterar os cadastros.': 'Runs a safe SQL database check without changing records.',
        'Reinicia somente xlxd.service e valida versão, SHA e processo depois.': 'Restarts only xlxd.service and then validates the version, SHA, and process.',
        'Confirmo o reinício somente do XLXD.': 'I confirm restarting XLXD only.',
        'Configuração de acesso salva. Reinicie o XLXD somente depois de conferir as regras.': 'Access configuration saved. Restart XLXD only after reviewing the rules.',
        'Não foi possível salvar: ': 'Could not save: ', 'XLX Interlink salvo. Reinicie o XLXD somente se quiser aplicar imediatamente.': 'XLX Interlink saved. Restart XLXD only to apply it immediately.',
        'Não foi possível salvar. A base anterior foi preservada.': 'Could not save. The previous database was preserved.',
        'Alteração cancelada: confirmação ou senha inválida.': 'Change canceled: confirmation or password is invalid.',
        'Informe um indicativo ou prefixo.': 'Enter a callsign or prefix.',
        'Registro excluído e banco sincronizado com segurança.': 'Record deleted and database synchronized safely.',
        'Não foi possível excluir. A base anterior foi preservada.': 'Could not delete. The previous database was preserved.',
        'Novo banco de indicativos criado, validado e publicado com segurança.': 'New callsign database created, validated, and published safely.',
        'A atualização falhou. A base anterior foi restaurada automaticamente.': 'Update failed. The previous database was restored automatically.',
        'Integridade do banco de indicativos: OK.': 'Callsign database integrity: OK.',
        'A verificação de integridade encontrou problema.': 'The integrity check found a problem.',
        'registro(s) encontrado(s).': 'record(s) found.',
        'Registro RadioID adicionado e banco sincronizado.': 'RadioID record added and database synchronized.',
        'Registro RadioID atualizado e banco sincronizado.': 'RadioID record updated and database synchronized.',
        'Exclusão cancelada: confirmação ou senha inválida.': 'Deletion canceled: confirmation or password is invalid.',
        'Atualização cancelada: confirmação ou senha inválida.': 'Update canceled: confirmation or password is invalid.',
        'Gerencie visualmente a base local usada pelo refletor. Cada alteração cria backup e só publica um novo banco SQL depois de validá-lo.': 'Manage the local directory used by the reflector. Every change creates a backup and publishes a new SQL database only after validation.',
        'Gerenciador protegido · sincronização atômica': 'Protected manager · atomic synchronization',
        'Integridade do banco de indicativos: OK.': 'Callsign database integrity: OK.',
        'Integridade': 'Integrity', 'Verificar': 'Check',
    }
    for old, new in english.items():
        s = s.replace(old, new)

    # helper_reason() must keep its Portuguese search keys because the helper
    # returns Portuguese diagnostics. Translate only the message values shown
    # to the operator, never those lookup keys.
    helper_values = {
        "'Radio ID já pertence'=>'Este Radio ID já pertence a outro cadastro.'": "'Radio ID já pertence'=>'This Radio ID already belongs to another record.'",
        "'Radio ID deve ter 7 dígitos'=>'O Radio ID deve ter 7 dígitos ou ficar vazio.'": "'Radio ID deve ter 7 dígitos'=>'The Radio ID must contain 7 digits or be left blank.'",
        "'indicativo original inválido'=>'O indicativo original é inválido.'": "'indicativo original inválido'=>'The original callsign is invalid.'",
        "'indicativo inválido'=>'O indicativo informado é inválido.'": "'indicativo inválido'=>'The supplied callsign is invalid.'",
        "'cadastro original não foi localizado de forma única'=>'O cadastro selecionado não pôde ser identificado de forma única. Pesquise novamente e tente outra vez.'": "'cadastro original não foi localizado de forma única'=>'The selected record could not be identified uniquely. Search again and try once more.'",
        "'indicativo já existe'=>'Este indicativo já possui cadastro. Pesquise o indicativo e edite o registro existente.'": "'indicativo já existe'=>'This callsign already has a record. Search for it and edit the existing record.'",
        "'nome, cidade, estado e país são obrigatórios'=>'Nome, cidade, estado e país são obrigatórios.'": "'nome, cidade, estado e país são obrigatórios'=>'Name, city, state, and country are required.'",
        "'campos não podem conter vírgulas'=>'Os campos não podem conter vírgulas ou quebras de linha.'": "'campos não podem conter vírgulas'=>'Fields cannot contain commas or line breaks.'",
        "'reconstrução SQL falhou'=>'A sincronização do banco SQL falhou. A base anterior foi restaurada automaticamente.'": "'reconstrução SQL falhou'=>'SQL database synchronization failed. The previous database was restored automatically.'",
        "'novo banco SQL falhou na integridade'=>'O novo banco SQL não passou na verificação de integridade. A base anterior foi restaurada.'": "'novo banco SQL falhou na integridade'=>'The new SQL database did not pass the integrity check. The previous database was restored.'",
        "'estrutura do novo banco SQL é incompatível'=>'O novo banco SQL apresentou estrutura incompatível. A base anterior foi restaurada.'": "'estrutura do novo banco SQL é incompatível'=>'The new SQL database has an incompatible structure. The previous database was restored.'",
        "'gerador SQL tem formato inesperado'=>'O gerador SQL atual não é compatível com a sincronização segura. Nenhuma alteração foi mantida.'": "'gerador SQL tem formato inesperado'=>'The current SQL generator is not compatible with safe synchronization. No change was kept.'",
        "'outra operação de indicativos está em andamento'=>'Já existe outra operação de indicativos em andamento. Tente novamente após ela terminar.'": "'outra operação de indicativos está em andamento'=>'Another callsign operation is already running. Try again after it finishes.'",
    }
    for old, new in helper_values.items():
        s = s.replace(old, new)

p.write_text(s, encoding='utf-8')

# XLX724 Admin: replace the legacy terminal label with Interlink.
s = s.replace('XLX Interlink', 'XLX Interlink')
s = s.replace('Configuração do terminal', 'XLX Interlink configuration')
s = s.replace('Save Interlink', 'Save Interlink')
s = s.replace('Terminal', 'Interlink')
