# 260605 Codex Report - 專案性能問題與解決方案

> 日期：2026-06-05  
> 專案：Monogatari-Assistant-FE / `dart_edition`  
> 分析方式：靜態程式碼審查、資源檔大小盤點、既有效能報告比對  
> 主要範圍：Flutter/Dart 前端輸入效能、搜尋/高亮、校正文、Riverpod 狀態流、資料快照、檔案 IO、資源包體  
> 備註：本次沒有執行 Flutter DevTools runtime profile 或 release build size analysis；以下結論以目前程式碼結構與可觀察成本推估，建議後續用實測指標驗證。

# 1. 總結

此專案已經做過不少效能優化，尤其是搜尋/高亮：`findreplace.dart` 已有 debounce、背景 `compute()`、搜尋結果上限、prefix-max coverage index 與 benchmark test。Dirty listener 也已從多個 listener 收斂成 `projectDataAggregateProvider`。這些是正確方向。

但 2026-06-05 當下仍有幾個會直接影響使用體感的熱點：

1. 主編輯器每次輸入會走兩條字數計算路徑，造成重複 isolate 啟動與大字串複製。
2. 手機版功能頁使用 `IndexedStack` 一次建立 14 個頁面，隱藏頁面仍會建立 controller / provider listener；其中 `ProofReadingView` 可能在非可視狀態下仍訂閱文字變更。
3. 文本校正 `_runProofreading()` 在 UI isolate 同步掃描全文，且同一次檢查會執行多個 O(n) 或 O(words * n) 分析。
4. 狀態列每次游標 offset 變更都從文字開頭掃到游標位置計算行列，長章節文末輸入會變成 O(n)。
5. `syncEditorToSelectedChapter()` 即使內容沒有改變也會重建 segments snapshot，造成不必要 provider 更新、rebuild 與 dirty 標記風險。
6. 自訂 NotoSans 字型 raw assets 約 62.6 MiB，對包體、啟動與記憶體有明顯壓力。
7. 多個大型表單/樹狀模組仍以 `SingleChildScrollView + Column` 或一次性 `Column(map(...))` 建立大量子元件，資料變大後會遇到首屏與重建成本問題。

最建議的短期策略不是大改架構，而是先修幾個高槓桿點：

- 合併 active chapter 字數計算，只保留一條可取消/可 debounce 的 pipeline。
- 手機版功能頁改成 lazy page cache，避免一次建立 14 個功能頁。
- `ProofReadingView` 改成只在可視或使用者要求時執行，並把全文校正移到 isolate。
- `syncEditorToSelectedChapter()` 加內容相同 early return。
- 狀態列行列計算加入換行索引快取或 incremental cursor cache。
- 對搜尋 benchmark 設定真正有約束力的 CI 門檻。

# 2. 專案熱區盤點

### 2.1 最大 Dart 檔案

| 檔案 | 行數 | 風險說明 |
|---|---:|---|
| `lib/modules/characterview.dart` | 3256 | 大型表單、多 controller、多 copy-on-write 操作集中 |
| `lib/modules/proofreadingview.dart` | 3151 | 全文校正邏輯與 UI 混在同一 State，容易在 UI isolate 形成熱點 |
| `lib/modules/outlineview.dart` | 3072 | 大型樹狀資料、拖曳、列表、詳細表單集中 |
| `lib/bin/findreplace.dart` | 2435 | 搜尋、取代、高亮、TextSpan 建構集中 |
| `lib/main.dart` | 2282 | 主編輯器、頁面切換、字數、檔案操作、狀態列集中 |
| `lib/modules/glossaryview.dart` | 2221 | 類別樹與詞條列表仍有非虛擬化區域 |
| `lib/bin/file.dart` | 2058 | XML parsing / merging / file dialog / export 集中 |
| `lib/presentation/providers/project_state_providers.dart` | 2051 | 多份 project state、snapshot、copy-on-write 集中 |

這些檔案不是「大就一定慢」，但它們是效能風險聚集區。後續 profiling 應優先看這些模組。

### 2.2 資源檔大小

| 資源 | 大小 |
|---|---:|
| `assets/fonts/NotoSansSC-Variable.ttf` | 17,773,248 bytes |
| `assets/fonts/NotoSansTC-Variable.ttf` | 11,917,560 bytes |
| `assets/fonts/NotoSansHK-Variable.ttf` | 11,887,164 bytes |
| `assets/fonts/NotoSansKR-Variable.ttf` | 10,400,436 bytes |
| `assets/fonts/NotoSansJP-Variable.ttf` | 9,135,128 bytes |
| `assets/fonts/NotoSans-Italic-Variable.ttf` | 2,300,468 bytes |
| `assets/fonts/NotoSans-Variable.ttf` | 2,044,548 bytes |
| `assets/fonts/NotoSansThai-Variable.ttf` | 217,004 bytes |

Custom fonts raw total 約 65,675,556 bytes，約 62.6 MiB。這是目前最明顯的包體風險。

# 3. 最高優先問題 // OK

## P0-1：主編輯器輸入時重複計算 active chapter 字數 // OK

### 證據位置

- `lib/main.dart:338` `_refreshActiveChapterWordCount()`
- `lib/main.dart:352` `TextChangeDebouncer(onWordCountTrigger: ...)`
- `lib/main.dart:386` `textController.addListener(...)`
- `lib/main.dart:402` `_textChangeDebouncer.onTextChanged(currentText)`
- `lib/main.dart:404` `_refreshActiveChapterWordCount()`
- `lib/main.dart:616` `_updateActiveWordCountAsync(...)`
- `lib/presentation/providers/word_count_providers.dart:60` `ActiveChapterWordCountNotifier.onTextChanged(...)`
- `lib/bin/content_manager.dart:21` `calculateWordCountAsync(...)`

