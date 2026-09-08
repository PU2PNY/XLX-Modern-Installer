const $=s=>document.querySelector(s);let previousConnections=null,lastData=null;const page=document.body.dataset.page||'ao-vivo';
const historyExpandedCalls=new Set();
const reflectorName=String(document.body.dataset.reflector||'XLX').trim().toUpperCase();
const fmtTime=ts=>ts?new Date(ts*1000).toLocaleTimeString('pt-BR',{hour:'2-digit',minute:'2-digit',second:'2-digit'}):'—';
const elapsed=ts=>{if(!ts)return'—';let s=Math.max(0,Math.floor(Date.now()/1000-ts)),d=Math.floor(s/86400);s%=86400;let h=Math.floor(s/3600);s%=3600;let m=Math.floor(s/60);s%=60;return(d?d+'d ':'')+String(h).padStart(2,'0')+'h '+String(m).padStart(2,'0')+'m '+String(s).padStart(2,'0')+'s'};
const duration=s=>{s=Number(s||0);const h=Math.floor(s/3600),m=Math.floor((s%3600)/60),sec=s%60;return(h?h+'h ':'')+String(m).padStart(2,'0')+':'+String(sec).padStart(2,'0')};
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const flag=x=>{
 const country=x?.country||{};
 const name=country.name||'País não identificado';
 const code=String(country.code||'').trim().toLowerCase();
 if(!/^[a-z]{2}$/.test(code)){
  return `<span class="flag" title="${esc(name)}">🌐</span>`;
 }
 return `<span class="flag" title="${esc(name)}"><img src="/flags/${esc(code)}.png" alt="Bandeira de ${esc(name)}" width="24" height="16" loading="lazy" decoding="async" style="display:inline-block;width:24px;height:16px;object-fit:cover;vertical-align:middle;border-radius:2px"></span>`;
};
const onlineBadge = online => `<span class="state-pill ${online?'online':'offline'}">${online?'Online':'Offline'}</span>`;
const xlxmodernQrzPhotoCache=new Map();
function xlxmodernSyncQrzPhotoSizes(root=document){
 const grid=document.getElementById('moduleGrid');
 if(!grid)return;
 const cards=[...grid.querySelectorAll('.tx-card.live.tx-v30')];
 const count=Math.max(1,Math.min(3,cards.length||1));
 const desktop=window.innerWidth>=721;
 const px=desktop?({1:120,2:96,3:80}[count]):72;

 grid.querySelectorAll('.tx-v30-person').forEach(person=>{
  person.classList.remove('qrz-one-tx-layout');
  ['display','grid-template-columns','gap','align-items','position','width'].forEach(k=>person.style.removeProperty(k));
  const data=person.querySelector('.tx-v30-person-data');
  if(data){
   ['padding-right','margin','min-width','position','z-index'].forEach(k=>data.style.removeProperty(k));
  }
 });

 grid.querySelectorAll('.operator-visual').forEach(v=>{
  v.classList.remove('qrz-size-1','qrz-size-2','qrz-size-3');
  if(!v.classList.contains('qrz-photo-active')){
   ['width','height','min-width','min-height','max-width','max-height','position','top','right','bottom','left','transform','margin','z-index'].forEach(k=>v.style.removeProperty(k));
  }
 });

 grid.querySelectorAll('.operator-visual.qrz-photo-active').forEach(v=>{
  v.classList.add(`qrz-size-${count}`);
  ['width','height','min-width','min-height','max-width','max-height'].forEach(k=>v.style.setProperty(k,`${px}px`,'important'));
  const img=v.querySelector('img.is-qrz-photo');
  if(img){
   ['width','height','min-width','min-height','max-width','max-height'].forEach(k=>img.style.setProperty(k,'100%','important'));
   img.style.setProperty('object-fit','cover','important');
   img.style.setProperty('display','block','important');
  }

  if(desktop && count===1){
   const person=v.closest('.tx-v30-person');
   const data=person?.querySelector('.tx-v30-person-data');
   if(person){
    person.classList.add('qrz-one-tx-layout');
    person.style.setProperty('display','grid','important');
    person.style.setProperty('grid-template-columns','132px minmax(0,1fr)','important');
    person.style.setProperty('gap','20px','important');
    person.style.setProperty('align-items','center','important');
    person.style.setProperty('position','relative','important');
    person.style.setProperty('width','100%','important');
   }
   v.style.setProperty('position','relative','important');
   v.style.setProperty('top','auto','important');
   v.style.setProperty('right','auto','important');
   v.style.setProperty('bottom','auto','important');
   v.style.setProperty('left','auto','important');
   v.style.setProperty('transform','none','important');
   v.style.setProperty('margin','0','important');
   v.style.setProperty('z-index','3','important');
   if(data){
    data.style.setProperty('padding-right','0','important');
    data.style.setProperty('margin','0','important');
    data.style.setProperty('min-width','0','important');
    data.style.setProperty('position','relative','important');
    data.style.setProperty('z-index','3','important');
   }
  }
 });
}
function operatorVisual(call=''){
 const c=String(call||'').toUpperCase().replace(/[^A-Z0-9]/g,'');
 const cached=xlxmodernQrzPhotoCache.get(c);
 if(typeof cached==='string'&&cached!==''){
  return `<div class="operator-visual qrz-photo-active"><img class="tx-qrz-photo-target is-qrz-photo" data-qrz-call="${esc(c)}" data-qrz-state="photo" src="${esc(cached)}" alt="Foto pública do QRZ de ${esc(c)}"><span class="signal-ring"></span></div>`;
 }
 return `<div class="operator-visual"><img class="tx-qrz-photo-target" data-qrz-call="${esc(c)}" src="assets/talking-radio.gif" alt="Indicador de transmissão"><span class="signal-ring"></span></div>`
}
async function xlxmodernLoadQrzPhoto(img){
 if(!img||img.dataset.qrzState)return;
 const call=String(img.dataset.qrzCall||'').toUpperCase().replace(/[^A-Z0-9]/g,'');
 if(!call)return;
 img.dataset.qrzState='loading';
 try{
  let result=xlxmodernQrzPhotoCache.get(call);
  if(result===undefined){
   const controller=new AbortController();
   const timer=setTimeout(()=>controller.abort(),5000);
   try{
    const r=await fetch(`/api/qrz-photo.php?callsign=${encodeURIComponent(call)}`,{cache:'no-store',signal:controller.signal});
    result=r.ok?await r.json():null;
   }finally{clearTimeout(timer)}
   const url=result&&result.ok&&result.photo&&result.url?String(result.url):'';
   xlxmodernQrzPhotoCache.set(call,url);
   result=url;
  }
  const url=typeof result==='string'?result:'';
  if(!url){img.dataset.qrzState='fallback';return}
  const fallback='assets/talking-radio.gif';
  img.onerror=()=>{
   img.onerror=null;
   img.src=fallback;
   img.classList.remove('is-qrz-photo');
   {const v=img.closest('.operator-visual');v?.classList.remove('qrz-photo-active','qrz-size-1','qrz-size-2','qrz-size-3');} xlxmodernSyncQrzPhotoSizes();
   img.alt='Indicador de transmissão';
   img.dataset.qrzState='fallback';
   xlxmodernQrzPhotoCache.set(call,'');
  };
  img.onload=()=>{
   img.classList.add('is-qrz-photo');
   img.closest('.operator-visual')?.classList.add('qrz-photo-active'); xlxmodernSyncQrzPhotoSizes();
   img.alt=`Foto pública do QRZ de ${call}`;
   img.dataset.qrzState='photo';
  };
  img.src=url;
 }catch(_e){img.dataset.qrzState='fallback'}
}
function xlxmodernHydrateQrzPhotos(root=document){
 root.querySelectorAll?.('img.tx-qrz-photo-target[data-qrz-call]').forEach(xlxmodernLoadQrzPhoto);
}
function xlxmodernInitQrzPhotoObserver(){
 if(page!=='ao-vivo')return;
 const grid=document.getElementById('moduleGrid');
 if(!grid||grid.dataset.qrzPhotoObserver==='1')return;
 grid.dataset.qrzPhotoObserver='1';
 new MutationObserver(()=>{xlxmodernHydrateQrzPhotos(grid);xlxmodernSyncQrzPhotoSizes(grid)}).observe(grid,{childList:true,subtree:true});
 xlxmodernHydrateQrzPhotos(grid);
 xlxmodernSyncQrzPhotoSizes(grid);
}
setTimeout(xlxmodernInitQrzPhotoObserver,0);
window.addEventListener('resize',()=>xlxmodernSyncQrzPhotoSizes(),{passive:true});
function txCard(m){
/* XLXMODERN_TXCARD_CALLSIGN_SEM_SUFFIX_V13 */

 const tx=m.transmission;
 const countryName=tx.country?.name||'País não informado';
 const gatewayHtml=hotspotRepeaterMarkup(tx);
 const callsign=esc(tx.callsign);

 return `<article class="tx-card live compact-tx tx-v30">
  <div class="tx-top">
   <div>
    <span class="module-badge">MÓDULO ${esc(m.module)} • ${esc(tx.protocol)}</span>
    <h3>Transmitindo agora</h3>
   </div>
   <span class="on-air"><i></i> NO AR</span>
  </div>

  <div class="tx-v30-content">
   <div class="tx-v30-person">
    ${operatorVisual(tx.callsign)}
    <div class="tx-v30-person-data">
     <span class="connected-call-wrap"><a class="tx-v30-callsign" target="_blank" rel="noopener" href="${esc(tx.qrz)}">${callsign}</a>${xlxmodernAprsSatelliteMarkup(tx.callsign)}</span>
     <strong class="tx-v30-name">${esc(tx.name||tx.callsign)}</strong>
     <span class="tx-v30-location">${esc(tx.location||'Localização não informada')}</span>
     <span class="tx-v30-country">${flag(tx)} ${esc(countryName)}</span>
    </div>
   </div>

   <div class="tx-v30-details">
    <div>
     <small>Gateway / Repetidora</small>
     <strong class="tx-hotspot-repeater">${gatewayHtml}</strong>
    </div>

    <div class="tx-v30-protocol-box tx-v30-protocol-box-v2">
     <small>Protocolo em uso</small>
     <strong class="tx-v30-protocol-line tx-v30-protocol-line-v2">
      <span class="tx-v30-protocol-value tx-v30-protocol-value-v2">${esc(tx.protocol)}</span>
     </strong>
    </div>

    <div>
     <small>Tempo transmitindo</small>
     <strong data-start="${tx.started_at}">${elapsed(tx.started_at)}</strong>
    </div>
   </div>
  </div>

  <div class="spectrum">${'<i></i>'.repeat(18)}</div>
 </article>`
}

function standbyCard(m,newest){
 const last=newest||m.last_transmission;
 const callsign=last
  ? `${esc(last.callsign)}${last.suffix?' '+esc(last.suffix):''}`
  : 'Sem transmissão recente';

 const name=last
  ? esc(last.name||'Operador não identificado')
  : 'Aguardando a próxima transmissão';

 return `<article class="tx-card standby compact-tx standby-v30">
  <div class="tx-top">
   <div>
    <span class="module-badge">${esc(reflectorName)} AO VIVO</span>
    <h3>Aguardando transmissão</h3>
   </div>
   <span class="ready"><i></i> STANDBY</span>
  </div>

  <div class="standby-v30-content">
   <div class="radar standby-v30-radar"><span></span><i></i></div>

   <div class="standby-v30-state">Servidor em espera</div>

   <div class="standby-v30-last">
    <small>Última transmissão</small>
    <strong>${callsign}</strong>
    <span>${name}</span>
   </div>

  </div>
 </article>`
}

