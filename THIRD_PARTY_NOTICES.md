# Third-Party Notices / Avisos de Terceiros

O **XLX Modern Installer** possui lógica própria de instalação, integração, validação, backup e administração. Alguns softwares instalados ou compilados pelo projeto são componentes independentes de terceiros e permanecem sujeitos às licenças e direitos autorais de seus respectivos projetos.

## XLXD

- Projeto: **XLX Multiprotocol Gateway Reflector Server**
- Autores originais: Jean-Luc Deltombe — LX3JL e Luc Engelmann — LX1IQ
- Fonte usada pelo instalador: `https://github.com/LX3JL/xlxd`
- O código-fonte é obtido diretamente do projeto XLXD em revisão fixada pelo nosso módulo de instalação.
- A licença do XLXD prevalece sobre a licença dos arquivos originais deste repositório.

## XLXEcho

- Projeto: **XLXEcho**
- Fonte opcional: `https://github.com/narspt/XLXEcho`
- Uso: serviço Echo/Parrot opcional.
- O instalador obtém uma revisão fixada diretamente desse projeto quando o operador escolhe instalar Echo.

## Pacotes do sistema

Debian, Apache HTTP Server, PHP, SQLite, Certbot, Git, GCC/G++, rsync, curl e demais pacotes instalados pelo APT mantêm suas licenças e avisos próprios.

## Regra de independência

O repositório XLX Modern Installer não incorpora nem executa outro instalador de refletor como dependência. A instalação do núcleo, systemd, painel, CallingHome, RadioID, Admin, validações e rollback é orquestrada pelos próprios módulos deste repositório.

## Regra de licenciamento

A licença presente na raiz cobre apenas o material original deste repositório na extensão em que ele não esteja sujeito a licença de terceiro. Componentes obtidos durante a instalação continuam sujeitos às respectivas licenças upstream.

---

# English summary

XLX Modern Installer has its own installation, integration, validation, backup, and administration logic. XLXD and optional XLXEcho are fetched directly from their respective upstream repositories at pinned revisions and retain their original copyright and license terms. Distribution packages also retain their own licenses. No third-party reflector installer is vendored or executed as an installation dependency.
