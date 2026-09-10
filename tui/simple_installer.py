#!/usr/bin/env python3
from __future__ import annotations

import argparse
import asyncio
import os
import re
import subprocess
import time
from collections import deque
from pathlib import Path
from typing import Any

from textual import on
from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical, VerticalScroll
from textual.widgets import Button, Input, Label, ProgressBar, Static

DOMAIN_RE = re.compile(r"^([a-z0-9-]+\.)+[a-z]{2,}$")
EMAIL_RE = re.compile(r"^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$")
CALLSIGN_RE = re.compile(r"^[A-Z0-9]{3,6}$")
ANSI_RE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")

DEFAULT_MODULES = 5
DEFAULT_YSF_PORT = 42000
DEFAULT_YSF_FREQ = 433125000
DEFAULT_AUTOLINK_MODULE = "C"


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


def build_answers(data: dict[str, Any]) -> list[str]:
    rid = data["reflector_id"]
    callsign = data["callsign"]
    domain = data["domain"]
    comment = f"XLX{rid} by {callsign} - {domain}"
    header = f"XLX{rid} • {callsign}"
    return [
        rid,
        domain,
        data["email"],
        callsign,
        data["country"],
        data["timezone"],
        "Y",
        comment,
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
        (("VALIDAÇÃO PÓS-INSTALAÇÃO", "POST-INSTALLATION VALIDATION"), 91, "Executando verificações finais" if pt else "Running final checks"),
        (("INSTALAÇÃO CONCLUÍDA", "INSTALLATION COMPLETE"), 100, "Concluído" if pt else "Complete"),
    ]
    for needles, value, label in stages:
        if any(needle in upper for needle in needles):
            return max(current, value), label
    return current, None


def safe_line(line: str) -> bool:
    upper = line.upper()
    return not any(token in upper for token in ("PASSWORD", "SENHA", "CONTROL_PASSWORD", "XLX_CONTROL_PASSWORD"))


PT = {
    "subtitle": "INSTALAÇÃO SIMPLES • SEGURA • GUIADA",
    "steps": ["Dados essenciais", "Acesso privado", "Revisão", "Instalação"],
    "guide": "Digite no campo destacado e pressione Enter. O cursor vai sozinho para a próxima resposta. Configurações técnicas recomendadas são automáticas.",
    "back": "← Voltar",
    "next": "Continuar →",
    "cancel": "Cancelar",
    "install": "INSTALAR AGORA",
}
EN = {
    "subtitle": "SIMPLE • SAFE • GUIDED INSTALLATION",
    "steps": ["Essential data", "Private access", "Review", "Installation"],
    "guide": "Type in the highlighted field and press Enter. The cursor moves to the next answer automatically. Recommended technical settings are automatic.",
    "back": "← Back",
    "next": "Continue →",
    "cancel": "Cancel",
    "install": "INSTALL NOW",
}


