#!/usr/bin/env python3
from __future__ import annotations

import os
import re
import secrets
import signal
import subprocess
import time
from collections import deque
from pathlib import Path
from threading import Lock, Thread
from typing import Any

from fastapi import FastAPI, Header, HTTPException, Request
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

ROOT_DIR = Path(os.environ.get("XLX_REPO_ROOT", Path(__file__).resolve().parents[1])).resolve()
STATIC_DIR = Path(__file__).resolve().parent / "static"
RUNTIME_DIR = Path("/opt/xlx-modern-installer/runtime")
TOKEN = os.environ.get("XLX_WEB_TOKEN") or secrets.token_urlsafe(32)
ALLOWED_IP = os.environ.get("XLX_WEB_ALLOWED_IP", "").strip()
ANSI_RE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
DOMAIN_RE = re.compile(r"^([a-z0-9-]+\.)+[a-z]{2,}$")
EMAIL_RE = re.compile(r"^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$")
CALLSIGN_RE = re.compile(r"^[A-Z0-9]{3,6}$")
ADMIN_USER_RE = re.compile(r"^[A-Za-z0-9._-]{3,64}$")
ADMIN_SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9-]{1,31}$")

app = FastAPI(title="XLX Modern Installer", docs_url=None, redoc_url=None, openapi_url=None)
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")


class InstallPayload(BaseModel):
    ui_lang: str = Field(default="pt-BR")
    reflector_id: str
    domain: str
    email: str
    callsign: str
    country: str
    timezone: str
    location: str
    https: bool = True
    echo: bool = True
    modules: int = 5
    ysf_port: int = 42000
    ysf_freq: int = 433125000
    autolink: bool = True
    autolink_module: str = "C"
    ysf_id: str
    admin_user: str
    admin_slug: str
    admin_password: str
    dashboard_lang: str = "pt-BR"


class InstallState:
    def __init__(self) -> None:
        self.lock = Lock()
        self.running = False
        self.finished = False
        self.success = False
        self.rc: int | None = None
        self.progress = 0
        self.stage = "Aguardando"
        self.message = ""
        self.started_at: float | None = None
        self.finished_at: float | None = None
        self.lines: deque[str] = deque(maxlen=16)
        self.proc: subprocess.Popen[str] | None = None

    def snapshot(self) -> dict[str, Any]:
        with self.lock:
            return {
                "running": self.running,
                "finished": self.finished,
                "success": self.success,
                "rc": self.rc,
                "progress": self.progress,
                "stage": self.stage,
                "message": self.message,
                "started_at": self.started_at,
                "finished_at": self.finished_at,
                "details": list(self.lines),
            }


STATE = InstallState()


@app.middleware("http")
async def security_headers(request: Request, call_next):
    if ALLOWED_IP and request.client and request.client.host != ALLOWED_IP:
        return JSONResponse({"detail": "Origem não autorizada."}, status_code=403)
    response = await call_next(request)
    response.headers["Cache-Control"] = "no-store, max-age=0"
    response.headers["Pragma"] = "no-cache"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    response.headers["Content-Security-Policy"] = (
        "default-src 'self'; style-src 'self'; script-src 'self'; img-src 'self' data:; "
        "connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'"
    )
    return response


def require_token(value: str | None) -> None:
    if not value or not secrets.compare_digest(value, TOKEN):
        raise HTTPException(status_code=401, detail="Sessão do instalador inválida.")


