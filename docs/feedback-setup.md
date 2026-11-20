# 問題回報寄信設定

介面與 `/api/feedback` 已準備；尚未提供管理者收件地址／寄信憑證，不能把程式測試成功視為真實寄達。使用者回覆既有服務後可調整寄信介接；目前準備的是 Resend REST API，不需要更動小組 SQL。

在 Vercel 專案 Settings → Environment Variables 設定，只設在伺服器環境，避免使用 PUBLIC／NEXT_PUBLIC 前綴：

| 名稱 | 值 |
| --- | --- |
| `REPORT_TO_EMAIL` | 管理者實際收件 Email，不會送到瀏覽器 |
| `RESEND_API_KEY` | Resend 寄信用 API key，只在 Vercel 後台輸入，不貼在聊天／GitHub |
| `REPORT_FROM_EMAIL` | 選填，已驗證寄件者，例如 EyeBible <reports@自有網域>；未設定採測試寄件地址 |
| `SUPABASE_URL` | 選填，預設目前 EyeBible 專案；若更換專案需同步設定 |
| `SUPABASE_PUBLISHABLE_KEY` | 選填，對應的公開驗證 key；不需要 service_role |

目前檢查的是 Preview，請選 Preview 範圍。正式上線時再補 Production。儲存環境變數後需重新部署，才會進到新的 Serverless Function。

未驗證寄件網域時，預設 `onboarding@resend.dev` 只能寄給 Resend 帳號本身的 Email。因此若只收管理者自己，可先以同一個地址建立 Resend 帳號並驗收；若收件地址不同，必須依 Resend 指示驗證自己的寄件網域並設定 FROM。Vercel 免費子網域不提供該網域的 DNS 管理權。[Resend 官方說明](https://resend.com/docs/knowledge-base/403-error-resend-dev-domain)（2026-11-20 查核）。

完成設定後，以另一位已登入的組員在「我的設定 → 問題回報」送出一則測試內容。確認介面顯示已送出、管理者信箱實際收到，並檢查垃圾郵件資料夾。寄件服務接受郵件與收件匣實際寄達是兩件事，需要完成這次實際驗收。

## 現有保護與界限

API 只接受已登入者的 Bearer token，並向 Supabase 驗證身分。收件者固定讀取伺服器設定，忽略瀏覽器提供的 `to`。內容為純文字、限制2000字，不傳送私人筆記、完整個人狀態或 OAuth URL。寄件憑證與收件者不回傳前端。

不確定是否成功時會保留原稿與操作ID，重試使用相同郵件內容／Resend idempotency key，在服務商的去重有效期間防止重複寄出。每個執行個體還有每帳號10分鐘5則的基本限流；這是 serverless 單個執行個體的保護，並非跨所有執行個體的持久全域限額。未設定服務時顯示尚未啟用，保留輸入以便稍後重試。
