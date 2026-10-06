# 微型時間軸快照預覽替換路線圖

本文件依目前程式碼盤點，規劃以 `TimelineMiniView` 取代地點、角色、角色關係圖與物品的快照預覽入口。以下內容是後續實作方案；目前已完成的是共用微型時間軸與角色新增快照對話框的接入。

建議順序：**共用預覽層 → 角色 → 地點 → 物品 Class／Instance → 角色圖 → 整體驗收**。角色已有資料投影與接入範例，適合作為完整替換的第一個頁面；角色圖涉及任意 Tick 查詢、唯讀權限與圖形效能，放在最後接入。

## 現況與替換範圍

| 頁面 | 現有入口與資料來源 | 替換重點 |
| --- | --- | --- |
| 角色 | `characterview.dart` 的 `_buildSnapshotQuickControls()` 是編輯快照選單；`_buildCharacterSnapshotsTab()` 顯示全域 Tick 狀態與所有快照；新增 Scene 對話框已使用微型時間軸 | 故事狀態預覽改用時間軸；編輯、複製、刪除仍需明確選定快照 ID |
| 地點 | `worldsettingsview.dart` 的地點快照選單、目前狀態與歷程；選擇快照會更新 `timelineViewProvider.currentTick` | 以選定地點的變更標記導覽，保留地點批次操作與當時物品投影 |
| 物品 | `itemview.dart` 的 Class 與各 Instance 快照選單；預覽依全域 Tick 查詢 | 同一元件分別接收 Class／Instance 資料，保留繼承、轉移與歸屬解析 |
| 角色圖 | `character_relationship_graph_view.dart` 的 `relationship-snapshot-selector`；以 `_selectedSnapshotEventId` 選事件，再查詢 `characterDataAtSnapshotTickProvider` | 從事件限定選擇擴充為任意 Tick；預覽模式與事件 ID 分開，維持歷史唯讀 |

目前可沿用的元件能力包括：雙軸捲動、Scrollbar、節點名稱 Tooltip、快照菱形標記、即時跟手拖曳、鍵盤與無障礙操作。一般快照標記仍是時間點；Scene 節點條表示 `[startTick, endTick)`，不要將 Scene 結束誤當成快照失效時間。

這次替換以預覽與導覽介面為主。既有的狀態摘要、欄位內容、差異、編輯表單及歷程操作仍由各領域提供；完整替換後，舊快照下拉選單不再作為主要預覽入口，歷程可收納在可展開區塊中。

## 共用互動規則

| 操作 | 預覽行為 | 編輯行為 |
| --- | --- | --- |
| 拖曳指針／點擊時間軸 | 顯示該 Tick 套用所有有效變更後的狀態；空白 Tick 仍可預覽 | 不切換正在編輯的快照，不觸發保存 |
| 點擊菱形 | 定位至事件解析後的 Tick，顯示事件摘要 | 記錄明確事件 ID，供「編輯／複製／刪除」使用；編輯透過明確操作進入 |
| 同 Tick 多個事件 | 點擊後提供事件選擇清單，Tooltip 列出各事件名稱 | 每個事件保留自己的 ID；不能以 Tick 作為刪除／編輯目標 |
| 切回預設資料 | 顯示領域原本的預設資料來源 | 使用既有預設資料編輯流程 |
| 定位主時間軸／Scene | 執行明確的導覽操作 | 不修改事件時間錨點 |

同 Tick 的預覽結果仍遵守現有 resolver 的排序與累積規則。選中其中一筆標記，代表選中操作目標，不代表將預覽截斷到該筆事件的中間狀態。

### 游標與狀態

- 地點、角色故事狀態與物品頁，預設跟隨 `timelineViewProvider.currentTick`，與現有地點／物品行為一致。
- 角色圖初始維持預設角色資料；進入歷史預覽時採獨立 Tick，另提供「跟隨主時間軸」模式。獨立預覽不更新全域 Tick，避免改變其他頁面的狀態。
- 跟隨模式下拖曳回寫全域 Tick；獨立模式下只更新局部 Tick。模式切換與目前模式都在工具列明確顯示。
- 新增／複製快照對話框保持局部 Tick，確認後才執行既有建立操作。
- 共用狀態區分 `baseline`、`followTimeline`、`localTick`；編輯中的 `stateChangeId` 由頁面另行持有。
- 預設資料不偽裝成 Tick 0 或「最早事件前一 Tick」。預設模式顯示明確標籤，隱藏播放頭；使用者點擊時間軸或標記後進入時間預覽。
- 預覽游標、縮放與捲動屬於 UI 狀態，不加入 XML、專案 dirty state 或 undo/redo。

