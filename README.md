# XLX Modern Installer

Instalador para refletores XLX em servidores Debian 12, com foco em instalação segura, painel moderno e distribuição internacional.

## Estado do projeto

- `main` — versão estável atualmente publicada;
- `release/global-dashboard-v1` — preparação do dashboard internacional atualizado;
- `development/v2-native-installer` — nova geração modular do instalador, ainda em desenvolvimento.

> Antes de usar em produção, execute sempre a pré-validação em uma VPS Debian 12 limpa ou descartável.

## Instalação atual

```bash
git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
sudo bash install.sh --check
sudo bash install.sh
```

O comando `--check` executa somente a pré-validação. A instalação real exige confirmação explícita e não sobrescreve silenciosamente uma instalação XLX ativa.

## Dashboard internacional

O dashboard distribuído pelo projeto é preparado para ser reutilizado por refletores de diferentes países.

A distribuição global inclui as áreas gerais do painel, como:

- Ao vivo;
- estações conectadas;
- módulos;
- ranking e estatísticas;
- lista de refletores XLX;
- recursos gerais de monitoramento compatíveis com a configuração do refletor.

### Recursos deliberadamente não distribuídos

A distribuição internacional **não inclui**:

- página **Suporte** do XLX026, pois contém conteúdo e atendimento exclusivos daquele refletor;
- página **Notícias** do XLX026, pois utiliza fontes e conteúdo de interesse nacional brasileiro;
- credenciais, tokens, bancos de usuários, logs operacionais, backups ou configurações privadas da VPS de produção;
- identidade visual específica do XLX026 quando não for reutilizável por outros refletores.

O processo de publicação do dashboard trabalha sobre uma cópia temporária da produção, executa sanitização e validações e publica somente em uma branch separada para revisão antes do merge.

## Estrutura principal

- `install.sh` — instalador principal atual;
- `install-v2.sh` — instalador modular V2 em desenvolvimento;
- `modules/` — módulos de instalação, diagnóstico e validação;
- `tests/` — testes automatizados;
- `config/` — configurações de exemplo;
- `docs/` — documentação;
- `dashboard/` — XLX Modern Dashboard;
- `scripts/` — utilitários de manutenção e publicação;
- `references/PP5PK-XLX-Installer/` — referência técnica do instalador original utilizado como base.

## Segurança operacional

O projeto adota como princípios:

- validação prévia do sistema;
- bloqueio contra sobrescrita silenciosa de uma instalação ativa;
- backup preventivo antes de mudanças relevantes;
- confirmação explícita antes da instalação real;
- validação de commit e SHA-256 quando aplicável;
- separação entre código público e dados privados da VPS;
- publicação do dashboard por staging e auditoria antes do GitHub;
- revisão em branch/PR antes de promover mudanças importantes para `main`.

## Diretórios utilizados no servidor

- `/opt/xlx-modern-installer` — fontes controladas do instalador;
- `/var/backups/xlx-reflector` — backups preventivos;
- `/var/log/xlx-reflector/installer` — logs de instalação.

## Créditos

Projeto original e base técnica: **Daniel K. — PP5PK**, mantenedor do projeto `PP5PK/XLX_Installer`.

Também reconhecemos **LX3JL**, **N5AMD**, **Narspt** e os autores dos componentes efetivamente utilizados.

Versão modificada e modernizada mantida por **Dario — PU2PNY**.
