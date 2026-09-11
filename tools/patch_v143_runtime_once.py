#!/usr/bin/env python3
from pathlib import Path

path = Path('tui/simple_installer.py')
text = path.read_text(encoding='utf-8')

bad_markup = '[f][b]Domínio[/b][/f]'
if bad_markup not in text:
    raise SystemExit('expected temporary markup token not found')
text = text.replace(bad_markup, '[b]Domínio[/b]', 1)

anchor = '''def looks_like_error(line: str) -> bool:\n    upper = line.upper()\n    return any(token in upper for token in ("ERROR", "ERRO", "FAILED", "FAILURE", "FALH", "MISSING", "INACTIVE", "FATAL"))\n\n\nclass SimpleInstaller(App):'''
insert = '''def looks_like_error(line: str) -> bool:\n    upper = line.upper()\n    return any(token in upper for token in ("ERROR", "ERRO", "FAILED", "FAILURE", "FALH", "MISSING", "INACTIVE", "FATAL"))\n\n\ndef write_ui_state(state: str) -> None:\n    state_file = os.environ.get("XLX_UI_STATE_FILE", "").strip()\n    if not state_file:\n        return\n    try:\n        target = Path(state_file)\n        target.parent.mkdir(parents=True, exist_ok=True)\n        target.write_text(state + "\\n", encoding="utf-8")\n        os.chmod(target, 0o600)\n    except Exception:\n        pass\n\n\nclass SimpleInstaller(App):'''
if anchor not in text:
    raise SystemExit('looks_like_error anchor not found')
text = text.replace(anchor, insert, 1)

mount_old = '''    def on_mount(self) -> None:\n        self.show_language()\n        self.query_one("#lang-pt", Button).focus()'''
mount_new = '''    def on_mount(self) -> None:\n        write_ui_state("MOUNTED")\n        self.show_language()\n        self.query_one("#lang-pt", Button).focus()'''
if mount_old not in text:
    raise SystemExit('on_mount anchor not found')
text = text.replace(mount_old, mount_new, 1)

close_old = '''        if self.installing:\n            self.fail("A instalação está em andamento. Aguarde a conclusão para evitar interrupção." if self.lang == "pt-BR" else "Installation is running. Wait for completion to avoid interruption.")\n            return\n        self.exit()'''
close_new = '''        if self.installing:\n            self.fail("A instalação está em andamento. Aguarde a conclusão para evitar interrupção." if self.lang == "pt-BR" else "Installation is running. Wait for completion to avoid interruption.")\n            return\n        write_ui_state("USER_CLOSED")\n        self.exit()'''
if close_old not in text:
    raise SystemExit('close anchor not found')
text = text.replace(close_old, close_new, 1)

path.write_text(text, encoding='utf-8')

version = Path('VERSION')
if version.read_text(encoding='utf-8').strip() != '1.4.2':
    raise SystemExit('unexpected VERSION before v1.4.3 patch')
version.write_text('1.4.3\n', encoding='utf-8')

for name in ('README.md', 'README.en.md'):
    p = Path(name)
    s = p.read_text(encoding='utf-8')
    s2 = s.replace('**Current release: v1.4.2**', '**Current release: v1.4.3**', 1)
    if s2 == s:
        raise SystemExit(f'English version marker not found in {name}')
    p.write_text(s2, encoding='utf-8')

p = Path('README.pt-BR.md')
s = p.read_text(encoding='utf-8')
s2 = s.replace('**Versão atual: v1.4.2**', '**Versão atual: v1.4.3**', 1)
if s2 == s:
    raise SystemExit('Portuguese version marker not found')
p.write_text(s2, encoding='utf-8')

changelog = Path('CHANGELOG.md')
current = changelog.read_text(encoding='utf-8')
section = '''## v1.4.3 — Usability and runtime hardening\n\n- Replaces the long scrolling form with one large question at a time so a required answer cannot be skipped silently.\n- Keeps a visible Back action on every question and makes the private Admin URL slug explicitly editable.\n- Uses black text on the bright blue/red/yellow action buttons, a white focused input with black text, wider fields and thicker progress bars for low-vision readability.\n- Adds a Show/Hide password control and keeps the password requirements visible before submission.\n- Validates the generated XLX comment length before installation so the answer stream cannot shift at the upstream 100-character limit.\n- Validates automatic YSF UDP port 42000 before installation so the upstream conditional port prompt cannot shift unattended answers.\n- Checks for an existing tmux installer session before fresh-install markers, preserving SSH-disconnect recovery after `/xlxd` has been created.\n- Starts tmux attached in isolated 256-color mode and records unexpected UI exits instead of silently dropping to `[exited]`.\n- Makes the 91% state explicit: if final validation fails, the UI shows the real captured error and a secure log path instead of looking frozen.\n\n'''
if current.startswith('## v1.4.3'):
    raise SystemExit('CHANGELOG already contains v1.4.3')
changelog.write_text(section + current, encoding='utf-8')
