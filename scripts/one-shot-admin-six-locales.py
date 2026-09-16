#!/usr/bin/env python3
import json
from pathlib import Path
import argostranslate.package
import argostranslate.translate

ROOT = Path(__file__).resolve().parents[1]
BASE_PATH = ROOT / 'control/admin-en.json'
BASE = json.loads(BASE_PATH.read_text(encoding='utf-8'))

PROTECTED = [
    'XLXD','XLX','D-STAR','DMR','RadioID.net','RadioID','users.db','SQL','CSV',
    'YSF','C4FM','Wires-X','CallingHome','Interlink','APRS','DV','GPS','TA','TX','RX',
    'N0CALL','PU2*','PU5*','xlxd.service','SHA','Data FR','Voice FR','Mode 2',
    '<strong>','</strong>','203.0.113.15','203.0.113.5','example.org'
]

OVERRIDES = {
    'es': {
        'Restricted access':'Acceso restringido','Username':'Usuario','Password':'Contraseña',
        'Sign in':'Iniciar sesión','Sign out':'Cerrar sesión','Private technical area':'Área técnica privada',
        'Reflector control':'Control del reflector','Operational Health':'Salud operativa',
        'Whitelist':'Lista blanca','Blacklist':'Lista negra','Restart XLXD':'Reiniciar XLXD',
        'Search records':'Buscar registros','Save and synchronize':'Guardar y sincronizar',
        'Update callsign database':'Actualizar la base de indicativos','Integrity and tests':'Integridad y pruebas',
        'Recent backups':'Copias de seguridad recientes','Recent logs':'Registros recientes',
        'Action':'Acción','State':'Estado','Detail':'Detalle','Search':'Buscar','Edit':'Editar',
        'Remove':'Eliminar','Check':'Comprobar','Check now':'Comprobar ahora','Validation':'Validación',
        'Expected':'Esperado','Result':'Resultado','Country':'País','City':'Ciudad','Name':'Nombre',
        'Last name':'Apellido','Callsign':'Indicativo','Modules':'Módulos','Processes':'Procesos',
        'Protocol':'Protocolo','Active TX':'TX activa','History':'Historial','Generated':'Generado'
    },
    'fr': {
        'Restricted access':'Accès restreint','Username':'Utilisateur','Password':'Mot de passe',
        'Sign in':'Se connecter','Sign out':'Se déconnecter','Private technical area':'Zone technique privée',
        'Reflector control':'Contrôle du réflecteur','Operational Health':'Santé opérationnelle',
        'Whitelist':'Liste blanche','Blacklist':'Liste noire','Restart XLXD':'Redémarrer XLXD',
        'Search records':'Rechercher des enregistrements','Save and synchronize':'Enregistrer et synchroniser',
        'Update callsign database':'Mettre à jour la base des indicatifs','Integrity and tests':'Intégrité et tests',
        'Recent backups':'Sauvegardes récentes','Recent logs':'Journaux récents','Action':'Action','State':'État',
        'Detail':'Détail','Search':'Rechercher','Edit':'Modifier','Remove':'Supprimer','Check':'Vérifier',
        'Check now':'Vérifier maintenant','Validation':'Validation','Expected':'Attendu','Result':'Résultat',
        'Country':'Pays','City':'Ville','Name':'Nom','Last name':'Nom de famille','Callsign':'Indicatif',
        'Modules':'Modules','Processes':'Processus','Protocol':'Protocole','Active TX':'TX active',
        'History':'Historique','Generated':'Généré'
    },
    'de': {
        'Restricted access':'Eingeschränkter Zugriff','Username':'Benutzername','Password':'Passwort',
        'Sign in':'Anmelden','Sign out':'Abmelden','Private technical area':'Privater Technikbereich',
        'Reflector control':'Reflektorsteuerung','Operational Health':'Betriebszustand',
        'Whitelist':'Positivliste','Blacklist':'Sperrliste','Restart XLXD':'XLXD neu starten',
        'Search records':'Einträge durchsuchen','Save and synchronize':'Speichern und synchronisieren',
        'Update callsign database':'Rufzeichendatenbank aktualisieren','Integrity and tests':'Integrität und Tests',
        'Recent backups':'Aktuelle Sicherungen','Recent logs':'Aktuelle Protokolle','Action':'Aktion','State':'Status',
        'Detail':'Detail','Search':'Suchen','Edit':'Bearbeiten','Remove':'Entfernen','Check':'Prüfen',
        'Check now':'Jetzt prüfen','Validation':'Validierung','Expected':'Erwartet','Result':'Ergebnis',
        'Country':'Land','City':'Stadt','Name':'Name','Last name':'Nachname','Callsign':'Rufzeichen',
        'Modules':'Module','Processes':'Prozesse','Protocol':'Protokoll','Active TX':'Aktive TX',
        'History':'Verlauf','Generated':'Erzeugt'
    },
    'it': {
        'Restricted access':'Accesso riservato','Username':'Nome utente','Password':'Password',
        'Sign in':'Accedi','Sign out':'Esci','Private technical area':'Area tecnica privata',
        'Reflector control':'Controllo del riflettore','Operational Health':'Stato operativo',
        'Whitelist':'Lista consentiti','Blacklist':'Lista bloccati','Restart XLXD':'Riavvia XLXD',
        'Search records':'Cerca registri','Save and synchronize':'Salva e sincronizza',
        'Update callsign database':'Aggiorna database nominativi','Integrity and tests':'Integrità e test',
        'Recent backups':'Backup recenti','Recent logs':'Log recenti','Action':'Azione','State':'Stato',
        'Detail':'Dettaglio','Search':'Cerca','Edit':'Modifica','Remove':'Rimuovi','Check':'Verifica',
        'Check now':'Verifica ora','Validation':'Validazione','Expected':'Previsto','Result':'Risultato',
        'Country':'Paese','City':'Città','Name':'Nome','Last name':'Cognome','Callsign':'Nominativo',
        'Modules':'Moduli','Processes':'Processi','Protocol':'Protocollo','Active TX':'TX attiva',
        'History':'Cronologia','Generated':'Generato'
    }
}


