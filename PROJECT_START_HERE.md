# PROJECT_START_HERE — XLX Modern Installer / XLX026

Este é o ponto inicial obrigatório para qualquer IA, desenvolvedor ou mantenedor antes de alterar o projeto.

## Projeto
- Repositório principal: `PU2PNY/XLX-Modern-Installer`
- Repositório do dashboard standalone: `PU2PNY/XLX-Modern-Dashboard`
- Branch padrão confirmada em 2026-09-21: `main`
- Commit de referência observado em `main`: `1d54417fe55e8a12f246fdf440df35428a38ec8d`
- Versão declarada em `VERSION` e README: `1.4.6`
- XLX026 é a referência de produção e demonstração, mas credenciais/dados privados não pertencem ao repositório.

## Ordem obrigatória de leitura
1. `PROJECT_MASTER_SPEC.md`
2. `PROJECT_RELEASE_STATUS.md`
3. `PROJECT_TEST_MATRIX.md`
4. `CHANGELOG.md` (histórico canônico já existente; não duplicar)
5. `ARCHITECTURE.md`
6. `SECURITY.md`
7. `docs/OPERATIONS.md`
8. `docs/RECOVERY.md`
9. `docs/DECISIONS.md`
10. `docs/RESEARCH_BACKLOG.md`

## Regra de continuidade
GitHub + documentação versionada são a memória técnica persistente. A conversa é ambiente de trabalho, não fonte exclusiva de verdade.

Antes de modificar qualquer coisa:
**GitHub → documentos canônicos → branch/commit atuais → código atual → requisitos → testes → backup/rollback → mudança mínima → validação → documentação → commit/PR.**

## Baseline de produção
Em 2026-09-21 o operador informou que o servidor XLX026 e a tela ativa estavam funcionando perfeitamente. Esse relato deve ser preservado como baseline operacional, porém é marcado como **relato do operador** enquanto não houver uma inspeção técnica independente do servidor no mesmo momento.

Não substituir, refatorar ou atualizar componentes críticos apenas por existir uma versão mais nova. Toda mudança deve provar que não degrada o baseline.

## Evidência
- `DOC`: confirmado em documentação/código.
- `SW`: teste local/automatizado executado com evidência.
- `ENV`: validado em ambiente reproduzível/VPS.
- `HW`: validado em hardware real, quando aplicável.
- `PROD`: validado diretamente em produção.
- `OPERATOR`: relatado pelo operador, sem verificação independente naquele registro.

Nunca promover um nível por inferência.

## Regra de segurança
Não publicar senhas, tokens, chaves privadas, certificados privados, bancos, backups de produção, sessões, logs sensíveis ou dados pessoais. Consulte `SECURITY.md`.

## Regra de Git
- Não alterar `main` diretamente quando a mudança puder ser revisada via branch/PR.
- Não reescrever histórico.
- Não apagar requisito aprovado silenciosamente.
- Não declarar teste como PASS sem evidência.
- Mudanças de alto risco exigem rollback definido antes da execução.
