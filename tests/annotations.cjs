const { chromium, webkit } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const htmlPath = require('node:path').join(__dirname, '..', 'index.html');
const server = http.createServer((req,res) => {res.setHeader('Content-Type','text/html; charset=utf-8');let html=fs.readFileSync(htmlPath,'utf8');if(req.url.includes('legacy'))html=html.replaceAll('100dvh','invalid');res.end(html);});
const legacy = {name:'測試',font:26,fullMarks:{'2026-11-17':{'1':'green'}},highlights:{'2026-11-17':{'1':[{start:0,end:3,color:'pink'}]}},notes:[{id:'old',date:'2026-11-17',text:'保留筆記',private:true}],checkins:{'2026-11-17':true}};
const geometry = page => page.evaluate(() => {
  const main=document.querySelector('main'), v=document.querySelector('#verse-10'), text=v.querySelector('.vtext');
  const r=v.getBoundingClientRect(), t=text.getBoundingClientRect(), m=main.getBoundingClientRect();
  return {scroll:main.scrollTop,window:window.scrollY,y:r.y,height:r.height,textY:t.y,textHeight:t.height,mainBottom:m.bottom};
});
(async()=>{
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const url='http://127.0.0.1:'+server.address().port;
  for(const [engine,type] of [['chromium',chromium],['webkit',webkit]]){
    const browser=await type.launch({headless:true});
    try {
      if(process.env.LEGACY_ONLY){
        const context=await browser.newContext({viewport:{width:390,height:664}});
        await context.addInitScript(data=>localStorage.setItem('devotion-v04',JSON.stringify(data)),legacy);
        const page=await context.newPage();await page.goto(url+'/?legacy');
        const nav=await page.locator('.navbar').boundingBox();
        assert(nav.y+nav.height<=665,'navigation must remain visible when dvh is unsupported');
        console.log('PASS '+engine+' viewport-height fallback');await context.close();continue;
      }
      for(const [width,height] of [[320,664],[390,664],[490,664],[320,420],[844,390],[1024,768]]){
        const context=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
        await context.addInitScript(data=>{if(!localStorage.getItem('devotion-v04'))localStorage.setItem('devotion-v04',JSON.stringify(data));},legacy);
        const page=await context.newPage(); const errors=[];page.on('pageerror',e=>errors.push(e.message));
        await page.goto(url);
        await page.locator('#verse-10').scrollIntoViewIfNeeded();
        const before=await geometry(page);
        // Tap a currently visible point; locator.tap would auto-scroll a tall verse first.
        const textBox=await page.locator('#verse-10 .vtext').boundingBox();
        await page.touchscreen.tap(textBox.x+textBox.width/2,Math.max(83,Math.min(textBox.y+30,before.mainBottom-20)));
        assert(await page.locator('#selectionTools').isVisible(),'a single tap on verse text must open tools');
        assert.deepEqual(await geometry(page),before,'opening tools must not move or scroll scripture');
        assert.equal(await page.locator('.verse[aria-pressed="true"]').count(),1,'only one verse selected');
        const dock=await page.locator('#selectionTools').boundingBox();
        assert(dock.y>=before.mainBottom-1,'tools must be outside the scripture viewport');
        assert(dock.x>=0&&dock.x+dock.width<=width+1,'toolbar must fit viewport');
        const buttons=await page.locator('#selectionTools button').all();
        for(const button of buttons){const r=await button.boundingBox();assert(r.x>=0&&r.x+r.width<=width+1&&r.y>=dock.y&&r.y+r.height<=dock.y+dock.height+1,'all controls must fit toolbar');}
        await page.getByRole('button',{name:'黃色重點',exact:true}).tap();
        assert(await page.locator('#verse-10').evaluate(v=>v.classList.contains('full-yellow')));
        assert.deepEqual(await geometry(page),before,'marking must not move scripture');
        await page.getByRole('button',{name:'黃色重點',exact:true}).tap();
        assert(await page.locator('#verse-10').evaluate(v=>v.classList.contains('full-yellow')),'same color remains applied');
        await page.getByRole('button',{name:'取消標註',exact:true}).tap();
        assert(!await page.locator('#verse-10').evaluate(v=>v.classList.contains('full-yellow')));
        await page.getByRole('button',{name:'關閉標註工具',exact:true}).tap();
        assert.deepEqual(await geometry(page),before,'closing tools must not move scripture');
        assert.equal(await page.locator('.verse[aria-pressed="true"]').count(),0);
        await page.locator('#verse-1').scrollIntoViewIfNeeded();await page.locator('#verse-1').tap();
        await page.getByRole('button',{name:'取消標註',exact:true}).tap();
        assert.equal(await page.locator('#verse-1 mark').count(),0,'whole-verse clear also removes legacy partial marks');
        await page.getByRole('button',{name:'粉色重點',exact:true}).tap();
        await page.locator('#verse-2').tap();
        assert.equal(await page.locator('.verse[aria-pressed="true"]').count(),1);
        assert.equal(await page.locator('#verse-1').getAttribute('aria-pressed'),'false');
        await page.getByRole('button',{name:'寫筆記',exact:true}).tap();
        assert(await page.locator('#modalBg').isVisible());await page.locator('#closeModal').tap();
        await page.locator('.navbar [data-tab="profile"]').tap();
        assert(!await page.locator('#selectionTools').isVisible(),'no tools on another tab');
        await page.locator('.navbar [data-tab="reading"]').tap();
        await page.locator('#verse-2').press('Enter');
        assert(await page.locator('#selectionTools').isVisible(),'keyboard selects a verse');
        const saved=await page.evaluate(()=>JSON.parse(localStorage.getItem('devotion-v04')));
        assert.equal(saved.fullMarks['2026-11-17']['1'],'pink');assert.equal(saved.highlights['2026-11-17']['1'],undefined);
        assert.equal(saved.notes[0].text,'保留筆記');assert.equal(saved.checkins['2026-11-17'],true);
        await page.reload();
        assert(await page.locator('#verse-1').evaluate(v=>v.classList.contains('full-pink')),'whole verse color survives reload');
        assert.equal(errors.length,0,errors.join('\n'));
        assert.equal(await page.locator('.verse').count(),10);
        console.log(`PASS ${engine} ${width}x${height}: tap, single selection, fixed geometry, mark/clear, legacy data, notes/tabs, keyboard`);
        await context.close();
      }
    }finally{await browser.close();}
  }
})().catch(e=>{console.error(e);process.exitCode=1}).finally(()=>server.close());
