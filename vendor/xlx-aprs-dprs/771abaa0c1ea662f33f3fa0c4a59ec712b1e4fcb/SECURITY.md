# Segurança

## Segredos e dados persistentes

Não versionar:

- `/etc/xlx-aprs-dprs/config.json` de produção;
- bancos de contas ou de atividade;
- credenciais iniciais ou atuais;
- tokens de sessão;
- arquivos de backup;
- chaves privadas.

O arquivo `config/config.example.json` contém apenas valores neutros e deve permanecer sem credenciais reais.

## Permissões

Padrão de instalação:

- configuração: `root:www-data`, modo `0640`;
- diretório de estado: `www-data:www-data`, modo `0750`;
- PHP do módulo: `root:www-data`, modo `0640`;
- assets públicos: `0644`;
- gateway Python: `root:root`, modo `0755`.

## Web

A API de operador:

- exige mesma origem para POST;
- usa cookie `HttpOnly`, `Secure` e `SameSite=Strict`;
- usa sessão própria;
- protege ações autenticadas com CSRF;
- limita payload;
- aplica rate limit para ações sensíveis.

## Atualizações

Não execute instaladores diretamente de uma URL com `curl | bash`.

Use artefato/commit fixado, confira SHA-256 e sintaxe antes da execução.
