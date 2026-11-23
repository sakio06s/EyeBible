# 日期選擇與補讀

使用者已指定：今日讀經上方日期可點擊，旁有不醒目的小箭頭，選單只提供「今天、昨天、前天」（後續更正取消大前天）。選取後顯示對應日期與經文，可補簽、標註／筆記；紀錄與既有雲端依選取日期保存。

沿用原生select覆蓋在日期觸控區，文字日期保留time元素與現有ID，箭頭低對比。原生選單已有手機、鍵盤與輔助科技行為；自製浮窗與額外月曆無本次需求。台北日期計算跨月／年。指定日期只接受同日期經文或有效快取；失敗留在原閱讀並顯示錯誤，不以今天資料冒充過去。不把背景今日請求結果切換到補讀；快速選擇只採用最後一次操作。既有歷史足跡任意日期閱讀仍保留絕對日期，帳號切換取消舊請求。今日自動刷新與午夜更新維持原行為。

Latest user constraint: all scripture entry points (picker, footprints, shared scripture) permit completion only 今天／昨天／前天; older readings remain readable/annotatable, existing completion retained read-only. Central UI handler and disabled state must enforce range. Existing dated storage/sync remains compatible; no SQL migration.
