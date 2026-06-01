# 專案性能與穩定性問題及詳細解決方案

> **文件更新日期**: 2026年6月2日
> **分析目標**: Monogatari-Assistant-FE (Dart/Flutter Edition)
> **參考報告**: `PERFORMANCE_STABILITY_ANALYSIS.md`, `PERFORMANCE_OPTIMIZATION_REPORT.md`

本報告彙總了專案中目前的性能瓶頸與穩定性風險，並針對各個問題提出了詳細的解決方案。

---

## 📊 執行摘要 (Executive Summary)

本專案主要面臨 **文本處理效能**、**狀態管理與過度重建 (Rebuild)**、**記憶體洩漏與膨脹**、以及 **非同步操作的 Race Condition** 四大類問題。其中，部分**文本高亮 (Highlight)** 的效能問題已經透過 Background Isolate 等方式初步優化，但仍有進一步改善空間。

---

## 🔴 一、文本處理與搜尋高亮效能問題

### 1.1 Highlight 與 Search 計算複雜度過高
* **問題點**：在 `HighlightTextEditingController.buildTextSpan()` 中，範圍檢查複雜度高達 `O(N*M)`。若在 50KB 以上的文本中伴隨多個搜尋結果，每輸入一個字元皆會觸發重新計算，造成明顯的輸入延遲 (Jank)。
* **目前進展**：已實作基礎 Debounce、Regex 預編譯，並將搜尋移至 **Background Isolate** 中進行，延遲已減少約 15% (7.23ms)。
* **詳細解決方案 (未來優化)**：
  1. 導入 **區間樹 (Interval Tree)** 或 **線段樹 (Segment Tree)**，將線性搜尋降級為 `O(log N)`。
  2. 實作 **增量更新 (Incremental Dirty-Range Updates)**：不必每次 Paint 都重新建構整個 Spans，僅對修改範圍 (Dirty range) 內的 TextSpans 進行差異更新。

### 1.2 字數計算阻塞主執行緒與取消機制缺失
* **問題點**：字數計算雖然使用了 `compute()`，但主程式 (例如 `main.dart` 中的 `_updateAllWordCounts`) 缺乏取消防護。使用者若快速切換章節，背景完成的字數結果返回時，舊的 Widget 可能已銷毀，引發 `setState on disposed widget` 崩潰。
* **詳細解決方案**：
  1. 建立 Revision (版本號) 機制，或導入 `CancelToken`。異步返回時驗證版本號或 `mounted` 狀態。
  2. 使用類似 `_AllWordCountsUpdateState` 的狀態封裝類別，在元件 `dispose` 或切換專案時，自動呼叫 `cancelPending()` 撤銷進行中的計算。

### 1.3 重複的字元正規化 (Normalization) 操作
* **問題點**：每次搜尋時對每個字元呼叫 `normalizeCase()` 與 `normalizeWidth()`，每次呼叫都進行 50+ 個 Unicode 範圍檢查，極端消耗 CPU 資源。
* **詳細解決方案**：建構 **正規化快取 (Normalization Cache)**。利用 `Map<String, String>` 將已轉換過的字元結果進行暫存，避免重複計算。

---

## 🟠 二、狀態管理與過度重建 (Listener Hell & Rebuilds)

### 2.1 Riverpod Listener 訂閱爆炸
* **問題點**：`editor_coordinator_provider.dart` 的 `_setupProjectDirtyListeners` 內綁定了 9 個獨立的 `ref.listen`。任一資料變更時（如單次輸入），引發連鎖擴散與重複觸發，理論上可導致 15-50+ 次非必要的 Widget Rebuild。
* **詳細解決方案**：
  1. **Listener 聚合**：建立單一的 `aggregatedDirtyProvider` 來匯集各種資料的 Dirty 標記，讓 UI 只 `listen` 這個聚合點。
  2. **縮小依賴**：要求所有 `ref.watch` 皆須搭配 `.select()` 精確監聽所需欄位，而非監聽整個 Controller。

### 2.2 ListenManual 的 Subscription 洩漏風險
* **問題點**：某些手動訂閱如 `_editorContentSubscription` 雖有呼叫 `cancel()`，但連續的 `cancel()` 未經過 Try-Catch 處理。若前一個 Subscription 取消拋出異常，後續的清理操作將被強制中斷，造成永久性 Memory Leak。
* **詳細解決方案**：將所有的 Subscription 放進陣列，在 `dispose()` 時使用 `for` 迴圈搭配 `try-catch` 確保每個 `.cancel()` 皆獨立並且安全執行。

---

## 🟡 三、記憶體累積問題 (Memory Accumulation)

### 3.1 Character/Outline 編輯模式下的暫存累積
* **問題點**：長會話期間，多次編輯角色的 Lists (喜惡、專長等) 會建立大量臨時物件 (Copy-on-write 產生大量 Lists)，累積峰值可達 1MB 以上，在移動裝置可能引發 OOM。
* **詳細解決方案**：
  1. 實作 **Lazy Loading (延遲初始化)**，只在區塊展開時才初始化列表。
  2. 對於空列表，預設參照 `const []`，避免物件複製浪費。
  3. 實作定期清理機制，釋放無效的舊快照 (Snapshots)。

### 3.2 搜尋結果集的無界增長
* **問題點**：遇到常態字元 (如：「的」) 在大文本搜尋時，可能返回 5,000 以上的 `TextSelection` 陣列，佔用大量記憶體。
* **詳細解決方案**：實作最大容量限制，設定如 `_MAX_SEARCH_RESULTS = 1000`，若匹配陣列大於上限，主動截斷並向使用者展示「僅顯示前 1000 筆結果」的提示。

---

## 🔵 四、非同步操作與 Race Condition　//OK

### 4.1 Timer Debounce 嵌套導致狀態不一致
* **問題點**：`_onTextChanged` 同時維護字數更新的 Debounce (`50ms`) 與存檔更新的 Debounce (`500ms`)。兩者未經同步管理，`50ms` 的操作可能在 `500ms` 之前改變共用狀態，進而產生不一致的錯誤狀態。
* **詳細解決方案**：封裝單一的 `TextChangeDebouncer` 控制器。由其統籌管理所有的非同步任務堆疊，統一執行序並排解 Race Condition。

---

## 🟣 五、UI 構建效能障礙

### 5.1 CodeTextController 的過度渲染
* **問題點**：文字輸入框結合 Regex 高亮時，每輸入一個字元，`CodeController` 就會把文本轉換為富文本 (`RichText`) 並重新 Paint 整塊渲染樹。
* **詳細解決方案**：
  1. 善用 **`RepaintBoundary`** 將編輯器區塊獨立隔離，避免與外部（如側邊欄、設定畫面）的 Rebuild 互相干擾。
  2. 將主題 (`themeColor`, `themeMode`, `fontSize`) 結合並實作單一 Configuration Provider，減少父層 ContentView 誤觸發的全面重繪。