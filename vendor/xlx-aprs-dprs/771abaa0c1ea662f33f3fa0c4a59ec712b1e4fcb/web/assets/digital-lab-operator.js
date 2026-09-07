/* XLX APRS/D-PRS — contas e administração */
(()=>{
'use strict';

const root=document.getElementById('digitalLab');
if(!root)return;

/* V1.2.1: cadastro começa recolhido */
const registerDisclosure=root.querySelector('.dlab-register-box');

if(registerDisclosure){
  registerDisclosure.removeAttribute('open');
}

const api=root.dataset.operatorApi||'api/digital-lab-operator.php';
const $=id=>document.getElementById(id);

const locked=$('dlabOperatorLocked');
const unlocked=$('dlabOperatorUnlocked');

const loginForm=$('dlabOperatorLoginForm');
const loginCall=$('dlabLoginCall');
const password=$('dlabOperatorPassword');
const remember=$('dlabRememberMe');

const registerForm=$('dlabRegisterForm');
const registerCall=$('dlabRegisterCall');
const birthDay=$('dlabBirthDay');
const birthMonth=$('dlabBirthMonth');
const birthdayConsent=$('dlabBirthdayConsent');
const registerResult=$('dlabRegisterResult');

const accountTitle=$('dlabAccountTitle');
const roleBadge=$('dlabRoleBadge');
const state=$('dlabOperatorState');

const usersBtn=$('dlabUsersBtn');
const resetBtn=$('dlabResetBtn');
const collaboratorsBtn=$('dlabCollaboratorsBtn');
const auditBtn=$('dlabAuditBtn');
const myPasswordBtn=$('dlabMyPasswordBtn');
const setBirthBtn=$('dlabSetBirthBtn');
const birthWarning=$('dlabBirthWarning');
const userNotice=$('dlabUserNotice');

const soundToggle=$('dlabSoundToggle');
const unreadBadge=$('dlabUnreadBadge');
const logout=$('dlabOperatorLogout');

const form=$('dlabMessageForm');
const dest=$('dlabMessageDest');
const message=$('dlabMessageText');
const count=$('dlabMessageCount');
const send=$('dlabMessageSend');
const historyWrap=$('dlabPrivateHistory');
const history=$('dlabOperatorMessages');

const dialog=$('dlabAccountDialog');
const dialogTitle=$('dlabDialogTitle');
const dialogBody=$('dlabDialogBody');
const dialogClose=$('dlabDialogClose');

const toast=$('dlabToast');

let csrf='';
let account=null;
let permissions={};
let timer=null;
let toastTimer=null;
let audioCtx=null;
let lastInboundId=null;
let unread=0;

const CALL=/^(?=[A-Z0-9]*[0-9])[A-Z0-9]{3,8}$/;
const APRS_CALL=/^[A-Z0-9]{3,8}(?:-[0-9]{1,2})?$/;

function notify(text){
  if(!toast)return;

  toast.textContent=text;
  toast.hidden=false;

  clearTimeout(toastTimer);

  toastTimer=setTimeout(()=>{
    toast.hidden=true;
  },5000);
}

function cleanBaseCall(v){
  return String(v??'')
    .toUpperCase()
    .replace(/[^A-Z0-9]/g,'')
    .slice(0,8);
}

function cleanAprsCall(v){
  return String(v??'')
    .toUpperCase()
    .replace(/[^A-Z0-9-]/g,'')
    .slice(0,9);
}

function monthName(m){
  return [
    '',
    'Janeiro','Fevereiro','Março','Abril',
    'Maio','Junho','Julho','Agosto',
    'Setembro','Outubro','Novembro','Dezembro'
  ][Number(m)]||'—';
}

function statusName(v){
  return ({
    awaiting_ack:'Aguardando ACK',
    acked:'ACK recebido',
    rejected:'Rejeitada',
    received:'Recebida',
    sent:'Enviada'
  })[v]||String(v||'—');
}

async function jsonFetch(url,options={}){
  const response=await fetch(url,{
    cache:'no-store',
    credentials:'same-origin',
    ...options
  });

  let data={};

  try{
    data=await response.json();
  }catch(_){
    data={ok:false,error:'invalid_response'};
  }

  if(!response.ok){
    const err=new Error(
      data.error||`HTTP ${response.status}`
    );

    err.data=data;
    throw err;
  }

  return data;
}

async function post(action,payload={}){
  return jsonFetch(api,{
    method:'POST',
    headers:{
      'Content-Type':'application/json',
      'Accept':'application/json',
      ...(csrf?{'X-CSRF-Token':csrf}:{})
    },
    body:JSON.stringify({
      action,
      ...payload
    })
  });
}

function loadSoundPref(){
  try{
    return localStorage.getItem(
      'xlx_aprs_dprs_sound'
    )!=='0';
  }catch(_){
    return true;
  }
}

let soundEnabled=loadSoundPref();

function saveSoundPref(){
  try{
    localStorage.setItem(
      'xlx_aprs_dprs_sound',
      soundEnabled?'1':'0'
    );
  }catch(_){}
}

function updateSoundButton(){
  if(!soundToggle)return;

  soundToggle.textContent=soundEnabled
    ? '🔊 Som ligado'
    : '🔇 Som desligado';

  soundToggle.setAttribute(
    'aria-pressed',
    soundEnabled?'true':'false'
  );
}

function updateUnread(){
  unreadBadge.hidden=unread<1;

  if(unread>0){
    unreadBadge.textContent=
      unread===1 ? '1 nova' : `${unread} novas`;
  }
}

async function ensureAudio(){
  if(!soundEnabled)return null;

  const AudioClass=
    window.AudioContext||
    window.webkitAudioContext;

  if(!AudioClass)return null;

  if(!audioCtx){
    audioCtx=new AudioClass();
  }

  if(audioCtx.state==='suspended'){
    try{
      await audioCtx.resume();
    }catch(_){}
  }

  return audioCtx;
}

async function playMessageChime(){
  if(!soundEnabled)return;

  const ctx=await ensureAudio();

  if(!ctx||ctx.state!=='running')return;

  const start=ctx.currentTime+.01;

  function note(freq,offset,duration,level){
    const osc=ctx.createOscillator();
    const gain=ctx.createGain();

    osc.type='sine';

    osc.frequency.setValueAtTime(
      freq,
      start+offset
    );

    gain.gain.setValueAtTime(
      .0001,
      start+offset
    );

    gain.gain.exponentialRampToValueAtTime(
      level,
      start+offset+.018
    );

    gain.gain.exponentialRampToValueAtTime(
      .0001,
      start+offset+duration
    );

    osc.connect(gain);
    gain.connect(ctx.destination);

    osc.start(start+offset);
    osc.stop(start+offset+duration+.03);
  }

  note(740,0,.13,.07);
  note(988,.105,.20,.055);
}

function inspectIncoming(rows){
  const incoming=(Array.isArray(rows)?rows:[])
    .filter(x=>x.direction==='in')
    .map(x=>({
      ...x,
      numericId:Number(x.id)||0
    }))
    .filter(x=>x.numericId>0)
    .sort((a,b)=>a.numericId-b.numericId);

  if(!incoming.length)return;

  const newest=incoming[incoming.length-1];

  if(lastInboundId===null){
    lastInboundId=newest.numericId;
    return;
  }

  const fresh=incoming.filter(
    x=>x.numericId>lastInboundId
  );

  if(!fresh.length)return;

  lastInboundId=newest.numericId;
  unread+=fresh.length;
  updateUnread();

  void playMessageChime();

  const last=fresh[fresh.length-1];

  notify(
    `🔔 Nova mensagem APRS de ${String(last.peer||'estação')}.`
  );
}

function prepareAprsReply(rawCall){
  const call=cleanAprsCall(rawCall);

  if(!APRS_CALL.test(call)){
    notify('Indicativo APRS inválido.');
    return;
  }

  if(
    !account ||
    !permissions.send_aprs ||
    !form ||
    form.hidden
  ){
    notify(
      'Entre como ADMIN para responder pelo painel.'
    );
    return;
  }

  dest.value=call;

  form.scrollIntoView({
    behavior:'smooth',
    block:'center'
  });

  window.setTimeout(()=>{
    message.focus();
  },300);

  notify(
    `${call} colocado em Destinatário APRS.`
  );
}

function renderMessages(rows){
  history.replaceChildren();

  if(!Array.isArray(rows)||!rows.length){
    const e=document.createElement('div');
    e.className='dlab-empty';
    e.textContent='Nenhuma mensagem.';
    history.append(e);
    return;
  }

  rows.slice(0,20).forEach(x=>{
    const row=document.createElement('div');
    row.className='dlab-private-message';

    if(x.status==='acked'){
      row.classList.add('is-acked');
    }

    if(x.status==='rejected'){
      row.classList.add('is-rejected');
    }

    const d=document.createElement('span');
    d.className='dir';
    d.textContent=
      x.direction==='out'
        ? 'ENVIADA'
        : 'RECEBIDA';

    const peer=document.createElement('button');
    peer.type='button';
    peer.className='peer dlab-peer-button';
    peer.textContent=String(x.peer||'—');

    if(x.peer){
      peer.title=
        `Responder para ${String(x.peer)}`;

      peer.setAttribute(
        'aria-label',
        `Responder para ${String(x.peer)}`
      );

      peer.addEventListener(
        'click',
        ()=>prepareAprsReply(x.peer)
      );
    }else{
      peer.disabled=true;
    }

    const b=document.createElement('span');
    b.className='body';
    b.textContent=String(x.body||'');

    const st=document.createElement('span');
    st.className='status';
    st.textContent=statusName(x.status);

    row.append(d,peer,b,st);
    history.append(row);
  });
}

function setLoggedOut(){
  account=null;
  permissions={};
  csrf='';

  locked.hidden=false;
  unlocked.hidden=true;

  lastInboundId=null;
  unread=0;

  updateUnread();
}

function applyPermissions(){
  const role=String(account?.role||'USER');

  roleBadge.textContent=
    role==='ADMIN'
      ? 'ADMIN'
      : role==='COLLABORATOR'
        ? 'COLABORADOR'
        : 'USUÁRIO';

  roleBadge.dataset.role=role;

  usersBtn.hidden=!permissions.manage_users;
  resetBtn.hidden=!permissions.reset_password;
  collaboratorsBtn.hidden=
    !permissions.manage_collaborators;
  auditBtn.hidden=!permissions.audit;

  const canSend=Boolean(
    permissions.send_aprs
  );

  form.hidden=!canSend;
  historyWrap.hidden=!canSend;
  soundToggle.hidden=!canSend;
  unreadBadge.hidden=
    !canSend || unread<1;

  userNotice.hidden=canSend;

  birthWarning.hidden=
    Boolean(account?.birth_complete);

  accountTitle.textContent=
    `${account.callsign} autenticado`;

  if(role==='ADMIN'){
    state.textContent=
      'Administrador • acesso total';
  }else if(role==='COLLABORATOR'){
    state.textContent=
      'Colaborador • recuperação de usuários';
  }else{
    state.textContent=
      'Conta ativa';
  }
}

async function refresh(){
  try{
    const data=await jsonFetch(
      `${api}?action=status`
    );

    if(!data.auth){
      setLoggedOut();
      return;
    }

    locked.hidden=true;
    unlocked.hidden=false;

    csrf=String(data.csrf||'');
    account=data.account||{};
    permissions=data.permissions||{};

    applyPermissions();

    if(permissions.send_aprs){
      const op=data.operator||{};

      const connected=Boolean(op.connected);
      const tx=Boolean(op.tx_enabled);

      state.textContent=connected
        ? (
            tx
              ? 'Administrador • APRS-IS verified • TX habilitado'
              : 'Administrador • APRS-IS verified • TX bloqueado'
          )
        : 'Administrador • APRS-IS não está pronto';

      send.disabled=!(connected&&tx);

      const rows=op.messages||[];

      inspectIncoming(rows);
      renderMessages(rows);
    }

  }catch(_){
    if(account){
      state.textContent=
        'Não foi possível consultar o acesso.';
    }
  }
}

function showCredential(call,passwordValue,title='Nova senha'){
  dialogTitle.textContent=title;
  dialogBody.replaceChildren();

  const box=document.createElement('div');
  box.className='dlab-generated-password';

  const callEl=document.createElement('strong');
  callEl.textContent=call;

  const label=document.createElement('span');
  label.textContent=
    'Esta senha é exibida somente agora.';

  const code=document.createElement('code');
  code.textContent=passwordValue;

  const actions=document.createElement('div');
  actions.className='dlab-dialog-actions';

  const copy=document.createElement('button');
  copy.type='button';
  copy.className='dlab-btn dlab-btn-primary';
  copy.textContent='Copiar senha';

  const copyMessage=document.createElement('button');
  copyMessage.type='button';
  copyMessage.className='dlab-btn dlab-btn-ghost';
  copyMessage.textContent=
    'Copiar mensagem para enviar';

  copy.addEventListener('click',async()=>{
    try{
      await navigator.clipboard.writeText(
        passwordValue
      );
      notify('Senha copiada.');
    }catch(_){
      window.prompt(
        'Copie a senha:',
        passwordValue
      );
    }
  });

  copyMessage.addEventListener(
    'click',
    async()=>{
      const text=
        `Olá ${call}. Sua nova senha de acesso ao Digital Lab XLX APRS/D-PRS é: ${passwordValue}. Guarde esta senha para os próximos acessos.`;

      try{
        await navigator.clipboard.writeText(text);
        notify('Mensagem pronta copiada.');
      }catch(_){
        window.prompt(
          'Copie a mensagem:',
          text
        );
      }
    }
  );

  actions.append(copy,copyMessage);

  box.append(
    callEl,
    label,
    code,
    actions
  );

  dialogBody.append(box);

  if(!dialog.open){
    dialog.showModal();
  }
}

function openDialog(title){
  dialogTitle.textContent=title;
  dialogBody.replaceChildren();

  if(!dialog.open){
    dialog.showModal();
  }
}

function createField(labelText,type='text'){
  const wrap=document.createElement('label');
  wrap.className='dlab-dialog-field';

  const label=document.createElement('span');
  label.textContent=labelText;

  const input=document.createElement('input');
  input.type=type;

  wrap.append(label,input);

  return {wrap,input};
}

function createBirthFields(){
  const row=document.createElement('div');
  row.className='dlab-birthday-grid';

  const day=createField('Dia','number');
  day.input.min='1';
  day.input.max='31';

  const monthWrap=document.createElement('label');
  monthWrap.className='dlab-dialog-field';

  const monthLabel=document.createElement('span');
  monthLabel.textContent='Mês';

  const month=document.createElement('select');

  const blank=document.createElement('option');
  blank.value='';
  blank.textContent='Selecione';
  month.append(blank);

  for(let i=1;i<=12;i++){
    const op=document.createElement('option');
    op.value=String(i);
    op.textContent=monthName(i);
    month.append(op);
  }

  monthWrap.append(monthLabel,month);
  row.append(day.wrap,monthWrap);

  return {
    row,
    day:day.input,
    month
  };
}

async function openReset(prefill=''){
  openDialog('Recuperar senha');

  const intro=document.createElement('p');
  intro.className='dlab-dialog-text';
  intro.textContent=
    'Peça ao operador o indicativo e o dia/mês real do aniversário. A senha antiga será invalidada e uma nova será gerada.';

  const formEl=document.createElement('form');
  formEl.className='dlab-dialog-form';

  const call=createField('Indicativo');
  call.input.value=cleanBaseCall(prefill);
  call.input.maxLength=8;

  const birth=createBirthFields();

  const submit=document.createElement('button');
  submit.type='submit';
  submit.className='dlab-btn dlab-btn-primary';
  submit.textContent='Gerar nova senha';

  formEl.append(
    call.wrap,
    birth.row,
    submit
  );

  formEl.addEventListener('submit',async ev=>{
    ev.preventDefault();

    const c=cleanBaseCall(call.input.value);

    try{
      const data=await post(
        'reset_password',
        {
          callsign:c,
          birth_day:Number(birth.day.value),
          birth_month:Number(birth.month.value)
        }
      );

      showCredential(
        data.callsign,
        data.password,
        'Senha redefinida'
      );

    }catch(err){
      const code=err?.data?.error;

      const labels={
        account_not_found:'Indicativo não cadastrado.',
        birthday_mismatch:'Dia ou mês do aniversário não confere.',
        forbidden:'Seu nível não permite redefinir esta conta.',
        admin_reset_denied:'A senha do ADMIN deve ser trocada pela própria conta.'
      };

      notify(
        labels[code]||
        'Não foi possível gerar a nova senha.'
      );
    }
  });

  dialogBody.append(intro,formEl);
}

async function loadUsers(){
  const data=await jsonFetch(
    `${api}?action=users`
  );

  return Array.isArray(data.users)
    ? data.users
    : [];
}

function userRow(u){
  const row=document.createElement('div');
  row.className='dlab-user-row';

  const info=document.createElement('div');

  const name=document.createElement('strong');
  name.textContent=u.callsign;

  const meta=document.createElement('span');

  const bd=
    u.birth_day&&u.birth_month
      ? `${String(u.birth_day).padStart(2,'0')}/${String(u.birth_month).padStart(2,'0')}`
      : 'aniversário pendente';

  meta.textContent=
    `${u.role} • ${u.status} • ${bd}`;

  info.append(name,meta);

  const actions=document.createElement('div');
  actions.className='dlab-row-actions';

  if(u.role!=='ADMIN'){
    const reset=document.createElement('button');
    reset.type='button';
    reset.textContent='Senha';

    reset.addEventListener(
      'click',
      ()=>openReset(u.callsign)
    );

    const role=document.createElement('button');
    role.type='button';

    role.textContent=
      u.role==='COLLABORATOR'
        ? 'Tornar usuário'
        : 'Tornar colaborador';

    role.addEventListener('click',async()=>{
      const newRole=
        u.role==='COLLABORATOR'
          ? 'USER'
          : 'COLLABORATOR';

      if(!confirm(
        `Alterar ${u.callsign} para ${newRole}?`
      ))return;

      try{
        await post(
          'set_role',
          {
            callsign:u.callsign,
            role:newRole
          }
        );

        notify('Permissão atualizada.');
        await openUsers();

      }catch(_){
        notify(
          'Não foi possível alterar a permissão.'
        );
      }
    });

    const status=document.createElement('button');
    status.type='button';

    status.textContent=
      u.status==='ACTIVE'
        ? 'Bloquear'
        : 'Ativar';

    status.addEventListener('click',async()=>{
      const newStatus=
        u.status==='ACTIVE'
          ? 'BLOCKED'
          : 'ACTIVE';

      if(!confirm(
        `${newStatus==='BLOCKED'?'Bloquear':'Ativar'} ${u.callsign}?`
      ))return;

      try{
        await post(
          'set_status',
          {
            callsign:u.callsign,
            status:newStatus
          }
        );

        notify('Status atualizado.');
        await openUsers();

      }catch(_){
        notify(
          'Não foi possível alterar o status.'
        );
      }
    });

    actions.append(reset,role,status);
  }

  row.append(info,actions);

  return row;
}

async function openUsers(){
  openDialog('Usuários');

  const create=document.createElement('details');
  create.className='dlab-admin-create';

  const summary=document.createElement('summary');
  summary.textContent='Cadastrar manualmente';

  const formEl=document.createElement('form');
  formEl.className='dlab-dialog-form';

  const call=createField('Indicativo');
  call.input.maxLength=8;

  const birth=createBirthFields();

  const roleWrap=document.createElement('label');
  roleWrap.className='dlab-dialog-field';

  const roleLabel=document.createElement('span');
  roleLabel.textContent='Nível';

  const role=document.createElement('select');

  [
    ['USER','Usuário'],
    ['COLLABORATOR','Colaborador']
  ].forEach(([value,text])=>{
    const op=document.createElement('option');
    op.value=value;
    op.textContent=text;
    role.append(op);
  });

  roleWrap.append(roleLabel,role);

  const submit=document.createElement('button');
  submit.type='submit';
  submit.className='dlab-btn dlab-btn-primary';
  submit.textContent='Cadastrar e gerar senha';

  formEl.append(
    call.wrap,
    birth.row,
    roleWrap,
    submit
  );

  formEl.addEventListener('submit',async ev=>{
    ev.preventDefault();

    try{
      const data=await post(
        'admin_create_user',
        {
          callsign:cleanBaseCall(call.input.value),
          birth_day:Number(birth.day.value),
          birth_month:Number(birth.month.value),
          role:role.value
        }
      );

      showCredential(
        data.callsign,
        data.password,
        'Conta criada'
      );

    }catch(err){
      notify(
        err?.data?.error==='account_exists'
          ? 'Este indicativo já está cadastrado.'
          : 'Não foi possível cadastrar.'
      );
    }
  });

  create.append(summary,formEl);

  const list=document.createElement('div');
  list.className='dlab-user-list';

  dialogBody.append(create,list);

  try{
    const users=await loadUsers();

    users.forEach(u=>{
      list.append(userRow(u));
    });

  }catch(_){
    notify('Não foi possível carregar usuários.');
  }
}

async function openCollaborators(){
  openDialog('Colaboradores');

  const intro=document.createElement('p');
  intro.className='dlab-dialog-text';
  intro.textContent=
    'O colaborador pode recuperar a senha de USUÁRIOS, mas não pode criar administradores, enviar APRS pelo painel ou alterar configurações.';

  const list=document.createElement('div');
  list.className='dlab-user-list';

  dialogBody.append(intro,list);

  try{
    const users=await loadUsers();

    const collabs=users.filter(
      u=>u.role==='COLLABORATOR'
    );

    if(!collabs.length){
      const empty=document.createElement('div');
      empty.className='dlab-empty';
      empty.textContent='Nenhum colaborador cadastrado.';
      list.append(empty);
      return;
    }

    collabs.forEach(u=>{
      list.append(userRow(u));
    });

  }catch(_){
    notify(
      'Não foi possível carregar colaboradores.'
    );
  }
}

async function openAudit(){
  openDialog('Auditoria');

  try{
    const data=await jsonFetch(
      `${api}?action=audit`
    );

    const rows=Array.isArray(data.audit)
      ? data.audit
      : [];

    const list=document.createElement('div');
    list.className='dlab-audit-list';

    if(!rows.length){
      const empty=document.createElement('div');
      empty.className='dlab-empty';
      empty.textContent='Nenhum registro.';
      list.append(empty);
    }

    rows.forEach(x=>{
      const row=document.createElement('div');
      row.className='dlab-audit-row';

      const action=document.createElement('strong');
      action.textContent=x.action||'—';

      const meta=document.createElement('span');
      meta.textContent=
        `${x.ts||''} • ${x.actor_callsign||''}`+
        `${x.target_callsign?' → '+x.target_callsign:''}`;

      row.append(action,meta);
      list.append(row);
    });

    dialogBody.append(list);

  }catch(_){
    notify('Não foi possível carregar auditoria.');
  }
}

function openMyPassword(){
  openDialog('Trocar minha senha');

  const text=document.createElement('p');
  text.className='dlab-dialog-text';
  text.textContent=
    'Informe sua senha atual. O sistema gerará automaticamente uma nova senha e invalidará a anterior.';

  const formEl=document.createElement('form');
  formEl.className='dlab-dialog-form';

  const current=createField(
    'Senha atual',
    'password'
  );

  const submit=document.createElement('button');
  submit.type='submit';
  submit.className='dlab-btn dlab-btn-primary';
  submit.textContent='Gerar nova senha';

  formEl.append(
    current.wrap,
    submit
  );

  formEl.addEventListener('submit',async ev=>{
    ev.preventDefault();

    try{
      const data=await post(
        'self_rotate_password',
        {
          current_password:current.input.value
        }
      );

      showCredential(
        data.callsign,
        data.password,
        'Nova senha'
      );

    }catch(_){
      notify('Senha atual incorreta.');
    }
  });

  dialogBody.append(text,formEl);
}

function openSetBirth(){
  openDialog('Completar aniversário');

  const text=document.createElement('p');
  text.className='dlab-dialog-text';
  text.textContent=
    'Informe seu dia e mês reais. Não pedimos o ano. Esses dados serão usados para auxiliar na recuperação da senha.';

  const birth=createBirthFields();

  const submit=document.createElement('button');
  submit.type='button';
  submit.className='dlab-btn dlab-btn-primary';
  submit.textContent='Salvar aniversário';

  submit.addEventListener('click',async()=>{
    try{
      await post(
        'set_birth',
        {
          birth_day:Number(birth.day.value),
          birth_month:Number(birth.month.value)
        }
      );

      notify('Aniversário cadastrado.');
      dialog.close();
      await refresh();

    }catch(_){
      notify(
        'Informe um dia e mês válidos.'
      );
    }
  });

  dialogBody.append(
    text,
    birth.row,
    submit
  );
}

loginForm?.addEventListener('submit',async ev=>{
  ev.preventDefault();

  void ensureAudio();

  const call=cleanBaseCall(
    loginCall.value
  );

  loginCall.value=call;

  if(!CALL.test(call)){
    notify('Informe um indicativo válido.');
    return;
  }

  try{
    const data=await jsonFetch(api,{
      method:'POST',
      headers:{
        'Content-Type':'application/json',
        'Accept':'application/json'
      },
      body:JSON.stringify({
        action:'login',
        callsign:call,
        password:String(password.value||''),
        remember:Boolean(remember.checked)
      })
    });

    password.value='';
    csrf=String(data.csrf||'');

    notify('Acesso realizado.');

    await refresh();

  }catch(err){
    notify(
      err?.data?.error==='rate_limited'
        ? 'Muitas tentativas. Aguarde alguns minutos.'
        : 'Indicativo ou senha inválidos.'
    );
  }
});

registerForm?.addEventListener(
  'submit',
  async ev=>{
    ev.preventDefault();

    const call=cleanBaseCall(
      registerCall.value
    );

    registerCall.value=call;

    if(!CALL.test(call)){
      notify('Informe um indicativo válido.');
      return;
    }

    try{
      const data=await jsonFetch(api,{
        method:'POST',
        headers:{
          'Content-Type':'application/json',
          'Accept':'application/json'
        },
        body:JSON.stringify({
          action:'register',
          callsign:call,
          birth_day:Number(birthDay.value),
          birth_month:Number(birthMonth.value),
          birthday_consent:Boolean(
            birthdayConsent.checked
          )
        })
      });

      showCredential(
        data.callsign,
        data.password,
        'Acesso criado'
      );

    }catch(err){
      const code=err?.data?.error;

      const labels={
        not_recently_seen:
          'Indicativo ainda não foi identificado. Faça um beacon D-PRS no módulo B ou envie uma mensagem APRS para indicativo APRS configurado e tente novamente.',
        account_exists:
          'Este indicativo já possui cadastro.',
        invalid_birthday:
          'Informe seu dia e mês reais corretamente.',
        birthday_consent_required:
          'Confirme a autorização de uso do dia e mês.',
        rate_limited:
          'Muitas tentativas de cadastro. Aguarde.'
      };

      notify(
        labels[code]||
        'Não foi possível criar o acesso.'
      );
    }
  }
);

logout?.addEventListener('click',async()=>{
  try{
    await post('logout');
  }catch(_){}

  setLoggedOut();
  notify('Acesso encerrado.');
});

dest?.addEventListener('input',()=>{
  dest.value=cleanAprsCall(dest.value);
});

message?.addEventListener('input',()=>{
  count.textContent=String(
    message.value.length
  );
});

form?.addEventListener('submit',async ev=>{
  ev.preventDefault();

  if(!permissions.send_aprs){
    notify('Seu nível não permite transmissão APRS pelo painel.');
    return;
  }

  const to=cleanAprsCall(dest.value);
  const text=String(message.value||'').trim();

  if(!APRS_CALL.test(to)){
    notify('Destinatário APRS inválido.');
    return;
  }

  if(
    !text ||
    text.length>60 ||
    /[^\x20-\x7E]/.test(text) ||
    /[{}]/.test(text)
  ){
    notify(
      'Use de 1 a 60 caracteres APRS sem acentos.'
    );
    return;
  }

  send.disabled=true;

  try{
    const data=await post(
      'send',
      {
        dest:to,
        message:text
      }
    );

    message.value='';
    count.textContent='0';

    notify(
      `Mensagem enviada para ${to}. ID ${data.msg_id} — aguardando ACK.`
    );

    await refresh();

  }catch(err){
    notify(
      err?.data?.error==='rate_limited'
        ? 'Aguarde antes de enviar outra mensagem.'
        : 'Não foi possível enviar a mensagem.'
    );

    await refresh();
  }
});

usersBtn?.addEventListener(
  'click',
  ()=>void openUsers()
);

resetBtn?.addEventListener(
  'click',
  ()=>void openReset()
);

collaboratorsBtn?.addEventListener(
  'click',
  ()=>void openCollaborators()
);

auditBtn?.addEventListener(
  'click',
  ()=>void openAudit()
);

myPasswordBtn?.addEventListener(
  'click',
  openMyPassword
);

setBirthBtn?.addEventListener(
  'click',
  openSetBirth
);

dialogClose?.addEventListener(
  'click',
  ()=>dialog.close()
);

dialog?.addEventListener('click',ev=>{
  if(ev.target===dialog){
    dialog.close();
  }
});

soundToggle?.addEventListener('click',()=>{
  soundEnabled=!soundEnabled;
  saveSoundPref();
  updateSoundButton();

  if(soundEnabled){
    void ensureAudio();
    notify('Som ativado.');
  }else{
    notify('Som desativado.');
  }
});

document.querySelectorAll(
  '.dlab-command-action'
).forEach(btn=>{
  btn.addEventListener('click',()=>{
    const command=String(
      btn.dataset.command||''
    ).trim();

    if(!command)return;

    if(
      !account ||
      !permissions.send_aprs ||
      !form ||
      form.hidden
    ){
      notify(
        `Para usar ${command}, envie esse texto pelo seu rádio ou aplicativo APRS para indicativo APRS configurado.`
      );
      return;
    }

    message.value=command;
    count.textContent=String(
      command.length
    );

    form.scrollIntoView({
      behavior:'smooth',
      block:'center'
    });

    window.setTimeout(()=>{
      message.focus();

      if(command.startsWith('LAST ')){
        try{
          message.setSelectionRange(
            5,
            message.value.length
          );
        }catch(_){}
      }
    },300);

    notify(
      `${command} colocado no campo Mensagem. Escolha o destinatário APRS e envie.`
    );
  });
});


// Em Estações recentes:
// clique especificamente no indicativo prepara resposta.
// Clique no restante do card continua abrindo o mapa.
root.addEventListener(
  'click',
  event=>{
    if(
      !account ||
      !permissions.send_aprs
    ){
      return;
    }

    const callElement=
      event.target.closest(
        '.dlab-station-call strong'
      );

    if(!callElement)return;

    event.preventDefault();
    event.stopPropagation();

    prepareAprsReply(
      callElement.textContent
    );
  },
  true
);

root.addEventListener(
  'pointerdown',
  ()=>{
    if(soundEnabled){
      void ensureAudio();
    }
  },
  {once:true}
);

document.addEventListener(
  'visibilitychange',
  ()=>{
    if(!document.hidden){
      unread=0;
      updateUnread();
    }
  }
);

updateSoundButton();
updateUnread();
setLoggedOut();

refresh();

timer=setInterval(
  refresh,
  5000
);

window.addEventListener(
  'beforeunload',
  ()=>clearInterval(timer),
  {once:true}
);

})();
