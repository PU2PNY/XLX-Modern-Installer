# 🧪 XLX Modern Installer — Public Beta Testing / Teste Beta Público

> **Status:** public beta candidate. The codebase has automated syntax, i18n and publication audits, but still needs independent clean-server validation before a stable `v1.0.0` release.
>
> **Status:** candidato a beta público. O código já possui auditorias automáticas de sintaxe, internacionalização e publicação, mas ainda precisa de validação independente em servidor limpo antes da versão estável `v1.0.0`.

---

## 🇧🇷 Como testar

Use **somente uma VPS Debian 12 descartável ou de laboratório**. Não execute sobre um refletor XLX em produção.

### 1. Requisitos mínimos

- Debian 12 x86_64 limpo;
- acesso root/sudo;
- pelo menos 768 MB de RAM;
- pelo menos 4 GB livres;
- acesso HTTPS ao GitHub;
- IP público e DNS somente se quiser testar HTTPS/serviços externos.

### 2. Clone

```bash
sudo apt update
sudo apt install -y git
cd /usr/src
sudo git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
```

### 3. Rode primeiro a pré-validação

```bash
sudo bash install.sh --check
```

Esperado: diagnóstico aprovado e **nenhuma instalação executada**.

### 4. Teste a instalação completa

Português:

```bash
sudo bash install.sh --lang=pt-BR
```

English:

```bash
sudo bash install.sh --lang=en
```

Español:

```bash
sudo bash install.sh --lang=es
```

Também são aceitos `fr`, `de` e `it`.

### 5. Teste somente o dashboard

```bash
sudo bash modules/60-dashboard-modern.sh --lang=en
```

O instalador deve permitir instalar/reinstalar apenas o painel sem reinstalar o núcleo XLXD.

### 6. Verificações pós-instalação

```bash
sudo systemctl status xlxd.service --no-pager
sudo systemctl status apache2 --no-pager
sudo apache2ctl configtest
sudo ss -lntup
sudo bash scripts/health-check.sh
```

Confirme também:

- dashboard abre no navegador;
- idioma selecionado está correto;
- menu, monitor ao vivo, tabelas, ranking e páginas estão legíveis;
- nome do refletor informado na instalação aparece no lugar dos exemplos;
- não aparecem placeholders `{{...}}`;
- backup foi criado quando aplicável;
- uma instalação XLXD existente não é sobrescrita silenciosamente.

### 7. O que NÃO fazer

- não testar em produção sem backup externo;
- não publicar senhas, tokens, bancos ou logs com dados pessoais em Issues;
- não abrir portas desnecessárias apenas para completar o teste;
- não usar `--force-clean` sem entender os vestígios encontrados.

### 8. Como reportar

Abra uma **Issue** no repositório e informe:

- versão Debian;
- arquitetura;
- idioma escolhido;
- etapa onde ocorreu o problema;
- saída de `sudo bash install.sh --check`;
- saída relevante do instalador;
- `systemctl status xlxd.service --no-pager`;
- `apache2ctl configtest`;
- print do dashboard, se o problema for visual.

**Remova IPs privados, e-mails pessoais, tokens, senhas e qualquer segredo antes de publicar logs.**

---

## 🇺🇸 How to test

Use **only a disposable/lab Debian 12 VPS**. Do not run the beta installer on a production XLX reflector.

### 1. Minimum requirements

- clean Debian 12 x86_64;
- root/sudo access;
- at least 768 MB RAM;
- at least 4 GB free disk space;
- HTTPS access to GitHub;
- public IP and DNS only if testing HTTPS/external services.

### 2. Clone

```bash
sudo apt update
sudo apt install -y git
cd /usr/src
sudo git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
```

### 3. Run validation first

```bash
sudo bash install.sh --check
```

Expected result: validation passes and **no installation is performed**.

### 4. Test the full installation

```bash
sudo bash install.sh --lang=en
```

Other supported dashboard languages: `pt-BR`, `es`, `fr`, `de`, `it`.

### 5. Test dashboard-only installation

```bash
sudo bash modules/60-dashboard-modern.sh --lang=en
```

### 6. Post-install checks

```bash
sudo systemctl status xlxd.service --no-pager
sudo systemctl status apache2 --no-pager
sudo apache2ctl configtest
sudo ss -lntup
sudo bash scripts/health-check.sh
```

Verify:

- dashboard loads;
- selected language is applied;
- navigation, live monitor, tables, ranking and pages are readable;
- the reflector name supplied during installation replaces examples;
- no `{{...}}` placeholders remain;
- backup is created when applicable;
- an existing XLXD production installation is not silently overwritten.

### 7. Reporting issues

Open a GitHub Issue and include:

- Debian version;
- architecture;
- selected language;
- failing step;
- relevant installer output;
- `systemctl status xlxd.service --no-pager`;
- `apache2ctl configtest`;
- dashboard screenshot for visual issues.

**Remove passwords, tokens, private keys, private user data and other secrets before posting logs.**

---

## ✅ Beta exit criteria / Critérios para sair do beta

The project can be promoted to stable `v1.0.0` after independent testers confirm:

- clean Debian 12 installation succeeds;
- XLXD starts and stays active;
- dashboard loads correctly;
- dashboard-only install works;
- at least Portuguese, English and Spanish are visually reviewed end-to-end;
- backup/rollback paths are validated;
- production overwrite protection is confirmed;
- no critical security or data-loss issue remains open.

Quando esses critérios forem confirmados por testes independentes, o projeto poderá avançar de **beta público** para **v1.0.0 estável**.
