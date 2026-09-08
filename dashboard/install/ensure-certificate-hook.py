#!/usr/bin/env python3
from pathlib import Path
import re
import sys

if len(sys.argv) != 2:
    raise SystemExit('uso: ensure-certificate-hook.py DASHBOARD/index.php')

p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8')
marker = 'XLX_CERTIFICATES_OPTIONAL_HOOK_V1'
required = [
    marker,
    "$allowed[] = 'certificado';",
    "$items['certificado']",
    "require __DIR__.'/certificado-view.php';",
    'assets/certificado.css',
    'assets/certificado.js',
    'assets/cert-event-alert-v1.js',
]


def validate_contract(text: str) -> None:
    missing = [x for x in required if x not in text]
    if missing:
        raise SystemExit('hook de certificados incompleto: ' + ', '.join(missing))


# Idempotence: a second run validates instead of modifying again.
if marker in s:
    validate_contract(s)
    print('Certificate optional hook: already present')
    raise SystemExit(0)


def sub_once(pattern: str, repl, label: str, flags: int = 0) -> None:
    global s
    new, n = re.subn(pattern, repl, s, count=1, flags=flags)
    if n != 1:
        raise SystemExit(f'estrutura {label} esperada 1 vez; encontrada {n}')
    s = new


# Route: locate the actual $allowed array semantically. Do not assume which
# standard pages are enabled or their order.
sub_once(
    r"(?m)^(\s*\$allowed\s*=\s*\[[^\n;]*\];\s*)$",
    lambda m: m.group(1) + "\n/* XLX_CERTIFICATES_OPTIONAL_HOOK_V1 */\n"
    "if (is_file(__DIR__.'/certificado-view.php')) $allowed[] = 'certificado';",
    'route',
)

# Navigation: insert immediately before the renderer initializes $html. The
# item list itself may gain/reorder normal dashboard pages without breaking us.
sub_once(
    r"(?m)^(\s*)\$html\s*=\s*'';\s*\n(\s*)foreach\s*\(\s*\$items\s+as\s+\$slug\s*=>\s*\$label\s*\)\s*\{",
    lambda m: (
        f"{m.group(1)}if (is_file(__DIR__.'/certificado-view.php')) {{\n"
        f"{m.group(1)}  $certCfg = is_file(__DIR__.'/config/site.php') ? require __DIR__.'/config/site.php' : [];\n"
        f"{m.group(1)}  $certLocale = (string)($certCfg['locale']['default'] ?? 'pt-BR');\n"
        f"{m.group(1)}  $certLabels = ['pt-BR'=>'Certificados','en'=>'Certificates','es'=>'Certificados','fr'=>'Certificats','de'=>'Zertifikate','it'=>'Certificati'];\n"
        f"{m.group(1)}  $items['certificado'] = $certLabels[$certLocale] ?? 'Certificates';\n"
        f"{m.group(1)}}}\n"
        f"{m.group(1)}$html = '';\n"
        f"{m.group(2)}foreach ($items as $slug => $label) {{"
    ),
    'navigation',
)

# SEO metadata: the stable semantic point is where the selected page metadata
# is read, not the order/content of the SEO array above it.
sub_once(
    r"(?m)^(\s*)\$meta\s*=\s*\$seo\[\$page\];\s*$",
    lambda m: (
        f"{m.group(1)}if (is_file(__DIR__.'/certificado-view.php')) {{\n"
        f"{m.group(1)}  $seo['certificado'] = [\n"
        f"{m.group(1)}    'title'=>'Certificates — {{{{REFLECTOR_NAME}}}}',\n"
        f"{m.group(1)}    'description'=>'Participation certificates and validation for {{{{REFLECTOR_NAME}}}}.'\n"
        f"{m.group(1)}  ];\n"
        f"{m.group(1)}}}\n"
        f"{m.group(1)}$meta = $seo[$page];"
    ),
    'seo',
)

# Styles: closing </head> is unique and independent from stylesheet ordering.
sub_once(
    r"</head>",
    "<?php if (is_file(__DIR__.'/assets/certificado.css')): ?>\n"
    "<link rel=\"stylesheet\" href=\"assets/certificado.css?v=1\">\n"
    "<?php endif; ?>\n"
    "<?php if (is_file(__DIR__.'/assets/cert-event-alert-v1.css')): ?>\n"
    "<link rel=\"stylesheet\" href=\"assets/cert-event-alert-v1.css?v=1\">\n"
    "<?php endif; ?>\n"
    "</head>",
    'styles',
)

# View: the dashboard has one top-level page dispatch beginning with Ao Vivo.
# Anchor to the PHP condition itself, not surrounding HTML or a specific module
# set/order.
sub_once(
    r"</section>\s*\n<\?php\s+if\s*\(\s*\$page\s*===\s*['\"]ao-vivo['\"]\s*\)\s*:\s*\?>",
    "</section>\n"
    "<?php if ($page === 'certificado' && is_file(__DIR__.'/certificado-view.php')): ?>\n"
    " <?php require __DIR__.'/certificado-view.php'; ?>\n"
    "<?php elseif ($page === 'ao-vivo'): ?>",
    'view',
)

# Scripts: closing body/html is unique and insensitive to script order/cache
# busters.
sub_once(
    r"</body>\s*</html>",
    "<?php if (is_file(__DIR__.'/assets/certificado.js')): ?>\n"
    "<script src=\"assets/certificado.js?v=1\" defer></script>\n"
    "<?php endif; ?>\n"
    "<?php if (is_file(__DIR__.'/assets/cert-event-alert-v1.js')): ?>\n"
    "<script src=\"assets/cert-event-alert-v1.js?v=1\" defer></script>\n"
    "<?php endif; ?>\n"
    "</body></html>",
    'scripts',
    re.S,
)

validate_contract(s)
p.write_text(s, encoding='utf-8')
print('Certificate optional hook: installed')
