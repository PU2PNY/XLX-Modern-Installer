# 🌐 XLX Modern Installer — Instale, Atualize e Recupere um Refletor XLX no Debian 12

<div align="center">

![Debian 12](https://img.shields.io/badge/Debian-12-red?logo=debian&logoColor=white)
![Architecture](https://img.shields.io/badge/Arquitetura-x86__64-blue)
![XLX](https://img.shields.io/badge/XLX-D--STAR%20%7C%20DMR%20%7C%20C4FM%2FYSF-00c8ff)
![Dashboard](https://img.shields.io/badge/Dashboard-Modern-success)
![Languages](https://img.shields.io/badge/Painel-6%20idiomas-blueviolet)
![License](https://img.shields.io/badge/Projeto-MIT-yellow)

**Instalador e kit de manutenção para refletores XLX em Debian 12, com pré-validação, backup, dashboard moderno, documentação bilíngue, internacionalização, diagnóstico e recuperação.**

D-STAR • DMR • C4FM/YSF • XLX Echo • Dashboard moderno • Debian 12

🇧🇷 **Português** | 🇺🇸 [English](README.en.md) | 📚 [Documentação](docs/README.md)

[Instalação](#-instalação-rápida) • [O que você quer fazer?](#-o-que-você-quer-fazer) • [Painel](#-dashboard-moderno) • [Idiomas](#-idiomas-do-dashboard) • [Firewall](#-firewall-e-portas) • [Recuperação](#-backup-diagnóstico-e-recuperação) • [Créditos](#-créditos-e-projetos-relacionados)

</div>

---

## 🖥️ Dashboard real

A imagem abaixo é uma captura real do **XLX Modern Dashboard** em funcionamento. Ela mostra o cabeçalho multiprotocolo, histórico de transmissões, monitor ao vivo/standby, estado operacional do servidor, estações conectadas e o bloco de clima e condições de propagação para radioamadores.

<p align="center">
  <img src="docs/images/xlx-modern-dashboard.webp" alt="XLX Modern Dashboard real mostrando D-STAR, DMR, C4FM/YSF, últimas transmissões, monitor ao vivo, estações conectadas, clima e condições de propagação" width="900">
</p>

> A aparência e os dados exibidos dependem da configuração do refletor. A imagem demonstra uma instalação real do painel, não um mockup.

---

## 📖 O que é o XLX Modern Installer?

O **XLX Modern Installer** foi criado para facilitar a instalação, atualização, manutenção e recuperação de um **refletor XLX multiprotocolo** em Debian 12, com foco em segurança operacional e documentação reutilizável.

O projeto usa como base técnica revisada o instalador de **Daniel K. — PP5PK** e acrescenta uma camada própria de validação, backup, dashboard moderno, documentação, internacionalização e procedimentos de manutenção.

Ele foi estruturado para responder de forma prática a pesquisas como:

- como instalar XLX no Debian 12;
- como instalar XLXD em uma VPS;
- como criar um refletor D-STAR, DMR e C4FM/YSF;
- como instalar ou reinstalar somente o dashboard XLX;
- como escolher o idioma do painel XLX;
- como atualizar um servidor XLX;
- como recuperar XLXD que não inicia;
- quais portas abrir no firewall para XLX;
- onde ficam os arquivos e logs do XLX;
- como configurar HTTPS e tarefas pós-instalação.

> **Princípio operacional:** diagnosticar antes de alterar, criar backup antes de mudanças e manter rollback disponível.

---

## ✨ Recursos principais

| Recurso | Situação | Descrição |
|---|:---:|---|
| 🆕 Nova instalação XLX + painel | ✅ | Instala o núcleo XLX e depois o dashboard moderno |
| 🔎 Pré-validação / dry-run | ✅ | Valida Debian, arquitetura, recursos, rede e instalação existente |
| 🖥️ Instalação somente do painel | ✅ | Instala ou reinstala o dashboard separadamente |
| 🌍 Painel em 6 idiomas | ✅ | `pt-BR`, `en`, `es`, `fr`, `de`, `it`, escolhidos durante a instalação |
| 💾 Backup preventivo | ✅ | Protege arquivos existentes antes de alterações reais |
| 🧾 Logs de instalação | ✅ | Mantém registro da execução para diagnóstico |
| 🛡️ Proteção de produção | ✅ | Bloqueia instalação completa sobre XLXD ativo |
| 📡 D-STAR / DMR / C4FM-YSF | ✅ | Base multiprotocolo XLX |
| 🔊 XLX Echo | ✅ | Suporte ao serviço opcional quando instalado |
| 🔄 Atualização via Git | ✅ | Atualização controlada do código do projeto |
| 🔐 CI e verificação básica de segredos | ✅ | Valida Shell, PHP, traduções e padrões comuns de chaves/tokens |
| 🧰 Reinstalação automática somente do núcleo | 🚧 | Ainda exige fluxo dedicado; não é feita por `install.sh` sobre produção |

---

# 🚀 Instalação rápida

Use uma VPS/servidor limpo com **Debian 12 x86_64**.

### 1. Instale Git

```bash
sudo apt update
sudo apt install -y git
```

### 2. Clone o projeto

```bash
cd /usr/src
sudo git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
```

### 3. Faça a pré-validação

```bash
sudo bash install.sh --check
```

O modo `--check` verifica o ambiente sem executar a instalação real.

### 4. Instale

```bash
sudo bash install.sh
```

O instalador cria backup preventivo e exige confirmação antes da alteração real.

### Instalar já definindo o idioma do painel

```bash
sudo bash install.sh --lang=en
```

Códigos disponíveis:

```text
pt-BR  en  es  fr  de  it
```

---

# 🧭 O que você quer fazer?

| Objetivo | Comando / documentação |
|---|---|
| Verificar se o servidor está pronto para instalar | `sudo bash install.sh --check` |
| Nova instalação completa | `sudo bash install.sh` |
| Nova instalação com dashboard em Inglês | `sudo bash install.sh --lang=en` |
| Instalar/reinstalar somente o dashboard | `sudo bash modules/60-dashboard-modern.sh` |
| Instalar somente o dashboard em Espanhol | `sudo bash modules/60-dashboard-modern.sh --lang=es` |
| Atualizar os arquivos do projeto | `git pull --ff-only` e depois `sudo bash install.sh --check` |
| Diagnosticar/recuperar XLX | [Guia de atualização e recuperação](docs/ATUALIZAR-RECUPERAR-XLX.pt-BR.md) |
| Conferir firewall e portas | [Firewall e portas do XLX](docs/FIREWALL-PORTAS-XLX.pt-BR.md) |
| Localizar arquivos e logs | [Arquivos e logs do XLX](docs/ARQUIVOS-LOGS-XLX.pt-BR.md) |
| HTTPS, YSF e pós-instalação | [Guia pós-instalação](docs/POS-INSTALACAO-XLX.pt-BR.md) |
| Entender o sistema de idiomas | [Internacionalização](docs/INTERNATIONALIZATION.md) |

---

# 🖥️ Dashboard moderno

Se o XLXD já funciona e você deseja instalar ou reinstalar **somente o painel**:

```bash
cd /usr/src/XLX-Modern-Installer
sudo bash modules/60-dashboard-modern.sh
```

O instalador do dashboard é separado do núcleo. Quando encontra um painel existente no destino, cria backup antes de copiar a nova versão.

Durante a instalação são solicitados dados como:

- identificação do refletor;
- nome exibido;
- descrição curta;
- indicativo do responsável;
- cidade/região;
- país;
- domínio;
- e-mail de contato;
- idioma do dashboard.

## 🌍 Idiomas do dashboard

O instalador oferece:

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
sudo bash modules/60-dashboard-modern.sh --lang=fr
```

A tradução é aplicada à cópia instalada do dashboard, incluindo as principais áreas visíveis e metadados de idioma/SEO. O projeto mantém uma única base de código e catálogos separados de tradução.

> A troca de idioma por visitante, sem reinstalação, é uma evolução futura. Hoje o idioma padrão é selecionado na instalação.

Mais detalhes: [docs/INTERNATIONALIZATION.md](docs/INTERNATIONALIZATION.md).

---

# 🔥 Firewall e portas

Não existe uma lista universal de portas que todo refletor precise abrir. Utilize apenas os protocolos e serviços realmente habilitados.

Exemplos comuns incluem HTTP/HTTPS, DPlus, DExtra, DCS, DMR/MMDVM, YSF, XLX interlink e serviços opcionais.

Confira primeiro o servidor:

```bash
sudo ss -lntup
sudo ufw status verbose
```

Tabela detalhada, NAT e exemplos de diagnóstico:

**[📘 Firewall e portas do XLX](docs/FIREWALL-PORTAS-XLX.pt-BR.md)**

---

# 📂 Arquivos e logs

Alguns dos caminhos mais importantes são:

```text
/xlxd/
/xlxd/users_db/
/xlxd/callinghome.php
/xlxd/xlxd.whitelist
/xlxd/xlxd.blacklist
/xlxd/xlxd.interlink
/xlxd/xlxd.terminal
/etc/systemd/system/xlxd.service
/etc/systemd/system/xlxecho.service
/etc/apache2/
/var/www/html/
/usr/src/XLX-Modern-Installer/
/var/backups/xlx-reflector/
/var/log/xlx-reflector/installer/
```

Guia completo: **[Onde ficam os arquivos e logs do XLX](docs/ARQUIVOS-LOGS-XLX.pt-BR.md)**.

---

# 🔄 Atualização

Para atualizar somente o repositório local:

```bash
cd /usr/src/XLX-Modern-Installer
git status
git pull --ff-only
sudo bash install.sh --check
```

> **Não execute `install.sh` novamente sobre um XLXD em produção apenas porque o Git foi atualizado.** O instalador bloqueia propositalmente a sobrescrita de uma instalação ativa.

Para atualizar/reinstalar somente o dashboard:

```bash
sudo bash modules/60-dashboard-modern.sh
```

---

# 💾 Backup, diagnóstico e recuperação

Antes de corrigir um servidor existente, preserve pelo menos os arquivos realmente existentes entre:

```text
/xlxd/
/xlxd/users_db/
/xlxd/callinghome.php
/xlxd/xlxd.whitelist
/xlxd/xlxd.blacklist
/xlxd/xlxd.interlink
/xlxd/xlxd.terminal
/etc/systemd/system/xlxd.service
/etc/systemd/system/xlxecho.service
/etc/apache2/
/var/www/html/
```

Fluxo recomendado:

```text
DIAGNÓSTICO → INVENTÁRIO → BACKUP VERIFICADO → ALTERAÇÃO MÍNIMA → VALIDAÇÃO → ROLLBACK
```

Comandos úteis:

```bash
sudo systemctl status xlxd.service --no-pager
sudo journalctl -u xlxd.service -n 100 --no-pager
sudo systemctl cat xlxd.service
sudo apache2ctl configtest
sudo ss -lntup
ps aux | grep '[x]lxd'
```

Guia completo: **[Atualizar, diagnosticar e recuperar XLX](docs/ATUALIZAR-RECUPERAR-XLX.pt-BR.md)**.

---

# 🎯 Pós-instalação e etapas opcionais

Dependendo da arquitetura, você poderá precisar de tarefas adicionais:

- registro/publicação de serviço YSF compatível — [DVRef](https://dvref.com/);
- HTTPS manual — [Certbot](https://certbot.eff.org/);
- teste de áudio / echo — [narspt/XLXEcho](https://github.com/narspt/XLXEcho);
- validação de DNS, Apache e firewall;
- backup pós-instalação validado;
- documentação local dos módulos, protocolos e portas utilizadas.

Veja **[Pós-instalação do XLX](docs/POS-INSTALACAO-XLX.pt-BR.md)**.

---

# 🧪 Qualidade e validação

O repositório inclui GitHub Actions para verificar:

- sintaxe de scripts Bash;
- sintaxe dos arquivos PHP do dashboard;
- paridade das chaves dos seis catálogos de tradução;
- geração de uma cópia do dashboard para cada idioma;
- padrões comuns de chaves privadas e tokens.

A validação automatizada complementa, mas não substitui, testes reais em uma VPS de homologação antes de mudanças importantes em produção.

---

# 🧱 Estrutura do projeto

```text
XLX-Modern-Installer/
├── install.sh
├── LICENSE
├── SECURITY.md
├── CONTRIBUTING.md
├── THIRD_PARTY_NOTICES.md
├── README.md
├── README.en.md
├── dashboard/
│   ├── i18n/
│   │   ├── bootstrap.php
│   │   ├── build.php
│   │   └── locales/
│   └── install/
├── docs/
│   └── images/
├── modules/
├── scripts/
├── references/
├── tests/
└── .github/workflows/
```

---

# 🔗 Créditos e projetos relacionados

| Projeto / recurso | Relação com este projeto |
|---|---|
| [LX3JL/xlxd](https://github.com/LX3JL/xlxd) | Núcleo/refletor XLXD e referência upstream de protocolos |
| [PP5PK/XLX_Installer](https://github.com/PP5PK/XLX_Installer) | Base técnica revisada utilizada pelo instalador controlado |
| [narspt/XLXEcho](https://github.com/narspt/XLXEcho) | Serviço relacionado para echo/parrot |
| [Certbot](https://certbot.eff.org/) | Referência oficial para certificados HTTPS |
| [DVRef](https://dvref.com/) | Diretório/serviço relacionado a publicação de refletores compatíveis |
| **Dario — PU2PNY** | Manutenção desta versão, documentação, camada de segurança e dashboard moderno |

Consulte também **[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)**.

---

# 📄 Licença

As partes originais deste repositório estão disponibilizadas sob **MIT License**. Componentes, projetos e código de terceiros continuam sujeitos às suas respectivas licenças — por exemplo, o projeto XLXD upstream mantém sua própria licença.

Leia **[LICENSE](LICENSE)** e **[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)** antes de redistribuir componentes de terceiros.

---

# 🔐 Segurança e contribuições

- [Política de Segurança](SECURITY.md)
- [Como contribuir](CONTRIBUTING.md)

Nunca publique senhas, tokens, chaves privadas, bancos reais de usuários ou backups de produção em issues, commits ou logs públicos.

---

# ❓ Perguntas frequentes

### Como instalar XLX no Debian 12?

Clone este repositório, execute `sudo bash install.sh --check` e, se a validação for aprovada, `sudo bash install.sh`.

### Posso instalar somente o dashboard?

Sim:

```bash
sudo bash modules/60-dashboard-modern.sh
```

### Posso escolher o idioma do painel?

Sim. Escolha no menu do instalador ou utilize, por exemplo:

```bash
sudo bash modules/60-dashboard-modern.sh --lang=en
```

### Posso executar `install.sh` por cima de um servidor XLXD funcionando?

Não. Essa situação é bloqueada propositalmente para evitar sobrescrita de produção.

### Onde encontro documentação de firewall, arquivos e recuperação?

No índice **[docs/README.md](docs/README.md)**.

---

## 🔎 Termos relacionados

XLX reflector installer, instalar refletor XLX, instalar XLXD Debian 12, servidor D-STAR, servidor DMR, servidor C4FM YSF, painel XLX, XLX dashboard, firewall XLX, portas XLXD, atualizar XLX, recuperar XLXD, backup XLX, reflector amateur radio, ham radio digital reflector.

---

<div align="center">

**XLX Modern Installer — instalação documentada, manutenção controlada e dashboard moderno para a comunidade radioamadora.**

🇺🇸 [Read the complete English version](README.en.md)

</div>
