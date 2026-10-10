# Decisões técnicas canônicas

## DEC-2026-09-21-001 — Produção saudável é baseline, não laboratório
O estado de produção relatado como perfeito em 2026-09-21 deve ser preservado. Pesquisa de fórum, versão nova ou refatoração não justificam alteração direta.

## DEC-2026-09-21-002 — Documentação antes de mudança funcional
A governança atual será aplicada em branch/PR separada, sem tocar no servidor ou no runtime de produção.

## DEC-2026-09-21-003 — CHANGELOG existente é o histórico canônico
Não criar `PROJECT_CHANGELOG.md` duplicado. O histórico oficial permanece em `CHANGELOG.md`.

## DEC-2026-09-21-004 — Evidência separada
Relato do operador, código, CI, staging e produção são níveis distintos. Nenhum é promovido por inferência.

## DEC-2026-09-21-005 — Atualização do XLXD exige validação
Não atualizar XLXD apenas por número de versão. Compatibilidade de D-Star/DMR/YSF, áudio/transcoding, interlinks e dashboard deve ser testada antes.

## DEC-2026-09-21-006 — Backlog de fórum não é ordem de execução
Itens de comunidade ficam em `docs/RESEARCH_BACKLOG.md` até existir evidência local, critério de aceitação, teste e rollback.

## DEC-2026-09-23-007 — Timeout administrativo deve ser específico da rota
Quando uma manutenção administrativa validada (ex.: reconstrução atômica do RadioID) exceder o orçamento FastCGI público, a correção preferida é uma janela adicional limitada à rota privada. Não aumentar o timeout global do dashboard/APIs apenas para acomodar a operação administrativa.

## DEC-2026-09-28-008 — Documentos canônicos ficam na branch principal
Os documentos de governança obrigatórios devem existir no `main` mantido, não apenas em branch lateral. Drift documental que descreva Apache/dry-run como estado atual deve falhar em teste automatizado enquanto o fluxo autoritativo permanecer Nginx + PHP-FPM.

## DEC-2026-09-30-009 — Orçamento total Helix IPC V1
A instrução explícita desta continuação limita XLX_HELIX_TIMEOUT_MS a 1..5 ms.
Ela substitui o aumento anterior para 10 ms descrito na branch.
O cliente usa uma única deadline monotônica desde a conexão até a resposta completa,
com socket não bloqueante e fallback sem alterar PCM. Não renovar o timeout a
cada leitura parcial. Linux pode produzir overshoot de wall-clock por scheduling;
nenhuma resposta recebida após a deadline pode substituir o PCM legado.
Não mudar DSP, codec, XLXD ou transcoder de produção para testar esse requisito.

## DEC-2026-10-01-010 — Conectados usa sessão pública canônica sem perder endpoints brutos
O XML do XLXD pode expor múltiplos `NODE` para a mesma identidade durante reconexões. Para a página e os contadores públicos, duplicatas com o mesmo indicativo, sufixo, protocolo e módulo são consolidadas em uma única sessão: vence a linha com `last_activity` mais recente e, em empate, `connected_at` mais recente.

A lista bruta permanece separada para `active_and_history()` e correlação de TX/endpoint. A correção não altera XLXD, protocolos, áudio, transcoder ou sockets; é uma normalização de apresentação/contagem do dashboard.

## DEC-2026-10-01-011 — Alias de indicativo entra antes da contagem pública
A validação PROD da correção de Conectados encontrou um caso adicional: um `NODE`
com indicativo histórico e outro com o indicativo atual eram convertidos para a
mesma identidade pública somente depois da primeira canonicalização. Resultado:
a primeira implantação reduziu fortemente os duplicados, mas ainda deixou 1 grupo.

Regra: quando houver identidade já resolvida pelo diretório/alias, a chave canônica
deve usar essa identidade resolvida antes da contagem pública. Em produção XLX026,
onde existe normalizador RadioID local anterior ao JSON final, o alias é aplicado à
cópia pública antes de `canonical_connections()`. A lista bruta permanece intacta
para correlação TX/endpoint.

