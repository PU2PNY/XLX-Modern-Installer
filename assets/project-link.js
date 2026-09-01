(() => {
  'use strict';

  const REPO = 'https://github.com/PU2PNY/XLX-Modern-Installer/tree/dashboard-only';
  const labels = {
    'pt': 'Código-fonte e documentação do painel no GitHub',
    'en': 'Dashboard source code and documentation on GitHub',
    'es': 'Código fuente y documentación del panel en GitHub',
    'fr': 'Code source et documentation du tableau de bord sur GitHub',
    'de': 'Dashboard-Quellcode und Dokumentation auf GitHub',
    'it': 'Codice sorgente e documentazione del pannello su GitHub'
  };

  function start() {
    if (document.querySelector('[data-xlx-project-link]')) return;

    const lang = String(document.documentElement.lang || 'en').slice(0, 2).toLowerCase();
    const text = labels[lang] || labels.en;
    const host = document.querySelector('footer') || document.querySelector('main') || document.body;

    const wrap = document.createElement('div');
    wrap.dataset.xlxProjectLink = '1';
    wrap.className = 'xlx-project-link';
    wrap.innerHTML = `<a href="${REPO}" target="_blank" rel="noopener noreferrer" aria-label="${text}">↗ GitHub · ${text}</a>`;

    const style = document.createElement('style');
    style.textContent = `
      .xlx-project-link{width:100%;box-sizing:border-box;margin:18px auto 0;padding:10px 14px;text-align:center;font-size:12px;line-height:1.4;opacity:.9}
      .xlx-project-link a{display:inline-flex;align-items:center;gap:6px;color:inherit;text-decoration:none;border:1px solid rgba(80,190,230,.28);border-radius:999px;padding:7px 11px;background:rgba(5,25,36,.55)}
      .xlx-project-link a:hover,.xlx-project-link a:focus-visible{opacity:1;text-decoration:underline;outline:none}
    `;
    document.head.appendChild(style);
    host.appendChild(wrap);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start, { once: true });
  } else {
    start();
  }
})();
