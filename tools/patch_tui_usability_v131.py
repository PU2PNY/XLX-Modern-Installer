#!/usr/bin/env python3
from pathlib import Path

# Patch only the guided TUI usability requested for v1.3.1.

p = Path("tui/installer.py")
s = p.read_text(encoding="utf-8")

s = s.replace(
'''    #content {\n        width: 1fr;\n        padding: 1 2;\n    }\n    #step-title {''',
'''    #content {\n        width: 1fr;\n        padding: 1 2;\n    }\n    #guide {\n        height: 3;\n        padding: 0 1;\n        color: #ffffff;\n        background: #102737;\n        border-left: thick #21c6ff;\n        content-align: left middle;\n    }\n    #step-title {'''
)

s = s.replace(
'''    #nav Button {\n        margin-left: 1;\n        min-width: 14;\n    }\n''',
'''    #nav Button {\n        margin-left: 1;\n        min-width: 14;\n        text-style: bold;\n    }\n    #back {\n        background: #263746;\n        color: #ffffff;\n    }\n    #next {\n        background: #26c6f3;\n        color: #00151f;\n    }\n    #cancel {\n        background: #ff6b73;\n        color: #240004;\n    }\n    #back:focus, #next:focus, #cancel:focus {\n        border: heavy #ffffff;\n    }\n'''
)

s = s.replace(
'''            with Vertical(id="content"):\n                yield Static("", id="step-title")\n                with VerticalScroll(id="form"):\n                    with Vertical(id="page-0", classes="page"):\n                        yield Label("ID do refletor *", classes="field-label")''',
'''            with Vertical(id="content"):\n                yield Static(\n                    "[b]Como usar:[/b] escolha o idioma, clique no primeiro campo, digite a resposta e pressione [b]Enter[/b] para ir ao próximo campo. Ao terminar a etapa, clique em [b]Continuar[/b].",\n                    id="guide",\n                    markup=True,\n                )\n                yield Static("", id="step-title")\n                with VerticalScroll(id="form"):\n                    with Vertical(id="page-0", classes="page"):\n                        yield Label("Idioma da instalação / Installer language *", classes="field-label")\n                        yield Select(\n                            [("Português (Brasil)", "pt-BR"), ("English", "en")],\n                            value="pt-BR",\n                            allow_blank=False,\n                            id="installer_lang",\n                        )\n                        yield Label("ID do refletor *", classes="field-label")'''
)

s = s.replace(
'''    def on_mount(self) -> None:\n        self.show_step(0)\n''',
'''    FIELD_ORDER = {\n        0: ["reflector_id", "domain", "email", "callsign", "country", "timezone"],\n        1: ["comment", "header_text", "footer_text", "modules"],\n        2: ["ysf_port", "ysf_freq", "autolink_module", "location", "ysf_id"],\n        3: ["admin_user", "admin_slug", "admin_password", "admin_password_confirm"],\n    }\n\n    def on_mount(self) -> None:\n        self.show_step(0)\n        self.query_one("#installer_lang", Select).focus()\n\n    @on(Input.Submitted)\n    def advance_on_enter(self, event: Input.Submitted) -> None:\n        \"\"\"Enter in a text response advances to the next response line.\"\"\"\n        order = self.FIELD_ORDER.get(self.current_step, [])\n        widget_id = event.input.id\n        if not widget_id or widget_id not in order:\n            return\n        index = order.index(widget_id)\n        if index + 1 < len(order):\n            self.query_one(f"#{order[index + 1]}", Input).focus()\n        else:\n            self.query_one("#next", Button).focus()\n'''
)

s = s.replace(
'''        if step == 0:\n            rid = self.input_value("reflector_id").upper()''',
'''        if step == 0:\n            installer_lang = self.query_one("#installer_lang", Select).value\n            rid = self.input_value("reflector_id").upper()'''
)

