# 時間軸功能實作評估

> 本文件評估 Monogatari Assistant 目前架構下，如何實作「時間軸」，並與「大綱調整」及「章節選擇」形成可預期的工作流程。
>
> 文件範圍：資料模型、狀態管理、UI 互動、跨模組導航、儲存格式、遷移、測試與分階段工期。本文是實作設計，不直接修改既有 Dart 程式。

## 1. 結論摘要

建議把時間軸實作成「由大綱資料投影出的 Tick 網格工作視圖」，而不是再建立一份獨立的事件副本。

核心原則如下：

1. 大綱中的 `SceneData` 是場景內容的主要來源；時間軸另外保存場景的 Tick 位置與軌道配置，負責排列、篩選與呈現。
2. 章節內容仍由 `ChapterData` 管理；時間軸不複製章節文字。
3. 大綱項目與章節之間新增明確的 UUID 關聯資料。不可使用陣列 index、顯示名稱或目前排序位置作為關聯。
4. 每個小箱代表一個固定的 `tick`；中箱和大箱是可點擊鑽入的階層範圍，子層時間軸由父層範圍與 Tick 長度推導，不各自保存另一套絕對時間。
5. Tick 長度和畫面縮放是兩個不同設定。前者改變故事時間的換算，後者只改變畫面寬度。
6. 點選時間軸項目時，以一次性的導航交易同步「大綱場景選取」與「編輯器章節選取」，避免兩個畫面各自切換而造成內容錯配。
7. 大綱的手動順序、Tick 順序與軌道順序是三種不同概念。修改其中一種不應偷偷覆寫另外兩種；需要提供明確的整理操作。
8. 舊專案沒有 Tick 資料時，應可正常載入。舊有 `SceneData.time` 及 `timePointIso8601` 必須保留，轉成 Tick 時應先預覽，不可依名稱自動把大綱綁到章節。
9. 大箱、中箱、小箱是階層式編輯範圍；點擊父箱進入子層介面，並以 Breadcrumb 保留目前層級。
10. 同一軌道的後續元素不可與目前元素重疊；若父元件延展造成衝突，將較後端元素移到新軌道並保留其相對 Tick 位置。

以目前程式結構估算：

- Tick 網格＋基本多軌＋章節關聯 MVP：約 **11–17 人日**。
- 加入大/中/小箱鑽入、父子範圍約束、自動延展與衝突分軌：約 **17–25 人日**。
- 再包含 Tick 轉換預覽、軌道自動分 lane、批次關聯、完整衝突提示、虛構曆法、細緻視覺打磨：約 **22–32 人日**。

這個估算假設既有 Flutter/Riverpod/XML 儲存流程可延續，且不另做多人同步或即時協作。

## 2. 現況盤點

### 2.1 大綱資料模型

目前大綱位於 `dart_edition/lib/models/outline_data.dart`，層級為：

```text
StorylineData
└── StoryEventData
    └── SceneData
```

各層都有穩定 UUID：

- `StorylineData.chapterUUID`：實際上是故事線自身的 UUID；名稱中的 `chapter` 容易讓人誤以為它已經連到章節。
- `StoryEventData.storyEventUUID`：事件 UUID。
- `SceneData.sceneUUID`：場景 UUID。

`SceneData` 目前已有：

```dart
String time;
String? timePointIso8601;
```

建構子會嘗試從 `time` 解析 ISO-8601，並填入 `timePointIso8601`。這是時間軸排序的良好起點，但目前仍有幾個限制：

- `time` 同時承擔「給人看的文字」及「可排序的時間」兩種責任。
- 只有單一時間點，沒有開始/結束時間。
- ISO-8601 不能完整表達純年份、模糊日期、相對時間或虛構曆法。
- 尚未保存場景與章節的關聯。

`dart_edition/lib/modules/outlineview.dart` 已負責大綱表單更新、拖放排序、XML `saveXML/loadXML`，並以 `<Time>` 與 `<TimePoint>` 保存場景時間。因此時間軸不應另寫一套獨立的場景編輯器。

### 2.2 章節選擇資料模型

章節模型位於 `dart_edition/lib/models/chapter_selection_data.dart`：

```text
隱藏根節點
├── SegmentData（資料夾）
│   ├── ChapterData（章節）
│   └── SegmentData（子資料夾）
└── ...
```

現有能力包括：

- 章節及資料夾都有穩定 UUID。
- 支援遞迴資料夾。
- `childNodeOrder` 可以保存同一資料夾內章節與子資料夾的混合順序。
- `ChapterTree.chaptersDepthFirst` 可取得穩定的章節遍歷順序。
- 章節可新增、刪除、改名、跨資料夾移動及拖放排序。

這代表時間軸若要列出「某章節有哪些場景」，必須使用 `chapterUUID` 查詢關聯，而不能假設章節樹的順序就是時間順序。

### 2.3 目前的編輯器選取同步

目前章節編輯器的選取狀態集中於 `editorSelectionProvider`，至少包含：

```text
selectedSegID
selectedChapID
cursorOffset
```

`editor_coordinator_provider.dart` 負責：

- 根據目前選取章節取得內容。
- 在切換章節前把編輯器內容寫回原章節。
- 專案載入後套用初始章節與游標位置。
- 透過 Riverpod Provider 讓章節樹、編輯器和持久化流程同步。

這個設計非常適合拿來當時間軸的章節導航入口，但時間軸不可直接修改 `TextEditingController` 或自行寫入章節內容。它應呼叫一個集中式導航協調器。

### 2.4 目前已存在但尚未完成的能力

目前程式已有下列可重用基礎：

- `OutlineDataNotifier`：大綱的集中式 immutable snapshot 更新。
- `SegmentsDataNotifier`：章節樹的集中式更新。
- `snapshotOutlineData`、`snapshotSegmentsData`：Provider 快照與防止可變清單外洩。
- `ProjectData`：可將各模組組成完整專案快照。
- `ProjectMigrator`：集中處理專案格式升級，也已替舊場景補上 `timePointIso8601`。
- XML Codec：大綱與章節已有獨立的讀寫路徑。

目前尚未存在：

- 時間軸專用的投影模型。
- 場景與章節的多對多關聯。
- 時間軸篩選及時間軸選取狀態。
- 從時間軸跳到大綱場景並同步章節編輯器的導航流程。

## 3. 預期使用情境

### 3.1 由大綱調整推動時間軸

使用者在大綱中：

1. 新增或刪除場景。
2. 修改場景名稱、時間、地點或事件歸屬。
3. 拖曳事件或場景調整敘事順序。

時間軸應自動反映這些變化：

- 新增場景：出現在「未排定時間」或依時間落點出現。
- 修改時間：重新計算排序與衝突提示。
- 修改 Tick 位置或時長：只更新對應的 `TimelinePlacementData`，不改寫大綱陣列順序。
- 刪除場景：時間軸項目和其關聯一併移除，或進入待確認狀態。
- 移動場景：保持 `sceneUUID` 不變，關聯和章節導航不受影響。
- 調整大綱順序：只影響相同時間或未排定項目的 tie-break 順序，不應自動覆寫場景時間。

