const { chromium, webkit } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const server = http.createServer((req,res) => {
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
      assert.equal(await page.locator('.brand').innerText(),'EyeBible');
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
    } finally {await browser.close();}
  }
})().catch(e=>{console.error(e);process.exitCode=1;}).finally(()=>server.close());
