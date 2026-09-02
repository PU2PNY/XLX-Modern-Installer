#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) not in (2, 3):
    raise SystemExit('usage: patch-admin-interlink-v2.py INDEX.php [locale]')

path = Path(sys.argv[1])
locale = (sys.argv[2] if len(sys.argv) == 3 else 'en').lower().replace('_', '-')
is_pt = locale in ('pt', 'pt-br')
s = path.read_text(encoding='utf-8')


def replace_once(old: str, new: str) -> None:
    global s
    count = s.count(old)
    if count != 1:
        raise SystemExit(f'Interlink patch refused: expected 1 marker, found {count}: {old[:100]}')
    s = s.replace(old, new, 1)


def replace_between(start: str, end: str, replacement: str) -> None:
    global s
    left = s.find(start)
    if left < 0:
        raise SystemExit(f'Interlink patch refused: start marker missing: {start[:100]}')
    right = s.find(end, left + len(start))
    if right < 0:
        raise SystemExit(f'Interlink patch refused: end marker missing: {end[:100]}')
    s = s[:left] + replacement + s[right:]


replace_once("const CTRL_VER='1.3.0';", "const CTRL_VER='1.4.0';")
replace_once(
    "'access-delete-black','interlink-status','interlink-save'];",
    "'access-delete-black','interlink-status','interlink-save','interlink-delete'];",
)

