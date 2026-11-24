const {chromium,webkit}=require('playwright');
const assert=require('node:assert/strict'),fs=require('node:fs'),http=require('node:http');
const server=http.createServer((req,res)=>{if(require('./static-assets.cjs')(req,res))return;if(req.url.startsWith('/data/')){res.writeHead(404);return res.end('{}')}res.setHeader('Content-Type','text/html; charset=utf-8');res.end(fs.readFileSync(require('node:path').join(__dirname,'../index.html')))});
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 for(const [name,engine] of [['chromium',chromium],['webkit',webkit]]){
  const browser=await engine.launch();
  try{
   const page=await browser.newPage({viewport:{width:390,height:800}});
   await page.addInitScript(()=>localStorage.setItem('devotion-v04',JSON.stringify({name:'測試',fullMarks:{},notes:[],checkins:{}})));
   await page.goto('http://127.0.0.1:'+server.address().port);
   const text=page.locator('#verse-1 .vtext');
   assert.equal(await text.evaluate(e=>(getComputedStyle(e).userSelect||getComputedStyle(e).webkitUserSelect)),'text','scripture permits native text selection');
   assert.notEqual(await text.evaluate(e=>getComputedStyle(e).webkitTouchCallout),'none','native copy callout is enabled');
   await text.click();assert(await page.locator('#selectionTools').isVisible(),'tap still opens tools');
   await page.locator('#selectionCancel').click();
   const b=await text.boundingBox();
   await page.mouse.move(b.x+3,b.y+18);await page.mouse.down();await page.mouse.move(b.x+130,b.y+18,{steps:12});await page.mouse.up();
   const chosen=await page.evaluate(()=>getSelection().toString());assert(chosen.length>1,'real browser drag selects scripture');
   assert(!await page.locator('#selectionTools').isVisible(),'selecting text does not open tools');
   await text.dispatchEvent('click');assert.equal(await page.evaluate(()=>getSelection().toString()),chosen,'selection survives click handler');
   assert(!await page.locator('#selectionTools').isVisible());
   // Exercise the browser's Copy command (the same command used by its selection menu).
   assert(await page.evaluate(()=>document.execCommand('copy')),'browser accepts Copy for selected scripture');
   await page.evaluate(()=>{const input=document.createElement('textarea');input.id='copy-test-target';document.body.append(input);input.focus({preventScroll:true})});
   await page.keyboard.press('Control+v');
   assert.equal(await page.locator('#copy-test-target').inputValue(),chosen,'native clipboard copies the selected scripture');
   await page.locator('#copy-test-target').evaluate(e=>e.remove());
   await page.evaluate(()=>getSelection().removeAllRanges());
   await page.mouse.move(b.x+40,b.y+18);await page.mouse.down();await page.waitForTimeout(550);await page.mouse.up();
   assert(!await page.locator('#selectionTools').isVisible(),'long press does not become an annotation tap');
   await text.click();assert(await page.locator('#selectionTools').isVisible(),'next ordinary tap works');
   await page.getByRole('button',{name:'黃色重點',exact:true}).click();
   assert(await page.locator('#verse-1').evaluate(e=>e.classList.contains('full-yellow')));
   await page.locator('#selectionCancel').click();
   assert.equal(await page.locator('#verse-1 mark').evaluate(e=>(getComputedStyle(e).userSelect||getComputedStyle(e).webkitUserSelect)),'text','highlighted text is also selectable');
   console.log('PASS '+name+': native selection/copy/paste, long press isolation, normal tap and highlighting');
  }finally{await browser.close()}
 }
})().catch(e=>{console.error(e);process.exitCode=1}).finally(()=>server.close());