function toast(c){let el=document.createElement('div');el.className='toast';el.innerHTML=`<div class="toast-icon">${flag(c)}</div><div><strong>${esc(c.callsign)} — ${esc(c.name)}</strong><span>Conectou por ${esc(c.protocol)} • módulo ${esc(c.module)}</span></div>`;$('#toastStack')?.append(el);setTimeout(()=>el.classList.add('out'),7500);setTimeout(()=>el.remove(),8500)}
function updateTitle(d){const active=Object.values(d.modules).filter(m=>m.transmission).map(m=>m.transmission.callsign);document.title=active.length?`(${d.connected_count}) ${active.join(' + ')} TX — ${reflectorName}`:`(${d.connected_count}) ${reflectorName}`;}
function historyCallKey(x){return String(x?.callsign||'').trim().toUpperCase()}
function historyRowId(callKey,index){const safe=Array.from(callKey).map(ch=>/[A-Z0-9_-]/.test(ch)?ch:'x'+ch.charCodeAt(0).toString(16)+'x').join('');return `history-${safe}-${index}`}
function ensureHistoryDropdownStyles(){
 if(document.getElementById('xlxmodernHistoryDropdownStyles'))return;
 const style=document.createElement('style');
 style.id='xlxmodernHistoryDropdownStyles';
 style.textContent=`
  body[data-page='ao-vivo'] .history-status-wrap{display:inline-flex;align-items:center;justify-content:center;gap:3px;flex-wrap:nowrap;white-space:nowrap;width:100%}
  body[data-page='ao-vivo'] .history-status-wrap .state-pill{display:inline-flex!important;align-items:center!important;justify-content:center!important;flex:0 0 auto!important;min-width:38px!important;max-width:none!important;padding:3px 5px!important;font-size:8px!important;line-height:1!important;white-space:nowrap!important;word-break:normal!important;overflow-wrap:normal!important}
  body[data-page='ao-vivo'] .history-toggle{display:inline-grid;place-items:center;flex:0 0 17px;width:17px;min-width:17px;height:17px;padding:0;border:1px solid #285164;border-radius:999px;background:#071923;color:#00d8ff;font:inherit;font-size:7px;font-weight:900;line-height:1;cursor:pointer;transition:border-color .16s ease,box-shadow .16s ease,transform .16s ease}
  body[data-page='ao-vivo'] .history-toggle-spacer{display:inline-block;flex:0 0 17px;width:17px;min-width:17px;height:17px;visibility:hidden;pointer-events:none}
  body[data-page='ao-vivo'] .history-row-country{display:inline-flex;align-items:center;justify-content:center;gap:4px;white-space:nowrap}
  body[data-page='ao-vivo'] .history-row-number{display:inline-grid;place-items:center;flex:0 0 17px;width:17px;height:17px;border:1px solid #285164;border-radius:999px;background:#071923;color:#8ddff2;font-size:8px;font-weight:900;line-height:1}
  body[data-page='ao-vivo'] .history-previous-row .history-row-number{opacity:.35}
  body[data-page='ao-vivo'] .history-toggle:hover,body[data-page='ao-vivo'] .history-toggle:focus-visible,body[data-page='ao-vivo'] .history-toggle[aria-expanded='true']{border-color:#00d8ff;box-shadow:0 0 12px rgba(0,216,255,.22);outline:none}
  body[data-page='ao-vivo'] .history-toggle[aria-expanded='true']{transform:rotate(180deg)}
  body[data-page='ao-vivo'] .history-previous-row>td{background:rgba(0,216,255,.035)!important;color:#b9d5df!important}
  body[data-page='ao-vivo'] .history-previous-row>td:first-child{box-shadow:inset 3px 0 0 rgba(0,216,255,.32)}
  body[data-page='ao-vivo'] .history-primary-row.is-expanded>td{background:rgba(0,216,255,.055)}
  @media(max-width:820px){
   html body[data-page='ao-vivo'] table.home-history tbody tr.history-previous-row>td{background:rgba(0,216,255,.035)!important}
   html body[data-page='ao-vivo'] table.home-history tbody tr.history-primary-row.is-expanded{border-color:rgba(0,216,255,.48)!important}
  }`;
 document.head.appendChild(style);
}
/* XLXMODERN APRS/DPRS PRESENCE V1 */
const xlxmodernAprsPresence=new Map();
const xlxmodernDmrTalkerAlias=new Map();
let xlxmodernAprsPresenceAt=0;
let xlxmodernAprsPresenceLoading=false;
const xlxmodernAprsActiveMs=30*60*1000;
function xlxmodernAprsBaseCall(v){return String(v||'').toUpperCase().trim().split(/[\s/]/)[0].replace(/[^A-Z0-9-]/g,'').replace(/-[0-9]{1,2}$/,'')}
function xlxmodernPositionSourceLabel(st){
 const source=String(st&&st.source||'');
 if(source.startsWith('DPRS_MODULE_'))return `D-PRS • módulo ${st&&st.module||'?'}`;
 if(source==='APRS_IS')return 'APRS-IS';
 if(source==='YSF_GPS')return 'YSF GPS';
 if(source==='DMR_GPS')return 'DMR GPS';
 return String(st&&st.protocol||'Posição digital');
}
function xlxmodernAprsDevice(st){
 const source=String(st&&st.source||'');
 if(source==='DMR_GPS')return ['🛰️','Posição GPS DMR'];
 if(source==='YSF_GPS')return ['🛰️','Posição GPS YSF'];
 if(source.startsWith('DPRS_MODULE_'))return ['🛰️','Posição D-PRS'];
 if(source==='APRS_IS')return ['🛰️','Posição APRS'];
 return ['🛰️','Posição digital'];
}
function xlxmodernAprsSatelliteMarkup(call){
 const key=xlxmodernAprsBaseCall(call),st=xlxmodernAprsPresence.get(key);
 if(!st)return '';
 const dev=xlxmodernAprsDevice(st),source=xlxmodernPositionSourceLabel(st);
 const target=String(st.callsign||key);
 return `<a class="aprs-activity-satellite aprs-device-icon" href="/aprs-dprs?station=${encodeURIComponent(target)}" title="${esc(dev[1])} • ${source} — ver localização" aria-label="${esc(dev[1])} — ver localização de ${esc(target)}">${dev[0]}</a>`;
}
function xlxmodernDmrTalkerAliasMarkup(call){
 const key=xlxmodernAprsBaseCall(call),row=xlxmodernDmrTalkerAlias.get(key);
 if(!row)return '';
 const alias=String(row.alias||'').trim();
 if(!alias)return '';
 return `<span class="dmr-talker-alias-badge" title="Talker Alias DMR reportado pelo rádio: ${esc(alias)}" aria-label="Talker Alias DMR reportado pelo rádio: ${esc(alias)}">T</span>`;
}
async function xlxmodernLoadAprsPresence(force=false){
 if(xlxmodernAprsPresenceLoading)return;
 if(!force && Date.now()-xlxmodernAprsPresenceAt<15000)return;
 xlxmodernAprsPresenceLoading=true;
 try{
  const r=await fetch('/api/digital-lab.php?presence=1&ts='+Date.now(),{cache:'no-store',headers:{Accept:'application/json'}});
  const d=await r.json();
  if(r.ok&&d&&d.ok&&Array.isArray(d.stations)){
   xlxmodernAprsPresence.clear();
   xlxmodernDmrTalkerAlias.clear();
   const now=Date.now();
   d.stations.forEach(st=>{
    const key=xlxmodernAprsBaseCall(st.callsign),t=Date.parse(st.last_seen||'');
    if(!key||!Number.isFinite(t)||now-t>xlxmodernAprsActiveMs)return;
    const prev=xlxmodernAprsPresence.get(key),pt=prev?Date.parse(prev.last_seen||''):0;
    if(!prev||t>pt)xlxmodernAprsPresence.set(key,st);
   });
   (Array.isArray(d.dmr_talker_alias)?d.dmr_talker_alias:[]).forEach(row=>{
    const key=xlxmodernAprsBaseCall(row&&row.callsign),t=Date.parse(row&&row.last_seen||'');
    if(!key||!Number.isFinite(t)||now-t>xlxmodernAprsActiveMs)return;
    const prev=xlxmodernDmrTalkerAlias.get(key),pt=prev?Date.parse(prev.last_seen||''):0;
    if(!prev||t>pt)xlxmodernDmrTalkerAlias.set(key,row);
   });
   xlxmodernAprsPresenceAt=Date.now();
   if(lastData){
    if(page==='conectados')renderConnectedTable(lastData);
    if(page==='ao-vivo'){
     const hr=$('#historyRows'); if(hr)hr.innerHTML=historyMarkup(lastData);
    }
   }
  }
 }catch(_e){}finally{xlxmodernAprsPresenceLoading=false}
}

/* XLXMODERN REPEATER POPUP V2 */
const xlxmodernRepeaterCache=new Map();
const xlxmodernGatewayLocalMeta=new Map();
function xlxmodernIndexGatewayLocalMeta(d){
 xlxmodernGatewayLocalMeta.clear();
 const rows=[...(d&&d.connections||[]),...(d&&d.history||[])];
 rows.forEach(r=>{
  const call=xlxmodernBaseCall(r&&r.callsign);
  const name=String((r&&r.name)||'').trim();
  const location=String((r&&r.location)||'').trim();
  if(!call)return;
  const usefulName=name&&!/^N[aã]o informado$/i.test(name);
  const usefulLocation=location&&!/^N[aã]o informad[ao]$/i.test(location);
  if(usefulName||usefulLocation){
   const prev=xlxmodernGatewayLocalMeta.get(call)||{};
   xlxmodernGatewayLocalMeta.set(call,{name:usefulName?name:(prev.name||''),location:usefulLocation?location:(prev.location||'')});
  }
 });
}
function xlxmodernStationProvesGateway(x){const src=String((x&&x.identity_source)||'');const conf=String((x&&x.identity_confidence)||'');return src.indexOf('xlxd-station')===0&&(conf==='station'||conf==='station-strict')}
function xlxmodernRepeaterEligible(x,gatewayCall,callsign){const selfRepeater=gatewayCall&&callsign&&gatewayCall===callsign&&/^REPETIDORA\b/i.test(String((x&&x.name)||'').trim());const linkedRepeater=gatewayCall&&callsign&&gatewayCall!==callsign&&xlxmodernStationProvesGateway(x);return Boolean(selfRepeater||linkedRepeater)}
async function xlxmodernRepeaterInfo(call){
 const key=xlxmodernBaseCall(call); if(!key)return null;
 if(xlxmodernRepeaterCache.has(key))return xlxmodernRepeaterCache.get(key);
 try{
  const r=await fetch('/api/repeater.php?callsign='+encodeURIComponent(key),{cache:'no-store',headers:{Accept:'application/json'}});
  const d=await r.json(); const v=(r.ok&&d&&d.ok&&d.repeater)?d.repeater:null;
  xlxmodernRepeaterCache.set(key,v); return v;
 }catch(_e){xlxmodernRepeaterCache.set(key,null);return null}
}
function xlxmodernEnsureRepeaterDialog(){
 let d=document.getElementById('xlxmodernRepeaterDialog'); if(d)return d;
 d=document.createElement('dialog');d.id='xlxmodernRepeaterDialog';d.className='xlxmodern-repeater-dialog';
 d.innerHTML='<div class="repeater-dialog-head"><strong id="xlxmodernRepeaterTitle">Repetidora</strong><button type="button" data-repeater-close aria-label="Fechar">×</button></div><div id="xlxmodernRepeaterBody" class="repeater-dialog-body"></div>';
 document.body.appendChild(d);d.querySelector('[data-repeater-close]').addEventListener('click',()=>d.close());d.addEventListener('click',e=>{if(e.target===d)d.close()});return d;
}
function xlxmodernRepeaterField(label,value){return value?`<div><small>${esc(label)}</small><strong>${esc(String(value))}</strong></div>`:''}
async function xlxmodernOpenRepeater(call){
 const d=xlxmodernEnsureRepeaterDialog(),body=d.querySelector('#xlxmodernRepeaterBody'),title=d.querySelector('#xlxmodernRepeaterTitle');
 title.textContent=xlxmodernBaseCall(call)||'Repetidora';body.innerHTML='<p class="repeater-loading">Consultando RadioID.net…</p>';d.showModal();
 const r=await xlxmodernRepeaterInfo(call);
 if(!r){body.innerHTML='<p>Não há cadastro de repetidora disponível no RadioID.net para este indicativo.</p>';return}
 const place=[r.city,r.state].filter(Boolean).join(' / '), updated=r.fetched_at?new Date(Number(r.fetched_at)*1000).toLocaleString('pt-BR'):'—';
 body.innerHTML=`<div class="repeater-detail-grid">${xlxmodernRepeaterField('Frequência',r.frequency?`${r.frequency} MHz`:'')}${xlxmodernRepeaterField('Offset',r.offset?`${r.offset} MHz`:'')}${xlxmodernRepeaterField('Localização',place)}${xlxmodernRepeaterField('Color Code',r.color_code)}${xlxmodernRepeaterField('Status',r.status)}${xlxmodernRepeaterField('Cobertura',r.coverage)}${xlxmodernRepeaterField('Rede / modos',r.network)}${xlxmodernRepeaterField('Responsável',Array.isArray(r.trustee)?r.trustee.join(', '):'')}</div><div class="repeater-source"><b>Fonte:</b> RadioID.net<br><b>Última consulta:</b> ${esc(updated)}${r.cache==='stale'?'<br><span>Exibindo último cache disponível.</span>':''}</div>`;
}
async function xlxmodernEnableRepeaterButtons(root=document){
 const nodes=[...root.querySelectorAll('[data-repeater-call]')];
 for(const n of nodes){
  if(n.dataset.repeaterBound==='1')continue;
  n.dataset.repeaterBound='1';
  const call=xlxmodernBaseCall(n.dataset.repeaterCall||'');
  if(!call)continue;
  const info=await xlxmodernRepeaterInfo(call);
  if(!info){
   n.dataset.gatewayType='gateway-unknown';
   n.title='Gateway/hotspot — sem cadastro de repetidora confirmado no RadioID.net';
   continue;
  }
  n.dataset.gatewayType='repeater';
  n.classList.add('has-repeater-info','gateway-confirmed-repeater');
  n.title='Repetidora confirmada no RadioID.net';
  const row=n.closest('tr');
  if(row){
   const nameCell=row.querySelector('.history-name-cell');
   const cityCell=row.querySelector('.history-city-cell');
   const city=String(info.city||'').trim();
   const state=String(info.state||'').trim();
   const place=[city,state].filter(Boolean).join(', ');
   const repName=city?`Repetidora ${city}${state?' '+state:''}`:'Repetidora '+call;
   if(nameCell&&nameCell.dataset.missing==='1'){
    nameCell.textContent=repName;
    nameCell.title='Dados oficiais da repetidora '+call+' • RadioID.net';
    nameCell.classList.add('repeater-meta-fallback');
   }
   if(cityCell&&cityCell.dataset.missing==='1'&&place){
    cityCell.textContent=place;
    cityCell.title='Localização oficial da repetidora '+call+' • RadioID.net';
    cityCell.classList.add('repeater-meta-fallback');
   }
  }
  const b=document.createElement('button');
  b.type='button';
  b.className='repeater-info-button';
  b.textContent='i';
  b.title='Ver informações da repetidora confirmada';
  b.setAttribute('aria-label','Ver dados da repetidora '+call);
  b.addEventListener('click',e=>{e.preventDefault();e.stopPropagation();xlxmodernOpenRepeater(call)});
  n.appendChild(b);
 }
}

