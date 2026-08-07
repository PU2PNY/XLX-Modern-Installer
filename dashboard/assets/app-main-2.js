let statusUpdateRunning=false;
async function update(){
 if(statusUpdateRunning||document.hidden)return;
 statusUpdateRunning=true;
 const controller=new AbortController();
 const timeoutId=setTimeout(()=>controller.abort(),4000);
 try{
  const r=await fetch('api/status.php?ts='+Date.now(),{cache:'no-store',signal:controller.signal});
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
 localStorage.getItem('xlxglobalTxRxSound')!=='disabled';

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
   'xlxglobalTxRxSound',
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

   window.XLXGLOBALMTR?.sync(
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

   window.XLXGLOBALMTR?.sync([]);
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
$('#connectedSearch')?.addEventListener('input',e=>{if(lastData)$('#connectedRows').innerHTML=connectedRows(lastData,e.target.value)});
const toggle=document.querySelector('.universal-header .menu-toggle');
const nav=document.querySelector('.universal-header .universal-nav');
toggle?.addEventListener('click',()=>{if(!nav)return;const open=nav.classList.toggle('open');toggle.setAttribute('aria-expanded',String(open))});
