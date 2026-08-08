# 🌐 XLX Modern Installer

<div align="center">

![Debian 12](https://img.shields.io/badge/Debian-12-red?logo=debian&logoColor=white)
![Architecture](https://img.shields.io/badge/Arquitetura-x86__64-blue)
![XLX](https://img.shields.io/badge/XLX-D--STAR%20%7C%20DMR%20%7C%20C4FM%2FYSF-00c8ff)
![Dashboard](https://img.shields.io/badge/Dashboard-Modern-success)
![Status](https://img.shields.io/badge/Status-em%20desenvolvimento-yellow)

**Instalador controlado para refletores XLX em Debian 12, com validações, backups preventivos e XLX Modern Dashboard.**

D-STAR • DMR • C4FM/YSF • XLX Echo • Dashboard moderno

[Instalação rápida](#-instalação-rápida) • [Modos de instalação](#-modos-de-instalação-e-manutenção) • [Dashboard](#-dashboard) • [Backups](#-backups-e-rollback) • [Diagnóstico](#-diagnóstico-e-correção) • [Estrutura](#-estrutura-do-projeto)

</div>

---

## 📖 Sobre o projeto

O **XLX Modern Installer** é uma camada de instalação e manutenção criada para tornar a implantação de um refletor XLX mais segura, auditável e fácil de recuperar.

A base técnica do núcleo continua sendo o projeto de **Daniel K. — PP5PK**, utilizando uma revisão previamente analisada do instalador original. Esta versão adiciona validações antes da instalação, backup preventivo, logs, separação do dashboard moderno e uma estrutura preparada para manutenção futura.

### Objetivos principais

- ✅ instalar um novo refletor XLX de forma controlada;
- ✅ validar o servidor antes de alterar produção;
- ✅ criar backup preventivo antes da instalação real;
- ✅ instalar o XLX Modern Dashboard separadamente;
- ✅ manter logs claros para diagnóstico;
- ✅ facilitar atualização, correção e recuperação;
- ✅ impedir sobrescrita acidental de uma instalação XLX ativa.

> **Importante:** este projeto prioriza preservação de dados. O instalador principal **não sobrescreve um XLXD já instalado**.

---

## ✨ Recursos

| Recurso | Situação | Descrição |
|---|---:|---|
| 🆕 Nova instalação completa | ✅ | Instala núcleo XLX e depois o dashboard moderno |
| 🔎 Pré-validação / dry-run | ✅ | Verifica Debian, recursos, rede, arquivos e instalação existente |
| 🖥️ Instalação somente do painel | ✅ | Pode instalar ou reinstalar apenas o XLX Modern Dashboard |
| 💾 Backup preventivo | ✅ | Salva arquivos relevantes antes da instalação real |
| 🧾 Logs de instalação | ✅ | Registra a execução em `/var/log/xlx-reflector/installer` |
| 🛡️ Proteção contra sobrescrita | ✅ | Interrompe se detectar XLXD ativo |
| 🔄 Atualização do repositório | ✅ | Atualização controlada via Git |
| 🧰 Reinstalação somente do núcleo XLXD | 🚧 | Ainda não automatizada pelo wrapper atual |
| ♻️ Reinstalação completa sobre servidor existente | 🚧 | Deve ser feita por procedimento de manutenção/restore, não pelo instalador de nova instalação |

---

## 🚀 Instalação rápida

### 1. Preparar o Debian 12

```bash
sudo apt update
sudo apt install -y git
```

### 2. Clonar o projeto

```bash
cd /usr/src
sudo git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
```

### 3. Fazer somente a pré-validação

```bash
sudo bash install.sh --check
```

Esse comando **não instala nada**. Ele verifica:

- Debian 12;
- arquitetura x86_64;
- memória disponível;
- espaço em disco;
- DNS e acesso HTTPS ao GitHub;
- comandos necessários;
- existência de uma instalação XLX ativa;
- commit e SHA-256 da base técnica revisada.

### 4. Executar uma nova instalação completa

```bash
sudo bash install.sh
```

Antes da alteração real, o instalador cria backup preventivo e exige confirmação explícita.

---

## 🧭 Modos de instalação e manutenção

### 🆕 A. Nova instalação — servidor + painel

Use em uma VPS/servidor Debian 12 **sem XLXD ativo**.

```bash
cd /usr/src/XLX-Modern-Installer
sudo bash install.sh --check
sudo bash install.sh
```

Fluxo executado:

1. valida o sistema;
2. valida recursos e internet;
3. confirma que não existe produção XLX ativa;
4. valida a revisão técnica do instalador original;
5. cria backup preventivo;
6. executa a instalação do XLX;
7. instala o XLX Modern Dashboard;
8. valida Apache, XLXD e XLX Echo quando presente.

---

### 🖥️ B. Instalar ou reinstalar somente o painel

Este é o modo correto quando o **servidor XLXD já está funcionando** e você quer apenas instalar/atualizar o dashboard moderno.

```bash
cd /usr/src/XLX-Modern-Installer
sudo bash modules/60-dashboard-modern.sh
```

O instalador do dashboard solicita:

- identificação do refletor;
- nome exibido;
- descrição;
- indicativo do responsável;
- cidade/estado;
- país;
- domínio;
- e-mail de contato.

Se já existir um painel no destino, o instalador cria um backup antes de copiar a nova versão.

> Esse procedimento não executa a instalação completa do XLXD.

---

### 📡 C. Reinstalar somente o servidor XLXD

**Situação atual: ainda não automatizada por este wrapper.**

O `install.sh` desta versão interrompe a execução quando encontra um XLXD ativo. O instalador PP5PK revisado também protege contra instalação sobre `/xlxd/xlxd` existente. Isso é intencional para evitar perda de configuração, bancos, listas e arquivos de produção.

Antes de qualquer reconstrução do núcleo, preserve pelo menos:

```text
/xlxd/
/etc/systemd/system/xlxd.service
/etc/systemd/system/xlxecho.service
/var/log/xlxd.xml
/var/log/xlx.log
/var/www/html/
```

E principalmente os arquivos locais que podem conter identidade/configuração do refletor:

```text
/xlxd/callinghome.php
/xlxd/xlxd.blacklist
/xlxd/xlxd.whitelist
/xlxd/xlxd.interlink
/xlxd/xlxd.terminal
/xlxd/users_db/
```

**Não use `install.sh` como tentativa de “reparar por cima” de um servidor ativo.**

Uma rotina dedicada de **reinstalação somente do núcleo**, com backup → compilação → troca controlada → validação → rollback, será adicionada separadamente para que esse procedimento possa ser feito com segurança.

---

### ♻️ D. Reinstalar servidor + painel em uma instalação existente

Para uma produção já existente, trate como **recuperação controlada**, não como nova instalação.

Fluxo recomendado:

1. inventário do estado atual;
2. backup completo verificado;
3. salvar configurações e bancos;
4. validar serviços e portas antes de remover qualquer componente;
5. reconstruir o núcleo;
6. restaurar configurações necessárias;
7. instalar o dashboard;
8. testar XLXD, Apache, Echo e APIs;
9. somente então liberar produção.

> Enquanto não existir um script específico de recuperação completa no repositório, não há um comando único seguro para sobrescrever uma instalação ativa.

---

## 🔄 Atualizar o projeto

Para atualizar somente os arquivos do repositório local:

```bash
cd /usr/src/XLX-Modern-Installer
git status
git pull --ff-only
```

Depois da atualização, execute primeiro:

```bash
sudo bash install.sh --check
```

Em um servidor já instalado, **não execute `sudo bash install.sh` novamente** apenas porque atualizou o Git. Para atualizar somente o painel, use o módulo próprio do dashboard.

---

## 🖥️ Dashboard

O dashboard moderno fica separado do núcleo XLXD para permitir evolução visual sem obrigar a reinstalação do refletor.

### Instalador do dashboard

```bash
sudo bash modules/60-dashboard-modern.sh
```

O módulo chama:

```text
dashboard/install/install-dashboard.sh
```

### Destino padrão do dashboard do repositório

```text
/var/www/html/xlx-dashboard
```

O destino pode ser alterado usando a variável `INSTALL_DIR` quando necessário.

### Configuração gerada

```text
config/site.php
```

O arquivo contém informações de identificação, branding e recursos visíveis do dashboard.

---

## 💾 Backups e rollback

### Diretório padrão de backups

```text
/var/backups/xlx-reflector
```

### Backup preventivo da instalação completa

Antes da instalação real, o wrapper cria um diretório com data/hora e, quando existem arquivos relevantes, gera:

```text
pre-installation.tar.gz
pre-installation.tar.gz.sha256
manifest.txt
```

O SHA-256 é verificado imediatamente após a criação.

### Itens considerados no inventário preventivo

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

### Regra recomendada antes de qualquer correção

```text
DIAGNÓSTICO → BACKUP → ALTERAÇÃO → VALIDAÇÃO → ROLLBACK DISPONÍVEL
```

Nunca remova arquivos de produção antes de confirmar que o backup existe e está íntegro.

---

## 🧾 Logs

### Logs do instalador moderno

```text
/var/log/xlx-reflector/installer/
```

### Logs comuns do XLX

```text
/var/log/xlxd.xml
/var/log/xlx.log
/var/log/xlxecho.log
```

### Acompanhar o serviço em tempo real

```bash
sudo journalctl -u xlxd.service -f
```

### Últimas mensagens do XLXD

```bash
sudo journalctl -u xlxd.service -n 100 --no-pager
```

---

## 🔍 Diagnóstico e correção

### Estado dos principais serviços

```bash
sudo systemctl status xlxd.service --no-pager
sudo systemctl status apache2.service --no-pager
sudo systemctl status xlxecho.service --no-pager
```

### Verificar somente se estão ativos

```bash
systemctl is-active xlxd
systemctl is-active apache2
systemctl is-active xlxecho
```

### Validar configuração do Apache

```bash
sudo apache2ctl configtest
```

### Ver processo XLXD

```bash
ps aux | grep '[x]lxd'
```

### Ver portas em escuta

```bash
sudo ss -lntup
```

### Conferir serviço configurado

```bash
sudo systemctl cat xlxd.service
```

### Recarregar systemd depois de uma alteração controlada

```bash
sudo systemctl daemon-reload
```

### Reiniciar somente o XLXD

```bash
sudo systemctl restart xlxd.service
```

> Reiniciar serviço é diferente de reinstalar o servidor. Use restart somente quando o binário e a configuração já estiverem válidos.

---

## 🚨 Checklist quando o refletor não inicia

1. verificar `systemctl status xlxd`;
2. verificar `journalctl -u xlxd -n 100`;
3. conferir `ExecStart` em `xlxd.service`;
4. confirmar existência e permissão de `/xlxd/xlxd`;
5. verificar arquivos de configuração necessários;
6. verificar portas e firewall;
7. validar IP configurado para o refletor;
8. conferir se Apache e dashboard estão independentes do erro;
9. não reinstalar antes de entender a causa;
10. criar backup antes da primeira correção.

---

## 📂 Diretórios utilizados

| Finalidade | Caminho |
|---|---|
| Instalador controlado | `/opt/xlx-modern-installer` |
| Fonte XLXD instalada | `/xlxd/` |
| Backups preventivos | `/var/backups/xlx-reflector` |
| Logs do instalador | `/var/log/xlx-reflector/installer` |
| Dashboard moderno do repositório | `/var/www/html/xlx-dashboard` |
| Código-fonte local do projeto | `/usr/src/XLX-Modern-Installer` |

---

## 🧱 Estrutura do projeto

```text
XLX-Modern-Installer/
├── install.sh
├── README.md
├── config/
├── dashboard/
│   └── install/
│       └── install-dashboard.sh
├── docs/
├── modules/
│   └── 60-dashboard-modern.sh
├── references/
│   └── PP5PK-XLX-Installer/
├── scripts/
│   └── development-preview.sh
└── tests/
```

### Arquivos principais

| Arquivo / pasta | Função |
|---|---|
| `install.sh` | Pré-validação e nova instalação completa |
| `modules/60-dashboard-modern.sh` | Instalação independente do dashboard |
| `dashboard/` | Código do XLX Modern Dashboard |
| `config/` | Configurações e exemplos |
| `docs/` | Documentação complementar |
| `scripts/` | Ferramentas auxiliares e desenvolvimento |
| `tests/` | Testes automatizados |
| `references/` | Referências técnicas preservadas |

---

## 🔐 Proteções do instalador

O wrapper atual possui diversas barreiras antes de executar uma instalação real:

- exige root;
- homologa Debian 12;
- exige x86_64;
- exige pelo menos 768 MB de RAM;
- exige pelo menos 4 GB livres;
- testa DNS e HTTPS;
- valida ferramentas necessárias;
- detecta XLXD existente;
- valida commit específico da base PP5PK;
- valida SHA-256 do instalador revisado;
- cria backup preventivo;
- exige confirmação textual antes da alteração real.

---

## 🛠️ Recuperação futura planejada

Para tornar este repositório um kit completo de manutenção, os seguintes modos devem existir como scripts próprios e independentes:

```text
scripts/reinstall-server-only.sh
scripts/reinstall-dashboard-only.sh
scripts/repair-installation.sh
scripts/backup-production.sh
scripts/restore-production.sh
scripts/health-check.sh
scripts/update-dashboard.sh
```

Cada rotina de manutenção deve seguir a mesma regra:

```text
1. diagnosticar
2. mostrar o que será alterado
3. criar backup
4. confirmar integridade do backup
5. executar somente o escopo escolhido
6. validar serviços e arquivos
7. manter rollback disponível
```

Isso evita transformar o instalador de nova instalação em uma ferramenta destrutiva de reparo.

---

## ⚠️ Operações que exigem cuidado

Evite executar comandos destrutivos sem backup validado, especialmente em:

```text
/xlxd
/var/www/html
/etc/systemd/system
/etc/apache2
```

Não apague `callinghome.php`, bancos, listas, arquivos de usuários ou configurações locais apenas para tentar corrigir um problema de serviço.

---

## 🤝 Créditos

Este projeto utiliza como base técnica o trabalho de:

- **Daniel K. — PP5PK** — `PP5PK/XLX_Installer` e componentes relacionados;
- **LX3JL** — projeto original XLXD;
- **N5AMD** — trabalhos anteriores de instalação XLX em Debian;
- **Narspt** — XLX Echo;
- demais autores dos componentes utilizados pelo ecossistema XLX.

Versão modificada, modernizada e mantida por **Dario — PU2PNY**.

---

## 📌 Estado do projeto

O projeto está em evolução. A prioridade é manter uma instalação segura e transformar gradualmente o repositório também em uma **caixa de ferramentas de recuperação e manutenção**, sem perder as proteções contra sobrescrita de produção.

Para uma **nova instalação**, use `install.sh`.

Para **somente o dashboard**, use `modules/60-dashboard-modern.sh`.

Para **reconstrução do núcleo XLXD em produção**, faça primeiro backup e diagnóstico; o modo automatizado dedicado ainda será implementado.
