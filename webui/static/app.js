(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const q = s => document.querySelector(s);
  const qa = s => [...document.querySelectorAll(s)];
  const token = decodeURIComponent((location.hash || '').replace(/^#(?:token=)?/, '').trim());
  const app = $('app'), languageScreen = $('language-screen'), fatalScreen = $('fatal-screen'), errorBox = $('error-box');
  let lang = 'pt-BR', step = 1, installing = false, pollTimer = null;

  const copy = {
    'pt-BR': {
      subtitle:'Refletor + Painel • Instalação guiada',
      steps:['Identidade','Localização','Módulos','Rede / YSF','Painel','Administração','Revisão','Instalação'],
      step:'Etapa', of:'de', back:'← Voltar', next:'Continuar →', cancel:'Cancelar', install:'INSTALAR AGORA',
      enter:'Enter passa para a próxima resposta • Campos com * são obrigatórios', community:'Para a comunidade radioamadora',
      how:'Como usar esta tela', help1:'Digite no campo destacado.',
      help2:'<strong>Pressione Enter</strong> para ir para a próxima resposta.',
      help3:'Ao terminar a etapa, selecione <strong>Continuar</strong>.', req:'Campos com * são obrigatórios.',
      auto:'O assistente valida os dados antes de avançar.', required:'Preencha todos os campos obrigatórios antes de continuar.',
      passwordMismatch:'As duas senhas não são iguais.', validating:'Validando os dados…', starting:'Iniciando a instalação…',
      installFailed:'Não foi possível iniciar a instalação.', cancelled:'Assistente encerrado. Você pode fechar esta página.'
    },
    en: {
      subtitle:'Reflector + Dashboard • Guided setup',
      steps:['Identity','Location','Modules','Network / YSF','Dashboard','Administration','Review','Installation'],
      step:'Step', of:'of', back:'← Back', next:'Continue →', cancel:'Cancel', install:'INSTALL NOW',
      enter:'Enter moves to the next answer • Fields marked * are required', community:'For the amateur radio community',
      how:'How to use this screen', help1:'Type in the highlighted field.',
      help2:'<strong>Press Enter</strong> to move to the next answer.',
      help3:'When the step is complete, choose <strong>Continue</strong>.', req:'Fields marked * are required.',
      auto:'The wizard validates your answers before moving on.', required:'Complete all required fields before continuing.',
      passwordMismatch:'The two passwords do not match.', validating:'Validating information…', starting:'Starting installation…',
      installFailed:'Could not start installation.', cancelled:'Installer closed. You may close this page.'
    }
  };

  const stepFields = {
    1:['reflector_id','domain','callsign','email'],
    2:['country','location','timezone'],
    3:['echo','modules'],
    4:['ysf_port','ysf_freq','autolink','autolink_module','ysf_id'],
    5:['dashboard_lang','https'],
    6:['admin_user','admin_slug','admin_password','admin_password_confirm']
  };

  const headers = () => ({'Content-Type':'application/json','X-Installer-Token':token});
  async function api(path, options={}) {
    const response = await fetch(path,{...options,headers:{...headers(),...(options.headers||{})}});
    let data={}; try{data=await response.json();}catch(_){}
    if(!response.ok){const err=new Error(typeof data.detail==='string'?data.detail:'Request failed');err.status=response.status;err.payload=data;throw err;}
    return data;
  }
  function showFatal(text){$('fatal-text').textContent=text;fatalScreen.classList.remove('hidden');app.classList.add('hidden');languageScreen.classList.add('hidden');}
  function renderSteps(){const list=$('steps-list');list.innerHTML='';copy[lang].steps.forEach((name,idx)=>{const li=document.createElement('li');li.className='step-item';li.dataset.step=String(idx+1);li.innerHTML=`<span class="step-num">${idx+1}</span><span class="step-label">${name}</span>`;list.appendChild(li);});}
  function setLanguage(value){lang=value==='en'?'en':'pt-BR';document.documentElement.lang=lang;const t=copy[lang];$('subtitle').textContent=t.subtitle;$('community-note').textContent=t.community;$('help-title').textContent=t.how;$('help-1').textContent=t.help1;$('help-2').innerHTML=t.help2;$('help-3').innerHTML=t.help3;$('help-required').textContent=t.req;$('help-auto').textContent=t.auto;$('enter-hint').textContent=t.enter;$('back').textContent=t.back;$('cancel').textContent=t.cancel;renderSteps();showStep(1);languageScreen.classList.add('hidden');app.classList.remove('hidden');}
  function clearError(){errorBox.textContent='';errorBox.classList.add('hidden');}
  function showError(message,fieldId){errorBox.textContent=message;errorBox.classList.remove('hidden');errorBox.focus();if(fieldId){const field=$(fieldId);if(field){field.setAttribute('aria-invalid','true');setTimeout(()=>field.focus(),0);}}}
  function clearInvalid(){qa('[aria-invalid="true"]').forEach(el=>el.removeAttribute('aria-invalid'));}
  function showStep(number){step=Math.max(1,Math.min(8,number));qa('.step-page').forEach(el=>el.classList.toggle('hidden',Number(el.dataset.step)!==step));qa('.step-item').forEach(el=>{const n=Number(el.dataset.step);el.classList.toggle('active',n===step);el.classList.toggle('done',n<step);});const t=copy[lang];$('top-step').textContent=`${t.step} ${step} ${t.of} 8`;$('top-step-name').textContent=t.steps[step-1];const pct=Math.round(step/8*100);$('wizard-progress').style.width=`${pct}%`;$('wizard-progress-label').textContent=`${pct}% • ${t.step} ${step} ${t.of} 8`;$('back').disabled=step===1||installing;$('back').classList.toggle('hidden',step===8&&installing);$('cancel').disabled=installing;$('next').disabled=installing||step===8;$('next').textContent=step===7?t.install:t.next;clearError();if(step===7)fillReview();const ids=stepFields[step]||[];if(ids.length&&!installing)setTimeout(()=>$(ids[0])?.focus(),0);}
  function prepareDefaults(){const callsign=$('callsign').value.trim().toLowerCase(),rid=$('reflector_id').value.trim().toLowerCase();if(!$('admin_user').value&&callsign)$('admin_user').value=callsign;if(!$('admin_slug').value&&rid)$('admin_slug').value=`controle-${rid}`;}
  const boolValue=id=>$(id).value==='yes'; const intValue=id=>Number.parseInt($(id).value,10);
  function payload(){return{ui_lang:lang,reflector_id:$('reflector_id').value.trim(),domain:$('domain').value.trim(),callsign:$('callsign').value.trim(),email:$('email').value.trim(),country:$('country').value.trim(),location:$('location').value.trim(),timezone:$('timezone').value.trim(),echo:boolValue('echo'),modules:intValue('modules'),ysf_port:intValue('ysf_port'),ysf_freq:intValue('ysf_freq'),autolink:boolValue('autolink'),autolink_module:$('autolink_module').value.trim(),ysf_id:$('ysf_id').value.trim(),dashboard_lang:$('dashboard_lang').value,https:boolValue('https'),admin_user:$('admin_user').value.trim(),admin_slug:$('admin_slug').value.trim(),admin_password:$('admin_password').value};}
  function localValidate(currentStep){clearInvalid();for(const id of(stepFields[currentStep]||[])){const el=$(id);if(!el||el.tagName==='SELECT')continue;if(id==='autolink_module'&&!boolValue('autolink'))continue;if(!String(el.value).trim()){showError(copy[lang].required,id);return false;}}if(currentStep===6&&$('admin_password').value!==$('admin_password_confirm').value){showError(copy[lang].passwordMismatch,'admin_password_confirm');return false;}return true;}
  function fieldErrorFromApi(err){const fields=err?.payload?.detail?.fields;if(!fields||typeof fields!=='object')return false;const [fieldId,message]=Object.entries(fields)[0]||[];if(!fieldId)return false;const stepForField=Object.entries(stepFields).find(([,ids])=>ids.includes(fieldId));if(stepForField)showStep(Number(stepForField[0]));showError(String(message),fieldId);return true;}
  function escapeHtml(value){return String(value).replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));}
  function fillReview(){prepareDefaults();const data=payload(),yes=lang==='pt-BR'?'Sim':'Yes',no=lang==='pt-BR'?'Não':'No';const rows=lang==='pt-BR'?[["Refletor",`XLX${data.reflector_id.toUpperCase()}`],["Domínio",data.domain],["Sysop",`${data.callsign.toUpperCase()} • ${data.email}`],["Local",`${data.location} • ${data.country}`],["Fuso",data.timezone],["Módulos",String(data.modules)],["Echo módulo E",data.echo?yes:no],["YSF",`UDP ${data.ysf_port} • ${data.ysf_freq} Hz • ID ${data.ysf_id}`],["Auto-link YSF",data.autolink?`${yes} • módulo ${data.autolink_module.toUpperCase()}`:no],["HTTPS",data.https?yes:no],["Idioma do painel",data.dashboard_lang],["Admin",`${data.admin_user} • /${data.admin_slug}/`],["Senha",'••••••••']]:[["Reflector",`XLX${data.reflector_id.toUpperCase()}`],["Domain",data.domain],["Sysop",`${data.callsign.toUpperCase()} • ${data.email}`],["Location",`${data.location} • ${data.country}`],["Timezone",data.timezone],["Modules",String(data.modules)],["Echo module E",data.echo?yes:no],["YSF",`UDP ${data.ysf_port} • ${data.ysf_freq} Hz • ID ${data.ysf_id}`],["YSF auto-link",data.autolink?`${yes} • module ${data.autolink_module.toUpperCase()}`:no],["HTTPS",data.https?yes:no],["Dashboard language",data.dashboard_lang],["Admin",`${data.admin_user} • /${data.admin_slug}/`],["Password",'••••••••']];$('review-grid').innerHTML=rows.map(([label,value])=>`<div class="review-item"><span>${escapeHtml(label)}</span><strong>${escapeHtml(value)}</strong></div>`).join('');}
  async function continueWizard(){if(installing)return;clearError();if(step<=6){if(!localValidate(step))return;if(step===1)prepareDefaults();showStep(step+1);return;}if(step===7){try{$('next').disabled=true;$('next').textContent=copy[lang].validating;const data=payload();await api('/api/validate',{method:'POST',body:JSON.stringify(data)});showStep(8);await startInstallation(data);}catch(err){$('next').disabled=false;$('next').textContent=copy[lang].install;if(!fieldErrorFromApi(err))showError(err.message||copy[lang].installFailed);}}}
  async function startInstallation(data){installing=true;window.onbeforeunload=()=>'';$('back').disabled=true;$('next').disabled=true;$('cancel').disabled=true;$('install-stage').textContent=copy[lang].starting;try{await api('/api/install',{method:'POST',body:JSON.stringify(data)});pollTimer=setInterval(pollStatus,900);await pollStatus();}catch(err){installing=false;window.onbeforeunload=null;showError(err.message||copy[lang].installFailed);}}
  async function pollStatus(){try{const s=await api('/api/status');$('install-stage').textContent=s.stage||'';$('install-message').textContent=s.message||'';const progress=Math.max(0,Math.min(100,Number(s.progress||0)));$('install-progress').style.width=`${progress}%`;$('install-progress-label').textContent=`${progress}%`;q('.install-progress-track')?.setAttribute('aria-valuenow',String(progress));$('install-details').textContent=(s.details||[]).join('\n')||(lang==='pt-BR'?'Sem detalhes técnicos no momento.':'No technical details at this time.');if(s.finished){clearInterval(pollTimer);pollTimer=null;installing=false;window.onbeforeunload=null;$('cancel').disabled=false;$('cancel').textContent=lang==='pt-BR'?'Fechar instalador':'Close installer';if(!s.success){$('technical-details').open=true;showError(s.message||(lang==='pt-BR'?'A instalação terminou com erro.':'Installation ended with an error.'));}}}catch(err){if(err.status===401){clearInterval(pollTimer);pollTimer=null;showFatal('A sessão do instalador expirou ou é inválida.');}}}
  async function cancelWizard(){if(installing)return;try{await api('/api/stop',{method:'POST',body:'{}'});}catch(_){}document.body.innerHTML=`<div class="fatal-screen"><div class="fatal-card"><h1>XLX Modern Installer</h1><p>${copy[lang].cancelled}</p></div></div>`;}
  function bindEnterNavigation(){Object.entries(stepFields).forEach(([,ids])=>ids.forEach((id,index)=>{const el=$(id);if(!el||el.tagName==='SELECT')return;el.addEventListener('keydown',event=>{if(event.key!=='Enter')return;event.preventDefault();const nextId=ids.slice(index+1).find(candidate=>candidate!=='autolink_module'||boolValue('autolink'));if(nextId&&$(nextId))$(nextId).focus();else $('next').focus();});}));}
  async function init(){if(!token||token.length<16){showFatal('Abra o endereço completo fornecido pelo comando de inicialização do instalador.');return;}try{const boot=await api('/api/bootstrap');if(boot.timezone)$('timezone').value=boot.timezone;bindEnterNavigation();qa('.language-button').forEach(button=>button.addEventListener('click',()=>setLanguage(button.dataset.lang)));$('back').addEventListener('click',()=>showStep(step-1));$('next').addEventListener('click',continueWizard);$('cancel').addEventListener('click',cancelWizard);$('callsign').addEventListener('change',prepareDefaults);$('reflector_id').addEventListener('change',prepareDefaults);$('autolink').addEventListener('change',()=>{$('autolink_module').disabled=!boolValue('autolink');});languageScreen.classList.remove('hidden');languageScreen.querySelector('button')?.focus();}catch(err){showFatal(err.message||'Não foi possível iniciar a interface.');}}
  init();
})();
