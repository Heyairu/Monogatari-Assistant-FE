# 角色設定快照（串接時間軸）實作規劃

> 文件目的：定義「角色設定快照」如何以既有時間軸的 Tick 作為故事時間基準，列出需要調整的資料模型、儲存、狀態管理、UI、遷移、測試與分期交付內容。
>
> 盤點基準：`dart_edition/lib/models/character_data.dart`、`dart_edition/lib/models/timeline_data.dart`、`dart_edition/lib/models/codecs/character_state_codec.dart`、`dart_edition/lib/presentation/providers/timeline_providers.dart`、`dart_edition/lib/presentation/providers/project_state_providers.dart`、`dart_edition/lib/presentation/providers/project_snapshot_utils.dart`。
>
> 本文件中的「快照」是指**指定故事時間的角色推導結果**；不可與 undo/redo 所保存的「整份專案歷史快照」混為一談。
>
> **1.12 修訂：** 快照不再建立所在地、健康、情緒、陣營、簡化持有物或自訂狀態等獨立欄位。快照直接沿用角色卡既有的「阻礙、人物關係、組織、角色狀態、擁有物品」Table，並包含自訂欄位。

## 1. 結論與推薦範圍

推薦將角色快照實作成「預設狀態 + 綁定 Scene 的狀態變更」，再由 Scene 在時間軸上的 Tick 排序推導出的唯讀結果，而不是在每個時間點複製一份完整角色卡。

```text
CharacterEntryData（固定人物設定）
        +
CharacterEntryData 中六組可快照資料（預設狀態）
        +
CharacterStateChange（綁定 Scene；依該 Scene 的 Tick 依序套用）
        ↓
CharacterStorySnapshot（目前 Tick 的推導結果，僅供檢視／編輯入口）
```

第一版直接共用時間軸既有的 `TimelineViewState.currentTick` 作為檢視游標，但快照的主要錨點為 `SceneData.sceneUUID`。使用者在時間軸移動播放頭後，角色頁便顯示該 Tick 的狀態；在角色頁新增快照時，先選擇或快速建立 Scene，再把該 Scene 綁定到變更事件。Tick 是由 Scene 的 timeline placement 解析出的排序值與失效回退值。

### 1.1 為何不儲存完整角色複本

- 固定設定（姓名、核心個性、外觀、長期目標）不會因為故事推進而重複儲存。
- 修改早期事件後，後面 Tick 的狀態可自然重算，不會留下多份過期副本。
- 專案 XML、歷史紀錄與同步時只傳遞差異事件，資料量和衝突面較小。
- 快照不可被誤認為一名新角色或一份可獨立儲存的角色設定。

### 1.2 第一版可交付功能

1. 在時間軸以目前 Tick 檢視角色的阻礙、人物關係、組織、角色狀態、擁有物品與自訂欄位。
2. 在角色設定頁以「預設 + 所有 Scene 快照」清單／時間線預覽完整狀態歷史；可點選任一快照比較或跳至 Scene。
3. 從角色頁快速選擇現有 Scene 或以最小表單新增 Scene，並立即建立綁定該 Scene 的快照；不會覆寫角色基本資料。
4. 快照可從另一個快照或預設狀態複製，帶入完整推導值後再調整差異，減少重複輸入。
5. 顯示「本 Scene 相較前一個狀態」的欄位差異、變更原因／備註，以及可跳回來源 Scene／時間軸位置的連結。
6. 變更事件可編輯、刪除、還原；所有操作納入既有專案 undo/redo、dirty state、自動儲存與 XML round-trip。
7. 在時間軸選取角色後，只顯示與該角色有關的狀態變更標記或清單（第一版不強制做複雜的圖形覆蓋層）。

### 1.3 不納入 MVP 的項目

- 每個 Tick 自動建立完整快照檔。
- 依真實日期、虛構曆法或自然語言日期推導狀態；MVP 一律以整數 Tick 排序。
- 關係圖的時間狀態、能力值曲線、角色服裝圖像版本、多使用者同步衝突處理。
- 自動從正文或 AI 推論狀態變化。

## 2. 既有基礎與目前缺口

### 2.1 可直接沿用的能力

