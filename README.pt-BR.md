# XLX Modern Installer

Instalador e camada de manutenção conservadora para **refletores XLX em Debian 12 x86_64**, mantido por **Dario — PU2PNY** e baseado no instalador revisado de **Daniel K. — PP5PK**.

O projeto mantém o fluxo comprovado do PP5PK para instalar/compilar o núcleo XLXD e substitui a camada de dashboard/dados antiga pelo XLX Modern Dashboard, RadioID persistente, Admin privado oculto, CallingHome dedicado e módulos opcionais APRS/D-PRS / Certificados.

> **Caminhos canônicos**
>
> - Núcleo XLXD, listas nativas e runtime: `/xlxd`
> - Webroot do painel moderno: `/var/www/html/xlxd`
> - O caminho antigo `/var/www/html/xlxd-novo` não é destino de instalação nova.

English: [README.en.md](README.en.md)

---

## O que uma instalação limpa deve entregar

Uma instalação concluída com sucesso foi desenhada para fornecer:

- núcleo XLXD compilado/instalado usando o fluxo base revisado do PP5PK;
- configuração de D-STAR, DMR e C4FM/YSF suportada pelo XLXD;
- ID do refletor, domínio, dados do sysop e timezone configuráveis;
- 1–26 módulos XLXD;
- porta UDP YSF, frequência Wires-X e auto-link YSF configuráveis;
- XLX Echo opcional;
- `xlxd.service` gerenciado pelo systemd;
- painel moderno diretamente em `/var/www/html/xlxd`;
- VirtualHost Apache e HTTPS Let's Encrypt quando escolhido;
- base RadioID/usuários atualizada diariamente com validação SQLite;
- alterações locais de RadioID persistentes após novas atualizações;
- ponte de log TX/RX e `xlx_log.service`;
- CallingHome dedicado, sem depender do dashboard antigo;
- Admin privado oculto, com usuário/senha locais e rota configurável;
- APRS/D-PRS opcional;
- XLX Certificate Generator opcional;
- backup preventivo, validações e rollback nas operações mutáveis da camada Modern.

O pacote público **não publica conteúdo específico do XLX026** como Suporte, Simulado ANATEL ou Notícias em outros refletores.

---

## Base PP5PK revisada

O instalador do núcleo está fixado à base revisada:

- repositório: `PP5PK/XLX_Installer`
- commit revisado: `20b48934505b1939317bf71b30ddc32b1ced0035`
- Git blob do `installer.sh` upstream: `266217ee910742710b9c5c9f30009c8a0f0fcaf7`

A cópia vendorizada é conferida por SHA-256 antes do uso. Veja [vendor/pp5pk-installer/UPSTREAM.md](vendor/pp5pk-installer/UPSTREAM.md) e [docs/PP5PK-COMPATIBILITY-MATRIX.md](docs/PP5PK-COMPATIBILITY-MATRIX.md).

A camada Modern mantém intencionalmente do PP5PK: compilação/instalação do XLXD, módulos, YSF, systemd, arquivo nativo de opções de terminal e caminho opcional do Echo. Ela substitui intencionalmente o dashboard legado, a antiga camada de users-db do painel e o CallingHome dependente do painel legado.

---

## Instalação rápida — VPS Debian 12 limpa

```bash
sudo apt update
sudo apt install -y git
cd /usr/src
sudo git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
```

Primeiro execute a pré-validação sem alteração:

```bash
sudo bash install.sh --check
```

Depois execute a instalação real:

```bash
sudo bash install.sh
```

A instalação real exige a confirmação explícita:

```text
INSTALL
```

### Idiomas

Sem `--lang`, a primeira escolha é o **idioma do instalador**:

```text
1) Português (Brasil)
2) English
```

Depois o instalador pergunta separadamente o **idioma do painel público**:

```text
1) Português (Brasil)
2) English
3) Español
4) Français
5) Deutsch
6) Italiano
```

O dashboard público é construído/testado nos seis idiomas. O Admin operacional privado possui duas interfaces completas: **Português (Brasil)** e **English**. Quando o painel público usa espanhol, francês, alemão ou italiano, o Admin usa inglês para evitar uma interface de segurança parcialmente traduzida.

Para selecionar inglês diretamente:

```bash
sudo bash install.sh --lang=en
```

---

## XLXD existente: atualizar somente o painel

A instalação completa é bloqueada quando encontra um XLXD ativo. Para instalar/reinstalar somente o painel moderno preservando o núcleo existente:

```bash
sudo bash install.sh --dashboard-only
```

Esse fluxo cria backup preventivo e não reinstala o binário do XLXD.

---

## Painel moderno canônico

O único destino de instalação limpa é:

```text
/var/www/html/xlxd
```

O instalador do painel:

- reaproveita os dados do refletor coletados pelo instalador base;
- cria `config/site.php`;
- compila o idioma escolhido;
- renderiza placeholders genéricos;
- cria diretórios de cache necessários;
- configura Apache;
- solicita HTTPS via Certbot quando escolhido;
- instala CallingHome;
- instala o Admin privado;
- valida APIs e dados de runtime.

