# XLX Modern Installer

Instalador profissional para refletores XLX em servidores Debian 12.

## Instalação

```bash
git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
sudo bash install.sh --check
sudo bash install.sh
```

O comando `--check` executa somente a pré-validação. A instalação real exige confirmação explícita e não sobrescreve uma instalação XLX existente.

## Estrutura principal

- `install.sh` — instalador principal;
- `scripts/development-preview.sh` — interface antiga de prévia e testes;
- `modules/` — módulos de diagnóstico, planejamento e validação;
- `tests/` — testes automatizados;
- `config/` — configurações de exemplo;
- `docs/` — documentação em Português e Inglês;
- `dashboard/` — reservado para o XLX Modern Dashboard.

## Diretórios utilizados no servidor

- `/opt/xlx-modern-installer` — fontes controladas do instalador;
- `/var/backups/xlx-reflector` — backups preventivos;
- `/var/log/xlx-reflector/installer` — logs de instalação.

## Créditos

Projeto original e base técnica: **Daniel K. — PP5PK**, mantenedor do projeto `PP5PK/XLX_Installer`.

Também reconhecemos **LX3JL**, **N5AMD**, **Narspt** e os autores dos componentes efetivamente utilizados.

Versão modificada e modernizada mantida por **Dario — PU2PNY**.

## Estado do novo painel

A estrutura e os nomes profissionais já foram aplicados. A integração automática do **XLX Modern Dashboard** depende da inclusão do pacote sanitizado do painel no diretório `dashboard/`.

Até essa integração ser concluída, o instalador principal utiliza o dashboard fornecido pelo projeto técnico original.
