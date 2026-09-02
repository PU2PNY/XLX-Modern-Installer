# XLX Modern Private Admin

Área técnica privada opcional para uma instalação XLX Modern já funcional.

## Instalação isolada

Na raiz do repositório:

```bash
sudo bash install-control.sh
```

O ponto de entrada oficial usa o dashboard canônico:

```text
/var/www/html/xlxd
```

Também é possível informar explicitamente outro diretório compatível:

```bash
sudo bash install-control.sh --dashboard-dir=/var/www/html/xlxd
```

O instalador lê a identidade e o domínio de `config/site.php`, captura a versão e o SHA-256 do Core XLXD já instalado, cria backup preventivo e instala uma rota administrativa privada. O nome padrão é `admin`, mas o operador pode escolher outro slug válido durante a instalação.

A rota não é adicionada ao menu público, sitemap, robots, `llms.txt` ou `ai-context.json`. Bots conhecidos recebem HTTP 404 e a página envia cabeçalhos `noindex`, `nofollow`, `noarchive` e `nosnippet`.

## Idioma

O dashboard público possui seis idiomas (`pt-BR`, `en`, `es`, `fr`, `de`, `it`). O Admin operacional possui duas interfaces completas e auditadas: **Português (Brasil)** e **English**. Em dashboards configurados para `es`, `fr`, `de` ou `it`, o Admin usa inglês para evitar uma tela de segurança parcialmente traduzida.

## Usuário e senha

**Nenhum usuário e nenhuma senha são distribuídos pelo GitHub.** Durante a primeira instalação o operador escolhe o usuário e digita a senha duas vezes sem que ela apareça na tela. Somente `password_hash()` é persistido em `/etc/xlx-modern-control/config.php`.

Para automação controlada, as credenciais podem ser fornecidas apenas ao processo local:

```bash
sudo -E env \
  XLX_CONTROL_USERNAME='operador' \
  XLX_CONTROL_PASSWORD='SENHA_LOCAL' \
  bash install-control.sh
```

Não grave senha em scripts, histórico do shell, arquivos de CI ou repositórios públicos.

## Funções administrativas

O Admin inclui:

- status do `xlxd.service`, versão, SHA, PID e quantidade de processos;
- listeners UDP, logs recentes, backups e testes HTTP/API;
- reinício protegido somente do XLXD, com senha, confirmação e validação de versão/SHA;
- RadioID: status, pesquisa, inclusão, edição, exclusão, integridade e atualização;
- persistência de inclusões/exclusões locais do RadioID após atualização automática da base;
- whitelist e blacklist com validação, backup, lock e auditoria;
- **XLX Interlink por peer**, usando o formato nativo `PEER ENDEREÇO MÓDULOS` de `/xlxd/xlxd.interlink`;
- inclusão/atualização e remoção de peers Interlink sem apagar as outras linhas do arquivo;
- preservação de comentários e de entradas existentes, como `ECHO 127.0.0.1 E`;
- backup e rollback em caso de falha de validação do Interlink.

O gatekeeper do XLXD monitora `xlxd.interlink` e recarrega alterações automaticamente, portanto uma alteração de Interlink **não exige restart do XLXD**. O botão de restart continua separado e protegido para situações em que o operador realmente precise reiniciar o serviço.

## Segurança e privilégio

O Admin usa:

- sessão com cookie `Secure`, `HttpOnly` e `SameSite=Strict`;
- CSRF em ações autenticadas;
- bloqueio temporário após tentativas repetidas de login;
- cabeçalhos defensivos e política contra indexação;
- helpers privilegiados com allowlist de ações, sem terminal web e sem comando arbitrário;
- `sudoers` restrito às ações administrativas previstas;
- backup antes de mudanças em RadioID, whitelist, blacklist e Interlink;
- escrita atômica e validação antes de considerar a alteração concluída.

## Arquivos locais

```text
/etc/xlx-modern-control/config.php
/etc/xlx-modern-control/helper.conf
/etc/xlx-modern-control/route
/var/lib/xlx-modern-control/
/usr/local/sbin/xlx-modern-control-helper
/usr/local/sbin/xlx-modern-radioid-helper
/usr/local/sbin/xlx-modern-access-helper
/etc/sudoers.d/xlx-modern-control
/var/backups/xlx-reflector/admin/
/var/backups/xlx-reflector/control-access/
```

## Pré-validação

```bash
sudo bash install-control.sh --check
```

Esse modo valida fontes, sintaxe e invariantes de segurança sem instalar ou alterar o Admin.
