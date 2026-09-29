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
| TEST-015 | GOV-001/002 | Documentos canônicos presentes e arquitetura web coerente | `tests/test-project-governance.sh` adicionado nesta correção; aguarda CI da PR | PENDENTE |

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

| TEST-016 | AUDIO-001/003 | Controlador adaptativo: referência, outliers, fail-open, janela robusta e hard cap ±1,0 codificado | WartyWallaby + commit 66d0dec5f92f22b11e34ad4e1e91bcd4d9f187f8: teste C++/contrato PASS; candidato ±3 anterior rejeitado e não promovido | PASS (ENV) |
| TEST-017 | AUDIO-002 | Modo adaptativo usa AdjustAmbeGain sem re-encode PCM/AMBE e preserva áudio nominal | replay offline no XLX026: mid e PU2UJY bit-exact; low/loud/MIZ corrigidos; MMDVM/DMRPlus failed=0 | PASS (ENV) |
| TEST-018 | AUDIO-001 | Sem OpenAI/API externa no caminho de áudio; 0 tokens por TX | contrato estático + WartyWallaby PASS no candidato atual | PASS (ENV) |
| TEST-019 | AUDIO-004/005 | Desativado por padrão; YSF/D-Star inalterados | adaptive_gain_dmr=0; escopo DMR somente; teste de rádio real/HW e PROD ainda pendentes | PARCIAL (DOC/SW/ENV) |

| TEST-020 | AI-001 | Segredo OpenAI fica fora do Git/browser e arquivo server-side usa 0600 | WartyWallaby: contrato 0600 PASS; PROD: API autenticada sem expor segredo e estado público sanitizado | PASS (ENV/PROD) |
| TEST-021 | AI-002/003 | Badge TX diferencia IA/DSP sem novo polling | PROD: status público retornou configured=true/api_connected=true com TX ativa; assets/integração já implantados | PASS (SW/ENV/PROD) |
| TEST-022 | AI-004 | V1 não envia áudio nem faz inferência; valida somente conectividade da API | WartyWallaby + PROD: autenticação da API confirmada; mensagem pública “IA conectada • monitoramento local ativo”; sem inferência contínua | PASS (SW/ENV/PROD) |

| TEST-023 | AI-006 / UI-002 | Indicador IA central na mesma linha do cabeçalho TX, autoajustável, sem animação contínua e sem novo polling | WartyWallaby contrato PASS; PROD 1365×768 confirmou IA entre “Transmitindo agora” e “NO AR”, sem linha extra, sobreposição ou perda de MTR/VU/dados | PASS (SW/ENV/PROD) |

| TEST-024 | AI-007 / SEC-001 | Controle exibe estado sanitizado da IA sem segredo e sem inferência fictícia | WartyWallaby: contrato, i18n e Controle funcional PASS; suíte completa `tests/run-all.sh` terminou `failures=0` no commit 06b988b727039074823a887130390d88911817b5; 5 workflows CI PASS; PROD: /controle/ HTTP 200, seção IA instalada, api_connected=true e serviços preservados | PASS (SW/ENV/PROD) |
