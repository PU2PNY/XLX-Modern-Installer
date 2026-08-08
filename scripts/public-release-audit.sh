#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

failures=0
warnings=0

ok(){ printf '[OK] %s\n' "$*"; }
warn(){ printf '[WARN] %s\n' "$*"; warnings=$((warnings+1)); }
fail(){ printf '[FAIL] %s\n' "$*" >&2; failures=$((failures+1)); }

printf '\n=== XLX Modern Installer — Public Release Audit ===\n\n'

mapfile -t tracked < <(git ls-files)
[ "${#tracked[@]}" -gt 0 ] || { echo 'No tracked files found.' >&2; exit 2; }
printf 'Tracked files: %d\n\n' "${#tracked[@]}"

printf '%s\n' '--- Forbidden or high-risk tracked file types ---'
for file in "${tracked[@]}"; do
    lower="${file,,}"

    # git ls-files também lista arquivos rastreados que foram
    # removidos no working tree e aguardam commit da exclusão.
    if [ ! -e "$file" ]; then
        case "$lower" in
            *.key|*.pem|*.p12|*.pfx|*.jks|*.keystore|*.sqlite|*.sqlite3|*.db|*.bak|*.dump|*.sql|*.tar|*.tgz|*.tar.gz|*.zip|*.7z|*.rar|*.env)
                warn "High-risk tracked file is pending deletion: $file"
                ;;
        esac
        continue
    fi

    case "$lower" in
        *.key|*.pem|*.p12|*.pfx|*.jks|*.keystore|*.sqlite|*.sqlite3|*.db|*.bak|*.dump|*.sql|*.tar|*.tgz|*.tar.gz|*.zip|*.7z|*.rar|*.env)
            fail "High-risk tracked file: $file"
            ;;
    esac
done
[ "$failures" -eq 0 ] && ok 'No prohibited archive, database, key or environment files are tracked.'

printf '\n%s\n' '--- Private-key and token signatures in current tree ---'
secret_regex='BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{20,}'
if git grep -nEI "$secret_regex" -- ':!*.md' ':!LICENSE' >/tmp/xlx-public-audit-secrets.$$ 2>/dev/null; then
    cat /tmp/xlx-public-audit-secrets.$$
    fail 'Potential secret/token signature found.'
else
    ok 'No common private-key or token signatures found in current tree.'
fi
rm -f /tmp/xlx-public-audit-secrets.$$ || true

printf '\n%s\n' '--- Suspicious credential assignments in current tree ---'
credential_regex="(password|passwd|secret|api[_-]?key|access[_-]?token|auth[_-]?token)[[:space:]]*[:=][[:space:]]*['\"][^'\"]{6,}['\"]"
if git grep -nEI "$credential_regex" -- ':!*.md' ':!LICENSE' >/tmp/xlx-public-audit-creds.$$ 2>/dev/null; then
    cat /tmp/xlx-public-audit-creds.$$
    fail 'Possible hard-coded credential assignment found.'
else
    ok 'No obvious hard-coded credential assignments found in current tree.'
fi
rm -f /tmp/xlx-public-audit-creds.$$ || true

printf '\n%s\n' '--- High-risk filenames anywhere in Git history ---'
if git rev-list --objects --all | grep -Ei '\.(key|pem|p12|pfx|jks|keystore|sqlite|sqlite3|db|bak|dump|sql|tar|tgz|tar\.gz|zip|7z|rar|env)([[:space:]]|$)' >/tmp/xlx-public-audit-history-files.$$; then
    cat /tmp/xlx-public-audit-history-files.$$
    warn 'High-risk filename exists in Git history. Content must be reviewed before publication.'
else
    ok 'No obvious high-risk filenames found in Git history.'
fi
rm -f /tmp/xlx-public-audit-history-files.$$ || true

printf '\n%s\n' '--- Secret signatures anywhere in Git history ---'
# git log -G examines historical patches as well as the current tree. Keep the
# output limited to commit/path metadata so secrets are never echoed by CI.
if git log --all --format='%H %ad %s' --date=short -G "$secret_regex" -- . >/tmp/xlx-public-audit-history-secrets.$$ 2>/dev/null && [ -s /tmp/xlx-public-audit-history-secrets.$$ ]; then
    head -n 50 /tmp/xlx-public-audit-history-secrets.$$
    fail 'Potential secret signature appears in Git history. Review before publication.'
else
    ok 'No common token/private-key signature detected in historical patches.'
fi
rm -f /tmp/xlx-public-audit-history-secrets.$$ || true

printf '\n%s\n' '--- Production-only identifiers ---'
for pattern in '141\.11\.128\.63' 'xlx026\.net' '/root/backups-xlx026' 'Telegram Bot Token' 'BOT_TOKEN'; do
    if git grep -nEI "$pattern" -- ':!docs/PUBLIC-RELEASE-CHECKLIST.md' ':!docs/GITHUB-ABOUT.md' ':!scripts/public-release-audit.sh' >/tmp/xlx-public-audit-prod.$$ 2>/dev/null; then
        warn "Review production-specific reference matching: $pattern"
        cat /tmp/xlx-public-audit-prod.$$
    fi
    rm -f /tmp/xlx-public-audit-prod.$$ || true

    if git log --all --format='%H %ad %s' --date=short -G "$pattern" -- . ':(exclude)scripts/public-release-audit.sh' >/tmp/xlx-public-audit-prod-history.$$ 2>/dev/null && [ -s /tmp/xlx-public-audit-prod-history.$$ ]; then
        warn "Production-specific reference appears in Git history: $pattern"
        head -n 20 /tmp/xlx-public-audit-prod-history.$$
    fi
    rm -f /tmp/xlx-public-audit-prod-history.$$ || true
done

printf '\n%s\n' '--- Required public-project files ---'
for file in README.md README.en.md LICENSE SECURITY.md CONTRIBUTING.md THIRD_PARTY_NOTICES.md SUPPORT.md CHANGELOG.md .gitignore; do
    if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
        ok "$file"
    else
        fail "Missing required project file: $file"
    fi
done

printf '\n%s\n' '--- Internationalization files ---'
for locale in pt-BR en es fr de it; do
    file="dashboard/i18n/locales/${locale}.php"
    if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
        ok "$file"
    else
        fail "Missing locale catalog: $file"
    fi
done

printf '\n%s\n' '--- Syntax checks ---'
while IFS= read -r file; do
    bash -n "$file" || fail "Bash syntax: $file"
done < <(git ls-files '*.sh')
ok 'Bash syntax scan completed.'

if command -v php >/dev/null 2>&1; then
    while IFS= read -r file; do
        php -l "$file" >/dev/null || fail "PHP syntax: $file"
    done < <(git ls-files 'dashboard/*.php' 'dashboard/**/*.php')
    ok 'PHP syntax scan completed.'
else
    warn 'PHP is not installed in this audit environment; PHP syntax was skipped.'
fi

printf '\n=== Audit summary ===\n'
printf 'Failures: %d\nWarnings: %d\n' "$failures" "$warnings"

if [ "$failures" -ne 0 ]; then
    echo 'NOT READY FOR PUBLICATION' >&2
    exit 1
fi

echo 'PASS — no blocking publication issue detected by automated audit.'
if [ "$warnings" -ne 0 ]; then
    echo 'Manual review is still required for warnings before changing repository visibility.'
fi