Rotas públicas importantes:

```text
/ao-vivo
/conectados
/ranking
/refletores
/api/status.php
/api/live.php
```

---

## Admin privado

O Admin não aparece no menu público nem nos arquivos de indexação. A rota padrão é `admin`, mas o operador pode escolher outro nome válido durante a instalação.

Para instalar/reparar o Admin isoladamente em um XLX Modern já funcional:

```bash
sudo bash install-control.sh
```

O instalador isolado usa `/var/www/html/xlxd` por padrão.

Funções:

- status do XLXD, versão, SHA, PID e quantidade de processos;
- listeners UDP;
- logs e backups recentes;
- testes HTTP/API;
- reinício protegido do XLXD com senha e validação posterior de SHA/versão;
- RadioID: pesquisar, adicionar, editar, excluir, verificar integridade e atualizar;
- whitelist e blacklist;
- gerenciamento de peers do XLX Interlink;
- auditoria, CSRF, rate-limit e cookies seguros.

Não existe terminal web genérico nem execução arbitrária de comandos.

### Interlink

O Admin gerencia o formato nativo do XLXD em:

```text
/xlxd/xlxd.interlink
```

Cada entrada ativa usa:

```text
PEER ENDEREÇO MÓDULOS
```

Exemplo:

```text
XLX123 peer.exemplo.net ABCDE
```

O Admin altera um peer por vez, preserva comentários e entradas não relacionadas — inclusive uma linha do Echo —, cria backup, valida o arquivo completo e publica de forma atômica. O gatekeeper do XLXD monitora o arquivo e recarrega alterações automaticamente; portanto editar um peer Interlink normalmente **não exige restart do XLXD**.

Veja [control/README.md](control/README.md).

---

## RadioID / base de indicativos

A camada Modern mantém:

```text
/xlxd/users_db/users_base.csv
/xlxd/users_db/users.db
```

A atualização diária cria um candidato separado, executa `PRAGMA integrity_check` e só então publica. Inclusões, correções e exclusões feitas localmente pelo Admin são persistidas separadamente e reaplicadas depois das atualizações da base principal.

A validação final exige que `users.db` exista, esteja íntegro e tenha quantidade coerente de registros antes de considerar a camada Modern pronta.

---

## CallingHome

O CallingHome não depende mais do painel legado. O XLX Modern instala um cliente/timer systemd próprio, com configuração local protegida, usando identidade do refletor, URL do dashboard, país, comentário, versão do XLXD e lista Interlink.

Falhas temporárias de rede/diretório são repetidas pelo timer.

---

## APRS / D-PRS opcional

Para instalar explicitamente:

```bash
sudo bash install.sh --with-aprs-dprs
```

Para pular o módulo e a pergunta:

```bash
sudo bash install.sh --without-aprs-dprs
```

---

## Certificados opcionais

Certificados **não fazem parte da instalação pública padrão**. O XLX Certificate Generator só é instalado quando habilitado explicitamente pelo fluxo suportado.

---

## Firewall, DNS e alcance externo

Assim como na base PP5PK, o instalador não afirma que firewall do provedor, NAT ou DNS estejam corretos apenas porque o processo XLXD está ativo. Essas camadas precisam ser verificadas na VPS real.

Consulte a documentação de portas/firewall em `docs/` antes dos testes públicos.

---

## Modelo de segurança

- `--check` antes da instalação real;
- bloqueio de instalação completa sobre XLXD ativo;
- confirmação explícita `INSTALL`;
- backup preventivo;
- validação SHA/sintaxe/configuração/SQLite;
- sudo restrito a ações administrativas fixas;
- nenhuma senha do Admin em texto puro no GitHub/webroot;
- rota Admin ausente do menu público;
- nenhum `NOPASSWD: ALL`;
- nenhum web shell;
- persistência de alterações locais do RadioID;
- rollback automático onde a operação Modern pode ser validada de forma atômica.

---

## CI e aceitação

O GitHub Actions valida sintaxe Bash/Python/PHP/JavaScript, os seis idiomas do dashboard, os dois idiomas completos do Admin, persistência RadioID, limites de privilégio, caminhos antigos proibidos, pin da base PP5PK e um teste ponta a ponta de inclusão/exclusão Interlink através da fronteira `www-data → sudo → helper`.

CI é obrigatório, mas não consegue provar propagação DNS, firewall do provedor ou tráfego real de rádio D-STAR/DMR/YSF. A validação de campo exige instalação limpa em uma VPS Debian 12 e testes reais dos protocolos.

---

## Créditos

- XLXD: Jean-Luc Deltombe — LX3JL e colaboradores
- Instalador-base: Daniel K. — PP5PK
- XLX Modern Installer / integração do painel moderno: Dario — PU2PNY

Veja [CREDITS.md](CREDITS.md), [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) e [LICENSE](LICENSE).
