# Public Release Checklist / Checklist antes de tornar o repositório público

This repository should remain private until every critical item below has been reviewed.

Este repositório deve permanecer privado até que todos os itens críticos abaixo tenham sido revisados.

## 1. Sensitive-data audit / Auditoria de dados sensíveis

- [ ] no passwords in tracked files;
- [ ] no API tokens or GitHub tokens;
- [ ] no SSH private keys;
- [ ] no private TLS keys/certificates;
- [ ] no real user databases;
- [ ] no production backup archives;
- [ ] no `.env` files containing credentials;
- [ ] no Calling Home secrets;
- [ ] no operational logs containing personal or sensitive data;
- [ ] no unnecessary production IP addresses or private infrastructure details.

Suggested local checks:

```bash
git grep -nEi 'password|passwd|secret|token|authorization|bearer'
git grep -nE 'BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY'
git ls-files | grep -Ei '\.(pem|key|p12|pfx|sqlite|db|bak|tar|tgz|zip)$'
```

Review every match manually; words such as `token` can legitimately appear in documentation or source code without containing a secret.

## 2. Installation validation / Validação da instalação

- [ ] test `sudo bash install.sh --check` on clean Debian 12;
- [ ] test full installation on a disposable/staging Debian 12 VPS;
- [ ] confirm XLXD starts;
- [ ] confirm Apache configuration is valid;
- [ ] confirm the modern dashboard loads;
- [ ] confirm backup paths and install logs are created as documented;
- [ ] confirm production overwrite protection works.

## 3. Dashboard language validation / Idiomas do dashboard

- [ ] `pt-BR` build;
- [ ] `en` build;
- [ ] `es` build;
- [ ] `fr` build;
- [ ] `de` build;
- [ ] `it` build;
- [ ] verify navigation, live monitor, tables, ranking, weather and PWA text;
- [ ] verify `<html lang>` and Open Graph locale;
- [ ] review `config/i18n-build-report.json`.

## 4. GitHub quality / Qualidade do GitHub

- [ ] README Portuguese reviewed;
- [ ] README English reviewed;
- [ ] real dashboard screenshot renders correctly;
- [ ] documentation links work;
- [ ] `LICENSE` and `THIRD_PARTY_NOTICES.md` reviewed;
- [ ] `SECURITY.md`, `SUPPORT.md` and `CONTRIBUTING.md` present;
- [ ] GitHub Actions final run passes;
- [ ] repository About description configured;
- [ ] website configured;
- [ ] repository topics configured.

Recommended About description:

```text
XLX reflector installer for Debian 12 with modern multilingual dashboard — D-STAR, DMR and C4FM/YSF. Installation, updates, backup, recovery and troubleshooting.
```

Recommended website:

```text
https://xlx026.net
```

Recommended topics:

```text
xlx
xlxd
xlx-reflector
dstar
dmr
c4fm
ysf
ham-radio
amateur-radio
debian
debian12
digital-radio
xlx-dashboard
xlx-installer
dstar-reflector
dmr-reflector
```

## 5. First public release / Primeira versão pública

- [ ] choose semantic version (for example `v1.0.0` only after validation);
- [ ] update changelog;
- [ ] create Git tag/release;
- [ ] include installation summary and upgrade notes;
- [ ] make repository public only after the checks above are complete.

## 6. After publication / Depois de publicar

- [ ] enable Private vulnerability reporting if available;
- [ ] verify public clone works without authentication;
- [ ] verify README images are public;
- [ ] verify Google can access repository pages;
- [ ] link the GitHub project from the public XLX dashboard/support page;
- [ ] periodically review dependencies and upstream projects.
