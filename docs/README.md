# 📚 XLX Modern Installer — Documentation / Documentação

Central de documentação para instalar, atualizar, proteger, diagnosticar e recuperar um refletor XLX no Debian 12.

Documentation hub for installing, updating, securing, troubleshooting and recovering an XLX reflector on Debian 12.

## 🇧🇷 Português

- [Como instalar um refletor XLX no Debian 12](INSTALACAO-XLX-DEBIAN-12.pt-BR.md)
- [Como atualizar, diagnosticar e recuperar um servidor XLX](ATUALIZAR-RECUPERAR-XLX.pt-BR.md)
- [Firewall e portas necessárias para XLX](FIREWALL-PORTAS-XLX.pt-BR.md)
- [Onde ficam os arquivos e logs do XLX](ARQUIVOS-LOGS-XLX.pt-BR.md)
- [Pós-instalação: HTTPS, YSF e XLX Echo](POS-INSTALACAO-XLX.pt-BR.md)
- [README principal em Português](../README.md)

## 🇺🇸 English

- [How to install an XLX reflector on Debian 12](INSTALL-XLX-DEBIAN-12.en.md)
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

XLX reflector installation, XLXD Debian 12, D-STAR reflector, DMR reflector, C4FM/YSF, dashboard installation, multilingual dashboard, firewall ports, Apache, HTTPS/Certbot, YSF registration, XLX Echo, backups, logs, systemd, troubleshooting, recovery and public-release security review.

Instalação de refletor XLX, XLXD no Debian 12, refletor D-STAR, DMR, C4FM/YSF, painel multilíngue, firewall, portas, Apache, HTTPS, Certbot, registro YSF, XLX Echo, backup, logs, systemd, diagnóstico, recuperação e auditoria antes da publicação.
