const assert=require('node:assert/strict'),fs=require('fs'),cp=require('child_process'),E=require(process.env.EXPORT_FILE_WRITER||'../study/export-files.js');
(async()=>{const doc={title:'TagBible 讀經筆記',scope:'約翰福音',paragraphs:[{runs:[{text:'約翰福音 3:16–18'}],size:14,bold:true},{runs:[{text:'神愛世人',color:'yellow'},{text:'，中文私人筆記 <script>& 😀\uFFFF\uFFFE'}],size:11},...Array.from({length:100},(_,i)=>({runs:[{text:'第'+i+'則筆記：'+('這是長篇中文換行測試。'.repeat(6))+'\n保留下一行'}],size:11,after:8}))]};
const word=E.docx(doc);assert(word instanceof Uint8Array);fs.writeFileSync('/tmp/tagbible-export-test.docx',word);cp.execFileSync('python',['-c',`import zipfile,xml.etree.ElementTree as E
z=zipfile.ZipFile('/tmp/tagbible-export-test.docx');assert z.testzip() is None;assert all(i.date_time[:3]==(1980,1,1) for i in z.infolist())
for n in z.namelist():
 if n.endswith('.xml') or n.endswith('.rels'):E.fromstring(z.read(n))
s=z.read('word/document.xml').decode();assert '神愛世人' in s and '中文私人筆記' in s and '😀' in s and '&lt;script&gt;&amp;' in s;assert 'F3DF90' in s
assert 'word/styles.xml' in z.namelist()
`]);
const pdf=await E.pdf(doc,{PDFLib:require('../study/vendor/pdf-lib-1.17.1.min.js'),fontkit:require('../study/vendor/fontkit-1.1.1.min.js'),fontBytes:fs.readFileSync('study/fonts/NotoSansTC-Regular.ttf')});assert.equal(new TextDecoder().decode(pdf.slice(0,5)),'%PDF-');fs.writeFileSync('/tmp/tagbible-export-test.pdf',pdf);const extraction=cp.spawnSync('pdftotext',['/tmp/tagbible-export-test.pdf','/tmp/tagbible-export-test.txt'],{encoding:'utf8'});assert.equal(extraction.status,0);assert(!/Error/i.test(extraction.stderr),'PDF font must render without parser errors: '+extraction.stderr.slice(0,200));const text=fs.readFileSync('/tmp/tagbible-export-test.txt','utf8');assert(text.includes('神愛世人'));assert(text.includes('中文私人筆記'));assert(text.includes('第99則筆記'));const info=cp.execFileSync('pdfinfo',['/tmp/tagbible-export-test.pdf'],{encoding:'utf8'});assert(Number(/Pages:\s+(\d+)/.exec(info)[1])>2);cp.execFileSync('python',['-c',`import fitz
p=fitz.open('/tmp/tagbible-export-test.pdf')[0]
checked=0
for block in p.get_text('rawdict')['blocks']:
 for line in block.get('lines',[]):
  for span in line['spans']:
   for c in span['chars']:
    if not ('\u4e00'<=c['c']<='\u9fff') or checked>=60: continue
    pix=p.get_pixmap(matrix=fitz.Matrix(2,2),clip=fitz.Rect(c['bbox']),alpha=False)
    raw=pix.samples
    dark=sum(1 for i in range(0,len(raw),3) if max(raw[i:i+3])<180)
    assert dark>8, 'Invisible Chinese glyph: '+c['c']
    checked+=1
assert checked>=30
for page in p.parent:
 assert all(w[2]<page.rect.width-35 for w in page.get_text('words')), 'Text overflows page margin'
`]);console.log('PASS real DOCX XML/ZIP/highlights/emoji/escaping and searchable Chinese multi-page PDF');})().catch(e=>{console.error(e);process.exitCode=1});
