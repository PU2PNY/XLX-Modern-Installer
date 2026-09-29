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

## DEC-2026-09-29-009 — Padronização de áudio sem LLM no caminho TX/RX
A normalização em tempo real deve ser local e determinística. OpenAI poderá ser usada futuramente apenas para diagnóstico agregado e sob demanda. A V1 atua somente em DMR, aprende o nível por transmissão, falha aberta quando faltam amostras e modifica o ganho AMBE+2 sem nova geração PCM/AMBE. Replay provou que o valor codificado não é 1:1 com dB PCM; por isso a candidata ±3 foi rejeitada e o teto passou a ±1,0 codificado, com escala empírica 0,125, referência ativa próxima de -30 dBFS, deadband ±3,5 dB e aprendizagem de 40 quadros ativos. A janela menor de 12 quadros também foi rejeitada porque o início de TX não representou corretamente PU2MIZ/PU2UJY. O recurso permanece desligado por padrão até validação ENV + rádio real/HW.

## DEC-2026-09-29-010 — Status de IA deve ser verificável e não promocional
O dashboard só pode dizer que a IA analisou, recomendou ou orientou um ajuste quando existir evento server-side correspondente. Ajustes do DSP local aparecem como DSP, não como IA. A chave OpenAI fica fora do webroot/Git e V1 não envia áudio nem consome tokens de inferência.

## DEC-2026-09-29-011 — Estado da IA deve ser visível dentro do box TX sem pesar o Live
O indicador de IA deve ficar centralizado no cabeçalho do próprio box TX, na mesma linha entre “Transmitindo agora” e “NO AR”. O componente usa largura automática e reduz conteúdo secundário em telas estreitas para preservar o restante do box. Reutiliza o mesmo estado sanitizado já existente, não cria fetch/polling, não usa animação contínua e não pode ocultar NO AR, MTR/VU, indicativo, gateway, protocolo ou tempo de TX.

## DEC-2026-09-29-012 — IA no Controle é observabilidade privada antes de automação
A página privada Controle deve exibir conexão OpenAI, estado atual, última atualização e última ação real usando exclusivamente o objeto sanitizado `ai_monitor` já obtido por `status.php`. Nenhuma chave é lida pelo PHP público/privado e nenhum novo polling é criado. Enquanto não existir backend de inferência manual/automática validado, o Controle deve informar explicitamente que análise automática por IA ainda não está habilitada, em vez de oferecer um botão enganoso.

## DEC-2026-09-29-013 — Controle dividido por visualizações internas
A rota privada existente permanece única. A navegação usa `?view=home|health|access|radioid` sob o mesmo `adminPath`, evitando qualquer nova regra Nginx. Início contém resumo, IA do Servidor, integridade/testes, listeners, logs, backups e reinício. Saúde Operacional, Controle de Acesso e Interlink e Indicativos & RadioID ficam em visualizações próprias. Ações POST continuam protegidas pela mesma sessão, CSRF, helpers limitados e auditoria.
