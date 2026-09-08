/* XLX Modern — XLXMODERN validated live/history identity synchronization. */
(() => {
  'use strict';
  if (window.__XLX_AUTHORIZED_SYNC_V15B__) return;
  window.__XLX_AUTHORIZED_SYNC_V15B__ = true;

  historyStatusMarkup = function (x) {
    if (Boolean(x && x.online)) return '<span class="state-pill online">Online</span>';
    const call = xlxmodernBaseCall((x && x.callsign) || '');
    const gateway = xlxmodernBaseCall((x && x.gateway) || '');
    const source = String((x && x.identity_source) || '').trim();
    const linked = call !== '' && gateway !== '' && call !== gateway && source.indexOf('xlxd-station') === 0;
    if (linked) {
      const title = `Operador ouvido através de ${gateway}`;
      return `<span class="state-pill link" title="${esc(title)}" aria-label="${esc(title)}"><i aria-hidden="true"></i>Link</span>`;
    }
    return '<span class="state-pill offline">Offline</span>';
  };

  /* Never display Via/Peer as the gateway unless STATION proved the relation. */
  hotspotRepeaterMarkup = function (x) {
    const callsign = xlxmodernBaseCall((x && x.callsign) || '');
    const source = String((x && x.identity_source) || '').trim();
    const stationIdentity = source.indexOf('xlxd-station') === 0;
    const raw = String(stationIdentity ? ((x && x.gateway) || '') : ((x && x.network_callsign) || (x && x.callsign) || '')).trim();
    const normalized = raw.toUpperCase();
    const gatewayCall = xlxmodernBaseCall(raw);
    const unknown = !raw || normalized === 'NÃO IDENTIFICADO' || normalized === 'GATEWAY NÃO IDENTIFICADO' || normalized === 'HOTSPOT / REPETIDORA NÃO IDENTIFICADO';
    if (unknown) return '<span class="hotspot-repeater-empty">—</span>';
    const different = callsign !== '' && gatewayCall !== '' && gatewayCall !== callsign;
    const neon = different ? '<span class="gateway-neon" role="img" aria-label="Usando hotspot ou repetidora diferente do indicativo" title="Usando hotspot ou repetidora diferente do indicativo"></span>' : '';
    return `<span class="gateway-display${different ? ' gateway-different' : ''}">${neon}<span class="gateway-value">${esc(gatewayCall || raw)}</span></span>`;
  };

  historyRowMarkup = function (x, options = {}) {
    const { statusHtml = '', toggleHtml = '', attrs = '', position = '' } = options;
    const rowNumber = position === '' ? '↳' : esc(position);
    const operator = operatorDisplay(x);
    const operatorCall = esc(operator.callsign);
    const operatorHtml = operator.qrz ? `<a target="_blank" rel="noopener" href="${esc(operator.qrz)}">${operatorCall}</a>` : `<span class="operator-unresolved" title="O gateway ainda não informou o operador">${operatorCall}</span>`;
    return `<tr ${attrs}>
      <td class="history-number-cell"><span class="history-number-wrap"><span class="history-row-number" aria-hidden="true">${rowNumber}</span>${toggleHtml}</span></td>
      <td class="history-country-cell"><span class="history-country-final">${flag(x)}</span></td>
      <td class="history-status-cell">${statusHtml}</td>
      <td class="history-callsign-cell">${operatorHtml}</td>
      <td>${esc(operator.name)}</td>
      <td class="history-hotspot-cell">${hotspotRepeaterMarkup(x)}</td>
      <td>${esc(x.location || 'Não informada')}</td>
      <td><span class="protocol">${esc(x.protocol)}</span></td>
      <td>${esc(x.module)}</td>
      <td class="history-duration-cell"><span class="history-duration-value">${duration(x.duration)}</span></td>
    </tr>`;
  };

  function installHistoryStyles() {
    if (document.getElementById('xlxModernIdentityLinkV15bStyles')) return;
    const style = document.createElement('style');
    style.id = 'xlxModernIdentityLinkV15bStyles';
    style.textContent = `
      body[data-page='ao-vivo'] .state-pill.link{display:inline-flex;align-items:center;justify-content:center;gap:4px;border:1px solid rgba(255,202,40,.78);background:rgba(255,202,40,.08);color:#ffd65a;box-shadow:0 0 9px rgba(255,202,40,.12);white-space:nowrap}
      body[data-page='ao-vivo'] .state-pill.link i{display:inline-block;width:5px;height:5px;border-radius:50%;background:#ffd24a;box-shadow:0 0 7px rgba(255,210,74,.65)}
      body[data-page='ao-vivo'] table.home-history{table-layout:fixed;width:100%}
      body[data-page='ao-vivo'] table.home-history th:nth-child(1),body[data-page='ao-vivo'] table.home-history td:nth-child(1){width:6%}
      body[data-page='ao-vivo'] table.home-history th:nth-child(2),body[data-page='ao-vivo'] table.home-history td:nth-child(2){width:5%}
      body[data-page='ao-vivo'] table.home-history th:nth-child(3),body[data-page='ao-vivo'] table.home-history td:nth-child(3){width:8%}
      body[data-page='ao-vivo'] table.home-history th:nth-child(4),body[data-page='ao-vivo'] table.home-history td:nth-child(4){width:10%}
      body[data-page='ao-vivo'] table.home-history th:nth-child(5),body[data-page='ao-vivo'] table.home-history td:nth-child(5){width:14%}
      body[data-page='ao-vivo'] table.home-history th:nth-child(6),body[data-page='ao-vivo'] table.home-history td:nth-child(6){width:14%}
      body[data-page='ao-vivo'] table.home-history th:nth-child(7),body[data-page='ao-vivo'] table.home-history td:nth-child(7){width:15%}
      body[data-page='ao-vivo'] table.home-history th:nth-child(8),body[data-page='ao-vivo'] table.home-history td:nth-child(8){width:12%}
      body[data-page='ao-vivo'] table.home-history th:nth-child(9),body[data-page='ao-vivo'] table.home-history td:nth-child(9){width:6%}
      body[data-page='ao-vivo'] table.home-history th:nth-child(10),body[data-page='ao-vivo'] table.home-history td:nth-child(10){width:10%}
      @media(max-width:820px){body[data-page='ao-vivo'] table.home-history{table-layout:auto}}
    `;
    document.head.appendChild(style);
  }

  function normalizeHeader() {
    const row = document.querySelector('body[data-page="ao-vivo"] table.home-history thead tr');
    if (!row) return;
    const labels = ['Nº','País','Status','Indicativo','Nome','Hotspot / Repetidora','Cidade','Protocolo','Módulo','Tempo de transmissão'];
    row.innerHTML = labels.map(label => `<th>${esc(label)}</th>`).join('');
  }

  function keepLiveCallsignWithoutSuffix() {
    const grid = document.getElementById('moduleGrid');
    if (!grid) return;
    grid.querySelectorAll('.tx-card.live .callsign, .tx-card.live .tx-v30-callsign').forEach(el => {
      const raw = String(el.textContent || '').replace(/\s+/g, ' ').trim().toUpperCase();
      const base = raw.split(' ')[0] || raw;
      if (base && raw !== base) el.textContent = base;
      el.style.whiteSpace = 'nowrap';
      el.style.wordBreak = 'normal';
      el.style.overflowWrap = 'normal';
    });
  }

  function start() {
    installHistoryStyles();
    normalizeHeader();
    keepLiveCallsignWithoutSuffix();
    const grid = document.getElementById('moduleGrid');
    if (!grid) return;
    const observer = new MutationObserver(() => window.requestAnimationFrame(keepLiveCallsignWithoutSuffix));
    observer.observe(grid, { childList: true, subtree: true, characterData: true });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, { once: true });
  else start();
})();
