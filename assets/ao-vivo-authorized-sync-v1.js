/* XLX Modern — compatibilidade visual da página Ao Vivo */
(() => {
  'use strict';

  if (window.__XLX_AUTHORIZED_SYNC_V2__) return;
  window.__XLX_AUTHORIZED_SYNC_V2__ = true;

  /*
   * O app.js atual já usa api/status.php?history_hours=24 e já implementa:
   * - agrupamento por indicativo;
   * - submenu das transmissões anteriores;
   * - numeração hierárquica;
   * - Status Online/Offline;
   * - Horário TX e Tempo de TX.
   *
   * Não sobrescrever historyMarkup() aqui. A antiga compatibilidade V1 usava
   * a assinatura anterior de historyRowMarkup() e quebrava exatamente essas
   * funções no painel publicado.
   */

  /*
   * Mantém somente a correção visual do indicativo no box TX.
   * Ex.: PU2PNY D -> PU2PNY-D, sem alterar os dados recebidos da API.
   */
  function normalizeLiveCallsign(raw) {
    const txt = String(raw || '')
      .replace(/\s+/g, ' ')
      .trim()
      .toUpperCase();

    if (!txt) return '';

    const match = txt.match(/^([A-Z0-9\/]+)\s+([A-Z])$/);
    if (match) return match[1] + '-' + match[2];

    return txt;
  }

  function fixLiveTxCard() {
    if (!document.body || document.body.dataset.page !== 'ao-vivo') return;

    const grid = document.getElementById('moduleGrid');
    if (!grid) return;

    grid
      .querySelectorAll('.tx-card.live .callsign, .tx-card.live .tx-v30-callsign')
      .forEach(el => {
        const current = String(el.textContent || '')
          .replace(/\s+/g, ' ')
          .trim()
          .toUpperCase();

        const fixed = normalizeLiveCallsign(current);
        if (fixed && fixed !== current) el.textContent = fixed;

        el.style.whiteSpace = 'nowrap';
        el.style.wordBreak = 'normal';
        el.style.overflowWrap = 'normal';
      });
  }

  function startCallsignFix() {
    const grid = document.getElementById('moduleGrid');
    if (!grid) return;

    let scheduled = false;
    const scheduleFix = () => {
      if (scheduled) return;
      scheduled = true;
      window.requestAnimationFrame(() => {
        scheduled = false;
        fixLiveTxCard();
      });
    };

    fixLiveTxCard();

    const observer = new MutationObserver(scheduleFix);
    observer.observe(grid, {
      childList: true,
      subtree: true,
      characterData: true,
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', startCallsignFix, { once: true });
  } else {
    startCallsignFix();
  }
})();
