# 角色設定快照（串接時間軸）實作規劃

> 文件目的：定義「角色設定快照」如何以既有時間軸的 Tick 作為故事時間基準，列出需要調整的資料模型、儲存、狀態管理、UI、遷移、測試與分期交付內容。
>
> 盤點基準：`dart_edition/lib/models/character_data.dart`、`dart_edition/lib/models/timeline_data.dart`、`dart_edition/lib/models/codecs/character_state_codec.dart`、`dart_edition/lib/presentation/providers/timeline_providers.dart`、`dart_edition/lib/presentation/providers/project_state_providers.dart`、`dart_edition/lib/presentation/providers/project_snapshot_utils.dart`。
>
> 本文件中的「快照」是指**指定故事時間的角色推導結果**；不可與 undo/redo 所保存的「整份專案歷史快照」混為一談。

## 1. 結論與推薦範圍

推薦將角色快照實作成「角色固定資料 + 依 Tick 排序的狀態變更」所推導出的唯讀結果，而不是在每個時間點複製一份完整角色卡。

```text
CharacterEntryData（固定人物設定）
        +
CharacterStateChange（指定 Tick 的變更事件，依序套用）
        ↓
CharacterStorySnapshot（目前 Tick 的推導結果，僅供檢視／編輯入口）
```

第一版應直接共用時間軸既有的 `TimelineViewState.currentTick`。使用者在時間軸移動播放頭後，角色頁便顯示該 Tick 的狀態；在角色頁寫入變更時，建立一筆錨定於該 Tick 的狀態變更事件。

### 1.1 為何不儲存完整角色複本

- 固定設定（姓名、核心個性、外觀、長期目標）不會因為故事推進而重複儲存。
- 修改早期事件後，後面 Tick 的狀態可自然重算，不會留下多份過期副本。
- 專案 XML、歷史紀錄與同步時只傳遞差異事件，資料量和衝突面較小。
- 快照不可被誤認為一名新角色或一份可獨立儲存的角色設定。

### 1.2 第一版可交付功能

1. 在時間軸以目前 Tick 檢視角色的所在地、健康／生死、情緒、陣營、持有物、自訂狀態與補充說明。
2. 從角色頁在目前 Tick 建立狀態變更；歷史 Tick 的編輯會新增或編輯「變更事件」，不會覆寫角色基本資料。
3. 顯示「本 Tick 相較前一個狀態」的欄位差異、變更原因／備註，以及可跳回來源時間軸位置的連結。
4. 變更事件可編輯、刪除、還原；所有操作納入既有專案 undo/redo、dirty state、自動儲存與 XML round-trip。
5. 在時間軸選取角色後，只顯示與該角色有關的狀態變更標記或清單（第一版不強制做複雜的圖形覆蓋層）。

### 1.3 不納入 MVP 的項目

- 每個 Tick 自動建立完整快照檔。
- 依真實日期、虛構曆法或自然語言日期推導狀態；MVP 一律以整數 Tick 排序。
- 關係圖的時間狀態、能力值曲線、角色服裝圖像版本、多使用者同步衝突處理。
- 自動從正文或 AI 推論狀態變化；只能先產生草稿建議，不能自動寫入。

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
- 沒有來源、備註、建立時間或自訂狀態欄位。
- `CharacterStatesNotifier` 目前只有整批覆寫方法，沒有新增、更新、刪除單筆變更的交易 API。
- 角色頁尚未以時間游標顯示／編輯狀態；時間軸也尚未投影角色變更。

因此，現有 `CharacterState` 可作為**舊格式相容模型**，但不應直接擴充成最終快照模型。

## 3. 核心行為與資料規則

### 3.1 時間錨定規則（MVP 採固定 Tick）

每個變更事件必須保存 `effectiveTick`，這是唯一的排序與推導權威。若使用者從某個時間軸箱體建立變更，可額外保存 `sourcePlacementUUID` 作為導航來源，但不得以它取代 Tick。

