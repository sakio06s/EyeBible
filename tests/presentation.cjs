const { chromium, webkit } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const server = http.createServer((req,res) => {
  if(req.url.startsWith('/data/')){const date=req.url.match(/(\d{4}-\d{2}-\d{2})/)?.[1]||'2027-01-02';res.setHeader('Content-Type','application/json');return res.end(JSON.stringify({schemaVersion:1,date,reference:'約翰福音 3:11',title:'今日經文',verses:[{id:'JHN.3.11',book:'約翰福音',chapter:3,verse:11,reference:'約翰福音 3:11',text:'我們所說的是我們知道的。'}]}))}
  res.setHeader('Content-Type','text/html; charset=utf-8');
  res.end(fs.readFileSync(path.join(__dirname,'..','index.html')));
});
(async()=>{
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  for(const [name,type] of [['chromium',chromium],['webkit',webkit]]) {
    const browser=await type.launch({headless:true});
    try {
      const context=await browser.newContext({viewport:{width:390,height:700},timezoneId:'Pacific/Honolulu',isMobile:true,hasTouch:true});
      await context.addInitScript(()=>{
        const NativeDate=Date;
        window.__testNow='2027-01-01T16:30:00Z';
        window.Date=class extends NativeDate {
          constructor(...args){super(...(args.length?args:[window.__testNow]));}
          static now(){return new NativeDate(window.__testNow).getTime();}
        };
        if(!localStorage.getItem('devotion-v04'))localStorage.setItem('devotion-v04',JSON.stringify({name:'測試',fullMarks:{'2026-11-17':{'1':'green'}},notes:[{id:'old',date:'2026-11-17',text:'保留我的筆記',private:true}]}));
      });
      const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
      await page.goto('http://127.0.0.1:'+server.address().port);
      assert(await page.getByRole('img',{name:'EyeBible',exact:true}).isVisible());
      assert.equal(await page.locator('.subbrand').count(),0);
      assert.equal(await page.locator('#todayDate').getAttribute('datetime'),'2027-01-02');
      const dateBox=await page.locator('#todayDate').boundingBox();assert(dateBox.y>=63&&dateBox.y+dateBox.height<700,'today must be visible without scrolling');
      assert.match(await page.locator('#todayDate').innerText(),/2027.*1.*2/);
      assert.equal(await page.locator('#noteInput').getAttribute('placeholder'),'寫下你的感動、想法或疑問，跟大家一起分享討論');
      await page.locator('.navbar [data-tab="profile"]').tap();
      await page.getByRole('button',{name:'暗色系',exact:true}).tap();
      assert.equal(await page.locator('html').getAttribute('data-theme'),'dark');
      assert.equal(await page.getByRole('button',{name:'暗色系',exact:true}).getAttribute('aria-pressed'),'true');
      assert.equal(await page.locator('body').evaluate(e=>getComputedStyle(e).backgroundColor),'rgb(16, 21, 17)');
      await page.reload();
      assert.equal(await page.locator('html').getAttribute('data-theme'),'dark','theme must survive reload');
      await page.locator('#verse-1').tap();
      await page.getByRole('button',{name:'寫筆記',exact:true}).tap();
      assert.equal(await page.locator('#noteInput').evaluate(e=>getComputedStyle(e).backgroundColor),'rgb(27, 34, 29)');
      await page.locator('#closeModal').tap();
      await page.locator('.navbar [data-tab="profile"]').tap();
      await page.getByRole('button',{name:'亮色系',exact:true}).tap();
      assert.equal(await page.locator('html').getAttribute('data-theme'),'light');
      const state=await page.evaluate(()=>JSON.parse(localStorage.getItem('devotion-v04')));
      assert.equal(state.theme,'light');assert.equal(state.notes[0].text,'保留我的筆記');
      await page.evaluate(()=>{window.__testNow='2027-01-02T16:30:00Z';window.dispatchEvent(new Event('focus'));});
      await page.locator('.navbar [data-tab="reading"]').tap();
      assert.equal(await page.locator('#todayDate').getAttribute('datetime'),'2027-01-03','resuming after midnight must refresh today');
      if(await page.locator('#loadReading').isVisible())await page.locator('#loadReading').tap();
      await page.waitForFunction(()=>document.querySelector('#readingStatus').textContent.startsWith('今日經文 · 2027-01-03'));
      await page.locator('#checkBtn').tap();
      assert.equal(await page.evaluate(()=>JSON.parse(localStorage.getItem('devotion-v04')).checkins['2027-01-03']),true);
      await page.locator('.navbar [data-tab="history"]').tap();
      await page.locator('#prevMonth').tap();await page.locator('#prevMonth').tap();
      await page.locator('[data-date="2026-11-17"]').tap();
      assert.match(await page.locator('#historyDetails').innerText(),/1 個標註/,'old annotations remain visible in history');
      assert.equal(await page.locator('#historyDetails .history-mark .hgreen').count(),1,'history renders the saved highlight');
      assert.deepEqual(errors,[]);
      console.log('PASS '+name+': brand, Taiwan date/rollover, prompt, light/dark persistence, dark input, legacy notes/marks');
      await context.close();
      const taipei=await browser.newContext({timezoneId:'Asia/Taipei'});await taipei.addInitScript(()=>{const NativeDate=Date;window.Date=class extends NativeDate{constructor(...args){super(...(args.length?args:['2027-01-02T04:00:00Z']))}static now(){return new NativeDate('2027-01-02T04:00:00Z').getTime()}};localStorage.setItem('devotion-v04',JSON.stringify({name:'測試'}));});const calendar=await taipei.newPage();await calendar.goto('http://127.0.0.1:'+server.address().port);await calendar.locator('.navbar [data-tab="history"]').click();await calendar.locator('#prevMonth').click();assert.equal(await calendar.locator('#monthTitle').innerText(),'2026 年 12 月');await calendar.locator('#nextMonth').click();assert.equal(await calendar.locator('#monthTitle').innerText(),'2027 年 1 月');await taipei.close();
    } finally {await browser.close();}
  }
})().catch(e=>{console.error(e);process.exitCode=1;}).finally(()=>server.close());