| 項目 | 現況 | 快照功能的用途 |
| --- | --- | --- |
| 角色識別 | `CharacterEntryData.characterId` 已是 UUID，`characterData` 也以 ID 為 key | 變更事件穩定引用角色；角色改名不影響歷史 |
| 時間軸位置 | `TimelinePlacementData.startTick`、`durationTicks`、`placementUUID` 已存在 | 以 `startTick` 當故事時間座標，必要時連回來源 placement |
| 播放頭 | `TimelineViewState.currentTick` 與 `setCurrentTick()` 已存在 | 直接作為角色快照的全域查詢時間 |
| 專案聚合 | `ProjectData` 已包含 `characterStates`、`timelineDocument` | 可擴充為狀態變更集合並一起保存／還原 |
| 專案歷史 | `ProjectHistoryEntry` 會保存不可變 `ProjectData` 快照 | 新增或刪除變更事件自動可 undo/redo |
| XML 通道 | `CharacterStateCodec` 已有獨立 `<Type><Name>CharacterStates</Name>` codec | 可在此處做新格式讀寫與舊格式相容 |

### 2.2 目前資料不足以構成快照

現有 `CharacterState` 僅有 `characterId`、可選 `storyTimePointId`，以及六種狀態欄位。它有保存能力，但還沒有下列快照必要資訊：

- 沒有狀態變更自身的唯一 ID，因此無法精確編輯／刪除某一筆歷史事件。
- `storyTimePointId` 不對應現有時間軸的 `currentTick` 或 `placementUUID`，無法穩定排序與推導。
- 沒有同 Tick 多筆變更的穩定順序。
- 空字串無法判斷是「未變更」還是「刻意清空」，因此不能安全做 patch 合併。
- 沒有來源、備註、建立時間或可直接對應角色 Table 的結構。
- `CharacterStatesNotifier` 目前只有整批覆寫方法，沒有新增、更新、刪除單筆變更的交易 API。
- 角色頁尚未以時間游標顯示／編輯狀態；時間軸也尚未投影角色變更。

因此，現有 `CharacterState` 可作為**舊格式相容模型**，但不應直接擴充成最終快照模型。

## 3. 核心行為與資料規則

### 3.1 時間錨定規則（Scene 為主、Tick 為輔）

每個一般快照事件必須綁定 `sceneUUID`；這是快照的主要業務錨點與導覽目標。解析快照時間時，先取得該 Scene 對應的時間軸 placement，再讀取其 `startTick`。事件同時保存 `fallbackTick`，只在 Scene 尚未排入時間軸、placement 被刪除或專案載入時連結暫時失效時用於排序與顯示。

```text
Scene UUID（快照的主要綁定、改名／重排不失聯）
  └─ 主要 placement UUID（選填；多軌／多 placement 時指定）
       └─ resolvedTick = placement.startTick
            └─ fallbackTick（無法解析 Scene 時的次要回退）
```

`CharacterStateBaseline` 是唯一不綁定 Scene 的「預設快照」：它代表故事開始前的初始狀態，可被檢視與複製，但不能冒充某個場景中的事件。

Scene 在多條軌道有多個 placement 時，新增快照必須讓使用者選定來源 placement；若未選，採該 Scene 最早的 `(startTick, track.order, placementUUID)` 作為主要 placement，並在 UI 顯示選擇結果。不可依名稱猜測 Scene 或 placement。

```text
Scene 改名／移動大綱：快照保持綁定，名稱自動更新
Scene 的主要 placement 移動：快照的 resolvedTick 跟隨更新
Scene 未排入時間軸：使用 fallbackTick，預覽標示「未排定」
Scene／placement 刪除：不刪除歷史資料，改顯示失效引用並要求修復或保留
```

### 3.2 排序、推導與衝突規則

同一角色在目標 Tick `T` 的推導程序：

1. 取角色的 `CharacterStateBaseline`；未填欄位為空白／未設定。
2. 取每筆快照的 `resolvedTick`（優先 Scene placement、失效時用 `fallbackTick`）。
3. 選出 `resolvedTick <= T` 的變更事件。
4. 依 `(resolvedTick, sequence, stateChangeId)` 升冪排序。
5. 逐筆套用 patch，最後結果即為 `CharacterStorySnapshot`。

`sequence` 僅用於同一角色、同一 resolved Tick 的明確順序；新增同 Tick 事件時預設為最大 sequence + 1。拖曳改序時必須重新編號為連續整數，且是單一 undoable 交易。`stateChangeId` 只作最後的 deterministic tie-break，不可期待 UUID 的字典序具業務語意。

不同角色在同 Tick 的變更互不覆蓋。關係變化屬於另一個未來模型，不應塞進角色個人狀態。

### 3.3 Patch 必須能分辨「不修改」與「清空」

快照的每一組 Table 採整份替換語意：`null` 代表本事件不修改該組資料，空集合代表清空，非空集合代表以該集合取代先前推導結果。透過 UI 建立或複製的快照會寫入六組完整資料，因此後續快照可獨立調整，不會與來源共享可變集合。

