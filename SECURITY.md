# Security Policy / Política de Segurança

Security is especially important for this project because an XLX reflector is normally deployed on an Internet-facing server and may handle operational configuration, logs and user-related data.

## 🇧🇷 Português

### Nunca publique no repositório

- senhas;
- tokens de API;
- chaves SSH privadas;
- certificados ou chaves TLS privadas;
- bancos reais de usuários;
- backups de produção;
- arquivos `.env` com credenciais;
- logs contendo dados pessoais ou informações operacionais sensíveis;
- segredos de Calling Home;
- configuração real de produção que exponha credenciais;
- arquivos de autenticação de serviços externos;
- chaves/arquivos de licença de software proprietário;
- `libStereoTool*.so`, pacotes Stereo Tool ou outros binários proprietários fornecidos pelo administrador;
- headers/SDK proprietários sem autorização expressa de redistribuição.

### Como relatar uma vulnerabilidade

Não publique credenciais ou detalhes exploráveis em uma issue pública.

Quando o repositório estiver público, prefira **Private vulnerability reporting / Security Advisories do GitHub**, quando habilitado. Se esse recurso não estiver disponível, entre em contato com o mantenedor pelo perfil oficial do projeto antes de divulgar detalhes técnicos sensíveis.

Inclua, quando possível:

1. componente afetado;
2. versão/commit;
3. impacto;
4. passos mínimos para reproduzir;
5. evidências sem dados pessoais;
6. sugestão de correção, se houver.

### Princípios de segurança do instalador

O projeto procura manter:

- pré-validação antes da instalação;
- bloqueio contra sobrescrita de uma instalação XLXD ativa;
- backup preventivo;
- validação de commit e SHA-256 da base técnica revisada;
- logs de instalação;
- menor exposição possível de portas;
- separação entre núcleo e dashboard;
- rollback como requisito de manutenção.

### Upload de DSP/binário proprietário

Upload de biblioteca executável deve ser tratado como código não confiável até validação. Para Stereo Tool, a política é:

- upload futuro somente por privilégio elevado;
- artifact fora do webroot;
- quarentena antes de qualquer load;
- limites de tamanho e quantidade;
- ZIP sem `../`, caminho absoluto, symlink ou special file;
- SHA-256 como identidade interna, sem chamar hash local de assinatura do fornecedor;
- inspeção ELF/arquitetura/GLIBC/símbolos antes do sandbox;
- processo de sandbox/worker separado de XLXD/xuvd/PHP;
- worker sem `AF_INET`/`AF_INET6` e sem web UI nativa do fornecedor;
- nunca registrar chave/licença em logs/auditoria.

## 🇺🇸 English

### Never commit

- passwords;
- API tokens;
- SSH private keys;
- private TLS certificates or keys;
- real user databases;
- production backups;
- credential-bearing `.env` files;
- logs containing personal or sensitive operational data;
- Calling Home secrets;
- production configuration exposing credentials;
- authentication files for external services;
- proprietary software license keys/files;
- administrator-supplied `libStereoTool*.so`, Stereo Tool packages or other proprietary binaries;
- proprietary SDK headers unless redistribution is explicitly permitted.

### Reporting a vulnerability

Do not publish credentials or directly exploitable details in a public issue.

Once the repository is public, prefer **Private vulnerability reporting / Security Advisories** when enabled. If private reporting is unavailable, contact the project maintainer through the official GitHub profile before disclosing sensitive technical details publicly.

When possible, include:

1. affected component;
2. version/commit;
3. impact;
4. minimal reproduction steps;
5. evidence without personal data;
6. suggested remediation, if available.

## Supported branch

The actively maintained branch is currently:

```text
main
```

Security fixes should be applied to the maintained branch and documented in the project changelog when they affect users.
