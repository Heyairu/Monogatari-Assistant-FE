# neonUI：狀態 Icon 與 IconButton 實作規格

## 1. 目標與範圍

以電梯樓層按鈕、IH 爐觸控環與機箱指示燈為視覺參考，讓工具列按鈕在小面積內同時表達「這是什麼操作」與「現在處於什麼狀態」。首版只做可重用的 Icon、IconButton 與狀態指示，不更換整個 App 主題，也不改專案資料格式。

三種參考各取一個明確規則：電梯按鈕的**亮環表示已選且持續生效**；IH 爐的**局部弧段表示正在處理**；機箱指示燈的**小 LED 表示系統狀況**。圖示本身只表示功能，不能用同一個發光效果同時表示 hover、已啟用與錯誤。一次性命令按鈕按完應回到待命，只有可從資料狀態重建的持續狀態才常亮。

首批套用範圍是關係設定工具列與時間軸工具列。關係圖畫布中的關係線、時間軸節點本身仍由各自的資料語意決定外觀；neonUI 只負責其操作控制與狀態指示。

## 2. 現況與整合點

- `lib/bin/ui_library.dart` 使用 Material 3 `ThemeData`、可自訂 seed color 的 `ColorScheme`；深色主題已有 `IconButtonThemeData`，淺色主題使用預設設定。neonUI 應覆寫單一元件的樣式，不能直接改全域 `IconButtonTheme` 使所有按鈕發光。
- `lib/infrastructure/rhodanthe/rhodanthe_theme.dart` 已用 `ThemeExtension` 管理淺色、深色與高對比色票。neonUI 色票可依此模式另建 `NeonUiTheme`，由 `Theme.of(context).brightness` 與 `MediaQuery.highContrast` 解析。現有 `RhodantheTheme` 著重文字標記，無須混入按鈕色票。
- `lib/modules/character_relationship_graph_view.dart` 的「只顯示一階鄰居」與「合併相同的雙向關係」以 `isSelected` 加 `Colors.green` 表達啟用；工具列也有搜尋、縮放、快照檢視與新增關係。
- `lib/modules/timelineview.dart` 的章節／未連結篩選、自動排序、省略空白以 `Colors.teal[400]` 表達啟用；新增節點按鈕以綠／紅表達可用／不可用。規格實作時應修正「不可用卻顯示紅色」的歧義：不可用使用灰色，紅色保留給錯誤或破壞性操作。

## 3. 元件模型

### 3.1 `NeonStatusIcon`

唯讀視覺元件，適用於清單、標題、狀態列。由中央 `Icon`、細環與外側短 LED 弧或 LED 點構成：

- 中央圖示說明操作或資料類型；狀態由環與 LED 表達。一般 `Icon` 可以不帶環，用於沒有狀態的地方。
- `compact`：單一 LED 點，適合密集清單；`ring`：約 270° 細環，適合工具列；`none`：只有圖示，適合高密度或無狀態場景。
- LED 不遮住圖示筆畫；即使發光，也必須有實心線條或點可辨識。發光是附加層，不能是唯一訊號。

### 3.2 `NeonIconButton`

以 Material `IconButton` 作為互動與無障礙基礎，外層繪製環和光暈，保留 ripple、focus、tooltip 與鍵盤操作。API 草案：

```dart
enum NeonStatus {
  idle,       // 灰：待命
  error,      // 紅：錯誤或衝突
  warning,    // 橙：需要處理的異常
  notice,     // 黃：待確認或待補資訊
  active,     // 綠：功能生效或完成
  connected,  // 藍綠：連結或同步就緒
  info,       // 藍：定位或資訊
  preview,    // 紫：歷史或快照預覽
}
enum NeonIndicatorStyle { none, dot, ring }

NeonIconButton({
  required IconData icon,
  required String label,
  required VoidCallback? onPressed,
  NeonStatus status = NeonStatus.idle,
  NeonIndicatorStyle indicator = NeonIndicatorStyle.ring,
  bool selected = false,
  bool busy = false,
  bool destructive = false,
  String? statusLabel,
  double size = 40,
});
```

`selected` 是按鈕開關值，`status` 是獨立的資料或系統狀況，`busy` 是動作進行中，`destructive` 是動作性質，`onPressed == null` 是不可操作。這些不可混成同一個 enum。對 toggle，綠色已啟用環應由 `selected` 推導；呼叫端毋須再傳 `status: active`。`status: active` 留給沒有開關值、但功能持續運作的狀態 Icon。`label` 必填，做 tooltip 與語意名稱；有狀態時附上 `statusLabel`，例如「只顯示一階鄰居，已啟用」。圖示可用 `selectedIcon` 作為後續擴充，但首版優先維持現有圖示。

## 4. 顏色語意