### 3.4 固定設定與故事狀態的邊界

| 資料類型 | 權威位置 | 快照是否覆寫 |
| --- | --- | --- |
| `displayName`、別名、角色類型、固定出生資料 | `CharacterEntryData` | 否 |
| 長期性格、核心動機、目標、背景備註 | `CharacterEntryData` | MVP 否 |
| 阻礙 Table、人物關係 Table、組織 Table、角色狀態 Table、擁有物品 Table | 預設為 `CharacterEntryData`；Scene 為 `CharacterStateChange` | 是 |
| 自訂欄位（含型別與值） | 預設為 `CharacterEntryData.customFields`；Scene 為 `CharacterStateChange` | 是 |
| 作者備註、設計筆記 | 角色資料或變更事件的 `note` | 不作自動推導 |

ComboBox 選擇「預設」時，六組資料直接編輯 `CharacterEntryData`；選擇 Scene 快照時，同一套 Table 控制項改為編輯該 Scene 的完整推導狀態。其餘角色資料維持顯示但停用，不能被 Scene 快照覆寫。

## 4. 建議資料模型

### 4.1 持久化模型

建議新增 `dart_edition/lib/models/character_state_change_data.dart`，並以 Freezed 產生不可變模型。

```dart
@freezed
class CharacterStatePatch with _$CharacterStatePatch {
  const factory CharacterStatePatch({
    List<CharacterConflict>? conflicts,
    List<CharacterRelationship>? relationships,
    List<CharacterProfileTableEntry>? organizations,
    List<CharacterProfileTableEntry>? statusEntries,
    List<CharacterPossessionEntry>? possessions,
    Map<String, CustomFieldValue>? customFields,
  }) = _CharacterStatePatch;
}

@freezed
class CharacterStateChange with _$CharacterStateChange {
  const factory CharacterStateChange({
    required String stateChangeId,
    required String characterId,
    required String sceneUUID,
    String? sourcePlacementUUID,
    required int fallbackTick,
    @Default(0) int sequence,
    @Default(CharacterStatePatch()) CharacterStatePatch patch,
    @Default("") String note,
  }) = _CharacterStateChange;
}

@freezed
class CharacterStateBaseline with _$CharacterStateBaseline {
  const factory CharacterStateBaseline({
    required String characterId,
    @Default(CharacterStatePatch()) CharacterStatePatch patch,
    @Default("") String note,
  }) = _CharacterStateBaseline;
}

@freezed
class CharacterStorySnapshot with _$CharacterStorySnapshot {
  const factory CharacterStorySnapshot({
    required String characterId,
    required int resolvedTick,
    String? sceneUUID,
    String? sourcePlacementUUID,
    @Default(<CharacterConflict>[]) List<CharacterConflict> conflicts,
    @Default(<CharacterRelationship>[]) List<CharacterRelationship> relationships,
    @Default(<CharacterProfileTableEntry>[]) List<CharacterProfileTableEntry> organizations,
    @Default(<CharacterProfileTableEntry>[]) List<CharacterProfileTableEntry> statusEntries,
    @Default(<CharacterPossessionEntry>[]) List<CharacterPossessionEntry> possessions,
    @Default(<String, CustomFieldValue>{}) Map<String, CustomFieldValue> customFields,
    @Default(<String>[]) List<String> appliedStateChangeIds,
  }) = _CharacterStorySnapshot;
}
```

`CharacterStorySnapshot` 是衍生資料，不寫入 XML／`ProjectData`；其 `appliedStateChangeIds` 只供差異面板與追溯來源使用。1.12 起「預設」直接取自 `CharacterEntryData` 的六組資料；`CharacterStateBaseline` 僅保留舊檔載入相容性，遷移時會合併回角色資料。

### 4.2 `ProjectData` 與 Provider 更新

將 `ProjectData.characterStates` 替換為或過渡為：

```dart
Map<String, CharacterStateBaseline> characterStateBaselines;
List<CharacterStateChange> characterStateChanges;
```

建議保留 `CharacterState` 和 `characterStates` 僅作 codec 遷移的內部相容資料，完成一版格式升級後再移除。若過渡期同時存在兩個集合，必須規定只有 `characterStateChanges` 可編輯與寫回，舊集合只讀取一次後轉換；不可讓兩者都成為可寫資料來源。

`CharacterStatesNotifier` 應改名為 `CharacterStateChangesNotifier`，最少提供：

