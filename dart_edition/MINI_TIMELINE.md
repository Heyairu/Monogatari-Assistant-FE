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
- 省略 `onTickChanged` 即為唯讀預覽；若有 `onMarkerTap`，仍可點擊標記。同 Tick 的標記共用 tooltip，點擊回傳呼叫端提供的第一筆。
- `onTickChanged` 只回傳 Tick，由呼叫端更新 `currentTick`。`TimelineMiniView` 不寫入 provider，快照對話框可維持獨立游標；需要同步主時間軸時可將回呼接到 `timelineViewProvider.notifier.setCurrentTick`。

角色新增快照對話框已使用 `TimelineMiniView`，保留原本依大箱／中箱切換的範圍與 Tick 輸入同步，並加入既有角色快照標記。
