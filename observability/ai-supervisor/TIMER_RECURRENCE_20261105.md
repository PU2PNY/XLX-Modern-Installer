# Recuperação de timers OpenAI / Helix shadow — XLX026 (2026-11-05)

## Falha comprovada em produção
Os indicadores de TX mostravam **OPENAI não configurada** e **HELIX indisponível** apesar de os serviços principais estarem ativos. O painel em `/api/status.php` usa `/run/xlx-ai-monitor/public.json`; ele não existia após a reinicialização. O estado do monitor Helix estava parado desde 2026-11-03. Os dois timers estavam habilitados, mas ocasionalmente `active (elapsed)` sem próxima execução. Ao iniciar manualmente as duas unidades oneshot e rearmar timers, o monitor público foi recriado, `configured=true`, `api_connected=true`, `shadow_active=true` e `anomaly=false`.

## Correção aplicada no XLX026
Drop-ins de timer isolados, sem mudança em script IA, segredo, JSON, dashboard, core, transcoder ou áudio:
- `/etc/systemd/system/xlx-ai-monitor.timer.d/zz-recurrence.conf` define `OnUnitInactiveSec=60s` e limpa `OnUnitActiveSec`.
- `/etc/systemd/system/xlx-helix-monitor.timer.d/zz-recurrence.conf` define `OnUnitInactiveSec=30s` e limpa `OnUnitActiveSec`.

Assim o próximo acionamento é relativo ao **encerramento da execução oneshot**, como já usado em `xlx-ai-supervisor.timer`. O monitor OpenAI mantém sua política interna de **não repetir consulta à API em intervalo saudável inferior a 900 segundos**; somente a checagem local é frequente.

Backup privado anterior: `/opt/xlx026-backups/AI_MONITOR_TIMER_RECURRENCE_20261105`, com `ROLLBACK.sh` somente para remover drop-ins e rearmar os timers. Não versionar backups nem segredos.

## Validação
- PROD: `systemctl start xlx-ai-monitor.service xlx-helix-monitor.service` concluído, `systemctl restart` somente dos dois timers, `systemctl list-timers` com horários próximos após alteração.
- PROD: `/api/status.php?history=1` confirmou `ai_monitor.configured=true`, `ai_monitor.api_connected=true`, `ai_monitor.state=monitoring` e `supervisor.local_supervision=true`.
- PROD: `xlxd.service` continuou ativo PID1298, mesmo executável, sem restart.
- Validar **após outro reboot** continua pendente; não anunciar como teste de reboot realizado.
- Este artefato versiona os templates e a intervenção. A inclusão automática dos drop-ins em instaladores novos fica como item de integração separado, com teste de não sobrescrever configuração existente.
