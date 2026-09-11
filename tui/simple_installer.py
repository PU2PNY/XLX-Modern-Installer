#!/usr/bin/env python3
from __future__ import annotations

import argparse
import asyncio
import os
import re
import socket
import subprocess
import time
from collections import deque
from pathlib import Path
from typing import Any

from textual import on
from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Button, Input, Label, ProgressBar, Static

DOMAIN_RE = re.compile(r"^([a-z0-9-]+\.)+[a-z]{2,}$")
EMAIL_RE = re.compile(r"^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$")
CALLSIGN_RE = re.compile(r"^[A-Z0-9]{3,6}$")
ADMIN_SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9-]{1,31}$")
ANSI_RE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")

DEFAULT_MODULES = 5
DEFAULT_YSF_PORT = 42000
DEFAULT_YSF_FREQ = 433125000
DEFAULT_AUTOLINK_MODULE = "C"
ENGINE_LOG = Path("/var/log/xlx-reflector/installer/engine-ui.log")

QUESTION_KEYS = [
    "reflector_id",
    "domain",
    "callsign",
    "email",
    "country",
    "location",
    "ysf_id",
    "admin_slug",
    "admin_password",
    "admin_password_confirm",
]
ESSENTIAL_COUNT = 7

PT = {
    "step1": "Dados essenciais",
    "step2": "Acesso privado",
    "step3": "Revisão",
    "step4": "Instalação",
    "guide": "Digite somente a resposta mostrada abaixo e pressione Enter. O instalador não permite pular campo obrigatório. Para corrigir a resposta anterior, use ← Voltar.",
    "back": "← Voltar",
    "next": "Confirmar e avançar →",
    "cancel": "Cancelar",
    "install": "INSTALAR AGORA",
    "show": "Mostrar senha",
    "hide": "Ocultar senha",
}
EN = {
    "step1": "Essential data",
    "step2": "Private access",
    "step3": "Review",
    "step4": "Installation",
    "guide": "Type only the answer requested below and press Enter. Required fields cannot be skipped. To correct the previous answer, use ← Back.",
    "back": "← Back",
    "next": "Confirm and continue →",
    "cancel": "Cancel",
    "install": "INSTALL NOW",
    "show": "Show password",
    "hide": "Hide password",
}


def detected_timezone() -> str:
    try:
        value = subprocess.check_output(
            ["timedatectl", "show", "--property=Timezone", "--value"],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=4,
        ).strip()
        return value or "UTC"
    except Exception:
        return "UTC"


def generated_comment(data: dict[str, Any]) -> str:
    return f"XLX{data['reflector_id']} by {data['callsign']} - {data['domain']}"


def build_answers(data: dict[str, Any]) -> list[str]:
    rid = data["reflector_id"]
    callsign = data["callsign"]
    domain = data["domain"]
    header = f"XLX{rid} • {callsign}"
    return [
        rid,
        domain,
        data["email"],
        callsign,
        data["country"],
        data["timezone"],
        "Y",
        generated_comment(data),
        header,
        header,
        "Y",
        "Y",
        str(DEFAULT_MODULES),
        str(DEFAULT_YSF_PORT),
        str(DEFAULT_YSF_FREQ),
        "Y",
        DEFAULT_AUTOLINK_MODULE,
        data["location"],
        data["ysf_id"],
        data["admin_user"],
        data["admin_slug"],
        data["admin_password"],
        data["admin_password"],
        "",
    ]


def udp_port_available(port: int) -> bool:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.bind(("0.0.0.0", port))
        return True
    except OSError:
        return False
    finally:
        sock.close()


