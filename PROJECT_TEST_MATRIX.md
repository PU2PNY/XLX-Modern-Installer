# PROJECT_TEST_MATRIX — XLX Modern Installer

Status permitidos: PASS / FAIL / PARCIAL / PENDENTE.
Níveis de evidência: DOC / SW / ENV / HW / PROD / OPERATOR.

> Regra: existência de teste no repositório não significa que o teste passou no commit atual.

| ID | Requisito | Verificação | Evidência atual | Status |
|---|---|---|---|---|
| TEST-001 | INSTALL-001 | Instalação limpa Debian 12 chega ao estado final | workflow `debian12-runtime-gate.yml` existe; execução atual não confirmada | PENDENTE |
| TEST-002 | UI-002 | Live mantém início/fim e multi-TX sem travar | `tests/regression-production-parity.sh` e testes de runtime existem | PENDENTE |
| TEST-003 | UI-005/006 | Identidade de stream/callsign/TA sem colisão | `tests/regression-stream-identity.php` existe | PENDENTE |
| TEST-004 | ADMIN-001/002 | Admin funcional sem terminal arbitrário | testes de control/admin existem | PENDENTE |
| TEST-014 | ADMIN-003 / PERF-001 | Operação privada >15 s não deve herdar timeout público nem ampliar o orçamento global | branch `fix/admin-control-timeout-20260923`: suíte `tests/test-current-panel-runtime-parity.sh` PASS completa em WartyWallaby, render da rota + `nginx -t` PASS; probe PHP de 18 s no Admin retornou HTTP 200 (~20 s) enquanto rota pública equivalente manteve HTTP 504 (~15 s); XLX026 `nginx -t`, reload e probes públicos/Admin HTTP 200 PASS; novo POST autenticado mutável ainda não repetido | PARCIAL (SW/ENV/PROD) |
| TEST-005 | SEC-001/002 | Auditoria de segredos e artefatos privados | CI e política existem; execução atual não confirmada | PENDENTE |
| TEST-006 | APRS-001/002 | Conta/reset preserva hash e revogação | testes de contrato documentados no repositório | PENDENTE |
| TEST-007 | CERT-001/002 | HMAC válido aceita e adulteração rejeita | `tests/test-certificate-hmac.php` existe | PENDENTE |
| TEST-008 | INSTALL-004 | Falha ACME recuperável não destrói instalação | comportamento documentado; execução atual não confirmada | PENDENTE |
| TEST-009 | BACKUP-001 | Backup criado antes de mudança crítica | comportamento documentado | PENDENTE |
| TEST-010 | BACKUP-002 | Restauração real de backup | sem evidência atual de restore test nesta auditoria | PENDENTE |
| TEST-011 | UI-008 | 6 idiomas sem traduzir contratos técnicos | workflow/commit atual declara isolamento de idiomas | PENDENTE |
| TEST-012 | PERF-003 | Performance comparada contra baseline | não houve benchmark executado nesta atualização | PENDENTE |
| TEST-013 | PROD baseline | Servidor e tela ativos sem regressão | relato do operador 2026-09-21 | PARCIAL (OPERATOR) |

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
