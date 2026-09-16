from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def one(text, old, new, label):
    n = text.count(old)
    if n != 1:
        raise SystemExit(f"{label}: expected 1 match, got {n}")
    return text.replace(old, new, 1)


# Main installer: resolve installer UI language before help/errors are printed.
p = ROOT / "install.sh"
s = p.read_text(encoding="utf-8")

start = s.index('for arg in "$@"; do\n    case "$arg" in\n        --check|--dry-run)')
end_marker = 'done\n\nif [ "$UI_LANG_EXPLICIT" != "yes" ]; then'
end = s.index(end_marker, start)

new_parser = r'''# Resolve the installer/operator language before parsing options that may print
# help or errors. Dashboard content language remains an independent setting.
for arg in "$@"; do
    case "$arg" in
        --ui-lang=*) UI_LANG="${arg#*=}"; UI_LANG_EXPLICIT="yes" ;;
    esac
done
if [ "$UI_LANG_EXPLICIT" != "yes" ]; then
    for arg in "$@"; do
        case "$arg" in
            --lang=en) UI_LANG="en" ;;
            --lang=*) UI_LANG="pt-BR" ;;
        esac
    done
fi

print_help() {
    if [ "$UI_LANG" = "en" ]; then
        cat <<'HELP_EN'
XLX Modern Installer

Usage:
  sudo bash install.sh --check
  sudo bash install.sh
  sudo bash install.sh --lang=en
  sudo bash install.sh --ui-lang=en --lang=es
  sudo bash install.sh --dashboard-only
  sudo bash install.sh --tui
  sudo bash install.sh --classic

Options:
  --check
      Checks the server only. Does not install or change XLX.

  --lang=CODE
      Sets the public dashboard language independently from the installer language.
      pt-BR | en | es | fr | de | it

  --ui-lang=CODE
      Sets the installer/operator language.
      pt-BR | en

  --tui
      Optional/experimental visual interface. The simple questionnaire is default.

  --classic
      Uses the simple text questionnaire. This is already the default mode.

  --dashboard-only
      Updates or reinstalls only the modern dashboard on an existing XLXD.
      It preserves the XLXD core, creates a safety backup, and does not run a
      full reflector installation.

  --allow-remnants
      Allows continuing when only old installation remnants exist.
      It never deletes files automatically.

  --force-clean
      Legacy alias for --allow-remnants. It does not clean files automatically.
HELP_EN
    else
        cat <<'HELP_PT'
XLX Modern Installer

Uso:
  sudo bash install.sh --check
  sudo bash install.sh
  sudo bash install.sh --lang=pt-BR
  sudo bash install.sh --ui-lang=pt-BR --lang=es
  sudo bash install.sh --dashboard-only
  sudo bash install.sh --tui
  sudo bash install.sh --classic

Opções:
  --check
      Apenas verifica o servidor. Não instala nem altera o XLX.

  --lang=CODE
      Define o idioma do painel público independentemente do idioma do instalador.
      pt-BR | en | es | fr | de | it

  --ui-lang=CODE
      Define o idioma do instalador/operador.
      pt-BR | en

  --tui
      Interface visual opcional/experimental. O padrão é o questionário simples.

  --classic
      Usa o questionário simples em texto. Este já é o modo padrão.

  --dashboard-only
      Atualiza ou reinstala somente o painel moderno em um XLXD existente.
      Preserva o núcleo XLXD, cria backup preventivo e não executa a instalação
      completa do refletor.

  --allow-remnants
      Permite continuar quando existem apenas vestígios de instalação antiga.
      Não apaga arquivos automaticamente.

  --force-clean
      Alias legado de --allow-remnants. Não executa limpeza automática.
HELP_PT
    fi
}

for arg in "$@"; do
    case "$arg" in
        --check|--dry-run) MODE="check" ;;
        --dashboard-only) DASHBOARD_ONLY="yes" ;;
        --allow-remnants|--force-clean) ALLOW_REMNANTS="yes" ;;
        --lang=*) DASHBOARD_LANG="${arg#*=}" ;;
        --ui-lang=*) UI_LANG="${arg#*=}"; UI_LANG_EXPLICIT="yes" ;;
        --tui) TUI_MODE="force" ;;
        --classic|--no-tui) TUI_MODE="off" ;;
        --tui-child) TUI_MODE="child" ;;
        -h|--help) print_help; exit 0 ;;
        *)
            if [ "$UI_LANG" = "en" ]; then
                printf 'ERROR: unknown option: %s\n' "$arg" >&2
            else
                printf 'ERRO: opção desconhecida: %s\n' "$arg" >&2
            fi
            exit 2
            ;;
    esac
done

'''
s = s[:start] + new_parser + s[end:]

s = one(
    s,
    '    *) printf \'ERRO / ERROR: idioma da instalação inválido / invalid installer language: %s\\n\' "$UI_LANG" >&2; exit 2 ;;',
    '    *) printf \'%s: %s\\n\' "${UI_LANG,,}" "invalid installer language" >&2; exit 2 ;;',
    "mixed invalid installer language error",
)

s = one(
    s,
    '            fatal "Arquivo de respostas da interface visual não está disponível: $XLX_MODERN_ANSWERS_FILE"',
    '            fatal "$(msg "Arquivo de respostas da interface visual não está disponível: $XLX_MODERN_ANSWERS_FILE" "The visual-interface answers file is not available: $XLX_MODERN_ANSWERS_FILE")"',
    "visual answers error",
)

