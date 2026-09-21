# PROJECT_RELEASE_STATUS — fotografia atual

Atualizado em: 2026-09-21

## Repositório
- Repositório: `PU2PNY/XLX-Modern-Installer`
- Branch padrão: `main`
- Commit observado em `main`: `1d54417fe55e8a12f246fdf440df35428a38ec8d`
- Commit: “Fix strict installer and dashboard language isolation”
- `VERSION`: **1.4.6**
- README: **Current release v1.4.6**
- Última GitHub Release observada: **v1.2.14**
- Estado: existe divergência confirmada entre versão declarada no branch e última Release publicada.

## Estado funcional documentado
Evidência `DOC`:
- instalação Debian 12 x86_64;
- XLXD core e Echo opcional;
- Nginx + PHP-FPM;
- dashboard multiprotocolo;
- RadioID/callsign com overrides persistentes;
- CallingHome;
- APRS/D-PRS nativo;
- certificados nativos com HMAC;
- observabilidade;
- Admin privado;
- backups preventivos e rollback por componente quando aplicável;
- suíte de testes e múltiplos workflows de regressão.

## Baseline de produção
Evidência `OPERATOR` em 2026-09-21:
- operador declarou servidor XLX026 e tela ativa “perfeitos”.

Limite: esta atualização documental não realizou inspeção direta do servidor de produção e não deve converter esse relato em `PROD` técnico.

## CI/testes
Existem workflows para CI geral, Debian 12 runtime gate, production parity, stream identity, Admin/control, instalador iniciante, TUI e Web UI.

Para o commit atual acima, o conector não retornou status combinados nem workflow runs associados. Portanto, **não registrar PASS atual por inferência**.

## Inconsistências corrigidas nesta governança
Os documentos antigos `STATUS.md`, `ARCHITECTURE.md` e `RELEASE_CHECKLIST.md` descreviam estado dry-run/Apache e “instalação real não habilitada”, contradizendo README/código/release atual. Devem ser alinhados via PR desta branch.

## Próxima sequência segura
1. revisar/mesclar somente documentação;
2. executar CI da branch;
3. reconciliar a versão 1.4.6 com GitHub Releases;
4. validar em VPS Debian 12 descartável;
5. apenas depois considerar backlog técnico;
6. não alterar produção enquanto o baseline estiver saudável sem necessidade comprovada.
