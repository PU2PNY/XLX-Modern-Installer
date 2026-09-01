/* XLX026 HAM WEATHER WIDGET V3 */
(() => {
  'use strict';
  const root=document.getElementById('hamWeatherWidget'); if(!root)return;
  const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const locale=document.documentElement.lang||'pt-BR';
  const us=locale.toLowerCase().startsWith('en');
  const tr=(pt,en)=>us?en:pt;
  const num=(v,d=0)=>Number.isFinite(Number(v))?Number(v).toFixed(d):'—';
  const compass=deg=>Number.isFinite(Number(deg))?(us?['N','NE','E','SE','S','SW','W','NW']:['N','NE','L','SE','S','SO','O','NO'])[Math.round(Number(deg)/45)%8]:'—';
  const weatherLabel=code=>(us?{0:'Clear sky',1:'Mainly clear',2:'Partly cloudy',3:'Overcast',45:'Fog',48:'Rime fog',51:'Light drizzle',53:'Drizzle',55:'Heavy drizzle',61:'Light rain',63:'Rain',65:'Heavy rain',80:'Light showers',81:'Showers',82:'Heavy showers',95:'Thunderstorms',96:'Thunderstorms with hail',99:'Severe thunderstorms'}:{0:'Céu limpo',1:'Predominantemente limpo',2:'Parcialmente nublado',3:'Nublado',45:'Neblina',48:'Neblina com geada',51:'Garoa fraca',53:'Garoa',55:'Garoa forte',61:'Chuva fraca',63:'Chuva',65:'Chuva forte',80:'Pancadas fracas',81:'Pancadas',82:'Pancadas fortes',95:'Trovoadas',96:'Trovoadas com granizo',99:'Trovoadas fortes'})[code]||tr('Condição variável','Variable conditions');
  const weatherIcon=code=>code===0?'☀️':code<=2?'🌤️':code===3?'☁️':code<60?'🌫️':code<70?'🌧️':code<90?'🌦️':'⛈️';
  const cls=level=>['favoravel','elevado','boa'].includes(level)?'hamwx-good':['moderada','moderado'].includes(level)?'hamwx-warn':['desfavoravel','baixo'].includes(level)?'hamwx-bad':'hamwx-neutral';
  const label=s=>(us?{favoravel:'Favorable',moderada:'Moderate',desfavoravel:'Unfavorable',elevado:'Elevated',moderado:'Moderate',baixo:'Low',indisponivel:'Unavailable'}:{favoravel:'Favorável',moderada:'Moderada',desfavoravel:'Desfavorável',elevado:'Elevado',moderado:'Moderado',baixo:'Baixo',indisponivel:'Indisponível'})[s]||s||tr('Indisponível','Unavailable');
  const temperature=v=>{const n=Number(v);return Number.isFinite(n)?(us?(n*9/5+32).toFixed(0):n.toFixed(0))+'°'+(us?'F':'C'):'—'};
  const wind=v=>{const n=Number(v);return Number.isFinite(n)?(us?(n*0.621371).toFixed(1)+' mph':n.toFixed(1)+' km/h'):'—'};
  const distance=v=>{const n=Number(v);return Number.isFinite(n)?(us?(n*0.621371).toFixed(1)+' mi':n.toFixed(1)+' km'):'—'};
  const pressure=v=>{const n=Number(v);return Number.isFinite(n)?(us?(n*0.029529983).toFixed(2)+' inHg':n.toFixed(0)+' hPa'):'—'};
  const time=iso=>{try{return iso?new Date(iso).toLocaleTimeString(locale,{hour:'2-digit',minute:'2-digit'}):'—'}catch{return'—'}};
  const dateTime=iso=>{try{return iso?new Date(iso).toLocaleString(locale,{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'}):'—'}catch{return'—'}};

  function render(data){
    const w=data.weather,s=data.space||{},l=data.location,scales=s.scales||{R:0,S:0,G:0};
    let loc=tr('Localização não identificada','Location unavailable');
    if(l){
      const named=[l.city,l.region,l.country].filter(Boolean).join(' · ');
      loc=named||`${num(l.latitude,2)}, ${num(l.longitude,2)}`;
      if(l.approximate) loc+=tr(' · aproximada',' · approximate');
    }
    const sfiNote=s.sfi_fresh?tr('Atual: ','Current: ')+dateTime(s.sfi_time):(s.data_status?.sfi==='antigo'?tr('Dado antigo ocultado','Stale data hidden'):tr('Indisponível','Unavailable'));
    const kpNote=s.kp_fresh?tr('Atual: ','Current: ')+dateTime(s.kp_time):(s.data_status?.kp==='antigo'?tr('Dado antigo ocultado','Stale data hidden'):tr('Indisponível','Unavailable'));

    root.innerHTML=`<div class="hamwx-head"><div><p class="eyebrow">${tr("RADIOAMADORISMO","AMATEUR RADIO")}</p><h2>${tr("Clima e condições de propagação","Weather and propagation conditions")}</h2><div class="hamwx-sub">${esc(loc)}</div></div><div class="hamwx-updated">${tr("Atualizado ","Updated ")}${esc(time(w?.updated_at||s.updated_at))}</div></div>
    <div class="hamwx-grid">
      <section class="hamwx-card"><div class="hamwx-card-title"><b>${tr("🌤️ CLIMA LOCAL","🌤️ LOCAL WEATHER")}</b><button class="hamwx-location-btn" id="hamWxLocate">${l?tr('Usar localização mais precisa','Use more precise location'):tr('Usar minha localização','Use my location')}</button></div>
      ${w?`<div class="hamwx-primary"><div class="hamwx-icon">${weatherIcon(w.weather_code)}</div><div><div class="hamwx-temp">${temperature(w.temperature)}</div><div class="hamwx-condition">${esc(weatherLabel(w.weather_code))} · ${tr('sensação ','feels like ')}${temperature(w.apparent_temperature)}</div></div></div>
      <div class="hamwx-list"><div class="hamwx-item"><span>${tr("Umidade","Humidity")}</span><strong>${num(w.humidity)}%</strong></div><div class="hamwx-item"><span>${tr("Pressão","Pressure")}</span><strong>${pressure(w.pressure)}</strong></div><div class="hamwx-item"><span>${tr("Vento","Wind")}</span><strong>${wind(w.wind_speed)} ${compass(w.wind_direction)}</strong></div><div class="hamwx-item"><span>${tr("Rajadas","Wind gusts")}</span><strong>${wind(w.wind_gust)}</strong></div><div class="hamwx-item"><span>${tr("Chuva","Precipitation")}</span><strong>${num(w.precipitation_probability)}%</strong></div><div class="hamwx-item"><span>${tr("Visibilidade","Visibility")}</span><strong>${distance(w.visibility_km)}</strong></div></div><div class="hamwx-note">${tr("Fonte da localização: ","Location source: ")}${esc(l?.source_label||tr('aproximada','approximate'))}.</div>`:`<div class="hamwx-skeleton">${tr("Não foi possível obter o clima local automaticamente. Você ainda pode permitir a localização do navegador.","Local weather could not be obtained automatically. You can still allow browser location.")}</div>`}</section>

      <section class="hamwx-card"><div class="hamwx-card-title"><b>${tr("☀️ PROPAGAÇÃO HF","☀️ HF PROPAGATION")}</b><span class="hamwx-status ${cls(s.hf_estimate)}">${label(s.hf_estimate)}</span></div>
      <div class="hamwx-list">
        <div class="hamwx-item"><span>${tr("Fluxo solar SFI","Solar flux SFI")}</span><strong>${num(s.sfi)}</strong><small>${esc(sfiNote)}</small></div>
        <div class="hamwx-item"><span>${tr("Índice Kp","Kp index")}</span><strong>${num(s.kp,2)}</strong><small>${esc(kpNote)}</small></div>
        <div class="hamwx-item"><span>${tr("Blackout rádio","Radio blackout")}</span><strong>R${Number(scales.R||0)}</strong></div>
        <div class="hamwx-item"><span>${tr("Tempestade geomagnética","Geomagnetic storm")}</span><strong>G${Number(scales.G||0)}</strong></div>
        <div class="hamwx-item"><span>${tr("Radiação solar","Solar radiation")}</span><strong>S${Number(scales.S||0)}</strong></div>
        <div class="hamwx-item"><span>${tr("Condição estimada","Estimated condition")}</span><strong class="${cls(s.hf_estimate)}">${label(s.hf_estimate)}</strong></div>
      </div>
      <div class="hamwx-note">${tr("Dados solares: NOAA SWPC. Valores fora da janela de atualização são ocultados para não parecerem atuais.","Solar data: NOAA SWPC. Values outside the update window are hidden so they are not presented as current.")}</div></section>

      <section class="hamwx-card"><div class="hamwx-card-title"><b>${tr("📡 VHF / UHF TROPO","📡 VHF / UHF TROPO")}</b><span class="hamwx-status ${cls(w?.tropo?.level)}">${label(w?.tropo?.level)}</span></div>
      ${w?`<div class="hamwx-big ${cls(w.tropo?.level)}">${tr("Potencial ","Potential ")}${label(w.tropo?.level).toLowerCase()}</div><div class="hamwx-meter"><i style="width:${Math.max(8,Math.min(100,(Number(w.tropo?.score||0)+2)*12))}%"></i></div><div class="hamwx-list"><div class="hamwx-item"><span>${tr("Ponto de orvalho","Dew point")}</span><strong>${temperature(w.dew_point)}</strong></div><div class="hamwx-item"><span>${tr("Cobertura de nuvens","Cloud cover")}</span><strong>${num(w.cloud_cover)}%</strong></div><div class="hamwx-item"><span>${tr("Nascer do sol","Sunrise")}</span><strong>${time(w.sunrise)}</strong></div><div class="hamwx-item"><span>${tr("Pôr do sol","Sunset")}</span><strong>${time(w.sunset)}</strong></div></div>`:`<div class="hamwx-skeleton">${tr("O potencial tropo depende do clima local.","Tropospheric potential depends on local weather.")}</div>`}
      <div class="hamwx-note">${tr("“Potencial” não significa abertura confirmada; é uma indicação atmosférica preliminar.","“Potential” does not mean a confirmed opening; it is an early atmospheric indication.")}</div></section>
    </div>`;
    document.getElementById('hamWxLocate')?.addEventListener('click',preciseLocation);
  }

  async function load(params=''){
    try{
      const sep=params?'&':'?';
      const r=await fetch(`api/ham-weather.php${params}${sep}_=${Date.now()}`,{cache:'no-store',credentials:'same-origin'});
      if(!r.ok) throw new Error(`HTTP ${r.status}`);
      const d=await r.json();
      if(!d.ok&&!d.needs_location) throw new Error('API');
      render(d);
    }catch(e){
      root.innerHTML='<div class="hamwx-skeleton">${tr("Não foi possível carregar clima e propagação agora.","Weather and propagation could not be loaded now.")}</div>';
    }
  }

  function preciseLocation(){
    if(!navigator.geolocation)return;
    const btn=document.getElementById('hamWxLocate');
    if(btn){btn.disabled=true;btn.textContent=tr('Localizando...','Locating...')}
    navigator.geolocation.getCurrentPosition(
      p=>load(`?lat=${encodeURIComponent(p.coords.latitude)}&lon=${encodeURIComponent(p.coords.longitude)}`),
      ()=>{if(btn){btn.disabled=false;btn.textContent=tr('Permissão não concedida','Permission not granted')}},
      {enableHighAccuracy:false,timeout:10000,maximumAge:600000}
    );
  }
/*
   * XLX026_HAMWX_LAZY_V1
   *
   * Clima e propagação deixam de disputar recursos
   * com o monitor durante o carregamento inicial.
   */

  let initialLoadStarted = false;

  function startInitialWeatherLoad() {

    if (initialLoadStarted) return;

    initialLoadStarted = true;
    load();
  }

  if ('IntersectionObserver' in window) {

    const weatherObserver =
      new IntersectionObserver(
        function (entries) {

          const visible =
            entries.some(
              function (entry) {
                return entry.isIntersecting;
              }
            );

          if (!visible) return;

          weatherObserver.disconnect();
          startInitialWeatherLoad();
        },
        {
          rootMargin: '500px 0px'
        }
      );

    weatherObserver.observe(root);

    /*
     * Fallback:
     * mesmo sem rolar a página, carrega depois.
     */
    window.setTimeout(
      startInitialWeatherLoad,
      4000
    );

  } else {

    window.setTimeout(
      startInitialWeatherLoad,
      1000
    );
  }

})();