function hotspotRepeaterMarkup(x){
 const callsign=
  xlxmodernBaseCall(
   (x&&x.callsign)||''
  );

 const raw=
  String(
   (x&&x.gateway)||''
  ).trim();

 const normalized=
  raw.toUpperCase();

 const gatewayCall=
  xlxmodernBaseCall(raw);

 const unknown=
  !raw
  || normalized==='NÃO IDENTIFICADO'
  || normalized==='GATEWAY NÃO IDENTIFICADO'
  || normalized==='GATEWAY / REPETIDORA NÃO IDENTIFICADO';

 if(unknown){
  return `<span class="hotspot-repeater-empty">—</span>`;
 }

 /*
  * A comparação é feita pelo indicativo-base.
  *
  * N0CALL B = PU2PNY
  * PY4RWC B = PY4RWC
  */
 const different=
  callsign!=='' &&
  gatewayCall!=='' &&
  gatewayCall!==callsign;

 const neon=different
  ? `<span class="gateway-neon" role="img" aria-label="Usando gateway, hotspot ou repetidora diferente do indicativo" title="Usando gateway, hotspot ou repetidora diferente do indicativo"></span>`
  : '';

 const displayed=
  gatewayCall||raw;

 const repAttr=gatewayCall?` data-repeater-call="${esc(gatewayCall)}"`:'';
 return `<span class="gateway-display${different?' gateway-different':''}"${repAttr}><span class="gateway-value">${esc(displayed)}</span></span>`;
}

function historyStatusMarkup(x){
 /* XLXMODERN_HISTORY_LINK_STATUS_V15B */

 /*
  * Online continua tendo prioridade.
  */
 if(Boolean(x&&x.online)){
  return onlineBadge(true);
 }

 const call=
  xlxmodernBaseCall(
   (x&&x.callsign)||''
  );

 const gatewayRaw=
  String(
   (x&&x.gateway)||''
  ).trim();

 const gateway=
  xlxmodernBaseCall(
   gatewayRaw
  );

 const source=
  String(
   (x&&x.identity_source)||''
  );

 const gatewayKnown=
  gateway!=='' &&
  !/NÃO\s+IDENTIFICADO/i.test(
   gatewayRaw
  );

 const stationConfirmed=
  source.indexOf(
   'xlxd-station'
  )===0;

 const viaLink=
  call!=='' &&
  gatewayKnown &&
  gateway!==call &&
  stationConfirmed;

 if(viaLink){
  return `<span class="history-link-badge" title="Operador ouvido através de ${esc(gateway)}" aria-label="Link através de ${esc(gateway)}">Link</span>`;
 }

 return onlineBadge(false);
}

function historyToggleMarkup(x,callKey,previousIds){
 if(!previousIds.length)return '';

 const expanded=historyExpandedCalls.has(callKey);

 const label=expanded
  ? 'Fechar atividades anteriores'
  : 'Abrir atividades anteriores';

 return `<button type="button" class="history-toggle" data-history-toggle="${esc(callKey)}" aria-expanded="${expanded?'true':'false'}" aria-controls="${esc(previousIds.join(' '))}" aria-label="${label} de ${esc(x.callsign)}" title="${label}"><span aria-hidden="true">▼</span></button>`;
}

/* XLXMODERN_HORARIO_TX_24H_V1 */
function historyRowMarkup(
 x,
 statusHtml,
 toggleHtml='',
 attrs='',
 position='',
 longPeriod=false
){
 const rowNumber=position===''?'↳':esc(position);

 return `<tr ${attrs}>

  <td class="history-number-cell">
   <span class="history-number-wrap">
    <span class="history-row-number" aria-hidden="true">${rowNumber}</span>
    ${toggleHtml}
   </span>
  </td>

  <td class="history-country-cell">
   <span class="history-country-final">${flag(x)}</span>
  </td>

  <td class="history-status-cell">
   ${statusHtml}
  </td>

  <td class="history-callsign-cell">
   <a target="_blank" href="${esc(x.qrz)}">${esc(x.callsign)}</a>${xlxmodernAprsSatelliteMarkup(x.callsign)}${xlxmodernDmrTalkerAliasMarkup(x.callsign)}
  </td>

  <td class="history-name-cell" data-missing="${!x.name||/^N[aã]o informado$/i.test(String(x.name))?'1':'0'}">${esc(x.name||'Não informado')}</td>

  <td class="history-hotspot-cell">
   ${hotspotRepeaterMarkup(x)}
  </td>

  <td class="history-city-cell" data-missing="${!x.location||/^N[aã]o informad[ao]$/i.test(String(x.location))?'1':'0'}">${esc(x.location||'Não informada')}</td>

  <td>
   <span class="protocol">${esc(x.protocol)}</span>
  </td>

  <td>${esc(x.module)}</td>

  <td class="history-tx-time" data-label="Horário TX" title="${esc(fmtTime(x.started_at))}">${x.started_at?(longPeriod?new Date(Number(x.started_at)*1000).toLocaleString('pt-BR',{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'}):new Date(Number(x.started_at)*1000).toLocaleTimeString('pt-BR',{hour:'2-digit',minute:'2-digit'})):'—'}</td><td class="history-duration-cell">
   <span class="history-duration-value">${duration(x.duration)}</span>
  </td>

 </tr>`;
}

function historyMarkup(d){
 const cutoff=
  Number(
   d.generated_at||
   Math.floor(Date.now()/1000)
  )-86400;

 const rows=(d.history||[])
  .filter(
   x=>Number(x.started_at||0)>=cutoff
  );

 if(!rows.length){
  return `<tr><td colspan="10">Nenhuma transmissão registrada nas últimas 24 horas.</td></tr>`;
 }

 const groups=new Map();

 rows.forEach((x,index)=>{
  const base=historyCallKey(x);
  const key=base||`SEM-INDICATIVO-${index}`;

  if(!groups.has(key)){
   groups.set(key,[]);
  }

  groups.get(key).push(x);
 });

 return [...groups.entries()]
  
  .map(([callKey,items],groupIndex)=>{
   const latest=items[0];
   const previous=items.slice(1);
   const expanded=historyExpandedCalls.has(callKey);

   const previousIds=previous.map(
    (_,index)=>historyRowId(callKey,index)
   );

   const mainAttrs=
    `class="history-primary-row${expanded?' is-expanded':''}" data-history-call="${esc(callKey)}"`;

   const main=historyRowMarkup(
    latest,
    historyStatusMarkup(latest),
    historyToggleMarkup(
     latest,
     callKey,
     previousIds
    ),
    mainAttrs,
    groupIndex+1
   );

   const older=previous.map((x,index)=>{
    const hidden=expanded
     ? ''
     : ` style="display:none!important"`;

    const attrs=
     `id="${esc(previousIds[index])}" class="history-previous-row" data-history-parent="${esc(callKey)}"${hidden}`;

    return historyRowMarkup(
     x,
     historyStatusMarkup(x),
     '',
     attrs,
     `${groupIndex+1}.${index+1}`
    );
   }).join('');

   return main+older;
  }).join('');
}

let xlxmodernHistoryPeriodDays=1;
let xlxmodernHistoryLongRequest=0;
function xlxmodernHistoryPeriodText(days){return days===7?'Atividade dos últimos 7 dias':days===30?'Atividade dos últimos 30 dias':'Atividade das últimas 24 horas'}
function xlxmodernHistoryCoverageText(data){
 const since=Number(data&&data.coverage_since||0);
 if(!since)return 'Base histórica iniciando agora';
 const dt=new Date(since*1000).toLocaleDateString('pt-BR');
 return `Base acumulada desde ${dt}`;
}
function historyLongToggleMarkup(x,days){
 const count=Number(x&&x.tx_count||0),call=historyCallKey(x);
 if(count<=1||!call)return '';
 return `<button type="button" class="history-toggle" data-history-long-toggle="${esc(call)}" data-history-days="${days}" aria-expanded="false" aria-label="Abrir ${count} transmissões de ${esc(x.callsign)}" title="${count} transmissões no período"><span aria-hidden="true">▼</span></button>`;
}
function historyLongMarkup(data){
 const days=Number(data&&data.days||xlxmodernHistoryPeriodDays||7),rows=Array.isArray(data&&data.groups)?data.groups:[];
 if(!rows.length)return `<tr><td colspan="11">Nenhuma transmissão registrada na base dos últimos ${days} dias.</td></tr>`;
 return rows.map((x,i)=>{
  const y={...x,duration:Number(x.total_duration||x.duration||0)};
  const attrs=`class="history-primary-row history-long-primary" data-history-long-call="${esc(historyCallKey(x))}"`;
  return historyRowMarkup(y,historyStatusMarkup(y),historyLongToggleMarkup(x,days),attrs,i+1,true);
 }).join('');
}
async function xlxmodernLoadLongHistory(days){
 const seq=++xlxmodernHistoryLongRequest,rows=$('#historyRows'),title=$('#historyPeriodTitle'),note=$('#historyCoverageNote');
 if(title)title.textContent=xlxmodernHistoryPeriodText(days);
 if(note)note.textContent='Carregando histórico…';
 if(rows)rows.innerHTML='<tr class="history-long-loading"><td colspan="11">Carregando histórico…</td></tr>';
 try{
  const r=await fetch(`/api/history-long.php?days=${days}&ts=${Date.now()}`,{cache:'no-store'}),d=await r.json();
  if(seq!==xlxmodernHistoryLongRequest)return;
  if(!r.ok||!d.ok)throw Error('history');
  if(rows)rows.innerHTML=historyLongMarkup(d);
  if(note)note.textContent=xlxmodernHistoryCoverageText(d);
  setTimeout(()=>xlxmodernEnableRepeaterButtons(document),0);
 }catch(_e){
  if(rows)rows.innerHTML='<tr><td colspan="11">Não foi possível carregar o histórico longo.</td></tr>';
  if(note)note.textContent='Histórico indisponível';
 }
}
async function toggleLongHistory(button){
 const call=String(button.dataset.historyLongToggle||''),days=Number(button.dataset.historyDays||xlxmodernHistoryPeriodDays||7),main=button.closest('tr');
 if(!call||!main)return;
 const expanded=button.getAttribute('aria-expanded')==='true';
 const existing=[...document.querySelectorAll('#historyRows tr[data-history-long-parent]')].filter(r=>r.dataset.historyLongParent===call);
 if(existing.length){
  existing.forEach(r=>r.style.setProperty('display',expanded?'none':'table-row','important'));
  button.setAttribute('aria-expanded',expanded?'false':'true'); main.classList.toggle('is-expanded',!expanded); return;
 }
 button.disabled=true;
 try{
  const r=await fetch(`/api/history-long.php?days=${days}&callsign=${encodeURIComponent(call)}&ts=${Date.now()}`,{cache:'no-store'}),d=await r.json();
  if(!r.ok||!d.ok)throw Error('detail');
  const items=Array.isArray(d.items)?d.items.slice(1):[];
  if(items.length){
   const html=items.map((x,i)=>historyRowMarkup(x,historyStatusMarkup(x),'',`class="history-previous-row" data-history-long-parent="${esc(call)}"`,`${main.querySelector('.history-row-number')?.textContent||''}.${i+1}`,true)).join('');
   main.insertAdjacentHTML('afterend',html);
   setTimeout(()=>xlxmodernEnableRepeaterButtons(document),0);
  }
  button.setAttribute('aria-expanded','true'); main.classList.add('is-expanded');
 }catch(_e){button.title='Falha ao carregar transmissões anteriores';}
 finally{button.disabled=false;}
}
function toggleHistoryGroup(callKey,button){
 const expanded=!historyExpandedCalls.has(callKey);
 if(expanded)historyExpandedCalls.add(callKey);else historyExpandedCalls.delete(callKey);
 button.setAttribute('aria-expanded',expanded?'true':'false');
 const label=expanded?'Fechar atividades anteriores':'Abrir atividades anteriores';
 button.setAttribute('aria-label',`${label} de ${callKey}`);
 button.title=label;
 const main=button.closest('tr');
 main?.classList.toggle('is-expanded',expanded);
 document.querySelectorAll('#historyRows tr[data-history-parent]').forEach(row=>{
  if(row.dataset.historyParent!==callKey)return;
  if(expanded)row.style.removeProperty('display');
  else row.style.setProperty('display','none','important');
 });
}
const xlxNatoModules=['Alfa','Bravo','Charlie','Delta','Echo','Foxtrot','Golf','Hotel','India','Juliett','Kilo','Lima','Mike','November','Oscar','Papa','Quebec','Romeo','Sierra','Tango','Uniform','Victor','Whiskey','X-Ray','Yankee','Zulu'];
const xlxReflectorName='{{REFLECTOR_NAME}}';
const xlxReflectorNumber='{{REFLECTOR_NUMBER}}';
const xlxReflectorShort='{{REFLECTOR_SHORT_NUMBER}}';
const xlxYsfId='{{YSF_ID}}';
function xlxModulePhonetic(letter){const i=String(letter||'').toUpperCase().charCodeAt(0)-65;return xlxNatoModules[i]||String(letter||'');}
function moduleInfo(m){const defs={A:['Envio de imagens D-STAR','Módulo A • imagens digitais',`${xlxReflectorName}-A`],B:['APRS / D-PRS','Dados digitais',`${xlxReflectorName}-B`],C:['C4FM/YSF e DMR',`YSF ${xlxYsfId} • DMR TG 4003`,`${xlxReflectorName}-C`],D:['D-STAR',`${xlxReflectorName}-D / XRF${xlxReflectorNumber}-D`,`${xlxReflectorName}-D`],E:['D-STAR Echo','Teste de áudio',`${xlxReflectorName}-E`]};return defs[m.module]||[m.configured_protocol,m.access,`${xlxReflectorName}-${m.module}`]}
function renderModules(d){$('#moduleOverview').innerHTML=Object.values(d.modules).map(m=>{const i=moduleInfo(m);return `<article class="module-mini ${m.transmission?'active':''}"><div class="module-mini-top"><span class="module-letter">${esc(m.module)}</span><span class="module-count">${m.connected_count} conectado${m.connected_count===1?'':'s'}</span></div><strong>${esc(i[0])}</strong><small>${esc(i[1])}</small><div class="module-id">${esc(i[2])}</div><div class="module-state">${m.transmission?'<i class="red"></i> Transmitindo agora':'<i></i> Aguardando transmissão'}</div></article>`}).join('');
 const functions={A:'Imagens D-STAR',B:'APRS / D-PRS',C:'C4FM/YSF/DMR',D:'D-STAR',E:'Echo / teste'};
 const dtmfBase=/^[0-9]+$/.test(xlxReflectorShort)?xlxReflectorShort:'';
 const rows=Object.values(d.modules).map((m,idx)=>{const n=idx+1,letter=m.module;const refDtmf=dtmfBase?`*${dtmfBase}${letter}`:'—';const xrfDtmf=dtmfBase?`B${dtmfBase}${letter}`:'—';const dcsDtmf=dtmfBase?`D${dtmfBase}${letter}`:'—';return `<tr><td><b>${esc(letter)}</b></td><td><strong>${esc(xlxModulePhonetic(letter))}</strong><br><span>${esc(functions[letter]||m.configured_protocol)}</span></td><td>${m.connected_count}</td><td>REF${esc(xlxReflectorNumber)}${letter}L</td><td>${refDtmf}</td><td>XRF${esc(xlxReflectorNumber)}${letter}L</td><td>${xrfDtmf}</td><td>DCS${esc(xlxReflectorNumber)}${letter}L</td><td>${dcsDtmf}</td><td>${4000+n}</td><td>${9+n}</td></tr>`}).join('');$('#moduleReferenceRows').innerHTML=rows; }
