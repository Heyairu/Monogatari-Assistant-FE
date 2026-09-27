# Quill 純文字正文編輯器替換計畫

> 目標：以 Flutter Quill 取代目前正文的輸入 UI；正文資料仍以既有純文字 `chapterContent` 保存。Quill Delta 與富文字持久化不納入此版本。

## 決策與範圍

### 本版本包含

- 以 `QuillEditor` 取代正文區的 `CodeField`。
- 將既有純文字轉換為 Quill `Document` 以供編輯。
- 將 Quill 文件轉回純文字，沿用既有 debounce、Provider、存檔、字數與 P2P 協作流程。
- 維持章節切換、Undo／Redo、剪下／複製／貼上、搜尋取代、校稿與遠端游標等既有能力。
- 以 feature flag 漸進釋出，保留回退至舊編輯器的能力。

### 本版本不包含

- 將 Quill Delta JSON 寫入 `chapterContent`、XML 或專案格式。
- 啟用粗體、字型、顏色、圖片、表格等可持久化富文字格式。
- 修改既有 XML、Markdown、閱讀模式或 P2P 純文字協定的資料格式。
- 承諾 Quill 取代後必然改善大章節效能；須以實測決定。

## 相容性原則

1. `chapterContent` 仍是唯一持久化真實來源。
2. 載入純文字至 Quill、再輸出純文字時，內容必須無損；中日韓文字、emoji、空行、換行符與 Mosaic 原始語法均須保留。
3. Quill 文件結尾所需的換行不得意外寫回正文；轉換規則應由單一 adapter 管理並覆蓋測試。
4. 任何錯誤或 feature flag 關閉時，舊 `CodeField` 流程必須可安全回退。
5. 此版本的格式化操作應關閉或不暴露，避免使用者以為格式會被保存。

## 實作階段

| 階段 | 工作項目 | 產出／驗收條件 | 預估 |
|---|---|---|---:|
| ✅ 0. 定義邊界 | 確認 Quill 僅作輸入 UI，沒有 Delta 持久化；定義空文件、末尾換行、換行符正規化與貼上規則。詳見 [Phase 0 規格](QUILL_PLAIN_TEXT_EDITOR_PHASE0.md)。 | 完成技術規格與相容規則。 | 0.5 天 |
| ✅ 1. 建立適配層 | 已建立 [`PlainTextQuillAdapter`](lib/features/editor/plain_text_quill_adapter.dart)，負責 `String → Quill Document`、`Document → String` 與 selection／offset 轉換。 | 往返轉換不改變中日韓文字、emoji、空行及 Mosaic 原始語法。 | 1–2 天 |
| 🟡 2. PoC | 已在隔離元件接入 `QuillEditor`，完成輸入、章節切換、純文字貼上設定與 200KB Widget 壓測；實機 IME 驗證待執行。 | 50KB／200KB 正文可編輯；Windows、Android 至少各完成一次 IME 驗證。 | 2–3 天 |
| 🟡 3. 常用互動接軌 | 已在 PoC 改接快捷鍵、正文級 Undo／Redo、Select All、Copy／Cut／Paste 與焦點控制；正式 AppBar 接入待 Phase 7 替換正文 UI 時完成。 | 既有 AppBar 與鍵盤操作可用，且不影響選取範圍。 | 2–3 天 |
| 🟡 4. 搜尋與校稿 | PoC 已將搜尋、取代與校稿範圍改接 Quill 文件 offset；持續多範圍視覺高亮需改用替代實作。 | 全取代、非同步搜尋取消與校稿標記均不錯位；高亮 UI 經多段落驗證後再接入。 | 3–5 天 |
| ✅ 5. Mosaic 標註 | 已採資料相容優先的第一版：Quill 顯示並編輯原始 Mosaic 語法；隱藏語法視覺投影保留為後續獨立工作。 | 標註儲存仍為原始語法；閱讀與匯出結果不變。 | 1 天／4–7 天 |
| 🟡 6. 協作與游標 | PoC 已將遠端游標量測與本機 selection callback 改接 Quill render tree；正式協作宿主接線待 Phase 7。 | 兩端編輯、游標、章節切換與斷線重連不出現偏移。 | 3–5 天 |
| 🟡 7. 主編輯器替換 | 已以 Quill 接替 `EditorTextBox` 內的 `CodeField`，並保留編譯期回退開關；實機完整生命週期驗收待 Phase 8。 | 建立、開啟、切換、儲存、重開專案後正文完全一致。 | 3–4 天 |
| 🟡 8. 回歸與發布 | 已補主宿主、資料鏈路與回退模式回歸，並加入可重複執行的 release check；實機 IME／雙端驗收待完成。 | XML、Markdown、P2P、閱讀模式與歷史復原皆通過回歸。 | 3–5 天 |