```text
時間軸 placement 移動：角色歷史不自動位移
來源 placement 改名：快照歷史不受影響
來源 placement 刪除：保留 effectiveTick；移除或標示來源連結
```

這個選擇可避免「重新排列時間軸」在未確認下改寫大量角色歷史。若未來確實需要「狀態跟著事件移動」，再新增明確的 `anchorMode = placementStart` 與位移預覽；不可默默改變 MVP 的固定 Tick 語意。

### 3.2 排序與衝突規則

同一角色在目標 Tick `T` 的推導程序：

1. 取角色的預設故事狀態（所有欄位空白／未設定）。
2. 選出 `effectiveTick <= T` 的變更事件。
3. 依 `(effectiveTick, sequence, stateChangeId)` 升冪排序。
4. 逐筆套用 patch，最後結果即為 `CharacterStorySnapshot`。

`sequence` 僅用於同一 Tick 的明確順序；新增同 Tick 事件時預設為該 Tick 最大 sequence + 1。拖曳改序時必須重新編號為連續整數，且是單一 undoable 交易。`stateChangeId` 只作最後的 deterministic tie-break，不可期待 UUID 的字典序具業務語意。

不同角色在同 Tick 的變更互不覆蓋。關係變化屬於另一個未來模型，不應塞進角色個人狀態。

### 3.3 Patch 必須能分辨「不修改」與「清空」

不可使用單純 `String` 欄位直接當差異，否則空字串不具語意。建議每個可變欄位使用顯式操作：

```dart
enum StateFieldOperation { set, clear }

@freezed
class StateFieldPatch<T> with _$StateFieldPatch<T> {
  const factory StateFieldPatch.set(T value) = StateFieldSet<T>;
  const factory StateFieldPatch.clear() = StateFieldClear<T>;
}
```

在 `CharacterStatePatch` 中，`null` 代表「本事件沒有碰這個欄位」；`StateFieldPatch.clear()` 才代表清空。持有物第一版以整份清單 `set / clear` 為主，避免「新增／移除」在修改早期歷史後產生難以理解的順序問題；若需求成熟，再加 `add/remove` 操作。

### 3.4 固定設定與故事狀態的邊界

| 資料類型 | 權威位置 | 快照是否覆寫 |
| --- | --- | --- |
| `displayName`、別名、角色類型、固定出生資料 | `CharacterEntryData` | 否 |
| 長期性格、核心動機、目標、背景備註 | `CharacterEntryData` | MVP 否 |
| 所在地、健康／生死、情緒、所屬陣營、持有物 | `CharacterStateChange` | 是 |
| 故事進程自訂狀態，例如「右臂受傷」「偽裝身分」 | `CharacterStateChange.customStatus` | 是 |
| 作者備註、設計筆記 | 角色資料或變更事件的 `note` | 不作自動推導 |

現有 `statusEntries` 需在實作前明確定位：已有內容應保留在角色設定中；新增的隨劇情狀態則寫入快照事件，避免同一資訊有兩個權威來源。

## 4. 建議資料模型

### 4.1 持久化模型

建議新增 `dart_edition/lib/models/character_state_change_data.dart`，並以 Freezed 產生不可變模型。

```dart
@freezed
class CharacterStatePatch with _$CharacterStatePatch {
  const factory CharacterStatePatch({
    StateFieldPatch<String>? location,
    StateFieldPatch<String>? healthStatus,
    StateFieldPatch<String>? emotion,
    StateFieldPatch<String>? alignment,
    StateFieldPatch<List<String>>? possessions,
    @Default(<String, StateFieldPatch<String>>{})
    Map<String, StateFieldPatch<String>> customStatus,
  }) = _CharacterStatePatch;
}

@freezed
class CharacterStateChange with _$CharacterStateChange {
  const factory CharacterStateChange({
    required String stateChangeId,
    required String characterId,
    required int effectiveTick,
    @Default(0) int sequence,
    String? sourcePlacementUUID,
    @Default(CharacterStatePatch()) CharacterStatePatch patch,
    @Default("") String note,
  }) = _CharacterStateChange;
}

@freezed
class CharacterStorySnapshot with _$CharacterStorySnapshot {
  const factory CharacterStorySnapshot({
    required String characterId,
    required int effectiveTick,
    @Default("") String location,
    @Default("") String healthStatus,
    @Default("") String emotion,
    @Default("") String alignment,
    @Default(<String>[]) List<String> possessions,
    @Default(<String, String>{}) Map<String, String> customStatus,
    @Default(<String>[]) List<String> appliedStateChangeIds,
  }) = _CharacterStorySnapshot;
}
```