/* XLXMODERN_CONECTADOS_UNIFICADO_V1 */
function filterConnectedRows(d,query='',moduleFilter='',protocolFilter=''){
 const q=String(query||'').trim().toLowerCase();
 const moduleValue=String(moduleFilter||'').trim().toUpperCase();
 const protocolValue=String(protocolFilter||'').trim().toLowerCase();

 return (d.connections||[]).filter(c=>{
  const queryMatch=!q||[c.callsign,c.name,c.location,c.protocol,c.module]
   .some(v=>String(v||'').toLowerCase().includes(q));
  const moduleMatch=!moduleValue||
   String(c.module||'').trim().toUpperCase()===moduleValue;
  const protocolMatch=!protocolValue||
   String(c.protocol||'').trim().toLowerCase()===protocolValue;
  return queryMatch&&moduleMatch&&protocolMatch;
 });
}

function connectedRows(d,query='',moduleFilter='',protocolFilter=''){
 const rows=filterConnectedRows(d,query,moduleFilter,protocolFilter);
 return rows.length
  ?rows.map((c,i)=>`<tr><td>${i+1}</td><td>${flag(c)}</td><td><span class="connected-call-wrap"><a target="_blank" href="${esc(c.qrz)}">${esc(c.callsign)}${c.suffix?' '+esc(c.suffix):''}</a>${xlxmodernAprsSatelliteMarkup(c.callsign)}${xlxmodernDmrTalkerAliasMarkup(c.callsign)}</span></td><td>${esc(c.name)}</td><td>${esc(c.location)}</td><td><span class="protocol">${esc(c.protocol)}</span></td><td>${esc(c.module)}</td><td>${fmtTime(c.connected_at)}</td><td data-start="${c.connected_at}">${elapsed(c.connected_at)}</td><td>${fmtTime(c.last_activity)}</td></tr>`).join('')
  :`<tr><td colspan="10">Nenhuma estação corresponde aos filtros.</td></tr>`;
}

function syncConnectedProtocolFilter(d){
 const select=$('#connectedProtocolFilter');
 if(!select)return;
 const current=select.value;
 const protocols=[...new Set((d.connections||[])
  .map(c=>String(c.protocol||'').trim()).filter(Boolean))];
 if(current&&!protocols.includes(current))protocols.push(current);
 protocols.sort();

 const signature=protocols.join('|');
 if(select.dataset.signature===signature)return;

 select.innerHTML='<option value="">Todos</option>'+
  protocols.map(p=>`<option value="${esc(p)}">${esc(p)}</option>`).join('');
 if(current)select.value=current;
 select.dataset.signature=signature;
}

function renderConnectedTable(d){
 const query=$('#connectedSearch')?.value||'';
 const moduleFilter=$('#connectedModuleFilter')?.value||'';
 const protocolFilter=$('#connectedProtocolFilter')?.value||'';
 const visible=filterConnectedRows(d,query,moduleFilter,protocolFilter).length;
 const total=Number(d.connected_count!=null?d.connected_count:(d.connections||[]).length);

 const label=$('#connectedLabel');
 if(label){
  const base=`${total} estação${total===1?'':'ões'} conectada${total===1?'':'s'}`;
  label.textContent=visible===total
   ?base
   :`${base} • ${visible} exibida${visible===1?'':'s'}`;
 }

 $('#connectedRows').innerHTML=
  connectedRows(d,query,moduleFilter,protocolFilter);
 xlxmodernEnableRepeaterButtons(document);
}

function renderConnected(d){
 syncConnectedProtocolFilter(d);
 renderConnectedTable(d);
}

function rankList(items,valueLabel){return items.length?items.map((x,i)=>`<div class="rank-item"><span class="rank-pos">${i+1}</span><div><b>${esc(x.label)}</b><small>${esc(x.sub||'')}</small></div><strong>${esc(valueLabel(x.value))}</strong></div>`).join(''):'<div class="rank-empty">Dados insuficientes no histórico disponível.</div>'}
function aggregate(arr,keyFn,valFn=()=>1){const m=new Map();arr.forEach(x=>{const k=keyFn(x);if(!k)return;const old=m.get(k)||{label:k,value:0,sub:''};old.value+=valFn(x);m.set(k,old)});return [...m.values()].sort((a,b)=>b.value-a.value)}
function renderRanking(d){const h=d.history||[],c=d.connections||[];const tx=aggregate(h,x=>x.callsign);tx.forEach(x=>{const y=h.find(z=>z.callsign===x.label);x.sub=y?.name||''});const air=aggregate(h,x=>x.callsign,x=>Number(x.duration||0));air.forEach(x=>{const y=h.find(z=>z.callsign===x.label);x.sub=y?.name||''});const con=[...c].sort((a,b)=>a.connected_at-b.connected_at).slice(0,10).map(x=>({label:x.callsign,sub:x.name,value:Math.max(0,Math.floor(Date.now()/1000-x.connected_at))}));const hrs=aggregate(h,x=>String(new Date(x.started_at*1000).getHours()).padStart(2,'0')+':00');const prot=aggregate(h,x=>x.protocol);const mods=aggregate(h,x=>'Módulo '+x.module);$('#rankTx').innerHTML=rankList(tx.slice(0,10),v=>v+' TX');$('#rankAirtime').innerHTML=rankList(air.slice(0,10),v=>duration(v));$('#rankConnected').innerHTML=rankList(con,v=>elapsed(Math.floor(Date.now()/1000-v)));$('#rankHours').innerHTML=rankList(hrs.slice(0,8),v=>v+' TX');$('#rankProtocols').innerHTML=rankList(prot.slice(0,8),v=>v+' TX');$('#rankModules').innerHTML=rankList(mods.slice(0,8),v=>v+' TX');const topTx=tx[0],topAir=air[0],topHour=hrs[0];$('#rankingHighlights').innerHTML=`<article><small>Mais transmissões</small><b>${esc(topTx?.label||'—')}</b><span>${topTx?topTx.value+' transmissões':'Sem dados'}</span></article><article><small>Maior tempo no ar</small><b>${esc(topAir?.label||'—')}</b><span>${topAir?duration(topAir.value):'Sem dados'}</span></article><article><small>Horário mais ativo</small><b>${esc(topHour?.label||'—')}</b><span>${topHour?topHour.value+' transmissões':'Sem dados'}</span></article><article><small>Conectados agora</small><b>${d.connected_count}</b><span>${d.active_count} transmissão${d.active_count===1?'':'ões'} ativa${d.active_count===1?'':'s'}</span></article>`}
/* XLXMODERN_REFLETORES_COMPLETO_V2B */
let reflectorAllRows=[];
let reflectorSort={key:'name',dir:'asc'};
let reflectorBound=false;
let reflectorSearchTimer=null;
function reflectorNorm(v){return String(v??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/\s+/g,' ').trim().toLowerCase()}
function reflectorState(r){return reflectorNorm(r?.status)==='online'?'online':'offline'}
function reflectorUrl(v){try{const u=new URL(String(v||''),location.origin);return /^(https?):$/.test(u.protocol)?u.href:''}catch(e){return ''}}
function ensureReflectorUi(){
 const panel=document.querySelector('body[data-page="refletores"] .embedded-panel');
 if(!panel)return false;
 if(panel.dataset.reflectorV2==='1')return true;
 panel.dataset.reflectorV2='1';
 panel.innerHTML=`
  <div class="reflector-tools">
   <div class="reflector-tools-title"><b>Refletores registrados</b><span id="reflectorSummary">Carregando lista mundial...</span></div>
   <div class="reflector-controls">
    <label><span>Pesquisar</span><input id="reflectorSearch" type="search" placeholder="XLXMODERN, país ou descrição" autocomplete="off"></label>
    <label><span>Status</span><select id="reflectorStatus"><option value="">Todos</option><option value="online">Online</option><option value="offline">Offline</option></select></label>
    <label><span>País</span><select id="reflectorCountry"><option value="">Todos os países</option></select></label>
   </div>
  </div>
  <div class="reflector-stats"><article><small>Total</small><b id="reflectorTotal">—</b></article><article><small>Online</small><b id="reflectorOnline">—</b></article><article><small>Offline</small><b id="reflectorOffline">—</b></article><article><small>Exibidos</small><b id="reflectorVisible">—</b></article></div>
  <div class="reflector-note">Todos os registros retornados pela rede são exibidos nesta página.</div>
  <div class="table-wrap reflector-table-wrap"><table class="reflectors-table"><thead><tr><th>#</th><th data-rsort-col="name" aria-sort="ascending"><button class="reflector-sort" type="button" data-rsort="name">Refletor <i>↑</i></button></th><th data-rsort-col="country" aria-sort="none"><button class="reflector-sort" type="button" data-rsort="country">País <i>↕</i></button></th><th data-rsort-col="status" aria-sort="none"><button class="reflector-sort" type="button" data-rsort="status">Status <i>↕</i></button></th><th>Descrição</th></tr></thead><tbody id="reflectorRows"><tr><td colspan="5">Carregando lista de refletores...</td></tr></tbody></table></div>`;
 return true;
}
function reflectorCountries(){
 const s=$('#reflectorCountry'); if(!s)return;
 const countries=[...new Set(reflectorAllRows.map(r=>String(r?.country||'').trim()).filter(Boolean))].sort((a,b)=>a.localeCompare(b,'pt-BR',{sensitivity:'base'}));
 s.innerHTML='<option value="">Todos os países</option>'+countries.map(c=>`<option value="${esc(c)}">${esc(c)}</option>`).join('');
}
function reflectorSortUi(){document.querySelectorAll('[data-rsort-col]').forEach(th=>{const active=th.dataset.rsortCol===reflectorSort.key;th.setAttribute('aria-sort',active?(reflectorSort.dir==='asc'?'ascending':'descending'):'none');const i=th.querySelector('i');if(i)i.textContent=active?(reflectorSort.dir==='asc'?'↑':'↓'):'↕'})}
function renderReflectorView(){
 const tb=$('#reflectorRows'); if(!tb)return;
 const q=reflectorNorm($('#reflectorSearch')?.value||''),sf=reflectorNorm($('#reflectorStatus')?.value||''),cf=reflectorNorm($('#reflectorCountry')?.value||'');
 const total=reflectorAllRows.length,online=reflectorAllRows.filter(r=>reflectorState(r)==='online').length,offline=total-online;
 const rows=reflectorAllRows.filter(r=>(!sf||reflectorState(r)===sf)&&(!cf||reflectorNorm(r?.country)===cf)&&(!q||[r?.name,r?.country,r?.status,r?.comment].some(v=>reflectorNorm(v).includes(q))));
 const dir=reflectorSort.dir==='desc'?-1:1;
 rows.sort((a,b)=>{const av=reflectorSort.key==='status'?reflectorState(a):String(a?.[reflectorSort.key]||''),bv=reflectorSort.key==='status'?reflectorState(b):String(b?.[reflectorSort.key]||'');return av.localeCompare(bv,'pt-BR',{numeric:true,sensitivity:'base'})*dir});
 $('#reflectorTotal').textContent=total.toLocaleString('pt-BR'); $('#reflectorOnline').textContent=online.toLocaleString('pt-BR'); $('#reflectorOffline').textContent=offline.toLocaleString('pt-BR'); $('#reflectorVisible').textContent=rows.length.toLocaleString('pt-BR'); $('#reflectorSummary').textContent=`${total.toLocaleString('pt-BR')} refletores • ${online.toLocaleString('pt-BR')} online • ${offline.toLocaleString('pt-BR')} offline`;
 reflectorSortUi();
 tb.innerHTML=rows.length?rows.map((r,i)=>{const name=String(r?.name||'—'),self=name.trim().toUpperCase()===reflectorName,url=reflectorUrl(r?.dashboardurl),nameHtml=url?`<a target="_blank" rel="noopener noreferrer" href="${esc(url)}">${esc(name)}</a>`:esc(name);return `<tr class="${self?'reflector-self':''}"><td data-label="#">${i+1}</td><td data-label="Refletor"><span class="reflector-name">${nameHtml}${self?'<em>Este servidor</em>':''}</span></td><td data-label="País">${esc(r?.country||'—')}</td><td data-label="Status">${onlineBadge(reflectorState(r)==='online')}</td><td data-label="Descrição">${esc(r?.comment||'—')}</td></tr>`}).join(''):'<tr class="reflector-empty"><td colspan="5">Nenhum refletor corresponde aos filtros.</td></tr>';
}
function bindReflectorUi(){
 if(reflectorBound)return;
 $('#reflectorSearch')?.addEventListener('input',()=>{clearTimeout(reflectorSearchTimer);reflectorSearchTimer=setTimeout(renderReflectorView,100)});
 $('#reflectorStatus')?.addEventListener('change',renderReflectorView); $('#reflectorCountry')?.addEventListener('change',renderReflectorView);
 document.querySelectorAll('[data-rsort]').forEach(b=>b.addEventListener('click',()=>{const k=b.dataset.rsort||'name';if(reflectorSort.key===k)reflectorSort.dir=reflectorSort.dir==='asc'?'desc':'asc';else reflectorSort={key:k,dir:'asc'};renderReflectorView()}));
 reflectorBound=true;
}
function renderReflectors(data){
 if(!ensureReflectorUi())return;
 reflectorAllRows=data&&Array.isArray(data.reflectors)?data.reflectors.slice():[];
 reflectorCountries(); bindReflectorUi(); renderReflectorView();
}
/* /XLXMODERN_REFLETORES_COMPLETO_V2B */

