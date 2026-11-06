# Espaço de câmbio V2 — participantes de qualquer QSO (3 s)

**Status 2026-11-05:** candidato LAB, ainda não implantado no XLX026 PROD. Issue #98. A V1 ativa no servidor ainda detecta a alternância A→B→A.

## Comportamento

- Cada módulo mantém sua própria relação de participantes, definidos pelo encerramento real da primeira transmissão DV da estação no QSO. Somente conexão/keepalive não cadastra participante.
- Quem chega pela primeira vez entra livremente, mesmo se a estação anterior acabou de soltar PTT. Depois do primeiro EOT, passa a respeitar o intervalo dos demais.
- Qualquer participante que tente abrir novo stream DV antes de **3.000 ms desde o EOT anterior** é recusado e recebe **7.000 ms de penalidade individual a partir da tentativa**. O prazo não é prolongado por novas tentativas. Quem não cometeu infração entra depois dos 3 s.
- A lista de QSO é esquecida quando transcorrerem mais de 60.000 ms de silêncio entre EOTs no módulo. Memória limitada a 128 participantes/módulo; ao ultrapassar o limite, a identidade mais antiga é esquecida. Outros módulos não são afetados.
- Estados usam relógio monotônico no C++, nunca decisão por API OpenAI. Eventos TXTURN não incluem identidade, RadioID, IP, áudio ou payload. A IA é observadora.
- Comandos fora de stream DV e keepalives mantêm caminho legado. Comandos que abram DV exigem prova específica de isenção em ENV antes de PROD.
- **TOT180, YSF VW, transcoder, codecs, CallingHome, áudio e dashboard ficam intocados no candidato C++.**

## Proveniência e configuração

Baseline LAB WartyWallaby: `/opt/xlx-vw-lab-20261023/candidate/src/xlxd` tem SHA-256 **3991b040573ff7522af69148c97f768d0b468b716212bf7b8e047fca1c6cc410**, idêntico ao executável inspecionado no XLX026 em 2026-11-05. O `/usr/src/xlxd` de produção é divergente, **não usá-lo** como base. O patch neste repositório aplica somente às fontes exatas do candidato VW, no topo das alterações V1/TOT180 existentes.

```text
XLX_TX_TURN_GUARD=1
XLX_TX_TURN_POLICY=participants
XLX_TX_TURN_TRIGGER_MS=3000
XLX_TX_TURN_COOLDOWN_MS=7000
XLX_TX_TURN_RESET_MS=60000
XLX_TX_TURN_STATE_DIR=/run/xlx-tx-turn-state
```

Na ausência de `XLX_TX_TURN_POLICY=participants`, o código mantém a política V1 A/B/A original. O instalador público não ativa o recurso automaticamente.

Artefato: `patches/xlxd-vw-20261023-participants-v2-3s.patch`. O patch só adiciona método e estado isolados e dois desvios opcionais de admissão/EOT; não substitui o binário de produção.

## Testes executados em 2026-11-05

- PROD (somente leitura): XLXD em PID 1298, SHA baseline idêntico ao LAB; indicadores OpenAI/Helix recuperados reiniciando apenas os dois monitors/timers, sem reiniciar o rádio.
- ENV (WartyWallaby): `make -C src -j2` PASS; binário candidato SHA `48fc86495d714142ccd24069e3f198cc4a06309a66c6230630d9d040f0736577`.
- ENV: `test-tx-turn-guard` V1 legado PASS (A/B/A, cooldown, terceiro, TOT).
- ENV: C++ multiparty PASS (4 e 12 participantes; admissão de novo usuário; cada um penalizado; tentativa repetida; 3 s; módulo independente; reset; limite 128; V1 opt-in/off; TOT181).
- ENV: handlers reais DCS/D-STAR, YSF e DMR MMDVM em fixtures sintéticas: stream admit/EOT, retry bloqueado, terceiro livre, keepalive, timeout e TOT180 PASS.
- ENV: patch aplicado em cópia separada reproduziu bytes C++ idênticos ao candidato. Não equivale a HW ou RF.

## Pendências bloqueantes antes da produção

1. Registrar aprovação do contrato da penalidade de 7 s com 3 s mínimos (proposta baseada na regra V1 previamente aprovada).
2. O Live atual lê no máximo **dois indicativos e um prazo por módulo**; o C++ novo aplica múltiplas penalidades individuais, mas publica somente o último infrator. **É necessário ampliar o contrato do Live e o frontend para mostrar todos os infratores com prazos independentes**, ou implementar aviso limitado explicitamente aprovado, sem mentir sobre bloqueios.
3. Exercitar o patch no baseline completo e um rollback funcional em sandbox, incluindo serviço, configuração, backup privado e testes de restauração.
4. Testar D-STAR/DMR/YSF com hardware, VW DN/FR, comandos que usam DV, reconexões, múltiplos TX, CallingHome, histórico e tempo de latência sob carga. Não confundir teste de protocolo sintético com RF/HW.
5. Abrir PR, passar CI e preservar o modo anterior com um ponto de reversão funcional. Só então promover canário no XLX026 numa janela sem TX, com rollback imediato em caso de regressão. Não alterar `main` diretamente nem reiniciar `xlxd` para testes de desenvolvimento.