### 問題描述

每次文字真的變更時，現在會同時做兩件事：

1. 立即呼叫 `_refreshActiveChapterWordCount()`，進入 `activeChapterWordCountProvider.onTextChanged()`，然後 `calculateWordCountAsync()` 使用 `compute()` 對整章文字做字數計算。
2. 呼叫 `_textChangeDebouncer.onTextChanged(currentText)`，500ms 後再跑 `_updateActiveWordCountAsync()`，同樣使用 `calculateWordCountAsync()` 對同一份文字做一次字數計算，並更新章節快取與全書字數。

也就是大章節輸入時，同一份文字至少會被複製到 isolate 一次，常見情境下還會第二次複製與重算。`characters` package 的 grapheme cluster 計算本身是 O(n)，混合字數模式也會逐 grapheme 掃描。對 100KB、500KB、1MB 章節，這會直接形成輸入延遲與 CPU 尖峰。

### 影響

- 大章節輸入時 CPU 使用率升高。
- isolate 啟動/訊息傳遞有額外成本；文字越大，複製成本越明顯。
- Provider state 會多次變更，進一步觸發狀態列與其他 watch。
- 全書字數更新與 active 字數更新可能短暫不一致。

### 建議解法

#### 方案 A：保留單一 debounced pipeline

讓 `TextChangeDebouncer` 成為唯一入口：

- 輸入時只更新 dirty / cursor / pending content。
- 300ms 後計算 active chapter word count。
- 計算結果同時更新：
  - `activeChapterWordCountProvider`
  - 章節 `cachedWordCount`
  - `totalWordsProvider`

這樣每次穩定輸入只計算一次。

#### 方案 B：active 字數即時、章節快取延遲，但共用結果

如果 UI 需要「當前章節字數」快速更新，可以讓 active provider 回傳計算結果後通知章節快取，而不是 main 再做第二次。概念是：

```dart
// 單一計算結果，同時服務 status bar 與 chapter cache。
final result = await activeWordCountService.compute(
  chapterId: selectedChapID,
  text: currentText,
  mode: mode,
);

if (!result.isStale) {
  activeWordCountNotifier.setCount(result.count);
  segmentsNotifier.updateChapterWordCountCache(result.chapterId, result.count);
  totalWordsNotifier.setTotalWords(recalculateFromCache());
}
```

#### 方案 C：小文字同步、大文字 isolate

對短章節直接同步計算可避免 isolate overhead；對長章節才丟 isolate。

建議門檻：

- `< 20KB`：同步計算或 microtask。
- `20KB - 200KB`：debounced isolate。
- `> 200KB`：debounced isolate + 顯示「計算中」狀態 + 可取消 revision。

### 驗證方式

新增 benchmark / widget test：

- 10KB / 100KB / 500KB 章節，各輸入 20 次。
- 驗證每次 debounce window 內最多只觸發一次 `calculateWordCountAsync()`。
- 測量輸入後 1 秒內 CPU 與 frame jank。
- 驗證切章節後舊字數結果不會回寫新章節。

## P0-2：手機版一次建立 14 個功能頁，隱藏頁面仍可能工作 // Ignore

### 證據位置

- `lib/bin/mobile_function_page.dart:78` `IndexedStack(...)`
- `lib/bin/mobile_function_page.dart:81` `children: [for (int i = 0; i < pageCount; i++) pageBuilder(i)]`
- `lib/main.dart:1088` `_buildSpecificPageContent(int pageIndex)`
- `lib/main.dart:1514` `_buildProofreadingView()`
- `lib/modules/proofreadingview.dart:371` `ref.listenManual<String>(editorContentProvider, ...)`
- `lib/modules/proofreadingview.dart:425` `_scheduleBackgroundProofreading()`

### 問題描述

手機版功能頁裡的 `IndexedStack` 會一次建立所有 14 個功能頁。這代表即使使用者只在「主頁」或「章節選擇」，其他頁面也會被 mount。

最明顯的風險是 `ProofReadingView`：

- 它在 `initState()` 中訂閱 `editorContentProvider`。
- 文字變更後會排程 `_runProofreading()`。
- `_runProofreading()` 是全文同步掃描。

因此在手機版，只要功能頁被建立，隱藏的校正文頁面就可能仍然聽到文字變更並排程檢查。這會把「使用者正在普通輸入」變成「輸入 + 字數計算 + 隱藏校正文全文掃描」。

其他頁面也有類似問題：BaseInfo、Outline、WorldSettings、Character、Glossary 都有自己的 controller、scroll controller、provider watch 或本地狀態。一次建立會提高首屏成本與記憶體。

### 影響

- 手機版首次進入功能頁會建立大量 widget/state/controller。
- 隱藏頁面仍可能訂閱 provider、排 timer、做計算。
- 大型專案下，輸入時可能觸發非可視模組的背景工作。
- 記憶體峰值提高。

### 建議解法

#### 方案 A：Lazy IndexedStack

只建立目前選中的頁面，已訪問頁面可選擇保留。

```dart
class LazyIndexedStack extends StatefulWidget {
  final int index;
  final int length;
  final Widget Function(int index) builder;
}
```

內部維護 `Map<int, Widget>` 或 `Set<int> visited`：

- 首次進入頁面時建立。
- 已訪問頁面保留 state。
- 未訪問頁面不建立、不訂閱、不跑 timer。

#### 方案 B：只讓可視頁面工作

對 `ProofReadingView` 增加 `isActive` 參數：

```dart
ProofReadingView(
  textController: textController,
  chapterSwitchVersion: _proofreadingChapterSwitchVersion,
  isActive: slidePageIndexNow == 10,
)
```

在 `_onSharedTextChanged()` 中：

