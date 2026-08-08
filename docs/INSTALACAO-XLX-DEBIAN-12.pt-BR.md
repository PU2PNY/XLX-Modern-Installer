# Como instalar um refletor XLX no Debian 12

[🇺🇸 English version](INSTALL-XLX-DEBIAN-12.en.md) • [Voltar ao índice](README.md)

Este guia mostra como instalar um **refletor XLX multiprotocolo** no Debian 12 usando o **XLX Modern Installer**. O fluxo é indicado para uma nova instalação em VPS ou servidor limpo.

## O que será instalado

A instalação prepara o ambiente para um refletor XLX com base XLXD e suporte aos protocolos configurados pelo projeto, incluindo D-STAR, DMR e C4FM/YSF, além do dashboard moderno e serviços auxiliares quando aplicáveis.

## Requisitos

- Debian 12;
- x86_64;
- root ou sudo;
- acesso à internet;
- DNS/FQDN para produção;
- IP público adequado ao ambiente;
- pelo menos 768 MB de RAM;
- pelo menos 4 GB livres em disco.

## 1. Atualizar o Debian e instalar Git

```bash
sudo apt update
sudo apt install -y git
```

## 2. Clonar o instalador

```bash
cd /usr/src
sudo git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
```

## 3. Executar a pré-validação

```bash
sudo bash install.sh --check
```

A pré-validação verifica sistema operacional, arquitetura, memória, disco, DNS, HTTPS, ferramentas necessárias e presença de uma instalação XLX ativa.

## 4. Executar a instalação completa

```bash
sudo bash install.sh
```

A instalação real exige confirmação explícita e cria backup preventivo quando existem caminhos relevantes para preservar.

## 5. Verificar serviços após a instalação

```bash
systemctl is-active xlxd
systemctl is-active apache2
systemctl is-active xlxecho
```

Para detalhes:

```bash
sudo systemctl status xlxd.service --no-pager
sudo journalctl -u xlxd.service -n 100 --no-pager
```

## Instalar ou reinstalar somente o dashboard

Se o servidor XLXD já estiver funcionando e você quiser apenas instalar ou reinstalar o painel moderno:

```bash
cd /usr/src/XLX-Modern-Installer
sudo bash modules/60-dashboard-modern.sh
```

Não use `install.sh` para tentar sobrescrever um XLXD ativo.

## Como confirmar que o servidor está respondendo

```bash
sudo ss -lntup
sudo systemctl cat xlxd.service
sudo apache2ctl configtest
```

## Problemas comuns

Antes de reinstalar qualquer componente, verifique:

1. `systemctl status xlxd`;
2. `journalctl -u xlxd -n 100`;
3. IP configurado no serviço;
4. firewall e portas;
5. existência do binário `/xlxd/xlxd`;
6. permissões e configurações locais;
7. Apache e dashboard separadamente.

## Próximos passos

Depois da instalação, consulte o guia de [atualização, diagnóstico e recuperação](ATUALIZAR-RECUPERAR-XLX.pt-BR.md).

## Termos relacionados

Como instalar XLX no Debian 12, instalar XLXD em VPS, servidor D-STAR, servidor DMR, servidor C4FM YSF, refletor digital radioamador, XLX dashboard, XLX reflector installer.
