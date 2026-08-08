/* XLX026 HAM WEATHER WIDGET V3 */
(() => {
  'use strict';
  const root=document.getElementById('hamWeatherWidget'); if(!root)return;
  const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const num=(v,d=0)=>Number.isFinite(Number(v))?Number(v).toFixed(d):'—';
  const compass=deg=>Number.isFinite(Number(deg))?['N','NE','L','SE','S','SO','O','NO'][Math.round(Number(deg)/45)%8]:'—';
  const weatherLabel=code=>({0:'Céu limpo',1:'Predominantemente limpo',2:'Parcialmente nublado',3:'Nublado',45:'Neblina',48:'Neblina com geada',51:'Garoa fraca',53:'Garoa',55:'Garoa forte',61:'Chuva fraca',63:'Chuva',65:'Chuva forte',80:'Pancadas fracas',81:'Pancadas',82:'Pancadas fortes',95:'Trovoadas',96:'Trovoadas com granizo',99:'Trovoadas fortes'})[code]||'Condição variável';
  const weatherIcon=code=>code===0?'☀️':code<=2?'🌤️':code===3?'☁️':code<60?'🌫️':code<70?'🌧️':code<90?'🌦️':'⛈️';
  const cls=level=>['favoravel','elevado','boa'].includes(level)?'hamwx-good':['moderada','moderado'].includes(level)?'hamwx-warn':['desfavoravel','baixo'].includes(level)?'hamwx-bad':'hamwx-neutral';
  const label=s=>({favoravel:'Favorável',moderada:'Moderada',desfavoravel:'Desfavorável',elevado:'Elevado',moderado:'Moderado',baixo:'Baixo',indisponivel:'Indisponível'})[s]||s||'Indisponível';
  const time=iso=>{try{return iso?new Date(iso).toLocaleTimeString('pt-BR',{hour:'2-digit',minute:'2-digit'}):'—'}catch{return'—'}};
  const dateTime=iso=>{try{return iso?new Date(iso).toLocaleString('pt-BR',{day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'}):'—'}catch{return'—'}};

  function render(data){
    const w=data.weather,s=data.space||{},l=data.location,scales=s.scales||{R:0,S:0,G:0};
    let loc='Localização não identificada';
    if(l){
      const named=[l.city,l.region,l.country].filter(Boolean).join(' · ');
      loc=named||`${num(l.latitude,2)}, ${num(l.longitude,2)}`;
      if(l.approximate) loc+=' · aproximada';
    }
    const sfiNote=s.sfi_fresh?`Atual: ${dateTime(s.sfi_time)}`:(s.data_status?.sfi==='antigo'?'Dado antigo ocultado':'Indisponível');
    const kpNote=s.kp_fresh?`Atual: ${dateTime(s.kp_time)}`:(s.data_status?.kp==='antigo'?'Dado antigo ocultado':'Indisponível');

    root.innerHTML=`<div class="hamwx-head"><div><p class="eyebrow">RADIOAMADORISMO</p><h2>Clima e condições de propagação</h2><div class="hamwx-sub">${esc(loc)}</div></div><div class="hamwx-updated">Atualizado ${esc(time(w?.updated_at||s.updated_at))}</div></div>
    <div class="hamwx-grid">
      <section class="hamwx-card"><div class="hamwx-card-title"><b>🌤️ CLIMA LOCAL</b><button class="hamwx-location-btn" id="hamWxLocate">${l?'Usar localização mais precisa':'Usar minha localização'}</button></div>
      ${w?`<div class="hamwx-primary"><div class="hamwx-icon">${weatherIcon(w.weather_code)}</div><div><div class="hamwx-temp">${num(w.temperature)}°C</div><div class="hamwx-condition">${esc(weatherLabel(w.weather_code))} · sensação ${num(w.apparent_temperature)}°C</div></div></div>
      <div class="hamwx-list"><div class="hamwx-item"><span>Umidade</span><strong>${num(w.humidity)}%</strong></div><div class="hamwx-item"><span>Pressão</span><strong>${num(w.pressure)} hPa</strong></div><div class="hamwx-item"><span>Vento</span><strong>${num(w.wind_speed)} km/h ${compass(w.wind_direction)}</strong></div><div class="hamwx-item"><span>Rajadas</span><strong>${num(w.wind_gust)} km/h</strong></div><div class="hamwx-item"><span>Chuva</span><strong>${num(w.precipitation_probability)}%</strong></div><div class="hamwx-item"><span>Visibilidade</span><strong>${num(w.visibility_km,1)} km</strong></div></div><div class="hamwx-note">Fonte da localização: ${esc(l?.source_label||'aproximada')}.</div>`:`<div class="hamwx-skeleton">Não foi possível obter o clima local automaticamente. Você ainda pode permitir a localização do navegador.</div>`}</section>

      <section class="hamwx-card"><div class="hamwx-card-title"><b>☀️ PROPAGAÇÃO HF</b><span class="hamwx-status ${cls(s.hf_estimate)}">${label(s.hf_estimate)}</span></div>
      <div class="hamwx-list">
        <div class="hamwx-item"><span>Fluxo solar SFI</span><strong>${num(s.sfi)}</strong><small>${esc(sfiNote)}</small></div>
        <div class="hamwx-item"><span>Índice Kp</span><strong>${num(s.kp,2)}</strong><small>${esc(kpNote)}</small></div>
        <div class="hamwx-item"><span>Blackout rádio</span><strong>R${Number(scales.R||0)}</strong></div>
        <div class="hamwx-item"><span>Tempestade geomagnética</span><strong>G${Number(scales.G||0)}</strong></div>
        <div class="hamwx-item"><span>Radiação solar</span><strong>S${Number(scales.S||0)}</strong></div>
        <div class="hamwx-item"><span>Condição estimada</span><strong class="${cls(s.hf_estimate)}">${label(s.hf_estimate)}</strong></div>
      </div>
      <div class="hamwx-note">Dados solares: NOAA SWPC. Valores fora da janela de atualização são ocultados para não parecerem atuais.</div></section>

      <section class="hamwx-card"><div class="hamwx-card-title"><b>📡 VHF / UHF TROPO</b><span class="hamwx-status ${cls(w?.tropo?.level)}">${label(w?.tropo?.level)}</span></div>
      ${w?`<div class="hamwx-big ${cls(w.tropo?.level)}">Potencial ${label(w.tropo?.level).toLowerCase()}</div><div class="hamwx-meter"><i style="width:${Math.max(8,Math.min(100,(Number(w.tropo?.score||0)+2)*12))}%"></i></div><div class="hamwx-list"><div class="hamwx-item"><span>Ponto de orvalho</span><strong>${num(w.dew_point)}°C</strong></div><div class="hamwx-item"><span>Cobertura de nuvens</span><strong>${num(w.cloud_cover)}%</strong></div><div class="hamwx-item"><span>Nascer do sol</span><strong>${time(w.sunrise)}</strong></div><div class="hamwx-item"><span>Pôr do sol</span><strong>${time(w.sunset)}</strong></div></div>`:`<div class="hamwx-skeleton">O potencial tropo depende do clima local.</div>`}
      <div class="hamwx-note">“Potencial” não significa abertura confirmada; é uma indicação atmosférica preliminar.</div></section>
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
      root.innerHTML='<div class="hamwx-skeleton">Não foi possível carregar clima e propagação agora.</div>';
    }
  }

  function preciseLocation(){
    if(!navigator.geolocation)return;
    const btn=document.getElementById('hamWxLocate');
    if(btn){btn.disabled=true;btn.textContent='Localizando...'}
    navigator.geolocation.getCurrentPosition(
      p=>load(`?lat=${encodeURIComponent(p.coords.latitude)}&lon=${encodeURIComponent(p.coords.longitude)}`),
      ()=>{if(btn){btn.disabled=false;btn.textContent='Permissão não concedida'}},
      {enableHighAccuracy:false,timeout:10000,maximumAge:600000}
    );
  }
  load();
})();
