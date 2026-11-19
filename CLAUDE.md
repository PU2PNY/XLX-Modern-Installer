# Claude Code — habilidades por contexto

Leia e cumpra [AGENTS.md](AGENTS.md). Escolha automaticamente apenas as skills relevantes para o trabalho atual, quando disponiveis no ambiente. Taste Skill e voltado a paginas comerciais/design; Modern Web Guidance a navegador e frontend. Nenhuma delas deve interferir em backend/infra ou alterar producao automaticamente.

## Ponytail: verificacao, instalacao e uso em tarefas de codigo

Esta regra vale para **Claude Code** e complementa [AGENTS.md](AGENTS.md). O proprietario do projeto autoriza a configuracao do Ponytail oficial quando o ambiente Claude Code permitir. Nao confundir Claude no navegador, Claude Code e ChatGPT/Codex: cada um possui recursos de plugin diferentes.

1. **Antes da primeira edicao de codigo na sessao**, ler [AGENTS.md](AGENTS.md) e identificar as skills pertinentes. Conferir pelos recursos disponiveis no Claude Code se o plugin oficial `ponytail@ponytail` ja esta instalado e ativo. Se estiver, nao reinstalar, apenas aplicar suas orientacoes.
2. **Se nao estiver instalado e o ambiente suportar plugins do Claude Code**, conferir a fonte oficial `DietrichGebert/ponytail`, a documentacao e eventuais requisitos. Instalar uma unica vez, usando os comandos nativos do Claude Code, em **duas mensagens separadas**, nesta ordem:
   ```text
   /plugin marketplace add DietrichGebert/ponytail
   ```
   ```text
   /plugin install ponytail@ponytail
   ```
   Esses comandos sao do **Claude Code**, nao do terminal Linux/Windows nem do Claude web. Se o agente nao puder executar comandos slash/instalacao automaticamente, apresentar os dois passos ao operador para execucao na interface e prosseguir com as regras locais; **nao alegar que instalou**.
3. **Ao instalar**, respeitar dialogos de permissao e revisar os hooks oficiais antes de habilita-los; nao contornar controles, baixar forks desconhecidos, executar instaladores por `curl | sh`, usar `sudo` ou trocar automaticamente versoes. Confirmar que a instalacao concluiu e que o plugin realmente aparece como disponivel.
4. **Na sessao de programacao**, usar o modo `full` como padrao (com `/ponytail full` se disponivel), nao `ultra` sem necessidade. Aplicar reducao de complexidade e reutilizacao, mas nunca omitir mudancas em chamadores, testes, seguranca, permissao, compatibilidade e integridade de dados.
5. Ao final de uma mudanca de codigo relevante, executar os testes pertinentes e, se disponivel, `/ponytail-review` antes de propor merge. Relatar status real: **plugin ativo / instrucoes somente / indisponivel**, testes executados e riscos restantes. Nao repetir a instalacao a cada tarefa, nao ativar atualizacoes automaticas nem fazer merge/deploy em producao apenas por esta regra.
6. Se estiver usando **Claude no navegador**, sem Claude Code/plugin, usar as regras ja presentes em [AGENTS.md](AGENTS.md) e informar que o plugin nativo nao esta disponivel nessa sessao. Nao bloquear tarefas por ausencia do plugin.

Fonte oficial e requisitos: https://github.com/DietrichGebert/ponytail/blob/main/INSTALL.md
