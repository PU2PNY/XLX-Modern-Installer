#!/usr/bin/env python3
from pathlib import Path
import re

EN_BLOCK = '''**Current release: v1.4.2**

Public, reproducible installer for a fresh **Debian 12 x86_64** server. It installs the XLXD core, Echo Test, the modern multi-protocol dashboard, private Admin, native APRS/D-PRS, native verifiable certificates, CallingHome and operational observability.

This repository publishes the XLX Modern installer and dashboard stack derived from the production-validated **XLX026 Brasil** environment. During setup, the operator enters the identity of the new reflector, so each installation receives its own reflector ID, domain and location. XLX026 is the production reference and live demonstration; its credentials, secrets and private production data are not distributed.

**Live production example:** [XLX026 Brasil — xlx026.net](https://xlx026.net/)

[Português (Brasil)](README.pt-BR.md) · [English](README.en.md) · [Changelog](CHANGELOG.md) · [Features](docs/FEATURES.md)

## Quick install

Use a clean Debian 12 VPS. Minimal images may not include Git.

```bash
apt-get update
apt-get install -y git ca-certificates
cd /usr/src
git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
bash start.sh
```

`start.sh` is the recommended beginner path. It validates the VPS first, prepares the interface automatically and refuses to overwrite an active XLXD installation or unresolved XLXD remnants. `install.sh --check` remains available as a read-only preflight.

## Installation behavior

The normal path uses **one SSH session only**. No second terminal, SSH tunnel or browser setup is required. The beginner interface starts with Portuguese/English and then uses only four clear stages: essential data, private access, review and installation. Pressing Enter validates the current answer and moves to the next field.

Only information that really needs a human decision is requested. Recommended technical values are applied automatically: HTTPS, Echo Test on module E, five modules A–E, YSF UDP 42000, YSF frequency 433125000, auto-link module C and the detected timezone. The Admin username/private path are generated from the supplied identity; the operator only creates the private password. The YSF reflector ID uses `12345` as an example, while the XLX reflector ID correctly remains exactly three alphanumeric characters.

The installer runs inside an automatically managed `tmux` session. If SSH disconnects, reconnect to the VPS and run `bash start.sh` again; the existing installer session is reopened instead of starting over. The reviewed `install.sh` remains the single installation engine. `bash install.sh --classic` is the compatibility fallback and `web-install.sh` remains available only as an advanced optional browser interface.

The installer does **not** run a mandatory full OS upgrade. It updates package indexes and installs only required dependencies using `apt-get`.'''

PT_BLOCK = '''**Versão atual: v1.4.2**

Instalador público e reproduzível para **Debian 12 x86_64**. Instala o núcleo XLXD, Echo Test, painel moderno multiprotocolo, Admin privado, APRS/D-PRS nativo, Certificados nativos verificáveis, CallingHome e observabilidade operacional.

Este repositório publica o instalador e o painel **XLX Modern** derivados do ambiente **XLX026 Brasil validado em produção**. Durante a instalação, o responsável informa somente os dados indispensáveis do novo refletor; as configurações técnicas recomendadas são aplicadas automaticamente. O XLX026 é a referência de produção e demonstração ao vivo; credenciais, segredos e dados privados do servidor de produção não são distribuídos.

**Exemplo funcionando em produção:** [XLX026 Brasil — xlx026.net](https://xlx026.net/)

## Instalação rápida

```bash
apt-get update
apt-get install -y git ca-certificates
cd /usr/src
git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
bash start.sh
```

`bash start.sh` é o caminho recomendado para leigos. Ele valida a VPS primeiro, prepara a interface automaticamente e recusa sobrescrever um XLXD ativo ou vestígios antigos ainda não revisados. `bash install.sh --check` continua disponível como pré-validação somente leitura.

## Como a instalação funciona

O caminho normal usa **uma única sessão SSH**. Não é necessário abrir outro terminal, criar túnel SSH nem configurar navegador. A primeira tela escolhe Português/English e depois existem somente quatro etapas claras: dados essenciais, acesso privado, revisão e instalação. Ao pressionar Enter, a resposta atual é validada e o cursor vai para o próximo campo.

O instalador pergunta apenas o que realmente precisa de decisão humana. Valores técnicos recomendados são automáticos: HTTPS, Echo Test no módulo E, cinco módulos A–E, YSF UDP 42000, frequência YSF 433125000, auto-link no módulo C e fuso horário detectado. Usuário e endereço privado do Admin são gerados a partir da identidade informada; a pessoa cria apenas a senha privada. O YSF ID usa `12345` como exemplo; o ID XLX continua corretamente limitado a exatamente três caracteres alfanuméricos.

A instalação roda dentro de uma sessão `tmux` criada automaticamente. Se o SSH cair, basta reconectar na VPS e executar `bash start.sh` novamente; a mesma instalação é reaberta em vez de recomeçar. O `install.sh` revisado continua sendo o único motor real. `bash install.sh --classic` fica como fallback de compatibilidade e `web-install.sh` permanece disponível apenas como opção avançada de navegador.

O instalador **não executa `full-upgrade` obrigatório**. Usa `apt-get` para atualizar índices e instalar apenas as dependências necessárias.'''