p.write_text(s, encoding="utf-8")


# Dashboard installer: localize its help using installer/operator language.
p = ROOT / "dashboard/install/install-dashboard.sh"
d = p.read_text(encoding="utf-8")
old_help = r'''        -h|--help)
            cat <<'HELP'
XLX Modern Dashboard Installer

Usage / Uso:
  sudo bash install-dashboard.sh
  sudo bash install-dashboard.sh --lang=en

Supported dashboard languages / Idiomas suportados:
  pt-BR  Português (Brasil)
  en     English
  es     Español
  fr     Français
  de     Deutsch
  it     Italiano
HELP
            exit 0
            ;;'''
new_help = r'''        -h|--help)
            if [ "$UI_LANG" = "en" ]; then
                cat <<'HELP_EN'
XLX Modern Dashboard Installer

Usage:
  sudo bash install-dashboard.sh
  sudo bash install-dashboard.sh --lang=en

Supported dashboard languages:
  pt-BR  Portuguese (Brazil)
  en     English
  es     Spanish
  fr     French
  de     German
  it     Italian
HELP_EN
            else
                cat <<'HELP_PT'
Instalador do Painel XLX Modern

Uso:
  sudo bash install-dashboard.sh
  sudo bash install-dashboard.sh --lang=pt-BR

Idiomas disponíveis para o painel:
  pt-BR  Português (Brasil)
  en     Inglês
  es     Espanhol
  fr     Francês
  de     Alemão
  it     Italiano
HELP_PT
            fi
            exit 0
            ;;'''
d = one(d, old_help, new_help, "dashboard help")
p.write_text(d, encoding="utf-8")


# Permanent regression test: exercise both language outputs, not just source markers.
t = ROOT / "tests/test-installer-language-contract.sh"
t.write_text(r'''#!/usr/bin/env bash
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
! grep -Fq 'Uso / Usage' "$ROOT/install.sh" || fail 'bilingual main help remains'
! grep -Fq 'ERRO / ERROR:' "$ROOT/install.sh" || fail 'bilingual main error remains'
! grep -Fq 'fatal "Arquivo de respostas da interface visual' "$ROOT/install.sh" || fail 'hard-coded Portuguese visual-answer error remains'
! grep -Fq 'Perguntas em Português + English' "$ROOT/start.sh" || fail 'entry point still advertises bilingual flow'

grep -Fq 'UI_LANG="${XLX_UI_LANG:-pt-BR}"' "$ROOT/dashboard/install/install-dashboard.sh" || fail 'dashboard installer does not consume installer UI language'
grep -Fq 'case "$UI_LANG:$key"' "$ROOT/dashboard/install/install-dashboard.sh" || fail 'operator prompts are still tied to dashboard content language'
! grep -Fq 'Dashboard Language / Idioma do Painel' "$ROOT/dashboard/install/install-dashboard.sh" || fail 'bilingual dashboard language heading remains'
! grep -Fq 'Usage / Uso' "$ROOT/dashboard/install/install-dashboard.sh" || fail 'bilingual dashboard help remains'
! grep -Fq 'ERROR / ERRO:' "$ROOT/dashboard/install/install-dashboard.sh" || fail 'bilingual dashboard installer error remains'
! grep -Fq 'Manual retry / tentativa manual' "$ROOT/dashboard/install/install-dashboard.sh" || fail 'bilingual HTTPS retry remains'

main_en="$(bash "$ROOT/install.sh" --ui-lang=en --help)"
main_pt="$(bash "$ROOT/install.sh" --ui-lang=pt-BR --help)"
dash_en="$(XLX_UI_LANG=en bash "$ROOT/dashboard/install/install-dashboard.sh" --help)"
dash_pt="$(XLX_UI_LANG=pt-BR bash "$ROOT/dashboard/install/install-dashboard.sh" --help)"

printf '%s' "$main_en" | grep -Fq 'Usage:' || fail 'English main help missing'
printf '%s' "$main_en" | grep -Eq '(^|[[:space:]])(Uso|Opções|Apenas|Define|Atualiza|Permite)(:|[[:space:]])' && fail 'Portuguese leaked into English main help'
printf '%s' "$main_pt" | grep -Fq 'Uso:' || fail 'Portuguese main help missing'
printf '%s' "$main_pt" | grep -Eq '(^|[[:space:]])(Usage|Options|Checks|Sets|Updates|Allows)(:|[[:space:]])' && fail 'English leaked into Portuguese main help'

printf '%s' "$dash_en" | grep -Fq 'Supported dashboard languages:' || fail 'English dashboard help missing'
printf '%s' "$dash_en" | grep -Eq '(Uso:|Idiomas disponíveis|Português \(Brasil\)|Espanhol|Francês|Alemão)' && fail 'Portuguese leaked into English dashboard help'
printf '%s' "$dash_pt" | grep -Fq 'Idiomas disponíveis para o painel:' || fail 'Portuguese dashboard help missing'
printf '%s' "$dash_pt" | grep -Eq '(Usage:|Supported dashboard languages:|Portuguese \(Brazil\)|Spanish|French|German)' && fail 'English leaked into Portuguese dashboard help'

ok 'installer/operator language is isolated from dashboard content language'
ok 'main and dashboard help are monolingual in pt-BR/en'
''', encoding="utf-8")
t.chmod(0o755)

print('final installer language cleanup prepared')