`CharacterStorySnapshot` 是衍生資料，不寫入 XML／`ProjectData`；其 `appliedStateChangeIds` 只供差異面板與追溯來源使用。實作上也可先不用 Freezed，只要確保輸出 immutable。

### 4.2 `ProjectData` 與 Provider 更新

將 `ProjectData.characterStates` 替換為或過渡為：

```dart
List<CharacterStateChange> characterStateChanges;
```

建議保留 `CharacterState` 和 `characterStates` 僅作 codec 遷移的內部相容資料，完成一版格式升級後再移除。若過渡期同時存在兩個集合，必須規定只有 `characterStateChanges` 可編輯與寫回，舊集合只讀取一次後轉換；不可讓兩者都成為可寫資料來源。

`CharacterStatesNotifier` 應改名為 `CharacterStateChangesNotifier`，最少提供：

- `setChanges(List<CharacterStateChange>)`
- `addChange(CharacterStateChange)`：正規化 ID、Tick 與同 Tick sequence。
- `updateChange(String id, CharacterStateChange Function(...))`
- `deleteChange(String id)`
- `reorderAtTick({characterId, effectiveTick, orderedIds})`
- `deleteForCharacter(String characterId)`：只能由角色刪除確認流程呼叫。

所有寫入都需輸出不可變 list，觸發既有 dirty／project aggregate provider，並在 UI 草稿 flush 後記錄為單一歷史節點。

### 4.3 純函式／Use case

新增 `character_state_snapshot_resolver.dart`，不要把推導邏輯放在 Widget 或 notifier。最少需要：

```dart
CharacterStorySnapshot resolveCharacterSnapshot({
  required CharacterEntryData character,
  required Iterable<CharacterStateChange> changes,
  required int atTick,
});

CharacterStateSnapshotDiff diffSnapshots(
  CharacterStorySnapshot previous,
  CharacterStorySnapshot current,
);

List<CharacterStateChange> orderedChangesForCharacter(...);
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
```

角色頁應 watch `currentCharacterSnapshotProvider(characterId)`；時間軸面板可 watch `characterStateChangesAtTickProvider(currentTick)`。若日後角色頁需要獨立預覽不同時間，另加本地 preview tick，不能偷偷覆蓋全域播放頭。

### 5.2 從時間軸建立與導覽

| 使用者操作 | 系統行為 |
| --- | --- |
| 播放頭移到 Tick 24 | 所有角色狀態卡重算為 Tick 24 |
| 點選角色後「在此時間新增狀態」 | 建立 `effectiveTick: 24` 的變更草稿 |
| 從某小箱建立狀態 | `effectiveTick` 為小箱 `startTick`；可填入 `sourcePlacementUUID` |
| 點選狀態事件的來源 | 若 source placement 尚存在，選取並捲動時間軸到該箱；否則定位其 `effectiveTick` |
| 拖動時間軸播放頭 | 只改 UI state，不建立歷史紀錄、不標記 dirty |
| 移動來源小箱 | MVP 只移動箱體，不改角色狀態的 `effectiveTick` |

第一版不要求每筆變更都是時間軸中的獨立可拖曳箱。先在 Tick 對應位置以小型 marker／側欄清單呈現即可；這能避開變更事件和大綱場景 placement 的雙重布局與重疊規則。

