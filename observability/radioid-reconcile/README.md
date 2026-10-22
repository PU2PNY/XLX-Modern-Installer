# RadioID: gravação incremental e retentativa

Referência de reparo para o runtime XLX026 existente. Os arquivos deste diretório não são habilitados automaticamente no instalador público. A instalação nova deve configurar serviço/timer e caminhos conforme seu ambiente; não declarar paridade integral por existir este pacote.

## Arquivos e limites
`reconcile_radioid.py` observa `/var/log/xlxd.xml` e os metadados DMR já existentes, mantendo o mecanismo de alias por ID/IP único previamente implantado. A fila de novos indicativos prioriza STATION e depois NODE; lê no máximo200/300fragmentos. Não consulta rede no PHP/Live nem no XLXD. O timer existente executa a cada15s; uma busca remota por execução, timeout5s. A marcação de tentativa é pending e não significa sucesso. Estados privados têm next_retry, retenção7dias e limite1024.

`radioid_delta.py` usa o mesmo lock administrativo `/run/lock/xlx026-radioid-control.lock`. Lê o CSV em streaming, preserva linhas não afetadas, rejeita colisãoID/indicativo, salva cópias anteriores com hashes e aplica um UPSERT em cópia da tabela users. Exige schema conhecido, journal DELETE, contagem esperada e quick_check. CSV é publicado antes do SQLite. Exceções restauram ambos. Morte abrupta entre renames pode deixar CSV atualizado/SQLantigo; a fila detecta SQLausente e repara na próxima tentativa, mesmo se o ID já estiver no CSV. Não prometer atomicidade transacional de dois arquivos.

Novos cadastros e reparos usam delta; alterações de indicativo de um ID existente mantêm o helper de alias anterior. `radioid_profiles.py` preserva a lista restrita de campos públicos anteriormente implantada. Falha ao arquivar perfil mantém tentativa pendente mesmo se a linha pública já foi salva.

## Caminhos do runtime de referência
Código em /opt/xlx-dmr-meta-monitor; CSV e SQL em /xlxd/users_db; estado/perfis em /var/lib/xlx026-identity. Backups delta privados em /root/backups-xlx026/radioid-control/delta, limitados aos16mais recentes desse subdiretório. O serviço existente já permite escrita nesses diretórios e /run/lock. Não ampliar permissões nem editar serviços para esta correção.

## Aplicação e rollback
Antes da aplicação, adquirir o lock de reconciliação e o lock administrativo, salvar código/CSV/SQL/estado/aliases/perfis em backup privado, conferir checksums e contagem. Publicar apenas reconcile_radioid.py e radioid_delta.py; o arquivo profiles permanece igual ao instalado. Nenhum reinício de rádio/transcoder/Live é necessário, pois a próxima execução oneshot carrega o código.

Em falha da promoção, restaurar o script anterior e remover o delta novo. Dados oficiais já confirmados podem permanecer; se for necessário reverter dados, adquirir ambos os locks e restaurar CSV/SQL/estado/perfis do backup da mesma janela. Nunca publicar bases/perfis/logs/backups no Git.

## Testes
Executar `python3 observability/radioid-reconcile/test_radioid_reconcile.py`. As11fixtures são sintéticas, isoladas por diretório temporário e usam respostas oficiais simuladas; não acessam API real. Cobrem retentativa, ausência de dado, conflitos, rollback, idempotência, recuperação CSV/SQL, STATION sem NODE e falha de perfil. ENV de escala usa300000registros sintéticos sob96MiB; não equivale a teste de carga no rádio.