def safe_text(value: str) -> str:
    return value.replace("'", '’').replace('"', '”').replace('\\', '')


def generate_catalogs():
    argostranslate.package.update_package_index()
    packages = argostranslate.package.get_available_packages()
    for locale in ('es','fr','de','it'):
        package = next((p for p in packages if p.from_code == 'en' and p.to_code == locale), None)
        if package is None:
            raise SystemExit(f'missing Argos package en->{locale}')
        argostranslate.package.install_from_path(package.download())
        output = {}
        for pt, en in BASE.items():
            if en in OVERRIDES[locale]:
                value = OVERRIDES[locale][en]
            else:
                text = en
                reverse = {}
                for i, token in enumerate(sorted(PROTECTED, key=len, reverse=True)):
                    if token in text:
                        marker = f'ZXQ{i}QXZ'
                        text = text.replace(token, marker)
                        reverse[marker] = token
                value = argostranslate.translate.translate(text, 'en', locale)
                for marker, token in reverse.items():
                    value = value.replace(marker, token)
                value = ' '.join(value.split())
            output[pt] = safe_text(value)
        if set(output) != set(BASE):
            raise SystemExit(f'catalog key mismatch: {locale}')
        (ROOT / f'control/admin-{locale}.json').write_text(
            json.dumps(output, ensure_ascii=False, indent=2, sort_keys=True) + '\n', encoding='utf-8'
        )


