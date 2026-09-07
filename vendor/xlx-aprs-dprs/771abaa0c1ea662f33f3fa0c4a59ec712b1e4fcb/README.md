# XLX-APRS-DPRS

Módulo opcional APRS / D-PRS para instalações XLX com o painel moderno.

Este repositório mantém o gateway de dados separado do core do XLXD. A instalação cria:

- um cliente DExtra independente para observar o módulo de dados (por padrão, módulo B);
- conexão opcional ao APRS-IS;
- decodificação D-PRS / GPS-A e posições APRS;
- página web isolada em `aprs-dprs/`;
- contas locais para operador, colaborador e usuário;
- envio APRS pelo painel restrito à função ADMIN;
- serviço systemd próprio;
- bancos SQLite próprios e fora do DocumentRoot.

## Segurança e isolamento

O instalador **não recompila nem modifica o XLXD**.

Ele também não copia bancos, contas, tokens, passcodes ou configurações de outra instalação. Uma instalação nova começa com estado próprio em:

```text
/var/lib/xlx-aprs-dprs
```

A configuração fica em:

```text
/etc/xlx-aprs-dprs/config.json
```

O gateway fica em:

```text
/opt/xlx-aprs-dprs
```

A interface é instalada dentro do painel detectado:

```text
<dashboard>/aprs-dprs/
```

O serviço é:

```text
xlx-aprs-dprs.service
```

## Requisitos

Base validada para o projeto:

- Debian 12;
- Python 3 com `sqlite3` da biblioteca padrão;
- PHP com `pdo_sqlite`;
- systemd;
- `rsync`;
- painel XLX Modern compatível, contendo `index.php` e `assets/app.css`.

O gateway Python não exige pacote `pip`.

## Pré-validação sem alterar nada

```bash
sudo bash install.sh \
  --dashboard-dir /var/www/html/xlx-dashboard \
  --reflector-name XLX000 \
  --client-callsign PY2ABC \
  --check
```

## Instalação interativa

```bash
sudo bash install.sh
```

O instalador tenta detectar:

```text
/var/www/html/xlx-dashboard
/var/www/html/xlxd
```

Também é possível informar outro caminho com `--dashboard-dir`.

## Instalação não interativa

Exemplo com leitura do módulo B, APRS-IS e TX APRS:

```bash
sudo bash install.sh \
  --dashboard-dir /var/www/html/xlx-dashboard \
  --reflector-name XLX000 \
  --reflector-host 127.0.0.1 \
  --client-callsign PY2ABC \
  --aprs-login PY2ABC-10 \
  --enable-aprs-tx \
  --activate \
  --non-interactive
```

Quando `--enable-aprs-tx` é usado, o gateway grava `passcode: "auto"` no arquivo local e calcula o passcode APRS-IS em runtime. Nenhum passcode real precisa ser versionado.

## Conta administrativa inicial

Quando `--client-callsign` é informado em uma instalação nova, o instalador usa esse indicativo para criar a primeira conta ADMIN.

A senha aleatória **não é impressa na tela**. Ela é gravada somente em um arquivo root-only:

```text
/root/xlx-aprs-dprs-admin-AAAAMMDD_HHMMSS.txt
```

Depois do primeiro acesso, troque a senha pelo próprio painel.

## Backup

```bash
sudo bash backup.sh
```

Os bancos SQLite são copiados usando a API de backup online do SQLite, evitando uma cópia inconsistente do arquivo enquanto o gateway está ativo.

## Atualização

A atualização preserva:

- `/etc/xlx-aprs-dprs/config.json`;
- `accounts.sqlite`;
- `digital-lab.sqlite`;
- demais dados persistentes.

Antes de publicar o novo código, `update.sh` cria backup.

```bash
sudo bash update.sh
```

## Remoção

Por padrão, remove código, página e serviço, mas preserva configuração e bancos:

```bash
sudo bash uninstall.sh
```

Para remover também dados persistentes, após backup:

```bash
sudo bash uninstall.sh --purge-data
```

## Integração com XLX-Modern-Installer

O repositório principal deve tratar este componente como opcional.

A integração recomendada é:

1. o instalador principal pergunta se APRS/D-PRS deve ser instalado;
2. baixa um **commit/tag fixado**, nunca `main` de forma cega;
3. valida o SHA-256 do instalador;
4. executa `bash -n`;
5. chama este `install.sh` com o diretório do painel e os dados do refletor;
6. se a opção for ignorada, o XLX continua instalando normalmente.

A integração no repositório principal só deve ser fixada depois de existir uma release/commit revisado deste repositório.

## Migração de instalações antigas

O instalador aborta se detectar o serviço legado `xlx-legacy-digital-lab.service` ativo.

Isso é intencional: executar dois gateways em paralelo no mesmo módulo pode duplicar conexões e atividade APRS.

Migrações de uma instalação legada devem usar procedimento controlado próprio, com backup, validação e rollback.

## Dados que nunca devem ser enviados ao GitHub

```text
config.json real
*.sqlite
*.sqlite-wal
*.sqlite-shm
operator-rate.json
public.json
credenciais administrativas
tokens
cookies/sessões
backups
chaves privadas
```

Veja também `SECURITY.md` e `docs/ARCHITECTURE.md`.