```dart
if (!widget.isActive) return;
```

切到 proofreading tab 時再執行一次檢查。

#### 方案 C：拆成 route/page

手機版如果仍需保留多功能切換，可以改成 `PageView.builder` 或 Navigator route。非可視頁面自然不 mount。

### 驗證方式

- 手機寬度 `< 800` 啟動 app，記錄 mount 的 module 數量。
- 在非 proofreading 頁輸入 100 次，驗證 `_runProofreading()` 不會被呼叫。
- DevTools Memory：比較 lazy 前後首次進入功能頁記憶體峰值。

## P0-3：文本校正同步全文掃描，且一次檢查包含多個 O(n) 分析 // OK

### 證據位置

- `lib/modules/proofreadingview.dart:416` `_onSharedTextChanged(...)`
- `lib/modules/proofreadingview.dart:430` `Timer(const Duration(seconds: 1), ...)`
- `lib/modules/proofreadingview.dart:860` `_runProofreading()`
- `lib/modules/proofreadingview.dart:863` `_checkPairClosures(text)`
- `lib/modules/proofreadingview.dart:866` `_detectConsecutiveSymbols(text)`
- `lib/modules/proofreadingview.dart:869` `_detectSameTypeQuoteNesting(text)`
- `lib/modules/proofreadingview.dart:872` `_detectLineEndingIssues(text)`
- `lib/modules/proofreadingview.dart:875` `_normalizePunctuation(text)`
- `lib/modules/proofreadingview.dart:878` `_analyzeFillerWords(text)`
- `lib/modules/proofreadingview.dart:2083` 逐 filler word 建立 RegExp 並 `allMatches(text)`

### 問題描述

`_runProofreading()` 目前在 UI isolate 同步跑完所有檢查，再 `setState()`。即使有 1 秒 timer，真正執行時仍會卡主 UI thread。

這些檢查多半各自掃全文一次：

- 成對符號檢查：O(n)
- 連續符號檢查：O(n)
- 同型引號巢狀檢查：O(n)
- 行尾檢查：O(n) 或依 line split 後掃描
- 標點 normalize：O(n)，且 line-level mask / quote map 建構
- 贅字分析：對每個 filler word 跑 `RegExp(...).allMatches(text)`，複雜度接近 O(words * n)

如果章節文字很長，這會比搜尋更容易造成可見卡頓，因為它沒有丟 isolate。

### 影響

- 校正文頁面打開時，輸入後 1 秒可能出現主執行緒尖峰。
- 手機版若所有頁面都被 `IndexedStack` 建立，此成本可能在隱藏頁發生。
- `_syncPunctuationHighlights()` / `_syncFillerWordHighlights()` 會更新 `HighlightTextEditingController`，使 editor TextSpan cache invalidated，再增加重繪成本。

### 建議解法

#### 方案 A：把 proofreading analyzer 移到 isolate

建立純資料輸入/輸出的 analyzer：

```dart
class ProofreadingRequest {
  final String text;
  final List<String> fillerWords;
  final ProofreadingOptions options;
  final int revision;
}

class ProofreadingResult {
  final List<PairIssueDto> pairIssues;
  final List<SymbolIssueDto> symbolIssues;
  final List<LineEndingIssueDto> lineEndingIssues;
  final PunctuationResultDto? punctuationResult;
  final FillerWordAnalysisDto fillerWordAnalysis;
  final int revision;
}
```

UI 只負責：

- 建立 request。
- await result。
- revision 比對。
- 更新 state / highlights。

#### 方案 B：filler word 改成 Trie / Aho-Corasick

目前逐字詞 `RegExp.allMatches(text)` 會隨詞庫大小線性放大。建議改成：

- 詞庫建立 Trie。
- 單次掃描全文找出所有命中。
- 若詞庫未變，不重建 Trie。

這會把 O(words * n) 降成接近 O(n + matches)。

#### 方案 C：只對變更區域做 incremental proofreading

短期可先全章 isolate。中長期可記錄 text diff，對變更行前後有限窗口重算：

- 成對符號與引號巢狀仍需全域狀態，可分段維護 prefix stack。
- 行尾、連續符號、標點 normalize 可按 line incremental。
- 贅字可按變更 range incremental。

### 驗證方式

- 100KB / 500KB / 1MB text 下手動執行 proofreading。
- UI thread frame build 不應超過 16ms 太多；大文字允許顯示 loading，但不應凍結。
- 詞庫 10 / 100 / 1000 筆時測 `_analyzeFillerWords()` 耗時。

## P0-4：同步章節內容時沒有內容相同 early return // OK

### 證據位置

- `lib/presentation/providers/editor_coordinator_provider.dart:463` `syncEditorToSelectedChapter(...)`
- `lib/presentation/providers/editor_coordinator_provider.dart:472` `copiedSegments = List.from(...)`
- `lib/presentation/providers/editor_coordinator_provider.dart:487` `segmentsDataProvider.notifier.updateSegmentsData((_) => copiedSegments)`
- `lib/bin/file.dart:282` `ProjectManager.syncEditorToSelectedChapter(...)`
- `lib/bin/file.dart:300` `currentEditorContent = textController.text`
- `lib/bin/file.dart:302` `chapters = [...segment.chapters]`
- `lib/bin/file.dart:303` `chapters[chapIndex] = chapters[chapIndex].copyWith(...)`

### 問題描述

目前 `_syncEditorToSelectedChapter()` 常在以下操作前被呼叫：

- 切換功能頁。
- 切換手機功能/編輯器。
- 儲存。
- 匯出。
- 開新專案/開檔前檢查 dirty。

但 `ProjectManager.syncEditorToSelectedChapter()` 沒有比較「章節原內容」與「目前 editor text」是否相同。即使內容一樣，也會：

