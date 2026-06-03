# 260603 Codex Perf / Stability Problem

> 整理日期：2026-06-03  
> 專案：Monogatari-Assistant-FE / dart_edition  
> 範圍：Flutter/Dart 前端的性能瓶頸、穩定性風險、已修復項目與後續解法  
> 參考：`PERFORMANCE_STABILITY_ANALYSIS.md`、`PERFORMANCE_OPTIMIZATION_REPORT.md`、`PERFORMANCE_ISSUES_AND_SOLUTIONS.md`、目前程式碼掃描

## 1. 總結

2026-06-03 當下，專案已處理掉幾個原本較高風險的問題：

- 搜尋與高亮已加入 debounce、背景 isolate、搜尋結果上限與 prefix-max coverage index。
- Dirty listener 已由多個獨立 listener 收斂成 `projectDataAggregateProvider`。
- `listenManual` 訂閱清理已改成 `ProviderSubscription.close()` 並以 try-catch 保護。
- 全專案字數統計已加入 generation guard、`mounted` 檢查與並行上限。
- 文字輸入 debounce 已封裝成 `TextChangeDebouncer`。

目前剩餘風險主要集中在三類：

1. 大文本搜尋、高亮與字元 normalization 仍可能造成 CPU 尖峰。
2. 長時間編輯或快速切章節時，仍需補測試鎖住 async 回寫與 pending commit 的邊界。
3. 大型 Glossary、Outline、Character 資料的 copy-on-write 與快取策略仍可能造成長會話記憶體累積。

## 2. 問題總覽

| ID | 類型 | 風險 | 狀態 | 主要位置 |
|---|---|---:|---|---|
| P1 | 搜尋 / 高亮渲染成本 | 中 | 已優化，仍需性能門檻 | `lib/bin/findreplace.dart` |
| P2 | 搜尋 normalization 快取無容量上限 | 中 | 已有快取與清理，仍需上限 | `lib/bin/findreplace.dart` |
| P3 | 全專案字數統計 CPU 尖峰 | 中 | 已加 guard 與並行上限 | `lib/main.dart` |
| P4 | Editor debounce 兩條 timer 路徑 | 中 | 已封裝，仍需章節 snapshot 防護 | `lib/utils/text_change_debouncer.dart`、`lib/main.dart` |
| P5 | Dirty aggregation fingerprint 精度 | 中 | 已聚合，仍需 revision 化 | `lib/presentation/providers/editor_coordinator_provider.dart` |
| S1 | 舊 async 結果回寫 | 低-中 | 多處已防護，仍需回歸測試 | `lib/main.dart` |
| S2 | 長會話記憶體累積 | 中 | 部分快取已清理，仍需 profiling | 多個 module / provider |
| S3 | 大型資料深層複製成本 | 中 | 待 benchmark | Glossary / Outline / Character 相關 provider |

## 3. P1：搜尋與高亮渲染成本

### 問題

`HighlightTextEditingController.buildTextSpan()` 需要根據搜尋結果、標點結果與 filler word 結果切分文字並建立 spans。即使搜尋本身已移到背景 isolate，span 建構與 layout/paint 仍在 UI thread 上發生。

在大文本中，若同時存在：

- 搜尋結果接近上限
- punctuation highlight
- filler word highlight
- 頻繁輸入導致高亮重新計算

仍可能造成輸入延遲或 frame jank。

### 已完成改善

- `HighlightTextEditingController._MAX_SEARCH_RESULTS = 1000`
- `_SelectionCoverageIndex` 使用 prefix-max index，降低 range coverage 查詢成本。
- `findAllMatchesAsync()` 使用 `compute()`，搜尋計算移至背景 isolate。
- 背景搜尋結果可附帶 precomputed index，降低主執行緒重建成本。
- 既有測試包含：
  - `test/findreplace_highlight_test.dart`
  - `test/findreplace_results_cap_test.dart`
  - `test/findreplace_performance_benchmark_test.dart`

### 剩餘風險

