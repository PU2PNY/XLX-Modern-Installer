# XLX026 — laboratório privado de React Bits Pro (preparação)

**Estado:** infraestrutura React/shadcn preparada, **Prismatic Slats Pro não baixado nem instalado** (chave ausente).  
**NÃO é um deploy. Não altera o painel PROD.**

O XLX026 mantém `Nginx + PHP-FPM` como stack web autoritativo. Esta subpasta é uma **island React opcional**, somente para experimentar o Prismatic Slats **como fundo integral da página** depois da instalação licenciada.

## Por que isolado
- Não transformar o dashboard inteiro em React nem introduzir SSR/Next.js em produção.
- Não alterar a marca, cabeçalho, menus, APIs, boxes TX/RX, regras de câmbio, Helix ou áudio.
- O pacote React Bits Pro tem licença proprietária que proíbe publicar seu código no GitHub público do projeto: https://pro.reactbits.dev/license
- CSS anterior `?prismatic=1` continua sendo uma experiência separada e não é o React Bits Pro original.
- O plano futuro é carregar bundle estático somente via opt-in `?prismatic-pro=1`, com fundo fixo não interativo, proteção de contraste e redução de movimento. **Não fazer isso antes dos testes e aprovação.**

## Pré-requisitos
Node >=18 (WartyWallaby já tinha Node 20.20.2 em 2026-11-10). Possuir licença oficial ativa de React Bits Pro (Starter ou superior). O token deve ser configurado somente em ambiente privado, nunca em arquivos versionados, na pasta web ou em logs.

## Instalação em cópia PRIVADA (não execute no webroot XLX026)
1. Copiar esta subpasta para um diretório privado de laboratório fora do GitHub público, mantendo `.gitignore`.
2. `npm install`
3. Configurar `REACTBITS_LICENSE_KEY` por gerenciador de segredos ou `.env.local` privado. **O script precisa da variável exportada no processo**; o CLI pode ler `.env.local` conforme documentação oficial.
4. `npm run verify:registry`
5. `npx shadcn@latest add @reactbits-starter/prismatic-slats-tw` (ou `bash scripts/install-private.sh` após exportar a variável).
6. Inspecionar os arquivos realmente gerados e as props do componente. **Só então** importar o componente real em `src/App.tsx`, limitar DPR/FPS quando suportado, respeitar `prefers-reduced-motion` e gerar bundle de produção com `npm run build`.
7. Testar desempenho e geometria no laboratório antes de criar uma URL opt-in no XLX026. Fazer backup e restore-test antes de qualquer deploy.

## Registro
O `components.json` desta subpasta tem os namespaces `@reactbits-starter` e `@reactbits-pro` e `Authorization: Bearer ${REACTBITS_LICENSE_KEY}` — apenas placeholder, sem segredos. 
A instalação da versão `-tw` usa Tailwind CSS 4; a alternativa oficial `-css` pode ser mais leve num painel sem Tailwind, mas o pedido original foi mantido.

## Gates para promoção
- Licença confirmada, downloads privados e redistribuição proibida no GitHub público.
- Unit test, build e relatório de acessibilidade/performance; validação mobile e TX ativo (não apenas standby).
- Fundo global opt-in isolado, sem criar nova camada interativa acima dos controles.
- Backup root-only, hash SHA256, restore test e rollback sem reiniciar XLXD/Nginx/áudio.
- Avaliação visual pelo operador antes do tema tornar-se padrão.

Fontes: https://pro.reactbits.dev/docs/installation · https://pro.reactbits.dev/docs/components/prismatic-slats · https://pro.reactbits.dev/license
