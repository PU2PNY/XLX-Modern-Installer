/* XLXMODERN HAM WEATHER WIDGET V3 */
(() => {
  'use strict';
  const root=document.getElementById('hamWeatherWidget'); if(!root)return;
  const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const locale=document.documentElement.lang||'pt-BR';
  const lang2=locale.toLowerCase().slice(0,2);
  const isPt=lang2==='pt';
  // Imperial units only for English; every other locale keeps metric.
  const us=lang2==='en';
  // es/fr/de/it texts keyed by the English string; pt/en use their own argument.
  const T={"es": {"📡 VHF / UHF TROPO": "📡 VHF / UHF TROPO", "Updated ": "Actualizado ", "Radio blackout": "Apagón de radio", "Precipitation": "Precipitación", "Weather and propagation conditions": "Clima y condiciones de propagación", "Cloud cover": "Nubosidad", "Estimated condition": "Condición estimada", "Solar data: NOAA SWPC. Values outside the update window are hidden so they are not presented as current.": "Datos solares: NOAA SWPC. Los valores fuera de la ventana de actualización se ocultan para no presentarlos como actuales.", "Solar flux SFI": "Flujo solar SFI", "Location source: ": "Fuente de la ubicación: ", "Sunrise": "Amanecer", "Local weather could not be obtained automatically. You can still allow browser location.": "No fue posible obtener el clima local automáticamente. Aún puede permitir la ubicación del navegador.", "Tropospheric potential depends on local weather.": "El potencial troposférico depende del clima local.", "Dew point": "Punto de rocío", "Potential ": "Potencial ", "Pressure": "Presión", "Sunset": "Atardecer", "AMATEUR RADIO": "RADIOAFICIONADOS", "Solar radiation": "Radiación solar", "Wind gusts": "Ráfagas", "Geomagnetic storm": "Tormenta geomagnética", "Humidity": "Humedad", "Wind": "Viento", "Visibility": "Visibilidad", "Kp index": "Índice Kp", "“Potential” does not mean a confirmed opening; it is an early atmospheric indication.": "«Potencial» no significa apertura confirmada; es una indicación atmosférica preliminar.", "☀️ HF PROPAGATION": "☀️ PROPAGACIÓN HF", "🌤️ LOCAL WEATHER": "🌤️ CLIMA LOCAL", " · approximate": " · aproximada", "Current: ": "Actual: ", "Variable conditions": "Condiciones variables", "Stale data hidden": "Dato antiguo oculto", "Unavailable": "No disponible", "Locating...": "Localizando...", "Location unavailable": "Ubicación no disponible", "Weather and propagation could not be loaded now.": "No fue posible cargar el clima y la propagación ahora.", "Permission not granted": "Permiso no concedido", "Use more precise location": "Usar ubicación más precisa", "Use my location": "Usar mi ubicación", "approximate": "aproximada", "feels like ": "sensación ", "Clear sky": "Cielo despejado", "Mainly clear": "Mayormente despejado", "Partly cloudy": "Parcialmente nublado", "Overcast": "Nublado", "Fog": "Niebla", "Rime fog": "Niebla con escarcha", "Light drizzle": "Llovizna ligera", "Drizzle": "Llovizna", "Heavy drizzle": "Llovizna intensa", "Light rain": "Lluvia ligera", "Rain": "Lluvia", "Heavy rain": "Lluvia intensa", "Light showers": "Chubascos ligeros", "Showers": "Chubascos", "Heavy showers": "Chubascos fuertes", "Thunderstorms": "Tormentas", "Thunderstorms with hail": "Tormentas con granizo", "Severe thunderstorms": "Tormentas fuertes", "Favorable": "Favorable", "Moderate": "Moderada", "Unfavorable": "Desfavorable", "Elevated": "Elevado", "Low": "Bajo"}, "fr": {"📡 VHF / UHF TROPO": "📡 VHF / UHF TROPO", "Updated ": "Mis à jour ", "Radio blackout": "Black-out radio", "Precipitation": "Précipitations", "Weather and propagation conditions": "Météo et conditions de propagation", "Cloud cover": "Couverture nuageuse", "Estimated condition": "Condition estimée", "Solar data: NOAA SWPC. Values outside the update window are hidden so they are not presented as current.": "Données solaires : NOAA SWPC. Les valeurs hors de la fenêtre de mise à jour sont masquées pour ne pas paraître actuelles.", "Solar flux SFI": "Flux solaire SFI", "Location source: ": "Source de la position : ", "Sunrise": "Lever du soleil", "Local weather could not be obtained automatically. You can still allow browser location.": "Impossible d’obtenir automatiquement la météo locale. Vous pouvez toujours autoriser la localisation du navigateur.", "Tropospheric potential depends on local weather.": "Le potentiel troposphérique dépend de la météo locale.", "Dew point": "Point de rosée", "Potential ": "Potentiel ", "Pressure": "Pression", "Sunset": "Coucher du soleil", "AMATEUR RADIO": "RADIOAMATEUR", "Solar radiation": "Rayonnement solaire", "Wind gusts": "Rafales", "Geomagnetic storm": "Tempête géomagnétique", "Humidity": "Humidité", "Wind": "Vent", "Visibility": "Visibilité", "Kp index": "Indice Kp", "“Potential” does not mean a confirmed opening; it is an early atmospheric indication.": "« Potentiel » ne signifie pas une ouverture confirmée ; c’est une indication atmosphérique préliminaire.", "☀️ HF PROPAGATION": "☀️ PROPAGATION HF", "🌤️ LOCAL WEATHER": "🌤️ MÉTÉO LOCALE", " · approximate": " · approximative", "Current: ": "Actuel : ", "Variable conditions": "Conditions variables", "Stale data hidden": "Donnée ancienne masquée", "Unavailable": "Indisponible", "Locating...": "Localisation...", "Location unavailable": "Position indisponible", "Weather and propagation could not be loaded now.": "Impossible de charger la météo et la propagation pour le moment.", "Permission not granted": "Autorisation refusée", "Use more precise location": "Utiliser une position plus précise", "Use my location": "Utiliser ma position", "approximate": "approximative", "feels like ": "ressenti ", "Clear sky": "Ciel dégagé", "Mainly clear": "Plutôt dégagé", "Partly cloudy": "Partiellement nuageux", "Overcast": "Couvert", "Fog": "Brouillard", "Rime fog": "Brouillard givrant", "Light drizzle": "Bruine légère", "Drizzle": "Bruine", "Heavy drizzle": "Forte bruine", "Light rain": "Pluie faible", "Rain": "Pluie", "Heavy rain": "Forte pluie", "Light showers": "Averses faibles", "Showers": "Averses", "Heavy showers": "Fortes averses", "Thunderstorms": "Orages", "Thunderstorms with hail": "Orages avec grêle", "Severe thunderstorms": "Orages violents", "Favorable": "Favorable", "Moderate": "Modérée", "Unfavorable": "Défavorable", "Elevated": "Élevé", "Low": "Faible"}, "de": {"📡 VHF / UHF TROPO": "📡 VHF / UHF TROPO", "Updated ": "Aktualisiert ", "Radio blackout": "Funkausfall", "Precipitation": "Niederschlag", "Weather and propagation conditions": "Wetter und Ausbreitungsbedingungen", "Cloud cover": "Bewölkung", "Estimated condition": "Geschätzte Bedingung", "Solar data: NOAA SWPC. Values outside the update window are hidden so they are not presented as current.": "Sonnendaten: NOAA SWPC. Werte außerhalb des Aktualisierungsfensters werden ausgeblendet, damit sie nicht als aktuell erscheinen.", "Solar flux SFI": "Solarflux SFI", "Location source: ": "Standortquelle: ", "Sunrise": "Sonnenaufgang", "Local weather could not be obtained automatically. You can still allow browser location.": "Das lokale Wetter konnte nicht automatisch ermittelt werden. Sie können weiterhin den Browser-Standort freigeben.", "Tropospheric potential depends on local weather.": "Das troposphärische Potenzial hängt vom lokalen Wetter ab.", "Dew point": "Taupunkt", "Potential ": "Potenzial ", "Pressure": "Luftdruck", "Sunset": "Sonnenuntergang", "AMATEUR RADIO": "AMATEURFUNK", "Solar radiation": "Sonneneinstrahlung", "Wind gusts": "Böen", "Geomagnetic storm": "Geomagnetischer Sturm", "Humidity": "Luftfeuchtigkeit", "Wind": "Wind", "Visibility": "Sichtweite", "Kp index": "Kp-Index", "“Potential” does not mean a confirmed opening; it is an early atmospheric indication.": "„Potenzial“ bedeutet keine bestätigte Öffnung; es ist ein vorläufiger atmosphärischer Hinweis.", "☀️ HF PROPAGATION": "☀️ KW-AUSBREITUNG", "🌤️ LOCAL WEATHER": "🌤️ LOKALES WETTER", " · approximate": " · ungefähr", "Current: ": "Aktuell: ", "Variable conditions": "Wechselhafte Bedingungen", "Stale data hidden": "Veraltete Daten ausgeblendet", "Unavailable": "Nicht verfügbar", "Locating...": "Standort wird ermittelt...", "Location unavailable": "Standort nicht verfügbar", "Weather and propagation could not be loaded now.": "Wetter und Ausbreitung konnten gerade nicht geladen werden.", "Permission not granted": "Berechtigung nicht erteilt", "Use more precise location": "Genaueren Standort verwenden", "Use my location": "Meinen Standort verwenden", "approximate": "ungefähr", "feels like ": "gefühlt ", "Clear sky": "Klarer Himmel", "Mainly clear": "Überwiegend klar", "Partly cloudy": "Teilweise bewölkt", "Overcast": "Bedeckt", "Fog": "Nebel", "Rime fog": "Reifnebel", "Light drizzle": "Leichter Nieselregen", "Drizzle": "Nieselregen", "Heavy drizzle": "Starker Nieselregen", "Light rain": "Leichter Regen", "Rain": "Regen", "Heavy rain": "Starker Regen", "Light showers": "Leichte Schauer", "Showers": "Schauer", "Heavy showers": "Starke Schauer", "Thunderstorms": "Gewitter", "Thunderstorms with hail": "Gewitter mit Hagel", "Severe thunderstorms": "Schwere Gewitter", "Favorable": "Günstig", "Moderate": "Mäßig", "Unfavorable": "Ungünstig", "Elevated": "Erhöht", "Low": "Niedrig"}, "it": {"📡 VHF / UHF TROPO": "📡 VHF / UHF TROPO", "Updated ": "Aggiornato ", "Radio blackout": "Blackout radio", "Precipitation": "Precipitazioni", "Weather and propagation conditions": "Meteo e condizioni di propagazione", "Cloud cover": "Copertura nuvolosa", "Estimated condition": "Condizione stimata", "Solar data: NOAA SWPC. Values outside the update window are hidden so they are not presented as current.": "Dati solari: NOAA SWPC. I valori fuori dalla finestra di aggiornamento sono nascosti per non apparire attuali.", "Solar flux SFI": "Flusso solare SFI", "Location source: ": "Fonte della posizione: ", "Sunrise": "Alba", "Local weather could not be obtained automatically. You can still allow browser location.": "Impossibile ottenere automaticamente il meteo locale. Puoi comunque consentire la posizione del browser.", "Tropospheric potential depends on local weather.": "Il potenziale troposferico dipende dal meteo locale.", "Dew point": "Punto di rugiada", "Potential ": "Potenziale ", "Pressure": "Pressione", "Sunset": "Tramonto", "AMATEUR RADIO": "RADIOAMATORI", "Solar radiation": "Radiazione solare", "Wind gusts": "Raffiche", "Geomagnetic storm": "Tempesta geomagnetica", "Humidity": "Umidità", "Wind": "Vento", "Visibility": "Visibilità", "Kp index": "Indice Kp", "“Potential” does not mean a confirmed opening; it is an early atmospheric indication.": "«Potenziale» non significa apertura confermata; è un’indicazione atmosferica preliminare.", "☀️ HF PROPAGATION": "☀️ PROPAGAZIONE HF", "🌤️ LOCAL WEATHER": "🌤️ METEO LOCALE", " · approximate": " · approssimativa", "Current: ": "Attuale: ", "Variable conditions": "Condizioni variabili", "Stale data hidden": "Dato vecchio nascosto", "Unavailable": "Non disponibile", "Locating...": "Localizzazione...", "Location unavailable": "Posizione non disponibile", "Weather and propagation could not be loaded now.": "Impossibile caricare meteo e propagazione in questo momento.", "Permission not granted": "Permesso non concesso", "Use more precise location": "Usa una posizione più precisa", "Use my location": "Usa la mia posizione", "approximate": "approssimativa", "feels like ": "percepita ", "Clear sky": "Cielo sereno", "Mainly clear": "Prevalentemente sereno", "Partly cloudy": "Parzialmente nuvoloso", "Overcast": "Coperto", "Fog": "Nebbia", "Rime fog": "Nebbia con brina", "Light drizzle": "Pioviggine leggera", "Drizzle": "Pioviggine", "Heavy drizzle": "Pioviggine intensa", "Light rain": "Pioggia leggera", "Rain": "Pioggia", "Heavy rain": "Pioggia intensa", "Light showers": "Rovesci leggeri", "Showers": "Rovesci", "Heavy showers": "Rovesci forti", "Thunderstorms": "Temporali", "Thunderstorms with hail": "Temporali con grandine", "Severe thunderstorms": "Temporali forti", "Favorable": "Favorevole", "Moderate": "Moderata", "Unfavorable": "Sfavorevole", "Elevated": "Elevato", "Low": "Basso"}};
  const tr=(pt,en)=>isPt?pt:((T[lang2]&&T[lang2][en])||en);
  const num=(v,d=0)=>Number.isFinite(Number(v))?Number(v).toFixed(d):'—';
  const compass=deg=>Number.isFinite(Number(deg))?(isPt?['N','NE','L','SE','S','SO','O','NO']:['N','NE','E','SE','S','SW','W','NW'])[Math.round(Number(deg)/45)%8]:'—';
  const weatherLabel=code=>{const v=(!isPt?{0:'Clear sky',1:'Mainly clear',2:'Partly cloudy',3:'Overcast',45:'Fog',48:'Rime fog',51:'Light drizzle',53:'Drizzle',55:'Heavy drizzle',61:'Light rain',63:'Rain',65:'Heavy rain',80:'Light showers',81:'Showers',82:'Heavy showers',95:'Thunderstorms',96:'Thunderstorms with hail',99:'Severe thunderstorms'}:{0:'Céu limpo',1:'Predominantemente limpo',2:'Parcialmente nublado',3:'Nublado',45:'Neblina',48:'Neblina com geada',51:'Garoa fraca',53:'Garoa',55:'Garoa forte',61:'Chuva fraca',63:'Chuva',65:'Chuva forte',80:'Pancadas fracas',81:'Pancadas',82:'Pancadas fortes',95:'Trovoadas',96:'Trovoadas com granizo',99:'Trovoadas fortes'})[code];return v?(isPt?v:tr(v,v)):tr('Condição variável','Variable conditions')};
  const weatherIcon=code=>code===0?'☀️':code<=2?'🌤️':code===3?'☁️':code<60?'🌫️':code<70?'🌧️':code<90?'🌦️':'⛈️';
  const cls=level=>['favoravel','elevado','boa'].includes(level)?'hamwx-good':['moderada','moderado'].includes(level)?'hamwx-warn':['desfavoravel','baixo'].includes(level)?'hamwx-bad':'hamwx-neutral';
  const label=s=>{const v=(!isPt?{favoravel:'Favorable',moderada:'Moderate',desfavoravel:'Unfavorable',elevado:'Elevated',moderado:'Moderate',baixo:'Low',indisponivel:'Unavailable'}:{favoravel:'Favorável',moderada:'Moderada',desfavoravel:'Desfavorável',elevado:'Elevado',moderado:'Moderado',baixo:'Baixo',indisponivel:'Indisponível'})[s];return v?(isPt?v:tr(v,v)):(s||tr('Indisponível','Unavailable'))};
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
      root.innerHTML='<div class="hamwx-skeleton">'+esc(tr('Não foi possível carregar clima e propagação agora.','Weather and propagation could not be loaded now.'))+'</div>';
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
   * XLXMODERN_HAMWX_LAZY_V1
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
