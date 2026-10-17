const $=s=>document.querySelector(s);let previousConnections=null,lastData=null;const page=document.body.dataset.page||'ao-vivo';
const historyExpandedCalls=new Set();
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
const xlx026QrzPhotoCache=new Map();
function xlx026SyncQrzPhotoSizes(root=document){
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

  if(desktop){
   const person=v.closest('.tx-v30-person');
   const data=person?.querySelector('.tx-v30-person-data');
   const personColumns={
    1:'132px minmax(0,1fr)',
    2:'106px minmax(0,1fr)',
    3:'90px minmax(0,1fr)'
   }[count]||'90px minmax(0,1fr)';
   const personGap={1:'20px',2:'10px',3:'8px'}[count]||'8px';
   if(person){
    if(count===1)person.classList.add('qrz-one-tx-layout');
    person.style.setProperty('display','grid','important');
    person.style.setProperty('grid-template-columns',personColumns,'important');
    person.style.setProperty('gap',personGap,'important');
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
 const cached=xlx026QrzPhotoCache.get(c);
 const hasPhoto=typeof cached==='string'&&cached!=='';
 const src=hasPhoto?cached:'assets/talking-radio.gif';
 const visualClass=hasPhoto?'operator-visual qrz-photo-active':'operator-visual';
 const imageClass=hasPhoto?'tx-qrz-photo-target is-qrz-photo':'tx-qrz-photo-target';
 const state=hasPhoto?' data-qrz-state="photo"':'';
 const alt=hasPhoto?`Foto pública do QRZ de ${c}`:'Indicador de transmissão';
 return `<div class="${visualClass}"><img class="${imageClass}" data-qrz-call="${esc(c)}"${state} src="${esc(src)}" loading="eager" decoding="async" fetchpriority="high" alt="${esc(alt)}"><span class="signal-ring"></span></div>`
}
async function xlx026LoadQrzPhoto(img){
 if(!img||img.dataset.qrzState)return;
 const call=String(img.dataset.qrzCall||'').toUpperCase().replace(/[^A-Z0-9]/g,'');
 if(!call)return;
 img.dataset.qrzState='loading';
 try{
  let result=xlx026QrzPhotoCache.get(call);
  if(result===undefined){
   const controller=new AbortController();
   const timer=setTimeout(()=>controller.abort(),5000);
   try{
    const r=await fetch(`/api/qrz-photo.php?callsign=${encodeURIComponent(call)}`,{cache:'no-store',signal:controller.signal});
    result=r.ok?await r.json():null;
   }finally{clearTimeout(timer)}
   const url=result&&result.ok&&result.photo&&result.url?String(result.url):'';
   xlx026QrzPhotoCache.set(call,url);
   result=url;
  }
  const url=typeof result==='string'?result:'';
  if(!url){img.dataset.qrzState='fallback';return}
  const fallback='assets/talking-radio.gif';
  img.onerror=()=>{
   img.onerror=null;
   img.src=fallback;
   img.classList.remove('is-qrz-photo');
   {const v=img.closest('.operator-visual');v?.classList.remove('qrz-photo-active','qrz-size-1','qrz-size-2','qrz-size-3');} xlx026SyncQrzPhotoSizes();
   img.alt='Indicador de transmissão';
   img.dataset.qrzState='fallback';
   xlx026QrzPhotoCache.set(call,'');
  };
  img.onload=()=>{
   img.classList.add('is-qrz-photo');
   img.closest('.operator-visual')?.classList.add('qrz-photo-active'); xlx026SyncQrzPhotoSizes();
   img.alt=`Foto pública do QRZ de ${call}`;
   img.dataset.qrzState='photo';
  };
  img.src=url;
 }catch(_e){img.dataset.qrzState='fallback'}
}
function xlx026HydrateQrzPhotos(root=document){
 root.querySelectorAll?.('img.tx-qrz-photo-target[data-qrz-call]').forEach(xlx026LoadQrzPhoto);
}
function xlx026InitQrzPhotoObserver(){
 if(page!=='ao-vivo')return;
 const grid=document.getElementById('moduleGrid');
 if(!grid||grid.dataset.qrzPhotoObserver==='1')return;
 grid.dataset.qrzPhotoObserver='1';
 new MutationObserver(()=>{xlx026HydrateQrzPhotos(grid);xlx026SyncQrzPhotoSizes(grid)}).observe(grid,{childList:true,subtree:false});
 xlx026HydrateQrzPhotos(grid);
 xlx026SyncQrzPhotoSizes(grid);
}
setTimeout(xlx026InitQrzPhotoObserver,0);
window.addEventListener('resize',()=>xlx026SyncQrzPhotoSizes(),{passive:true});
function txCard(m){
/* XLX026_TXCARD_CALLSIGN_SEM_SUFFIX_V13 */

 const tx=m.transmission;
 const countryName=tx.country?.name||'País não informado';
 const gatewayHtml=hotspotRepeaterMarkup(tx);
 const callsign=esc(tx.callsign);

 return `<article class="tx-card live compact-tx tx-v30" data-turn-module="${esc(m.module)}">
  <div class="tx-top">
   <div class="tx-top-main">
    <span class="module-badge">MÓDULO ${esc(m.module)} • ${esc(tx.protocol)}</span>
    <h3>Transmitindo agora</h3>
   </div>
   <div class="tx-ai-monitor-wrap">
    <span class="tx-ai-monitor is-ready" data-ai-module="${esc(m.module)}" role="status" aria-live="polite" title="Monitoramento local ativo; verificando estado da IA.">
     <i aria-hidden="true"></i><b>IA</b><span>carregando</span><em class="tx-ai-scan" aria-hidden="true"></em>
    </span>
   </div>
   <div class="tx-top-actions">
    <span class="on-air"><i></i> NO AR</span>
   </div>
  </div>

  <div class="tx-v30-content">
   <div class="tx-v30-person">
    ${operatorVisual(tx.callsign)}
    <div class="tx-v30-person-data">
     <span class="connected-call-wrap"><a class="tx-v30-callsign" target="_blank" rel="noopener" href="${esc(tx.qrz)}">${callsign}</a>${xlx026AprsSatelliteMarkup(tx.callsign)}</span>
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

  <div class="spectrum tx-vu" data-vu-module="${esc(m.module)}" aria-label="Nível de áudio recebido pelo servidor">${'<i></i>'.repeat(18)}<span class="tx-vu-readout" aria-hidden="true">NÍVEL —</span></div>
 </article>`
}


/* XLX026_AI_MONITOR_UI_V1 */
function xlx026AiPublicState(){
 const ai=lastData&&lastData.ai_monitor&&typeof lastData.ai_monitor==='object'
  ?lastData.ai_monitor
  :{};
 return ai;
}
function xlx026UpdateTxAi(live){
 if(page!=='ao-vivo')return;
 const ai=xlx026AiPublicState();
 const active=live&&live.active?live.active:{};

 document.querySelectorAll('#moduleGrid .tx-ai-monitor[data-ai-module]').forEach(pill=>{
  const module=String(pill.dataset.aiModule||'').trim().toUpperCase();
  const tx=active[module]||lastData?.modules?.[module]?.transmission||null;
  const audio=tx&&tx.audio_vu?tx.audio_vu:null;
  const audioMode=String(audio?.mode||'').toLowerCase();
  const configured=Boolean(ai.configured);
  const connected=Boolean(ai.api_connected);
  const state=String(ai.state||'ready').toLowerCase();
  const action=ai.last_action&&typeof ai.last_action==='object'?ai.last_action:null;
  const actionAt=Number(action?.at||0);
  const actionFresh=actionAt>0&&Math.abs(Date.now()/1000-actionAt)<=900;

  let css='is-ready',primary='OPENAI',text='não configurada';
  let title='Monitor local ativo; API OpenAI ainda não configurada.';

  if(audioMode==='adaptive-gain'){
   css='is-dsp';primary='DSP';text='ajustando';
   title='O normalizador local está aplicando uma microcorreção de áudio. Não é uma alteração feita pela IA.';
  }else if(configured&&connected&&state==='analyzing'){
   css='is-analyzing';primary='IA CONECTADA';text='analisando';
   title='A IA está analisando telemetria resumida do servidor.';
  }else if(configured&&connected&&actionFresh&&state==='ai_applied'){
   css='is-applied';primary='IA CONECTADA';text='ajuste orientado';
   title=String(action?.message||'Ajuste dentro dos limites de segurança orientado pela IA.');
  }else if(configured&&connected&&actionFresh&&state==='recommendation'){
   css='is-recommendation';primary='IA CONECTADA';text='recomendação';
   title=String(action?.message||'A IA gerou uma recomendação; nenhuma alteração automática é presumida.');
  }else if(configured&&connected){
   css='is-monitoring';primary='OPENAI';text='conectada';
   title=String(ai.message||'API OpenAI disponível. Este indicador confirma conectividade; não significa que uma análise técnica esteja em execução.');
  }else if(configured){
   css='is-error';primary='OPENAI';text='reconectando';
   title=String(ai.message||'Chave configurada, mas a API ainda não foi validada.');
  }

  pill.className='tx-ai-monitor '+css;
  const primaryLabel=pill.querySelector('b');
  const label=pill.querySelector('span');
  if(primaryLabel&&primaryLabel.textContent!==primary)primaryLabel.textContent=primary;
  if(label&&label.textContent!==text)label.textContent=text;
  if(pill.title!==title)pill.title=title;
 });
}
/* /XLX026_AI_MONITOR_UI_V1 */

const xlx026VuPeakHold=new Map();
function xlx026VuSegment(value,min=-45,max=-10){
 const v=Math.max(min,Math.min(max,Number(value)));
 return Math.max(0,Math.min(18,Math.round(((v-min)/(max-min))*18)));
}
function xlx026UpdateTxVu(live){
 if(page!=='ao-vivo')return;
 const active=live&&live.active?live.active:{};
 const now=Date.now();

 document.querySelectorAll('#moduleGrid .tx-vu[data-vu-module]').forEach(vu=>{
  const module=String(vu.dataset.vuModule||'').toUpperCase();
  const tx=active[module]||lastData?.modules?.[module]?.transmission||null;
  const audio=tx&&tx.audio_vu?tx.audio_vu:null;
  const bars=[...vu.querySelectorAll('i')];
  const readout=vu.querySelector('.tx-vu-readout');
  const ts=Number(audio?.ts_ms||0);
  const fresh=audio&&Number.isFinite(ts)&&Math.abs(now-ts)<=1800;

  if(!fresh){
   if(vu.dataset.vuFresh!=='0'){
    vu.classList.remove('is-live','vu-low','vu-ideal','vu-high');
    bars.forEach(bar=>bar.classList.remove('vu-lit','vu-peak'));
    if(readout)readout.textContent='NÍVEL —';
    vu.dataset.vuFresh='0';
    vu.dataset.vuLit='';
    vu.dataset.vuPeak='';
    vu.dataset.vuState='';
    vu.dataset.vuText='NÍVEL —';
   }
   return;
  }

  const rms=Number(audio.rms_dbfs);
  const peak=Number(audio.peak_dbfs);
  if(!Number.isFinite(rms)||!Number.isFinite(peak))return;

  const backendState=String(audio.level||'').toLowerCase();
  const state=['low','ideal','high'].includes(backendState)?backendState:(rms<-33?'low':(rms>-20?'high':'ideal'));
  const label=state==='low'?'BAIXO':(state==='high'?'ALTO':'IDEAL');
  const lit=xlx026VuSegment(rms);
  const peakSeg=Math.max(1,xlx026VuSegment(peak));
  const holdKey=module||'_';
  const prev=xlx026VuPeakHold.get(holdKey);
  let hold=prev;

  if(!hold||peakSeg>=hold.segment||now-hold.at>1200){
   hold={segment:peakSeg,at:now};
   xlx026VuPeakHold.set(holdKey,hold);
  }

  if(vu.dataset.vuFresh!=='1'){
   vu.classList.add('is-live');
   vu.dataset.vuFresh='1';
  }

  if(vu.dataset.vuState!==state){
   vu.classList.remove('vu-low','vu-ideal','vu-high');
   vu.classList.add(`vu-${state}`);
   vu.dataset.vuState=state;
  }

  const litKey=String(lit);
  const peakKey=String(hold.segment);
  if(vu.dataset.vuLit!==litKey||vu.dataset.vuPeak!==peakKey){
   bars.forEach((bar,index)=>{
    const n=index+1;
    bar.classList.toggle('vu-lit',n<=lit);
    bar.classList.toggle('vu-peak',n===hold.segment);
   });
   vu.dataset.vuLit=litKey;
   vu.dataset.vuPeak=peakKey;
  }

  const roundedRms=Math.round(rms);
  const text=`${label} ${roundedRms} dB`;
  if(vu.dataset.vuText!==text){
   vu.title=`Nível recebido pelo servidor: ${rms.toFixed(1)} dBFS · pico ${peak.toFixed(1)} dBFS · ${label}`;
   if(readout){
    readout.textContent=text;
    readout.setAttribute('aria-hidden','false');
   }
   vu.dataset.vuText=text;
  }
 });
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
    <span class="module-badge">XLX026 AO VIVO</span>
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
let xlx026LastDocumentTitle='';
function updateTitle(d){const active=Object.values(d.modules).filter(m=>m.transmission).map(m=>m.transmission.callsign);const title=active.length?`(${d.connected_count}) ${active.join(' + ')} TX — XLX026`:`(${d.connected_count}) XLX026 Brasil`;if(title!==xlx026LastDocumentTitle){document.title=title;xlx026LastDocumentTitle=title;}}
function historyCallKey(x){return String(x?.callsign||'').trim().toUpperCase()}
function historyRowId(callKey,index){const safe=Array.from(callKey).map(ch=>/[A-Z0-9_-]/.test(ch)?ch:'x'+ch.charCodeAt(0).toString(16)+'x').join('');return `history-${safe}-${index}`}
function ensureHistoryDropdownStyles(){
 if(document.getElementById('xlx026HistoryDropdownStyles'))return;
 const style=document.createElement('style');
 style.id='xlx026HistoryDropdownStyles';
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
/* XLX026 APRS/DPRS PRESENCE V1 */
const xlx026AprsPresence=new Map();
const xlx026DmrTalkerAlias=new Map();
let xlx026AprsPresenceAt=0;
let xlx026AprsPresenceLoading=false;
const xlx026AprsActiveMs=30*60*1000;
function xlx026AprsBaseCall(v){return String(v||'').toUpperCase().trim().split(/[\s/]/)[0].replace(/[^A-Z0-9-]/g,'').replace(/-[0-9]{1,2}$/,'')}
function xlx026PositionSourceLabel(st){
 const source=String(st&&st.source||'');
 if(source.startsWith('DPRS_MODULE_'))return `D-PRS • módulo ${st&&st.module||'?'}`;
 if(source==='APRS_IS')return 'APRS-IS';
 if(source==='YSF_GPS')return 'YSF GPS';
 if(source==='DMR_GPS')return 'DMR GPS';
 return String(st&&st.protocol||'Posição digital');
}
function xlx026AprsDevice(st){
 const source=String(st&&st.source||'');
 if(source==='DMR_GPS')return ['🛰️','Posição GPS DMR'];
 if(source==='YSF_GPS')return ['🛰️','Posição GPS YSF'];
 if(source.startsWith('DPRS_MODULE_'))return ['🛰️','Posição D-PRS'];
 if(source==='APRS_IS')return ['🛰️','Posição APRS'];
 return ['🛰️','Posição digital'];
}
function xlx026AprsSatelliteMarkup(call){
 const key=xlx026AprsBaseCall(call),st=xlx026AprsPresence.get(key);
 if(!st)return '';
 const dev=xlx026AprsDevice(st),source=xlx026PositionSourceLabel(st);
 const target=String(st.callsign||key);
 return `<a class="aprs-activity-satellite aprs-device-icon" href="/aprs-dprs?station=${encodeURIComponent(target)}" title="${esc(dev[1])} • ${source} — ver localização" aria-label="${esc(dev[1])} — ver localização de ${esc(target)}">${dev[0]}</a>`;
}
function xlx026DmrTalkerAliasMarkup(call){
 const key=xlx026AprsBaseCall(call),row=xlx026DmrTalkerAlias.get(key);
 if(!row)return '';
 const alias=String(row.alias||'').trim();
 if(!alias)return '';
 return `<span class="dmr-talker-alias-badge" title="Talker Alias DMR reportado pelo rádio: ${esc(alias)}" aria-label="Talker Alias DMR reportado pelo rádio: ${esc(alias)}">T</span>`;
}
async function xlx026LoadAprsPresence(force=false){
 if(xlx026AprsPresenceLoading)return;
 if(!force && Date.now()-xlx026AprsPresenceAt<60000)return;
 xlx026AprsPresenceLoading=true;
 try{
  const r=await fetch('/api/digital-lab.php?presence=1&ts='+Date.now(),{cache:'no-store',headers:{Accept:'application/json'}});
  const d=await r.json();
  if(r.ok&&d&&d.ok&&Array.isArray(d.stations)){
   xlx026AprsPresence.clear();
   xlx026DmrTalkerAlias.clear();
   const now=Date.now();
   d.stations.forEach(st=>{
    const key=xlx026AprsBaseCall(st.callsign),t=Date.parse(st.last_seen||'');
    if(!key||!Number.isFinite(t)||now-t>xlx026AprsActiveMs)return;
    const prev=xlx026AprsPresence.get(key),pt=prev?Date.parse(prev.last_seen||''):0;
    if(!prev||t>pt)xlx026AprsPresence.set(key,st);
   });
   (Array.isArray(d.dmr_talker_alias)?d.dmr_talker_alias:[]).forEach(row=>{
    const key=xlx026AprsBaseCall(row&&row.callsign),t=Date.parse(row&&row.last_seen||'');
    if(!key||!Number.isFinite(t)||now-t>xlx026AprsActiveMs)return;
    const prev=xlx026DmrTalkerAlias.get(key),pt=prev?Date.parse(prev.last_seen||''):0;
    if(!prev||t>pt)xlx026DmrTalkerAlias.set(key,row);
   });
   xlx026AprsPresenceAt=Date.now();
   if(lastData){
    if(page==='conectados')renderConnectedTable(lastData);
    if(page==='ao-vivo'){
     xlx026RenderHistory(lastData);
    }
   }
  }
 }catch(_e){}finally{xlx026AprsPresenceLoading=false}
}

/* XLX026 REPEATER POPUP V2 */
const xlx026RepeaterCache=new Map();
const xlx026GatewayLocalMeta=new Map();
function xlx026IndexGatewayLocalMeta(d){
 xlx026GatewayLocalMeta.clear();
 const rows=[...(d&&d.connections||[]),...(d&&d.history||[])];
 rows.forEach(r=>{
  const call=xlx026BaseCall(r&&r.callsign);
  const name=String((r&&r.name)||'').trim();
  const location=String((r&&r.location)||'').trim();
  if(!call)return;
  const usefulName=name&&!/^N[aã]o informado$/i.test(name);
  const usefulLocation=location&&!/^N[aã]o informad[ao]$/i.test(location);
  if(usefulName||usefulLocation){
   const prev=xlx026GatewayLocalMeta.get(call)||{};
   xlx026GatewayLocalMeta.set(call,{name:usefulName?name:(prev.name||''),location:usefulLocation?location:(prev.location||'')});
  }
 });
}
function xlx026StationProvesGateway(x){const src=String((x&&x.identity_source)||'');const conf=String((x&&x.identity_confidence)||'');return src.indexOf('xlxd-station')===0&&(conf==='station'||conf==='station-strict')}
function xlx026RepeaterEligible(x,gatewayCall,callsign){const selfRepeater=gatewayCall&&callsign&&gatewayCall===callsign&&/^REPETIDORA\b/i.test(String((x&&x.name)||'').trim());const linkedRepeater=gatewayCall&&callsign&&gatewayCall!==callsign&&xlx026StationProvesGateway(x);return Boolean(selfRepeater||linkedRepeater)}
async function xlx026RepeaterInfo(call){
 const key=xlx026BaseCall(call); if(!key)return null;
 if(xlx026RepeaterCache.has(key))return xlx026RepeaterCache.get(key);
 const pending=fetch('/api/repeater.php?callsign='+encodeURIComponent(key),{cache:'no-store',headers:{Accept:'application/json'}})
  .then(async r=>{const d=await r.json();return (r.ok&&d&&d.ok&&d.repeater)?d.repeater:null})
  .catch(()=>null);
 xlx026RepeaterCache.set(key,pending);
 return pending;
}
function xlx026EnsureRepeaterDialog(){
 let d=document.getElementById('xlx026RepeaterDialog'); if(d)return d;
 d=document.createElement('dialog');d.id='xlx026RepeaterDialog';d.className='xlx026-repeater-dialog';
 d.innerHTML='<div class="repeater-dialog-head"><strong id="xlx026RepeaterTitle">Repetidora</strong><button type="button" data-repeater-close aria-label="Fechar">×</button></div><div id="xlx026RepeaterBody" class="repeater-dialog-body"></div>';
 document.body.appendChild(d);d.querySelector('[data-repeater-close]').addEventListener('click',()=>d.close());d.addEventListener('click',e=>{if(e.target===d)d.close()});return d;
}
function xlx026RepeaterField(label,value){return value?`<div><small>${esc(label)}</small><strong>${esc(String(value))}</strong></div>`:''}
async function xlx026OpenRepeater(call){
 const d=xlx026EnsureRepeaterDialog(),body=d.querySelector('#xlx026RepeaterBody'),title=d.querySelector('#xlx026RepeaterTitle');
 title.textContent=xlx026BaseCall(call)||'Repetidora';body.innerHTML='<p class="repeater-loading">Consultando RadioID.net…</p>';d.showModal();
 const r=await xlx026RepeaterInfo(call);
 if(!r){body.innerHTML='<p>Não há cadastro de repetidora disponível no RadioID.net para este indicativo.</p>';return}
 const place=[r.city,r.state].filter(Boolean).join(' / '), updated=r.fetched_at?new Date(Number(r.fetched_at)*1000).toLocaleString('pt-BR'):'—';
 body.innerHTML=`<div class="repeater-detail-grid">${xlx026RepeaterField('Frequência',r.frequency?`${r.frequency} MHz`:'')}${xlx026RepeaterField('Offset',r.offset?`${r.offset} MHz`:'')}${xlx026RepeaterField('Localização',place)}${xlx026RepeaterField('Color Code',r.color_code)}${xlx026RepeaterField('Status',r.status)}${xlx026RepeaterField('Cobertura',r.coverage)}${xlx026RepeaterField('Rede / modos',r.network)}${xlx026RepeaterField('Responsável',Array.isArray(r.trustee)?r.trustee.join(', '):'')}</div><div class="repeater-source"><b>Fonte:</b> RadioID.net<br><b>Última consulta:</b> ${esc(updated)}${r.cache==='stale'?'<br><span>Exibindo último cache disponível.</span>':''}</div>`;
}
async function xlx026EnableRepeaterButtons(root=document){
 const nodes=[...root.querySelectorAll('[data-repeater-call]')];
 const eagerLookup=Boolean(root&&root.id==='moduleGrid');
 for(const n of nodes){
  if(n.dataset.repeaterBound==='1')continue;
  n.dataset.repeaterBound='1';
  const call=xlx026BaseCall(n.dataset.repeaterCall||'');
  if(!call)continue;
  const inHistory=Boolean(n.closest('#historyRows'));
  if(inHistory&&!n.classList.contains('gateway-different'))continue;
  const info=await xlx026RepeaterInfo(call);
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
  b.addEventListener('click',e=>{e.preventDefault();e.stopPropagation();xlx026OpenRepeater(call)});
  n.appendChild(b);
 }
}

function hotspotRepeaterMarkup(x){
 const callsign=
  xlx026BaseCall(
   (x&&x.callsign)||''
  );

 const raw=
  String(
   (x&&x.gateway)||''
  ).trim();

 const normalized=
  raw.toUpperCase();

 const gatewayCall=
  xlx026BaseCall(raw);

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
  * PU2PNY B = PU2PNY
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
 /* XLX026_HISTORY_LINK_STATUS_V15B */

 /*
  * Online continua tendo prioridade.
  */
 if(Boolean(x&&x.online)){
  return onlineBadge(true);
 }

 const call=
  xlx026BaseCall(
   (x&&x.callsign)||''
  );

 const gatewayRaw=
  String(
   (x&&x.gateway)||''
  ).trim();

 const gateway=
  xlx026BaseCall(
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

 return `<button type="button" class="history-toggle" data-history-toggle="${esc(callKey)}" aria-expanded="${expanded?'true':'false'}" ${expanded?`aria-controls="${esc(previousIds.join(' '))}"`:""} aria-label="${label} de ${esc(x.callsign)}" title="${label}"><span aria-hidden="true">▼</span></button>`;
}

/* XLX026_HORARIO_TX_24H_V1 */
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
   <a target="_blank" href="${esc(x.qrz)}">${esc(x.callsign)}</a>${xlx026AprsSatelliteMarkup(x.callsign)}${xlx026DmrTalkerAliasMarkup(x.callsign)}
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

   const older=expanded?previous.map((x,index)=>{
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
   }).join(''):'';

   return main+older;
  }).join('');
}

let xlx026HistoryPeriodDays=1;
let xlx026HistoryLongRequest=0;
function xlx026HistoryPeriodText(days){return days===7?'Atividade dos últimos 7 dias':days===30?'Atividade dos últimos 30 dias':'Atividade das últimas 24 horas'}
function xlx026HistoryCoverageText(data){
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
 const days=Number(data&&data.days||xlx026HistoryPeriodDays||7),rows=Array.isArray(data&&data.groups)?data.groups:[];
 if(!rows.length)return `<tr><td colspan="11">Nenhuma transmissão registrada na base dos últimos ${days} dias.</td></tr>`;
 return rows.map((x,i)=>{
  const y={...x,duration:Number(x.total_duration||x.duration||0)};
  const attrs=`class="history-primary-row history-long-primary" data-history-long-call="${esc(historyCallKey(x))}"`;
  return historyRowMarkup(y,historyStatusMarkup(y),historyLongToggleMarkup(x,days),attrs,i+1,true);
 }).join('');
}
async function xlx026LoadLongHistory(days){
 const seq=++xlx026HistoryLongRequest,rows=$('#historyRows'),title=$('#historyPeriodTitle'),note=$('#historyCoverageNote');
 if(title)title.textContent=xlx026HistoryPeriodText(days);
 if(note)note.textContent='Carregando histórico…';
 if(rows)rows.innerHTML='<tr class="history-long-loading"><td colspan="11">Carregando histórico…</td></tr>';
 try{
  const r=await fetch(`/api/history-long.php?days=${days}&ts=${Date.now()}`,{cache:'no-store'}),d=await r.json();
  if(seq!==xlx026HistoryLongRequest)return;
  if(!r.ok||!d.ok)throw Error('history');
  if(rows)rows.innerHTML=historyLongMarkup(d);
  if(note)note.textContent=xlx026HistoryCoverageText(d);
  setTimeout(()=>xlx026EnableRepeaterButtons(document),0);
 }catch(_e){
  if(rows)rows.innerHTML='<tr><td colspan="11">Não foi possível carregar o histórico longo.</td></tr>';
  if(note)note.textContent='Histórico indisponível';
 }
}
async function toggleLongHistory(button){
 const call=String(button.dataset.historyLongToggle||''),days=Number(button.dataset.historyDays||xlx026HistoryPeriodDays||7),main=button.closest('tr');
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
   setTimeout(()=>xlx026EnableRepeaterButtons(document),0);
  }
  button.setAttribute('aria-expanded','true'); main.classList.add('is-expanded');
 }catch(_e){button.title='Falha ao carregar transmissões anteriores';}
 finally{button.disabled=false;}
}
function toggleHistoryGroup(callKey,button){
 if(!lastData||xlx026HistoryPeriodDays!==1)return;
 if(historyExpandedCalls.has(callKey))historyExpandedCalls.delete(callKey);
 else historyExpandedCalls.add(callKey);
 xlx026RenderHistory(lastData);
}
function moduleInfo(m){const defs={A:['Envio de imagens D-STAR','Módulo A • imagens digitais','XLX026-A'],B:['APRS / D-PRS','Dados digitais','XLX026-B'],C:['C4FM/YSF e DMR','YSF 72426 • DMR TG 4003','XLX026-C'],D:['D-STAR','XLX026-D / XRF026-D','XLX026-D'],E:['D-STAR Echo','Teste de áudio','XLX026-E']};return defs[m.module]||[m.configured_protocol,m.access,'XLX026-'+m.module]}
function renderModules(d){
 const modules=(d&&d.modules)||{};
 Object.values(modules).forEach(m=>{
  const letter=String(m&&m.module||'').trim().toUpperCase();
  if(!letter)return;
  const el=document.getElementById('moduleCount'+letter);
  if(el)el.textContent=Number(m.connected_count||0);
 });
}
/* XLX026_CONECTADOS_UNIFICADO_V1 */
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
  ?rows.map((c,i)=>`<tr><td>${i+1}</td><td>${flag(c)}</td><td><span class="connected-call-wrap"><a target="_blank" href="${esc(c.qrz)}">${esc(c.callsign)}${c.suffix?' '+esc(c.suffix):''}</a>${xlx026AprsSatelliteMarkup(c.callsign)}${xlx026DmrTalkerAliasMarkup(c.callsign)}</span></td><td>${esc(c.name)}</td><td>${esc(c.location)}</td><td><span class="protocol">${esc(c.protocol)}</span></td><td>${esc(c.module)}</td><td>${fmtTime(c.connected_at)}</td><td data-start="${c.connected_at}">${elapsed(c.connected_at)}</td><td>${fmtTime(c.last_activity)}</td></tr>`).join('')
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

