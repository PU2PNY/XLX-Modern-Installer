# TX turn guard + painel de espera — 2026-10-04

Implementação sobre PP5PK/xlxd e69f2dcdd9cf004d5ad199f85c27f1fa1e7e5004, incluindo TOT180 da PR54. A base recompilada reproduziu exatamente o SHA256 ativo c0283b7f6c7644b84284140ecaa20e7643bd60a99b961a8f099f9fea19976441. Não usar /usr/src/xlxd divergente.

Candidato final XLXD: 9dce43475fed2fa464e8b76f1363167827b5cb80e33981523d2e701ea3d0b9f0.
Live Core V2: 83977c221a327a6d39d7fd12a6aa1170274b3fa71de367934ce8fd87601099ed.
Configuração preservada: 5 módulos, YSF 433125000 Hz, autolink C, keepalive MMDVM180/YSF90.

Patch C++ agora inclui conjuntamente TOT180, guard e publicação local. Aplicar apenas a base limpa aprovada. Nenhuma constante de configuração específica de produção está no patch.
Estado /run/xlx-tx-turn-state/module-X.json: até 2 identidades locais, prazo CLOCK_MONOTONIC; publicação atômica no fechamento/início de cooldown e liberação por terceiro. Diretório root0755, arquivos0644. Expiração validada pelo consumidor. Até26 arquivos, sem escrita por quadro de áudio.
Rust lê estado local a cada100ms em tarefa separada, publica no WebSocket somente mudanças de módulo/prazo (início, fim e terceiro). App conserva o prazo, mostra os dois indicativos e countdown no box TX; nenhum falso TX ou aumento de active_count. SSE fallback recebe o mesmo estado via hub.

PASS ENV WartyWallaby: lifecycle real admit/EOT, bloqueio dos dois membros, retry sem extensão, terceiro, isolamento de módulos, feature OFF, expiry, identidade DMR, TOT181s. Inicialização e restauração candidato/base em namespace de rede/PID separado, listeners preservados.
PASS ENV: binário Rust idêntico ao candidato, handshake WebSocket, evento espera, snapshot, liberação terceiro, expiry e rejeição de dado inválido.
PASS UI: fixture explícita fictícia, desktop e box350px, contagem7s, remoção expiry/terceiro; nenhum erro do aplicativo. Erros vistos apenas da extensão do navegador.
Backup produção verificado: /opt/xlx026-backups/TX_TURN_WAIT_20261004_2120, manifest SHA256 e rollback.py. Restauração core exercitada em ENV; não reiniciar produção durante TX.
Observer: resumo sem identidade, somente novos eventos, 900s mínimos entre tentativas mesmo em erro, máximo120 tokens. Modelo explicitamente configurado via OPENAI_TX_TURN_MODEL; segredo existente não versionado.
Deploy PROD PASS em21:36:13 UTC: PID655997, candidato9dce4347, 13 listeners, xuvd/Helix preservados. Dois rollbacks automáticos por falhas do verificador foram executados antes da promoção final; readiness agora aguarda até90s pelo carregamento das bases e normaliza o status. Reconexões dos três protocolos/streams reais confirmadas; nenhuma dupla real observada ainda. API real/RF/interlink/soak permanecem pendentes. Veja PROJECT_RELEASE_STATUS.md.

PASS ENV adicional: test-protocol-env.sh usa encoders/decoders e callbacks de admissão/EOT/timeout/TOT reais das classes DCS, YSF e DMR com fixtures sintéticas. Teste systemd PrivateNetwork exercitou baseline→candidato→restore de unit/binário/ambiente/restart. Não afirmar transporte UDP ou RF pela execução dessas classes.
