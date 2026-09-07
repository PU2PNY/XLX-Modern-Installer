# Changelog

## 1.1.1 — 2026-08-13

- separa o gateway APRS/D-PRS do repositório principal do XLX Modern Installer;
- mantém código, configuração, estado SQLite e serviço systemd em caminhos próprios;
- adiciona instalação, atualização, backup e remoção independentes;
- cria banco de autenticação vazio em instalações novas, sem copiar contas da produção;
- protege configuração, bancos, tokens, sessões, chaves e backups via `.gitignore` e validação;
- bloqueia coexistência acidental com o serviço legado `xlx-legacy-digital-lab.service`;
- permite integração opcional pelo XLX Modern Installer usando commit e SHA-256 fixados;
- adiciona validação automática de Bash, PHP, JavaScript, Python, manifesto e permissões executáveis.
