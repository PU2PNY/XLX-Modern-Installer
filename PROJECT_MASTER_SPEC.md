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
- **UI-010** — Ranking deve preservar estatísticas persistentes entre viradas de dia/mês, oferecer períodos Hoje, 7 dias, mês corrente e ano corrente, e evitar aparência de painel vazio na virada da meia-noite quando houver histórico recente.
- **UI-011** — A página e os contadores de Conectados não podem contar múltiplos `NODE` do XLXD como estações diferentes quando representam a mesma identidade, sufixo, protocolo e módulo. A sessão pública canônica é a de atividade mais recente; a lista bruta deve permanecer disponível internamente para correlação de TX/endpoint.
- **UI-012** — Nós DExtra internos do próprio XLXD não são estações de usuário e não podem aparecer nem inflar os contadores públicos de Conectados. A exclusão exige evidência local: protocolo DExtra, endpoint igual ao endereço do próprio XLXD e ausência de `Via`/`Peer`; conexões remotas ou de outros protocolos permanecem visíveis.

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
- **OBS-003** — O analisador de transmissão deve ser passivo: pode observar metadados e temporização de frames para diagnosticar integridade, mas não pode alterar, atrasar, retransmitir ou substituir o caminho de áudio/protocolo. O V1 cobre transporte YSF e não deve declarar análise acústica sem decodificação comprovada do áudio.
- **PERF-001** — Evitar polling, loops, gravações, consultas e chamadas externas desnecessárias.
- **PERF-002** — Não sacrificar estabilidade do Live por efeitos visuais ou coleta excessiva.
- **PERF-003** — Mudanças de performance exigem comparação contra baseline.

### HELIX / LEGACY RADIO COMPATIBILITY
- **HELIX-001** — Helix é opcional. A ausência, falha ou incompatibilidade do Helix não pode impedir um rádio legado compatível de usar o caminho DMR/YSF/D-Star já funcional.
- **HELIX-002** — A primeira integração usa fronteira de processo e IPC local PCM; o decoder/encoder de codec legado permanece fora do núcleo Helix.
- **HELIX-003** — O cliente PCM deve ser fail-open: erro, timeout ou resposta inválida preserva o PCM legado original. Em `process`, após a primeira falha de um stream, o restante daquele stream permanece no caminho legado para evitar alternância repetida de processamento. Nenhuma dependência remota/cloud pode entrar no hot path.
- **HELIX-004** — O estado padrão em produção é `off`. `shadow` usa IPC Unix datagram não bloqueante, sem esperar resposta e sem comitar PCM. `process` usa request/reply local com timeout estritamente limitado (máximo 5 ms na V1, com orçamento total por requisição) e exige validação ENV e gate separado de áudio/rollback antes de produção.
- **HELIX-005** — Usuários sem Helix não podem exigir firmware, rádio ou hotspot especial para continuar conversando pelos protocolos legados suportados.
- **HELIX-006** — O orçamento IPC é uma única deadline monotônica de 1..5 ms para conectar, escrever e ler a resposta completa. Conexão e I/O não podem bloquear sem limite; respostas atrasadas não podem comitar PCM. A primeira falha mantém o stream em legado conforme HELIX-003. O sistema operacional não oferece garantia hard real-time.

### STEREO TOOL / EXTERNAL DSP
- **ST-001** — Stereo Tool é opcional e proprietário. O repositório/instalador público não pode redistribuir `libStereoTool`, CLI, licença, chave ou pacote do fornecedor; o artifact deve ser fornecido pelo administrador.
- **ST-002** — Qualquer biblioteca proprietária do Stereo Tool deve ser carregada somente em worker isolado (`xlx-stereotoold` ou equivalente), nunca dentro de `xlxd`, `xuvd`, PHP/Nginx ou processo web.
- **ST-003** — O data plane usa somente IPC local; o worker de produção não pode expor web UI do Stereo Tool nem abrir `AF_INET`/`AF_INET6`. Cloud/API externa não entra no hot path.
- **ST-004** — Estado DSP deve ser independente por stream/PTT. Saturação de contexto produz bypass, não fila de voz. Mudança de preset/artifact é geracional e não altera PTT já aberto.
- **ST-005** — `PROCESS` deve ser fail-open e sticky por PTT: primeira falha usa PCM original até fechar o stream. Antes de qualquer canário, o bypass original deve ser delay-matched ao caminho processado para evitar salto temporal.
- **ST-006** — Upload de artifact executável exige privilégio elevado, quarentena, limites de tamanho/quantidade, SHA-256, inspeção ZIP segura, ELF/arquitetura/GLIBC/símbolos, sandbox posterior e trilha de auditoria. Artifact ativo é imutável e não pode ser apagado/substituído durante validação de outro.
- **ST-007** — Identificadores e chamadas runtime do SDK não podem ser inventados. Inicialização/processamento/settings/meters/presets só serão implementados contra headers/exemplos da versão efetivamente licenciada.
- **ST-008** — Produção com `PROCESS_CANARY`/`PROCESS` exige autorização comercial/jurídica escrita do fornecedor para refletor multiusuário, definição de “instance”/contextos e uso de SDK/servidor público, além de licença runtime válida.
- **ST-009** — A primeira etapa permitida é fundação de laboratório e validação estática. `READY_FOR_SANDBOX` não equivale a artifact aprovado, licença válida, qualidade aprovada, `SHADOW` ou `PROCESS`.
- **ST-010** — Stereo Tool e Helix não devem ser empilhados automaticamente no caminho de áudio. Qualquer comparação/combinação futura requer corpus comum, benchmark, A/B e gate de rollback independente.

