import importlib.util
import io
import pathlib
import tempfile
import unittest
import urllib.error
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[1]/'observability/ai-supervisor'
def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m
m = module('monitor', ROOT/'xlx-ai-monitor.py')
s = module('supervisor', ROOT/'xlx-ai-supervisor.py')

class Response:
    status = 200
    def __enter__(self): return self
    def __exit__(self, *args): pass

class Tests(unittest.TestCase):
    def test_timeout_then_recovery(self):
        with patch.object(m.urllib.request, 'urlopen', side_effect=[TimeoutError(), Response()]) as op, patch.object(m.time, 'sleep'):
            self.assertTrue(m.validate_key('test')[0])
            self.assertEqual(op.call_count, 2)

    def test_auth_no_retry(self):
        err = urllib.error.HTTPError('https://test', 401, 'x', {}, io.BytesIO())
        with patch.object(m.urllib.request, 'urlopen', side_effect=err) as op:
            self.assertEqual(m.validate_key('test')[2], 'http_401')
            self.assertEqual(op.call_count, 1)

    def test_rate_limit(self):
        err = urllib.error.HTTPError('https://test', 429, 'x', {'Retry-After': '3600'}, io.BytesIO())
        with patch.object(m.urllib.request, 'urlopen', side_effect=err) as op:
            self.assertEqual(m.validate_key('test')[3], 3600)
            self.assertEqual(op.call_count, 1)

    def test_failures_do_not_claim_connection(self):
        with patch.object(m.urllib.request, 'urlopen', side_effect=TimeoutError()), patch.object(m.time, 'sleep'):
            self.assertFalse(m.validate_key('test')[0])

    def test_healthy_skip_external_call(self):
        with tempfile.TemporaryDirectory() as td, patch.object(m, 'PUBLIC', pathlib.Path(td)/'public.json'), patch.dict(m.os.environ, {'OPENAI_API_KEY': 'test'}), patch.object(m, 'validate_key') as validate:
            m.atomic_json(m.PUBLIC, {'next_probe_at': int(m.time.time())+900})
            self.assertEqual(m.main(), 0)
            validate.assert_not_called()

    def test_recovery_permissions(self):
        for service in ('xlxd.service', 'xlx-unified-voice.service', 'nginx.service', 'ssh.service', 'arbitrary.service'):
            self.assertFalse(s.recovery_allowed(service, 'failed', 2, 0, 0, 5000))
        name = 'xlx026-live-hub.service'
        self.assertTrue(s.recovery_allowed(name, 'failed', 1, 0, 0, 5000))
        for status in ('active', 'inactive', 'unknown', 'activating'):
            self.assertFalse(s.recovery_allowed(name, status, 2, 0, 0, 5000))
        self.assertFalse(s.recovery_allowed(name, 'failed', 0, 0, 0, 5000))
        self.assertFalse(s.recovery_allowed(name, 'failed', 2, 4900, 0, 5000))
        self.assertFalse(s.recovery_allowed(name, 'failed', 2, 0, 3, 5000))

    def test_end_to_end_recovery_and_ai_separation(self):
        with tempfile.TemporaryDirectory() as td, patch.object(s, 'RUNTIME', pathlib.Path(td)/'run'), patch.object(s, 'STATE', pathlib.Path(td)/'state.json'), patch.object(s, 'local_health', return_value={'services': {'xlx026-live-hub.service': 'failed'}, 'disk_used_pct': 10, 'memory_used_pct': 20, 'load_per_cpu': 0.1}), patch.object(s, 'command', return_value=(0, '')) as command, patch.object(s, 'service_status', return_value='active'), patch.object(s, 'analyze', return_value=(True, 'systemctl restart xlxd.service')) as ai:
            s.main()
            command.assert_not_called()
            s.main()
            self.assertEqual(command.call_args.args[0], ['/usr/bin/systemctl', 'start', 'xlx026-live-hub.service'])
            self.assertEqual(command.call_count, 1)
            self.assertEqual(ai.call_count, 1)
            s.main()
            self.assertEqual(command.call_count, 1)
            self.assertEqual(ai.call_count, 1)

if __name__ == '__main__': unittest.main()