## P0：完成共用預覽層

交付一個包裝 `TimelineMiniView` 的 `SnapshotTimelinePreview`，各頁只提供領域資料與回呼。

**資料投影**

- 建立共用的顯示模型，包含領域／主體 ID、事件 ID、Scene UUID、解析 Tick、來源 placement、名稱、排序資訊，以及 `usesFallbackTick`／來源失聯狀態。
- 角色沿用 `characterSnapshotTimelineProvider`；角色圖沿用 `characterSnapshotEventsProvider`。
- 地點、Class、Instance 使用各自的 `ordered*StateChanges`／`resolve*StateChangeTime` 或既有時間索引建立投影，不直接用 `fallbackTick` 排序。
- 目前地點／物品頁的部分歷程以 `fallbackTick` 排序；接入時一併統一為解析時間，避免 Scene 移動後標記與清單順序不同。
- 狀態解析仍由既有領域 resolver 負責。共用層不套用 patch、不另存一份快照內容，也不改寫時間錨點。

**元件補強**

- 補上同 Tick 標記群組選擇回呼與選取樣式。現有 `onMarkerTap` 對重合標記回傳第一筆，完整快照導覽不能只沿用此行為。
- 增加預設模式隱藏播放頭的能力，保留時間軸與進入時間預覽的操作。
- 工具列提供「預設資料」、Tick 輸入、上一／下一事件、主時間軸定位與選中事件摘要；新增、複製、編輯、刪除由頁面傳入。
- 預設顯示與目前主體事件相關的 Scene 節點，保留事件間空白時間；提供查看完整 Scene 上下文的範圍選擇。失聯事件以回退標記顯示，不建立假的 Scene 節點。
- 框架固定預覽範圍、縮放與捲動狀態；資料或主體切換時重新計算。一般拖曳保留目前即時跟手行為，不重新加入計時步進。
- 拖曳只更新預覽與整數 Tick；未跨 Tick 的像素移動只重繪指針，不重算領域狀態。
- 各領域按 Tick 查詢的 `Provider.family` 都需檢查生命週期；只保留仍使用中的查詢或目前投影，避免連續拖曳留下大量過期快照結果。

**P0 驗收**

同 Tick 多事件可逐筆選取；負 Tick、空歷程、只有預設資料、Scene 多 placement、來源刪除與回退時間皆可顯示。Scene 移動後，標記、清單及狀態查詢使用同一解析時間。預覽操作不產生資料保存或 dirty state。

## P1：角色完整接入

主要改動：`lib/modules/characterview.dart`、`lib/presentation/providers/character_snapshot_providers.dart`。

1. 在 `_buildCharacterSnapshotsTab()` 接入共用預覽，使用角色事件與全域 Tick，讓時間軸、故事狀態摘要及相關物品投影同步。
2. 以時間軸標記與事件摘要取代主要快照導覽選單；所有快照清單收納為歷程面板，保留差異與定位操作。
3. 明確區分「目前預覽」與 `_selectedSnapshotChangeId` 編輯目標。單純拖曳不能呼叫 `_switchSnapshotSelection()`，因為該方法會保存、載入表單並切換頁籤。
4. 透過「編輯此快照」沿用 `_selectSnapshotForEditing()`；複製與刪除以明確選中的事件 ID 為準。
5. 新增／複製快照對話框改用同一共用包裝，保留大箱／中箱範圍與局部 Tick。

驗收：拖曳不改動表單，不觸發自動保存，不切換頁籤；切換角色不沿用其他角色的事件 ID；預設資料與 Scene 快照的可編輯欄位規則保持有效。

## P2：地點接入

主要改動：`lib/modules/worldsettingsview.dart`、地點變更投影 provider。

1. 選定地點詳情加入時間軸，取代地點快照下拉預覽；狀態摘要與地點內物品查詢沿用全域 Tick。
2. 標記只投影目前地點的變更；不將子地點事件混成父地點快照。
3. 顯示名稱、Scene、批次來源與失聯提示，讓單筆或整批刪除的範圍可辨識。
4. 新增地點快照對話框使用局部預覽 Tick／Scene 選擇；父子地點批次預覽與確認仍走現有流程。

驗收：父地點消失不改變子地點的獨立存在規則；批次刪除範圍正確；控制者、可進入狀態及當時物品內容隨 Tick 更新；世界設定的非地點節點不出現地點快照元件。

## P3：物品 Class 與 Instance 接入

