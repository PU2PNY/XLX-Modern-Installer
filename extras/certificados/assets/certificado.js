'use strict';
(() => {
  const cfg = window.XLX_CERT || {};
  const $ = selector => document.querySelector(selector);
  const input = $('#certCallsign');
  const search = $('#certSearch');
  const message = $('#certMessage');
  const preview = $('#certPreview');
  const actions = $('#certActions');
  const issue = $('#certIssue');
  const print = $('#certPrint');
  let current = null;

  const setMessage = (text, type = '') => {
    message.textContent = text;
    message.className = 'cert-message' + (type ? ' ' + type : '');
  };
  const call = () => String(input.value || '').toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 12);
  const seconds = value => {
    value = Math.max(0, Number(value) || 0);
    const h = Math.floor(value / 3600);
    const m = Math.floor((value % 3600) / 60);
    const s = Math.floor(value % 60);
    if (h) return `${h}h ${m}min`;
    if (m) return `${m}min ${s}s`;
    return `${s}s`;
  };
  const escText = value => String(value ?? '').trim();

  function fillOperator(operator) {
    current = operator;
    $('#certName').textContent = escText(operator.name) || 'Radioamador';
    $('#certCall').textContent = escText(operator.callsign);
    $('#certText').textContent = `${escText(operator.name) || escText(operator.callsign)} participou das atividades de ${cfg.reflector?.title || cfg.reflector?.name || 'este refletor'} durante ${cfg.campaign?.title || 'a campanha vigente'}, contribuindo para a comunicação e a integração da comunidade radioamadora.`;
    $('#statTx').textContent = operator.stats?.transmissions ?? 0;
    $('#statTime').textContent = seconds(operator.stats?.duration_total);
    $('#statModes').textContent = (operator.stats?.protocols || []).join(' • ') || '—';
    $('#certId').textContent = 'Aguardando emissão';
    $('#certIssued').textContent = '';
    $('#certQr').replaceChildren();
    preview.hidden = false;
    actions.hidden = false;
    issue.disabled = false;
    print.disabled = true;
  }

  async function lookup() {
    const callsign = call();
    input.value = callsign;
    if (callsign.length < 3) {
      setMessage('Digite um indicativo válido.', 'error');
      return;
    }
    search.disabled = true;
    setMessage('Consultando a atividade registrada...');
    try {
      const response = await fetch(`${cfg.api}?action=lookup&callsign=${encodeURIComponent(callsign)}&_=${Date.now()}`, {cache: 'no-store'});
      const data = await response.json();
      if (!response.ok || !data.ok) throw new Error(data.error || 'lookup_failed');
      if (!data.operator?.eligible) {
        current = null;
        preview.hidden = true;
        actions.hidden = true;
        setMessage('Ainda não há transmissão elegível deste indicativo na campanha atual.', 'error');
        return;
      }
      fillOperator(data.operator);
      setMessage('Participação encontrada. Você pode emitir o certificado.', 'ok');
    } catch (error) {
      setMessage('Não foi possível consultar o certificado neste momento.', 'error');
    } finally {
      search.disabled = false;
    }
  }

  async function issueCertificate() {
    if (!current) return;
    issue.disabled = true;
    setMessage('Emitindo e registrando certificado...');
    const body = new URLSearchParams({action: 'issue', callsign: current.callsign});
    try {
      const response = await fetch(cfg.api, {
        method: 'POST',
        headers: {'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8'},
        body: body.toString(),
        cache: 'no-store'
      });
      const data = await response.json();
      if (!response.ok || !data.ok || !data.certificate) throw new Error(data.error || 'issue_failed');
      const cert = data.certificate;
      $('#certId').textContent = cert.id;
      $('#certIssued').textContent = 'Emitido em ' + new Date((Number(cert.issued_at) || 0) * 1000).toLocaleString();
      const img = document.createElement('img');
      img.alt = 'QR Code de validação do certificado';
      img.src = `${cfg.api}?action=qr&id=${encodeURIComponent(cert.id)}&sig=${encodeURIComponent(cert.signature)}`;
      $('#certQr').replaceChildren(img);
      print.disabled = false;
      setMessage(data.reused ? 'Este certificado já existia e foi recuperado.' : 'Certificado emitido e registrado com sucesso.', 'ok');
    } catch (error) {
      issue.disabled = false;
      setMessage('Não foi possível emitir o certificado.', 'error');
    }
  }

  input.addEventListener('input', () => { input.value = call(); });
  input.addEventListener('keydown', event => { if (event.key === 'Enter') lookup(); });
  search.addEventListener('click', lookup);
  issue.addEventListener('click', issueCertificate);
  print.addEventListener('click', () => window.print());
})();