def update_english(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    pattern = re.compile(
        r"\*\*Current release: v1\.4\.0\*\*.*?The installer does \*\*not\*\* run a mandatory full OS upgrade\. It updates package indexes and installs only required dependencies using `apt-get`\.",
        re.S,
    )
    new, count = pattern.subn(EN_BLOCK, text, count=1)
    if count != 1:
        raise SystemExit(f"expected English intro block not found exactly once in {path}: {count}")
    new = new.replace(
        "install.sh                 top-level installer",
        "start.sh                   recommended beginner launcher\ninstall.sh                 authoritative installation engine",
        1,
    )
    path.write_text(new, encoding="utf-8")


def update_portuguese(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    pattern = re.compile(
        r"\*\*Versão atual: v1\.4\.0\*\*.*?O instalador \*\*não executa `full-upgrade` obrigatório\*\*\. Usa `apt-get` para atualizar índices e instalar apenas as dependências necessárias\.",
        re.S,
    )
    new, count = pattern.subn(PT_BLOCK, text, count=1)
    if count != 1:
        raise SystemExit(f"expected Portuguese intro block not found exactly once: {count}")
    new = new.replace(
        "install.sh                 top-level installer",
        "start.sh                   inicializador recomendado para leigos\ninstall.sh                 motor real da instalação",
        1,
    )
    path.write_text(new, encoding="utf-8")


def update_changelog(path: Path) -> None:
    current = path.read_text(encoding="utf-8")
    if current.startswith("## v1.4.2"):
        return
    if not current.startswith("## v1.4.0"):
        raise SystemExit("unexpected CHANGELOG head")
    section = '''## v1.4.2 — Beginner-first resilient installer

- Makes `bash start.sh` the recommended one-command installation path for beginners.
- Removes the second-terminal, SSH-tunnel and browser requirement from the normal path; the web installer remains optional for advanced use.
- Reduces the visible wizard to four stages and asks only for essential identity/location/YSF data plus the private Admin password.
- Applies reviewed technical defaults automatically: HTTPS, Echo E, modules A–E, YSF UDP 42000, 433125000 Hz and auto-link C.
- Generates the Admin username/private path automatically and keeps the password hidden from review/log output.
- Uses a high-contrast dark interface with thicker progress bars and Enter-to-next behavior.
- Keeps the valid `12345` example on the YSF reflector ID while preserving the XLX ID contract at exactly three alphanumeric characters.
- Runs the visual installer inside an automatically managed `tmux` session so an SSH disconnect can be recovered by running `bash start.sh` again.
- Adds a dedicated beginner-installer regression gate and keeps `install.sh` as the authoritative installation engine.

'''
    path.write_text(section + current, encoding="utf-8")


for filename in ("README.md", "README.en.md"):
    update_english(Path(filename))
update_portuguese(Path("README.pt-BR.md"))
update_changelog(Path("CHANGELOG.md"))
