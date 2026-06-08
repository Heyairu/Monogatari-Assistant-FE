# 260607 Codex 效能檢查報告

分析日期：2026-06-07  
專案：Monogatari Assistant FE / `dart_edition`  
技術棧：Flutter、Dart、Riverpod、`code_text_field`、XML project format  
分析方式：靜態程式碼檢查、既有效能文件比對、既有測試與 benchmark 門檻檢查

## 結論摘要

目前專案已經完成一批重要優化：搜尋高亮有結果上限、index 快取、`compute` 背景 isolate；專案 XML 解析與產生也已經放到 `compute`；Riverpod dirty listener 已從多個 listener 收斂為聚合 provider；全章節字數計算已經有 generation 防過期與分批並發。這些方向正確，代表目前最大的風險不再是「完全沒有背景化」，而是「大文字量下仍有 UI rebuild、字串複製、結果清單建構與同步橋接成本」。

Rust FFI 結論：現階段不建議導入 Rust FFI 作為主要效能解法。  
原因是目前熱點大多在 Flutter widget/render pipeline、`TextEditingValue`/`TextSpan` 大量配置、controller 雙向同步、列表 UI 建構與 isolate 間大字串傳輸。這些瓶頸 Rust FFI 不能直接解決，且大型字串跨 FFI 邊界仍會有複製與封裝成本。應先完成 Dart/Flutter 端的演算法、快取、虛擬化、分層 provider 與 benchmark 收斂。只有在經 DevTools profile 證明「純 CPU 文字演算法」仍長期佔用大量時間後，才考慮 Rust。

## 已改善的項目

### 1. 搜尋與高亮已背景化、快取化

位置：
- `lib/bin/findreplace.dart`

目前已看到：
- `_MAX_SEARCH_RESULTS = 1000`，搜尋、標點、贅字高亮都會 cap。
- `_SelectionCoverageIndex` 使用排序與 prefix max，`covers()` 以 binary search 檢查區間覆蓋。
- `findAllMatchesAsync()` 使用 `compute()`，把搜尋移出 UI isolate。
- `HighlightTextEditingController.buildTextSpan()` 有 `_cachedSpan`，避免同文字、同樣式、同 highlight revision 重建 `TextSpan`。
- `charsMatch()` 有 `_normalizationCache`，並在切換專案時由 `editor_coordinator_provider.dart` 呼叫 `clearNormalizationCache()`。

仍需注意：
- `buildTextSpan()` 在 cache miss 時仍會建立 boundary set、排序、切很多 `substring`，並建立多個 `TextSpan`。這是 UI isolate 工作，Rust FFI 無法代替 Flutter render tree 配置。
- `_normalizationCache` 是無上限 `Map<String, String>`，雖然切專案會清，但單一長時間 session 仍可能膨脹。

### 2. 字數計算已具備基本競態防護

位置：
- `lib/main.dart`
- `lib/bin/content_manager.dart`
- `lib/utils/text_change_debouncer.dart`

目前已看到：
- `ContentManager.calculateWordCountAsync()` 使用 `compute()`。
- `_updateActiveWordCountAsync()` 使用 `_activeWordCountGen`、`mounted`、章節 ID、文字 snapshot、字數模式 snapshot 檢查。
- `_updateAllWordCounts()` 使用 `_allWordCountsGen`，每批最多 `_maxConcurrentChapterWordCounts = 6`。
- `TextChangeDebouncer` 將字數更新與內容 commit debounce 集中管理。

仍需注意：
- `_updateAllWordCounts()` 每章一個 `compute()`，章節多時會產生很多 isolate 任務和大字串傳輸。
- `_recalculateSumFast()` 若 cache miss，仍可能同步計算字數。

### 3. 專案 XML 解析與產生已移到 isolate

位置：
- `lib/bin/file.dart`
- `lib/data/repositories/file_repository.dart`
- `lib/presentation/providers/project_io_providers.dart`