class SimpleInstaller(App):
    TITLE = "XLX Modern Installer — PU2PNY"
    BINDINGS = [("ctrl+c", "request_close", "Sair / Exit")]

    CSS = """
    Screen {
        background: #02070c;
        color: #ffffff;
    }
    #brand {
        height: 5;
        padding: 1 3;
        background: #07131d;
        color: #ffffff;
        border-bottom: solid #2aa8ff;
        text-style: bold;
    }
    #wrap {
        width: 94%;
        max-width: 118;
        height: 1fr;
        align-horizontal: center;
        padding: 1 0;
    }
    #step-line {
        height: 2;
        color: #ffffff;
        text-style: bold;
    }
    #wizard-progress {
        height: 3;
        margin-bottom: 1;
    }
    #guide {
        min-height: 4;
        height: auto;
        padding: 1 2;
        margin-bottom: 1;
        background: #0b2233;
        color: #ffffff;
        border: round #2f82b8;
    }
    #card {
        height: 1fr;
        padding: 1 3;
        background: #07131d;
        border: round #39799f;
    }
    .page {
        width: 1fr;
        height: auto;
    }
    .heading {
        margin-bottom: 1;
        color: #ffffff;
        text-style: bold;
    }
    .label {
        margin-top: 1;
        color: #ffffff;
        text-style: bold;
    }
    .help {
        height: auto;
        color: #d8e8f2;
        margin-bottom: 0;
    }
    Input {
        width: 1fr;
        height: 3;
        margin-bottom: 1;
        background: #01060a;
        color: #ffffff;
        border: round #658ba4;
    }
    Input:focus {
        background: #061a27;
        color: #ffffff;
        border: heavy #ffffff;
    }
    #lang-actions {
        height: auto;
        align: center middle;
        margin-top: 2;
    }
    #lang-actions Button {
        min-width: 28;
        height: 4;
        margin: 1 2;
        background: #123a56;
        color: #ffffff;
        border: round #76bce8;
        text-style: bold;
    }
    #lang-actions Button:focus {
        background: #0b5a8f;
        color: #ffffff;
        border: heavy #ffffff;
    }
    #auto-box {
        min-height: 7;
        height: auto;
        padding: 1 2;
        margin: 1 0;
        background: #0b2618;
        color: #ffffff;
        border: round #2f9c5b;
    }
    #review {
        height: auto;
        color: #ffffff;
        padding: 1 2;
    }
    #install-status {
        height: 4;
        content-align: center middle;
        color: #ffffff;
        text-style: bold;
    }
    #install-progress {
        height: 4;
        margin: 2 0;
    }
    #install-detail {
        min-height: 5;
        height: auto;
        padding: 1 2;
        background: #01060a;
        color: #e8f4fb;
        border: round #456b84;
    }
    #error {
        min-height: 3;
        height: auto;
        padding: 1 2;
        margin-top: 1;
        background: #661824;
        color: #ffffff;
        border: round #ff8995;
        text-style: bold;
        display: none;
    }
    #hint {
        height: 2;
        color: #ffffff;
    }
    #nav {
        height: 5;
        align: right middle;
    }
    #nav Button {
        min-width: 19;
        height: 4;
        margin-left: 1;
        color: #ffffff;
        text-style: bold;
    }
    #back {
        background: #263845;
        border: round #8fa7b8;
    }
    #next {
        background: #116b39;
        border: round #70d39a;
    }
    #cancel {
        background: #7a1d28;
        border: round #ff8995;
    }
    #back:focus, #next:focus, #cancel:focus {
        color: #ffffff;
        border: heavy #ffffff;
    }
    #footer {
        height: 2;
        content-align: center middle;
        color: #d8e8f2;
    }
    """

    INPUT_ORDER = {
        1: ["reflector_id", "domain", "callsign", "email", "country", "location", "ysf_id"],
        2: ["admin_password", "admin_password_confirm"],
    }

    def __init__(self, root: Path):
        super().__init__()
        self.root = root
        self.lang = "pt-BR"
        self.step = 0
        self.installing = False
        self.data: dict[str, Any] = {"timezone": detected_timezone()}
        self.proc: asyncio.subprocess.Process | None = None
        self.last_lines: deque[str] = deque(maxlen=8)

    @property
    def copy(self) -> dict[str, Any]:
        return PT if self.lang == "pt-BR" else EN

    def compose(self) -> ComposeResult:
        yield Static("[b]XLX MODERN INSTALLER[/b]  •  [#70d39a]PU2PNY[/#70d39a]\nINSTALAÇÃO GUIADA", id="brand", markup=True)
        with Vertical(id="wrap"):
            yield Static("", id="step-line")
            yield ProgressBar(total=4, show_percentage=False, show_eta=False, id="wizard-progress")
            yield Static("", id="guide")
            with VerticalScroll(id="card"):
                with Vertical(id="page-0", classes="page"):
                    yield Static("Escolha o idioma / Choose language", classes="heading")
                    yield Static("Use as setas ou o mouse e pressione Enter.", classes="help")
                    with Horizontal(id="lang-actions"):
                        yield Button("Português (Brasil)", id="lang-pt")
                        yield Button("English", id="lang-en")

                with Vertical(id="page-1", classes="page"):
                    yield Static("Dados essenciais", id="heading-1", classes="heading")
                    yield Label("ID do refletor XLX *", id="label-reflector_id", classes="label")
                    yield Static("3 caracteres. Exemplo válido: 026 ou PNY.", id="help-reflector_id", classes="help")
                    yield Input(placeholder="026", id="reflector_id", max_length=3)
                    yield Label("Domínio completo *", id="label-domain", classes="label")
                    yield Static("Ex.: xlx026.net", id="help-domain", classes="help")
                    yield Input(placeholder="xlx026.net", id="domain")
                    yield Label("Indicativo do sysop *", id="label-callsign", classes="label")
                    yield Static("Ex.: PU2PNY", id="help-callsign", classes="help")
                    yield Input(placeholder="PU2PNY", id="callsign", max_length=6)
                    yield Label("E-mail do sysop *", id="label-email", classes="label")
                    yield Static("Ex.: contato@seudominio.net", id="help-email", classes="help")
                    yield Input(placeholder="contato@seudominio.net", id="email")
                    yield Label("País *", id="label-country", classes="label")
                    yield Static("Ex.: Brazil", id="help-country", classes="help")
                    yield Input(value="Brazil", id="country")
                    yield Label("Cidade / estado ou região *", id="label-location", classes="label")
                    yield Static("Ex.: Santa Isabel - SP", id="help-location", classes="help")
                    yield Input(placeholder="Santa Isabel - SP", id="location")
                    yield Label("ID do refletor YSF *", id="label-ysf_id", classes="label")
                    yield Static("Exemplo: 12345", id="help-ysf_id", classes="help")
                    yield Input(placeholder="12345", id="ysf_id", max_length=8)

                with Vertical(id="page-2", classes="page"):
                    yield Static("Acesso privado", id="heading-2", classes="heading")
                    yield Static("O usuário e o endereço privado do Admin serão criados automaticamente. Você só precisa definir a senha.", id="admin-guide", classes="help")
                    yield Label("Senha do Admin *", id="label-password", classes="label")
                    yield Static("Mínimo de 8 caracteres.", id="help-password", classes="help")
                    yield Input(password=True, id="admin_password")
                    yield Label("Repita a senha *", id="label-password2", classes="label")
                    yield Static("Digite exatamente a mesma senha.", id="help-password2", classes="help")
                    yield Input(password=True, id="admin_password_confirm")
                    yield Static("", id="auto-box", markup=True)

                with Vertical(id="page-3", classes="page"):
                    yield Static("Revisão", id="heading-3", classes="heading")
                    yield Static("", id="review", markup=True)

                with Vertical(id="page-4", classes="page"):
                    yield Static("Instalação", id="heading-4", classes="heading")
                    yield Static("Preparando…", id="install-status")
                    yield ProgressBar(total=100, show_percentage=True, show_eta=False, id="install-progress")
                    yield Static("Aguardando início.", id="install-detail")

            yield Static("", id="error")
            yield Static("Enter = próxima resposta • Tab também funciona • * = obrigatório", id="hint")
            with Horizontal(id="nav"):
                yield Button("← Voltar", id="back")
                yield Button("Continuar →", id="next")
                yield Button("Cancelar", id="cancel")
        yield Static("XLX Modern Installer • PU2PNY", id="footer")

    def on_mount(self) -> None:
        self.show_step(0)
        self.query_one("#lang-pt", Button).focus()

    def show_step(self, step: int) -> None:
        self.step = max(0, min(4, step))
        for page in self.query(".page"):
            page.display = page.id == f"page-{self.step}"
        back = self.query_one("#back", Button)
        nxt = self.query_one("#next", Button)
        cancel = self.query_one("#cancel", Button)
        if self.step == 0:
            self.query_one("#step-line", Static).update("IDIOMA / LANGUAGE")
            self.query_one("#guide", Static).update("Escolha Português ou English. Depois disso o assistente guia tudo passo a passo.")
            self.query_one("#wizard-progress", ProgressBar).update(progress=0)
            back.display = False
            nxt.display = False
            cancel.display = True
            return
        names = self.copy["steps"]
        self.query_one("#step-line", Static).update(f"ETAPA {self.step} DE 4  •  {names[self.step-1]}" if self.lang == "pt-BR" else f"STEP {self.step} OF 4  •  {names[self.step-1]}")
        self.query_one("#guide", Static).update(self.copy["guide"] if self.step < 3 else ("Confira os dados. Nada será instalado antes de INSTALAR AGORA." if self.lang == "pt-BR" and self.step == 3 else "Check the information. Nothing is installed before INSTALL NOW." if self.step == 3 else "A instalação está automática. Aguarde a conclusão." if self.lang == "pt-BR" else "Installation is automatic. Wait for completion."))
        self.query_one("#wizard-progress", ProgressBar).update(progress=self.step)
        back.display = self.step in {2, 3} and not self.installing
        back.label = self.copy["back"]
        nxt.display = self.step in {1, 2, 3} and not self.installing
        nxt.label = self.copy["install"] if self.step == 3 else self.copy["next"]
        cancel.display = self.step < 4 and not self.installing
        cancel.label = self.copy["cancel"]
        self.clear_error()
        if self.step == 1:
            self.query_one("#reflector_id", Input).focus()
        elif self.step == 2:
            self.prepare_auto_values()
            self.query_one("#admin_password", Input).focus()
        elif self.step == 3:
            self.prepare_review()
            nxt.focus()

    def set_language(self, lang: str) -> None:
        self.lang = "en" if lang == "en" else "pt-BR"
        if self.lang == "en":
            self.query_one("#country", Input).value = ""
            self.query_one("#heading-1", Static).update("Essential data")
            self.query_one("#heading-2", Static).update("Private access")
            self.query_one("#heading-3", Static).update("Review")
            self.query_one("#heading-4", Static).update("Installation")
            labels = {
                "#label-reflector_id": "XLX reflector ID *", "#help-reflector_id": "3 characters. Valid example: 026 or PNY.",
                "#label-domain": "Full domain *", "#help-domain": "Example: xlx026.net",
                "#label-callsign": "Sysop callsign *", "#help-callsign": "Example: PU2PNY",
                "#label-email": "Sysop email *", "#help-email": "Example: contact@yourdomain.net",
                "#label-country": "Country *", "#help-country": "Example: Brazil",
                "#label-location": "City / state or region *", "#help-location": "Example: Miami - FL",
                "#label-ysf_id": "YSF reflector ID *", "#help-ysf_id": "Example: 12345",
                "#admin-guide": "The Admin username and private address are created automatically. You only need to set the password.",
                "#label-password": "Admin password *", "#help-password": "At least 8 characters.",
                "#label-password2": "Repeat the password *", "#help-password2": "Type exactly the same password.",
                "#hint": "Enter = next answer • Tab also works • * = required",
            }
            for selector, value in labels.items():
                self.query_one(selector).update(value)
        self.show_step(1)

    def value(self, field_id: str) -> str:
        return self.query_one(f"#{field_id}", Input).value.strip()

    def clear_error(self) -> None:
        error = self.query_one("#error", Static)
        error.update("")
        error.display = False

    def fail(self, message: str, field_id: str | None = None) -> bool:
        error = self.query_one("#error", Static)
        error.update(message)
        error.display = True
        if field_id:
            self.query_one(f"#{field_id}", Input).focus()
        return False

    def validate_field(self, field_id: str) -> bool:
        pt = self.lang == "pt-BR"
        value = self.value(field_id)
        if field_id == "reflector_id":
            if not re.fullmatch(r"[A-Z0-9]{3}", value.upper()):
                return self.fail("Use exatamente 3 letras ou números. Ex.: 026 ou PNY." if pt else "Use exactly 3 letters or numbers. Example: 026 or PNY.", field_id)
        elif field_id == "domain":
            if not DOMAIN_RE.fullmatch(value.lower()):
                return self.fail("Informe um domínio completo válido. Ex.: xlx026.net." if pt else "Enter a valid full domain. Example: xlx026.net.", field_id)
        elif field_id == "callsign":
            if not CALLSIGN_RE.fullmatch(value.upper()):
                return self.fail("Indicativo inválido. Use de 3 a 6 letras/números." if pt else "Invalid callsign. Use 3 to 6 letters/numbers.", field_id)
        elif field_id == "email":
            if not EMAIL_RE.fullmatch(value.lower()):
                return self.fail("Informe um e-mail válido." if pt else "Enter a valid email.", field_id)
        elif field_id in {"country", "location"}:
            if not value:
                return self.fail("Este campo é obrigatório." if pt else "This field is required.", field_id)
        elif field_id == "ysf_id":
            if not re.fullmatch(r"\d{1,8}", value):
                return self.fail("Use de 1 a 8 dígitos. Exemplo: 12345." if pt else "Use 1 to 8 digits. Example: 12345.", field_id)
        elif field_id == "admin_password":
            if len(self.query_one("#admin_password", Input).value) < 8:
                return self.fail("A senha precisa ter pelo menos 8 caracteres." if pt else "The password must contain at least 8 characters.", field_id)
        elif field_id == "admin_password_confirm":
            if self.query_one("#admin_password", Input).value != self.query_one("#admin_password_confirm", Input).value:
                return self.fail("As duas senhas não são iguais." if pt else "The two passwords do not match.", field_id)
        self.clear_error()
        return True

    def validate_step(self, step: int) -> bool:
        for field_id in self.INPUT_ORDER.get(step, []):
            if not self.validate_field(field_id):
                return False
        if step == 1:
            self.data.update(
                reflector_id=self.value("reflector_id").upper(),
                domain=self.value("domain").lower(),
                callsign=self.value("callsign").upper(),
                email=self.value("email").lower(),
                country=self.value("country"),
                location=self.value("location"),
                ysf_id=self.value("ysf_id"),
            )
        if step == 2:
            self.prepare_auto_values()
            self.data["admin_password"] = self.query_one("#admin_password", Input).value
        return True

    def prepare_auto_values(self) -> None:
        rid = self.value("reflector_id").lower()
        callsign = self.value("callsign").lower()
        self.data["admin_user"] = callsign
        self.data["admin_slug"] = f"controle-{rid}"
        self.data["dashboard_lang"] = self.lang
        pt = self.lang == "pt-BR"
        text = (
            f"[b]Configuração automática recomendada[/b]\n"
            f"• HTTPS: Sim\n• Echo Test: módulo E\n• Módulos: A–E\n"
            f"• YSF: UDP {DEFAULT_YSF_PORT} • {DEFAULT_YSF_FREQ} Hz • Auto-link C\n"
            f"• Admin: {self.data['admin_user']} • /{self.data['admin_slug']}/\n"
            f"• Fuso detectado: {self.data['timezone']}"
        ) if pt else (
            f"[b]Recommended automatic configuration[/b]\n"
            f"• HTTPS: Yes\n• Echo Test: module E\n• Modules: A–E\n"
            f"• YSF: UDP {DEFAULT_YSF_PORT} • {DEFAULT_YSF_FREQ} Hz • Auto-link C\n"
            f"• Admin: {self.data['admin_user']} • /{self.data['admin_slug']}/\n"
            f"• Detected timezone: {self.data['timezone']}"
        )
        self.query_one("#auto-box", Static).update(text)

    def prepare_review(self) -> None:
        self.prepare_auto_values()
        pt = self.lang == "pt-BR"
        review = (
            f"[b]Refletor[/b]  XLX{self.data['reflector_id']}\n"
            f"[b]Domínio[/b]  {self.data['domain']}\n"
            f"[b]Sysop[/b]  {self.data['callsign']} • {self.data['email']}\n"
            f"[b]Local[/b]  {self.data['location']} • {self.data['country']}\n"
            f"[b]Fuso[/b]  {self.data['timezone']}\n"
            f"[b]YSF ID[/b]  {self.data['ysf_id']}\n"
            f"[b]Admin[/b]  {self.data['admin_user']} • /{self.data['admin_slug']}/\n"
            f"[b]Senha[/b]  ••••••••\n\n"
            f"[#70d39a][b]Automático:[/b][/#70d39a] HTTPS • Echo E • 5 módulos • YSF {DEFAULT_YSF_PORT} • Auto-link C • painel em Português\n\n"
            "[b]Nada foi instalado ainda. Pressione INSTALAR AGORA para começar.[/b]"
        ) if pt else (
            f"[b]Reflector[/b]  XLX{self.data['reflector_id']}\n"
            f"[b]Domain[/b]  {self.data['domain']}\n"
            f"[b]Sysop[/b]  {self.data['callsign']} • {self.data['email']}\n"
            f"[b]Location[/b]  {self.data['location']} • {self.data['country']}\n"
            f"[b]Timezone[/b]  {self.data['timezone']}\n"
            f"[b]YSF ID[/b]  {self.data['ysf_id']}\n"
            f"[b]Admin[/b]  {self.data['admin_user']} • /{self.data['admin_slug']}/\n"
            f"[b]Password[/b]  ••••••••\n\n"
            f"[#70d39a][b]Automatic:[/b][/#70d39a] HTTPS • Echo E • 5 modules • YSF {DEFAULT_YSF_PORT} • Auto-link C • dashboard in English\n\n"
            "[b]Nothing has been installed yet. Press INSTALL NOW to start.[/b]"
        )
        self.query_one("#review", Static).update(review)

    @on(Input.Submitted)
    def advance_on_enter(self, event: Input.Submitted) -> None:
        order = self.INPUT_ORDER.get(self.step, [])
        field_id = event.input.id
        if not field_id or field_id not in order:
            return
        if not self.validate_field(field_id):
            return
        idx = order.index(field_id)
        if idx + 1 < len(order):
            self.query_one(f"#{order[idx + 1]}", Input).focus()
        else:
            self.query_one("#next", Button).focus()

    @on(Button.Pressed)
    async def handle_button(self, event: Button.Pressed) -> None:
        bid = event.button.id
        if bid == "lang-pt":
            self.set_language("pt-BR")
            return
        if bid == "lang-en":
            self.set_language("en")
            return
        if bid == "cancel":
            self.action_request_close()
            return
        if bid == "back" and not self.installing:
            self.show_step(self.step - 1)
            return
        if bid != "next" or self.installing:
            return
        if self.step in {1, 2}:
            if self.validate_step(self.step):
                self.show_step(self.step + 1)
            return
        if self.step == 3:
            await self.run_installation()

    def action_request_close(self) -> None:
        if self.installing:
            self.fail("A instalação está em andamento e continuará protegida nesta sessão." if self.lang == "pt-BR" else "Installation is running and remains protected in this session.")
            return
        self.exit()

    async def run_installation(self) -> None:
        if not self.validate_step(1) or not self.validate_step(2):
            return
        self.installing = True
        self.show_step(4)
        status = self.query_one("#install-status", Static)
        detail = self.query_one("#install-detail", Static)
        progress = self.query_one("#install-progress", ProgressBar)
        status.update("Preparando a instalação…" if self.lang == "pt-BR" else "Preparing installation…")
        progress.update(progress=1)

        runtime = Path("/opt/xlx-modern-installer/runtime")
        runtime.mkdir(parents=True, exist_ok=True)
        os.chmod(runtime, 0o700)
        answers_file = runtime / f"simple-answers-{os.getpid()}-{int(time.time())}.txt"
        answers_file.write_text("\n".join(build_answers(self.data)) + "\n", encoding="utf-8")
        os.chmod(answers_file, 0o600)
        env = os.environ.copy()
        env["XLX_MODERN_ANSWERS_FILE"] = str(answers_file)
        cmd = ["bash", str(self.root / "install.sh"), "--tui-child", f"--ui-lang={self.lang}", f"--lang={self.data['dashboard_lang']}"]
        rc = 1
        try:
            self.proc = await asyncio.create_subprocess_exec(
                *cmd,
                cwd=str(self.root),
                env=env,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
            )
            assert self.proc.stdout is not None
            current = 1
            while True:
                raw = await self.proc.stdout.readline()
                if not raw:
                    break
                line = ANSI_RE.sub("", raw.decode("utf-8", errors="replace")).strip()
                if not line:
                    continue
                current, stage = progress_from_line(line, current, self.lang == "pt-BR")
                progress.update(progress=current)
                if stage:
                    status.update(stage)
                if safe_line(line):
                    self.last_lines.append(line[:400])
                    detail.update("\n".join(self.last_lines))
            rc = await self.proc.wait()
        except Exception as exc:
            self.last_lines.append(f"{type(exc).__name__}")
            rc = 1
        finally:
            self.proc = None
            try:
                answers_file.unlink(missing_ok=True)
            except Exception:
                pass

        self.installing = False
        if rc == 0:
            progress.update(progress=100)
            status.update("✓ INSTALAÇÃO CONCLUÍDA" if self.lang == "pt-BR" else "✓ INSTALLATION COMPLETE")
            detail.update("Painel, serviços e validações finais concluídos. A instalação está pronta." if self.lang == "pt-BR" else "Dashboard, services and final checks completed. Installation is ready.")
            self.query_one("#cancel", Button).display = True
            self.query_one("#cancel", Button).label = "Fechar" if self.lang == "pt-BR" else "Close"
        else:
            status.update("✖ INSTALAÇÃO NÃO CONCLUÍDA" if self.lang == "pt-BR" else "✖ INSTALLATION NOT COMPLETE")
            self.fail("A instalação parou com segurança. Nenhuma conclusão foi exibida porque as validações finais não passaram." if self.lang == "pt-BR" else "Installation stopped safely. No completion was shown because final checks did not pass.")
            self.query_one("#cancel", Button).display = True
            self.query_one("#cancel", Button).label = "Fechar" if self.lang == "pt-BR" else "Close"


def self_test() -> int:
    sample = {
        "reflector_id": "PNY",
        "domain": "xlx026.net",
        "email": "sysop@example.net",
        "callsign": "PU2PNY",
        "country": "Brazil",
        "timezone": "America/Sao_Paulo",
        "location": "Santa Isabel - SP",
        "ysf_id": "12345",
        "admin_user": "pu2pny",
        "admin_slug": "controle-pny",
        "admin_password": "ExampleOnly-123!",
        "dashboard_lang": "pt-BR",
    }
    answers = build_answers(sample)
    assert len(answers) == 24
    assert answers[0] == "PNY"
    assert answers[18] == "12345"
    assert answers[19] == "pu2pny"
    assert answers[-1] == ""
    p, label = progress_from_line("INSTALLING XLX MODERN DASHBOARD", 1, True)
    assert p == 68 and label == "Instalando o painel"
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