def normalize_and_validate(payload: InstallPayload) -> dict[str, Any]:
    data = payload.model_dump()
    data["ui_lang"] = payload.ui_lang if payload.ui_lang in {"pt-BR", "en"} else "pt-BR"
    data["reflector_id"] = payload.reflector_id.strip().upper()
    data["domain"] = payload.domain.strip().lower()
    data["email"] = payload.email.strip().lower()
    data["callsign"] = payload.callsign.strip().upper()
    data["country"] = payload.country.strip()
    data["timezone"] = payload.timezone.strip()
    data["location"] = payload.location.strip()
    data["autolink_module"] = payload.autolink_module.strip().upper() or "C"
    data["ysf_id"] = payload.ysf_id.strip()
    data["admin_user"] = payload.admin_user.strip()
    data["admin_slug"] = payload.admin_slug.strip().lower()
    errors: dict[str, str] = {}

    if not re.fullmatch(r"[A-Z0-9]{3}", data["reflector_id"]):
        errors["reflector_id"] = "Use exatamente 3 letras ou números. Ex.: 026 ou PNY."
    if not DOMAIN_RE.fullmatch(data["domain"]):
        errors["domain"] = "Informe um domínio completo válido. Ex.: xlx026.net."
    if not EMAIL_RE.fullmatch(data["email"]):
        errors["email"] = "Informe um e-mail válido."
    if not CALLSIGN_RE.fullmatch(data["callsign"]):
        errors["callsign"] = "Use um indicativo de 3 a 6 letras/números."
    if not data["country"]:
        errors["country"] = "Informe o país."
    if not data["timezone"]:
        errors["timezone"] = "Informe o fuso horário."
    if not data["location"]:
        errors["location"] = "Informe cidade e estado/região."
    minimum_modules = 5 if payload.echo else 1
    if not minimum_modules <= payload.modules <= 26:
        errors["modules"] = f"Use entre {minimum_modules} e 26 módulos."
    if not 1 <= payload.ysf_port <= 65535:
        errors["ysf_port"] = "A porta YSF deve estar entre 1 e 65535."
    if not re.fullmatch(r"\d{9}", str(payload.ysf_freq)):
        errors["ysf_freq"] = "A frequência YSF precisa ter exatamente 9 dígitos."
    if payload.autolink:
        module = data["autolink_module"]
        if not re.fullmatch(r"[A-Z]", module):
            errors["autolink_module"] = "Informe uma letra de módulo válida."
        elif ord(module) - ord("A") >= payload.modules:
            last = chr(ord("A") + payload.modules - 1)
            errors["autolink_module"] = f"O módulo precisa estar entre A e {last}."
    if not re.fullmatch(r"\d{1,8}", data["ysf_id"]):
        errors["ysf_id"] = "Use de 1 a 8 dígitos. Ex.: 12345."
    if not ADMIN_USER_RE.fullmatch(data["admin_user"]):
        errors["admin_user"] = "Use letras, números, ponto, _ ou -."
    if not ADMIN_SLUG_RE.fullmatch(data["admin_slug"]):
        errors["admin_slug"] = "Use 2 a 32 caracteres: a-z, 0-9 e hífen."
    if len(payload.admin_password) < 8:
        errors["admin_password"] = "Use uma senha com pelo menos 8 caracteres."
    if payload.dashboard_lang not in {"pt-BR", "en", "es", "fr", "de", "it"}:
        errors["dashboard_lang"] = "Selecione um idioma válido para o painel."
    if errors:
        raise HTTPException(status_code=422, detail={"fields": errors})

    data["comment"] = f"XLX{data['reflector_id']} by {data['callsign']} - {data['domain']}"
    data["header_text"] = f"XLX{data['reflector_id']} • {data['callsign']}"
    data["footer_text"] = data["header_text"]
    return data


def build_answers(data: dict[str, Any]) -> list[str]:
    answers = [
        data["reflector_id"], data["domain"], data["email"], data["callsign"], data["country"], data["timezone"],
        "Y", data["comment"], data["header_text"], data["footer_text"],
        "Y" if data["https"] else "N", "Y" if data["echo"] else "N", str(data["modules"]),
        str(data["ysf_port"]), str(data["ysf_freq"]), "Y" if data["autolink"] else "N",
    ]
    if data["autolink"]:
        answers.append(data["autolink_module"])
    answers.extend([
        data["location"], data["ysf_id"], data["admin_user"], data["admin_slug"],
        data["admin_password"], data["admin_password"], "",
    ])
    return answers


def progress_from_line(line: str, current: int, lang: str) -> tuple[int, str | None]:
    upper = line.upper()
    pt = lang == "pt-BR"
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


def safe_detail_line(line: str) -> bool:
    upper = line.upper()
    return not any(item in upper for item in ("PASSWORD", "SENHA", "CONTROL_PASSWORD", "XLX_CONTROL_PASSWORD"))


