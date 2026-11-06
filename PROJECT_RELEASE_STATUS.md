## Situação adicional — 2026-11-05 — IA e regra de espaço de câmbio (V2 3s LAB)
- PROD: OpenAI/Helix apareciam indevidamente como indisponíveis no painel; o monitor antigo OpenAI não tinha arquivo em /run e o monitor Helix estava stale após 2026-11-03. Somente monitores oneshot/timers foram iniciados/rearmados; API conectividade OpenAI=true e Helix shadow=true, candidato hash=true, sem anomalia; XLXD PID1298 e SHA `3991b040573ff7522af69148c97f768d0b468b716212bf7b8e047fca1c6cc410` preservados.
- PROD V1: XLX_TX_TURN_GUARD=1, trigger3000, cooldown7000, reset60000. Essa regra ainda só detecta A→B→A; **V2 não está em produção**.
- ENV WartyWallaby: código base do XLXD VW encontrado com o mesmo SHA do binário PROD. Patch C++ opcional `XLX_TX_TURN_POLICY=participants` acrescenta 3 segundos mínimos a qualquer integrante do QSO, isenta primeira entrada e penaliza 7 segundos individualmente após infração. Compilação total PASS, V1 regression PASS, C++ com 12 participantes PASS e handlers DCS/YSF/DMR sintéticos PASS. Replay do patch reproduz fontes idênticas.
- Gates: atualizar UI para múltiplas penalidades com deadlines próprios, confirmar áudio/RF/controle/multi-TX, restaurar baseline em sandbox, validar CI/PR e rollback, só então avaliar canário. DOC/SW/ENV não são HW/PROD.
- Rastreio: issue #98, feature/tx-turn-multiparty-3s-20261105, experimental/tx-turn-guard/MULTIPARTICIPANTS-20261105.md, TEST-056..058.

# PROJECT_RELEASE_STATUS — fotografia atual

Atualizado em: 2026-10-02