let xlx026ConnectedRowsSignature='';
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

 const connectedRowsElement=$('#connectedRows');
 const connectedMarkup=connectedRows(d,query,moduleFilter,protocolFilter);
 if(connectedRowsElement&&connectedMarkup!==xlx026ConnectedRowsSignature){
  connectedRowsElement.innerHTML=connectedMarkup;
  xlx026ConnectedRowsSignature=connectedMarkup;
  xlx026EnableRepeaterButtons(connectedRowsElement);
 }
}

function renderConnected(d){
 syncConnectedProtocolFilter(d);
 renderConnectedTable(d);
}

function rankList(items,valueLabel){return items.length?items.map((x,i)=>`<div class="rank-item"><span class="rank-pos">${i+1}</span><div><b>${esc(x.label)}</b><small>${esc(x.sub||'')}</small></div><strong>${esc(valueLabel(x.value))}</strong></div>`).join(''):'<div class="rank-empty">Dados insuficientes no histórico disponível.</div>'}
function aggregate(arr,keyFn,valFn=()=>1){const m=new Map();arr.forEach(x=>{const k=keyFn(x);if(!k)return;const old=m.get(k)||{label:k,value:0,sub:''};old.value+=valFn(x);m.set(k,old)});return [...m.values()].sort((a,b)=>b.value-a.value)}
function renderRanking(d){const h=d.history||[],c=d.connections||[];const tx=aggregate(h,x=>x.callsign);tx.forEach(x=>{const y=h.find(z=>z.callsign===x.label);x.sub=y?.name||''});const air=aggregate(h,x=>x.callsign,x=>Number(x.duration||0));air.forEach(x=>{const y=h.find(z=>z.callsign===x.label);x.sub=y?.name||''});const con=[...c].sort((a,b)=>a.connected_at-b.connected_at).slice(0,10).map(x=>({label:x.callsign,sub:x.name,value:Math.max(0,Math.floor(Date.now()/1000-x.connected_at))}));const hrs=aggregate(h,x=>String(new Date(x.started_at*1000).getHours()).padStart(2,'0')+':00');const prot=aggregate(h,x=>x.protocol);const mods=aggregate(h,x=>'Módulo '+x.module);$('#rankTx').innerHTML=rankList(tx.slice(0,10),v=>v+' TX');$('#rankAirtime').innerHTML=rankList(air.slice(0,10),v=>duration(v));$('#rankConnected').innerHTML=rankList(con,v=>elapsed(Math.floor(Date.now()/1000-v)));$('#rankHours').innerHTML=rankList(hrs.slice(0,8),v=>v+' TX');$('#rankProtocols').innerHTML=rankList(prot.slice(0,8),v=>v+' TX');$('#rankModules').innerHTML=rankList(mods.slice(0,8),v=>v+' TX');const topTx=tx[0],topAir=air[0],topHour=hrs[0];$('#rankingHighlights').innerHTML=`<article><small>Mais transmissões</small><b>${esc(topTx?.label||'—')}</b><span>${topTx?topTx.value+' transmissões':'Sem dados'}</span></article><article><small>Maior tempo no ar</small><b>${esc(topAir?.label||'—')}</b><span>${topAir?duration(topAir.value):'Sem dados'}</span></article><article><small>Horário mais ativo</small><b>${esc(topHour?.label||'—')}</b><span>${topHour?topHour.value+' transmissões':'Sem dados'}</span></article><article><small>Conectados agora</small><b>${d.connected_count}</b><span>${d.active_count} transmissão${d.active_count===1?'':'ões'} ativa${d.active_count===1?'':'s'}</span></article>`}
/* XLX026_REFLETORES_COMPLETO_V2B */
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
    <label><span>Pesquisar</span><input id="reflectorSearch" type="search" placeholder="XLX026, país ou descrição" autocomplete="off"></label>
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
 tb.innerHTML=rows.length?rows.map((r,i)=>{const name=String(r?.name||'—'),self=name.trim().toUpperCase()==='XLX026',url=reflectorUrl(r?.dashboardurl),nameHtml=url?`<a target="_blank" rel="noopener noreferrer" href="${esc(url)}">${esc(name)}</a>`:esc(name);return `<tr class="${self?'reflector-self':''}"><td data-label="#">${i+1}</td><td data-label="Refletor"><span class="reflector-name">${nameHtml}${self?'<em>Este servidor</em>':''}</span></td><td data-label="País">${esc(r?.country||'—')}</td><td data-label="Status">${onlineBadge(reflectorState(r)==='online')}</td><td data-label="Descrição">${esc(r?.comment||'—')}</td></tr>`}).join(''):'<tr class="reflector-empty"><td colspan="5">Nenhum refletor corresponde aos filtros.</td></tr>';
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
/* /XLX026_REFLETORES_COMPLETO_V2B */