### 3.2 由時間軸定位章節

使用者點選時間軸中的場景：

1. 時間軸先確認場景是否有關聯章節。
2. 若只有一個章節，切換到該章節。
3. 若有多個章節，顯示章節選擇器，讓使用者選定要開啟的章節。
4. 先 flush 目前大綱表單和編輯器的待提交草稿。
5. 更新大綱場景選取。
6. 透過現有編輯器協調流程更新 `selectedSegID`、`selectedChapID` 和章節內容。
7. 讓章節樹展開到目標章節，編輯器定位到章節開頭或保存的游標位置。

若場景沒有章節關聯：

- 保留目前編輯器章節，不要偷偷切換到第一章。
- 顯示「此場景尚未連結章節」狀態。
- 提供「連結至目前章節」及「選擇章節」操作。

### 3.3 由章節選擇反查時間軸

使用者在章節樹選取章節時，時間軸應可：

- 將該章節相關場景標示為選取狀態。
- 提供「只看目前章節」篩選。
- 若目前章節沒有關聯，顯示未連結提示，而不是顯示空白畫面造成誤解。

章節移動到另一個資料夾時，因 `chapterUUID` 不變，時間軸關聯不需重建；只有刪除章節時才需要處理關聯清理。

### 3.4 透過多軌觀察平行事件

使用者可以建立多條軌道，例如「主角」「反派」「地點 A」「世界事件」，把不同故事線的場景放在同一條共享 Tick 尺上。這樣可以直接看出：

- 不同角色線是否在同一 Tick 發生事件。
- 某個事件是否跨越其他事件的時間範圍。
- 哪些場景尚未配置軌道或 Tick。
- 同一場景是否被多條軌道引用。

多軌是檢視與編排維度，不應複製大綱資料，也不應強迫每條故事線都變成固定軌道。

## 4. 建議的資料設計

### 4.1 時間資料：Tick 為主、舊日期相容

Tick 模式下，第一版的排列主鍵應是 `TimelinePlacementData.startTick`，不是 `DateTime`。不建議同時引入完整虛構曆法引擎；先把「離散排序」和「人類可讀時間」分開，讓未來可以擴充。

#### 舊 SceneData 欄位的相容責任

保留既有欄位並定義清楚：

```dart
class SceneData {
  String sceneUUID;

  // 使用者看到的原始文字，例如「第三天晚上」或「王曆 102 年春」。
  String time;

  // 舊格式的可排序標準時間；Tick 模式下作為遷移/顯示相容資料。
  String? timePointIso8601;
}
```

在尚未建立 Timeline Placement 的舊專案中，暫時排序規則：

1. `timePointIso8601` 可解析時，使用 UTC-normalized instant 或明確的 local offset 排序。
2. 只有 `time` 時，嘗試 `DateTime.tryParse(time)` 作為暫時排序值，但不回寫資料，避免純顯示文字被誤判。
3. 無法解析的場景集中到「未排定」區段。
4. 同一時間的項目以大綱原始順序及 `sceneUUID` 作穩定 tie-break。

#### 第二階段時間欄位

當使用者確定需要模糊時間或虛構曆法後，再增加明確的 value object：

```dart
enum TimelinePrecision { unknown, era, year, month, day, time }

class TimelinePosition {
  String? calendarId;       // gregorian、fictional-calendar-id...
  String? sortableKey;      // 由曆法解析器產出的可比較值
  String displayText;       // 原始/顯示文字
  TimelinePrecision precision;
  bool isApproximate;
}
```

若要支援跨日場景，再擴充為 `startPosition` 與 `endPosition`。這些欄位應由單獨模型封裝，不要持續把更多語意塞進 `SceneData.time`。

### 4.2 大綱與章節關聯：採用獨立 Link 模型

建議新增一組獨立的 `OutlineChapterLinkData`，而不是把 `chapterUUID` 加進 `StorylineData` 或直接把多個章節 ID 塞進 `SceneData`。

```dart
@freezed
class OutlineChapterLinkData with _$OutlineChapterLinkData {
  const factory OutlineChapterLinkData({
    required String linkUUID,
    required String sceneUUID,
    required String chapterUUID,
    @Default(0) int sequence,
    @Default(ChapterLinkCoverage.full) ChapterLinkCoverage coverage,
    String? note,
  }) = _OutlineChapterLinkData;
}

enum ChapterLinkCoverage { full, opening, middle, ending, reference }
```

為什麼選獨立 link：

- 一個章節可包含多個場景。
- 一個場景可能跨越多章，或在某章節只作為參考。
- 章節搬移資料夾時不需修改 link。
- 之後可加入「章節內順序」「連結註記」「內容涵蓋程度」而不污染大綱場景本身。
- 可在刪除大綱或章節後檢查 dangling link。

若產品確認永遠是一個場景只對應一個章節，MVP 可以先用 `sceneUUID + chapterUUID` 的最小 link，保留獨立資料表的結構；不要因此改用名稱或 index 關聯。

### 4.3 ProjectData 擴充

建議在 `ProjectData` 增加：

```dart
List<OutlineChapterLinkData> outlineChapterLinks;
```

時間軸的排序結果、篩選結果、目前視窗縮放和目前游標位置屬於 UI 狀態，不應寫進專案檔；只有使用者建立的 link、時間欄位及未來的時間 metadata 才是持久化資料。

若採用 Tick 網格，`ProjectData` 建議再增加一個專門的時間軸文件，而不是把 Tick 位置塞進 `SceneData`：

```dart
class TimelineDocumentData {
  TimelineGridConfig grid;
  List<TimelineTrackData> tracks;
  List<TimelinePlacementData> placements;
}

class TimelineGridConfig {
  // 一個 Tick 在故事世界中代表多少時間。
  TickDuration tickDuration;

  // 小箱數量到中箱/大箱的換算倍率。
  int ticksPerMiddleBox;
  int middleBoxesPerLargeBox;

  // Tick 0 的語意；可為故事開始、紀元起點或自訂原點。
  String originLabel;
  String? originIso8601;
}

class TickDuration {
  int value;
  TickDurationUnit unit; // second、minute、hour、day、week、custom
}

class TimelineTrackData {
  String trackUUID;
  String name;
  int order;
  String? colorToken;
  bool isCollapsed;
}

class TimelinePlacementData {
  String placementUUID;
  String? sceneUUID;
  String? parentPlacementUUID;
  TimelineElementLevel level; // large、middle、small
  String trackUUID;
  int startTick;
  int durationTicks;
  int order;
}

enum TimelineElementLevel { large, middle, small }
```

`timelineDocument` 的 `grid`、`tracks` 和 `placements` 是作者資料，應持久化；目前的篩選、水平捲動、縮放倍率和選取項目仍屬 UI 狀態，不應持久化。

#### Tick 的語意

