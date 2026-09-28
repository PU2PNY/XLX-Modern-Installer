# XLX026 — REGRAS PERMANENTES PARA IA / CONVERSA

## Identidade do projeto
Projeto: XLX026 / XLX Modern Installer / dashboard multiprotocolo.
Repositório canônico principal: `PU2PNY/XLX-Modern-Installer`.
Dashboard standalone relacionado: `PU2PNY/XLX-Modern-Dashboard`.

## Regra zero
Antes de analisar, planejar, programar, corrigir, publicar, fazer deploy ou modificar o projeto:
1. leia `PROJECT_START_HERE.md`;
2. leia `PROJECT_MASTER_SPEC.md`;
3. leia `PROJECT_RELEASE_STATUS.md`;
4. leia `PROJECT_TEST_MATRIX.md`;
5. leia `CHANGELOG.md`;
6. leia `ARCHITECTURE.md`, `SECURITY.md`, `docs/OPERATIONS.md`, `docs/RECOVERY.md`, `docs/DECISIONS.md` e `docs/RESEARCH_BACKLOG.md` quando relevantes;
7. confirme branch, commit, versão e código atuais;
8. só então proponha ou execute mudanças.

GitHub + documentação versionada são a memória técnica persistente. A conversa é ambiente de trabalho.

## Baseline
Em 2026-09-21 o operador informou que o servidor XLX026 e a tela ativa estavam funcionando perfeitamente. Preserve esse estado como baseline operacional. Não faça refatoração, atualização ou “melhoria” que arrisque regressão sem necessidade comprovada, teste e rollback.

## Verdade e evidência
Use níveis separados:
- DOC: documentação/código;
- SW: teste local/automatizado;
- ENV: VPS/staging;
- HW: hardware real;
- PROD: produção validada diretamente;
- OPERATOR: relato do operador.

Nunca converta um nível em outro por inferência.
CI PASS não é PROD PASS.
Build PASS não é protocolo/áudio funcionando.
Deploy concluído não é validação funcional.

Nunca invente logs, testes, commits, versões, métricas, portas, serviços, status, resultados ou acessos.

## Mudanças
Toda mudança permanente relevante segue:
**decisão → requisito/ID → MASTER_SPEC → TEST_MATRIX → implementação → teste → RELEASE_STATUS → CHANGELOG.**

Não remova requisito aprovado silenciosamente.
Não recomece o projeto do zero.
Não substitua implementação comprovadamente funcional apenas para modernizar.
Não altere `main` diretamente quando branch + PR puderem ser usados.

## Segurança
Nunca grave no GitHub:
- senhas;
- tokens;
- API keys;
- chaves privadas;
- certificados privados;
- sessões;
- bancos reais;
- backups de produção;
- logs sensíveis;
- credenciais de serviços;
- configuração contendo segredos.

Se detectar segredo exposto: não reproduza; trate como incidente e recomende rotação.

## XLXD e protocolos
Não atualizar XLXD apenas porque existe versão numericamente superior.
Mudanças no core, D-Star, DMR, YSF/C4FM, interlinks, AMBE/transcoding, Talker Alias, CallingHome, portas, systemd ou áudio exigem:
1. evidência do problema;
2. backup;
3. laboratório/VPS;
4. testes de regressão;
5. rollback;
6. somente então produção.

Recomendações de fórum/comunidade são hipóteses até serem confirmadas localmente. Consulte `docs/RESEARCH_BACKLOG.md`.

## Dashboard / Live
Preservar:
- baixa latência;
- estabilidade de abertura/fechamento de TX/RX;
- múltiplas transmissões;
- identidade correta do callsign;
- gateway/repeater somente com evidência;
- Talker Alias apenas suplementar;
- APRS/D-PRS/GPS apenas quando observado;
- responsividade;
- acessibilidade;
- compatibilidade documentada;
- consumo baixo;
- histórico e dados sem loops/polling desnecessários.

Não adicionar efeito visual ou coleta que torne o painel pesado.

## Web stack
No fluxo autoritativo observado em `install.sh`, o stack principal é Nginx + PHP-FPM e o módulo chamado é `modules/70-nginx.sh`. O arquivo legado `modules/70-apache.sh` existe, mas não deve ser tratado como stack principal sem nova evidência.

## Backup e rollback
Antes de mudança de alto risco:
1. registrar branch/commit/versão;
2. registrar baseline;
3. criar backup/ponto de retorno;
4. limitar escopo;
5. alterar uma coisa por vez;
6. testar;
7. comparar com baseline;
8. reverter se houver regressão grave.

Backup só é confiável depois de restore test correspondente.

## Performance
Evite polling excessivo, loops agressivos, gravação repetida, chamadas externas duplicadas, processos redundantes, cache sem limite e logs sem rotação.
Prefira eventos, consultas sob demanda, cache controlado, backoff, deduplicação e rate limiting quando adequados.
Meça antes e depois.

## Estado atual de documentação
Versão declarada no branch analisado: 1.4.6.
Há uma divergência registrada entre `VERSION`/README (1.4.6) e a última GitHub Release observada (v1.2.14). Não inventar resolução; reconciliar com teste/release quando apropriado.

## Fluxo de nova conversa
Não releia milhares de mensagens primeiro.
Comece pelo GitHub e por `PROJECT_START_HERE.md`.
Reconstrua o estado técnico pelos documentos canônicos.
Use conversas antigas apenas para preencher lacunas ou investigar decisões não registradas.

## Regra final
A IA deve poder ser substituída amanhã sem perder o projeto.
Tudo que for essencial para continuar o XLX026 deve terminar versionado no GitHub, com evidência, teste e histórico suficientes para outra IA ou desenvolvedor continuar com segurança.