### BACKUP / RECOVERY
- **BACKUP-001** — Backups preventivos devem existir antes de mudanças críticas.
- **BACKUP-002** — Backup só é considerado confiável após teste de restauração correspondente.
- **REC-001** — Cada mudança de alto risco deve definir rollback antes da execução.
- **REC-002** — Regressão grave contra baseline funcional deve bloquear promoção.

### GOVERNANÇA
- **GOV-001** — Os documentos canônicos `PROJECT_START_HERE.md`, `PROJECT_MASTER_SPEC.md`, `PROJECT_RELEASE_STATUS.md` e `PROJECT_TEST_MATRIX.md` devem existir na branch principal mantida.
- **GOV-002** — Documentação de arquitetura/operação deve refletir o fluxo autoritativo atual; o legado Apache não pode ser descrito como stack web principal enquanto `install.sh` usar `modules/70-nginx.sh`.

### TEST / RELEASE
- **TEST-001** — Build/CI PASS não equivale a PROD PASS.
- **TEST-002** — Todo requisito crítico deve possuir teste ou critério de aceitação verificável.
- **REL-001** — Versão, tag, release, README e `VERSION` devem ser coerentes.
- **REL-002** — Uma release só é “operacionalmente pronta” após os gates definidos para seu nível de evidência.

## 3. Arquitetura canônica
Consultar `ARCHITECTURE.md`. Componentes atualmente documentados incluem XLXD core, Echo opcional, Nginx + PHP-FPM, dashboard, callsign database, CallingHome, APRS/D-PRS, certificados, observabilidade, Admin privado, módulos de instalação e suíte de regressão.

A arquitetura e os gates de Stereo Tool ficam detalhados em `docs/STEREOTOOL_INTEGRATION.md`.

## 4. Segurança
Consultar `SECURITY.md`. Segredos não podem ser copiados para documentação de governança.

## 5. Critérios de aceitação globais
Uma mudança só é aceita se:
1. preserva os invariantes acima;
2. não introduz regressão conhecida;
3. possui evidência proporcional ao risco;
4. possui rollback quando necessário;
5. atualiza documentação/testes/histórico se altera permanentemente o projeto.

### HELIX SHADOW PROD / IA
- **HELIX-007** — Quando `shadow` for explicitamente habilitado pelo operador em produção, a interface deve identificá-lo como observação/monitoramento, nunca como processamento do áudio. O caminho transmitido continua legado; indisponibilidade do observador não pode derrubar o áudio.
- **HELIX-008** — Monitoramento por IA do Helix fica fora do hot path. Somente telemetria técnica agregada pode sair do servidor; áudio, conteúdo de voz, indicativos e payloads de rádio não são enviados à IA. Falha da API externa não pode afetar XLXD, xuvd ou o áudio.
- **HELIX-009** — O monitor local deve validar serviço Helix, socket, xuvd, XLXD, hash do candidato e fallbacks; chamadas externas devem ser limitadas e orientadas a resumo/anomalia, preservando baixo consumo.

### TX TURN GUARD / ANTI-PING-PONG
- **TURN-001** — O TOT existente de 180 s permanece independente e não pode ser alterado por este recurso.
- **TURN-002** — A detecção V1 é por módulo lógico: `A -> B -> A` somente arma a dupla quando os dois intervalos EOT→novo stream são de até 2.000 ms por padrão. Uma alternância isolada A→B não basta.
- **TURN-003** — Depois de armada a dupla, cada EOT de A ou B inicia 7.000 ms de inelegibilidade para novo stream DV de voz somente para A/B naquele módulo. Tentativa negada não reinicia nem prolonga o prazo; em `elapsed >= 7000 ms`, a estação volta a ser elegível.
- **TURN-004** — Terceira estação C não pode ser bloqueada pela dupla e, ao conseguir abrir stream no mesmo módulo, quebra o estado A/B. Estado de um módulo não bloqueia módulo independente.
- **TURN-005** — A identidade usada é o `MY`/origem transmissora já normalizada pelo XLXD; gateway, peer, IP ou repetidora não podem substituir o operador quando a origem estiver disponível. O relógio de decisão é monotônico e o estado é efêmero.
- **TURN-006** — O guard atua somente na admissão de novo stream DV. Keepalive, conexão e controle fora de stream não são bloqueados. Qualquer protocolo que transportar comando legítimo como stream DV exige exceção explícita comprovada em ENV antes de produção.
- **TURN-007** — O recurso permanece `off` por padrão no candidato. Habilitação requer variável explícita, validação de DMR/YSF/D-Star, backup e restore testado.
- **TURN-008** — A IA é somente observadora consultiva, fora do hot path. Pode receber apenas contadores técnicos agregados sem áudio, conteúdo de voz, indicativo, RadioID, IP ou payload; falha ou opinião da IA nunca pode liberar/bloquear stream nem alterar o temporizador local.