let xlx026HistorySignature='';
let xlx026HistoryQuickSignature='';
let xlx026HistoryRenderedAt=0;
function xlx026HistoryQuickKey(d){
 const recent=(Array.isArray(d&&d.history)?d.history:[]).slice(0,30)
  .map(x=>[
   xlx026HistoryItemKey(x),
   Number(x&&x.duration||0),
   x&&x.online?1:0,
   x&&x.gateway||'',
   x&&x.identity_source||''
  ].join('~')).join('|');
 const online=(Array.isArray(d&&d.connections)?d.connections:[])
  .map(c=>xlx026BaseCall(c&&c.callsign)).filter(Boolean).sort().join(',');
 const expanded=[...historyExpandedCalls].sort().join(',');
 return [recent,online,expanded,xlx026AprsPresenceAt].join('||');
}
/* XLX026_HISTORY_ON_DEMAND_RESEARCH_V1 */
function xlx026RenderHistory(d){
 const rows=$('#historyRows');
 if(!rows||!d||xlx026HistoryPeriodDays!==1)return false;
 const quickSignature=xlx026HistoryQuickKey(d);
 if(quickSignature===xlx026HistoryQuickSignature)return false;
 xlx026HistoryQuickSignature=quickSignature;
 // Compare every displayed field, including APRS, alias and online state.
 // Closed groups retain their data but do not create hidden DOM rows.
 const markup=historyMarkup(d);
 if(markup===xlx026HistorySignature)return false;
 const focused=document.activeElement;
 const focusCall=focused&&rows.contains(focused)&&focused.dataset
  ?focused.dataset.historyToggle:null;
 rows.innerHTML=markup;
 xlx026HistorySignature=markup;
 xlx026HistoryRenderedAt=Date.now();
 if(focusCall){
  const replacement=[...rows.querySelectorAll('[data-history-toggle]')]
   .find(button=>button.dataset.historyToggle===focusCall);
  if(replacement)replacement.focus({preventScroll:true});
 }
 setTimeout(()=>xlx026EnableRepeaterButtons(rows),0);
 return true;
}
function render(d){lastData=d;$('#syncState').textContent='Ao vivo';updateTitle(d);trackConnectedCountVoice(d);
 xlx026IndexGatewayLocalMeta(d);
 if(page==='ao-vivo'){ xlx026LoadAprsPresence(); $('#headerConnected').textContent=d.connected_count; $('#headerActive').textContent=d.active_count; $('#widgetCount').textContent=d.active_count?`${d.active_count} no ar`:'Standby'; const active=Object.values(d.modules).filter(m=>m.transmission); const newest=[...d.history].sort((a,b)=>b.started_at-a.started_at)[0]||null; const standModule=Object.values(d.modules)[0];

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
  setTimeout(()=>xlx026EnableRepeaterButtons($('#moduleGrid')),0);
 }

 ensureHistoryDropdownStyles();
 xlx026RenderHistory(d);
 }
 if(page==='modulos')renderModules(d);
 if(page==='conectados'){xlx026LoadAprsPresence();renderConnected(d);}
 if(page==='ranking')renderRanking(d);
 const nowSet=new Set(d.connections.map(c=>`${c.callsign}|${c.suffix}|${c.protocol}|${c.module}|${c.ip}`));if(previousConnections!==null)d.connections.forEach(c=>{const k=`${c.callsign}|${c.suffix}|${c.protocol}|${c.module}|${c.ip}`;if(!previousConnections.has(k))toast(c)});previousConnections=nowSet; }
