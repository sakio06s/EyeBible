# TagBible 上線更名切換清單

## 目前狀態

App HTML／字標／介紹／隱私／條款已改成 TagBible。2026-11-23 已確認 GitHub 更名為 [sakio06s/TagBible](https://github.com/sakio06s/TagBible)，repository ID 1460893685 不變，分支與 PR 保留；本機 remote 與每日經文 API canonical repository URL 同步更新。

正式網址 https://tagbible.vercel.app/ 已由擁有者完成綁定，檢查 HTTP200；在新版部署前仍為 EyeBible v0.9.2。擁有者已同意部署 TagBible 新版；目前正驗證 PR10 合併結果，完成後以實際 production HTTP 回應確認。Google 品牌／Supabase Site URL 與 redirect allowlist 後台尚未驗證，不宣稱登入回跳已切換。

每日經文來源在 2026-11-23 顯示「每日經文系統維護中」，沒有當日 range；因此 importer 拒絕發布，保留 2026-11-20 最後成功資料。不可把舊經文改日期冒充今天。

## 切換順序

1. Vercel 現有專案 Settings → General：Project Name 改 tagbible。Domains 明確新增／確認 tagbible.vercel.app 是否可用；專案名稱變更不代表網域已變更。若已被使用先回報，不另選名稱、不購買網域。保留原網址到新站與登入驗證完成。
2. GitHub 已完成更名 TagBible，同一 repository ID、歷史、分支、PR、Actions 保留。後續需在 Vercel 確認 Git integration 指向此儲存庫。
3. Google Cloud 原專案顯示名稱改 TagBible；Project ID 通常不能改，不重建 OAuth 憑證。Google Auth Platform → Branding 名稱 TagBible；Clients 的顯示名稱 TagBible Web。保留同一 Client ID／Secret、基本 scopes 與發布設定。JavaScript origins 加上實際取得的新正式／預覽 origin。
4. Supabase 原專案顯示名稱改 TagBible。Authentication → URL Configuration：取得新網址後 Site URL 改新正式網址，Redirect URLs 增補新正式／實際預覽網址（精確值，不加全域萬用字元），過渡期保留舊站。Google provider 設定與 callback 維持 https://mddbzoagloktnwoszuvj.supabase.co/auth/v1/callback 。Project reference／API URL 不是品牌名稱，不可直接替換成 tagbible。
5. 準備新版正式部署並保留可回復版本，核對 main 每日經文最新資料，不能用較舊預覽 JSON 蓋掉排程資料。正式部署與公開政策發布另須確認切換狀態；目前沒有合併完整候選 App。
6. 新站公開後，驗證 /about/、/privacy/、/terms/ 無需登入 HTTP200，再把 Google Branding 的網站連結改成同站新網址；網域驗證依 Google 實際提示處理，不填不屬於自己的 vercel.app 根網域。
7. 新 origin 的瀏覽器儲存與登入 session 不會從舊 origin 自動搬移。已同步使用者在新站重新 Google 登入可取回同帳號雲端紀錄；只有本機的紀錄先在舊站備份／同步，不能宣稱換網址會自動帶入。驗證跨帳號隱私、小組成員、私人筆記、標註、簽到與每日經文後，再設定舊站導向，避免導向環路及 OAuth 回跳失敗。

## 相容名稱

eyebible.* storage/session/event keys、EyeBibleApp 等 JS bridge、已部署的 eyebible_* 資料表／RPC 與舊 SQL 檔案是相容識別碼，非對外品牌。現階段保留以讀取既有資料；如要求連內部識別碼清零，需先備份並設計資料／RPC／RLS 的分階段遷移，不能全文取代後直接上線。舊驗證文件保留當時版本名稱以維持紀錄準確。

## 操作者界線

可直接準備程式與文件；Vercel／Supabase／Google 需要已登入的管理者工作階段。GitHub rename 需要擁有者在後台操作或具 repository administration 寫入權限的整合。不要把密碼、驗證碼、Client Secret 或 service_role key 貼入聊天或前端。
