'use strict';
/* XLX_CERTIFICATE_MENU_V1 */
(() => {
  const language = String(document.documentElement.lang || 'pt-BR').toLowerCase();
  const labels = {en:'Certificate',es:'Certificado',fr:'Certificat',de:'Zertifikat',it:'Certificato'};
  const key = language.split('-')[0];
  const label = labels[key] || 'Certificado';

  function addLink(container) {
    if (!container || container.querySelector('a[data-xlx-certificate-link]')) return;
    const link = document.createElement('a');
    link.href = 'certificado.php';
    link.textContent = label;
    link.dataset.xlxCertificateLink = '1';
    container.appendChild(link);
  }

  function init() {
    addLink(document.querySelector('nav.universal-nav'));
    addLink(document.querySelector('.footer-links'));
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init, {once:true});
  else init();
})();
