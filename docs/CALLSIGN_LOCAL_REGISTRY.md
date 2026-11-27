# Consulta local de indicativos Anatel

A página `/consulta-indicativo.php` usa SQLite de leitura, fora do webroot, em `/var/lib/xlx-modern-callsigns/registry.sqlite`. Sem base instalada, mostra uma mensagem e o link oficial. Não requer daemon, polling ou mudança no Nginx. Formulário GET, parâmetros SQL, escaping HTML e paginação limitada a25 resultados.

## Importação
O operador fornece o ZIP oficial ou o CSV Radioamador. `scripts/import-anatel-callsigns.py ORIGEM DESTINO` extrai somente `Estacoes_Radioamador.csv`; as demais bases não são descompactadas. Aceita também CSV minimizado comprimido gzip. O esquema é validado e CPF/CNPJ, Fistel, número de estação e frequências nunca entram no SQLite.

Antes de atualizar, copie a base atual para backup privado e confira SHA256. Importe para um candidato fora do webroot, confira `PRAGMA integrity_check`, contagem, pesquisa e schema. Atribua leitura ao grupo do PHP-FPM (ex.: diretório root:www-data0750, arquivo root:www-data0640) e faça troca atômica por rename no mesmo filesystem. O importador também constrói o destino por arquivo temporário no mesmo diretório antes de `os.replace`. Não use caminho web público nem permissões777. O usuário PHP não deve poder escrever no diretório ou banco.

Para dados já minimizados, a opção `--original-source-sha256` retém o hash previamente conferido do CSV original, além do hash do CSV efetivamente importado. A data interna do membro ZIP não é data garantida de atualização da Anatel. A interface exibe a data de importação e deixa explícito que é cópia estática.

`N/I`/`N/A` são ausências, exibidas como travessão. Registros de estação são preservados, inclusive sem indicativo. Indicativos são normalizados em uppercase e a contagem distinta exclui vazios. UF do titular e município/UF da estação permanecem separados; cidade ou posição não são inferidas. Status de validade reproduz o arquivo e não certifica situação em tempo real. Valores de classe/tipo/status permanecem canônicos no código dos seis idiomas; o conteúdo cadastral é fornecido em português pela fonte.

## Rollback
Guarde view, helper, CSS e base anteriores em backup privado antes da troca. Uma falha nos checks exige restaurar esses arquivos por rename/copy atômico e revalidar a página e Live health. Não reinicie XLXD, transcoder, Nginx ou PHP-FPM para alterar esta consulta.

## Git
Somente código, procedimento e evidência sanitizada são versionados. Não incluir ZIP, CSV, SQLite reais, nomes de titulares em fixtures, dumps ou backups. A base precisa ser reapresentada pelo administrador numa instalação nova.
