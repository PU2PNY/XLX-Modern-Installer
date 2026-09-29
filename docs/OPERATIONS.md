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

## AI Monitor — chave OpenAI
- No XLX026, cadastrar a chave somente com `sudo xlx-ai-key`.
- O helper grava `/etc/xlx-ai-monitor.env` como `root:root 0600`; nunca colar a chave em JavaScript, PHP público, GitHub, chat de suporte ou logs.
- O estado público vem de `/run/xlx-ai-monitor/public.json` e contém apenas campos sanitizados.
- V1 valida autenticação da API sem inferência; análise de IA futura deve ser por exceção e manter DSP/telemetria local como caminho contínuo.
