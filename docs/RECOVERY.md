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
