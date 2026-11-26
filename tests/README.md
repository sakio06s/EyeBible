# Annotation regression checks

The app remains a static `index.html`; these checks do not change its hosting setup.

With Node.js and Playwright installed:

```sh
npm install --no-save --package-lock=false playwright@1.62.1
npx playwright install --with-deps chromium webkit
node tests/annotations.cjs
node tests/presentation.cjs
node tests/daily.cjs
node tests/interface.cjs
node tests/social.cjs
node tests/refinements.cjs
node tests/login-mobile.cjs
LEGACY_ONLY=1 node tests/annotations.cjs
```

The script serves the actual HTML from an ephemeral localhost port. It checks Chromium and WebKit at six viewport sizes, including narrow phones, landscape and desktop, using the largest supported scripture font. It tests single-tap whole-verse selection, color/clear persistence, untouched legacy data, notes/tab transitions, keyboard activation, and unchanged scripture geometry/scroll position when opening, coloring, clearing or closing the toolbar. The second command simulates browsers that ignore dynamic viewport height units.

WebKit tests are engine checks, not a substitute for a final check on an actual iPhone with Safari's browser bars and software keyboard.

`presentation.cjs` checks the EyeBible name, visible Taiwan date (including a day boundary in another device timezone), exact sharing prompt, saved light/dark preferences, dark inputs, and legacy-note preservation in both engines.

`daily.cjs` checks dated and latest-file fetching, true verse numbering, stale/offline fallback, legacy snapshot isolation, frozen note drafts across midnight, historical note navigation, delayed responses without moving the reading, and malformed or changed snapshot rejection in Chromium and WebKit. Run the importer unit suite separately with `python3 -m unittest discover -s tests -p "test_*.py"`.

`interface.cjs` checks the annotated onboarding and reading-screen changes, compact retry control, local checkin names/avatars, circular centered photo uploads, and concise floating-toolbar/note titles.

`social.cjs` checks the real seven-day feed boundary in Taipei, private/own activity exclusion, unread persistence, inline reply drafts, Amen toggles, local member completion and glow levels 1–10, duplicate dates, missing-day decay, midnight rollover and narrow light/dark layouts.

`refinements.cjs` verifies 20% smaller logo with transparent dark treatment, equal annotation buttons, concise prompts, one group composer, historical reading dates/full verse excerpts, and visible emoji pixel centering.

## Account and private cloud storage

`node tests/cloud-core.cjs` checks stable record encoding and three-way merging, including deletions and conflicts. `node tests/cloud-ui.cjs` uses the real locally vendored Supabase SDK with mocked Auth/PostgREST endpoints to check OTP, import consent, independent updates, conflict choices, offline retry, logout and account isolation. These tests never send real email.

Run `sh tests/cloud-db.sh` only against the disposable `eyebible-cloud-test` Docker container described in [cloud setup](../docs/cloud-setup.md). It rebuilds that test database schema and checks actual PostgreSQL RLS, per-user isolation and optimistic revisions. Never run the database harness against a production database.

`login-mobile.cjs` checks actual touch/keyboard entry in mobile Chromium and WebKit contexts and simulates iOS visual viewport shrink/pan. Email and OTP remain visible on short keyboard viewports without scrolling the app underneath. This is not a physical iPhone software-keyboard test.

`google-login.cjs` checks Google-only mode, disabled-provider readiness messaging, retry after backend activation, minimal identity scopes, account selection and PKCE redirect parameters without contacting real Google or requesting Email OTP.

`node tests/cloud-devices.cjs` opens independent Chromium and WebKit storage contexts against a shared simulated cloud API. It uses the shipped SDK and real UI to verify verse highlights, private notes and checkins arrive on the second device, independent concurrent edits survive merging, another account sees none of these records, and logout clears the displayed workspace. This is a deterministic integration test, not evidence of real Supabase account synchronization.

## Invite-only shared groups

`sh tests/groups-db.sh` resets only the disposable `eyebible-cloud-test` database, runs private isolation tests and applies `cloud/groups.sql`. It checks 30-day expiry/rotation, membership/blocking, cross-group and anonymous denial, author/leader operations, duplicate retries/tombstones, archive retention and keyset pagination. Never use this harness against the live project.

`node tests/groups-ui.cjs` runs the shipped app/group module in Chromium and WebKit with a simulated account bridge/API: create, invitation preview/join, private/public separation, replies/Amen/completions, ambiguous network delivery followed by reload/retry, dated archive pagination, and delayed responses after signout. `cloud-devices.cjs` also exercises the real shipped SDK/account subscription with the groups flag enabled. These do not replace the two-real-account acceptance steps in [group setup](../docs/groups-setup.md).

`node tests/groups-edge.cjs` covers all independent review fixes: semantic scripture identity and conflicting-version isolation, group/session-bound drafts with private-draft preservation, per-operation multi-tab outboxes, delayed old-group pagination, refreshed expanded feeds, retained archive pages/replies, Taipei reply dates, photo DOM reuse and ungrouped personal checkins. `groups-db.sh` includes `groups-payload.sql` for bounded photo/unseen payloads and `groups-races.sh` for concurrent joins. SQL set-operation receipt tests prove an acknowledged-but-lost operation cannot undo a newer opposite choice.