let statusUpdateRunning=false;
let xlx026AoVivoHistoryReady=false;
function xlx026HistoryItemKey(x){
 if(!x)return '';
 return [
  x.module||'',
  x.stream_id||x.sid||'',
  x.callsign||'',
  x.started_at||''
 ].join('|');
}
function xlx026MergeRecentHistory(current,recent,generatedAt,connections){
 const cutoff=Number(generatedAt||Math.floor(Date.now()/1000))-86400;
 const onlineCalls=new Set(
  (Array.isArray(connections)?connections:[])
   .map(c=>xlx026BaseCall(c&&c.callsign))
   .filter(Boolean)
 );
 const merged=new Map();
 [...(Array.isArray(recent)?recent:[]),...(Array.isArray(current)?current:[])].forEach(x=>{
  const key=xlx026HistoryItemKey(x);
  if(key&&!merged.has(key))merged.set(key,x);
 });
 const rows=[...merged.values()]
  .filter(x=>Number(x&&x.started_at||0)>=cutoff);
 rows.forEach(x=>{
  x.online=onlineCalls.has(xlx026BaseCall(x&&x.callsign));
 });
 return rows.sort((a,b)=>Number(b.started_at||0)-Number(a.started_at||0));
}
async function update(){
 if(statusUpdateRunning||document.hidden)return;
 statusUpdateRunning=true;
 const controller=new AbortController();
 const timeoutId=setTimeout(()=>controller.abort(),4000);
 const needFullHistory=page==='ao-vivo'&&!xlx026AoVivoHistoryReady;
 try{
  const statusEndpoint=page==='ao-vivo'
   ?(needFullHistory?'api/status.php?history_hours=24&ts=':'api/status.php?history=30&ts=')
   :'api/status.php?ts=';
  const r=await fetch(statusEndpoint+Date.now(),{cache:'no-store',signal:controller.signal});
  const d=await r.json();
  if(!d.ok)throw Error();
  if(page==='ao-vivo'&&!needFullHistory&&lastData&&Array.isArray(lastData.history)){
   d.history=xlx026MergeRecentHistory(lastData.history,d.history,d.generated_at,d.connections);
  }
  render(d);
  if(page==='ao-vivo'&&needFullHistory){
   xlx026AoVivoHistoryReady=true;
  }
 }catch(e){
  $('#syncState').textContent='Reconectando';
 }finally{
  clearTimeout(timeoutId);
  statusUpdateRunning=false;
 }
}
async function loadReflectors(){ if(page!=='refletores') return; try{ const r=await fetch('api/reflectors.php?ts='+Date.now(), {cache:'no-store'}); const d=await r.json(); if(!d.ok) throw Error(); renderReflectors(d);} catch(e){ const tb=$('#reflectorRows'); if(tb) tb.innerHTML='<tr><td colspan="5">Não foi possível carregar a lista de refletores neste momento.</td></tr>'; }}
let xlx026ElapsedTimer=null;
function xlx026RefreshElapsed(){
 if(document.hidden)return;
 const nowSeconds=Date.now()/1000;
 document.querySelectorAll('[data-start]').forEach(e=>{
  const started=Number(e.dataset.start);
  e.textContent=elapsed(started);
  const card=e.closest('.tx-card.live');
  if(!card||!Number.isFinite(started)||started<=0)return;
  const seconds=Math.max(0,Math.floor(nowSeconds-started));
  const yellowWarning=seconds>=160&&seconds<170;
  const redWarning=seconds>=170&&seconds<180;
  const expired=seconds>=180;
  card.classList.remove('tx-tot-warning');
  card.classList.toggle('tx-tot-warning-yellow',yellowWarning);
  card.classList.toggle('tx-tot-warning-red',redWarning);
  card.classList.toggle('tx-tot-expired',expired);
  card.dataset.totRemaining=(yellowWarning||redWarning)
   ?String(Math.max(0,180-seconds))
   :'';
 });
}
function xlx026StartElapsedTimer(){
 if(xlx026ElapsedTimer!==null||document.hidden)return;
 xlx026RefreshElapsed();
 xlx026ElapsedTimer=setInterval(xlx026RefreshElapsed,1000);
}
function xlx026StopElapsedTimer(){
 if(xlx026ElapsedTimer===null)return;
 clearInterval(xlx026ElapsedTimer);
 xlx026ElapsedTimer=null;
}
xlx026StartElapsedTimer();

