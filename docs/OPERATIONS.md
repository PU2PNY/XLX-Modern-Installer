# Operação segura — XLX Modern Installer / XLX026

## Antes de qualquer mudança
1. identificar branch/commit;
2. registrar versão;
3. identificar baseline que não pode regredir;
4. conferir health/status/logs relevantes;
5. criar backup/ponto de retorno quando houver risco;
6. limitar escopo;
7. testar fora de produção quando possível.

## Produção
Não usar o XLX026 como ambiente de experimento. Mudança de core, protocolos, áudio/transcoding, rede, systemd, firewall, PHP/Nginx, banco ou persistência deve passar primeiro por laboratório/VPS.

## Diagnóstico
Preferir mecanismos já existentes no projeto: health, status, logs, self-tests e checks. Não instalar observabilidade pesada sem medir custo.

## Deploy
- documentação: branch + PR;
- código de baixo risco: branch + CI + regressão;
- mudança de infraestrutura: plano + backup + janela + validação + rollback;
- produção: somente após evidência compatível com risco.

## Pós-mudança
Registrar:
- commit;
- arquivos alterados;
- testes;
- resultado;
- regressões;
- rollback disponível;
- impacto observado.

## Proibido
- mudanças múltiplas sem isolamento;
- `chmod 777`;
- apagar arquivos sem backup;
- reiniciar serviços “para ver se resolve” sem diagnóstico;
- atualizar dependência crítica sem comparação de compatibilidade;
- publicar segredos/logs privados.

## Analisador passivo de transmissão
O serviço `xlx-modern-transmission-analyzer.service` observa cópias dos datagramas YSF recebidos. Ele não é proxy, não reencaminha tráfego e não altera áudio.

Estado local: `/var/lib/xlx-modern-transmission-analyzer/state.json`.
Eventos de anomalia: `/var/log/xlx-modern-transmission-analyzer/events.log`.

Interpretação:
- `likely_missing_frames`: somente quando salto de sequência e tempo decorrido são compatíveis;
- `counter_jump`: contador mudou de forma incompatível com perda temporal; não converter automaticamente em “pacotes perdidos”;
- `concurrent_endpoints`: mais de um endpoint recente para o mesmo indicativo;
- o V1 não mede ruído acústico, clipping ou equalização porque não decodifica AMBE/AMBE+2.

## Helix PCM Bridge
A integração experimental Helix deve ser operada em três fases explícitas:
1. `off` — comportamento legado; estado padrão;
2. `shadow` — Helix recebe PCM por datagrama Unix não bloqueante; não existe espera de resposta nem alteração do áudio transmitido;
3. `process` — PCM retornado pode ser usado somente após validação ENV e gate específico de áudio/rollback.

O cliente tem timeout local limitado a 5 ms na V1, com orçamento total por requisição e comportamento fail-open. Erro, socket ausente, timeout ou resposta inválida devem manter o PCM original; em `process`, a primeira falha fixa o restante daquele stream no legado. Não introduza API/cloud no caminho de áudio. Antes de qualquer mudança do transcoder ativo, registre PID, binário/hash, unit/config, tráfego ativo, proveniência das dependências usadas no build e ponto de retorno.

### Gate adicional antes de shadow

Antes de substituir o xuvd conhecido-bom por um build com suporte Helix, execute `experimental/helix-bridge/test-prod-equivalence.sh` em ENV usando:
- uma cópia exata do binário xuvd de produção;
- a árvore OP25 historicamente correspondente;
- opcionalmente o `helix-daemon` para validar `shadow`.

O teste deve ser bit-idêntico nos quatro caminhos do corpus. Não execute este teste em um host onde `127.0.0.1:10100` já esteja em uso. PCAP/corpus bruto de produção não deve ser versionado.

Não aumentar a deadline para esconder falhas sob contenção. A execução adicional do wrapper entregou todos os frames mas acionou fallback em ambos os streams: continuidade foi validada, confiabilidade process permanece PARCIAL. Avaliar scheduling/CPU/latência em soak dedicado antes de qualquer promoção.

