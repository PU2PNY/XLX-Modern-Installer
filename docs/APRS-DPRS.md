# APRS / D-PRS opcional

O APRS/D-PRS não faz parte do núcleo do XLXD nem do código-fonte interno deste repositório.

A implementação é mantida separadamente em `PU2PNY/XLX-APRS-DPRS` para permitir:

- instalação opcional junto com um XLX novo;
- instalação independente em um XLX Modern existente;
- atualização e backup próprios;
- isolamento de bancos, contas, configuração e serviço systemd;
- evolução do gateway sem acoplar o ciclo de release do painel principal.

## Versão pinada

O integrador `modules/67-aprs-dprs.sh` usa exatamente:

```text
repositório : PU2PNY/XLX-APRS-DPRS
commit      : 771abaa0c1ea662f33f3fa0c4a59ec712b1e4fcb
install.sh  : 0c5c26adbf9b54fe803e3cbaf2ddc17e4ba737f7c9f3b5606231b67c9a9403f9
manifesto   : b4a0e8f1e1fec7e894cff4c61b18c5891122278ecf5f2f666e5398b361c808d4
```

O instalador principal nunca executa `main` remotamente de forma cega e não usa `curl | bash`.

Antes de chamar o instalador independente, o módulo:

1. baixa o tarball do commit fixado por HTTPS;
2. rejeita caminhos inseguros no arquivo;
3. valida o SHA-256 de `install.sh`;
4. valida o SHA-256 de `SOURCE-MANIFEST.sha256`;
5. executa `sha256sum -c` no conjunto distribuído;
6. valida Bash e, quando disponíveis, PHP e Python;
7. armazena a fonte validada em diretório versionado sob `/opt/xlx-modern-installer/vendor/`.

## Instalação junto com o XLX

```bash
sudo bash install.sh --with-aprs-dprs
```

Também é possível executar `install.sh` sem essa opção. Na instalação real ele pergunta se APRS/D-PRS deve ser incluído; responder não mantém a instalação base inalterada.

Para desabilitar a pergunta:

```bash
sudo bash install.sh --without-aprs-dprs
```

## Instalação posterior

O repositório `XLX-APRS-DPRS` possui `install.sh` próprio e pode ser instalado depois sobre um dashboard compatível.

Os caminhos operacionais do componente independente são:

```text
/opt/xlx-aprs-dprs
/etc/xlx-aprs-dprs
/var/lib/xlx-aprs-dprs
xlx-aprs-dprs.service
<dashboard>/aprs-dprs/
```

## Migração de instalações legadas

Uma instalação que ainda utiliza `xlx026-digital-lab.service` não é convertida automaticamente. O instalador independente aborta se esse serviço legado estiver ativo para impedir dois gateways concorrentes no mesmo módulo.

A migração deve ser uma operação separada, com backup dos bancos/configuração, mapeamento de contas, janela controlada e rollback.

## Dados proibidos no repositório

Nunca versionar:

- `config.json` real;
- bancos SQLite reais;
- contas e hashes de senha;
- tokens, cookies ou sessões;
- passcodes APRS reais;
- chaves privadas;
- logs e backups de produção.
