# Monogatari Assistant Flutter 介面、渲染、效能與記憶體審查

審查日期：2026-08-25  
審查範圍：`dart_edition/lib`、`dart_edition/assets`、`pubspec.yaml`、`analysis_options.yaml` 與相關測試  
審查方式：依 `flutter-dart-code-review` 清單進行靜態審查、生命週期配對、重建邊界、演算法複雜度、資產大小與測試保護盤點

> 限制：目前環境找不到 `flutter` 與 `dart` 指令，因此本次無法執行 `flutter analyze`、`flutter test`、DevTools Track Widget Builds、frame timeline 或 heap snapshot。以下結論以程式碼可直接證明的呼叫路徑與複雜度為主；實際毫秒數與 retained heap 仍需在 profile/release mode 量測。

## 結論摘要

目前最值得先處理的不是零星 `const` 或 controller 遺漏，而是三條會隨文件、角色關係或工作階段長度放大的結構性路徑：

1. 協作文字在每次輸入時重新線性化全文、重建 grapheme/atom 集合，並複製持續增長的 operation map；部分欄位連游標移動也會走完整文字編輯流程。
2. 所有功能頁由 `IndexedStack` eager build 並常駐；隱藏的校對頁仍監聽每次文字變更、啟動 timer 與 worker。
3. 人物關係圖把 graph mapping、節點配置、邊避障與標籤配置放在同步 `build()` 路徑，搜尋、選取與縮放控制狀態都可能重跑昂貴計算。

風險分布：

| 等級 | 數量 | 意義 |
| --- | ---: | --- |
| P0 | 1 | 長篇輸入的核心路徑，會同時放大 CPU、配置量與 retained memory |
| P1 | 5 | 一般使用可遇到明顯延遲、背景 CPU、畫面不同步或大範圍重建 |
| P2 | 6 | 特定視窗尺寸、長工作階段、深色模式或交付資源下明顯 |

建議先做的三件事：

1. 先在 project text listener 加入「文字未變只更新 cursor」的 fast path，避免游標移動觸發 CRDT diff 與 provider state emission。
2. 為 CRDT 增加 cached linearization／增量 edit，並設計 checkpoint + acknowledged-operation compaction；這是長篇輸入與長工作階段的根治項目。
3. 功能頁改 lazy construction，校對 worker 受頁面可見性控制；未開啟校對頁時不應分析全文。

## 問題清單

| ID | 優先級 | 類別 | 問題 |
| --- | --- | --- | --- |
| CRDT-01 | P0 | 效能／記憶體 | 每次文字編輯重建全文 CRDT view，且 operation/tombstone 無 compaction |
| CRDT-02 | P1 | 渲染／狀態 | Project text 的游標移動也觸發全文 diff 與 provider emission |
| UI-01 | P1 | 記憶體／背景 CPU | 所有功能頁 eager build；隱藏校對頁持續分析 |
| RENDER-01 | P1 | 渲染／效能 | 人物關係圖在每次 build 同步重算高成本 layout |
| STATE-01 | P1 | 介面正確性 | `ref.listen` 只在第一次 build 註冊，下一次 rebuild 後 listener 失效 |
| BG-01 | P1 | CPU／耗電 | 協作 provider 在未連線時仍每 80 ms polling |
| REBUILD-01 | P2 | 渲染／效能 | CharacterView 的 provider/rebuild 邊界過大，私有 builder 不是重建邊界 |
| IMAGE-01 | P2 | 記憶體／解碼 | 1024×1024 app icon 以 40～64 px 顯示但按原尺寸解碼 |
| UI-02 | P2 | 響應式介面 | 快照 dialog 強制最小 420 px 高，低高度／橫向螢幕可能 overflow |
| UI-03 | P2 | 主題／介面 | 共用 table 在深色模式仍使用固定淺灰 border |
| A11Y-01 | P2 | 介面／可操作性 | 8 px resize divider 只有 pointer drag，無鍵盤與語意操作 |
| TOOL-01 | P2 | 防回歸 | analyzer 不嚴格、無 golden、CI 未完整覆蓋 Flutter 品質門檻 |