let xlxmodernHistorySignature='';
let xlxmodernHistoryRenderedAt=0;
function render(d){lastData=d;$('#syncState').textContent='Ao vivo';updateTitle(d);trackConnectedCountVoice(d);
 xlxmodernIndexGatewayLocalMeta(d);
 if(page==='ao-vivo'){ xlxmodernLoadAprsPresence(); setTimeout(()=>xlxmodernEnableRepeaterButtons(document),0); $('#headerConnected').textContent=d.connected_count; $('#headerActive').textContent=d.active_count; $('#widgetCount').textContent=d.active_count?`${d.active_count} no ar`:'Standby'; const active=Object.values(d.modules).filter(m=>m.transmission); const newest=[...d.history].sort((a,b)=>b.started_at-a.started_at)[0]||null; const standModule=Object.values(d.modules)[0];

 /*
  * A API geral pode preencher o box somente na carga inicial.
  * Depois que a API rápida assume o monitor, ela passa a ser
  * a única responsável pelo box TX/RX e pelo widget MTR.
  *
  * Isso impede o status.php de apagar uma transmissão ativa
  * enquanto o live.php continua informando a mesma assinatura.
  */
 if(lastLiveVisualSignature===null){
  $('#moduleGrid').innerHTML=active.length
   ?active.slice(0,3).map(txCard).join('')
   :standbyCard(standModule,newest);
 }

 ensureHistoryDropdownStyles();
 const historySignature=(d.history||[]).map(x=>[x.callsign||'',x.suffix||'',x.module||'',x.protocol||'',x.started_at||'',x.ended_at||'',x.gateway||''].join('|')).join('~');
 const now=Date.now();
 if(xlxmodernHistoryPeriodDays===1&&(historySignature!==xlxmodernHistorySignature||now-xlxmodernHistoryRenderedAt>=15000)){
  $('#historyRows').innerHTML=historyMarkup(d);
  xlxmodernHistorySignature=historySignature;
  xlxmodernHistoryRenderedAt=now;
 }
 }
 if(page==='modulos')renderModules(d);
 if(page==='conectados'){xlxmodernLoadAprsPresence();renderConnected(d);}
 if(page==='ranking')renderRanking(d);
 const nowSet=new Set(d.connections.map(c=>`${c.callsign}|${c.suffix}|${c.protocol}|${c.module}|${c.ip}`));if(previousConnections!==null)d.connections.forEach(c=>{const k=`${c.callsign}|${c.suffix}|${c.protocol}|${c.module}|${c.ip}`;if(!previousConnections.has(k))toast(c)});previousConnections=nowSet; }
let statusUpdateRunning=false;
async function update(){
 if(statusUpdateRunning||(document.hidden&&page!=='ao-vivo'))return;
 statusUpdateRunning=true;
 const controller=new AbortController();
 const timeoutId=setTimeout(()=>controller.abort(),4000);
 try{
  const statusEndpoint=page==='ao-vivo'
   ?'api/status.php?history_hours=24&ts='
   :'api/status.php?ts=';
  const r=await fetch(statusEndpoint+Date.now(),{cache:'no-store',signal:controller.signal});
  const d=await r.json();
  if(!d.ok)throw Error();
  render(d);
 }catch(e){
  $('#syncState').textContent='Reconectando';
 }finally{
  clearTimeout(timeoutId);
  statusUpdateRunning=false;
 }
}
async function loadReflectors(){ if(page!=='refletores') return; try{ const r=await fetch('api/reflectors.php?ts='+Date.now(), {cache:'no-store'}); const d=await r.json(); if(!d.ok) throw Error(); renderReflectors(d);} catch(e){ const tb=$('#reflectorRows'); if(tb) tb.innerHTML='<tr><td colspan="5">Não foi possível carregar a lista de refletores neste momento.</td></tr>'; }}
setInterval(()=>document.querySelectorAll('[data-start]').forEach(e=>e.textContent=elapsed(Number(e.dataset.start))),1000);

let liveUpdateRunning=false;
let liveUpdateTimer=null;
let previousLiveKeys=null;

/*
 * XLXMODERN_LIVE_STABILITY_V1
 *
 * Uma leitura rápida isolada não pode apagar um TX confirmado.
 * Mantém o último estado por 900 ms quando somente um poll perde
 * temporariamente o stream. Evita foto/GIF piscando e falso bip de fim.
 */
const XLXMODERN_LIVE_END_GRACE_MS=900;
let xlxmodernStableLiveActive={};
const xlxmodernLiveMissingSince=new Map();

function xlxmodernStabilizeLiveState(live){
 const now=Date.now();
 const next=Object.assign({},live,{active:Object.assign({},live?.active||{})});

 Object.keys(next.active).forEach(module=>{
  xlxmodernLiveMissingSince.delete(module);
 });

 Object.entries(xlxmodernStableLiveActive).forEach(([module,tx])=>{
  if(next.active[module])return;
  const since=xlxmodernLiveMissingSince.get(module)??now;
  xlxmodernLiveMissingSince.set(module,since);
  if(now-since<XLXMODERN_LIVE_END_GRACE_MS){
   next.active[module]=tx;
  }else{
   xlxmodernLiveMissingSince.delete(module);
  }
 });

 next.active_count=Object.keys(next.active).length;
 xlxmodernStableLiveActive=Object.assign({},next.active);
 return next;
}

let txRxAudioContext=null;
let txRxAudioUnlocked=false;
/*
 * Som habilitado por padrão.
 * Somente fica desligado quando o usuário escolhe explicitamente
 * a opção desativada.
 */
let txRxSoundEnabled=
 localStorage.getItem('xlxmodernTxRxSound')!=='disabled';

/* XLXMODERN_AUDIO_CONTROL_V5E */

function xlxmodernAudioStored(key,fallback){
 try{
  const value=localStorage.getItem(key);

  if(value===null){
   return fallback;
  }

  return value!=='disabled';

 }catch(error){
  return fallback;
 }
}

function xlxmodernPanelAudioEnabled(){
 return xlxmodernAudioStored(
  'xlxmodernPanelAudio',
  true
 );
}

function xlxmodernConnectedVoiceEnabled(){
 return (
  xlxmodernPanelAudioEnabled() &&
  xlxmodernAudioStored(
   'xlxmodernConnectedVoice',
   true
  )
 );
}

function xlxmodernTxBeepsEnabled(){
 return (
  xlxmodernPanelAudioEnabled() &&
  xlxmodernAudioStored(
   'xlxmodernTxBeeps',
   txRxSoundEnabled
  )
 );
}




/*
 * ==========================================================
 * XLXMODERN_CONNECTED_COUNT_VOICE_V1
 *
 * Fala somente o total já recebido pelo status.php.
 *
 * NÃO cria:
 * - fetch
 * - polling
 * - API
 * - timer recorrente
 *
 * Regras:
 * - somente página Ao Vivo
 * - respeita o mesmo botão de som dos bips
 * - espera 10 segundos após a última mudança
 * - máximo de 30 segundos durante mudanças contínuas
 * - nunca repete o mesmo total já falado
 * ==========================================================
 */

/*
 * XLXMODERN_CONNECTED_COUNT_VOICE_V103_NO_TX
 *
 * - conexao/desconexao: 3 segundos apos a ultima mudanca
 * - varias mudancas: somente o total final
 * - repeticao: a cada 30 minutos sem conectar/desconectar
 * - TX/RX nao reinicia os 30 minutos
 * - mesmo botao dos bips
 * - som ligado por padrao
 */

const CONNECTED_VOICE_DEBOUNCE_MS=3000;
const CONNECTED_VOICE_REPEAT_MS=1800000;

let connectedVoiceSignature=null;
let connectedVoiceCurrentTotal=null;

let connectedVoiceEventTimer=null;
let connectedVoicePendingEvent=false;

let connectedVoiceLastConnectionChangeAt=0;
let connectedVoiceNextRepeatAt=0;

let connectedVoiceUserActivated=false;

let connectedVoiceUtterance=null;
let connectedVoiceStarted=null;
let connectedVoiceLastError=null;


function connectedVoiceSupported(){
 return (
  'speechSynthesis' in window &&
  'SpeechSynthesisUtterance' in window
 );
}


function clearConnectedVoiceEventTimer(){
 if(connectedVoiceEventTimer===null)return;

 clearTimeout(connectedVoiceEventTimer);
 connectedVoiceEventTimer=null;
}


function chooseConnectedVoice(){
 try{
  const voices=
   window.speechSynthesis.getVoices()||[];

  return (
   voices.find(
    voice=>
     String(voice.lang||'')
      .toLowerCase()==='pt-br'
   )||
   voices.find(
    voice=>
     String(voice.lang||'')
      .toLowerCase()
      .startsWith('pt')
   )||
   null
  );

 }catch(error){
  return null;
 }
}


function connectedVoiceValue(total){
 return Math.max(
  0,
  Math.floor(Number(total)||0)
 );
}


/*
 * V10.3
 *
 * A locucao do total nunca deve competir com uma
 * transmissao digital ativa.
 */
function connectedVoiceTxActive(){
 return Number(lastData?.active_count||0)>0;
}


/*
 * Se TX comecar enquanto existe:
 * - timer de voz;
 * - anuncio pendente;
 * - locucao em andamento;
 *
 * preservamos o evento para falar depois do TX.
 */
function deferConnectedVoiceForTx(){
 if(page!=='ao-vivo')return;

 const hadVoiceWaiting=
  connectedVoicePendingEvent||
  connectedVoiceEventTimer!==null||
  connectedVoiceUtterance!==null;

 clearConnectedVoiceEventTimer();

 if(connectedVoiceUtterance!==null){
  /*
   * Zera a referencia antes do cancel().
   * Assim callbacks atrasados da utterance antiga
   * nao modificam o estado atual.
   */
  connectedVoiceUtterance=null;

  try{
   window.speechSynthesis.cancel();
  }catch(error){
  }
 }

 if(hadVoiceWaiting){
  connectedVoicePendingEvent=true;
 }
}


