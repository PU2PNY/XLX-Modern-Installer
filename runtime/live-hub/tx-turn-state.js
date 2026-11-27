'use strict';
const fs=require('fs');
function readTurnWait(dir='/run/xlx-tx-turn-state',now=Number(process.hrtime.bigint()/1000000n)){
 const result=[];
 for(const module of 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'){
  const path=dir+'/module-'+module+'.json';
  try{
   const stat=fs.statSync(path);
   if(!stat.isFile()||stat.size<2||stat.size>2048)continue;
   const x=JSON.parse(fs.readFileSync(path,'utf8'));
   if(x.module!==module||!Array.isArray(x.callsigns))continue;
   const callsigns=x.callsigns.slice(0,2).filter(s=>typeof s==='string'&&/^[A-Z0-9/:.-]{1,24}$/.test(s));
   const until=Number(x.until_ms);
   const remaining=until-now;
   if(callsigns.length!==2||!Number.isFinite(remaining)||remaining<=0||remaining>7000)continue;
   result.push({module,callsigns,until_ms:until,remaining_ms:Math.min(7000,Math.ceil(remaining))});
  }catch(_){}
 }
 return result;
}
module.exports={readTurnWait};
