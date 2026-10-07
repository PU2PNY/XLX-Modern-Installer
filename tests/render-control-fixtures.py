#!/usr/bin/env python3
"""Render disposable Control views; never deploy these authentication stubs."""
import argparse
from pathlib import Path
import re
import subprocess

p=argparse.ArgumentParser();p.add_argument('--output',required=True,type=Path);args=p.parse_args()
root=Path(__file__).resolve().parents[1];work=args.output.resolve()
work.mkdir(parents=True,exist_ok=True)
cfg=work/'config.php'
cfg.write_text("<?php return ['username'=>'fixture','password_hash'=>'fixture_only','expected_core_sha'=>'fixture','expected_core_version'=>'2.5.3','base_url'=>'https://xlx123.example.org','title'=>'Control XLX123','admin_slug'=>'private-control'];")
source=(root/'control/current-production-admin.php').read_text()
source=source.replace("const CFG='/etc/xlx-modern-control/config.php';", "const CFG='"+str(cfg)+"';")
source=source.replace("const STATE='/var/lib/xlx-modern-control';","const STATE='"+str(work)+"';")
source=re.sub(r'function auth\(\):bool\{[^\n]*\}', 'function auth():bool{return ($GLOBALS["argv"][1]??"")!=="login";}', source)
start=source.index('function runh(');end=source.index('function kv(',start)
source=source[:start]+'''function runh(string $c,array $args=[]):array{
 if($c==='status')return[true,"service=active\\nversion=2.5.3\\npid=12345\\nsha=fixture",0];
 if($c==='health-status')return[true,json_encode(['ok'=>true,'generated_at'=>'fixture','xlxd'=>['service_active'=>true],'capability_matrix'=>['items'=>[]]]),0];
 if($c==='radioid-status')return[true,json_encode(['ok'=>true,'records'=>10,'integrity'=>'ok']),0];
 if($c==='access-status')return[true,json_encode(['ok'=>true,'whitelist'=>['N0CALL'],'blacklist'=>[],'interlinks'=>[]]),0];
 return[true,'Fixture data',0];
}
'''+source[end:]
start=source.index('function probe(');end=source.index('function bytesv(',start)
source=source[:start]+'''function probe(string $url):array{return[200,json_encode(['ok'=>true,'ai_monitor'=>['configured'=>false,'api_connected'=>false,'state'=>'ready']]),0];}
'''+source[end:]
source=source.replace("declare(strict_types=1);","declare(strict_types=1);\n$_SERVER['REQUEST_METHOD']='GET';$_GET['view']=$argv[1]??'home';")
for locale in ['pt-BR','en','es','fr','de','it']:
 fixture=work/(locale+'.php');fixture.write_text(source)
 subprocess.run(['python3',str(root/'control/build-admin.py'),str(fixture),locale],check=True)
 for view in ['home','health','access','radioid','login']:
  result=subprocess.run(['php',str(fixture),view],capture_output=True,text=True,check=True)
  if 'Fatal error' in result.stdout or 'Warning:' in result.stdout:raise RuntimeError(result.stdout[:200])
  html=result.stdout
  if view!='login':
   assert 'Control XLX123' in html and '/private-control/' in html
   for target in ['home','health','access','radioid']:
    route='/private-control/'+('' if target=='home' else '?view='+target)
    html=html.replace('href="'+route+'"','href="'+locale+'-'+target+'.html"')
  (work/(locale+'-'+view+'.html')).write_text(html)
print('CONTROL_FIXTURES=PASS (30 PHP renders; disposable service/auth fixtures)')
