# XLX Modern Installer

Instalador e camada de manutenção **independente** para refletores XLX em **Debian 12 x86_64**, mantido por **Dario — PU2PNY**.

O XLX Modern Installer possui sua própria lógica de instalação: diagnóstico, coleta de configuração, backup preventivo, compilação do XLXD, systemd, painel moderno, Apache/HTTPS, RadioID, CallingHome, Admin privado, validações e recuperação. Ele **não executa, incorpora nem chama outro instalador de refletor**.

English: [README.en.md](README.en.md)

## Fontes externas realmente usadas

O instalador busca somente os componentes de software que efetivamente precisa instalar:

- núcleo XLXD: `https://github.com/LX3JL/xlxd.git`, revisão fixada em `modules/40-xlxd.sh`;
- Echo/Parrot opcional: `https://github.com/narspt/XLXEcho.git`, revisão fixada em `modules/50-echo.sh`;
- pacotes Debian pelo APT.

O **XLX Modern Dashboard está dentro deste próprio repositório** e nunca é clonado de um repositório externo de dashboard.

## Caminhos canônicos

```text
Runtime XLXD:       /xlxd
Fonte XLXD:         /usr/src/xlxd
Painel moderno:     /var/www/html/xlxd
Configuração Admin: /etc/xlx-modern-control
CallingHome:        /etc/xlx-modern
Backups:            /var/backups/xlx-reflector
```

Os caminhos antigos `/var/www/html/xlxd-novo` e `/var/www/html/xlx-dashboard` não são destinos válidos de instalação limpa.

## Instalação limpa

```bash
sudo apt update
sudo apt install -y git
cd /usr/src
sudo git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
sudo bash install.sh --check
sudo bash install.sh
```

A instalação real exige a confirmação explícita:

```text
INSTALL
```

O fluxo executado pelo nosso próprio instalador é:

1. escolha do idioma do instalador;
2. escolha do idioma do painel;
3. validação do Debian 12 x86_64, recursos, DNS e HTTPS;
4. detecção de instalação XLX ativa ou resíduos;
5. coleta de ID do refletor, domínio, sysop, país, local, timezone, módulos, YSF, HTTPS e Echo;
6. backup preventivo verificado;
7. instalação dos pacotes Debian;
8. download da revisão fixada do XLXD, configuração, compilação e instalação;
9. instalação do nosso próprio `xlxd.service` e validação do processo/listeners;
10. Echo/Parrot opcional instalado de forma independente;
11. instalação do painel moderno local;
12. Apache e HTTPS opcional;
13. RadioID, timer de atualização e ponte de log TX/RX;
14. CallingHome próprio com timer;
15. Admin privado oculto;
16. APRS/D-PRS opcional;
17. validação final de serviços, portas, banco, Admin e HTTP/HTTPS.

## Idiomas

Idioma do instalador:

```text
1) Português (Brasil)
2) English
```

Idioma do painel público:

```text
1) Português (Brasil)
2) English
3) Español
4) Français
5) Deutsch
6) Italiano
```

O Admin operacional privado possui duas interfaces completas e auditadas: **Português (Brasil)** e **English**. Se o painel público estiver em espanhol, francês, alemão ou italiano, o Admin usa inglês para não apresentar uma interface de segurança parcialmente traduzida.

## XLXD existente — somente painel

A instalação completa se recusa a sobrescrever um XLXD ativo. Para preservar o núcleo e instalar/atualizar apenas o painel moderno:

```bash
sudo bash install.sh --dashboard-only
```

## Núcleo XLXD independente

`modules/40-xlxd.sh` realiza diretamente:

- download da revisão fixada do projeto oficial XLXD;
- verificação do commit exato;
- configuração da quantidade de módulos, porta/frequência YSF e auto-link;
- compilação local;
- instalação de `/xlxd/xlxd` e arquivos nativos;
- configuração de `/xlxd/xlxd.terminal`;
- geração e instalação do nosso próprio serviço systemd;
- validação do processo XLXD e listeners UDP.

Nenhum instalador externo participa dessa etapa.

## Echo / Parrot opcional

Quando escolhido, `modules/50-echo.sh` busca diretamente uma revisão fixada do XLXEcho, compila, instala nosso serviço systemd e gerencia com segurança a entrada nativa de Interlink:

```text
ECHO 127.0.0.1 E
```

Se o operador escolher não instalar Echo, a ausência de `xlxecho.service` é tratada corretamente como opcional.

## Painel moderno

A árvore local `dashboard/` é instalada diretamente em:

```text
/var/www/html/xlxd
```

Rotas públicas principais:

```text
/ao-vivo
/conectados
/ranking
/refletores
/api/status.php
/api/live.php
```

O pacote universal não publica em outros refletores conteúdo específico do XLX026 como **Suporte, Simulado ANATEL e Notícias**.

## Admin privado

Para instalar ou reparar isoladamente o Admin em um XLX Modern funcional:

```bash
sudo bash install-control.sh
```

A rota padrão é `admin`, podendo ser renomeada. Ela não aparece no menu público, sitemap, robots ou arquivos de indexação para IAs/buscadores.

O Admin oferece:

- status, versão, SHA, PID e listeners do XLXD;
- logs, backups e testes HTTP/API;
- reinício do XLXD protegido por senha e confirmação;
- RadioID: pesquisa, inclusão, edição, exclusão, integridade e atualização;
- whitelist e blacklist;
- gerenciamento de peers do XLX Interlink;
- auditoria, CSRF, cookies seguros e rate-limit de login.

Não existe terminal web genérico nem execução arbitrária de comandos.

### Interlink nativo

O Admin trabalha diretamente com:

```text
/xlxd/xlxd.interlink
```

no formato nativo:

```text
PEER ENDEREÇO MÓDULOS
```

Ele altera somente o peer solicitado, preserva comentários e demais entradas, cria backup, valida o arquivo completo e publica de forma atômica. O XLXD monitora a lista e recarrega alterações automaticamente, portanto uma alteração de peer normalmente não exige restart.

## RadioID

A camada runtime mantém:

```text
/xlxd/users_db/users_base.csv
/xlxd/users_db/users.db
```

A atualização cria um banco candidato, valida a integridade SQLite e só então publica. Inclusões, correções e exclusões locais feitas pelo Admin são persistidas separadamente e reaplicadas após futuras atualizações.

## CallingHome

O CallingHome é implementado pelo próprio repositório, com configuração local protegida e serviço/timer systemd próprios, sem depender de painel antigo.

## Módulos opcionais

APRS/D-PRS:

```bash
sudo bash install.sh --with-aprs-dprs
```

ou:

```bash
sudo bash install.sh --without-aprs-dprs
```

Certificados permanecem opcionais e **não fazem parte da instalação pública padrão**.

## Segurança e aceitação

Os testes do repositório verificam sintaxe, traduções, caminhos canônicos, revisões das fontes independentes, limites de privilégio do Admin, alterações atômicas do Interlink e persistência RadioID.

CI não consegue provar firewall do provedor, propagação DNS nem tráfego real D-STAR/DMR/YSF. A aceitação final de uma versão exige instalação limpa em VPS Debian 12 e teste real dos protocolos.

Veja [ARCHITECTURE.md](ARCHITECTURE.md), [control/README.md](control/README.md) e os guias em `docs/`.
