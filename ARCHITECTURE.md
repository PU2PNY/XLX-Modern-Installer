# Architecture

Atualizado em: 2026-09-28

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
- `observability/` — Health, DMR data/meta, YSF data, analisador passivo de integridade de transmissão, histórico e self-test.
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


## Helix Voice — fronteira experimental

A integração Helix inicial é uma fronteira de processo, não uma substituição direta do XLXD nem do codec dos rádios.

```text
rádio legado -> XLXD -> backend codec legado -> PCM -> Helix (IPC local)
                                             <- PCM <-
                    -> backend codec legado -> rádio legado
```

Regras:
- backend AMBE/AMBE+2 permanece externo ao núcleo Helix;
- `off` é o padrão;
- `shadow` envia PCM ao Helix e descarta a resposta;
- `process` só comita PCM após resposta completa e válida;
- falha/timeout do Helix preserva o PCM original;
- ausência de Helix não pode impedir operação de rádio legado;
- nenhum serviço remoto faz parte do hot path de áudio.

A implementação inicial está em `experimental/helix-bridge/` e não é instalada/ativada automaticamente.
