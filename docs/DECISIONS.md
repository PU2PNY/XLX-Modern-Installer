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
O indicador compacto no canto superior direito é insuficiente para comunicar o recurso. O estado deve virar um banner horizontal dentro do box TX, abaixo do cabeçalho e antes dos dados da transmissão. O banner reutiliza o mesmo estado sanitizado já existente, não cria fetch/polling, não usa animação contínua e não pode ocultar NO AR, MTR/VU, indicativo, gateway, protocolo ou tempo de TX.
