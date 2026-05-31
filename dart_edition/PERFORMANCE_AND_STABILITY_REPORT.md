# 性能與穩定性問題報告與修正建議

**專案**: Monogatari-Assistant-FE (Dart / Flutter)

**目的**: 列出程式碼中已觀察到或文件提及的性能與穩定性風險，並提供具體、可執行的解法與優先順序。

---

## 總覽（快速關鍵點）
- 主要性能瓶頸集中在文字搜尋/高亮、字數計算，以及過度的 provider/listener 訂閱。
- 穩定性風險包含異步競態 (race conditions)、listener/subscription 洩漏、以及在 widget disposed 後仍呼叫 `setState()`。
- 優先修復建議：
  1. 修正高頻率的 UI 重建與不必要的同步計算（高影響，優先）
  2. 加入取消/版本檢查以避免 race condition（中高）
  3. 控制搜尋/高亮結果上限與緩存（中）
  4. 合併與精簡 provider 依賴，避免 listener 爆炸（中高）

---

## 具體問題與建議修正

### 1) Text search / highlight 計算過重（高影響）
- 位置: [lib/bin/findreplace.dart](lib/bin/findreplace.dart)
- 問題: 每次 rebuild 或每次文字變更時，整段文本可能被 O(N*M) 的邊界檢查與規範化掃描，導致輸入延遲與 UI 卡頓。

建議修正 (步驟):
- 使用區間樹 (interval tree) 或更快的索引結構來存放 match 範圍，將查詢從線性降為對數或常數平均時間。
- 將高亮計算移到 background isolate（`compute()` 或自訂 Isolate pool），UI 只接收最終範圍集合。
- 實作增量更新：僅當變更影響到目前可視段落（viewport）時才重新計算高亮。
- 對常用的規範化結果使用緩存 (normalization cache) 以避免重複 Unicode 處理。

參考實作片段:

```dart
// 範例: 使用緩存的規範化函式
final Map<String,String> _normCache = {};
String normalizeCached(String s, FindReplaceOptions opt) =>
  _normCache.putIfAbsent('\$s-\$opt', () => normalizeSlow(s, opt));
```

優先級: 高。影響使用者互動流暢度，建議第一時間在 `findreplace` 與 `HighlightTextEditingController` 實作。

---

### 2) 字數計算與並發控制（中高）
- 位置: [lib/main.dart](lib/main.dart) 與 [lib/presentation/providers/word_count_providers.dart](lib/presentation/providers/word_count_providers.dart)
- 問題: 雖然部分 providers 已使用 revision/debounce 機制，但 `MainApp` 的 `_updateAllWordCounts()` 與其他 async 呼叫仍存在在 widget disposed 後 `setState()` 或 race condition 的風險。

建議修正 (步驟):
- 在所有觸發長耗時計算的地方加入 **版本號 (revision/gen)** 或 CancelToken，並在更新 UI 前檢查是否仍為最新任務。
- 將大批次計算限制並行數（專案中已定 `_maxConcurrentChapterWordCounts`，請保留），並在每批次開始時檢查 `mounted` 與 `gen` 是否仍有效。
- 在 provider 層面優先讓 providers 負責計算並保留最小的 UI 端領域去呼叫 `setState()`，採用 `ref.read(...notifier).setX()` 以減少直接在 widget 邏輯內大量 `setState()`。

參考: `MainApp` 中 `_updateAllWordCounts()` 已包含 `gen` 檢查，請擴展到其他 async 路徑並統一實踐。

優先級: 中高。

---

### 3) Provider/listener 過度訂閱與重建風暴（中高）
- 位置: [lib/presentation/providers/editor_coordinator_provider.dart](lib/presentation/providers/editor_coordinator_provider.dart)
- 問題: 多處 `ref.listen(...)` 導致單一改動引發多次連鎖更新與大量重建。

