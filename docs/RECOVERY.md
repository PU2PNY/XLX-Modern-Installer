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
