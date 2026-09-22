# Quill 純文字正文編輯器：Phase 0 規格

**狀態：完成**  
**範圍：** Quill 僅替換正文輸入 UI；本階段不新增 Quill UI 或改動正文資料格式。

本文件是 [Quill 純文字正文編輯器替換計畫](QUILL_PLAIN_TEXT_EDITOR_PLAN.md) 的 Phase 0 可執行契約。後續實作、測試與 code review 均以本文件為準。

## 1. 不變條件

1. `ChapterData.chapterContent` 繼續是正文唯一的持久化真實來源，型別仍為 `String`。
2. `editorContentProvider`、XML `<Content>`、Markdown 匯出、閱讀模式與 P2P 協作仍只接收純文字。
3. Quill `Document`、Delta、attribute、embed 與 toolbar 狀態均為 UI 暫態資料；不得寫入專案格式或協作協定。
4. 在 feature flag 關閉時，使用既有 `CodeField` 流程，資料與行為不變。
5. Quill 純文字版不提供任何可保存的格式化控制項；圖片、影片、連結、表格與自訂 embed 均不接受為文件內容。

## 2. 編輯器模式與 feature flag

後續 Phase 3 應新增 app-local、預設為 `false` 的 feature flag，例如 `quillPlainTextEditorEnabled`。

- 此 flag 不寫入 `.mnproj`、XML、P2P payload 或專案快照。
- 此 flag 只選擇渲染與輸入控制器，不能改寫 `chapterContent`。
- 關閉 flag 或初始化 Quill 失敗時，必須安全回退到既有 `CodeField`。
- Phase 2 的 PoC 應使用獨立入口，不得改變正式編輯器的預設路徑。

## 3. 正文與 Quill 文件轉換契約

### 3.1 名詞

- **raw text：** `chapterContent` 與協作、匯出所使用的純文字。
- **editor text：** Quill 文件的純文字序列；Quill 文件必須以一個終止段落換行結束。
- **sentinel newline：** 只為滿足 Quill 文件結構而附加的最後一個 `\n`；它不是正文內容。

### 3.2 載入

`PlainTextQuillAdapter.fromPlainText(rawText)` 必須：

1. 將 `\r\n` 與單獨 `\r` 轉為 `\n`，做為 Quill 內部表示。
2. 在結果後附加**恰好一個** sentinel newline。
3. 以未格式化的純文字 insert operations 建立 `Document`；不得建立 attribute 或 embed。
4. 不得在載入、章節切換、focus、selection 變動或 feature flag 切換時回寫 Provider、標記 dirty 或建立協作操作。

範例：

| raw text | editor text |
|---|---|
| `""` | `"\n"` |
| `"第一行"` | `"第一行\n"` |
| `"第一行\n"` | `"第一行\n\n"` |
| `"甲\r\n乙"` | `"甲\n乙\n"` |

### 3.3 輸出

`PlainTextQuillAdapter.toPlainText(document)` 必須：

1. 拒絕或移除所有 attribute 與 embed，僅取出文字內容。
2. 僅移除文件最後一個 sentinel newline；原正文所含的尾端空行必須保留。
3. 以 `\n` 作為輸出的標準換行符。
4. 若文件不符合「以一個終止段落換行結束」的契約，拒絕輸出並回報可診斷錯誤；正常的 `Document.fromDelta` 建構流程會在開發模式先行驗證此結構。

因此，含有 CRLF 的既有正文在**第一次實際文字修改並寫回後**會成為 LF；但只開啟、瀏覽或切換章節絕不可觸發這個正規化寫回。此規則避免無使用者變更時產生 dirty state、歷史快照或 P2P delta。

### 3.4 Offset 與 selection

- 本版本的 raw text 與 Quill editor text 都以 Dart UTF-16 code-unit offset 計算；這符合 Flutter 的 `TextSelection`。
- 已使用 LF 的正文，raw offset 與 Quill offset 相同。含 `CRLF` 或單獨 `CR` 的既有正文因為 Quill 內部採 LF，必須透過 adapter 的雙向 offset 映射轉換；呼叫端不得假設兩者相同。
- sentinel newline 的 offset 是 `rawText.length` 之後的一個額外位置，不能用於正文游標、搜尋結果、校稿範圍或協作游標。
- Phase 1 adapter 必須提供明確的 clamp／轉換 API，呼叫端不得自行加減 sentinel 長度或處理 CRLF 差異。
- emoji 與組合字元的 offset 契約以 Flutter 現有 `TextSelection` 語義為準；字素群集導覽與刪除行為由 Quill／Flutter widget 實測保障。

## 4. 貼上、格式化與外部內容

| 來源 | 本版本行為 |
|---|---|
| 純文字貼上 | 插入文字；輸入中的 `\r\n`／`\r` 於 adapter 輸出時正規化為 `\n`。 |
| HTML／RTF 貼上 | 僅取可見純文字；忽略字型、顏色、粗斜體、連結與段落格式。 |
| 圖片、影片、檔案 | 不插入 Quill embed；沿用既有平台無法貼上時的安全失敗行為。 |
| 格式化快捷鍵 | 不暴露工具列，且應攔截或立即清除 attribute，避免 UI 暫態格式與存檔結果不一致。 |

## 5. Mosaic、搜尋、校稿與協作邊界

### Mosaic 標註

- 第一次 Quill 發布可將 Mosaic 原始語法視為普通純文字顯示與編輯。
- 不得解析後遺失 UUID、註解、跳脫字元或原始標籤語法。
- 隱藏語法、標籤樣式與 atomic selection 屬於後續的 UI 投影工作，不是本階段的承諾。

### 搜尋與校稿

- 搜尋、取代、贅字與標點分析仍以 raw text 執行。
- 搜尋與校稿結果不得指向 sentinel newline。
- Quill UI 高亮接軌前，這些功能不可靜默失效；feature flag 預設關閉直到相容性測試完成。

### 協作與遠端游標

- `CollaborativeTextDelta` 持續以 adapter 輸出的 raw text 產生。
- Quill attribute、embed、UI-only 樣式均不產生 P2P 操作。
- 協作游標 offset 使用 raw text offset；轉換為 Quill 位置只能透過 adapter。

## 6. Phase 1 進入條件與測試案例

Phase 1 開始前，adapter 必須先有下列自動化測試：

- 空字串、單行、含與不含尾端換行、多個尾端空行。
- `LF`、`CRLF`、單獨 `CR` 的載入與輸出規則。
- 繁中、日文、韓文、emoji、組合字元與 RTL 文字。
- Mosaic 原始語法及其跳脫字元的往返。
- 文件含 attribute 或 embed 時，輸出不會把非文字資料寫入 `chapterContent`。
- 載入與 selection 變更不觸發 `editorContentProvider` 更新、dirty state 或協作 delta。
- raw offset `0`、中間位置、`rawText.length` 與 sentinel 位置的 clamp 行為。

## 7. Phase 0 驗收紀錄

- [x] 確認正文持久化格式維持 `String`，不引入 Delta JSON。
- [x] 定義 Quill 終止段落換行與正文尾端換行的區別。
- [x] 定義 CRLF／CR 的內部轉換與延後寫回規則。
- [x] 定義純文字貼上、富文字貼上、embed 與格式快捷鍵的處置。
- [x] 定義 Mosaic、搜尋校稿、協作與游標的相容性邊界。
- [x] 定義 feature flag 的生命週期與失敗回退條件。
- [x] 定義 Phase 1 必要的 adapter 測試案例。
