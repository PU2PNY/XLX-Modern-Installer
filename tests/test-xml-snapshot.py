#!/usr/bin/env python3
"""Exercise the real PHP status producer against an interrupted XLXD writer."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def php(code, *args):
    r = subprocess.run(["php", "-r", code, *map(str, args)], text=True,
                       capture_output=True, timeout=5)
    assert r.returncode == 0, r.stderr
    return r.stdout


def snapshot(nodes=""):
    return ('<?xml version="1.0"?><Version>2.5.3</Version>'
            '<XLXABC  linked peers></XLXABC  linked peers>'
            '<XLXABC  linked nodes>' + nodes + '</XLXABC  linked nodes>'
            '<XLXABC  heard users></XLXABC  heard users>')


with tempfile.TemporaryDirectory(prefix="xlx-xml-test-") as temp:
    base = Path(temp)
    api = base / "api"
    api.mkdir()
    for name in ["common.php", "status.php", "user-directory.php"]:
        shutil.copy2(ROOT / "dashboard/api" / name, api / name)
    cache = base / "cache"
    cache.mkdir()
    status = api / "status.php"
    status.write_text(status.read_text().replace("/var/cache/xlx-dashboard", str(cache)))
    xml = base / "xlxd.xml"
    log = base / "xlx.log"
    log.write_text("")
    (base / "config.php").write_text("<?php return " +
        "['xml_path'=>" + repr(str(xml)) + ", 'log_path'=>" + repr(str(log)) +
        ", 'users_db'=>'/nonexistent', 'users_override_db'=>'/nonexistent',"
        " 'history_limit'=>30, 'server_name'=>'Fixture',"
        " 'modules'=>['C'=>['name'=>'Fixture','protocol'=>'YSF','access'=>'Fixture']]];")
    complete = snapshot('<NODE><Callsign>W0TEST B</Callsign><Protocol>YSF</Protocol>'
                        '<LinkedModule>C</LinkedModule></NODE>')
    empty = snapshot()
    fixture = base / "fixture.json"
    fixture.write_text(json.dumps({"full": complete, "empty": empty}))
    result = php(r'''
require $argv[1]; $f=json_decode(file_get_contents($argv[2]),true);
if(!xlx_xml_snapshot_complete($f['full']) || !xlx_xml_snapshot_complete($f['empty'])) exit(1);
for($i=0;$i<strlen($f['full']);++$i) {
    if(xlx_xml_snapshot_complete(substr($f['full'],0,$i))) exit(2);
}
if(xlx_xml_snapshot_complete(str_replace('</NODE>','',$f['full']))) exit(3);
if(xlx_xml_snapshot_complete(str_replace('</XLXABC  heard users>','</XLXDEF  heard users>',$f['full']))) exit(4);
echo 'complete, empty and all interrupted prefixes checked';
''', api / "common.php", fixture)
    print("[PASS]", result)
    xml.write_text(complete)
    first = json.loads(php('require $argv[1];', status))
    assert first["connected_count"] == 1
    cachefile = cache / "status.json"
    original = cachefile.read_bytes()
    xml.write_text(complete[:complete.index("</NODE>") + len("</NODE>")])
    os.utime(cachefile, (time.time() - 10, time.time() - 10))
    oldstamp = cachefile.stat().st_mtime_ns
    fallback = json.loads(php('require $argv[1];', status))
    assert fallback == first, "partial XML replaced last valid status"
    assert cachefile.read_bytes() == original and cachefile.stat().st_mtime_ns == oldstamp
    print("[PASS] partial NODE list preserved previous status without refreshing cache")
    # Retry a separate path so request-local snapshot memoization cannot hide the write.
    xml.write_text("<Version>2.5.3</Version>")
    code = r'''require $argv[1]; echo "READY\n"; flush();
$t=microtime(true); $raw=xlx_read_complete_xml($argv[2]);
echo json_encode(['full'=>xlx_xml_snapshot_complete($raw),'seconds'=>microtime(true)-$t]);'''
    proc = subprocess.Popen(["php", "-r", code, str(api / "common.php"), str(xml)],
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert proc.stdout.readline() == "READY\n"
    time.sleep(0.035)
    xml.write_text(complete)
    stdout, stderr = proc.communicate(timeout=5)
    assert proc.returncode == 0, stderr
    recovered = json.loads(stdout)
    assert recovered["full"] and recovered["seconds"] < 0.3
    print("[PASS] bounded retry recovered a concurrently completed write")
    xml.write_text(empty)
    os.utime(cachefile, (time.time() - 10, time.time() - 10))
    assert json.loads(php('require $argv[1];', status))["connected_count"] == 0
    print("[PASS] genuinely empty complete list replaced the old count")
    xml.write_text(complete)
    php(r'''require $argv[1]; $a=xlx_read_complete_xml($argv[2]);
file_put_contents($argv[2],'<Version>partial');
if(xlx_read_complete_xml($argv[2])!==$a)exit(1);''', api / "common.php", xml)
    print("[PASS] same request reuses one consistent NODE/STATION snapshot")
    php(r'''require $argv[1]; $t=microtime(true);
try { xlx_read_complete_xml($argv[2]); exit(1); }
catch(RuntimeException $e) { if(microtime(true)-$t>0.3)exit(2); }''',
        api / "common.php", xml)
    print("[PASS] persistent partial source terminates after four attempts")
print("[PASS] XML snapshot regression")
