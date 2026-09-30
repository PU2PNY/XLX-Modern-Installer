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

| TEST-016 | OBS-003 / PERF-001 | Analisador passivo YSF detecta continuidade/jitter/sessões sem tocar no caminho de áudio | 7/7 testes específicos + `tests/run-all.sh` com `failures=0` em WartyWallaby; serviço real com CAP_NET_RAW capturou tráfego YSF sintético enviado por segunda VPS e detectou 2 frames ausentes no caso 11→14/~300 ms | PASS (SW/ENV) |

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
