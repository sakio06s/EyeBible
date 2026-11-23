import importlib.util
from datetime import date
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from xml.sax.saxutils import escape

spec=importlib.util.spec_from_file_location('fallback_updater',Path(__file__).parents[1]/'scripts/update_daily.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
DAY=date(2026,11,23)
CHANNEL='UCqUnxXxHSFb6At-njlSX9AQ'
XML='<usfx><book id="AMO"><c id="8"/><v id="1"/>第一節<ve/><v id="2"/>第二節<ve/><v id="3"/>第三節<ve/></book></usfx>'
PAGE='2026 年 11 月 23 日<div class="range">阿摩司書8:1-3</div>'
def entry(title='2026/11/23 活潑的生命 阿摩司書8:1-3',description='',channel=CHANNEL,video='abcdefghijk'):
 return f'<entry><yt:channelId>{channel}</yt:channelId><yt:videoId>{video}</yt:videoId><title>{escape(title)}</title><published>2026-11-22T15:00:00Z</published><media:group><media:description>{escape(description)}</media:description></media:group></entry>'
def feed(*entries,channel=CHANNEL):
 return f'<feed xmlns="http://www.w3.org/2005/Atom" xmlns:yt="http://www.youtube.com/xml/schemas/2015" xmlns:media="http://search.yahoo.com/mrss/"><yt:channelId>{channel}</yt:channelId>'+''.join(entries)+'</feed>'
class FallbackTests(unittest.TestCase):
 def test_matching_title_uses_explicit_reading_date_not_publication(self):
  self.assertEqual(m.parse_youtube_feed(feed(entry()),DAY),('阿摩司書8:1-3','https://www.youtube.com/watch?v=abcdefghijk'))
 def test_description_label_and_date_formats(self):
  for day in ['2026年11月23日','2026.11.23','20261123']:
   with self.subTest(day=day):self.assertEqual(m.parse_youtube_feed(feed(entry(day+' 每日靈修','經文：阿摩司書 8：1～3')),DAY)[0],'阿摩司書8:1-3')
 def test_wrong_missing_ambiguous_invalid_date_rejected(self):
  for title in ['2026/11/22 阿摩司書8:1-3','2025/11/23 阿摩司書8:1-3','今日 阿摩司書8:1-3','2026/11/23 2026/11/24 阿摩司書8:1-3','2026/02/30 阿摩司書8:1-3']:
   with self.subTest(title=title),self.assertRaises(ValueError):m.parse_youtube_feed(feed(entry(title)),DAY)
 def test_observed_live_feed_root_identity_and_title_format(self):
  text=feed(entry('[活潑的生命] 20261123 含淚寫下的愛心勸勉(哥林多後書 2:1~11)'),channel=CHANNEL[2:])
  self.assertEqual(m.parse_youtube_feed(text,DAY)[0],'哥林多後書2:1-11')
 def test_irrelevant_today_video_does_not_hide_daily_progress(self):
  self.assertEqual(m.parse_youtube_feed(feed(entry('2026/11/23 頻道公告'),entry()),DAY)[0],'阿摩司書8:1-3')
 def test_wrong_channel_and_malformed_feed_rejected(self):
  for text in [feed(entry(),channel='another'),feed(entry(channel='another')),feed(entry(video='bad')), '<feed/>','not xml']:
   with self.subTest(text=text),self.assertRaises(ValueError):m.parse_youtube_feed(text,DAY)
 def test_reference_missing_conflicting_and_multiple_today_rejected(self):
  for text in [feed(entry('2026/11/23 每日靈修')),feed(entry(description='經文：阿摩司書8:2-3')),feed(entry(),entry('2026/11/23 阿摩司書8:2-3',video='ABCDEFGHIJK'))]:
   with self.subTest(text=text),self.assertRaises(ValueError):m.parse_youtube_feed(text,DAY)
 def test_unsupported_reference_does_not_publish_valid_prefix(self):
  for ref in ['阿摩司書8:1至3','阿摩司書8:1-9999','阿摩司書8:1/3','阿摩司書8:1-3,9999']:
   with self.subTest(ref=ref),self.assertRaises(ValueError):m.parse_youtube_feed(feed(entry('2026/11/23 '+ref)),DAY)
 def test_conflicting_labelled_date_rejected_even_with_title_date(self):
  with self.assertRaises(ValueError):m.parse_youtube_feed(feed(entry(description='讀經日期：2026/11/22')),DAY)
 def test_same_range_multiple_today_videos_ok(self):
  self.assertEqual(m.parse_youtube_feed(feed(entry(),entry(video='ABCDEFGHIJK')),DAY)[0],'阿摩司書8:1-3')
 def test_primary_valid_never_loads_backup(self):
  def backup():self.fail('backup must not be fetched')
  self.assertEqual(m.resolve_daily_reference(lambda:PAGE,backup,DAY),('阿摩司書8:1-3',m.SOURCE_URL))
 def test_primary_failure_or_maintenance_uses_backup(self):
  def unavailable():raise OSError('offline')
  for primary in [unavailable,lambda:'系統維護中',lambda:PAGE.replace('23 日','22 日')]:
   self.assertEqual(m.resolve_daily_reference(primary,lambda:feed(entry()),DAY)[0],'阿摩司書8:1-3')
 def test_both_fail_preserve_existing_files(self):
  with tempfile.TemporaryDirectory() as tmp:
   p=Path(tmp)/'latest.json';p.write_text('original')
   with self.assertRaises(ValueError):m.resolve_daily_reference(lambda:'maintenance',lambda:feed(entry('2026/11/22 阿摩司書8:1-3')),DAY)
   self.assertEqual(p.read_text(),'original');self.assertFalse((Path(tmp)/'daily').exists())
 def test_primary_recovery_preserves_existing_fallback_provenance(self):
  with tempfile.TemporaryDirectory() as tmp:
   m.publish_reference('阿摩司書8:1-3',XML,tmp,DAY,'https://www.youtube.com/watch?v=abcdefghijk')
   saved=(Path(tmp)/'daily/2026-11-23.json').read_bytes()
   self.assertFalse(m.publish(PAGE,XML,tmp,DAY));self.assertEqual((Path(tmp)/'daily/2026-11-23.json').read_bytes(),saved)
   with self.assertRaises(ValueError):m.publish_reference('阿摩司書8:1-2',XML,tmp,DAY,m.SOURCE_URL)
   self.assertEqual((Path(tmp)/'daily/2026-11-23.json').read_bytes(),saved)
 def test_cli_fallback_includes_real_video_provenance(self):
  with tempfile.TemporaryDirectory() as tmp:
   calls=[]
   def download(url):
    calls.append(url)
    return {m.SOURCE_URL:'maintenance',m.YOUTUBE_FEED:feed(entry()),m.BIBLE_URL:XML}[url]
   with patch.object(m,'download',side_effect=download),patch('sys.argv',['updater','--date','2026-11-23','--output',tmp]):m.main()
   self.assertEqual(calls,[m.SOURCE_URL,m.YOUTUBE_FEED,m.BIBLE_URL])
   import json
   record=json.loads((Path(tmp)/'latest.json').read_text())
   self.assertEqual(record['date'],'2026-11-23');self.assertEqual(record['planSource'],'https://www.youtube.com/watch?v=abcdefghijk')
 def test_cli_bible_failure_preserves_files(self):
  with tempfile.TemporaryDirectory() as tmp:
   p=Path(tmp)/'latest.json';p.write_text('original')
   def download(url):
    if url==m.BIBLE_URL:raise OSError('Bible unavailable')
    return PAGE
   with patch.object(m,'download',side_effect=download),patch('sys.argv',['updater','--date','2026-11-23','--output',tmp]),self.assertRaises(OSError):m.main()
   self.assertEqual(p.read_text(),'original');self.assertFalse((Path(tmp)/'daily').exists())
if __name__=='__main__':unittest.main()