let liveUpdateRunning=false;
let liveUpdateTimer=null;
let previousLiveKeys=null;
let txRxAudioContext=null;
let txRxAudioUnlocked=false;
/*
 * Som habilitado por padrão.
 * Somente fica desligado quando o usuário escolhe explicitamente
 * a opção desativada.
 */
let txRxSoundEnabled=
 localStorage.getItem('xlx026TxRxSound')!=='disabled';

/* XLX026_AUDIO_CONTROL_V5E */

function xlx026AudioStored(key,fallback){
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

function xlx026PanelAudioEnabled(){
 return xlx026AudioStored(
  'xlx026PanelAudio',
  true
 );
}

function xlx026ConnectedVoiceEnabled(){
 return (
  xlx026PanelAudioEnabled() &&
  xlx026AudioStored(
   'xlx026ConnectedVoice',
   true
  )
 );
}

function xlx026TxBeepsEnabled(){
 return (
  xlx026PanelAudioEnabled() &&
  xlx026AudioStored(
   'xlx026TxBeeps',
   txRxSoundEnabled
  )
 );
}




/*
 * ==========================================================
 * XLX026_CONNECTED_COUNT_VOICE_V1
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
 * XLX026_CONNECTED_COUNT_VOICE_V103_NO_TX
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
  !xlx026ConnectedVoiceEnabled()||
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
  !xlx026ConnectedVoiceEnabled()||
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

 if(
  connectedVoicePendingEvent&&
  connectedVoiceCurrentTotal!==null&&
  xlx026ConnectedVoiceEnabled()&&
  connectedVoiceSupported()&&
  !connectedVoiceTxActive()
 ){
  clearConnectedVoiceEventTimer();
  if(
   speakConnectedCount(
    connectedVoiceCurrentTotal,
    'user-activate'
   )
  ){
   connectedVoicePendingEvent=false;
   return;
  }
 }

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
  {once:true}
 );

 document.addEventListener(
  'keydown',
  armConnectedVoice,
  {
   once:true
  }
 );
}


/* /XLX026_CONNECTED_COUNT_VOICE_V101 */


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
   'xlx026TxRxSound',
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
 if(!txRxSoundEnabled||!xlx026PanelAudioEnabled()||!xlx026TxBeepsEnabled())return false;

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
 * XLX026_TXRX_SOUND_STRONG_V1
 * Sinais TX/RX mais fortes e distintos.
 */
function playTxRxTone(frequency,duration,delay){
 if(!txRxSoundEnabled||!xlx026PanelAudioEnabled()||!xlx026TxBeepsEnabled())return;

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
 * XLX026_TXRX_END_DOUBLE_BEEP_V1
 * Fim de TX com dois bips mais separados e nítidos.
 */
function playTxEndedSound(){
 playTxRxTone(2350,95,0);
 playTxRxTone(2350,95,155);
}

function detectTxRxSound(active){
 const currentKeys=new Set(
  Object.values(active||{}).map(tx=>
   String(`${tx.module||''}:${tx.stream_id||''}:${tx.started_at||''}`)
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

 const previousCount=previousLiveKeys.size;
 const currentCount=currentKeys.size;

 const started=currentCount>previousCount;
 const ended=previousCount>0 && currentCount===0;

 /* Atualiza primeiro o estado lógico; áudio nunca pode impedir o próximo ciclo. */
 previousLiveKeys=currentKeys;

 if(started){
  try{ deferConnectedVoiceForTx(); }catch(_e){}
  try{ playTxStartedSound(); }catch(_e){}
 }

 /*
  * Som de fim somente quando TODO o monitor volta a standby.
  * Troca de chave/identidade e fim de apenas um TX simultâneo
  * não devem soar como desconexão geral.
  */
 if(ended){
  try{ playTxEndedSound(); }catch(_e){}
 }
}


let lastLiveVisualSignature=null;

function renderLiveTxRxOnly(live){
 if(page!=='ao-vivo')return;

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
      tx.stream_id||'',
      tx.started_at||'',
      tx.callsign||'',
      tx.suffix||'',
      tx.name||'',
      tx.location||'',
      tx.protocol||'',
      tx.qrz||'',
      tx.gateway||'',
      tx.gateway_suffix||'',
      tx.network_callsign||'',
      tx.identity_source||'',
      tx.identity_confidence||'',
      tx.country?.code||tx.country?.name||''
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

   window.XLX026MTR?.sync(
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

   window.XLX026MTR?.sync([]);
  }

  setTimeout(()=>xlx026EnableRepeaterButtons(moduleGrid),0);
  lastLiveVisualSignature=visualSignature;
 }

 updateTitle(lastData);
}


/* ==========================================================
   XLX026_LIVE_IDENTITY_MERGE_V10

   A API live.php continua responsável pela velocidade.

   A identidade do operador é preservada do status.php
   quando módulo/stream/horário comprovam que se trata
   da mesma transmissão.
   ========================================================== */

let xlx026LastIdentityRefreshKey='';

function xlx026BaseCall(value){
 return String(value||'')
  .replace(/\s+/g,' ')
  .trim()
  .toUpperCase()
  .split(' ')[0]||'';
}

function xlx026LiveIdentityKey(tx){
 if(!tx)return '';
 return [
  tx.module||'',
  tx.stream_id||'',
  tx.started_at||''
 ].join(':');
}

function xlx026SameTransmission(a,b){
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

function xlx026HasStationIdentity(tx){
 return Boolean(
  tx &&
  String(tx.identity_source||'')
   .indexOf('xlxd-station')===0
 );
}

function xlx026MergeLiveIdentity(
 liveTx,
 statusTx
){
 if(
  !xlx026SameTransmission(
   liveTx,
   statusTx
  ) ||
  !xlx026HasStationIdentity(statusTx)
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

function xlx026LiveIdentityLooksAmbiguous(tx){
 if(!tx)return false;

 const call=
  xlx026BaseCall(tx.callsign);

 const gateway=
  xlx026BaseCall(tx.gateway);

 return Boolean(
  call &&
  gateway &&
  call===gateway &&
  !xlx026HasStationIdentity(tx)
 );
}

/* /XLX026_LIVE_IDENTITY_MERGE_V10 */

/* XLX026_BROWSER_SCALE_V1
 * Abas do mesmo navegador compartilham o snapshot ao vivo.
 * Navegadores sem BroadcastChannel mantêm o polling tradicional.
 */
let xlx026LiveShared=null;
let xlx026LiveSharedAt=0;
let xlx026LiveChannel=null;

try{
 if(typeof BroadcastChannel==='function'){
  xlx026LiveChannel=new BroadcastChannel('xlx026-live-v1');
  xlx026LiveChannel.onmessage=event=>{
   const live=event&&event.data;
   if(!live||live.ok!==true)return;
   xlx026LiveShared=live;
   xlx026LiveSharedAt=Date.now();
   if(page==='ao-vivo'&&!document.hidden&&!liveUpdateRunning){
    updateLiveTxRx();
   }
  };
 }
}catch(_liveChannelError){}

/* XLX026_LIVE_SSE_CLIENT_V1
 * Transporte primário: SSE push.
 * Fallback: polling atual quando EventSource não existe ou a conexão cai.
 */
let xlx026LiveEventSource=null;
let xlx026LiveSseOpen=false;
let xlx026LiveSsePending=false;
let xlx026LiveCoreConnected=false;

function xlx026StartLiveSse(){
 if(
  page!=='ao-vivo'||
  document.hidden||
  xlx026LiveCoreConnected||
  typeof EventSource!=='function'||
  xlx026LiveEventSource
 )return;

 try{
  const source=new EventSource('/api/live-stream');
  xlx026LiveEventSource=source;

  source.onopen=()=>{
   xlx026LiveSseOpen=true;
  };

  source.addEventListener('live',event=>{
   try{
    const live=JSON.parse(event.data);
    if(!live||live.ok!==true)return;
    xlx026LiveSseOpen=true;
    xlx026LiveShared=live;
    xlx026LiveSharedAt=Date.now();
    /* SSE já é fan-out no servidor; não duplique o mesmo evento entre abas. */
    if(liveUpdateRunning){
     xlx026LiveSsePending=true;
    }else if(page==='ao-vivo'&&!document.hidden){
     updateLiveTxRx();
    }
   }catch(_liveSseParseError){}
  });

  source.onerror=()=>{
   xlx026LiveSseOpen=false;
   if(
    liveLoopEnabled&&
    !document.hidden&&
    page==='ao-vivo'
   ){
    if(liveUpdateTimer!==null){
     clearTimeout(liveUpdateTimer);
     liveUpdateTimer=null;
    }
    liveUpdateTimer=setTimeout(runLiveTxRxLoop,0);
   }
  };
 }catch(_liveSseError){
  xlx026LiveSseOpen=false;
  xlx026LiveEventSource=null;
 }
}

function xlx026StopLiveSse(){
 xlx026LiveSseOpen=false;
 xlx026LiveSsePending=false;
 if(!xlx026LiveEventSource)return;
 try{xlx026LiveEventSource.close()}catch(_liveSseCloseError){}
 xlx026LiveEventSource=null;
}

window.addEventListener('xlxmodern-live-core-state',event=>{
 const connected=Boolean(event?.detail?.connected);
 xlx026LiveCoreConnected=connected;
 if(connected){
  xlx026StopLiveSse();
  return;
 }
 if(liveLoopEnabled&&!document.hidden&&page==='ao-vivo'){
  xlx026StartLiveSse();
  if(liveUpdateTimer===null&&!liveUpdateRunning){
   liveUpdateTimer=setTimeout(runLiveTxRxLoop,0);
  }
 }
});

async function updateLiveTxRx(){
 if(
  liveUpdateRunning||
  document.hidden||
  page!=='ao-vivo'
 )return;

 liveUpdateRunning=true;

 let controller=null;
 let timeoutId=null;

 try{
  let live=null;
  const sharedAge=Date.now()-xlx026LiveSharedAt;

  if(
   xlx026LiveShared&&
   sharedAge>=0&&
   sharedAge<=450
  ){
   live=xlx026LiveShared;
  }else{
   controller=new AbortController();
   timeoutId=setTimeout(()=>controller.abort(),1200);
   const response=await fetch(
    'api/live.php?ts='+Date.now(),
    {
     cache:'no-store',
     signal:controller.signal
    }
   );

   live=await response.json();

   if(live&&live.ok===true){
    xlx026LiveShared=live;
    xlx026LiveSharedAt=Date.now();
    try{
     xlx026LiveChannel?.postMessage(live);
    }catch(_liveBroadcastError){}
   }
  }

  if(!live||!live.ok)throw Error();

  /*
   * live.php é a fonte primária do box TX.
   * Não espera status.php: cria somente o estado mínimo necessário
   * e deixa a API completa enriquecer nome/gateway depois.
   */
  if(!lastData){
   lastData={
    ok:true,
    modules:{},
    history:[],
    connections:[],
    connected_count:0,
    active_count:Number(live.active_count||0),
    generated_at:Number(live.generated_at||0)
   };
  }

  if(!lastData.modules||typeof lastData.modules!=='object'){
   lastData.modules={};
  }

  Object.entries(live.active||{}).forEach(([moduleName,tx])=>{
   const module=String(tx?.module||moduleName||'').trim().toUpperCase();
   if(module&&!lastData.modules[module]){
    lastData.modules[module]={
     module,
     transmission:null
    };
   }
  });

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
    xlx026MergeLiveIdentity(
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
    xlx026LiveIdentityLooksAmbiguous(
     liveTx
    )
   ){
    const refreshKey=
     xlx026LiveIdentityKey(liveTx);

    if(
     refreshKey &&
     refreshKey!==
      xlx026LastIdentityRefreshKey
    ){
     xlx026LastIdentityRefreshKey=
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
  window.XLX026TurnWait?.update(live);
  try{xlx026UpdateTxVu(live)}catch(_vuError){}
  try{xlx026UpdateTxAi(live)}catch(_aiUiError){}
  try{window.XLX026MTR?.push?.(live)}catch(_mtrPushError){}

  /* O áudio é efeito secundário: nunca pode bloquear o estado visual. */
  try{
   detectTxRxSound(live.active);
  }catch(_audioError){}
 }catch(error){
 }finally{
  if(timeoutId!==null)clearTimeout(timeoutId);
  liveUpdateRunning=false;
  if(
   xlx026LiveSsePending&&
   page==='ao-vivo'&&
   !document.hidden
  ){
   xlx026LiveSsePending=false;
   Promise.resolve().then(updateLiveTxRx);
  }
 }
}

const LIVE_POLL_ACTIVE_MS=500;
const LIVE_POLL_STANDBY_MS=750;
const LIVE_POLL_START_JITTER_MS=350;

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

 /* Com WebSocket ou SSE aberto, não consulta live.php por navegador. */
 if(xlx026LiveCoreConnected||xlx026LiveSseOpen){
  liveUpdateTimer=setTimeout(runLiveTxRxLoop,5000);
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
 if(!xlx026LiveCoreConnected){
  xlx026StartLiveSse();
 }

 liveUpdateTimer=setTimeout(
  runLiveTxRxLoop,
  Math.floor(Math.random()*LIVE_POLL_START_JITTER_MS)
 );
}

function stopLiveTxRx(){
 liveLoopEnabled=false;
 xlx026StopLiveSse();

 if(liveUpdateTimer===null)return;

 clearTimeout(liveUpdateTimer);
 liveUpdateTimer=null;
}

let statusUpdateTimer=null;
function xlx026StatusInterval(){
 if(page==='ao-vivo')return 15000;
 if(page==='conectados')return 30000;
 if(page==='modulos'||page==='ranking')return 60000;
 return 0;
}
function startStatusUpdates(){
 const interval=xlx026StatusInterval();
 if(interval<=0||statusUpdateTimer!==null)return;
 update();
 statusUpdateTimer=setInterval(update,interval);
}
function stopStatusUpdates(){
 if(statusUpdateTimer===null)return;
 clearInterval(statusUpdateTimer);
 statusUpdateTimer=null;
}
let xlx026PageHiddenAt=0;
document.addEventListener('visibilitychange',()=>{
 if(document.hidden){
  xlx026PageHiddenAt=Date.now();
  stopStatusUpdates();
  stopLiveTxRx();
  xlx026StopElapsedTimer();

 }else{
  if(
   page==='ao-vivo'&&
   xlx026PageHiddenAt>0&&
   Date.now()-xlx026PageHiddenAt>300000
  ){
   xlx026AoVivoHistoryReady=false;
  }
  xlx026PageHiddenAt=0;
  xlx026StartElapsedTimer();
  startStatusUpdates();
  startLiveTxRx();
 }
});

if(!document.hidden){
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
 xlx026HistoryPeriodDays=[1,7,30].includes(days)?days:1;
 historyExpandedCalls.clear();
 if(xlx026HistoryPeriodDays===1){
  const title=$('#historyPeriodTitle'),note=$('#historyCoverageNote');
  if(title)title.textContent=xlx026HistoryPeriodText(1);
  if(note)note.textContent='Todos os indicativos';
  if(lastData){xlx026HistorySignature='';xlx026RenderHistory(lastData);}
 }else xlx026LoadLongHistory(xlx026HistoryPeriodDays);
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
   XLX026 V39 — tabelas móveis estáveis, sem piscar
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

        document.querySelectorAll('table').forEach(table => {
            if (!isTargetTable(table)) return;
            observer.observe(table, {
                childList: true,
                subtree: true,
                attributes: false,
                characterData: false
            });
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
   XLX026_TX_CALLSIGN_FIX_V2
   OTIMIZADO
   ========================================================== */
(function () {
  'use strict';

  if (window.__XLX026_TX_CALLSIGN_FIX_V2__) return;
  window.__XLX026_TX_CALLSIGN_FIX_V2__ = true;

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
        subtree: false,
        characterData: false
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

/* FIM XLX026_TX_CALLSIGN_FIX_V2 */







/* ==========================================================
   XLX026_MENU_MOBILE_FECHADO_V3
   Controle do menu mobile
   ========================================================== */

(() => {
    'use strict';

    const MOBILE_QUERY = '(max-width: 820px)';

    function initXLX026MobileMenuV3(){

        const header = document.querySelector('.universal-header');
        if (!header) return;

        const row = header.querySelector('.universal-header-row');
        const nav = header.querySelector('.universal-nav');

        if (!row || !nav) return;

        let wrap = header.querySelector('.xlx026-mobile-togglebar');
        let button = wrap ? wrap.querySelector('button') : null;

        if (!wrap){
            wrap = document.createElement('div');
            wrap.className = 'xlx026-mobile-togglebar';
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
            if (nav.parentNode === row){
                row.insertBefore(wrap, nav);
            }else{
                row.appendChild(wrap);
            }
        }

        const isMobile = () => window.matchMedia(MOBILE_QUERY).matches;

        function fecharMenu(){
            nav.classList.remove('open');
            nav.classList.remove('xlx026-mobile-open-v3');

            button.textContent = 'MENU';
            button.setAttribute('aria-expanded', 'false');
            button.setAttribute('aria-label', 'Abrir menu');
        }

        function abrirMenu(){
            nav.classList.remove('open');
            nav.classList.add('xlx026-mobile-open-v3');

            button.textContent = 'FECHAR';
            button.setAttribute('aria-expanded', 'true');
            button.setAttribute('aria-label', 'Fechar menu');
        }

        function ajustarEstadoInicial(){
            if (isMobile()){
                fecharMenu();
            } else {
                nav.classList.remove('xlx026-mobile-open-v3');
                nav.classList.remove('open');
                button.textContent = 'MENU';
                button.setAttribute('aria-expanded', 'false');
            }
        }

        ajustarEstadoInicial();

        if (!button.dataset.xlx026Bound){
            button.addEventListener('click', function(ev){
                ev.preventDefault();
                ev.stopPropagation();

                if (!isMobile()) return;

                if (nav.classList.contains('xlx026-mobile-open-v3')){
                    fecharMenu();
                } else {
                    abrirMenu();
                }
            });

            button.dataset.xlx026Bound = '1';
        }

        if (!nav.dataset.xlx026Bound){
            nav.addEventListener('click', function(ev){
                const link = ev.target.closest('a');
                if (!link) return;

                if (isMobile()){
                    fecharMenu();
                }
            });

            nav.dataset.xlx026Bound = '1';
        }

        window.addEventListener('resize', ajustarEstadoInicial, { passive:true });

        document.addEventListener('keydown', function(ev){
            if (ev.key === 'Escape' && isMobile()){
                fecharMenu();
            }
        });
    }

    if (document.readyState === 'loading'){
        document.addEventListener('DOMContentLoaded', initXLX026MobileMenuV3, { once:true });
    } else {
        initXLX026MobileMenuV3();
    }

})();

/* FIM XLX026_MENU_MOBILE_FECHADO_V3 */


/* XLX026_AUDIO_API_V5E */

function xlx026StopWebAudio(){

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


window.XLX026AudioControl={

 state:function(){

  return {

   master:
    xlx026AudioStored(
     'xlx026PanelAudio',
     true
    ),

   voice:
    xlx026AudioStored(
     'xlx026ConnectedVoice',
     true
    ),

   beeps:
    xlx026AudioStored(
     'xlx026TxBeeps',
     txRxSoundEnabled
    )

  };
 },


 setMaster:function(enabled){

  enabled=!!enabled;

  try{
   localStorage.setItem(
    'xlx026PanelAudio',
    enabled?'enabled':'disabled'
   );
  }catch(error){}

  if(!enabled){

   try{
    clearConnectedVoiceEventTimer();
   }catch(error){}

   try{
    if('speechSynthesis' in window){
     window.speechSynthesis.cancel();
    }
   }catch(error){}

   xlx026StopWebAudio();

   return true;
  }

  if(
   txRxSoundEnabled &&
   xlx026TxBeepsEnabled()
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
    'xlx026ConnectedVoice',
    enabled?'enabled':'disabled'
   );
  }catch(error){}

  if(!enabled){

   try{
    clearConnectedVoiceEventTimer();
   }catch(error){}

   try{
    if('speechSynthesis' in window){
     window.speechSynthesis.cancel();
    }
   }catch(error){}
  }else if(page==='ao-vivo'){
   connectedVoiceUserActivated=true;
   if(lastData){
    connectedVoiceCurrentTotal=connectedVoiceValue(lastData.connected_count);
    connectedVoicePendingEvent=true;
    clearConnectedVoiceEventTimer();
    if(
     !connectedVoiceTxActive()&&
     speakConnectedCount(
      connectedVoiceCurrentTotal,
      'manual-enable'
     )
    ){
     connectedVoicePendingEvent=false;
    }else{
     scheduleConnectedVoiceEvent();
    }
   }
  }

  return true;
 },


 setBeeps:function(enabled){

  enabled=!!enabled;

  txRxSoundEnabled=enabled;

  try{

   localStorage.setItem(
    'xlx026TxBeeps',
    enabled?'enabled':'disabled'
   );

   localStorage.setItem(
    'xlx026TxRxSound',
    enabled?'enabled':'disabled'
   );

  }catch(error){}

  try{
   updateTxRxSoundButton();
  }catch(error){}

  if(!enabled){

   xlx026StopWebAudio();

   return true;
  }

  if(xlx026PanelAudioEnabled()){

   try{
    unlockTxRxAudio(false);
   }catch(error){}
  }

  return true;
 },


 testBeep:function(){

  if(
   !xlx026PanelAudioEnabled() ||
   !xlx026TxBeepsEnabled()
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
   clearConnectedVoiceEventTimer();
  }catch(error){}

  try{
   if('speechSynthesis' in window){
    window.speechSynthesis.cancel();
   }
  }catch(error){}

  xlx026StopWebAudio();

  return true;
 }

};



/* XLX_TX_TURN_WAIT_UI_V1 */
(()=> {
 if(page!=='ao-vivo')return;
 const waits=new Map();
 let ticker=null, observer=null, root=null;
 function draw(){
  root=document.getElementById('moduleGrid');
  if(!root)return;
  if(!observer){
   observer=new MutationObserver(()=>{if(ticker)draw();});
   observer.observe(root,{childList:true,subtree:true});
  }
  const now=performance.now();
  const live=[...waits.values()].filter(x=>x.deadline>now);
  if(live.length){
   root.querySelectorAll('.tx-card.standby:not(.tx-turn-wait-card)').forEach(x=>x.remove());
  }
  root.querySelectorAll('[data-turn-wait-module]').forEach(el=>{
   if(!live.some(x=>x.module===el.dataset.turnWaitModule))el.remove();
  });
  root.querySelectorAll('.tx-turn-notice').forEach(el=>{
   if(!live.some(x=>x.module===el.dataset.turnNoticeModule))el.remove();
  });
  for(const x of live){
   const seconds=Math.max(1,Math.ceil((x.deadline-now)/1000));
   let el=root.querySelector('[data-turn-wait-module="'+x.module+'"]');
   const active=root.querySelector('.tx-card.live[data-turn-module="'+x.module+'"]');
   if(active){
    if(el)el.remove();
    el=active.querySelector('.tx-turn-notice');
    if(!el){
     el=document.createElement('div');
     el.className='tx-turn-notice';
     el.dataset.turnNoticeModule=x.module;
     active.appendChild(el);
    }
   }else if(!el){
    el=document.createElement('article');
    el.className='tx-card standby compact-tx tx-turn-wait-card';
    el.dataset.turnWaitModule=x.module;
    root.appendChild(el);
   }
   const label=x.callsigns.join(' • ');
   const signature=label+':'+seconds;
   if(el.dataset.turnSignature!==signature){
    el.dataset.turnSignature=signature;
    el.innerHTML='<div class="tx-turn-label">MÓDULO '+esc(x.module)+
     ' • ESPAÇO DE CÂMBIO</div><h3>'+esc(label)+
     '</h3><div class="tx-turn-count">AGUARDE <b>'+seconds+
     ' s</b></div><p>Esses indicativos estão em espera. Outras estações podem entrar.</p>';
    el.setAttribute('aria-label',label+' em espera no módulo '+x.module);
   }
  }
  if(!live.length){
   if(ticker){clearInterval(ticker);ticker=null;}
   if(!root.querySelector('.tx-card')){
    const modules=lastData?.modules||{};
    const m=Object.values(modules)[0]||{module:'C'};
    const last=[...(lastData?.history||[])].sort((a,b)=>b.started_at-a.started_at)[0]||null;
    root.innerHTML=standbyCard(m,last);
   }
  }
 }
 function update(data){
  if(!data||!Array.isArray(data.tx_turn_wait))return;
  const allowed=new Set(),now=performance.now();
  for(const x of data.tx_turn_wait.slice(0,26)){
   if(!/^[A-Z]$/.test(x.module)||!Array.isArray(x.callsigns))continue;
   const calls=x.callsigns.slice(0,2).map(String).filter(s=>/^[A-Z0-9/:.-]{1,24}$/.test(s));
   const ms=Math.min(7000,Math.max(0,Number(x.remaining_ms)||0));
   if(!calls.length||!ms)continue;
   const key=String(x.until_ms)+':'+calls.join(',');
   const old=waits.get(x.module);
   const deadline=old&&old.key===key?Math.min(old.deadline,now+ms):now+ms;
   waits.set(x.module,{module:x.module,callsigns:calls,key,deadline});
   allowed.add(x.module);
  }
  for(const module of waits.keys())if(!allowed.has(module))waits.delete(module);
  if([...waits.values()].some(x=>x.deadline>now)&&!ticker)ticker=setInterval(draw,250);
  draw();
 }
 const style=document.createElement('style');
 style.id='xlx-tx-turn-wait-styles';
 style.textContent='.tx-turn-wait-card,.tx-turn-notice{background:#ffe391!important;color:#fff!important;border:3px solid #9b6700!important;border-radius:16px;padding:22px;min-width:0;box-sizing:border-box}.tx-turn-notice{margin:14px 12px 0;padding:14px}.tx-turn-label{font-size:15px;font-weight:800;letter-spacing:.04em}.tx-turn-wait-card h3,.tx-turn-notice h3{color:#fff!important;font-size:clamp(22px,3vw,34px)!important;line-height:1.3;overflow-wrap:anywhere;margin:16px 0!important}.tx-turn-count{display:flex;align-items:center;flex-wrap:wrap;gap:12px;font-size:20px;font-weight:800}.tx-turn-count b{font-size:42px;color:#fff!important}.tx-turn-wait-card p,.tx-turn-notice p{color:#fff!important;font-size:16px;line-height:1.45;margin:14px 0 0}';
 document.head.appendChild(style);
 window.XLX026TurnWait={update,draw};
})();
