# Contributing / Como contribuir

Obrigado por ajudar o **XLX Modern Installer**. Contributions that improve installation safety, documentation, protocol compatibility, internationalization or the modern dashboard are welcome.

## 🇧🇷 Português

Antes de propor mudanças:

1. não publique senhas, tokens, chaves privadas, bancos de usuários ou logs com dados pessoais;
2. não remova créditos ou licenças de projetos upstream;
3. preserve compatibilidade com Debian 12 salvo quando a mudança declarar explicitamente outro alvo;
4. para mudanças em instalação, mantenha backup, validação e rollback como princípios obrigatórios;
5. não transforme `install.sh` em um instalador destrutivo sobre produção existente;
6. para novos textos do dashboard, atualize todos os catálogos em `dashboard/i18n/locales/`;
7. valide shell e PHP antes de enviar a alteração.

### Validações mínimas

```bash
find . -type f -name '*.sh' -print0 | xargs -0 -r -n1 bash -n
find dashboard -type f -name '*.php' -print0 | xargs -0 -r -n1 php -l
```

Para internacionalização, compare as chaves de `pt-BR.php` com `en`, `es`, `fr`, `de` e `it`.

### Pull requests

Explique:

- problema que está sendo resolvido;
- arquivos alterados;
- impacto esperado;
- como foi validado;
- como reverter caso a alteração envolva instalação ou configuração.

## 🇺🇸 English

Before proposing changes:

1. never publish passwords, tokens, private keys, user databases or logs containing personal data;
2. preserve upstream credits and licenses;
3. preserve Debian 12 compatibility unless the change explicitly targets another platform;
4. installation changes must keep backup, validation and rollback as core principles;
5. do not make `install.sh` destructive over an existing production reflector;
6. when adding dashboard text, update every catalog under `dashboard/i18n/locales/`;
7. validate shell and PHP syntax before submitting.

### Minimum validation

```bash
find . -type f -name '*.sh' -print0 | xargs -0 -r -n1 bash -n
find dashboard -type f -name '*.php' -print0 | xargs -0 -r -n1 php -l
```

### Pull requests

Please describe:

- the problem being solved;
- files changed;
- expected impact;
- validation performed;
- rollback procedure when installation or configuration behavior changes.

## Related documents

- [Security policy](SECURITY.md)
- [Third-party notices](THIRD_PARTY_NOTICES.md)
- [Internationalization](docs/INTERNATIONALIZATION.md)
- [Portuguese documentation](README.md)
- [English documentation](README.en.md)
