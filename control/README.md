# Controle XLX Modern

Área técnica privada opcional para uma instalação XLX Modern já funcional.

## Instalação

Na raiz do repositório:

```bash
sudo bash install-control.sh
```

O instalador lê a identidade e o domínio de `config/site.php`, captura a versão e o SHA-256 do Core XLXD que já está instalado e cria a área:

```text
https://SEU-DOMINIO/controle/
```

## Usuário e senha

**Nenhum usuário e nenhuma senha são distribuídos pelo GitHub.**

Durante a instalação:

1. o operador escolhe o nome de usuário;
2. digita a senha sem ela aparecer na tela;
3. repete a senha para confirmação;
4. somente `password_hash()` é salvo em `/etc/xlx-modern-control/config.php`.

A senha não é escrita no repositório, no webroot nem no relatório final.

Para automação controlada também é possível fornecer, apenas no processo local:

```bash
sudo -E env \
  XLX_CONTROL_USERNAME='operador' \
  XLX_CONTROL_PASSWORD='SENHA_LOCAL' \
  bash install-control.sh
```

Evite gravar senha em scripts, histórico do shell, arquivos de CI ou repositórios públicos.

## Segurança

O Controle usa:

- sessão com cookie `Secure`, `HttpOnly` e `SameSite=Strict`;
- CSRF para ações autenticadas;
- bloqueio temporário após tentativas repetidas de login;
- `X-Robots-Tag: noindex` e cabeçalhos defensivos;
- confirmação de senha antes do reinício;
- helper privilegiado sem terminal web e sem comando arbitrário;
- `sudoers` limitado a cinco ações fixas: `status`, `listeners`, `logs`, `backups` e `restart`;
- verificação do SHA-256 e da versão do Core antes e depois de reiniciar o XLXD.

## O que aparece no Controle

- estado do serviço XLXD;
- versão, SHA, PID e quantidade de processos;
- estações conectadas e TX ativa quando a API fornecer esses dados;
- testes HTTP/API;
- listeners UDP;
- logs recentes;
- backups recentes;
- reinício protegido somente do serviço XLXD.

## Arquivos locais

```text
/etc/xlx-modern-control/config.php
/etc/xlx-modern-control/helper.conf
/var/lib/xlx-modern-control/
/usr/local/sbin/xlx-modern-control-helper
/etc/sudoers.d/xlx-modern-control
```

A pasta `controle/` é instalada dentro do dashboard configurado.

## Pré-validação

```bash
sudo bash install-control.sh --check
```

Esse modo valida sintaxe e invariantes de segurança sem instalar a área de controle.
