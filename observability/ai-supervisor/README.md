# Supervisão técnica limitada XLX026

Opt-in, sem instalação automática; nomes dos serviços são específicos da referência XLX026. A API recebe apenas estados dos serviços e métricas de disco/memória/carga. Sem áudio, indicativos, IP, logs ou credenciais.

Conectividade: duas tentativas de até 12s em erro transitório. 401/403/429 não têm repetição imediata. Timer local a cada minuto; conexão saudável consulta a cada 900s. Erro mantém api_connected=false e diagnóstico sanitizado; sem mascarar falha com sucesso antigo.

Supervisor: coleta local por minuto, análise remota no máximo a cada 15min inclusive falha/mudança; resumo horário em estado saudável estável. Usa OPENAI_API_KEY e OPENAI_MODEL do env privado existente. Texto incompleto não conta como análise. ai_last_analysis_at só muda com resposta completa. Texto remoto nunca é executado.

Recuperação local: somente START de xlx026-live-core-v2.service, xlx026-live-hub.service e xlx026-health-monitor.service, em failed por duas amostras consecutivas, intervalo 30min e até 3 tentativas por dia UTC por serviço. Serviço inactive/unknown/active não é acionado. Sem recuperação de XLXD/xuvd/Helix/Nginx/PHP, alteração de rádio, codecs, TOT, rede ou firewall. Não detecta travamento com daemon ainda active. Falha da IA não impede recuperação local.

Estado público: /run/xlx-ai-supervisor/public.json. Estado privado limitado a 20 eventos: /var/lib/xlx-ai-supervisor/state.json (0600), preservado entre deploys para manter limites. Eventos de tentativa também em journald. O painel supervisionando exige telemetria local fresca e análise real completa recente; não afirma correção de áudio/RF.

## Instalação opt-in e rollback

Salvar originais e hashes. Validar testes em ambiente isolado. Instalar Python root:root 0755 em /usr/local/lib/xlx-modern e units root:root 0644 em /etc/systemd/system. Unit supervisor é root para START por systemd/D-Bus, filesystem protegido, sem capabilities e escrita somente runtime/state. Não adicionar terminal/sudo para IA. Aplicar integrate-dashboard.py primeiro sobre cópia do webroot, validar PHP/Node, depois sobre produção com backup. Não copiar webroot inteiro de outra revisão.

Drop-in do timer existente: [Timer], limpar OnUnitActiveSec com valor vazio e então usar OnUnitActiveSec=60s, RandomizedDelaySec=10s. Verificar systemd-analyze verify, daemon-reload, iniciar monitor e supervisor.timer; preservar env privado e regras da unit existente. Não reiniciar rádio/transcoder.

Rollback: desabilitar/parar somente supervisor.timer/service, remover novas units/código, restaurar monitor, drop-in e os dois arquivos UI/API salvos; daemon-reload e reiniciar apenas monitor/timer. Preservar state privado/auditoria. Conferir restore por hash antes da promoção. Backup não deve entrar no Git.

Teste: python3 tests/test-ai-supervisor.py. Casos timeout→sucesso, autenticação, 429/Retry-After, indisponibilidade honesta, cache saudável, escopo/cooldown/limite diário e recuperação sintética sem executar texto remoto. SW/ENV sintético não equivale a incidente real de produção.
