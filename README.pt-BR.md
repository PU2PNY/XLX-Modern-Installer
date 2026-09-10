# XLX Modern Installer

**Versão atual: v1.4.0**

Instalador público e reproduzível para **Debian 12 x86_64**. Instala o núcleo XLXD, Echo Test quando selecionado, painel moderno multiprotocolo, Admin privado, APRS/D-PRS nativo, Certificados nativos verificáveis, CallingHome e observabilidade operacional.

Este repositório publica o instalador e o painel **XLX Modern** derivados do ambiente **XLX026 Brasil validado em produção**. Durante a instalação, o responsável informa a identidade do novo refletor, portanto cada servidor recebe seu próprio ID XLX, domínio, localização e parâmetros operacionais. O XLX026 é a referência de produção e demonstração ao vivo; credenciais, segredos e dados privados do servidor de produção não são distribuídos.

**Exemplo funcionando em produção:** [XLX026 Brasil — xlx026.net](https://xlx026.net/)

## Instalação rápida

```bash
apt-get update
apt-get install -y git ca-certificates
cd /usr/src
git clone https://github.com/PU2PNY/XLX-Modern-Installer.git
cd XLX-Modern-Installer
bash web-install.sh
```

`bash install.sh --check` faz somente a pré-validação sem instalar. O `web-install.sh` é o inicializador gráfico recomendado e recusa uma instalação XLXD ativa ou vestígios antigos ainda não revisados.

## Como a instalação funciona

O caminho recomendado agora é `bash web-install.sh`. Ele inicia o **instalador gráfico no navegador** somente no endereço interno da própria VPS e mostra um comando de túnel SSH e um endereço local temporário para abrir no navegador. O assistente tem controles grandes e de alto contraste, oito etapas curtas, barra de progresso grossa, orientação em cada campo, Enter para avançar entre respostas e uma revisão final antes de instalar. A interface não fica exposta diretamente à Internet.

O `install.sh` revisado continua sendo o único motor real da instalação por trás da interface gráfica. `bash install.sh` mantém o Textual como alternativa no terminal, e `bash install.sh --classic` mantém o questionário clássico como fallback.

O questionário reúne refletor, domínio, email/indicativo do sysop, país, fuso, textos públicos, HTTPS, Echo Test, quantidade de módulos, YSF, cidade/região, YSF ID e usuário/slug/senha do Admin. A senha do Admin exige no mínimo 8 caracteres e nunca aparece no resumo.

O instalador **não executa `full-upgrade` obrigatório**. Usa `apt-get` para atualizar índices e instalar apenas as dependências necessárias.

## O que o servidor instala

| Componente | Função |
|---|---|
| XLXD | Núcleo do refletor multiprotocolo e módulos configurados |
| XLX Echo | Teste de eco opcional no módulo E |
| Apache + PHP | Painel e APIs |
| Base de indicativos | RadioID/callsigns com atualizações e correções locais persistentes |
| CallingHome | Registro/heartbeat por timer usando HTTP/HTTPS realmente disponível |
| APRS/D-PRS nativo | D-PRS/GPS, APRS-IS, mensagens/ACK e contas |
| Certificados nativos | Certificados por participação com QR e validação HMAC |
| Observabilidade | Health, DMR data/meta, YSF data, histórico e self-test |
| Admin privado | Status, portas, logs, backups, Health, RadioID, listas, Interlink e reinício protegido |

## Páginas do painel

- **Ao Vivo**: boxes de TX/RX de baixa latência respondem rapidamente ao início e ao fim das transmissões e exibem indicativo, protocolo, módulo e, quando disponível, a imagem pública do operador. A tabela reúne as transmissões das últimas **24 horas** e consolida atividades repetidas por indicativo, com submenu expansível para consultar as transmissões daquele operador sem poluir a lista com linhas repetitivas. Quando existe APRS/D-PRS/GPS realmente observado, a atividade é identificada e a ação de localização abre a própria página APRS/D-PRS do servidor com o contexto do operador/localização.
- **Conectados**: filtros e tabela em tempo real das estações conectadas, com indicativo, protocolo, módulo e tempo de conexão, separada da página Módulos.
- **Módulos**: identificações de acesso primeiro e cards de módulos depois; quantidade configurável e nomes NATO Alfa–Zulu quando aplicável.
- **Ranking**: mostra quem está conectado há mais tempo, quem mais apertou o PTT/gerou TX, quem acumulou mais tempo falando, horários de maior movimento, módulos mais utilizados e protocolos atualmente conectados. Há visões de hoje, 7 dias e mês atual quando existe cobertura estatística.
- **Refletores**: lista mundial de refletores XLX com busca e filtros para selecionar o que será exibido.
- **APRS / D-PRS**: Digital Lab nativo ligado ao **módulo B**, reservado neste modelo de instalação para beacons, APRS e D-PRS. Mostra posições realmente observadas e permite enviar e receber mensagens de rádio APRS, incluindo ACKs, pela interface do servidor.
- **Certificados**: gera certificado de participação a partir de atividade elegível registrada, incluindo dados de TX, tempo acumulado, módulos e protocolos presentes naquela atividade, com QR Code público e validação de autenticidade por HMAC.

O pacote público padrão **não instala Suporte, Simulado ANATEL nem Notícias**.

## Identidade, gateway e atividade

A regra é a mesma validada no XLX026:

- indicativo do log XLXD é a origem da transmissão;
- Gateway/Repetidora diferente só aparece quando existe evidência exata de relação;
- `Online` significa realmente conectado;
- `Link` só aparece quando há relação de gateway comprovada para um operador que estaria Offline;
- Talker Alias é metadado complementar transmitido pelo rádio e não substitui RadioID;
- coordenada cadastrada de hotspot/repetidora não é tratada como GPS ao vivo do operador;
- posição APRS/D-PRS/GPS só aparece quando realmente observada.

O histórico visível do painel é de **24 horas**.

## APRS/D-PRS nativo

A interface e APIs ficam dentro do próprio `dashboard/`; não existe segundo painel APRS. Somente gateway/serviço de fundo e SQLite são provisionados fora do webroot. O runtime liga o Digital Lab ao **módulo B**, dedicado a beacons/APRS/D-PRS, e habilita transmissão e recepção via APRS-IS para que operadores autenticados possam trocar mensagens APRS e confirmações pela interface do refletor.

Fluxo de conta:

- indicativo validado;
- cadastro próprio exige atividade recente válida APRS/D-PRS;
- usuário informa **dia e mês reais do aniversário** e dá consentimento;
- senha é gerada com aleatoriedade criptográfica;
- banco guarda somente `password_hash()`;
- senha aparece apenas no momento de criação/troca;
- recuperação por indicativo + dia/mês é feita no fluxo autorizado de Admin/Colaborador, igual ao modelo validado no XLX026;
- a recuperação gera senha nova, incrementa a versão de autenticação e revoga tokens antigos;
- dia/mês não são gravados como detalhes do evento de auditoria.

O indicativo do serviço APRS é derivado do sysop com SSID dedicado `-10`, sem indicativo de produção fixo.

## Certificados nativos e QR verificável

Certificados fazem parte deste repositório e do próprio painel. A instalação normal **não baixa um segundo Certificate Generator**.

O certificado só é emitido quando existe atividade elegível na campanha. Cada emissão possui ID único e token HMAC. O QR aponta para o próprio painel:

```text
https://SEU-DOMINIO/?page=certificado&validar=ID&token=ASSINATURA
```

A validação busca a emissão, recalcula o token e usa `hash_equals()`. Token adulterado é rejeitado. O segredo HMAC é criado fora do webroot em `/etc/xlx-certificates/`.

## Admin privado

O Admin não aparece no menu público e não depende de uma URL fixa `/admin/`. O **slug privado é configurável durante a instalação**, reduzindo a exposição do ponto de entrada administrativo. Recursos:

- status do XLXD/serviços e portas;
- logs e backups;
- Health;
- RadioID: status, check, atualização, busca, inclusão/edição/exclusão;
- whitelist e blacklist;
- Interlink;
- reinício XLXD protegido;
- CSRF, sessão, rate-limit e auditoria;
- **sem terminal SSH/Linux e sem Terminal XLXD no navegador**.

A validação do instalador usa marcadores funcionais estáveis (`id="access"`, `id="radioid"`, `access-interlink-add`, `radioid_save`) e não textos traduzidos.

## HTTPS / Let's Encrypt

Se HTTPS for escolhido e o ACME/Certbot falhar, uma instalação válida do refletor não é descartada. O painel público permanece em HTTP, o erro real é registrado e o helper de nova tentativa fica disponível:

```bash
xlx-modern-https-retry SEU-DOMINIO SEU-EMAIL
```

Em testes repetidos, use staging do Let's Encrypt para evitar rate limit. Cookies de sessão privados usam `Secure`; HTTP temporário não deve ser considerado substituto de HTTPS para uso autenticado.

## Idiomas

- Instalador: PT-BR e EN.
- Admin privado: PT-BR e EN.
- Painel: PT-BR, EN, ES, FR, DE e IT.

Rotas, IDs, nomes de arquivos e APIs são protegidos contra tradução acidental.

## Backups, falhas e validação final

Backups preventivos ficam em `/var/backups/xlx-reflector/`. Scripts críticos informam **arquivo, linha, código de retorno e comando** em erro inesperado, evitando retorno silencioso ao shell. Onde há mutação controlada, existe rollback do componente.

Uma instalação completa só deve ser considerada aprovada quando chegar a **INSTALLATION COMPLETE / INSTALAÇÃO CONCLUÍDA** após validar serviços essenciais, Apache, binário XLXD, arquivos do painel, VirtualHost, CallingHome e resposta local do painel.

## Base de indicativos e correções persistentes

A base principal fica em `/xlxd/users_db/`. Correções/aliases locais ficam separadas em `/var/lib/xlx-user-directory/overrides.db` e sobrevivem às atualizações da base principal.

```bash
xlx-user-directory --help
```

## Segurança

- sem senha Admin fixa no Git;
- sem dados/credenciais privados de produção;
- sem `chmod 777` global;
- Admin usa helpers sudo limitados, não sudo arbitrário pelo navegador;
- segredo HMAC fora do webroot;
- senhas APRS armazenadas somente como hash;
- Suporte/Simulado/Notícias fora da distribuição pública do instalador.

## Estrutura

```text
install.sh                 instalador principal
vendor/pp5pk-installer/    base XLXD revisada
dashboard/                 painel, APRS/D-PRS e Certificados nativos
control/                   Admin privado e helpers
modules/                   etapas controladas de instalação
observability/             Health/DMR/YSF/histórico/self-test
tests/                     regressões
scripts/                   auditorias e manutenção
docs/                      documentação
```

## Gate de release

Antes de publicar uma tag: sintaxe Bash/PHP, fluxo do instalador, Admin PT/EN, seis builds do painel, auditoria pública, APRS/Certificados nativos, paridade de produção e validação de instalação limpa Debian 12. A reinstalação também deve ser idempotente e não duplicar rotas/serviços.

Veja também [CHANGELOG.md](CHANGELOG.md), [LICENSE](LICENSE) e [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).


## HTTPS e validação final

Se o Let's Encrypt responder com rate-limit, a instalação mantém o painel funcional em HTTP, registra o horário `retry after` e agenda automaticamente o próprio Certbot para nova tentativa. A instalação só mostra conclusão após validar painel, APIs, APRS/D-PRS, Health, Admin privado, Apache, XLXD e Echo.