### Operação Helix shadow em produção
- `helix-voice-shadow.service` observa PCM via Unix datagram local; ele não participa da entrega do áudio legado.
- `xlx-helix-monitor.timer` atualiza telemetria local a cada 30 s. A análise remota é limitada a cada 15 min ou mudança de anomalia.
- Nunca enviar áudio, conteúdo de voz, indicativo ou payload de rádio à API externa.
- O indicador do Live deve dizer `HELIX • MONITORANDO`/`SHADOW`, nunca `PROCESSANDO`, enquanto `XLX_HELIX_MODE=shadow`.
- Se Helix/monitor/OpenAI falhar, verificar o caminho legado antes de qualquer ação; não reiniciar XLXD por causa do observador.
- `process` continua proibido até seus gates próprios serem concluídos.

## Stereo Tool — operação da fundação LAB

A etapa atual é somente laboratório. Ela não instala Stereo Tool no XLX026, não altera `xlxd`/`xuvd` e não muda o áudio transmitido.

Procedimento permitido:
1. obter o artifact diretamente do fornecedor pelo administrador;
2. manter o artifact fora do Git e fora do webroot;
3. executar `experimental/stereotool/artifact_validator.py` em ambiente de laboratório;
4. interpretar `READY_FOR_SANDBOX` apenas como aprovação para a próxima etapa isolada;
5. registrar SHA-256, arquitetura, GLIBC, origem e resultado sem registrar licença/chave;
6. só depois construir/usar worker sandbox com o SDK oficial.

Rejeitar promoção quando:
- houver dúvida de origem/integridade do artifact;
- SDK oficial não estiver disponível;
- autorização comercial/jurídica para o uso pretendido não estiver escrita;
- licença estiver inválida/ambígua;
- houver crash, state leakage, audio drop ou crescimento de memória;
- latência/CPU/RAM não estiverem medidos;
- emergency bypass e restore não estiverem comprovados.

A unidade em `experimental/stereotool/systemd/xlx-stereotoold.service.example` é **referência**, não deve ser habilitada na etapa atual. A futura unidade deve permanecer `AF_UNIX`-only e sem web UI do fornecedor.

Não usar Stereo Tool para “corrigir” a instabilidade atual de `process` do Helix e não empilhar os dois DSPs automaticamente. Cada mecanismo mantém gates, benchmark e rollback separados.

## TX Turn Guard / anti-ping-pong

O candidato está em `experimental/tx-turn-guard/` e permanece desligado por padrão. `apply-and-build.sh` é somente LAB: aplica o patch à revisão XLXD aprovada e compila, sem instalar, reiniciar ou habilitar o recurso.

Configuração V1 de referência:

```text
XLX_TX_TURN_GUARD=1
XLX_TX_TURN_TRIGGER_MS=2000
XLX_TX_TURN_COOLDOWN_MS=7000
XLX_TX_TURN_RESET_MS=60000
```

Antes de qualquer canário:
1. validar o patch no commit upstream documentado;
2. executar `tests/test-tx-turn-guard.sh` e a suíte geral;
3. testar DMR MMDVM, YSF/C4FM e D-Star separadamente em ENV, incluindo EOT normal e timeout;
4. provar que Wires-X/link/unlink/keepalive/comandos legítimos continuam funcionando;
5. provar que terceiro usuário entra imediatamente durante a janela A/B;
6. provar que módulo independente não é bloqueado;
7. registrar binário/hash/unit/env atuais do XLXD e criar backup root-only;
8. restaurar o binário/config/unit conhecidos em ENV e revalidar protocolos;
9. somente então considerar canário PROD.

Eventos `TXTURN` não devem conter indicativo, RadioID, IP ou payload. O monitor de IA é consultivo e executado por timer separado; a OpenAI recebe somente contadores agregados. Ausência de chave/API não muda o comportamento do guard. Nunca usar resposta da IA como autorização para abrir/fechar stream.
