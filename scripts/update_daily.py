#!/usr/bin/env python3
"""Validate Living Life's daily reference and publish public-domain CUV verses."""
import argparse
from datetime import date, datetime, timezone
from html import unescape
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import re
import tempfile
import urllib.request
import xml.etree.ElementTree as ET
from zoneinfo import ZoneInfo

SOURCE_URL = 'https://www.duranno.tw/livinglife/index.php/daily'
BIBLE_COMMIT = 'df3d5958933e0e1a62495fe95527b5949bb04a9f'
BIBLE_URL = f'https://raw.githubusercontent.com/seven1m/open-bibles/{BIBLE_COMMIT}/chi-cuv.usfx.xml'
BIBLE_LICENSE = 'https://github.com/seven1m/open-bibles/blob/master/README.md'
BOOK_NAMES = '創世記 出埃及記 利未記 民數記 申命記 約書亞記 士師記 路得記 撒母耳記上 撒母耳記下 列王紀上 列王紀下 歷代志上 歷代志下 以斯拉記 尼希米記 以斯帖記 約伯記 詩篇 箴言 傳道書 雅歌 以賽亞書 耶利米書 耶利米哀歌 以西結書 但以理書 何西阿書 約珥書 阿摩司書 俄巴底亞書 約拿書 彌迦書 那鴻書 哈巴谷書 西番雅書 哈該書 撒迦利亞書 瑪拉基書 馬太福音 馬可福音 路加福音 約翰福音 使徒行傳 羅馬書 哥林多前書 哥林多後書 加拉太書 以弗所書 腓立比書 歌羅西書 帖撒羅尼迦前書 帖撒羅尼迦後書 提摩太前書 提摩太後書 提多書 腓利門書 希伯來書 雅各書 彼得前書 彼得後書 約翰一書 約翰二書 約翰三書 猶大書 啟示錄'.split()
BOOK_CODES = 'GEN EXO LEV NUM DEU JOS JDG RUT 1SA 2SA 1KI 2KI 1CH 2CH EZR NEH EST JOB PSA PRO ECC SNG ISA JER LAM EZK DAN HOS JOL AMO OBA JON MIC NAM HAB ZEP HAG ZEC MAL MAT MRK LUK JHN ACT ROM 1CO 2CO GAL EPH PHP COL 1TH 2TH 1TI 2TI TIT PHM HEB JAS 1PE 2PE 1JN 2JN 3JN JUD REV'.split()
BOOKS = dict(zip(BOOK_NAMES, BOOK_CODES))
BOOKS['創世紀'] = 'GEN'

class RangeParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.depth = 0
        self.ranges = []
        self.parts = []
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if self.depth:
            self.depth += 1
        elif 'range' in attrs.get('class','').split():
            self.depth = 1
            self.parts = []
    def handle_endtag(self, tag):
        if self.depth:
            self.depth -= 1
            if not self.depth:
                self.ranges.append(''.join(self.parts))
    def handle_data(self, data):
        if self.depth:
            self.parts.append(data)

def normalize_reference(reference):
    return re.sub(r'\s+', '', unescape(reference)).translate(str.maketrans('：～∼–—－；，、', ':-----;,,')).strip()

def parse_daily_page(html, expected_date):
    dates = {date(int(y),int(m),int(d)) for y,m,d in re.findall(r'(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日',unescape(html))}
    if dates != {expected_date}:
        raise ValueError(f'Official date does not match {expected_date}: {sorted(dates)}')
    parser = RangeParser()
    parser.feed(html)
    if len(parser.ranges) != 1:
        raise ValueError('Expected exactly one official scripture range')
    return normalize_reference(parser.ranges[0])

def parse_usfx(xml):
    root = ET.fromstring(xml)
    bible = {}
    skip = {'f','x','s','s1','s2','h','toc','id','rem','mt','ms','r','cl','cp'}
    for book in root.findall('book'):
        chapters = bible.setdefault(book.attrib['id'],{})
        chapter, verse, pieces = 0, None, []
        def finish():
            nonlocal pieces
            if verse is not None:
                text = ' '.join(''.join(pieces).split())
                if not text:
                    raise ValueError(f'Empty verse {book.attrib["id"]}.{chapter}.{verse}')
                target = chapters.setdefault(chapter,{})
                if verse in target:
                    raise ValueError('Duplicate Bible verse')
                target[verse] = text
            pieces = []
        def walk(node):
            nonlocal chapter, verse
            tag = node.tag.split('}')[-1]
            if tag in skip:
                return
            if tag == 'c':
                finish(); verse = None; chapter = int(node.attrib['id'])
            elif tag == 'v':
                finish(); verse = int(node.attrib['id'])
            elif tag == 've':
                finish(); verse = None
            elif verse is not None and node.text:
                pieces.append(node.text)
            for child in node:
                walk(child)
                if verse is not None and child.tail:
                    pieces.append(child.tail)
        walk(book)
        finish()
    return bible

