# 🌐 XLX Modern Installer — Instalar, Atualizar e Recuperar Refletores XLX no Debian 12

<div align="center">

![Debian 12](https://img.shields.io/badge/Debian-12-red?logo=debian&logoColor=white)
![Architecture](https://img.shields.io/badge/Arquitetura-x86__64-blue)
![XLX](https://img.shields.io/badge/XLX-D--STAR%20%7C%20DMR%20%7C%20C4FM%2FYSF-00c8ff)
![Dashboard](https://img.shields.io/badge/Dashboard-Modern-success)
![Maintenance](https://img.shields.io/badge/Manuten%C3%A7%C3%A3o-Backup%20%7C%20Diagn%C3%B3stico%20%7C%20Rollback-brightgreen)

**Instalador e kit de manutenção para refletores XLX em Debian 12, com instalação controlada, dashboard moderno, backup preventivo, diagnóstico e recuperação.**

D-STAR • DMR • C4FM/YSF • XLX Echo • Dashboard moderno • Debian 12

🇧🇷 **Português** | 🇺🇸 [English documentation](README.en.md)

[Instalação rápida](#-como-instalar-um-refletor-xlx-no-debian-12) • [Modos de instalação](#-modos-de-instalação-e-manutenção) • [Atualização](#-como-atualizar-o-xlx-modern-installer) • [Dashboard](#-instalar-ou-reinstalar-somente-o-dashboard) • [Backups](#-backup-e-rollback) • [Diagnóstico](#-diagnóstico-e-correção) • [FAQ](#-perguntas-frequentes)

</div>

---

## 📖 O que é o XLX Modern Installer?

O **XLX Modern Installer** foi criado para facilitar a instalação, atualização, manutenção e recuperação de um **refletor XLX multiprotocolo** em servidores Debian 12.

O projeto utiliza como base técnica o instalador de **Daniel K. — PP5PK** e adiciona uma camada de segurança operacional com pré-validação, backup preventivo, logs, separação entre núcleo e dashboard e procedimentos documentados de manutenção.

Este repositório é útil para quem procura por:

- como instalar um refletor XLX no Debian 12;
- como instalar XLXD em uma VPS;
- como configurar um servidor D-STAR, DMR e C4FM/YSF;
- como instalar ou reinstalar somente o painel XLX;
- como atualizar um servidor XLX;
- como diagnosticar um refletor XLX que não inicia;
- como fazer backup e rollback de uma instalação XLX;
- como recuperar um servidor XLXD existente sem sobrescrever produção por engano.

> **Princípio principal:** diagnosticar antes de alterar e nunca sobrescrever uma instalação XLX ativa sem backup e procedimento de recuperação.

---

## ✨ Recursos principais

| Recurso | Situação | Descrição |
|---|---:|---|
| 🆕 Nova instalação completa | ✅ | Instala o núcleo XLX e depois o dashboard moderno |
| 🔎 Pré-validação / dry-run | ✅ | Verifica Debian, arquitetura, recursos, rede e instalação existente |
| 🖥️ Instalação somente do painel | ✅ | Instala ou reinstala apenas o XLX Modern Dashboard |
| 💾 Backup preventivo | ✅ | Cria backup antes de alterações reais |
| 🧾 Logs de instalação | ✅ | Registra a execução para diagnóstico posterior |
| 🛡️ Proteção contra sobrescrita | ✅ | Interrompe a instalação se encontrar XLXD ativo |
| 🔄 Atualização do repositório | ✅ | Atualização controlada via Git |
| 📡 D-STAR / DMR / C4FM-YSF | ✅ | Base multiprotocolo XLX |
| 🔊 XLX Echo | ✅ | Serviço opcional quando instalado |
| 🧰 Reinstalação somente do núcleo | 🚧 | Deve usar rotina dedicada de recuperação, não `install.sh` |

---

## 📋 Requisitos

Antes da instalação, utilize preferencialmente:

- Debian 12;
- arquitetura x86_64;
- acesso root ou sudo;
- IP público fixo para uso em produção;
- DNS/FQDN para o dashboard;
- acesso HTTPS ao GitHub;
- pelo menos 768 MB de RAM;
- pelo menos 4 GB livres em disco.

O instalador realiza validações automáticas antes da instalação real.

---

# 🚀 Como instalar um refletor XLX no Debian 12

Esta é a forma recomendada para uma **nova instalação XLX em uma VPS ou servidor limpo**.

### 1. Atualizar o sistema e instalar Git

```bash
sudo apt update
sudo apt install -y git
```

### 2. Clonar o XLX Modern Installer

```bash
cd /usr/src
sudo git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
```

### 3. Fazer a pré-validação antes de instalar

```bash
sudo bash install.sh --check
```

O modo `--check` não instala o XLX. Ele verifica o ambiente antes de qualquer alteração.

### 4. Executar a nova instalação completa

```bash
sudo bash install.sh
```

Antes da instalação real, o instalador cria backup preventivo e exige confirmação explícita.

---

# 🧭 Modos de instalação e manutenção

## A. Nova instalação — servidor XLX + dashboard

Use quando o servidor ainda não possui uma instalação XLXD ativa.

```bash
cd /usr/src/XLX-Modern-Installer
sudo bash install.sh --check
sudo bash install.sh
```

Fluxo principal:

1. valida Debian 12 e arquitetura;
2. valida memória, disco, DNS e HTTPS;
3. verifica se existe produção XLX ativa;
4. valida a revisão técnica utilizada como base;
5. cria backup preventivo;
6. instala o núcleo XLX;
7. instala o XLX Modern Dashboard;
8. valida serviços essenciais.

---

# 🖥️ Instalar ou reinstalar somente o dashboard

Se o XLXD já está funcionando e você quer apenas instalar, atualizar ou reinstalar o painel:

```bash
cd /usr/src/XLX-Modern-Installer
sudo bash modules/60-dashboard-modern.sh
```

Este procedimento é separado do núcleo XLXD. O instalador do painel cria backup quando encontra um dashboard existente antes de copiar a nova versão.

O dashboard solicita informações como:

- identificação do refletor;
- nome exibido;
- descrição;
- indicativo do responsável;
- localização;
- país;
- domínio;
- e-mail de contato.

---

# 📡 Reinstalar somente o servidor XLXD

O `install.sh` de nova instalação **não deve ser usado para sobrescrever um servidor XLXD ativo**.

O wrapper detecta uma instalação existente e interrompe para evitar perda de:

- identidade do refletor;
- whitelist e blacklist;
- interlinks;
- configurações locais;
- bancos de usuários;
- configurações systemd;
- arquivos do dashboard;
- dados de produção.

Antes de reconstruir somente o núcleo, preserve no mínimo:

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
/var/www/html/
```

A reinstalação somente do servidor deve seguir:

```text
DIAGNÓSTICO → BACKUP → VALIDAÇÃO → RECONSTRUÇÃO → TESTES → ROLLBACK DISPONÍVEL
```

---

# 🔄 Como atualizar o XLX Modern Installer

Para atualizar somente o repositório local:

```bash
cd /usr/src/XLX-Modern-Installer
git status
git pull --ff-only
```

Depois da atualização:

```bash
sudo bash install.sh --check
```

> Em um servidor XLXD já instalado, não execute `sudo bash install.sh` novamente apenas para atualizar os arquivos do GitHub. Para atualizar apenas o dashboard, utilize o módulo próprio do painel.

---

# 💾 Backup e rollback

O diretório padrão de backups preventivos é:

```text
/var/backups/xlx-reflector
```

Antes da instalação real, o wrapper pode gerar:

```text
pre-installation.tar.gz
pre-installation.tar.gz.sha256
manifest.txt
```

Itens importantes para backup:

```text
/etc/apache2
/etc/systemd/system
/etc/ufw
/etc/nftables.conf
/var/www/html
/xlxd
/usr/src/xlxd
/usr/src/XLXEcho
/usr/src/XLX_Dark_Dashboard
```

Regra recomendada para qualquer manutenção:

```text
DIAGNÓSTICO → BACKUP → ALTERAÇÃO → VALIDAÇÃO → ROLLBACK
```

---

# 🔍 Diagnóstico e correção

## Verificar os serviços principais

```bash
sudo systemctl status xlxd.service --no-pager
sudo systemctl status apache2.service --no-pager
sudo systemctl status xlxecho.service --no-pager
```

## Verificar se estão ativos

```bash
systemctl is-active xlxd
systemctl is-active apache2
systemctl is-active xlxecho
```

## Ver logs recentes do XLXD

```bash
sudo journalctl -u xlxd.service -n 100 --no-pager
```

## Acompanhar logs em tempo real

```bash
sudo journalctl -u xlxd.service -f
```

## Validar Apache

```bash
sudo apache2ctl configtest
```

## Conferir o serviço XLXD

```bash
sudo systemctl cat xlxd.service
```

## Ver portas TCP/UDP em escuta

```bash
sudo ss -lntup
```

## Ver processo XLXD

```bash
ps aux | grep '[x]lxd'
```

---

# 🚨 XLX não inicia: checklist rápido

1. conferir `systemctl status xlxd`;
2. verificar `journalctl -u xlxd -n 100`;
3. conferir o `ExecStart` em `xlxd.service`;
4. confirmar existência de `/xlxd/xlxd`;
5. conferir IP usado pelo serviço;
6. verificar firewall e portas;
7. verificar arquivos de configuração;
8. confirmar permissões;
9. validar Apache separadamente;
10. criar backup antes de qualquer correção.

---

# 📂 Diretórios importantes

| Finalidade | Caminho |
|---|---|
| Instalador controlado | `/opt/xlx-modern-installer` |
| Núcleo XLXD | `/xlxd/` |
| Código-fonte local | `/usr/src/XLX-Modern-Installer` |
| Backups | `/var/backups/xlx-reflector` |
| Logs do instalador | `/var/log/xlx-reflector/installer` |
| Dashboard moderno | `/var/www/html/xlx-dashboard` |

---

# 🧱 Estrutura do projeto

```text
XLX-Modern-Installer/
├── install.sh
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

# ❓ Perguntas frequentes

## Como instalar XLX no Debian 12?

Clone este repositório, execute primeiro `sudo bash install.sh --check` e, se a validação for aprovada, execute `sudo bash install.sh`.

## Como instalar um refletor D-STAR, DMR e C4FM/YSF?

O XLX é multiprotocolo. O instalador utiliza a base XLXD e prepara a implantação do refletor com suporte aos protocolos configurados pelo projeto-base.

## Como reinstalar somente o painel XLX?

```bash
sudo bash modules/60-dashboard-modern.sh
```

## Como atualizar o XLX Modern Installer?

```bash
cd /usr/src/XLX-Modern-Installer
git pull --ff-only
sudo bash install.sh --check
```

## Posso rodar `install.sh` por cima de um servidor XLXD funcionando?

Não. O instalador bloqueia essa situação propositalmente para proteger a instalação existente.

## Como diagnosticar um servidor XLX que parou?

Comece por `systemctl status`, `journalctl`, configuração systemd, portas, IP, firewall e existência do binário antes de tentar reinstalar.

## Onde ficam os backups?

Por padrão, em `/var/backups/xlx-reflector`.

---

# 🔎 Termos relacionados

XLX reflector installer, instalar refletor XLX, instalar XLXD Debian 12, servidor D-STAR, servidor DMR, servidor C4FM YSF, XLX dashboard, atualizar XLX reflector, reinstalar XLX dashboard, recuperar servidor XLXD, radioamador digital, digital amateur radio reflector.

---

# 🤝 Créditos

- **XLX / XLXD:** projeto original da comunidade XLX / LX3JL;
- **base técnica do instalador:** Daniel K. — **PP5PK**;
- **conceitos e projetos relacionados:** N5AMD, Narspt e demais autores dos componentes efetivamente utilizados;
- **versão modificada e manutenção:** **Dario — PU2PNY**.

Este projeto mantém os créditos da base técnica utilizada e adiciona uma camada própria de instalação controlada, documentação, dashboard e manutenção.

---

## 🇺🇸 English

For the complete English version, open **[README.en.md](README.en.md)**.
