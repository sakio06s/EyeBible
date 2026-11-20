/* Authenticated problem reports. Recipient and mail credentials remain server-only. */
'use strict';
const AUTH_URL=process.env.SUPABASE_URL||'https://mddbzoagloktnwoszuvj.supabase.co',PUBLIC_KEY=process.env.SUPABASE_PUBLISHABLE_KEY||'sb_publishable_XjntXt30I6CC7DIES89Y8A_Db-K47qN';
const UUID=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i,EMAIL=/^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$/;
const windows=new Map(),WINDOW=10*60*1000;
function allow(user,id){const now=Date.now();for(const [key,value] of windows)if(now-value.start>WINDOW)windows.delete(key);let state=windows.get(user);if(!state){if(windows.size>=5000)windows.delete(windows.keys().next().value);state={start:now,ids:new Set()};windows.set(user,state)}if(state.ids.has(id))return true;if(state.ids.size>=5)return false;state.ids.add(id);return true}
module.exports=async function feedback(req,res){res.setHeader('Cache-Control','no-store');const fail=(status,error)=>res.status(status).json({error});if(req.method!=='POST'){res.setHeader('Allow','POST');return fail(405,'只接受送出回報。')}
 const auth=req.headers?.authorization;if(typeof auth!=='string'||!/^Bearer [^\s]{1,8192}$/.test(auth))return fail(401,'請先登入後再送出回報。');
 const origin=req.headers?.origin;if(origin){try{const url=new URL(origin);if(url.host!==req.headers.host||!['https:','http:'].includes(url.protocol))return fail(403,'無法從這個網頁送出回報。')}catch(_){return fail(403,'無法從這個網頁送出回報。')}}
 let body=req.body;try{if(typeof body==='string'){if(Buffer.byteLength(body)>16384)return fail(413,'回報內容太長，請縮短後再試。');body=JSON.parse(body)}if(!body||Array.isArray(body)||typeof body!=='object'||Buffer.byteLength(JSON.stringify(body))>16384||typeof body.id!=='string'||!UUID.test(body.id)||typeof body.text!=='string'||!body.text.trim()||body.text.length>2000)return fail(400,'請輸入2000字以內的問題或建議。')}catch(_){return fail(400,'回報格式不正確，請重新輸入。')}
 const to=process.env.REPORT_TO_EMAIL,key=process.env.RESEND_API_KEY,from=process.env.REPORT_FROM_EMAIL||'EyeBible <onboarding@resend.dev>';
 if(!key||!to||to.length>254||!EMAIL.test(to)||!PUBLIC_KEY)return fail(503,'回報功能尚未啟用，請稍後再試。');
 try{const verified=await fetch(AUTH_URL.replace(/\/$/,'')+'/auth/v1/user',{headers:{apikey:PUBLIC_KEY,Authorization:auth},signal:AbortSignal.timeout(8000)});if(verified.status===401||verified.status===403)return fail(401,'登入已過期，請重新登入後送出回報。');if(!verified.ok)return fail(503,'暫時無法確認登入，內容已保留，請稍後重試。');const user=await verified.json();if(typeof user?.id!=='string'||!UUID.test(user.id))return fail(401,'請先登入後再送出回報。');if(!allow(user.id,body.id)){res.setHeader('Retry-After','600');return fail(429,'回報次數較多，請稍後再送出。')}
  const name=typeof body.name==='string'?body.name.replace(/[\r\n\u2028\u2029]+/g,' ').trim().slice(0,60):'組員',reply=typeof user.email==='string'&&user.email.length<=254&&EMAIL.test(user.email)?user.email:null;
  // Keep payload stable across retries so the provider can deduplicate uncertain sends.
  const message={from,to:[to],subject:'EyeBible｜問題回報',text:'回報者：'+(name||'組員')+'\n帳號：'+user.id+'\n'+(reply?'聯絡Email：'+reply+'\n':'')+'\n'+body.text.trim(),...(reply?{reply_to:reply}:{})};
  const sent=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:'Bearer '+key,'Content-Type':'application/json','Idempotency-Key':'eyebible-feedback/'+user.id+'/'+body.id},body:JSON.stringify(message),signal:AbortSignal.timeout(10000)});if(!sent.ok)return fail(503,'暫時無法確認是否送出，內容已保留，請重試。');const receipt=await sent.json();if(typeof receipt.id!=='string')return fail(503,'暫時無法確認是否送出，內容已保留，請重試。');return res.status(200).json({ok:true});
 }catch(_){return fail(503,'暫時無法確認是否送出，內容已保留，請重試。')}
};
