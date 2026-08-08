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
function operatorVisual(){return `<div class="operator-visual"><img src="assets/talking-radio.gif" alt="Indicador de transmissão"><span class="signal-ring"></span></div>`}
function txCard(m){
 const tx=m.transmission;
 const countryName=tx.country?.name||'País não informado';
 const gateway=tx.gateway||'Gateway não identificado';
 const callsign=`${esc(tx.callsign)}${tx.suffix?' '+esc(tx.suffix):''}`;

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
    ${operatorVisual()}
    <div class="tx-v30-person-data">
     <a class="tx-v30-callsign" target="_blank" rel="noopener" href="${esc(tx.qrz)}">${callsign}</a>
     <strong class="tx-v30-name">${esc(tx.name||tx.callsign)}</strong>
     <span class="tx-v30-location">${esc(tx.location||'Localização não informada')}</span>
     <span class="tx-v30-country">${flag(tx)} ${esc(countryName)}</span>
    </div>
   </div>

   <div class="tx-v30-details">
    <div>
     <small>Gateway / repetidor</small>
     <strong>${esc(gateway)}</strong>
    </div>

    <div>
     <small>Protocolo e módulo</small>
     <strong>${esc(tx.protocol)} • Módulo ${esc(m.module)}</strong>
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
    <span class="module-badge">{{REFLECTOR_NAME}} AO VIVO</span>
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

function toast(c){let el=document.createElement('div');el.className='toast';el.innerHTML=`<div class="toast-icon">${esc(c.country?.flag||'↗')}</div><div><strong>${esc(c.callsign)} — ${esc(c.name)}</strong><span>Conectou por ${esc(c.protocol)} • módulo ${esc(c.module)}</span></div>`;$('#toastStack')?.append(el);setTimeout(()=>el.classList.add('out'),7500);setTimeout(()=>el.remove(),8500)}
function updateTitle(d){const active=Object.values(d.modules).filter(m=>m.transmission).map(m=>m.transmission.callsign);document.title=active.length?`(${d.connected_count}) ${active.join(' + ')} TX — {{REFLECTOR_NAME}}`:`(${d.connected_count}) {{REFLECTOR_NAME}}`;}
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
function historyStatusMarkup(x,callKey,previousIds){
 const badge=onlineBadge(Boolean(x.online));
 if(!previousIds.length){
  return `<span class="history-status-wrap">${badge}<span class="history-toggle-spacer" aria-hidden="true"></span></span>`;
 }
 const expanded=historyExpandedCalls.has(callKey);
 const label=expanded?'Fechar atividades anteriores':'Abrir atividades anteriores';
 return `<span class="history-status-wrap">${badge}<button type="button" class="history-toggle" data-history-toggle="${esc(callKey)}" aria-expanded="${expanded?'true':'false'}" aria-controls="${esc(previousIds.join(' '))}" aria-label="${label} de ${esc(x.callsign)}" title="${label}"><span aria-hidden="true">▼</span></button></span>`;
}
function historyRowMarkup(x,statusHtml,attrs='',position=''){
 const rowNumber=position===''?'↳':esc(position);
 return `<tr ${attrs}><td><span class="history-row-country"><span class="history-row-number" aria-hidden="true">${rowNumber}</span>${flag(x)}</span></td><td>${fmtTime(x.started_at)}</td><td><a target="_blank" href="${esc(x.qrz)}">${esc(x.callsign)}</a></td><td>${esc(x.name)}</td><td><span class="protocol">${esc(x.protocol)}</span></td><td>${esc(x.module)}</td><td>${duration(x.duration)}</td><td>${statusHtml}</td></tr>`;
}
function historyMarkup(d){
 const rows=d.history||[];
 if(!rows.length)return `<tr><td colspan="8">O histórico será preenchido pelas transmissões registradas.</td></tr>`;
 const groups=new Map();
 rows.forEach((x,index)=>{
  const base=historyCallKey(x);
  const key=base||`SEM-INDICATIVO-${index}`;
  if(!groups.has(key))groups.set(key,[]);
  groups.get(key).push(x);
 });
 return [...groups.entries()].slice(0,20).map(([callKey,items],groupIndex)=>{
  const latest=items[0];
  const previous=items.slice(1);
  const expanded=historyExpandedCalls.has(callKey);
  const previousIds=previous.map((_,index)=>historyRowId(callKey,index));
  const mainAttrs=`class="history-primary-row${expanded?' is-expanded':''}" data-history-call="${esc(callKey)}"`;
  const main=historyRowMarkup(latest,historyStatusMarkup(latest,callKey,previousIds),mainAttrs,groupIndex+1);
  const older=previous.map((x,index)=>{
   const hidden=expanded?'':` style="display:none!important"`;
   const attrs=`id="${esc(previousIds[index])}" class="history-previous-row" data-history-parent="${esc(callKey)}"${hidden}`;
   return historyRowMarkup(x,onlineBadge(Boolean(x.online)),attrs,'');
  }).join('');
  return main+older;
 }).join('');
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
function moduleInfo(m){const defs={A:['Envio de imagens D-STAR','Módulo A • imagens digitais','{{REFLECTOR_NAME}}-A'],B:['APRS / D-PRS','Dados digitais','{{REFLECTOR_NAME}}-B'],C:['C4FM/YSF e DMR','YSF {{YSF_ID}} • DMR TG {{DMR_TG}}','{{REFLECTOR_NAME}}-C'],D:['D-STAR','{{REFLECTOR_NAME}}-D / XRF{{REFLECTOR_NUMBER}}-D','{{REFLECTOR_NAME}}-D'],E:['D-STAR Echo','Teste de áudio','{{REFLECTOR_NAME}}-E']};return defs[m.module]||[m.configured_protocol,m.access,'{{REFLECTOR_NAME}}-'+m.module]}
function renderModules(d){$('#moduleOverview').innerHTML=Object.values(d.modules).map(m=>{const i=moduleInfo(m);return `<article class="module-mini ${m.transmission?'active':''}"><div class="module-mini-top"><span class="module-letter">${esc(m.module)}</span><span class="module-count">${m.connected_count} conectado${m.connected_count===1?'':'s'}</span></div><strong>${esc(i[0])}</strong><small>${esc(i[1])}</small><div class="module-id">${esc(i[2])}</div><div class="module-state">${m.transmission?'<i class="red"></i> Transmitindo agora':'<i></i> Aguardando transmissão'}</div></article>`}).join('');
 const functions={A:'Imagens D-STAR',B:'APRS / D-PRS',C:'C4FM/YSF/DMR',D:'D-STAR',E:'Echo / teste'};
 const rows=Object.values(d.modules).map((m,idx)=>{const n=idx+1,letter=m.module;return `<tr><td><b>${esc(letter)}</b></td><td>${esc(functions[letter]||m.configured_protocol)}</td><td>${m.connected_count}</td><td>REF{{REFLECTOR_NUMBER}}${letter}L</td><td>*26${letter}</td><td>XRF{{REFLECTOR_NUMBER}}${letter}L</td><td>B{{REFLECTOR_SHORT_NUMBER}}${letter}</td><td>DCS{{REFLECTOR_NUMBER}}${letter}L</td><td>D{{REFLECTOR_SHORT_NUMBER}}${letter}</td><td>${4000+n}</td><td>${9+n}</td></tr>`}).join('');$('#moduleReferenceRows').innerHTML=rows; }
function connectedRows(d,query=''){const q=query.trim().toLowerCase();const rows=d.connections.filter(c=>!q||[c.callsign,c.name,c.location,c.protocol,c.module].some(v=>String(v||'').toLowerCase().includes(q)));return rows.length?rows.map((c,i)=>`<tr><td>${i+1}</td><td>${flag(c)}</td><td><a target="_blank" href="${esc(c.qrz)}">${esc(c.callsign)}${c.suffix?' '+esc(c.suffix):''}</a></td><td>${esc(c.name)}</td><td>${esc(c.location)}</td><td><span class="protocol">${esc(c.protocol)}</span></td><td>${esc(c.module)}</td><td>${fmtTime(c.connected_at)}</td><td data-start="${c.connected_at}">${elapsed(c.connected_at)}</td><td>${fmtTime(c.last_activity)}</td></tr>`).join(''):`<tr><td colspan="10">Nenhuma estação corresponde à pesquisa.</td></tr>`}
function rankList(items,valueLabel){return items.length?items.map((x,i)=>`<div class="rank-item"><span class="rank-pos">${i+1}</span><div><b>${esc(x.label)}</b><small>${esc(x.sub||'')}</small></div><strong>${esc(valueLabel(x.value))}</strong></div>`).join(''):'<div class="rank-empty">Dados insuficientes no histórico disponível.</div>'}
function aggregate(arr,keyFn,valFn=()=>1){const m=new Map();arr.forEach(x=>{const k=keyFn(x);if(!k)return;const old=m.get(k)||{label:k,value:0,sub:''};old.value+=valFn(x);m.set(k,old)});return [...m.values()].sort((a,b)=>b.value-a.value)}
function renderRanking(d){const h=d.history||[],c=d.connections||[];const tx=aggregate(h,x=>x.callsign);tx.forEach(x=>{const y=h.find(z=>z.callsign===x.label);x.sub=y?.name||''});const air=aggregate(h,x=>x.callsign,x=>Number(x.duration||0));air.forEach(x=>{const y=h.find(z=>z.callsign===x.label);x.sub=y?.name||''});const con=[...c].sort((a,b)=>a.connected_at-b.connected_at).slice(0,10).map(x=>({label:x.callsign,sub:x.name,value:Math.max(0,Math.floor(Date.now()/1000-x.connected_at))}));const hrs=aggregate(h,x=>String(new Date(x.started_at*1000).getHours()).padStart(2,'0')+':00');const prot=aggregate(h,x=>x.protocol);const mods=aggregate(h,x=>'Módulo '+x.module);$('#rankTx').innerHTML=rankList(tx.slice(0,10),v=>v+' TX');$('#rankAirtime').innerHTML=rankList(air.slice(0,10),v=>duration(v));$('#rankConnected').innerHTML=rankList(con,v=>elapsed(Math.floor(Date.now()/1000-v)));$('#rankHours').innerHTML=rankList(hrs.slice(0,8),v=>v+' TX');$('#rankProtocols').innerHTML=rankList(prot.slice(0,8),v=>v+' TX');$('#rankModules').innerHTML=rankList(mods.slice(0,8),v=>v+' TX');const topTx=tx[0],topAir=air[0],topHour=hrs[0];$('#rankingHighlights').innerHTML=`<article><small>Mais transmissões</small><b>${esc(topTx?.label||'—')}</b><span>${topTx?topTx.value+' transmissões':'Sem dados'}</span></article><article><small>Maior tempo no ar</small><b>${esc(topAir?.label||'—')}</b><span>${topAir?duration(topAir.value):'Sem dados'}</span></article><article><small>Horário mais ativo</small><b>${esc(topHour?.label||'—')}</b><span>${topHour?topHour.value+' transmissões':'Sem dados'}</span></article><article><small>Conectados agora</small><b>${d.connected_count}</b><span>${d.active_count} transmissão${d.active_count===1?'':'ões'} ativa${d.active_count===1?'':'s'}</span></article>`}
function renderReflectors(data){ const rows = (data.reflectors||[]).slice(0,300); $('#reflectorRows').innerHTML = rows.length ? rows.map((r,i)=>`<tr><td>${i+1}</td><td>${r.dashboardurl?`<a target="_blank" rel="noopener" href="${esc(r.dashboardurl)}">${esc(r.name)}</a>`:esc(r.name)}</td><td>${esc(r.country||'—')}</td><td>${onlineBadge((r.status||'').toLowerCase()==='online')}</td><td>${esc(r.comment||'—')}</td></tr>`).join('') : '<tr><td colspan="5">Não foi possível carregar a lista de refletores neste momento.</td></tr>'; }
function render(d){lastData=d;$('#syncState').textContent='Ao vivo';updateTitle(d);
 if(page==='ao-vivo'){ $('#serverLine').textContent=`Atualizado às ${fmtTime(d.generated_at)}`; $('#headerConnected').textContent=d.connected_count; $('#headerActive').textContent=d.active_count; $('#widgetCount').textContent=d.active_count?`${d.active_count} no ar`:'Standby'; const active=Object.values(d.modules).filter(m=>m.transmission); const newest=[...d.history].sort((a,b)=>b.started_at-a.started_at)[0]||null; const standModule=Object.values(d.modules)[0];

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
 $('#historyRows').innerHTML=historyMarkup(d)
 }
 if(page==='modulos')renderModules(d);
 if(page==='conectados'){ $('#connectedLabel').textContent=`${d.connected_count} estação${d.connected_count===1?'':'ões'} conectada${d.connected_count===1?'':'s'}`; $('#connectedCards').innerHTML=Object.values(d.modules).map(m=>`<div class="connected-summary"><b>${m.connected_count}</b><span>Módulo ${esc(m.module)} • ${esc(moduleInfo(m)[0])}</span></div>`).join(''); $('#connectedRows').innerHTML=connectedRows(d,$('#connectedSearch')?.value||'') }
 if(page==='ranking')renderRanking(d);
 const nowSet=new Set(d.connections.map(c=>`${c.callsign}|${c.suffix}|${c.protocol}|${c.module}|${c.ip}`));if(previousConnections!==null)d.connections.forEach(c=>{const k=`${c.callsign}|${c.suffix}|${c.protocol}|${c.module}|${c.ip}`;if(!previousConnections.has(k))toast(c)});previousConnections=nowSet; }
let statusUpdateRunning=false;
async function update(){
 if(statusUpdateRunning||document.hidden)return;
 statusUpdateRunning=true;
 const controller=new AbortController();
 const timeoutId=setTimeout(()=>controller.abort(),4000);
 try{
  const statusEndpoint=page==='ao-vivo'
   ?'api/status.php?history=150&ts='
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
let txRxAudioContext=null;
let txRxAudioUnlocked=false;
/*
 * Som habilitado por padrão.
 * Somente fica desligado quando o usuário escolhe explicitamente
 * a opção desativada.
 */
let txRxSoundEnabled=
 localStorage.getItem('xlx026TxRxSound')!=='disabled';

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
 if(!txRxSoundEnabled)return false;

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

function playTxRxTone(frequency,duration,delay){
 if(!txRxSoundEnabled)return;

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

 oscillator.type='sine';
 oscillator.frequency.setValueAtTime(frequency,start);

 gain.gain.setValueAtTime(0.0001,start);
 gain.gain.exponentialRampToValueAtTime(
  0.16,
  start+0.01
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

function playTxStartedSound(){
 playTxRxTone(880,120,0);
}

function playTxEndedSound(){
 playTxRxTone(660,90,0);
 playTxRxTone(660,90,160);
}

function detectTxRxSound(active){
 const currentKeys=new Set(
  Object.values(active||{}).map(tx=>
   String(tx.key||`${tx.module}:${tx.stream_id}`)
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
 const serverLine=document.getElementById('serverLine');

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

 if(serverLine){
  serverLine.textContent=
   `Atualizado às ${fmtTime(live.generated_at)}`;
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

   window.XLXMTR?.sync(
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

   window.XLXMTR?.sync([]);
  }

  lastLiveVisualSignature=visualSignature;
 }

 updateTitle(lastData);
 ensureTxRxSoundButton();
}

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

  const live=await response.json();

  if(!live.ok)throw Error();

  detectTxRxSound(live.active);

  Object.values(lastData.modules).forEach(module=>{
   module.transmission=
    live.active[module.module]||null;
  });

  lastData.active_count=live.active_count;
  lastData.generated_at=live.generated_at;

  renderLiveTxRxOnly(live);
 }catch(error){
 }finally{
  clearTimeout(timeoutId);
  liveUpdateRunning=false;
 }
}

function startLiveTxRx(){
 if(
  liveUpdateTimer!==null||
  page!=='ao-vivo'
 )return;

 ensureTxRxSoundButton();
 updateLiveTxRx();

 liveUpdateTimer=setInterval(
  updateLiveTxRx,
  250
 );
}

function stopLiveTxRx(){
 if(liveUpdateTimer===null)return;

 clearInterval(liveUpdateTimer);
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
  stopStatusUpdates();
  stopLiveTxRx();
 }else{
  startStatusUpdates();
  startLiveTxRx();
 }
});
if(!document.hidden){
 startStatusUpdates();
 startLiveTxRx();
}
loadReflectors();
$('#historyRows')?.addEventListener('click',event=>{
 const button=event.target.closest('[data-history-toggle]');
 if(!button)return;
 event.preventDefault();
 event.stopPropagation();
 toggleHistoryGroup(button.dataset.historyToggle||'',button);
});
$('#connectedSearch')?.addEventListener('input',e=>{if(lastData)$('#connectedRows').innerHTML=connectedRows(lastData,e.target.value)});
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
     * Verificação leve para acompanhar a atualização dinâmica
     * do painel sem reconstruir a página continuamente.
     */
    window.setInterval(
        scheduleUpdate,
        2000
    );

    if (document.readyState !== 'loading') {
        scheduleUpdate();

        if (document.body) {
            startObserver();
        }
    }
})();

/* ==========================================================
   XLX026_TX_CALLSIGN_FIX_V1
   SOMENTE BOX VERMELHO DE TRANSMISSAO
   ========================================================== */
(function () {
  if (window.__XLX026_TX_CALLSIGN_FIX_V1__) return;
  window.__XLX026_TX_CALLSIGN_FIX_V1__ = true;

  function normalizeLiveCallsign(raw) {
    const txt = String(raw || '')
      .replace(/\s+/g, ' ')
      .trim()
      .toUpperCase();

    if (!txt) return '';

    /* Ex.: PY1RCM B -> PY1RCM-B
       Ex.: PU2PNY D -> PU2PNY-D */
    const m = txt.match(/^([A-Z0-9\/]+)\s+([A-Z])$/);

    if (m) {
      return m[1] + '-' + m[2];
    }

    return txt;
  }

  function fixLiveTxCard() {
    if (!document.body || document.body.dataset.page !== 'ao-vivo') return;

    document.querySelectorAll('.tx-card.live .callsign').forEach(function(el) {
      const fixed = normalizeLiveCallsign(el.textContent);
      if (fixed) {
        el.textContent = fixed;
      }
      el.style.whiteSpace = 'nowrap';
      el.style.wordBreak = 'normal';
      el.style.overflowWrap = 'normal';
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    fixLiveTxCard();

    const target = document.body;
    const observer = new MutationObserver(function () {
      fixLiveTxCard();
    });

    observer.observe(target, {
      childList: true,
      subtree: true,
      characterData: true
    });

    setInterval(fixLiveTxCard, 1500);
  });
})();

/* FIM XLX026_TX_CALLSIGN_FIX_V1 */







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
            row.insertBefore(wrap, nav);
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
