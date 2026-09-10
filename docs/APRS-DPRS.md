# APRS / D-PRS nativo

Na versão **1.2.12**, APRS/D-PRS faz parte do XLX Modern Installer e é provisionado pelo próprio repositório durante a instalação normal. A implementação pública fica em `dashboard/native/aprs/`, com interface e APIs integradas ao dashboard.

## Modelo operacional

- **Módulo B** dedicado a beacons, APRS e D-PRS.
- Gateway local entre o refletor e APRS-IS.
- Transmissão e recepção APRS habilitadas pelo serviço nativo.
- Mensagens APRS, ACKs e estado do operador pela interface Digital Lab.
- Posições GPS/APRS/D-PRS exibidas somente quando realmente observadas.
- Indicadores de posição na atividade do painel podem abrir a visão de localização do próprio servidor.
- Estado persistente em SQLite fora do webroot.
- Conta por indicativo, senha gerada criptograficamente e armazenamento somente de hash.
- Recuperação autorizada com rotação da versão de autenticação e revogação de tokens lembrados.

O indicativo do serviço APRS é derivado do indicativo do sysop com SSID `-10`. A configuração operacional é criada em `/etc/xlx-aprs-dprs/`, o estado fica em `/var/lib/xlx-aprs-dprs/` e o serviço é executado como `xlx-aprs-dprs.service`.

## Segurança e dados privados

Credenciais, passcodes reais, bancos SQLite de produção, contas, tokens, sessões, chaves privadas, logs e backups de produção não são publicados no GitHub. Cada instalação cria e mantém seus próprios dados operacionais localmente.

## Referência em produção

O **XLX026 Brasil** é a referência de produção do painel e pode ser acompanhado em [https://xlx026.net/](https://xlx026.net/).