- `setBaselines(Map<String, CharacterStateBaseline>)` 與 `updateBaseline(characterId, patch)`
- `setChanges(List<CharacterStateChange>)`
- `addChange(CharacterStateChange)`：驗證 Scene／placement、保存 fallback Tick 並正規化同 Tick sequence。
- `updateChange(String id, CharacterStateChange Function(...))`
- `deleteChange(String id)`
- `duplicateToScene({sourceSnapshot, characterId, targetSceneUUID, targetPlacementUUID?})`：將來源的**完整推導結果**轉為 target Scene 的完整 `set` patch。
- `reorderAtSceneTick({characterId, sceneUUID, resolvedTick, orderedIds})`
- `deleteForCharacter(String characterId)`：只能由角色刪除確認流程呼叫。

所有寫入都需輸出不可變 list，觸發既有 dirty／project aggregate provider，並在 UI 草稿 flush 後記錄為單一歷史節點。

### 4.3 純函式／Use case

新增 `character_state_snapshot_resolver.dart`，不要把推導邏輯放在 Widget 或 notifier。最少需要：

```dart
CharacterStorySnapshot resolveCharacterSnapshot({
  required CharacterEntryData character,
  required CharacterStateBaseline? baseline,
  required Iterable<CharacterStateChange> changes,
  required TimelineDocumentData timeline,
  required int atTick,
});

CharacterStateSnapshotDiff diffSnapshots(
  CharacterStorySnapshot previous,
  CharacterStorySnapshot current,
);

List<CharacterStateChange> orderedChangesForCharacter(...);

ResolvedCharacterStateChange resolveChangeTime(...);
```

Resolver 不讀 Riverpod、不修改資料、不依賴目前畫面；同樣輸入必須產生同樣輸出。Provider、測試與未來 MCP／匯出才可安全重用。

## 5. 與時間軸的整合方式

### 5.1 全域時間游標

`timelineViewProvider.currentTick` 已能代表播放頭。新增下列 derived providers：

```text
timelineCurrentTickProvider
characterStateChangesForCharacterProvider(characterId)
characterSnapshotAtTickProvider((characterId, tick))
currentCharacterSnapshotProvider(characterId)
characterStateChangesAtTickProvider(tick)
characterSnapshotTimelineProvider(characterId)
```

角色頁應 watch `currentCharacterSnapshotProvider(characterId)`；時間軸面板可 watch `characterStateChangesAtTickProvider(currentTick)`。`characterSnapshotTimelineProvider` 需回傳「預設快照 + 所有 Scene 快照」的排序投影，包含場景名稱、resolved／fallback Tick、來源 placement、失效狀態與差異摘要，供角色頁完整預覽。若日後角色頁需要獨立預覽不同時間，另加本地 preview tick，不能偷偷覆蓋全域播放頭。

### 5.2 從時間軸建立與導覽

| 使用者操作 | 系統行為 |
| --- | --- |
| 點選角色後「新增 Scene 快照」 | 先選取／建立 Scene，再建立 `sceneUUID` 綁定的快照草稿 |
| 從某小箱建立狀態 | 綁定小箱的 `sceneUUID`、保存其 `placementUUID` 與 `startTick` 為 fallback |
| 點選狀態事件的來源 | 優先選取該 Scene 與主要 placement；失效時定位至 `fallbackTick` 並顯示修復操作 |
| 拖動時間軸播放頭 | 只改 UI state，不建立歷史紀錄、不標記 dirty |
| 移動來源小箱 | 快照保留 Scene 綁定並依新的 `startTick` 重排；頁面提示受影響快照 |

第一版不要求每筆變更都是時間軸中的獨立可拖曳箱。先在 Scene 對應 Tick 位置以小型 marker／側欄清單呈現即可；這能避開變更事件和大綱場景 placement 的雙重布局與重疊規則。

### 5.3 角色篩選與可讀性

- 時間軸工具列增加「角色」篩選器，依 `characterId` 選擇、以 `displayName` 顯示；不可用名稱當儲存 key。
- 角色篩選啟用時，保留原本大綱 placement，並額外顯示該角色的狀態 marker；不要複製場景資料。
- 若場景的 `people` 欄位尚有舊名稱字串，只作顯示／建議，不能用它自動建立角色狀態。
- marker 預設顯示事件數；同 Tick 多筆變更可開啟清單並顯示 sequence。

## 6. UI 與操作流程

### 6.1 角色卡頂部快照操作列

角色卡上方固定提供 ComboBox 與兩個 IconButton。ComboBox 預設為「預設」，並列出所有 Scene 快照；按鈕分別用於新增與複製目前快照：