1. 複製 `segmentsData` list。
2. 複製 `chapters` list。
3. 建立新的 chapter copy。
4. 建立新的 segment copy。
5. 呼叫 provider `updateSegmentsData()`。
6. 觸發 snapshot、aggregate provider、可能的 rebuild / dirty timer。

這是典型的「無效寫入」。它不一定每次造成巨大卡頓，但會放大所有頁面切換與儲存前同步成本。

### 影響

- 沒有文字變更時，頁面切換仍可能推送新的 segments state。
- 下游 watch `segmentsDataProvider` 的 UI 會重建。
- Dirty aggregation 可能被無效更新觸發，增加計時器與狀態變更。
- 大型專案中每次切頁都會有不必要 list copy。

### 建議解法

讓 `ProjectManager.syncEditorToSelectedChapter()` 回傳 bool，只有內容真的變更才 update provider。

```dart
static bool syncEditorToSelectedChapter({
  required List<SegmentData> segmentsData,
  required String? selectedSegID,
  required String? selectedChapID,
  required TextEditingController textController,
  required Function(String) updateContentCallback,
}) {
  if (selectedSegID == null || selectedChapID == null) return false;

  final segIndex = segmentsData.indexWhere((seg) => seg.segmentUUID == selectedSegID);
  if (segIndex < 0) return false;

  final segment = segmentsData[segIndex];
  final chapIndex = segment.chapters.indexWhere((chap) => chap.chapterUUID == selectedChapID);
  if (chapIndex < 0) return false;

  final currentEditorContent = textController.text;
  final currentChapter = segment.chapters[chapIndex];
  if (currentChapter.chapterContent == currentEditorContent) return false;

  final chapters = [...segment.chapters];
  chapters[chapIndex] = currentChapter.copyWith(chapterContent: currentEditorContent);
  segmentsData[segIndex] = segment.copyWith(chapters: chapters);
  updateContentCallback(currentEditorContent);
  return true;
}
```

Coordinator 端：

```dart
final changed = ProjectManager.syncEditorToSelectedChapter(...);
if (!changed) return;

ref.read(segmentsDataProvider.notifier).updateSegmentsData((_) => copiedSegments);
```

### 驗證方式

- Widget test：不修改文字，只切換頁面，`segmentsDataProvider` 不應發布新 state。
- Provider test：`hasUnsavedChanges` 不應因無效同步變成 true。
- 大型 project：連續切頁 100 次，rebuild / dirty timer 次數應顯著下降。

# 4. 高優先問題

## P1-1：狀態列行列計算每次從文字開頭掃到游標 //OK

### 證據位置

- `lib/main.dart:1002` `statusContentText = textController.text`
- `lib/main.dart:1004` watch `editorSelectionProvider` cursorOffset
- `lib/main.dart:1044` `_lineColumnFromOffset(statusContentText, statusSelection.cursorOffset)`
- `lib/main.dart:1522` `_lineColumnFromOffset(String text, int offset)`
- `lib/main.dart:1527` `for (int i = 0; i < safeOffset; i++)`

### 問題描述

狀態列為了顯示游標行列，每次 cursor offset 改變都從 `0` 掃到 `offset`。當游標在文末，成本就是 O(章節長度)。

這在短文字不明顯，但小說寫作場景常見長章節。若章節 100KB、游標在文末，每次輸入、方向鍵移動、滑鼠點擊都會掃一次前面所有字元。

### 建議解法

#### 方案 A：換行位置索引

文字變更時建立或更新 `List<int> newlineOffsets`。查詢行列時：

- 用 binary search 找 `cursorOffset` 前最後一個 newline。
- line = newline index + 1。
- column = cursorOffset - previousNewlineOffset。

查詢成本從 O(n) 降為 O(log lines)。

#### 方案 B：增量 cursor cache

記錄上一次：

- offset
- line
- column

若新 offset 與舊 offset 很近，只掃 delta。若跳很遠再 fallback 到 newline index。

#### 方案 C：交給 editor adapter

如果未來主編輯器抽象成 adapter，可把 line/column 計算放在 editor controller 內，避免 `main.dart` 直接掃大字串。

### 驗證方式

- 500KB text，游標在文末，連續輸入 100 次。
- 比較 `_lineColumnFromOffset` 總耗時。
- 目標：單次查詢 < 1ms。

## P1-2：搜尋/高亮已優化但仍有大文字成本與 CI 門檻過鬆

### 證據位置

- `lib/bin/findreplace.dart:84` `_MAX_SEARCH_RESULTS = 1000`
- `lib/bin/findreplace.dart:107` `buildTextSpan(...)`
- `lib/bin/findreplace.dart:145` 建立 highlight boundaries
- `lib/bin/findreplace.dart:165` `text.substring(segmentStart, segmentEnd)`
- `lib/bin/findreplace.dart:847` `findAllMatchesAsync(...)`
- `lib/bin/findreplace.dart:856` `compute(_findAllMatchesTask, ...)`
- `lib/bin/findreplace.dart:863` `findAllMatchesSync(...)`
- `test/findreplace_performance_benchmark_test.dart` 100KB + 1000 matches benchmark
- `test/findreplace_performance_benchmark_test.dart` 門檻 `averageMs < 250`

### 問題描述

搜尋已經比早期好很多，但仍有幾個剩餘成本：

- 每次搜尋會把全文送進 `compute()`，大文字會有 isolate message copy 成本。
- `buildTextSpan()` 仍在 UI thread 切文字並建立多個 `TextSpan`。
- 搜尋結果上限是 1000，但 UI 未必清楚提示使用者結果被截斷。
- Benchmark 目前允許平均 250ms，對互動式文字輸入而言太寬。既有報告曾測到約 7.23ms，若未來回歸到 100ms，測試仍會通過。
- Regex 搜尋可輸入任意 pattern，複雜 regex 仍可能在 isolate 中長時間執行。雖然 UI 不阻塞，但結果延遲與 isolate 資源仍會被占用。

