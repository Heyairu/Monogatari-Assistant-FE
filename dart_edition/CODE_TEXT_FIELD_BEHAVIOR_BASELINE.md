# Code Text Field Migration Baseline (Step 1)

建立日期: 2026-04-16
範圍: 主文本輸入框遷移前的行為基線與相依點標記。
目標: 在替換為 code_text_field 後，以下行為不得回歸。

## 1.1 關鍵行為基線

### A. 輸入與游標
- 觸發: 在主編輯器輸入、刪除、貼上任意文字。
- 目前預期:
  - `editorContentProvider` 會同步更新為 `textController.text`。
  - `_cursorOffset` 會同步為目前選取起點並做安全夾取。
  - 500ms debounce 後觸發目前章節字數更新。
  - `hasUnsavedChanges` 會被標記為 true。
  - 若目前有搜尋結果，高亮與匹配索引會被清空。
- 錨點:
  - `textController.addListener` in `lib/main.dart:367`
  - `_debouncedWordCountUpdate` in `lib/main.dart:479`
  - `_markAsModified` call in `lib/main.dart:382`
  - `clearHighlights` reset block in `lib/main.dart:386-392`

### B. 游標與外部內容回寫同步
- 觸發: `editorContentProvider` 被其他模組寫入內容（例如章節切換）。
- 目前預期:
  - 當非同步中且內容不同時，主控制器會以 `TextEditingValue` 回寫文字。
  - 游標 offset 會依新文字長度做安全夾取。
  - 透過 `_isSyncing` 避免循環更新。
- 錨點:
  - `_editorContentSubscription` in `lib/main.dart:433`
  - `textController.value = TextEditingValue(...)` in `lib/main.dart:444-449`

### C. 搜尋 Next / Previous
- 觸發: 搜尋列按下下一個或上一個。
- 目前預期:
  - 先找出全部匹配；無結果時清空高亮與索引。
  - 第一次搜尋以目前游標位置決定起始匹配。
  - 可循環切換匹配項。
  - 當前匹配會被選取，並將焦點拉回編輯器。
- 錨點:
  - `onFindNext` callback in `lib/main.dart:1048`
  - `onFindPrevious` callback in `lib/main.dart:1065`
  - `performFind` in `lib/bin/findreplace.dart:152`

### D. 單次替換與全部替換
- 觸發: 搜尋列按下 Replace / Replace All。
- 目前預期:
  - Replace:
    - 當前選取與匹配一致才替換。
    - 替換後重設搜尋狀態，再自動找下一個。
  - Replace All:
    - 以搜尋選項批次替換所有匹配。
    - 替換後更新文字並重建匹配狀態。
  - 兩者都會透過 `onTextUpdate` 回傳新文字給主狀態，並觸發字數更新。
- 錨點:
  - `onReplace` callback in `lib/main.dart:1082`
  - `onReplaceAll` callback in `lib/main.dart:1106`
  - `performReplace` in `lib/bin/findreplace.dart:235`
  - `performReplaceAll` in `lib/bin/findreplace.dart:361`

### E. 章節切換（內容提交與載入）
- 觸發: 在章節清單切換 segment/chapter，或切換左側頁籤前的同步流程。
- 目前預期:
  - 先把目前編輯器內容提交到舊章節。
  - 再更新 `editorSelectionProvider` 的 `selectedSegID/selectedChapID`。
  - 再把新章節內容寫入 `editorContentProvider`，由主編輯器訂閱者回寫到控制器。
- 錨點:
  - `_commitCurrentEditorToSelectedChapter` in `lib/modules/chapterselectionview.dart:631`
  - `_setSelection` in `lib/modules/chapterselectionview.dart:645`
  - `_setEditorContent` in `lib/modules/chapterselectionview.dart:652`
  - `_selectChapter` in `lib/modules/chapterselectionview.dart:674`
  - `_syncEditorToSelectedChapter` in `lib/main.dart:1959`
  - `ProjectManager.syncEditorToSelectedChapter` in `lib/bin/file.dart:268`