- `startTick` 是相對於 `originLabel` 的整數位置，可為負數，以支援前史或回溯。
- `durationTicks` 至少為 1。若場景是瞬間事件，可使用 1 Tick 並以不同的視覺樣式顯示；不要使用 0 導致排序和點選區域不穩定。
- `endTick = startTick + durationTicks`，不需要重複保存。
- `ticksPerMiddleBox` 和 `middleBoxesPerLargeBox` 必須大於 0；中箱時間為 `tickDuration × ticksPerMiddleBox`，大箱時間為 `tickDuration × ticksPerMiddleBox × middleBoxesPerLargeBox`。
- 所有軌道共用同一個 Tick 原點與水平尺，才可以直接比較平行事件。

#### 箱體換算例子

假設：

```text
1 Tick = 15 分鐘
4 個小箱 = 1 個中箱
6 個中箱 = 1 個大箱
```

則：

```text
小箱 = 15 分鐘
中箱 = 60 分鐘
大箱 = 360 分鐘 = 6 小時
```

這種換算應由 `TimelineGridConfig` 單一計算器產生。UI 不可自行用另一套常數計算標籤，否則放大、縮小和匯出圖片時很容易出現刻度不一致。

### 4.4 Tick 長度與畫面縮放必須分離

使用者說的「Tick 長度可調整」可能有兩種意思，產品上應明確拆成兩個控制項：

| 設定 | 例子 | 影響 | 是否改變事件資料 |
|---|---|---|---|
| 故事 Tick 時長 | 1 Tick = 15 分鐘 / 1 天 | 中箱、大箱的實際時間標籤 | 會改變時間換算語意 |
| 畫面 Tick 寬度 | 每 Tick 24 px / 48 px | 時間軸水平密度與可讀性 | 不會 |

畫面 Tick 寬度應使用 `zoom` 或 `pixelsPerTick`，只存在於 `TimelineView` 的 UI state。不能把它和 `tickDuration` 共用欄位名稱 `tickLength`。

調整故事 Tick 時長時，建議提供兩種明確操作：

1. **重新解讀刻度**：保留所有 `startTick` 和 `durationTicks`，只改變一 Tick 所代表的故事時間。適合作者本來就是用抽象 Tick 規劃故事。
2. **保留原有實際時間**：依舊 Tick 時長與新 Tick 時長換算所有 placement，使用四捨五入或明確的 snap 規則重新計算 Tick。此操作必須顯示預覽、可能的捨入誤差及一次性 undo。

預設建議使用第一種，因為 Tick 是使用者選擇的故事離散單位；但任何會讓畫面上的時間標籤大量改變的操作，都應有確認視窗。

### 4.5 多軌設計

軌道是共享同一條 Tick 尺的平行容器，例如：

```text
軌道 A：主角線        Tick 0 ─── 場景 A ─────── Tick 8
軌道 B：反派線        Tick 2 ─ 場景 B ───── Tick 7
軌道 C：世界事件      Tick 5 ─── 事件 C ─────── Tick 12
```

建議規則：

- 軌道由使用者建立、命名、排序、隱藏或收合。
- 故事線可以「一鍵產生對應軌道」作為便利操作，但 Storyline 不應和 Track 強制一對一；故事線是內容結構，軌道是時間軸檢視維度。
- 每個 `TimelinePlacementData` 指向一個 `trackUUID`；葉節點通常再指向一個 `sceneUUID`，容器型大箱/中箱可以沒有場景 UUID。
- 同一場景若必須出現在多個軌道，可建立多個 placement；它們共用 `sceneUUID`，但各自擁有軌道位置。UI 必須標示為同一場景的多軌引用，避免作者誤以為建立了兩個場景。
- 軌道本身不保存場景副本，也不改變大綱中的 storyline/event 階層。
- 軌道刪除時，應要求把 placements 移到其他軌道或移入「未分軌」，不可直接刪除場景。

在本需求下，同一軌道的後續事件不可在 Tick 範圍上重疊；應直接採用第 7 節的自動分軌規則，而不是先允許重疊再靠警告補救。若要更像甘特圖，可在軌道內加入計算出的子 lane，但子 lane 是投影結果，不應變成作者資料。

### 4.6 階層式時間軸元素與鑽入規則

大箱、中箱、小箱不能只當成畫面上的刻度線；因為使用者要求父子端點約束和父元件自動延展，資料層必須能表達真正的階層元素：

```text
大箱 A（parent = null）
├── 中箱 A-1（parent = 大箱 A）
│   ├── 小箱 A-1-1（parent = 中箱 A-1）
│   └── 小箱 A-1-2（parent = 中箱 A-1）
└── 中箱 A-2（parent = 大箱 A）
```

建議使用 `parentPlacementUUID` 建立階層，不要用陣列 index。`sceneUUID` 可以為 null，因為大箱/中箱可能是規劃用的容器；小箱或葉節點才通常綁定 `SceneData.sceneUUID`。

#### 父子範圍 invariant

對每個有子元素的父元素 `P` 和子元素 `C`，必須維持：

```text
P.startTick <= C.startTick
C.endTick <= P.endTick
P.endTick = P.startTick + P.durationTicks
C.endTick = C.startTick + C.durationTicks
```

換句話說：

- 子元素頭端不可早於父元素頭端。
- 子元素頭端可以晚於父元素頭端，但父元素頭端不可晚於最早子元素頭端。
- 子元素尾端不可晚於父元素尾端。
- 父元素尾端可以晚於子元素尾端，但父元素尾端不可早於最晚子元素尾端。

父元素的有效範圍至少要包住所有直系子元素；若父元素還有祖父，延展需逐層向上傳播。

#### 「有效範圍」與「預設網格範圍」分離

大箱/中箱的 Grid 邊界可以由 Tick 倍率產生，但內容元素的有效範圍可能因子元素調整而延展。建議將兩者分開：

- `gridStartTick/gridEndTick`：依 Tick 設定和目前鑽入層級產生的視覺網格。
- `startTick/endTick`：作者實際編排的元素範圍。

若子元素超出預設網格，先調整父元素有效範圍；必要時由畫面產生額外大箱/中箱網格，不得截斷子元素或把 Tick 靜默捨入。

### 4.7 不使用現有 `StorylineData.chapterUUID` 作章節關聯

這是實作時最需要避免的陷阱。

目前 `StorylineData.chapterUUID` 是故事線自身的識別值，由 `StorylineData` 建構子產生，並在大綱 UI 中用來選取、拖放及 XML UUID。它不是 `ChapterData.chapterUUID` 的外鍵。

若直接把兩者當成同一個 ID，會導致：

- 新增故事線時產生錯誤或碰撞的關聯。
- 故事線與章節數量不一致時無法表達。
- 重新命名或移動章節時產生難以追蹤的 dangling reference。

應保留它作為 storyline ID，新增明確的 `OutlineChapterLinkData`。

## 5. 時間軸投影與狀態管理

### 5.1 時間軸是 derived state

推薦資料流：

```text
outlineDataProvider ─────┐
segmentsDataProvider ────┼──> timelineProjectionProvider ──> TimelineView
timelineDocument ────────┤              │
outlineChapterLinks ─────┘              │
                                       ├── filters
                                       ├── sort keys
                                       ├── dangling links
                                       └── chapter/scene counts
```

