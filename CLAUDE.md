# Claude Code — habilidades por contexto

Leia e cumpra [AGENTS.md](AGENTS.md). Escolha automaticamente apenas as skills relevantes para o trabalho atual, quando disponiveis no ambiente. Taste Skill e voltado a paginas comerciais/design; Modern Web Guidance a navegador e frontend. Nenhuma delas deve interferir em backend/infra ou alterar producao automaticamente.

## Ponytail nas tarefas de codigo

Sempre consultar a secao Ponytail de [AGENTS.md](AGENTS.md) antes de editar codigo. Aplicar automaticamente seus principios de escopo minimo completo, reutilizacao, seguranca e testes, sem depender da instalacao do plugin. Quando o plugin oficial Ponytail estiver disponivel **no Claude Code**, ele pode complementar essas instrucoes; nao presumir que esteja instalado, nem executar comandos `/plugin` ou hooks sem revisao. Nao fazer deploy ou merge automatico.

Instalacao opcional do plugin no Claude Code: https://github.com/DietrichGebert/ponytail/blob/main/INSTALL.md
