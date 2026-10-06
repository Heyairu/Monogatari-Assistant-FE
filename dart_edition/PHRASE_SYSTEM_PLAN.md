# MonoAshi 短語系統規劃（Mosaic／Mention）

> 狀態：第 1–7 步已完成程式實作與自動化驗收；Windows 實機 IME／焦點操作仍需人工檢查。此文件以 2026-09-30 的專案架構為基礎。

## 1. 目標與參考

讓作者預先建立可重複使用的句子或段落，以短碼快速插入正文；短語內容可以包含 Mosaic 標記與連到專案對象的 Mention。常用情境包括人物稱謂、場景描寫、對話格式與連載固定段落。

大方廣漢書／文采公開介紹提到「片語功能、AZ 片語功能」：書記官在開庭前建立會用到的文字段落，再於記錄時快速輸入。這裡借用「事前準備、短碼觸發、鍵盤完成」的工作流；其內部代碼格式與資料結構沒有公開資料可證實，不照搬。

參考：[漢書 V11 片語快速輸入](https://dc.stone.com.tw/archives/1706)、[大方廣產品介紹](https://www.stone.com.tw/stone/web/product/product.jsp?dm_id=DM1465270114430)。

## 2. 產品決策

| 項目 | 第一版決策 |
| --- | --- |
| 名稱 | UI 使用「短語」；Mosaic 是內部系統名稱，正文功能仍稱「標記」 |
| 範圍 | 專案短語庫，跟著專案檔移動與備份；個人跨專案短語留待第二階段 |
| 插入模型 | 插入時將短語展開為正文 raw text；已插入內容不隨短語庫修改而改變 |
| 內容 | 多行文字、Mosaic 高亮、人物／地點／事件／伏筆／計畫／物品 Mention |
| 輸入 | 半形 `;;` 直接開啟短語 PoppinSense；既有 `\` 與 `/` 手動候選的第一層也保留「短語」入口。兩條路徑共用短語候選與插入流程 |
| 鍵盤 | 沿用 PoppinSense 的方向鍵選取與階層切換、Enter／Tab 接受、Esc 關閉；IME composing 期間不啟動或接受候選 |
| 失效連結 | 插入前顯示失效的 Mention；讓使用者重新連結、改為純文字或取消，不暗中指向同名對象 |

短碼在同一專案內唯一，忽略英文字母大小寫。短語候選以短碼前綴、內容和標籤搜尋，先顯示完全匹配，再依短碼排序。按 Esc 關閉候選後，已輸入的 `;;` 保留為字面文字。若 PoppinSense 已在設定中停用，編輯器不顯示短語候選，但仍可由短語庫管理與插入。

## 3. 作者流程

1. 在「短語庫」設定內容、短碼與標籤；標籤以 Chip 新增或移除。或選取正文後按「存成短語」。內容使用主編輯器的 PoppinSense 與 Mosaic 投影，Mention 僅呈現標誌及顯示文字。
2. 在正文輸入 `;;` 直接開啟短語候選，或輸入 `\`／`/` 並從 PoppinSense 第一層選「短語」。接著輸入短碼或內容篩選。候選列顯示短碼與投影後的內容預覽；Mosaic 部分只顯示標誌和顯示文字，另標出 Mention 數量及失效數量。
3. 選定後在游標或選取範圍處插入。若取代選取文字，先顯示正常取代行為；插入完成後游標停在短語結尾，整次插入可一次 Undo。
4. 在短語庫編輯、複製、停用或刪除短語；刪除不改動過去插入的正文。

範例：輸入 `;;arrive` 選取短語；短語內容可為：

```text
//!<c05404a8-8ff7-4df8-8db5-a738a14bb1f0|舊教堂>// 的鐘聲響起，//@<4e251fc2-1e2b-4f78-93da-91f8c76d9a92|艾莉絲>// 推開門。
```

實際序列化應由現有 `InlineAnnotationSyntax.format` 產生，不能自行拼接未跳脫的文字。

## 4. 資料模型

新增 `PhraseEntry`，欄位至少有 `id`、`name`、`shortcut`、`category`、`tags`、`body`、`enabled`、`createdAt`、`updatedAt`。編輯表單只顯示內容、短碼與標籤；`name` 由內容預覽產生，`category` 保留作舊資料相容欄位。`body` 儲存與章節相同的 Mosaic raw text，作為短語的唯一權威值；解析後的 Mention 清單和投影預覽只作衍生資料，不另存第二份。每個 `id` 為 UUID，供編輯、匯入及協作合併時穩定識別。

在 `ProjectData` 加入 `phrases`，依現有專案 XML 慣例新增 `<Type><Name>Phrases</Name>…</Type>` 區塊，短語 payload 自帶格式版本。舊專案沒有該區塊時讀為空庫；儲存／讀取須保留 `body` 的換行、跳脫字元及 Mosaic 語法。新增專案格式欄位時，同步納入快照、歷史、選擇性匯入及協作操作；不可只改 XML serializer。

第一版只允許**目前專案的 UUID Mention**。跨專案匯入短語時不沿用來源專案的 UUID：先以未連結狀態呈現，逐項由使用者選擇目標，或轉為純文字。匯入同 ID 的短語需要保留／覆蓋／複製為新 ID 的衝突選擇。

## 5. Mosaic 整合規則

- 建立或儲存短語時，以現有 `InlineAnnotationParser` 解析 Mosaic 標記，另加完整性檢查；目前 parser 會略過無效或未完成標記，單看解析結果不足以判定 body 合法。未完成語法可在編輯中保留，但不能啟用該短語；指出錯誤位置，不自動吞掉原文。
- Mention 必須保留 UUID、顯示文字、狀態、色碼與註記。不要將 `displayText` 轉回對象名稱，因為自訂顯示文字和人物別名都有意義。
- 插入前以 `InlineAnnotationTargetResolver` 檢查對象是否仍存在；無效 UUID 不以名稱猜測補連。插入後由現有 Mosaic projection 折疊顯示。
- 用 `MosaicEditingController.replaceRawRange` 做一次 raw 範圍替換；由 display selection 轉 raw range 時，沿用現有原子 Mention 邊界規則，不允許只替換半個 `//...//`。
- `;;` 只在普通正文的游標位置直接觸發短語 PoppinSense；`\`／`/` 沿用既有手動選單並提供「短語」入口。在 Mosaic raw 語法、Mention 詳情浮窗及 IME composing 中不觸發短語候選。貼上的觸發字元與查詢文字保持字面文字，避免意外批次展開。
- 正文搜尋、字數、讀者匯出仍使用 Mosaic reader/display projection；短語庫搜尋索引短碼、標籤和投影後內容。

## 6. 實作步驟與每步驗收

以下按依賴順序實作；每一步可獨立提交與驗收，下一步不應繞過前一步的資料規則。

### 步驟 1：短語領域模型與驗證

在 `lib/features/phrases/` 加入 `PhraseEntry`、短碼正規化、唯一性規則、`PhraseBodyValidator`、預覽投影及搜尋索引。第一版短碼限 1–32 個半形英數字、`_` 或 `-`，以小寫比較、保留原輸入顯示；中文可用內容或標籤搜尋。驗證器辨識完整 Mosaic 標記、疑似但不完整的標記及跳脫的字面 `//`，回傳帶 UTF-16 範圍的錯誤；Mention 對象存在性另外檢查，避免把已刪除目標誤判為語法錯誤。預覽沿用 Mosaic projection，不自行以正則剝語法。

**驗收**：中英混排、多行、跳脫、重複短碼、錯誤語法及全部 Mention 類型都有單元測試；無效 body 不能啟用。

### 步驟 2：專案持久化與狀態

將 `phrases` 接入 `lib/models/project_data.dart`、`lib/bin/file.dart` 的 `_ProjectParser`／`_ProjectMerger`、`project_state_providers.dart` 與 `project_snapshot_utils.dart`。XML 用現有 `<Type><Name>Phrases</Name>` 結構，payload 記錄版本與 UUID；缺少區塊視為空庫。更新專案建立、開啟、儲存、另存、備份、歷史還原與 dirty 狀態。保留未知或損毀 payload 的復原策略需先定義，避免一次存檔清掉原內容。

**驗收**：新舊專案往返、特殊字元與 Mosaic raw body 往返、備份與歷史還原均一致；修改短語會標記專案未儲存。

### 步驟 3：匯入與協作資料流

將短語納入 `selective_project_import.dart` 的可選模組，以及現有協作操作或專案快照同步路徑。以 `PhraseEntry.id` 對應同一筆；來源專案的 Mention UUID 不直接指向目標專案。若目前協作協定只能同步某些固定 record，先補短語操作與版本相容處理，再開放多人編輯短語庫。

**驗收**：選擇性匯入保留短語資料；跨專案匯入顯示未連結 Mention 並可修復；協作 record 能以穩定 ID 辨識短語變更。

### 步驟 4：原子插入服務

實作 `PhraseInsertionService`：輸入短語、目標專案資料、目前 raw revision、display selection 與觸發來源，輸出待確認的 Mention 問題、完整替換字串與 raw range。確認後再檢查 raw revision，避免對話窗開啟期間內容已變卻覆蓋新文字。正常插入只呼叫一次 `MosaicEditingController.replaceRawRange`；選區邊界沿用 Mosaic projection，不能切半個 Mention。失效連結採「重新連結／轉純文字／取消」，處理後重新驗證整段 body。

**驗收**：游標插入、取代選區、相鄰或跨越 Mention、多行與 IME commit、一次 Undo／Redo、對話期間正文變更，都有針對性測試。

### 步驟 5：PoppinSense 三個入口

擴充 `lib/features/poppin/mosaic_intellisense.dart`：`;;` 直接進短語查詢；原有 `\`、`/` 手動候選第一層加入「短語」分類。兩路共用短語搜尋、排序與候選資料，並在 session 中保存入口起點、查詢範圍及 raw replacement range。`PoppinNavigation.reset` 目前會清空階層，因此從手動選單進短語後，持續輸入查詢時須保留短語模式與選項階層；模式、游標位置或 raw revision 改變時才關閉或重建。`lib/bin/content.dart` 仍使用既有 `PoppinPanel`、方向鍵、Enter／Tab、Esc、焦點與浮層定位；短語候選交由步驟 4 插入服務處理，不能直接把 body 當普通 `candidate.insertText` 而略過驗證。

**驗收**：`;;查詢`、`\`→短語→查詢、`/`→短語→查詢三條路徑結果相同；Esc 保留字面輸入；貼上與 IME composing 不誤觸發；原有 Mosaic 候選不回歸。

### 步驟 6：短語庫介面與正文入口

加入短語庫列表、搜尋、建立／編輯、複製、停用、刪除；表單只提供內容、短碼和 Chip 標籤，內容欄位共用 Mosaic／PoppinSense 編輯與 Mention 詳情／重新連結行為。正文選取工具列加入「存成短語」，以選區對應的 raw 片段作初始 body；另保留可見的「插入短語」入口供不用觸發鍵的使用者。刪除短語需確認，但不改已插入的正文。停用短語不出現在候選中，仍能編輯與重新啟用。

**驗收**：純鍵盤可建立與插入短語；選取含 Mention 的文字儲存後重新插入，UUID、顯示文字、註記均不變。

### 步驟 7：整合驗收與效能

跑 Mosaic parser／projection、編輯器輸入、專案 XML、搜尋字數匯出、協作及專案匯入的相關測試。再以大型短語庫量測候選開啟、查詢與插入；索引只在短語庫變更時更新，不在每次按鍵重解析所有 body。最後執行靜態分析並做 Windows 實機 IME、鍵盤與焦點檢查。

**完成標準**：第 7 節所有情境通過，舊專案與既有 PoppinSense 行為維持正常。

### 第二階段

跨專案個人短語、具名欄位（如角色與日期）、匯入匯出及快捷鍵自訂。具名欄位需要明確的參數 UI 和新的模板語法，不混入第一版。

## 7. 驗收條件

- 舊專案開啟正常；新專案儲存、重開、備份與專案快照後短語內容完全一致。
- 插入包含多行、中文、跳脫字元與多個 Mention 的短語後，raw 語法可解析，畫面只顯示投影文字；一次 Undo／Redo 可完整還原。
- 選區跨越普通文字與 Mention 時，插入遵守現有原子邊界；IME 組字、遠端游標和協作同步沒有錯位。
- 目標重新命名仍指向原 UUID；目標刪除後需重新連結或轉純文字才能插入。
- 協作 typed record 以短語 ID 辨識新增、修改與刪除，不將短語變更混為普通正文更新。
- 候選在大型短語庫中仍能流暢鍵盤操作，且不每次按鍵都重新解析全部短語 body。

## 8. 已採用的第一版假設

- 短語先限專案庫，讓 Mention 的 UUID 語意明確；個人跨專案短語放到第二階段。
- 搜尋文字直接輸入在正文；接受候選時，連同 `;;` 或 `\`／`/` 的觸發文字一併取代，以維持 PoppinSense 的編輯器焦點與輸入手感。步驟 5 須以編輯器原型驗證。

## 9. 實作紀錄（2026-10-01）

- 步驟 1：`lib/features/phrases/` 已有不可變短語、版本化 codec、Mosaic 完整性驗證、reader 預覽及預先建立的搜尋索引。
- 步驟 2：短語已納入 `ProjectData`、專案 XML、provider、快照、歷史與資料遷移；未知或受損的 payload 會保留供復原。
- 步驟 3：選擇性匯入／匯出及協作 typed record 已接入短語資料。跨專案匯入的 Mention 即使 UUID 恰巧存在，也須在插入前明確重新連結。
- 步驟 4：`PhraseInsertionService` 已提供預備、失效 Mention 決策及一次性 raw 替換；選區碰到 Mention 時擴大到完整標記，對話期間正文變更則拒絕提交。
- 步驟 5：`;;`、`\` 與 `/` 已接入 PoppinSense 短語搜尋；手動選單進入後維持查詢模式，候選交由原子插入服務處理。Esc 保留字面觸發文字；貼上與 IME 組字不開啟短語候選。
- 步驟 6：編輯器提供短語庫與插入按鈕；短語庫支援搜尋、建立、編輯、複製、停用、刪除。表單只提供內容、短碼與 Chip 標籤；內容使用 Mosaic／PoppinSense 編輯器，Mosaic 內容在編輯器和預覽中只呈現標誌及顯示文字。選區工具列可將完整 raw Mosaic 片段存成短語。
- 步驟 7：短語、PoppinSense、兩種編輯器路徑、Mosaic、專案 XML／歷史、匯入、字數與協作相關自動化測試通過；2,000 筆短語庫的索引與 50 次查詢通過效能驗收。此次修改檔案的靜態分析無問題。Windows 實機 IME 與焦點仍需人工驗證。
