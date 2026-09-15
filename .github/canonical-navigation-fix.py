from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    n = text.count(old)
    if n != 1:
        raise SystemExit(f"{path}: expected one target, found {n}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")

replace_once(
    "dashboard/index.php",
    "function page_url(string $p): string { return '?page=' . rawurlencode($p); }",
    "function page_url(string $p): string {\n  if ($p === 'digital-lab') return '/aprs-dprs';\n  return '/' . rawurlencode($p);\n}",
)
replace_once(
    "dashboard/index.php",
    "$canonical = 'https://{{REFLECTOR_DOMAIN}}/' . ($page === 'ao-vivo' ? '' : '?page=' . rawurlencode($page));",
    "$canonical = 'https://{{REFLECTOR_DOMAIN}}' . page_url($page);",
)

replace_once(
    "modules/70-nginx.sh",
    "    location = / { return 301 /ao-vivo; }",
    "    # Preserve old /?page=... links while making clean routes canonical.\n    location = / {\n        if (\\$xlxmodern_old_page_redirect != \"\") { return 301 \\$xlxmodern_old_page_redirect; }\n        return 301 /ao-vivo;\n    }",
)
replace_once(
    "modules/70-nginx.sh",
    "    location = / { return 301 https://$DOMAIN/ao-vivo; }",
    "    # Preserve old /?page=... links while making clean routes canonical.\n    location = / {\n        if (\\$xlxmodern_old_page_redirect != \"\") { return 301 https://$DOMAIN\\$xlxmodern_old_page_redirect; }\n        return 301 https://$DOMAIN/ao-vivo;\n    }",
)

Path("tests/test-canonical-navigation.sh").write_text(r'''#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ printf 'FAIL | %s\n' "$*" >&2; exit 1; }
INDEX="$ROOT/dashboard/index.php"
NGINX="$ROOT/modules/70-nginx.sh"
grep -Fq "if (\$p === 'digital-lab') return '/aprs-dprs';" "$INDEX" || fail 'APRS clean-route mapping missing from navigation'
grep -Fq "return '/' . rawurlencode(\$p);" "$INDEX" || fail 'clean-route navigation helper missing'
grep -Fq "\$canonical = 'https://{{REFLECTOR_DOMAIN}}' . page_url(\$page);" "$INDEX" || fail 'canonical metadata does not use the clean route'
if grep -Fq "return '?page=' . rawurlencode(\$p)" "$INDEX"; then fail 'query-string navigation remains'; fi
[ "$(grep -Fc 'Preserve old /?page=... links while making clean routes canonical.' "$NGINX")" -eq 2 ] || fail 'legacy root query redirects are not covered in HTTP and HTTPS sites'
grep -Fq 'digital-lab /aprs-dprs;' "$NGINX" || fail 'legacy APRS route mapping missing'
printf 'OK | clean navigation, canonical metadata and legacy query compatibility are aligned\n'
''', encoding="utf-8")
