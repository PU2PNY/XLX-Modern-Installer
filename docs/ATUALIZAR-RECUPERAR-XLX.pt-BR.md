# Como atualizar, diagnosticar e recuperar um servidor XLX

[🇺🇸 English version](UPDATE-RECOVER-XLX.en.md) • [Voltar ao índice](README.md)

Este guia reúne procedimentos seguros para **atualizar o XLX Modern Installer**, atualizar somente o dashboard, diagnosticar falhas do XLXD e preparar uma recuperação com backup e rollback.

## Atualizar o repositório

```bash
cd /usr/src/XLX-Modern-Installer
git status
git pull --ff-only
```

Depois:

```bash
sudo bash install.sh --check
```

Em um servidor XLXD já instalado, não execute a instalação completa apenas porque o Git foi atualizado.

## Atualizar ou reinstalar somente o dashboard

```bash
cd /usr/src/XLX-Modern-Installer
sudo bash modules/60-dashboard-modern.sh
```

O painel possui rotina separada do núcleo XLXD e cria backup quando encontra dashboard existente no destino.

## Diagnóstico do XLXD

### Estado do serviço

```bash
sudo systemctl status xlxd.service --no-pager
```

### Logs recentes

```bash
sudo journalctl -u xlxd.service -n 100 --no-pager
```

### Logs ao vivo

```bash
sudo journalctl -u xlxd.service -f
```

### Configuração systemd

```bash
sudo systemctl cat xlxd.service
```

### Portas em escuta

```bash
sudo ss -lntup
```

### Processo

```bash
ps aux | grep '[x]lxd'
```

### Apache

```bash
sudo apache2ctl configtest
sudo systemctl status apache2.service --no-pager
```

## Backup antes de corrigir

Preserve pelo menos:

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

O diretório padrão de backups do projeto é:

```text
/var/backups/xlx-reflector
```

## Método recomendado de recuperação

```text
1. DIAGNÓSTICO
2. INVENTÁRIO
3. BACKUP VERIFICADO
4. IDENTIFICAR A CAUSA
5. ALTERAÇÃO MÍNIMA
6. VALIDAR SERVIÇOS
7. VALIDAR DASHBOARD
8. MANTER ROLLBACK DISPONÍVEL
```

## Quando não reinstalar

Evite reinstalação completa quando o problema estiver restrito a:

- serviço systemd;
- endereço IP incorreto;
- Apache;
- dashboard;
- permissões;
- firewall;
- configuração local;
- banco ou arquivo específico.

A reinstalação sem diagnóstico pode apagar informações úteis para encontrar a causa original.

## Servidor XLX não aparece na lista pública

Verifique primeiro:

1. se `xlxd.service` está ativo;
2. o IP usado em `ExecStart`;
3. DNS e conectividade externa;
4. portas e firewall;
5. logs do XLXD;
6. Calling Home e configurações relacionadas ao ambiente instalado.

Não altere várias causas possíveis ao mesmo tempo. Faça uma alteração por vez e valide o resultado.

## Termos relacionados

Atualizar XLX reflector, atualizar XLXD, reparar servidor XLX, recuperar refletor XLX, XLX não inicia, XLX não aparece na lista, backup XLXD, reinstalar dashboard XLX, troubleshooting XLX Debian 12.