目前已看到：
- `ProjectManager.generateProjectXML()` 使用 `compute(FileService.generateProjectXML, data)`。
- `ProjectManager.loadProjectParseResultFromXML()` 使用 `compute(FileService.parseProjectXMLWithMetadata, projectFile.content)`。

仍需注意：
- isolate 傳輸整個 XML 字串與完整 `ProjectData`，大型專案會有複製成本。
- `ProjectIoController` 將 save/load/export 設為 `AsyncLoading()`，會影響全域 loading 狀態，可能讓 UI 在存檔期間整體進入 loading。

### 4. Dirty tracking 已收斂

位置：
- `lib/presentation/providers/editor_coordinator_provider.dart`

目前已看到：
- `projectDataAggregateProvider` 取代大量分散 `ref.listen`。
- `_dirtyTimer` 以 150ms debounce 合併 dirty signal。

仍需注意：
- aggregate provider 使用部分欄位與 identity hash；這可減少重建風暴，但也要用測試確認每個資料區塊的變更都能正確標 dirty。

## 主要效能問題與詳細解法

### P0：建立可重複的效能基準

問題：
目前已有 `findreplace_performance_benchmark_test.dart`，但門檻是 `averageMs < 250`。這可以防止極端退化，卻不足以保證寫作器輸入流暢。Flutter 目標應以 frame budget 思考：
- 60 FPS：約 16.7ms/frame。
- 30 FPS：約 33.3ms/frame。
- 任何單次輸入觸發的 UI isolate 工作都應盡量低於 8-12ms，給 layout/paint 留空間。

建議解法：

1. 建立三層 benchmark：
   - 100KB 文字、1000 highlights：`buildTextSpan` 平均 < 16ms。
   - 500KB 文字、1000 highlights：`buildTextSpan` 平均 < 33ms。
   - 無 highlight、純輸入同步：單次 controller listener pipeline < 8ms。

2. 增加 profile mode 手動測試腳本：
   - 開啟 100KB、500KB、1MB 專案。
   - 啟用/關閉校對。
   - 快速輸入 20 字。
   - 搜尋常見字，例如「的」。
   - 執行全部取代。
   - 切換章節、切換字數模式、儲存。

3. 在 CI 或本機加入固定命令：

```powershell
flutter test test\findreplace_performance_benchmark_test.dart
flutter test test\text_position_index_test.dart
flutter test test\text_change_debouncer_test.dart
```

本次環境限制：
- 目前 shell 找不到 `flutter` 指令，因此未能實際執行測試。
- 這不是測試失敗，而是本機 PATH/SDK 可用性問題。

### P1：主編輯器大文本輸入仍可能卡頓 // OK

位置：
- `lib/bin/content.dart`
- `lib/bin/findreplace.dart`
- `lib/main.dart`

現況：
- `EditorTextBox` 使用 `CodeField`。
- 外部傳入 `HighlightTextEditingController`，但 `EditorTextBox` 內部會在必要時建立 `_codeController = CodeController(text: externalController.text)`。
- 內外 controller 以 listener 雙向同步。
- `CodeField` 每次文字變更都要處理 `TextEditingValue`、selection、rich text rendering。
- `HighlightTextEditingController.buildTextSpan()` cache miss 時仍要切 segment 與建 `TextSpan`。

風險：
- 大文本每次輸入會複製/比較整段 `TextEditingValue`。
- 外部 controller 與內部 `CodeController` 的同步增加一次 listener 與 value copy。
- 高亮存在時，cache 失效會導致大量 `TextSpan` 建構。
- 即使搜尋計算在 isolate，render tree 建構仍在 UI isolate。

詳細解法：

