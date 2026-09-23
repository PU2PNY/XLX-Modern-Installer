# PROJECT_MASTER_SPEC — XLX Modern Installer / XLX026

Fonte oficial de requisitos técnicos e operacionais. Este documento não substitui README, CHANGELOG, SECURITY ou código; ele define os invariantes que futuras mudanças devem preservar.

## 1. Objetivo
Fornecer um instalador público, reproduzível e seguro para refletor XLXD em Debian 12 x86_64, baseado no ambiente validado do XLX026, com dashboard moderno multiprotocolo, operação observável, Administração privada e mecanismos de recuperação.

## 2. Requisitos e invariantes

### CORE
- **CORE-001** — Instalação deve usar um único motor autoritativo: `install.sh`.
- **CORE-002** — Não sobrescrever silenciosamente uma instalação XLXD ativa.
- **CORE-003** — Preservar atribuições/licenças do XLXD upstream e da base técnica usada.
- **CORE-004** — Atualização do XLXD core só pode ser promovida após teste em laboratório/VPS e regressão de protocolos/áudio.
- **CORE-005** — Não assumir que versão numericamente mais nova é mais estável.

### INSTALL
- **INSTALL-001** — Debian 12 x86_64 é o alvo público documentado.
- **INSTALL-002** — `start.sh` é o caminho recomendado para iniciantes; `install.sh --check` é preflight somente leitura.
- **INSTALL-003** — Não executar `full-upgrade` obrigatório como efeito colateral da instalação.
- **INSTALL-004** — Falha recuperável de HTTPS/ACME não deve destruir uma instalação válida.
- **INSTALL-005** — Falhas inesperadas devem informar arquivo, linha, código de retorno e comando, sem saída silenciosa.
- **INSTALL-006** — Toda alteração destrutiva relevante deve possuir backup/ponto de retorno antes da mudança.

### WEB/UI
- **UI-001** — Dashboard público deve permanecer responsivo, legível, multilíngue e independente de credenciais de produção.
- **UI-002** — Live TX/RX deve manter baixa latência, início/fim estáveis e suporte a múltiplas transmissões conforme implementação validada.
- **UI-003** — Histórico público visível deve manter a política documentada de 24 horas no instalador; extensões adicionais do dashboard standalone devem ser tratadas como recurso separado e testadas.
- **UI-004** — Connected e Modules permanecem páginas independentes.
- **UI-005** — Identidade no Live: callsign do log é a fonte transmissora; gateway/repeater diferente só com evidência exata.
- **UI-006** — Talker Alias é metadado suplementar e não substitui identidade RadioID.
- **UI-007** — GPS/APRS/D-PRS só pode ser exibido como posição quando houver dado observado, nunca por inferência de cadastro.
- **UI-008** — Rotas, IDs, nomes de arquivos, APIs e contratos técnicos não podem ser traduzidos.
- **UI-009** — Publicação não deve reintroduzir páginas deliberadamente excluídas do pacote público sem decisão registrada.

### DATA / APRS / CERTIFICATES
- **DATA-001** — Correções locais de callsign devem sobreviver a refresh do diretório upstream.
- **APRS-001** — APRS/D-PRS nativo deve preservar hash-only de senha e rotação/revogação no reset.
- **APRS-002** — Dados sensíveis de recuperação não devem ser gravados em payloads de auditoria.
- **CERT-001** — Certificados devem usar emissão persistida, HMAC versionado e verificação em tempo constante.
- **CERT-002** — Segredo HMAC deve permanecer fora do webroot.

### ADMIN / SECURITY
- **ADMIN-001** — Administração privada não deve expor terminal SSH/Linux nem terminal XLXD arbitrário.
- **ADMIN-002** — Ações privilegiadas devem usar helpers limitados, não sudo arbitrário no navegador.
- **ADMIN-003** — Operações administrativas legítimas que excedam o orçamento HTTP público devem usar exceção de timeout limitada à rota privada; não ampliar o timeout global para mascarar operação lenta.
- **SEC-001** — Nenhum segredo de produção no Git.
- **SEC-002** — `.gitignore` deve continuar cobrindo chaves, certificados, bancos, env, backups e segredos.
- **SEC-003** — Admin deve preservar CSRF, sessão, rate limiting e auditoria.
- **SEC-004** — Portas e serviços devem seguir princípio de menor exposição.

### OBSERVABILITY / PERFORMANCE
- **OBS-001** — Serviços críticos devem ter estado verificável por health/status/logs.
- **OBS-002** — Erros operacionais devem ser diagnosticáveis sem expor segredos.
- **PERF-001** — Evitar polling, loops, gravações, consultas e chamadas externas desnecessárias.
- **PERF-002** — Não sacrificar estabilidade do Live por efeitos visuais ou coleta excessiva.
- **PERF-003** — Mudanças de performance exigem comparação contra baseline.

### BACKUP / RECOVERY
- **BACKUP-001** — Backups preventivos devem existir antes de mudanças críticas.
- **BACKUP-002** — Backup só é considerado confiável após teste de restauração correspondente.
- **REC-001** — Cada mudança de alto risco deve definir rollback antes da execução.
- **REC-002** — Regressão grave contra baseline funcional deve bloquear promoção.

### TEST / RELEASE
- **TEST-001** — Build/CI PASS não equivale a PROD PASS.
- **TEST-002** — Todo requisito crítico deve possuir teste ou critério de aceitação verificável.
- **REL-001** — Versão, tag, release, README e `VERSION` devem ser coerentes.
- **REL-002** — Uma release só é “operacionalmente pronta” após os gates definidos para seu nível de evidência.

## 3. Arquitetura canônica
Consultar `ARCHITECTURE.md`. Componentes atualmente documentados incluem XLXD core, Echo opcional, Nginx + PHP-FPM, dashboard, callsign database, CallingHome, APRS/D-PRS, certificados, observabilidade, Admin privado, módulos de instalação e suíte de regressão.

## 4. Segurança
Consultar `SECURITY.md`. Segredos não podem ser copiados para documentação de governança.

## 5. Critérios de aceitação globais
Uma mudança só é aceita se:
1. preserva os invariantes acima;
2. não introduz regressão conhecida;
3. possui evidência proporcional ao risco;
4. possui rollback quando necessário;
5. atualiza documentação/testes/histórico se altera permanentemente o projeto.
