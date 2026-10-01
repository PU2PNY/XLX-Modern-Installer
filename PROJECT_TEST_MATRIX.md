# PROJECT_TEST_MATRIX — XLX Modern Installer

Status permitidos: PASS / FAIL / PARCIAL / PENDENTE.
Níveis de evidência: DOC / SW / ENV / HW / PROD / OPERATOR.

> Regra: existência de teste no repositório não significa que o teste passou no commit atual.

| ID | Requisito | Verificação | Evidência atual | Status |
|---|---|---|---|---|
| TEST-001 | INSTALL-001 | Instalação Debian 12 / runtime gate | workflow `Debian 12 runtime gate` concluiu com sucesso em `4cb8dc37c35e29f107a77090dc9bec287e863bea`; não substitui VPS descartável completa | PARCIAL (SW/CI) |
| TEST-002 | UI-002 | Live mantém início/fim e multi-TX sem travar | `Production parity regression` concluiu com sucesso em `4cb8dc37c35e29f107a77090dc9bec287e863bea`; sem nova medição PROD | PARCIAL (SW/CI) |
| TEST-003 | UI-005/006 | Identidade de stream/callsign/TA sem colisão | `Stream identity regression` concluiu com sucesso em `4cb8dc37c35e29f107a77090dc9bec287e863bea` | PASS (SW/CI) |
| TEST-004 | ADMIN-001/002 | Admin funcional sem terminal arbitrário | suíte geral CI concluiu com sucesso em `4cb8dc37c35e29f107a77090dc9bec287e863bea`; ação administrativa mutável real não foi repetida nesta auditoria | PARCIAL (SW/CI) |
| TEST-005 | SEC-001/002 | Auditoria de segredos e artefatos privados | CI geral inclui `scripts/public-release-audit.sh` e concluiu com sucesso em `4cb8dc37c35e29f107a77090dc9bec287e863bea` | PASS (SW/CI) |
| TEST-006 | APRS-001/002 | Conta/reset preserva hash e revogação | contratos automatizados existem; sem nova validação ENV nesta auditoria | PARCIAL (SW/CI) |
| TEST-007 | CERT-001/002 | HMAC válido aceita e adulteração rejeita | testes automatizados existem; CI geral atual passou | PARCIAL (SW/CI) |
| TEST-008 | INSTALL-004 | Falha ACME recuperável não destrói instalação | teste contratual existe; CI geral atual passou | PARCIAL (SW/CI) |
| TEST-009 | BACKUP-001 | Backup criado antes de mudança crítica | comportamento documentado; sem nova execução ENV | PENDENTE |
| TEST-010 | BACKUP-002 | Restauração real de backup | sem evidência atual de restore test completo da revisão corrente | PENDENTE |
| TEST-011 | UI-008 | 6 idiomas sem traduzir contratos técnicos | CI geral atual passou e executa builds/testes multilíngues | PASS (SW/CI) |
| TEST-012 | PERF-003 | Performance comparada contra baseline | não houve benchmark novo nesta auditoria documental | PENDENTE |
| TEST-013 | PROD baseline | Servidor e tela ativos sem regressão | relato do operador em 2026-09-21 | PARCIAL (OPERATOR) |
| TEST-014 | ADMIN-003 / PERF-001 | Timeout privado não amplia orçamento público | PR #55 + evidência SW/ENV/PROD registrada em 2026-09-23; novo POST mutável autenticado ainda pendente | PARCIAL (SW/ENV/PROD) |
| TEST-015 | GOV-001/002 | Documentos canônicos presentes e arquitetura web coerente | `tests/test-project-governance.sh` executado no head final `9fb4d690...` da PR #65 dentro da suíte CI concluída com sucesso | PASS (SW/CI) |

| TEST-016 | OBS-003 / PERF-001 | Analisador passivo YSF detecta continuidade/jitter/sessões sem tocar no caminho de áudio | 7/7 testes específicos + `tests/run-all.sh` com `failures=0`; ENV: CAP_NET_RAW capturou YSF externo e detectou 2 frames ausentes no caso 11→14/~300 ms; PROD 2026-09-30: serviço ativo ~10 MB, >1.500 YSFP reais, sem listener UDP adicional, PID XLXD inalterado e detecção real `PS7JAP concurrent_endpoints=2`; nenhum YSFD real ocorreu na janela PROD | PASS (SW/ENV) + PARCIAL (PROD) |

| TEST-017 | HELIX-001/002/003/004/005 | Bridge PCM local preserva fallback legado, shadow sem alteração e processamento somente após resposta válida | SW: contrato C++ PASS. ENV/WartyWallaby: off=fallback=shadow bit-idênticos (SHA-256 `0927cfff...1074f`); shadow 40/40; process single-stream 40/40; Helix ausente fixa stream no legado e entrega 40/40; 2 streams entregam 60/60 com fallback seguro de um stream | PASS (SW/ENV) |

| TEST-021 | UI-010 | Ranking preserva histórico na virada de dia/mês, inclui período anual e mantém persistência no instalador | PR #67: cinco workflows PASS no head `468638a8...`; PROD 2026-10-01: API v3 com `year`, `/ranking` HTTP 200 e botão ANUAL, XLXD PID 1093634 preservado; próxima virada 23:59→00:00 ainda não foi reobservada em PROD | PASS (SW/CI) + PARCIAL (PROD) |

