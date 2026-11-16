# Instrucoes para agentes de desenvolvimento

## Habilidades de agentes — ativacao condicional

Antes de desenvolver, identificar a natureza da tarefa e consultar os SKILL.md das ferramentas instaladas que realmente se aplicam:

- **Modern Web Guidance** (`modern-web-guidance`): consultar primeiro em tarefas de HTML, CSS, JavaScript no navegador, formularios, acessibilidade, Web Vitals e compatibilidade Baseline. Usar `search` e depois `retrieve` do ID encontrado; nao ativar para backend, radio, CI, banco de dados ou scripts de infraestrutura.
- **Taste Skill** (`design-taste-frontend`): ativar em criacao/redesign/auditoria visual de sites, landing pages e paginas comerciais, juntamente com Modern Web Guidance se necessario. Nao aplicar seu kit automaticamente em paineis operacionais existentes; usar previews/branches e checagens em navegador com Node 22+ e Chrome/Chromium.
- **Outras skills instaladas**: verificar descricoes e escolher somente quando correspondam a tarefa; por exemplo, Playwright em testes funcionais, ferramentas de design em auditorias de UI. Nao executar indiscriminadamente todos os scripts, nao assumir que ferramentas estao instaladas em outro computador.
- Prioridade: especificacao e requisitos de seguranca do projeto, dados verificados, compatibilidade, acessibilidade e intencao do usuario prevalecem sobre templates. Nao inventar valores, numeros, contatos ou alterar marcas sem pedido. Nao instalar novas dependencias ou publicar em producao apenas por ler uma skill.

Fontes: https://github.com/GoogleChrome/modern-web-guidance e https://github.com/Leonxlnx/taste-skill.