1. 消除雙 controller 橋接成本。
   - 讓 `EditorTextBox` 直接接受 `CodeController` 或讓 `HighlightTextEditingController` 成為實際給 `CodeField` 使用的 controller。
   - 避免「外部 TextEditingController <-> 內部 CodeController」雙向同步。
   - 如果 `CodeField` 必須使用 `CodeController`，就讓 `ContentView` 擁有 `HighlightTextEditingController extends CodeController`，並直接傳入。

2. 降低每次輸入造成的 provider 更新。
   - 文字輸入時只更新 editor local controller。
   - 內容 commit 仍由 debounce 寫入 `editorContentProvider`。
   - cursor provider 可用較短 debounce 或只在章節切換/狀態列需要時更新。
   - 狀態列行列號可直接讀 `_textPositionIndex`，避免每個 cursor move 都牽動更大範圍。

3. `buildTextSpan()` 做區段快取。
   - 目前只快取整個 `TextSpan`。
   - 建議新增 `HighlightSpanCache`，用 `(textIdentity/revision, highlightRevision, styleHash)` 管理。
   - 若只有 current match index 改變，理論上只需要重繪前一個 current 與下一個 current 的區段，不需要重建全部 spans。

4. 對大文本啟用降級策略。
   - 例如文字 > 300KB 時，輸入中暫停非必要高亮，停止輸入 150-300ms 後恢復。
   - 文字 > 500KB 時，只高亮 viewport 附近或目前搜尋結果前後範圍。
   - 顯示提示：「大型章節已啟用輕量高亮」。

建議驗收：
- 500KB 章節連續輸入 20 字，DevTools timeline 中 UI isolate 沒有連續 long frame。
- 搜尋結果 1000 筆時，移動 current match 不應完整重建所有 spans。

### P1：校對模組背景化正確，但仍太頻繁、部分資料重建成本偏高 // OK

位置：
- `lib/modules/proofreadingview.dart`

現況：
- `_scheduleBackgroundProofreading()` 使用 100ms debounce。
- `_runProofreading()` 使用 `compute(_analyzeProofreading, request)`。
- 有 revision、mounted、文字 snapshot 檢查，能避免舊結果覆蓋新結果。
- 贅字偵測使用 `_FillerWordMatcher`，實作類似 Aho-Corasick trie。

風險：
- 每次 `_analyzeFillerWords()` 都建立 `_FillerWordMatcher(request.fillerWords)`，等於每輪校對都重建 trie。
- 100ms debounce 對 100KB 以下文字可接受，但對 500KB/1MB 文字可能造成 compute 任務排隊與結果丟棄。
- `_lineColumnAt()` 對每個 issue 從頭掃到 index，結果清單多時 UI 建構會變成 O(issueCount * textLength)。
- `_syncFillerWordHighlights()` 與 `_syncPunctuationHighlights()` 把結果轉成 `TextSelection` 後交給 highlighter，雖然 highlighter 會 cap 1000，但在 cap 前仍可能建立很多 match。

詳細解法：

1. 快取贅字 trie。
   - 在 UI state 載入 filler words 後建立一次 matcher snapshot。
   - 因為 isolate 不能直接傳 class instance，故把校對任務集中到長生命週期 worker isolate，而不是每次 `compute()` 新任務。

2. 依文字大小調整 debounce。
   - `< 128KB`：100ms。
   - `128KB - 512KB`：300ms。
   - `512KB - 2MB`：500ms。
   - `> 2MB`: 1s

3. 共用行列索引。
   - 將 `TextPositionIndex` 的概念移到 proofreader 結果顯示。
   - `_lineColumnAt()` 不應每筆 issue 從頭掃。
   - 在 `_runProofreading()` 成功套用結果時建立一次 `TextPositionIndex(text)`，UI map issue 時用 binary search 查行列。

建議驗收：
- 500KB 文字開啟校對時，輸入不產生持續排隊的 compute 任務。
- 1000 個 issue 的結果面板展開時，UI 不出現明顯卡頓。

### P1：全章節字數重算的 isolate 數量需要收斂 // Ignore，預計近期有資料結構更新