時間軸不保存另一份 `SceneData`。每次 Provider 重新計算時，從目前的大綱、章節樹和 link 產生扁平化的 `TimelineEntryViewModel`：

```dart
class TimelineEntryViewModel {
  final String? sceneUUID;
  final String placementUUID;
  final String? parentPlacementUUID;
  final TimelineElementLevel level;
  final String? eventUUID;
  final String? storylineUUID;
  final String sceneName;
  final String displayTime;
  final int? startTick;
  final int? durationTicks;
  final String? trackUUID;
  final String trackName;
  final String? location;
  final List<String> linkedChapterIDs;
  final bool isUnscheduled;
  final bool isOverlapping;
  final bool hasDanglingLink;
  final int narrativeOrder;
  final List<String> breadcrumbLabels;
}
```

`TimelineEntryViewModel` 不需要持久化。它是讓 UI 不必理解三層大綱結構的查詢結果。

### 5.2 Provider 建議

可按目前專案的 Riverpod 命名習慣拆成：

- `timelineLinksProvider`：保存 link 資料並提供新增、移除、批次更新方法。
- `timelineFilterProvider`：保存 storyline、folder、chapter、時間範圍、未排定等篩選條件。
- `timelineProjectionProvider`：由 `outlineDataProvider`、`segmentsDataProvider` 和 `timelineLinksProvider` 派生。
- `timelineSelectionProvider`：保存目前選取的 `sceneUUID`，不要用 index。
- `timelineNavigationCoordinatorProvider`：負責跨大綱、章節樹與編輯器的導航交易。

若第一版希望降低 Provider 數量，也可以先把 link 放進 `ProjectData` 聚合 Provider，之後再抽出 `timelineLinksProvider`。但投影和導航的責任仍應分離。

### 5.3 Tick 與多軌排序規則

```text
軌道內
  1. startTick 升冪
  2. durationTicks 升冪
  3. narrativeOrder
  4. placementUUID

跨軌道
  1. track.order
  2. startTick 升冪
  3. durationTicks 升冪
  4. narrativeOrder
  5. placementUUID

未分軌或未排定
  1. track.order（未分軌在最後）
  2. narrativeOrder
  3. placementUUID
```

排序必須是穩定的。使用者調整大綱順序後，即使兩個 placement 位於相同 Tick，畫面也不應隨機跳動。若作者拖曳的是同一軌道內的項目，應修改 `startTick` 或 `order`，但不可修改 `sceneUUID`。

時間軸的主要排序鍵是 Tick，而不是 `DateTime`。舊的 `timePointIso8601` 可在匯入或遷移時輔助轉換成 Tick，但轉換完成後，時間軸排列以 `startTick` 為準。

### 5.4 篩選條件

MVP 建議先做：

- 故事線。
- 資料夾/章節。
- 只看已連結、未連結或有 dangling link。
- 已排定/未排定時間。
- 關鍵字搜尋場景名稱、事件名稱、章節名稱。

日期範圍、角色、地點與跨故事線比較可在第二階段加入，避免第一版 UI 過度擁擠。

## 6. UI 與互動設計

### 6.1 建議版面

### 6.1 建議版面

採三個互相可定位的區域：

```text
┌──────────────────────┐
│ 時間軸                │
│ TimelineView         │
│                      │
│ 時間排序/篩選         │
└──────────────────────┘
┌──────────────────────┐
│ 區段編輯器            │
│                      │
│ 編輯選取元件之區段資訊 │
└──────────────────────┘
```

- 時間軸項目點選後進入獨立介面，顯示子元件之時間軸(小箱不用考慮)。
- 使用麵包屑返回主時間軸。
- 保留目前 `sceneUUID` 和 `chapterUUID`，避免返回後選取遺失。

### 6.2 Tick 網格與多軌畫面

時間軸主畫面建議採用「左側軌道標題、右側共享水平 Tick 尺」的甘特圖式列表：

```text
                  大箱 0                 大箱 1
                  ├────── 中箱 ──────┤   ├────── 中箱 ──────┤
Tick               0  1  2  3  4  5  6   7  8  9 10 11 12
軌道1              [       場景 A       ]
軌道2                 [    場景 B    ]
已重命名                         [ 事件 C ]
```

實作重點：

- 小箱是唯一的基本網格單位；中箱、大箱只是視覺標尺和時間標籤，不另外產生 placement。
- 所有軌道共用同一個 horizontal scroll controller 和 Tick-to-pixel converter。
- 拖曳 placement 時以 Tick snap；若目前縮放太小，仍以資料 Tick 為準，不以像素位置累積誤差。
- 左側固定軌道名稱，右側水平捲動；垂直捲動時保持尺在頂部或固定 header。
- 大箱和中箱應有不同線寬/顏色層級，小箱可使用淡網格，避免密集線條影響閱讀。
- 不能只用顏色辨識軌道；要同時提供名稱、圖示或標籤，兼顧色覺差異。

MVP 建議使用列表式、可拖曳卡片的時間軸，不先做任意縮放的無限畫布。畫布化會同時增加碰撞、虛擬化、捲動同步和觸控命中區域的複雜度。

### 6.3 Tick 設定面板

設定面板至少要顯示換算結果，而不只讓使用者輸入數字：

```text
Tick 長度： [15] [分鐘]
中箱：     [4] 個小箱       = 1 小時
大箱：     [6] 個中箱       = 6 小時
畫面縮放： [24] px / Tick
```

建議提供常用預設：

- 1 Tick = 1 分鐘
- 1 Tick = 15 分鐘
- 1 Tick = 1 小時
- 1 Tick = 1 天
- 自訂數值＋單位

`ticksPerMiddleBox` 和 `middleBoxesPerLargeBox` 可以先使用作品類型預設值，第二階段再開放作者調整。無論是否開放調整，中箱/大箱的實際時間都必須由公式計算，不允許使用者分別輸入互相矛盾的值。

### 6.4 軌道管理

軌道工具列建議提供：

- 新增軌道、改名、改色、拖曳調整軌道順序。
- 收合/展開軌道。
- 將目前選取場景放入軌道。
- 將場景移到另一軌道。
- 顯示軌道內事件數量與重疊警告。
- 選擇「依故事線建立軌道」的便利操作。

「依故事線建立軌道」只能是一次性的建立/對應動作，不應把故事線和軌道永久綁死；否則使用者無法用「角色線」「地點線」「世界事件」等不同維度檢視同一份大綱。

### 6.5 階層鑽入與 Breadcrumb

點擊大箱或中箱時，不是在同一個列表裡展開更多內容，而是進入該元素的獨立時間軸介面：

```text
根時間軸
  └─ 點擊「大箱 A」
      大箱 A 的中箱時間軸
        └─ 點擊「中箱 A-2」
            中箱 A-2 的小箱時間軸
```

畫面頂部固定顯示 Breadcrumb：

```text
全部時間軸  /  大箱 A  /  中箱 A-2
```

Breadcrumb 規則：

