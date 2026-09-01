(function(){
 'use strict';

 if(window.__XLX026_A11Y_LIGHT_V5E__){
  return;
 }

 window.__XLX026_A11Y_LIGHT_V5E__=true;

 var panel=null;
 var fontSteps=[90,100,110,125,150,175,200];


 function read(key,fallback){
  try{
   var value=localStorage.getItem(key);

   if(value===null){
    return fallback;
   }

   return value!=='disabled';

  }catch(error){
   return fallback;
  }
 }


 function save(key,value){
  try{
   localStorage.setItem(
    key,
    value?'enabled':'disabled'
   );
  }catch(error){}
 }


 function readFont(){
  try{
   var n=parseInt(
    localStorage.getItem(
     'xlx026A11yFontV5E'
    ),
    10
   );

   if(fontSteps.indexOf(n)!==-1){
    return n;
   }
  }catch(error){}

  return 100;
 }


 function applyFont(value){

  document.documentElement.style.fontSize=
   String(value)+'%';

  try{
   localStorage.setItem(
    'xlx026A11yFontV5E',
    String(value)
   );
  }catch(error){}

  var label=
   document.getElementById(
    'xlxA11yFontValueV5E'
   );

  if(label){
   label.textContent=
    String(value)+'%';
  }
 }


 function hasClass(element,name){

  if(!element||element.nodeType!==1){
   return false;
  }

  if(element.classList){
   return element.classList.contains(name);
  }

  return (
   (' '+element.className+' ')
    .indexOf(' '+name+' ')!==-1
  );
 }


 function findTrigger(node){

  while(node&&node!==document){

   if(
    hasClass(node,'xlx-a11y-menu-icon') ||
    hasClass(node,'xlx-a11y-mobile-icon')
   ){
    return node;
   }

   node=node.parentNode;
  }

  return null;
 }


 function setClass(name,enabled){

  var root=document.documentElement;

  if(root.classList){

   if(enabled){
    root.classList.add(name);
   }else{
    root.classList.remove(name);
   }

   return;
  }
 }


 function setPressed(id,value){

  var el=document.getElementById(id);

  if(el){
   el.setAttribute(
    'aria-pressed',
    value?'true':'false'
   );
  }
 }


 function audioState(){

  if(
   window.XLX026AudioControl &&
   typeof
   window.XLX026AudioControl.state
   ==='function'
  ){
   try{
    return window.XLX026AudioControl.state();
   }catch(error){}
  }

  return {
   master:read(
    'xlx026PanelAudio',
    true
   ),
   voice:read(
    'xlx026ConnectedVoice',
    true
   ),
   beeps:read(
    'xlx026TxBeeps',
    true
   )
  };
 }


 function syncAudio(){

  var state=audioState();

  setPressed(
   'xlxA11yMasterV5E',
   state.master
  );

  setPressed(
   'xlxA11yVoiceV5E',
   state.voice
  );

  setPressed(
   'xlxA11yBeepsV5E',
   state.beeps
  );
 }


 function option(id,text){

  var button=
   document.createElement('button');

  button.type='button';
  button.id=id;
  button.className='xlx-a11y-option';

  button.setAttribute(
   'aria-pressed',
   'false'
  );

  button.appendChild(
   document.createTextNode(text)
  );

  return button;
 }


 function bindVisual(
  button,
  storage,
  className,
  fallback
 ){

  var state=read(
   storage,
   fallback
  );

  setClass(
   className,
   state
  );

  button.setAttribute(
   'aria-pressed',
   state?'true':'false'
  );

  button.onclick=function(){

   state=!state;

   save(storage,state);

   setClass(
    className,
    state
   );

   button.setAttribute(
    'aria-pressed',
    state?'true':'false'
   );
  };
 }


 function createPanel(){

  if(panel){
   return panel;
  }


  panel=document.createElement('div');

  panel.id='xlxA11yV5E';
  panel.hidden=true;

  panel.setAttribute(
   'role',
   'dialog'
  );

  panel.setAttribute(
   'aria-label',
   'Acessibilidade'
  );


  var head=document.createElement('div');

  head.className='xlx-a11y-head';


  var title=document.createElement('strong');

  title.appendChild(
   document.createTextNode(
    '♿ Acessibilidade'
   )
  );


  var close=document.createElement('button');

  close.type='button';
  close.id='xlxA11yCloseV5E';

  close.setAttribute(
   'aria-label',
   'Fechar acessibilidade'
  );

  close.appendChild(
   document.createTextNode('×')
  );

  head.appendChild(title);
  head.appendChild(close);


  var body=document.createElement('div');

  body.className='xlx-a11y-body';


  if(
   window.XLX026AudioControl
  ){

   var audioTitle=
    document.createElement('span');

   audioTitle.className='xlx-a11y-title';

   audioTitle.appendChild(
    document.createTextNode(
     'Áudio do painel'
    )
   );


   var note=document.createElement('p');

   note.className='xlx-a11y-note';

   note.appendChild(
    document.createTextNode(
     'O controle geral interrompe fala e bips internamente.'
    )
   );


   var master=option(
    'xlxA11yMasterV5E',
    '🔊 Som do painel'
   );

   var voice=option(
    'xlxA11yVoiceV5E',
    '🗣 Fala da quantidade de conectados'
   );

   var beeps=option(
    'xlxA11yBeepsV5E',
    '🔔 Bips de transmissão'
   );


   var test=
    document.createElement('button');

   test.type='button';
   test.className='xlx-a11y-action';

   test.appendChild(
    document.createTextNode(
     '🔊 Testar bip'
    )
   );


   body.appendChild(audioTitle);
   body.appendChild(note);
   body.appendChild(master);
   body.appendChild(voice);
   body.appendChild(beeps);
   body.appendChild(test);


   master.onclick=function(){

    var next=
     master.getAttribute(
      'aria-pressed'
     )!=='true';

    save(
     'xlx026PanelAudio',
     next
    );

    try{
     window.XLX026AudioControl
      .setMaster(next);
    }catch(error){}

    syncAudio();
   };


   voice.onclick=function(){

    var next=
     voice.getAttribute(
      'aria-pressed'
     )!=='true';

    save(
     'xlx026ConnectedVoice',
     next
    );

    try{
     window.XLX026AudioControl
      .setVoice(next);
    }catch(error){}

    syncAudio();
   };


   beeps.onclick=function(){

    var next=
     beeps.getAttribute(
      'aria-pressed'
     )!=='true';

    save(
     'xlx026TxBeeps',
     next
    );

    try{
     window.XLX026AudioControl
      .setBeeps(next);
    }catch(error){}

    syncAudio();
   };


   test.onclick=function(){

    try{
     window.XLX026AudioControl
      .testBeep();
    }catch(error){}
   };
  }


  var visualTitle=
   document.createElement('span');

  visualTitle.className='xlx-a11y-title';

  visualTitle.appendChild(
   document.createTextNode(
    'Visual e navegação'
   )
  );

  body.appendChild(visualTitle);


  var fontLabel=
   document.createElement('span');

  fontLabel.className='xlx-a11y-note';

  fontLabel.appendChild(
   document.createTextNode(
    'Tamanho do texto'
   )
  );

  body.appendChild(fontLabel);


  var fontRow=
   document.createElement('div');

  fontRow.className='xlx-a11y-font-row';


  var fontMinus=
   document.createElement('button');

  fontMinus.type='button';
  fontMinus.textContent='A−';


  var fontValue=
   document.createElement('span');

  fontValue.id='xlxA11yFontValueV5E';


  var fontPlus=
   document.createElement('button');

  fontPlus.type='button';
  fontPlus.textContent='A+';


  fontRow.appendChild(fontMinus);
  fontRow.appendChild(fontValue);
  fontRow.appendChild(fontPlus);

  body.appendChild(fontRow);


  var contrast=option(
   'xlxA11yContrastV5E',
   '◐ Alto contraste'
  );

  var links=option(
   'xlxA11yLinksV5E',
   '🔗 Destacar links'
  );

  var controls=option(
   'xlxA11yControlsV5E',
   '▣ Controles maiores'
  );

  var motion=option(
   'xlxA11yMotionV5E',
   '◼ Reduzir animações'
  );

  var focus=option(
   'xlxA11yFocusV5E',
   '⌨ Foco de teclado'
  );


  body.appendChild(contrast);
  body.appendChild(links);
  body.appendChild(controls);
  body.appendChild(motion);
  body.appendChild(focus);


  var reset=
   document.createElement('button');

  reset.type='button';
  reset.className='xlx-a11y-action';

  reset.appendChild(
   document.createTextNode(
    '↺ Restaurar acessibilidade'
   )
  );

  body.appendChild(reset);


  bindVisual(
   contrast,
   'xlx026A11yContrastV5E',
   'xlx-a11y-contrast',
   false
  );

  bindVisual(
   links,
   'xlx026A11yLinksV5E',
   'xlx-a11y-links',
   false
  );

  bindVisual(
   controls,
   'xlx026A11yControlsV5E',
   'xlx-a11y-controls',
   false
  );

  bindVisual(
   motion,
   'xlx026A11yMotionV5E',
   'xlx-a11y-motion',
   false
  );

  bindVisual(
   focus,
   'xlx026A11yFocusV5E',
   'xlx-a11y-focus',
   true
  );


  function changeFont(direction){

   var current=readFont();
   var index=fontSteps.indexOf(current);

   if(index<0){
    index=1;
   }

   index+=direction;

   if(index<0){
    index=0;
   }

   if(index>=fontSteps.length){
    index=fontSteps.length-1;
   }

   applyFont(
    fontSteps[index]
   );
  }


  fontMinus.onclick=function(){
   changeFont(-1);
  };

  fontPlus.onclick=function(){
   changeFont(1);
  };


  reset.onclick=function(){

   [
    'xlx026A11yContrastV5E',
    'xlx026A11yLinksV5E',
    'xlx026A11yControlsV5E',
    'xlx026A11yMotionV5E'
   ].forEach(
    function(key){
     save(key,false);
    }
   );

   save(
    'xlx026A11yFocusV5E',
    true
   );

   setClass(
    'xlx-a11y-contrast',
    false
   );

   setClass(
    'xlx-a11y-links',
    false
   );

   setClass(
    'xlx-a11y-controls',
    false
   );

   setClass(
    'xlx-a11y-motion',
    false
   );

   setClass(
    'xlx-a11y-focus',
    true
   );

   setPressed(
    'xlxA11yContrastV5E',
    false
   );

   setPressed(
    'xlxA11yLinksV5E',
    false
   );

   setPressed(
    'xlxA11yControlsV5E',
    false
   );

   setPressed(
    'xlxA11yMotionV5E',
    false
   );

   setPressed(
    'xlxA11yFocusV5E',
    true
   );

   applyFont(100);
  };


  panel.appendChild(head);
  panel.appendChild(body);

  document.body.appendChild(panel);


  close.onclick=function(){
   panel.hidden=true;
  };


  applyFont(
   readFont()
  );

  syncAudio();

  return panel;
 }


 function openPanel(){

  var p=createPanel();

  p.hidden=false;

  syncAudio();

  try{
   document
    .getElementById(
     'xlxA11yCloseV5E'
    )
    .focus();
  }catch(error){}
 }


 document.addEventListener(
  'click',
  function(event){

   var trigger=
    findTrigger(event.target);

   if(!trigger){
    return;
   }

   if(event.preventDefault){
    event.preventDefault();
   }

   if(event.stopPropagation){
    event.stopPropagation();
   }

   openPanel();
  },
  false
 );


 document.addEventListener(
  'keydown',
  function(event){

   var key=event.key||'';

   if(
    event.altKey &&
    (
     String(key).toLowerCase()==='a' ||
     event.keyCode===65
    )
   ){
    if(event.preventDefault){
     event.preventDefault();
    }

    openPanel();
   }

   if(
    (
     key==='Escape' ||
     event.keyCode===27
    ) &&
    panel &&
    !panel.hidden
   ){
    panel.hidden=true;
   }
  },
  false
 );


 applyFont(
  readFont()
 );

}());
