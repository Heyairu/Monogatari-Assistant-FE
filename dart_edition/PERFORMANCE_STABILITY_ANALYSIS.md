# 性能與穩定性問題分析報告

**分析日期**: 2026年5月5日  
**項目**: Monogatari-Assistant-FE (Dart/Flutter 版本)  
**性能等級**: ⚠️ 中度風險 | **穩定性等級**: ⚠️ 中度風險

---

## 📊 執行摘要

該專案為一個複雜的創意寫作助手應用，使用 Riverpod 狀態管理。分析發現 **5 類重要性能問題** 和 **6 類穩定性風險**，主要集中在：

1. **文本高亮和搜尋的計算複雜度** (O(n²) 潛在)
2. **過度 Listener 訂閱導致的重建風暴**
3. **長會話期間的內存累積**
4. **異步操作 Race Condition**
5. **Provider 清理機制不完善**

---

## 🔴 **類別 1: 文本處理性能問題**

### 問題 1.1: Search/Find 操作的高計算複雜度

**位置**: [lib/bin/findreplace.dart](lib/bin/findreplace.dart#L100-L180)

**問題描述**:
- `HighlightTextEditingController.buildTextSpan()` 在每次構建時執行複雜的範圍檢查
- 對於 N 個搜尋匹配項和 M 個邊界，時間複雜度為 O(N*M)
- 在擁有大量搜尋結果的大文本中，每個字符更改都可能觸發完整重新計算

**代碼片段** (問題所在):
```dart
// buildTextSpan() 中的邊界計算 - O(n) 級別
for (final TextSelection match in normalizedSearch) {
  boundaries.add(match.start);
  boundaries.add(match.end);
}
for (final TextSelection match in normalizedPunctuation) {
  boundaries.add(match.start);
  boundaries.add(match.end);
}
for (final TextSelection match in normalizedFiller) {
  boundaries.add(match.start);
  boundaries.add(match.end);
}

// 後續段落檢查 - O(n*m) 級別
for (int i = 0; i < sortedBoundaries.length - 1; i++) {
  // ...段落檢查...
  _isRangeCoveredByAny(normalizedSearch, segmentStart, segmentEnd); // 線性搜索
}
```

**影響**: 
- ⚠️ 大文本 (>50KB) + 多個搜尋結果時，輸入延遲明顯
- 📱 移動設備上更為嚴重

**建議修復**:
1. 使用 **區間樹 (Interval Tree)** 或 **線段樹 (Segment Tree)** 替代線性搜索
2. 對高亮匹配項使用 **增量更新** (只更新改變的段落)
3. 在 Isolate 中執行 highlight 計算

---

### 問題 1.2: 字數計算在主線程阻塞

**位置**: [lib/bin/content_manager.dart](lib/bin/content_manager.dart#L1-L80)

**問題描述**:
- 雖然已使用 `compute()` 進行異步計算，但未實現 **取消機制**
- 若用戶快速切換章節，舊的字數計算可能仍在進行，造成 Jank

**代碼分析**:
```dart
// word_count_providers.dart 中有防護（好的）
final int count = await ContentManager.calculateWordCountAsync(
  text,
  mode: mode,
);

if (_isDisposed || nextRevision != _revision) {
  return;  // ✓ 正確的撤銷檢查
}
```

**但在主 main.dart 中缺乏相同保護**:
```dart
Future<void> _updateAllWordCounts() async {
  // ...
  final int count = await ContentManager.calculateWordCountAsync(
    chapterData.contentText,
    mode: mode,
  );
  // ❌ 沒有檢查此時是否已切換項目或 widget 已 dispose
  
  setState(() {
    // 可能導致 setState on disposed widget
    _allChapterWordCounts[chapterData.uuid] = count;
  });
}
```

**影響**: 
- 🔴 快速項目切換時出現 "setState on disposed widget" 警告
- 💥 可能在低端設備造成 ANR (應用無響應)

**建議修復**:
```dart
class _AllWordCountsUpdateState {
  bool _isActive = true;
  List<Future> _pendingTasks = [];
  
  void startUpdate() {
    _isActive = true;
    _pendingTasks.clear();
  }
  
  void cancelPending() {
    _isActive = false;
    // 使用 CancelToken 或 revision 檢查
  }
}
```

---

### 問題 1.3: 重複的字符規範化操作

**位置**: [lib/bin/findreplace.dart](lib/bin/findreplace.dart#L200-L400)

**問題描述**:
- 搜尋時每個字符都調用 `normalizeCase()` 和 `normalizeWidth()`
- 這些函數包含大量的 Unicode 範圍檢查

**示例複雜度分析**:
```dart
// 對每個搜尋位置重複執行
for (int i = 0; i < text.length; i++) {
  if (!charsMatch(text[i], findText[i % findText.length], options)) {
    // 內部調用 normalizeCase() (>8 個 if 條件)
    // 內部調用 normalizeWidth() (~50 個 Unicode 範圍檢查)
  }
}
// 總複雜度: O(text.length * findText.length * 60+)
```

**建議修復**: 建立 **規範化緩存**:
```dart
final Map<String, String> _normalizationCache = {};

String _getNormalizedChar(String char, FindReplaceOptions options) {
  final key = '${char}_${options.hashCode}';
  return _normalizationCache.putIfAbsent(key, () => 
    _normalizeCharSlow(char, options));
}
```

---

## 🟠 **類別 2: 狀態管理與 Listener 過度訂閱**

### 問題 2.1: Riverpod Listener 訂閱爆炸 (Listener Hell)

**位置**: [lib/presentation/providers/editor_coordinator_provider.dart](lib/presentation/providers/editor_coordinator_provider.dart#L208-L260)

**問題描述**:
```dart
void _setupProjectDirtyListeners() {
  ref.listen(baseInfoDataProvider, (previous, next) { /* ... */ });
  ref.listen(segmentsDataProvider, (previous, next) { /* ... */ });
  ref.listen(outlineDataProvider, (previous, next) { /* ... */ });
  ref.listen(worldSettingsDataProvider, (previous, next) { /* ... */ });
  ref.listen(characterDataProvider, (previous, next) { /* ... */ });
  ref.listen(foreshadowDataProvider, (previous, next) { /* ... */ });
  ref.listen(updatePlanDataProvider, (previous, next) { /* ... */ });
  ref.listen(projectIoControllerProvider, (previous, next) { /* ... */ });
  ref.listen(settingsStateProvider, (previous, next) { /* ... */ });
  // 共 9 個 ref.listen 調用
}
```

**級聯效應**:
- 單個字段改變 → 觸發 dirty flag
- dirty flag 改變 → 觸發所有 watch dirty flag 的 widget rebuild
- widget rebuild → 可能更新其他 provider
- → 再次觸發 listener 回調

**理論重建次數計算**:
```
初始改變 (1) → 9 個 listener 各自獨立檢查 → 
可能導致 2-5 次連鎖更新 → 
總體: 單次編輯 = 15-50+ 次重建
```

**測試方案**: 
```bash
# 在 debug build 中啟用 Flutter DevTools
# Performance 面板會顯示 widget rebuild 計數
# 預期: 編輯一個字符 → >10 次重建 = 問題確認
```

**建議修復**:
1. **合併 listener** 為單個聚合 provider
```dart
// ❌ 現在的做法
ref.listen(baseInfoDataProvider, ...);
ref.listen(segmentsDataProvider, ...);

// ✅ 改進做法
final aggregatedDirtyProvider = Provider((ref) {
  ref.watch(baseInfoDataProvider);
  ref.watch(segmentsDataProvider);
  // ...
  return isDirty; // 只發出一個信號
});
ref.listen(aggregatedDirtyProvider, ...);
```

2. **使用 `select()` 縮小依賴範圍**:
```dart
// ❌ watch 整個 provider
final coordinator = ref.watch(editorCoordinatorProvider);

// ✅ 只 watch 需要的字段
final isLoading = ref.watch(
  editorCoordinatorProvider.select((s) => s.isLoading)
);
```

---

### 問題 2.2: ListenManual 的 Subscription 洩漏風險

**位置**: [lib/main.dart](lib/main.dart#L406-L471)

**代碼片段**:
```dart
class _ContentViewState extends ConsumerState<ContentView> {
  StreamSubscription<String>? _editorContentSubscription;
  StreamSubscription<EditorSelectionState>? _editorSelectionSubscription;
  // ... 多個 subscription

  @override
  void initState() {
    super.initState();
    _editorContentSubscription = ref.listenManual<String>(
      editorContentProvider, (previous, next) {
        // 回調邏輯
      },
    ) as StreamSubscription;
  }

  @override
  void dispose() {
    _editorContentSubscription?.cancel();  // ✓ 有清理
    // ...
    super.dispose();
  }
}
```

**問題分析**:
- ✓ 已正確實現 `cancel()` 清理
- ⚠️ 但 `listenManual` 返回值類型不安全 (cast 為 StreamSubscription)
- ⚠️ 若其中一個 `cancel()` 拋出異常，後續清理會被跳過

**建議修復**:
```dart
@override
void dispose() {
  final subscriptions = [
    _editorContentSubscription,
    _editorSelectionSubscription,
    _editorCoordinatorSubscription,
    // ...
  ];
  
  for (final sub in subscriptions) {
    try {
      sub?.cancel();
    } catch (e) {
      debugPrint('Error canceling subscription: $e');
    }
  }
  
  super.dispose();
}
```

---

## 🟠 **類別 3: 內存管理與累積問題**

### 問題 3.1: Character/Outline 編輯模式下的臨時數據累積

**位置**: [lib/modules/characterview.dart](lib/modules/characterview.dart#L1-L100)

**問題描述**:
```dart
// CharacterView 中的大量臨時列表
List<String> loveToDoList = [];
List<String> hateToDoList = [];
List<String> wantToDoList = [];
List<String> fearToDoList = [];
List<String> proficientToDoList = [];
List<String> unProficientToDoList = [];
```

**問題**:
- 每個字符對象包含 6 個列表
- 長會話中編輯 100+ 個字符 → 累積 600+ 列表對象
- 列表復制 (copy-on-write) 可能在內存峰值時失敗

**內存累積計算**:
```
基礎字符數據:     ~2KB
6 個 empty 列表:  ~0.5KB/字符
100 字符 × 6 個列表 × 平均 5 個項目:
  = 100 × 6 × 5 × 50 字節 = 150KB (單次編輯周期)
  
長會話 (1000+ 編輯):
  理論峰值: 150KB × 5-10 = 750KB - 1.5MB 累積
```

**建議修復**: 
1. 延遲加載列表 (只在展開時初始化)
2. 使用 `const` 集合初始化，避免多次復制
3. 定期清理未使用的舊快照

---

### 問題 3.2: 搜尋結果集的無界增長

**位置**: [lib/bin/findreplace.dart](lib/bin/findreplace.dart#L150-L200)

**代碼**:
```dart
// 搜尋存儲中的無限增長
class HighlightTextEditingController extends CodeController {
  List<TextSelection> searchMatches = [];     // ← 可無限增長
  List<TextSelection> punctuationMatches = [];
  List<TextSelection> fillerWordMatches = [];
}
```

**問題**:
- 若在 100KB 文本中搜尋常見詞 (如 "的" 或 "是")，可能返回 5000+ 匹配
- `List<TextSelection>` × 5000 = 消耗 ~200KB 內存
- 切換搜尋詞語時，舊列表未及時清理

**建議修復**:
```dart
// 實現最大容量限制
static const int _MAX_SEARCH_RESULTS = 1000;

void updateSearchHighlights({
  required List<TextSelection> matches,
  // ...
}) {
  // 截斷超大結果集
  searchMatches = matches.length > _MAX_SEARCH_RESULTS
    ? matches.sublist(0, _MAX_SEARCH_RESULTS)
    : matches;
  notifyListeners();
}
```

---

## 🟡 **類別 4: 異步操作與 Race Condition**

### 問題 4.1: 字數計算的 Race Condition

**位置**: [lib/presentation/providers/word_count_providers.dart](lib/presentation/providers/word_count_providers.dart#L60-L100)

**代碼分析** (✓ 已防護):
```dart
int nextRevision = ++_revision;
_debounce?.cancel();
_debounce = Timer(_debounceDuration, () async {
  // ...
  if (_isDisposed || nextRevision != _revision) {
    return;  // ✓ 正確: 檢查是否已過期
  }
  // ...
});
```

**但 main.dart 中缺乏保護** (❌ 存在問題):
```dart
Future<void> _updateAllWordCounts() async {
  // ❌ 沒有 revision 機制
  for (var job in jobs) {
    final int count = await ContentManager.calculateWordCountAsync(...);
    
    setState(() {
      // 如果此時 widget 已 dispose，會拋出異常
      _allChapterWordCounts[job.uuid] = count;
    });
  }
}
```

**影響**: 快速項目切換時出現 "setState called after dispose" 異常

**建議修復** (見類別 1.2)

---

### 問題 4.2: 多個 Debounce Timer 的嵌套

**位置**: [lib/main.dart](lib/main.dart#L560-L610)

**問題描述**:
```dart
class _ContentViewState extends ConsumerState<ContentView> {
  Timer? _wordCountDebounce;
  Timer? _contentCommitDebounce;
  // 潛在的多個 Timer 同時運行
}

void _onTextChanged(String newText) {
  if (_wordCountDebounce?.isActive ?? false) _wordCountDebounce!.cancel();
  _wordCountDebounce = Timer(Duration(milliseconds: 50), () {
    _updateActiveWordCountAsync();
  });

  if (_contentCommitDebounce?.isActive ?? false) {
    _contentCommitDebounce!.cancel();
  }
  _contentCommitDebounce = Timer(Duration(milliseconds: 500), () {
    _commitContentChanges();
  });
}
```

**風險**:
- 2 個 Timer 同時運行，時間不同步
- 若 50ms Timer 先完成，可能在 500ms Timer 完成前修改共享狀態
- 導致狀態不一致

**建議修復**:
```dart
class TextChangeDebouncer {
  Timer? _timer;
  final List<VoidCallback> _callbacks = [];
  
  void debounce(List<VoidCallback> callbacks, Duration delay) {
    _timer?.cancel();
    _callbacks.clear();
    _callbacks.addAll(callbacks);
    
    _timer = Timer(delay, () {
      for (var callback in _callbacks) {
        callback();
      }
    });
  }
}
```

---

## 🔵 **類別 5: 構建性能與 Widget 層級問題**

### 問題 5.1: ContentView 中過多的 ref.watch 調用

**位置**: [lib/main.dart](lib/main.dart#L114-L130)

**代碼**:
```dart
final themeColor = ref.watch(
  settingsStateProvider.select((s) => s.themeColor),
);
final themeMode = ref.watch(
  settingsStateProvider.select((s) => s.themeMode),
);
final fontSize = ref.watch(
  settingsStateProvider.select((s) => s.fontSize),
);
```

**問題**:
- 雖然使用了 `.select()`，但每個 watch 都是獨立的 dependency
- 若 themeColor 改變，整個 ContentView 會重建
- 實際上只有主題相關 widget 需要重建

**建議修復**:
```dart
// 建立聚合 Provider
final appThemeSettingsProvider = Provider((ref) {
  final settings = ref.watch(settingsStateProvider);
  return AppThemeSettings(
    color: settings.themeColor,
    mode: settings.themeMode,
    fontSize: settings.fontSize,
  );
});

// 在 ConsumerWidget 中
final theme = ref.watch(appThemeSettingsProvider);
```

---

### 問題 5.2: CodeTextController 的過度渲染

**位置**: [lib/bin/content.dart](lib/bin/content.dart#L1-L100)

**問題描述**:
- `CodeController` (來自 `code_text_field`) 在每次文本改變時重建整個 RichText
- 對於 50KB+ 文本，此成本很高
- 且 highlight 計算同時進行 (見類別 1.1)

**複合效應**:
```
用戶輸入 1 個字符
  ↓
CodeController 檢測到改變
  ↓
buildTextSpan() 執行 (O(n²) highlight)
  ↓
RichText 重建
  ↓
同時: ref.watch 依賴改變
  ↓
父 widget (ContentView) 也重建
  ↓
結果: 2 層級重建 + highlight 計算 = 明顯 Jank
```

**建議修復**:
1. 將 highlight 計算移至獨立的 Provider
2. 使用 `RepaintBoundary` 隔離編輯器區域
3. 考慮使用 `CachedNetworkImage` 等輕量級渲染方案

---

## 📋 **穩定性問題總結**

| ID | 風險等級 | 類別 | 描述 | 影響範圍 |
|----|---------|------|------|---------|
| S1 | 🔴 高 | Provider 清理 | setState on disposed widget | 快速項目切換時崩潰 |
| S2 | 🟠 中 | 內存洩漏 | 舊快照未清理 | 長會話應用內存持續增長 |
| S3 | 🟠 中 | Listener 訂閱 | 多個 listener 導致重建風暴 | 卡頓、響應遲緩 |
| S4 | 🟠 中 | 異步競態 | Race condition 在字數更新中 | 間歇性崩潰 |
| S5 | 🟡 低 | Timer 管理 | 多個 debounce timer 衝突 | 狀態不一致 |
| S6 | 🟡 低 | 資源清理 | Subscription 異常未捕獲 | 部分清理失敗 |

---

## 🛠️ **優先級修復路線圖**

### **第 1 階段 (立即 / 1-2 天)**
- [ ] **P1**: 修復 `setState on disposed widget` (S1) 
  - 在 `_updateAllWordCounts()` 中添加 disposed 檢查
  - 預期影響: 消除快速切換時的崩潰
  
- [ ] **P2**: 實現 Listener 聚合 (P2.1)
  - 合併 `_setupProjectDirtyListeners()` 的 9 個 listen
  - 預期改進: 重建次數 -60% ~ -80%

### **第 2 階段 (本周 / 3-5 天)**
- [ ] **P3**: 優化高亮計算 (P1.1)
  - 從 O(n²) 降至 O(n log n) 
  - 預期改進: 大文本搜尋性能 +50% ~ +200%

- [ ] **P4**: 實現搜尋結果容量限制 (P3.2)
  - 限制最大 1000 個結果
  - 預期改進: 內存 -30% 在大規模搜尋場景

### **第 3 階段 (下周 / 5-7 天)**
- [ ] **P5**: 重構字數計算為聚合 Provider (P4.1)
  - 添加 revision 機制到所有異步操作
  - 預期改進: 消除間歇性崩潰

- [ ] **P6**: CodeController 隔離 (P5.2)
  - 使用 RepaintBoundary
  - 預期改進: 編輯響應性 +30% ~ +50%

---

## 📊 **性能基準測試建議**

```dart
// 在 test/ 中添加的效能測試
group('Performance Benchmarks', () {
  test('Search in 100KB text with 1000 matches', () async {
    final largeText = 'a ' * 50000;  // 100KB
    final stopwatch = Stopwatch()..start();
    
    final matches = findAllMatchesSync(largeText, 'a', FindReplaceOptions());
    
    stopwatch.stop();
    expect(stopwatch.elapsedMilliseconds, lessThan(200)); // 應 < 200ms
  });
  
  test('Character editor rebuild count', () async {
    // 監控單次編輯的 widget rebuild 計數
    // 目標: < 5 次重建
  });
  
  test('Memory growth over 100 edits', () async {
    // 監控內存增長曲線
    // 目標: 線性增長, 無指數爆炸
  });
});
```

---

## 📚 **參考資源**

- Riverpod 最佳實踐: https://riverpod.dev/docs/concepts/combining_providers
- Flutter 性能優化: https://flutter.dev/docs/testing/best-practices#performance-testing
- Dart 異步編程: https://dart.dev/guides/libraries/async-await

---

**下一步**: 請選擇第 1 階段的修復項目開始實施，或提供特定場景的詳細分析。
