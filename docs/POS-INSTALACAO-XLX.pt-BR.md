# Pós-instalação do XLX: YSF, HTTPS, validação e tarefas opcionais

[🇺🇸 English version](XLX-POST-INSTALL.en.md) • [Voltar ao índice](README.md)

Depois de instalar o XLX no Debian 12, algumas etapas podem ser necessárias conforme os protocolos e serviços escolhidos. Este guia reúne as tarefas opcionais mais úteis sem pressupor que todo refletor use a mesma arquitetura.

## 1. Validar os serviços principais

```bash
sudo systemctl status xlxd.service --no-pager
sudo systemctl status apache2.service --no-pager
```

Se XLXEcho estiver instalado:

```bash
sudo systemctl status xlxecho.service --no-pager
```

## 2. Validar o Apache

```bash
sudo apache2ctl configtest
```

## 3. Conferir portas em escuta

```bash
sudo ss -lntup
```

Compare o resultado com os protocolos realmente habilitados. Consulte também [Firewall e portas do XLX](FIREWALL-PORTAS-XLX.pt-BR.md).

## 4. Configurar HTTPS manualmente

Se o instalador não configurou HTTPS automaticamente:

1. confirme que o domínio resolve para o IP correto;
2. confirme TCP 80 e 443 no firewall/NAT;
3. valide o Apache;
4. utilize o assistente oficial do [Certbot](https://certbot.eff.org/).

Antes de executar o Certbot:

```bash
getent hosts seu-dominio.example
sudo apache2ctl configtest
sudo ss -lntp | grep -E ':(80|443)\b'
```

## 5. Registro/publicação de YSF

Se sua instalação utiliza um serviço YSF que precisa ser publicado em diretórios compatíveis, consulte:

- [DVRef](https://dvref.com/)

Confirme antes se o tipo de registro é compatível com a arquitetura utilizada pelo seu XLX/YSF. Nem toda implantação XLX precisa do mesmo cadastro.

## 6. XLXEcho / teste de áudio

Se você usa um serviço de eco/parrot, consulte:

- [narspt/XLXEcho](https://github.com/narspt/XLXEcho)

Valide o serviço depois da instalação:

```bash
systemctl is-active xlxecho
sudo systemctl status xlxecho.service --no-pager
```

## 7. Configurar o idioma do dashboard

O XLX Modern Dashboard pode ser instalado em:

```text
pt-BR  en  es  fr  de  it
```

Exemplo em Inglês:

```bash
sudo bash modules/60-dashboard-modern.sh --lang=en
```

Exemplo em Espanhol:

```bash
sudo bash modules/60-dashboard-modern.sh --lang=es
```

Na instalação completa:

```bash
sudo bash install.sh --lang=en
```

## 8. Fazer uma cópia de segurança depois de validar tudo

Quando o servidor estiver confirmado como funcional, registre um backup pós-instalação de acordo com sua política local. Preserve especialmente:

```text
/xlxd/
/etc/systemd/system/xlxd.service
/etc/systemd/system/xlxecho.service
/etc/apache2/
/var/www/html/
```

## 9. Documentar a instalação

Anote:

- identificador do refletor;
- domínio;
- IP público;
- módulos habilitados;
- protocolos habilitados;
- portas utilizadas;
- serviços opcionais;
- versão/commit do instalador;
- data do último backup válido.

Não publique senhas, tokens, chaves privadas ou bancos reais de usuários.

## 10. Verificação rápida final

```bash
systemctl is-active xlxd
systemctl is-active apache2
sudo apache2ctl configtest
sudo ss -lntup
```

## Documentação relacionada

- [Instalar XLX no Debian 12](INSTALACAO-XLX-DEBIAN-12.pt-BR.md)
- [Atualizar e recuperar XLX](ATUALIZAR-RECUPERAR-XLX.pt-BR.md)
- [Firewall e portas](FIREWALL-PORTAS-XLX.pt-BR.md)
- [Arquivos e logs](ARQUIVOS-LOGS-XLX.pt-BR.md)
- [Internacionalização do dashboard](INTERNATIONALIZATION.md)

## Termos relacionados

pós instalação XLX, registrar YSF reflector, configurar HTTPS XLX, Certbot XLX, XLXEcho, parrot XLX, atualizar painel XLX, idioma dashboard XLX, Debian 12 refletor radioamador.
