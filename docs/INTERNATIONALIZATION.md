# Internationalization / Internacionalização do XLX Modern Dashboard

O objetivo é transformar o dashboard em um painel universal, sem manter cópias separadas por idioma.

## Idiomas planejados

| Código | Idioma | Prioridade |
|---|---|---:|
| `pt-BR` | Português (Brasil) | 1 |
| `en` | English | 1 |
| `es` | Español | 1 |
| `fr` | Français | 2 |
| `de` | Deutsch | 2 |
| `it` | Italiano | 2 |

## Comportamento pretendido

Durante a instalação do dashboard, o instalador deverá oferecer:

```text
Choose dashboard language / Escolha o idioma do painel
1) Português (Brasil)
2) English
3) Español
4) Français
5) Deutsch
6) Italiano
7) Automatic / Automático
```

O idioma selecionado será salvo como idioma padrão do painel. A opção `Automatic` poderá utilizar a preferência do navegador quando existir tradução compatível.

## Estrutura proposta

```text
dashboard/
├── i18n/
│   ├── bootstrap.php
│   └── locales/
│       ├── pt-BR.php
│       ├── en.php
│       ├── es.php
│       ├── fr.php
│       ├── de.php
│       └── it.php
├── config/
│   └── site.php
└── assets/
```

Exemplo de chave:

```php
'nav.live' => 'Ao vivo',
'nav.connected' => 'Conectados',
'live.standby' => 'Servidor em espera',
'history.title' => 'Últimas transmissões',
```

English:

```php
'nav.live' => 'Live',
'nav.connected' => 'Connected',
'live.standby' => 'Server on standby',
'history.title' => 'Latest transmissions',
```

## Escopo da tradução

A internacionalização deve cobrir todo texto apresentado ao visitante:

- navegação;
- títulos e subtítulos;
- monitor ao vivo;
- standby;
- informações de TX;
- tabela de transmissões;
- conectados;
- módulos;
- ranking;
- lista de refletores;
- suporte;
- notícias;
- clima e propagação;
- status Online/Offline;
- mensagens de carregamento e erro;
- tooltips;
- instalação PWA;
- textos gerados por JavaScript;
- metadados SEO (`title`, `description`, Open Graph e idioma HTML).

## Preferência por visitante

Além do idioma padrão escolhido na instalação, o dashboard poderá disponibilizar um seletor discreto de idioma. A preferência individual deverá ser salva no navegador (cookie ou `localStorage`) sem alterar a configuração global do servidor.

## SEO multilíngue

Quando o dashboard estiver totalmente internacionalizado, cada idioma deve expor metadados coerentes e, quando possível, URLs previsíveis ou parâmetros de idioma acompanhados de `hreflang`.

Exemplo:

```html
<link rel="alternate" hreflang="pt-BR" href="https://example.net/?lang=pt-BR">
<link rel="alternate" hreflang="en" href="https://example.net/?lang=en">
<link rel="alternate" hreflang="es" href="https://example.net/?lang=es">
<link rel="alternate" hreflang="x-default" href="https://example.net/">
```

## Regra de implantação

A internacionalização deve ser implementada em etapas e validada antes de substituir o dashboard estável:

1. inventariar todas as strings PHP e JavaScript;
2. criar o motor de tradução;
3. migrar o Português para chaves sem alterar o visual;
4. adicionar English e Español;
5. validar todas as páginas e o monitor ao vivo;
6. adicionar seletor de idioma;
7. integrar a escolha ao instalador;
8. adicionar Français, Deutsch e Italiano;
9. validar SEO multilíngue;
10. somente então promover para a versão estável.

Essa estratégia evita misturar mudança visual, funcional e linguística na mesma etapa.