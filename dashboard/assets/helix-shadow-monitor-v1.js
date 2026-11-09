(()=>{
 'use strict';
 if(document.body?.dataset?.page!=='ao-vivo') return;
 /*
  * Lightweight Helix status badge.
  * - Never rewrites the DOM when nothing changed (dataset.helixSignature):
  *   the MutationObserver below watches the same subtree, so unconditional
  *   innerHTML writes re-triggered paint() forever while a TX card existed.
  * - Installations without the optional Helix monitor (updated_at=0, mode=off)
  *   show no badge and poll only every 5 minutes.
  * - Polling pauses while the tab is hidden.
  */
 const ACTIVE_POLL_MS=10000;
 const IDLE_POLL_MS=300000;
 let state={mode:'off',shadow_active:false,ai_connected:false,anomaly:false,updated_at:0};
 let timer=null;
 let paintQueued=false;
 function ensureStyle(){
  if(document.querySelector('link[data-helix-shadow-css]'))return;
  const l=document.createElement('link'); l.rel='stylesheet'; l.href='assets/helix-shadow-monitor-v1.css?v=1'; l.dataset.helixShadowCss='1'; document.head.appendChild(l);
 }
 function deployed(){
  return state.mode==='shadow'||Number(state.updated_at||0)>0;
 }
 function paint(){
  paintQueued=false;
  if(!deployed()){
   document.querySelectorAll('#moduleGrid .tx-helix-status').forEach(el=>el.remove());
   return;
  }
  ensureStyle();
  document.querySelectorAll('#moduleGrid .tx-card.live.tx-v30').forEach(card=>{
   const actions=card.querySelector('.tx-top-actions')||card.querySelector('.tx-top');
   if(!actions)return;
   let el=card.querySelector('.tx-helix-status');
   if(!el){el=document.createElement('span');el.className='tx-helix-status';el.setAttribute('role','status');el.setAttribute('aria-live','polite');actions.insertBefore(el,actions.firstChild);}
   const active=state.mode==='shadow'&&state.shadow_active;
   const anomaly=Boolean(state.anomaly);
   const css='tx-helix-status '+(active?(anomaly?'is-warning':'is-active'):'is-off');
   let html,title;
   if(active){
    html='<i aria-hidden="true"></i><b>HELIX</b><span>MONITORANDO</span>';
    title='Helix ativo em SHADOW: recebe uma cópia PCM desta transmissão para observação. O áudio transmitido continua no caminho legado. '+(state.ai_connected?'IA acompanha a telemetria técnica; nenhum áudio é enviado à IA.':'Monitoramento local ativo.');
   }else{
    html='<i aria-hidden="true"></i><b>HELIX</b><span>INDISPONÍVEL</span>';
    title='Helix shadow não está pronto. O áudio legado continua independente.';
   }
   const signature=css+'|'+html+'|'+title;
   if(el.dataset.helixSignature===signature)return;
   el.className=css;
   el.innerHTML=html;
   el.title=title;
   el.dataset.helixSignature=signature;
  });
 }
 function queuePaint(){
  if(paintQueued)return;
  paintQueued=true;
  if(typeof window.requestAnimationFrame==='function')window.requestAnimationFrame(paint);
  else setTimeout(paint,16);
 }
 function schedule(){
  if(timer!==null){clearTimeout(timer);timer=null;}
  if(document.hidden)return;
  timer=setTimeout(refresh,deployed()?ACTIVE_POLL_MS:IDLE_POLL_MS);
 }
 async function refresh(){
  timer=null;
  try{
   const r=await fetch('api/helix-status.php?ts='+Date.now(),{cache:'no-store',credentials:'same-origin'});
   if(r.ok){state=await r.json();}
  }catch(_e){}
  queuePaint();
  schedule();
 }
 document.addEventListener('visibilitychange',()=>{
  if(document.hidden){if(timer!==null){clearTimeout(timer);timer=null;}}
  else refresh();
 });
 refresh();
 const grid=document.getElementById('moduleGrid');
 if(grid)new MutationObserver(queuePaint).observe(grid,{childList:true,subtree:true});
})();