- 第一節「全部時間軸」回到根層。
- 中間節點回到對應父元素的子層時間軸。
- 最後一節是目前 scope，不應再以相同文字產生重複節點。
- 每一節以 `placementUUID` 導航，不以顯示名稱查找。
- 父元件改名後 Breadcrumb 即時更新；父元件刪除時回到仍存在的最近祖先。
- 進入子層後保留目前軌道篩選、Tick 水平位置和選取 placement；返回父層時可恢復原 scroll anchor。
- 從時間軸跳到大綱/章節後，仍可使用 Breadcrumb 返回原本的時間軸 scope。

每層介面使用同一個 TimelineView 元件，但傳入不同的 `scopePlacementUUID`：

```text
scope = null          → 顯示根層大箱
scope = largeUUID     → 顯示該大箱的中箱
scope = middleUUID    → 顯示該中箱的小箱
```

這樣可以重用 Tick 網格、拖曳、端點控制和多軌元件，同時讓使用者明確知道目前正在編排哪一層。

### 6.6 父子端點調整元件

每個可調整元素前後都要有獨立的 Tick 控制元件：

```text
[- 1 Tick] [◀ 頭端] ───── 元素內容 ───── [尾端 ▶] [+ 1 Tick]
```

建議支援：

- 頭端減少/增加 Tick：調整 `startTick`，並以 `endTick` 不變或保持最小長度為原則。
- 尾端減少/增加 Tick：調整 `durationTicks` 或 `endTick`。
- 拖曳整個元素：以 `deltaTick` 同時移動元素和所有子孫。
- 所有調整都 snap 到整數 Tick，並顯示調整後的 Tick 及換算時間。

端點調整的驗證順序：

1. 先套用使用者的端點操作。
2. 對直系子元素檢查父子 invariant。
3. 若子元素超出父範圍，自動擴大父元素。
4. 將父元素延展遞迴傳播至祖父元素。
5. 檢查同軌道後續元素的衝突。
6. 若有衝突，建立新軌道並搬移較後端的元素。
7. 以一次 history transaction 保存整個結果。

禁止只把控制項畫面上的位置改掉而不更新資料；所有控制項必須最後落到 `startTick`/`durationTicks`，畫面是資料的投影。

### 6.7 移動父元件時的子元件跟隨

移動父元件的操作定義為「整棵子樹平移」，不是重新排序子元件：

```text
delta = newParentStartTick - oldParentStartTick
child.startTick = child.startTick + delta
```

對所有後代遞迴套用同一個 `delta`：

- 子元件相對父元件的起點偏移不變。
- 子元件彼此的相對距離不變。
- 子元件的 duration 不變。
- 父元素的 duration 不因單純平移而改變。
- 若平移後與後續元素衝突，按自動分軌規則處理整棵後續子樹。

若只拖曳子元件，則只移動該子元件子樹；如果它越出父範圍，先擴大父範圍，不把父元件整體跟著移動。

### 6.8 時間軸項目內容

每個項目至少顯示：

- 顯示時間；沒有可排序時間時顯示「未排定」。
- 場景名稱。
- 所屬事件與故事線。
- 主要地點。
- 連結章節名稱。
- 未連結、時間衝突或 dangling link 的狀態圖示。

點選項目與點選「開啟」應有一致結果；拖曳調整時間軸順序則要明確標示是修改時間、修改敘事順序，還是只修改檢視排序，不能讓使用者猜測。

### 6.9 從大綱新增或修改場景

- 新增場景：保留既有大綱新增流程；時間軸 Provider 自動取得新項目。
- 修改 `sceneTimeController`：除更新 `time` 外，同步更新可排序值；空值時清除排序值。
- 修改名稱、地點、事件或故事線：時間軸只重新投影，不建立新 link。
- 移動事件/場景：保留 UUID，link 不變。
- 刪除場景：刪除該 `sceneUUID` 的 links；若支援復原，link 應包含在同一歷史快照中。

目前 `OutlineView` 已有約 300ms 的草稿 debounce。時間軸應沿用同一提交邊界，避免每次輸入一個字就進行完整跨模組重算及寫檔。

### 6.10 從章節選擇建立關聯

建議提供兩種入口：

1. 在時間軸項目上按「連結章節」：選章節樹中的一個或多個章節。
2. 在章節樹上選取章節後，按「加入時間軸」：選擇一個現有場景或建立場景後直接建立 link。

建立 link 時必須檢查：

- `sceneUUID` 是否仍存在。
- `chapterUUID` 是否仍存在。
- 相同 scene/chapter 組合是否已存在。
- 是否要取代既有主要章節，或新增為參考章節。

## 7. 大綱調整、Tick 順序與多軌衝突處理

### 7.1 不自動把大綱順序當作時間順序

大綱順序可能代表：

- 讀者看到的敘事順序。
- 作者的規劃順序。
- 某一條故事線的呈現順序。

時間軸的 Tick 順序則代表：

- 故事世界內事件發生的先後。

兩者可以不同。例如倒敘、平行敘事和多視角作品都需要這種差異。因此拖曳大綱不應自動改時間，拖曳時間軸也不應無提示地改動大綱陣列。

多軌後還要再區分「跨軌道同 Tick」和「同軌道重疊」：

- 跨軌道同 Tick 通常是合法的平行事件，不應視為錯誤。
- 同一軌道內 `startTick < other.endTick` 時，表示時間範圍重疊；MVP 顯示警告並保留作者位置。
- 若軌道代表互斥資源，例如同一角色的行程，可在軌道設定上標示 `exclusive`，再提供衝突檢查。
- 不同軌道內的視覺上下順序只由 `track.order` 決定，不應拿來推斷故事先後。

### 7.2 「依時間重新排列」的安全操作

如果提供自動整理功能，建議採用：

1. 顯示預覽差異。
2. 明確告知會修改故事線/事件/場景的陣列順序。
3. 允許只整理目前故事線或目前篩選結果。
4. 以現有 history provider 建立一次可復原的操作。
5. 遇到未排定項目時放在尾端，或要求使用者選擇處理方式。

對 Tick 網格另提供「吸附到最近 Tick」和「依 Tick 排序」兩個不同操作：

- 吸附只修正 placement 的 `startTick`/`durationTicks`。
- 依 Tick 排序只改變同一軌道的 `order` 或檢視順序。
- 兩者都必須可以 undo，不能把拖曳像素位置直接寫入浮點秒數。

### 7.3 後續元素衝突時的自動分軌

本需求要求「不可與後續元素衝突」。建議把它定義成同一 scope、同一軌道、同一層級下的時間區間不可重疊：

```text
current.startTick < later.endTick
且
current.endTick > later.startTick
```

調整目前元素造成衝突時，採用以下 deterministic 流程：

1. 找出目前 scope 中，位於同一軌道且 `order` 在目前元素之後的後續元素。
2. 找出與目前元素新範圍重疊的元素及其完整子樹。
3. 在目前軌道後方建立新軌道，名稱可暫定為「原軌道 2」，並保存 `derivedFromTrackUUID` 供 UI 顯示來源。
4. 按原順序把衝突元素及其子孫移到新軌道；所有 `startTick`、`durationTicks` 和父子相對位置保持不變。
5. 重新檢查新軌道；若新軌道仍和更後面的元素衝突，繼續在其後建立下一條軌道。
6. 同一個使用者操作只產生一次 undo history entry。

