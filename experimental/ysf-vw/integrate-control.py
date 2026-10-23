#!/usr/bin/python3
"""Prepare narrowly-scoped VW integration for an existing XLX026 control page."""
from pathlib import Path
import sys
root=Path(sys.argv[1])
admin=root/'index.php'
wrapper=root/'xlx026-control-helper'
def replace_once(s, old, new):
    if s.count(old)!=1: raise RuntimeError('Unexpected control page; refusing patch: '+old[:60])
    return s.replace(old,new,1)
s=admin.read_text()
s=replace_once(s,"$allowed=['status',","$allowed=['ysf-vw-status','ysf-vw-set','status',")
action="""
 if($a==='ysf_vw_save'){
  $mode=(string)($_POST['ysf_vw']??'');
  if(!in_array($mode,['0','1'],true)||!password_verify((string)($_POST['vw_password']??''),$cfg['password_hash'])){
   $msg='Alteração do VW cancelada: senha ou opção inválida.';$bad=true;audit('ysf_vw_denied');
  }else{
   [$ok,$result]=jr('ysf-vw-set',[$mode]);
   $msg=$ok?($mode==='1'?'VW ativado entre estações YSF do mesmo módulo.':'VW desativado para novas transmissões; transmissões iniciadas podem terminar.'):'Não foi possível alterar o VW.';
   $bad=!$ok;audit($ok?'ysf_vw_saved':'ysf_vw_fail');
  }
 }
"""
s=replace_once(s," $a=(string)($_POST['action']??'');"," $a=(string)($_POST['action']??'');"+action)
s=replace_once(s,"$token=csrf();","[$vwOk,$vwStatus]=jr('ysf-vw-status');$token=csrf();")
form="""
<section class="p" id="ysf-vw"><div class="section-head"><div><h2>YSF · Voz larga (VW)</h2><p class="sub">VW entre estações YSF do mesmo módulo. Para conversar com DN, DMR ou D-STAR, use DN.</p></div><span class="badge"><?=($vwStatus['enabled']??false)?'ATIVADO':'DESATIVADO'?></span></div>
<?php if(!$vwOk||!($vwStatus['supported']??false)):?><p class="warn">O núcleo ainda não oferece suporte VW nesta instalação.</p><?php else:?>
<form method="post" class="actions"><input type="hidden" name="csrf" value="<?=h($token)?>"><input type="hidden" name="action" value="ysf_vw_save">
<label>VW <select name="ysf_vw" aria-label="Ativar voz larga YSF"><option value="0" <?=!($vwStatus['enabled']??false)?'selected':''?>>Desativado</option><option value="1" <?=($vwStatus['enabled']??false)?'selected':''?>>Ativado</option></select></label>
<input class="password" type="password" name="vw_password" placeholder="Confirme sua senha" aria-label="Confirme sua senha" required><button class="good">Salvar VW</button></form>
<p class="muted">A mudança vale para novas transmissões, sem reiniciar o servidor. Os dois rádios precisam aceitar VW.</p><?php endif;?></section>
"""
s=replace_once(s,"<?php if($view==='home'):?>\n<div class=\"grid\">","<?php if($view==='home'):?>"+form+'\n<div class="grid">')
s=replace_once(s,'<td class="warn">NÃO HABILITADO</td><td>Não entra no fluxo DV/crossmode atual','<td class="<?=($vwStatus[\'enabled\']??false)?\'ok\':\'warn\'?>"><?=($vwStatus[\'enabled\']??false)?\'ATIVO (YSF)\':\'DESATIVADO\'?></td><td>Chave na página Início · somente YSF/VW, sem conversão entre protocolos')
admin.write_text(s)
s=wrapper.read_text()
s=replace_once(s,'case "${1:-}" in','case "${1:-}" in\n  ysf-vw-status)\n    [[ "$#" -eq 1 ]] || exit 64\n    exec /usr/local/sbin/xlx026-ysf-vw-helper status\n    ;;\n  ysf-vw-set)\n    [[ "$#" -eq 2 && ( "$2" == 0 || "$2" == 1 ) ]] || exit 64\n    exec /usr/local/sbin/xlx026-ysf-vw-helper set "$2"\n    ;;')
wrapper.write_text(s)
