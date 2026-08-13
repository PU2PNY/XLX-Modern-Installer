# Atualização segura do dashboard existente

O `install.sh` continua sendo um instalador para hosts novos e, por proteção, aborta quando detecta um XLX já instalado.

Para atualizar apenas um dashboard XLX Modern existente, use o `update.sh` da raiz.

## Pré-validação

O modo padrão não publica nada:

```bash
sudo bash update.sh --check --dashboard-dir=/var/www/html/xlx-dashboard
```

O atualizador:

- valida Bash/PHP/JavaScript da fonte;
- exige um `config/site.php` universal completo;
- cria um candidato fora do DocumentRoot ativo;
- renderiza idioma e placeholders no candidato;
- preserva a pasta `aprs-dprs/` quando o módulo independente já estiver instalado;
- rejeita placeholders não resolvidos;
- compara hashes antes de qualquer publicação.

## Dashboard legado

Se o dashboard existente ainda não possui `config/site.php`, nenhuma atualização é aplicada automaticamente.

Essa recusa é intencional para evitar transformar uma instalação específica em universal usando valores inferidos incorretamente.

É possível preparar uma configuração revisada e validá-la explicitamente:

```bash
sudo bash update.sh --check \
  --dashboard-dir=/var/www/html/xlxd-novo \
  --site-config=/root/site.php
```

## Publicação

Depois de uma pré-validação aprovada:

```bash
sudo bash update.sh --apply --dashboard-dir=/var/www/html/xlx-dashboard
```

A publicação exige a confirmação textual mostrada pelo script.

Antes da troca, o updater cria:

- backup completo do dashboard;
- SHA-256 do backup;
- script `ROLLBACK.sh` pronto.

A troca do diretório é feita de forma atômica. Se a validação pós-publicação falhar, o dashboard anterior é restaurado imediatamente.

## O que o updater não altera

O updater não:

- executa `git pull` dentro da produção;
- recompila ou substitui o XLXD;
- altera bancos do refletor;
- altera configuração ou bancos do APRS/D-PRS;
- altera certificados TLS;
- reinicia serviços sem uma necessidade específica prevista pelo procedimento.

A atualização do repositório-fonte e a publicação do dashboard são operações diferentes e devem permanecer separadas.