不要把衝突的後續元素直接推到目前元素尾端，因為那會默默改變作者原本的 Tick 時間；分軌只改變空間維度，不改變事件時間。

分軌範圍需依階層處理：

- 大箱衝突：搬移後續大箱及其完整中箱/小箱子樹。
- 中箱衝突：在目前 scope 的軌道新增軌道，搬移後續中箱及其小箱子樹。
- 小箱衝突：搬移後續小箱；若小箱是由同一場景的 placement 產生，所有同一 placement 的視覺引用需一起處理。

如果衝突元素已有其他軌道引用，不應複製元素資料；只移動當前 scope 的 placement，並在 UI 顯示該場景的多軌引用。

自動分軌後，應提供「合併軌道」預覽。只有合併後不違反同軌不重疊和父子範圍 invariant 時才允許確認。

## 8. 刪除、移動與一致性規則

| 操作 | 章節 UUID | 場景 UUID | Link 處理 | UI 行為 |
|---|---|---|---|---|
| 章節改名 | 不變 | 不變 | 保留 | 時間軸名稱更新 |
| 章節移動資料夾 | 不變 | 不變 | 保留 | 章節路徑更新 |
| 場景改名/改時間 | 不變 | 不變 | 保留 | 項目重新投影 |
| 場景改 Tick 位置/時長 | 不變 | 不變 | 保留 | 只更新時間軸 placement |
| 場景移動事件/故事線 | 不變 | 不變 | 保留 | 所屬標籤更新 |
| placement 移動軌道 | 不變 | 不變 | 保留 | 更新 track 與軌道內排序 |
| 軌道改名/排序 | 不變 | 不變 | 保留 | 所有 placement 位置不變 |
| 刪除軌道 | 不變 | 不變 | 保留 | 先移到其他軌道或未分軌 |
| 移動父元素 | 不變 | 不變 | 保留 | 父子樹以同一 delta Tick 平移 |
| 子元素超出父範圍 | 不變 | 不變 | 保留 | 父與祖先自動延展 |
| 父元素延展造成後續衝突 | 不變 | 不變 | 保留 | 後續元素及子樹移至新軌道 |
| 刪除章節 | 移除 | 不變 | link 變 dangling，建議確認後清理 | 顯示修復提示 |
| 刪除場景 | 不變 | 移除 | 連同 links 移除 | 時間軸項目消失 |
| 讀到不存在的 scene/chapter | 不適用 | 不適用 | 暫留 dangling | 不阻擋載入，提供修復 |

不建議在載入時靜默刪除 dangling link。應保留並產生 migration warning 或資料修復提示，讓使用者知道原本的規劃關係曾存在。

## 9. 儲存格式與版本遷移

### 9.1 建議新增 TimelineLinks XML Type

現有大綱與章節都已有獨立 XML Codec。時間軸關聯建議另存為可選的 Type：

```xml
<Type>
  <Name>TimelineLinks</Name>
  <Link
    UUID="link-1"
    SceneUUID="scene-1"
    ChapterUUID="chapter-4"
    Sequence="0"
    Coverage="full">
    <Note>本章節包含場景的完整段落</Note>
  </Link>
</Type>
```

好處：

- 舊有 Outline XML 不必重新解釋。
- 沒有 link 的舊專案不需新增空節點。
- 可由 `project_io_providers.dart` 沿用 selected modules 的匯入/匯出策略。
- 未來新增欄位不會把 `Scene` XML 變得過度耦合。

若產品最後決定只支援單一 scene-to-chapter 關係，仍可使用同一個 Type，只把 UI 限制成單選。

Tick 網格與多軌配置可放在同一個 Type 的子節點，或拆成 `Timeline` Type。建議拆成 `Timeline`，因為它不只是章節關聯：

```xml
<Type>
  <Name>Timeline</Name>
  <Grid TickValue="15" TickUnit="minute"
        TicksPerMiddle="4" MiddlesPerLarge="6"
        OriginLabel="故事開始" />
  <Tracks>
    <Track UUID="track-main" Name="主角線" Order="0" />
    <Track UUID="track-world" Name="世界事件" Order="1" />
  </Tracks>
  <Placements>
    <Placement UUID="placement-1" SceneUUID="scene-1"
               ParentUUID="large-1" Level="small"
               TrackUUID="track-main" StartTick="0"
               DurationTicks="8" Order="0" />
  </Placements>
</Type>
```

`TimelineLinks` 和 `Timeline` 可以分開：前者描述場景/章節關係，後者描述 Tick 位置和軌道。這樣匯出時可以只帶出大綱內容，也可以選擇一併帶出時間軸編排。

### 9.2 專案版本

現有 `ProjectMigrator` 會依專案版本集中處理升級。新增 link 後應：

1. 提高專案格式版本，例如從目前版本升至下一個 patch/minor 版本。
2. 沒有 `TimelineLinks` Type 時初始化為空清單。
3. 保留舊 `SceneData.time` 及 `timePointIso8601`。
4. 對可解析的舊時間補上 sortable value；不可解析者進入未排定區。
5. 不因場景名稱等於章節名稱就自動建立 link。
6. 對重複 link、缺失 scene、缺失 chapter 產生可讀 warning。

### 9.3 舊日期轉 Tick 的遷移

舊專案只有 `timePointIso8601` 時，不能直接假設 `2026-01-01` 就是 Tick 0。應由使用者選擇：

1. 指定 Tick 0 的原點日期/故事時刻。
2. 指定一 Tick 的時長。
3. 預覽每個場景轉換後的 `startTick`。
4. 對無法解析或超出精度的項目顯示「需人工處理」。
5. 確認後一次寫入 placements，原本的 `time` 和 `timePointIso8601` 仍保留作顯示/回溯。

換算概念為：

```text
startTick = round((sceneTime - originTime) / tickDuration)
```

若要保留舊日期的精準差異，則應把 Tick 時長設為足以容納最小單位，或讓轉換器允許 fractional remainder 並要求使用者決定是否吸附；資料層仍建議保存整數 Tick。

### 9.4 既有 `timePointIso8601` 的處理

目前已經有 `<TimePoint>` 的 XML 讀寫和遷移補值邏輯。因此第一版不需一次更換場景模型：

- `time` 繼續保存原始顯示文字。
- `timePointIso8601` 供時間軸排序。
- 使用者輸入無法解析的文字時，清除或保留舊 sortable value 必須有明確規則；建議輸入內容改變後若不再能代表原時間，就清除舊值並顯示「未排定」。

## 10. 實作分階段與工期

### Phase 0：規格確認與資料邊界（0.5–1 人日）

- 確認時間軸是宇宙內時間、敘事時間，還是兩者都要。
- 確認一個場景是否允許跨多章。
- 確認第一版是否接受 ISO-8601 以外的時間。
- 確認 XML Type 是否受 selected module 匯出控制。
- 明確保留 `StorylineData.chapterUUID` 為 storyline ID。

交付：資料契約與 UI 流程定稿。

