const $=s=>document.querySelector(s);let previousConnections=null,lastData=null;const page=document.body.dataset.page||'ao-vivo';
const locale=window.XLX_CONFIG?.locale||navigator.language||'pt-BR';
const fmtTime=ts=>ts?new Date(ts*1000).toLocaleTimeString(locale,{hour:'2-digit',minute:'2-digit',second:'2-digit'}):'—';
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
    <span class="module-badge">${esc(window.XLX_CONFIG?.serverName||'XLX')} AO VIVO</span>
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
function updateTitle(d){const active=Object.values(d.modules).filter(m=>m.transmission).map(m=>m.transmission.callsign),name=d.server_name||window.XLX_CONFIG?.serverName||'XLX';document.title=active.length?`(${d.connected_count}) ${active.join(' + ')} TX — ${name}`:`(${d.connected_count}) ${name}`;}
function historyMarkup(d){const rows=d.history.slice(0,30);return rows.length?rows.map(x=>`<tr><td>${flag(x)}</td><td>${fmtTime(x.started_at)}</td><td><a target="_blank" href="${esc(x.qrz)}">${esc(x.callsign)}</a></td><td>${esc(x.name)}</td><td><span class="protocol">${esc(x.protocol)}</span></td><td>${esc(x.module)}</td><td>${duration(x.duration)}</td><td>${onlineBadge(Boolean(x.online))}</td></tr>`).join(''):`<tr><td colspan="8">O histórico será preenchido pelas transmissões registradas.</td></tr>`}
function moduleInfo(m){const server=lastData?.server_name||window.XLX_CONFIG?.serverName||'XLX';return [m.name||m.configured_protocol||('Módulo '+m.module),m.access||m.configured_protocol||'Acesso não configurado',server+'-'+m.module]}
function renderModules(d){$('#moduleOverview').innerHTML=Object.values(d.modules).map(m=>{const i=moduleInfo(m);return `<article class="module-mini ${m.transmission?'active':''}"><div class="module-mini-top"><span class="module-letter">${esc(m.module)}</span><span class="module-count">${m.connected_count} conectado${m.connected_count===1?'':'s'}</span></div><strong>${esc(i[0])}</strong><small>${esc(i[1])}</small><div class="module-id">${esc(i[2])}</div><div class="module-state">${m.transmission?'<i class="red"></i> Transmitindo agora':'<i></i> Aguardando transmissão'}</div></article>`}).join('');
 const code=String(d.reflector_code||'').toUpperCase(),dtmf=String(d.dtmf_number||'');
 const rows=Object.values(d.modules).map(m=>{const letter=m.module,ref=code?`REF${code}${letter}L`:'—',xrf=code?`XRF${code}${letter}L`:'—',dcs=code?`DCS${code}${letter}L`:'—',refDtmf=dtmf?`*${dtmf}${letter}`:'—',xrfDtmf=dtmf?`B${dtmf}${letter}`:'—',dcsDtmf=dtmf?`D${dtmf}${letter}`:'—';return `<tr><td><b>${esc(letter)}</b></td><td>${esc(m.configured_protocol||m.name||'—')}</td><td>${m.connected_count}</td><td>${esc(ref)}</td><td>${esc(refDtmf)}</td><td>${esc(xrf)}</td><td>${esc(xrfDtmf)}</td><td>${esc(dcs)}</td><td>${esc(dcsDtmf)}</td><td>${esc(m.dmr_tg||'—')}</td><td>${esc(m.ysf_dgid||'—')}</td></tr>`}).join('');$('#moduleReferenceRows').innerHTML=rows; }
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

 $('#historyRows').innerHTML=historyMarkup(d)
 }
 if(page==='modulos')renderModules(d);
 if(page==='conectados'){ $('#connectedLabel').textContent=`${d.connected_count} estação${d.connected_count===1?'':'ões'} conectada${d.connected_count===1?'':'s'}`; $('#connectedCards').innerHTML=Object.values(d.modules).map(m=>`<div class="connected-summary"><b>${m.connected_count}</b><span>Módulo ${esc(m.module)} • ${esc(moduleInfo(m)[0])}</span></div>`).join(''); $('#connectedRows').innerHTML=connectedRows(d,$('#connectedSearch')?.value||'') }
 if(page==='ranking')renderRanking(d);
 const nowSet=new Set(d.connections.map(c=>`${c.callsign}|${c.suffix}|${c.protocol}|${c.module}|${c.ip}`));if(previousConnections!==null)d.connections.forEach(c=>{const k=`${c.callsign}|${c.suffix}|${c.protocol}|${c.module}|${c.ip}`;if(!previousConnections.has(k))toast(c)});previousConnections=nowSet; }