建議修正 (步驟):
- 合併相關狀態成一個聚合 provider（aggregated provider），使變更只發出必要的單一信號。
- 使用 `select()` 精準訂閱 provider 中的具體欄位，避免 watch 整個物件。
- 對於不必立即反應的狀態（例如 dirty flag 的顯示），使用 throttle/debounce 與 batch 更新。

優先級: 中高。可快速改善重建次數與 UI 流暢性。

---

### 4) Subscription / listenManual cast 與清理（中）
- 位置: [lib/main.dart](lib/main.dart)
- 問題: `listenManual` 的回傳型別被不安全地轉型為 `StreamSubscription`，且在 dispose 時若一個 cancel 拋出異常，後續清理可能被跳過。

建議修正 (步驟):
- 統一管理 subscriptions 陣列，dispose 時使用 try/catch 單獨取消每個 subscription，並記錄錯誤。

範例:

```dart
final subs = <Cancelable>{...};
@override
void dispose() {
  for (final s in subs) {
    try { s.cancel(); } catch(e) { debugPrint(e.toString()); }
  }
  super.dispose();
}
```

優先級: 中。

---

### 5) 搜尋結果無界增長（中）
- 位置: [lib/bin/findreplace.dart](lib/bin/findreplace.dart), `HighlightTextEditingController`
- 問題: 搜尋結果列表可能非常大 (常用詞於長文檔)，在記憶體與 UI 處理上造成壓力。

建議修正:
- 為搜尋結果設置上限（例如 1000 條），並在 UI 上提供「顯示前 N 筆」與「顯示全部（警告）」選項。
- 在結果極大時，改為只索引與顯示靠近 cursor 或當前 viewport 的結果。

優先級: 中。

---

### 6) 內存累積：臨時資料與快照管理（中）
- 位置: [lib/modules/characterview.dart](lib/modules/characterview.dart) 等多處
- 問題: 多個物件保留大量臨時列表與過度複製，長會話導致內存峰值與 GC 頻繁。

建議修正:
- 採用延遲初始化（lazy init）與按需展開（expand-on-demand）資料結構。
- 對大型集合採用不可變快照與共享結構 (structural sharing) 避免重複複製。
- 增加周期性快照清理與弱參照 (WeakReference) 機制（若需）以釋放未使用資源。

優先級: 中。

---

### 7) 異步錯誤處理與 UI 對話框競態（低中）
- 位置: [lib/main.dart](lib/main.dart) 中 `showDialog` 後的 `mounted` 檢查
- 問題: 已使用 `addPostFrameCallback` 與 `mounted` 檢查，建議在所有 await showDialog 後再檢查 `mounted`（部分情況已處理但需統一）。

建議修正:
- 在所有 `await showDialog(...)` 後確認 `mounted` 再執行狀態更新或 provider 操作。

優先級: 低中。

---

## 建議的執行計畫（短期到中期）
1. 立即 (1-2 週):
   - 在 `findreplace` 與高亮邏輯實作緩存與基礎的結果上限；將大計算移到 `compute()`。
   - 在所有 async 更新前加入 revision/gen 檢查以避免 setState on disposed。
2. 次階段 (2-6 週):
   - 合併 provider 與使用 `select()` 精準訂閱，減少重建。
   - 重構大型集合的記憶體使用，採延遲初始化與共享快照策略。
3. 長期 (6 週以上):
   - 導入更完整的 Isolate 池（若需要），並對 UI-heavy 操作做壓力測試。
   - 在 CI 中加入性能追蹤（integration test + perf benchmarks）與回歸警示。

---

## 後續我可以幫忙的項目（選一或多項）
- 將 `findreplace` 的高亮計算改為 isolate 實作 (我可以提交 patch)
- 在 `MainApp` 中一處一處補上 revision/cancel 檢查 (我可以自動加 patch)
- 合併複數 provider 實作成 aggregated provider (我可以草擬 PR)

---

報告生成於: 2026-05-31
