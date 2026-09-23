# BACKLOG XLX026 — pesquisado, ainda não aplicado ou não comprovado

Este arquivo separa recomendações de fóruns/comunidades/boas práticas do estado realmente confirmado no repositório. Nada abaixo autoriza alteração automática de produção.

## A — confirmado como pendência de governança
### A1. Reconciliar versão e GitHub Release
- `VERSION`/README: 1.4.6.
- última GitHub Release observada: v1.2.14.
- ação: decidir se 1.4.6 deve ganhar tag/release ou se a documentação deve ser ajustada.
- risco: baixo, desde que não publique artefato não validado.

### A2. Corrigir drift documental
- `STATUS.md`, `ARCHITECTURE.md` e `RELEASE_CHECKLIST.md` estavam incompatíveis com o runtime documentado atual.
- ação: corrigir via PR de governança.

### A3. Proteger branch principal
- `main` foi observado como não protegido em 2026-09-21.
- candidato: exigir PR/CI antes de alterações diretas.
- aplicar somente após verificar que não bloqueia o fluxo atual do mantenedor.

## B — sem evidência suficiente de aplicação no servidor/repositório
### B1. Ordenação explícita do XLXD após rede pronta
Relatos de comunidade sugerem evitar corrida de boot aguardando rede operacional. Não aplicar `sleep 45` cegamente. Preferir dependência systemd em `network-online.target` se o problema existir e houver prova nos logs.

### B2. Atualizações automáticas de segurança do Debian
Não foi comprovado nesta auditoria se `unattended-upgrades` está configurado no servidor real. Validar antes de propor, pois atualização automática também pode introduzir regressão operacional.

### B3. Política explícita de logrotate para logs XLXD/customizados
Não comprovada nesta auditoria. Primeiro identificar quais logs já são cobertos por journald/logrotate.

### B4. Monitoramento/alertas externos
Prometheus/Grafana/Monit/Zabbix foram citados como possibilidades, mas não há justificativa para adicionar peso ao servidor enquanto Health/self-tests existentes forem suficientes. Só adotar se existir requisito mensurável.

### B5. Teste real de restauração
Backups são documentados, mas esta auditoria não encontrou evidência atual de um restore test completo da versão corrente. Deve ser feito em ambiente descartável.

### B6. Validação independente em VPS Debian 12
Há runtime gate e documentação de beta, mas uma nova instalação limpa da revisão atual deve ser registrada com commit, ambiente e evidência antes de promover mudanças críticas.

## C — não aplicar agora
### C1. Upgrade do XLXD apenas por versão
Não promover 2.6.x ou qualquer versão numericamente superior sem laboratório. O baseline atual tem prioridade sobre novidade.

### C2. Ferramentas pesadas de observabilidade
Não instalar apenas por “boas práticas”. Medir necessidade, RAM/CPU/I/O e ganho operacional.

### C3. Delay fixo de boot como solução genérica
Um `sleep` fixo mascara causa. Usar somente como workaround temporário quando logs comprovarem corrida de inicialização e uma dependência systemd correta não resolver.

## D — obsoleto/superado pelos fatos atuais
### D1. “Integrar painel moderno ao instalador”
Já está superado: o README atual documenta dashboard moderno como parte do instalador.

### D2. “APRS/certificados externos”
Superado: arquitetura atual documenta APRS/D-PRS e certificados nativos no repositório principal.

### D3. “Instalação real ainda desabilitada”
Superado: documento antigo estava obsoleto e contradizia o instalador/release atual.

## Regra
Antes de tirar qualquer item deste backlog:
**evidência local → requisito → teste → backup/rollback → laboratório → resultado → decisão registrada → somente então produção.**
