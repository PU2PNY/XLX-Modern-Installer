# Operação segura — XLX Modern Installer / XLX026

## Antes de qualquer mudança
1. identificar branch/commit;
2. registrar versão;
3. identificar baseline que não pode regredir;
4. conferir health/status/logs relevantes;
5. criar backup/ponto de retorno quando houver risco;
6. limitar escopo;
7. testar fora de produção quando possível.

## Produção
Não usar o XLX026 como ambiente de experimento. Mudança de core, protocolos, áudio/transcoding, rede, systemd, firewall, PHP/Nginx, banco ou persistência deve passar primeiro por laboratório/VPS.

## Diagnóstico
Preferir mecanismos já existentes no projeto: health, status, logs, self-tests e checks. Não instalar observabilidade pesada sem medir custo.

## Deploy
- documentação: branch + PR;
- código de baixo risco: branch + CI + regressão;
- mudança de infraestrutura: plano + backup + janela + validação + rollback;
- produção: somente após evidência compatível com risco.

## Pós-mudança
Registrar:
- commit;
- arquivos alterados;
- testes;
- resultado;
- regressões;
- rollback disponível;
- impacto observado.

## Proibido
- mudanças múltiplas sem isolamento;
- `chmod 777`;
- apagar arquivos sem backup;
- reiniciar serviços “para ver se resolve” sem diagnóstico;
- atualizar dependência crítica sem comparação de compatibilidade;
- publicar segredos/logs privados.

## Analisador passivo de transmissão
O serviço `xlx-modern-transmission-analyzer.service` observa cópias dos datagramas YSF recebidos. Ele não é proxy, não reencaminha tráfego e não altera áudio.

Estado local: `/var/lib/xlx-modern-transmission-analyzer/state.json`.
Eventos de anomalia: `/var/log/xlx-modern-transmission-analyzer/events.log`.

Interpretação:
- `likely_missing_frames`: somente quando salto de sequência e tempo decorrido são compatíveis;
- `counter_jump`: contador mudou de forma incompatível com perda temporal; não converter automaticamente em “pacotes perdidos”;
- `concurrent_endpoints`: mais de um endpoint recente para o mesmo indicativo;
- o V1 não mede ruído acústico, clipping ou equalização porque não decodifica AMBE/AMBE+2.


## Helix PCM Bridge
A integração experimental Helix deve ser operada em três fases explícitas:
1. `off` — comportamento legado; estado padrão;
2. `shadow` — Helix recebe PCM, mas a resposta não altera o áudio transmitido;
3. `process` — PCM retornado pode ser usado somente após validação ENV e gate específico de áudio/rollback.

O cliente tem timeout local limitado e comportamento fail-open. Erro, socket ausente, timeout ou resposta inválida devem manter o PCM original. Não introduza API/cloud no caminho de áudio. Antes de qualquer mudança do transcoder ativo, registre PID, binário/hash, unit/config, tráfego ativo e ponto de retorno.
