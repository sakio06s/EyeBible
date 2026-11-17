import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from datetime import date

spec=importlib.util.spec_from_file_location('updater',Path(__file__).parents[1]/'scripts/update_daily.py')
updater=importlib.util.module_from_spec(spec)
if spec.loader and spec.origin and Path(spec.origin).exists():spec.loader.exec_module(updater)

PAGE='<!-- 2026 年 11 月 17 日 --><div class="range">阿摩司書8：1∼3</div><h2>今日主題</h2>'
XML='''<usfx><book id="AMO"><h>阿摩司書</h><c id="8"/><v id="1"/>第一節<ve/><v id="2"/>第二<it>節</it><f>不包含註腳</f>。<ve/><v id="3"/>第三節<ve/><c id="9"/><v id="1"/>下一章<ve/><v id="2"/>最後一節<ve/></book></usfx>'''

class UpdateTests(unittest.TestCase):
    def test_public_date_and_reference(self):
        self.assertTrue(hasattr(updater,'parse_daily_page'),'daily importer is not implemented')
        result=updater.parse_daily_page(PAGE,date(2026,11,17))
        self.assertEqual(result,'阿摩司書8:1-3')
    def test_stale_missing_ambiguous_date_rejected(self):
        for page in [PAGE.replace('17 日','16 日'),PAGE.replace('2026 年 11 月 17 日',''),PAGE+'<!--2026年11月18日-->']:
            with self.subTest(page=page),self.assertRaises(ValueError):updater.parse_daily_page(page,date(2026,11,17))
    def test_footnotes_excluded(self):
        bible=updater.parse_usfx(XML)
        self.assertEqual(bible['AMO'][8][2],'第二節。')
    def test_full_range_and_cross_chapter(self):
        bible=updater.parse_usfx(XML)
        verses=updater.select_verses('阿摩司書8:2-9:2',bible)
        self.assertEqual([v['id'] for v in verses],['AMO.8.2','AMO.8.3','AMO.9.1','AMO.9.2'])
        self.assertEqual(verses[0]['reference'],'阿摩司書 8:2')
    def test_disjoint_ranges_and_single_verse(self):
        bible=updater.parse_usfx(XML)
        verses=updater.select_verses('阿摩司書8:1,3',bible)
        self.assertEqual([v['verse'] for v in verses],[1,3])
    def test_missing_verses_and_invalid_reference_rejected(self):
        bible=updater.parse_usfx(XML)
        for ref in ['阿摩司書8:1-4','阿摩司書8:3-1','不存在書1:1','阿摩司書8:1oops']:
            with self.subTest(ref=ref),self.assertRaises(ValueError):updater.select_verses(ref,bible)
    def test_failed_update_preserves_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            out=Path(tmp);(out/'latest.json').write_text('{"keep":true}')
            with self.assertRaises(ValueError):updater.publish(PAGE.replace('17 日','16 日'),XML,out,date(2026,11,17))
            self.assertEqual((out/'latest.json').read_text(),'{"keep":true}')
            self.assertFalse((out/'daily').exists())
    def test_publish_and_repeat_do_not_change_reading_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            out=Path(tmp)
            self.assertTrue(updater.publish(PAGE,XML,out,date(2026,11,17)))
            saved=(out/'latest.json').read_bytes()
            self.assertFalse(updater.publish(PAGE,XML,out,date(2026,11,17)))
            self.assertEqual(saved,(out/'latest.json').read_bytes())
            record=json.loads(saved)
            self.assertEqual(record['date'],'2026-11-17')
            status=json.loads((out/'sync-status.json').read_text())
            self.assertEqual(status['date'],record['date'])
            self.assertEqual(status['reference'],record['reference'])
            self.assertIn('lastSuccess',status)
            self.assertEqual(len(record['verses']),3)
            self.assertEqual(saved,(out/'daily/2026-11-17.json').read_bytes())
    def test_latest_never_moves_backwards(self):
        with tempfile.TemporaryDirectory() as tmp:
            out=Path(tmp);(out/'latest.json').write_text('{"date":"2026-11-18"}')
            with self.assertRaises(ValueError):updater.publish(PAGE,XML,out,date(2026,11,17))
            self.assertEqual((out/'latest.json').read_text(),'{"date":"2026-11-18"}')
            self.assertFalse((out/'daily').exists())
            self.assertFalse((out/'sync-status.json').exists())
    def test_duplicate_requested_verses_rejected(self):
        with self.assertRaises(ValueError):updater.select_verses('阿摩司書8:1-3,2',updater.parse_usfx(XML))
    def test_same_date_content_change_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            out=Path(tmp);updater.publish(PAGE,XML,out,date(2026,11,17));saved=(out/'latest.json').read_bytes()
            with self.assertRaises(ValueError):updater.publish(PAGE,XML.replace('第一節','改寫內容'),out,date(2026,11,17))
            self.assertEqual(saved,(out/'latest.json').read_bytes())

if __name__=='__main__':unittest.main()
