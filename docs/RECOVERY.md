# Recuperação e rollback

## Princípio
Rollback é parte da mudança, não reação improvisada depois da falha.

## Procedimento mínimo
1. registrar commit/versão anterior;
2. salvar configuração e arquivos afetados;
3. registrar checksums quando aplicável;
4. confirmar que o backup é legível;
5. executar uma mudança por vez;
6. validar health, serviço, dashboard, APIs e protocolos afetados;
7. se regressão grave ocorrer, interromper novas mudanças;
8. restaurar o componente anterior;
9. revalidar baseline;
10. documentar causa e resultado.

## Camadas
- **Código**: reverter commit/PR ou restaurar artefato versionado.
- **Dashboard**: restaurar diretório/configuração previamente salvos.
- **Serviços**: restaurar unit/config conhecida e fazer daemon-reload quando aplicável.
- **Dados**: nunca sobrescrever banco sem cópia consistente e teste de restauração.
- **TLS**: preservar material válido; nunca versionar chaves privadas.
- **XLXD core**: manter binário/configuração anterior disponíveis antes de upgrade.

## Critério de parada
Se a recuperação não puder ser provada, a mudança de alto risco não deve ser promovida para produção.

## Helix / transcoder legado
Antes de trocar ou reiniciar o transcoder de produção:
- registrar PID e hash do binário ativo;
- salvar fonte/binário/unit/configuração atuais;
- confirmar `XLX_HELIX_MODE=off` como fallback inicial;
- validar em ENV o mesmo caminho com Helix ausente;
- testar retorno ao binário legado;
- não reiniciar XLXD como parte do rollback do Helix.

Rollback mínimo da integração Helix: retirar as variáveis Helix/repor `off`, restaurar o binário legado do transcoder e revalidar o fluxo já conhecido. O serviço Helix deve poder parar sem tornar rádios legados incompatíveis.

Evidência ENV 2026-09-30: Helix ausente em `process` manteve a saída bit-idêntica ao modo `off`; apenas a primeira tentativa do stream falhou e o restante do stream permaneceu legado. Isso valida o mecanismo de fallback em ENV, não autoriza troca do transcoder de produção.

### Escopo de validação desta continuação
A correção da deadline é limitada ao adapter experimental; produção conserva
XLXD PID 1093634 e xuvd PID 1107847 na inspeção somente leitura de 2026-09-30.
Hash do ELF ativo xuvd: 4b72dfc7a26697a3e315fba8c8d22435996d8e67c3112e2f343a65b4c6e58069.
Restore de arquivo/binário em laboratório não valida automaticamente restore
de unit/config/serviço nem autoriza troca do processo ativo.
Shadow em produção permanece pendente enquanto seus gates não estiverem
comprovados; process continua bloqueado e PU2PNY-OS não é integrado nesta fase.

### Rollback PROD shadow 2026-10-01
O deploy de produção cria backup local em `/opt/xlx026-backups/HELIX_SHADOW_<timestamp>` e um `ROLLBACK.sh` root-only. O rollback deve parar apenas `xlx-unified-voice.service`, remover o drop-in Helix, restaurar o xuvd legado e unit conhecidos, fazer `daemon-reload`, iniciar novamente o transcoder e então parar o observer. **Não reiniciar XLXD.**

A sequência completa de restore (binário + unit + configuração/drop-in + serviço) foi comprovada em ENV antes da promoção. Em PROD inicial o XLXD manteve PID 1093634; isso não transforma o soak de 24 h em concluído.

## Stereo Tool

A fundação LAB de 2026-10-02 não modifica produção; portanto seu rollback é simplesmente reverter/remover o código experimental da branch. Não existe serviço Stereo Tool ativo, artifact proprietário instalado ou alteração de áudio a restaurar nessa etapa.

Antes de qualquer promoção futura para `SHADOW`, `PROCESS_CANARY` ou `PROCESS`:
- registrar hash/versão do artifact e preset;
- manter artifact/preset anterior instalados e imutáveis;
- salvar unit/config do worker/router/control plane;
- registrar baseline de XLXD/xuvd e PIDs;
- comprovar que `EMERGENCY_BYPASS` independe do worker proprietário;
- testar restore completo em ENV;
- garantir que rollback de Stereo Tool **não reinicia XLXD**;
- manter PCM original disponível mesmo com worker morto.

Rollback futuro de artifact deve trocar somente a geração usada por novos streams e drenar a geração problemática; rollback de preset deve selecionar a revisão anterior para novos PTTs. Artifact/preset problemático é quarantined, não sobrescrito.

Se o fail-open delay-matched, o emergency bypass ou o restore completo não puderem ser demonstrados, `PROCESS` permanece bloqueado.

## TX Turn Guard / anti-ping-pong

Enquanto o recurso estiver somente na branch experimental, rollback é reverter a branch/patch; nenhum runtime de produção foi alterado.

