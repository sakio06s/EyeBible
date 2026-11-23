# 發布前清空測試留言及限制建立小組

正式站是 TagBible。本次資料清除範圍已由擁有者確認：所有小組留言13、回覆4、留言阿們3、回覆阿們1、足跡中的非私人筆記／分享14。私人筆記、標註、簽到、小組、成員、帳號、問題回報與既有操作收據保留。

## 實際操作

1. 所有測試帳號先在「我的設定 → 我的小組」捨棄尚未送出的內容，關閉 TagBible 分頁／App。未送出的本機草稿不在已盤點的雲端筆數內。
2. 開啟完整合併SQL：[2026-11-23-launch-preparation.sql](https://raw.githubusercontent.com/sakio06s/TagBible/main/cloud/maintenance/2026-11-23-launch-preparation.sql)，複製全部內容。
3. 開啟 [Supabase SQL Editor](https://supabase.com/dashboard/project/mddbzoagloktnwoszuvj/sql/new)，貼上並執行。這是實際清除操作；需要資料庫管理者工作階段。不要在未知／其他專案執行。
4. 若筆數已改變，整個交易會停止並回滾，輸出 Expected / found；先重新盤點，不要移除保護條件強行執行。
5. 成功結果的 visible_posts、visible_replies、post_amens、reply_amens、public_history_copies 均應是0。記下 private_backup_run。重新開啟網站並登入／同步，確認留言板與足跡公開分享清空、私人筆記／標註／簽到／成員保留。

這份合併檔同時啟用「僅管理者建立小組」。管理者使用既有問題回報管理者資格，不等同一般組長；沿用現有單一小組成員規則。非管理者顯示尚未開啟；邀請碼加入功能正常。新能力RPC只回傳能否建立的布林值，資料庫觸發器亦會拒絕一般登入者透過舊版或自行呼叫API建立。未套用SQL時前端預設關閉，但後端限制仍待資料庫管理者執行。

## 備份與清除語意

原有公開內容先存入 `tagbible_maintenance_private.discussion_backup`，開啟RLS且移除一般角色權限；不對App一般使用者開放。私人個人筆記不會複製到備份。私人備份供管理者必要時復原，並非永久抹除所有伺服器副本。

公開留言／回覆清除內容後保留deleted tombstone ID，避免舊裝置已送出但未收到回應的重試復活留言。因此原始table筆數仍可能顯示13／4，應以上述visible欄位與App顯示判定清空。阿們與舊已讀標記清空。個人雲端刪除非私人筆記及舊公開互動副本，revision增加讓既有裝置合併刪除；不重設帳號或整份個人payload。若有編輯衝突，先保留雲端清除結果，再核對私人內容，不要盲目選擇舊本機公開分享。

正式資料庫尚未由代理執行清除；程式部署不會自動執行這份SQL。獨立的可重跑權限升級檔為 `cloud/upgrade-admin-group-creation.sql`。一次性清除檔與合併檔含相同清除內容，兩者擇一，勿重複執行。

## 隔離驗證

`tests/maintenance-db.sh` 僅針對固定名稱 `tagbible-maintenance-test` 的網路隔離PostgreSQL容器，重建其測試資料，不能傳入正式連線。驗證合併SQL實際產物、所有保留資料、私有備份權限、延遲重試、revision衝突、偽造／一般／匿名拒絕與管理者成功，重複執行因筆數保護停止。`tests/group-creation-gate.cjs` 驗證一般／管理者／升級缺漏／過期能力與跨帳號回應，及邀請碼加入介面。