位置：
- `lib/main.dart`
- `lib/bin/content_manager.dart`

現況：
- `_updateAllWordCounts()` 每章呼叫一次 `ContentManager.calculateWordCountAsync()`。
- 每章各自 `compute()`。
- 每批最多 6 個任務。

風險：
- 專案若有 200 章，可能產生 200 個 isolate 任務。
- 大章節字串會被複製進 isolate，再把 int 傳回。
- 這比同步阻塞好，但仍可能造成 CPU 排隊、記憶體峰值與任務啟動 overhead。

詳細解法：

- 將字數計算改為SegTree
   - 將形式改為動態開點線段樹套動態開點線段樹
   - 利用 Update更新單章字數。
   - 使用 Query 回傳整體字數。
   - `_updateAllWordCounts()` 不再每章建立 compute，而是每次一個 compute。

建議驗收：
- 200 章、總 2MB 專案切換字數模式時，不凍結 UI。
- DevTools 中 isolate 任務數量不隨章節數線性暴增。

### P2：Normalization cache 無容量上限

位置：
- `lib/bin/findreplace.dart`
- `lib/presentation/providers/editor_coordinator_provider.dart`

現況：
- `_normalizationCache` 是全域 `Map<String, String>`。
- `applyProjectData()` 時會清除。

風險：
- 單一專案長時間工作、多語系、不同搜尋選項組合會持續增加 key。
- key 用字串串接：`char_matchCase_matchWidth`，本身也有額外配置。

詳細解法：

1. 改成固定容量 LRU。
   - 上限例如 4096 或 8192。
   - 使用 `LinkedHashMap`，命中時移到尾端，超過上限移除最舊。

2. 用結構化 key。
   - 避免字串插值。
   - 例如：

```dart
class _NormalizationKey {
  const _NormalizationKey(this.char, this.matchCase, this.matchWidth);
  final String char;
  final bool matchCase;
  final bool matchWidth;
  // override == and hashCode
}
```

3. 在搜尋完成後可選擇清理冷資料。
   - 如果搜尋文字長度 > 500KB，搜尋結束後保留常見 ASCII/CJK cache，其他冷 key 可清。

建議驗收：
- 長時間搜尋不同語系文字後，cache entry 數不超過設定上限。

### P2：專案 IO 背景化已做，但 loading 狀態可能過度影響 UI

位置：
- `lib/presentation/providers/project_io_providers.dart`
- `lib/main.dart`

現況：
- save/load/export 一進入即 `state = const AsyncLoading()`。
- `editorCoordinatorProvider` listen `projectIoControllerProvider` 並呼叫 `setLoading(next.isLoading)`。
- `main.dart` 讀 `isLoading` 傳給 app bar 或主要 UI。

風險：
- 存檔或匯出是背景操作，不一定需要讓整個 editor 視為 loading。
- 若 loading 狀態牽動大範圍 rebuild，可能讓存檔瞬間卡頓更明顯。

詳細解法：

1. 將 IO 狀態拆成 operation-specific。
   - `isOpeningProject`
   - `isSaving`
   - `isExporting`
   - `isParsing`

2. 只有 open/load project 擋住編輯 UI。
   - save/export 用 app bar spinner 或 status bar message。
   - 不要讓 `ContentView` 主體因 save/export 重建。

3. 對 save 加入最小重建策略。
   - save 前 `_collectProjectData()` 已 flush content。
   - save 中不需要重建 editor。
   - save 完只更新 `lastSavedTime` 與 `hasUnsavedChanges`。

建議驗收：
- 1MB 專案按存檔時，editor 不消失、不整頁 loading、不丟 focus。

### P2：大型表單頁面仍有重建與 controller 配置壓力 // OK

位置：
- `lib/modules/characterview.dart`
- `lib/modules/worldsettingsview.dart`
- `lib/modules/outlineview.dart`
- `lib/modules/glossaryview.dart`
- `lib/modules/planview.dart`

