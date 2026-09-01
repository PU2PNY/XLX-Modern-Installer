#!/usr/bin/env python3
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit('uso: ensure-certificate-hook.py DASHBOARD/index.php')

p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8')
marker = 'XLX_CERTIFICATES_OPTIONAL_HOOK_V1'

# Already patched: validate the whole contract instead of patching twice.
if marker in s:
    required = [
        "$allowed[] = 'certificado';",
        "$items['certificado']",
        "require __DIR__.'/certificado-view.php';",
        'assets/certificado.css',
        'assets/certificado.js',
        'assets/cert-event-alert-v1.js',
    ]
    missing = [x for x in required if x not in s]
    if missing:
        raise SystemExit('hook de certificados incompleto: ' + ', '.join(missing))
    print('Certificate optional hook: already present')
    raise SystemExit(0)


def replace_once(old: str, new: str, label: str) -> None:
    global s
    n = s.count(old)
    if n != 1:
        raise SystemExit(f'âncora {label} esperada 1 vez; encontrada {n}')
    s = s.replace(old, new, 1)

# Route: the certificate page only becomes routable after the optional module
# has actually installed certificado-view.php.
replace_once(
    "$allowed = ['ao-vivo','conectados','ranking','refletores'];\nif (!in_array($page, $allowed, true))",
    "$allowed = ['ao-vivo','conectados','ranking','refletores'];\n"
    "/* XLX_CERTIFICATES_OPTIONAL_HOOK_V1 */\n"
    "if (is_file(__DIR__.'/certificado-view.php')) $allowed[] = 'certificado';\n"
    "if (!in_array($page, $allowed, true))",
    'route',
)

# Public navigation. Keep labels locale-aware because this hook is installed
# after the main i18n build has already rendered the dashboard.
replace_once(
    "  ];\n  $html = '';\n  foreach ($items as $slug => $label) {",
    "  ];\n"
    "  if (is_file(__DIR__.'/certificado-view.php')) {\n"
    "    $certCfg = is_file(__DIR__.'/config/site.php') ? require __DIR__.'/config/site.php' : [];\n"
    "    $certLocale = (string)($certCfg['locale']['default'] ?? 'pt-BR');\n"
    "    $certLabels = ['pt-BR'=>'Certificados','en'=>'Certificates','es'=>'Certificados','fr'=>'Certificats','de'=>'Zertifikate','it'=>'Certificati'];\n"
    "    $items['certificado'] = $certLabels[$certLocale] ?? 'Certificates';\n"
    "  }\n"
    "  $html = '';\n"
    "  foreach ($items as $slug => $label) {",
    'navigation',
)

# SEO metadata only exists when the module is installed and the route can be
# selected. No Brazil/XLX026 identity is introduced.
replace_once(
    "$meta = $seo[$page];",
    "if (is_file(__DIR__.'/certificado-view.php')) {\n"
    "  $seo['certificado'] = [\n"
    "    'title'=>'Certificates — {{REFLECTOR_NAME}}',\n"
    "    'description'=>'Participation certificates and validation for {{REFLECTOR_NAME}}.'\n"
    "  ];\n"
    "}\n"
    "$meta = $seo[$page];",
    'seo',
)

# Styles are loaded only after the optional module has installed them.
replace_once(
    "</head>\n<body data-page=",
    "<?php if (is_file(__DIR__.'/assets/certificado.css')): ?>\n"
    "<link rel=\"stylesheet\" href=\"assets/certificado.css?v=1\">\n"
    "<?php endif; ?>\n"
    "<?php if (is_file(__DIR__.'/assets/cert-event-alert-v1.css')): ?>\n"
    "<link rel=\"stylesheet\" href=\"assets/cert-event-alert-v1.css?v=1\">\n"
    "<?php endif; ?>\n"
    "</head>\n<body data-page=",
    'styles',
)

# View: place the optional page at the beginning of the main page chain so it
# does not interfere with Ao Vivo/Conectados/Ranking/Refletores.
replace_once(
    "</section>\n<?php if ($page === 'ao-vivo'): ?>\n <section class=\"dashboard-layout\">",
    "</section>\n"
    "<?php if ($page === 'certificado' && is_file(__DIR__.'/certificado-view.php')): ?>\n"
    " <?php require __DIR__.'/certificado-view.php'; ?>\n"
    "<?php elseif ($page === 'ao-vivo'): ?>\n"
    " <section class=\"dashboard-layout\">",
    'view',
)

# Scripts are likewise conditional. Anchor only on the single closing body
# tag so this stays stable after language/template rendering changes earlier
# script tags or their cache-busting query strings.
replace_once(
    "</body></html>",
    "<?php if (is_file(__DIR__.'/assets/certificado.js')): ?>\n"
    "<script src=\"assets/certificado.js?v=1\" defer></script>\n"
    "<?php endif; ?>\n"
    "<?php if (is_file(__DIR__.'/assets/cert-event-alert-v1.js')): ?>\n"
    "<script src=\"assets/cert-event-alert-v1.js?v=1\" defer></script>\n"
    "<?php endif; ?>\n"
    "</body></html>",
    'scripts',
)

required = [
    marker,
    "$allowed[] = 'certificado';",
    "$items['certificado']",
    "require __DIR__.'/certificado-view.php';",
    'assets/certificado.css',
    'assets/certificado.js',
    'assets/cert-event-alert-v1.js',
]
missing = [x for x in required if x not in s]
if missing:
    raise SystemExit('hook final incompleto: ' + ', '.join(missing))

p.write_text(s, encoding='utf-8')
print('Certificate optional hook: installed')
