# Preview experimental de fundo prismático (2026-11-10)

Status: **PROD opt-in (visual CSS somente)**, **não aprovado como tema padrão**.
Requisito candidato: UI-PRISM-001 (não permanente até aprovação).
O efeito é **CSS original inspirado no conceito visual de prismas/slats**, e **não** contém código ou materiais do React Bits Pro.

## Objetivo e escopo
- Testar um fundo prismático no cabeçalho existente, sem mudar DOM/JS, TX/RX, XLXD, transcoder, áudio, CallingHome, módulos, APIs, rotas ou idiomas.
- Não adicionar React, WebGL, polling, chamadas externas, novos scripts, fontes ou acesso a dados.
- Ativação somente com o parâmetro `prismatic=1`.
- As demais URLs mantêm o tema original; respeitar `prefers-reduced-motion` e manter versão móvel estática.
- Avaliar legibilidade, consumo de CPU/GPU e responsividade antes de qualquer proposta para o tema padrão.

## Evidência de implantação opt-in no XLX026 (2026-11-10)
- GitHub base `main` consultado: `ee9f6670bc41d3d024793e758f72cccc29855c9c`. **Não** equivale ao runtime PROD.
- Em PROD, backup root-only anterior: `/opt/xlx026-backups/PRISMATIC_PREVIEW_20261110_113422_UTC`, incluindo `index.php.orig`, manifesto e `ROLLBACK.sh`.
- Arquivo PROD `index.php` original SHA-256: `2e108ebe2bcaa6cf02795ab0971de55991a8cf80f20d3492b36e18e795b5681b`.
- Teste de cópia restaurável com hash e comparação binária: PASS.
- PHP lint sobre a modificação no runtime: PASS.
- Verificação PROD: `/ao-vivo` e `/ao-vivo?prismatic=1` HTTP 200, stylesheet HTTP 200; `/api/live.php`, `/modulos`, `/conectados` HTTP 200, Nginx/XLXD ativos.
- O link `/` redireciona para `/ao-vivo` descartando parâmetros. Para teste usar **/ao-vivo?prismatic=1**, não **/?prismatic=1**.
- Inspeção visual e benchmark GPU/mobile são gates separados; não inferir PASS por HTTP 200.

## Rollback
- Desligamento imediato por visitante: navegar para `/ao-vivo` sem `?prismatic=1` (tema original, nenhum CSS adicional).
- Remoção total da implementação PROD: script privado `ROLLBACK.sh` no backup acima restaura `index.php.orig` e remove somente `assets/prismatic-preview-v1.css`; verificar hash, HTTP, Live e serviços após uso.
- Não executar rollback cego se `index.php` mudou posteriormente; comparar primeiro.
- Reversão Git: fechar/reverter a PR, sem merge enquanto estiver em avaliação.
- Não copiar arquivos PROD XLX026 integrais para o repositório genérico: há drift confirmado e dados específicos.

## Aceitação antes de ativar globalmente
- Visual desktop/mobile e acessibilidade aprovados pelo operador.
- Se `prefers-reduced-motion`, animação desligada.
- Diferenças da velocidade, CPU/GPU, estabilidade de TX/RX e memória medidas sem degradação significativa.
- Sem efeitos em idiomas, menu, serviços, áudio ou live.
- **Nenhum uso do React Bits Pro proprietário sem licença válida**: https://pro.reactbits.dev/license.