if is_pt:
    interlink_post = r''' if($a==='interlink-save'){
  $p=(string)($_POST['access_password']??'');$c=($_POST['confirm_access']??'')==='yes';$peer=strtoupper(posted('interlink_peer',8));$address=posted('interlink_address',253);$modules=strtoupper(preg_replace('/[^A-Za-z*]/','',(string)($_POST['interlink_modules']??''))??'');
  if(!$c||!password_verify($p,$cfg['password_hash'])){$msg='Alteração do Interlink cancelada: confirmação ou senha inválida.';$bad=true;audit('interlink_denied');}
  elseif($peer===''||$address===''||$modules===''){$msg='Informe refletor/peer, endereço e módulos do Interlink.';$bad=true;}
  else{[$aok,$aj,$detail]=jr('interlink-save',[$peer,$address,$modules]);if($aok&&(($aj['ok']??false)===true)){$access=$aj;$accessOk=true;$msg='Interlink salvo com backup. O XLXD recarrega a lista automaticamente em até 30 segundos; não é necessário reiniciar.';audit('interlink_save');}else{$msg='Não foi possível salvar o Interlink: '.mb_substr($detail,0,160);$bad=true;audit('interlink_fail');}}
 }
 if($a==='interlink-delete'){
  $p=(string)($_POST['access_password']??'');$c=($_POST['confirm_access']??'')==='yes';$peer=strtoupper(posted('interlink_peer',8));
  if(!$c||!password_verify($p,$cfg['password_hash'])){$msg='Exclusão do Interlink cancelada: confirmação ou senha inválida.';$bad=true;audit('interlink_delete_denied');}
  elseif($peer===''){$msg='Informe o refletor/peer que será removido.';$bad=true;}
  else{[$aok,$aj,$detail]=jr('interlink-delete',[$peer]);if($aok&&(($aj['ok']??false)===true)){$access=$aj;$accessOk=true;$msg='Interlink removido com backup. O XLXD recarrega a lista automaticamente em até 30 segundos.';audit('interlink_delete');}else{$msg='Não foi possível remover o Interlink: '.mb_substr($detail,0,160);$bad=true;audit('interlink_delete_fail');}}
 }
'''
    quick = r'''<section class="p" id="quick-links"><div class="section-head"><div><h2>Acesso rápido</h2><p class="sub">Atalhos para as páginas públicas do refletor.</p></div><span class="badge">Somente após login</span></div><div class="actions"><a class="btn" href="/ao-vivo">Ao vivo</a><a class="btn secondary" href="/conectados">Conectados</a><a class="btn secondary" href="/ranking">Ranking</a><a class="btn secondary" href="/refletores">Refletores</a><?php if(is_dir(dirname(__DIR__).'/aprs-dprs')):?><a class="btn secondary" href="/aprs-dprs/">APRS / D-PRS</a><?php endif;?></div></section>'''
    access_ui = r'''<section class="p" id="access"><div class="section-head"><div><h2>Controle de acesso XLXD</h2><p class="sub">Gerencie whitelist, blacklist e peers do XLX Interlink. Toda alteração cria backup e registro de auditoria.</p></div><span class="badge">Backup automático · confirmação por senha</span></div><?php if(!$accessOk):?><div class="msg bad">Não foi possível validar os arquivos de acesso/Interlink. Nenhuma alteração de Interlink deve ser feita até corrigir o arquivo.</div><?php else:?><div class="maintenance"><div class="mini"><h3>Whitelist</h3><p class="muted">Regras ativas: <strong><?=h(implode(', ',(array)($access['whitelist']??[]))?:'nenhuma')?></strong></p><?php if(in_array('*',(array)($access['whitelist']??[]),true)):?><p class="warn">Acesso aberto: a regra <code>*</code> permite todos.</p><?php endif;?><form method="post"><input type="hidden" name="csrf" value="<?=h($token)?>"><input type="hidden" name="action" value="access-add-white"><input name="access_rule" maxlength="9" placeholder="PU2PNY ou PU2*" required><input class="password" type="password" name="access_password" placeholder="Confirme sua senha" required><label class="confirm"><input type="checkbox" name="confirm_access" value="yes" required> Confirmo esta alteração.</label><button class="good">Adicionar regra</button></form><details class="new"><summary>Remover regra</summary><form method="post"><input type="hidden" name="csrf" value="<?=h($token)?>"><input type="hidden" name="action" value="access-delete-white"><input name="access_rule" maxlength="9" required placeholder="Regra exata"><input class="password" type="password" name="access_password" placeholder="Confirme sua senha" required><label class="confirm"><input type="checkbox" name="confirm_access" value="yes" required> Confirmo a remoção.</label><button class="danger">Remover</button></form></details></div><div class="mini"><h3>Blacklist</h3><p class="muted">Bloqueios ativos: <strong><?=h(implode(', ',(array)($access['blacklist']??[]))?:'nenhum')?></strong></p><form method="post"><input type="hidden" name="csrf" value="<?=h($token)?>"><input type="hidden" name="action" value="access-add-black"><input name="access_rule" maxlength="9" placeholder="PU5BIF ou PU5*" required><input class="password" type="password" name="access_password" placeholder="Confirme sua senha" required><label class="confirm"><input type="checkbox" name="confirm_access" value="yes" required> Confirmo este bloqueio.</label><button class="danger">Bloquear</button></form><details class="new"><summary>Remover bloqueio</summary><form method="post"><input type="hidden" name="csrf" value="<?=h($token)?>"><input type="hidden" name="action" value="access-delete-black"><input name="access_rule" maxlength="9" required placeholder="Regra exata"><input class="password" type="password" name="access_password" placeholder="Confirme sua senha" required><label class="confirm"><input type="checkbox" name="confirm_access" value="yes" required> Confirmo a remoção.</label><button class="danger">Remover</button></form></details></div></div><?php $interlinks=(array)($access['interlink']['entries']??[]);?><div class="mini" style="margin-top:14px"><h3>XLX Interlink</h3><p class="muted">Formato nativo do XLXD: <strong>REFLETOR/PEER · IP ou host · módulos</strong>. O arquivo é recarregado automaticamente pelo XLXD em até 30 segundos.</p><?php if($interlinks):?><div class="table-wrap"><table><thead><tr><th>Peer</th><th>Endereço</th><th>Módulos</th><th>Ação</th></tr></thead><tbody><?php foreach($interlinks as $entry):?><tr><td><strong><?=h((string)($entry['peer']??''))?></strong></td><td><?=h((string)($entry['address']??''))?></td><td><?=h((string)($entry['modules']??''))?></td><td><form method="post" class="actions"><input type="hidden" name="csrf" value="<?=h($token)?>"><input type="hidden" name="action" value="interlink-delete"><input type="hidden" name="interlink_peer" value="<?=h((string)($entry['peer']??''))?>"><input class="password" type="password" name="access_password" placeholder="Senha" required><label class="confirm"><input type="checkbox" name="confirm_access" value="yes" required> Confirmo</label><button class="danger">Remover</button></form></td></tr><?php endforeach;?></tbody></table></div><?php else:?><p class="muted">Nenhum peer Interlink ativo.</p><?php endif;?><details class="new" open><summary>Adicionar ou atualizar peer</summary><form method="post"><input type="hidden" name="csrf" value="<?=h($token)?>"><input type="hidden" name="action" value="interlink-save"><label>Refletor / peer<input name="interlink_peer" maxlength="8" placeholder="XLX123 ou ECHO" required></label><label>IP ou host<input name="interlink_address" maxlength="253" placeholder="203.0.113.10 ou host.exemplo.net" required></label><label>Módulos<input name="interlink_modules" maxlength="26" placeholder="ABCDE ou *" required></label><input class="password" type="password" name="access_password" placeholder="Confirme sua senha" required><label class="confirm"><input type="checkbox" name="confirm_access" value="yes" required> Confirmo esta alteração.</label><button>Salvar Interlink</button></form></details></div><p class="sub">Alterações em whitelist, blacklist e Interlink são gravadas com backup. O Interlink não exige reinício: o gatekeeper do XLXD monitora a alteração do arquivo.</p><?php endif;?></section>'''
