from pathlib import Path
import importlib.util
import os

os.environ['XLX_WEB_TOKEN'] = 'test-token-1234567890'
os.environ['XLX_REPO_ROOT'] = str(Path(__file__).resolve().parents[1])

spec = importlib.util.spec_from_file_location('xlx_web_server', Path(__file__).with_name('server.py'))
module = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(module)


def sample_payload():
    return module.InstallPayload(
        ui_lang='pt-BR', reflector_id='PNY', domain='xlx026.net', email='sysop@example.net', callsign='PU2PNY',
        country='Brazil', timezone='America/Sao_Paulo', location='Santa Isabel - SP', https=True, echo=True,
        modules=5, ysf_port=42000, ysf_freq=433125000, autolink=True, autolink_module='C', ysf_id='12345',
        admin_user='pu2pny', admin_slug='controle-pny', admin_password='ExampleOnly-123!', dashboard_lang='pt-BR')


def test_answer_sequence():
    data = module.normalize_and_validate(sample_payload())
    answers = module.build_answers(data)
    assert len(answers) == 24
    assert answers[0] == 'PNY'
    assert answers[1] == 'xlx026.net'
    assert answers[18] == '12345'
    assert answers[-1] == ''


def test_invalid_xlx_id_rejected():
    payload = sample_payload()
    payload.reflector_id = '12345'
    try:
        module.normalize_and_validate(payload)
    except Exception as exc:
        assert getattr(exc, 'status_code', None) == 422
    else:
        raise AssertionError('invalid 5-character XLX ID was accepted')


def test_progress_mapping():
    progress, stage = module.progress_from_line('INSTALLING XLX MODERN DASHBOARD', 1, 'en')
    assert progress == 68
    assert stage == 'Installing dashboard'


def test_static_assets_present():
    static = Path(__file__).with_name('static')
    for name in ('index.html', 'app.css', 'app.js'):
        assert (static / name).is_file()