### 建議解法

1. 把 benchmark 門檻改成分層：
   - 100KB + 1000 matches：平均 < 16ms 或 < 25ms。
   - 500KB + 1000 matches：平均 < 50ms。
2. 對簡單搜尋加入 fast path：
   - 非 regex。
   - 不忽略空白。
   - 不忽略標點。
   - match width。
   - match case 或可一次性 lower-case。
   - 使用 `String.indexOf` loop，而不是逐位置逐字比對。
3. 搜尋結果截斷時顯示明確提示：「僅高亮前 1000 筆」。
4. 對 regex 搜尋加上 revision cancellation；新搜尋開始時舊結果直接丟棄。
5. 對 normalization cache 加容量上限，避免同一專案長會話內無界成長。

### 驗證方式

- `flutter test test/findreplace_highlight_test.dart`
- `flutter test test/findreplace_results_cap_test.dart`
- `flutter test test/findreplace_performance_benchmark_test.dart`
- 新增 simple search fast path correctness test。
- 新增連續 100 組搜尋的 cache size test。

## P1-3：主編輯器 CodeField 對大文字仍是全文件渲染模型

### 證據位置

- `lib/bin/content.dart:189` `CodeField(...)`
- `lib/bin/content.dart:151` `RepaintBoundary(...)`
- `lib/bin/findreplace.dart:107` `HighlightTextEditingController.buildTextSpan(...)`

### 問題描述

`CodeField` / `CodeController` 本質上仍是以整份 text 建構富文字 spans。`RepaintBoundary` 已可隔離 repaint 範圍，但無法避免 editor 內部對大文字的 layout / span / selection 成本。

對小說編輯器，真正危險情境是：

- 單章文字非常長。
- 同時開啟搜尋高亮、標點高亮、贅字高亮。
- 每次輸入或取代後整份 text value 改變。

目前的專案已透過 debounce / 上限 / cache 降低成本，但沒有 editor-level virtualization。若目標支援 50 萬字單章或更大，這會是長期瓶頸。

### 建議解法

1. 短期：限制單章建議長度，超過門檻時降低高亮功能密度。
2. 中期：高亮只處理 viewport 附近 ranges，搜尋結果列表仍可完整保留。
3. 長期：評估支援大文本 virtualization 的 editor 元件，或自建「分段文字 buffer + viewport renderer」。

### 驗證方式

- 100KB / 500KB / 1MB text，無高亮、搜尋高亮、校正高亮三種情境。
- DevTools 記錄 build/layout/paint flame chart。
- 指標：輸入後 frame jank 次數、平均 input latency、memory peak。

## P1-4：Provider watch 範圍仍偏寬，部分 build 內做全量計算

### 證據位置

- `lib/main.dart:1012` `segmentsDataProvider.select((segments) => segments)`
- `lib/main.dart:1023` 狀態列每次 build 掃 segments 找目前章節名稱
- `lib/modules/chapterselectionview.dart:943` watch 全量 `segmentsDataProvider`
- `lib/modules/chapterselectionview.dart:1004` `_totalWordCountForMode(segments, wordCountMode)`
- `lib/modules/chapterselectionview.dart:1423` segment subtitle 內 fold chapters 算字數
- `lib/modules/chapterselectionview.dart:1562` chapter subtitle 算 `chapter.getWordCount(...)`
- `lib/presentation/providers/project_state_providers.dart:2039` `projectDataProvider` 聚合 watch 所有 project data

### 問題描述

Riverpod `.select()` 只有在 selector 回傳更小、更穩定的值時才有效。`select((segments) => segments)` 等於仍 watch 整份 segments list。任何章節內容或結構更新都會讓下游重建。

狀態列其實只需要：

- 目前 project name。
- selected segment/chapter name。
- cursor line/column。
- current words。
- total words。

但現在它 watch 全量 segments，再在 build 裡迴圈找名稱。

章節選擇頁也會在 build 中 fold 計算全書/區段字數。雖然章節 word count 有 cache，但如果 cache miss 或資料大，仍會放大 build 成本。

### 建議解法

1. 新增 derived provider：

```dart
final currentChapterPathProvider = Provider<String>((ref) {
  final selection = ref.watch(editorSelectionProvider.select(...));
  final segments = ref.watch(segmentsDataProvider);
  // 只回傳顯示字串，避免 status bar 持有整份 list。
});
```

更理想是 segments notifier 維護 id -> name index，更新結構時才改。

2. 章節選擇頁改用 `totalWordsProvider` 顯示全書字數。
3. Segment word count 也放 provider/cache，不要在 build 裡 fold。
4. `projectDataProvider` 只給儲存/匯出用，不讓 UI 常態 watch；儲存時用 `ref.read(...).collectProjectData()`。

### 驗證方式

- Provider observer 記錄輸入一個字時哪些 provider 發布新值。
- Flutter rebuild tracker 比較 status bar、chapter list 的 rebuild 次數。

## P1-5：大型表單/列表仍有非虛擬化建構

### 證據位置

- `lib/bin/mobile_function_page.dart:81` 手機版一次建立所有頁面
- `lib/modules/glossaryview.dart:1588` category rows 用 `Column(children: rows.map(...).toList())`
- `lib/modules/glossaryview.dart:1841` entry list 外層 `SingleChildScrollView + Column`
- `lib/modules/outlineview.dart:1398` 外層 `SingleChildScrollView`
- `lib/modules/worldsettingsview.dart:515` 外層 `SingleChildScrollView`
- `lib/modules/characterview.dart:1715` 多個 tab 內使用大型 `Column`
- `lib/modules/planview.dart:1521` `ListView(children: [...])` 而不是 builder

