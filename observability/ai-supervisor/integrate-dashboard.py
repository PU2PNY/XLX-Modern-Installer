#!/usr/bin/env python3
"""Apply a narrow integration to the known production V1 indicator. Back up first."""
import pathlib
import sys

def integrate(root):
    status = root/'api/status.php'
    app = root/'assets/app.js'
    php, js = status.read_text(), app.read_text()
    marker = '/* XLX_AI_SUPERVISOR_V1 */'
    if marker in php and '/* XLX_AI_SUPERVISOR_V1 */' in js: return
    anchor = 'function xlx026_ai_monitor_public_status(): array\n{\n'
    extra = '''    /* XLX_AI_SUPERVISOR_V1 */
    $supervisor = null;
    $supervisorPath = '/run/xlx-ai-supervisor/public.json';
    clearstatcache(true, $supervisorPath);
    if (is_readable($supervisorPath) && filesize($supervisorPath) <= 16384) {
        $s = json_decode((string)@file_get_contents($supervisorPath), true);
        if (is_array($s) && abs(time() - (int)($s['updated_at'] ?? 0)) <= 180) {
            $supervisor = [
                'local_supervision' => !empty($s['local_supervision']),
                'ai_ok' => !empty($s['ai_ok']),
                'ai_last_analysis_at' => (int)($s['ai_last_analysis_at'] ?? 0),
                'ai_summary' => substr((string)($s['ai_summary'] ?? ''), 0, 900),
            ];
        }
    }
'''
    assert php.count(anchor) == 1, 'Unknown PHP contract'
    old_return = "        'last_action' => $action,\n    ];"
    assert php.count(old_return) == 1, 'Unknown PHP return'
    php = php.replace(anchor, anchor+extra).replace(old_return,
        "        'last_action' => $action,\n        'supervisor' => $supervisor,\n    ];")
    anchor_js = "  }else if(configured&&connected){\n   css='is-monitoring';primary='OPENAI';text='conectada';"
    extra_js = """  /* XLX_AI_SUPERVISOR_V1 */
  }else if(configured&&connected&&ai.supervisor?.local_supervision&&ai.supervisor?.ai_ok&&Number(ai.supervisor?.ai_last_analysis_at)>0&&Math.abs(Date.now()/1000-Number(ai.supervisor.ai_last_analysis_at))<=7200){
   css='is-monitoring';primary='IA';text='supervisionando';
   title='Última análise: '+new Date(Number(ai.supervisor.ai_last_analysis_at)*1000).toLocaleString()+' • '+String(ai.supervisor.ai_summary||'Supervisão técnica ativa.');
"""
    assert js.count(anchor_js) == 1, 'Unknown JS contract'
    js = js.replace(anchor_js, extra_js+anchor_js)
    js = js.replace("primary='OPENAI';text='reconectando';", "primary='OPENAI';text='indisponível';")
    status.write_text(php)
    app.write_text(js)

if __name__ == '__main__': integrate(pathlib.Path(sys.argv[1]))