## Repositório
- Repositório: `PU2PNY/XLX-Modern-Installer`
- Branch padrão: `main`
- Baseline funcional/runtime confirmado em `main` antes deste follow-up documental: `15a1612a720bbab4882bf1b56f4584301a2ec16b`
- Commit funcional: “Add optional Helix PCM bridge with bounded legacy fallback (#65)”
- O tip corrente de `main` deve ser confirmado diretamente no GitHub; este documento não tenta auto-referenciar o SHA do commit que o atualiza.
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

## CI do estado Helix mesclado
No head final da PR #65, `9fb4d6906bfe2f699b7c09d6ada47cdcf72d53fc`, concluíram com sucesso:
- XLX Modern Installer CI;
- Debian 12 runtime gate;
- Stream identity regression.

A PR foi então mesclada por squash em `main` como `15a1612a720bbab4882bf1b56f4584301a2ec16b`. No instante desta atualização ainda não havia execução separada de Actions registrada para o SHA do squash; portanto a evidência de CI pertence ao head final da PR, não deve ser reclassificada como CI do commit de merge.

Classificação: `SW/CI`. Isso **não** equivale a validação `ENV`, `HW` ou `PROD`.

## Correção Ranking — 2026-10-01
- Diagnóstico PROD somente leitura antes da mudança: o banco persistente permaneceu íntegro após 00:00; foram observadas 56.182 transmissões armazenadas e 7.822 TX na janela de 7 dias, enquanto Hoje/Mês reiniciaram por serem períodos civis.
- PR #67 mesclado em `main` como `5ce83b70d085bc1f3d0ecbac2f1e52c214fdafc1`.
- Gates do head final da PR: XLX Modern Installer CI, Debian 12 runtime gate, Production parity regression, Stream identity regression e Classic installer regression = PASS.
- PROD XLX026: backup criado em `/opt/xlx026-backups/RANKING_ROLLOVER_20261001_001741`; somente `ranking-v2-view.php` e `xlx026-ranking-v2.py` foram substituídos; nenhum restart do XLXD.
- API PROD passou a emitir `version: 3`, período `year` e metadado `year_complete`; a página pública `/ranking` respondeu HTTP 200 e expôs o botão ANUAL.
- O histórico anual disponível em PROD é parcial: `source_start=2026-07-29 11:05:41 -03`, portanto janeiro–julho não são inventados nem marcados como cobertura completa.
- O comportamento exato da próxima virada de 23:59→00:00 está coberto por SW/CI, mas ainda não foi reobservado em PROD após este deploy.

## Correção Conectados — em validação 2026-10-01
- Diagnóstico PROD somente leitura: o endpoint/status refletia diretamente os `NODE` do XML do XLXD. Em uma amostra dinâmica foram vistos 125 rows públicos, mas apenas 105 chaves canônicas distintas por indicativo+sufixo+protocolo+módulo; 20 linhas eram duplicações distribuídas em 10 grupos, concentradas no módulo C.
- Exemplo observado: um único indicativo C4FM/YSF acumulou 12 `NODE` simultâneos com mesma identidade/sufixo/protocolo/módulo durante reconexões.
- Branch: `feature/connected-real-dedupe-v1-20261001`, baseada em `c10b21870829d0da2d072b86b805ecdeb6ee4f9f`.
- Estratégia: contagem/lista pública usa sessão canônica mais recentemente ativa; a lista bruta continua sendo usada internamente para correlação de TX/endpoint.
- WartyWallaby: teste específico PASS; `tests/run-all.sh` concluiu `failures=0` no mesmo código funcional; no head documental seguinte, teste específico + governança + PHP lint também PASS. CI do head final e deploy PROD ainda estão pendentes neste registro.
- Nenhuma alteração de XLXD, DMR/YSF/D-Star, xuvd/Helix ou áudio faz parte desta correção.

## Conectados — validação PROD 2026-10-01
- PR #72 foi mesclada no `main` em `a7ab1ab45ee62639e9f1e80e363d126703fbdd27`; quatro workflows GitHub Actions passaram. O follow-up de alias PR #73 também passou os quatro workflows e foi mesclado em `c1045a22efbb9c6f6a476504efb0680b308f0436`. WartyWallaby executou `tests/run-all.sh` no head funcional do follow-up com `failures=0`.
- Antes do deploy, o XLX026 mostrou drift controlado entre os PHPs de produção e o dashboard genérico versionado. Por isso **não** houve substituição integral dos arquivos: a correção foi aplicada cirurgicamente sobre os PHPs ativos, preservando IA/RadioID locais.
- Backup local root-only criado em `/opt/xlx026-backups/CONNECTED_DEDUPE_20261001_184450`; cópia de restore testada antes da mudança.
- Primeira validação PROD encontrou 107 linhas e ainda 1 grupo duplicado: `PY1ARF` era normalizado pelo alias RadioID para `PY1SGA` somente após a primeira canonicalização. A falha foi registrada e corrigida, sem esconder o resultado.
- Segunda correção aplica o alias à cópia pública **antes** da canonicalização; a lista bruta continua em `active_and_history()`.
- PROD final: `connected_count=106`, 106 linhas, **0 grupos duplicados / 0 linhas extras** pela chave indicativo+sufixo+protocolo+módulo. Conexões distintas por protocolo/módulo permaneceram visíveis.
- `/conectados`, `/api/live.php` e `/api/helix-status.php`: HTTP 200. XLXD permaneceu PID 1093634 e xuvd PID 3729899; Helix permaneceu `shadow`. Nenhum restart de XLXD/xuvd, nenhuma alteração de protocolo/áudio.

## Conectados — nós DExtra internos corrigidos 2026-10-01
- Evidência PROD antes da mudança: o XML continha cinco `NODE` DExtra para o mesmo indicativo do operador, nos módulos A, B, C, D e E. Todos usavam o mesmo endereço configurado no `ExecStart` do próprio XLXD, tinham `Via`/`Peer` vazios e `LastHeardTime` igual ao instante de criação de 2026-09-23.
- Dry-run sobre o JSON real de produção: 89 linhas públicas → 84 após o filtro; para o indicativo afetado, 7 linhas → 2. As cinco removidas eram exatamente os nós DExtra internos; D-STAR/DCS e C4FM/YSF reais permaneceram.
- PR #75 passou `XLX Modern Installer CI`, `Debian 12 runtime gate`, `Production parity regression` e `Stream identity regression` no head `a272f12f85eb6f2ccb13c618cedc14bc0c93a993`, e foi mesclada em `main` como `1495c190bb4ed1647f86b4be8acca3576f690870`.
- WartyWallaby: teste específico de Conectados, PHP lint e governança PASS. A suíte completa local encontrou a falha preexistente/ambiental `mock CallingHome server did not start`; o teste CallingHome executado isoladamente PASS. Não classificar a suíte local completa como PASS.
- Backup PROD root-only: `/opt/xlx026-backups/CONNECTED_SELF_DEXTRA_20261001_225743`; cópia de restore validada antes do deploy.
- PROD após deploy: `connected_count=84`, 84 linhas, 0 grupos duplicados e 0 nós DExtra do endereço do próprio XLXD na lista pública. O indicativo afetado ficou com 2 conexões legítimas distintas: D-STAR/DCS módulo D e C4FM/YSF módulo C.
- `/conectados`, `/api/live.php` e `/api/helix-status.php`: HTTP 200. XLXD permaneceu PID 1093634 e xuvd PID 3729899; Helix permaneceu `shadow`. Nenhum restart de XLXD/xuvd e nenhuma alteração de áudio/protocolo.

## Correções recentes confirmadas no main
- PR #55: timeout FastCGI de 30 s limitado à rota privada do Admin; público permanece em 15 s.
- PR #57: botão de informações nas 24h somente para gateway diferente do indicativo e confirmado como repetidor.
- PR #65: Helix PCM Bridge V1 experimental mesclado com `off` padrão, deadline total 1..5 ms, fail-open e bloqueios de produção explícitos.

## Drift de governança corrigido em 2026-09-28
O `main` passou a conter os documentos canônicos e a regressão documental que protege Nginx + PHP-FPM como stack autoritativa. Não usar documentação histórica de Apache/dry-run como estado atual.

## Próxima sequência segura
1. manter `process` bloqueado até resolver a repetibilidade sob contenção e completar áudio real/soak/rollback;
2. não habilitar `shadow` em produção antes do soak de 24 h, gates de IP aplicáveis, restore completo e procedimento de mudança;
3. reconciliar `VERSION`/README 1.4.6 com GitHub Releases em fluxo separado;
4. executar nova instalação limpa em VPS Debian 12 descartável quando for validar release geral;
5. não alterar produção saudável sem necessidade comprovada.

## Trabalho isolado — Passive Transmission Analyzer V1
Branch: `feature/passive-transmission-analyzer-v1-20260930`.

Escopo:
- observação passiva do transporte YSF/UDP;
- continuidade conservadora do contador de rede;
- jitter/inter-arrival;
- sessões concorrentes e reconexões;
- estado local limitado e log apenas de anomalias;
- sem alteração do caminho de áudio, XLXD ou transcoding.

Estado: SW + ENV validados e deploy PROD do serviço passivo validado no XLX026 em 2026-09-30. `tests/test-transmission-analyzer.sh`: 7/7 PASS; `tests/run-all.sh`: failures=0. Em ENV, o serviço real com CAP_NET_RAW capturou YSF sintético enviado por segunda VPS e detectou corretamente uma lacuna 11→14/~300 ms. Em PROD, o serviço permaneceu ativo com ~10 MB, recebeu mais de 1.500 YSFP reais, não abriu listener UDP adicional e o PID do XLXD permaneceu 1093634 antes/depois do deploy. O analisador detectou automaticamente PS7JAP com `concurrent_endpoints` e `endpoint_count=2`, confirmando a detecção de sessões concorrentes em tráfego real. Não houve YSFD/voz real durante a janela curta de validação PROD; a análise de continuidade dos frames de voz permanece comprovada em ENV, não promovida por inferência.

## Helix PCM Bridge V1 — integrado como experimental
Branch de origem: `feature/helix-pcm-fallback-v1-20260930`.
PR #65 mesclada em `main` por squash em `15a1612a720bbab4882bf1b56f4584301a2ec16b`. O merge apenas versiona o código experimental; não habilita Helix no áudio de produção.

Objetivo:
- preservar compatibilidade de rádio legado DMR/YSF/D-Star;
- manter AMBE/AMBE+2 no backend legado externo ao núcleo Helix;
- fornecer PCM ao Helix por socket Unix local;
- modo `off` como padrão;
- modo `shadow` sem comitar áudio retornado;
- modo `process` somente após gate adicional;
- timeout/falha do Helix mantém PCM original e caminho legado.

Evidência atual: DOC/SW/ENV registrada abaixo. Não promove áudio de produção. O transcoder `xuvd` ativo do XLX026 foi identificado como backend local em `127.0.0.1:10100`; nenhuma substituição/restart de produção foi executada durante esta etapa.

### Evidência ENV — Helix PCM Bridge V1 (2026-09-30)

WartyWallaby:
- contrato C++/Unix socket: PASS;
- Helix daemon self-test: PASS;
- transcoder experimental compilado com OP25 `71abcd0ead32f86f51615ea6cc8a6a4dba4c949a`;
- `off`, Helix ausente e `shadow`: saída bit-idêntica, SHA-256 `0927cfff2bb8dfd6076ba6912ba9a96eef57284afd4df77e2436e9657521074f`;
- `shadow`: 40/40 observações, zero fallback, zero falha de codec;
- `process`: 40/40 respostas Helix em execução single-stream, zero fallback, saída diferente do baseline como esperado;
- Helix ausente em `process`: 1 tentativa falhou de forma limitada, o stream foi fixado em legado e 40/40 frames continuaram entregues;
- dois streams intercalados: 60/60 frames entregues; um stream permaneceu Helix 30/30, o outro teve um timeout e passou de forma segura ao legado;
- HXP1 direto, 2.000 frames: p50 0,085 ms; p95 0,319 ms; p99 0,817 ms; p99,9 1,750 ms; máximo 3,653 ms; 0 acima de 5 ms.

Classificação: `SW/ENV PASS` para contrato, shadow, fail-open e continuidade multi-stream. `process` continua **não autorizado em PROD** até áudio real/soak/rollback e reconciliação da proveniência do transcoder ativo.

Proveniência histórica recuperada em backup: o trabalho do transcoder de 2026-09-08 preserva `boatbod/op25@28f2c40645deca3f8c2d529d27d0df2555ed287a`, o source `xuvd.cpp` atual (SHA-256 `2327548067...bfea5c`) e uma cópia byte-idêntica do binário PROD atual (SHA-256 `4b72dfc7...e58069`). O log de instalação prova que esse binário foi obtido por um patch binário único de 1 byte no predecessor `50ac33df...cec15`, alterando o limite FEC 3→4. Porém o rebuild limpo preservado daquela mesma investigação gera SHA-256 `cc163930...a475d0`, não o ELF ativo. Portanto a cadeia histórica foi identificada, mas a reprodução byte a byte por compilação ainda não foi comprovada; o binário de produção não foi substituído nem reiniciado.

### Equivalência contra xuvd PROD — ENV com corpus PROD (2026-09-30)

Sem alterar produção, o binário PROD exato foi copiado para WartyWallaby e comparado ao bridge compilado com a árvore histórica `boatbod/op25@28f2c40645deca3f8c2d529d27d0df2555ed287a`.

Corpus sintético determinístico:
- AMBE+2→D-Star módulo A: bit-idêntico;
- AMBE+2→D-Star módulo C: bit-idêntico;
- D-Star→AMBE+2 módulo A: bit-idêntico;
- D-Star→AMBE+2 módulo C: bit-idêntico;
- `shadow` também foi bit-idêntico nos quatro caminhos e entregou 560/560 observações ao Helix.

Corpus derivado de produção:
- captura passiva de 90 s no loopback XLXD↔xuvd: 1.947 pacotes, 0 drops;
- três sessões reais AMBE+2→D-Star: 828 frames;
- xuvd PROD, candidate `off` e candidate `shadow` produziram o mesmo SHA-256 de saída `f64ebcfebfe59aeba9404a174f2c95eef000303f41e43a8c3b7562b8cf62a470`;
- Helix recebeu 828/828 frames em `shadow`, com 0 falhas do transcoder.

Classificação: PASS em ENV para equivalência comportamental do caminho legado no corpus testado. Os pacotes de origem vieram de PROD, mas o replay/comparação ocorreu em ENV; não promover para PROD por inferência.

### Continuação validada — deadline total e fail-open (2026-09-30)
- Helix main confirmado em e80969d58d0ecf0f4bd55bbc7fae85311c0176d2 (PR #1 já mesclada).
- XLX base desta continuação: `1c137e200fb7ea64d5e6e83a6d279b6f49c55cca`; PR #65 posteriormente mesclada em `main` como `15a1612a720bbab4882bf1b56f4584301a2ec16b`.
- Instrução do operador reconciliada: teto 5 ms; deadline única inclui connect/write/read. Não renovar prazo em fragmentos; socket não bloqueante.
- 11 cenários adversariais + backlog cheio preservam PCM; header incompleto/inválido ou flags desconhecidos não comitam saída.
- Helix: governança/patent gate, fmt, clippy -D warnings, workspace tests, release build e daemon self-test PASS em ENV.
- XLX: tests/run-all.sh terminou failures=0; contrato/deadline específicos PASS.
- Equivalência contra ELF PROD exato: quatro caminhos em off/shadow bit-idênticos.
- E2E de sete sessões: off/absent/shadow/shadow-kill bit-idênticos; process 40/40; queda no frame 20 preserva entrega 40/40; dois streams 40/40 Helix cada, sem falhas de codec.
- PCM baixo/alto isolado versus intercalado: idêntico por stream; 600 IDs novos aceitos sem crescimento RSS no teste curto (1252 KiB).
- Restore do binário em ENV PASS, incluindo quatro caminhos após restore; unit/config/serviço de produção não restaurados/testados.
- Produção somente inspecionada: XLXD 1093634 e xuvd 1107847, ELF xuvd 4b72dfc7...e58069 preservado.
- Falhas de execução desta continuação: timeout operacional de um comando curto durante compilação concorrente; uma resposta de despacho background expirou, mas o build iniciou e foi verificado; primeiro harness E2E rejeitou o banner de copyright OP25 em stderr. Harness corrigido para preservar o log e verificar erro/exit code/frames. Nenhuma dessas falhas foi tratada como falha DSP.
- Retorno 127 anterior: cargo ausente no PATH do agente/root e Rust instalado em /root/.cargo/bin, hipótese compatível confirmada no contexto atual. O comando exato da execução antiga não pode ser reconstruído pela saída resumida; não alegar causa definitiva sem trace.
- Shadow PROD não habilitado: ainda faltam soak 24h, gates de IP aplicáveis, restore completo e janela/procedimento de troca sem regressão. Process e PU2PNY-OS permanecem bloqueados.

Evidência sanitizada reproduzível: [Helix PCM bridge ENV](docs/evidence/helix-pcm-bridge-20260930.json). Apenas métricas/hashes de corpus sintético; nenhum áudio, PCAP ou segredo de produção.

### Execução adicional do wrapper — limitação de process registrada
O script completo test-e2e-lab.sh passou seus critérios de continuidade/fail-open. Porém, no multi-TX dessa execução adicional, stream 1 teve helix_ok=4 e helix_fallback=1, stream 2 helix_ok=5 e helix_fallback=1; cada um entregou 40/40 frames, sem falhas de codec. Isso difere das duas execuções anteriores com Helix 40/40 em ambos. Não escolher apenas o melhor run: a confiabilidade de processamento sob contenção permanece PARCIAL, e disputa de CPU/scheduling é hipótese a investigar. A latência do wrapper é round-trip incluindo codec/IPC/scheduling, não latência isolada Helix. Soak/áudio/PROD continuam bloqueados. O prazo 5 ms não será aumentado para mascarar a falha.
Evidência adicional: [wrapper ENV](docs/evidence/helix-pcm-bridge-wrapper-20260930.json).

### Repetibilidade multi-TX após o gate final da PR #65
Três repetições controladas adicionais na WartyWallaby mantiveram 40/40 frames por stream e zero falha de codec, mas cada stream acionou uma vez o fallback sticky em momentos variáveis: 35/34, 2/28 e 18/14 respostas Helix antes do fallback. Isso confirma que a continuidade/fail-open está PASS, porém a confiabilidade de `process` sob contenção permanece PARCIAL. O teto de 5 ms não foi aumentado. Scheduling/contenção continua hipótese, não causa raiz provada. Nenhuma alteração foi feita em produção.

Evidência sanitizada: [repetibilidade multi-TX](docs/evidence/helix-pcm-bridge-repeatability-20260930.json).

## Helix shadow PROD — 2026-10-01
Por autorização explícita do operador, o XLX026 recebeu a integração Helix em **`shadow` somente**; `process` continua bloqueado. Antes da troca, o xuvd ativo foi revalidado no hash conhecido-bom `4b72dfc7a26697a3e315fba8c8d22435996d8e67c3112e2f343a65b4c6e58069`. O rollback completo de binário + unit + configuração + serviço foi executado com sucesso em ENV/WartyWallaby.

PROD inicial: o XLXD permaneceu no PID 1093634 e não foi reiniciado. O xuvd candidate tem SHA-256 `559f580b5edf58883eb81293d8fbdc044e13eff9ca4dc6437e6b16014f75a243`; `helix-voice-shadow.service` usa socket Unix datagram local `0660` com identidade dedicada. Foram observados streams reais de 18, 108 e 72 frames com `helix_ok` igual ao total de frames, `helix_fallback=0` e `failures=0`. Isso é evidência PROD inicial de `shadow`, não valida `process` e não substitui o soak de 24 h ainda pendente.

Foi instalado monitor técnico separado do hot path. Ele coleta somente estado de serviços/socket/hash/RSS/counters; a OpenAI recebe somente telemetria agregada em intervalo limitado (15 min ou transição de anomalia), nunca áudio/voz/indicativo. O dashboard expõe estado sanitizado por endpoint dedicado e mostra `HELIX • MONITORANDO` no box Ao Vivo quando `shadow` está pronto. A primeira análise remota retornou estado OK. `process` permanece bloqueado.

## Stereo Tool — fundação LAB 2026-10-02
Branch: `feature/stereotool-lab-foundation-v1-20261002`, criada a partir de `main` em `377f5e4bea0d311657d5df1258724aecc2b4efbf`.

Escopo implantado na branch:
- `experimental/stereotool/artifact_validator.py` para inspeção estática, sem carregar/rodar a biblioteca;
- quarentena segura de ZIP com rejeição de traversal, symlink e special file;
- SHA-256, ELF64, arquitetura, GLIBC e símbolos de identidade;
- `xlx-stereotoold.service.example` como referência hardening `AF_UNIX`-only, não instalada;
- mock sintético e teste de regressão sem artifact proprietário;
- arquitetura/gates em `docs/STEREOTOOL_INTEGRATION.md`;
- invariantes ST-001…ST-010 e testes TEST-030/031.

Evidência ENV na WartyWallaby: `python3 -m py_compile`, `bash -n` e `tests/test-stereotool-foundation.sh` PASS. O teste aceitou mock `.so` válido como `READY_FOR_SANDBOX` e rejeitou biblioteca sem símbolos, ZIP traversal e ZIP symlink. Nenhuma biblioteca/CLI Stereo Tool real foi encontrada/fornecida no laboratório e nenhum artifact proprietário foi versionado.

Classificação: `SW/ENV PASS` somente para a fundação estática/mock. `TEST-031` permanece PENDENTE para artifact/SDK reais, licença/autorização escrita, sandbox load, PCM inventory, contextos por stream, latência/CPU/RAM, shadow, delay-matched fail-open, chaos, canário e rollback.

**Produção XLX026 não foi modificada nesta etapa.** Nenhum serviço Stereo Tool foi criado/habilitado, nenhum `xlxd`/`xuvd` foi reiniciado e `PROCESS` Stereo Tool permanece proibido.

## TX Turn Guard V1 — ativo no XLX026 (2026-10-04)
- PR #78, branch `feature/tx-reentry-cooldown-v1-20261004`. Código funcional e13f4e1a95ac8064688763017761601fea149e0f: três workflows CI PASS (37235697443, 37235697453, 37235697534).
- Base ativa recuperada: PP5PK/xlxd e69f2dc + TOT180 da PR54. Rebuild exato c0283b7f6c7644b84284140ecaa20e7643bd60a99b961a8f099f9fea19976441; fonte divergente em /usr/src não utilizada.
- ENV Warty: build completo -j1 PASS; C++ lifecycle guard/TOT PASS; encoders/decoders + admissão real de classes DCS/YSF/DMR com A/B/A, bloqueio, terceiro, EOT, timeout e TOT PASS. Dados sintéticos, sem alegar teste RF.
- ENV: restauração de ELF/unit/ambiente/restart em serviço systemd com rede privada PASS; baseline final hash exato e variável guard removida. WebSocket/snapshot de espera/expiry/terceiro/dado inválido PASS.
- UI: fixture explicitamente fictícia PASS em desktop e box350px; contagem7s e remoção no expiry/terceiro. Componente e versão nova de app.js conferidos no painel real. Captura [teste visual](docs/evidence/tx-turn-wait-ui-20261004.jpg).
- PROD promovido em 2026-10-04 21:36:13 UTC, após janela sem TX. XLXD PID655997/hash9dce43475fed2fa464e8b76f1363167827b5cb80e33981523d2e701ea3d0b9f0; 13 listeners confirmados, variáveis guard1/trigger2000/cooldown7000/reset60000 e estado local no tmpfs.
- Live Core V2 hash83977c221a327a6d39d7fd12a6aa1170274b3fa71de367934ce8fd87601099ed, WebSocket entrega espera local; fallback SSE e box TX instalados. Nginx/PHP mantidos.
- Transcoder PID3729899 e Helix shadow PID3716236 preservados. Serviços sem reinício automático (NRestarts0). Reconexões reais observadas em DCS, YSF e DMR; contagem pública recuperou96 estações na amostra dinâmica.
- Canário inicial: quatro streams abertos e três encerrados, zero loop; três estatísticas ambed com 0 de1224, 0 de986 e 0 de198 pacotes em timeout. Um stream ainda ativo na amostra. Rotas ao-vivo, live-v2/snapshot, live.php e helix-status.php HTTP200. Não equivale a escuta de áudio/RF/soak.
- Backup root-only `/opt/xlx026-backups/TX_TURN_WAIT_20261004_2120`, manifest SHA256, rollback.py e deploy-result.json. Duas tentativas foram revertidas automaticamente por falhas do verificador (checagem antes do carregamento das bases; comparação sem remover newline do status). Baseline exato e todas as portas foram reconfirmados antes da promoção final. Não ocultar essas reversões como deploys bem-sucedidos.
- Observador local/timer ativos e modelo explicitamente configurado reutilizando a configuração existente; silêncio confirmado com zero eventos e nenhuma análise remota. Não houve gasto por aviso/PTT. Limites: resumo novo/diferente, mínimo900s entre tentativas inclusive erro, máximo120 tokens, no máximo4096 eventos; nunca voz/identidade para IA.
- PENDENTE: primeira dupla/cooldown real observada em PROD, chamada real da API deste recurso, RF multiprotocolo/interlink e soak prolongado. Política padrão do instalador continua OFF; ativação explícita somente nesta instância autorizada.
- Evidência sanitizada [resultado](docs/evidence/tx-turn-guard-production-20261004.json) e [procedimento](experimental/tx-turn-guard/PRODUCTION-20261004.md).

O bloqueio de conectividade de Warty às20:43 UTC foi superado após reconexão; o build antigo divergente não foi promovido. O timeout anterior permanece histórico, não resultado final.

## YSF VW — ativo no XLX026 em 2026-10-23
- PR #88, branch `feature/ysf-vw-native-lab-20261023`, base `56a8591c9f3504805136be64bfcbf48e98fbeb46`; VERSION continua 1.4.6.
- Baseline ativo reproduzido bit-idêntico: `9dce43475fed2fa464e8b76f1363167827b5cb80e33981523d2e701ea3d0b9f0`. Candidato VW: `3991b040573ff7522af69148c97f768d0b468b716212bf7b8e047fca1c6cc410`.
- ENV PASS: roteador real e UDP header/voz/EOT bit-idênticos; chave/arquivo inválido, hot-disable, origem/módulo/peer, DN EOT, VW TOT e ausência de transcoder; regressão guard e DCS/YSF/DMR admit/EOT/timeout/TOT.
- ENV PASS: baseline → candidato → restauração em serviços com rede/arquivos temporários isolados, 13 listeners em cada estágio. A tentativa inicial do harness usou Type=simple; corrigida para Type=forking e repetida com sucesso.
- CI do primeiro head `0703f0d2490813417db4bd651a4d34eb6ce35f6c`: Installer CI, Debian 12 runtime gate e Stream identity regression PASS. Atualizações documentais posteriores têm seus próprios checks.
- PROD: instalação em janela sem TX, PID1197741, 13 listeners, rotas HTTP200, clientes reconectados e chave ON. Transcoder/Helix não reiniciados. Teste do helper como www-data OFF→ON preservou PID; três regras sudo exatas, sem terminal arbitrário. Duas aberturas/fechamentos observados e zero assinaturas fatais no canário inicial; NRestarts0.
- Backup root-only `/opt/xlx026-backups/VW_ENABLE_20261023`, manifesto e rollback.py; fixture de restauração dos cinco arquivos privados originais PASS. Uma espera inicial foi interrompida antes de qualquer mutação para corrigir a verificação de reconexões: o snapshot Live não fornece connected_count; o gate usa o XML atualizado. Sem rollback de produção nesta implantação.
- PENDENTE: escuta de áudio VW com rádios reais, validação visual autenticada do novo controle e soak prolongado. VW não é convertido para DN/DMR/D-Star; usar DN para conversas multiprotocolo.
- Evidência sanitizada: [resultado](docs/evidence/ysf-vw-20261023.json). Nenhum segredo, áudio, backup ou sessão foi versionado.

- Diagnóstico operacional atualizado para refletir o marcador do núcleo e a chave: `voice.vw_voice_fr=true`, `vw_supported=true`, `crossmode_safe.vw_voice_fr=false`. Função de leitura/sintaxe PASS; reiniciado somente o monitor de saúde para carregar essa correção, sem segundo restart do XLXD.

## 2026-10-27 — Supervisão IA limitada, candidato

Base canônica main 9a55d5701348312dcdd170ec911065b9d2e68941, VERSION1.4.6. Checkout legado /usr/src/XLX-Modern-Installer está detached em 454bd431 e não representa automaticamente o runtime. Não atualizar nem promover esse checkout.

Diagnóstico PROD: xlx-ai-monitor falhas intermitentes e timeout de leitura de 8s reproduzido, intercalado com HTTP200 usando a mesma chave; sem prova de chave inválida. Monitor existente testa /models, não analisa servidor. Monitores Helix/Turn Guard consultivos são separados.

Candidato: observability/ai-supervisor, instalação opt-in. 7 testes SW/ENV isolado PASS, PHP/Node em cópia PASS, Python compile/systemd verify PASS. Análise real em staging retornou texto completo sobre serviços/recursos agregados. Não houve mutação dos serviços monitorados durante esse teste. Ações sintéticas não são incidentes reais. Deploy/soak serão registrados separadamente.

### Ativação PROD — 2026-10-27 18:49 BRT

- Backup root-only: `/opt/xlx026-backups/AI_SUPERVISION_20261027_184844`; os 3 arquivos anteriores foram restaurados em fixture e hashes conferidos. Novos paths ausentes registrados; rollback.py privado restaura arquivos e remove novos componentes, sem restart do rádio. Restore real de serviço em PROD não executado.
- Monitor corrigido API HTTP200, error_code vazio; supervisor concluiu análise remota real e publicou ai_last_analysis_at=1793137747. Oito serviços active, eventos de recuperação vazios.
- Timers ativos, ambas execuções Result=success/ExecMainStatus=0. Ciclo seguinte atualizou telemetria sem repetir probe saudável ou análise externa; timestamps remotos preservados.
- Endpoint público /api/status.php HTTP200 expôs supervisor sanitizado; JS HTTP200 incluiu integração e removeu rótulo enganoso reconectando.
- Chrome: screenshot durante TX real PU2PNY em C4FM/YSF confirmou indicador IA supervisionando, 95 conectados, Helix monitorando e histórico preenchido. Isso comprova apresentação/atividade observada, não qualidade RF/áudio.
- XLXD PID1197741 e xuvd PID3946342 preservados antes/depois. Nenhuma ação de recuperação foi necessária; recuperação de incidente real e soak longo permanecem pendentes.
- CI no código 78365759: validate, regression, debian12-runtime e duas execuções supervision concluídas success. Níveis SW/CI, ENV isolado e PROD específicos permanecem separados.

## 2026-10-27 — Ícone de leitura do indicador IA

Base main 6b8ee70da82665db572f54c031abf5e6b299fc24, VERSION1.4.6. Troca cirúrgica de barra por SVG/CSS, sem mudança de status/IA/protocolo. Código em observability/ai-supervisor/integrate-reading-icon.py e ai-reading-icon.css. Backup root-only /opt/xlx026-backups/AI_READING_ICON_20261027_190122: originais/cópias restauradas e hashes conferidos; restaurar somente assets/app.js e assets/ai-monitor-v1.css, sem restart. Node syntax/Python compile PASS; PIDs XLXD1197741/xuvd3946342 preservados. Browser em /ao-vivo confirmou página/histórico e console sem erro, mas esteve em standby na primeira amostra, sem ícone TX visível. Visual/movimento real e mobile permanecem pendentes até observados.

## SoftAMBE PP5PK — compatibilidade LAB, 2026-11-03
**DOC:** analisado PP5PK/XLX-SoftAMBE_Installer@eff7972 e PP5PK/xlxd@f10f91b: patch de 65 arquivos/~14.892 linhas adicionadas para D-STAR↔DMR/YSF, não DSP direto de DMR↔YSF DN; controle ambed e xuvd compartilham UDP 10100; upstream usa Apache, enquanto este instalador usa Nginx/PHP-FPM. Issue #92 e branch research/softambe-compat-lab-20261103 documentam decisão.
**SW:** teste local offline de contrato test-softambe-lab-only.sh executado com PASS; CI da PR e build remoto ainda não confirmados.
**ENV:** não houve build/execução no laboratório; WartyWallaby SentinelX indisponível.
**HW:** rádio real não testado.
**PROD:** nenhum XLXD/xuvd/Helix/serviço alterado para este estudo. Consulta pontual do agente SentinelX do XLX026 retornou connection_lost, sem prova de parada de serviços; não realizar operação insegura.
Sem tag/release nova, sem inclusão no instalador principal e sem autorização de runtime.

## SoftAMBE PP5PK — PROD técnico ativado em 2026-11-03 (substitui o estado LAB anterior)
- Decisão OPERATOR: migração in-place em produção sem WartyWallaby, com aceitação de interrupção e rollback. Autorização não converte testes SW no host em ENV/HW.
- Fontes pinadas eff7972/f10f91b, patch blob dca3f9, build isolado SW PASS em host PROD, binário implantado SHA256 59cbb5, config PP5PK com 3 pares, EQ=0 (OFF).
- Backup \`/opt/xlx026-backups/SOFTAMBE_PRE_SWITCH_20261103_191457Z\`, SHA256 c694c402..., extração/compare PASS; rollback executado de fato após primeiro start falho por permissões, restaurou xuvd e Helix sem reiniciar XLXD; correção 0755 e segunda ativação PASS.
- PROD: SoftAMBE PID7092 active/enabled, xuvd inactive/disabled, Helix shadow e monitor timer inactive/disabled, XLXD PID1298 preservado, UDP 127.0.0.1:10100 e AMBEDPONG PASS, streams reais e 0 timeouts em amostras de 211/221/96/90 quadros, 3 endpoints web HTTP200. Registros técnicos, não certificado de áudio HW.
- **PENDENTE:** escuta RF, qualidade de áudio, regressão de chamadas de vários protocolos, soak prolongado e teste de desastre global. O efeito em DMR↔YSF DN **não é comprovado e não decorre diretamente do SoftAMBE**. Veja \`experimental/softambe/PRODUCTION-20261103.md\`.
- Sem atualização de \`main\`, tag/release ou habilitação do SoftAMBE no \`install.sh\` por esta observação; a evidência inicial foi feita em branch e PR de mudança controlada.

### Continuação — testes no XLX026 PROD sem laboratório (2026-11-03)
OPERATOR reiterou que os testes restantes são **exclusivamente na produção XLX026**. Observação passiva posterior: 23 aberturas e 23 fechamentos de vocoder; 22 registros de contador internamente consistentes com 4 eventos de timeout em 10.389 frames enviados; um registro reportou 2/1 e foi excluído do quociente. Esses contadores não são taxa comprovada de perda de áudio: o código-fonte disponível no host descreve sinais informativos de resposta lenta; paridade do fonte antigo com o ELF atual não comprovada; maior máximo de latência reportada 103ms. Sem erros no log do SoftAMBE nem timeout de keepalive do transcoder na janela amostrada. Quatro URLs públicas HTTP200; serviços XLXD/SoftAMBE e PIDs preservados, xuvd/Helix desativados, backup SHA íntegro. Classificar como PROD técnico limitado, não aprovação RF/acústica. A/B com rádios, investigação do contador anômalo e soak continuam pendentes; não projetar testes em WartyWallaby nesta rodada.

## Reversão da migração SoftAMBE — 2026-11-03
**Estado operacional mais recente nesta documentação:** o operador **rejeitou** o áudio SoftAMBE no fluxo D-STAR⇄DMR como “horrível” (OPERATOR). A troca de codec em produção registrada acima **foi revertida**. Não interpretar qualquer seção anterior afirmando SoftAMBE “active” como estado atual.

- PROD: backup privado \`/opt/xlx026-backups/SOFTAMBE_PRE_SWITCH_20261103_191457Z\` teve SHA256/TAR PASS; script \`ROLLBACK.sh --apply\` executado.
- PROD: SoftAMBE inactive/disabled; xuvd active/enabled PID31974 e Helix shadow active/enabled PID31954; XLXD continua active PID1298 sem restart; xuvd SHA256 \`d3ea28efb76ff61f615a5613bc5475b08b9a94a3085f638d470e70a8d21e1884\`; core SHA256 \`3991b040573ff7522af69148c97f768d0b468b716212bf7b8e047fca1c6cc410\`.
- **Diferença intencional versus pre-switch:** \`xlx-unified-voice.service\` foi habilitado para boot; o backup tinha o serviço disabled e a primeira reinicialização antes da migração o deixou inactive. Necessário para não perder transcoding no próximo reboot. Sem alteração no binário.
- PROD: UDP 127.0.0.1:10100 no xuvd. Log mostrou 1 stream real \`codec=2→1\`, 201 frames, zero \`failures\`; 3 páginas HTTP200. Sem prova de audiofilia pós-rollback, que depende de escuta OPERATOR.
- Não reinstalar SoftAMBE nem mesclar sua execução no instalador sem nova decisão, hipótese técnica comprovada e aceite de áudio. Preservar fontes, PR #93 histórico, Issue #92 e backup root-only para auditoria; SoftAMBE runtime desabilitado.

## mbelib upstream — auditoria sem alteração de runtime (2026-11-03)
**DOC:** upstream szechyjs/mbelib 1.3.0 @9a04ed5 (último commit 2019-05-29), licença ISC e aviso sobre patente; a interface pública inclui decodificação e síntese mas não equivale ao encoder/OP25 estendido usado no xuvd.
**PROD somente leitura:** XLXD e xuvd ativos; SoftAMBE desativado. Executável xuvd SHA d3ea28ef... contém símbolos \`mbe_initMbeParms\`, \`mbe_dequantizeAmbe2400Parms\`, \`mbe_synthesizeSpeech\` e relacionados; \`readelf\` não mostra libmbe.so como biblioteca dinâmica. Isso não comprova igualdade bit-a-bit com upstream.
**SW/HW:** sem build novo, comparação de amostras nem intervenção em áudio. Nenhum serviço ou arquivo da VPS alterado por esta auditoria. Decisão DEC-2026-11-03-021, requisito MBELIB-001..003, TEST-055 e issue #95. Preservado transcoder restaurado.