下表是**語意色基準值**，供深色主題原型及設計檢視；正式元件需從 `NeonUiTheme` 取得 light/dark/high-contrast 實際的前景、背景、環及光暈色，不可在頁面中直接寫這些 hex。自訂主題 seed color 不應改變八色的語意。

| 顏色 | 建議基準值 | 作用 | 例子 |
| --- | --- | --- | --- |
| 石墨灰 | `#8B949E` | 待命、未選取；禁用時再降低對比並停止發光 | 未啟用的篩選、沒有選取角色時的鄰居篩選 |
| 訊號紅 | `#FF5D6C` | 錯誤、無法繼續的衝突；破壞性操作只借用紅色圖示／外框，不亮錯誤 LED | 關係解析失敗、刪除確認 |
| 警示橙 | `#FF9F43` | 已發生、需要使用者處理，但仍可恢復的異常 | 時間軸節點衝突、關係指向失效且可修復 |
| 提醒黃 | `#FFD84D` | 尚未出錯的待確認、待補齊或未完成事項 | 未排定的時間軸 placement、關係資訊待補 |
| LED 綠 | `#3DDC84` | 功能正在生效、操作已完成 | 已啟用的關係合併、時間軸篩選 |
| 連結藍綠 | `#36CFC9` | 資料關聯有效、連線或同步已就緒；不表示某個篩選已開啟 | 關係目標已連結、時間軸節點已關聯章節的狀態 Icon |
| 電光藍 | `#52A8FF` | 資訊、當前定位、導航焦點或處理進度；不表示功能已啟用 | 返回目前 Tick、聚焦搜尋結果 |
| 脈衝紫 | `#BA8CFF` | 歷史／快照預覽模式，提醒目前看的是非預設資料 | 關係快照檢視、歷史 Tick 預覽 |

顏色使用規則：

1. 同一按鈕同時有多種狀況時，以 `error > warning > notice > preview > connected > active > info > idle` 決定狀態 LED；`selected` 另以環的完整度與底色表示，不覆蓋橙、黃或紅 LED。這是單一 LED 必須擇一顯示時的優先序，並非八色的嚴重度排名。
2. `destructive` 只在可執行時給圖示／外框紅色；尚未執行的刪除按鈕不顯示「系統錯誤」文案。一般「關閉」、「取消」、「新增」不使用紅／綠做動詞分類。
3. 禁用優先於視覺狀態：保留 tooltip 說明禁用原因，環與光暈熄滅，圖示改為 `ColorScheme.onSurface` 的 disabled 色。資料本身若仍有警告，應在旁邊另顯示狀態，不靠禁用按鈕保留亮燈。
4. 黃色表示「待處理但尚未出錯」，橙色表示「異常已發生且需要處理」，紅色表示「錯誤或阻斷」。藍綠色表示連結／同步就緒，不代替綠色的啟用狀態；藍色表示定位或資訊，不代表啟用。動畫中的工作使用藍色進度弧，並附「處理中」文字語意。
5. 關係圖的「內在／外在」仍以虛線／實線區分；時間軸的大／中／小箱仍以圖示、名稱和階層區分。不可把上述狀態色拿來代表資料分類。

### 4.1 兩個視覺通道與優先序

| 通道 | 表達內容 | 規則 |
| --- | --- | --- |
| 環與底座 | 開關是否持續生效 | `selected` 為完整實線環與淡底色；未選取為低對比斷環。一次性操作沒有常亮環。 |
| LED 點與局部弧 | 資料／系統狀況 | 依 `error > warning > notice > preview > connected > active > info > idle` 取最高狀態；`busy` 時改為進度弧，並在語意中保留原有提醒／警告／錯誤。 |
| 圖示 | 功能或動作 | 使用既有 Material icon；破壞性動作在可執行時使用紅色描邊，不能冒充錯誤 LED。 |

若「已選取」同時有警告，環仍表示已選取，LED 顯示橙色，tooltip 同時說明兩件事。禁用時整個按鈕視覺熄燈，但 tooltip 必須仍可透過外層 `Tooltip` 讀到禁用原因。`busy` 阻止重複觸發，但不套用一般 disabled 灰色，避免使用者誤認工作已停止。

## 5. 外觀、動作與尺寸

| 情境 | 規格 |
| --- | --- |
| 常態 | 40×40 dp 可視區，至少 48×48 dp 點擊區；圖示 20–24 dp；環 1.5–2 dp，距圖示至少 4 dp。 |
| 待命 | 灰色圖示與低對比細環；LED 點不亮。 |
| 啟用 | 綠色完整實線環與淡底色；若另有資料狀況，LED 依狀況顯色。深色模式可有半徑約 6–10 dp、低透明度光暈。 |
| Hover | 增加底色與環亮度，不改狀態色；游標仍顯示 tooltip。 |
| Focus | 獨立的高對比外框，不把 focus 當成資料狀態；鍵盤 Tab 清楚可見。 |
| Pressed | 背景短暫加深或環縮小，保留 Material ripple；不得閃爍紅色。 |
| Busy | 阻止重複送出；環的部分弧段緩慢旋轉，語意狀態顯示「處理中」。 |
| Disabled | 不發光、不播放動畫；保留可讀的禁用原因說明。 |