### Phase 1：Tick/軌道資料模型、快照與 XML（2–3 人日）

- 新增 `OutlineChapterLinkData`。
- 新增 `TimelineDocumentData`、`TimelineGridConfig`、`TimelineTrackData`、`TimelinePlacementData`。
- 定義 `tickDuration`、小箱/中箱/大箱換算與整數 Tick invariant。
- 定義 `parentPlacementUUID`、`TimelineElementLevel` 和父子範圍 invariant。
- 擴充 `ProjectData`、`ProjectMigrationResult` 和 snapshot。
- 新增 TimelineLinks/Timeline codec。
- 接上 project load/save/export/import。
- 更新 Freezed 產物，禁止手動修改 generated file。

交付：Tick 網格、軌道、placement 和章節 link 可建立、保存、載入及 round-trip。

### Phase 2：Tick 投影、多軌索引與 Provider（2–3 人日）

- 實作場景扁平化索引。
- 實作 Tick-to-pixel、pixel-to-Tick 與 snap。
- 實作軌道 lookup、軌道順序、同軌重疊檢查。
- 實作未分軌、未排定及 dangling link 狀態。
- 實作 link lookup、dangling link 檢查。
- 實作多軌排序及篩選 Provider。
- 實作父子索引、Breadcrumb scope 和祖先範圍重算。
- 讓 `outlineDataProvider` 和 `segmentsDataProvider` 更新後自動刷新時間軸。

交付：以測試或簡單畫面驗證 Tick 排列、多軌投影和重疊判定正確。

### Phase 3：Tick 網格與 TimelineView MVP（3–5 人日）

- 左側軌道標籤、右側共享 Tick 尺與水平捲動。
- 顯示小箱、中箱、大箱與換算後時間標籤。
- 提供 `pixelsPerTick` 畫面縮放，不和故事 Tick 時長混用。
- 支援新增、改名、排序、收合及刪除軌道。
- 支援 placement 拖曳、Tick snap、調整時長及移動軌道。
- 支援端點控制、父元件自動延展、子樹相對位移。
- 支援衝突檢查與後續元素自動分軌。
- 顯示場景、故事線、事件、章節 link。
- 提供搜尋、已排定/未排定、未分軌、章節篩選。
- 提供建立、移除 link 的入口。
- 加入 empty、loading、dangling、無 Tick、重疊與未分軌狀態。

交付：時間軸可獨立瀏覽、調整 Tick 編排、管理多軌及管理章節關聯。

### Phase 4：跨模組導航（2–3 人日）

- 將場景選取改用 UUID 查詢。
- 實作 flush 草稿後的導航交易。
- 接入 `editorSelectionProvider` 和既有 editor coordinator。
- 章節樹自動展開/捲動到目標章節。
- 大綱畫面自動定位到目標 storyline/event/scene。
- 處理多章節 link 的選擇對話框。
- 從子層時間軸導航後保留 Breadcrumb scope。

交付：從時間軸、章節樹、大綱互相跳轉且不丟內容。

### Phase 5：Tick 轉換、衝突提示與整理工具（2–4 人日）

- Tick 缺失、同軌重疊、同 Tick 平行事件提示。
- 調整 Tick 時長時提供「重新解讀」及「保留實際時間」預覽。
- 舊日期轉 Tick 的原點設定、換算預覽與 undo。
- 「依 Tick 重新排列」預覽與 undo。
- 小箱吸附、批次移動軌道、批次關聯。
- 批次連結或解除連結。
- dangling link 修復清單。

交付：適合日常寫作使用的修正工作流。

### Phase 6：測試與回歸（2–3 人日）

- 模型與 Provider 單元測試。
- XML round-trip 與舊格式遷移測試。
- 章節移動/刪除與 link 一致性測試。
- 編輯器未儲存草稿切換測試。
- Flutter widget/integration 測試。
- 大型專案效能檢查。

## 11. 測試策略

### 11.1 模型與排序

- 點擊大箱進入中箱 scope，點擊中箱進入小箱 scope，Breadcrumb UUID 導航正確。
- 父元素的 `startTick/endTick` 永遠包住所有直系子元素。
- 子元素頭端移到父頭端之前時，父元素向前自動延展。
- 子元素尾端移到父尾端之後時，父元素向後自動延展。
- 父元素延展會遞迴更新祖父元素。
- 移動父元素時，所有子孫保持相同的相對 Tick 偏移。
- 調整元素端點時，後續同軌元素不會保留重疊；衝突元素會被移到新軌道。
- 新軌道建立後，原本較後端元素的 Tick 和子樹相對位置不變。
- Tick 長度、箱體倍率和換算後的中箱/大箱時間正確。
- `startTick`、`durationTicks` 只使用整數，負 Tick 可以正確排序。
- 改變 `tickDuration` 後，重新解讀模式保留 Tick 位置。
- 保留實際時間模式能依比例換算並顯示捨入誤差。
- 多軌共享同一時間尺，跨軌同 Tick 不被錯誤判定為衝突。
- 同軌重疊能被正確偵測；軌道順序改變不會改變 placement 的 Tick。
- placement 拖曳經過不同畫面縮放後仍落在一致 Tick。
- 相同時間的場景排序穩定。
- ISO-8601 含時區的時間排序一致。
- 純文字時間不會被錯誤當成可排序日期。
- `timePointIso8601` 為空時正確進入未排定區。
- 場景、事件、故事線移動後 UUID 不變。
- 重複 `sceneUUID + chapterUUID` link 被拒絕或去重。

### 11.2 跨模組一致性

- 父元件改名後 Breadcrumb 和所有子層標題即時更新。
- 父元件刪除後，時間軸回到最近仍存在的祖先 scope。
- 章節改名後時間軸名稱立即更新。
- 章節移動資料夾後 link 仍有效。
- 刪除章節後不會讓時間軸點擊到錯誤章節。
- 刪除場景後所有 link 一起移除。
- 載入包含缺失引用的檔案不會整個專案失敗。

### 11.3 導航與編輯器

- 從子層時間軸跳到大綱後返回，仍恢復原 Breadcrumb scope。
- 在編輯器有未提交文字時，從時間軸切換仍會保存原章節。
- 從無 link 場景點選不會誤切換到第一章。
- 多 link 場景會讓使用者選擇章節。
- 切換後 `selectedSegID` 與 `selectedChapID` 配對正確。
- 章節樹、編輯器內容、時間軸選取不出現上一章/下一章錯配。
- 切換專案後不殘留上一個專案的時間軸選取或 link。

### 11.4 持久化與遷移

- Timeline Grid、Tracks、Placements 保存後再載入不改變 Tick 位置和軌道順序。
- ParentUUID、Level 和軌道自動分配結果 round-trip 後不變。
- 舊日期轉 Tick 需要明確原點，不會把第一個場景默認成 Tick 0。
- 舊版無 TimelineLinks 的專案載入後時間軸為空但功能可用。
- 新版保存再載入後所有時間欄位與 links 相同。
- import/export 只選取 Outline 時，link 行為符合產品決策。
- 無法解析的舊時間保留原文字，不被清空。
- dangling link 有明確 warning，且不靜默刪除。

