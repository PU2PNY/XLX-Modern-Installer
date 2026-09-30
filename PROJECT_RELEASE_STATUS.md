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


## Trabalho isolado — Helix PCM Bridge V1
Branch: `feature/helix-pcm-fallback-v1-20260930`.

Objetivo:
- preservar compatibilidade de rádio legado DMR/YSF/D-Star;
- manter AMBE/AMBE+2 no backend legado externo ao núcleo Helix;
- fornecer PCM ao Helix por socket Unix local;
- modo `off` como padrão;
- modo `shadow` sem comitar áudio retornado;
- modo `process` somente após gate adicional;
- timeout/falha do Helix mantém PCM original e caminho legado.

Evidência atual: DOC/SW em construção. Não promove áudio de produção. O transcoder `xuvd` ativo do XLX026 foi identificado como backend local em `127.0.0.1:10100`; nenhuma substituição/restart de produção foi executada durante esta etapa.


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