### Phase 1 實作紀錄

- `PlainTextQuillAdapter` 已建立於 `lib/features/editor/plain_text_quill_adapter.dart`，並以 `PlainTextQuillDocument` 封裝 Quill 文件、原始正文與雙向 offset 映射。
- 已補 `test/plain_text_quill_adapter_test.dart`，覆蓋 sentinel 換行、CRLF／CR 正規化、CJK／emoji／Mosaic 原始語法、CRLF offset，以及 attribute／embed 拒絕。
- `flutter_quill` 已固定至 `11.6.0`。此版本保留 Flutter 3.44 的 `TextInputClient` 相容性，並修正 CJK whole-word 搜尋與 Android caret／IME 同步；專案最低 Dart SDK 為 `3.12.0`，開發與建置環境需使用 Flutter `3.44.0` 以上。

### Phase 2 實作紀錄

- 已新增隔離的 [`PlainTextQuillEditorPoc`](lib/features/editor/plain_text_quill_editor_poc.dart)，尚未接入正式編輯器路由或 Provider；它只接收純文字 `content`，並只透過 `onChanged(String)` 回傳 adapter 輸出的純文字。
- 已關閉外部富文字貼上；沒有工具列、embed 或格式化 UI。章節內容或 selection 由宿主更新時，會重新建立文件且不回送假變更。
- Quill 11.6.0 對含大量換行的單一 Delta 字串仍需避免深度遞迴。adapter 現以每行一個、僅供記憶體內部使用的 ignored loader marker 載入，再由 adapter 忽略該 marker；持久化輸出仍為不含 metadata 的純文字。
- 已新增 `test/plain_text_quill_editor_poc_test.dart`，覆蓋 CJK 輸入、章節切換與約 200KB 多段落正文；實體 Windows 與 Android 的中文／日文／韓文 IME 驗證仍須在目標裝置手動完成。

### Phase 3 實作紀錄

- `PlainTextQuillEditorCommands` 已提供給宿主 AppBar 或其他控制元件使用的正文級 Undo／Redo、全選、剪下、複製、貼上與 focus API。它不暴露 `QuillController`，避免呼叫端繞過純文字邊界插入 Delta 或格式。
- PoC 的 AppBar 已接入上述 commands。剪貼簿流程直接使用系統 `text/plain`，不使用 Quill 內部會保留 Delta 的 clipboard；貼上前會將 CRLF／CR 正規化為 LF。
- Quill 焦點內已設定 Ctrl/Cmd+Z、Ctrl/Cmd+Shift+Z（Windows/Linux 另支援 Ctrl+Y）、Ctrl/Cmd+A/C/X/V。這些 nested shortcuts 優先於目前應用程式的全域專案歷史快捷鍵。
- 已補 Widget 測試驗證選取範圍、正文級 Undo／Redo、純文字剪下／複製／貼上，以及 Quill 聚焦時 Ctrl+Z 的優先權。正式 AppBar 仍使用舊 `CodeField`，因此需等 Phase 7 正式替換後再進行端對端接線與手動驗收。

### Phase 4 實作紀錄

- `PlainTextQuillSearchController` 已在 PoC 建立搜尋、前後移動、單次取代、全取代與校稿範圍的橋接；所有範圍均以 adapter 輸出的 canonical LF 純文字 UTF-16 offset 表示，因此可直接套用至 Quill selection。
- 搜尋工作會以 generation 與文件 revision 取消過時結果；編輯或外部章節切換也會清除既有搜尋／校稿範圍，避免在已變動文字上使用舊 offset。無效正規表示式會安全回傳零筆結果。
- 已補 Widget 測試覆蓋 CJK 搜尋導航、跨 CRLF 段落的單次／全取代，以及搜尋取消與校稿範圍在編輯後清除。
- 11.6.0 的 release notes 未包含 `textSpanBuilder` 多段落高亮的修正；升級後仍暫不接入持續高亮渲染，目前的「目前命中」仍由 Quill selection 呈現。後續應評估不依賴 `textSpanBuilder` 的 overlay／decorator，或以完整多段落高亮案例重新驗證套件行為。