Antes de um futuro canário do XLXD:
- registrar commit/hash do binário XLXD ativo, unit, drop-ins, ambiente e configuração;
- copiar o binário conhecido-bom e todos os arquivos de serviço/configuração afetados para backup root-only;
- validar a cópia de restore em ENV;
- manter o candidato com `XLX_TX_TURN_GUARD` ausente/`0` como bypass funcional;
- provar que remover o drop-in e restaurar o binário anterior retorna exatamente ao comportamento conhecido-bom;
- não usar a IA como mecanismo de rollback e não tornar a API OpenAI dependência do serviço XLXD.

Rollback de produção, se o canário vier a ser autorizado: parar somente o `xlxd` pelo procedimento operacional aprovado, restaurar o binário/unit/env anteriores, executar `daemon-reload` quando necessário, iniciar o serviço e revalidar DMR/YSF/D-Star, Live e interlinks. O monitor consultivo pode ser parado/retirado independentemente porque não participa do caminho de voz.

Qualquer bloqueio indevido de terceira estação, comando legítimo, módulo independente ou regressão de EOT é critério de rollback imediato.

## Complete private reconstruction archive (current parity candidate)

Two recovery paths have different inputs:
1. **New reflector**: install the tagged public source on Debian 12 x86_64 and
   enter the new operator's callsign, domain, modules, YSF identity and credentials.
2. **Existing reflector**: restore its private archive, retaining CallingHome's
   ownership token, admin password hash, TLS/private keys, APRS/certificate secrets,
   persistent databases and service configuration. Never publish that archive.

Create a private archive without restarting XLXD:
```bash
sudo bash scripts/backup-production.sh
```
The command reports the archive and SHA-256. Copy both to storage independent
of the original VPS. A copy left on the same VPS does not protect against its loss.

Verify and extract on a separate Debian 12 host into an empty private directory:
```bash
sudo python3 scripts/restore-production.py --archive /path/recovery.tar.gz --destination /opt/xlx-recovery-staging
```
The helper refuses `/`, a populated destination, traversal, duplicate members,
special files and checksum mismatch. It verifies all recorded file hashes and
SQLite integrity; no production services are restarted. The manifest maps
`recovery-running/` ELFs to actual install paths; disk source can be stale.

Only after staging verification, preserve target files, review hostname/IP/
DNS/timezone paths, restore ownership/configuration/service units and databases,
run `systemctl daemon-reload`, `nginx -t`, and start services in dependency order.
Restore the running ELF from the recorded mapping if the source-tree binary
has a different hash. Validate CallingHome identity/token without re-registering
as another reflector; verify Control login/CSRF, Live multi-TX, connected/history,
APRS, certificates and DMR/YSF/D-Star before directing public traffic to it.
A staging file restore is not a completed operational or RF restoration.

Audio reconstruction sources matching the observed d3ea28ef transcoder are in
`runtime/audio-recovery/`; the passive VU source is in `runtime/audio-vu/`.
These are preserved recovery references, not automatic DSP activation.


### Service identities and activation checklist

Use the archive's `/etc/passwd` and `/etc/group` as a reference for the service
accounts only; never replace the target host's complete account databases.
Archives created before this addition retain user/group names and numeric IDs
in tar member metadata. Create missing service accounts, reconcile UID/GID
conflicts on the replacement host and restore ownership before starting units.
Review the recovered unit `User`, `Group`, `EnvironmentFile`, `ExecStart` and
`ReadWritePaths` fields rather than guessing account names or paths.

On a replacement host, install Debian packages and PHP/Node runtime versions
first. Keep public reflector ports closed while validating. After copying only
the reviewed reflector files from staging, use these checks:
```bash
sudo systemctl daemon-reload
sudo nginx -t
sudo php-fpm8.2 -t
sudo systemctl --failed
```
Start PHP-FPM/Nginx and the read-only local data services first, then XLXD and
the recovered legacy/shadow audio services using their original unit/config.
Check each `systemctl status`, `/api/status.php`, `/api/live.php`, Control
login and the loopback Live health endpoints before opening reflector traffic.
Use the private manifest's exact running ELF mapping instead of stale source
outputs. Retain the staging archive and a copy of target files for rollback.
DNS/TLS and public CallingHome validation require the replacement host's real
address and domain. Preserve the private CallingHome hash for an existing
reflector; generate a new identity for a different operator.

The observed Helix daemon is reproducible from the pinned public revision in
`runtime/helix-recovery/README.md`; the accompanying locked build helper and
`runtime/build-audio-recovery.sh` only compile into a new directory. They do not
install a service, replace XLXD or activate DSP. The current 4,588-file restore
result proves archive integrity on another VPS; RF/audio/interlink continuity
and operational activation still require the checks above on the replacement.
