# EyeBible 登入與個人雲端儲存設定

程式支援 Email 驗證碼及個人跨裝置同步。目前 `cloud/config.js` 保持空白，正式網站仍使用本機紀錄。完成以下設定後才啟用；這一階段不共享其他組員或私人筆記。

## 1. 建立免費專案

1. 用 Safari 開啟 https://supabase.com/dashboard ，建立 Supabase 管理帳號（可用 GitHub）。這是管理後台帳號；EyeBible 的使用者仍使用 Email 驗證碼登入。
2. 建立免費方案的 Organization，再選 New project。
3. 名稱輸入 `EyeBible`，產生並自行保存 Database password。區域可選 Singapore 或可用的鄰近區域。
4. 等待專案建立完成。

## 2. 建立個人資料表與權限

1. 開啟專案的 SQL Editor → New query。
2. 複製本儲存庫 [cloud/schema.sql](../cloud/schema.sql) 的完整內容，貼上執行。
3. 執行成功後會有 `personal_states` 表及 `save_personal_state` 函式。SQL 可安全重跑，不會刪除既有紀錄。

此表啟用 RLS。登入帳號只能讀自己的資料；寫入函式會根據登入身分與資料版本處理，前端不持有管理權限。

## 3. 設定 Email 驗證碼

1. 在 Authentication 的登入方式設定啟用 Email。
2. 在 Email templates 的 Magic Link 與 Confirm signup 範本中，讓內文包含以下內容（新帳號及既有帳號都要能看到驗證碼）：

```html
<h2>EyeBible 登入驗證碼</h2>
<p>你的驗證碼是：<strong>{{ .Token }}</strong></p>
<p>請回到 EyeBible 輸入驗證碼。</p>
```

3. Authentication → URL Configuration 的 Site URL 設為 `https://eyebible.vercel.app`，Redirect URLs 加入 `https://eyebible.vercel.app/`。
4. Supabase 內建寄信適合對專案管理員／團隊信箱測試，有收件者與寄送額度限制。開放一般組員前，需要在 Auth 設定自訂 SMTP，並確認寄件網域驗證完成。可先用管理帳號的信箱完成第一次測試。

## 4. 連接網站

從專案的 Connect／API 設定頁取得：

- Project URL，例如 `https://你的專案編號.supabase.co`
- Publishable key，以 `sb_publishable_` 開頭（也支援舊版 `anon` key）

這兩項為瀏覽器可使用的公開設定，可提供給開發者填入 `cloud/config.js`。Database password、`sb_secret_...` 或 `service_role` key 不需要提供給網站，請勿填入此檔案。

```js
window.EYEBIBLE_CLOUD={
  url:'https://你的專案編號.supabase.co',
  publishableKey:'sb_publishable_你的公開金鑰',
  authMode:'email'
};
```

提交部署後，設定頁與初次設定頁的登入按鈕會啟用。真實專案尚未設定前，不能把模擬測試通過視為已能登入。

## 5. 實際驗證

1. 用設定好的測試信箱取得驗證碼，回 EyeBible 輸入。
2. 第一次登入時選擇是否匯入本機資料。未選擇前不會自動上傳。
3. 建立一筆私人筆記並標註經文，等待顯示「已同步到雲端」。
4. 另一個瀏覽器登入相同帳號，確認資料完整；再修改一筆並回原瀏覽器按立即同步。
5. 登出後顯示原本的訪客資料，不應顯示只有帳號內才有的筆記。
6. 用另一個帳號確認不能讀到第一個帳號的私人紀錄。

「已同步」需要網路往返成功；離線時仍保存本機快取。兩個裝置修改同一筆資料會要求選擇版本，不直接覆寫。清除本機資料需先登出，避免把清除裝置誤當成刪除雲端紀錄。

## 開發測試

```sh
node tests/cloud-core.cjs
node tests/cloud-ui.cjs
```

`cloud-ui.cjs` 使用正式版本 SDK 與模擬 Auth/PostgREST 回應；不寄送真實郵件。資料庫測試使用本地隔離 PostgreSQL，不能指向正式專案：

```sh
docker run --name eyebible-cloud-test --network none \
  -e POSTGRES_PASSWORD=local-eyebible-tests-only -d postgres:17-alpine
sh tests/cloud-db.sh
docker rm -f eyebible-cloud-test
```

資料庫測試會重建測試容器的 public schema。正式專案只執行 `cloud/schema.sql`。
