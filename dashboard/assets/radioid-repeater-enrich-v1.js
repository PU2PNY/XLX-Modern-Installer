/* XLXMODERN_RADIOID_REPEATER_POPUP_V1 */
(()=>{
 'use strict';
 const cache=new Map();
 const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
 const baseCall=v=>String(v||'').trim().toUpperCase().split(/\s+/)[0].replace(/[^A-Z0-9]/g,'');
 const valid=c=>/^[A-Z0-9]{3,10}$/.test(c);
 async function get(call){
  call=baseCall(call); if(!valid(call))return null;
  if(cache.has(call))return cache.get(call);
  const p=fetch(`/api/repeater.php?callsign=${encodeURIComponent(call)}`,{cache:'no-store',headers:{Accept:'application/json'}})
   .then(r=>r.json()).then(j=>j&&j.ok?j.repeater:null).catch(()=>null);
  cache.set(call,p); return p;
 }
 function findCall(el){
  const raw=el.querySelector('.gateway-value')?.textContent||'';
  return baseCall(raw);
 }
 function isProven(el){
  const row=el.closest('tr');
  if(row){
   const link=row.querySelector('.history-link-badge');
   return Boolean(link);
  }
  const card=el.closest('.tx-card');
  if(card){
   const call=baseCall(card.querySelector('.callsign,.tx-v30-callsign')?.textContent||'');
   const gw=findCall(el);
   return Boolean(call&&gw&&call!==gw);
  }
  return false;
 }
 async function hydrate(el){
  if(!(el instanceof Element)||el.dataset.radioidHydrated==='1'||!el.classList.contains('gateway-different'))return;
  if(!isProven(el))return;
  const call=findCall(el); if(!valid(call))return;
  el.dataset.radioidHydrated='1'; el.dataset.repeaterCall=call;
  const r=await get(call); if(!r)return;
  el.classList.add('gateway-radioid-ready');
  let extra=el.querySelector('.gateway-extra');
  if(!extra){extra=document.createElement('small');extra.className='gateway-extra';el.append(extra)}
  const bits=[];
  if(r.frequency)bits.push(`${r.frequency} MHz`);
  const place=[r.city,r.state].filter(Boolean).join(' / ');
  if(place)bits.push(place);
  extra.textContent=bits.join(' · ');
  el.setAttribute('role','button');el.setAttribute('tabindex','0');
  el.setAttribute('aria-label',`Ver dados da repetidora ${call}`);
  el.title=`Ver dados da repetidora ${call}`;
 }
 function hydrateAll(root=document){
  root.querySelectorAll?.('.gateway-display.gateway-different').forEach(hydrate);
 }
 function ensureModal(){
  let m=document.getElementById('xlxRepeaterModal'); if(m)return m;
  m=document.createElement('div');m.id='xlxRepeaterModal';m.className='repeater-modal';m.hidden=true;
  m.innerHTML='<div class="repeater-modal-card" role="dialog" aria-modal="true" aria-labelledby="xlxRepeaterTitle"><button class="repeater-modal-close" type="button" aria-label="Fechar">×</button><div id="xlxRepeaterBody"></div></div>';
  document.body.append(m);
  m.addEventListener('click',e=>{if(e.target===m||e.target.closest('.repeater-modal-close'))closeModal()});
  document.addEventListener('keydown',e=>{if(e.key==='Escape'&&!m.hidden)closeModal()});
  return m;
 }
 function closeModal(){const m=document.getElementById('xlxRepeaterModal');if(m)m.hidden=true}
 function row(label,value){if(value===null||value===undefined||String(value).trim()==='')return'';return `<div class="repeater-detail-row"><span>${esc(label)}</span><strong>${esc(value)}</strong></div>`}
 async function openModal(el){
  const call=el.dataset.repeaterCall||findCall(el); const r=await get(call); if(!r)return;
  const m=ensureModal(),b=m.querySelector('#xlxRepeaterBody');
  const place=[r.city,r.state,r.country].filter(Boolean).join(' / ');
  const trustee=Array.isArray(r.trustee)?r.trustee.join(', '):'';
  const updated=r.fetched_at?new Date(Number(r.fetched_at)*1000).toLocaleString('pt-BR'):'';
  b.innerHTML=`<div class="repeater-modal-head"><small>HOTSPOT / REPETIDORA IDENTIFICADA</small><h2 id="xlxRepeaterTitle">${esc(r.callsign||call)}</h2>${place?`<p>${esc(place)}</p>`:''}</div><div class="repeater-detail-grid">${row('Frequência',r.frequency?`${r.frequency} MHz`:'')}${row('Offset',r.offset?`${r.offset} MHz`:'')}${row('Color Code',r.color_code)}${row('Status',r.status)}${row('Rede / Modos',r.network)}${row('Cobertura',r.coverage)}${row('Responsável',trustee)}</div><div class="repeater-source"><strong>Fonte da informação:</strong> <a href="${esc(r.source_url||'https://radioid.net/')}" target="_blank" rel="noopener noreferrer">${esc(r.source||'RadioID.net')}</a>${updated?`<br><span>Última consulta: ${esc(updated)}</span>`:''}${r.cache==='stale'?'<br><span>Exibindo último cache disponível.</span>':''}</div>`;
  m.hidden=false;m.querySelector('.repeater-modal-close')?.focus();
 }
 document.addEventListener('click',e=>{const el=e.target.closest('.gateway-display.gateway-radioid-ready');if(el){e.preventDefault();openModal(el)}});
 document.addEventListener('keydown',e=>{const el=e.target.closest?.('.gateway-display.gateway-radioid-ready');if(el&&(e.key==='Enter'||e.key===' ')){e.preventDefault();openModal(el)}});
 new MutationObserver(ms=>ms.forEach(m=>m.addedNodes.forEach(n=>{if(n.nodeType===1){if(n.matches?.('.gateway-display.gateway-different'))hydrate(n);hydrateAll(n)}}))).observe(document.documentElement,{childList:true,subtree:true});
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>hydrateAll());else hydrateAll();
})();
