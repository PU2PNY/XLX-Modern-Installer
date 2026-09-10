from pathlib import Path


def replace_required(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing expected block: {label}")
    return text.replace(old, new, 1)


# README.md and README.en.md
for name in ("README.md", "README.en.md"):
    p = Path(name)
    s = p.read_text(encoding="utf-8")

    s = replace_required(
        s,
        "The repository is generic: it uses the reflector identity entered during installation and does not publish production credentials, private data or production-only implementation details.",
        "This repository publishes the XLX Modern installer and dashboard stack derived from the production-validated **XLX026 Brasil** environment. During setup, the operator enters the identity of the new reflector, so each installation receives its own reflector ID, domain, location and operating parameters. XLX026 is the production reference and live demonstration; its credentials, secrets and private production data are not distributed.\n\n**Live production example:** [XLX026 Brasil — xlx026.net](https://xlx026.net/)",
        f"{name} production positioning",
    )

    old_features = "\n".join([
        "- **Live** — real-time TX boxes, protocol/module state, QRZ public profile photo when available and 24-hour activity.",
        "- **Connected** — filters plus connected-station table; it is not merged with Modules.",
        "- **Modules** — access-identification table followed by module cards. Active modules follow the configured count and use NATO names Alfa–Zulu where applicable.",
        "- **Ranking** — recent activity indicators from available server history.",
        "- **Reflectors** — worldwide XLX reflector listing.",
        "- **APRS / D-PRS** — native Digital Lab interface.",
        "- **Certificates** — native participation certificate generation and verification.",
    ])
    new_features = "\n".join([
        "- **Live** — low-latency TX/RX boxes react quickly to the start and end of transmissions, showing callsign, protocol, module and, when available, the operator's public profile photo. The activity table covers the last **24 hours** and consolidates repeated activity by callsign with an expandable submenu for that operator's transmissions, avoiding repetitive rows. When observed APRS/D-PRS/GPS data is available, the activity is identified and the location action opens the reflector's own APRS/D-PRS page with the operator/location context.",
        "- **Connected** — filters plus a real-time connected-station table with callsign, protocol, module and connection time; it remains independent from Modules.",
        "- **Modules** — access-identification table followed by module cards. Active modules follow the configured count and use NATO names Alfa–Zulu where applicable.",
        "- **Ranking** — shows the station connected for the longest time, who generated the most PTT/TX events, who accumulated the most airtime, busiest hours, most-used modules and currently connected protocols. Statistical views include today, 7 days and the current month when coverage is available.",
        "- **Reflectors** — worldwide XLX reflector directory with search/filter controls to narrow the displayed list.",
        "- **APRS / D-PRS** — native Digital Lab associated with **module B**, reserved in this deployment model for beacons, APRS and D-PRS traffic. It supports observed GPS/location data plus sending and receiving APRS radio messages and acknowledgements through the server interface.",
        "- **Certificates** — generates participation certificates from eligible recorded activity, including TX information, accumulated airtime, modules and protocols represented in that activity, with public QR Code and HMAC authenticity verification.",
    ])
    s = replace_required(s, old_features, new_features, f"{name} dashboard features")

    s = replace_required(
        s,
        "APRS/D-PRS is native and mandatory in the normal installation. The web interface and APIs ship inside `dashboard/`; only the background gateway/service and SQLite state are provisioned outside the webroot.",
        "APRS/D-PRS is native and mandatory in the normal installation. The web interface and APIs ship inside `dashboard/`; only the background gateway/service and SQLite state are provisioned outside the webroot. The runtime connects the Digital Lab to **module B**, used as the dedicated beacon/APRS/D-PRS module, and enables APRS-IS transmit/receive operation so authenticated operators can exchange APRS messages and acknowledgements from the reflector interface.",
        f"{name} APRS model",
    )

    s = replace_required(
        s,
        "The Admin is not linked from public navigation and uses the private slug selected during setup. It includes:",
        "The Admin is not linked from public navigation and does not depend on a fixed `/admin/` URL. Its **private slug is configurable during installation**, reducing exposure of the management entry point. It includes:",
        f"{name} admin slug",
    )

    s = s.replace(
        "- Support/ANATEL simulator/News are not part of the generic deployment.",
        "- Support/ANATEL simulator/News are not part of the public installer distribution.",
    )
    p.write_text(s, encoding="utf-8")


# README.pt-BR.md
p = Path("README.pt-BR.md")
s = p.read_text(encoding="utf-8")

s = replace_required(
    s,
    "O repositório é genérico: utiliza a identidade informada durante a instalação e não publica credenciais, dados privados nem implementação exclusiva do servidor de referência.",
    "Este repositório publica o instalador e o painel **XLX Modern** derivados do ambiente **XLX026 Brasil validado em produção**. Durante a instalação, o responsável informa a identidade do novo refletor, portanto cada servidor recebe seu próprio ID XLX, domínio, localização e parâmetros operacionais. O XLX026 é a referência de produção e demonstração ao vivo; credenciais, segredos e dados privados do servidor de produção não são distribuídos.\n\n**Exemplo funcionando em produção:** [XLX026 Brasil — xlx026.net](https://xlx026.net/)",
    "README.pt-BR production positioning",
)

old_features = "\n".join([
    "- **Ao Vivo**: boxes de TX em tempo real, protocolo/módulo, foto pública do QRZ quando disponível e atividade de 24h.",
    "- **Conectados**: filtros e tabela de estações conectadas, separado de Módulos.",
    "- **Módulos**: identificações de acesso primeiro e cards de módulos depois; quantidade configurável e nomes NATO Alfa–Zulu quando aplicável.",
    "- **Ranking**: indicadores recentes com dados disponíveis no servidor.",
    "- **Refletores**: lista mundial XLX.",
    "- **APRS / D-PRS**: Digital Lab nativo.",
    "- **Certificados**: emissão e validação nativas.",
])
new_features = "\n".join([
    "- **Ao Vivo**: boxes de TX/RX de baixa latência respondem rapidamente ao início e ao fim das transmissões e exibem indicativo, protocolo, módulo e, quando disponível, a imagem pública do operador. A tabela reúne as transmissões das últimas **24 horas** e consolida atividades repetidas por indicativo, com submenu expansível para consultar as transmissões daquele operador sem poluir a lista com linhas repetitivas. Quando existe APRS/D-PRS/GPS realmente observado, a atividade é identificada e a ação de localização abre a própria página APRS/D-PRS do servidor com o contexto do operador/localização.",
    "- **Conectados**: filtros e tabela em tempo real das estações conectadas, com indicativo, protocolo, módulo e tempo de conexão, separada da página Módulos.",
    "- **Módulos**: identificações de acesso primeiro e cards de módulos depois; quantidade configurável e nomes NATO Alfa–Zulu quando aplicável.",
    "- **Ranking**: mostra quem está conectado há mais tempo, quem mais apertou o PTT/gerou TX, quem acumulou mais tempo falando, horários de maior movimento, módulos mais utilizados e protocolos atualmente conectados. Há visões de hoje, 7 dias e mês atual quando existe cobertura estatística.",
    "- **Refletores**: lista mundial de refletores XLX com busca e filtros para selecionar o que será exibido.",
    "- **APRS / D-PRS**: Digital Lab nativo ligado ao **módulo B**, reservado neste modelo de instalação para beacons, APRS e D-PRS. Mostra posições realmente observadas e permite enviar e receber mensagens de rádio APRS, incluindo ACKs, pela interface do servidor.",
    "- **Certificados**: gera certificado de participação a partir de atividade elegível registrada, incluindo dados de TX, tempo acumulado, módulos e protocolos presentes naquela atividade, com QR Code público e validação de autenticidade por HMAC.",
])
s = replace_required(s, old_features, new_features, "README.pt-BR dashboard features")

s = replace_required(
    s,
    "A interface e APIs ficam dentro do próprio `dashboard/`; não existe segundo painel APRS. Somente gateway/serviço de fundo e SQLite são provisionados fora do webroot.",
    "A interface e APIs ficam dentro do próprio `dashboard/`; não existe segundo painel APRS. Somente gateway/serviço de fundo e SQLite são provisionados fora do webroot. O runtime liga o Digital Lab ao **módulo B**, dedicado a beacons/APRS/D-PRS, e habilita transmissão e recepção via APRS-IS para que operadores autenticados possam trocar mensagens APRS e confirmações pela interface do refletor.",
    "README.pt-BR APRS model",
)

s = replace_required(
    s,
    "O Admin não aparece no menu público. A URL privada é o slug escolhido na instalação. Recursos:",
    "O Admin não aparece no menu público e não depende de uma URL fixa `/admin/`. O **slug privado é configurável durante a instalação**, reduzindo a exposição do ponto de entrada administrativo. Recursos:",
    "README.pt-BR admin slug",
)

s = s.replace(
    "- Suporte/Simulado/Notícias fora do instalador genérico.",
    "- Suporte/Simulado/Notícias fora da distribuição pública do instalador.",
)
p.write_text(s, encoding="utf-8")


# docs/FEATURES.md
p = Path("docs/FEATURES.md")
s = p.read_text(encoding="utf-8")
s = s.replace("Version: **1.2.8**", "Version: **1.2.12**", 1)
s = s.replace(
    "\n".join([
        "- Live TX monitor and 24-hour activity.",
        "- QRZ public TX profile photo when available.",
        "- Connected stations as an independent page.",
        "- Modules/access identifiers as an independent page; configured module range and NATO names.",
        "- Ranking and worldwide XLX reflector list.",
    ]),
    "\n".join([
        "- Low-latency live TX/RX monitor with fast start/end state changes and 24-hour activity grouped by callsign with expandable transmission history.",
        "- Public operator profile photo when available and observed APRS/D-PRS/GPS location linking into the reflector Digital Lab.",
        "- Connected stations as an independent page.",
        "- Modules/access identifiers as an independent page; configured module range and NATO names.",
        "- Ranking for longest connected station, most PTT/TX, most airtime, busiest hours, modules and protocols.",
        "- Worldwide XLX reflector list with search/filter controls.",
    ]),
)
s = s.replace(
    "- Native APRS/D-PRS Digital Lab.",
    "- Native APRS/D-PRS Digital Lab on dedicated module B, with APRS message/ACK send and receive support.",
)
s = s.replace(
    "- Native activity-based certificates with QR + HMAC verification.",
    "- Native activity-based certificates with TX/airtime/module/protocol data plus QR + HMAC verification.",
)
s = s.replace(
    "- Support, ANATEL simulator and News are intentionally excluded from the generic public package.",
    "- Support, ANATEL simulator and News are intentionally excluded from the public installer distribution.",
)
p.write_text(s, encoding="utf-8")


# Replace obsolete APRS/D-PRS documentation with the current native model.
Path("docs/APRS-DPRS.md").write_text(
    """# APRS / D-PRS nativo

Na versão **1.2.12**, APRS/D-PRS faz parte do XLX Modern Installer e é provisionado pelo próprio repositório durante a instalação normal. A implementação pública fica em `dashboard/native/aprs/`, com interface e APIs integradas ao dashboard.

## Modelo operacional

- **Módulo B** dedicado a beacons, APRS e D-PRS.
- Gateway local entre o refletor e APRS-IS.
- Transmissão e recepção APRS habilitadas pelo serviço nativo.
- Mensagens APRS, ACKs e estado do operador pela interface Digital Lab.
- Posições GPS/APRS/D-PRS exibidas somente quando realmente observadas.
- Indicadores de posição na atividade do painel podem abrir a visão de localização do próprio servidor.
- Estado persistente em SQLite fora do webroot.
- Conta por indicativo, senha gerada criptograficamente e armazenamento somente de hash.
- Recuperação autorizada com rotação da versão de autenticação e revogação de tokens lembrados.

O indicativo do serviço APRS é derivado do indicativo do sysop com SSID `-10`. A configuração operacional é criada em `/etc/xlx-aprs-dprs/`, o estado fica em `/var/lib/xlx-aprs-dprs/` e o serviço é executado como `xlx-aprs-dprs.service`.

## Segurança e dados privados

Credenciais, passcodes reais, bancos SQLite de produção, contas, tokens, sessões, chaves privadas, logs e backups de produção não são publicados no GitHub. Cada instalação cria e mantém seus próprios dados operacionais localmente.

## Referência em produção

O **XLX026 Brasil** é a referência de produção do painel e pode ser acompanhado em [https://xlx026.net/](https://xlx026.net/).
""",
    encoding="utf-8",
)

print("README_REFRESH_OK")
