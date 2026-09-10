#!/usr/bin/env python3
from __future__ import annotations

import argparse
import asyncio
import os
import re
import subprocess
from pathlib import Path
from typing import Any

from textual import on
from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical, VerticalScroll
from textual.widgets import Button, Input, Label, ProgressBar, RichLog, Select, Static, Switch

TEXTUAL_PIN = "8.2.8"
ANSI_RE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
DOMAIN_RE = re.compile(r"^([a-z0-9-]+\.)+[a-z]{2,}$")
EMAIL_RE = re.compile(r"^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$")
CALLSIGN_RE = re.compile(r"^[A-Z0-9]{3,6}$")
ADMIN_USER_RE = re.compile(r"^[A-Za-z0-9._-]{3,64}$")
ADMIN_SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9-]{1,31}$")


def detected_timezone() -> str:
    try:
        value = subprocess.check_output(
            ["timedatectl", "show", "--property=Timezone", "--value"],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=4,
        ).strip()
        if value:
            return value
    except Exception:
        pass
    return "UTC"


def port_in_use(port: int) -> bool:
    try:
        result = subprocess.run(
            ["ss", "-H", "-tuln", f"sport = :{port}"],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=4,
            check=False,
        )
        return bool(result.stdout.strip())
    except Exception:
        return False


def build_answers(data: dict[str, Any]) -> list[str]:
    """Build the exact stdin sequence expected by the reviewed base installer."""
    answers = [
        data["reflector_id"],
        data["domain"],
        data["email"],
        data["callsign"],
        data["country"],
        data["timezone"],
        "Y",
        data["comment"],
        data["header_text"],
        data["footer_text"],
        "Y" if data["https"] else "N",
        "Y" if data["echo"] else "N",
        str(data["modules"]),
        str(data["ysf_port"]),
        str(data["ysf_freq"]),
        "Y" if data["autolink"] else "N",
    ]
    if data["autolink"]:
        answers.append(data["autolink_module"])
    answers.extend(
        [
            data["location"],
            data["ysf_id"],
            data["admin_user"],
            data["admin_slug"],
            data["admin_password"],
            data["admin_password"],
            "",
        ]
    )
    return answers


def self_test() -> int:
    sample = {
        "reflector_id": "PNY",
        "domain": "xlx026.net",
        "email": "sysop@example.net",
        "callsign": "PU2PNY",
        "country": "Brazil",
        "timezone": "America/Sao_Paulo",
        "comment": "XLXPNY Multiprotocol Reflector by PU2PNY",
        "header_text": "XLXPNY by PU2PNY",
        "footer_text": "Provided by PU2PNY",
        "https": True,
        "echo": True,
        "modules": 5,
        "ysf_port": 42000,
        "ysf_freq": 433125000,
        "autolink": True,
        "autolink_module": "C",
        "location": "Santa Isabel - SP",
        "ysf_id": "72426",
        "admin_user": "pu2pny",
        "admin_slug": "controle-xlx",
        "admin_password": "ExampleOnly-123!",
    }
    answers = build_answers(sample)
    assert answers[0] == "PNY"
    assert answers[5:7] == ["America/Sao_Paulo", "Y"]
    assert answers[16] == "C"
    assert answers[-1] == ""
    assert len(answers) == 24
    return 0


