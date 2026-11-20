const assert=require('node:assert/strict');
let handler;try{handler=require('../api/scripture.js')}catch(e){if(e.code==='MODULE_NOT_FOUND'){assert.fail('Preview scripture proxy is missing')}throw e}
const originalFetch=global.fetch;
async function request(query,upstream){let result={headers:{}};global.fetch=upstream;const req={method:'GET',query};const res={setHeader(k,v){result.headers[k]=v},status(code){result.status=code;return this},json(body){result.body=body;return this},end(body){result.body=body;return this}};await handler(req,res);return result}
const payload={schemaVersion:1,date:'2026-11-19',reference:'阿摩司書 9:7–15',title:'今日經文',verses:[{id:'AMO.9.7',book:'阿摩司書',chapter:9,verse:7,reference:'阿摩司書 9:7',text:'經文'}]};
(async()=>{let url;let r=await request({date:'2026-11-19'},async u=>{url=u;return new Response(JSON.stringify(payload))});assert.equal(url,'https://raw.githubusercontent.com/sakio06s/EyeBible/main/data/daily/2026-11-19.json');assert.equal(r.status,200);assert.equal(r.body.date,'2026-11-19');
r=await request({},async u=>{url=u;return new Response(JSON.stringify(payload))});assert(url.endsWith('/data/latest.json'));assert.equal(r.status,200);
for(const date of ['../../secret','2026-02-30',['2026-11-19']]){r=await request({date},async()=>{throw Error('must not fetch')});assert.equal(r.status,400)}
r=await request({date:'2026-11-20'},async()=>new Response(JSON.stringify(payload)));assert.equal(r.status,502,'wrong upstream date is rejected');
r=await request({},async()=>new Response('<html>bad</html>'));assert.equal(r.status,502);
r=await request({},async()=>{throw Error('offline')});assert.equal(r.status,503);assert.match(r.headers['Cache-Control'],/no-store/);
console.log('PASS scripture API: fixed source, daily/latest, invalid date/shape/date mismatch and offline responses')})().catch(e=>{console.error(e);process.exitCode=1}).finally(()=>global.fetch=originalFetch);
