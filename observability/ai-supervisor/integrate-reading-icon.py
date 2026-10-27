#!/usr/bin/env python3
"""Decorative SVG reader; no status, polling, API, timer or radio change."""
import pathlib
import sys

ICON = '''<em class="tx-ai-scan" aria-hidden="true"><svg class="tx-ai-reader" viewBox="0 0 72 32" fill="none" focusable="false" aria-hidden="true"><g stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="6" width="24" height="23" rx="7" fill="currentColor" fill-opacity=".09"/><path d="M15 6V2M12 2h6M9 29v2m12-2v2M3 14H1m26 0h3"/><path d="M9 22h12"/><path d="M35 16h8m-3-3 3 3-3 3"/><path d="M49 3h14l6 6v20H49z" fill="currentColor" fill-opacity=".06"/><path d="M63 3v6h6M54 13h10m-10 5h10m-10 5h7" opacity=".5"/></g><g fill="currentColor"><circle class="ai-reader-node" cx="10" cy="15" r="2.2"/><circle class="ai-reader-node" cx="20" cy="15" r="2.2"/><circle class="ai-reader-node" cx="34" cy="16" r="1.5"/></g><g class="ai-reader-beam"><rect x="47" y="8" width="24" height="5" rx="2" fill="currentColor" opacity=".2"/><path d="M47 10.5h24" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></g></svg></em>'''

def integrate(root):
    js_path = root/'assets/app.js'
    css_path = root/'assets/ai-monitor-v1.css'
    js, css = js_path.read_text(), css_path.read_text()
    old = '<em class="tx-ai-scan" aria-hidden="true"></em>'
    if 'class="tx-ai-reader"' not in js:
        assert js.count(old) == 1, 'Unknown indicator markup; refuse broad edit'
        js = js.replace(old, ICON)
    v4 = '/* XLXMODERN AI MONITOR V4'
    v5 = '/* XLXMODERN AI MONITOR V5'
    assert v4 in css or v5 in css, 'Unknown CSS contract'
    start = css.index(v4 if v4 in css else v5)
    css = css[:start]+pathlib.Path(__file__).with_name('ai-reading-icon.css').read_text()
    js_path.write_text(js)
    css_path.write_text(css)

if __name__ == '__main__': integrate(pathlib.Path(sys.argv[1]))