現況與風險：

1. CharacterView
   - `_controllers` 會為 `CharacterCodec.allControllerKeys` 建立大量 `TextEditingController`。
   - 每個 controller listener 都會 `_markAsModified()`，1 秒後 `_saveCurrentCharacterData()`。
   - `_buildDraftCharacterEntry()` 會掃過所有 controller key。
   - 對角色欄位數很多的頁面，單次欄位變更仍會造成較多資料收集。

2. WorldSettingsView
   - `_buildLocationRow()` 在 build 裡使用 `TextEditingController(text: location.localName)`。
   - `_showRenamePresetDialog()` 也直接建立 controller，沒有保留參照釋放。
   - dialog 內臨時 controller 問題較小，但 build row 內建立 controller 容易造成游標/輸入狀態不穩與配置浪費。

3. ProofReadingView 和其他頁面
   - 多個結果區塊用 `.map(...).toList()` 一次建立 children。
   - 若 issue 多，建構成本集中在單次 frame。

詳細解法：

1. CharacterView 改為 dirty field tracking。
   - listener 只記錄 changed keys。
   - `_saveCurrentCharacterData()` 只合併 changed keys 與舊 entry。
   - 大型 list/slider 區塊分 provider 或局部 state，避免單欄位改動掃全表。

2. WorldSettingsView 的 row edit controller 改為 stateful item。
   - 建立 `_EditableLocationName` StatefulWidget。
   - `initState()` 建 controller。
   - `didUpdateWidget()` 同步外部名稱。
   - `dispose()` 釋放 controller。

3. 結果清單虛擬化。
   - issue list 用 `ListView.builder` / `ListView.separated`。
   - 不要先 `.map(...).toList()` 建完整 widgets。
   - 每個區塊 cap 顯示數量，提供「顯示更多」。

4. 對大型樹狀資料建立 flat index。
   - outline/world/glossary 可維護 `id -> node/path` index。
   - 避免每次選取/rename 都掃整棵樹。

建議驗收：
- 100 個角色、每個角色完整欄位，切換角色 < 50ms。
- 世界設定 1000 個節點，展開/rename 不掉幀。

### P2：搜尋演算法仍有進一步空間

位置：
- `lib/bin/findreplace.dart`

現況：
- 搜尋已背景化。
- 一般搜尋支援 ignore punctuation/whitespace、match case、match width、whole word。
- `charsMatch()` 已有 normalization cache。

風險：
- 一般搜尋是從每個位置嘗試匹配 pattern，遇到常見短 pattern 或忽略標點空白時仍可能接近 O(N*M)。
- regex 搜尋未限制結果數，雖然 controller 端會 cap highlighter，但 isolate 仍可能先建立全部 matches。

詳細解法：

1. 在 `findAllMatchesSync()` 內早停。
   - 傳入 `maxResults`。
   - 一旦 matches 到 1000 或 UI 顯示上限，就停止掃描。
   - 若需要完整計數，分成「高亮結果」與「總數估算/完整計數」兩條路。

2. 對普通搜尋建立預處理字串。
   - 當 `ignoreWhitespace` 或 `ignorePunctuation` 開啟時，建立 normalized text 與 original offset mapping。
   - 用 Dart `indexOf` 或 KMP 在 normalized text 搜尋。
   - 回映到原始 offset。
   - 這通常比每個原始位置手動跳字元更穩定。

3. 常見單字元搜尋快路徑。
   - 搜尋詞長度為 1 且不啟用忽略標點/空白時，用 codeUnit 快速掃描。
   - 對 CJK 常見字可以降低非常多比較成本。

建議驗收：
- 1MB 文字搜尋單字「的」時，背景 isolate 時間可預期，且不建立超過高亮上限的 selection。

### P3：XML 格式處理可以再減少記憶體峰值

位置：
- `lib/bin/file.dart`

