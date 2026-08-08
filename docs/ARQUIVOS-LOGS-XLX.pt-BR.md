# Onde ficam os arquivos e logs do XLX no Debian 12

[🇺🇸 English version](XLX-FILES-LOGS.en.md) • [Voltar ao índice](README.md)

Este guia mostra os principais caminhos utilizados em uma instalação XLX para facilitar **backup, diagnóstico, atualização e recuperação**.

## Diretórios e arquivos principais

| Finalidade | Caminho típico |
|---|---|
| Núcleo XLXD | `/xlxd/` |
| Binário XLXD | `/xlxd/xlxd` |
| Banco/arquivos de usuários | `/xlxd/users_db/` |
| Calling Home | `/xlxd/callinghome.php` |
| Whitelist | `/xlxd/xlxd.whitelist` |
| Blacklist | `/xlxd/xlxd.blacklist` |
| Interlinks | `/xlxd/xlxd.interlink` |
| Terminais | `/xlxd/xlxd.terminal` |
| Serviço systemd XLXD | `/etc/systemd/system/xlxd.service` |
| Serviço XLXEcho | `/etc/systemd/system/xlxecho.service` |
| Apache | `/etc/apache2/` |
| Conteúdo web | `/var/www/html/` |
| Dashboard moderno | `/var/www/html/xlx-dashboard/` |
| Repositório local | `/usr/src/XLX-Modern-Installer/` |
| Área controlada do wrapper | `/opt/xlx-modern-installer/` |
| Backups preventivos | `/var/backups/xlx-reflector/` |
| Logs do instalador | `/var/log/xlx-reflector/installer/` |

Alguns caminhos podem variar conforme a base upstream, personalizações locais ou versão instalada.

## Encontrar arquivos relacionados ao XLX

```bash
sudo find /xlxd /usr/src /var/www/html /etc/systemd/system -maxdepth 3 \
  \( -iname '*xlx*' -o -iname '*dstar*' \) -print 2>/dev/null
```

## Ver o serviço XLXD real

```bash
sudo systemctl cat xlxd.service
```

Esse comando é importante porque mostra o `ExecStart` efetivamente usado pelo systemd.

## Status do serviço

```bash
sudo systemctl status xlxd.service --no-pager
```

## Logs recentes

```bash
sudo journalctl -u xlxd.service -n 100 --no-pager
```

## Logs ao vivo

```bash
sudo journalctl -u xlxd.service -f
```

## Procurar logs gravados em arquivo

```bash
sudo find /var/log /xlxd -maxdepth 3 -type f \
  \( -iname '*xlx*.log' -o -iname '*xlxd*.log' -o -iname '*.xml' \) \
  -print 2>/dev/null
```

## Arquivos que devem entrar em um backup antes de correções

Preserve, no mínimo, o que realmente existir no servidor:

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

## Validar o dashboard

```bash
sudo find /var/www/html/xlx-dashboard -type f -name '*.php' -print0 \
  | xargs -0 -r -n1 php -l
```

## Validar Apache

```bash
sudo apache2ctl configtest
sudo systemctl status apache2.service --no-pager
```

## Ver portas e processos

```bash
sudo ss -lntup
ps aux | grep '[x]lxd'
```

## Fluxo recomendado de diagnóstico

```text
ARQUIVOS → SERVIÇO SYSTEMD → LOGS → PROCESSO → PORTAS → APACHE/DASHBOARD → CORREÇÃO MÍNIMA
```

## Documentação relacionada

- [Instalação do XLX no Debian 12](INSTALACAO-XLX-DEBIAN-12.pt-BR.md)
- [Atualização e recuperação](ATUALIZAR-RECUPERAR-XLX.pt-BR.md)
- [Firewall e portas](FIREWALL-PORTAS-XLX.pt-BR.md)
- [Etapas pós-instalação](POS-INSTALACAO-XLX.pt-BR.md)

## Termos relacionados

arquivos XLX, logs XLXD, onde fica xlxd.service, backup XLX, callinghome.php XLX, whitelist XLX, blacklist XLX, recuperar refletor XLX, Debian 12 XLXD logs.
