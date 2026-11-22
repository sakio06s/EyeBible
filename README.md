# TagBible
## 登入與個人雲端儲存

程式已加入個人雲端同步，測試分支已連接 Supabase；正式網站待真實登入與同步驗證後才啟用。依 [雲端設定](docs/cloud-setup.md) 建立專案、執行資料表 SQL 及設定 Google OAuth 登入，再填寫公開連線設定後啟用。此階段同步個人資料，小組跨帳號共享尚未啟用。

## HTML 改名階段

目前測試版顯示名稱為 TagBible，使用提供的 TagBible 字標。網址、Google／Supabase／Vercel 專案及內部儲存識別碼沿用原設定；正式發佈仍暫停。

改名檢查：`node tests/brand-rename.cjs`。驗證範圍見 [改名驗證](docs/verification/2026-11-22-tagbible-html-rename.md)。
