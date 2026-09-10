#!/usr/bin/env python3
from __future__ import annotations

import argparse
import asyncio
import os
import re
import subprocess
from collections import deque
from pathlib import Path
from typing import Any

from textual import on
from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical, VerticalScroll
from textual.widgets import Button, Input, Label, ProgressBar, Select, Static

TEXTUAL_PIN = "8.2.8"
ANSI_RE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
DOMAIN_RE = re.compile(r"^([a-z0-9-]+\.)+[a-z]{2,}$")
EMAIL_RE = re.compile(r"^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$")
CALLSIGN_RE = re.compile(r"^[A-Z0-9]{3,6}$")
ADMIN_USER_RE = re.compile(r"^[A-Za-z0-9._-]{3,64}$")
ADMIN_SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9-]{1,31}$")

YES_NO_PT = [("Sim — recomendado", "yes"), ("Não", "no")]
YES_NO_EN = [("Yes — recommended", "yes"), ("No", "no")]
DASHBOARD_LANGUAGES = [
    ("Português (Brasil)", "pt-BR"),
    ("English", "en"),
    ("Español", "es"),
    ("Français", "fr"),
    ("Deutsch", "de"),
    ("Italiano", "it"),
]

TEXT = {
    "pt-BR": {
        "subtitle": "REFLETOR + PAINEL • INSTALAÇÃO GUIADA",
        "cancel": "Cancelar",
        "close": "Fechar",
        "back": "← Voltar",
        "next": "Continuar →",
        "install": "INSTALAR AGORA",
        "installing": "Instalando...",
        "steps": [
            "Idioma",
            "Identidade",
            "Localização",
            "Opções",
            "Rede / YSF",
            "Administração",
            "Revisão",
            "Instalação",
        ],
        "guides": [
            "Escolha o idioma. Você pode usar o mouse ou as setas do teclado. Pressione Enter na opção desejada.",
            "Comece no primeiro campo. Digite a resposta e pressione Enter: o cursor vai automaticamente para a próxima resposta.",
            "Informe onde o refletor ficará. Os valores detectados ou recomendados já aparecem preenchidos quando possível.",
            "As opções recomendadas já estão selecionadas. Se não tiver uma necessidade específica, mantenha os valores sugeridos.",
            "Os valores técnicos recomendados já estão preenchidos. Normalmente você só precisa informar o ID do refletor YSF.",
            "Crie o acesso privado do administrador. A senha não será exibida na revisão e o endereço do Admin pode ser alterado.",
            "Confira o resumo. Nada será instalado até você selecionar INSTALAR AGORA.",
            "A instalação está sendo executada. Não feche esta sessão SSH até a conclusão.",
        ],
        "step_fmt": "ETAPA {current} DE {total}  •  {name}",
        "lang_title": "Escolha o idioma da instalação",
        "lang_help": "Esta escolha altera os textos do instalador. O idioma do painel poderá ser escolhido depois.",
        "identity_title": "Dados principais do refletor",
        "location_title": "Localização do servidor",
        "options_title": "Opções recomendadas",
        "ysf_title": "Rede e YSF",
        "admin_title": "Acesso administrativo privado",
        "review_title": "Tudo pronto para revisar",
        "install_title": "Instalando XLX Modern",
        "rid": "ID do refletor *",
        "rid_help": "3 caracteres. Ex.: PNY, 026 ou 724",
        "domain": "Domínio completo (FQDN) *",
        "domain_help": "Ex.: xlx026.net",
        "callsign": "Indicativo do sysop *",
        "callsign_help": "Ex.: PU2PNY",
        "email": "E-mail do sysop *",
        "email_help": "Ex.: contato@seudominio.net",
        "country": "País *",
        "country_help": "Ex.: Brazil",
        "location": "Cidade / estado ou região *",
        "location_help": "Ex.: Santa Isabel - SP",
        "timezone": "Fuso horário *",
        "timezone_help": "Detectado automaticamente; altere apenas se estiver incorreto.",
        "https": "Ativar HTTPS",
        "https_help": "Recomendado. Se o certificado não puder ser emitido agora, a instalação preserva o painel em HTTP e agenda nova tentativa.",
        "echo": "Instalar Echo Test no módulo E",
        "echo_help": "Recomendado para testar áudio do refletor.",
        "modules": "Quantidade de módulos ativos",
        "modules_help": "Recomendado: 5 módulos (A–E). Com Echo no módulo E, use no mínimo 5.",
        "ysf_port": "Porta UDP YSF",
        "ysf_port_help": "Recomendado: 42000. Normalmente não altere.",
        "ysf_freq": "Frequência YSF Wires-X (Hz)",
        "ysf_freq_help": "Recomendado: 433125000. Use exatamente 9 dígitos.",
        "autolink": "Auto-link YSF",
        "autolink_help": "Recomendado: ativado.",
        "autolink_module": "Módulo do Auto-link YSF",
        "autolink_module_help": "Recomendado: C.",
        "ysf_id": "ID do refletor YSF *",
        "ysf_id_help": "Informe de 1 a 8 dígitos.",
        "admin_user": "Usuário do Admin *",
        "admin_user_help": "Será sugerido a partir do indicativo. Você pode alterar.",
        "admin_slug": "Endereço privado do Admin *",
        "admin_slug_help": "Parte da URL depois do domínio. Ex.: controle-pny. Pode ser alterada.",
        "password": "Senha do Admin *",
        "password_help": "Mínimo de 8 caracteres.",
        "password2": "Repita a senha *",
        "dashboard_lang": "Idioma do painel",
        "dashboard_lang_help": "Escolha como o painel público será exibido.",
        "review_ok": "Se os dados estiverem corretos, selecione INSTALAR AGORA.",
        "status_prepare": "Preparando a instalação...",
        "status_running": "Instalando. Não feche esta sessão SSH.",
        "status_done": "✓ Instalação concluída e validações finais executadas.",
        "status_fail": "✖ A instalação terminou com erro (código {rc}).",
        "tech_log": "O log técnico continua sendo salvo automaticamente no servidor.",
        "enter_hint": "Dica: Enter passa para a próxima resposta • Tab também funciona • Campos com * são obrigatórios",
    },
    "en": {
        "subtitle": "REFLECTOR + DASHBOARD • GUIDED INSTALLATION",
        "cancel": "Cancel",
        "close": "Close",
        "back": "← Back",
        "next": "Continue →",
        "install": "INSTALL NOW",
        "installing": "Installing...",
        "steps": [
            "Language",
            "Identity",
            "Location",
            "Options",
            "Network / YSF",
            "Administration",
            "Review",
            "Installation",
        ],
        "guides": [
            "Choose the installer language. Use the mouse or arrow keys, then press Enter on your choice.",
            "Start with the first field. Type your answer and press Enter: the cursor automatically moves to the next answer.",
            "Tell us where the reflector will run. Detected or recommended values are already filled when possible.",
            "Recommended options are already selected. Keep them unless you have a specific reason to change them.",
            "Recommended technical values are already filled. Normally you only need to enter the YSF reflector ID.",
            "Create the private administrator access. The password is hidden from review and the Admin URL can be changed.",
            "Check the summary. Nothing is installed until you select INSTALL NOW.",
            "Installation is running. Do not close this SSH session until it finishes.",
        ],
        "step_fmt": "STEP {current} OF {total}  •  {name}",
        "lang_title": "Choose the installer language",
        "lang_help": "This changes the installer text. You can choose the public dashboard language later.",
        "identity_title": "Main reflector information",
        "location_title": "Server location",
        "options_title": "Recommended options",
        "ysf_title": "Network and YSF",
        "admin_title": "Private administration access",
        "review_title": "Ready to review",
        "install_title": "Installing XLX Modern",
        "rid": "Reflector ID *",
        "rid_help": "3 characters. Example: PNY, 026 or 724",
        "domain": "Full domain (FQDN) *",
        "domain_help": "Example: xlx026.net",
        "callsign": "Sysop callsign *",
        "callsign_help": "Example: PU2PNY",
        "email": "Sysop email *",
        "email_help": "Example: contact@yourdomain.net",
        "country": "Country *",
        "country_help": "Example: Brazil",
        "location": "City / state or region *",
        "location_help": "Example: Santa Isabel - SP",
        "timezone": "Timezone *",
        "timezone_help": "Detected automatically; change it only if it is wrong.",
        "https": "Enable HTTPS",
        "https_help": "Recommended. If a certificate cannot be issued now, the installer preserves HTTP access and schedules a retry.",
        "echo": "Install Echo Test on module E",
        "echo_help": "Recommended for reflector audio testing.",
        "modules": "Number of active modules",
        "modules_help": "Recommended: 5 modules (A–E). With Echo on module E, use at least 5.",
        "ysf_port": "YSF UDP port",
        "ysf_port_help": "Recommended: 42000. Normally do not change it.",
        "ysf_freq": "YSF Wires-X frequency (Hz)",
        "ysf_freq_help": "Recommended: 433125000. Use exactly 9 digits.",
        "autolink": "YSF Auto-link",
        "autolink_help": "Recommended: enabled.",
        "autolink_module": "YSF Auto-link module",
        "autolink_module_help": "Recommended: C.",
        "ysf_id": "YSF reflector ID *",
        "ysf_id_help": "Enter 1 to 8 digits.",
        "admin_user": "Admin username *",
        "admin_user_help": "A value will be suggested from the callsign. You may change it.",
        "admin_slug": "Private Admin address *",
        "admin_slug_help": "The URL part after the domain. Example: control-pny. You may change it.",
        "password": "Admin password *",
        "password_help": "At least 8 characters.",
        "password2": "Repeat the password *",
        "dashboard_lang": "Dashboard language",
        "dashboard_lang_help": "Choose how the public dashboard will be displayed.",
        "review_ok": "If everything is correct, select INSTALL NOW.",
        "status_prepare": "Preparing installation...",
        "status_running": "Installing. Do not close this SSH session.",
        "status_done": "✓ Installation completed and final checks executed.",
        "status_fail": "✖ Installation ended with an error (code {rc}).",
        "tech_log": "The technical log is still saved automatically on the server.",
        "enter_hint": "Tip: Enter moves to the next answer • Tab also works • Fields marked * are required",
    },
}


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
        "comment": "XLXPNY by PU2PNY - xlx026.net",
        "header_text": "XLXPNY • PU2PNY",
        "footer_text": "XLXPNY • PU2PNY",
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
        "admin_slug": "controle-pny",
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
    SUB_TITLE = "Guided installer"
    BINDINGS = [("ctrl+c", "request_close", "Sair / Exit")]

    CSS = """
    Screen {
        background: #07131d;
        color: #e8f4ff;
    }
    #brand {
        height: 5;
        padding: 1 3;
        background: #0b2130;
        border-bottom: solid #10b8ff;
        color: #ffffff;
        text-style: bold;
    }
    #wizard {
        width: 92%;
        max-width: 118;
        height: 1fr;
        align-horizontal: center;
        padding: 1 0;
    }
    #step-line {
        height: 2;
        color: #21c6ff;
        text-style: bold;
    }
    #wizard-progress {
        height: 2;
        margin-bottom: 1;
    }
    #guide {
        min-height: 3;
        height: auto;
        padding: 1 2;
        margin-bottom: 1;
        color: #ffffff;
        background: #102737;
        border-left: thick #21c6ff;
    }
    #form-card {
        height: 1fr;
        border: round #1d6689;
        background: #0a1c28;
        padding: 1 3;
    }
    .page {
        width: 1fr;
        height: auto;
    }
    .page-heading {
        margin-bottom: 1;
        color: #ffffff;
        text-style: bold;
    }
    .field-label {
        margin-top: 1;
        color: #e8f4ff;
        text-style: bold;
    }
    .help {
        height: auto;
        margin-bottom: 0;
        color: #8fb1c5;
    }
    Input, Select {
        width: 1fr;
        margin-bottom: 1;
    }
    Input:focus, Select:focus {
        border: heavy #21c6ff;
    }
    #lang-buttons {
        height: auto;
        align: center middle;
        margin-top: 2;
    }
    #lang-buttons Button {
        min-width: 26;
        margin: 1 2;
        text-style: bold;
    }
    #lang-pt, #lang-en {
        background: #1b5570;
        color: #ffffff;
    }
    #lang-pt:focus, #lang-en:focus {
        background: #27c8f4;
        color: #00151f;
        border: heavy #ffffff;
    }
    #review {
        height: auto;
        padding: 1 2;
        color: #e8f4ff;
    }
    #install-status {
        height: 4;
        padding: 1;
        color: #ffffff;
        text-style: bold;
        content-align: center middle;
    }
    #install-progress {
        margin: 2 1;
    }
    #install-detail {
        min-height: 5;
        height: auto;
        padding: 1 2;
        color: #9bc2d8;
        background: #061018;
        border: round #1d6689;
    }
    #error {
        min-height: 3;
        height: auto;
        padding: 1;
        color: #ffffff;
        background: #7b2028;
        display: none;
    }
    #hint {
        height: 2;
        color: #8fb1c5;
        content-align: left middle;
    }
    #nav {
        height: 5;
        align: right middle;
    }
    #nav Button {
        min-width: 18;
        margin-left: 1;
        text-style: bold;
    }
    #back {
        background: #2d4352;
        color: #ffffff;
    }
    #next {
        background: #26c6f3;
        color: #00151f;
    }
    #cancel {
        background: #ff6872;
        color: #220005;
    }
    #back:focus, #next:focus, #cancel:focus {
        border: heavy #ffffff;
    }
    #footer-line {
        height: 2;
        color: #6c8ea2;
        content-align: center middle;
    }
    """

    STEP_COUNT = 8
    INPUT_ORDER = {
        1: ["reflector_id", "domain", "callsign", "email"],
        2: ["country", "location", "timezone"],
        3: ["modules"],
        4: ["ysf_port", "ysf_freq", "autolink_module", "ysf_id"],
        5: ["admin_user", "admin_slug", "admin_password", "admin_password_confirm"],
    }

    def __init__(self, root_dir: Path):
        super().__init__()
        self.root_dir = root_dir
        self.current_step = 0
        self.ui_lang = "pt-BR"
        self.installing = False
        self.proc: asyncio.subprocess.Process | None = None
        self.data: dict[str, Any] = {}
        self._detected_tz = detected_timezone()
        self._last_lines: deque[str] = deque(maxlen=10)

    def t(self, key: str) -> Any:
        return TEXT[self.ui_lang][key]

    def compose(self) -> ComposeResult:
        yield Static(
            "[b]XLX MODERN INSTALLER[/b]  •  [#21c6ff]PU2PNY[/#21c6ff]\n"
            "[#5ee68a]REFLETOR + PAINEL • INSTALAÇÃO GUIADA[/#5ee68a]",
            id="brand",
            markup=True,
        )
        with Vertical(id="wizard"):
            yield Static("", id="step-line")
            yield ProgressBar(total=self.STEP_COUNT, show_percentage=False, show_eta=False, id="wizard-progress")
            yield Static("", id="guide", markup=True)
            with VerticalScroll(id="form-card"):
                with Vertical(id="page-0", classes="page"):
                    yield Static("Escolha o idioma da instalação", id="page-heading-0", classes="page-heading")
                    yield Static(
                        "Esta escolha altera os textos do instalador. O idioma do painel poderá ser escolhido depois.",
                        id="lang-help",
                        classes="help",
                    )
                    with Horizontal(id="lang-buttons"):
                        yield Button("Português (Brasil)", id="lang-pt")
                        yield Button("English", id="lang-en")

                with Vertical(id="page-1", classes="page"):
                    yield Static("", id="page-heading-1", classes="page-heading")
                    yield Label("", id="label-reflector_id", classes="field-label")
                    yield Static("", id="help-reflector_id", classes="help")
                    yield Input(placeholder="PNY", id="reflector_id", max_length=3)
                    yield Label("", id="label-domain", classes="field-label")
                    yield Static("", id="help-domain", classes="help")
                    yield Input(placeholder="xlx026.net", id="domain")
                    yield Label("", id="label-callsign", classes="field-label")
                    yield Static("", id="help-callsign", classes="help")
                    yield Input(placeholder="PU2PNY", id="callsign", max_length=6)
                    yield Label("", id="label-email", classes="field-label")
                    yield Static("", id="help-email", classes="help")
                    yield Input(placeholder="contato@seudominio.net", id="email")

                with Vertical(id="page-2", classes="page"):
                    yield Static("", id="page-heading-2", classes="page-heading")
                    yield Label("", id="label-country", classes="field-label")
                    yield Static("", id="help-country", classes="help")
                    yield Input(value="Brazil", id="country")
                    yield Label("", id="label-location", classes="field-label")
                    yield Static("", id="help-location", classes="help")
                    yield Input(placeholder="Santa Isabel - SP", id="location")
                    yield Label("", id="label-timezone", classes="field-label")
                    yield Static("", id="help-timezone", classes="help")
                    yield Input(value=self._detected_tz, id="timezone")

                with Vertical(id="page-3", classes="page"):
                    yield Static("", id="page-heading-3", classes="page-heading")
                    yield Label("", id="label-https", classes="field-label")
                    yield Static("", id="help-https", classes="help")
                    yield Select(YES_NO_PT, value="yes", allow_blank=False, id="https")
                    yield Label("", id="label-echo", classes="field-label")
                    yield Static("", id="help-echo", classes="help")
                    yield Select(YES_NO_PT, value="yes", allow_blank=False, id="echo")
                    yield Label("", id="label-modules", classes="field-label")
                    yield Static("", id="help-modules", classes="help")
                    yield Input(value="5", id="modules")

                with Vertical(id="page-4", classes="page"):
                    yield Static("", id="page-heading-4", classes="page-heading")
                    yield Label("", id="label-ysf_port", classes="field-label")
                    yield Static("", id="help-ysf_port", classes="help")
                    yield Input(value="42000", id="ysf_port")
                    yield Label("", id="label-ysf_freq", classes="field-label")
                    yield Static("", id="help-ysf_freq", classes="help")
                    yield Input(value="433125000", id="ysf_freq")
                    yield Label("", id="label-autolink", classes="field-label")
                    yield Static("", id="help-autolink", classes="help")
                    yield Select(YES_NO_PT, value="yes", allow_blank=False, id="autolink")
                    yield Label("", id="label-autolink_module", classes="field-label")
                    yield Static("", id="help-autolink_module", classes="help")
                    yield Input(value="C", id="autolink_module", max_length=1)
                    yield Label("", id="label-ysf_id", classes="field-label")
                    yield Static("", id="help-ysf_id", classes="help")
                    yield Input(placeholder="72426", id="ysf_id", max_length=8)

                with Vertical(id="page-5", classes="page"):
                    yield Static("", id="page-heading-5", classes="page-heading")
                    yield Label("", id="label-admin_user", classes="field-label")
                    yield Static("", id="help-admin_user", classes="help")
                    yield Input(id="admin_user")
                    yield Label("", id="label-admin_slug", classes="field-label")
                    yield Static("", id="help-admin_slug", classes="help")
                    yield Input(id="admin_slug", max_length=32)
                    yield Label("", id="label-password", classes="field-label")
                    yield Static("", id="help-password", classes="help")
                    yield Input(password=True, id="admin_password")
                    yield Label("", id="label-password2", classes="field-label")
                    yield Input(password=True, id="admin_password_confirm")
                    yield Label("", id="label-dashboard_lang", classes="field-label")
                    yield Static("", id="help-dashboard_lang", classes="help")
                    yield Select(DASHBOARD_LANGUAGES, value="pt-BR", allow_blank=False, id="dashboard_lang")

                with Vertical(id="page-6", classes="page"):
                    yield Static("", id="page-heading-6", classes="page-heading")
                    yield Static("", id="review", markup=True)

                with Vertical(id="page-7", classes="page"):
                    yield Static("", id="page-heading-7", classes="page-heading")
                    yield Static("", id="install-status")
                    yield ProgressBar(total=100, show_eta=False, id="install-progress")
                    yield Static("", id="install-detail")

            yield Static("", id="error")
            yield Static("", id="hint")
            with Horizontal(id="nav"):
                yield Button("← Voltar", id="back")
                yield Button("Continuar →", id="next")
                yield Button("Cancelar", id="cancel")
        yield Static("XLX Modern Installer • PU2PNY", id="footer-line")

    def on_mount(self) -> None:
        self.apply_language()
        self.show_step(0)
        self.query_one("#lang-pt", Button).focus()

    def apply_language(self) -> None:
        t = self.t
        self.query_one("#brand", Static).update(
            "[b]XLX MODERN INSTALLER[/b]  •  [#21c6ff]PU2PNY[/#21c6ff]\n"
            f"[#5ee68a]{t('subtitle')}[/#5ee68a]"
        )
        heading_keys = [
            "lang_title",
            "identity_title",
            "location_title",
            "options_title",
            "ysf_title",
            "admin_title",
            "review_title",
            "install_title",
        ]
        for index, key in enumerate(heading_keys):
            self.query_one(f"#page-heading-{index}", Static).update(t(key))
        self.query_one("#lang-help", Static).update(t("lang_help"))

        fields = [
            "reflector_id", "domain", "callsign", "email", "country", "location", "timezone",
            "https", "echo", "modules", "ysf_port", "ysf_freq", "autolink", "autolink_module",
            "ysf_id", "admin_user", "admin_slug", "password", "password2", "dashboard_lang",
        ]
        text_keys = {
            "reflector_id": "rid",
            "domain": "domain",
            "callsign": "callsign",
            "email": "email",
            "country": "country",
            "location": "location",
            "timezone": "timezone",
            "https": "https",
            "echo": "echo",
            "modules": "modules",
            "ysf_port": "ysf_port",
            "ysf_freq": "ysf_freq",
            "autolink": "autolink",
            "autolink_module": "autolink_module",
            "ysf_id": "ysf_id",
            "admin_user": "admin_user",
            "admin_slug": "admin_slug",
            "password": "password",
            "password2": "password2",
            "dashboard_lang": "dashboard_lang",
        }
        for field in fields:
            self.query_one(f"#label-{field}", Label).update(t(text_keys[field]))
        help_fields = [
            "reflector_id", "domain", "callsign", "email", "country", "location", "timezone",
            "https", "echo", "modules", "ysf_port", "ysf_freq", "autolink", "autolink_module",
            "ysf_id", "admin_user", "admin_slug", "password", "dashboard_lang",
        ]
        for field in help_fields:
            self.query_one(f"#help-{field}", Static).update(t(f"{text_keys[field]}_help"))

        choices = YES_NO_PT if self.ui_lang == "pt-BR" else YES_NO_EN
        for select_id in ("https", "echo", "autolink"):
            select = self.query_one(f"#{select_id}", Select)
            current = select.value
            select.set_options(choices)
            select.value = current if current in {"yes", "no"} else "yes"

        dashboard = self.query_one("#dashboard_lang", Select)
        if self.current_step == 0:
            dashboard.value = self.ui_lang if self.ui_lang in {"pt-BR", "en"} else "pt-BR"

        self.query_one("#back", Button).label = t("back")
        self.query_one("#next", Button).label = t("next")
        self.query_one("#cancel", Button).label = t("cancel")
        self.query_one("#hint", Static).update(t("enter_hint"))

    def show_step(self, step: int) -> None:
        self.current_step = max(0, min(step, self.STEP_COUNT - 1))
        for index in range(self.STEP_COUNT):
            self.query_one(f"#page-{index}").styles.display = "block" if index == self.current_step else "none"

        name = self.t("steps")[self.current_step]
        self.query_one("#step-line", Static).update(
            self.t("step_fmt").format(current=self.current_step + 1, total=self.STEP_COUNT, name=name)
        )
        self.query_one("#wizard-progress", ProgressBar).update(progress=self.current_step + 1)
        self.query_one("#guide", Static).update(self.t("guides")[self.current_step])

        back = self.query_one("#back", Button)
        nxt = self.query_one("#next", Button)
        cancel = self.query_one("#cancel", Button)
        back.disabled = self.current_step in {0, 7} or self.installing
        cancel.disabled = self.installing
        back.styles.display = "none" if self.current_step == 0 else "block"
        nxt.styles.display = "none" if self.current_step == 0 else "block"

        if self.current_step == 6:
            nxt.label = self.t("install")
            nxt.disabled = False
            self.prepare_review()
        elif self.current_step == 7:
            nxt.label = self.t("installing")
            nxt.disabled = True
        else:
            nxt.label = self.t("next")
            nxt.disabled = False

        self.clear_error()
        if self.current_step == 1:
            self.query_one("#reflector_id", Input).focus()
        elif self.current_step == 2:
            self.query_one("#country", Input).focus()
        elif self.current_step == 3:
            self.query_one("#https", Select).focus()
        elif self.current_step == 4:
            self.query_one("#ysf_port", Input).focus()
        elif self.current_step == 5:
            self.prepare_admin_defaults()
            self.query_one("#admin_user", Input).focus()

    def set_language(self, lang: str) -> None:
        self.ui_lang = lang
        self.apply_language()
        self.show_step(1)

    def clear_error(self) -> None:
        error = self.query_one("#error", Static)
        error.update("")
        error.styles.display = "none"

    def fail(self, message: str, focus_id: str | None = None) -> bool:
        error = self.query_one("#error", Static)
        error.update(f"⚠ {message}")
        error.styles.display = "block"
        if focus_id:
            try:
                self.query_one(f"#{focus_id}").focus()
            except Exception:
                pass
        return False

    def input_value(self, widget_id: str) -> str:
        return self.query_one(f"#{widget_id}", Input).value.strip()

    def select_yes(self, widget_id: str) -> bool:
        return self.query_one(f"#{widget_id}", Select).value == "yes"

    def prepare_admin_defaults(self) -> None:
        callsign = self.data.get("callsign", "").lower()
        rid = self.data.get("reflector_id", "").lower()
        user = self.query_one("#admin_user", Input)
        slug = self.query_one("#admin_slug", Input)
        if not user.value and callsign:
            user.value = callsign
        if not slug.value and rid:
            slug.value = f"controle-{rid}"

    @on(Input.Submitted)
    def advance_on_enter(self, event: Input.Submitted) -> None:
        order = self.INPUT_ORDER.get(self.current_step, [])
        widget_id = event.input.id
        if not widget_id or widget_id not in order:
            return
        index = order.index(widget_id)
        if index + 1 < len(order):
            self.query_one(f"#{order[index + 1]}", Input).focus()
        else:
            self.query_one("#next", Button).focus()

    @on(Button.Pressed)
    async def handle_button(self, event: Button.Pressed) -> None:
        button_id = event.button.id
        if button_id == "lang-pt":
            self.set_language("pt-BR")
            return
        if button_id == "lang-en":
            self.set_language("en")
            return
        if button_id == "cancel":
            self.action_request_close()
            return
        if button_id == "back" and not self.installing:
            self.show_step(self.current_step - 1)
            return
        if button_id != "next" or self.installing:
            return
        if self.current_step in {1, 2, 3, 4, 5}:
            if not self.validate_step(self.current_step):
                return
            self.show_step(self.current_step + 1)
            return
        if self.current_step == 6:
            self.show_step(7)
            await self.run_installation()

    def validate_step(self, step: int) -> bool:
        self.clear_error()
        if step == 1:
            rid = self.input_value("reflector_id").upper()
            domain = self.input_value("domain").lower()
            callsign = self.input_value("callsign").upper()
            email = self.input_value("email").lower()
            if not re.fullmatch(r"[A-Z0-9]{3}", rid):
                return self.fail(
                    "O ID precisa ter exatamente 3 letras/números." if self.ui_lang == "pt-BR"
                    else "The ID must contain exactly 3 letters/numbers.",
                    "reflector_id",
                )
            if not DOMAIN_RE.fullmatch(domain):
                return self.fail(
                    "Domínio inválido. Exemplo: xlx026.net." if self.ui_lang == "pt-BR"
                    else "Invalid domain. Example: xlx026.net.",
                    "domain",
                )
            if not CALLSIGN_RE.fullmatch(callsign):
                return self.fail(
                    "Indicativo inválido. Use de 3 a 6 letras/números." if self.ui_lang == "pt-BR"
                    else "Invalid callsign. Use 3 to 6 letters/numbers.",
                    "callsign",
                )
            if not EMAIL_RE.fullmatch(email):
                return self.fail(
                    "Informe um e-mail válido." if self.ui_lang == "pt-BR" else "Enter a valid email.",
                    "email",
                )
            self.data.update(
                reflector_id=rid,
                domain=domain,
                callsign=callsign,
                email=email,
                comment=f"XLX{rid} by {callsign} - {domain}",
                header_text=f"XLX{rid} • {callsign}",
                footer_text=f"XLX{rid} • {callsign}",
            )
            return True

        if step == 2:
            country = self.input_value("country")
            location = self.input_value("location")
            timezone = self.input_value("timezone")
            if not country:
                return self.fail("Informe o país." if self.ui_lang == "pt-BR" else "Enter the country.", "country")
            if not location:
                return self.fail(
                    "Informe cidade e estado/região." if self.ui_lang == "pt-BR" else "Enter city and state/region.",
                    "location",
                )
            if not timezone:
                return self.fail(
                    "Informe o fuso horário." if self.ui_lang == "pt-BR" else "Enter the timezone.",
                    "timezone",
                )
            self.data.update(country=country, location=location, timezone=timezone)
            return True

        if step == 3:
            try:
                modules = int(self.input_value("modules"))
            except ValueError:
                return self.fail(
                    "A quantidade de módulos precisa ser um número." if self.ui_lang == "pt-BR"
                    else "The module count must be a number.",
                    "modules",
                )
            echo = self.select_yes("echo")
            minimum = 5 if echo else 1
            if not minimum <= modules <= 26:
                return self.fail(
                    f"Use entre {minimum} e 26 módulos." if self.ui_lang == "pt-BR"
                    else f"Use between {minimum} and 26 modules.",
                    "modules",
                )
            self.data.update(https=self.select_yes("https"), echo=echo, modules=modules)
            return True

        if step == 4:
            try:
                ysf_port = int(self.input_value("ysf_port"))
            except ValueError:
                return self.fail(
                    "A porta YSF precisa ser numérica." if self.ui_lang == "pt-BR" else "The YSF port must be numeric.",
                    "ysf_port",
                )
            if not 1 <= ysf_port <= 65535:
                return self.fail(
                    "A porta YSF deve estar entre 1 e 65535." if self.ui_lang == "pt-BR"
                    else "The YSF port must be between 1 and 65535.",
                    "ysf_port",
                )
            if port_in_use(ysf_port):
                return self.fail(
                    f"A porta {ysf_port} já está em uso." if self.ui_lang == "pt-BR"
                    else f"Port {ysf_port} is already in use.",
                    "ysf_port",
                )
            ysf_freq = self.input_value("ysf_freq")
            if not re.fullmatch(r"\d{9}", ysf_freq):
                return self.fail(
                    "A frequência YSF precisa ter exatamente 9 dígitos." if self.ui_lang == "pt-BR"
                    else "The YSF frequency must contain exactly 9 digits.",
                    "ysf_freq",
                )
            autolink = self.select_yes("autolink")
            module = self.input_value("autolink_module").upper()
            if autolink:
                if not re.fullmatch(r"[A-Z]", module):
                    return self.fail(
                        "Informe uma letra de módulo válida." if self.ui_lang == "pt-BR"
                        else "Enter a valid module letter.",
                        "autolink_module",
                    )
                if ord(module) - ord("A") >= self.data["modules"]:
                    last = chr(ord("A") + self.data["modules"] - 1)
                    return self.fail(
                        f"O módulo deve estar entre A e {last}." if self.ui_lang == "pt-BR"
                        else f"The module must be between A and {last}.",
                        "autolink_module",
                    )
            ysf_id = self.input_value("ysf_id")
            if not re.fullmatch(r"\d{1,8}", ysf_id):
                return self.fail(
                    "O ID YSF deve ter de 1 a 8 dígitos." if self.ui_lang == "pt-BR"
                    else "The YSF ID must contain 1 to 8 digits.",
                    "ysf_id",
                )
            self.data.update(
                ysf_port=ysf_port,
                ysf_freq=int(ysf_freq),
                autolink=autolink,
                autolink_module=module or "C",
                ysf_id=ysf_id,
            )
            return True

        if step == 5:
            admin_user = self.input_value("admin_user")
            admin_slug = self.input_value("admin_slug").lower()
            password = self.query_one("#admin_password", Input).value
            confirm = self.query_one("#admin_password_confirm", Input).value
            dashboard_lang = self.query_one("#dashboard_lang", Select).value
            if not ADMIN_USER_RE.fullmatch(admin_user):
                return self.fail(
                    "Usuário inválido. Use letras, números, ponto, _ ou -." if self.ui_lang == "pt-BR"
                    else "Invalid username. Use letters, numbers, dot, _ or -.",
                    "admin_user",
                )
            if not ADMIN_SLUG_RE.fullmatch(admin_slug):
                return self.fail(
                    "O endereço privado deve ter de 2 a 32 caracteres: a-z, 0-9 e hífen." if self.ui_lang == "pt-BR"
                    else "The private address must contain 2 to 32 characters: a-z, 0-9 and hyphen.",
                    "admin_slug",
                )
            if len(password) < 8:
                return self.fail(
                    "A senha precisa ter pelo menos 8 caracteres." if self.ui_lang == "pt-BR"
                    else "The password must contain at least 8 characters.",
                    "admin_password",
                )
            if password != confirm:
                return self.fail(
                    "As duas senhas não são iguais." if self.ui_lang == "pt-BR"
                    else "The two passwords do not match.",
                    "admin_password_confirm",
                )
            if dashboard_lang not in {"pt-BR", "en", "es", "fr", "de", "it"}:
                return self.fail(
                    "Selecione um idioma válido para o painel." if self.ui_lang == "pt-BR"
                    else "Select a valid dashboard language.",
                    "dashboard_lang",
                )
            self.data.update(
                admin_user=admin_user,
                admin_slug=admin_slug,
                admin_password=password,
                dashboard_lang=str(dashboard_lang),
            )
            return True
        return True

    def prepare_review(self) -> None:
        if not self.data:
            return
        yes = "Sim" if self.ui_lang == "pt-BR" else "Yes"
        no = "Não" if self.ui_lang == "pt-BR" else "No"
        yn = lambda value: yes if value else no
        off = "Desativado" if self.ui_lang == "pt-BR" else "Disabled"
        module_line = self.data["autolink_module"] if self.data["autolink"] else off
        if self.ui_lang == "pt-BR":
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
                f"[#5ee68a][b]{self.t('review_ok')}[/b][/#5ee68a]"
            )
        else:
            review = (
                f"[b]Reflector[/b]       XLX{self.data['reflector_id']}\n"
                f"[b]Domain[/b]          {self.data['domain']}\n"
                f"[b]Sysop[/b]           {self.data['callsign']} • {self.data['email']}\n"
                f"[b]Location[/b]        {self.data['location']} • {self.data['country']}\n"
                f"[b]Timezone[/b]        {self.data['timezone']}\n\n"
                f"[b]HTTPS[/b]           {yn(self.data['https'])}\n"
                f"[b]Echo module E[/b]  {yn(self.data['echo'])}\n"
                f"[b]Modules[/b]         {self.data['modules']}\n"
                f"[b]YSF[/b]             UDP {self.data['ysf_port']} • {self.data['ysf_freq']} Hz\n"
                f"[b]Auto-link[/b]       {yn(self.data['autolink'])} • module {module_line}\n"
                f"[b]YSF ID[/b]          {self.data['ysf_id']}\n\n"
                f"[b]Admin[/b]           {self.data['admin_user']} • /{self.data['admin_slug']}/\n"
                f"[b]Password[/b]        ••••••••\n"
                f"[b]Dashboard language[/b] {self.data['dashboard_lang']}\n\n"
                f"[#5ee68a][b]{self.t('review_ok')}[/b][/#5ee68a]"
            )
        self.query_one("#review", Static).update(review)

    def action_request_close(self) -> None:
        if self.installing:
            self.fail(
                "A instalação está em andamento. Aguarde a conclusão." if self.ui_lang == "pt-BR"
                else "Installation is running. Wait for it to finish."
            )
            return
        self.exit()

    def progress_from_line(self, line: str, current: int) -> tuple[int, str | None]:
        upper = line.upper()
        stages = [
            (("INICIANDO XLX MODERN INSTALLER", "STARTING XLX MODERN INSTALLER"), 5, "Inicializando" if self.ui_lang == "pt-BR" else "Starting"),
            (("UPDATING OS", "ATUALIZANDO OS"), 12, "Preparando o sistema" if self.ui_lang == "pt-BR" else "Preparing system"),
            (("INSTALLING DEPENDENCIES", "INSTALANDO DEPENDÊNCIAS"), 22, "Instalando dependências" if self.ui_lang == "pt-BR" else "Installing dependencies"),
            (("DOWNLOADING THE XLX APP", "BAIXANDO"), 32, "Preparando o XLXD" if self.ui_lang == "pt-BR" else "Preparing XLXD"),
            (("COMPILING", "COMPILANDO"), 43, "Compilando o refletor" if self.ui_lang == "pt-BR" else "Compiling reflector"),
            (("COPYING COMPONENTS", "COPIANDO COMPONENTES"), 52, "Instalando componentes" if self.ui_lang == "pt-BR" else "Installing components"),
            (("INSTALLING ECHO TEST SERVER", "ECHO TEST"), 58, "Configurando Echo Test" if self.ui_lang == "pt-BR" else "Configuring Echo Test"),
            (("INSTALANDO XLX MODERN DASHBOARD", "INSTALLING XLX MODERN DASHBOARD"), 68, "Instalando o painel" if self.ui_lang == "pt-BR" else "Installing dashboard"),
            (("PROVISIONANDO APRS/D-PRS", "PROVISIONING NATIVE APRS/D-PRS"), 80, "Configurando APRS / D-PRS" if self.ui_lang == "pt-BR" else "Configuring APRS / D-PRS"),
            (("VALIDAÇÃO PÓS-INSTALAÇÃO", "POST-INSTALLATION VALIDATION"), 91, "Executando verificações finais" if self.ui_lang == "pt-BR" else "Running final checks"),
            (("INSTALAÇÃO CONCLUÍDA", "INSTALLATION COMPLETE"), 100, "Concluído" if self.ui_lang == "pt-BR" else "Complete"),
        ]
        for needles, value, label in stages:
            if any(needle in upper for needle in needles):
                return max(current, value), label
        return current, None

    async def run_installation(self) -> None:
        self.installing = True
        self.show_step(7)
        progress = self.query_one("#install-progress", ProgressBar)
        status = self.query_one("#install-status", Static)
        detail = self.query_one("#install-detail", Static)
        status.update(self.t("status_running"))
        detail.update(self.t("tech_log"))
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
            f"--ui-lang={self.ui_lang}",
            f"--lang={self.data['dashboard_lang']}",
        ]

        current_progress = 1
        progress.update(progress=current_progress)
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
                if not line:
                    continue
                self._last_lines.append(line)
                current_progress, stage = self.progress_from_line(line, current_progress)
                progress.update(progress=current_progress)
                if stage:
                    status.update(stage)
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
        close_button.label = self.t("close")

        if rc == 0:
            progress.update(progress=100)
            status.update(self.t("status_done"))
            detail.update(
                "Tudo pronto. O painel e os serviços passaram pelas validações finais."
                if self.ui_lang == "pt-BR"
                else "Ready. The dashboard and services passed the final checks."
            )
        else:
            status.update(self.t("status_fail").format(rc=rc))
            tail = "\n".join(self._last_lines)
            detail.update(
                ("A instalação NÃO foi considerada pronta.\n\nÚltimas informações:\n" + tail)
                if self.ui_lang == "pt-BR"
                else ("The installation was NOT considered ready.\n\nLast details:\n" + tail)
            )


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