def progress_from_line(line: str, current: int, pt: bool) -> tuple[int, str | None]:
    upper = line.upper()
    stages = [
        (("INICIANDO XLX MODERN INSTALLER", "STARTING XLX MODERN INSTALLER"), 5, "Inicializando" if pt else "Starting"),
        (("UPDATING OS", "ATUALIZANDO OS"), 12, "Preparando o sistema" if pt else "Preparing system"),
        (("INSTALLING DEPENDENCIES", "INSTALANDO DEPENDÊNCIAS"), 22, "Instalando dependências" if pt else "Installing dependencies"),
        (("DOWNLOADING THE XLX APP", "BAIXANDO"), 32, "Preparando o XLXD" if pt else "Preparing XLXD"),
        (("COMPILING", "COMPILANDO"), 43, "Compilando o refletor" if pt else "Compiling reflector"),
        (("COPYING COMPONENTS", "COPIANDO COMPONENTES"), 52, "Instalando componentes" if pt else "Installing components"),
        (("INSTALLING ECHO TEST SERVER", "ECHO TEST"), 58, "Configurando Echo Test" if pt else "Configuring Echo Test"),
        (("INSTALANDO XLX MODERN DASHBOARD", "INSTALLING XLX MODERN DASHBOARD"), 68, "Instalando o painel" if pt else "Installing dashboard"),
        (("PROVISIONANDO APRS/D-PRS", "PROVISIONING NATIVE APRS/D-PRS"), 80, "Configurando APRS / D-PRS" if pt else "Configuring APRS / D-PRS"),
        (("VALIDAÇÃO PÓS-INSTALAÇÃO", "POST-INSTALLATION VALIDATION"), 91, "Validando tudo antes de concluir" if pt else "Validating everything before completion"),
        (("INSTALAÇÃO CONCLUÍDA", "INSTALLATION COMPLETE"), 100, "Concluído" if pt else "Complete"),
    ]
    for needles, value, label in stages:
        if any(needle in upper for needle in needles):
            return max(current, value), label
    return current, None


def safe_line(line: str) -> bool:
    upper = line.upper()
    return not any(token in upper for token in ("PASSWORD", "SENHA", "CONTROL_PASSWORD", "XLX_CONTROL_PASSWORD"))


def looks_like_error(line: str) -> bool:
    upper = line.upper()
    return any(token in upper for token in ("ERROR", "ERRO", "FAILED", "FAILURE", "FALH", "MISSING", "INACTIVE", "FATAL"))


def write_ui_state(state: str) -> None:
    state_file = os.environ.get("XLX_UI_STATE_FILE", "").strip()
    if not state_file:
        return
    try:
        target = Path(state_file)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(state + "\n", encoding="utf-8")
        os.chmod(target, 0o600)
    except Exception:
        pass


