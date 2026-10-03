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
