# Sincronização validada da produção — 2026-08-13

Este relatório registra a sincronização de melhorias comprovadas do servidor XLX026 para a base universal do XLX Modern Installer.

## Backup de origem

Antes da comparação foi criado e validado o backup:

```text
/root/backups-xlx026/ANTES_SYNC_GITHUB_20260812_224029/xlx026-producao.tar.gz
SHA-256: ad7cb778bae32312eaeea7c721aaea66cc2a44188efc167d34054f961566f673
```

O backup do servidor não foi enviado ao repositório e pode conter dados privados que devem permanecer fora do GitHub.

## Comparação inicial

A comparação entre GitHub, cópia local antiga e produção mostrou:

```text
IGUAIS_3                 228
PROD_DIFERE_GITHUB        23
LOCAL_DIFERE_GITHUB       14
SO_PRODUCAO               33
SO_GITHUB                   4
SO_LOCAL                    0
```

A cópia local antiga estava em `61caa7ccdbf195883ae45ab02456cc116f49f0c5`; o `main` analisado no início estava em `78ab0745af59127d76e1c2ac20106c2f71b83540` e já continha 36 commits posteriores.

Por isso a produção não foi simplesmente copiada sobre o repositório.

## Fonte de verdade por área

### Mantido do GitHub universal

Os arquivos abaixo já haviam recebido universalizações posteriores e não foram substituídos pela versão renderizada/específica da produção:

- `dashboard/config.php`;
- `dashboard/api/status.php`;
- `dashboard/api/ranking-v2.php`;
- `dashboard/index.php`.

### Sincronizado da produção e sanitizado

Foram sincronizados 23 arquivos de núcleo relacionados a:

- atualização ao vivo;
- polling e histórico;
- MTR;
- clima e propagação;
- PWA;
- aplicação principal do dashboard;
- estilos ativos da página ao vivo;
- metadados públicos do painel.

Antes da aplicação foram removidos identificadores específicos de uma instalação, incluindo domínio, IP, TG/YSF fixos, cache com nome do servidor e branding operacional. Foram preservados placeholders universais como `{{REFLECTOR_NAME}}`, `{{REFLECTOR_DOMAIN}}`, `{{YSF_ID}}` e `{{DMR_TG}}`.

A lógica de voz/conexões da produção V10.3 foi preservada em forma universalizada.

O pacote intermediário utilizado na aplicação controlada teve:

```text
23 arquivos
SHA-256: bd8284e45fcd8d6937dcd240dff13eab3b518b683eb0afae7ebda79c79e98a3e
```

A transferência temporária foi removida da branch depois da aplicação.

## APRS / D-PRS

O Digital Lab/APRS não foi incorporado ao código interno do dashboard principal.

Ele foi separado no repositório público `PU2PNY/XLX-APRS-DPRS`, com instalação/atualização/backup próprios e CI de segurança.

Versão aprovada para integração:

```text
commit: 771abaa0c1ea662f33f3fa0c4a59ec712b1e4fcb
install.sh SHA-256: 0c5c26adbf9b54fe803e3cbaf2ddc17e4ba737f7c9f3b5606231b67c9a9403f9
manifesto SHA-256: b4a0e8f1e1fec7e894cff4c61b18c5891122278ecf5f2f666e5398b361c808d4
```

## Itens deliberadamente não importados

Não foram enviados para a base pública:

- `/etc/xlx026-digital-lab/config.json`;
- bancos SQLite reais;
- contas, senhas, hashes, tokens, cookies ou sessões;
- passcodes APRS reais;
- certificados/chaves privadas;
- `/etc/letsencrypt`;
- logs de produção;
- backups em `/root`;
- scripts históricos/auditoria antigos;
- páginas operacionais específicas cuja publicação universal exigiria configuração própria.

## Produção

A sincronização GitHub não publicou arquivos no DocumentRoot do servidor e não reiniciou `xlxd`, `xlxecho`, Apache ou o gateway APRS legado.

A produção permaneceu como origem operacional durante todo o processo. A atualização futura de um dashboard existente deve usar o procedimento documentado em `docs/UPDATING.md`, separado da sincronização do repositório-fonte.
