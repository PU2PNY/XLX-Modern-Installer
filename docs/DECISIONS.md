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
