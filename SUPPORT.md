# Support / Suporte

## 🇧🇷 Português

Antes de pedir ajuda, execute o diagnóstico somente leitura:

```bash
sudo bash scripts/health-check.sh
```

E consulte primeiro:

- [Instalação no Debian 12](docs/INSTALACAO-XLX-DEBIAN-12.pt-BR.md)
- [Atualização e recuperação](docs/ATUALIZAR-RECUPERAR-XLX.pt-BR.md)
- [Firewall e portas](docs/FIREWALL-PORTAS-XLX.pt-BR.md)
- [Arquivos e logs](docs/ARQUIVOS-LOGS-XLX.pt-BR.md)
- [Pós-instalação](docs/POS-INSTALACAO-XLX.pt-BR.md)

Ao abrir uma issue pública, informe:

1. versão do Debian;
2. arquitetura (`uname -m`);
3. commit do projeto (`git rev-parse HEAD`);
4. objetivo: nova instalação, dashboard, atualização ou recuperação;
5. mensagem de erro completa;
6. resultado relevante de `systemctl status`/`journalctl`, removendo dados sensíveis.

**Nunca envie:** senhas, tokens, chaves privadas, bancos de usuários, backups de produção ou segredos de Calling Home.

Problemas de segurança devem seguir [SECURITY.md](SECURITY.md), não uma issue pública com detalhes exploráveis.

## 🇺🇸 English

Before requesting help, run the read-only diagnostic:

```bash
sudo bash scripts/health-check.sh
```

Check these guides first:

- [Debian 12 installation](docs/INSTALL-XLX-DEBIAN-12.en.md)
- [Update and recovery](docs/UPDATE-RECOVER-XLX.en.md)
- [Firewall and ports](docs/XLX-FIREWALL-PORTS.en.md)
- [Files and logs](docs/XLX-FILES-LOGS.en.md)
- [Post-installation](docs/XLX-POST-INSTALL.en.md)

When opening a public issue, include:

1. Debian version;
2. architecture (`uname -m`);
3. project commit (`git rev-parse HEAD`);
4. whether the task is a new install, dashboard install, update or recovery;
5. complete error message;
6. relevant `systemctl status`/`journalctl` output with sensitive data removed.

**Never post:** passwords, tokens, private keys, user databases, production backups or Calling Home secrets.

Security issues must follow [SECURITY.md](SECURITY.md) instead of disclosing exploitable details in a public issue.
