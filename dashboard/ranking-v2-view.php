<style>
body[data-page=ranking] .rv2{display:grid;gap:14px;margin-top:8px}
body[data-page=ranking] .rv2-display{padding:22px;border:1px solid rgba(0,216,255,.45);border-radius:16px;background:linear-gradient(180deg,#061923,#030c12);box-shadow:0 0 30px rgba(0,216,255,.08);text-align:center}
body[data-page=ranking] .rv2-brand{color:#70eaff;font-size:10px;font-weight:900;letter-spacing:.2em}
body[data-page=ranking] .rv2-call{margin-top:15px;color:#fff;font:900 31px "Courier New",monospace;letter-spacing:.1em;text-shadow:0 0 12px #00d8ff}
body[data-page=ranking] .rv2-clock{color:#21eaa0;font:900 30px "Courier New",monospace;letter-spacing:.045em;text-shadow:0 0 12px rgba(33,234,160,.8);font-variant-numeric:tabular-nums;white-space:nowrap}
body[data-page=ranking] .rv2-name{color:#88a9b9;font-size:10px}
body[data-page=ranking] .rv2-tabs{display:flex;justify-content:center;gap:8px;margin-top:18px}
body[data-page=ranking] .rv2-tab{padding:9px 18px;border:1px solid #28556b;border-radius:8px;background:#071923;color:#b7cfda;font-weight:900;font-size:10px;cursor:pointer}
body[data-page=ranking] .rv2-tab.active{color:#fff;border-color:#00d8ff;background:rgba(0,216,255,.12);box-shadow:0 0 16px rgba(0,216,255,.25)}
body[data-page=ranking] .rv2-summary{display:grid;grid-template-columns:repeat(3,1fr);gap:10px}
body[data-page=ranking] .rv2-box,.rv2-card{border:1px solid #1a3a4c;border-radius:14px;background:linear-gradient(145deg,#0e2330,#071721)}
body[data-page=ranking] .rv2-box{padding:14px}
body[data-page=ranking] .rv2-box small{display:block;color:#88a9b9;font-size:8px;text-transform:uppercase;letter-spacing:.1em}
body[data-page=ranking] .rv2-box b{display:block;margin-top:5px;font:900 24px "Courier New",monospace}
body[data-page=ranking] .rv2-grid{display:grid;grid-template-columns:repeat(2,1fr);gap:14px}
body[data-page=ranking] .rv2-card{padding:16px}
body[data-page=ranking] .rv2-card h2{font-size:18px;margin:0 0 12px}
body[data-page=ranking] .rv2-card h2 small{display:block;color:#00d8ff;font-size:8px;letter-spacing:.12em;margin-bottom:4px}
body[data-page=ranking] .rv2-row{display:grid;grid-template-columns:32px 1fr auto;gap:9px;align-items:center;padding:8px 3px;border-bottom:1px solid #143143}
body[data-page=ranking] .rv2-pos{width:27px;height:27px;display:grid;place-items:center;border-radius:8px;background:#0d2b3a;color:#00d8ff;font-weight:900;font-size:10px}
body[data-page=ranking] .rv2-row b{font-size:12px}
body[data-page=ranking] .rv2-row span:last-child{color:#21eaa0;font:900 11px "Courier New",monospace}
body[data-page=ranking] .rv2-bars{display:grid;gap:10px}
body[data-page=ranking] .rv2-barrow{display:grid;grid-template-columns:80px 1fr 80px;gap:8px;align-items:center;font:900 10px "Courier New",monospace}
body[data-page=ranking] .rv2-track{height:13px;border:1px solid #174052;border-radius:4px;overflow:hidden;background:repeating-linear-gradient(90deg,#071923 0 7px,#0e2a38 7px 9px)}
body[data-page=ranking] .rv2-bar{height:100%;background:repeating-linear-gradient(90deg,#00d8ff 0 6px,#087b94 6px 8px);box-shadow:0 0 10px rgba(0,216,255,.45)}
body[data-page=ranking] .rv2-green{color:#21eaa0;text-align:right}
body[data-page=ranking] .rv2-aux{display:grid;grid-template-columns:repeat(3,1fr);gap:14px}
body[data-page=ranking] .rv2-small{display:flex;justify-content:space-between;padding:8px 2px;border-bottom:1px solid #143143;font-size:10px}
body[data-page=ranking] .rv2-small strong{color:#21eaa0;font-family:"Courier New",monospace}
body[data-page=ranking] .rv2-note{padding:11px 13px;border-left:3px solid #21eaa0;background:rgba(33,234,160,.05);color:#94b2bf;font-size:10px}
body[data-page=ranking] .rv2-old{display:none!important}
@media(max-width:820px){
 body[data-page=ranking] .rv2-summary,body[data-page=ranking] .rv2-grid,body[data-page=ranking] .rv2-aux{grid-template-columns:1fr}
 body[data-page=ranking] .rv2-call{font-size:25px}
 body[data-page=ranking] .rv2-clock{font-size:22px;letter-spacing:.02em}
 body[data-page=ranking] .rv2-tabs{display:grid;grid-template-columns:repeat(3,1fr)}
 body[data-page=ranking] .rv2-tab{padding:9px 4px}
 body[data-page=ranking] .rv2-barrow{grid-template-columns:65px 1fr 70px}
}
</style>

<section class="rv2" id="rankingV2">
 <section class="rv2-display">
  <div class="rv2-brand">RANKING {{REFLECTOR_TITLE}}</div>
  <div style="margin-top:12px;color:#88a9b9;font-size:9px;font-weight:900">MAIS TEMPO CONECTADO</div>
  <div class="rv2-call" id="rv2Call">—</div>
  <div class="rv2-clock" id="rv2Clock">00:00:00</div>
  <div class="rv2-name" id="rv2Name">Carregando...</div>
  <div class="rv2-tabs">
   <button class="rv2-tab active" data-p="today">HOJE</button>
   <button class="rv2-tab" data-p="week">7 DIAS</button>
   <button class="rv2-tab" data-p="month">ESTE MÊS</button>
  </div>
 </section>

 <section class="rv2-summary">
  <div class="rv2-box"><small>Transmissões</small><b id="rv2Tx">—</b></div>
  <div class="rv2-box"><small>Tempo total falando</small><b id="rv2Air">—</b></div>
  <div class="rv2-box"><small>Indicativos participantes</small><b id="rv2Users">—</b></div>
 </section>

 <section class="rv2-grid">
  <article class="rv2-card"><h2><small>PTT / TX</small>Mais transmissões</h2><div id="rv2TopTx"></div></article>
  <article class="rv2-card"><h2><small>TEMPO NO AR</small>Mais tempo falando</h2><div id="rv2TopAir"></div></article>
 </section>

 <article class="rv2-card">
  <h2><small>DISPLAY DIGITAL</small>Comparativo de tempo falando</h2>
  <div class="rv2-bars" id="rv2Bars"></div>
 </article>

 <section class="rv2-aux">
  <article class="rv2-card"><h2><small>HORÁRIOS</small>Maior movimento</h2><div id="rv2Hours"></div></article>
  <article class="rv2-card"><h2><small>MÓDULOS</small>Mais utilizados</h2><div id="rv2Mods"></div></article>
  <article class="rv2-card"><h2><small>AGORA</small>Protocolos conectados</h2><div id="rv2Proto"></div></article>
 </section>

 <div class="rv2-note" id="rv2Note">Carregando cobertura estatística...</div>
</section>

<div class="rv2-old">
 <div id="rankingHighlights"></div><div id="rankTx"></div><div id="rankAirtime"></div>
 <div id="rankConnected"></div><div id="rankHours"></div><div id="rankProtocols"></div><div id="rankModules"></div>
</div>

<script>
(()=>{
 if(document.body.dataset.page!=='ranking')return;
 const S={p:'today',r:null,status:null,long:null},$=s=>document.querySelector(s);
 const dur=n=>{n=Math.max(0,+n||0);let h=Math.floor(n/3600),m=Math.floor(n%3600/60),s=Math.floor(n%60);return [h,m,s].map(x=>String(x).padStart(2,'0')).join(':')};

 /* XLX026_RANKING_CONNECTED_DHM_V22
    Somente contador da estacao mais tempo conectada. */
 const connectedDur=n=>{
   n=Math.max(0,Math.floor(+n||0));
   const d=Math.floor(n/86400);
   const h=Math.floor((n%86400)/3600);
   const m=Math.floor((n%3600)/60);

   return d+' dia'+(d===1?'':'s')
     +' '+String(h).padStart(2,'0')+'h'
     +' '+String(m).padStart(2,'0')+'min';
 };
 const num=n=>(+n||0).toLocaleString('pt-BR');
 const rows=(a,f)=>(a||[]).slice(0,10).map((x,i)=>`<div class="rv2-row"><span class="rv2-pos">${i+1}</span><b>${x.label}</b><span>${f(x.value)}</span></div>`).join('')||'<div class="rv2-name">Sem dados.</div>';
 const small=(a,f)=>(a||[]).map(x=>`<div class="rv2-small"><span>${x.label}</span><strong>${f(x.value)}</strong></div>`).join('')||'<div class="rv2-name">Sem dados.</div>';
 function clock(){
  let x=S.long;if(!x)return;
  $('#rv2Clock').textContent=connectedDur(Date.now()/1000-(+x.connected_at||0));
 }
 function longest(){
  let a=[...(S.status?.connections||[])].filter(x=>+x.connected_at>0).sort((a,b)=>a.connected_at-b.connected_at);
  S.long=a[0]||null;
  $('#rv2Call').textContent=S.long?.callsign||'—';
  $('#rv2Name').textContent=[S.long?.name,S.long?.location].filter(Boolean).join(' • ')||'Nenhuma estação conectada';
  clock();
 }
 function render(){
  if(!S.r)return;
  let p=S.r.periods[S.p];
  $('#rv2Tx').textContent=num(p.tx_count);
  $('#rv2Air').textContent=dur(p.airtime_seconds);
  $('#rv2Users').textContent=num(p.unique_callsigns);
  $('#rv2TopTx').innerHTML=rows(p.top_tx,v=>num(v)+' TX');
  $('#rv2TopAir').innerHTML=rows(p.top_airtime,dur);
  let a=(p.top_airtime||[]).slice(0,8),mx=Math.max(1,...a.map(x=>+x.value||0));
  $('#rv2Bars').innerHTML=a.map(x=>`<div class="rv2-barrow"><span>${x.label}</span><div class="rv2-track"><div class="rv2-bar" style="width:${Math.max(2,x.value/mx*100)}%"></div></div><span class="rv2-green">${dur(x.value)}</span></div>`).join('');
  $('#rv2Hours').innerHTML=small(p.hours,v=>num(v)+' TX');
  $('#rv2Mods').innerHTML=small(p.modules,v=>num(v)+' TX');
  let mp=new Map;for(let x of S.status?.connections||[]){if(x.protocol)mp.set(x.protocol,(mp.get(x.protocol)||0)+1)}
  $('#rv2Proto').innerHTML=small([...mp].sort((a,b)=>b[1]-a[1]).map(x=>({label:x[0],value:x[1]})),num);
  let c=S.r.coverage,ok=S.p==='today'?c.today_complete:S.p==='week'?c.week_complete:c.month_complete;
  $('#rv2Note').textContent=(ok?'Cobertura integral disponível para este período.':'Cobertura parcial para este período.')+' Estatísticas atualizadas há '+num(S.r.age_seconds)+' s.';
  longest();
 }
 async function load(){
  try{
   let [r,s]=await Promise.all([
    fetch('/api/ranking-v2.php?t='+Date.now(),{cache:'no-store'}).then(x=>x.json()),
    fetch('/api/status.php?t='+Date.now(),{cache:'no-store'}).then(x=>x.json())
   ]);
   if(r.ok)S.r=r;S.status=s;render();
  }catch(e){console.error('Ranking V2',e);$('#rv2Note').textContent='Falha temporária ao atualizar estatísticas.'}
 }
 document.querySelectorAll('.rv2-tab').forEach(b=>b.onclick=()=>{
  S.p=b.dataset.p;document.querySelectorAll('.rv2-tab').forEach(x=>x.classList.toggle('active',x===b));render();
 });
 load();setInterval(clock,1000);setInterval(load,60000);
})();
</script>
