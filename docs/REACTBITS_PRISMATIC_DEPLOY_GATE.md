# React Bits Pro Prismatic Slats — estado do requisito experimental

- Data: 2026-11-10.
- Requisito candidato: UI-PRISMATIC-PRO-001 (fundo global, sem mudança na UI original).
- Origem: https://pro.reactbits.dev/docs/components/prismatic-slats
- **Status: BLOCKED, licença indisponível no processo**. Não declarar `Prismatic Slats` original instalado, build testado ou PROD alterado.
- Detectado em `main` no GitHub: `components.json` e `package.json` ausentes na raiz. Repositório padrão `main`: `ee9f6670bc41d3d024793e758f72cccc29855c9c`; versão em VERSION: 1.4.6.
- Ambiente: Node 20.20.2 em WartyWallaby; `REACTBITS_LICENSE_KEY` não disponível no contexto de execução consultado em WartyWallaby e produção. Não foi procurado nem mostrado segredo de terceiros.
- Arquitetura: conservar o dashboard Nginx/PHP-FPM. A island React fica opcional em `experimental/reactbits-prismatic`, sem tocar na infraestrutura do rádio.
- Configuração dos dois registries no `components.json` incluída, sem chave real.
- Nunca incluir arquivos da registry Pro, fonte proprietário, token, `.env.local` ou build reutilizável do produto em GitHub público.
- Nenhuma PR desta fase está apta a merge como funcionalidade pronta. Só promover após licença, build, performance, acessibilidade, ENV, backup/rollback e validação OPERATOR.

## Estado de teste
- DOC: documentação/repositório e fontes oficiais verificadas.
- SW: validar sintaxe JSON, placeholders das registries e shell; **não há teste do componente original**.
- ENV: pendente (componente não instalado).
- HW: pendente.
- PROD: não modificado nesta fase; instalação de Prismatic Slats Pro pendente.

Fonte oficial licença: https://pro.reactbits.dev/license

## Build de scaffold comprovado (WartyWallaby, 2026-11-10)
- Clone temporário da branch experimental: PASS.
- `npm install --ignore-scripts --no-audit --no-fund`: PASS, 85 pacotes instalados em pasta temporária.
- `npm run build` (`tsc --noEmit && vite build`): PASS, Vite 7.3.8; bundle LAB 227477 bytes (antes do componente proprietário).
- Nenhum componente React Bits Pro instalado, nenhuma chave fornecida ou vazada, nenhum arquivo desta execução implantado em produção.