/*
 * Assinatura somente de CONEXAO.
 *
 * last_activity nao participa.
 * Portanto TX/RX nao reinicia os 30 minutos.
 */
function connectedVoiceConnectionKey(connection){
 const c=connection||{};

 return [
  c.callsign||'',
  c.suffix||'',
  c.protocol||'',
  c.module||'',
  c.ip||'',
  c.connected_at||''
 ]
 .map(value=>String(value))
 .join('|');
}


function connectedVoiceBuildSignature(data){
 const connections=
  Array.isArray(data?.connections)
   ?data.connections
   :[];

 return connections
  .map(connectedVoiceConnectionKey)
  .sort()
  .join('\n');
}


function speakConnectedCount(total,reason='event'){
 if(
  page!=='ao-vivo'||
  !xlxmodernConnectedVoiceEnabled()||
  !connectedVoiceUserActivated||
  !connectedVoiceSupported()||
  connectedVoiceTxActive()
 ){
  return false;
 }

 const value=
  connectedVoiceValue(total);

 try{
  window.speechSynthesis.cancel();

  const utterance=
   new SpeechSynthesisUtterance(
    `XLX zero vinte e seis com ${value} estações conectados.`
   );

  utterance.lang='pt-BR';

  /*
   * Rapida e mais animada.
   */
  utterance.rate=1.55;
  utterance.pitch=1.05;
  utterance.volume=1;

  const voice=chooseConnectedVoice();

  if(voice){
   utterance.voice=voice;
  }

  connectedVoiceUtterance=utterance;
  connectedVoiceLastError=null;

  utterance.onstart=()=>{
   if(connectedVoiceUtterance!==utterance)return;

   connectedVoiceStarted=value;
  };

  utterance.onend=()=>{
   if(connectedVoiceUtterance!==utterance)return;

   connectedVoiceUtterance=null;
  };

  utterance.onerror=event=>{
   if(connectedVoiceUtterance!==utterance)return;

   connectedVoiceLastError=
    String(event?.error||'speech-error');

   connectedVoiceUtterance=null;
  };

  window.speechSynthesis.speak(utterance);

  return true;

 }catch(error){
  connectedVoiceLastError=
   String(
    error?.message||
    error||
    'speech-error'
   );

  connectedVoiceUtterance=null;

  return false;
 }
}


function scheduleConnectedVoiceEvent(){
 clearConnectedVoiceEventTimer();

 if(
  page!=='ao-vivo'||
  connectedVoiceCurrentTotal===null||
  !connectedVoicePendingEvent||
  !xlxmodernConnectedVoiceEnabled()||
  !connectedVoiceUserActivated||
  !connectedVoiceSupported()||
  connectedVoiceTxActive()
 ){
  return;
 }

 connectedVoiceEventTimer=setTimeout(
  ()=>{
   connectedVoiceEventTimer=null;

   /*
    * V10.3:
    * TX ganhou prioridade.
    *
    * Se alguem estiver transmitindo agora,
    * o evento continua pendente.
    */
   if(connectedVoiceTxActive()){
    connectedVoicePendingEvent=true;
    return;
   }

   /*
    * Somente consumimos o evento quando
    * realmente chegou a hora de falar
    * SEM transmissao ativa.
    */
   connectedVoicePendingEvent=false;

   speakConnectedCount(
    connectedVoiceCurrentTotal,
    'event'
   );
  },
  CONNECTED_VOICE_DEBOUNCE_MS
 );
}


/*
 * Se o navegador atrasar timers em segundo plano,
 * nao toca todas as repeticoes atrasadas.
 * Avanca direto para o proximo ciclo futuro.
 */
function advanceConnectedVoiceRepeat(now){
 if(!connectedVoiceNextRepeatAt)return;

 while(connectedVoiceNextRepeatAt<=now){
  connectedVoiceNextRepeatAt+=
   CONNECTED_VOICE_REPEAT_MS;
 }
}


function trackConnectedCountVoice(data){
 if(page!=='ao-vivo')return;

 const now=Date.now();

 const value=
  connectedVoiceValue(
   data?.connected_count
  );

 const signature=
  connectedVoiceBuildSignature(data);

 connectedVoiceCurrentTotal=value;


 /*
  * Primeira leitura da pagina:
  * baseline atual + primeira fala apos 3 segundos.
  */
 if(connectedVoiceSignature===null){
  connectedVoiceSignature=signature;

  connectedVoiceLastConnectionChangeAt=now;

  connectedVoiceNextRepeatAt=
   now+CONNECTED_VOICE_REPEAT_MS;

  connectedVoicePendingEvent=true;

  scheduleConnectedVoiceEvent();

  return;
 }


 /*
  * Mudou a composicao das conexoes:
  * alguem entrou, saiu ou reconectou.
  */
 if(signature!==connectedVoiceSignature){
  connectedVoiceSignature=signature;

  connectedVoiceLastConnectionChangeAt=now;

  connectedVoiceNextRepeatAt=
   now+CONNECTED_VOICE_REPEAT_MS;

  connectedVoicePendingEvent=true;

  /*
   * Nova mudanca reinicia os 3 segundos.
   */
  scheduleConnectedVoiceEvent();

  return;
 }


 /*
  * Se aguardava a fala e antes faltava liberacao
  * de audio, permite reagendar depois.
  */
 if(
  connectedVoicePendingEvent &&
  connectedVoiceEventTimer===null
 ){
  scheduleConnectedVoiceEvent();
 }


 /*
  * Repeticao a cada 30 minutos SEM
  * qualquer conexao/desconexao.
  *
  * TX/RX nao altera connectedVoiceSignature.
  */
 if(
  connectedVoiceNextRepeatAt &&
  now>=connectedVoiceNextRepeatAt &&
  !connectedVoiceTxActive()
 ){
  speakConnectedCount(
   connectedVoiceCurrentTotal,
   'repeat'
  );

  advanceConnectedVoiceRepeat(now);
 }
}


function armConnectedVoice(){
 if(page!=='ao-vivo')return;

 connectedVoiceUserActivated=true;

 scheduleConnectedVoiceEvent();
}


if(page==='ao-vivo'){
 document.addEventListener(
  'pointerdown',
  armConnectedVoice,
  {
   once:true,
   passive:true
  }
 );

 document.addEventListener(
  'keydown',
  armConnectedVoice,
  {
   once:true
  }
 );
}


/* /XLXMODERN_CONNECTED_COUNT_VOICE_V101 */


function updateTxRxSoundButton(){
 const button=document.getElementById('txRxSoundButton');

 if(!button)return;

 button.textContent=txRxSoundEnabled?'🔊':'🔇';

 button.setAttribute(
  'aria-pressed',
  txRxSoundEnabled?'true':'false'
 );

 button.setAttribute(
  'aria-label',
  txRxSoundEnabled
   ?'Desativar avisos sonoros'
   :'Ativar avisos sonoros'
 );

 button.title=txRxSoundEnabled
  ?'Som ativado — clique para desativar'
  :'Som desativado — clique para ativar';
}

function ensureTxRxSoundButton(){
 if(page!=='ao-vivo')return;

 const heading=document.querySelector(
  '.live-widget .widget-heading'
 );

 if(!heading||document.getElementById('txRxSoundButton')){
  return;
 }

 const button=document.createElement('button');

 button.id='txRxSoundButton';
 button.type='button';
 button.className='txrx-sound-button';
 button.title='Som ativado — clique para desativar';

 button.addEventListener('click',async()=>{
  txRxSoundEnabled=!txRxSoundEnabled;

  localStorage.setItem(
   'xlxmodernTxRxSound',
   txRxSoundEnabled?'enabled':'disabled'
  );

  if(txRxSoundEnabled){
   txRxAudioUnlocked=false;
   await unlockTxRxAudio();

   if(txRxAudioUnlocked){
    playTxRxTone(660,80,0);
   }
  }

  updateTxRxSoundButton();
 });

 heading.appendChild(button);
 updateTxRxSoundButton();
}


async function unlockTxRxAudio(playConfirmation=false){
 if(!txRxSoundEnabled||!xlxmodernPanelAudioEnabled()||!xlxmodernTxBeepsEnabled())return false;

 const AudioContextClass=
  window.AudioContext||window.webkitAudioContext;

 if(!AudioContextClass)return false;

 try{
  txRxAudioContext=
   txRxAudioContext||new AudioContextClass();

  /*
   * resume() é chamado diretamente durante o gesto autorizado.
   */
  if(txRxAudioContext.state==='suspended'){
   await txRxAudioContext.resume();
  }

  if(txRxAudioContext.state!=='running'){
   return false;
  }

  txRxAudioUnlocked=true;

  /*
   * Um som realmente audível confirma ao navegador que o áudio
   * foi iniciado pela interação do usuário.
   */
  if(playConfirmation){
   const start=txRxAudioContext.currentTime;
   const oscillator=txRxAudioContext.createOscillator();
   const gain=txRxAudioContext.createGain();

   oscillator.type='sine';
   oscillator.frequency.setValueAtTime(660,start);

   gain.gain.setValueAtTime(0.0001,start);
   gain.gain.exponentialRampToValueAtTime(
    0.06,
    start+0.01
   );
   gain.gain.exponentialRampToValueAtTime(
    0.0001,
    start+0.07
   );

   oscillator.connect(gain);
   gain.connect(txRxAudioContext.destination);

   oscillator.start(start);
   oscillator.stop(start+0.09);
  }

  return true;
 }catch(error){
  txRxAudioUnlocked=false;
  return false;
 }
}

/*
 * O primeiro gesto real na página desbloqueia o áudio.
 * O ouvinte permanece instalado até o navegador confirmar sucesso.
 */
async function handleTxRxAudioGesture(){
 if(
  !txRxSoundEnabled||
  txRxAudioUnlocked
 ){
  return;
 }

 const unlocked=await unlockTxRxAudio(true);

 if(unlocked){
  document.removeEventListener(
   'pointerdown',
   handleTxRxAudioGesture,
   true
  );

  document.removeEventListener(
   'keydown',
   handleTxRxAudioGesture,
   true
  );
 }
}

document.addEventListener(
 'pointerdown',
 handleTxRxAudioGesture,
 {
  capture:true,
  passive:true
 }
);

document.addEventListener(
 'keydown',
 handleTxRxAudioGesture,
 true
);

/*
 * XLXMODERN_TXRX_SOUND_STRONG_V1
 * Sinais TX/RX mais fortes e distintos.
 */
function playTxRxTone(frequency,duration,delay){
 if(!txRxSoundEnabled||!xlxmodernPanelAudioEnabled()||!xlxmodernTxBeepsEnabled())return;

 const AudioContextClass=
  window.AudioContext||window.webkitAudioContext;

 if(!AudioContextClass)return;

 txRxAudioContext=
  txRxAudioContext||new AudioContextClass();

 if(txRxAudioContext.state!=='running'){
  return;
 }

 txRxAudioUnlocked=true;

 const start=
  txRxAudioContext.currentTime+(delay/1000);

 const oscillator=txRxAudioContext.createOscillator();
 const gain=txRxAudioContext.createGain();

 oscillator.type='square';
 oscillator.frequency.setValueAtTime(frequency,start);

 gain.gain.setValueAtTime(0.0001,start);
 gain.gain.exponentialRampToValueAtTime(
  0.60,
  start+0.008
 );
 gain.gain.exponentialRampToValueAtTime(
  0.0001,
  start+(duration/1000)
 );

 oscillator.connect(gain);
 gain.connect(txRxAudioContext.destination);

 oscillator.start(start);
 oscillator.stop(start+(duration/1000)+0.02);
}

/*
 * Início: bip único, mais agudo e forte.
 */
function playTxStartedSound(){
 playTxRxTone(2700,115,0);
}

/*
 * Final: dois bips descendentes.
 */
/*
 * XLXMODERN_TXRX_END_DOUBLE_BEEP_V1
 * Fim de TX com dois bips mais separados e nítidos.
 */
function playTxEndedSound(){
 playTxRxTone(2350,95,0);
 playTxRxTone(2350,95,155);
}

function detectTxRxSound(active){
 const currentKeys=new Set(
  Object.values(active||{}).map(tx=>
   String(tx.key||`${tx.module}:${tx.stream_id}:${tx.started_at||''}`)
  )
 );

 /*
  * Na primeira leitura apenas memoriza o estado.
  * Não toca som ao abrir ou atualizar a página.
  */
 if(previousLiveKeys===null){
  previousLiveKeys=currentKeys;
  return;
 }

 const started=[...currentKeys].some(
  key=>!previousLiveKeys.has(key)
 );

 const ended=[...previousLiveKeys].some(
  key=>!currentKeys.has(key)
 );

 if(started){
  deferConnectedVoiceForTx();
  playTxStartedSound();
 }

 if(ended){
  playTxEndedSound();
 }

 previousLiveKeys=currentKeys;
}


let lastLiveVisualSignature=null;