### 問題描述

很多模組目前是「資料量小時很直覺」的寫法：`SingleChildScrollView + Column`，或把 rows map 成完整 widgets。當資料量成長時，這會導致：

- 首次進入頁面建構所有子元件。
- 任一 setState 可能重建大量不可視內容。
- 拖曳/排序時 layout 成本提高。

### 建議解法

依資料型態分流：

- 樹狀列表：flatten visible nodes，使用 `ListView.builder` 或 `SliverList`。
- 詳細表單：只建當前選中的 detail panel。
- 多 tab 大表單：使用 `IndexedStack` + lazy tab，或 tab 切換才 mount。
- 詞條列表：`ListView.builder`，避免 `Column(map(...))`。

### 驗證方式

- 建立測試資料：
  - 1000 glossary entries。
  - 1000 outline scenes。
  - 500 world locations。
  - 300 characters。
- 測首屏時間、切換 tab 時間、滾動 frame jank。

## P1-6：XML 開檔/存檔仍有多次全文複製與重複解析 // OK

### 證據位置

- `lib/bin/file.dart:313` `generateProjectXML` 使用 `compute(...)`
- `lib/bin/file.dart:320` `parseProjectXML` 使用 `compute(...)`
- `lib/main.dart:1995` 開檔後先 `FileService.extractProjectVersion(projectFile.content)`
- `lib/bin/file.dart:1684` `extractProjectVersion` 解析整份 XML
- `lib/bin/file.dart:1027` `_ProjectParser.parseProjectXML` 再解析整份 XML
- `lib/bin/file.dart:1038` 每個 `<Type>` 區塊 `element.toXmlString()`
- `lib/bin/file.dart:1045` 各模組 parser 再 parse block XML

### 問題描述

目前開檔流程中，版本檢查會先 parse 一次 XML；真正載入又 parse 一次。`_ProjectParser` 找到 `<Type>` 後，會把 element 重新序列化成字串，交給各模組再 parse。這讓大型專案開啟時有多次 XML DOM / 字串配置。

`compute()` 避免 UI thread 被堵住，是好的。但 isolate 與主 isolate 之間仍要傳遞完整 XML 字串與完整 ProjectData 結果。專案越大，copy 成本越明顯。

### 建議解法

1. 開檔時只 parse 一次 XML，版本號在同一 parse tree 裡取。
2. 各模組 parser 改接收 `xml.XmlElement`，避免 `toXmlString()` 後再 parse。
3. 對大型 XML 顯示 loading/progress；避免使用者以為卡住。
4. 中長期評估更適合大資料的格式：
   - JSON with schema version。
   - 分段儲存章節內容。
   - zip package：metadata JSON + chapters 分檔。

### 驗證方式

- 建立 1MB / 10MB / 50MB `.mnproj`。
- 測 open、save、export 時間與 memory peak。
- 確認 UI thread 在 open/save 期間仍可顯示 loading。

## 5. 中優先問題

## P2-1：字型資源包體過大 //Ignore

### 證據位置

- `pubspec.yaml` fonts 註冊 `NotoSans`、`NotoSansHK`、`NotoSansJP`、`NotoSansKR`、`NotoSansSC`、`NotoSansTC`、`NotoSansThai`
- `assets/fonts/*.ttf` raw total 約 62.6 MiB
- `lib/bin/ui_library.dart` 依 locale 選擇不同 NotoSans family

### 問題描述

目前一次打包多個 CJK 大字型。這能提供跨語系一致顯示，但對安裝包與資源載入不友善。尤其 mobile/web 目標會更有感。

### 建議解法

1. 優先依平台使用 system font fallback。桌面與手機作業系統通常已有 CJK 字型。
2. 只打包主要目標語系字型，例如 TC 或 JP；其他語系改為可選包。
3. 對 release build 做 size analysis：

```powershell
flutter build windows --release --analyze-size
flutter build apk --release --analyze-size
flutter build web --release --analyze-size
```

4. 若仍要全語系支援，建立不同 flavor：
   - `zh-hant`
   - `zh-hans`
   - `jp`
   - `kr`
   - `full`

### 驗證方式

- 比較移除部分字型前後 release artifact 大小。
- 測各語系文字是否 fallback 正常。
- 測首次進入 editor 時 memory。

## P2-2：`SharedPreferences.getInstance()` 重複呼叫

### 證據位置

- `lib/data/repositories/theme_repository.dart:30`
- `lib/data/repositories/theme_repository.dart:49`
- `lib/data/repositories/theme_repository.dart:55`
- `lib/data/repositories/settings_repository.dart:43`
- `lib/data/repositories/settings_repository.dart:75`
- `lib/data/repositories/settings_repository.dart:81`
- `lib/data/repositories/settings_repository.dart:87`
- `lib/data/repositories/settings_repository.dart:93`
- `lib/modules/proofreadingview.dart:483`
- `lib/modules/proofreadingview.dart:610`
- `lib/modules/proofreadingview.dart:631`
- `lib/modules/proofreadingview.dart:654`

### 問題描述

`SharedPreferences.getInstance()` 通常有 cache，不是最大瓶頸。但現在 repository 與 proofreading settings 每次 save 都重新取 instance，會讓程式碼更難控制 IO 生命週期，也增加 async overhead。

### 建議解法

- 在 `core_providers.dart` 建立 `sharedPreferencesProvider`。
- app bootstrap 時初始化一次。
- repository 注入 `SharedPreferences` instance。
- Proofreading settings 也改用 repository/provider，而不是 widget 直接操作 prefs。

