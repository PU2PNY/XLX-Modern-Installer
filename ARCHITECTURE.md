# Architecture

Atualizado em: 2026-10-02

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
- `shadow` envia PCM por datagrama Unix não bloqueante, sem esperar resposta;
- `process` só comita PCM após resposta completa e válida;
- falha/timeout do Helix preserva o PCM original;
- ausência de Helix não pode impedir operação de rádio legado;
- nenhum serviço remoto faz parte do hot path de áudio.

A implementação inicial está em `experimental/helix-bridge/` e não é instalada/ativada automaticamente.

## Stereo Tool — fronteira de processo e fundação LAB

Stereo Tool não é dependência do XLXD nem do transcoder legado. A arquitetura aprovada para uma futura integração é:

```text
XLXD / backend legado -> PCM -> xlx-audio-router -> encoder legado
                               |              ^
                               |              |
                               +-- IPC AF_UNIX --> xlx-stereotoold
                                                    |
                                                    v
                                               libStereoTool
```

A primeira implantação em `experimental/stereotool/` contém apenas validação estática de artifact, mock de teste, documentação e referência de hardening. Ela não instala a biblioteca do fornecedor, não altera `xlxd`/`xuvd` e não entra no áudio.

Invariantes:
- biblioteca proprietária somente em processo isolado futuro;
- nenhuma redistribuição de artifact/licença proprietários;
- worker sem `AF_INET`/`AF_INET6` e sem web UI do fornecedor;
- artifact fornecido pelo administrador passa por quarentena, SHA-256, ZIP seguro, ELF/arquitetura/GLIBC/símbolos antes de qualquer load test;
- contexto DSP independente por stream/PTT;
- falta de capacidade produz bypass, nunca fila de voz;
- fail-open sticky por PTT;
- `PROCESS` futuro exige bypass original delay-matched;
- artifact/preset ativo é imutável e troca é geracional;
- autorização comercial/jurídica escrita e licença válida são gates de produção;
- Helix e Stereo Tool não são empilhados automaticamente.

Detalhes e gates: `docs/STEREOTOOL_INTEGRATION.md`.

## TX Turn Guard / anti-ping-pong — candidato experimental

O candidato em `experimental/tx-turn-guard/` adiciona uma política de admissão de **novo stream DV**, não um DSP e não um proxy de áudio. O hook fica no caminho central de `CReflector::OpenStream()` para que DMR, YSF/C4FM e D-Star possam compartilhar a mesma regra depois de validação individual.

```text
header DV -> valida cliente/módulo/stream livre -> TX Turn Guard -> CPacketStream::Open()
                                                     |
                                                     +-- allow -> caminho XLXD existente
                                                     +-- deny  -> header recusado; nenhum stream novo
```

Estado é separado por módulo e protegido por mutex. O relógio usa `std::chrono::steady_clock`. A identidade é `MY`/origem do `CDvHeaderPacket`, não IP/gateway. A sequência rápida `A -> B -> A` arma a dupla; após EOT, somente A/B aguardam 7 s. Terceiro C continua livre e quebra a dupla. O TOT de 180 s não é alterado.

O patch é `off` por padrão e a configuração V1 só é habilitada por ambiente explícito. Keepalive/Wires-X/conexão que não abrem stream DV permanecem fora do hook; comandos que eventualmente usem DV comum precisam de teste específico antes de produção.

O observador `xlx-tx-turn-ai-monitor.py` é processo/timer separado. Ele lê somente eventos técnicos `TXTURN` sem identidade de estação, agrega contadores e pode solicitar análise consultiva à OpenAI. A resposta da IA nunca retorna ao caminho de admissão e não pode alterar timer, permitir ou negar transmissão. Falha de rede/API é operacionalmente irrelevante ao XLXD.


## Reproducible recovery runtime (2026-10-05)

The installer builds the pinned upstream XLXD plus the versioned TOT180/Turn
Guard patch before applying operator settings. Turn Guard remains OFF by
default. `modules/72-live-runtime.sh` builds the locked Rust Live core and
installs the Node SSE fallback, both listening on loopback. Nginx routes browser
WebSocket/SSE requests to these services; the hub reads the existing PHP API
through a localhost-only route. No production identity or OpenAI key is required.

The Control source follows current production navigation/layout and renders
operator identity, URL slug and six languages from configuration. Optional
Helix/audio/VU references preserve source provenance without enabling process
mode. Recovery snapshots include consistent SQLite copies and actual running
ELFs, because a source directory on disk may be stale. Restore verification
extracts into a private empty staging directory; activating a replacement host
is a separate operational step described in `docs/RECOVERY.md`.