| TEST-028 | UI-011 | Conectados elimina sessões XML duplicadas sem perder protocolo/módulo/sufixo distintos e preserva endpoints brutos para correlação de TX | WartyWallaby: teste específico PASS e `tests/run-all.sh` com `failures=0`; PR #72: quatro workflows CI PASS. PROD XLX026: primeira validação deixou 1 alias duplicado; após alias-before-canonicalization, 106/106 linhas, 0 grupos duplicados, rotas HTTP 200, XLXD PID 1093634 e xuvd PID 3729899 preservados. | PASS (SW/CI/PROD) |

## Como registrar PASS
Atualize a linha com:
- ambiente;
- versão;
- commit;
- comando/procedimento;
- resultado observado;
- link/log/artefato;
- nível de evidência.

Nunca transformar `OPERATOR` em `PROD`, ou `SW` em `ENV`, sem novo teste.

| TEST-018 | HELIX-004 / PERF-003 | Latência HXP1 request/reply | WartyWallaby, 2.000 frames: p50 0,085 ms; p95 0,319 ms; p99 0,817 ms; p99,9 1,750 ms; máximo 3,653 ms; nenhum >5 ms | PASS (ENV) |
| TEST-019 | HELIX-004 / REC-001 | Habilitar `process` em produção com áudio real, soak e rollback | bloqueado; transcoder PROD não foi substituído e a proveniência histórica OP25/mbelib do build ativo precisa ser reconciliada | PENDENTE (PROD) |

| TEST-020 | HELIX-001/004 / CORE-004 | Candidato bridge preserva saída do xuvd PROD conhecido-bom | ENV/Warty: corpus sintético nos 4 caminhos (2→1 A/C e 1→2 A/C) bit-idêntico; `shadow` 560/560 observações; corpus PROD de 828 frames reais 2→1 reproduzido com saída bit-idêntica em PROD-binary/off/shadow, 0 falhas | PASS (ENV; entrada adicional derivada de PROD) |

| TEST-021 | HELIX-003/004/006 | Deadline total com peer lento/travado, conexão saturada e header inválido | ENV/Warty: 11 cenários preservam PCM; dribble 5,246 ms e stall 5,229 ms observados; backlog 0,030 ms. Orçamento lógico 5 ms, scheduling pode acrescentar overshoot | PASS (ENV) |
| TEST-022 | HELIX-001/003/004/006 | E2E real AMBED com falha no meio e multi-TX | ENV: off/absent/shadow/shadow-kill bit-idênticos; process 40/40; process-kill 20 Helix + fallback e 40 entregues; uma execução multi entregou 80/80 com Helix 40/40 por stream; PCM baixo/alto isolado vs intercalado idêntico; 600 IDs, RSS 1252→1252 KiB. Repetibilidade é avaliada separadamente em TEST-024 | PASS (ENV, continuidade/isolamento) |
| TEST-023 | BACKUP-002 / REC-001 | Restore binário xuvd em laboratório | Backup→candidato→restore do ELF exato; SHA 4b72dfc7...e58069 e quatro caminhos de codec idênticos após restore. Não valida restore de unit/config/serviço PROD | PASS (ENV, binário) / PENDENTE (PROD, completo) |

Evidência sanitizada reproduzível: [Helix PCM bridge ENV](docs/evidence/helix-pcm-bridge-20260930.json), [wrapper ENV](docs/evidence/helix-pcm-bridge-wrapper-20260930.json) e [repetibilidade multi-TX](docs/evidence/helix-pcm-bridge-repeatability-20260930.json). Apenas métricas/hashes; nenhum áudio, PCAP ou segredo de produção.

| TEST-024 | HELIX-003/006 / PERF-003 | Repetibilidade multi-TX no script E2E completo | Wrapper: ambos 40/40, Helix 4/5 antes de fallback. Três repetições controladas adicionais: 35/34, 2/28 e 18/14 respostas Helix; em todas, 40/40 frames por stream, zero falha de codec e 1 fallback sticky por stream. Continuidade/fail-open PASS; confiabilidade `process` sob contenção PARCIAL; causa raiz não provada | PASS (ENV, continuidade) / PARCIAL (process/performance) |

| TEST-025 | BACKUP-002 / REC-001 / HELIX-004 | Restore completo do caminho shadow em ENV | WartyWallaby 2026-10-01: baseline service PASS → candidate shadow PASS → restore de binário + unit + drop-in/config + serviço; hash final do xuvd legado `4b72dfc7...e58069`; variável Helix removida após restore | PASS (ENV) |
| TEST-026 | HELIX-001/004/007/009 | Shadow em produção preserva XLXD e observa PCM real | XLX026 2026-10-01: XLXD PID 1093634 preservado; xuvd candidate `559f580b...75a243`; Helix/socket ativos. Streams reais observados 18/18, 108/108 e 72/72 `helix_ok`, todos com `helix_fallback=0` e `failures=0` | PASS inicial (PROD, shadow); soak 24 h PENDENTE |
| TEST-027 | HELIX-007/008/009 / PERF-001 | Telemetria/IA e indicador público não entram no hot path | monitor local 30 s; OpenAI a cada 15 min ou mudança de anomalia; primeira análise real retornou estado OK usando somente telemetria técnica; API `/api/helix-status.php` e assets JS/CSS HTTP 200; PHP lint, Python compile, Node syntax e Nginx config PASS. Validação visual por navegador externo ficou PENDENTE porque o túnel do navegador retornou `ERR_TUNNEL_CONNECTION_FAILED` | PASS (SW/PROD endpoint) / PENDENTE (visual externo) |