`node tests/scripture-api.cjs` verifies the fixed-source preview scripture proxy, date validation, malformed upstream and offline behavior. `node tests/daily-preview.cjs` verifies a frozen preview branch still reads today from canonical main data and retains correct-day checkins/annotations on outage. `tests/feed-ten.sql` checks 10-post all-history/latest-activity pages and reply Amen isolation/receipts; it runs after the existing group database suite. `node tests/feed-ten-ui.cjs` checks reply Amen/tap treatment, ten-post automatic appends and roster access in Chromium and WebKit.

`feed-five-ui.cjs`：Chromium／WebKit 觸控模式驗證淺／暗色阿們透明、SVG／留言節點與捲動保持、鍵盤焦點、5→10→15 明確按鈕追加、小組設定位置、自己回覆與背景輪詢置頂（含舊讀取與新回覆重疊）。`feed-ten-ui.cjs` 保留為同一測試的相容入口；資料庫的十筆游標仍由 `feed-ten.sql` 驗證。

`pull-refresh.cjs`：取消5000ms輪詢；阿們與回覆的數字間距；頂端下拉72px放開更新；短拉／橫向／多指／取消／收回／最後touchend座標與觸點／放開時已離開頂端；編輯與其他分頁不攔截；更新中合併、失敗保留／重試、已展開數量保留。Chromium以原生CDP觸控補驗，WebKit使用合成Touch Events驗證狀態機。

`composers-feedback.cjs` 驗證固定發文列、獨立純文字分享、無經文與重載隔離、等距按鈕、私人讀經筆記、小組標題、回報表單與固定重試內容。`feedback-auth.cjs` 使用實際帳號模組及SDK fixtures，驗證各帳號Bearer與登出後的回報草稿／回應隔離。本版本不使用Email。

`support-db.sh` 在隔離Postgres測試升級與管理者／回報者／匿名邊界、去重、已讀、處理／刪除及持久限流；`support-ui.cjs` 透過相同隔離資料庫驗證Chromium管理者與WebKit組員、首頁／導覽／頭像提醒、日期／提供者、分頁與換帳號清除。`activity-ui.cjs` 驗證新直接分享超過多篇舊回覆、送出後定位與重載後歷史保留。

`support-seed.py` 驗證未確認Email與非Google身份不能被私有升級指定為管理者；`activity-index.sql` 用EXPLAIN確認最新互動游標可直接走索引。`support-ui.cjs` 另覆蓋多頁讀取中關窗／換管理者帳號停止後續RPC與開窗鍵盤焦點。

`recent-reading.cjs` 驗證今天／昨天／前天原生選單、台北跨月／年、補讀快取與日期別筆記／標註／小組簽到、快速操作與失敗重試、換帳號，以及所有歷史入口的補簽窗口；`recent-reading-edges.cjs` 驗證正式每日與共享快照區分、筆記跳轉取消舊請求、背景fallback隔離、午夜忙碌清理、寫作中延後載入、精確選項文字與帳號載入提示。兩者執行Chromium／WebKit。

`member-streak.cjs` 驗證本機／雲端小組頭像狀態：連續1～3天與4天以上、1000天不封頂、中斷／重複／未來／無效日期、補簽接回、跨日與無障礙文字；10級發光、綠色／金黃色切換、30天獎牌與漏讀滿3個完整日失效。Chromium／WebKit皆執行。

`public-info.cjs` 驗證公開介紹／隱私／條款在無JavaScript、亮暗色320px畫面可讀，沒有SDK／Auth依賴、首頁政策互鏈、歡迎／設定入口、個資說明與刪除後伺服器保留原文的揭露。Chromium／WebKit執行。

`python3 -m unittest discover -s tests -p "test_*.py"` 包含官網優先／指定 YouTube 頻道備援、日期／參考範圍／頻道驗證、來源恢復後不可變紀錄、CLI 錯誤不覆寫。`node tests/progress-source.cjs` 驗證來源連結與不可信 URL 拒絕。

`node tests/group-creation-gate.cjs` 驗證管理者建立權限、一般／升級缺漏預設關閉、邀請加入、跨帳號與過期管理者能力、權限拒絕提示。`sh tests/maintenance-db.sh` 只使用 `tagbible-maintenance-test` 隔離容器，執行實際合併維護 SQL，驗證盤點保護、私有備份、資料保留、延遲重送及資料庫權限。

`edit-ui.cjs` checks owner-only note/post/reply editing, personal/shared synchronization, immutable metadata, failed-save draft preservation, cancel/account cleanup and uniform single-line roster fonts in Chromium/WebKit. `edit-text.sql` runs only in a disposable PostgreSQL fixture after `cloud/upgrade-text-editing.sql` and verifies author enforcement (including group-leader rejection), optimistic conflict detection, idempotency, personal-copy sync/privacy, deleted content and anonymous access.
`edit-rpc-integration.cjs` uses the shipped Supabase SDK and account wrapper to verify authenticated edit RPC forwarding and the allowlist. `cloud-devices.cjs` also verifies a private-note edit reaches an independent WebKit device.