## 詳細發現與解法

### CRDT-01（P0）：每次文字編輯重建全文 CRDT view，operation/tombstone 持續成長

證據：

- 主編輯器 controller 每次文字變更立即呼叫 `recordLocalTextEdit`：[`main.dart:843`](dart_edition/lib/main.dart#L843)、[`main.dart:859`](dart_edition/lib/main.dart#L859)。
- `createLocalEdit` 先透過 `text` 走訪全部 atoms，再把 current/next 全文轉成 grapheme list，之後又取一次 `visibleAtomIds`：[`collaborative_text.dart:103`](dart_edition/lib/domain/collaboration/collaborative_text.dart#L103)、[`collaborative_text.dart:131`](dart_edition/lib/domain/collaboration/collaborative_text.dart#L131)、[`collaborative_text.dart:152`](dart_edition/lib/domain/collaboration/collaborative_text.dart#L152)。
- `_orderedAtoms()` 每次都為全部 atom 重建 `Map<TextAtomId?, SplayTreeSet<TextAtomId>>`：[`collaborative_text.dart:293`](dart_edition/lib/domain/collaboration/collaborative_text.dart#L293)。
- 每個 insert/delete 又複製完整 atom map、tombstone set：[`collaborative_text.dart:92`](dart_edition/lib/domain/collaboration/collaborative_text.dart#L92)、[`collaborative_text.dart:117`](dart_edition/lib/domain/collaboration/collaborative_text.dart#L117)。
- 每筆 operation 再複製完整 `_operations` map：[`collaboration_document.dart:339`](dart_edition/lib/domain/collaboration/collaboration_document.dart#L339)。目前只看得到 batch 上限，沒有已確認 operation 的淘汰或 checkpoint compaction。

影響：

- 單次按鍵至少包含多次 O(N) 全文 traversal／配置，`SplayTreeSet` 建構還會帶入排序成本。
- 長章節、快速輸入、貼上或 Replace All 會造成 UI isolate 停頓與短期 heap 尖峰。
- tombstone、atom 與 operation log 隨工作階段持續成長；`_recordApplied` 對持續增長 map 反覆 spread，長期總配置量接近二次成長。

解法：

1. 短期：保存上一個 `TextEditingValue`，用共同前後綴或 `TextEditingDelta` 只傳遞變更區段；不要把整份 `nextText` 當作每次編輯 API。
2. 快取 `text`、ordered atom ids 與 UTF-16 offset index；insert/delete 只失效受影響區段。
3. 避免每筆 operation 以 map spread 複製完整 log。可使用可控的 mutable engine、persistent HAMT，或將 immutable notification state 與內部 CRDT store 分離。
4. 設計 protocol-aware checkpoint：只有在 checkpoint 已持久化、所有需要的 peer 已 acknowledge、且可從 snapshot 重建時，才移除舊 operation/tombstone。這一項涉及一致性，不能只依本機時間或筆數直接刪除。
5. 對 10k、100k、1M 字元建立 microbenchmark，記錄每鍵 p50/p95、allocation、atom/tombstone/operation count。

驗收：100k 字章節連續輸入 60 秒時，每次 edit 不得重建全量 ordered tree；強制 GC 後 operation/tombstone retained size必須受 checkpoint budget 約束。

### CRDT-02（P1）：Project text 游標移動也觸發全文 diff 與多次 provider emission

證據：

- `CollaborativeProjectTextFieldRegion` 把同一個 controller listener `_publishSelection` 同時用於文字與 selection：[`remote_text_cursor_overlay.dart:298`](dart_edition/lib/presentation/widgets/remote_text_cursor_overlay.dart#L298)、[`remote_text_cursor_overlay.dart:360`](dart_edition/lib/presentation/widgets/remote_text_cursor_overlay.dart#L360)。
- 只要是 project text document，就直接呼叫 `recordLocalProjectTextEdit`，沒有先比較文字：[`remote_text_cursor_overlay.dart:379`](dart_edition/lib/presentation/widgets/remote_text_cursor_overlay.dart#L379)。
- `recordLocalProjectTextEdit` 即使 `createLocalTextEdit` 回傳同一 document，仍無條件 `state.copyWith`，接著再更新 cursor、publish batch：[`collaboration_providers.dart:353`](dart_edition/lib/presentation/providers/collaboration_providers.dart#L353)。

影響：按方向鍵、滑鼠選字或輸入法調整 selection，都可能先執行 CRDT 全文比對，再發出 document state，造成依賴 `collaborationProvider` 的 overlay/field rebuild。這是可直接感受到游標卡頓的高機率來源。

解法：

```dart
final currentText = current.text(documentId);
if (currentText == nextText) {
  updateLocalProjectTextCursor(...);
  return;
}
```

更完整的做法是拆成 `onTextChanged(delta)` 與 `onSelectionChanged(selection)` 兩條事件，不要從同一 listener 猜測。`state` 也只在 document identity 真正改變時更新；presence/cursor 放獨立、窄範圍 provider。

驗收：只移動游標 1,000 次，CRDT edit count 必須為 0，document provider emission 必須為 0。

### UI-01（P1）：所有功能頁 eager build

證據：

- 桌面功能區以 `IndexedStack` 建立全部頁面：[`main.dart:2151`](dart_edition/lib/main.dart#L2151)。
- 手機功能頁同樣一次建立全部 page；外層又常駐 function/editor 兩頁：[`mobile_function_page.dart:40`](dart_edition/lib/bin/mobile_function_page.dart#L40)、[`mobile_function_page.dart:118`](dart_edition/lib/bin/mobile_function_page.dart#L118)。
- 校對頁在 `initState` 就註冊 `editorContentProvider` manual listener 並載入資產：[`proofreadingview.dart:427`](dart_edition/lib/modules/proofreadingview.dart#L427)。
- 每次共享文字改變都排程背景校對，沒有頁面可見性條件：[`proofreadingview.dart:481`](dart_edition/lib/modules/proofreadingview.dart#L481)、[`proofreadingview.dart:490`](dart_edition/lib/modules/proofreadingview.dart#L490)。

影響：冷啟動就建立多個大型頁面的 State、controller、索引與 subtree。使用者只在編輯器打字時，從未開啟或目前隱藏的校對頁仍會 timer debounce、建立 request、啟動 worker 並保存結果。這不是 unreachable leak，但常駐記憶體與背景 CPU 表現近似 leak。

解法：

- 將 page factory 改成 lazy cache，只建立首次打開的頁面；必要時只保留最近 1～3 頁。
- 把需要跨頁保存的 draft/selection 移入 feature-scoped provider，不以常駐整棵 Widget tree 保存。
- 明確傳入 `isActive`，隱藏時取消校對 timer、停止 content subscription、清除大 result；重新顯示時只分析最新 revision。
- 若仍使用 `IndexedStack`，至少讓 proofreading listener 受目前 page index provider 控制。
- 隱藏校對頁仍須保持分析。

驗收：冷啟動未開啟校對頁時，heap 不應存在 `_ProofreadingWorker`；編輯 60 秒不得出現 proofreading isolate 或 request。

### RENDER-01（P1）：人物關係圖在 build 同步重算高成本 layout

證據：

- `build()` 每次把全部人物重新 map 成 graph：[`character_relationship_graph_view.dart:135`](dart_edition/lib/modules/character_relationship_graph_view.dart#L135)。
- controller 的任何通知直接對整頁 `setState`：[`character_relationship_graph_view.dart:102`](dart_edition/lib/modules/character_relationship_graph_view.dart#L102)。搜尋每一字也直接 `setState`：[`character_relationship_graph_view.dart:333`](dart_edition/lib/modules/character_relationship_graph_view.dart#L333)。
- canvas build 同步做 visible ids、node layout、canvas metrics、edge sort、edge routing/label layout：[`character_relationship_graph_view.dart:526`](dart_edition/lib/modules/character_relationship_graph_view.dart#L526)。
- 邊路由對每條 edge 建立所有 node obstacle，測試多組 control offsets，每組又採樣曲線並用 `any()` 掃 obstacle/label；另以 `edges.any()` 尋找反向 edge：[`character_relationship_graph_view.dart:1324`](dart_edition/lib/modules/character_relationship_graph_view.dart#L1324)、[`character_relationship_graph_view.dart:1388`](dart_edition/lib/modules/character_relationship_graph_view.dart#L1388)、[`character_relationship_graph_view.dart:1405`](dart_edition/lib/modules/character_relationship_graph_view.dart#L1405)、[`character_relationship_graph_view.dart:1445`](dart_edition/lib/modules/character_relationship_graph_view.dart#L1445)。

影響：角色／關係數增加後，搜尋、點選節點、切換「一階鄰居」或重新排列會在 frame build 階段重跑近似 O(E × candidates × samples × (N+E)) 的工作，容易超過 16.7 ms frame budget。

解法：

- 將 graph mapping、layout、edge geometry 做成 memoized derived state，key 至少包含 graph revision、visible ids、layout revision、canvas size、text scale/theme revision。
- 搜尋字串只重建 toolbar/options，不要重建 graph canvas。
- 預先建立 reverse-edge set、spatial index（grid/R-tree）與 obstacle index，取代內層 `any()` 全掃。
- 大圖 layout 放 isolate；UI 先顯示上一版 geometry，結果帶 generation，過期結果不得套用。
- edge paint layer、node layer與 selection overlay 分離 `RepaintBoundary`，只在對應資料變更時 repaint。

驗收：200 nodes／1,000 edges 下搜尋輸入、單純選取與平移縮放保持流暢；Track Widget Builds 顯示 toolbar rebuild 不會重建 geometry。

### STATE-01（P1）：CharacterView 的 `ref.listen` 只註冊第一次 build

證據：

- `_registeredCharacterDataListener` 把 `ref.listen` 包在一次性 guard：[`characterview.dart:2286`](dart_edition/lib/modules/characterview.dart#L2286)。
- `flutter_riverpod 2.6.1` 的 `ConsumerStatefulElement.build()` 會在每次 build 開始前關閉並清空 `WidgetRef.listen` listeners；因此下一次 rebuild 若不再呼叫 `ref.listen`，原 listener 已不存在。可對照專案鎖定版本的 [官方原始碼](https://github.com/rrousselGit/riverpod/blob/flutter_riverpod-v2.6.1/packages/flutter_riverpod/lib/src/consumer.dart)。

影響：CharacterView 第一次因任何原因 rebuild 後，character provider 的 selection sync listener 可能停止運作，造成外部資料更新後畫面選取、欄位與關係資料不同步。這是介面正確性問題，不是避免重複 subscription 的優化。

解法（二選一）：

- 在每次 `build()` 無條件呼叫 `ref.listen`；Riverpod 會處理當次 build 的 listener lifecycle。
- 或在 `initState` 使用 `ref.listenManual`，保存 `ProviderSubscription` 並在 `dispose` 關閉；一次性 flag 可移除。

驗收：pump CharacterView、觸發一次任意 rebuild，再從外部更新 `characterDataProvider`，選取與 controller 內容仍必須同步。

### BG-01（P1）：未連線時仍每 80 ms 執行 collaboration polling

證據：

- provider build 後無條件啟動 `Timer.periodic(Duration(milliseconds: 80))`：[`collaboration_providers.dart:191`](dart_edition/lib/presentation/providers/collaboration_providers.dart#L191)、[`collaboration_providers.dart:218`](dart_edition/lib/presentation/providers/collaboration_providers.dart#L218)。
- `_tick()` 每次至少 prune cursor、read P2P state、記錄 bootstrap role、確保 in-memory project，之後才檢查 transport：[`collaboration_providers.dart:596`](dart_edition/lib/presentation/providers/collaboration_providers.dart#L596)。

影響：provider 是主編輯流程長駐依賴，所以未配對、未連線時仍約每秒喚醒 12.5 次。桌面上是無效 CPU wakeup；行動裝置還會影響耗電。

解法：未認證時不啟動 timer；由 P2P state transition 啟停。已有 active stream 時用 stream event + 750 ms presence heartbeat；fallback polling 使用 adaptive interval（active 80～150 ms、idle 750 ms、disconnected stop）。

驗收：未配對待機 5 分鐘，`_tick()` 次數應為 0；連線且無編輯時只保留低頻 heartbeat。

### REBUILD-01（P2）：CharacterView 的重建邊界過大

證據：

- 6,469 行的單一 view state 在根 build 監看 character fingerprint 與完整 world settings：[`characterview.dart:2286`](dart_edition/lib/modules/characterview.dart#L2286)。
- 角色列表、快照控制、tab 與大量表單主要透過 `_build*()` helper 組裝；helper 不是 Flutter element/rebuild boundary：[`characterview.dart:2335`](dart_edition/lib/modules/characterview.dart#L2335)、[`characterview.dart:2467`](dart_edition/lib/modules/characterview.dart#L2467)。
- 單一 checkbox 的 local `setState` 也會讓整個 `CharacterViewState.build` 重跑：[`characterview.dart:4825`](dart_edition/lib/modules/characterview.dart#L4825)。

影響：輸入、拖曳、tab、checkbox、snapshot 或 world settings 的變化會建立大量新 Widget configuration；`const` 只能減少部分子節點更新，無法替代真正的 Consumer/State 邊界。

解法：拆為 `CharacterListPane`、`CharacterHeader`、每個 tab 的獨立 widget、`SnapshotControls` 與小型 field section；每個 consumer 只 `select` 必要欄位。World provider 改成只輸出地點 options/revision 的 derived provider，不監看整棵資料。

驗收：修改單一 checkbox 或文字欄位時，Track Widget Builds 只顯示該 field/section，不重建列表與非目前 tab。

### IMAGE-01（P2）：1024×1024 icon 按原尺寸解碼

證據：

- `assets/icon/app_icon.png` 為 1024×1024；RGBA 解碼約 4 MiB。
- AppBar 只在約 40×40 顯示，沒有 `cacheWidth/cacheHeight`：[`appbar.dart:48`](dart_edition/lib/bin/appbar.dart#L48)。
- Splash 只在 64×64 顯示，也沒有 decode hint：[`splash_screen.dart:179`](dart_edition/lib/presentation/widgets/splash_screen.dart#L179)。

影響：為小圖示保留約 4 MiB decoded image cache，首次解碼也做了不必要工作。相同 provider 可重用一份 cache，但仍遠大於畫面需求。

解法：提供 64/128/192 px asset variants，或依 DPR 設定 `cacheWidth`/`cacheHeight`；例如 splash 使用 `(64 * devicePixelRatio).round()` 並設合理上限。App icon 產生器仍可保留 1024 原檔，但 UI 不必載入它。

### UI-02（P2）：快照 dialog 在低高度螢幕可能 overflow

證據：快照 dialog content 同時設定寬 632，且高度 `(screenHeight - 220).clamp(420, 680)`：[`characterview.dart:3503`](dart_edition/lib/modules/characterview.dart#L3503)。AlertDialog 還有 title、actions、padding 與 safe area；當視窗高度低於約 500 px（手機橫向、桌面縮小、螢幕鍵盤出現）時，content 仍不得低於 420 px。

解法：用 `LayoutBuilder`/`MediaQuery.viewInsetsOf` 取得 dialog 可用高度，移除 420 的硬下限；讓 content `Flexible` + scrollable，actions 保持可見。補 360×640、640×360、文字 200%、鍵盤開啟的 widget test。

### UI-03（P2）：共用 table border 不跟隨深色主題

證據：`AppTwoColumnTable`、`AppThreeColumnTable` 等共用元件 fallback 到 `Colors.grey.shade300`：[`tables.dart:133`](dart_edition/lib/ui_library/tables.dart#L133)、[`tables.dart:211`](dart_edition/lib/ui_library/tables.dart#L211)、[`tables.dart:313`](dart_edition/lib/ui_library/tables.dart#L313)。淺灰在深色 surface 上容易過亮，且不會隨 seed color/high-contrast scheme 調整。

解法：全面改用 `Theme.of(context).colorScheme.outlineVariant`／`surfaceContainer*`；若 table 支援 override，default 必須來自 scheme。為 light/dark/high-contrast 補 golden test。

### A11Y-01（P2）：resize divider 只有 8 px pointer drag

證據：`MonogatariResizeDivider` 是 8 px 寬 `GestureDetector`，只支援 `onPanUpdate`，沒有 `Semantics`、focus 或鍵盤 action：[`slidebar.dart:145`](dart_edition/lib/bin/slidebar.dart#L145)。

影響：精細滑鼠操作困難；鍵盤與螢幕閱讀器使用者無法調整兩欄寬度。

解法：保留 1 px 視覺線，但把 hit area 擴至至少 16～24 px；加入 `FocusableActionDetector`、左右方向鍵增減、Home/End 或 reset；使用 adjustable/slider semantics 提供目前寬度與 increase/decrease action。

### TOOL-01（P2）：缺少可阻擋回歸的分析與視覺測試門檻

證據：

- [`analysis_options.yaml`](dart_edition/analysis_options.yaml) 只有 `include: package:flutter_lints/flutter.yaml`，沒有 `strict-casts`、`strict-inference`、`strict-raw-types`、`unawaited_futures` 等嚴格設定。
- `test/` 有多個 widget 與效能測試，但未找到 `matchesGoldenFile`；主題、overflow、字體縮放和關係圖沒有像素回歸保護。
- repo root workflow 目前只有 `state-policy-guard.yml`，未看到完整 analyze/test/generator drift/profile benchmark gate。

解法：

```yaml
analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
linter:
  rules:
    - unawaited_futures
    - avoid_catches_without_on_clauses
    - always_declare_return_types
    - prefer_final_locals
```

導入時先建立 baseline，分批清理，不要用全檔 `ignore` 壓掉問題。CI 至少執行 format check、`flutter analyze --fatal-infos`、完整 test、生成碼 clean diff；另加本報告的幾個大型 fixture benchmark。

## 額外資源觀察

### 字型資產

`assets/fonts` 共 8 個 variable fonts、約 **62.63 MiB**，而且全域 fallback 同時列出 NotoSans、TC、SC、JP、KR、HK、Thai：[`ui_library.dart:177`](dart_edition/lib/bin/ui_library.dart#L177)、[`pubspec.yaml`](dart_edition/pubspec.yaml)。這一定會增加 bundle/安裝大小；runtime 是否同時載入則取決於實際 glyph/font fallback。

建議用 release artifact analyzer 確認各平台實際包體，依語系做 subset/flavor；至少不要讓一個只使用單一語系的 build 永遠攜帶全部 CJK variable font。此項偏交付資源與首次字型解析，優先級低於 CRDT 與 hidden worker。

### 搜尋正規化快取

`findreplace.dart` 的 global `_normalizationCache` 沒有容量上限，但 key 是單一字元加兩個布林選項，且專案切換會呼叫 clear：[`findreplace.dart:25`](dart_edition/lib/bin/findreplace.dart#L25)、[`findreplace.dart:2100`](dart_edition/lib/bin/findreplace.dart#L2100)。因此它是低優先級、理論上有界的 Web/長工作階段問題，不列入前 12 項。若保留快取，建議固定容量 LRU 並量測 hit rate。

## 已確認做得好的部分

- 主要頁面的 `TextEditingController`、`ScrollController`、`FocusNode`、timer 與 manual subscription 多數有配對清理；本次沒有看到普遍的 controller 永久洩漏。
- project history 已有 50 entries 與約 64 MiB budget，且目前只建立一次 immutable snapshot／一次 XML digest：[`project_history_provider.dart:106`](dart_edition/lib/presentation/providers/project_history_provider.dart#L106)、[`project_history_provider.dart:183`](dart_edition/lib/presentation/providers/project_history_provider.dart#L183)。
- word count 已改為 service + worker pool，cache 會依 active chapter prune；校對 result 也有截斷資訊與可見數量限制。
- find/replace 已有 latest-wins、結果上限與 `TextSpan` cache；狀態列 marquee 也以 generation 和 app lifecycle 正確停止。
- World/Glossary 的祖先判斷已使用 DFS entry/exit，而非為每個節點保存所有 descendants，避免退化樹 O(N²) retained references。
- 主編輯器已有 `RepaintBoundary`，多數圖片提供 error builder，主要動態清單多使用 builder。

## 建議修正順序

### 第一階段：1～2 天，先止血

1. CRDT-02：文字未變 fast path；游標與文字事件拆流。
2. STATE-01：移除一次性 `ref.listen` guard，補 widget regression test。
3. BG-01：未連線停止 80 ms timer。
4. IMAGE-01：app icon 加 decode size/asset variant。

### 第二階段：3～7 天，縮小背景與重建成本

1. UI-01：lazy page cache + proofreading visibility lifecycle。
2. RENDER-01：關係圖 layout memoization、toolbar/canvas rebuild boundary。
3. REBUILD-01：拆 CharacterView tabs/sections，provider 使用窄 `select`。
4. UI-02/UI-03/A11Y-01：補小視窗、深色模式、鍵盤操作。

### 第三階段：架構工作

1. CRDT-01：增量 index、structural sharing/mutable engine、acknowledged checkpoint compaction。
2. 建立 100k/1M 字元與 200 nodes/1,000 edges 的 profile benchmarks。
3. 啟用嚴格 analyzer、golden 與 CI quality gates。

## 建議量測矩陣

| 情境 | 應記錄指標 | 驗收方向 |
| --- | --- | --- |
| 100k 字章節連續輸入 60 秒 | frame p95/p99、每鍵 CPU、alloc/GC、atom/op/tombstone | 每鍵不做全文 traversal；heap 有上限 |
| 只移動 project field 游標 1,000 次 | CRDT edit、document emission、widget rebuild | edit/emission 都為 0 |
| 冷啟動後只使用編輯器 | 建立的 page State、isolate、timer | 未開頁面不建立；無 proofreading worker |
| 200 人／1,000 關係 | layout 時間、search/selection frame | toolbar rebuild 不重算 geometry |
| P2P 未連線待機 5 分鐘 | `_tick` 次數、CPU wakeups | timer 停止、tick 0 次 |
| 640×360、鍵盤開啟、文字 200% | overflow exception、actions 可見性 | dialog 可捲動且按鈕可操作 |
| light/dark/high contrast | golden diff、文字/邊界對比 | 共用元件完全跟隨 ColorScheme |
| app bar/splash 首次顯示 | decoded image bytes、raster time | 不載入 1024² decoded bitmap |

量測 heap 時應保留「操作前、操作後、強制 GC 後」三個點，區分 temporary allocation peak 與 retained growth。效能門檻應在最低支援硬體、profile/release mode 與固定 fixture 下校準。