```text
[角色快照：預設／Tick 24 · 伏擊事件 ▼]          [新增] [複製]

角色卡
  阻礙與解決方式 Table
  人物關係 Table
  所屬組織 Table
  角色狀態 Table
  擁有物品 Table

自訂資料
  文字／滑桿／核取方塊／清單型自訂欄位

快照總覽                                              [複製快照] [新增 Scene 快照]
預設狀態（故事開始前）                               [檢視] [複製]
Tick 12　城門衝突                                    [檢視] [複製] [前往]
Tick 24　伏擊事件                                    [檢視] [複製] [前往]
```

選取「預設」時，Table 與自訂欄位直接更新角色資料。選取 Scene 快照時仍使用完全相同的 Table／自訂欄位元件，但儲存目標改為該 Scene 的 `CharacterStateChange`；姓名、暱稱、角色類型、外觀、性格文字、備註與進階設定停用。快照總覽必須預覽**所有**快照，不因目前 Tick 篩掉未來項目。

### 6.2 快速新增 Scene 快照

「新增 Scene 快照」採兩段式但不離開角色頁的流程：

1. **選擇 Scene**：使用 UILib `AppDropdownField` 選擇既有 Scene，顯示其故事線／事件／Scene；也可切換為快速建立。
2. **選擇或建立大箱**：使用可編輯 `AppComboBoxField`，可選取時間軸既有大箱，或直接輸入新大箱名稱。
3. **選擇或建立中箱**：使用可編輯 `AppComboBoxField`，選項依目前大箱過濾；輸入不存在的名稱時，在該大箱下建立新中箱。
4. **建立小箱**：小箱維持一般 `AppTextField`，輸入 Scene 名稱後建立新的大綱 Scene 與時間軸 placement。
5. **確認 Tick**：顯示外觀與 Timeline 一致的唯讀迷你時間軸，包含 Tick 刻度、節點方塊、垂直 Scrubber 與目前 Tick。可點擊時間軸、拖曳 Scrubber，或直接輸入含負值的 Tick；不提供節點位置、長度、父子關係或排序調整。
6. **選擇初始內容**：空白、目前播放頭、預設或任一既有 Scene 快照。

Tick 採固定安全範圍：時間軸播放頭與 Tick 輸入允許 `-4194304～+4194304`；節點實際可佔用範圍為 `-4194304～+4194303`。節點尾端採 exclusive end，因此合法尾端可等於 `+4194304`。建立、移動、縮放、階層同步、XML 載入與 Scrubber 都必須共用此限制；超出範圍的既有或外部資料需安全夾限，不能造成加減運算溢位或生成範圍外節點。

Dialog 外殼使用 `AppDialog`，分區使用 `AppSectionCard`，提示與錯誤使用 `AppNoticeBanner`，避免混用未套用應用程式樣式的原生表單。

迷你時間軸的預覽層級依 ComboBox 內容即時決定：

- 大箱與中箱都能解析至既有 placement：進入該中箱，只顯示其小箱。
- 大箱能解析、但中箱不存在：進入該大箱，只顯示其直屬中箱。
- 大箱不存在：顯示全域預覽，只顯示大箱。

預覽中的節點全部是唯讀；唯一會改變狀態的操作是 Scrubber／Tick 欄位，且只決定即將建立的小箱起始 Tick。

若 Scene 尚未排定 Tick，角色頁可建立快照但必須要求填入 fallback Tick，並在總覽標示「未排定」。後續為 Scene 建立 placement 後，系統改用 placement 的 Tick，不需重建快照。

### 6.3 新增 Dialog 與角色卡內編輯

Dialog 只負責決定 Scene 與初始來源：

- `綁定 Scene：伏擊事件（Tick 24）`；可更換 Scene 或主要 placement，fallback Tick 僅在未排定時可編輯。
- 初始內容可選空白、目前播放頭、預設或任一 Scene 快照。
- 確認後立即建立快照、切換 ComboBox，並回到角色卡編輯。
- 不在 Dialog 內再建立一套快照專用欄位；所有內容均使用原有 Table 與自訂欄位控制項。
- Table 與自訂欄位儲存為完整狀態，並影響此 Scene 之後的推導結果。

### 6.4 複製快照（包含預設）

複製不是複製原始 patch，而是先解析來源的**完整推導狀態**，再把五組 Table 與自訂欄位寫成目標 Scene 的完整 patch。目標快照可獨立調整，且不與來源共用集合。