### Phase 5 實作紀錄

- Quill 的純文字 adapter 與 PoC 已明確將 Mosaic `//…//` 視為一般正文來源字元：不會建立 Quill attribute、embed 或 placeholder，也不會套用既有 `MosaicEditingController` 的 display/raw offset 投影。
- 已補 Widget 測試，確認有效的角色標註與 emphasis 標註在 Quill 載入、一般正文編輯、輸出後仍保有相同原始語法，並可被既有 `InlineAnnotationParser` 重新解析。
- 因此 XML、Markdown、閱讀模式與 P2P 仍會收到原有的純文字 Mosaic 原始碼。若產品要求隱藏 UUID／語法並顯示彩色標籤，須另設 render-only projection，且需處理 raw／Quill offset 映射、IME 與選取行為；不得將投影資料持久化至 Delta。

### Phase 6 實作紀錄

- `PlainTextQuillEditorPoc` 現可接收既有協作層的 `RemoteCursorState`，並以 `PlainTextQuillRemoteCursorOverlay` 將遠端的 canonical plain-text UTF-16 offset 量測為 Quill caret 位置。它使用 Quill 的 `RenderEditor.getLocalRectForCaret`，不假設 Quill 使用 Flutter 的 `RenderEditable`，且會在文字、selection 或捲動後重測。
- PoC 在取得焦點或本機 selection 改變時，會以 `PlainTextQuillCursorReporter` 回送不含 Quill sentinel newline 的 anchor／focus offset。Phase 7 的正式宿主可直接轉交至現有 `CollaborationNotifier.updateLocalCursor`；協作內容本身仍僅由 `onChanged(String)` 的純文字流程處理。
- 已補 Widget 測試覆蓋本機選取 offset 回報，以及遠端 cursor 在 Quill render tree 的 caret 量測。實際雙端文字合併、章節切換與斷線重連需在 Phase 7 將 PoC 接入 Provider／P2P 後做端對端驗收。

### Phase 7 實作紀錄

- `EditorTextBox` 預設改以 `PlainTextQuillEditorPoc` 作為正式正文輸入 UI。Quill 每次輸出都回寫既有 `MosaicEditingController.rawText`，因此既有 `TextChangeDebouncer`、`editorContentProvider`、章節持久化、字數與 P2P 純文字 delta 仍沿用原本資料流；不會保存 Quill Delta。
- 主編輯器沿用既有 `editorFocusNode`，供 Find/Replace 與其他既有命令要求焦點；Quill selection 會同步回舊 controller 的 raw offset，並以 `updateLocalCursor` 發送本機協作游標。遠端游標改由 `PlainTextQuillRemoteCursorOverlay` 在 Quill render tree 上繪製。
- 已在主 `MaterialApp` 加入 `FlutterQuillLocalizations.delegate` 與中、日、韓等支援語系，避免正文區缺少 Quill 本地化資源。
- 可用 `--dart-define=MONOGATARI_PLAIN_TEXT_QUILL_EDITOR=false` 在發布期間回退舊 `CodeField`。因 Quill 第一版採 Mosaic 原始語法可見策略，舊 editor 的標註視覺投影、點擊詳情與 Poppin 自動完成只會在回退模式啟用。
- 已補外部 focus node 與「provider 回寫不清除 Quill Undo 歷史」的回歸測試；專案建立／開啟／切章／儲存／重開與雙端 P2P 的完整實機驗收留待 Phase 8。

### Phase 8 實作紀錄

- 新增 `test/editor_text_box_quill_integration_test.dart`，驗證正式 `EditorTextBox` 預設呈現 Quill、Mosaic 原始語法無損，且 Quill 編輯會回寫既有 raw controller；也驗證既有宿主的 raw selection 可同步至 Quill。
- 原有 Mosaic IntelliSense 與剪貼簿測試明確指定 `usePlainTextQuillEditor: false`，將它們定位為 feature flag 回退模式的回歸，不再與預設 Quill 行為混用。
- 已執行 Quill adapter／PoC、正式宿主、Mosaic 回退、XML 讀寫、Markdown 匯出、協作 CRDT／presence、章節協調器與專案歷史測試；自動化範圍內均通過。
- 新增 `tool/quill_release_check.ps1`：預設執行 analyzer、Quill focused tests、完整 Flutter suite 與 Windows debug build；可用 `-SkipFullSuite`、`-SkipBuild` 作本機快速檢查。
- 發布前仍須在 Windows 與 Android 以中文、日文、韓文 IME 手動輸入；並以兩台裝置驗證同章節輸入、遠端游標、切章、斷線重連，以及建立／儲存／關閉／重開的真實專案生命週期。完成後才可將 Phase 8 標示為完成並考慮預設長期啟用。

