# Indicativos, base de usuários e certificados no XLX Modern Installer

Este guia explica os recursos adicionados ao instalador oficial para manter dados de operadores e emitir certificados de participação de forma genérica em qualquer refletor XLX.

## 1. O que foi adicionado

A instalação do dashboard agora também prepara dois recursos:

1. **Diretório persistente de indicativos** — permite corrigir nome/localização de um operador, relacionar indicativo antigo com indicativo novo e atualizar a base principal do XLX com backup e rollback.
2. **Sistema de certificados** — verifica transmissões registradas, emite um certificado por campanha/indicativo, cria QR Code de validação e usa os dados configurados no refletor atual.

Esses recursos são instalados por `modules/60-dashboard-modern.sh` depois do dashboard principal.

## 2. Dados usados pela instalação

O dashboard e os certificados usam a mesma configuração do refletor. Entre os dados informados durante a instalação estão:

- identificador do refletor, por exemplo `XLX724`;
- título/nome exibido;
- descrição;
- indicativo do responsável;
- cidade/região;
- país;
- domínio;
- e-mail de contato;
- YSF ID;
- TG DMR;
- idioma do painel;
- timezone do servidor;
- aniversário opcional do refletor em `MM-DD`.

A configuração instalada fica em:

```text
/var/www/html/xlx-dashboard/config/site.php
```

O template público continua genérico. Portanto um servidor configurado como `XLX724` não herda automaticamente nome, domínio ou identidade do XLX026.

## 3. Diretório persistente de indicativos

### Para que serve

A base principal de operadores continua sendo:

```text
/xlxd/users_db/users.db
```

O XLX Modern Installer adiciona uma segunda base, somente para correções locais:

```text
/var/lib/xlx-user-directory/overrides.db
```

Essa separação evita que uma correção manual seja perdida quando a base principal for atualizada ou reconstruída.

### Ferramenta de administração

Depois da instalação, o comando é:

```bash
sudo xlx-user-directory
```

Ajuda:

```bash
sudo xlx-user-directory --help
```

### Consultar um indicativo

```bash
sudo xlx-user-directory lookup PU2PNY
```

A saída informa se o resultado veio da base principal ou da camada de correção.

### Corrigir nome e localização

```bash
sudo xlx-user-directory set PU2PNY "Nome do operador" "Cidade, Estado"
```

A correção fica em `overrides.db` e é consultada pelo painel antes dos dados padrão.

### Relacionar indicativo antigo com o novo

```bash
sudo xlx-user-directory alias PU2OLD PU2NEW
```

Isso registra a relação `PU2OLD -> PU2NEW` no diretório local.

**Importante:** o alias não altera o indicativo que o rádio transmite pelo ar. Se o equipamento continuar configurado com `PU2OLD`, o protocolo continua recebendo `PU2OLD`. O alias serve para administração e resolução de dados; a configuração do rádio/hotspot precisa ser corrigida separadamente.

### Remover uma correção local

```bash
sudo xlx-user-directory delete PU2PNY
```

### Verificar integridade das bases

```bash
sudo xlx-user-directory check
```

O comando executa `PRAGMA integrity_check` nas bases disponíveis.

### Atualizar/reconstruir a base principal

```bash
sudo xlx-user-directory refresh
```

O fluxo é:

```text
BACKUP DA BASE ATUAL
        ↓
VALIDAÇÃO DO BACKUP
        ↓
EXECUÇÃO DO GERADOR DO XLX
        ↓
PRAGMA integrity_check
        ↓
OK → mantém a nova base
ERRO → restaura a base anterior
```

As correções locais ficam separadas e não são apagadas pelo `refresh`.

### Backup da base principal

Os backups criados pelo `refresh` ficam em:

```text
/var/backups/xlx-reflector/callsign-directory/
```

## 4. Como o painel usa as correções

A API do dashboard consulta a camada de overrides para complementar:

- nome do operador;
- localização;
- resolução administrativa de alias.

Isso afeta principalmente as páginas:

- Ao Vivo;
- Conectados;
- histórico das últimas 24 horas;
- dados utilizados pelo sistema de certificados.

O painel preserva o indicativo realmente registrado na transmissão para não falsificar dados de protocolo.

## 5. Sistema de certificados

### Para que serve

O certificado registra a participação de um radioamador que realmente transmitiu no refletor durante a campanha ativa.

O sistema não libera certificado apenas porque um indicativo existe na base. A elegibilidade depende de transmissão encontrada nos logs do XLX dentro do período da campanha.

### Página do certificado

Depois da instalação:

```text
https://SEU-DOMINIO/certificado.php
```

A página também é adicionada ao menu do dashboard.

### Fluxo para o usuário

1. O radioamador abre `certificado.php`.
2. Digita o indicativo.
3. O sistema verifica transmissões elegíveis.
4. Se houver atividade, exibe a prévia.
5. O usuário escolhe **Emitir certificado**.
6. A emissão é registrada.
7. O certificado recebe ID e QR Code.
8. O usuário pode imprimir ou salvar como PDF pelo navegador.

