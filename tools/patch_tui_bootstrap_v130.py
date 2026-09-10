#!/usr/bin/env python3
from pathlib import Path

p = Path("install.sh")
s = p.read_text(encoding="utf-8")

old = '''    if ! python3 -m venv --help >/dev/null 2>&1; then
        apt-get update || return 1
        DEBIAN_FRONTEND=noninteractive apt-get install -y python3-venv || return 1
    fi

    mkdir -p "$WORK_ROOT" || return 1
    chmod 700 "$WORK_ROOT" || return 1

    if [ ! -x "$venv/bin/python" ]; then
        rm -rf "$venv"
        python3 -m venv "$venv" || return 1
    fi
'''
new = '''    mkdir -p "$WORK_ROOT" || return 1
    chmod 700 "$WORK_ROOT" || return 1

    if [ ! -x "$venv/bin/python" ]; then
        rm -rf "$venv"
        if ! python3 -m venv "$venv" >/dev/null 2>&1; then
            rm -rf "$venv"
            apt-get update || return 1
            DEBIAN_FRONTEND=noninteractive apt-get install -y python3-venv || return 1
            python3 -m venv "$venv" || return 1
        fi
    fi
'''
if s.count(old) != 1:
    raise SystemExit(f"venv bootstrap block: expected 1 match, got {s.count(old)}")
s = s.replace(old, new, 1)

old_main = '''    validate_options
    require_root
    maybe_launch_tui
    select_ui_language
    select_dashboard_language
    section "XLX MODERN INSTALLER — PU2PNY"
    validate_os
    bootstrap_install_prerequisites
    validate_commands
    validate_resources
    validate_network
    detect_existing_installation
'''
new_main = '''    validate_options
    require_root
    validate_os
    validate_resources
    detect_existing_installation
    bootstrap_install_prerequisites
    validate_commands
    validate_network
    maybe_launch_tui
    select_ui_language
    select_dashboard_language
    section "XLX MODERN INSTALLER — PU2PNY"
'''
if s.count(old_main) != 1:
    raise SystemExit(f"main order block: expected 1 match, got {s.count(old_main)}")
s = s.replace(old_main, new_main, 1)
p.write_text(s, encoding="utf-8")

main = s[s.index("main() {"):]
required = [
    "validate_os",
    "validate_resources",
    "detect_existing_installation",
    "bootstrap_install_prerequisites",
    "validate_network",
    "maybe_launch_tui",
]
positions = [main.index(x) for x in required]
assert positions == sorted(positions), (required, positions)