### 驗證方式

- 設定頁連續調整 font size / word count mode，不應造成多餘 async hops。
- 單元測試可用 fake preferences。

## P2-3：Controller 在 build/dialog 中臨時建立

### 證據位置

- `lib/modules/worldsettingsview.dart:702` row edit 時 `TextEditingController(text: location.localName)`
- `lib/modules/worldsettingsview.dart:1147` dialog 中 `TextEditingController(text: renamePresetText)`
- `lib/bin/findreplace.dart:1357` optional temp find/replace controllers

### 問題描述

大部分 controller 都有在 State 中建立與 dispose，這點是好的。但仍有少數在 widget build 或 dialog builder 中直接建立。這些通常不是最大瓶頸，但會有：

- rebuild 時游標/輸入狀態重置。
- controller 未明確 dispose。
- 未來如果該 row 頻繁 rebuild，配置成本增加。

### 建議解法

- 編輯 row 使用 `_renameController` 類似 chapter/outline 的做法。
- Dialog 用局部 State class 或 `TextEditingController` 在 showDialog 前建立，`finally` dispose。
- temp controller 若由函式建立，函式結束前 dispose。

## P2-4：大型資料 snapshot / copy-on-write 成本仍需 benchmark

### 證據位置

- `lib/presentation/providers/project_snapshot_utils.dart:32` `snapshotSegmentsData(...)`
- `lib/presentation/providers/project_snapshot_utils.dart:95` `snapshotWorldSettingsData(...)`
- `lib/presentation/providers/project_snapshot_utils.dart:143` `snapshotCharacterData(...)`
- `lib/presentation/providers/project_state_providers.dart:154` `SegmentsDataNotifier`
- `lib/presentation/providers/project_state_providers.dart:502` `WorldSettingsDataNotifier`
- `lib/presentation/providers/project_state_providers.dart:772` `CharacterDataNotifier`
- `lib/presentation/providers/project_state_providers.dart:1125` `GlossaryStateNotifier`

### 問題描述

不可變 snapshot 對 Riverpod state 很合理，也能降低外部 mutation 風險。但大型資料下，小改動可能伴隨：

- list copy。
- map copy。
- nested tree deep copy。
- unmodifiable wrapper。
- downstream provider rebuild。

目前應先透過 benchmark 判斷是否真的熱，再決定是否引入更複雜的資料結構。

### 建議解法

1. 每個大型 domain state 加 revision：
   - `segmentsRevision`
   - `outlineRevision`
   - `worldSettingsRevision`
   - `characterRevision`
   - `glossaryRevision`
2. Aggregate dirty provider 聚合 revision，而不是依賴資料物件 identity/hash。
3. WorldSettings / Glossary / Outline 樹狀資料採局部 copy，避免整棵 deep copy。
4. 對空 list/map 使用共享不可變空集合，減少配置。

### 驗證方式

- 1000 次 character field update。
- 1000 次 outline scene rename。
- 1000 次 world location custom value edit。
- 1000 次 glossary entry edit/move。
- 記錄每次操作平均時間與 memory allocation。

# 6. 已完成且應保留的優化

| 已完成項目 | 位置 | 保留原因 |
|---|---|---|
| 搜尋 debounce 100ms | `findreplace.dart` | 避免每個搜尋字元都立即全文搜尋 |
| 搜尋使用 `compute()` | `findreplace.dart` | 避免大型搜尋直接阻塞 UI isolate |
| `_MAX_SEARCH_RESULTS = 1000` | `findreplace.dart` | 控制高亮 spans 與 selections 數量 |
| `_SelectionCoverageIndex` prefix-max | `findreplace.dart` | 降低 range coverage 查詢成本 |
| `TextChangeDebouncer` | `utils/text_change_debouncer.dart` | 將文字輸入 debounce 集中管理 |
| `_maxConcurrentChapterWordCounts = 6` | `main.dart` | 避免全專案字數重算無限制開 isolate |
| `_allWordCountsGen` / `_activeWordCountGen` | `main.dart` | 防止舊 async 結果回寫 |
| `projectDataAggregateProvider` | `editor_coordinator_provider.dart` | 比多個 dirty listener 更集中 |
| subscription list + close | 多個 State | 降低 listener 泄漏風險 |
| `RepaintBoundary` 包住 editor | `content.dart` | 隔離 editor repaint 對外部 UI 的影響 |

注意：這些優化應用測試鎖住，避免後續重構時回歸。

# 7. 建議修復路線

### Phase 1：1-2 天內可做的高槓桿修復

1. `syncEditorToSelectedChapter()` 加內容相同 early return。
2. 合併 active chapter 字數計算，避免每次輸入雙重 `compute()`。
3. 手機版 `MonogatariMobileFunctionPage` 改 lazy page 建立。
4. `ProofReadingView` 增加 `isActive`，非可視狀態不跑 `_runProofreading()`。
5. 狀態列 `_lineColumnFromOffset()` 加快取或 newline index。
6. 搜尋結果截斷時顯示 UI 提示。

### Phase 2：1 週內的結構優化

1. Proofreading analyzer 移到 isolate。
2. Filler word 掃描改 Trie / Aho-Corasick。
3. 建立 `currentChapterPathProvider`、`segmentWordCountProvider` 等 derived providers。
4. `projectDataAggregateProvider` 改聚合 revision。
5. CI 加入真正有約束力的 performance tests。

### Phase 3：中長期優化

1. 評估大文本 editor virtualization。
2. 大型 project storage 改分段格式，降低 XML DOM 與完整字串 copy。
3. 字型資源依平台/語系拆包。
4. Glossary / Outline / Character 建立大型資料 benchmark 後做局部 copy 結構。

## 8. 建議新增測試