### Emissão única

A combinação abaixo é única:

```text
campanha + indicativo
```

Se o operador tentar emitir novamente o mesmo certificado, o registro existente é recuperado em vez de criar uma segunda emissão.

### Onde ficam os registros

```text
/var/lib/xlx-certificates/emissoes.jsonl
```

Esse arquivo é dado operacional e **não deve ser publicado no GitHub**.

### Assinatura HMAC

Cada instalação cria uma chave privada local:

```text
/etc/xlx-certificates/hmac.key
```

Ela é usada para assinar a validação do certificado. A chave não faz parte do repositório e não deve ser compartilhada.

### QR Code

O QR Code é gerado localmente pelo utilitário `qrencode` e aponta para a página de validação do próprio domínio configurado no refletor.

Isso evita depender de um serviço externo de QR Code.

### Página de validação

```text
https://SEU-DOMINIO/certificado-validar.php?id=...&sig=...
```

O sistema compara o ID com o registro de emissão e valida a assinatura HMAC.

## 6. Campanhas automáticas

O motor possui campanhas genéricas e campanhas condicionadas ao país da instalação.

### Para qualquer país

- Certificado de participação diária;
- Dia Mundial do Radioamador — 18 de abril;
- semana de aniversário do refletor, quando a data é configurada.

### Somente quando o país configurado é Brasil

- Dia das Mães;
- Dia dos Pais;
- Independência do Brasil;
- Dia do Radioamador Brasileiro.

Por exemplo: um `XLX724` configurado com país `Portugal` não recebe automaticamente campanhas brasileiras.

## 7. Aniversário do refletor

Durante a instalação dos certificados pode ser informada uma data no formato:

```text
MM-DD
```

Exemplo:

```text
07-22
```

Também pode ser fornecida por variável de ambiente:

```bash
sudo XLX_REFLECTOR_ANNIVERSARY=07-22 bash modules/66-certificates.sh
```

## 8. Instalação completa

Em um servidor novo:

```bash
sudo bash install.sh --check
sudo bash install.sh
```

O fluxo oficial instala o núcleo XLX e depois executa o módulo do dashboard. O módulo do dashboard executa:

```text
Dashboard
   ↓
Pós-instalação do dashboard
   ↓
Diretório persistente de indicativos
   ↓
Certificados
```

## 9. Reinstalar somente o dashboard

```bash
cd /usr/src/XLX-Modern-Installer
sudo bash modules/60-dashboard-modern.sh
```

Isso também instala/verifica o diretório de indicativos e o módulo de certificados.

Os dados operacionais persistentes ficam fora da árvore do dashboard para que uma atualização de arquivos do painel não apague automaticamente:

- `overrides.db`;
- `emissoes.jsonl`;
- `hmac.key`.

## 10. O que deve entrar em backup

Além do backup normal do XLX, preserve:

```text
/var/lib/xlx-user-directory/
/var/lib/xlx-certificates/
/etc/xlx-certificates/
```

Sem `hmac.key`, certificados antigos podem deixar de validar após uma reconstrução completa do servidor. Portanto a chave HMAC deve fazer parte do backup privado de recuperação.

## 11. O que nunca publicar

Não coloque em commits, issues ou arquivos públicos:

- `/etc/xlx-certificates/hmac.key`;
- `emissoes.jsonl` real;
- `users.db` real;
- `overrides.db` real;
- logs de produção contendo dados sensíveis;
- backups completos do servidor;
- senhas, tokens ou chaves privadas.

## 12. Resumo dos comandos

```bash
# Ver ajuda
sudo xlx-user-directory --help

# Consultar
sudo xlx-user-directory lookup PU2PNY

# Corrigir nome/localização
sudo xlx-user-directory set PU2PNY "Nome" "Cidade, Estado"

# Relacionar indicativo antigo e novo
sudo xlx-user-directory alias PU2OLD PU2NEW

# Remover correção
sudo xlx-user-directory delete PU2PNY

# Verificar bases
sudo xlx-user-directory check

# Atualizar a base principal com backup/rollback
sudo xlx-user-directory refresh

# Reinstalar dashboard + recursos integrados
sudo bash modules/60-dashboard-modern.sh
```

## 13. Caminhos principais

| Recurso | Caminho |
|---|---|
| Base principal de usuários | `/xlxd/users_db/users.db` |
| Correções persistentes | `/var/lib/xlx-user-directory/overrides.db` |
| Utilitário | `/usr/local/sbin/xlx-user-directory` |
| Backups da base | `/var/backups/xlx-reflector/callsign-directory/` |
| Dashboard | `/var/www/html/xlx-dashboard/` |
| Página de certificados | `/var/www/html/xlx-dashboard/certificado.php` |
| Registros emitidos | `/var/lib/xlx-certificates/emissoes.jsonl` |
| Chave HMAC | `/etc/xlx-certificates/hmac.key` |

---

O objetivo desses recursos é permitir que cada instalação do **XLX Modern Installer** use a identidade e os dados do próprio refletor, mantendo correções locais e certificados separados dos arquivos versionados do projeto.