def installation_worker(data: dict[str, Any]) -> None:
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    os.chmod(RUNTIME_DIR, 0o700)
    answers_file = RUNTIME_DIR / f"web-answers-{os.getpid()}-{int(time.time())}.txt"
    answers_file.write_text("\n".join(build_answers(data)) + "\n", encoding="utf-8")
    os.chmod(answers_file, 0o600)
    env = os.environ.copy()
    env["XLX_MODERN_ANSWERS_FILE"] = str(answers_file)
    cmd = ["bash", str(ROOT_DIR / "install.sh"), "--tui-child", f"--ui-lang={data['ui_lang']}", f"--lang={data['dashboard_lang']}"]

    with STATE.lock:
        STATE.running = True; STATE.finished = False; STATE.success = False; STATE.rc = None
        STATE.progress = 1; STATE.started_at = time.time(); STATE.finished_at = None; STATE.lines.clear()
        STATE.stage = "Preparando instalação" if data["ui_lang"] == "pt-BR" else "Preparing installation"
        STATE.message = "Não feche esta página." if data["ui_lang"] == "pt-BR" else "Do not close this page."

    rc = 1
    try:
        proc = subprocess.Popen(cmd, cwd=str(ROOT_DIR), env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, encoding="utf-8", errors="replace", bufsize=1)
        with STATE.lock:
            STATE.proc = proc
        assert proc.stdout is not None
        current = 1
        for raw in proc.stdout:
            line = ANSI_RE.sub("", raw).strip()
            if not line:
                continue
            current, stage = progress_from_line(line, current, data["ui_lang"])
            with STATE.lock:
                STATE.progress = current
                if stage:
                    STATE.stage = stage
                if safe_detail_line(line):
                    STATE.lines.append(line[:500])
        rc = proc.wait()
    except Exception as exc:
        with STATE.lock:
            STATE.lines.append(f"Erro interno: {type(exc).__name__}")
        rc = 1
    finally:
        try:
            answers_file.unlink(missing_ok=True)
        except Exception:
            pass

    with STATE.lock:
        STATE.running = False; STATE.finished = True; STATE.success = rc == 0; STATE.rc = rc
        STATE.finished_at = time.time(); STATE.proc = None
        if rc == 0:
            STATE.progress = 100
            STATE.stage = "Instalação concluída" if data["ui_lang"] == "pt-BR" else "Installation complete"
            STATE.message = "Painel e serviços passaram pelas validações finais." if data["ui_lang"] == "pt-BR" else "Dashboard and services passed the final checks."
        else:
            STATE.stage = "Instalação interrompida" if data["ui_lang"] == "pt-BR" else "Installation stopped"
            STATE.message = f"A instalação não foi considerada pronta (código {rc})." if data["ui_lang"] == "pt-BR" else f"The installation was not considered ready (code {rc})."


@app.get("/")
def index() -> FileResponse:
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/api/health")
def health() -> dict[str, Any]:
    return {"ok": True, "name": "XLX Modern Installer", "version": "1"}


@app.get("/api/bootstrap")
def bootstrap(x_installer_token: str | None = Header(default=None)) -> dict[str, Any]:
    require_token(x_installer_token)
    timezone = "UTC"
    try:
        timezone = subprocess.check_output(["timedatectl", "show", "--property=Timezone", "--value"], text=True,
                                           stderr=subprocess.DEVNULL, timeout=4).strip() or "UTC"
    except Exception:
        pass
    return {"ok": True, "timezone": timezone, "defaults": {"country": "Brazil", "modules": 5, "ysf_port": 42000,
            "ysf_freq": 433125000, "autolink_module": "C", "dashboard_lang": "pt-BR"}}


@app.post("/api/validate")
def validate(payload: InstallPayload, x_installer_token: str | None = Header(default=None)) -> dict[str, Any]:
    require_token(x_installer_token)
    data = normalize_and_validate(payload)
    return {"ok": True, "data": {key: value for key, value in data.items() if key != "admin_password"}}


@app.post("/api/install", status_code=202)
def start_install(payload: InstallPayload, x_installer_token: str | None = Header(default=None)) -> dict[str, Any]:
    require_token(x_installer_token)
    data = normalize_and_validate(payload)
    with STATE.lock:
        if STATE.running:
            raise HTTPException(status_code=409, detail="Já existe uma instalação em andamento.")
    Thread(target=installation_worker, args=(data,), daemon=True).start()
    return {"ok": True, "started": True}


@app.get("/api/status")
def status(x_installer_token: str | None = Header(default=None)) -> dict[str, Any]:
    require_token(x_installer_token)
    return STATE.snapshot()


@app.post("/api/stop")
def stop_server(x_installer_token: str | None = Header(default=None)) -> dict[str, Any]:
    require_token(x_installer_token)
    with STATE.lock:
        if STATE.running:
            raise HTTPException(status_code=409, detail="A instalação está em andamento.")
    os.kill(os.getpid(), signal.SIGTERM)
    return {"ok": True}


def self_test() -> int:
    sample = InstallPayload(reflector_id="PNY", domain="xlx026.net", email="sysop@example.net", callsign="PU2PNY",
                            country="Brazil", timezone="America/Sao_Paulo", location="Santa Isabel - SP", ysf_id="12345",
                            admin_user="pu2pny", admin_slug="controle-pny", admin_password="ExampleOnly-123!")
    data = normalize_and_validate(sample)
    answers = build_answers(data)
    assert answers[0] == "PNY" and answers[18] == "12345" and answers[-1] == "" and len(answers) == 24
    progress, stage = progress_from_line("INSTALLING XLX MODERN DASHBOARD", 1, "en")
    assert progress == 68 and stage == "Installing dashboard"
    return 0


if __name__ == "__main__":
    raise SystemExit(self_test())
