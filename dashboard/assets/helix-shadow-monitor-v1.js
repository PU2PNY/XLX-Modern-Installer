(()=>{
 'use strict';
 if(document.body?.dataset?.page!=='ao-vivo') return;
 let state={mode:'off',shadow_active:false,ai_connected:false,anomaly:false};
 function esc(s){return String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
 function ensureStyle(){
  if(document.querySelector('link[data-helix-shadow-css]'))return;
  const l=document.createElement('link'); l.rel='stylesheet'; l.href='assets/helix-shadow-monitor-v1.css?v=1'; l.dataset.helixShadowCss='1'; document.head.appendChild(l);
 }
 function paint(){
  document.querySelectorAll('#moduleGrid .tx-card.live.tx-v30').forEach(card=>{
   const actions=card.querySelector('.tx-top-actions')||card.querySelector('.tx-top');
   if(!actions)return;
   let el=card.querySelector('.tx-helix-status');
   if(!el){el=document.createElement('span');el.className='tx-helix-status';el.setAttribute('role','status');el.setAttribute('aria-live','polite');actions.insertBefore(el,actions.firstChild);}
   const active=state.mode==='shadow'&&state.shadow_active;
   const anomaly=Boolean(state.anomaly);
   const css=active?(anomaly?'is-warning':'is-active'):'is-off';
   const label=active?'MONITORANDO':'INDISPONÍVEL';
   const title=active
    ?'Helix ativo em SHADOW: recebe uma cópia PCM desta transmissão para observação. O áudio transmitido continua no caminho legado. '+(state.ai_connected?'IA acompanha a telemetria técnica; nenhum áudio é enviado à IA.':'Monitoramento local ativo.')
    :'Helix shadow não está pronto. O áudio legado continua independente.';
   const signature=[css,label,title].join('|');
   el.className='tx-helix-status '+css;
   if(el.dataset.helixSignature!==signature){
    el.innerHTML='<i aria-hidden="true"></i><b>HELIX</b><span>'+label+'</span>';
    el.title=title;
    el.dataset.helixSignature=signature;
   }
  });
 }
 async function refresh(){
  try{
   const r=await fetch('api/helix-status.php?ts='+Date.now(),{cache:'no-store',credentials:'same-origin'});
   if(r.ok){state=await r.json();}
  }catch(_e){}
  paint();
 }
 ensureStyle(); refresh();
 setInterval(refresh,10000);
 const grid=document.getElementById('moduleGrid');
 if(grid)new MutationObserver(paint).observe(grid,{childList:true,subtree:true});
})();