def patch_builder():
    path = ROOT / 'control/build-admin.py'
    text = path.read_text(encoding='utf-8')
    text = text.replace(
        'usage: build-admin.py INDEX.php [pt-BR|en]',
        'usage: build-admin.py INDEX.php [pt-BR|en|es|fr|de|it]'
    )
    old = '''if locale in {"en","en-us","en_us"}:\n    mapping=json.loads((Path(__file__).with_name("admin-en.json")).read_text(encoding="utf-8"))\n    for old in sorted(mapping,key=len,reverse=True): s=s.replace(old,mapping[old])\n    s=s.replace('lang="pt-BR"','lang="en"')\nelif locale not in {"pt","pt-br","pt_br"}:\n    raise SystemExit("Admin supports installer languages pt-BR or en")\n'''
    new = '''aliases={"pt":"pt-BR","pt-br":"pt-BR","pt_br":"pt-BR","en-us":"en","en_us":"en"}\nlocale=aliases.get(locale,locale)\nsupported={"pt-BR","en","es","fr","de","it"}\nif locale not in supported:\n    raise SystemExit("Admin supports dashboard languages pt-BR, en, es, fr, de or it")\nif locale != "pt-BR":\n    mapping=json.loads((Path(__file__).with_name(f"admin-{locale}.json")).read_text(encoding="utf-8"))\n    baseline=json.loads((Path(__file__).with_name("admin-en.json")).read_text(encoding="utf-8"))\n    if set(mapping) != set(baseline):\n        raise SystemExit(f"Admin locale catalog key mismatch: {locale}")\n    for old in sorted(mapping,key=len,reverse=True): s=s.replace(old,mapping[old])\n    s=s.replace('lang="pt-BR"',f'lang="{locale}"')\n'''
    if old not in text:
        raise SystemExit('build-admin language block not found')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


def patch_admin_module():
    path = ROOT / 'modules/69-admin-page.sh'
    text = path.read_text(encoding='utf-8')
    old = '''# Admin intentionally supports two complete interfaces only.  The dashboard\n# can use six languages, while the private operational screen stays PT-BR or\n# English so its safety prompts and maintenance actions remain unambiguous.\nADMIN_UI_LANG='en'\n[[ "$UI_LANG" == pt || "$UI_LANG" == pt-BR || "$UI_LANG" == pt_BR ]] && ADMIN_UI_LANG='pt-BR'\npython3 "$ROOT/control/build-admin.py" "$WORK/index.php" "$ADMIN_UI_LANG"\n'''
    new = '''# Admin follows exactly the dashboard locale. Installer prompts remain PT-BR/English.\ncase "$UI_LANG" in\n  pt|pt-BR|pt_BR) ADMIN_UI_LANG='pt-BR' ;;\n  en|es|fr|de|it) ADMIN_UI_LANG="$UI_LANG" ;;\n  *) fail "$(say "Idioma do Admin não suportado: $UI_LANG" "Unsupported Admin language: $UI_LANG")" ;;\nesac\npython3 "$ROOT/control/build-admin.py" "$WORK/index.php" "$ADMIN_UI_LANG"\n'''
    if old not in text:
        raise SystemExit('Admin language fallback block not found')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


