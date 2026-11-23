# TagBible Google 登入與個人雲端儲存

目前採用 Google 登入。測試分支已連接 Supabase 公開設定；正式網站待真實 Google 登入與跨裝置同步驗證後才啟用。本階段僅同步個人資料，不共享其他組員或私人筆記。

Google 登入不使用 Supabase 的 Email 驗證碼寄信服務，也不要求購買自有網域。Supabase、Vercel 的免費額度仍各自適用。

## 既有專案更名

現有專案請依[更名切換清單](tagbible-launch-rename.md)修改顯示名稱，不要重建專案、金鑰或資料庫。下方舊網址是目前沿用的登入設定；新網址確認可用後才增補／切換，暫時保留舊網址供過渡。

## 1. 建立 Google Cloud 專案

1. 開啟 https://console.cloud.google.com/ ，使用你的 Google 帳號登入。
2. 在上方專案選單選擇新增專案，命名為 `TagBible`。
3. 本次只設定 Google Auth Platform 的 OAuth 登入，不需要啟用付費 API、建立計費帳戶或申請付費試用。

## 2. 設定 Google Auth Platform

在選好的 TagBible 專案中，開啟 Google Auth Platform；第一次使用時按 Get started（開始設定）。若看到舊版選單，對應位置是 APIs & Services 的 OAuth consent screen 與 Credentials。

- Branding：應用程式名稱 `TagBible`，支援信箱及開發者聯絡信箱填你的信箱。
- Audience：一般組員使用個人 Google 帳號，選 External（外部）。測試階段先把你要測試的 Google 信箱加入 Test users。
- Data Access：只使用 `openid`、`userinfo.email`、`userinfo.profile` 這些基本身分範圍，不需要 Gmail、Drive 或其他 API 權限。
- 外部正式版請先依[品牌網站連結](google-branding.md)準備公開首頁、隱私權政策與服務條款；品牌與網域驗證及 Audience 發布狀態，依Google後台的實際提示完成。

## 3. 建立 OAuth 用戶端

在 Google Auth Platform → Clients（或 Credentials → Create credentials → OAuth client ID）：

- Application type：Web application。
- 名稱：`TagBible Web`。
- Authorized JavaScript origins：

```text
https://eyebible.vercel.app
https://eyebible-git-codex-account-cloud-shane-lin.vercel.app
```

- Authorized redirect URIs：必須精確填入以下 Supabase 回呼網址，沒有結尾斜線。

```text
https://mddbzoagloktnwoszuvj.supabase.co/auth/v1/callback
```

建立後會得到 Client ID 與 Client Secret。Client Secret 只填入 Supabase 後台，不要貼到聊天、前端程式或 GitHub。

## 4. 在 Supabase 啟用 Google

進入 TagBible 專案 → Authentication → Sign In / Providers → Google：

1. 開啟 Google 登入。
2. 把 Google 的 Client ID 與 Client Secret 貼到對應欄位，儲存。
3. 保留原有安全選項，不需要停用 nonce 等驗證。
4. 確認此處顯示的 Callback URL 與 Google 用戶端的 Authorized redirect URIs 完全一致。

Authentication → URL Configuration：

- Site URL：`https://eyebible.vercel.app`
- Redirect URLs 加入以下兩個完整網址：

```text
https://eyebible.vercel.app/
https://eyebible-git-codex-account-cloud-shane-lin.vercel.app/
```

測試網址必須在允許清單內，否則登入後可能回到尚未啟用雲端的正式網站。測試版受 Vercel 存取保護，需先以部署者帳號通過 Vercel 登入。

## 5. 個人資料表與公開連線設定

已準備的 [cloud/schema.sql](../cloud/schema.sql) 需在 Supabase SQL Editor 執行。可重跑，不刪除既有紀錄。

`personal_states` 啟用 RLS。登入帳號只能讀自己的資料，寫入函式根據 `auth.uid()` 與預期版本處理，前端沒有管理權限。

`cloud/config.js` 只保存 Supabase Project URL、Publishable key 與 `authMode:'google'`。不要放 Google Client Secret、資料庫密碼或 Supabase Secret/service_role key。

## 6. 實際測試

1. 先使用 Safari 或 Chrome 開啟測試網站，避免某些 App 內建瀏覽器阻擋 Google 登入。
2. 我的設定 → 登入 → 使用 Google 登入。後台未啟用時，網站會明確提示設定尚未完成，不會導向壞掉的登入端點。
3. 選擇已加入 Google Test users 的信箱完成登入。
4. 第一次登入選擇是否匯入本機資料；未選擇前不自動上傳。
5. 建立私人筆記及經文標註，等顯示「已同步到雲端」。
6. 第二個瀏覽器登入同一個 Google 帳號，確認同步；修改一筆，再回原瀏覽器按立即同步。
7. 登出應回到原本的訪客資料，其他帳號不能看到帳號專有筆記。

Google 登入不會寄送 TagBible Email 驗證碼；Google 本身的帳號安全檢查仍依它的流程進行。發布給一般組員前需確認 Google Audience 設定及實際授權結果。

## Email 驗證碼（目前不啟用）

先前的 Email 入口保留於程式作相容性測試，但設定改為 Google。若未來再啟用 Email：Free 使用內建寄信時無法自訂範本；需自訂 SMTP，或使用 Supabase 提供的付費範本方案。內建寄信僅適合專案團隊測試，不能當成一般組員的正式寄信服務。

## 開發測試

```sh
node tests/cloud-core.cjs
node tests/cloud-ui.cjs
node tests/login-mobile.cjs
node tests/google-login.cjs
```

瀏覽器測試使用正式版本 SDK 與模擬 Auth/PostgREST/Google 導向回應，不寄送郵件，也不登入真實 Google 帳號。

資料庫測試只使用本地隔離 PostgreSQL，不要指向正式專案：

```sh
docker run --name eyebible-cloud-test --network none \
  -e POSTGRES_PASSWORD=local-eyebible-tests-only -d postgres:17-alpine
sh tests/cloud-db.sh
docker rm -f eyebible-cloud-test
```

資料庫測試會重建測試容器的 public schema。正式專案只執行 `cloud/schema.sql`。
