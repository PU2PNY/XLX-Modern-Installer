# Project Status

Atualizado em: 2026-09-21

## Estado atual confirmado no repositório

- Versão declarada em `VERSION`: **1.4.6**.
- Branch padrão: `main`.
- Commit de referência observado: `1d54417fe55e8a12f246fdf440df35428a38ec8d`.
- O instalador real está habilitado; `install.sh` é o motor autoritativo.
- O fluxo principal instala e valida dashboard, Nginx, PHP-FPM, XLXD, APRS/D-PRS e observabilidade conforme o código/README atuais.
- `start.sh` é o caminho recomendado para iniciantes.
- Backups preventivos e validações pós-instalação fazem parte da arquitetura documentada.

## Baseline de produção

Em 2026-09-21 o operador informou que o XLX026 e sua tela ativa estavam funcionando perfeitamente.

Classificação: **OPERATOR** — relato operacional importante a preservar, ainda não convertido em evidência técnica `PROD` nesta auditoria documental.

## Atenções

1. A última GitHub Release observada é v1.2.14, enquanto `VERSION` e README declaram 1.4.6.
2. O commit atual não retornou workflow runs/status combinados pelo conector nesta auditoria; não registrar CI PASS atual por inferência.
3. Alterações no XLXD core, protocolos, áudio/transcoding, rede ou produção exigem laboratório + rollback.
4. O backlog de fóruns/comunidades está em `docs/RESEARCH_BACKLOG.md`.

## Fonte de verdade

Comece por `PROJECT_START_HERE.md`.