| 複製來源 | 目標 | 結果 |
| --- | --- | --- |
| 預設快照 | 新／既有 Scene | 複製 baseline 的完整初始狀態 |
| 任一 Scene 快照 | 新／既有 Scene | 複製來源 Scene 當下完整推導狀態 |
| 目前播放頭推導狀態 | 新 Scene | 以目前看到的完整狀態建立快照 |

複製流程必須讓使用者選擇目標 Scene，並在儲存前顯示「複製後所有欄位會成為該 Scene 的明確值」。不可讓使用者誤以為複製後仍會隨來源快照變動。預設快照的「複製」按鈕可直接開啟新增 Scene 快照流程。

### 6.5 差異與歷史清單

角色頁提供「狀態歷史」清單，以 Tick 分組並按 sequence 排序。選取一筆後：

- 左側顯示該事件 patch，右側顯示套用前／後狀態。
- 顯示其後第一個受影響的狀態（若有），協助理解連鎖影響。
- 可「編輯事件」、「刪除事件」、「前往時間軸」。
- 不提供「直接編輯推導快照」；快照上的編輯按鈕必須建立新事件或指向當 Tick 的既有事件。

## 7. 持久化、遷移與資料完整性

### 7.1 XML 新格式

建議新增 `<Type><Name>CharacterStateBaselines</Name>` 與 `<Type><Name>CharacterStateChanges</Name>`。Baseline 保存可複製的預設狀態；每個 `<Change>` 保存 ID、角色、必要的 Scene UUID、可選主要 placement、fallback Tick、順序、patch 與備註。Patch 的 `clear` 操作需明確序列化，不能靠空文字元素猜測。

概念範例：

```xml
<Type>
  <Name>CharacterStateChanges</Name>
  <Change Id="state-change-uuid" CharacterId="character-uuid"
          SceneId="scene-uuid" SourcePlacementId="placement-uuid"
          FallbackTick="24" Sequence="0">
    <Patch>
      <HealthStatus Operation="set">左肩受傷</HealthStatus>
      <Emotion Operation="set">警戒</Emotion>
      <Possessions Operation="set"><Item>短劍</Item></Possessions>
      <CustomStatus Key="disguise" Operation="clear" />
    </Patch>
    <Note>伏擊後逃入地牢</Note>
  </Change>
</Type>
```

新增 `CharacterStateChangeCodec`；現有 `CharacterStateCodec` 在過渡版只負責讀取舊 `<CharacterStates>`，不可同時把兩種格式重複寫入。

### 7.2 舊 `CharacterState` 遷移規則

| 舊資料情形 | 遷移結果 |
| --- | --- |
| `storyTimePointId` 對到既有 `placementUUID`，且 placement 有 `sceneUUID` | 使用該 `sceneUUID`、placement 與 `startTick`，產生一筆 `set` patch |
| `storyTimePointId` 是可解析整數且能找到該 Tick 的唯一 Scene placement | 綁定該 Scene，將整數存為 fallback Tick |
| `storyTimePointId` 空白 | 轉為預設快照或未排定 Scene 快照，依遷移選擇；產生 `legacy-character-state-no-scene` 警告 |
| 無法對到 Scene 或 placement | 保留原值在遷移備註／相容欄位，建立「待修復」事件並保留可解析 Tick；不可用名稱猜測關聯 |
| 同角色／同 Tick 多筆舊狀態 | 依 XML 出現順序設定 `sequence`，每筆轉為獨立 patch |

載入舊檔時只在記憶體遷移；使用者明確儲存後才寫新格式。遷移警告沿用 `ProjectMigrationWarning`，並在不阻塞開檔的前提下提供可查看清單。

### 7.3 刪除與引用規則

- 刪除角色：提示會刪除的 baseline 與狀態變更數量；確認後以同一專案歷史交易刪除角色與其資料。不可遺留可編輯的孤兒事件。
- 刪除時間軸 placement：不刪除角色變更；若 Scene 還有其他 placement，改選主要 placement，否則改用 fallback Tick 並標示未排定。
- 刪除 Scene：不應靜默刪除角色快照。刪除確認需列出被引用快照數量，讓作者選擇「取消」、「刪除 Scene 與快照」或「保留快照為待修復資料」。
- 編輯／移動 placement：快照的 resolved Tick 會跟隨更新；需讓時間軸與角色頁投影重新計算。
- 載入時：檢查 `characterId`、`sceneUUID`、`sourcePlacementUUID` 是否存在，fallback Tick 是否為合法整數，同角色同 resolved Tick 的 `(sequence, id)` 是否唯一且可排序。
- 修復策略：可安全重編 sequence；不可安全猜測的角色／Scene／來源引用只警告、保留資料，不自動改指其他實體。