現況：
- XML parse/generate 已丟到 isolate。
- `_ProjectParser.parseProjectXMLWithMetadata()` 使用 `xml.XmlDocument.parse(xmlContent)` 建完整 DOM。
- `_ProjectMerger.generateProjectXML()` 使用 `StringBuffer` 一次產生完整 XML。

風險：
- 大型專案載入時，記憶體峰值至少包含：
  - 原始 XML 字串。
  - XML DOM。
  - 解析後 ProjectData。
  - isolate 傳輸副本。
- 儲存時也會有 ProjectData snapshot 與完整 XML 字串。

詳細解法：

1. 先加大小 telemetry。
   - 記錄 XML byte length、章節數、總字數、parse time、generate time。
   - 不需要上報，debug log 或本地 profile 即可。

2. 儲存時減少不必要 snapshot。
   - `snapshotProjectData()` 應只在必要處 deep copy。
   - 如果資料模型已 immutable/freezed，可避免重複深拷貝。

3. 大型專案再評估 streaming parse。
   - Dart `xml` 套件目前以 DOM 為主。
   - 若專案常超過 10MB XML，再考慮 SAX/streaming parser 或 Rust parser。

建議驗收：
- 10MB XML 專案載入時記憶體峰值可被觀測且不超過目標。

## 是否需要用 FFI 橋接 Rust

### 短結論

不需要，至少現在不應優先做。

### 原因

1. 目前主要瓶頸不是單一純 CPU 函式。
   - 編輯器卡頓多半來自 Flutter UI isolate 的 `TextEditingValue`、`TextSpan`、layout、paint、controller listener 與 provider rebuild。
   - Rust 無法直接替 Flutter 建 widget，也無法降低 `CodeField` render tree 的成本。

2. 現有重 CPU 工作已使用 Dart isolate。
   - 搜尋：`findAllMatchesAsync()`。
   - 字數：`calculateWordCountAsync()`。
   - 校對：`_runProofreading()`。
   - XML parse/generate：`ProjectManager`。

3. FFI 傳大字串仍有成本。
   - 目前熱路徑的資料是大型 Dart `String`。
   - 跨 FFI 或 flutter_rust_bridge 傳輸通常仍需編碼、複製、生命週期管理。
   - 如果每次輸入、每次校對都傳 500KB/1MB 字串，可能只是把成本換位置。

4. 跨平台成本高。
   - 目前專案支援 Android、iOS、macOS、Windows、Linux、Web。
   - `dart:ffi` 不支援 Flutter Web 的一般 native library 模式，Web 需要 WASM/JS interop 另一套。
   - Rust native library 需要各平台 build、signing、CI、debug symbols、crash reporting。

5. 維護成本不符合當前收益。
   - 新增 Rust 後，資料模型、錯誤處理、測試、打包都會變複雜。
   - 在尚未有 profile 證明 Dart 演算法已到瓶頸前，不值得。

### 什麼情況才值得導入 Rust

只有同時符合以下條件才建議：

1. DevTools/profile 顯示某個純文字演算法在 release/profile mode 下仍長期超過 50-100ms。
2. Dart 端已完成：
   - early stop/cap。
   - LRU cache。
   - batch isolate。
   - viewport/區段化渲染。
   - issue list 虛擬化。
3. 該演算法輸入輸出穩定、可以做成純函式。
4. 不需要每個 keypress 都跨 FFI。

可能適合 Rust 的候選：

1. 超大型 XML streaming parser。
   - 條件：專案檔常超過 10MB，Dart DOM parse 記憶體峰值不可接受。

2. 統一的文字分析引擎。
   - 搜尋、贅字、標點、行尾、引號配對整合為一次掃描。
   - 條件：Dart 版 Aho-Corasick、line index、cap、batch isolate 都完成後仍不足。

3. 大型正規化/index engine。
   - 建立 normalized text、offset map、suffix/search index。
   - 條件：章節常達數 MB，且搜尋是主要使用流程。

