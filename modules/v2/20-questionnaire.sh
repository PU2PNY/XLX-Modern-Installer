#!/usr/bin/env bash

ask_required(){ local __var="$1" prompt="$2" value=''; while [ -z "$value" ]; do read -r -p "$prompt: " value; done; printf -v "$__var" '%s' "$value"; }
ask_yes_no(){ local __var="$1" prompt="$2" default="${3:-yes}" answer=''; while true; do read -r -p "$prompt " answer; answer="${answer:-$([ "$default" = yes ] && echo s || echo n)}"; case "${answer,,}" in s|sim|y|yes) printf -v "$__var" 'yes'; return ;; n|nao|não|no) printf -v "$__var" 'no'; return ;; *) ui_warning 'Responda Sim/Não ou Yes/No.' ;; esac; done; }

run_questionnaire(){
  ui_section 'Configuração do refletor / Reflector configuration'

  while true; do
    if [ "$LANGUAGE" = en ]; then
      printf '\nEnter exactly three digits. They form the reflector identifier, for example 026 becomes XLX026.\n'
      read -r -p 'Reflector number: ' REFLECTOR_NUMBER
    else
      printf '\nDigite exatamente três números. Eles formarão o identificador do refletor; por exemplo, 026 resulta em XLX026.\n'
      read -r -p 'Número do refletor: ' REFLECTOR_NUMBER
    fi
    [[ "$REFLECTOR_NUMBER" =~ ^[0-9]{3}$ ]] && break
    ui_warning 'Valor inválido. Use exatamente três números.'
  done
  REFLECTOR_ID="XLX${REFLECTOR_NUMBER}"

  if [ "$LANGUAGE" = en ]; then
    printf '\nPublic name shown in the dashboard header, browser title and metadata.\n'
    ask_required PUBLIC_NAME 'Public server name'
    printf '\nShort text explaining the reflector purpose.\n'
    ask_required DESCRIPTION 'Description'
    printf '\nDomain without http:// or https://. It will be used by Apache, dashboard and optional HTTPS.\n'
    ask_required DOMAIN 'Domain'
    printf '\nAmateur radio callsign of the administrator responsible for the reflector.\n'
    ask_required SYSOP_CALLSIGN 'Sysop callsign'
    printf '\nAdministrative contact and optional e-mail for HTTPS certificate registration.\n'
    ask_required CONTACT_EMAIL 'Contact e-mail'
    printf '\nCity and state, region or province.\n'
    ask_required LOCATION 'Location'
    ask_required COUNTRY 'Country'
  else
    printf '\nNome exibido no cabeçalho do painel, título do navegador e metadados.\n'
    ask_required PUBLIC_NAME 'Nome público do servidor'
    printf '\nTexto curto que explica a finalidade do refletor.\n'
    ask_required DESCRIPTION 'Descrição'
    printf '\nDomínio sem http:// ou https://. Será usado no Apache, painel e HTTPS opcional.\n'
    ask_required DOMAIN 'Domínio'
    printf '\nIndicativo do radioamador responsável pela administração do refletor.\n'
    ask_required SYSOP_CALLSIGN 'Indicativo do responsável'
    printf '\nContato administrativo e e-mail opcional para o certificado HTTPS.\n'
    ask_required CONTACT_EMAIL 'E-mail de contato'
    printf '\nCidade e estado, região ou província.\n'
    ask_required LOCATION 'Localização'
    ask_required COUNTRY 'País'
  fi

  DOMAIN="${DOMAIN#http://}"; DOMAIN="${DOMAIN#https://}"; DOMAIN="${DOMAIN%%/*}"
  [[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]] || { ui_error 'Domínio inválido.'; exit 1; }
  [[ "$CONTACT_EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]] || { ui_error 'E-mail inválido.'; exit 1; }

  DETECTED_TIMEZONE="$(timedatectl show -p Timezone --value)"
  printf '\nFuso horário detectado / Detected timezone: %s\n' "$DETECTED_TIMEZONE"
  TZ="$DETECTED_TIMEZONE" date '+%Y-%m-%d %H:%M:%S %Z'
  ask_yes_no KEEP_TIMEZONE 'Manter este fuso? / Keep this timezone? [S/n]' yes
  if [ "$KEEP_TIMEZONE" = yes ]; then TIMEZONE="$DETECTED_TIMEZONE"; else
    ask_required TIMEZONE 'Novo fuso, exemplo America/Sao_Paulo / New timezone'
    timedatectl list-timezones | grep -Fxq "$TIMEZONE" || { ui_error 'Fuso horário inválido.'; exit 1; }
  fi

  ui_section 'Protocolos / Protocols'
  printf '\nD-STAR é o protocolo digital central do XLX e permite conexões de repetidores, hotspots e usuários compatíveis.\nD-STAR is the central XLX digital protocol for compatible repeaters, hotspots and users.\n'
  ask_yes_no ENABLE_DSTAR 'Habilitar D-STAR? / Enable D-STAR? [S/n]' yes
  printf '\nDMR permite conexões Digital Mobile Radio e pode exigir configuração adicional de rede, talkgroups e módulos.\nDMR enables Digital Mobile Radio connections and may require network, talkgroup and module configuration.\n'
  ask_yes_no ENABLE_DMR 'Habilitar DMR? / Enable DMR? [S/n]' yes
  printf '\nC4FM/YSF é o ecossistema digital Yaesu System Fusion para hotspots e salas compatíveis.\nC4FM/YSF is the Yaesu System Fusion digital ecosystem for compatible hotspots and rooms.\n'
  ask_yes_no ENABLE_YSF 'Habilitar C4FM/YSF? / Enable C4FM/YSF? [S/n]' yes
  printf '\nNXDN é um protocolo digital usado por rádios compatíveis.\nNXDN is a digital protocol used by compatible radios.\n'
  ask_yes_no ENABLE_NXDN 'Habilitar NXDN? / Enable NXDN? [s/N]' no
  printf '\nP25 é um protocolo digital usado principalmente por equipamentos profissionais e redes compatíveis.\nP25 is a digital protocol mainly used by professional equipment and compatible networks.\n'
  ask_yes_no ENABLE_P25 'Habilitar P25? / Enable P25? [s/N]' no
  printf '\nM17 é um protocolo digital aberto para voz e dados.\nM17 is an open digital voice and data protocol.\n'
  ask_yes_no ENABLE_M17 'Habilitar M17? / Enable M17? [s/N]' no

  while true; do
    printf '\nOs módulos funcionam como salas independentes. Informe letras separadas por vírgula, por exemplo A,B,C,D,E.\nModules are independent rooms. Enter letters separated by commas, for example A,B,C,D,E.\n'
    read -r -p 'Módulos / Modules: ' MODULES
    MODULES="${MODULES^^}"; MODULES="${MODULES// /}"
    [[ "$MODULES" =~ ^[A-Z](,[A-Z])*$ ]] && break
    ui_warning 'Formato inválido.'
  done

  printf '\nXLX Echo grava uma transmissão curta e devolve o áudio para teste de qualidade e volume.\nXLX Echo records a short transmission and plays it back for audio quality testing.\n'
  ask_yes_no INSTALL_ECHO 'Instalar XLX Echo? / Install XLX Echo? [S/n]' yes
  if [ "$INSTALL_ECHO" = yes ]; then ask_required ECHO_MODULE 'Módulo do Echo / Echo module'; ECHO_MODULE="${ECHO_MODULE^^}"; fi

  printf '\nO painel moderno exibe status, conexões, módulos e informações públicas do refletor.\nThe modern dashboard displays status, connections, modules and public reflector information.\n'
  ask_yes_no INSTALL_DASHBOARD 'Instalar painel moderno? / Install modern dashboard? [S/n]' yes
  ask_yes_no SHOW_SYSOP 'Exibir indicativo no painel? / Show sysop callsign? [S/n]' yes
  ask_yes_no SHOW_LOCATION 'Exibir localização? / Show location? [S/n]' yes
  ask_yes_no SHOW_EMAIL 'Exibir e-mail? / Show e-mail? [s/N]' no
  ask_yes_no ENABLE_PWA 'Permitir instalação como PWA? / Enable PWA installation? [S/n]' yes

  printf '\nHTTPS protege o painel. A emissão automática exige que o domínio já aponte para esta VPS.\nHTTPS protects the dashboard. Automatic issuance requires the domain to point to this VPS.\n'
  ask_yes_no ENABLE_HTTPS 'Configurar HTTPS? / Configure HTTPS? [S/n]' yes
  printf '\nO firewall permitirá SSH, web e somente as portas exigidas pelos protocolos escolhidos.\nThe firewall will allow SSH, web and only ports required by selected protocols.\n'
  ask_yes_no ENABLE_FIREWALL 'Configurar firewall? / Configure firewall? [S/n]' yes
  ask_yes_no ENABLE_FAIL2BAN 'Instalar Fail2ban? / Install Fail2ban? [S/n]' yes
  ask_yes_no ENABLE_SECURITY_UPDATES 'Ativar atualizações automáticas de segurança? / Enable automatic security updates? [S/n]' yes
}

show_installation_summary(){
  ui_section 'Resumo / Summary'
  cat <<SUMMARY
Refletor / Reflector: $REFLECTOR_ID
Nome / Name: $PUBLIC_NAME
Descrição / Description: $DESCRIPTION
Domínio / Domain: $DOMAIN
Sysop: $SYSOP_CALLSIGN
E-mail: $CONTACT_EMAIL
Localização / Location: $LOCATION
País / Country: $COUNTRY
Fuso / Timezone: $TIMEZONE
Módulos / Modules: $MODULES
D-STAR: $ENABLE_DSTAR
DMR: $ENABLE_DMR
C4FM/YSF: $ENABLE_YSF
NXDN: $ENABLE_NXDN
P25: $ENABLE_P25
M17: $ENABLE_M17
XLX Echo: $INSTALL_ECHO ${ECHO_MODULE:-}
Dashboard: $INSTALL_DASHBOARD
HTTPS: $ENABLE_HTTPS
Firewall: $ENABLE_FIREWALL
Fail2ban: $ENABLE_FAIL2BAN
Security updates: $ENABLE_SECURITY_UPDATES
SUMMARY
  ask_yes_no CONFIRM_SUMMARY 'As informações estão corretas? / Are these settings correct? [S/n]' yes
  [ "$CONFIRM_SUMMARY" = yes ] || { ui_error 'Configuração cancelada para revisão.'; exit 1; }
}
