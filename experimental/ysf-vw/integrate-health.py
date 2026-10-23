#!/usr/bin/python3
"""Patch a staged health-monitor copy; do not execute the monitor's send/test mode."""
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text()
old='    wires_markers = ('
assert s.count(old)==1
s=s.replace(old,'''    # Native VW support and admission key are independent from crossmode.
    vw_supported = b"YSF VW native-only" in blob
    try:
        vw_enabled = vw_supported and Path("/etc/xlx-modern/ysf-vw.conf").read_bytes() in (b"1", b"1\\n")
    except OSError:
        vw_enabled = False

'''+old,1)
old='''            "vw_voice_fr": False,
            "detail": "Core ativo aceita YSF VD Mode 2; Voice FR/VW não entra no fluxo DV atual",'''
new='''            "vw_voice_fr": vw_enabled,
            "vw_supported": vw_supported,
            "detail": (
                "VW nativo ativo entre estações YSF do mesmo módulo; sem conversão multiprotocolo"
                if vw_enabled else
                "DN/VD2 ativo; VW nativo disponível com chave desligada"
                if vw_supported else
                "DN/VD2 ativo; núcleo sem suporte VW"
            ),'''
assert s.count(old)==1;s=s.replace(old,new,1)
p.write_text(s)
