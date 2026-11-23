# Daily scripture operation

TagBible follows the **daily scripture range** on Taiwan Duranno's Living Life page:
https://www.duranno.tw/livinglife/index.php/daily

The updater reads only the source date and scripture range. It does not publish the source's devotional article, prayer, images or audio. Scripture text is the public-domain traditional Chinese Union Version from `seven1m/open-bibles`, pinned to commit `df3d5958933e0e1a62495fe95527b5949bb04a9f` (`chi-cuv.usfx.xml`). Attribution and provenance are included in every generated JSON record.

## Schedule and deployment

The GitHub Actions workflow **Update daily scripture** has three target times each day:

- 00:05 Asia/Taipei: main update (16:05 UTC on the preceding UTC date).
- 00:35 Asia/Taipei: follow-up check (16:35 UTC).
- 04:05 Asia/Taipei: recovery check (20:05 UTC).

These are scheduled start targets, not guaranteed publication deadlines. GitHub may delay or drop scheduled runs. The website updates after GitHub commits the validated files and the existing Vercel Git integration finishes deploying `main`.

The workflow also runs after changes to its own file or the updater are merged to `main`, and can be started from **Actions → Update daily scripture → Run workflow**. No API keys or third-party database are needed. GitHub supplies a short-lived repository token; only the publication job has `contents: write`.

## Data and validation

`scripts/update_daily.py` checks that the official source's date matches the current date in Asia/Taipei, parses its reference, extracts every requested verse from the pinned Bible source, and rejects missing, duplicate or empty verses. It supports single verses, ranges, disjoint same-book ranges and ranges crossing chapters. An unsupported format fails explicitly.

A successful import writes:

- `data/daily/YYYY-MM-DD.json`: the immutable record of that day's reference and complete verse text.
- `data/latest.json`: the latest complete record, used if today's publication is not ready.
- `data/sync-status.json`: the date/reference and UTC time of the last successful validation. This changes on a successful follow-up check without changing immutable verse text.

All publication files are committed together. The updater does not modify a previously published day's text or move `latest` backwards. A same-day source correction requires review so existing notes and partial highlight offsets cannot move silently onto different text.

## Failures and recovery

If either source is unavailable, the source date is stale/missing/ambiguous, or verse validation fails, the workflow fails and commits nothing. The old files remain available. The follow-up schedules retry later. Check **Actions → Update daily scripture** for the failed step and log, fix the source/parser problem if needed, then use **Run workflow**.

GitHub can disable a public repository's schedules after 60 days without repository activity. Check the workflow is enabled if a long period passes without updates. The next successful import does not fabricate any skipped day's content; missing dates require a verified historical source and a reviewed import.

## Local checks

```sh
python3 -m unittest discover -s tests -p 'test_*.py'
python3 scripts/update_daily.py
```

For reproducible parser tests, use `--date YYYY-MM-DD`, `--source-file source.html`, `--bible-file bible.usfx.xml` and `--output temporary-directory`. Manual backfills must not replace a newer `latest.json`.

## Vercel 測試分支的即時資料

每日排程只發布到 main；測試分支的靜態 JSON 不會跟著更新。因此標準 `eyebible-*.vercel.app` 測試網址改讀同源 `/api/scripture?date=YYYY-MM-DD`，由 Vercel Node 函式讀取 main 中已驗證的每日 JSON。最新可用資料使用 `/api/scripture`，固定來源、日期格式驗證、1 MiB 回應上限與 8 秒逾時，沒有金鑰或任意 URL 代理。正式網址及本機測試仍使用靜態 `/data` 路徑。資料未發布或網路失敗時保留已存經文與原日期的標註，不把舊經文改標為今天。

## YouTube 備援進度

指定頻道：https://www.youtube.com/channel/UCqUnxXxHSFb6At-njlSX9AQ 。官網下載失敗、維護、日期不符或進度缺失時才讀取該頻道官方 Atom feed。必須核對 feed/entry 的 channel ID、影片 ID、明確讀經日期及不衝突的經文範圍；不以最新一支影片或上傳日期當作今日進度。影片日期可為 YYYY/MM/DD、YYYY.MM.DD、YYYY年M月D日 或 YYYYMMDD，經文可在標題或明確標示經文的說明欄行。

只取得進度範圍，經文仍取既有公版和合本；資料的 planSource 記錄實際影片網址，閱讀頁提供相符的來源連結。官網恢復時仍優先官網；同日已發布經文若相同，保留原始來源紀錄，若內容不同則拒絕覆寫。同日多支影片進度互相衝突也拒絕發布。兩個進度來源皆失敗、沒有今日影片或 Bible 原文下載／驗證失敗時，保留最後成功資料。

離線測試可搭配 `--youtube-feed-file feed.xml`。Actions → Update daily scripture 的 `verify_only` 選項只在暫存目錄驗證來源，不寫入 data/、不 commit/push；正式發布仍限 main。影片實際格式與 Actions 端讀取結果必須在上線前另行核對。
