# Release checklist

> Use esta lista junto com `PROJECT_TEST_MATRIX.md`. Não marque PASS sem evidência associada ao commit/release.

## Código e segurança
- [ ] Bash/PHP/JS syntax checks executados para o commit candidato.
- [ ] Auditoria de segredos/identidade privada executada.
- [ ] Dependências/licenças revisadas.
- [ ] Nenhuma permissão ampla/destrutiva reintroduzida.
- [ ] Admin/CSRF/session/rate-limit/audit regressions executadas.

## Instalador
- [ ] `install.sh --check` validado.
- [ ] instalação Debian 12 limpa validada em VPS descartável.
- [ ] `start.sh` validado no fluxo de iniciante.
- [ ] idioma do instalador isolado do idioma do dashboard.
- [ ] reinstalação/idempotência testada quando aplicável.
- [ ] falha ACME recuperável testada sem destruir instalação.

## Runtime
- [ ] XLXD ativo e validado.
- [ ] Nginx `nginx -t` aprovado.
- [ ] PHP-FPM ativo.
- [ ] Live / Connected / Modules validados.
- [ ] APRS/D-PRS validado.
- [ ] Certificates/HMAC validado.
- [ ] Health/observability validado.
- [ ] CallingHome validado quando aplicável.

## Regressão
- [ ] production parity.
- [ ] stream identity.
- [ ] dashboard nos 6 idiomas.
- [ ] mobile/acessibilidade/navegadores suportados.
- [ ] desempenho comparado ao baseline quando a mudança tocar runtime.

## Backup/rollback
- [ ] backup preventivo criado.
- [ ] rollback documentado.
- [ ] restore test executado quando a mudança toca dados/configuração crítica.

## Publicação
- [ ] `VERSION`, README, tag e GitHub Release são coerentes.
- [ ] CHANGELOG atualizado.
- [ ] PROJECT_RELEASE_STATUS atualizado.
- [ ] PROJECT_TEST_MATRIX atualizado com evidência.
- [ ] release aprovada no nível correto: DEV / BETA / RC / STABLE / PROD.