function renderLiveTxRxOnly(live){
 if(page!=='ao-vivo'||!lastData)return;

 const moduleGrid=document.getElementById('moduleGrid');
 const widgetCount=document.getElementById('widgetCount');
 const headerActive=document.getElementById('headerActive');

 const active=Object.values(lastData.modules)
  .filter(module=>module.transmission);

 /*
  * Identifica somente mudanças reais do box:
  * início, encerramento ou troca de transmissão.
  *
  * Enquanto o estado permanece igual, não recria o HTML.
  * Assim, radar, VU e demais animações não reiniciam a cada 250 ms.
  */
 const visualSignature=active.length
  ?active
    .map(module=>{
     const tx=module.transmission||{};

     return [
      module.module||'',
      tx.key||'',
      tx.stream_id||'',
      tx.callsign||'',
      tx.suffix||'',
      tx.gateway||'',
      tx.ip||'',
      tx.protocol||''
     ].join(':');
    })
    .sort()
    .join('|')
  :'standby';

 if(widgetCount){
  widgetCount.textContent=live.active_count
   ?`${live.active_count} no ar`
   :'Standby';
 }

 if(headerActive){
  headerActive.textContent=live.active_count;
 }

 /*
  * Redesenha o conteúdo visual somente quando houver
  * alteração efetiva no estado TX/RX.
  */
 if(
  moduleGrid&&
  visualSignature!==lastLiveVisualSignature
 ){
  if(active.length){
   moduleGrid.innerHTML=active
    .slice(0,3)
    .map(txCard)
    .join('');

   window.XLXMODERNMTR?.sync(
    active.slice(0,3)
   );
  }else{
   const newest=[...(lastData.history||[])]
    .sort((a,b)=>b.started_at-a.started_at)[0]||null;

   const standbyModule=
    Object.values(lastData.modules)[0];

   if(standbyModule){
    moduleGrid.innerHTML=
     standbyCard(standbyModule,newest);
   }

   window.XLXMODERNMTR?.sync([]);
  }

  lastLiveVisualSignature=visualSignature;
 }

 updateTitle(lastData);
 ensureTxRxSoundButton();
}


/* ==========================================================
   XLXMODERN_LIVE_IDENTITY_MERGE_V10

   A API live.php continua responsável pela velocidade.

   A identidade do operador é preservada do status.php
   quando módulo/stream/horário comprovam que se trata
   da mesma transmissão.
   ========================================================== */

let xlxmodernLastIdentityRefreshKey='';

function xlxmodernBaseCall(value){
 return String(value||'')
  .replace(/\s+/g,' ')
  .trim()
  .toUpperCase()
  .split(' ')[0]||'';
}

function xlxmodernLiveIdentityKey(tx){
 if(!tx)return '';

 return String(
  tx.key||
  [
   tx.module||'',
   tx.stream_id||'',
   tx.started_at||''
  ].join(':')
 );
}

function xlxmodernSameTransmission(a,b){
 if(!a||!b)return false;

 const sidA=Number(a.stream_id||0);
 const sidB=Number(b.stream_id||0);

 const startA=Number(a.started_at||0);
 const startB=Number(b.started_at||0);

 return (
  sidA>0 &&
  sidB>0 &&
  sidA===sidB &&
  startA>0 &&
  startB>0 &&
  Math.abs(startA-startB)<=2
 );
}

function xlxmodernHasStationIdentity(tx){
 return Boolean(
  tx &&
  String(tx.identity_source||'')
   .indexOf('xlxd-station')===0
 );
}

function xlxmodernMergeLiveIdentity(
 liveTx,
 statusTx
){
 if(
  !xlxmodernSameTransmission(
   liveTx,
   statusTx
  ) ||
  !xlxmodernHasStationIdentity(statusTx)
 ){
  return liveTx;
 }

 const merged=Object.assign(
  {},
  liveTx
 );

 [
  'callsign',
  'suffix',
  'name',
  'location',
  'country',
  'protocol',
  'qrz',
  'gateway',
  'gateway_suffix',
  'network_callsign',
  'identity_source',
  'origin_match'
 ].forEach(field=>{
  if(
   Object.prototype.hasOwnProperty.call(
    statusTx,
    field
   )
  ){
   merged[field]=statusTx[field];
  }
 });

 return merged;
}

function xlxmodernLiveIdentityLooksAmbiguous(tx){
 if(!tx)return false;

 const call=
  xlxmodernBaseCall(tx.callsign);

 const gateway=
  xlxmodernBaseCall(tx.gateway);

 return Boolean(
  call &&
  gateway &&
  call===gateway &&
  !xlxmodernHasStationIdentity(tx)
 );
}

/* /XLXMODERN_LIVE_IDENTITY_MERGE_V10 */


async function updateLiveTxRx(){
 if(
  liveUpdateRunning||
  document.hidden||
  page!=='ao-vivo'||
  !lastData
 )return;

 liveUpdateRunning=true;

 const controller=new AbortController();
 const timeoutId=setTimeout(
  ()=>controller.abort(),
  1200
 );

 try{
  const response=await fetch(
   'api/live.php?ts='+Date.now(),
   {
    cache:'no-store',
    signal:controller.signal
   }
  );

  let live=await response.json();

  if(!live.ok)throw Error();

  live=xlxmodernStabilizeLiveState(live);
  detectTxRxSound(live.active);

  let requestIdentityRefresh=false;

  Object.values(lastData.modules).forEach(module=>{
   const liveTx=
    live.active[module.module]||null;

   const statusTx=
    module.transmission||null;

   if(!liveTx){
    module.transmission=null;
    return;
   }

   const merged=
    xlxmodernMergeLiveIdentity(
     liveTx,
     statusTx
    );

   module.transmission=merged;

   /*
    * Uma transmissão nova chegou pela API rápida,
    * mas ainda não temos identidade STATION para ela.
    *
    * Solicita imediatamente UMA atualização da API
    * completa para esta stream, em vez de esperar
    * o ciclo normal de 5 segundos.
    */
   if(
    merged===liveTx &&
    xlxmodernLiveIdentityLooksAmbiguous(
     liveTx
    )
   ){
    const refreshKey=
     xlxmodernLiveIdentityKey(liveTx);

    if(
     refreshKey &&
     refreshKey!==
      xlxmodernLastIdentityRefreshKey
    ){
     xlxmodernLastIdentityRefreshKey=
      refreshKey;

     requestIdentityRefresh=true;
    }
   }
  });

  if(requestIdentityRefresh){
   Promise.resolve().then(()=>{
    update();
   });
  }

  lastData.active_count=live.active_count;
  lastData.generated_at=live.generated_at;

  /*
   * V10.3:
   * acabou todo TX e existe anuncio pendente:
   * inicia os 3 segundos somente agora.
   */
  if(
   Number(live.active_count||0)===0 &&
   connectedVoicePendingEvent &&
   connectedVoiceEventTimer===null
  ){
   scheduleConnectedVoiceEvent();
  }

  renderLiveTxRxOnly(live);
 }catch(error){
 }finally{
  clearTimeout(timeoutId);
  liveUpdateRunning=false;
 }
}

const LIVE_POLL_ACTIVE_MS=350;
const LIVE_POLL_STANDBY_MS=500;

let liveLoopEnabled=false;

function livePollDelay(){
 return Number(lastData?.active_count||0)>0
  ? LIVE_POLL_ACTIVE_MS
  : LIVE_POLL_STANDBY_MS;
}

async function runLiveTxRxLoop(){
 if(
  !liveLoopEnabled||
  document.hidden||
  page!=='ao-vivo'
 ){
  liveUpdateTimer=null;
  return;
 }

 const cycleStarted=performance.now();

 await updateLiveTxRx();

 if(
  !liveLoopEnabled||
  document.hidden||
  page!=='ao-vivo'
 ){
  liveUpdateTimer=null;
  return;
 }

 const targetDelay=livePollDelay();

 const elapsed=
  performance.now()-cycleStarted;

 const wait=Math.max(
  0,
  targetDelay-elapsed
 );

 liveUpdateTimer=setTimeout(
  runLiveTxRxLoop,
  wait
 );
}

function startLiveTxRx(){
 if(page!=='ao-vivo')return;

 liveLoopEnabled=true;

 if(
  liveUpdateTimer!==null||
  liveUpdateRunning
 )return;

 ensureTxRxSoundButton();

 liveUpdateTimer=setTimeout(
  runLiveTxRxLoop,
  0
 );
}

function stopLiveTxRx(){
 liveLoopEnabled=false;

 if(liveUpdateTimer===null)return;

 clearTimeout(liveUpdateTimer);
 liveUpdateTimer=null;
}

let statusUpdateTimer=null;
function startStatusUpdates(){
 if(statusUpdateTimer!==null)return;
 update();
 statusUpdateTimer=setInterval(update,5000);
}
function stopStatusUpdates(){
 if(statusUpdateTimer===null)return;
 clearInterval(statusUpdateTimer);
 statusUpdateTimer=null;
}
document.addEventListener('visibilitychange',()=>{
 if(document.hidden){
  if(page!=='ao-vivo'){
   stopStatusUpdates();
  }

  stopLiveTxRx();

 }else{
  startStatusUpdates();
  startLiveTxRx();
 }
});

if(page==='ao-vivo'||!document.hidden){
 startStatusUpdates();
}

if(!document.hidden){
 startLiveTxRx();
}
loadReflectors();
$('#historyRows')?.addEventListener('click',event=>{
 const longButton=event.target.closest('[data-history-long-toggle]');
 if(longButton){event.preventDefault();event.stopPropagation();toggleLongHistory(longButton);return;}
 const button=event.target.closest('[data-history-toggle]');
 if(!button)return;
 event.preventDefault();
 event.stopPropagation();
 toggleHistoryGroup(button.dataset.historyToggle||'',button);
});
$('#historyPeriodSelect')?.addEventListener('change',event=>{
 const days=Number(event.target.value||1);
 xlxmodernHistoryPeriodDays=[1,7,30].includes(days)?days:1;
 historyExpandedCalls.clear();
 if(xlxmodernHistoryPeriodDays===1){
  const title=$('#historyPeriodTitle'),note=$('#historyCoverageNote');
  if(title)title.textContent=xlxmodernHistoryPeriodText(1);
  if(note)note.textContent='Todos os indicativos';
  if(lastData){$('#historyRows').innerHTML=historyMarkup(lastData);xlxmodernHistorySignature='';}
 }else xlxmodernLoadLongHistory(xlxmodernHistoryPeriodDays);
});
function refreshConnectedFilters(){
 if(lastData&&page==='conectados')renderConnectedTable(lastData);
}
$('#connectedSearch')?.addEventListener('input',refreshConnectedFilters);
$('#connectedModuleFilter')?.addEventListener('change',refreshConnectedFilters);
$('#connectedProtocolFilter')?.addEventListener('change',refreshConnectedFilters);
const toggle=document.querySelector('.universal-header .menu-toggle');
const nav=document.querySelector('.universal-header .universal-nav');
toggle?.addEventListener('click',()=>{if(!nav)return;const open=nav.classList.toggle('open');toggle.setAttribute('aria-expanded',String(open))});

/* ==========================================================
   XLXMODERN V39 — tabelas móveis estáveis, sem piscar
   ========================================================== */