- `buildTextSpan()` 仍需依 boundaries 切分文字，boundary 數越高，主執行緒成本越高。
- 結果上限是保護措施，但使用者可能不知道實際搜尋結果被截斷。
- benchmark 若未納入 CI，未來改動可能讓成本回升。

### 解法

1. 將 `findreplace_performance_benchmark_test.dart` 變成 CI 回歸門檻。
2. 設定明確性能門檻，例如 100KB text + 1000 matches 的 `buildTextSpan()` 平均時間低於 10ms，實際門檻可依目前測得數據微調。
3. UI 顯示結果截斷提示，例如「結果過多，僅顯示前 1000 筆」。
4. 若 profiling 仍顯示 `buildTextSpan()` 是熱點，再實作 incremental dirty-range update，只重建被修改區段。

### 驗證

```powershell
flutter test test/findreplace_highlight_test.dart
flutter test test/findreplace_results_cap_test.dart
flutter test test/findreplace_performance_benchmark_test.dart
```

## 4. P2：搜尋 normalization 快取無容量上限

### 問題

搜尋時會處理大小寫、全半形、標點與空白忽略等條件。`findreplace.dart` 已有 `_normalizationCache`，可避免重複 normalization，但目前快取是全域 map，長時間同一專案內大量搜尋不同字元組合時，仍可能累積。

### 已完成改善

- `_normalizationCache` 已存在。
- `clearNormalizationCache()` 已提供清理入口。
- 套用新 project data 時會清理 normalization cache，降低跨專案累積。

### 剩餘風險

- 同一專案長時間搜尋不同文字時，快取仍可能成長。
- 複雜選項組合會增加 cache key 數量。
- 簡單搜尋仍可能走逐字比對，未充分利用 `String.indexOf`。

### 解法

1. 對 `_normalizationCache` 加容量上限，例如 512 或 1024 entries。
2. 採用簡易 LRU 或 FIFO eviction，避免 map 無界成長。
3. 對以下條件加入快速路徑：
   - 非 regex
   - 不忽略標點
   - 不忽略空白
   - 不做寬度轉換
   - case-sensitive 或可先一次性 lower-case
4. 對 regex 搜尋增加結果數與耗時觀測，避免複雜 regex 長時間消耗背景 isolate。

### 驗證

- 建立 benchmark：100KB text，連續搜尋 100 組不同關鍵字。
- 驗證 cache size 不超過上限。
- 驗證簡單搜尋結果與原本逐字演算法一致。

## 5. P3：全專案字數統計 CPU 尖峰

### 問題

`_updateAllWordCounts()` 會對所有章節計算字數。雖然單章計算使用 async / isolate，但大型專案中仍會同時啟動多個工作，造成短時間 CPU 尖峰。

### 已完成改善

- `_allWordCountsGen` generation guard。
- 多處 `mounted` 檢查。
- `_maxConcurrentChapterWordCounts = 6` 限制並行數。
- 章節內容與 word count mode snapshot 比對，避免過期結果回寫。

### 剩餘風險

- 6 個並行工作對低階裝置或 mobile 可能仍太高。
- 大量章節同時重算時，使用者會感到短暫卡頓。
- 未變更章節若未命中快取，仍會參與重算。

### 解法

1. 依平台或 CPU core 數調整並行上限：
   - Desktop：4-6
   - Mobile：2-3
2. 先更新目前章節字數，再以低優先級漸進更新其他章節。
3. 對空內容、內容未變更、mode 未變更且已有快取的章節直接跳過。
4. 將全專案字數統計狀態改成 provider 層管理，UI 只 watch 必要欄位。

### 驗證

- 建立 100、500、1000 章節測試資料。
- 觀察切換專案後首 3 秒 CPU 使用率。
- 測試快速開檔後立刻切另一個專案，不得出現舊結果回寫或 exception。

## 6. P4：Editor debounce 兩條 timer 路徑

### 問題

`TextChangeDebouncer` 目前同時管理：

- 字數更新：`wordCountDelay = 500ms`
- 內容提交：`contentCommitDelay = 200ms`