### 8.1 字數計算

- 快速輸入 20 次，只允許最後一次 word count 寫回。
- 切章節後舊 word count 結果不得更新新章節。
- active count 與 chapter cached count 使用同一計算結果。
- 小文字同步、大文字 isolate 的結果一致。

### 8.2 手機 lazy page

- 初始只 mount selected page。
- 未進入 proofreading 頁時，輸入不觸發 proofreading。
- 切換頁面後已訪問頁 state 是否保留，依設計驗證。

### 8.3 無效同步

- 不修改 editor text 時呼叫 sync，不發布新的 `segmentsDataProvider` state。
- 不修改 editor text 時切頁，不標 dirty。
- 儲存前 sync 若無變更，不造成 rebuild storm。

### 8.4 校正文

- 100KB text 執行 proofreading 不阻塞 UI thread。
- filler word 詞庫擴大到 1000 筆仍能在可接受時間內完成。
- 舊 proofreading result 在 revision 過期後不回寫。

### 8.5 搜尋

- 100KB + 1000 matches 平均 `buildTextSpan()` < 16ms 或團隊指定門檻。
- 500KB simple search fast path correctness。
- Regex invalid pattern 不崩潰。
- 搜尋結果超過 1000 時 UI 顯示截斷提示。

## 9. 建議實測場景

### 場景 A：大章節輸入

- 章節大小：10KB、100KB、500KB、1MB。
- 操作：文末連續輸入 100 個字。
- 指標：
  - input latency。
  - UI frame jank。
  - word count compute 次數。
  - `_lineColumnFromOffset` 耗時。

### 場景 B：手機版功能頁

- 視窗寬度 `< 800`。
- 操作：進入功能頁後不切 proofreading，直接到 editor 輸入。
- 指標：
  - mount 的頁面數。
  - `ProofReadingView._runProofreading()` 呼叫次數。
  - 首屏 memory。

### 場景 C：校正文

- 章節大小：100KB、500KB、1MB。
- 詞庫大小：目前、100、1000。
- 操作：打開 proofreading，切換各檢查開關。
- 指標：
  - analyzer runtime。
  - UI thread blocking。
  - highlight update 耗時。

### 場景 D：大型資料模組

- Glossary：100 categories、5000 entries。
- Outline：100 storylines、1000 scenes。
- Character：300 characters。
- WorldSettings：500 locations。
- 指標：
  - 首次進入頁面時間。
  - 單次 edit/move/rename 時間。
  - rebuild count。
  - memory allocation。

### 場景 E：檔案開啟/儲存

- `.mnproj` 大小：1MB、10MB、50MB。
- 操作：open、save、save as、export md。
- 指標：
  - 總耗時。
  - isolate message copy 耗時。
  - memory peak。
  - UI loading 是否順暢。

## 10. 優先級總表

| ID | 問題 | 優先級 | 預估效益 | 修復難度 |
|---|---|---:|---:|---:|
| P0-1 | 輸入時重複字數計算 | 最高 | 高 | 中 |
| P0-2 | 手機一次 mount 14 頁 | 最高 | 高 | 中 |
| P0-3 | Proofreading UI isolate 全文掃描 | 最高 | 高 | 中-高 |
| P0-4 | 無效 sync 仍更新 segments | 最高 | 中-高 | 低 |
| P1-1 | 狀態列 O(n) 行列計算 | 高 | 中 | 低-中 |
| P1-2 | 搜尋高亮 CI 門檻過鬆 | 高 | 中 | 低 |
| P1-3 | CodeField 大文本全文件渲染 | 高 | 高 | 高 |
| P1-4 | Provider watch 範圍偏寬 | 高 | 中 | 中 |
| P1-5 | 大型表單/列表非虛擬化 | 高 | 中-高 | 中 |
| P1-6 | XML 開檔/存檔多次 parse/copy | 高 | 中 | 中 |
| P2-1 | 字型 raw assets 約 62.6 MiB | 中 | 高 | 中 |
| P2-2 | SharedPreferences instance 重複取得 | 中 | 低-中 | 低 |
| P2-3 | 少數 controller 臨時建立 | 中 | 低 | 低 |
| P2-4 | 大型 snapshot/copy-on-write 未 benchmark | 中 | 中 | 中 |

## 11. 建議最小落地清單

若只能先做一小輪，建議順序如下：

1. 在 `ProjectManager.syncEditorToSelectedChapter()` 加內容相同判斷，並讓 coordinator 在無變更時不更新 provider。
2. 刪掉 active chapter 雙重字數計算，或讓兩條路徑共用一次結果。
3. 手機版 `IndexedStack` 改 lazy，只 mount selected/visited pages。
4. `ProofReadingView` 非 active 不監聽或不執行檢查。
5. 狀態列行列計算改 newline offset cache。
6. 把 `findreplace_performance_benchmark_test.dart` 的 250ms 門檻調成實際可防回歸的值。

這六項完成後，使用者最常遇到的「輸入、切頁、手機版、校正文」體感應該會明顯改善。

## 12. 結論

目前專案不是缺少優化意識，而是已經進入「多個合理保護機制互相疊加後，仍需把熱路徑收斂」的階段。搜尋/高亮已經有不錯基礎；接下來真正值得先修的是輸入鏈路中的重複計算、隱藏頁面工作、同步全文校正與無效 state update。

最重要的原則：

- 輸入時只做必要工作。
- 隱藏頁面不要工作。
- 大文字計算要可 debounce、可取消、可丟棄舊結果。
- Provider 不要因無效寫入發布新 state。
- 大型資料列表只建可視範圍。
- 包體資源要按平台/語系控制。

照這個方向處理，專案不需要一次重寫，就能先把最容易讓使用者感覺卡頓的地方降下來。
