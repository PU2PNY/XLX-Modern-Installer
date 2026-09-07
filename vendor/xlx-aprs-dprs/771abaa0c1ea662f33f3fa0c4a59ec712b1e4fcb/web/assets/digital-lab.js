/* XLX APRS/D-PRS — painel isolado; não altera o dashboard principal */
(()=>{
'use strict';
const root=document.getElementById('digitalLab');
if(!root)return;
const $=(id)=>document.getElementById(id);
const api=root.dataset.api||'api/digital-lab.php';
const preview=root.dataset.preview==='1';
const els={
 gateway:$('dlabGatewayStatus'),gatewayDetail:$('dlabGatewayDetail'),
 module:$('dlabModuleStatus'),moduleDetail:$('dlabModuleDetail'),
 aprs:$('dlabAprsStatus'),aprsDetail:$('dlabAprsDetail'),
 stations:$('dlabStations'),count:$('dlabStationCount'),commands:$('dlabCommands'),
 service:$('dlabAprsServicePill'),form:$('dlabBeaconForm'),input:$('dlabCallsign'),
 test:$('dlabTestState'),cancel:$('dlabCancelTest'),mapPlaceholder:$('dlabMapPlaceholder'),
 mapFrame:$('dlabMapFrame'),mapMeta:$('dlabMapMeta'),mapCall:$('dlabMapCall'),
 mapCoords:$('dlabMapCoords'),aprsLink:$('dlabAprsFiLink'),toast:$('dlabToast')
};
let timer=null,latest=null,test=null,toastTimer=null;
const CALL=/^[A-Z0-9]{3,8}(?:-[0-9]{1,2})?$/;

function txt(v){return v==null?'':String(v)}
function upperCall(v){return txt(v).toUpperCase().replace(/[^A-Z0-9-]/g,'').slice(0,11)}
function ts(v){const d=new Date(v);return Number.isNaN(d.getTime())?0:d.getTime()}
function age(v){const t=ts(v);if(!t)return '—';const s=Math.max(0,Math.round((Date.now()-t)/1000));if(s<5)return 'agora';if(s<60)return `há ${s}s`;const m=Math.floor(s/60);if(m<60)return `há ${m} min`;const h=Math.floor(m/60);if(h<24)return `há ${h} h`;return `há ${Math.floor(h/24)} d`}
function coord(v){const n=Number(v);return Number.isFinite(n)?n.toFixed(5):'—'}
function showToast(message){if(!els.toast)return;els.toast.textContent=message;els.toast.hidden=false;clearTimeout(toastTimer);toastTimer=setTimeout(()=>{els.toast.hidden=true},4200)}
function statusClass(card,state){card.classList.remove('is-ok','is-warn','is-error');if(['connected','running'].includes(state))card.classList.add('is-ok');else if(['disabled','connecting','reconnecting','starting'].includes(state))card.classList.add('is-warn');else if(state==='error'||state==='stale')card.classList.add('is-error')}
function prettyState(state){return ({connected:'Conectado',running:'Operacional',disabled:'Aguardando ativação',connecting:'Conectando…',reconnecting:'Reconectando…',starting:'Iniciando…',error:'Falha',stale:'Sem atualização'})[state]||'Verificando…'}
function renderService(key,statusEl,detailEl,data){const card=root.querySelector(`[data-service="${key}"]`);let item=data?.status?.[key];let state='disabled',detail='Aguardando configuração';if(data?.stale){state='stale';detail='Gateway sem atualização recente'}else if(typeof item==='string'){state=item;detail=''}else if(item&&typeof item==='object'){state=txt(item.state)||'disabled';detail=txt(item.detail)}if(key==='gateway'&&typeof item==='string'){state=item==='running'?'running':item}statusEl.textContent=prettyState(state);detailEl.textContent=detail||detailEl.dataset.default||'';if(card)statusClass(card,state)}
function renderStatus(data){renderService('gateway',els.gateway,els.gatewayDetail,data);renderService('module_b',els.module,els.moduleDetail,data);renderService('aprs_is',els.aprs,els.aprsDetail,data);const service=upperCall(data?.config?.aprs_service||'');if(service){els.service.textContent=service;els.service.classList.toggle('is-online',Boolean(data?.status?.aprs_is?.tx_enabled));els.aprsDetail.textContent=data?.status?.aprs_is?.tx_enabled?'Mensagens TX/RX habilitadas':'Recepção ativa / TX não habilitado'}else{els.service.textContent='AGUARDANDO ATIVAÇÃO';els.service.classList.remove('is-online')}}
function sourceLabel(s){return s==='DPRS_MODULE_B'?'D-PRS • B':s==='APRS_IS'?'APRS-IS':txt(s)||'DATA'}
function renderStations(list){const rows=Array.isArray(list)?list:[];els.count.textContent=String(rows.length);els.stations.replaceChildren();if(!rows.length){const e=document.createElement('div');e.className='dlab-empty';e.textContent='Nenhum beacon recebido ainda.';els.stations.append(e);return}rows.forEach(st=>{const b=document.createElement('button');b.type='button';b.className='dlab-station-row';b.dataset.call=txt(st.callsign);b.dataset.lat=txt(st.lat);b.dataset.lon=txt(st.lon);const c=document.createElement('div');c.className='dlab-station-call';const strong=document.createElement('strong');strong.textContent=txt(st.callsign)||'—';const small=document.createElement('span');small.textContent=`${txt(st.protocol)||'Digital'}${st.module?' • Módulo '+st.module:''} • ${age(st.last_seen)}`;c.append(strong,small);const p=document.createElement('div');p.className='dlab-station-position';const ps=document.createElement('strong');ps.textContent=`${coord(st.lat)}, ${coord(st.lon)}`;const pm=document.createElement('span');pm.textContent=txt(st.format)||'Posição';p.append(ps,pm);const badge=document.createElement('span');badge.className='dlab-source-badge';badge.textContent=sourceLabel(st.source);b.append(c,p,badge);b.addEventListener('click',()=>openMap(st));els.stations.append(b)})}
function renderCommands(list){const rows=Array.isArray(list)?list:[];els.commands.replaceChildren();if(!rows.length){const e=document.createElement('div');e.className='dlab-empty';e.textContent='Nenhum comando registrado.';els.commands.append(e);return}rows.slice(0,12).forEach(x=>{const r=document.createElement('div');r.className='dlab-command-row';const peer=document.createElement('strong');peer.textContent=txt(x.peer)||'—';const cmd=document.createElement('code');cmd.textContent=txt(x.command)||'—';const time=document.createElement('time');time.dateTime=txt(x.ts);time.textContent=age(x.ts);r.append(peer,cmd,time);els.commands.append(r)})}
function openMap(st){const lat=Number(st.lat),lon=Number(st.lon);if(!Number.isFinite(lat)||!Number.isFinite(lon))return;const delta=.035;const bbox=[lon-delta,lat-delta,lon+delta,lat+delta].map(x=>x.toFixed(6)).join('%2C');const marker=`${lat.toFixed(6)}%2C${lon.toFixed(6)}`;els.mapFrame.src=`https://www.openstreetmap.org/export/embed.html?bbox=${bbox}&layer=mapnik&marker=${marker}`;els.mapPlaceholder.hidden=true;els.mapFrame.hidden=false;els.mapMeta.hidden=false;els.mapCall.textContent=txt(st.callsign)||'Estação';els.mapCoords.textContent=`${coord(lat)}, ${coord(lon)} • ${age(st.last_seen)}`;els.aprsLink.href=`https://aprs.fi/${encodeURIComponent(txt(st.callsign))}`}
function setTest(mode,title,detail){els.test.classList.remove('is-success','is-error');if(mode)els.test.classList.add('is-'+mode);const d=els.test.querySelector('div:last-child');d.querySelector('strong').textContent=title;d.querySelector('span').textContent=detail}
function startTest(call){test={call,start:Date.now(),expires:Date.now()+120000};els.cancel.hidden=false;setTest('',`Aguardando ${call}…`,'Transmita pelo módulo B com GPS/D-PRS ativado. O teste fica ativo por 2 minutos.');schedule(250)}
function stopTest(message='Teste cancelado.'){test=null;els.cancel.hidden=true;setTest('','Pronto para testar',message)}
function evaluateTest(data){if(!test)return;const stations=Array.isArray(data?.stations)?data.stations:[];const found=stations.find(s=>upperCall(s.callsign)===test.call&&s.source==='DPRS_MODULE_B'&&ts(s.last_seen)>=test.start-1500);if(found){setTest('success',`Beacon de ${test.call} recebido!`,`D-PRS confirmado no módulo B • ${coord(found.lat)}, ${coord(found.lon)} • ${age(found.last_seen)}`);els.cancel.hidden=true;test=null;showToast(`✅ ${found.callsign}: beacon D-PRS recebido pelo módulo B.`);return}if(Date.now()>test.expires){setTest('error','Beacon não encontrado','O período de 2 minutos terminou. Confira se o rádio está no módulo B e se GPS/D-PRS está ativado.');els.cancel.hidden=true;test=null}}
async function load(){try{const res=await fetch(api,{cache:'no-store',headers:{Accept:'application/json'}});const data=await res.json();latest=data;if(!res.ok||data.ok===false){renderOffline(data);return}renderStatus(data);renderStations(data.stations);renderCommands(data.commands);evaluateTest(data)}catch(err){renderOffline({message:'Não foi possível ler o Digital Lab.'})}finally{schedule()}}
function renderOffline(data){const fake={stale:false,status:{gateway:{state:'disabled',detail:txt(data?.message)||'Gateway aguardando ativação'},module_b:{state:'disabled',detail:'Sem conexão ativa'},aprs_is:{state:'disabled',detail:'Sem conexão ativa'}},config:{}};renderStatus(fake);if(!latest){renderStations([]);renderCommands([])}evaluateTest({stations:[]})}
function schedule(delay){clearTimeout(timer);if(preview&&!test)return;const ms=delay??(test?1500:(document.hidden?15000:5000));timer=setTimeout(load,ms)}
els.form?.addEventListener('submit',ev=>{ev.preventDefault();const call=upperCall(els.input.value);els.input.value=call;if(!CALL.test(call)){showToast('Informe um indicativo válido para iniciar o teste.');els.input.focus();return}startTest(call)});
els.cancel?.addEventListener('click',()=>stopTest());
els.input?.addEventListener('input',()=>{els.input.value=upperCall(els.input.value)});
document.addEventListener('visibilitychange',()=>schedule(150));
window.addEventListener('beforeunload',()=>clearTimeout(timer),{once:true});
load();
})();
