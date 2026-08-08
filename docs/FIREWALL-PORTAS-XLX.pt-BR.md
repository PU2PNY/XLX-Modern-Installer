# Firewall e portas do XLX: quais portas abrir no Debian 12

[🇺🇸 English version](XLX-FIREWALL-PORTS.en.md) • [Voltar ao índice](README.md)

Este guia explica **quais portas um servidor XLX pode utilizar**, como conferir o que está realmente em escuta e como evitar abrir serviços desnecessários no firewall.

> Regra principal: **abra somente as portas necessárias para os protocolos e recursos que seu refletor realmente utiliza**.

## Portas comuns em instalações XLX

| Porta | Transporte | Uso típico |
|---:|:---:|---|
| 22 | TCP | Administração SSH |
| 80 | TCP | HTTP e validação/renovação de certificados |
| 443 | TCP | HTTPS do dashboard |
| 8080 | TCP | RepNet, quando utilizado |
| 20001-20005 | TCP/UDP | DPlus, conforme a configuração |
| 40001 | TCP | Icom G3, quando aplicável |
| 8880 | UDP | DMR+ DMO |
| 10001 | UDP | Interface JSON do XLXD |
| 10002 | UDP | XLX interlink |
| 10100 | UDP | Controlador AMBE |
| 10101-10199 | UDP | Transcodificação AMBE |
| 12345-12346 | UDP | Icom Terminal presence/request |
| 21110 | UDP | Yaesu IMRS |
| 30001 | UDP | DExtra |
| 30051 | UDP | DCS |
| 40000 | UDP | Icom Terminal DV |
| 42000 | UDP | YSF, valor comum/configurável |
| 62030 | UDP | MMDVM/DMR |

Nem toda instalação utiliza todas essas portas. A configuração real depende do XLXD, serviços opcionais e protocolos habilitados.

## Como conferir as portas realmente abertas

```bash
sudo ss -lntup
```

Para filtrar processos relacionados ao XLX:

```bash
sudo ss -lntup | grep -Ei 'xlx|apache|php|ssh'
```

## UFW

Veja primeiro a configuração atual:

```bash
sudo ufw status verbose
```

Nunca aplique uma lista inteira de regras apenas porque ela aparece em uma documentação. Confirme quais serviços serão utilizados e mantenha acesso administrativo antes de alterar o firewall.

## NAT e encaminhamento de portas

Se o servidor está atrás de NAT, CGNAT, roteador ou firewall externo, liberar a porta no Debian pode não ser suficiente. Verifique também:

1. IP público acessível;
2. encaminhamento de portas no roteador/firewall;
3. regras do provedor/VPS;
4. DNS apontando para o endereço correto;
5. firewall local;
6. processo realmente escutando na porta esperada.

## Diagnóstico de uma porta específica

Exemplo para a porta 62030/UDP:

```bash
sudo ss -lunp | grep ':62030'
```

Exemplo para HTTPS:

```bash
sudo ss -lntp | grep ':443'
```

## Antes de mudar o firewall

```text
SERVIÇO → PORTA ESPERADA → PROCESSO EM ESCUTA → FIREWALL LOCAL → FIREWALL EXTERNO/NAT → TESTE
```

Esse fluxo reduz alterações desnecessárias e evita confundir falha de aplicação com bloqueio de rede.

## Documentação relacionada

- [Instalar XLX no Debian 12](INSTALACAO-XLX-DEBIAN-12.pt-BR.md)
- [Atualizar e recuperar XLX](ATUALIZAR-RECUPERAR-XLX.pt-BR.md)
- [Arquivos e logs do XLX](ARQUIVOS-LOGS-XLX.pt-BR.md)
- [Etapas pós-instalação](POS-INSTALACAO-XLX.pt-BR.md)

## Termos relacionados

portas XLX, firewall XLX, portas XLXD, liberar porta D-STAR, porta DMR XLX, porta YSF XLX, Debian 12 firewall radioamador, XLX reflector ports, UFW XLXD.