主要改動：`lib/modules/itemview.dart`、Class／Instance 變更投影 provider。

1. 先替換 Class 詳情的快照預覽入口，再替換 Instance 的預覽入口。
2. Class 標記只表示 Class 自己的事件。Instance 檢視同時呈現其自身事件與影響它的 Class 事件，Tooltip 明確標示來源；只有自身事件可作為 Instance 編輯／刪除目標。
3. 所有狀態內容繼續使用 `itemClassSnapshotProvider`／`itemInstanceSnapshotProvider`，避免忽略繼承、分組與歸屬規則。
4. 大量 Instance 採「選中單件的預覽面板」或展開時才建立時間軸，避免每個清單列都常駐 ScrollController 與完整歷程。
5. 新增／轉移快照對話框逐一接入局部時間預覽，保留既有交易、批次結果與確認流程。

驗收：Class 變更正確影響 Instance 狀態；轉移前後的數量、持有者與地點符合現有 resolver；封存、轉換及刪除操作不誤用其他主體的事件 ID。

## P4：角色關係圖接入

主要改動：`lib/modules/character_relationship_graph_view.dart`、`characterDataAtSnapshotTickProvider` 的使用方式。

1. 以共用微型時間軸取代 `relationship-snapshot-selector`，呈現全體角色的變更事件及 Scene 節點。
2. 將預覽模式、任意預覽 Tick 與選中事件 ID 分開；沒有事件的 Tick 也能繪圖，不能因找不到事件而退回預設角色資料。
3. 預覽 Tick 的每位角色仍採用自己在該 Tick 前最後一次有效變更，沿用現有角色投影規則。
4. `_isViewingSnapshot` 改由預覽模式決定。獨立 Tick／跟隨時間軸都維持歷史唯讀，不能再只以 `_selectedSnapshotEventId != null` 判斷權限。
5. 拖曳期間保留圖形視角、縮放、角色位置及可保留的節點選取；關係內容更新不應讓整張圖跳回初始布局。
6. 評估現有以 Tick 為參數的 `Provider.family` 在連續拖曳時保留多份查詢結果的問題；採可釋放或只保留目前查詢的投影，重用未變更的關係資料，避免逐 Tick 常駐整份角色圖。

驗收：任意空白 Tick 可正確預覽；唯讀不能透過拖曳節點、連線或其他編輯入口繞過；切回預設資料才恢復現有編輯能力；獨立預覽不改動全域 Tick，跟隨模式則與主時間軸一致。

## P5：一致性與移除舊入口

- 各頁都以時間軸作為主要快照預覽入口，舊下拉選單移除；保留有實際編輯、差異或批次操作價值的歷程面板。
- 驗證新增、修改、刪除、undo/redo、Scene 重排及專案切換後，標記、事件選取與預覽內容同步；失效選取回到安全狀態，不落到另一筆事件。
- 查核窄視窗、文字縮放、明暗主題、觸控、Scrollbar、Tooltip、鍵盤與畫面閱讀器。
- 大量事件／角色／Instance 下，記錄拖曳與捲動效能、圖形重建次數及記憶體；繪製只處理可見刻度，避免每個 Tick 建立整份快照快取。
- 以各領域現有 resolver 的結果作為對照，確認這次 UI 替換不改變故事狀態的解析結果。

優先驗證現有 `mini_timeline_test.dart`、`character_snapshot_test.dart`、`character_relationship_graph_test.dart`、`itemview_test.dart`、`item_snapshot_test.dart`、`location_item_projection_test.dart`、`location_deletion_test.dart`，再補共用投影、同 Tick 選擇與跨頁游標模式測試。

## 交付拆分

| 交付 | 範圍 | 完成條件 |
| --- | --- | --- |
| A | P0 共用投影、互動與預覽包裝 | 各領域可接入；同 Tick、預設模式與回退事件規則有測試 |
| B | P1 角色 | 第一個完整頁面接入；預覽與編輯互不干擾 |
| C | P2 地點 | 單點、子樹批次與地點物品投影正確 |
| D | P3 物品 | Class／Instance 繼承與交易歷程正確 |
| E | P4 角色圖 | 任意 Tick、唯讀權限與圖形效能正確 |
| F | P5 整體驗收 | 四處的主要舊預覽入口移除，跨頁與回歸測試通過 |

每一交付可獨立檢視與驗收。若共用介面需要調整，優先由已完成的角色頁驗證後再擴散到其他頁面；本路線圖不預估日曆工期，待共用投影與角色圖資料量確認後再估算。