切換動畫 120–180 ms；狀態變化最多一次柔和亮度過渡，不持續閃爍。系統要求減少動畫時停用旋轉與光暈動畫，改用靜態進度圖示。淺色主題以實色環和淡底色為主，避免白底上的發光失焦；高對比模式取消 blur，使用較粗實線環並提高前景與背景對比。文字與必要圖示的對比目標分別為 4.5:1、3:1；每組主題色應以實際背景驗算。

## 6. 首批畫面對照

| 畫面 | 控制 | 狀態來源 | 呈現 |
| --- | --- | --- | --- |
| 關係設定 | 只顯示一階鄰居 | `_controller.neighborsOnly`、`selectedNodeId` | 啟用時綠燈；未選角色時禁用，tooltip 說明「先選擇角色」。 |
| 關係設定 | 合併相同雙向關係 | `_controller.mergeOpposite` | 啟用時綠燈，關閉時灰燈。 |
| 關係設定 | 快照檢視提示 | `selectedSnapshotEvent` | 紫色狀態 Icon 或工具列指示，並保留現有文字提示與 Tick。新增關係在快照模式不可用。 |
| 關係設定 | 搜尋／全局預覽／縮放 | 現有操作與目前焦點 | 一般為灰色操作按鈕；實際定位焦點可短暫藍色，不能常亮成「已啟用」。 |
| 時間軸 | 只看目前章節、未連結章節、略過空白 | `TimelineViewState` 對應布林值 | 啟用時綠燈；未啟用時灰燈。 |
| 時間軸 | 自動排序大綱 | `grid.autoSortOutline` | 啟用時綠燈，tooltip 要明示它會同步變更大綱順序。 |
| 時間軸 | 返回目前 Tick | `currentTick` 與視窗位置 | 藍色定位動作；完成定位後回待命，避免持續亮燈。 |
| 時間軸 | 新增大／中／小箱 | `nextLevel` | 可用時中性動作色；無下一層時灰色禁用，tooltip 說明小箱為末層。 |

橙、黃、藍綠只在畫面已有可靠的異常、待補或關聯狀態來源時接入；不能從「未連結章節」篩選是否開啟推測資料有警告。元件展示頁先完整呈現八色，再逐一接上實際資料狀態。

## 7. 實作順序

1. 在 `lib/ui_library/` 新增 `neon_ui_theme.dart`、`neon_status_icon.dart`、`neon_icon_button.dart`，定義語意色、狀態解析及元件 API；由現有 `ui_library.dart` 匯出。先完成 light/dark/high-contrast 三組色票。
2. 建立元件展示頁或 Widgetbook 類展示區，列出八種狀態與 hover、focus、selected、disabled、busy 組合；用實際主題背景檢查尺寸、對比和光暈，特別驗證紅／橙／黃與綠／藍綠／藍可區分。
3. 先替換關係設定的兩個 toggle 和快照狀態提示；保留原本 `ValueKey`、操作 callback、tooltip 文案及 provider／controller 更新路徑。
4. 再替換時間軸的四個 toggle、返回目前 Tick 與新增節點；移除畫面內的 `Colors.teal[400]`、`Colors.green`、`Colors.red` 作為這些按鈕狀態的直接指定。
5. 檢查鍵盤、觸控、滑鼠、淺色／深色／高對比與減少動畫，最後才擴及其他工具列。首版不批次改寫整個專案的 `IconButton`。

## 8. 驗收條件

- 不看顏色也能由圖示、環／LED 形狀、tooltip 或鄰近文字分辨八種語意與不可用；特別確認橙色異常和黃色待辦、綠色啟用和藍綠色連結、藍色定位沒有混淆。
- `selected`、`status`、`busy`、`disabled` 的優先規則一致；禁用時不會仍發亮，也不會因 `onPressed == null` 顯示紅色。
- 關係設定與時間軸既有切換行為、Tick 導航、快照唯讀限制與 `ValueKey` 不變；重建 widget 後狀態仍由既有 controller/provider 決定。
- 48×48 dp 命中區、Tab focus、Enter/Space 操作、螢幕閱讀器名稱／狀態、減少動畫及高對比模式都可用。
- Widget 測試涵蓋狀態優先序、禁用與忙碌回呼、語意標籤；畫面測試確認關係設定及時間軸兩組 toggle 與資料狀態同步。視覺比對涵蓋淺／深／高對比及 100%／200% 縮放。
