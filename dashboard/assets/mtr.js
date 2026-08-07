'use strict';

(() => {
  const INTERVAL = 3000;
  const MAX_WIDGETS = 3;
  let updateTimer = null;
  let widgets = [];

  const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const txKey = module => String(module?.transmission?.key || `${module?.module || ''}:${module?.transmission?.stream_id || ''}`);
  const finite = value => Number.isFinite(Number(value)) ? Number(value) : null;

  function sparklinePoints(history) {
    const values = (Array.isArray(history) ? history : []).map(finite).filter(v => v !== null);
    if (!values.length) return '';
    if (values.length === 1) return '0,12 100,12';
    const min = Math.min(...values), max = Math.max(...values), range = Math.max(max - min, 1);
    return values.map((v, i) => `${(i/(values.length-1)*100).toFixed(1)},${(21-((v-min)/range)*18).toFixed(1)}`).join(' ');
  }

  function widgetHtml(module) {
    const tx = module.transmission || {};
    const gateway = tx.gateway || [tx.callsign, tx.suffix].filter(Boolean).join(' ') || 'Gateway';
    return `<div class="mtr-mini mtr-unknown" data-loading="0">
      <div class="mtr-head"><span class="mtr-label">MTR</span><strong class="mtr-gateway">${esc(gateway)}</strong><span class="mtr-update">atualizando</span><span class="mtr-info-wrap"><button type="button" class="mtr-info" aria-label="Entenda as informações do MTR">i</button><span class="mtr-tooltip" role="tooltip"><strong>Como interpretar</strong><b>LAT</b>: latência. Quanto menor, melhor.<br><b>PER</b>: perda de pacotes. Ideal: 0%.<br><b>JIT</b>: variação da latência. Quanto menor, mais estável.<br><b>Rota parcial</b>: o destino não respondeu, então a medição usa o último salto válido.</span></span></div>
      <div class="mtr-metrics"><span class="mtr-metric"><small>LAT</small><b class="mtr-latency">— ms</b></span><span class="mtr-metric"><small>PER</small><b class="mtr-loss">—%</b></span><span class="mtr-metric"><small>JIT</small><b class="mtr-jitter">— ms</b></span></div>
      <div class="mtr-graph-row"><span class="mtr-chart"><svg class="mtr-sparkline" viewBox="0 0 100 24" preserveAspectRatio="none" aria-label="Histórico recente da latência"><polyline class="mtr-line" points="" fill="none"></polyline><circle class="mtr-dot" cx="0" cy="12" r="2.5" hidden></circle></svg></span><span class="mtr-state-group"><span class="mtr-quality"><i></i><b>Medindo</b></span><span class="mtr-reason">aguardando dados</span><span class="mtr-trend">→ iniciando</span><span class="mtr-route" hidden>↝ rota parcial</span></span></div>
      <span class="mtr-scale" aria-label="Escala de qualidade"><i class="mtr-scale-marker"></i></span>
    </div>`;
  }

  function score(data) {
    const lat=finite(data.avg_ms), loss=finite(data.loss_pct), jit=finite(data.jitter_ms);
    if (lat===null || loss===null || jit===null) return 0;
    return Math.max(0, Math.min(100, Math.max(lat/2, loss*10, jit*2)));
  }

  function trend(history) {
    const values=(Array.isArray(history)?history:[]).map(finite).filter(v=>v!==null);
    if(values.length<2)return '→ estável';
    const d=values.at(-1)-values.at(-2);
    return d>8?'↑ piorando':d<-8?'↓ melhorando':'→ estável';
  }

  function render(widget, data) {
    const status=['good','warning','bad'].includes(data.status)?data.status:'unknown';
    widget.className=`mtr-mini mtr-${status}`;
    widget.style.setProperty('--mtr-score', `${score(data)}%`);
    const set=(selector,value)=>{const el=widget.querySelector(selector);if(el)el.textContent=value;};
    if(data.gateway)set('.mtr-gateway',data.gateway);
    set('.mtr-update',data.state==='ready'?'agora':(data.status_label||'atualizando'));
    set('.mtr-latency',finite(data.avg_ms)!==null?`${Number(data.avg_ms).toFixed(1)} ms`:'— ms');
    set('.mtr-loss',finite(data.loss_pct)!==null?`${Number(data.loss_pct).toFixed(1)}%`:'—%');
    set('.mtr-jitter',finite(data.jitter_ms)!==null?`${Number(data.jitter_ms).toFixed(1)} ms`:'— ms');
    set('.mtr-quality b',data.status_label||'Medindo');
    set('.mtr-reason',data.state==='waiting'?'aguardando rota':data.state==='queued'?'aguardando vaga':data.route_partial?'último salto válido':'destino final');
    set('.mtr-trend',trend(data.history));
    const route=widget.querySelector('.mtr-route');if(route)route.hidden=!data.route_partial;
    const points=sparklinePoints(data.history);const line=widget.querySelector('.mtr-line');if(line)line.setAttribute('points',points);
    const dot=widget.querySelector('.mtr-dot');
    if(dot){const last=points.trim().split(/\s+/).filter(Boolean).pop();if(last&&last.includes(',')){const [x,y]=last.split(',');dot.setAttribute('cx',x);dot.setAttribute('cy',y);dot.hidden=false;}else dot.hidden=true;}
  }

  async function updateWidget(item) {
    const widget=item.widget;if(!widget?.isConnected||widget.dataset.loading==='1')return;
    widget.dataset.loading='1';
    const tx=item.module.transmission||{};
    const qs=new URLSearchParams({key:txKey(item.module),module:item.module.module||'',callsign:tx.callsign||'',suffix:tx.suffix||''});
    const controller=new AbortController();const timer=setTimeout(()=>controller.abort(),9500);
    try{
      const response=await fetch(`api/mtr.php?${qs}&ts=${Date.now()}`,{cache:'no-store',signal:controller.signal});
      const data=await response.json();
      if(!widget.isConnected)return;
      if(!data.ok){render(widget,{status:'unknown',status_label:data.state==='inactive'?'Finalizando':'Indisponível',avg_ms:null,loss_pct:null,jitter_ms:null,history:[]});return;}
      render(widget,data);
    }catch{if(widget.isConnected)render(widget,{status:'unknown',status_label:'Sem resposta',avg_ms:null,loss_pct:null,jitter_ms:null,history:[]});}
    finally{clearTimeout(timer);if(widget.isConnected)widget.dataset.loading='0';}
  }

  function refreshAll(){if(!document.hidden)widgets.forEach(updateWidget);}
  function stop(){if(updateTimer!==null){clearInterval(updateTimer);updateTimer=null;}widgets=[];}

  function sync(activeModules) {
    stop();
    const grid=document.getElementById('moduleGrid');if(!grid)return;
    const modules=(Array.isArray(activeModules)?activeModules:[]).filter(m=>m?.transmission).slice(0,MAX_WIDGETS);
    if(!modules.length)return;
    const cards=[...grid.children].filter(el=>el.matches('article.tx-card'));
    modules.forEach((module,index)=>{
      const card=cards[index];if(!card)return;
      const stack=document.createElement('div');stack.className='tx-mtr-stack';stack.dataset.mtrKey=txKey(module);stack.innerHTML=widgetHtml(module);
      const widget=stack.querySelector('.mtr-mini');grid.insertBefore(stack,card);stack.appendChild(card);if(widget)widgets.push({module,widget});
    });
    refreshAll();updateTimer=setInterval(refreshAll,INTERVAL);
  }

  document.addEventListener('visibilitychange',()=>{if(!document.hidden)refreshAll();});
  window.XLXGLOBALMTR=Object.freeze({sync});
})();
