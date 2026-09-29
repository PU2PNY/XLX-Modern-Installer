# PROJECT_RELEASE_STATUS — fotografia atual

Atualizado em: 2026-09-28

## Repositório
- Repositório: `PU2PNY/XLX-Modern-Installer`
- Branch padrão: `main`
- Commit confirmado em `main`: `4cb8dc37c35e29f107a77090dc9bec287e863bea`
- Commit: “Fix 24h gateway repeater info visibility (#57)”
- `VERSION`: **1.4.6**
- README: **Current release v1.4.6**
- Última GitHub Release observada: **v1.2.14** (2026-09-10)
- Estado: permanece divergência confirmada entre a versão declarada no branch e a última GitHub Release publicada.

## Estado funcional documentado
Evidência `DOC`:
- instalação Debian 12 x86_64;
- XLXD core e Echo opcional;
- **Nginx + PHP-FPM** como stack web principal;
- dashboard multiprotocolo;
- RadioID/callsign com overrides persistentes;
- CallingHome;
- APRS/D-PRS nativo;
- certificados nativos com HMAC;
- observabilidade;
- Admin privado;
- backups preventivos e rollback por componente quando aplicável;
- suíte de testes e múltiplos workflows de regressão.

## Baseline de produção
Evidência `OPERATOR` em 2026-09-21:
- operador declarou servidor XLX026 e tela ativa “perfeitos”.

Limite: este documento não converte o relato em evidência técnica `PROD`.

## CI do commit atual
Para `4cb8dc37c35e29f107a77090dc9bec287e863bea`, o GitHub Actions registrou sucesso em:
- XLX Modern Installer CI;
- Debian 12 runtime gate;
- Production parity regression;
- Stream identity regression.

Classificação: `SW/CI`. Isso **não** equivale a validação `ENV`, `HW` ou `PROD`.

## Correções recentes confirmadas no main
- PR #55: timeout FastCGI de 30 s limitado à rota privada do Admin; público permanece em 15 s.
- PR #57: botão de informações nas 24h somente para gateway diferente do indicativo e confirmado como repetidor.

## Drift de governança identificado em 2026-09-28
O `main` não continha os quatro documentos canônicos e ainda havia documentação antiga descrevendo Apache/dry-run como arquitetura atual. A correção proposta nesta branch restaura os documentos e adiciona regressão documental.

## Próxima sequência segura
1. revisar/mesclar esta correção documental;
2. confirmar CI da PR;
3. reconciliar `VERSION`/README 1.4.6 com GitHub Releases;
4. executar nova instalação limpa em VPS Debian 12 descartável;
5. manter branches funcionais pendentes isoladas até validação específica;
6. não alterar produção saudável sem necessidade comprovada.

## Experimental — Adaptive DMR Gain Normalizer V1 (2026-09-29)
- Branch: `feature/audio-normalizer-adaptive-v1-20260929`
- Commit de implementação testado: `2ba20b02fe261441a49d72e40a5d49f5786e5de0`
- ENV: WartyWallaby executou `tests/test-audio-adaptive-gain.sh` com PASS.
- O teste confirmou hard cap ±3 dB, fail-open, deadband e ausência de OpenAI/API externa no caminho do áudio.
- Consumo LLM no processamento TX/RX: **0 tokens**.
- O serviço permanece **desativado por padrão** e não foi promovido ao XLX026.
- Pendente: regressão completa da branch, compilação/integração com dependências AMBE do runtime, tráfego DMR real e comparação por rádio/HW.

### Calibração de segurança posterior
- O replay offline rejeitou o primeiro teto experimental ±3 de ganho codificado: a alteração decodificada foi muito maior que o número solicitado.
- Referência real: PU2UJY mediana ativa ~-30,53 dBFS; PU2MIZ bruto ~-23,42; PU2MIZ com ajuste V6 -0,8 ~-29,60.
- O candidato foi recalibrado para alvo -30 dBFS, deadband ±3, escala 0,125 e hard cap ±1,0 codificado.
- Nenhuma dessas experiências alterou o serviço de produção.

### Candidato de áudio recalibrado — commit 66d0dec5f92f22b11e34ad4e1e91bcd4d9f187f8
- Alvo de fala ativa: aproximadamente -30 dBFS.
- Deadband: ±3,5 dB para preservar áudio nominal.
- Aprendizagem: 40 quadros ativos; timeout fail-open em 100 quadros; sem buffering.
- Escala: 0,125 de ganho AMBE codificado por 1 dB de erro PCM; hard cap ±1,0 codificado.
- Replay ENV/offline: mid e PU2UJY permaneceram bit-exact; PU2MIZ foi de -23,42 para -27,95 dBFS; vetores low/loud moveram-se na direção correta; MMDVM/DMRPlus failed=0.
- Estado: **não ativado em produção**. HW/rádio real permanece gate obrigatório.

## Experimental — AI Monitor TX badge
- Adiciona contrato de estado sanitizado para o box TX, sem expor chave ao navegador.
- Local seguro planejado para a chave: `/etc/xlx-ai-monitor.env`, `root:root 0600`.
- V1 não envia áudio e não faz inferência: valida conectividade da API e mantém 0 tokens de inferência.
- O box diferencia `IA conectada`, `IA analisando`, `IA recomendou`, `IA orientou ajuste` e `DSP ajustando`.
- Nenhuma atribuição à IA é exibida quando a correção foi apenas local.

### AI Monitor V1 — implantação controlada no XLX026 (2026-09-29)
- Produção não foi sobrescrita pela árvore do GitHub: `app.js`, `status.php` e `index.php` ativos apresentavam drift em relação ao `main`; a integração foi feita por patch mínimo sobre o baseline vivo.
- Backup/rollback criado antes da alteração: `/root/backups-xlx026/AI_MONITOR_PRE_V1_20260929_143703`.
- Validações PROD: PHP/JS syntax PASS, `nginx -t` PASS, `ai_monitor` sanitizado presente em `status.php`, asset JS público contém o badge, timer `xlx-ai-monitor.timer` ativo.
- Estado atual: **sem chave OpenAI configurada**; `/etc/xlx-ai-monitor.env` não existe e o box deve mostrar estado preparado/local.
- A mensagem padrão após uma chave válida será **IA conectada**, não “IA monitorando”: a telemetria/DSP local é o monitor contínuo; a IA só recebe rótulos de análise/recomendação quando houver evento real.
- Nenhum serviço de áudio/protocolo foi reiniciado ou alterado; XLXD, Nginx, Unified Voice e VU Tap permaneceram ativos.