### 5.3 角色篩選與可讀性

- 時間軸工具列增加「角色」篩選器，依 `characterId` 選擇、以 `displayName` 顯示；不可用名稱當儲存 key。
- 角色篩選啟用時，保留原本大綱 placement，並額外顯示該角色的狀態 marker；不要複製場景資料。
- 若場景的 `people` 欄位尚有舊名稱字串，只作顯示／建議，不能用它自動建立角色狀態。
- marker 預設顯示事件數；同 Tick 多筆變更可開啟清單並顯示 sequence。

## 6. UI 與操作流程

### 6.1 角色設定頁新增「故事狀態」區

放在固定角色設定之後，清楚與基本設定區隔：

```text
故事狀態（時間軸：Tick 24）                    [跳至時間軸] [回到最新]
所在地：王城地牢          健康：左肩受傷           情緒：警戒
陣營：王國                持有物：短劍、地圖
自訂狀態：偽裝身分＝失效

本時間點變更：健康、情緒、持有物                [檢視差異] [新增／編輯]
最後變更來源：伏擊事件（Tick 24）                [前往]
```

顯示「時間軸：Tick N」而不是「目前狀態」，避免使用者誤以為正在改固定人物資料。`回到最新` 應將游標移到所有時間軸 placement 與該角色變更中的最大 Tick；若專案沒有任何時間資料，回到 Tick 0。

### 6.2 新增／編輯變更對話框

對話框必須顯示錨定時間與會影響的範圍：

- `有效時間：Tick 24`；可選擇「使用目前播放頭」或輸入其他 Tick。
- 同 Tick 已有事件時，選擇「新增於最後」或選取既有事件編輯；不要默默覆寫。
- 每欄位有「維持不變／設定值／清空」語意。UI 可用未勾選、輸入值、清除按鈕表達，但送出時必須映射成顯式 patch。
- 持有物以完整清單編輯；儲存時顯示是「替換」而非增量。
- 提供備註與可選來源時間軸項目。
- 儲存前顯示「會影響 Tick 24 以後的角色狀態」提示；不需要阻擋，但應讓作者理解回溯效果。

### 6.3 差異與歷史清單

角色頁提供「狀態歷史」清單，以 Tick 分組並按 sequence 排序。選取一筆後：

- 左側顯示該事件 patch，右側顯示套用前／後狀態。
- 顯示其後第一個受影響的狀態（若有），協助理解連鎖影響。
- 可「編輯事件」、「刪除事件」、「前往時間軸」。
- 不提供「直接編輯推導快照」；快照上的編輯按鈕必須建立新事件或指向當 Tick 的既有事件。

## 7. 持久化、遷移與資料完整性

### 7.1 XML 新格式

建議新增 `<Type><Name>CharacterStateChanges</Name>`，並在每個 `<Change>` 中保存 ID、角色、Tick、順序、可選 source placement、patch 與備註。Patch 的 `clear` 操作需明確序列化，不能靠空文字元素猜測。

概念範例：

