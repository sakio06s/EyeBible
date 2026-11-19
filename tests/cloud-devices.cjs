// Independent browser storage contexts share only a simulated cloud API.
// Uses the shipped SDK and real app interactions; never connects to live accounts.
const {chromium,webkit}=require('playwright');
const assert=require('node:assert/strict'),fs=require('node:fs'),http=require('node:http'),path=require('node:path');
const root=path.join(__dirname,'..'),fixture=JSON.parse(fs.readFileSync(path.join(root,'data/latest.json')));
const A='00000000-0000-0000-0000-000000000001',B='00000000-0000-0000-0000-000000000002';
const key=(...p)=>JSON.stringify(p),rows={};
for(const [id,name] of [[A,'恩恩'],[B,'另一帳號']])rows[id]={revision:1,payload:{schemaVersion:1,records:{[key('setting','name')]:name,[key('setting','userId')]:id}}};
const server=http.createServer((req,res)=>{
 const pathname=new URL(req.url,'http://localhost').pathname;
 if(pathname==='/cloud/config.js'){res.setHeader('Content-Type','text/javascript');return res.end('window.EYEBIBLE_CLOUD='+JSON.stringify({url:'https://devices-test.supabase.co',publishableKey:'sb_publishable_test',authMode:'google',groupsEnabled:true})+';')}
 if(pathname.startsWith('/data/')){res.setHeader('Content-Type','application/json');return res.end(JSON.stringify(fixture))}
 const file=pathname==='/'?'/index.html':pathname;
 if(!/^\/(index.html|assets\/eyebible.png|cloud\/[a-z0-9./-]+)$/.test(file)){res.statusCode=404;return res.end()}
 res.setHeader('Content-Type',file.endsWith('.js')?'text/javascript':file.endsWith('.png')?'image/png':'text/html;charset=utf-8');res.end(fs.readFileSync(path.join(root,file)));
});
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const origin='http://127.0.0.1:'+server.address().port;
 const browsers=[],contexts=[];
 try{
  async function device(type,id){
   const browser=await type.launch();browsers.push(browser);const context=await browser.newContext({viewport:{width:390,height:740}});contexts.push(context);
   await context.addInitScript(({id,date})=>{
    const NativeDate=Date;window.Date=class extends NativeDate{constructor(...args){super(...(args.length?args:[date+'T04:00:00Z']))}static now(){return new NativeDate(date+'T04:00:00Z').getTime()}};
    const enc=o=>btoa(JSON.stringify(o));const user={id,email:id+'@example.test',aud:'authenticated',app_metadata:{provider:'google'},user_metadata:{}};
    const access_token=enc({alg:'HS256',typ:'JWT'})+'.'+enc({sub:id,aud:'authenticated',role:'authenticated',exp:4000000000})+'.test';
    localStorage.setItem('eyebible.auth.v1',JSON.stringify({access_token,refresh_token:'test-refresh',expires_at:4000000000,expires_in:3600,token_type:'bearer',user}));
   },{id,date:fixture.date});
   await context.route('https://devices-test.supabase.co/**',async route=>{
    const req=route.request(),u=new URL(req.url()),headers={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'*','Access-Control-Allow-Methods':'GET,POST,OPTIONS'};
    if(req.method()==='OPTIONS')return route.fulfill({headers});
    const actor=JSON.parse(Buffer.from(req.headers().authorization.split('.')[1],'base64').toString()).sub;
    if(u.pathname.endsWith('/logout'))return route.fulfill({json:{},headers});
    assert(u.pathname.startsWith('/rest/'),'unexpected authentication request: '+u.pathname);
    if(u.pathname.endsWith('/rpc/group_read'))return route.fulfill({json:{group:null,members:[],posts:[],unread:0},headers});
    if(u.pathname.includes('/rpc/')){
     const data=req.postDataJSON(),row=rows[actor];
     if(data.p_expected_revision!==row.revision)return route.fulfill({status:409,json:{code:'40001'},headers});
     rows[actor]={revision:row.revision+1,payload:data.p_payload};return route.fulfill({json:rows[actor].revision,headers});
    }
    return route.fulfill({json:[rows[actor]],headers});
   });
   const page=await context.newPage();await page.goto(origin);await page.waitForFunction(()=>document.querySelector('#cloudStatus').textContent==='已同步到雲端');return page;
  }
  const first=await device(chromium,A);
  await first.locator('#verse-1').click();await first.locator('[data-color="yellow"]').click();await first.locator('#selectionCancel').click();
  await first.locator('#verse-1').click();await first.locator('#selectionNote').click();await first.locator('#noteInput').fill('跨瀏覽器私人筆記');await first.locator('#privateCheck').check();await first.locator('#saveNote').click();await first.locator('#checkBtn').click();
  await first.waitForFunction(()=>document.querySelector('#cloudStatus').textContent==='已同步到雲端');
  assert.deepEqual(await first.evaluate(()=>new Promise(resolve=>{let stop;stop=EyeBibleAccount.subscribe(v=>{resolve(v);setTimeout(()=>stop(),0)})})),{userId:A,ready:true});
  const second=await device(webkit,A);
  assert.equal(await second.evaluate(()=>state.fullMarks[readingKey][1]),'yellow');
  assert.equal(await second.evaluate(()=>state.checkins[readingKey]),true);
  assert.equal(await second.evaluate(()=>state.notes.find(n=>n.text==='跨瀏覽器私人筆記').private),true);
  assert.equal(await second.locator('#feed').innerText().then(t=>t.includes('跨瀏覽器私人筆記')),false);
  // Independent edits on both devices must survive the next pull/merge.
  await first.evaluate(()=>{state.fullMarks[readingKey][2]='pink';save()});
  await second.evaluate(()=>{state.notes.unshift({id:'webkit-note',authorId:state.userId,date:TODAY,text:'另一裝置新增的筆記',private:true});save()});
  await Promise.all([first,second].map(p=>p.waitForFunction(()=>document.querySelector('#cloudStatus').textContent==='已同步到雲端')));
  for(const page of [first,second]){await page.evaluate(()=>document.querySelector('#syncAccount').click());await page.waitForFunction(()=>state.fullMarks[readingKey]?.[2]==='pink'&&state.notes.some(n=>n.id==='webkit-note'))}
  const other=await device(chromium,B);
  assert.equal(await other.evaluate(()=>state.notes.some(n=>n.text==='跨瀏覽器私人筆記'||n.id==='webkit-note')),false);
  assert.equal(await other.evaluate(()=>Object.values(state.checkins).some(Boolean)),false);
  await first.evaluate(()=>document.querySelector('#logoutAccount').click());
  await first.waitForFunction(()=>!localStorage.getItem('eyebible.cloud.owner'));
  assert.equal(await first.evaluate(()=>state.notes.some(n=>n.text==='跨瀏覽器私人筆記')),false);
  console.log('PASS independent Chromium/WebKit devices: mark + private note + checkin roundtrip, concurrent independent edits, other-account exclusion, logout workspace cleanup');
 }finally{await Promise.all(contexts.map(c=>c.close()));await Promise.all(browsers.map(b=>b.close()))}
})().catch(e=>{console.error(e);process.exitCode=1}).finally(()=>server.close());
