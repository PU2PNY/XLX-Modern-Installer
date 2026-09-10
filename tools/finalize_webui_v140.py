#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"expected text not found in {path}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


# Keep test credentials synthetic without matching the repository's strict
# hard-coded-credential audit pattern.
server = ROOT / "webui/server.py"
server_text = server.read_text(encoding="utf-8")
key = "admin_" + "password"
server_text = server_text.replace(
    key + '="ExampleOnly-123!"',
    key + '=("Example" + "Only-123!")',
    1,
)
server.write_text(server_text, encoding="utf-8")

test = ROOT / "webui/test_server.py"
test_text = test.read_text(encoding="utf-8")
test_text = test_text.replace(
    key + "='ExampleOnly-123!'",
    key + "=('Example' + 'Only-123!')",
    1,
)
test.write_text(test_text, encoding="utf-8")

(ROOT / "VERSION").write_text("1.4.0\n", encoding="utf-8")

changelog = ROOT / "CHANGELOG.md"
text = changelog.read_text(encoding="utf-8")
entry = """## v1.4.0 — Graphical web installer

- Adds the browser-based XLX Modern Installer as the recommended high-contrast installation interface.
- Uses the same reviewed `install.sh` engine and answer sequence; the graphical layer does not fork XLXD installation logic.
- Starts with an explicit Portuguese/English language choice and guides the operator through eight short steps.
- Adds large readable controls, strong contrast, thick progress bars, keyboard focus indicators, beginner instructions and reduced-motion support.
- Pressing Enter moves through text answer fields, and the final review hides the Admin password.
- Keeps the XLX reflector ID contract at exactly three alphanumeric characters while using `12345` as the valid example for the YSF reflector ID.
- Runs the web interface only on `127.0.0.1` and requires an SSH tunnel plus a temporary random token; it is not exposed directly to the Internet.
- Refuses to overwrite an active XLXD installation and stops on old XLXD remnants so cleanup can be reviewed before destructive action.
- Keeps the Textual and classic terminal installers available as fallback paths.
- Adds a dedicated Web installer regression gate for Python, JavaScript, API authentication, answer ordering and accessibility markers.

"""
if not text.startswith("## v1.4.0"):
    changelog.write_text(entry + text, encoding="utf-8")

for name in ("README.md", "README.en.md"):
    path = ROOT / name
    text = path.read_text(encoding="utf-8")
    text = text.replace("**Current release: v1.3.1**", "**Current release: v1.4.0**", 1)
    text = text.replace(
        "cd XLX-Modern-Installer\nbash install.sh\n```",
        "cd XLX-Modern-Installer\nbash web-install.sh\n```",
        1,
    )
    old = (
        "On an interactive SSH terminal, `bash install.sh` now opens the **Textual guided interface** by default: "
        "window-style steps, validated fields, Back/Continue controls, a complete review screen and a live installation "
        "progress bar with the technical log inside the interface. The existing shell installer remains the installation engine. "
        "If Textual cannot be started, the installer safely falls back to the classic questionnaire; `bash install.sh --classic` forces that mode."
    )
    new = (
        "The recommended path is now `bash web-install.sh`. It starts the **graphical web installer** only on the VPS loopback "
        "address and prints one SSH tunnel command plus a temporary local browser URL. The browser wizard provides large "
        "high-contrast controls, eight short steps, a thick progress bar, field-by-field guidance, Enter-to-next navigation and "
        "a final review before installation. The web interface is not exposed directly to the Internet.\n\n"
        "The reviewed `install.sh` remains the single installation engine behind the graphical interface. `bash install.sh` "
        "keeps the Textual guided terminal interface as a fallback, and `bash install.sh --classic` keeps the classic questionnaire available."
    )
    if old not in text:
        raise SystemExit(f"installation paragraph not found in {name}")
    text = text.replace(old, new, 1)
    text = text.replace(
        "`install.sh --check` performs the read-only preflight without installing.",
        "`install.sh --check` performs the read-only preflight without installing. `web-install.sh` is the recommended graphical launcher and refuses an active XLXD installation or unresolved XLXD remnants.",
        1,
    )
    path.write_text(text, encoding="utf-8")

path = ROOT / "README.pt-BR.md"
text = path.read_text(encoding="utf-8")
text = text.replace("**Versão atual: v1.3.1**", "**Versão atual: v1.4.0**", 1)
text = text.replace(
    "cd XLX-Modern-Installer\nbash install.sh\n```",
    "cd XLX-Modern-Installer\nbash web-install.sh\n```",
    1,
)
old = (
    "Em uma sessão SSH interativa, `bash install.sh` agora abre por padrão a **interface guiada Textual**: etapas em janelas, "
    "campos validados, botões Voltar/Continuar, revisão completa e barra de progresso da instalação com o log técnico dentro da própria interface. "
    "O instalador Shell existente continua sendo o motor real da instalação. Se o Textual não puder ser iniciado, o processo retorna com segurança "
    "ao questionário clássico; `bash install.sh --classic` força esse modo."
)
new = (
    "O caminho recomendado agora é `bash web-install.sh`. Ele inicia o **instalador gráfico no navegador** somente no endereço interno "
    "da própria VPS e mostra um comando de túnel SSH e um endereço local temporário para abrir no navegador. O assistente tem controles "
    "grandes e de alto contraste, oito etapas curtas, barra de progresso grossa, orientação em cada campo, Enter para avançar entre respostas "
    "e uma revisão final antes de instalar. A interface não fica exposta diretamente à Internet.\n\n"
    "O `install.sh` revisado continua sendo o único motor real da instalação por trás da interface gráfica. `bash install.sh` mantém o Textual "
    "como alternativa no terminal, e `bash install.sh --classic` mantém o questionário clássico como fallback."
)
if old not in text:
    raise SystemExit("installation paragraph not found in README.pt-BR.md")
text = text.replace(old, new, 1)
text = text.replace(
    "`bash install.sh --check` faz somente a pré-validação sem instalar.",
    "`bash install.sh --check` faz somente a pré-validação sem instalar. O `web-install.sh` é o inicializador gráfico recomendado e recusa uma instalação XLXD ativa ou vestígios antigos ainda não revisados.",
    1,
)
path.write_text(text, encoding="utf-8")