## 12. 效能與可維護性

### 12.1 小型到中型專案

目前大綱和章節都透過 immutable snapshot 更新。對一般小說專案，Provider 更新後完整建立一次扁平化投影通常足夠，不需要立即導入資料庫或 isolate。

建議：

- 用 `sceneUUID`、`chapterUUID` 建立 lookup map。
- 用 `trackUUID` 建立軌道索引，預先計算每個 placement 的 `endTick`。
- 將 Tick-to-pixel 轉換集中在單一 converter，避免每個 item 各自取整。
- `timelineProjectionProvider` 只在 outline、segments、links 或 filter 改變時重算。
- 不在每個 list item build 中重新遍歷整棵章節樹。
- UI 只使用 view model 的顯示值。

### 12.2 大型專案

若場景達到數千至數萬筆，再考慮：

- 以 revision/hash 判斷是否需要重建索引。
- 將排序鍵預先計算。
- 對時間軸列表使用虛擬化。
- 把昂貴的解析或統計移至既有 worker pattern。
- 避免把完整 `chapterContent` 帶入時間軸 view model。
- 大範圍水平空白區不要建立一個 Widget；使用可見 Tick 範圍計算標尺和項目位置。

### 12.3 Undo/Redo

時間軸 link、場景時間、大綱排序應落入同一個專案 history 邊界。一次「把場景連到章節」應是一次可撤銷操作；「依時間重新排列」應是一次整體快照，不應讓每一個元素移動都產生獨立 undo step。

## 13. 主要風險與應對

| 風險 | 影響 | 建議 |
|---|---|---|
| 把 storyline UUID 當 chapter UUID | 關聯錯誤且難以修復 | 新增獨立 link model，禁止語意混用 |
| 使用 index 作關聯 | 拖曳或刪除後指向錯誤 | 全部以 UUID lookup |
| 時間軸另存一份場景 | 大綱與時間軸互相覆蓋 | 時間軸只做 projection |
| 時間軸拖曳默默改大綱 | 倒敘/平行線被破壞 | 清楚區分檢視排序、時間修改、敘事排序 |
| 父子端點互相推動造成迴圈 | 範圍計算不穩定 | 只向祖先方向傳播延展，使用 immutable transaction 和 invariant validator |
| 自動分軌搬動過多元素 | 使用者不理解版面變化 | 顯示衝突清單、來源軌道、移動數量與一次性 undo |
| 子層 scope 與根層選取不同步 | Breadcrumb/導航回錯層 | 以 placement UUID 保存 scope，刪除時回退最近祖先 |
| 直接操作 TextEditingController | 章節內容遺失 | 統一交由 editor coordinator flush/switch |
| 刪除資料時靜默清 link | 使用者無法追蹤規劃遺失 | warning、修復清單、可復原 |
| 第一版做自由縮放畫布 | UI/效能成本高 | 先做列表式時間軸 |
| 只支援 DateTime | 虛構世界時間無法使用 | MVP 保留顯示文字，第二階段抽象 calendar/position |
| 每次輸入都重算和寫檔 | 輸入卡頓、dirty 狀態混亂 | 沿用現有 debounce 與快照邊界 |

## 14. MVP 驗收標準

以下條件全部達成即可視為第一版完成：

- 可以看到所有大綱場景的時間軸列表。
- 每個已排定場景以整數 Tick 定位，並按 `startTick` 排序。
- 小箱、中箱、大箱的時間標籤由 Tick 長度和倍率推導。
- 使用者可以調整 Tick 時長，也可以獨立調整畫面 Tick 寬度。
- 使用者可以建立、排序、收合至少兩條軌道，並將場景在軌道間移動。
- 點擊大箱可進入其中箱時間軸，點擊中箱可進入其中小箱時間軸。
- Breadcrumb 能顯示並返回目前的大箱/中箱/小箱層級。
- 每個元素可以調整頭端與尾端 Tick，且不會破壞父子包覆關係。
- 子元素超出父範圍時，父元素和必要的祖父元素會自動延展。
- 移動父元素時，子元素保持相對位置跟隨移動。
- 調整造成後續元素衝突時，後續元素會自動放入新軌道，而不是被靜默改變 Tick。
- 可從時間軸篩選目前章節或未連結場景。
- 可建立、移除場景與章節的 link。
- 從時間軸點選場景，可以正確跳到大綱場景及其關聯章節。
- 點選無關聯場景時，不會誤切換編輯器章節。
- 章節改名、移動資料夾、場景改名、修改時間會即時反映。
- 同軌重疊有提示，跨軌同 Tick 可正常共存。
- 刪除場景或章節後，不會產生錯誤導航；缺失引用有提示。
- 舊專案可以載入，新舊專案都能 round-trip 保存。
- 編輯器未保存內容不會因時間軸導航而遺失。
- 時間軸新增功能不破壞現有大綱、章節樹、undo/redo 與專案匯入匯出。

## 15. 建議的實作順序

建議依下列順序開發，避免先做 UI 後才發現資料關聯不足：

```text
資料契約（Tick、軌道、placement、章節 link）
  ↓
Timeline model + Link model + ProjectData + migration + XML
  ↓
Tick converter、軌道索引與 timeline projection
  ↓
Tick 網格與多軌 TimelineView
  ↓
統一導航協調器
  ↓
大綱/章節雙向入口
  ↓
衝突提示、批次操作、依時間排序
```

最重要的決策是先固定三件事：

1. `SceneData` 的時間欄位是唯一故事時間來源。
2. `sceneUUID` 與 `chapterUUID` 透過獨立 link 關聯。
3. 所有跨畫面切換都經過同一個導航協調器。

只要這三點維持不變，第一版可以先做簡單列表，日後再加入虛構曆法、跨章節涵蓋、縮放畫布及批次整理，而不必重寫既有大綱與章節資料。

## 16. 相關程式位置

- `dart_edition/lib/models/outline_data.dart`：故事線、事件、場景及場景時間欄位。
- `dart_edition/lib/models/chapter_selection_data.dart`：章節樹、章節 UUID、遞迴查詢與排序。
- `dart_edition/lib/modules/outlineview.dart`：大綱 UI、場景編輯、拖放與 Outline XML Codec。
- `dart_edition/lib/modules/chapterselectionview.dart`：章節樹 UI、章節選取、拖放與 Chapter XML Codec。
- `dart_edition/lib/models/project_data.dart`：專案聚合資料模型。
- `dart_edition/lib/models/project_migrator.dart`：專案格式遷移與引用驗證。
- `dart_edition/lib/presentation/providers/project_state_providers.dart`：大綱、章節及編輯器選取 Provider。
- `dart_edition/lib/presentation/providers/project_snapshot_utils.dart`：專案資料 snapshot/freeze。
- `dart_edition/lib/presentation/providers/editor_coordinator_provider.dart`：章節內容同步、專案套用與編輯器導航邊界。
- `dart_edition/lib/presentation/providers/project_io_providers.dart`：專案讀寫與模組匯入匯出。
