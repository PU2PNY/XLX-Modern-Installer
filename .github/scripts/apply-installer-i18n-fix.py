from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, got {count}")
    return text.replace(old, new, 1)


def replace_regex(text: str, pattern: str, new: str, label: str) -> str:
    out, count = re.subn(pattern, new, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 regex match, got {count}")
    return out


# ---------------------------------------------------------------------------
# install.sh — installer language and dashboard language are independent.
# ---------------------------------------------------------------------------
p = ROOT / "install.sh"
s = p.read_text(encoding="utf-8")

s = replace_once(
    s,
    '[ "$TUI_MODE" != "force" ] || fatal "A interface Textual exige uma sessão de terminal interativa compatível."',
    '[ "$TUI_MODE" != "force" ] || fatal "$(msg "A interface Textual exige uma sessão de terminal interativa compatível." "The Textual interface requires a compatible interactive terminal session.")"',
    "TUI terminal error",
)
s = replace_once(
    s,
    '[ "$TUI_MODE" != "force" ] || fatal "Não foi possível preparar a interface Textual."',
    '[ "$TUI_MODE" != "force" ] || fatal "$(msg "Não foi possível preparar a interface Textual." "The Textual interface could not be prepared.")"',
    "TUI prepare error",
)
s = replace_once(
    s,
    'warn "A interface visual não pôde ser iniciada; continuando com o instalador clássico."',
    'warn "$(msg "A interface visual não pôde ser iniciada; continuando com o instalador clássico." "The visual interface could not be started; continuing with the classic installer.")"',
    "TUI fallback warning",
)

# English plan first, Portuguese plan second.
s = replace_once(s, '- APRS/D-PRS: native and mandatory / nativo e obrigatório', '- APRS/D-PRS: native and mandatory', "English plan")
s = replace_once(s, '- APRS/D-PRS: native and mandatory / nativo e obrigatório', '- APRS/D-PRS: nativo e obrigatório', "Portuguese plan")

# Replace the deliberately bilingual base-installer translation with a strict
# pt-BR-only translation. English keeps the vendored installer's native English.
pt_block = r'''
    # Strict language isolation. The language chooser above is the only
    # intentionally bilingual screen because no language has been selected yet.
    # After selection, English stays native English and pt-BR becomes pt-BR only.
    if [ "$UI_LANG" = "pt-BR" ]; then
        sed -i \
            -e 's|XLX MULTIPROTOCOL AMATEUR RADIO REFLECTOR INSTALLER PROGRAM|INSTALADOR DO REFLETOR XLX MULTIPROTOCOLO|' \
            -e 's|Next, you will be asked some questions\. Answer with the requested information or, if applicable, to accept the suggested value, press \[ENTER\]|A seguir, responda às perguntas. Para aceitar um valor sugerido, pressione [ENTER].|' \
            -e 's|At any prompt, type X and press \[ENTER\] to cancel the installation\.|Em qualquer pergunta, digite X e pressione [ENTER] para cancelar a instalação.|' \
            -e 's|REFLECTOR DATA INPUT|DADOS DO REFLETOR|' \
            -e 's|Mandatory|Obrigatório|g' \
            -e 's|Suggested:|Sugerido:|g' \
            -e 's|Using:|Usando:|g' \
            -e 's|Installation cancelled by user\. No changes were made to the system\.|Instalação cancelada pelo usuário. Nenhuma alteração foi feita no sistema.|g' \
            -e 's|01\. XLX Reflector ID, 3 alphanumeric characters\. (e\.g\., 026, 724, PNY)|01. ID do refletor XLX: 3 caracteres alfanuméricos (ex.: 026, 724, PNY)|' \
            -e 's|Invalid ID\. Must be exactly 3 characters (A-Z and/or 0-9)\. Try again!|ID inválido. Use exatamente 3 caracteres (A-Z e/ou 0-9). Tente novamente!|' \
            -e 's|02\. Dashboard FQDN (fully qualified domain name)\. (e\.g\., xlx026\.net)|02. Domínio completo FQDN do painel (ex.: xlx026.net)|' \
            -e 's|Invalid domain\. Must be a valid FQDN (e\.g\., xlx026\.net)\.|Domínio inválido. Informe um FQDN válido (ex.: xlx026.net).|' \
            -e 's|03\. Sysop e-mail address|03. E-mail do sysop|' \
            -e 's|Invalid email format\. (e\.g\., user@domain\.com)\.|Formato de e-mail inválido (ex.: usuario@dominio.com).|' \
            -e 's|04\. Sysop callsign\. Only letters and numbers allowed, max 6 characters\.|04. Indicativo do sysop: somente letras e números, máximo 6 caracteres.|' \
            -e 's|Invalid callsign\. Use only letters and numbers, 3 - 6 characters\.|Indicativo inválido. Use somente letras e números, de 3 a 6 caracteres.|' \
            -e 's|05\. Reflector country name\.|05. Nome do país do refletor.|' \
            -e 's|This field is mandatory and cannot be empty\. Try again!|Este campo é obrigatório e não pode ficar vazio. Tente novamente!|g' \
            -e 's|06\. Local timezone\. Detected:|06. Fuso horário local detectado:|' \
            -e 's|Press ENTER to keep it or type another timezone\.|Pressione ENTER para manter ou informe outro fuso.|' \
            -e 's|06\. What is the local timezone? (e\.g\., America/Sao_Paulo, UTC, GMT-3)|06. Qual é o fuso horário local? (ex.: America/Sao_Paulo, UTC, GMT-3)|' \
            -e 's|Invalid timezone\. Please try again\.|Fuso horário inválido. Tente novamente.|' \
            -e 's|Warning: Timezone file not found\. Using system default\.|Atenção: arquivo de fuso horário não encontrado. Usando o padrão do sistema.|' \
            -e 's|Selected timezone:|Fuso horário selecionado:|' \
            -e 's|IMPORTANT: Linux POSIX GMT zones use inverted sign notation\.|IMPORTANTE: as zonas GMT POSIX do Linux usam sinal invertido.|' \
            -e 's|Confirm this timezone? (Y/N, ENTER = Y)|Confirmar este fuso horário? (S/N, ENTER = S)|' \
            -e 's|Please inform your timezone or press ENTER to accept detected\.|Informe seu fuso horário ou pressione ENTER para aceitar o detectado.|' \
            -e 's|07\. Comment to XLX Reflectors list\.|07. Comentário para a lista de refletores XLX.|' \
            -e 's|Comment must be max 100 characters\. Please try again!|O comentário deve ter no máximo 100 caracteres. Tente novamente!|' \
            -e 's|08\. Custom text for the dashboard tab\. (max 25 characters)|08. Texto da aba do painel (máximo 25 caracteres)|' \
            -e 's|Tab page text must be max 25 characters\. Please try again!|O texto da aba deve ter no máximo 25 caracteres. Tente novamente!|' \
            -e 's|09\. Custom text on footer of the dashboard webpage\.|09. Texto do rodapé do painel.|' \
            -e 's|Footer must be max 50 characters\. Please try again!|O rodapé deve ter no máximo 50 caracteres. Tente novamente!|' \
            -e 's|10\. Create an SSL certificate (https) for the dashboard webpage? (Y/N)|10. Criar certificado SSL/HTTPS para o painel? (S/N)|' \
            -e 's|11\. Install Echo Test on module E? (Y/N)|11. Instalar Echo Test no módulo E? (S/N)|' \
            -e "s|Please enter 'Y' or 'N'\.|Digite 'S' ou 'N'.|g" \
            -e 's|12\. Number of active modules for the DStar Reflector\.|12. Quantidade de módulos ativos do refletor D-STAR.|' \
            -e 's|Must be a number between \([^ ]*\) and 26\. Try again!|Informe um número entre \1 e 26. Tente novamente!|' \
            -e 's|13\. YSF Reflector UDP port number\. (1-65535)|13. Porta UDP do refletor YSF (1-65535)|' \
            -e 's|Must be a number between 1 and 65535\. Try again!|Informe um número entre 1 e 65535. Tente novamente!|' \
            -e 's|Warning: Port \([^ ]*\) appears to be in use\.|Atenção: a porta \1 parece estar em uso.|' \
            -e 's|Do you want to continue anyway? (Y/N)|Deseja continuar mesmo assim? (S/N)|' \
            -e 's|Please enter a different port, or \[ENTER\] to accept suggested\.|Informe outra porta ou pressione [ENTER] para aceitar a sugerida.|' \
            -e 's|Please answer Y or N\.|Responda S ou N.|g' \
            -e 's|14\. YSF Wires-X frequency\. In Hertz, 9 digits\.|14. Frequência YSF Wires-X em Hertz, 9 dígitos.|' \
            -e 's|Must be exactly 9 numeric digits (e\.g\., 433125000)\. Try again!|Informe exatamente 9 dígitos numéricos (ex.: 433125000). Tente novamente!|' \
            -e 's|15\. Auto-link YSF to a module? (Y/N)|15. Vincular YSF automaticamente a um módulo? (S/N)|' \
            -e 's|16\. Module to Auto-link YSF\.|16. Módulo para vínculo automático YSF.|' \
            -e 's|One of|Uma das opções|g' \
            -e 's|Choose from|Escolha de|g' \
            -e 's|Invalid entry\. Valid modules are:|Entrada inválida. Módulos válidos:|' \
            -e 's|Invalid entry\. Choose from|Entrada inválida. Escolha de|' \
            -e 's|17\. City and state/region shown on the dashboard\.|17. Cidade e estado/região exibidos no painel.|' \
            -e 's|18\. YSF reflector ID shown on the dashboard\. (1-8 digits)|18. ID do refletor YSF exibido no painel (1-8 dígitos)|' \
            -e 's|Invalid YSF ID\. Use 1 to 8 digits\.|ID YSF inválido. Use de 1 a 8 dígitos.|' \
            -e 's|19\. Private Admin username\. (3-64 characters)|19. Usuário do Admin privado (3-64 caracteres)|' \
            -e 's|Use 3 to 64 characters: letters, numbers, dot, underscore or hyphen\.|Use de 3 a 64 caracteres: letras, números, ponto, sublinhado ou hífen.|' \
            -e 's|20\. Private Admin URL name\.|20. Nome da URL privada do Admin.|' \
            -e 's|Use 2 to 32 characters: lowercase letters, numbers and hyphens; choose a name that does not conflict with a public dashboard route\.|Use de 2 a 32 caracteres: letras minúsculas, números e hífens; escolha um nome que não conflite com uma rota pública do painel.|' \
            -e 's|21\. Private Admin password\. (minimum 8 characters)|21. Senha do Admin privado (mínimo 8 caracteres)|' \
            -e 's|Repeat password:|Repita a senha:|' \
            -e 's|Password must contain at least 8 characters\.|A senha deve conter pelo menos 8 caracteres.|' \
            -e 's|Passwords do not match\. Try again\.|As senhas não coincidem. Tente novamente.|' \
            -e 's|password defined (not displayed)|senha definida (não exibida)|g' \
            -e 's|PLEASE REVIEW YOUR SETTINGS:|REVISE AS CONFIGURAÇÕES:|' \
            -e 's|Reflector ID:|ID do refletor:|g' \
            -e 's|Callsign:|Indicativo:|g' \
            -e 's|Country:|País:|g' \
            -e 's|Time Zone:|Fuso horário:|g' \
            -e 's|XLX list comment:|Comentário da lista XLX:|g' \
            -e 's|Tab page text:|Texto da aba:|g' \
            -e 's|Dashboard footnote:|Rodapé do painel:|g' \
            -e 's|SSL certification:|Certificado SSL:|g' \
            -e 's|Modules:|Módulos:|g' \
            -e 's|YSF frequency:|Frequência YSF:|g' \
            -e 's|YSF Auto-link:|Vínculo automático YSF:|g' \
            -e 's|YSF module:|Módulo YSF:|g' \
            -e 's|City / region:|Cidade / região:|g' \
            -e 's|YSF reflector ID:|ID do refletor YSF:|g' \
            -e 's|Admin username:|Usuário Admin:|g' \
            -e 's|Admin password:|Senha Admin:|g' \
            -e 's|Settings correct? Press \[ENTER\] to confirm, type a question number to edit it, or \[X\] to cancel the installation\.|Configurações corretas? Pressione [ENTER] para confirmar, digite o número da pergunta para editar ou [X] para cancelar a instalação.|' \
            -e 's|Information verified, installation starting!|Informações verificadas, iniciando a instalação!|' \
            -e 's|Installation cancelled by user\.|Instalação cancelada pelo usuário.|g' \
            -e 's|Minimum modules changed\. Please reconfigure question 12\.|O mínimo de módulos mudou. Reconfigure a pergunta 12.|' \
            -e 's|Echo Test removed\. Module minimum is now 1\.|Echo Test removido. O mínimo de módulos agora é 1.|' \
            -e 's|Selected YSF Auto-link module is no longer valid, choose another\.|O módulo selecionado para vínculo automático YSF não é mais válido; escolha outro.|' \
            -e 's|Module range changed\. Please reconfigure question 16\.|O intervalo de módulos mudou. Reconfigure a pergunta 16.|' \
            -e 's|Question 16 is not active\.|A pergunta 16 não está ativa.|' \
            -e 's|Invalid input\. Press \[ENTER\] to confirm, enter a question number (1-21), or \[X\] to cancel\.|Entrada inválida. Pressione [ENTER] para confirmar, informe uma pergunta (1-21) ou [X] para cancelar.|' \
            -e 's|UPDATING OS\.\.\.|ATUALIZANDO O SISTEMA...|g' \
            -e 's|Full operating-system upgrade skipped by design; only required dependencies will be installed\.|A atualização completa do sistema foi ignorada por projeto; somente as dependências necessárias serão instaladas.|' \
            -e 's|Timezone adjustment:|Ajuste de fuso horário:|' \
            -e 's|Applying new timezone:|Aplicando novo fuso horário:|' \
            -e 's|Detected system timezone preserved:|Fuso horário detectado preservado:|' \
            -e 's|System updated successfully!|Sistema atualizado com sucesso!|' \
            -e 's|INSTALLING DEPENDENCIES\.\.\.|INSTALANDO DEPENDÊNCIAS...|g' \
            -e 's|PHP version:|Versão do PHP:|' \
            -e 's|Dependencies installed!|Dependências instaladas!|' \
            -e 's|DOWNLOADING THE XLX APP\.\.\.|BAIXANDO O XLX...|g' \
            -e 's|Cloning repository\.\.\.|Clonando repositório...|g' \
            -e 's|Seeding customizations\.\.\.|Aplicando personalizações...|g' \
            -e 's|Reflector |Refletor |g' \
            -e 's|Ethernet IP address:|Endereço IP Ethernet:|' \
            -e 's|Public IP address:|Endereço IP público:|' \
            -e 's|Network adapter name:|Nome do adaptador de rede:|' \
            -e 's|Repository cloned and customizations applied!|Repositório clonado e personalizações aplicadas!|' \
            -e 's|COMPILING\.\.\.|COMPILANDO...|g' \
            -e 's|COMPILATION SUCCESSFUL!!!|COMPILAÇÃO CONCLUÍDA COM SUCESSO!!!|' \
            -e 's|Compilation FAILED\. Check the output for errors\.|A compilação FALHOU. Verifique a saída para identificar os erros.|' \
            -e 's|COPYING COMPONENTS\.\.\.|COPIANDO COMPONENTES...|g' \
            -e 's|Downloading DMR ID file\.\.\.|Baixando arquivo de IDs DMR...|g' \
            -e 's|Downloading\.\.\.|Baixando...|g' \
            -e 's|File size:|Tamanho do arquivo:|' \
            -e 's|DMR ID download: SUCCESS|Download de IDs DMR: SUCESSO|g' \
            -e 's|DMR ID file downloaded successfully\.|Arquivo de IDs DMR baixado com sucesso.|' \
            -e 's|DMR ID download: FAILED|Download de IDs DMR: FALHOU|g' \
            -e 's|Creating custom XLX log\.\.\.|Criando log personalizado do XLX...|g' \
            -e 's|Components copied and configured!|Componentes copiados e configurados!|' \
            -e 's|INSTALLING ECHO TEST SERVER\.\.\.|INSTALANDO SERVIDOR DE TESTE ECHO...|g' \
            -e 's|Compiling Echo Test\.\.\.|Compilando Echo Test...|g' \
            -e 's|Copying files and adjusting properties\.\.\.|Copiando arquivos e ajustando propriedades...|g' \
            -e 's|Echo Test server successfully installed!|Servidor Echo Test instalado com sucesso!|' \
            -e 's|Configuration completed!|Configuração concluída!|g' \
            -e 's|STARTING \(.*\) REFLECTOR\.\.\.|INICIANDO REFLETOR \1...|g' \
            -e 's|Initializing XLX log|Inicializando log XLX|g' \
            -e 's|Initializing Echo Test|Inicializando Echo Test|g' \
            -e 's|Initialization completed!|Inicialização concluída!|g' \
            -e 's|Running post-installation validation\.\.\.|Executando validação pós-instalação...|g' \
            -e 's|XLXD binary found|Binário XLXD encontrado|g' \
            -e 's|XLXD service is running|Serviço XLXD está ativo|g' \
            -e 's|XLX log service is running|Serviço de log XLX está ativo|g' \
            -e 's|Echo Test service is running|Serviço Echo Test está ativo|g' \
            -e 's|REFLECTOR INSTALLED SUCCESSFULLY!!!|REFLETOR INSTALADO COM SUCESSO!!!|g' \
            -e 's|Your Reflector \(.*\) is now installed and running!|Seu refletor \1 está instalado e em funcionamento!|g' \
            -e 's|For Public Reflectors:|Para refletores públicos:|g' \
            -e '/^[[:space:]]*INSTALL_SSL=$(echo /a\        [[ "$INSTALL_SSL" == "S" ]] && INSTALL_SSL="Y"' \
            -e '/^[[:space:]]*INSTALL_ECHO=$(echo /a\        [[ "$INSTALL_ECHO" == "S" ]] && INSTALL_ECHO="Y"' \
            -e '/^[[:space:]]*PORT_ANSWER=$(echo /a\                [[ "$PORT_ANSWER" == "S" ]] && PORT_ANSWER="Y"' \
            -e '/^[[:space:]]*AUTOLINK_USER=$(echo /a\        [[ "$AUTOLINK_USER" == "S" ]] && AUTOLINK_USER="Y"' \
            -e '/^[[:space:]]*CONFIRM_TZ=$(echo /a\        [[ "$CONFIRM_TZ" == "S" ]] && CONFIRM_TZ="Y"' \
            "$translated"
    fi
'''

s = replace_regex(
    s,
    r'\n    # Questionário clássico bilíngue:.*?\n        "\$translated"\n',
    "\n" + pt_block,
    "bilingual base-installer block",
)

p.write_text(s, encoding="utf-8")


# ---------------------------------------------------------------------------
# start.sh — do not advertise bilingual output after selection.
# ---------------------------------------------------------------------------
p = ROOT / "start.sh"
p.write_text(
    '''#!/usr/bin/env bash\nset -Eeuo pipefail\numask 077\n\nROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"\nexec bash "$ROOT_DIR/install.sh" "$@" --classic\n''',
    encoding="utf-8",
)


# ---------------------------------------------------------------------------
# Dashboard installer — operator language follows XLX_UI_LANG only.
# Dashboard content language remains DASHBOARD_LANG (six independent locales).
# ---------------------------------------------------------------------------
p = ROOT / "dashboard/install/install-dashboard.sh"
d = p.read_text(encoding="utf-8")

d = replace_once(
    d,
    'PROJECT_VERSION="$(cat "$ROOT/../VERSION" 2>/dev/null || printf \'unknown\')"\n',
    'PROJECT_VERSION="$(cat "$ROOT/../VERSION" 2>/dev/null || printf \'unknown\')"\nUI_LANG="${XLX_UI_LANG:-pt-BR}"\ncase "$UI_LANG" in pt-BR|en) ;; *) UI_LANG="pt-BR" ;; esac\n\nui() {\n    local pt="$1" en="$2"\n    if [ "$UI_LANG" = "en" ]; then printf \'%s\' "$en"; else printf \'%s\' "$pt"; fi\n}\n',
    "dashboard UI language helper",
)

d = replace_once(d, '        *) echo "ERROR / ERRO: unknown option / opção desconhecida: $arg" >&2; exit 2 ;;', '        *) echo "$(ui "ERRO: opção desconhecida: $arg" "ERROR: unknown option: $arg")" >&2; exit 2 ;;', "dashboard unknown option")

choose = r'''choose_language() {
    local answer normalized

    if [ -n "$DASHBOARD_LANG" ]; then
        normalized="$(normalize_lang "$DASHBOARD_LANG" 2>/dev/null || true)"
        [ -n "$normalized" ] || {
            echo "$(ui "ERRO: idioma do painel não suportado: $DASHBOARD_LANG" "ERROR: unsupported dashboard language: $DASHBOARD_LANG")" >&2
            exit 2
        }
        DASHBOARD_LANG="$normalized"
        return
    fi

    printf '\n============================================================\n %s\n============================================================\n' "$(ui 'Idioma do Painel' 'Dashboard Language')"
    printf '%s\n' \
        '  1) Português (Brasil)' \
        '  2) English' \
        '  3) Español' \
        '  4) Français' \
        '  5) Deutsch' \
        '  6) Italiano'

    while :; do
        read -r -p "$(ui 'Escolha [1-6]: ' 'Choose [1-6]: ')" answer
        case "$answer" in
            1) DASHBOARD_LANG='pt-BR'; break ;;
            2) DASHBOARD_LANG='en'; break ;;
            3) DASHBOARD_LANG='es'; break ;;
            4) DASHBOARD_LANG='fr'; break ;;
            5) DASHBOARD_LANG='de'; break ;;
            6) DASHBOARD_LANG='it'; break ;;
            *) echo "$(ui 'Opção inválida.' 'Invalid option.')" ;;
        esac
    done
}
'''
d = replace_regex(d, r'choose_language\(\) \{.*?\n\}\n\nprompt_text\(\)', choose + '\nprompt_text()', "dashboard choose_language")

prompt = r'''prompt_text() {
    local key="$1"
    case "$UI_LANG:$key" in
        pt-BR:reflector) printf '%s' 'Identificação do refletor' ;;
        pt-BR:title) printf '%s' 'Nome exibido' ;;
        pt-BR:description) printf '%s' 'Descrição curta' ;;
        pt-BR:sysop) printf '%s' 'Indicativo do responsável' ;;
        pt-BR:location) printf '%s' 'Cidade e estado/região' ;;
        pt-BR:country) printf '%s' 'País' ;;
        pt-BR:domain) printf '%s' 'Domínio' ;;
        pt-BR:email) printf '%s' 'E-mail de contato' ;;
        *:reflector) printf '%s' 'Reflector identifier' ;;
        *:title) printf '%s' 'Displayed name' ;;
        *:description) printf '%s' 'Short description' ;;
        *:sysop) printf '%s' 'Sysop callsign' ;;
        *:location) printf '%s' 'City and state/region' ;;
        *:country) printf '%s' 'Country' ;;
        *:domain) printf '%s' 'Domain' ;;
        *:email) printf '%s' 'Contact email' ;;
    esac
}
'''
d = replace_regex(d, r'prompt_text\(\) \{.*?\n\}\n\nask\(\)', prompt + '\nask()', "dashboard prompt_text")

pairs = [
    ("printf '%s: %s [reaproveitado]\\n' \"$(prompt_text \"$label_key\")\" \"$value\"", "printf '%s: %s [%s]\\n' \"$(prompt_text \"$label_key\")\" \"$value\" \"$(ui 'reaproveitado' 'reused')\""),
    ('[ -f "$file" ] || { echo "ERROR / ERRO: dados iniciais não encontrados: $file" >&2; exit 1; }', '[ -f "$file" ] || { echo "$(ui "ERRO: dados iniciais não encontrados: $file" "ERROR: initial data not found: $file")" >&2; exit 1; }'),
    ("printf 'Dados já informados serão reaproveitados.\\n\\n'", "printf '%s\\n\\n' \"$(ui 'Dados já informados serão reaproveitados.' 'Previously supplied data will be reused.')\""),
    ('echo "Run as root / Execute como root." >&2', 'echo "$(ui "Execute como root." "Run as root.")" >&2'),
    ('echo "ERROR / ERRO: invalid XLXD module count / quantidade de módulos XLXD inválida: $MODULE_COUNT" >&2', 'echo "$(ui "ERRO: quantidade de módulos XLXD inválida: $MODULE_COUNT" "ERROR: invalid XLXD module count: $MODULE_COUNT")" >&2'),
    ("printf 'Dashboard language / Idioma do painel: %s (%s)\\n' \"$(language_name \"$DASHBOARD_LANG\")\" \"$DASHBOARD_LANG\"", "printf '%s: %s (%s)\\n' \"$(ui 'Idioma do painel' 'Dashboard language')\" \"$(language_name \"$DASHBOARD_LANG\")\" \"$DASHBOARD_LANG\""),
    ("printf 'XLXD modules / Módulos XLXD: A-%s (%s)\\n\\n' \"$(module_last_letter \"$MODULE_COUNT\")\" \"$MODULE_COUNT\"", "printf '%s: A-%s (%s)\\n\\n' \"$(ui 'Módulos XLXD' 'XLXD modules')\" \"$(module_last_letter \"$MODULE_COUNT\")\" \"$MODULE_COUNT\""),
    ('echo "ERROR / ERRO: reflector identifier must use XLX + 3 alphanumeric characters (A-Z/0-9), examples XLX123 or XLXPNY." >&2', 'echo "$(ui "ERRO: o identificador deve usar XLX + 3 caracteres alfanuméricos (A-Z/0-9), exemplos XLX123 ou XLXPNY." "ERROR: reflector identifier must use XLX + 3 alphanumeric characters (A-Z/0-9), examples XLX123 or XLXPNY.")" >&2'),
    ('echo "ERROR / ERRO: domínio inválido: $DOMAIN" >&2', 'echo "$(ui "ERRO: domínio inválido: $DOMAIN" "ERROR: invalid domain: $DOMAIN")" >&2'),
    ('echo "ERROR / ERRO: Invalid YSF ID / ID YSF inválido: $YSF_ID" >&2', 'echo "$(ui "ERRO: ID YSF inválido: $YSF_ID" "ERROR: invalid YSF ID: $YSF_ID")" >&2'),
    ("printf 'YSF reflector ID / ID do refletor YSF: %s [reaproveitado]\\n' \"$YSF_ID\"", "printf '%s: %s [%s]\\n' \"$(ui 'ID do refletor YSF' 'YSF reflector ID')\" \"$YSF_ID\" \"$(ui 'reaproveitado' 'reused')\""),
    ('read -r -p "YSF reflector ID / ID do refletor YSF: " YSF_ID', 'read -r -p "$(ui "ID do refletor YSF: " "YSF reflector ID: ")" YSF_ID'),
    ('echo "Invalid YSF ID / ID YSF inválido."', 'echo "$(ui "ID YSF inválido." "Invalid YSF ID.")"'),
    ('echo "ERROR / ERRO: i18n builder not found: $DEST/i18n/build.php" >&2', 'echo "$(ui "ERRO: construtor i18n não encontrado: $DEST/i18n/build.php" "ERROR: i18n builder not found: $DEST/i18n/build.php")" >&2'),
    ('echo "ERROR / ERRO: placeholder renderer not found: $ROOT/install/render-placeholders.php" >&2', 'echo "$(ui "ERRO: renderizador de placeholders não encontrado: $ROOT/install/render-placeholders.php" "ERROR: placeholder renderer not found: $ROOT/install/render-placeholders.php")" >&2'),
    ("printf 'HTTPS certificate already present / certificado HTTPS já existente: %s\\n' \"$DOMAIN\"", "printf '%s: %s\\n' \"$(ui 'Certificado HTTPS já existente' 'HTTPS certificate already present')\" \"$DOMAIN\""),
    ("printf '[OK] HTTPS enabled / HTTPS ativado: %s\\n' \"$DOMAIN\"", "printf '[OK] %s: %s\\n' \"$(ui 'HTTPS ativado' 'HTTPS enabled')\" \"$DOMAIN\""),
    ("printf '[INFO] Manual retry / tentativa manual: %s %q %q\\n' \"$HTTPS_RETRY\" \"$DOMAIN\" \"$CONTACT_EMAIL\" >&2", "printf '[INFO] %s: %s %q %q\\n' \"$(ui 'Tentativa manual' 'Manual retry')\" \"$HTTPS_RETRY\" \"$DOMAIN\" \"$CONTACT_EMAIL\" >&2"),
]
for old, new in pairs:
    if old in d:
        d = d.replace(old, new, 1)

# HTTPS prompt and reused state are installer UI, not dashboard content language.
d = d.replace('read -r -p "Ativar HTTPS com certificado Let\'s Encrypt? / Enable HTTPS with a Let\'s Encrypt certificate? [S/n]: " HTTPS_ANSWER', 'read -r -p "$(ui "Ativar HTTPS com certificado Let\'s Encrypt? [S/n]: " "Enable HTTPS with a Let\'s Encrypt certificate? [Y/n]: ")" HTTPS_ANSWER')
d = d.replace('echo "Resposta inválida / Invalid answer. Use S ou N / Y or N."', 'echo "$(ui "Resposta inválida. Use S ou N." "Invalid answer. Use Y or N.")"')

d = d.replace("printf '[WARNING] HTTPS certificate could not be issued now; installation will continue over HTTP.\\n' >&2\n            printf '[ATENÇÃO] O certificado HTTPS não pôde ser emitido agora; a instalação continuará em HTTP.\\n' >&2", "printf '%s %s\\n' \"$(ui '[ATENÇÃO]' '[WARNING]')\" \"$(ui 'O certificado HTTPS não pôde ser emitido agora; a instalação continuará em HTTP.' 'HTTPS certificate could not be issued now; installation will continue over HTTP.')\" >&2")

d = d.replace("printf '[WARNING] Debian 12 Certbot 2.1.x hit its known Python 3.11 error while reporting an ACME failure.\\n' >&2\n                printf '[ATENÇÃO] O Certbot 2.1.x do Debian 12 encontrou o erro conhecido do Python 3.11 ao reportar uma falha ACME.\\n' >&2", "printf '%s %s\\n' \"$(ui '[ATENÇÃO]' '[WARNING]')\" \"$(ui 'O Certbot 2.1.x do Debian 12 encontrou o erro conhecido do Python 3.11 ao reportar uma falha ACME.' 'Debian 12 Certbot 2.1.x hit its known Python 3.11 error while reporting an ACME failure.')\" >&2")

p.write_text(d, encoding="utf-8")


# ---------------------------------------------------------------------------
# Regression tests.
# ---------------------------------------------------------------------------
test = ROOT / "tests/test-installer-language-contract.sh"
test.write_text(r'''#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
ok(){ printf '[OK] %s\n' "$*"; }

bash -n "$ROOT/install.sh"
bash -n "$ROOT/start.sh"
bash -n "$ROOT/dashboard/install/install-dashboard.sh"

grep -Fq 'Strict language isolation.' "$ROOT/install.sh" || fail 'strict installer-language contract missing'
! grep -Fq 'Questionário clássico bilíngue' "$ROOT/install.sh" || fail 'legacy bilingual base-installer mode still present'
! grep -Fq 'native and mandatory / nativo e obrigatório' "$ROOT/install.sh" || fail 'mixed-language install-plan line remains'
! grep -Fq 'Perguntas em Português + English' "$ROOT/start.sh" || fail 'entry point still advertises bilingual flow'

grep -Fq 'UI_LANG="${XLX_UI_LANG:-pt-BR}"' "$ROOT/dashboard/install/install-dashboard.sh" || fail 'dashboard installer does not consume installer UI language'
grep -Fq 'case "$UI_LANG:$key"' "$ROOT/dashboard/install/install-dashboard.sh" || fail 'operator prompts are still tied to dashboard content language'
! grep -Fq 'Dashboard Language / Idioma do Painel' "$ROOT/dashboard/install/install-dashboard.sh" || fail 'bilingual dashboard language heading remains'
! grep -Fq 'ERROR / ERRO:' "$ROOT/dashboard/install/install-dashboard.sh" || fail 'bilingual dashboard installer error remains'
! grep -Fq 'Manual retry / tentativa manual' "$ROOT/dashboard/install/install-dashboard.sh" || fail 'bilingual HTTPS retry remains'

ok 'installer/operator language is isolated from dashboard content language'
''', encoding="utf-8")
test.chmod(0o755)

parity = ROOT / "tests/test-dashboard-locale-key-parity.php"
parity.write_text(r'''<?php
$root = dirname(__DIR__);
$locales = ['pt-BR', 'en', 'es', 'fr', 'de', 'it'];
$baseline = require $root . '/dashboard/i18n/locales/en.php';
$baseKeys = array_keys($baseline);
sort($baseKeys);
foreach ($locales as $locale) {
    $data = require $root . '/dashboard/i18n/locales/' . $locale . '.php';
    if (!is_array($data)) {
        fwrite(STDERR, "[FAIL] locale $locale did not return an array\n");
        exit(1);
    }
    $keys = array_keys($data);
    sort($keys);
    $missing = array_values(array_diff($baseKeys, $keys));
    $extra = array_values(array_diff($keys, $baseKeys));
    if ($missing || $extra) {
        fwrite(STDERR, "[FAIL] locale $locale key mismatch\n");
        if ($missing) fwrite(STDERR, "missing: " . implode(', ', $missing) . "\n");
        if ($extra) fwrite(STDERR, "extra: " . implode(', ', $extra) . "\n");
        exit(1);
    }
}
echo "[OK] all dashboard locales have exact key parity with English\n";
''', encoding="utf-8")

runall = ROOT / "tests/run-all.sh"
r = runall.read_text(encoding="utf-8")
anchor = 'echo "[installation flow]"\n'
insert = 'echo "[installer language contract]"\nbash "$ROOT/tests/test-installer-language-contract.sh" || failures=$((failures+1))\n\necho "[dashboard locale key parity]"\nphp "$ROOT/tests/test-dashboard-locale-key-parity.php" || failures=$((failures+1))\n\n'
if insert not in r:
    if anchor not in r:
        raise SystemExit("tests/run-all.sh anchor not found")
    r = r.replace(anchor, insert + anchor, 1)
runall.write_text(r, encoding="utf-8")

print("installer language isolation patch prepared")
