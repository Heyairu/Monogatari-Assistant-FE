# 微型時間軸

`MiniTimeline`（`lib/ui_library/mini_timeline.dart`，亦由 `bin/ui_library.dart` 匯出）是受控元件，可用於快照、書籤或其他 Tick 預覽。`TimelineMiniView`（`lib/presentation/widgets/timeline_mini_view.dart`）直接接收 `TimelinePlacementData`，適合沿用主時間軸資料。

```dart
TimelineMiniView(
  placements: scopedPlacements,
  currentTick: selectedTick,
  markers: [
    MiniTimelineMarker(id: snapshotId, tick: snapshotTick, label: sceneName),
  ],
  onTickChanged: (tick) => setState(() => selectedTick = tick),
  onMarkerTap: (marker) => selectSnapshot(marker.id),
)
```

- 區間採用與 `TimelineView` 相同的 `[startTick, endTick)`；viewport 的 `minTick`、`maxTick` 皆可選取。
- 預設高 120 dp，跟隨明暗主題。圓角條表示區間、圓形游標表示目前 Tick、菱形表示快照或其他標記；區間與標記提供 tooltip 和無障礙描述。
- 未指定邊界時，自動涵蓋區間、標記與目前 Tick，前後各留 1 Tick；可傳入 `minTick`、`maxTick` 固定預覽範圍。範圍外資料不顯示，跨界區間會裁切。
- `TimelineMiniView` 預設每 Tick 48 dp，可透過 `pixelsPerTick` 調整。超出可見寬度時可水平捲動，底部顯示可拖曳的 Scrollbar；`MiniTimeline` 省略 `pixelsPerTick` 時維持自動填滿寬度。
- 依 `trackId` 分軌，同軌重疊區間自動分列；相接的區間可共用一列。列數超過高度時可垂直捲動，右側顯示 Scrollbar。游標停留在節點上可查看名稱與 Tick 範圍。
- 點擊選取整數 Tick；按住指針左右拖曳時即時跟隨指標位移，指針顯示可在刻度間平滑移動，回呼取最近的整數 Tick。指標停止時指針也停止，放開後對齊選定刻度。拖曳期間固定刻度，捲動位移會納入座標換算，接近畫面邊界時才捲動，不會突然置中；在節點區水平拖曳可捲動畫面。聚焦後可用左右鍵步進、Home／End 跳到邊界。畫面閱讀器亦可逐 Tick 調整。
- 省略 `onTickChanged` 即為唯讀預覽；標記仍可透過 `onMarkerTap` 或 `onMarkerGroupTap` 點擊。同 Tick 共用 Tooltip；群組回呼包含所有事件，單筆回呼維持回傳第一筆。播放頭重疊標記時，點擊播放頭也能選取事件。
- `selectedMarkerId` 顯示事件選取外框；`showPlayhead: false` 隱藏指針與 slider 語意，可用於預設資料模式，避免將預設資料誤當成 Tick 0。
- `onTickChanged` 只回傳 Tick，由呼叫端更新 `currentTick`。`TimelineMiniView` 不寫入 provider，快照對話框可維持獨立游標；需要同步主時間軸時可將回呼接到 `timelineViewProvider.notifier.setCurrentTick`。

`SnapshotTimelinePreview`（`lib/presentation/widgets/snapshot_timeline_preview.dart`）提供快照導覽包裝，已接入角色、地點、物品 Class／Instance 與角色圖。事件由 `snapshotTimelineEventsProvider` 投影，狀態仍由原有 resolver 解析。

```dart
SnapshotTimelinePreview(
  subject: (kind: SnapshotSubjectKind.character, id: characterId),
  mode: previewMode,
  onModeChanged: (mode) => setState(() => previewMode = mode),
  autoSelectAtTick: true,
  onEventSelected: (event) => loadSnapshot(event?.sourceId),
)
```

模式與局部 Tick 都由頁面控制。「跟隨時間軸」使用 `Icons.playlist_add_check_rounded`，開啟時跟隨主時間軸，關閉時顯示預設資料；切換需提供 `onModeChanged`。`localTick` 模式需提供 `localTick` 與 `onTickChanged`，角色圖另啟用 `allowLocalMode`。再次按下已開啟的「獨立預覽」會回到預設資料，同步與獨立預覽均關閉。元件提供 Tick 輸入、事件前後導覽、縮放、相關／完整 Scene 範圍與同 Tick 事件選擇。

角色、地點與物品頁面啟用 `autoSelectAtTick`，同步時自動載入目前 Tick 的快照事件，並以 `selectedEventId` 同步標記與編輯目標。同 Tick 保留明確選中的事件，否則優先選取最後一筆自身事件，再選繼承事件。該 Tick 沒有快照時，仍顯示解析後的有效狀態，但禁用編輯；物品 Instance 僅有 Class 繼承事件時亦為唯讀。快照編輯只合併至選中事件的 patch，預設資料維持原值。切換 Tick 或模式時，角色會先保存既有待提交編輯；純粹預覽不會新增或修改資料。

工具列使用單列水平 `SingleChildScrollView`，滑鼠移入工具列時在底部顯示可拖曳的 `Scrollbar`，移出時隱藏。頁面透過 `snapshotActionsBuilder` 在列首提供新增／複製／刪除快照，並以 `VerticalDivider` 分隔導覽控制。builder 接收明確選中的事件；未選中時使用目前預覽狀態作為複製來源。預設資料與 Instance 的 Class 繼承事件不可作為刪除目標。

工具列頂部為 Tick 欄位的浮動標籤保留空間。`hint` 以列首資訊圖示顯示，滑鼠懸停時可讀取說明；啟用 `autoSelectAtTick` 時預設提示目前的編輯／唯讀原因。人物的 Tick 與編輯狀態合併為單行；切回預設資料使用「跟隨時間軸」開關，不另提供編輯預設按鈕。選取事件後，時間軸下方只顯示事件資訊。

角色、地點、物品 Class 與 Instance 均可複製完整快照狀態至選定 Scene。選中同 Tick 的某一事件時，複製來源只解析至該筆變更，避免混入同 Tick 的後續變更；新增快照以遞增 sequence 保持同 Tick 的操作順序。對話框確認前不寫入故事資料或主時間軸游標。

新增與轉移等既有 Scene 操作使用 `SceneSnapshotTimelinePreview`。它僅變更對話框內的游標與 Scene 選取，不回寫主時間軸；空白或重疊範圍保留原綁定，確認後仍使用所選 Scene 的起點與 placement。角色快速新增 Scene 則沿用原有大箱／中箱範圍與 Tick 輸入同步。對話框中的共用預覽設定 `allowLocateMainTimeline: false`。
