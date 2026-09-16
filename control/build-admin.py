#!/usr/bin/env python3
from pathlib import Path
import json,re,sys
if len(sys.argv) not in (2,3): raise SystemExit("usage: build-admin.py INDEX.php [pt-BR|en|es|fr|de|it]")
p=Path(sys.argv[1]); locale=(sys.argv[2] if len(sys.argv)==3 else "pt-BR").lower()
s=p.read_text(encoding="utf-8")
if "const CTRL_VER='1.5.1';" not in s: raise SystemExit("unsupported Admin baseline")
# Source is already structurally generic. Translation is static at install time.
aliases={"pt":"pt-BR","pt-br":"pt-BR","pt_br":"pt-BR","en-us":"en","en_us":"en"}
locale=aliases.get(locale,locale)
supported={"pt-BR","en","es","fr","de","it"}
if locale not in supported:
    raise SystemExit("Admin supports dashboard languages pt-BR, en, es, fr, de or it")
if locale != "pt-BR":
    mapping=json.loads((Path(__file__).with_name(f"admin-{locale}.json")).read_text(encoding="utf-8"))
    baseline=json.loads((Path(__file__).with_name("admin-en.json")).read_text(encoding="utf-8"))
    if set(mapping) != set(baseline):
        raise SystemExit(f"Admin locale catalog key mismatch: {locale}")
    for old in sorted(mapping,key=len,reverse=True): s=s.replace(old,mapping[old])
    s=s.replace('lang="pt-BR"',f'lang="{locale}"')
# Security and genericity invariants.
for bad in ("/etc/legacy-control","/var/lib/legacy-control","/usr/local/sbin/legacy-control-"):
    if bad in s: raise SystemExit("forbidden production marker: "+bad)
for required in ("health-status","access-interlink-add","radioid_api_search","$adminPath","$baseUrl"):
    if required not in s: raise SystemExit("required Admin marker missing: "+required)
p.write_text(s,encoding="utf-8")