## 8. 需要更新的程式位置

| 區域 | 主要檔案 | 更新內容 |
| --- | --- | --- |
| 資料模型 | `lib/models/character_state_change_data.dart`（新增） | baseline、Scene 綁定 `CharacterStateChange`、patch、推導快照與 ID 產生 |
| 舊模型相容 | `lib/models/character_data.dart` | 保留／標示 `CharacterState` 為 legacy；不要再把它當 runtime snapshot |
| 專案資料 | `lib/models/project_data.dart` | 改存 `characterStateBaselines`、`characterStateChanges`，更新空專案預設值 |
| XML | `lib/models/codecs/character_state_change_codec.dart`（新增）、`lib/bin/file.dart` | 新格式讀寫、舊格式讀取和格式優先順序 |
| 專案遷移 | `lib/models/project_migrator.dart` | 將 legacy states 轉 baseline／Scene patch、產生警告、驗證引用完整性 |
| 不可變快照 | `lib/presentation/providers/project_snapshot_utils.dart` | 深層 freeze patch、持有物、自訂 map；確保 undo/redo 不共享可變集合 |
| 狀態 Provider | `lib/presentation/providers/project_state_providers.dart` | baseline 與變更 CRUD、複製快照、不可變更新、角色刪除整合 |
| 快照查詢 | `lib/presentation/providers/character_state_snapshot_providers.dart`（新增） | 依角色／Scene／Tick 的 resolver providers、完整快照總覽、差異與歷史清單 |
| 時間軸 | `lib/presentation/providers/timeline_providers.dart`、`lib/modules/timelineview.dart` | 共用 currentTick、角色篩選、變更 marker、來源導航 |
| 角色 UI | `lib/modules/characterview.dart` | 頂部快照 ComboBox、快速新增／複製、原有 Table 編輯、固定欄位鎖定、所有快照總覽 |
| 專案聚合／還原 | `lib/presentation/providers/editor_coordinator_provider.dart` | 載入、儲存、undo/redo 時帶入新集合 |
| 測試 | `test/character_state_*_test.dart`（新增）及既有 project/timeline 測試 | 見第 10 節 |

模型變更後需重新執行 Freezed code generation，將產生檔納入變更；不可手動維護 `.freezed.dart`。

## 9. 實作順序與交付切分

### Phase A：資料基礎與相容（約 2–3 人日）

1. 新增 baseline、Scene 綁定狀態變更、patch、resolver 模型與序列化 fixture。
2. 將 `ProjectData`、snapshot utils、aggregate provider、歷史還原流程改接 baseline 與新集合。
3. 完成 XML 新舊讀寫、`ProjectMigrator` 遷移與引用驗證。
4. 完成純函式 resolver、同 Tick sequence 與深層不可變測試。

完成條件：不做 UI 也能開啟舊檔、遷移、儲存、重開、undo/redo，並依指定 Scene／Tick 得到穩定狀態。

### Phase B：角色頁快照 MVP（約 2–3 人日）

1. 建立 snapshot providers，接入 `timelineViewProvider.currentTick`、Scene／placement resolver。
2. 在角色頁新增快照操作列、Table 資料來源切換，以及「預設 + 所有 Scene 快照」總覽。
3. 建立快速新增／選擇 Scene、複製預設／快照、新增／編輯／刪除變更對話框與差異視圖。
4. 將操作接至 draft flush、dirty state 與專案歷史。

完成條件：作者可不離開角色頁快速建立 Scene 快照、複製任一快照或預設、預覽所有快照前後結果，並安全還原。

### Phase C：時間軸呈現與導航（約 1–2 人日）

1. 在時間軸 Tick 顯示角色狀態 marker 或清單。
2. 加入角色篩選、marker 詳情與角色頁／來源 placement 導航。
3. 檢查多軌、scope、縮放與未排定項目下的顯示行為。

完成條件：時間軸播放頭、角色狀態與變更來源可雙向定位，且不改寫大綱內容。

### Phase D：品質與效能（約 1–2 人日）

1. 建立大型資料基準與快照正確性回歸測試。
2. 只有在實測需要時，加入記憶體快取。
3. 補齊可及性、空狀態、錯誤提示與遷移警告 UI。

快取 key 應至少包含 `(characterId, atTick, characterStateChangesRevision)`；若 snapshot 會讀固定角色資料，也要包含角色資料 revision。任何變更、刪除、遷移或歷史還原都必須使快取失效。初期純函式線性掃描較容易驗證正確性。

## 10. 測試與驗收清單