(() => {
    'use strict';

    const MOBILE_WIDTH = 820;

    let updatePending = false;
    let observerStarted = false;

    const normalize = value => String(value || '')
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .replace(/\s+/g, ' ')
        .trim()
        .toLowerCase();

    const findColumn = (headers, aliases) => {
        return headers.findIndex(header => {
            const current = normalize(header);

            return aliases.some(alias => {
                const expected = normalize(alias);

                return current === expected
                    || current.includes(expected);
            });
        });
    };

    const countryCodeToFlag = code => {
        const value = String(code || '')
            .trim()
            .toUpperCase();

        if (!/^[A-Z]{2}$/.test(value)) {
            return '';
        }

        return String.fromCodePoint(
            ...Array.from(value).map(
                letter => 127397 + letter.charCodeAt(0)
            )
        );
    };

    const getPanelTitle = table => {
        const container = table.closest(
            'section, article, .panel, .card, '
            + '.table-panel, .data-panel'
        );

        if (!container) {
            return '';
        }

        const heading = container.querySelector(
            'h1, h2, h3, h4, '
            + '.panel-title, .card-title, .section-title'
        );

        return normalize(
            heading ? heading.textContent : ''
        );
    };

    const isTargetTable = table => {
        const title = getPanelTitle(table);

        return (
            title.includes('estacoes conectadas')
            || title.includes('estacao conectada')
            || title.includes('conectados')
            || title.includes('ultimas transmissoes')
            || title.includes('ultima transmissao')
        );
    };

    const markColumn = (table, index, className) => {
        if (index < 0) {
            return;
        }

        Array.from(table.rows).forEach(row => {
            const cell = row.cells[index];

            if (cell) {
                cell.classList.add(className);
            }
        });
    };

    const configureFlags = (table, countryIndex) => {
        if (countryIndex < 0) {
            return;
        }

        Array.from(table.tBodies).forEach(tbody => {
            Array.from(tbody.rows).forEach(row => {
                const cell = row.cells[countryIndex];

                if (!cell) {
                    return;
                }

                if (cell.querySelector('img, picture, svg')) {
                    cell.classList.add('xlx-v39-native-flag');
                    return;
                }

                const countryCode = String(
                    cell.dataset.countryCode
                    || cell.textContent
                    || ''
                )
                    .replace(/\s+/g, ' ')
                    .trim()
                    .toUpperCase();

                const flag = countryCodeToFlag(countryCode);

                if (!flag) {
                    return;
                }

                /*
                 * Não modifica textContent.
                 * Isso evita disparar novamente o MutationObserver.
                 */
                cell.dataset.countryCode = countryCode;
                cell.dataset.countryFlag = flag;
                cell.classList.add('xlx-v39-emoji-flag');
                cell.title = countryCode;
                cell.setAttribute(
                    'aria-label',
                    'País ' + countryCode
                );
            });
        });
    };

    const configureTable = table => {
        if (!isTargetTable(table)) {
            return;
        }

        let headerCells = Array.from(
            table.querySelectorAll(
                'thead tr:last-child th'
            )
        );

        if (!headerCells.length) {
            headerCells = Array.from(
                table.querySelectorAll(
                    'tr:first-child th'
                )
            );
        }

        if (!headerCells.length) {
            return;
        }

        const headers = headerCells.map(
            cell => cell.textContent
        );

        const countryIndex = findColumn(headers, [
            'país',
            'pais',
            'country',
            'bandeira'
        ]);

        const callsignIndex = findColumn(headers, [
            'indicativo',
            'callsign',
            'call sign',
            'estação',
            'estacao'
        ]);

        const nameIndex = findColumn(headers, [
            'nome',
            'operador',
            'operator',
            'name'
        ]);

        let locationIndex = findColumn(headers, [
            'localização',
            'localizacao',
            'localidade',
            'location'
        ]);

        if (locationIndex < 0) {
            locationIndex = findColumn(headers, [
                'cidade',
                'city',
                'município',
                'municipio'
            ]);
        }

        if (callsignIndex < 0) {
            return;
        }

        table.classList.add('xlx-v38-mobile-table');
        table.classList.add('xlx-v39-stable-table');

        markColumn(
            table,
            countryIndex,
            'xlx-v38-country'
        );

        markColumn(
            table,
            callsignIndex,
            'xlx-v38-call'
        );

        markColumn(
            table,
            nameIndex,
            'xlx-v38-name'
        );

        markColumn(
            table,
            locationIndex,
            'xlx-v38-location'
        );

        configureFlags(table, countryIndex);

        if (table.parentElement) {
            table.parentElement.classList.add(
                'xlx-v38-table-container'
            );
        }
    };

    const updateTables = () => {
        updatePending = false;

        document.querySelectorAll('table').forEach(
            configureTable
        );

        document.documentElement.classList.add(
            'xlx-v39-ready'
        );
    };

    const scheduleUpdate = () => {
        if (updatePending) {
            return;
        }

        updatePending = true;

        window.requestAnimationFrame(() => {
            updateTables();
        });
    };

    const startObserver = () => {
        if (observerStarted) {
            return;
        }

        observerStarted = true;

        const observer = new MutationObserver(mutations => {
            /*
             * Observa somente inclusão ou remoção de elementos.
             * Alterações de classe e data-* feitas pela V39
             * não disparam uma nova atualização.
             */
            const relevant = mutations.some(mutation => {
                if (mutation.type !== 'childList') {
                    return false;
                }

                return (
                    mutation.addedNodes.length > 0
                    || mutation.removedNodes.length > 0
                );
            });

            if (relevant) {
                scheduleUpdate();
            }
        });

        observer.observe(document.body, {
            childList: true,
            subtree: true,
            attributes: false,
            characterData: false
        });
    };

    document.addEventListener(
        'DOMContentLoaded',
        () => {
            scheduleUpdate();
            startObserver();
        }
    );

    window.addEventListener(
        'load',
        scheduleUpdate
    );

    window.addEventListener(
        'resize',
        scheduleUpdate,
        { passive: true }
    );

    /*
     * PERFORMANCE V1B:
     * MutationObserver já acompanha inclusão/remoção.
     * Evita varrer todas as tabelas a cada 2 segundos.
     */

    if (document.readyState !== 'loading') {
        scheduleUpdate();

        if (document.body) {
            startObserver();
        }
    }
})();

/* ==========================================================
   XLXMODERN_TX_CALLSIGN_FIX_V2
   OTIMIZADO
   ========================================================== */
(function () {
  'use strict';

  if (window.__XLXMODERN_TX_CALLSIGN_FIX_V2__) return;
  window.__XLXMODERN_TX_CALLSIGN_FIX_V2__ = true;

  function normalizeLiveCallsign(raw) {
    const txt = String(raw || '')
      .replace(/\s+/g, ' ')
      .trim()
      .toUpperCase();

    if (!txt) return '';

    const match =
      txt.match(/^([A-Z0-9\/]+)\s+([A-Z])$/);

    if (match) {
      return match[1] + '-' + match[2];
    }

    return txt;
  }

  function fixLiveTxCard() {
    if (
      !document.body ||
      document.body.dataset.page !== 'ao-vivo'
    ) {
      return;
    }

    const grid =
      document.getElementById('moduleGrid');

    if (!grid) return;

    grid
      .querySelectorAll(
        '.tx-card.live .callsign'
      )
      .forEach(function (el) {

        const current =
          String(el.textContent || '')
            .replace(/\s+/g, ' ')
            .trim()
            .toUpperCase();

        const fixed =
          normalizeLiveCallsign(current);

        /*
         * Só altera conteúdo quando realmente necessário.
         */
        if (
          fixed &&
          fixed !== current
        ) {
          el.textContent = fixed;
        }

        if (
          el.style.whiteSpace !== 'nowrap'
        ) {
          el.style.whiteSpace = 'nowrap';
        }

        if (
          el.style.wordBreak !== 'normal'
        ) {
          el.style.wordBreak = 'normal';
        }

        if (
          el.style.overflowWrap !== 'normal'
        ) {
          el.style.overflowWrap = 'normal';
        }
      });
  }

  function startCallsignFix() {

    const grid =
      document.getElementById('moduleGrid');

    if (!grid) return;

    let scheduled = false;

    function scheduleFix() {

      if (scheduled) return;

      scheduled = true;

      window.requestAnimationFrame(
        function () {
          scheduled = false;
          fixLiveTxCard();
        }
      );
    }

    /*
     * Primeira verificação.
     */
    fixLiveTxCard();

    /*
     * Observa somente o box que realmente muda.
     * Não observa mais o document.body inteiro.
     */
    const observer =
      new MutationObserver(scheduleFix);

    observer.observe(
      grid,
      {
        childList: true,
        subtree: true,
        characterData: true
      }
    );
  }

  if (
    document.readyState === 'loading'
  ) {
    document.addEventListener(
      'DOMContentLoaded',
      startCallsignFix,
      { once: true }
    );
  } else {
    startCallsignFix();
  }

})();

/* FIM XLXMODERN_TX_CALLSIGN_FIX_V2 */







/* ==========================================================
   XLXMODERN_MENU_MOBILE_FECHADO_V3
   Controle do menu mobile
   ========================================================== */

(() => {
    'use strict';

    const MOBILE_QUERY = '(max-width: 820px)';

    function initXLXMODERNMobileMenuV3(){

        const header = document.querySelector('.universal-header');
        if (!header) return;

        const row = header.querySelector('.universal-header-row');
        const nav = header.querySelector('.universal-nav');

        if (!row || !nav) return;

        let wrap = header.querySelector('.xlxmodern-mobile-togglebar');
        let button = wrap ? wrap.querySelector('button') : null;

        if (!wrap){
            wrap = document.createElement('div');
            wrap.className = 'xlxmodern-mobile-togglebar';
        }

        if (!button){
            button = document.createElement('button');
            button.type = 'button';
            button.textContent = 'MENU';
            button.setAttribute('aria-expanded', 'false');
            button.setAttribute('aria-label', 'Abrir menu');
            wrap.appendChild(button);
        }

        if (!wrap.parentNode){
            row.insertBefore(wrap, nav);
        }

        const isMobile = () => window.matchMedia(MOBILE_QUERY).matches;

        function fecharMenu(){
            nav.classList.remove('open');
            nav.classList.remove('xlxmodern-mobile-open-v3');

            button.textContent = 'MENU';
            button.setAttribute('aria-expanded', 'false');
            button.setAttribute('aria-label', 'Abrir menu');
        }

        function abrirMenu(){
            nav.classList.remove('open');
            nav.classList.add('xlxmodern-mobile-open-v3');

            button.textContent = 'FECHAR';
            button.setAttribute('aria-expanded', 'true');
            button.setAttribute('aria-label', 'Fechar menu');
        }

        function ajustarEstadoInicial(){
            if (isMobile()){
                fecharMenu();
            } else {
                nav.classList.remove('xlxmodern-mobile-open-v3');
                nav.classList.remove('open');
                button.textContent = 'MENU';
                button.setAttribute('aria-expanded', 'false');
            }
        }

        ajustarEstadoInicial();

        if (!button.dataset.xlxmodernBound){
            button.addEventListener('click', function(ev){
                ev.preventDefault();
                ev.stopPropagation();

                if (!isMobile()) return;

                if (nav.classList.contains('xlxmodern-mobile-open-v3')){
                    fecharMenu();
                } else {
                    abrirMenu();
                }
            });

            button.dataset.xlxmodernBound = '1';
        }

        if (!nav.dataset.xlxmodernBound){
            nav.addEventListener('click', function(ev){
                const link = ev.target.closest('a');
                if (!link) return;

                if (isMobile()){
                    fecharMenu();
                }
            });

            nav.dataset.xlxmodernBound = '1';
        }

        window.addEventListener('resize', ajustarEstadoInicial, { passive:true });

        document.addEventListener('keydown', function(ev){
            if (ev.key === 'Escape' && isMobile()){
                fecharMenu();
            }
        });
    }

    if (document.readyState === 'loading'){
        document.addEventListener('DOMContentLoaded', initXLXMODERNMobileMenuV3, { once:true });
    } else {
        initXLXMODERNMobileMenuV3();
    }

})();

/* FIM XLXMODERN_MENU_MOBILE_FECHADO_V3 */


/* XLXMODERN_AUDIO_API_V5E */

function xlxmodernStopWebAudio(){

 try{

  if(txRxAudioContext){

   if(
    typeof txRxAudioContext.close==='function'
   ){
    txRxAudioContext.close();

   }else if(
    txRxAudioContext.state==='running' &&
    typeof txRxAudioContext.suspend==='function'
   ){
    txRxAudioContext.suspend();
   }
  }

 }catch(error){}

 txRxAudioContext=null;
 txRxAudioUnlocked=false;
}


window.XLXMODERNAudioControl={

 state:function(){

  return {

   master:
    xlxmodernAudioStored(
     'xlxmodernPanelAudio',
     true
    ),

   voice:
    xlxmodernAudioStored(
     'xlxmodernConnectedVoice',
     true
    ),

   beeps:
    xlxmodernAudioStored(
     'xlxmodernTxBeeps',
     txRxSoundEnabled
    )

  };
 },


 setMaster:function(enabled){

  enabled=!!enabled;

  try{
   localStorage.setItem(
    'xlxmodernPanelAudio',
    enabled?'enabled':'disabled'
   );
  }catch(error){}

  if(!enabled){

   try{
    clearConnectedVoiceTimer();
   }catch(error){}

   try{
    if('speechSynthesis' in window){
     window.speechSynthesis.cancel();
    }
   }catch(error){}

   xlxmodernStopWebAudio();

   return true;
  }

  if(
   txRxSoundEnabled &&
   xlxmodernTxBeepsEnabled()
  ){
   try{
    unlockTxRxAudio(false);
   }catch(error){}
  }

  return true;
 },


 setVoice:function(enabled){

  enabled=!!enabled;

  try{
   localStorage.setItem(
    'xlxmodernConnectedVoice',
    enabled?'enabled':'disabled'
   );
  }catch(error){}

  if(!enabled){

   try{
    clearConnectedVoiceTimer();
   }catch(error){}

   try{
    if('speechSynthesis' in window){
     window.speechSynthesis.cancel();
    }
   }catch(error){}
  }

  return true;
 },


 setBeeps:function(enabled){

  enabled=!!enabled;

  txRxSoundEnabled=enabled;

  try{

   localStorage.setItem(
    'xlxmodernTxBeeps',
    enabled?'enabled':'disabled'
   );

   localStorage.setItem(
    'xlxmodernTxRxSound',
    enabled?'enabled':'disabled'
   );

  }catch(error){}

  try{
   updateTxRxSoundButton();
  }catch(error){}

  if(!enabled){

   xlxmodernStopWebAudio();

   return true;
  }

  if(xlxmodernPanelAudioEnabled()){

   try{
    unlockTxRxAudio(false);
   }catch(error){}
  }

  return true;
 },


 testBeep:function(){

  if(
   !xlxmodernPanelAudioEnabled() ||
   !xlxmodernTxBeepsEnabled()
  ){
   return false;
  }

  txRxSoundEnabled=true;

  try{

   unlockTxRxAudio(false).then(
    function(ok){

     if(ok){
      playTxRxTone(
       2700,
       100,
       0
      );
     }
    }
   );

  }catch(error){}

  return true;
 },


 stopAll:function(){

  try{
   clearConnectedVoiceTimer();
  }catch(error){}

  try{
   if('speechSynthesis' in window){
    window.speechSynthesis.cancel();
   }
  }catch(error){}

  xlxmodernStopWebAudio();

  return true;
 }

};
