#!/usr/bin/env python3
# validation branch: no runtime behavior change
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit('uso: patch-xlx026-control-v111.py INDEX.php')

p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8')

replacements = [
    ("const CTRL_VER='1.1.0';", "const CTRL_VER='1.1.1';"),
    (
        "function jr(string $c,array $args=[]):array{[$ok,$out,$rc]=runh($c,$args);$j=json_decode($out,true);return[$ok&&is_array($j),is_array($j)?$j:[],trim($out),$rc];}",
        "function jr(string $c,array $args=[]):array{[$ok,$out,$rc]=runh($c,$args);$j=json_decode($out,true);return[$ok&&is_array($j),is_array($j)?$j:[],trim($out),$rc];}\n"
        "function helper_reason(string $detail,string $fallback):string{\n"
        " $d=trim($detail);\n"
        " $map=[\n"
        "  'Radio ID já pertence'=>'Este Radio ID já pertence a outro cadastro.',\n"
        "  'Radio ID deve ter 7 dígitos'=>'O Radio ID deve ter 7 dígitos ou ficar vazio.',\n"
        "  'indicativo original inválido'=>'O indicativo original é inválido.',\n"
        "  'indicativo inválido'=>'O indicativo informado é inválido.',\n"
        "  'cadastro original não foi localizado de forma única'=>'O cadastro selecionado não pôde ser identificado de forma única. Pesquise novamente e tente outra vez.',\n"
        "  'indicativo já existe'=>'Este indicativo já possui cadastro. Pesquise o indicativo e edite o registro existente.',\n"
        "  'nome, cidade, estado e país são obrigatórios'=>'Nome, cidade, estado e país são obrigatórios.',\n"
        "  'campos não podem conter vírgulas'=>'Os campos não podem conter vírgulas ou quebras de linha.',\n"
        "  'reconstrução SQL falhou'=>'A sincronização do banco SQL falhou. A base anterior foi restaurada automaticamente.',\n"
        "  'novo banco SQL falhou na integridade'=>'O novo banco SQL não passou na verificação de integridade. A base anterior foi restaurada.',\n"
        "  'estrutura do novo banco SQL é incompatível'=>'O novo banco SQL apresentou estrutura incompatível. A base anterior foi restaurada.',\n"
        "  'gerador SQL tem formato inesperado'=>'O gerador SQL atual não é compatível com a sincronização segura. Nenhuma alteração foi mantida.',\n"
        "  'outra operação de indicativos está em andamento'=>'Já existe outra operação de indicativos em andamento. Tente novamente após ela terminar.'\n"
        " ];\n"
        " foreach($map as $needle=>$message){if(stripos($d,$needle)!==false)return$message;}\n"
        " return$fallback;\n"
        "}"
    ),
    (
        "[$ok,$j]=jr('radioid-save',$args);",
        "[$ok,$j,$detail,$rc]=jr('radioid-save',$args);"
    ),
    (
        "else{$msg='Não foi possível salvar. Nenhuma alteração incompleta foi mantida.';$bad=true;audit('radioid_save_fail');}",
        "else{$msg=helper_reason($detail,'Não foi possível salvar. A base anterior foi preservada.');$bad=true;audit('radioid_save_fail');}"
    ),
    (
        "else{[$ok,$j]=jr('radioid-delete',[posted('orig_dmrid',10),strtoupper(posted('orig_callsign',12))]);if($ok){$msg='Registro excluído e banco sincronizado com backup.';audit('radioid_delete');}else{$msg='Exclusão falhou; a base anterior foi preservada.';$bad=true;audit('radioid_delete_fail');}}",
        "else{[$ok,$j,$detail,$rc]=jr('radioid-delete',[posted('orig_dmrid',10),strtoupper(posted('orig_callsign',12))]);if($ok){$msg='Registro excluído e banco sincronizado com segurança.';audit('radioid_delete');}else{$msg=helper_reason($detail,'Não foi possível excluir. A base anterior foi preservada.');$bad=true;audit('radioid_delete_fail');}}"
    ),
    (
        "else{[$ok,$j]=jr('radioid-refresh');if($ok){$radioActionResult=$j;$msg='Banco de indicativos reconstruído, validado e atualizado com sucesso.';audit('radioid_refresh');}else{$msg='Atualização falhou; rollback automático preservou a base anterior.';$bad=true;audit('radioid_refresh_fail');}}",
        "else{[$ok,$j,$detail,$rc]=jr('radioid-refresh');if($ok){$radioActionResult=$j;$msg='Novo banco de indicativos criado, validado e publicado com segurança.';audit('radioid_refresh');}else{$msg=helper_reason($detail,'A atualização falhou. A base anterior foi restaurada automaticamente.');$bad=true;audit('radioid_refresh_fail');}}"
    ),
    (
        '<span class="badge">Gerenciador protegido</span>',
        '<span class="badge">Gerenciador protegido · sincronização atômica</span>'
    ),
    (
        'Gerencie visualmente a base local usada pelo refletor. Alterações críticas criam backup e sincronizam o banco SQL.',
        'Gerencie visualmente a base local usada pelo refletor. Cada alteração cria backup e só publica um novo banco SQL depois de validá-lo.'
    ),
    (
        'Reconstrói o <strong>users.db</strong> a partir da base RadioID local, cria backup antes e valida a integridade depois. Se falhar, restaura automaticamente.',
        'Cria um novo <strong>users.db</strong> separado, valida a integridade e só então publica o arquivo pronto. Se falhar, mantém a base anterior.'
    ),
]

for old, new in replacements:
    n = s.count(old)
    if n != 1:
        raise SystemExit(f'patch recusado: ocorrência esperada=1 obtida={n}: {old[:80]}')
    s = s.replace(old, new, 1)

required = [
    "const CTRL_VER='1.1.1'",
    'function helper_reason',
    'sincronização atômica',
    "[$ok,$j,$detail,$rc]=jr('radioid-save'",
]
for needle in required:
    if needle not in s:
        raise SystemExit(f'marcador final ausente: {needle}')

p.write_text(s, encoding='utf-8')