### 10.1 單元測試

- [ ] 空事件在 Tick 0、正 Tick、負 Tick 都回傳一致的 baseline 狀態。
- [ ] Scene 的 placement Tick 決定快照順序；未排定 Scene 正確使用 fallback Tick。
- [ ] 早期 Scene 快照會影響所有後續 Tick，晚期快照不影響前面 Tick。
- [ ] 同 Tick 的 `sequence` 決定結果；相同輸入有 deterministic 結果。
- [ ] `null`（不修改）、空集合（清空）、非空集合（替換）三種 Table patch 語意可區分。
- [ ] 五組 Table 與自訂欄位的 immutable copy 不會在歷史快照間共用可變集合。
- [ ] 刪除一筆早期事件後，後續 snapshot 正確回推。
- [ ] placement 移動後，綁定 Scene 的快照會依新 Tick 重排；placement 刪除會安全回退至 fallback Tick。
- [ ] 從 baseline 或任一 Scene 快照複製時，目標 patch 取得來源的完整推導狀態，而非只複製來源 patch。

### 10.2 整合與儲存測試

- [ ] 新 XML round-trip 後，事件 ID、Scene／placement 引用、fallback Tick、順序、五組 Table、自訂欄位型別與值都不遺失。
- [ ] 1.11 的獨立狀態欄位可轉入角色狀態／擁有物品／自訂欄位，舊 baseline 合併回預設角色資料。
- [ ] 舊 `<CharacterStates>` 可載入並轉為新事件；不明 `storyTimePointId` 會產生警告而不崩潰。
- [ ] 專案 load、save、undo、redo、project switch 與歷史 restore 都保存角色狀態變更。
- [ ] 刪除角色時對應變更會在同一 undo 步驟回復。
- [ ] 角色改名、時間軸改名、場景重排不影響 ID 引用。

### 10.3 Widget／使用者流程測試

- [ ] 播放頭改為 Tick 24 時，角色頁狀態卡立即更新且不標記 dirty。
- [ ] 角色頁的快照總覽同時列出預設、已排定和未排定的所有 Scene 快照。
- [ ] 不離開角色頁即可建立最小 Scene 並立即建立綁定快照。
- [ ] 複製預設或 Scene 快照後，可用原有 Table 與自訂欄位調整完整狀態。
- [ ] 在 Scene Tick 24 新增角色狀態列後，Tick 23 不變、Tick 24 及之後更新。
- [ ] Scene 快照中修改 Table／自訂欄位不會改寫 `CharacterEntryData` 的預設內容。
- [ ] UI 清楚顯示正在查看歷史 Tick，並不能誤把變更寫到基本人物卡。
- [ ] 差異面板顯示正確的前後值與來源；來源失效時仍能跳至有效 Tick。
- [ ] 角色篩選下只顯示該角色 marker，不影響既有 timeline placement／大綱資料。

### 10.4 效能目標

以 100 名角色、2,000 個 placement、1,000 筆狀態變更為初期壓力資料：

- 切換單一角色或播放頭時，目標在一般桌面環境維持可感知即時（建議 p95 小於 100 ms）。
- 不因播放頭拖動建立歷史紀錄、寫 XML 或整頁重建全部角色表單。
- 若實測超標，優先針對「單角色、單 Tick」做 selector／memoization，不快取整個專案的所有 Tick 快照。

## 11. 已確定的產品決策

1. 快照欄位固定為五組既有 Table：阻礙、人物關係、組織、角色狀態、擁有物品，另含所有自訂欄位。
2. 每組 Table 與自訂欄位採整份替換語意；空集合代表清空。
3. 「預設」以 `CharacterEntryData` 為唯一權威來源，不另建可編輯 baseline。
4. Scene 快照沿用角色卡原有控制項；其他固定項目停用。
5. 同 Tick 多筆事件依 `sequence`、再依事件 ID 決定穩定順序。
6. 一個 Scene 多 placement 時預設使用最早 placement，並保留來源 placement UUID 與 fallback Tick。

## 12. 最終驗收定義

完成後，作者可在角色設定頁預覽「預設 + 所有 Scene 快照」，一鍵複製預設或任一快照到目標 Scene，也可不離開角色頁快速建立 Scene 與對應快照。每筆一般快照以 Scene 為主錨點，隨該 Scene 在時間軸上的 Tick 排序；Tick 僅作檢視、排序與失效回退。角色名稱、場景名稱與大綱排序改變都不會讓歷史失聯；儲存、重開和 undo/redo 會得到相同結果。整套功能不複製大綱、章節或完整角色資料。