## 技術設計要點

### 資料流

```text
chapterContent（純文字）
        │ 載入
        ▼
PlainTextQuillAdapter
        ▼
Quill Document / QuillController
        │ 使用者輸入
        ▼
PlainTextQuillAdapter
        ▼
純文字 debounce → editorContentProvider → chapterContent → XML／Markdown／P2P
```

### Mosaic 標註策略

第一版以「資料相容優先」為原則：原始 Mosaic 語法可先顯示為文字，確保標註不會在編輯、儲存或匯出時遺失。若產品需要維持目前隱藏標記、顯示標籤的體驗，應在後續小版本加入 Quill attribute 或 embed 投影；此投影只能改變顯示，不改變純文字儲存內容。

### 協作策略

既有協作模型以純文字插入／刪除 delta 與字元 offset 運作。本版本不得將 Quill 的格式化操作送入協作協定；所有同步內容均以 adapter 輸出的純文字為準。遠端游標需要由 Quill 的選取位置與 render tree 重新量測。

## 測試清單

- 純文字往返：空內容、單行、多空行、CRLF／LF、CJK、emoji、組合字元。
- Mosaic：原始語法、逸出字元、標註前後輸入、標註內編輯與複製貼上。
- 編輯生命週期：新建、開啟、切換章節、關閉、重開、Undo／Redo、歷史復原。
- 搜尋與校稿：搜尋、單次取代、全取代、非同步取消、高亮範圍。
- 協作：雙端同章節輸入、遠端游標、章節切換、斷線與重新連線。
- 匯出：XML 儲存／讀取、Markdown、閱讀模式文字投影。
- 平台：Windows、Android；如支援範圍包含 macOS、Linux、iOS，均需 IME 與快捷鍵驗證。
- 效能：50KB、200KB 正文的輸入延遲、捲動、搜尋與章節切換，對照舊編輯器量測。

## 發布策略

1. 先以內部 feature flag 啟用，舊編輯器可隨時回退。
2. 僅對新建專案與測試使用者開放，蒐集 IME、長文與協作問題。
3. 修正相容性與效能問題後，預設啟用 Quill，但保留舊編輯器一個發布週期。
4. 完成跨平台回歸後移除舊 `CodeField` 實作。
5. 後續版本再另立提案，評估 Delta JSON 與真正富文字持久化。

## 工期摘要

- **基礎 Quill 純文字版**（不保留 Mosaic 視覺標註）：約 **2–3 週**。
- **功能等價版**（保留現有標註、校稿與協作游標）：約 **4–6 週**。

## 主要風險與處置

| 風險 | 影響 | 處置 |
|---|---|---|
| Quill 文件末尾換行造成內容差異 | 存檔、字數與協作出現假變更 | 以 adapter 統一定義轉換與測試。 |
| CJK IME composing 與 selection 不一致 | 中文、日文、韓文輸入異常 | 在 PoC 階段優先驗證各平台 IME。 |
| Mosaic 投影無法直接移植 | 標註可能顯示原始語法或游標錯位 | 第一版允許原始語法可見；視需求再做 UI 投影。 |
| 遠端游標依賴 `RenderEditable` | 協作游標無法定位 | 重新實作 Quill render tree 的位置量測。 |
| `textSpanBuilder` 多段落初始化卡住 | 搜尋／校稿無法安全繪製持續多範圍高亮 | Phase 4 保留 offset bridge 與目前命中 selection；改採 overlay／decorator 或升級套件後重新驗證。 |
| Quill render tree 不使用 Flutter `RenderEditable` | 沿用舊游標量測會找不到或錯置遠端 caret | Phase 6 改用 Quill `RenderEditor.getLocalRectForCaret`；正式接線後以多段落與捲動做雙端驗收。 |
| 效能未如預期 | 大章節仍有卡頓 | 採實測門檻決策，不以替換元件假設改善。 |
