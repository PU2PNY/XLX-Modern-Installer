# Architecture

Atualizado em: 2026-09-21

## Fluxo autoritativo

1. `start.sh` — launcher recomendado para iniciantes.
2. `install.sh` — motor autoritativo de instalação.
3. preflight e validação de configuração.
4. bloqueio contra sobrescrita de XLXD ativo/restos não resolvidos.
5. revisão final.
6. backup preventivo.
7. preparação de dependências.
8. instalação/configuração do XLXD.
9. Echo opcional.
10. dashboard moderno.
11. **Nginx + PHP-FPM**.
12. APRS/D-PRS nativo.
13. observabilidade/Health/history/self-test.
14. Admin privado e helpers limitados.
15. validação pós-instalação e relatório final.

## Evidência no código

No `install.sh` atual:
- o módulo executado para o web stack é `modules/70-nginx.sh`;
- a validação espera `XLX_EXPECT_WEB_STACK=nginx`;
- serviços verificados incluem `nginx`, `php8.2-fpm` e `xlxd`;
- `nginx -t` faz parte da validação;
- Apache ativo é tratado como condição a verificar, não como stack principal.

O arquivo legado `modules/70-apache.sh` ainda existe no repositório, mas não é chamado pelo fluxo autoritativo atual observado em `install.sh`. Não o trate como arquitetura principal sem nova evidência.

## Componentes

- `vendor/pp5pk-installer/` — base técnica revisada/pinada para XLXD.
- `dashboard/` — painel público, APIs e componentes nativos.
- `control/` — Administração privada, builders e helpers.
- `modules/` — estágios controlados de instalação.
- `observability/` — Health, DMR data/meta, YSF data, histórico e self-test.
- `tests/` — regressões e contratos.
- `.github/workflows/` — CI e gates.
- `scripts/` — auditoria/manutenção/backup quando aplicável.

## Invariantes

- produção saudável não é ambiente de experimento;
- mudanças críticas exigem rollback;
- nenhuma credencial de produção entra no Git;
- CI não equivale a PROD;
- identidade e posição no painel dependem de evidência real, não inferência;
- atualização de XLXD/dependências críticas exige validação de compatibilidade.

Consulte `PROJECT_MASTER_SPEC.md` para requisitos e `docs/RECOVERY.md` para rollback.
