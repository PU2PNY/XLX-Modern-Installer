/* XLX Modern — XLX026 validated identity/history synchronization. */
(function(){
 'use strict';

 historyStatusMarkup=function(x){
  if(Boolean(x&&x.online)){
   return '<span class="state-pill online">Online</span>';
  }

  const call=xlx026BaseCall((x&&x.callsign)||'');
  const gateway=xlx026BaseCall((x&&x.gateway)||'');
  const source=String((x&&x.identity_source)||'').trim();
  const linked=call!==''&&gateway!==''&&call!==gateway&&source.indexOf('xlxd-station')===0;

  if(linked){
   const title=`Operador ouvido através de ${gateway}`;
   return `<span class="state-pill link" title="${esc(title)}" aria-label="${esc(title)}"><i aria-hidden="true"></i>Link</span>`;
  }

  return '<span class="state-pill offline">Offline</span>';
 };

 historyRowMarkup=function(x,options={}){
  const {statusHtml='',toggleHtml='',attrs='',position=''}=options;
  const rowNumber=position===''?'↳':esc(position);
  const operator=operatorDisplay(x);
  const operatorCall=esc(operator.callsign);
  const operatorHtml=operator.qrz
   ?`<a target="_blank" rel="noopener" href="${esc(operator.qrz)}">${operatorCall}</a>`
   :`<span class="operator-unresolved" title="O gateway ainda não informou o operador">${operatorCall}</span>`;

  return `<tr ${attrs}>
   <td class="history-number-cell"><span class="history-number-wrap"><span class="history-row-number" aria-hidden="true">${rowNumber}</span>${toggleHtml}</span></td>
   <td class="history-country-cell"><span class="history-country-final">${flag(x)}</span></td>
   <td class="history-status-cell">${statusHtml}</td>
   <td class="history-callsign-cell">${operatorHtml}</td>
   <td>${esc(operator.name)}</td>
   <td class="history-hotspot-cell">${hotspotRepeaterMarkup(x)}</td>
   <td>${esc(x.location||'Não informada')}</td>
   <td><span class="protocol">${esc(x.protocol)}</span></td>
   <td>${esc(x.module)}</td>
   <td class="history-duration-cell"><span class="history-duration-value">${duration(x.duration)}</span></td>
  </tr>`;
 };
})();
