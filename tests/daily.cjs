const {chromium,webkit}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),http=require('node:http');
let available=true, requests=0;
const fixture=date=>({schemaVersion:1,date,reference:'約翰福音 3:11–4:2',title:'今日經文',verses:[{id:'JHN.3.11',book:'約翰福音',chapter:3,verse:11,reference:'約翰福音 3:11',text:'第一節測試經文。'},{id:'JHN.4.2',book:'約翰福音',chapter:4,verse:2,reference:'約翰福音 4:2',text:'第二節測試經文。'}]});
const server=http.createServer((req,res)=>{
  if(req.url.startsWith('/data/')){
    requests++;res.setHeader('Content-Type','application/json');
    if(!available){res.statusCode=404;return res.end('{}')}
    return res.end(JSON.stringify(fixture(req.url.includes('2026-11-18')?'2026-11-18':'2026-11-17')));
  }
  res.setHeader('Content-Type','text/html; charset=utf-8');res.end(fs.readFileSync(path.join(__dirname,'..','index.html')));
});
function initialize({now,legacy}){
  const NativeDate=Date;window.testNow=sessionStorage.getItem('testNow')||now;
  window.Date=class extends NativeDate{constructor(...a){super(...(a.length?a:[window.testNow]))}static now(){return new NativeDate(window.testNow).getTime()}};
  if(!localStorage.getItem('devotion-v04'))localStorage.setItem('devotion-v04',JSON.stringify(legacy?{name:'測試',fullMarks:{'2026-11-17':{'2':'green'}},highlights:{'2026-11-17':{'2':[{start:0,end:3,color:'pink'}]}},notes:[{id:'old',date:'2026-11-17',verse:2,text:'舊筆記',private:true}]}:{name:'測試'}));
}
const saved=page=>page.evaluate(()=>JSON.parse(localStorage.getItem('devotion-v04')));
(async()=>{
  await new Promise(r=>server.listen(0,'127.0.0.1',r));const url='http://127.0.0.1:'+server.address().port;
  for(const [name,engine] of [['chromium',chromium],['webkit',webkit]]){
    const browser=await engine.launch();
    try{
      available=true;
      const context=await browser.newContext();await context.addInitScript(initialize,{now:'2026-11-17T04:00:00Z',legacy:true});
      const page=await context.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));
      await page.goto(url);await page.waitForFunction(()=>document.querySelector('#verse-1 .vnum').textContent==='3:11');
      assert.equal(await page.locator('#verse-2 .vnum').innerText(),'4:2');
      assert.match(await page.locator('#verse-2').getAttribute('aria-label'),/4:2/);
      assert.equal(await page.locator('#verse-2 mark').count(),0,'legacy marks must not attach to new text');
      assert.match((await saved(page)).readings['2026-11-17'].verses[1].text,/什麼/);
      // A changed publication for an already saved date cannot move saved offsets.
      const changed=fixture('2026-11-17');changed.verses[0].text='改版文字不可覆蓋原快照。';
      await page.route('**/data/**',route=>route.fulfill({json:changed}));await page.locator('#retryReading').click();
      await page.waitForFunction(()=>document.querySelector('#readingStatus').textContent.includes('已儲存版本不同'));
      assert.equal((await saved(page)).readings['2026-11-17~daily'].verses[0].text,'第一節測試經文。');
      assert.equal(await page.locator('#verse-1 .vtext').innerText(),'第一節測試經文。');
      await page.unroute('**/data/**');
      const count=requests;
      await page.locator('#verse-1').click();await page.getByRole('button',{name:'寫筆記',exact:true}).click();
      assert.equal(await page.locator('#modalTitle').innerText(),'約翰福音 3:11');
      await page.locator('#noteInput').fill('跨午夜草稿');
      await page.evaluate(()=>{window.testNow='2026-11-17T16:01:00Z';window.dispatchEvent(new Event('focus'));});
      await page.waitForFunction(()=>!document.querySelector('#loadReading').classList.contains('hidden'));
      assert.equal(await page.locator('#verse-1 .vnum').innerText(),'3:11');
      assert.match(await page.locator('#readingStatus').innerText(),/2026-11-17/);
      await page.locator('#saveNote').click();
      assert.equal((await saved(page)).notes[0].date,'2026-11-17');
      assert.equal((await saved(page)).notes[0].reference,'約翰福音 3:11');
      await page.locator('#loadReading').click();
      await page.waitForFunction(()=>document.querySelector('#readingStatus').textContent.startsWith('今日經文 · 2026-11-18'));
      await page.locator('#checkBtn').click();assert.equal((await saved(page)).checkins['2026-11-18'],true);
      assert(requests>count);const after=requests;
      await page.locator('#verse-1').click();await page.getByRole('button',{name:'黃色重點',exact:true}).click();
      assert.equal(requests,after,'annotation clicks must not fetch');
      // A historical note must reopen its own original text and original marks.
      await page.locator('.navbar [data-tab="history"]').click();await page.locator('[data-date="2026-11-17"]').click();
      assert.match(await page.locator('#historyDetails').innerText(),/原示範經文/);
      assert.match(await page.locator('#historyDetails .history-mark-text').first().innerText(),/什麼/);
      await page.locator('#historyDetails [data-reading="2026-11-17"]').click();
      assert.equal(await page.locator('#verse-2 .vnum').innerText(),'2');
      assert.match(await page.locator('#verse-2 mark').innerText(),/什麼/);
      await page.locator('.navbar [data-tab="history"]').click();await page.locator('[data-date="2026-11-18"]').click();
      await page.locator('[data-open-reading="2026-11-18"]').click();
      // Offline reload and next-day checkin remain bound to the saved reading's true date.
      available=false;await page.evaluate(()=>sessionStorage.setItem('testNow',window.testNow));await page.reload();
      await page.waitForFunction(()=>document.querySelector('#readingStatus').textContent.includes('目前無法取得'));
      assert.match(await page.locator('#readingStatus').innerText(),/2026-11-18/);
      assert.equal(await page.locator('#verse-1 mark').innerText(),'第一節測試經文。');
      await page.evaluate(()=>{window.testNow='2026-11-18T16:01:00Z';window.dispatchEvent(new Event('focus'));});
      await page.waitForFunction(()=>TODAY==='2026-11-19');
      assert.equal(await page.locator('#todayDate').getAttribute('datetime'),'2026-11-18','offline saved reading retains its actual date');
      assert(!((await page.locator('#todayDate').innerText()).includes('今天')));
      await page.locator('#checkBtn').click();assert.equal((await saved(page)).checkins['2026-11-19'],undefined);
      assert.deepEqual(Object.keys((await saved(page)).readings).sort(),['2026-11-17','2026-11-17~daily','2026-11-18']);
      assert.deepEqual(errors,[]);await context.close();
      // A late response must preserve both scroll position and a live verse selection.
      const delayed=await browser.newContext({viewport:{width:390,height:664}});await delayed.addInitScript(initialize,{now:'2026-11-18T04:00:00Z',legacy:false});
      const second=await delayed.newPage();let release;const held=new Promise(r=>release=r);
      await second.route('**/data/**',async route=>{await held;await route.fulfill({json:fixture('2026-11-18')})});
      await second.goto(url);await second.locator('#verse-10').click();
      const before=await second.evaluate(()=>({scroll:document.querySelector('main').scrollTop,text:document.querySelector('#verses').textContent,selected:document.querySelector('.verse[aria-pressed="true"]').id}));
      release();await second.waitForFunction(()=>document.querySelector('#readingStatus').textContent.includes('新經文已備妥'));
      assert.equal(await second.locator('#loadReading').isVisible(),false,'pending update must not cover annotation tools');
      const afterResponse=await second.evaluate(()=>({scroll:document.querySelector('main').scrollTop,text:document.querySelector('#verses').textContent,selected:document.querySelector('.verse[aria-pressed="true"]').id}));
      assert.deepEqual(afterResponse,before,'a delayed response must not move or replace an active reading');
      await second.getByRole('button',{name:'粉色重點',exact:true}).click();
      assert.equal((await saved(second)).fullMarks['2026-11-17']['10'],'pink');
      assert.equal((await saved(second)).fullMarks['2026-11-18'],undefined);
      await second.locator('#selectionCancel').click();
      await second.locator('#loadReading').click();assert.equal(await second.locator('#verse-1 .vnum').innerText(),'3:11');
      await delayed.close();
      // Invalid and future dated records never replace the last readable snapshot.
      for(const bad of [fixture('2099-01-01'),{...fixture('2026-11-18'),verses:[{text:'<img onerror="alert(1)">'}]}, {...fixture('2026-11-18'),date:'2026-02-30'}]){
        const invalid=await browser.newContext();await invalid.addInitScript(initialize,{now:'2026-11-18T04:00:00Z',legacy:false});const third=await invalid.newPage();
        await third.route('**/data/**',route=>route.fulfill({json:bad}));await third.goto(url);
        await third.waitForFunction(()=>document.querySelector('#readingStatus').textContent.includes('目前無法取得'));
        assert.match(await third.locator('#readingStatus').innerText(),/原示範經文/);
        assert.deepEqual(Object.keys((await saved(third)).readings),['2026-11-17']);await invalid.close();
      }
      const stale=await browser.newContext();await stale.addInitScript(initialize,{now:'2026-11-18T04:00:00Z',legacy:false});const fourth=await stale.newPage();
      await fourth.route('**/data/**',route=>route.request().url().endsWith('/latest.json')?route.fulfill({json:fixture('2026-11-17')}):route.fulfill({status:404,json:{}}));
      await fourth.goto(url);await fourth.waitForFunction(()=>document.querySelector('#verse-1 .vnum').textContent==='3:11');
      assert.match(await fourth.locator('#readingStatus').innerText(),/目前閱讀 · 2026-11-17/);await fourth.locator('#checkBtn').click();assert.equal((await saved(fourth)).checkins['2026-11-18'],undefined);assert.equal((await saved(fourth)).checkins['2026-11-17~daily'],true);await stale.close();
      console.log('PASS '+name+': daily fetch, real verse references, legacy isolation/history jump, frozen midnight draft, deferred loading/scroll, actual-date checkin/marks, cache, invalid/future rejection, no click fetch');
    }finally{await browser.close()}
  }
})().catch(e=>{console.error(e);process.exitCode=1}).finally(()=>server.close());
