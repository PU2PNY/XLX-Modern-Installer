# 🌐 XLX Modern Installer — Instalar, Atualizar e Recuperar Refletores XLX no Debian 12

<div align="center">

![Debian 12](https://img.shields.io/badge/Debian-12-red?logo=debian&logoColor=white)
![Architecture](https://img.shields.io/badge/Arquitetura-x86__64-blue)
![XLX](https://img.shields.io/badge/XLX-D--STAR%20%7C%20DMR%20%7C%20C4FM%2FYSF-00c8ff)
![Dashboard](https://img.shields.io/badge/Dashboard-Modern-success)
![License](https://img.shields.io/badge/License-MIT-yellow)
![Maintenance](https://img.shields.io/badge/Manuten%C3%A7%C3%A3o-Backup%20%7C%20Diagn%C3%B3stico%20%7C%20Rollback-brightgreen)

**Instalador e kit de manutenção para refletores XLX em Debian 12, com instalação controlada, dashboard moderno, backup preventivo, diagnóstico, recuperação e documentação bilíngue.**

D-STAR • DMR • C4FM/YSF • XLX Echo • Dashboard moderno • Debian 12

🇧🇷 **Português** | 🇺🇸 [English documentation](README.en.md)

[Instalação](#-instalação-rápida) • [Modos de uso](#-modos-de-instalação-e-manutenção) • [Firewall](#-firewall-e-portas) • [Arquivos](#-localização-dos-arquivos) • [Atualização](#-atualização) • [Recuperação](#-backup-diagnóstico-e-recuperação) • [Idiomas](#-painel-universal-e-idiomas) • [Créditos](#-créditos-e-projetos-relacionados) • [Licença](#-licença)

</div>

---

## 📖 Sobre o projeto

O **XLX Modern Installer** foi criado para facilitar a instalação, atualização, manutenção e recuperação de um **refletor XLX multiprotocolo** em Debian 12, preservando uma regra essencial: **diagnosticar antes de alterar e manter rollback disponível**.

O projeto utiliza como base técnica revisada o instalador de **Daniel K. — PP5PK** e integra uma camada própria de segurança operacional, documentação, dashboard moderno e procedimentos de manutenção.

Este repositório foi organizado para responder diretamente a pesquisas como:

- como instalar XLX no Debian 12;
- como instalar XLXD em uma VPS;
- como criar um refletor D-STAR, DMR e C4FM/YSF;
- como instalar somente o dashboard XLX;
- como atualizar um servidor XLX;
- como recuperar XLXD que não inicia;
- quais portas abrir no firewall para XLX;
- onde ficam os arquivos e logs do XLX;
- como fazer backup e rollback de um refletor XLX.

> **Objetivo:** permitir que um radioamador consiga instalar, manter e recuperar um refletor XLX com procedimentos claros, reproduzíveis e documentados.

---

## ✨ Recursos principais

| Recurso | Situação | Descrição |
|---|---:|---|
| 🆕 Nova instalação completa | ✅ | Instala o núcleo XLX e o dashboard moderno |
| 🔎 Pré-validação / dry-run | ✅ | Verifica Debian, arquitetura, recursos, rede e instalação existente |
| 🖥️ Instalação somente do painel | ✅ | Instala ou reinstala apenas o dashboard |
| 💾 Backup preventivo | ✅ | Cria backup antes de alterações reais |
| 🧾 Logs de instalação | ✅ | Mantém registro para diagnóstico posterior |
| 🛡️ Proteção contra sobrescrita | ✅ | Interrompe se detectar XLXD ativo |
| 🔄 Atualização via Git | ✅ | Atualização controlada do repositório |
| 📡 D-STAR / DMR / C4FM-YSF | ✅ | Base multiprotocolo XLX |
| 🔊 XLX Echo | ✅ | Serviço opcional de teste/eco |
| 🌍 Documentação PT/EN | ✅ | Documentação principal em dois idiomas |
| 🌐 Dashboard multilíngue | 🚧 | Arquitetura de internacionalização em desenvolvimento |
| 🧰 Reinstalação somente do núcleo | 🚧 | Exige rotina dedicada de recuperação |

---

## 📋 Requisitos

Ambiente recomendado:

- Debian 12;
- arquitetura x86_64;
- acesso root ou sudo;
- IP público fixo para produção;
- DNS/FQDN apontando para o servidor;
- acesso HTTPS ao GitHub;
- pelo menos 768 MB de RAM;
- pelo menos 4 GB livres em disco;
- capacidade de administrar firewall/NAT quando necessário.

---

# 🚀 Instalação rápida

## 1. Atualize o sistema e instale Git

```bash
sudo apt update
sudo apt install -y git
```

## 2. Clone o repositório

```bash
cd /usr/src
sudo git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
```

## 3. Execute primeiro a pré-validação

```bash
sudo bash install.sh --check
```

O modo `--check` valida o ambiente **sem executar a instalação real**.

## 4. Inicie a instalação completa

```bash
sudo bash install.sh
```

Antes da alteração real, o instalador cria backup preventivo e exige confirmação explícita.

---

# 🧭 Modos de instalação e manutenção

## 🆕 Nova instalação — XLXD + dashboard

Use em VPS/servidor limpo:

```bash
cd /usr/src/XLX-Modern-Installer
sudo bash install.sh --check
sudo bash install.sh
```

Fluxo esperado:

```text
VALIDAÇÃO → INVENTÁRIO → BACKUP → XLXD → SYSTEMD → DASHBOARD → APACHE/HTTPS → TESTES
```

## 🖥️ Instalar ou reinstalar somente o dashboard

Se o XLXD já está operacional e você precisa mexer apenas no painel:

```bash
cd /usr/src/XLX-Modern-Installer
sudo bash modules/60-dashboard-modern.sh
```

O módulo do dashboard é separado do núcleo e cria backup quando encontra um painel existente no destino.

## 📡 Reinstalar somente o núcleo XLXD

O `install.sh` de nova instalação **não deve sobrescrever um XLXD em produção**. Essa proteção existe para preservar:

- identidade do refletor;
- whitelist e blacklist;
- interlinks;
- bancos de usuários;
- Calling Home;
- serviços systemd;
- Apache;
- dashboard;
- configurações locais.

A rotina correta deve seguir:

```text
DIAGNÓSTICO → BACKUP VERIFICADO → RECONSTRUÇÃO DO NÚCLEO → VALIDAÇÃO → ROLLBACK DISPONÍVEL
```

---

# 🔥 Firewall e portas

As portas realmente necessárias dependem dos protocolos e serviços habilitados. **Não abra portas que você não utiliza.** Em ambientes com NAT, além do firewall local pode ser necessário encaminhamento no roteador/provedor.

| Porta | Transporte | Uso típico |
|---:|:---:|---|
| 22 | TCP | SSH administrativo |
| 80 | TCP | HTTP / emissão ou renovação de certificado |
| 443 | TCP | HTTPS do dashboard |
| 8080 | TCP | RepNet, quando utilizado |
| 20001-20005 | TCP/UDP | DPlus, conforme a configuração utilizada |
| 40001 | TCP | Icom G3, quando aplicável |
| 8880 | UDP | DMR+ DMO |
| 10001 | UDP | Interface JSON do núcleo XLX |
| 10002 | UDP | XLX interlink |
| 10100 | UDP | Controlador AMBE |
| 10101-10199 | UDP | Transcodificação AMBE |
| 12345-12346 | UDP | Icom Terminal presence/request |
| 21110 | UDP | Yaesu IMRS |
| 30001 | UDP | DExtra |
| 30051 | UDP | DCS |
| 40000 | UDP | Icom Terminal DV |
| 42000 | UDP | YSF, valor comum/configurável |
| 62030 | UDP | MMDVM/DMR |

### Conferir portas atualmente em escuta

```bash
sudo ss -lntup
```

### Exemplo com UFW

Antes de aplicar regras, confirme as portas usadas no seu ambiente.

```bash
sudo ufw status verbose
```

> O instalador e a documentação priorizam **menor exposição necessária**. Abra somente os serviços que seu refletor realmente oferece.

Referência upstream de protocolos/portas: [LX3JL/xlxd](https://github.com/LX3JL/xlxd).

---

# 📂 Localização dos arquivos

Os caminhos abaixo ajudam em manutenção, backup e recuperação. Alguns componentes opcionais só existirão quando instalados.

| Finalidade | Caminho |
|---|---|
| Núcleo XLXD | `/xlxd/` |
| Banco/arquivos de usuários | `/xlxd/users_db/` |
| Calling Home | `/xlxd/callinghome.php` |
| Whitelist | `/xlxd/xlxd.whitelist` |
| Blacklist | `/xlxd/xlxd.blacklist` |
| Interlinks | `/xlxd/xlxd.interlink` |
| Terminais | `/xlxd/xlxd.terminal` |
| Repositório local deste projeto | `/usr/src/XLX-Modern-Installer/` |
| Área controlada do wrapper | `/opt/xlx-modern-installer/` |
| Dashboard moderno | `/var/www/html/xlx-dashboard/` |
| Conteúdo web geral | `/var/www/html/` |
| Serviço XLXD | `/etc/systemd/system/xlxd.service` |
| Serviço XLXEcho | `/etc/systemd/system/xlxecho.service` |
| Apache | `/etc/apache2/` |
| Backups preventivos | `/var/backups/xlx-reflector/` |
| Logs do instalador | `/var/log/xlx-reflector/installer/` |
| Logs XLX | `/var/log/xlx*` e arquivos definidos pelo ambiente |

### Descobrir rapidamente arquivos relacionados ao XLX

```bash
sudo find /xlxd /usr/src /var/www/html /etc/systemd/system -maxdepth 3 \
  \( -iname '*xlx*' -o -iname '*dstar*' \) -print 2>/dev/null
```

---

# 🔄 Atualização

## Atualizar somente os arquivos do projeto

```bash
cd /usr/src/XLX-Modern-Installer
git status
git pull --ff-only
sudo bash install.sh --check
```

> Atualizar o Git **não significa** que você deve executar uma nova instalação completa sobre um XLXD em produção.

## Atualizar/reinstalar somente o dashboard

```bash
sudo bash modules/60-dashboard-modern.sh
```

---

# 💾 Backup, diagnóstico e recuperação

## Caminhos mínimos que merecem preservação

```text
/xlxd/
/xlxd/users_db/
/xlxd/callinghome.php
/xlxd/xlxd.blacklist
/xlxd/xlxd.whitelist
/xlxd/xlxd.interlink
/xlxd/xlxd.terminal
/etc/systemd/system/xlxd.service
/etc/systemd/system/xlxecho.service
/etc/apache2/
/var/www/html/
```

## Sequência recomendada

```text
1. DIAGNOSTICAR
2. INVENTARIAR
3. CRIAR BACKUP E VALIDAR O BACKUP
4. IDENTIFICAR A CAUSA
5. FAZER A MENOR ALTERAÇÃO POSSÍVEL
6. VALIDAR OS SERVIÇOS
7. VALIDAR O DASHBOARD
8. MANTER ROLLBACK DISPONÍVEL
```

## Comandos úteis

```bash
sudo systemctl status xlxd.service --no-pager
sudo journalctl -u xlxd.service -n 100 --no-pager
sudo journalctl -u xlxd.service -f
sudo systemctl cat xlxd.service
sudo apache2ctl configtest
sudo ss -lntup
ps aux | grep '[x]lxd'
```

---

# 🎯 Etapas opcionais depois da instalação

Estas etapas não são obrigatórias para todo refletor. Use apenas quando fizerem sentido para sua arquitetura.

## 📡 Publicação/registro YSF

Se você deseja divulgar um serviço YSF compatível com a forma como seu refletor foi configurado, consulte:

- [DVRef — diretório e registro de refletores](https://dvref.com/)

> O XLX também pode atuar como YSF Master com sua própria arquitetura de salas. Confirme se o tipo de registro é aplicável antes de publicar.

## 🔒 Configuração manual de HTTPS

Se o HTTPS não foi configurado automaticamente:

1. confirme que o DNS aponta para o servidor;
2. confirme TCP 80 e 443 no firewall/NAT;
3. valide o Apache;
4. utilize o assistente oficial do [Certbot](https://certbot.eff.org/).

Antes:

```bash
sudo apache2ctl configtest
sudo ss -lntp | grep -E ':(80|443)\b'
```

## 🔊 XLX Echo / Parrot

Para ambientes que utilizem teste de áudio, consulte o projeto relacionado:

- [narspt/XLXEcho](https://github.com/narspt/XLXEcho)

---

# 🌐 Painel universal e idiomas

O projeto está preparando uma arquitetura de internacionalização para que o dashboard possa ser instalado com idioma padrão e, posteriormente, permitir troca pelo visitante.

Idiomas prioritários:

- 🇧🇷 Português (Brasil)
- 🇺🇸 English
- 🇪🇸 Español
- 🇫🇷 Français
- 🇩🇪 Deutsch
- 🇮🇹 Italiano

A proposta é que o instalador ofereça uma escolha como:

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

A implementação será baseada em **chaves de tradução**, sem manter seis cópias diferentes do dashboard.

Arquitetura completa: **[docs/INTERNATIONALIZATION.md](docs/INTERNATIONALIZATION.md)**.

---

# 🧱 Estrutura do projeto

```text
XLX-Modern-Installer/
├── install.sh
├── LICENSE
├── THIRD_PARTY_NOTICES.md
├── README.md
├── README.en.md
├── config/
├── dashboard/
│   └── install/
│       └── install-dashboard.sh
├── docs/
├── modules/
│   └── 60-dashboard-modern.sh
├── references/
├── scripts/
└── tests/
```

---

# 🔗 Créditos e projetos relacionados

Este projeto não tenta esconder sua origem técnica. Cada componente upstream mantém seu crédito e sua licença.

| Projeto / serviço | Autor / organização | Relação |
|---|---|---|
| [XLX / XLXD](https://github.com/LX3JL/xlxd) | LX3JL / LX1IQ e colaboradores | Núcleo multiprotocolo upstream |
| [PP5PK/XLX_Installer](https://github.com/PP5PK/XLX_Installer) | Daniel K. — PP5PK | Base técnica revisada do instalador |
| [XLXEcho](https://github.com/narspt/XLXEcho) | narspt | Serviço opcional de eco/parrot |
| [Certbot](https://certbot.eff.org/) | EFF / comunidade Certbot | HTTPS/SSL |
| [DVRef](https://dvref.com/) | comunidade de rádio digital | Referência de registro/diretório YSF |
| [XLX Modern Installer](https://github.com/PU2PNY/XLX-Modern-Installer) | Dario — PU2PNY | Integração, segurança operacional, documentação e dashboard moderno |

Avisos detalhados: **[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)**.

---

# 📄 Licença

Os **componentes originais deste repositório** são disponibilizados sob **Licença MIT**, permitindo uso, estudo, modificação e redistribuição conforme os termos da licença.

Leia: **[LICENSE](LICENSE)**.

⚠️ **Importante:** componentes de terceiros mantêm suas próprias licenças. O XLXD upstream, por exemplo, é publicado sob GPL. A licença MIT deste projeto não substitui licenças upstream.

Consulte também **[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)**.

---

# ❓ Perguntas frequentes

## Como instalar XLX no Debian 12?

```bash
sudo apt update && sudo apt install -y git
cd /usr/src
sudo git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
sudo bash install.sh --check
sudo bash install.sh
```

## Como instalar somente o painel?

```bash
cd /usr/src/XLX-Modern-Installer
sudo bash modules/60-dashboard-modern.sh
```

## Posso rodar `install.sh` por cima de um XLXD funcionando?

Não. A proteção contra sobrescrita é proposital.

## Onde vejo as portas necessárias?

Na seção **Firewall e portas** deste README e na documentação upstream do XLXD.

## Onde ficam os arquivos mais importantes?

Veja **Localização dos arquivos** nesta página.

## O dashboard terá vários idiomas?

Sim. A arquitetura multilíngue está documentada e será implementada por chaves de tradução, com idioma padrão escolhido na instalação e possibilidade de seleção pelo visitante.

---

# 🔎 Termos relacionados

XLX reflector installer, instalar XLX Debian 12, instalar XLXD VPS, servidor D-STAR, servidor DMR, C4FM YSF reflector, XLX dashboard, firewall XLX ports, portas XLXD, atualizar XLX reflector, recuperar XLXD, reinstall XLX dashboard, amateur radio reflector, ham radio digital voice server.

---

## 🇺🇸 English

Complete English version: **[README.en.md](README.en.md)**.