### F. 儲存與未儲存標記
- 觸發: 內容變更、儲存、另存、開新檔/開舊檔、退出。
- 目前預期:
  - 內容改變後 `_markAsModified` 令 `hasUnsavedChanges = true`。
  - 成功儲存後 `_markAsSaved` 令 `hasUnsavedChanges = false` 並更新 `_lastSavedTime`。
  - 儲存前會先同步目前編輯器內容到所選章節。
- 錨點:
  - `_markAsModified` in `lib/main.dart:1645`
  - `_markAsSaved` in `lib/main.dart:1657`
  - `_saveProject` in `lib/main.dart:1880`
  - `_saveProjectAs` in `lib/main.dart:1899`
  - `ProjectManager.markAsModified/markAsSaved` in `lib/bin/file.dart:249-255`

## 1.2 相依點標記

### Controller Listener Pipeline
- `HighlightTextEditingController` 是主編輯控制器，承接文字、選取與高亮繪製。
  - 定義: `lib/bin/findreplace.dart:38`
- 主輸入框目前是 Flutter `TextField`，直接吃 `TextEditingController`。
  - 元件: `EditorTextBox` in `lib/bin/content.dart:3`
  - `TextField` in `lib/bin/content.dart:17`

### Provider Sync Pipeline
- 主編輯器輸入 -> `editorContentProvider` + `editorSelectionProvider.cursorOffset`。
  - 寫入點: `lib/main.dart:367-402`
- 章節模組切換 -> `editorSelectionProvider` + `editorContentProvider`。
  - 寫入點: `lib/modules/chapterselectionview.dart:645-685`
- 主頁監聽 `editorContentProvider` 再回寫到主控制器。
  - 訂閱點: `lib/main.dart:433-451`

### Find/Replace Callback Pipeline
- 主頁 `FindReplaceBar` callbacks 皆以 `textController` 為核心傳遞。
  - 綁定點: `lib/main.dart:1048-1167`
- find/replace 執行函式依賴 `TextSelection` 與控制器 selection/text API。
  - `performFind`: `lib/bin/findreplace.dart:152`
  - `performReplace`: `lib/bin/findreplace.dart:235`
  - `performReplaceAll`: `lib/bin/findreplace.dart:361`

### Highlight Update Pipeline
- 搜尋時更新高亮:
  - `textController.updateHighlights(...)` in `lib/main.dart:1146`
- 內容改變或關閉搜尋時清空高亮:
  - `textController.clearHighlights()` in `lib/main.dart:390`, `lib/main.dart:1156`, `lib/main.dart:1166`
- 高亮渲染策略（雙色）在控制器 `buildTextSpan` 內。
  - `HighlightTextEditingController.buildTextSpan` in `lib/bin/findreplace.dart:44-113`

## 回歸驗收清單（遷移前後都要跑）

1. 輸入 20 字並換行，確認字數在約 500ms 後更新。
2. 輸入後不儲存直接切章，再切回原章，確認內容未丟失。
3. 搜尋一個出現 >= 3 次的詞，連按 Next/Previous，確認循環切換與焦點回到編輯器。
4. Replace 目前匹配一次，確認游標與下一個匹配定位正常。
5. Replace All，確認替換數量與內容一致，且高亮狀態重建正確。
6. 修改內容後檢查檔名顯示 `*`（未儲存）；儲存後 `*` 消失且更新儲存時間。
7. 關閉搜尋列，確認高亮清空但不破壞目前游標/選取狀態。

## 遷移限制（Step 1 結論）
- 目前搜尋高亮依賴 `buildTextSpan` 雙色渲染，遷移到 code_text_field 時必須保留雙色行為。
- 章節切換依賴 provider 寫入與主頁訂閱回寫，不可改壞此雙向同步。
- 儲存流程依賴「先同步當前章節再序列化」，不能省略 `_syncEditorToSelectedChapter`。