## DEC-2026-10-01-012 — Nó DExtra interno do XLXD não conta como estação
A captura PROD mostrou cinco entradas `DExtra` do indicativo do operador, uma por
módulo A–E, todas originadas do mesmo endereço usado no `ExecStart` do próprio
XLXD, com `Via` e `Peer` vazios e sem atividade posterior ao instante de criação.
Essas entradas são nós internos do refletor, não cinco estações conectadas.

A lista pública deve remover somente o caso comprovado: protocolo DExtra +
endpoint igual a um endereço local do XLXD + `Via` vazio + `Peer` vazio.
O endereço do XLXD é obtido localmente da unit systemd; não usar DNS ou API
externa no hot path. A lista bruta continua intacta para correlação de TX.

## DEC-2026-10-02-013 — Stereo Tool começa como fundação LAB isolada
Stereo Tool é código proprietário, stateful e potencialmente pesado. A primeira implantação aprovada contém apenas validação estática de artifact, mock, documentação, testes e referência de hardening; ela não instala o produto, não modifica `xlxd`/`xuvd` e não altera o áudio de produção.

A integração runtime futura deve usar processo separado e IPC local. O worker não pode expor rede Internet/web UI do fornecedor; falha deve resultar em bypass para o PCM original, e `PROCESS` só pode existir depois de delay-matched fail-open, contexto por stream, benchmark, chaos/rollback e autorização comercial/jurídica escrita para o uso multiusuário. `READY_FOR_SANDBOX` não autoriza `SHADOW` nem `PROCESS`.

Helix e Stereo Tool mantêm gates independentes. Não usar o Stereo Tool para mascarar a confiabilidade ainda parcial do `process` Helix nem empilhar ambos automaticamente no hot path.

## DEC-2026-10-04-014 — Anti-ping-pong usa regra local determinística e IA apenas consultiva
O objetivo é criar espaço real de câmbio sem impor um lockout global. A V1 identifica, por módulo lógico, alternância rápida `A -> B -> A`; após a detecção, o EOT de um membro inicia uma janela de 7 s na qual somente a dupla A/B fica inelegível para novo stream DV de voz. Terceiros permanecem livres e quebram o estado da dupla. Tentativas negadas não prolongam o cronômetro e o TOT de 180 s permanece separado.

A decisão de admitir ou negar stream deve ocorrer localmente no XLXD, usando relógio monotônico e a identidade `MY`/origem, nunca API externa. Keepalive, conexão, Wires-X/controle fora de stream e demais pacotes que não abrem DV não entram no bloqueio. Se algum protocolo usar stream DV comum para comando legítimo, a exceção depende de evidência ENV e teste específico.

A IA é observadora: recebe somente contadores técnicos agregados e pode sugerir revisão de limiares/falsos positivos. Não recebe áudio, conteúdo de voz, indicativos, RadioID, IP ou payload e nunca participa da decisão em tempo real. O recurso fica `off` por padrão até gates de DMR, YSF/C4FM, D-Star, backup e restore.

### Continuação 2026-10-04 — economia do observador
Silêncio ou resumo idêntico não geram consulta. Mudança de avaliação não pode furar o limite de 15 minutos entre tentativas. A regra local permanece independente da API. Teste C++ deve exercitar a sequência completa admit/EOT, além dos casos de estado preparado.

## DEC-2026-10-10-015 — XLX026 trigger de câmbio 3 s
Operador autorizou 3 s após diagnóstico de alternâncias com intervalos de 2,079–2,286 s que não armavam o limite de 2 s. Override somente XLX026: XLX_TX_TURN_TRIGGER_MS=3000; cooldown7000, reset60000, TOT180 e política pública OFF preservados. Binário não alterado.