```xml
<Type>
  <Name>CharacterStateChanges</Name>
  <Change Id="state-change-uuid" CharacterId="character-uuid"
          EffectiveTick="24" Sequence="0" SourcePlacementId="scene-uuid">
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
| 有可解析的整數 `storyTimePointId` | 轉為對應 `effectiveTick`，產生一筆 `set` patch |
| `storyTimePointId` 對到既有 `placementUUID` | 使用該 placement 的 `startTick`，並填 `sourcePlacementUUID` |
| `storyTimePointId` 空白 | 轉為 Tick 0，產生 `legacy-character-state-no-time` 警告 |
| 無法對到 Tick 或 placement | 保留原值在遷移備註／相容欄位，預設 Tick 0，產生警告；不可用名稱猜測關聯 |
| 同角色／同 Tick 多筆舊狀態 | 依 XML 出現順序設定 `sequence`，每筆轉為獨立 patch |

載入舊檔時只在記憶體遷移；使用者明確儲存後才寫新格式。遷移警告沿用 `ProjectMigrationWarning`，並在不阻塞開檔的前提下提供可查看清單。

### 7.3 刪除與引用規則

- 刪除角色：提示會刪除的狀態變更數量；確認後以同一專案歷史交易刪除角色與其變更。不可遺留可編輯的孤兒事件。
- 刪除時間軸 placement：不刪除角色變更，因為 `effectiveTick` 是權威；清空相同的 `sourcePlacementUUID` 或保留為已失效連結並顯示警告，二者需擇一。推薦前者，避免永久 dangling reference。
- 編輯／移動 placement：不可修改角色變更的 Tick。
- 載入時：檢查 `characterId` 是否存在、`sourcePlacementUUID` 是否存在、Tick 是否為合法整數、同角色同 Tick 的 `(sequence, id)` 是否唯一且可排序。
- 修復策略：可安全重編 sequence；不可安全猜測的角色／來源引用只警告、保留資料，不自動改指其他角色。

## 8. 需要更新的程式位置

| 區域 | 主要檔案 | 更新內容 |
| --- | --- | --- |
| 資料模型 | `lib/models/character_state_change_data.dart`（新增） | `CharacterStateChange`、patch、推導快照與 ID 產生 |
| 舊模型相容 | `lib/models/character_data.dart` | 保留／標示 `CharacterState` 為 legacy；不要再把它當 runtime snapshot |
| 專案資料 | `lib/models/project_data.dart` | 改存 `characterStateChanges`，更新空專案預設值 |
| XML | `lib/models/codecs/character_state_change_codec.dart`（新增）、`lib/bin/file.dart` | 新格式讀寫、舊格式讀取和格式優先順序 |
| 專案遷移 | `lib/models/project_migrator.dart` | 將 legacy states 轉 patch、產生警告、驗證引用完整性 |
| 不可變快照 | `lib/presentation/providers/project_snapshot_utils.dart` | 深層 freeze patch、持有物、自訂 map；確保 undo/redo 不共享可變集合 |
| 狀態 Provider | `lib/presentation/providers/project_state_providers.dart` | 新 notifier CRUD、不可變更新、角色刪除整合 |
| 快照查詢 | `lib/presentation/providers/character_state_snapshot_providers.dart`（新增） | 依角色／Tick 的 resolver providers、差異與歷史清單 |
| 時間軸 | `lib/presentation/providers/timeline_providers.dart`、`lib/modules/timelineview.dart` | 共用 currentTick、角色篩選、變更 marker、來源導航 |
| 角色 UI | `lib/modules/characterview.dart` | 故事狀態卡、變更對話框、歷史與差異面板、時間游標提示 |
| 專案聚合／還原 | `lib/presentation/providers/editor_coordinator_provider.dart` | 載入、儲存、undo/redo 時帶入新集合 |
| 測試 | `test/character_state_*_test.dart`（新增）及既有 project/timeline 測試 | 見第 10 節 |

模型變更後需重新執行 Freezed code generation，將產生檔納入變更；不可手動維護 `.freezed.dart`。

## 9. 實作順序與交付切分

### Phase A：資料基礎與相容（約 2–3 人日）

1. 新增狀態變更、patch、resolver 模型與序列化 fixture。
2. 將 `ProjectData`、snapshot utils、aggregate provider、歷史還原流程改接新集合。
3. 完成 XML 新舊讀寫、`ProjectMigrator` 遷移與引用驗證。
4. 完成純函式 resolver、同 Tick sequence 與深層不可變測試。

完成條件：不做 UI 也能開啟舊檔、遷移、儲存、重開、undo/redo，並於指定 Tick 得到穩定狀態。

### Phase B：角色頁快照 MVP（約 2–3 人日）

1. 建立 snapshot providers，接入 `timelineViewProvider.currentTick`。
2. 在角色頁新增唯讀故事狀態卡、時間提示與回到最新操作。
3. 建立新增／編輯／刪除變更對話框與差異視圖。
4. 將操作接至 draft flush、dirty state 與專案歷史。

完成條件：作者可在任意 Tick 建立變更、跳看前後結果，並安全還原。

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

- [ ] 空事件在 Tick 0、正 Tick、負 Tick 都回傳一致預設狀態。
- [ ] 早期事件會影響所有後續 Tick，晚期事件不影響前面 Tick。
- [ ] 同 Tick 的 `sequence` 決定結果；相同輸入有 deterministic 結果。
- [ ] `set`、`clear`、未修改三種 patch 語意可區分。
- [ ] 自訂狀態與持有物的 immutable copy 不會在歷史快照間共用可變集合。
- [ ] 刪除一筆早期事件後，後續 snapshot 正確回推。
- [ ] placement 移動不改變固定 Tick 快照；placement 刪除不會刪除狀態歷史。

### 10.2 整合與儲存測試

- [ ] 新 XML round-trip 後，事件 ID、Tick、順序、clear 操作、備註、自訂狀態都不遺失。
- [ ] 舊 `<CharacterStates>` 可載入並轉為新事件；不明 `storyTimePointId` 會產生警告而不崩潰。
- [ ] 專案 load、save、undo、redo、project switch 與歷史 restore 都保存角色狀態變更。
- [ ] 刪除角色時對應變更會在同一 undo 步驟回復。
- [ ] 角色改名、時間軸改名、場景重排不影響 ID 引用。

### 10.3 Widget／使用者流程測試

- [ ] 播放頭改為 Tick 24 時，角色頁狀態卡立即更新且不標記 dirty。
- [ ] 在 Tick 24 新增健康狀態後，Tick 23 不變、Tick 24 及之後更新。
- [ ] UI 清楚顯示正在查看歷史 Tick，並不能誤把變更寫到基本人物卡。
- [ ] 差異面板顯示正確的前後值與來源；來源失效時仍能跳至有效 Tick。
- [ ] 角色篩選下只顯示該角色 marker，不影響既有 timeline placement／大綱資料。

### 10.4 效能目標

以 100 名角色、2,000 個 placement、1,000 筆狀態變更為初期壓力資料：

- 切換單一角色或播放頭時，目標在一般桌面環境維持可感知即時（建議 p95 小於 100 ms）。
- 不因播放頭拖動建立歷史紀錄、寫 XML 或整頁重建全部角色表單。
- 若實測超標，優先針對「單角色、單 Tick」做 selector／memoization，不快取整個專案的所有 Tick 快照。

## 11. 開發前需確認的產品決策

以下決策不會阻礙 Phase A 的核心模型，但應在做 UI 前確認：

1. 第一版狀態欄位是否固定為所在地、健康、情緒、陣營、持有物、自訂狀態、備註。
2. `持有物` 是否接受第一版「整份替換」語意；若需要增減明細，需另定 add/remove/quantity 的事件規則。
3. 同 Tick 多筆事件的順序要以手動排序、建立順序，或兩者都支援。推薦先採建立順序 + 手動調整。
4. 來源 placement 刪除時，採「自動清除來源連結」或「保留失效連結供稽核」。推薦自動清除並保留 `effectiveTick`。
5. 未來是否需要「狀態隨 placement 移動」的進階錨定模式。若有，必須提供受影響事件預覽與單一 undo，不能改變固定 Tick 的預設行為。

## 12. 最終驗收定義

完成後，作者可在時間軸任意 Tick 查看某角色當時的狀態，建立可追溯的變更事件，並在修改早期劇情後自動看到後續快照重算。角色名稱、場景名稱與大綱排序改變都不會讓歷史失聯；儲存、重開和 undo/redo 會得到相同結果。整套功能以時間軸 Tick 為共同語言，但不複製大綱、章節或完整角色資料。
