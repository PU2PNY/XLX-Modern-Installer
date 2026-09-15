# XLX Modern Installer v2 — Especificação funcional

Esta branch contém a nova geração do instalador nativo e modular.

## Objetivo

Executar, em uma VPS Debian 12 limpa, a preparação do sistema, instalação do XLXD, XLX Echo, painel moderno, HTTPS opcional, firewall, validações, backup e relatório final.

## Idiomas

- Português (pt-BR)
- English (en)

## Modos

1. Instalação completa recomendada
2. Instalação personalizada
3. Somente verificar a VPS
4. Instalar somente o painel
5. Reparar instalação existente

## Perguntas obrigatórias e respectivas explicações

### Número do refletor

Solicita três dígitos e forma o identificador `XLXnnn`.

### Nome público

Nome exibido no cabeçalho, título da página e metadados.

### Descrição

Texto curto que explica a finalidade do refletor.

### Domínio

Domínio sem protocolo, por exemplo `xlx000.example.org`. É usado para Apache, painel e HTTPS.

### Indicativo do responsável

Indicativo do sysop responsável pela administração.

### E-mail

Contato administrativo e, quando aplicável, cadastro do certificado HTTPS.

### Localização e país

Usados apenas para identificação pública quando o administrador permitir.

### Fuso horário

O instalador detecta o fuso atual, mostra a hora correspondente e permite manter ou selecionar outro fuso válido.

### Protocolos

Cada protocolo deve ser explicado antes da escolha:

- D-STAR
- DMR
- C4FM/YSF
- NXDN
- P25
- M17

Somente protocolos realmente suportados pela versão instalada devem ser oferecidos.

### Módulos

O administrador informa os módulos, por exemplo `A,B,C,D,E`, e pode fornecer uma descrição para cada um.

### XLX Echo

Pergunta se o serviço de teste de áudio deve ser instalado e em qual módulo funcionará.

### Painel moderno

Pergunta se o dashboard deve ser instalado e quais dados públicos serão exibidos.

### HTTPS

Valida DNS, IP e Apache antes de tentar emitir certificado.

### Firewall e segurança

Permite somente as portas necessárias aos protocolos escolhidos, preservando o acesso SSH.

## Segurança operacional

- Sem telemetria
- Backup preventivo
- Resumo antes de alterar o sistema
- Confirmação explícita antes da instalação
- Logs separados
- Validação pós-instalação
- Rollback documentado
- Sem sobrescrever instalação ativa

## Arquitetura planejada

```text
install-v2.sh
modules/v2/00-language.sh
modules/v2/05-ui.sh
modules/v2/10-preflight.sh
modules/v2/20-questionnaire.sh
modules/v2/30-config.sh
modules/v2/40-system-update.sh
modules/v2/50-dependencies.sh
modules/v2/60-xlxd.sh
modules/v2/70-xlxecho.sh
modules/v2/80-dashboard.sh
modules/v2/85-apache-https.sh
modules/v2/90-security.sh
modules/v2/95-validation.sh
modules/v2/99-report.sh
```

## Estado

Esta branch é de desenvolvimento. Não deve ser usada em produção antes de testes completos em uma VPS Debian 12 descartável.