這比舊版直接散落在 widget 中更清楚，但兩條 timer 仍可能在快速輸入、切章節、儲存、開新專案時碰到同步邊界。

### 剩餘風險

- pending content commit 在切章節前後 flush，可能誤寫到錯誤章節。
- word count callback 回來時，章節或 segment 已切換。
- 儲存前 `_flushPendingEditorContent()` 與 provider 同步順序若不一致，可能短暫漏存最後輸入。

### 解法

1. pending content commit 附帶 chapter id / segment id snapshot。
2. word count callback 也附帶同一組 snapshot。
3. callback 執行時若 snapshot 與目前 active chapter 不一致，直接丟棄。
4. 儲存、切章節、開檔前統一呼叫 `flushPendingContentCommit()`，並在 flush 後再讀取 provider snapshot。

### 驗證

- 新增 widget test：快速輸入後立即切章節，確認內容落在原章節。
- 新增 widget test：快速輸入後立即儲存，確認最後一次輸入有被保存。
- 新增 test：切換章節後舊 word count callback 不得更新新章節字數。

## 7. P5：Dirty aggregation fingerprint 精度

### 問題

`projectDataAggregateProvider` 已將多個 project data provider 聚合成單一 signal，這能降低 listener 數量。不過目前聚合值主要由 length 與 shallow hash 組成，仍有 fingerprint 精度問題。

### 已完成改善

- 多個 dirty listener 已收斂成單一 `ref.listen<int>(projectDataAggregateProvider, ...)`。
- `_dirtyTimer` 對 dirty 標記做 debounce。
- 避免單一欄位變更引發多條 listener 連鎖。

### 剩餘風險

- 深層資料變更若 outer hash 或 length 沒有可靠變化，可能漏標 dirty。
- hash 過於粗略也可能造成不必要 dirty 標記。
- 以資料物件 hashCode 表示語意版本，長期維護不夠明確。

### 解法

1. 每個 project state notifier 維護明確 revision。
2. 任一寫入操作都遞增對應 revision。
3. `projectDataAggregateProvider` 聚合 revision，而不是推導 shallow fingerprint。
4. 補測深層資料變更案例：
   - outline scene 修改
   - character list item 修改
   - world setting nested value 修改
   - glossary entry move / rename / edit

### 驗證

```powershell
flutter test test/providers/project_dirty_provider_test.dart
```

並新增深層資料變更必須觸發 `hasUnsavedChanges` 的 provider tests。

## 8. S1：舊 async 結果回寫

### 問題

背景搜尋、字數計算、project loading、save/export 等流程都可能在使用者切換章節或專案後才完成。若沒有 generation guard 或 snapshot check，舊結果可能寫回新狀態。

### 目前狀態

多數熱點已加入：

- `mounted` check
- generation check
- snapshot compare
- try-catch cleanup

因此風險已從高降為低-中，但仍需要壓力測試。

### 解法

1. 對所有 async callback 統一採用三段式檢查：
   - 開始前建立 generation / snapshot。
   - await 後檢查 `mounted` 與 generation。
   - 寫回前再次確認 active project / chapter / segment。
2. debug 模式加入 optional log，記錄被丟棄的舊 async 結果。

### 驗證情境

- 開啟大型專案後立刻再開另一個專案。
- 搜尋進行中修改文字。
- 切換字數模式時快速切章節。
- 儲存期間持續輸入。

## 9. S2：長會話記憶體累積

### 問題

長時間編輯同一專案時，以下資料可能反覆配置：

- normalization cache
- chapter word count cache
- glossary category tree snapshot
- outline scene tree snapshot
- character list copy-on-write 結果
- text controller 暫存狀態

### 已完成改善

- `clearNormalizationCache()` 可清理搜尋 normalization cache。
- `ChapterData.clearAllWordCountCache()` 可清理章節字數快取。
- 多數 controller 已有 `dispose()` 清理。

### 剩餘風險