def patch_tests():
    admin_test = r'''#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }
ok(){ printf '[OK] %s\n' "$*"; }
command -v python3 >/dev/null 2>&1 || fail 'python3 is required'
command -v php >/dev/null 2>&1 || fail 'php is required'
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
locales=(pt-BR en es fr de it)
for locale in "${locales[@]}"; do
  f="$tmp/$locale.php"
  cp "$ROOT/control/current-production-admin.php" "$f"
  python3 "$ROOT/control/build-admin.py" "$f" "$locale"
  php -l "$f" >/dev/null || fail "PHP syntax broken in $locale"
  grep -Fq "lang=\"$locale\"" "$f" || fail "HTML lang mismatch in $locale"
  for marker in "const CTRL_VER='1.5.1'" health-status access-interlink-add access-interlink-delete radioid_api_search radioid_save; do
    grep -Fq "$marker" "$f" || fail "$marker missing in $locale"
  done
  ! grep -Eq 'Terminal XLXD|Terminal SSH|shell_exec\(\$_POST|passthru\(\$_POST' "$f" || fail "terminal marker leaked in $locale"
done
grep -Fq 'Acesso restrito' "$tmp/pt-BR.php" || fail 'pt-BR login marker missing'
grep -Fq 'Restricted access' "$tmp/en.php" || fail 'English login marker missing'
grep -Fq 'Acceso restringido' "$tmp/es.php" || fail 'Spanish login marker missing'
grep -Fq 'Accès restreint' "$tmp/fr.php" || fail 'French login marker missing'
grep -Fq 'Eingeschränkter Zugriff' "$tmp/de.php" || fail 'German login marker missing'
grep -Fq 'Accesso riservato' "$tmp/it.php" || fail 'Italian login marker missing'
python3 - "$ROOT" "$tmp" <<'PY'
import json,re,sys
from pathlib import Path
root=Path(sys.argv[1]); tmp=Path(sys.argv[2])
en_catalog=json.loads((root/'control/admin-en.json').read_text(encoding='utf-8'))
for loc in ('es','fr','de','it'):
    cat=json.loads((root/f'control/admin-{loc}.json').read_text(encoding='utf-8'))
    if set(cat)!=set(en_catalog): raise SystemExit(f'{loc}: catalog key mismatch')
def fingerprint(path):
    s=path.read_text(encoding='utf-8')
    return {
      'id':sorted(set(re.findall(r'\bid=["\']([^"\']+)["\']',s))),
      'name':sorted(set(re.findall(r'\bname=["\']([^"\']+)["\']',s))),
      'actions':sorted(set(re.findall(r"(?:action|op|cmd)\s*===?\s*['\"]([^'\"]+)['\"]",s))),
      'helpers':sorted(set(re.findall(r'(?:health-status|access-[a-z-]+|radioid[-_][a-z-]+|restart|listeners|logs|backups)',s)))
    }
ref=fingerprint(tmp/'pt-BR.php')
for loc in ('en','es','fr','de','it'):
    if fingerprint(tmp/f'{loc}.php') != ref:
        raise SystemExit(f'{loc}: functional structure changed by translation')
for loc in ('en','es','fr','de','it'):
    built=(tmp/f'{loc}.php').read_text(encoding='utf-8')
    cat=en_catalog if loc=='en' else json.loads((root/f'control/admin-{loc}.json').read_text(encoding='utf-8'))
    leaks=[]
    for source,target in cat.items():
        if source != target and len(source) >= 8 and source in built:
            leaks.append(source)
    if leaks:
        raise SystemExit(f'{loc}: untranslated Admin strings remain: {leaks[:8]}')
PY
for bad in '/etc/legacy-control' '/var/lib/legacy-control' '/usr/local/sbin/legacy-control-'; do
  ! grep -Fq "$bad" "$tmp"/*.php || fail "production marker leaked: $bad"
done
ok 'Admin has six locale-faithful builds with identical functional structure'
'''
    path = ROOT / 'tests/test-admin-i18n.sh'
    path.write_text(admin_test, encoding='utf-8')
    path.chmod(0o755)

    flow = ROOT / 'tests/test-install-flow.sh'
    text = flow.read_text(encoding='utf-8')
    old = "expect 'Admin source is localized for English installations' 'usage: build-admin.py INDEX.php [pt-BR|en]' \"$ROOT/control/build-admin.py\""
    new = "expect 'Admin builder supports every dashboard language' 'usage: build-admin.py INDEX.php [pt-BR|en|es|fr|de|it]' \"$ROOT/control/build-admin.py\""
    if old not in text:
        raise SystemExit('obsolete Admin English-only test not found')
    text = text.replace(old, new, 1)
    if 'ADMIN_LANGUAGE_PARITY_CONTRACT=OK' not in text:
        text += '''\necho "[admin/dashboard locale parity]"\ngrep -Fq 'en|es|fr|de|it) ADMIN_UI_LANG="$UI_LANG"' "$ROOT/modules/69-admin-page.sh" || { echo 'Admin does not inherit dashboard locale' >&2; exit 1; }\nfor loc in es fr de it; do test -s "$ROOT/control/admin-$loc.json" || { echo "missing Admin locale catalog: $loc" >&2; exit 1; }; done\necho "ADMIN_LANGUAGE_PARITY_CONTRACT=OK"\n'''
    flow.write_text(text, encoding='utf-8')


generate_catalogs()
patch_builder()
patch_admin_module()
patch_tests()
print('SIX_LOCALE_ADMIN_MIGRATION=PREPARED')