class XLXInstallerApp(App):
    TITLE = "XLX Modern Installer — PU2PNY"
    SUB_TITLE = "Instalação guiada do refletor e painel"
    BINDINGS = [("ctrl+c", "request_close", "Sair")]
    CSS = """
    Screen {
        background: #07131d;
        color: #e8f4ff;
    }
    #brand {
        height: 5;
        padding: 1 2;
        background: #0b2130;
        border-bottom: solid #10b8ff;
        color: #f4fbff;
        text-style: bold;
    }
    #layout { height: 1fr; }
    #sidebar {
        width: 28;
        min-width: 24;
        padding: 1;
        background: #081a27;
        border-right: solid #1b4a64;
    }
    .step {
        height: 3;
        padding: 1;
        color: #7792a4;
    }
    .step-active {
        color: #ffffff;
        background: #0d3045;
        border-left: thick #19bdfc;
        text-style: bold;
    }
    .step-done { color: #5ee68a; }
    #content {
        width: 1fr;
        padding: 1 2;
    }
    #step-title {
        height: 3;
        content-align: left middle;
        text-style: bold;
        color: #21c6ff;
    }
    #form {
        height: 1fr;
        border: round #1d6689;
        background: #0a1c28;
        padding: 1 2;
    }
    .page {
        width: 1fr;
        height: auto;
    }
    .field-label {
        margin-top: 1;
        color: #c9e8f8;
        text-style: bold;
    }
    Input, Select {
        width: 1fr;
        margin-bottom: 1;
    }
    Switch { margin-bottom: 1; }
    #error {
        height: 3;
        padding: 1;
        color: #ff6b6b;
    }
    #nav {
        height: 4;
        align: right middle;
    }
    #nav Button {
        margin-left: 1;
        min-width: 14;
    }
    #review {
        padding: 1 2;
        border: round #1d6689;
        background: #0a1c28;
        height: 1fr;
    }
    #progress-page { height: 1fr; }
    #progress { margin: 1 0; }
    #install-status {
        height: 3;
        color: #21c6ff;
        text-style: bold;
    }
    #install-log {
        height: 1fr;
        border: round #1d6689;
        background: #040b11;
        padding: 1;
    }
    #footer-line {
        height: 2;
        color: #6c8ea2;
        content-align: center middle;
    }
    """

    STEP_NAMES = [
        "1  Identidade",
        "2  Opções",
        "3  Rede / YSF",
        "4  Administração",
        "5  Revisão",
        "6  Instalação",
    ]

    def __init__(self, root_dir: Path):
        super().__init__()
        self.root_dir = root_dir
        self.current_step = 0
        self.installing = False
        self.proc: asyncio.subprocess.Process | None = None
        self.data: dict[str, Any] = {}
        self._detected_tz = detected_timezone()

    def compose(self) -> ComposeResult:
        yield Static(
            "[b]XLX MODERN INSTALLER[/b]  •  [#21c6ff]PU2PNY[/#21c6ff]\n"
            "[#5ee68a]REFLETOR + PAINEL • INSTALAÇÃO GUIADA[/#5ee68a]",
            id="brand",
            markup=True,
        )
        with Horizontal(id="layout"):
            with Vertical(id="sidebar"):
                for index, name in enumerate(self.STEP_NAMES):
                    yield Static(name, id=f"step-{index}", classes="step")
            with Vertical(id="content"):
                yield Static("", id="step-title")
                with VerticalScroll(id="form"):
                    with Vertical(id="page-0", classes="page"):
                        yield Label("ID do refletor *", classes="field-label")
                        yield Input(placeholder="Ex.: PNY, 026 ou 724", id="reflector_id", max_length=3)
                        yield Label("Domínio completo (FQDN) *", classes="field-label")
                        yield Input(placeholder="Ex.: xlx026.net", id="domain")
                        yield Label("E-mail do sysop *", classes="field-label")
                        yield Input(placeholder="Ex.: contato@seudominio.net", id="email")
                        yield Label("Indicativo do sysop *", classes="field-label")
                        yield Input(placeholder="Ex.: PU2PNY", id="callsign", max_length=6)
                        yield Label("País *", classes="field-label")
                        yield Input(placeholder="Ex.: Brazil", id="country")
                        yield Label("Fuso horário *", classes="field-label")
                        yield Input(value=self._detected_tz, id="timezone")
                    with Vertical(id="page-1", classes="page"):
                        yield Label("Comentário para lista XLX", classes="field-label")
                        yield Input(placeholder="Gerado automaticamente se ficar vazio", id="comment")
                        yield Label("Texto da aba do painel", classes="field-label")
                        yield Input(placeholder="Gerado automaticamente se ficar vazio", id="header_text")
                        yield Label("Rodapé do painel", classes="field-label")
                        yield Input(placeholder="Gerado automaticamente se ficar vazio", id="footer_text")
                        yield Label("Ativar HTTPS", classes="field-label")
                        yield Switch(value=True, id="https")
                        yield Label("Instalar Echo Test no módulo E", classes="field-label")
                        yield Switch(value=True, id="echo")
                        yield Label("Quantidade de módulos ativos", classes="field-label")
                        yield Input(value="5", id="modules")
                    with Vertical(id="page-2", classes="page"):
                        yield Label("Porta UDP YSF", classes="field-label")
                        yield Input(value="42000", id="ysf_port")
                        yield Label("Frequência YSF Wires-X (Hz)", classes="field-label")
                        yield Input(value="433125000", id="ysf_freq")
                        yield Label("Auto-link YSF", classes="field-label")
                        yield Switch(value=True, id="autolink")
                        yield Label("Módulo do Auto-link YSF", classes="field-label")
                        yield Input(value="C", id="autolink_module", max_length=1)
                        yield Label("Cidade / estado ou região *", classes="field-label")
                        yield Input(placeholder="Ex.: Santa Isabel - SP", id="location")
                        yield Label("ID do refletor YSF *", classes="field-label")
                        yield Input(placeholder="1 a 8 dígitos", id="ysf_id", max_length=8)
                    with Vertical(id="page-3", classes="page"):
                        yield Label("Usuário do Admin privado *", classes="field-label")
                        yield Input(placeholder="3 a 64 caracteres", id="admin_user")
                        yield Label("Slug/URL privada do Admin *", classes="field-label")
                        yield Input(value="admin", id="admin_slug", max_length=32)
                        yield Label("Senha do Admin *", classes="field-label")
                        yield Input(password=True, id="admin_password")
                        yield Label("Repita a senha *", classes="field-label")
                        yield Input(password=True, id="admin_password_confirm")
                        yield Label("Idioma do painel", classes="field-label")
                        yield Select(
                            [
                                ("Português (Brasil)", "pt-BR"),
                                ("English", "en"),
                                ("Español", "es"),
                                ("Français", "fr"),
                                ("Deutsch", "de"),
                                ("Italiano", "it"),
                            ],
                            value="pt-BR",
                            allow_blank=False,
                            id="dashboard_lang",
                        )
                    with Vertical(id="page-4", classes="page"):
                        yield Static("", id="review")
                    with Vertical(id="page-5", classes="page"):
                        with Vertical(id="progress-page"):
                            yield Static("Preparando instalação...", id="install-status")
                            yield ProgressBar(total=100, show_eta=False, id="progress")
                            yield RichLog(id="install-log", highlight=False, markup=False, wrap=True)
                yield Static("", id="error")
                with Horizontal(id="nav"):
                    yield Button("← Voltar", id="back")
                    yield Button("Continuar →", variant="primary", id="next")
                    yield Button("Cancelar", variant="error", id="cancel")
        yield Static("XLX Modern Installer • PU2PNY", id="footer-line")

    def on_mount(self) -> None:
        self.show_step(0)

    def show_step(self, step: int) -> None:
        self.current_step = max(0, min(step, len(self.STEP_NAMES) - 1))
        for index in range(len(self.STEP_NAMES)):
            page = self.query_one(f"#page-{index}")
            page.styles.display = "block" if index == self.current_step else "none"
            marker = self.query_one(f"#step-{index}", Static)
            marker.remove_class("step-active", "step-done")
            if index == self.current_step:
                marker.add_class("step-active")
            elif index < self.current_step:
                marker.add_class("step-done")

        self.query_one("#step-title", Static).update(self.STEP_NAMES[self.current_step])
        back = self.query_one("#back", Button)
        nxt = self.query_one("#next", Button)
        cancel = self.query_one("#cancel", Button)
        back.disabled = self.current_step == 0 or self.installing
        cancel.disabled = self.installing
        if self.current_step == 4:
            nxt.label = "Instalar agora"
        elif self.current_step == 5:
            nxt.label = "Instalando..."
            nxt.disabled = True
        else:
            nxt.label = "Continuar →"
            nxt.disabled = False
        self.clear_error()

    def clear_error(self) -> None:
        self.query_one("#error", Static).update("")

    def fail(self, message: str) -> bool:
        self.query_one("#error", Static).update(f"⚠ {message}")
        return False

    def input_value(self, widget_id: str) -> str:
        return self.query_one(f"#{widget_id}", Input).value.strip()

    def validate_step(self, step: int) -> bool:
        self.clear_error()
        if step == 0:
            rid = self.input_value("reflector_id").upper()
            domain = self.input_value("domain").lower()
            email = self.input_value("email").lower()
            callsign = self.input_value("callsign").upper()
            country = self.input_value("country")
            timezone = self.input_value("timezone")
            if not re.fullmatch(r"[A-Z0-9]{3}", rid):
                return self.fail("O ID precisa ter exatamente 3 caracteres: letras A-Z e/ou números.")
            if not DOMAIN_RE.fullmatch(domain):
                return self.fail("Informe um domínio completo válido, por exemplo: xlx026.net.")
            if not EMAIL_RE.fullmatch(email):
                return self.fail("Informe um e-mail válido.")
            if not CALLSIGN_RE.fullmatch(callsign):
                return self.fail("O indicativo deve ter de 3 a 6 letras/números.")
            if not country:
                return self.fail("Informe o país.")
            if not timezone:
                return self.fail("Informe o fuso horário.")
            self.data.update(
                reflector_id=rid,
                domain=domain,
                email=email,
                callsign=callsign,
                country=country,
                timezone=timezone,
            )
            return True

        if step == 1:
            comment = self.input_value("comment") or (
                f"XLX{self.data['reflector_id']} Multiprotocol Reflector "
                f"by {self.data['callsign']}, info: {self.data['email']}"
            )
            header_text = self.input_value("header_text") or f"XLX{self.data['reflector_id']} by {self.data['callsign']}"
            footer_text = self.input_value("footer_text") or f"Provided by {self.data['callsign']}, info: {self.data['email']}"
            if len(comment) > 100:
                return self.fail("O comentário deve ter no máximo 100 caracteres.")
            if len(header_text) > 25:
                return self.fail("O texto da aba deve ter no máximo 25 caracteres.")
            if len(footer_text) > 50:
                return self.fail("O rodapé deve ter no máximo 50 caracteres.")
            try:
                modules = int(self.input_value("modules"))
            except ValueError:
                return self.fail("A quantidade de módulos precisa ser um número.")
            echo = self.query_one("#echo", Switch).value
            minimum = 5 if echo else 1
            if not minimum <= modules <= 26:
                return self.fail(f"Com essa opção de Echo, use entre {minimum} e 26 módulos.")
            self.data.update(
                comment=comment,
                header_text=header_text,
                footer_text=footer_text,
                https=self.query_one("#https", Switch).value,
                echo=echo,
                modules=modules,
            )
            return True

        if step == 2:
            try:
                ysf_port = int(self.input_value("ysf_port"))
            except ValueError:
                return self.fail("A porta YSF precisa ser numérica.")
            if not 1 <= ysf_port <= 65535:
                return self.fail("A porta YSF deve estar entre 1 e 65535.")
            if port_in_use(ysf_port):
                return self.fail(f"A porta {ysf_port} já está em uso. Escolha outra antes de continuar.")
            ysf_freq = self.input_value("ysf_freq")
            if not re.fullmatch(r"\d{9}", ysf_freq):
                return self.fail("A frequência YSF precisa ter exatamente 9 dígitos.")
            autolink = self.query_one("#autolink", Switch).value
            module = self.input_value("autolink_module").upper()
            if autolink:
                if not re.fullmatch(r"[A-Z]", module):
                    return self.fail("Informe uma letra de módulo válida para o Auto-link.")
                if ord(module) - ord("A") >= self.data["modules"]:
                    last = chr(ord("A") + self.data["modules"] - 1)
                    return self.fail(f"O módulo do Auto-link deve estar entre A e {last}.")
            location = self.input_value("location")
            ysf_id = self.input_value("ysf_id")
            if not location:
                return self.fail("Informe cidade e estado/região.")
            if not re.fullmatch(r"\d{1,8}", ysf_id):
                return self.fail("O ID YSF deve ter de 1 a 8 dígitos.")
            self.data.update(
                ysf_port=ysf_port,
                ysf_freq=int(ysf_freq),
                autolink=autolink,
                autolink_module=module or "C",
                location=location,
                ysf_id=ysf_id,
            )
            return True

        if step == 3:
            admin_user = self.input_value("admin_user")
            admin_slug = self.input_value("admin_slug").lower()
            password = self.query_one("#admin_password", Input).value
            confirm = self.query_one("#admin_password_confirm", Input).value
            lang = self.query_one("#dashboard_lang", Select).value
            if not ADMIN_USER_RE.fullmatch(admin_user):
                return self.fail("Usuário Admin inválido. Use letras, números, ponto, _ ou -.")
            if not ADMIN_SLUG_RE.fullmatch(admin_slug):
                return self.fail("A URL do Admin deve ter de 2 a 32 caracteres: a-z, 0-9 e hífen.")
            if len(password) < 8:
                return self.fail("A senha do Admin precisa ter pelo menos 8 caracteres.")
            if password != confirm:
                return self.fail("As duas senhas não são iguais.")
            if lang not in {"pt-BR", "en", "es", "fr", "de", "it"}:
                return self.fail("Selecione um idioma válido.")
            self.data.update(
                admin_user=admin_user,
                admin_slug=admin_slug,
                admin_password=password,
                dashboard_lang=str(lang),
            )
            return True

        return True

    def update_review(self) -> None:
        yn = lambda value: "Sim" if value else "Não"
        module_line = self.data["autolink_module"] if self.data["autolink"] else "Desativado"
        review = (
            f"[b]Refletor[/b]        XLX{self.data['reflector_id']}\n"
            f"[b]Domínio[/b]         {self.data['domain']}\n"
            f"[b]Sysop[/b]           {self.data['callsign']} • {self.data['email']}\n"
            f"[b]Local[/b]           {self.data['location']} • {self.data['country']}\n"
            f"[b]Fuso[/b]            {self.data['timezone']}\n\n"
            f"[b]HTTPS[/b]           {yn(self.data['https'])}\n"
            f"[b]Echo módulo E[/b]   {yn(self.data['echo'])}\n"
            f"[b]Módulos[/b]         {self.data['modules']}\n"
            f"[b]YSF[/b]             UDP {self.data['ysf_port']} • {self.data['ysf_freq']} Hz\n"
            f"[b]Auto-link[/b]       {yn(self.data['autolink'])} • módulo {module_line}\n"
            f"[b]YSF ID[/b]          {self.data['ysf_id']}\n\n"
            f"[b]Admin[/b]           {self.data['admin_user']} • /{self.data['admin_slug']}/\n"
            f"[b]Senha[/b]           ••••••••\n"
            f"[b]Idioma painel[/b]   {self.data['dashboard_lang']}\n\n"
            "[#5ee68a][b]Revise os dados. Se estiver tudo correto, selecione ‘Instalar agora’.[/b][/#5ee68a]"
        )
        self.query_one("#review", Static).update(review)

    @on(Button.Pressed)
    async def handle_button(self, event: Button.Pressed) -> None:
        button_id = event.button.id
        if button_id == "cancel":
            self.action_request_close()
            return
        if button_id == "back" and not self.installing:
            self.show_step(self.current_step - 1)
            if self.current_step == 4:
                self.update_review()
            return
        if button_id != "next" or self.installing:
            return

        if self.current_step <= 3:
            if not self.validate_step(self.current_step):
                return
            self.show_step(self.current_step + 1)
            if self.current_step == 4:
                self.update_review()
            return

        if self.current_step == 4:
            self.show_step(5)
            await self.run_installation()

    def action_request_close(self) -> None:
        if self.installing:
            self.fail("A instalação está em andamento. Aguarde a conclusão para evitar estado parcial.")
            return
        self.exit()

    def progress_from_line(self, line: str, current: int) -> int:
        upper = line.upper()
        stages = [
            (("INICIANDO XLX MODERN INSTALLER", "STARTING XLX MODERN INSTALLER"), 5),
            (("UPDATING OS", "ATUALIZANDO OS"), 12),
            (("INSTALLING DEPENDENCIES", "INSTALANDO DEPENDÊNCIAS"), 22),
            (("DOWNLOADING THE XLX APP", "BAIXANDO"), 32),
            (("COMPILING", "COMPILANDO"), 43),
            (("COPYING COMPONENTS", "COPIANDO COMPONENTES"), 52),
            (("INSTALLING ECHO TEST SERVER", "ECHO TEST"), 58),
            (("INSTALANDO XLX MODERN DASHBOARD", "INSTALLING XLX MODERN DASHBOARD"), 68),
            (("PROVISIONANDO APRS/D-PRS", "PROVISIONING NATIVE APRS/D-PRS"), 80),
            (("VALIDAÇÃO PÓS-INSTALAÇÃO", "POST-INSTALLATION VALIDATION"), 91),
            (("INSTALAÇÃO CONCLUÍDA", "INSTALLATION COMPLETE"), 100),
        ]
        for needles, value in stages:
            if any(needle in upper for needle in needles):
                return max(current, value)
        return current

    async def run_installation(self) -> None:
        self.installing = True
        self.show_step(5)
        log = self.query_one("#install-log", RichLog)
        progress = self.query_one("#progress", ProgressBar)
        status = self.query_one("#install-status", Static)
        status.update("Instalando. Não feche esta sessão SSH.")
        self.query_one("#cancel", Button).disabled = True

        runtime = Path("/opt/xlx-modern-installer/runtime")
        runtime.mkdir(parents=True, exist_ok=True)
        answers_file = runtime / f"tui-answers-{os.getpid()}.txt"
        answers_file.write_text("\n".join(build_answers(self.data)) + "\n", encoding="utf-8")
        answers_file.chmod(0o600)

        env = os.environ.copy()
        env["XLX_MODERN_ANSWERS_FILE"] = str(answers_file)
        cmd = [
            "bash",
            str(self.root_dir / "install.sh"),
            "--tui-child",
            f"--lang={self.data['dashboard_lang']}",
        ]

        current_progress = 1
        progress.update(progress=current_progress)
        log.write("Iniciando o motor de instalação XLX Modern...")
        rc = 1

        try:
            self.proc = await asyncio.create_subprocess_exec(
                *cmd,
                cwd=str(self.root_dir),
                env=env,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
            )
            assert self.proc.stdout is not None
            while True:
                raw = await self.proc.stdout.readline()
                if not raw:
                    break
                line = ANSI_RE.sub("", raw.decode("utf-8", errors="replace")).rstrip()
                if line:
                    log.write(line)
                    current_progress = self.progress_from_line(line, current_progress)
                    progress.update(progress=current_progress)
            rc = await self.proc.wait()
        finally:
            try:
                answers_file.unlink(missing_ok=True)
            except Exception:
                pass

        self.installing = False
        self.query_one("#back", Button).disabled = True
        self.query_one("#next", Button).disabled = True
        close_button = self.query_one("#cancel", Button)
        close_button.disabled = False
        close_button.label = "Fechar"

        if rc == 0:
            progress.update(progress=100)
            status.update("✓ Instalação concluída e validações finais executadas.")
            log.write("")
            log.write("Instalação concluída. Você pode fechar esta janela.")
        else:
            status.update(f"✖ A instalação terminou com erro (código {rc}).")
            log.write("")
            log.write("A instalação NÃO foi considerada pronta. Revise as últimas linhas acima.")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    XLXInstallerApp(args.root.resolve()).run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
