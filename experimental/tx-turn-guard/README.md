# TX Turn Guard / Anti-Ping-Pong V1

Status: experimental / LAB. **Não é ativado automaticamente e não autoriza deploy em produção.**

## Objetivo

Preservar o TOT existente de 180 s e criar espaço de câmbio sem bloquear o refletor inteiro.

A regra trabalha por **módulo lógico** e pela identidade `MY`/origem já normalizada pelo XLXD:

1. A transmite e encerra (EOT).
2. B entra em até 2.000 ms e encerra.
3. A volta em até 2.000 ms.
4. A sequência `A -> B -> A` ativa a dupla anti-ping-pong naquele módulo.
5. Quando um integrante da dupla encerra o stream, A e B ficam impedidos de abrir **novo stream DV de voz** por 7.000 ms.
6. Qualquer terceira estação C continua apta a entrar imediatamente; se C entrar, o estado da dupla é quebrado.
7. Uma tentativa bloqueada não reinicia nem prolonga a janela.
8. Após 60 s sem atividade relevante, o estado é descartado.

A regra é por módulo. Uma dupla detectada em C não bloqueia o mesmo indicativo em outro módulo independente.

A identidade principal é o callsign `MY`. Em DMR, se o RadioID não puder ser resolvido para callsign, o próprio RadioID é usado **somente como fallback interno de identidade** para não deixar uma estação sem proteção. Essa identidade interna nunca é incluída nos eventos `TXTURN` enviados ao observador. Indicativos compartilhados/forjados continuam sendo uma limitação de uma rede sem autenticação forte de operador e exigem observação no gate real.

## Controles que não são bloqueados

A decisão ocorre somente em `CReflector::OpenStream()` para abertura de stream DV. Keepalive, conexão, link/unlink e demais pacotes de controle que não abrem stream DV não passam pelo bloqueio. Se algum protocolo provar em ENV que um comando legítimo é transportado como stream DV comum, a exceção deve ser implementada de forma explícita e testada; não inferir.

## Configuração do candidato

O patch permanece **OFF por padrão**.

```text
XLX_TX_TURN_GUARD=1
XLX_TX_TURN_TRIGGER_MS=2000
XLX_TX_TURN_COOLDOWN_MS=7000
XLX_TX_TURN_RESET_MS=60000
```

Limites internos:
- trigger: 250..10000 ms;
- cooldown: 1000..30000 ms;
- reset configurado: 10000..600000 ms;
- o reset efetivo nunca fica abaixo do cooldown, mesmo com configuração incoerente.

Valores inválidos voltam ao padrão seguro do código.

## IA / observador

`monitor/xlx-tx-turn-ai-monitor.py` é opcional e fica **fora do hot path**. Ele lê apenas eventos técnicos `TXTURN` do journal e envia, no máximo, métricas agregadas para a API OpenAI. O patch deliberadamente não inclui indicativos nos eventos `TXTURN`; áudio, conteúdo de voz, RadioID, IP e payload de rádio não são enviados à IA.

A IA é consultiva. Ela pode apontar excesso de bloqueios, frequência de detecção e necessidade de revisar limiares, mas **não pode liberar, bloquear ou alterar um stream**. Falha de API não afeta XLXD.

## Upstream alvo do patch

O artefato V1 é validado contra:

```text
PP5PK/xlxd
e69f2dcdd9cf004d5ad199f85c27f1fa1e7e5004
XLXD 2.5.3
```

`apply-and-build.sh` recusa outra revisão para evitar aplicar patch em código divergente. Depois do build, `test-cpp-unit.sh /caminho/do/xlxd` executa a máquina de estados diretamente sobre as classes C++ do candidato; ele não instala nem inicia o daemon.

## Gates antes de produção

- patch aplica limpo no commit alvo;
- compilação completa do XLXD;
- regressão específica do estado A/B/A;
- terceiro usuário sempre livre;
- tentativa bloqueada não estende cooldown;
- módulos independentes;
- DMR MMDVM, YSF/C4FM e D-Star validados separadamente em ENV;
- comandos/keepalives/link sem regressão;
- multi-TX entre módulos preservado;
- backup do binário/config/unit atuais;
- restore do binário/config/unit testado;
- somente depois canário de produção, com rollback imediato em regressão.

Não confundir build/CI com validação de protocolo real.