def select_verses(reference, bible):
    reference = normalize_reference(reference)
    selected, seen = [], set()
    book_name, code, chapter = None, None, None
    for part in re.split('[;,]',reference):
        named = re.fullmatch(r'([^0-9:]+)(\d+):(.+)',part)
        if named:
            book_name, chapter, part = named.groups()
            code = BOOKS.get(book_name)
            chapter = int(chapter)
        else:
            explicit = re.fullmatch(r'(\d+):(.+)',part)
            if explicit:
                chapter, part = int(explicit[1]),explicit[2]
        if code not in bible or chapter is None:
            raise ValueError('Unknown Bible book or missing chapter')
        match = re.fullmatch(r'(\d+)(?:-(?:(\d+):)?(\d+))?',part)
        if not match:
            raise ValueError('Unsupported scripture range')
        start = int(match[1])
        end_chapter = int(match[2]) if match[2] else chapter
        end = int(match[3]) if match[3] else start
        if (end_chapter,end) < (chapter,start) or end_chapter-chapter > 10:
            raise ValueError('Invalid scripture range')
        for ch in range(chapter,end_chapter+1):
            data = bible[code].get(ch,{})
            first = start if ch == chapter else 1
            last = end if ch == end_chapter else max(data,default=0)
            if not data or first > last:
                raise ValueError('Missing chapter or invalid verse range')
            for number in range(first,last+1):
                text = data.get(number)
                verse_id = f'{code}.{ch}.{number}'
                if not text or verse_id in seen:
                    raise ValueError('Missing or duplicate verse: '+verse_id)
                seen.add(verse_id)
                selected.append({'id':verse_id,'book':book_name,'chapter':ch,'verse':number,'reference':f'{book_name} {ch}:{number}','text':text})
        chapter = end_chapter
    if not 1 <= len(selected) <= 300:
        raise ValueError('Unexpected daily scripture length')
    return selected

def atomic_write(path, text):
    path.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.NamedTemporaryFile('w',encoding='utf-8',dir=path.parent,delete=False) as file:
        file.write(text);temporary = file.name
    os.replace(temporary,path)

def publish(html, xml, output, expected_date):
    reference = parse_daily_page(html,expected_date)
    verses = select_verses(reference,parse_usfx(xml))
    payload = {'schemaVersion':1,'date':expected_date.isoformat(),'reference':reference,'title':'今日經文','verses':verses,'planSource':SOURCE_URL,'translation':'和合本（繁體、公版）','textSource':BIBLE_URL,'licenseSource':BIBLE_LICENSE}
    output = Path(output)
    daily = output/'daily'/f'{expected_date.isoformat()}.json'
    latest = output/'latest.json'
    # Published days are immutable: don't silently move existing annotations to changed text.
    if daily.exists() and json.loads(daily.read_text(encoding='utf-8')) != payload:
        raise ValueError('Published reading changed; manual review required')
    if latest.exists():
        old = json.loads(latest.read_text(encoding='utf-8'))
        if old.get('date','') > payload['date']:
            raise ValueError('Refusing to replace latest with an older reading')
    text = json.dumps(payload,ensure_ascii=False,indent=2)+'\n'
    changed = False
    for path in [daily,latest]:
        if not path.exists() or path.read_text(encoding='utf-8') != text:
            atomic_write(path,text);changed = True
    status = {'date':payload['date'],'reference':reference,'lastSuccess':datetime.now(timezone.utc).isoformat()}
    atomic_write(output/'sync-status.json',json.dumps(status,ensure_ascii=False,indent=2)+'\n')
    return changed

def download(url):
    with urllib.request.urlopen(url,timeout=45) as response:
        data = response.read(16*1024*1024+1)
    if len(data) > 16*1024*1024:
        raise ValueError('Unexpectedly large source response')
    return data.decode('utf-8-sig')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--date',type=date.fromisoformat,default=datetime.now(ZoneInfo('Asia/Taipei')).date())
    parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]/'data')
    parser.add_argument('--source-file',type=Path)
    parser.add_argument('--bible-file',type=Path)
    args = parser.parse_args()
    page = args.source_file.read_text(encoding='utf-8') if args.source_file else download(SOURCE_URL)
    # Check the source date before downloading the larger Bible text.
    parse_daily_page(page,args.date)
    xml = args.bible_file.read_text(encoding='utf-8') if args.bible_file else download(BIBLE_URL)
    changed = publish(page,xml,args.output,args.date)
    print(('Published' if changed else 'Already current')+' scripture for '+str(args.date))

if __name__ == '__main__':
    main()
