# Internationalization / Internacionalização do XLX Modern Dashboard

O XLX Modern Dashboard agora possui uma camada de internacionalização voltada para instalações públicas e uso internacional.

## Idiomas disponíveis

| Código | Idioma | Situação |
|---|---|---:|
| `pt-BR` | Português (Brasil) | ✅ |
| `en` | English | ✅ |
| `es` | Español | ✅ |
| `fr` | Français | ✅ |
| `de` | Deutsch | ✅ |
| `it` | Italiano | ✅ |

## Seleção durante a instalação

Ao instalar somente o dashboard:

```bash
sudo bash modules/60-dashboard-modern.sh
```

o instalador apresenta:

```text
Dashboard Language / Idioma do Painel
1) Português (Brasil)
2) English
3) Español
4) Français
5) Deutsch
6) Italiano
```

Também é possível definir diretamente:

```bash
sudo bash modules/60-dashboard-modern.sh --lang=en
```

Na instalação completa:

```bash
sudo bash install.sh --lang=en
```

Idiomas aceitos:

```text
pt-BR  en  es  fr  de  it
```

## Como funciona

A arquitetura evita manter seis cópias independentes do dashboard.

```text
dashboard/
├── i18n/
│   ├── bootstrap.php
│   ├── build.php
│   └── locales/
│       ├── pt-BR.php
│       ├── en.php
│       ├── es.php
│       ├── fr.php
│       ├── de.php
│       └── it.php
├── config/
└── assets/
```

O fluxo da instalação é:

```text
1. Copiar uma versão limpa do dashboard
2. Criar config/site.php
3. Executar i18n/build.php
4. Aplicar o idioma escolhido aos textos visíveis
5. Ajustar lang do HTML e locale do Open Graph
6. Registrar o idioma em config/site.php
7. Criar config/i18n-build-report.json
8. Validar todos os arquivos PHP
```

Isso mantém o código-base centralizado e permite gerar o painel final no idioma selecionado.

## Configuração gravada

Depois da instalação, `config/site.php` recebe informações de locale semelhantes a:

```php
'locale' => [
    'default' => 'en',
    'html' => 'en',
    'og' => 'en_US',
    'name' => 'English',
],
```

O relatório da tradução fica em:

```text
/var/www/html/xlx-dashboard/config/i18n-build-report.json
```

## Escopo de tradução

O catálogo já contempla as principais áreas do dashboard:

- navegação;
- monitor ao vivo;
- standby;
- transmissões;
- histórico recente;
- cabeçalhos de tabela;
- módulos;
- estações conectadas;
- ranking;
- lista de refletores;
- suporte;
- clima e propagação;
- estados Online/Offline;
- textos de carregamento;
- PWA / instalação do painel no dispositivo;
- títulos e descrições SEO;
- idioma HTML e Open Graph locale.

## SEO multilíngue

O instalador altera o idioma estrutural da página e o locale de Open Graph para combinar com o idioma escolhido.

Exemplos:

```html
<html lang="en">
<meta property="og:locale" content="en_US">
```

```html
<html lang="es">
<meta property="og:locale" content="es_ES">
```

A fase seguinte do projeto poderá adicionar troca de idioma por visitante e URLs dedicadas com `hreflang`, sem exigir reinstalação.

## Auditoria de textos ainda não traduzidos

O projeto mantém:

```bash
scripts/audit-dashboard-i18n.sh
```

Esse script ajuda a localizar strings em Português que possam ter sido adicionadas posteriormente ao PHP ou JavaScript sem entrar nos catálogos.

## Regra de manutenção

Qualquer novo texto visível deve ser incluído primeiro em `pt-BR.php` e depois receber equivalentes em todos os demais catálogos.

Ao adicionar uma página ou recurso novo:

```text
1. adicionar as novas strings ao catálogo base;
2. traduzir para en/es/fr/de/it;
3. executar auditoria;
4. testar uma instalação em Português;
5. testar pelo menos uma instalação em Inglês;
6. validar PHP e JavaScript;
7. conferir title/description quando houver impacto em SEO.
```

## Objetivo

Permitir que um administrador instale o mesmo projeto em diferentes países sem editar manualmente o código-fonte, mantendo uma única base de código, documentação bilíngue e possibilidade de expansão para outros idiomas no futuro.
