# Project Status

Atualizado em: 2026-09-28

## Estado atual confirmado no repositório

- Versão declarada em `VERSION`: **1.4.6**.
- Branch padrão: `main`.
- Commit confirmado antes desta correção: `4cb8dc37c35e29f107a77090dc9bec287e863bea`.
- O instalador real está habilitado; `install.sh` é o motor autoritativo.
- O fluxo principal instala e valida dashboard, **Nginx + PHP-FPM**, XLXD, APRS/D-PRS e observabilidade.
- `start.sh` é o caminho recomendado para iniciantes.
- Backups preventivos e validações pós-instalação fazem parte da arquitetura documentada.
- No commit `4cb8dc37c35e29f107a77090dc9bec287e863bea`, CI geral, Debian 12 runtime gate, Production Parity e Stream Identity concluíram com sucesso.

## Baseline de produção

Em 2026-09-21 o operador informou que o XLX026 e sua tela ativa estavam funcionando perfeitamente.

Classificação: **OPERATOR**. O CI atual não transforma esse relato em evidência `PROD`.

## Atenções

1. A última GitHub Release observada é **v1.2.14**, enquanto `VERSION` e README declaram **1.4.6**.
2. `main` permanece sem proteção de branch no estado observado em 2026-09-28.
3. Alterações no XLXD core, protocolos, áudio/transcoding, rede ou produção exigem laboratório + rollback.
4. Branches funcionais pendentes não devem ser mescladas em bloco apenas por existirem.
5. O backlog de pesquisa está em `docs/RESEARCH_BACKLOG.md`.

## Fonte de verdade

Comece por `PROJECT_START_HERE.md`.