- 同一專案內長時間操作不一定會觸發跨專案 cache clear。
- 大型樹狀資料每次小改動都可能產生較大的 snapshot。
- Flutter GC 會回收短生命物件，但高峰配置仍可能造成 jank。

### 解法

1. 對 normalization cache 加上容量上限。
2. 對 Glossary / Outline / Character 做長會話 memory profiling。
3. 空集合優先使用不可變空集合，減少重複配置。
4. 大型樹狀資料若 profiling 顯示成本過高，改採局部更新與 revision。

### 驗證

- 連續執行 1000 次 glossary edit / move / rename。
- 連續執行 1000 次 outline scene edit。
- 連續執行 1000 次 character list edit。
- 觀察記憶體是否能在 GC 後回落。

## 10. S3：大型 Glossary / Outline 深層複製成本

### 問題

不可變狀態與 copy-on-write 能提高狀態一致性，但在大型資料中，小改動若造成整棵樹複製，會增加 CPU 與記憶體壓力。

### 解法

1. 為 Glossary 建立 benchmark：
   - 100 categories
   - 5000 entries
   - 連續 rename / move / edit
2. 為 Outline 建立 benchmark：
   - 100 chapters
   - 1000 scenes
   - 連續 reorder / edit / delete
3. 若 benchmark 顯示複製成本過高：
   - 保留不可變 state 邊界。
   - 內部改採局部 copy。
   - 用 revision 表示變更，而不是每次重建完整索引。

## 11. 已改善項目對照

| 舊問題 | 目前狀態 |
|---|---|
| 搜尋結果無界增長 | 已有 `_MAX_SEARCH_RESULTS = 1000` |
| 搜尋高亮每次重建 coverage index | 已加入 `_SelectionCoverageIndex` 快取與 precomputed index |
| 搜尋阻塞 UI | 已使用 `compute()` 背景 isolate |
| RegExp 重複建立 | 已使用 top-level precompiled regex |
| 多個 dirty listener 造成 listener hell | 已聚合為 `projectDataAggregateProvider` |
| `listenManual` 清理不安全 | 已改用 subscription list + try-catch close |
| `_updateAllWordCounts()` 缺少 disposed guard | 已加入 generation / mounted / snapshot 檢查 |
| debounce timer 散落於 widget | 已封裝為 `TextChangeDebouncer` |
| normalization cache 跨專案累積 | 套用 project data 時已有清理 |

## 12. 建議優先級

### 第一優先：補測試與回歸門檻

- 將 `findreplace_performance_benchmark_test.dart` 納入 CI 性能門檻。
- 補深層資料變更 dirty tests。
- 補快速輸入後切章節 tests。
- 補搜尋中修改文字時舊結果丟棄 tests。

### 第二優先：降低 CPU 尖峰

- `_normalizationCache` 加容量上限。
- `findAllMatchesSync()` 加 simple search 快速路徑。
- 全專案字數統計依平台調整並行數。
- 未變更章節直接跳過字數重算。

### 第三優先：長會話記憶體優化

- Glossary / Outline / Character 加 benchmark。
- 大型樹狀資料改局部 copy 或 revision 化。
- 加入 debug-only memory / cache size telemetry。

## 13. 最小驗證清單

```powershell
flutter test test/findreplace_highlight_test.dart
flutter test test/findreplace_results_cap_test.dart
flutter test test/findreplace_performance_benchmark_test.dart
flutter test test/providers/project_dirty_provider_test.dart
flutter test
```

## 14. 結論

專案已經從「多個高風險性能與穩定性問題」進入「已有防護，但需要測試與 profiling 鎖住成果」的階段。

後續重點不是大改架構，而是：

1. 補足回歸測試，避免已修掉的 async、listener、search 問題回來。
2. 對大文本搜尋與全專案字數統計建立明確性能門檻。
3. 對大型 Glossary / Outline / Character 操作做 benchmark，確認是否需要局部 copy 或 revision 化。

這份文件可作為後續修復、性能驗收與回歸測試的追蹤清單。