s = s.replace(
'''            self.data.update(\n                reflector_id=rid,''',
'''            if installer_lang not in {"pt-BR", "en"}:\n                return self.fail("Selecione Português (Brasil) ou English para o idioma da instalação.")\n            self.data.update(\n                installer_lang=str(installer_lang),\n                reflector_id=rid,''',
1
)

s = s.replace(
'''            f"[b]Refletor[/b]        XLX{self.data['reflector_id']}\\n"''',
'''            f"[b]Idioma instalação[/b] {self.data['installer_lang']}\\n"\n            f"[b]Refletor[/b]        XLX{self.data['reflector_id']}\\n"'''
)

s = s.replace(
'''            "--tui-child",\n            f"--lang={self.data['dashboard_lang']}",\n''',
'''            "--tui-child",\n            f"--ui-lang={self.data['installer_lang']}",\n            f"--lang={self.data['dashboard_lang']}",\n'''
)

required = [
    'id="installer_lang"',
    'id="guide"',
    'def advance_on_enter',
    '#next {',
    'f"--ui-lang={self.data[\'installer_lang\']}"',
]
for needle in required:
    if needle not in s:
        raise SystemExit(f"missing TUI marker after patch: {needle}")
p.write_text(s, encoding="utf-8")

p = Path("install.sh")
s = p.read_text(encoding="utf-8")
s = s.replace('UI_LANG="pt-BR"\nCHECK_READY=', 'UI_LANG="pt-BR"\nUI_LANG_EXPLICIT="no"\nCHECK_READY=', 1)
s = s.replace('        --lang=*) DASHBOARD_LANG="${arg#*=}" ;;\n        --tui)', '        --lang=*) DASHBOARD_LANG="${arg#*=}" ;;\n        --ui-lang=*) UI_LANG="${arg#*=}"; UI_LANG_EXPLICIT="yes" ;;\n        --tui)', 1)
s = s.replace(
'''case "$DASHBOARD_LANG" in\n    en) UI_LANG="en" ;;\n    *) UI_LANG="pt-BR" ;;\nesac\nexport XLX_UI_LANG="$UI_LANG"''',
'''if [ "$UI_LANG_EXPLICIT" != "yes" ]; then\n    case "$DASHBOARD_LANG" in\n        en) UI_LANG="en" ;;\n        *) UI_LANG="pt-BR" ;;\n    esac\nfi\ncase "$UI_LANG" in\n    pt-BR|en) ;;\n    *) printf 'ERRO / ERROR: idioma da instalação inválido / invalid installer language: %s\\n' "$UI_LANG" >&2; exit 2 ;;\nesac\nexport XLX_UI_LANG="$UI_LANG"''',
1
)
if '--ui-lang=*)' not in s:
    raise SystemExit('install.sh --ui-lang patch failed')
p.write_text(s, encoding="utf-8")

# Version and docs.
Path("VERSION").write_text("1.3.1\n", encoding="utf-8")
for name in ["README.md", "README.en.md", "README.pt-BR.md"]:
    p = Path(name)
    s = p.read_text(encoding="utf-8")
    s = s.replace("v1.3.0", "v1.3.1", 1)
    p.write_text(s, encoding="utf-8")

p = Path("CHANGELOG.md")
s = p.read_text(encoding="utf-8")
entry = '''## v1.3.1 — TUI usability\n\n- Adds an installer-language selector at the start of the guided interface.\n- Adds a short on-screen instruction explaining where to type and how to continue.\n- Pressing Enter in text-answer fields now moves focus to the next response line; on the final field it focuses Continue.\n- Improves contrast of Back, Continue and Cancel buttons for readability.\n- Keeps dashboard language selection independent from installer language.\n\n'''
if "## v1.3.1 — TUI usability" not in s:
    first = s.find("## ")
    s = (s[:first] + entry + s[first:]) if first >= 0 else (entry + s)
p.write_text(s, encoding="utf-8")