不適合 Rust 的項目：

1. `buildTextSpan()`。
   - 因為瓶頸在 Flutter `TextSpan`/render tree 建構。

2. provider rebuild。
   - 這是 Flutter/Riverpod 架構問題。

3. controller 同步。
   - 這是 Dart object 與 Flutter text input pipeline 問題。

4. 小型字數計算。
   - Dart isolate + cache 已足夠，Rust bridge overhead 可能更大。

### 若未來真的導入 Rust，建議方式

優先使用 `flutter_rust_bridge` 或明確的 C ABI：

1. 先建立 `text_engine` package，不直接改 UI。
2. API 設計為批次：

```text
analyze_text(input, options) -> {
  search_matches_capped,
  punctuation_issues_capped,
  filler_hits_capped,
  line_index,
  stats
}
```

3. 不要為每個功能各跨一次 FFI。
4. 不要為每次 keypress 跨 FFI。
5. Web 版同步規劃 WASM 或保留 Dart fallback。
6. benchmark 必須比較：
   - Dart sync。
   - Dart compute。
   - Rust FFI。
   - Rust FFI + 大字串傳輸成本。

# 建議實作路線圖

## 第 1 階段：1-2 天

1. 把 benchmark 門檻調整為 frame budget 導向。
2. 新增大型文字 smoke benchmark：100KB、500KB、1MB。
3. `findAllMatchesSync()` 增加 `maxResults` early stop。
4. `_normalizationCache` 改固定容量 LRU。
5. Proofreading `_lineColumnAt()` 改用 `TextPositionIndex`。

預期收益：
- 降低搜尋和校對結果 UI 的最差情況。
- 避免 cache 長時間膨脹。
- 有可回歸的效能標準。

## 第 2 階段：3-5 天

1. 移除 `EditorTextBox` 的雙 controller 橋接，讓 highlighter controller 直接供 `CodeField` 使用。
2. `_updateAllWordCounts()` 改批次 isolate。
3. 校對 debounce 依文字大小調整。
4. 校對結果清單 cap + builder 虛擬化。
5. WorldSettings row editing controller 改 StatefulWidget 管理。

預期收益：
- 大文本輸入更穩。
- 切換字數模式與校對不再堆大量 isolate 任務。
- 表單與結果面板降低配置尖峰。

## 第 3 階段：1-2 週

1. 高亮改成 viewport/dirty range 或 current match 局部更新。
2. 搜尋普通模式改 normalized text + offset map。
3. 專案 IO 加 telemetry，記錄 parse/generate time 與 XML size。
4. 將 save/export loading 狀態拆細，避免存檔牽動整頁 loading。

預期收益：
- 大專案下操作可預期。
- 可用數據決定是否真的需要 native/Rust。

## 驗證清單

建議在有 Flutter SDK 的環境執行：

```powershell
flutter test test\findreplace_performance_benchmark_test.dart
flutter test test\text_position_index_test.dart
flutter test test\text_change_debouncer_test.dart
flutter test test\findreplace_results_cap_test.dart
flutter test test\findreplace_highlight_test.dart
```

建議手動 profile：

```powershell
flutter run --profile
```

DevTools 觀測項：
- UI thread frame time。
- Raster thread frame time。
- `buildTextSpan()` 出現頻率與耗時。
- `CodeField`/EditableText rebuild。
- isolate 任務數量。
- GC 次數與記憶體峰值。
- save/load 時 UI 是否整頁 rebuild。

## 最終建議

短期不要導入 Rust FFI。  
先把目前已經開始的 Dart isolate、cache、cap、provider 收斂做完整，並補上真正貼近 frame budget 的 benchmark。若完成上述第 1、2 階段後，大型文字的純 CPU 分析仍明顯超標，再以「批次文字分析引擎」為單一 Rust 候選，而不是把多個小功能零散地橋到 Rust。
