# 📚 XLX Modern Installer — Documentation / Documentação

Central de documentação para instalar, atualizar, proteger, diagnosticar e recuperar um refletor XLX no Debian 12, incluindo o dashboard moderno, diretório persistente de indicativos e sistema de certificados.

Documentation hub for installing, updating, securing, troubleshooting and recovering an XLX reflector on Debian 12, including the modern dashboard, persistent callsign directory and certificate system.

## 🇧🇷 Português

- [Como instalar um refletor XLX no Debian 12](INSTALACAO-XLX-DEBIAN-12.pt-BR.md)
- [Indicativos, base de usuários e certificados](INDICATIVOS-CERTIFICADOS.pt-BR.md)
- [Como atualizar, diagnosticar e recuperar um servidor XLX](ATUALIZAR-RECUPERAR-XLX.pt-BR.md)
- [Firewall e portas necessárias para XLX](FIREWALL-PORTAS-XLX.pt-BR.md)
- [Onde ficam os arquivos e logs do XLX](ARQUIVOS-LOGS-XLX.pt-BR.md)
- [Pós-instalação: HTTPS, YSF e XLX Echo](POS-INSTALACAO-XLX.pt-BR.md)
- [README principal em Português](../README.md)

## 🇺🇸 English

- [How to install an XLX reflector on Debian 12](INSTALL-XLX-DEBIAN-12.en.md)
- [Callsign directory, user database and certificates](CALLSIGNS-CERTIFICATES.en.md)
- [How to update, troubleshoot and recover an XLX server](UPDATE-RECOVER-XLX.en.md)
- [XLX firewall ports and network requirements](XLX-FIREWALL-PORTS.en.md)
- [XLX files, directories and logs](XLX-FILES-LOGS.en.md)
- [Post-installation: HTTPS, YSF and XLX Echo](XLX-POST-INSTALL.en.md)
- [Main README in English](../README.en.md)

## 🌍 Dashboard multilíngue / Multilingual dashboard

- [Internationalization architecture](INTERNATIONALIZATION.md)
- Supported installation languages: `pt-BR`, `en`, `es`, `fr`, `de`, `it`

Examples:

```bash
sudo bash install.sh --lang=en
sudo bash modules/60-dashboard-modern.sh --lang=es
```

The installed reflector identity is reused by the dashboard and certificate module. A generic deployment does not inherit the XLX026 name, domain or country.

A identidade configurada no refletor é reutilizada pelo dashboard e pelo módulo de certificados. Uma instalação genérica não herda automaticamente nome, domínio ou país do XLX026.

## 👤 Indicativos / Callsigns

Main XLX database:

```text
/xlxd/users_db/users.db
```

Persistent local corrections:

```text
/var/lib/xlx-user-directory/overrides.db
```

Administration examples:

```bash
sudo xlx-user-directory lookup PU2PNY
sudo xlx-user-directory set PU2PNY "Nome" "Cidade, Estado"
sudo xlx-user-directory alias PU2OLD PU2NEW
sudo xlx-user-directory check
sudo xlx-user-directory refresh
```

Full guide / Guia completo:

- [Português](INDICATIVOS-CERTIFICADOS.pt-BR.md)
- [English](CALLSIGNS-CERTIFICATES.en.md)

## 🏅 Certificados / Certificates

Installed pages:

```text
/certificado.php
/certificado-validar.php
```

Persistent server-side data:

```text
/var/lib/xlx-certificates/emissoes.jsonl
/etc/xlx-certificates/hmac.key
```

Certificates require recorded activity during the active campaign. The HMAC key is generated locally and must never be committed to the public repository.

Os certificados exigem atividade registrada durante a campanha ativa. A chave HMAC é criada localmente e nunca deve ser publicada no repositório.

## 🔐 Segurança e publicação / Security and publication

- [Security policy / Política de segurança](../SECURITY.md)
- [Contribution guide / Guia de contribuição](../CONTRIBUTING.md)
- [Support / Suporte](../SUPPORT.md)
- [Third-party notices / Créditos e licenças](../THIRD_PARTY_NOTICES.md)
- [Public release checklist](PUBLIC-RELEASE-CHECKLIST.md)
- [GitHub About, Website and Topics](GITHUB-ABOUT.md)

Automated pre-public audit:

```bash
bash scripts/public-release-audit.sh
```

## 🔎 Topics covered / Assuntos cobertos

XLX reflector installation, XLXD Debian 12, D-STAR reflector, DMR reflector, C4FM/YSF, dashboard installation, multilingual dashboard, callsign database, persistent callsign corrections, callsign aliasing, SQLite integrity checks, certificate issuance, certificate QR validation, HMAC validation, firewall ports, Apache, HTTPS/Certbot, YSF registration, XLX Echo, backups, logs, systemd, troubleshooting, recovery and public-release security review.

Instalação de refletor XLX, XLXD no Debian 12, refletor D-STAR, DMR, C4FM/YSF, painel multilíngue, base de indicativos, correções persistentes, alias de indicativo, integridade SQLite, emissão de certificados, QR Code de validação, HMAC, firewall, portas, Apache, HTTPS, Certbot, registro YSF, XLX Echo, backup, logs, systemd, diagnóstico, recuperação e auditoria antes da publicação.
