# Google 品牌網站連結

Google官方說明：https://support.google.com/cloud/answer/15549049 。外部正式應用程式需提供首頁、隱私權政策及服務條款連結；首頁須介紹功能，不能只是登入頁，並應連到同一份隱私政策。品牌／網域驗證與目標對象發布是不同狀態，不保證填連結後立即核准。

## 公開後填入（尚未公開前不要填成已可用）

| Google品牌欄位 | 網址 |
| --- | --- |
| 應用程式首頁 | https://eyebible.vercel.app/about/ |
| 應用程式隱私權政策連結 | https://eyebible.vercel.app/privacy/ |
| 應用程式服務條款連結 | https://eyebible.vercel.app/terms/ |

標誌先維持目前設定，不把上傳圖案當成公開政策頁的替代。若Google指出其他缺項，以View issues／必填訊息為準；需要網域驗證時再處理實際提示，不把不屬於自己的根網域任意加入。

這三個網站連結不是Google用戶端的redirect URI。既有Supabase OAuth callback與正式站回跳白名單保持原設定。

## 發布界線

測試分支有Vercel登入保護，不能把測試網址當成供Google公開審查的正式網址。已準備三頁及共用CSS；可用獨立的四檔變更，在使用者確認政策內容後先公開這些頁面，保留原正式App及每日經文資料。完整App另在PR10等待正式上線決定。

公開後驗證三個網址不需登入、HTTP200、頁面與政策連結互相可達，再填入Google。不要宣稱Vercel部署成功等於Google品牌審核成功。