class SimpleInstaller(App):
    TITLE = "XLX Modern Installer — PU2PNY"
    BINDINGS = [("ctrl+c", "request_close", "Sair / Exit")]

    CSS = """
    Screen {
        background: #00070c;
        color: #ffffff;
    }
    #brand {
        height: 5;
        padding: 1 3;
        background: #00131f;
        color: #ffffff;
        border-bottom: heavy #35c9ff;
        text-style: bold;
    }
    #wrap {
        width: 98%;
        max-width: 156;
        height: 1fr;
        align-horizontal: center;
        padding: 1 1;
    }
    #step-line {
        height: 2;
        color: #ffffff;
        text-style: bold;
    }
    #wizard-progress {
        height: 5;
        margin-bottom: 1;
    }
    #guide {
        min-height: 5;
        height: auto;
        padding: 1 2;
        margin-bottom: 1;
        background: #00131f;
        color: #ffffff;
        border: heavy #35c9ff;
    }
    #card {
        height: 1fr;
        min-height: 16;
        padding: 2 3;
        background: #030b11;
        border: heavy #35c9ff;
    }
    .heading {
        height: auto;
        margin-bottom: 1;
        color: #ffffff;
        text-style: bold;
    }
    #counter {
        height: 2;
        color: #ffe066;
        text-style: bold;
    }
    #question-label {
        height: auto;
        margin-top: 1;
        color: #ffffff;
        text-style: bold;
    }
    #question-help {
        min-height: 3;
        height: auto;
        color: #dcefff;
        margin-bottom: 1;
    }
    #answer {
        width: 1fr;
        height: 5;
        margin: 1 0 1 0;
        background: #02070c;
        color: #ffffff;
        border: heavy #78b9dd;
    }
    #answer:focus {
        background: #ffffff;
        color: #000000;
        border: heavy #35c9ff;
    }
    #password-note {
        height: 2;
        color: #ffe066;
    }
    #review {
        height: 1fr;
        min-height: 15;
        padding: 1 2;
        background: #02070c;
        color: #ffffff;
        border: round #78b9dd;
    }
    #install-status {
        min-height: 4;
        height: auto;
        content-align: center middle;
        color: #ffffff;
        text-style: bold;
    }
    #install-progress {
        height: 6;
        margin: 1 0;
    }
    #install-detail {
        min-height: 9;
        height: auto;
        padding: 1 2;
        background: #02070c;
        color: #ffffff;
        border: heavy #78b9dd;
    }
    #install-detail.failed {
        background: #24070a;
        border: heavy #ff7070;
        color: #ffffff;
    }
    #error {
        min-height: 4;
        height: auto;
        padding: 1 2;
        margin-top: 1;
        background: #3b070b;
        color: #ffffff;
        border: heavy #ff7070;
        text-style: bold;
        display: none;
    }
    #hint {
        height: 2;
        color: #ffffff;
        text-style: bold;
    }
    #nav {
        height: 6;
        align: right middle;
    }
    #nav Button {
        min-width: 23;
        height: 5;
        margin-left: 1;
        color: #000000;
        text-style: bold;
    }
    #back {
        background: #ffe066;
        color: #000000;
        border: heavy #ffffff;
    }
    #next {
        background: #58d4ff;
        color: #000000;
        border: heavy #ffffff;
    }
    #cancel {
        background: #ff7070;
        color: #000000;
        border: heavy #ffffff;
    }
    #show-password {
        background: #ffffff;
        color: #000000;
        border: heavy #78b9dd;
    }
    #nav Button:focus {
        background: #ffffff;
        color: #000000;
        border: heavy #35c9ff;
    }
    #lang-actions {
        height: 7;
        align: center middle;
        margin-top: 2;
    }
    #lang-actions Button {
        min-width: 32;
        height: 5;
        margin: 1 2;
        background: #58d4ff;
        color: #000000;
        border: heavy #ffffff;
        text-style: bold;
    }
    #lang-actions Button:focus {
        background: #ffffff;
        color: #000000;
        border: heavy #35c9ff;
    }
    #footer {
        height: 2;
        content-align: center middle;
        color: #ffffff;
    }
    """

    def __init__(self, root: Path):
        super().__init__()
        self.root = root
        self.lang = "pt-BR"
        self.phase = "language"
        self.question_index = 0
        self.installing = False
        self.password_visible = False
        self.data: dict[str, Any] = {"timezone": detected_timezone(), "country": "Brazil"}
        self.proc: asyncio.subprocess.Process | None = None
        self.last_lines: deque[str] = deque(maxlen=14)
        self.last_errors: deque[str] = deque(maxlen=8)
        self.current_progress = 0

    @property
    def copy(self) -> dict[str, str]:
        return PT if self.lang == "pt-BR" else EN

    @property
    def current_key(self) -> str:
        return QUESTION_KEYS[self.question_index]

    def compose(self) -> ComposeResult:
        yield Static("[b]XLX MODERN INSTALLER[/b]  •  [#73ffac]PU2PNY[/#73ffac]\nINSTALAÇÃO GUIADA • GUIDED INSTALLATION", id="brand", markup=True)
        with Vertical(id="wrap"):
            yield Static("", id="step-line")
            yield ProgressBar(total=12, show_percentage=False, show_eta=False, id="wizard-progress")
            yield Static("", id="guide")
            with Vertical(id="card"):
                with Vertical(id="language-page"):
                    yield Static("Escolha o idioma / Choose language", classes="heading")
                    yield Static("Português fica selecionado primeiro. Pressione Enter para continuar em Português, ou escolha English.", id="language-help")
                    with Horizontal(id="lang-actions"):
                        yield Button("Português (Brasil)", id="lang-pt")
                        yield Button("English", id="lang-en")
                with Vertical(id="question-page"):
                    yield Static("", id="counter")
                    yield Label("", id="question-label")
                    yield Static("", id="question-help")
                    yield Input(id="answer")
                    yield Static("", id="password-note")
                with Vertical(id="review-page"):
                    yield Static("Revise antes de instalar", id="review-heading", classes="heading")
                    yield Static("", id="review", markup=True)
                with Vertical(id="install-page"):
                    yield Static("Instalação", id="install-heading", classes="heading")
                    yield Static("Preparando…", id="install-status")
                    yield ProgressBar(total=100, show_percentage=True, show_eta=False, id="install-progress")
                    yield Static("Aguardando início.", id="install-detail")
            yield Static("", id="error")
            yield Static("Enter = confirmar resposta • ← Voltar = corrigir resposta anterior • * = obrigatório", id="hint")
            with Horizontal(id="nav"):
                yield Button("← Voltar", id="back")
                yield Button("Mostrar senha", id="show-password")
                yield Button("Confirmar e avançar →", id="next")
                yield Button("Cancelar", id="cancel")
        yield Static("XLX Modern Installer • PU2PNY", id="footer")

    def on_mount(self) -> None:
        write_ui_state("MOUNTED")
        self.show_language()
        self.query_one("#lang-pt", Button).focus()

    def set_pages(self, language: bool = False, question: bool = False, review: bool = False, install: bool = False) -> None:
        self.query_one("#language-page").display = language
        self.query_one("#question-page").display = question
        self.query_one("#review-page").display = review
        self.query_one("#install-page").display = install

    def clear_error(self) -> None:
        error = self.query_one("#error", Static)
        error.update("")
        error.display = False

    def fail(self, message: str) -> bool:
        error = self.query_one("#error", Static)
        error.update(f"⚠ {message}")
        error.display = True
        if self.phase == "questions":
            self.query_one("#answer", Input).focus()
        return False

    def show_language(self) -> None:
        self.phase = "language"
        self.set_pages(language=True)
        self.query_one("#step-line", Static).update("IDIOMA / LANGUAGE")
        self.query_one("#guide", Static).update("Escolha Português ou English. Depois disso, o instalador mostra uma pergunta por vez.")
        self.query_one("#wizard-progress", ProgressBar).update(progress=0)
        self.query_one("#back", Button).display = False
        self.query_one("#show-password", Button).display = False
        self.query_one("#next", Button).display = False
        self.query_one("#cancel", Button).display = True
        self.clear_error()

    def set_language(self, lang: str) -> None:
        self.lang = "en" if lang == "en" else "pt-BR"
        if self.lang == "en" and self.data.get("country") == "Brazil":
            self.data["country"] = ""
        self.question_index = 0
        self.show_question()

    def macro_step(self) -> int:
        if self.phase == "questions":
            return 1 if self.question_index < ESSENTIAL_COUNT else 2
        if self.phase == "review":
            return 3
        return 4

    def step_title(self) -> str:
        return self.copy[f"step{self.macro_step()}"]

    def question_meta(self, key: str) -> tuple[str, str, str, bool]:
        pt = self.lang == "pt-BR"
        rid = str(self.data.get("reflector_id", "")).lower()
        if key == "reflector_id":
            return ("ID do refletor XLX *" if pt else "XLX reflector ID *", "Use exatamente 3 letras ou números. Exemplos válidos: 026, 724 ou PNY." if pt else "Use exactly 3 letters or numbers. Valid examples: 026, 724 or PNY.", "026", False)
        if key == "domain":
            return ("Domínio completo (FQDN) *" if pt else "Full domain (FQDN) *", "Digite o domínio que abrirá o painel. Exemplo: xlx026.net" if pt else "Enter the domain that will open the dashboard. Example: xlx026.net", "xlx026.net", False)
        if key == "callsign":
            return ("Indicativo do responsável (sysop) *" if pt else "Sysop callsign *", "Use somente letras e números, de 3 a 6 caracteres. Exemplo: PU2PNY" if pt else "Use only letters and numbers, 3 to 6 characters. Example: PU2PNY", "PU2PNY", False)
        if key == "email":
            return ("E-mail do responsável *" if pt else "Sysop email *", "Este e-mail será usado nas configurações do refletor e do certificado HTTPS." if pt else "This email is used in reflector settings and the HTTPS certificate.", "contato@seudominio.net" if pt else "contact@yourdomain.net", False)
        if key == "country":
            return ("País do refletor *" if pt else "Reflector country *", "Brasil já vem preenchido. Pressione Enter para aceitar ou substitua pelo seu país." if pt else "Enter the reflector country.", "Brazil", False)
        if key == "location":
            return ("Cidade e estado/região *" if pt else "City and state/region *", "Exemplo: Santa Isabel - SP" if pt else "Example: Miami - FL", "Santa Isabel - SP" if pt else "Miami - FL", False)
        if key == "ysf_id":
            return ("ID do refletor YSF *" if pt else "YSF reflector ID *", "Use de 1 a 8 números. Exemplo: 12345" if pt else "Use 1 to 8 digits. Example: 12345", "12345", False)
        if key == "admin_slug":
            suggested = f"controle-{rid or '026'}"
            return ("Endereço privado da Administração *" if pt else "Private Admin URL name *", f"Você pode mudar. Será usado como /{suggested}/. Use letras minúsculas, números e hífen." if pt else f"You can change it. It will be used as /{suggested}/. Use lowercase letters, numbers and hyphens.", suggested, False)
        if key == "admin_password":
            return ("Crie a senha da Administração *" if pt else "Create the Admin password *", "Mínimo de 8 caracteres. A senha fica ocultada por segurança; use o botão Mostrar senha se precisar conferir." if pt else "At least 8 characters. The password is hidden for safety; use Show password if you need to check it.", "", True)
        return ("Repita a senha da Administração *" if pt else "Repeat the Admin password *", "Digite exatamente a mesma senha para evitar erro de acesso depois da instalação." if pt else "Type exactly the same password to prevent access errors after installation.", "", True)

    def question_position(self) -> tuple[int, int]:
        if self.question_index < ESSENTIAL_COUNT:
            return self.question_index + 1, ESSENTIAL_COUNT
        return self.question_index - ESSENTIAL_COUNT + 1, len(QUESTION_KEYS) - ESSENTIAL_COUNT

    def show_question(self) -> None:
        self.phase = "questions"
        self.set_pages(question=True)
        self.clear_error()
        step = self.macro_step()
        pos, total = self.question_position()
        pt = self.lang == "pt-BR"
        self.query_one("#step-line", Static).update(f"ETAPA {step} DE 4  •  {self.step_title()}" if pt else f"STEP {step} OF 4  •  {self.step_title()}")
        self.query_one("#guide", Static).update(self.copy["guide"])
        self.query_one("#counter", Static).update(f"PERGUNTA {pos} DE {total}" if pt else f"QUESTION {pos} OF {total}")
        key = self.current_key
        label, help_text, placeholder, is_password = self.question_meta(key)
        self.query_one("#question-label", Label).update(label)
        self.query_one("#question-help", Static).update(help_text)
        answer = self.query_one("#answer", Input)
        answer.placeholder = placeholder
        answer.password = is_password and not self.password_visible
        if key == "admin_slug" and not self.data.get(key):
            rid = str(self.data.get("reflector_id", "026")).lower()
            self.data[key] = f"controle-{rid}"
        answer.value = str(self.data.get(key, ""))
        self.query_one("#password-note", Static).update("Senha ocultada • use Mostrar senha para conferir" if is_password and pt else "Password hidden • use Show password to check it" if is_password else "")
        show_password = self.query_one("#show-password", Button)
        show_password.display = is_password
        show_password.label = self.copy["hide"] if self.password_visible else self.copy["show"]
        self.query_one("#back", Button).display = True
        self.query_one("#back", Button).label = self.copy["back"]
        self.query_one("#next", Button).display = True
        self.query_one("#next", Button).label = self.copy["next"]
        self.query_one("#cancel", Button).display = True
        self.query_one("#cancel", Button).label = self.copy["cancel"]
        self.query_one("#wizard-progress", ProgressBar).update(progress=self.question_index + 1)
        answer.focus()

    def validate_current(self) -> bool:
        key = self.current_key
        answer = self.query_one("#answer", Input)
        raw = answer.value
        value = raw.strip()
        pt = self.lang == "pt-BR"
        if key == "reflector_id":
            value = value.upper()
            if not re.fullmatch(r"[A-Z0-9]{3}", value):
                return self.fail("O ID XLX precisa ter exatamente 3 letras ou números. Ex.: 026, 724 ou PNY." if pt else "The XLX ID must be exactly 3 letters or numbers. Example: 026, 724 or PNY.")
        elif key == "domain":
            value = value.lower()
            if not DOMAIN_RE.fullmatch(value):
                return self.fail("Digite um domínio completo válido. Ex.: xlx026.net" if pt else "Enter a valid full domain. Example: xlx026.net")
        elif key == "callsign":
            value = value.upper()
            if not CALLSIGN_RE.fullmatch(value):
                return self.fail("Indicativo inválido. Use somente letras e números, de 3 a 6 caracteres." if pt else "Invalid callsign. Use only letters and numbers, 3 to 6 characters.")
        elif key == "email":
            value = value.lower()
            if not EMAIL_RE.fullmatch(value):
                return self.fail("Digite um e-mail válido." if pt else "Enter a valid email address.")
        elif key in {"country", "location"}:
            if not value:
                return self.fail("Este campo é obrigatório. Ele não pode ser pulado." if pt else "This field is required and cannot be skipped.")
        elif key == "ysf_id":
            if not re.fullmatch(r"\d{1,8}", value):
                return self.fail("O ID YSF deve ter de 1 a 8 números. Exemplo: 12345" if pt else "The YSF ID must contain 1 to 8 digits. Example: 12345")
        elif key == "admin_slug":
            value = value.lower()
            if not ADMIN_SLUG_RE.fullmatch(value):
                return self.fail("Use de 2 a 32 caracteres: letras minúsculas, números e hífen. Ex.: controle-026" if pt else "Use 2 to 32 characters: lowercase letters, numbers and hyphens. Example: control-026")
        elif key == "admin_password":
            value = raw
            if len(value) < 8:
                return self.fail("A senha precisa ter pelo menos 8 caracteres. A resposta continua neste campo." if pt else "The password must contain at least 8 characters. You are still on this field.")
        elif key == "admin_password_confirm":
            value = raw
            if value != str(self.data.get("admin_password", "")):
                return self.fail("As duas senhas não são iguais. Corrija esta confirmação ou use ← Voltar para alterar a primeira senha." if pt else "The two passwords do not match. Correct this confirmation or use ← Back to change the first password.")
        self.data[key] = value
        if key == "callsign":
            self.data["admin_user"] = value.lower()
        if key == "reflector_id" and not self.data.get("admin_slug"):
            self.data["admin_slug"] = f"controle-{value.lower()}"
        self.clear_error()
        return True

    def validate_generated_values(self) -> bool:
        pt = self.lang == "pt-BR"
        required = ("reflector_id", "domain", "callsign", "email", "country", "location", "ysf_id", "admin_slug", "admin_password")
        if any(not str(self.data.get(key, "")) for key in required):
            return self.fail("Alguma resposta obrigatória ficou vazia. Use ← Voltar para revisar." if pt else "A required answer is empty. Use ← Back to review it.")
        if len(generated_comment(self.data)) > 100:
            self.question_index = 1
            self.show_question()
            return self.fail("O domínio é longo demais para a identificação aceita pelo XLXD. Use um domínio menor." if pt else "The domain is too long for the XLXD identification field. Use a shorter domain.")
        if not udp_port_available(DEFAULT_YSF_PORT):
            self.question_index = 6
            self.show_question()
            return self.fail(f"A porta YSF automática {DEFAULT_YSF_PORT}/UDP já está em uso nesta VPS. A instalação foi bloqueada antes de alterar o servidor." if pt else f"The automatic YSF UDP port {DEFAULT_YSF_PORT} is already in use on this VPS. Installation was blocked before changing the server.")
        return True

    def move_next(self) -> None:
        if not self.validate_current():
            return
        if self.question_index + 1 < len(QUESTION_KEYS):
            self.question_index += 1
            self.password_visible = False
            self.show_question()
            return
        if not self.validate_generated_values():
            return
        self.show_review()

    def move_back(self) -> None:
        if self.phase == "review":
            self.question_index = len(QUESTION_KEYS) - 1
            self.password_visible = False
            self.show_question()
            return
        if self.phase != "questions":
            return
        if self.question_index == 0:
            self.show_language()
            self.query_one("#lang-pt", Button).focus()
            return
        self.question_index -= 1
        self.password_visible = False
        self.show_question()

    def show_review(self) -> None:
        self.phase = "review"
        self.set_pages(review=True)
        self.clear_error()
        pt = self.lang == "pt-BR"
        self.query_one("#step-line", Static).update("ETAPA 3 DE 4  •  Revisão" if pt else "STEP 3 OF 4  •  Review")
        self.query_one("#guide", Static).update("Confira os dados abaixo. Se algo estiver errado, use ← Voltar. Nada será instalado antes de INSTALAR AGORA." if pt else "Check the information below. If anything is wrong, use ← Back. Nothing is installed before INSTALL NOW.")
        self.query_one("#wizard-progress", ProgressBar).update(progress=11)
        admin_user = str(self.data.get("admin_user") or str(self.data.get("callsign", "admin")).lower())
        self.data["admin_user"] = admin_user
        automatic = f"HTTPS • Echo E • módulos A–E • YSF UDP {DEFAULT_YSF_PORT} • {DEFAULT_YSF_FREQ} Hz • auto-link C • fuso {self.data['timezone']}"
        if pt:
            review = (f"[b]Refletor[/b]          XLX{self.data['reflector_id']}\n[b]Domínio[/b]           {self.data['domain']}\n[b]Responsável[/b]       {self.data['callsign']} • {self.data['email']}\n[b]Local[/b]             {self.data['location']} • {self.data['country']}\n[b]YSF ID[/b]            {self.data['ysf_id']}\n[b]Admin usuário[/b]     {admin_user}\n[b]Admin endereço[/b]    /{self.data['admin_slug']}/\n[b]Admin senha[/b]       definida e ocultada\n\n[#73ffac][b]Automático:[/b][/#73ffac] {automatic}\n\n[b]Para corrigir qualquer resposta, pressione ← Voltar. Para iniciar, escolha INSTALAR AGORA.[/b]")
        else:
            review = (f"[b]Reflector[/b]          XLX{self.data['reflector_id']}\n[b]Domain[/b]             {self.data['domain']}\n[b]Sysop[/b]              {self.data['callsign']} • {self.data['email']}\n[b]Location[/b]           {self.data['location']} • {self.data['country']}\n[b]YSF ID[/b]             {self.data['ysf_id']}\n[b]Admin user[/b]         {admin_user}\n[b]Admin address[/b]      /{self.data['admin_slug']}/\n[b]Admin password[/b]     defined and hidden\n\n[#73ffac][b]Automatic:[/b][/#73ffac] {automatic}\n\n[b]To correct any answer, press ← Back. To start, choose INSTALL NOW.[/b]")
        self.query_one("#review", Static).update(review)
        self.query_one("#back", Button).display = True
        self.query_one("#back", Button).label = self.copy["back"]
        self.query_one("#show-password", Button).display = False
        self.query_one("#next", Button).display = True
        self.query_one("#next", Button).label = self.copy["install"]
        self.query_one("#cancel", Button).display = True
        self.query_one("#cancel", Button).label = self.copy["cancel"]
        self.query_one("#next", Button).focus()

    def show_install(self) -> None:
        self.phase = "install"
        self.set_pages(install=True)
        self.clear_error()
        pt = self.lang == "pt-BR"
        self.query_one("#step-line", Static).update("ETAPA 4 DE 4  •  Instalação" if pt else "STEP 4 OF 4  •  Installation")
        self.query_one("#guide", Static).update("Agora é automático. Não feche esta tela. A barra mostra a etapa real executada pelo instalador." if pt else "Everything is automatic now. Do not close this screen. The progress bar follows the real installer stage.")
        self.query_one("#wizard-progress", ProgressBar).update(progress=12)
        self.query_one("#back", Button).display = False
        self.query_one("#show-password", Button).display = False
        self.query_one("#next", Button).display = False
        self.query_one("#cancel", Button).display = False

    @on(Input.Submitted, "#answer")
    def answer_submitted(self, event: Input.Submitted) -> None:
        del event
        if self.phase == "questions" and not self.installing:
            self.move_next()

    @on(Button.Pressed)
    async def handle_button(self, event: Button.Pressed) -> None:
        bid = event.button.id
        if bid == "lang-pt":
            self.set_language("pt-BR")
            return
        if bid == "lang-en":
            self.set_language("en")
            return
        if bid == "back" and not self.installing:
            self.move_back()
            return
        if bid == "show-password" and self.phase == "questions":
            self.password_visible = not self.password_visible
            answer = self.query_one("#answer", Input)
            answer.password = not self.password_visible
            event.button.label = self.copy["hide"] if self.password_visible else self.copy["show"]
            answer.focus()
            return
        if bid == "cancel":
            self.action_request_close()
            return
        if bid != "next" or self.installing:
            return
        if self.phase == "questions":
            self.move_next()
            return
        if self.phase == "review" and self.validate_generated_values():
            await self.run_installation()

    def action_request_close(self) -> None:
        if self.installing:
            self.fail("A instalação está em andamento. Aguarde a conclusão para evitar interrupção." if self.lang == "pt-BR" else "Installation is running. Wait for completion to avoid interruption.")
            return
        write_ui_state("USER_CLOSED")
        self.exit()

    def append_engine_log(self, line: str) -> None:
        if not safe_line(line):
            return
        try:
            ENGINE_LOG.parent.mkdir(parents=True, exist_ok=True)
            with ENGINE_LOG.open("a", encoding="utf-8") as handle:
                handle.write(line + "\n")
            os.chmod(ENGINE_LOG, 0o600)
        except Exception:
            pass

    async def run_installation(self) -> None:
        if not self.validate_generated_values():
            return
        self.installing = True
        self.show_install()
        status = self.query_one("#install-status", Static)
        detail = self.query_one("#install-detail", Static)
        progress = self.query_one("#install-progress", ProgressBar)
        detail.remove_class("failed")
        status.update("Preparando a instalação…" if self.lang == "pt-BR" else "Preparing installation…")
        detail.update("Validando os dados e iniciando o motor de instalação." if self.lang == "pt-BR" else "Validating data and starting the installation engine.")
        self.current_progress = 1
        progress.update(progress=1)
        runtime = Path("/opt/xlx-modern-installer/runtime")
        runtime.mkdir(parents=True, exist_ok=True)
        os.chmod(runtime, 0o700)
        answers_file = runtime / f"simple-answers-{os.getpid()}-{int(time.time())}.txt"
        answers_file.write_text("\n".join(build_answers(self.data)) + "\n", encoding="utf-8")
        os.chmod(answers_file, 0o600)
        env = os.environ.copy()
        env["XLX_MODERN_ANSWERS_FILE"] = str(answers_file)
        cmd = ["bash", str(self.root / "install.sh"), "--tui-child", f"--ui-lang={self.lang}", f"--lang={self.lang}"]
        rc = 1
        try:
            self.proc = await asyncio.create_subprocess_exec(*cmd, cwd=str(self.root), env=env, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT)
            assert self.proc.stdout is not None
            while True:
                raw = await self.proc.stdout.readline()
                if not raw:
                    break
                line = ANSI_RE.sub("", raw.decode("utf-8", errors="replace")).strip()
                if not line:
                    continue
                self.current_progress, stage = progress_from_line(line, self.current_progress, self.lang == "pt-BR")
                progress.update(progress=self.current_progress)
                if stage:
                    status.update(stage)
                if safe_line(line):
                    self.last_lines.append(line[:500])
                    self.append_engine_log(line[:1000])
                    if looks_like_error(line):
                        self.last_errors.append(line[:500])
                    detail.update("\n".join(list(self.last_lines)[-5:]))
            rc = await self.proc.wait()
        except Exception as exc:
            msg = f"{type(exc).__name__}: {exc}"
            self.last_lines.append(msg)
            self.last_errors.append(msg)
            self.append_engine_log(msg)
            rc = 1
        finally:
            self.proc = None
            try:
                answers_file.unlink(missing_ok=True)
            except Exception:
                pass
        self.installing = False
        close = self.query_one("#cancel", Button)
        close.display = True
        close.label = "Fechar" if self.lang == "pt-BR" else "Close"
        close.focus()
        if rc == 0:
            progress.update(progress=100)
            self.current_progress = 100
            status.update("✓ INSTALAÇÃO CONCLUÍDA E VALIDADA" if self.lang == "pt-BR" else "✓ INSTALLATION COMPLETE AND VALIDATED")
            detail.update("Todos os passos terminaram e as validações finais foram aprovadas." if self.lang == "pt-BR" else "All steps finished and the final validations passed.")
            return
        detail.add_class("failed")
        if self.current_progress >= 91:
            status.update("✖ 91% • A VALIDAÇÃO FINAL ENCONTROU UM ERRO" if self.lang == "pt-BR" else "✖ 91% • FINAL VALIDATION FOUND AN ERROR")
        else:
            status.update(f"✖ PAROU COM SEGURANÇA EM {self.current_progress}%" if self.lang == "pt-BR" else f"✖ STOPPED SAFELY AT {self.current_progress}%")
        lines = list(self.last_errors) or list(self.last_lines)[-8:]
        cause = "\n".join(lines[-8:]) if lines else ("Nenhum detalhe adicional foi emitido pelo motor." if self.lang == "pt-BR" else "No additional detail was emitted by the engine.")
        if self.lang == "pt-BR":
            detail.update(f"A instalação NÃO foi marcada como concluída.\n\nCausa registrada pelo motor:\n{cause}\n\nLog técnico salvo em: {ENGINE_LOG}")
            self.fail("A tela não está travada: o motor encerrou com erro. O motivo real está mostrado acima e foi salvo no log.")
        else:
            detail.update(f"The installation was NOT marked complete.\n\nCause reported by the engine:\n{cause}\n\nTechnical log saved at: {ENGINE_LOG}")
            self.fail("The screen is not frozen: the engine exited with an error. The real cause is shown above and saved in the log.")


def self_test() -> int:
    sample = {"reflector_id": "PNY", "domain": "xlx026.net", "email": "sysop@example.net", "callsign": "PU2PNY", "country": "Brazil", "timezone": "America/Sao_Paulo", "location": "Santa Isabel - SP", "ysf_id": "12345", "admin_user": "pu2pny", "admin_slug": "controle-pny", "admin_password": "ExampleOnly-123!"}
    answers = build_answers(sample)
    assert len(answers) == 24
    assert answers[0] == "PNY"
    assert answers[2] == "sysop@example.net"
    assert answers[3] == "PU2PNY"
    assert answers[18] == "12345"
    assert answers[19] == "pu2pny"
    assert answers[20] == "controle-pny"
    assert answers[-1] == ""
    assert len(generated_comment(sample)) <= 100
    p, label = progress_from_line("POST-INSTALLATION VALIDATION", 80, True)
    assert p == 91 and label == "Validando tudo antes de concluir"
    assert ADMIN_SLUG_RE.fullmatch("controle-pny")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--self-test", action="store_true")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    if args.self_test:
        raise SystemExit(self_test())
    SimpleInstaller(args.root.resolve()).run()