else:
    interlink_post = r''' if($a==='interlink-save'){
  $p=(string)($_POST['access_password']??'');$c=($_POST['confirm_access']??'')==='yes';$peer=strtoupper(posted('interlink_peer',8));$address=posted('interlink_address',253);$modules=strtoupper(preg_replace('/[^A-Za-z*]/','',(string)($_POST['interlink_modules']??''))??'');
  if(!$c||!password_verify($p,$cfg['password_hash'])){$msg='Interlink change canceled: confirmation or password is invalid.';$bad=true;audit('interlink_denied');}
  elseif($peer===''||$address===''||$modules===''){$msg='Enter the Interlink peer, address, and modules.';$bad=true;}
  else{[$aok,$aj,$detail]=jr('interlink-save',[$peer,$address,$modules]);if($aok&&(($aj['ok']??false)===true)){$access=$aj;$accessOk=true;$msg='Interlink saved with a backup. XLXD reloads the list automatically within 30 seconds; no restart is required.';audit('interlink_save');}else{$msg='Could not save Interlink: '.mb_substr($detail,0,160);$bad=true;audit('interlink_fail');}}
 }
 if($a==='interlink-delete'){
  $p=(string)($_POST['access_password']??'');$c=($_POST['confirm_access']??'')==='yes';$peer=strtoupper(posted('interlink_peer',8));
  if(!$c||!password_verify($p,$cfg['password_hash'])){$msg='Interlink deletion canceled: confirmation or password is invalid.';$bad=true;audit('interlink_delete_denied');}
  elseif($peer===''){$msg='Enter the Interlink peer to remove.';$bad=true;}
  else{[$aok,$aj,$detail]=jr('interlink-delete',[$peer]);if($aok&&(($aj['ok']??false)===true)){$access=$aj;$accessOk=true;$msg='Interlink peer removed with a backup. XLXD reloads the list automatically within 30 seconds.';audit('interlink_delete');}else{$msg='Could not remove Interlink: '.mb_substr($detail,0,160);$bad=true;audit('interlink_delete_fail');}}
 }
'''
    quick = r'''<section class="p" id="quick-links"><div class="section-head"><div><h2>Quick links</h2><p class="sub">Shortcuts to the reflector public pages.</p></div><span class="badge">After login only</span></div><div class="actions"><a class="btn" href="/ao-vivo">Live</a><a class="btn secondary" href="/conectados">Connected</a><a class="btn secondary" href="/ranking">Ranking</a><a class="btn secondary" href="/refletores">Reflectors</a><?php if(is_dir(dirname(__DIR__).'/aprs-dprs')):?><a class="btn secondary" href="/aprs-dprs/">APRS / D-PRS</a><?php endif;?></div></section>'''
    access_ui = r'''<section class="p" id="access"><div class="section-head"><div><h2>XLXD Access Control</h2><p class="sub">Manage whitelist, blacklist, and XLX Interlink peers. Every change creates a backup and audit record.</p></div><span class="badge">Automatic backup · password confirmation</span></div><?php if(!$accessOk):?><div class="msg bad">The access/Interlink files could not be validated. Do not change Interlink entries until the file is corrected.</div><?php else:?><div class="maintenance"><div class="mini"><h3>Whitelist</h3><p class="muted">Active rules: <strong><?=h(implode(', ',(array)($access['whitelist']??[]))?:'none')?></strong></p><?php if(in_array('*',(array)($access['whitelist']??[]),true)):?><p class="warn">Open access: rule <code>*</code> allows everyone.</p><?php endif;?><form method="post"><input type="hidden" name="csrf" value="<?=h($token)?>"><input type="hidden" name="action" value="access-add-white"><input name="access_rule" maxlength="9" placeholder="N0CALL or N0*" required><input class="password" type="password" name="access_password" placeholder="Confirm your password" required><label class="confirm"><input type="checkbox" name="confirm_access" value="yes" required> I confirm this change.</label><button class="good">Add rule</button></form><details class="new"><summary>Remove rule</summary><form method="post"><input type="hidden" name="csrf" value="<?=h($token)?>"><input type="hidden" name="action" value="access-delete-white"><input name="access_rule" maxlength="9" required placeholder="Exact rule"><input class="password" type="password" name="access_password" placeholder="Confirm your password" required><label class="confirm"><input type="checkbox" name="confirm_access" value="yes" required> I confirm removal.</label><button class="danger">Remove</button></form></details></div><div class="mini"><h3>Blacklist</h3><p class="muted">Active blocks: <strong><?=h(implode(', ',(array)($access['blacklist']??[]))?:'none')?></strong></p><form method="post"><input type="hidden" name="csrf" value="<?=h($token)?>"><input type="hidden" name="action" value="access-add-black"><input name="access_rule" maxlength="9" placeholder="N0CALL or N0*" required><input class="password" type="password" name="access_password" placeholder="Confirm your password" required><label class="confirm"><input type="checkbox" name="confirm_access" value="yes" required> I confirm this block.</label><button class="danger">Block</button></form><details class="new"><summary>Remove block</summary><form method="post"><input type="hidden" name="csrf" value="<?=h($token)?>"><input type="hidden" name="action" value="access-delete-black"><input name="access_rule" maxlength="9" required placeholder="Exact rule"><input class="password" type="password" name="access_password" placeholder="Confirm your password" required><label class="confirm"><input type="checkbox" name="confirm_access" value="yes" required> I confirm removal.</label><button class="danger">Remove</button></form></details></div></div><?php $interlinks=(array)($access['interlink']['entries']??[]);?><div class="mini" style="margin-top:14px"><h3>XLX Interlink</h3><p class="muted">Native XLXD format: <strong>REFLECTOR/PEER · IP or host · modules</strong>. XLXD reloads the file automatically within 30 seconds.</p><?php if($interlinks):?><div class="table-wrap"><table><thead><tr><th>Peer</th><th>Address</th><th>Modules</th><th>Action</th></tr></thead><tbody><?php foreach($interlinks as $entry):?><tr><td><strong><?=h((string)($entry['peer']??''))?></strong></td><td><?=h((string)($entry['address']??''))?></td><td><?=h((string)($entry['modules']??''))?></td><td><form method="post" class="actions"><input type="hidden" name="csrf" value="<?=h($token)?>"><input type="hidden" name="action" value="interlink-delete"><input type="hidden" name="interlink_peer" value="<?=h((string)($entry['peer']??''))?>"><input class="password" type="password" name="access_password" placeholder="Password" required><label class="confirm"><input type="checkbox" name="confirm_access" value="yes" required> Confirm</label><button class="danger">Remove</button></form></td></tr><?php endforeach;?></tbody></table></div><?php else:?><p class="muted">No active Interlink peers.</p><?php endif;?><details class="new" open><summary>Add or update peer</summary><form method="post"><input type="hidden" name="csrf" value="<?=h($token)?>"><input type="hidden" name="action" value="interlink-save"><label>Reflector / peer<input name="interlink_peer" maxlength="8" placeholder="XLX123 or ECHO" required></label><label>IP or host<input name="interlink_address" maxlength="253" placeholder="203.0.113.10 or host.example.net" required></label><label>Modules<input name="interlink_modules" maxlength="26" placeholder="ABCDE or *" required></label><input class="password" type="password" name="access_password" placeholder="Confirm your password" required><label class="confirm"><input type="checkbox" name="confirm_access" value="yes" required> I confirm this change.</label><button>Save Interlink</button></form></details></div><p class="sub">Whitelist, blacklist, and Interlink changes are backed up. Interlink does not require a restart: the XLXD gatekeeper monitors the file for changes.</p><?php endif;?></section>'''

replace_between(" if($a==='interlink-save'){", " if($a==='radioid_search'){", interlink_post)
replace_once(
    "if(!$access){[$accessOk,$access]=jr('access-status');}",
    "if(!$access){[$accessOk,$access]=jr('access-status');$accessOk=$accessOk&&(($access['ok']??false)===true);}",
)

quick_start = '<section class="p" id="quick-links">'
quick_pos = s.find(quick_start)
if quick_pos < 0:
    raise SystemExit('Interlink patch refused: quick-links section missing')
quick_end = s.find('</section>', quick_pos)
if quick_end < 0:
    raise SystemExit('Interlink patch refused: quick-links end missing')
s = s[:quick_pos] + quick + s[quick_end + len('</section>'):]

replace_between('<section class="p" id="access">', '<section class="p" id="radioid">', access_ui)

required = [
    "const CTRL_VER='1.4.0'",
    "'interlink-delete'",
    "if($a==='interlink-save')",
    "if($a==='interlink-delete')",
    "name=\"interlink_peer\"",
    "($access['interlink']['entries']??[])",
]
for marker in required:
    if marker not in s:
        raise SystemExit(f'Interlink patch failed: marker missing: {marker}')

path.write_text(s, encoding='utf-8')
