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
