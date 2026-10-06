# List、ListCard 顯示規範

本規範統一同類資料的清單與清單卡片，沿用本專案的 [尺寸](COMPONENT_SIZE_GUIDELINES.md)、[Padding](PADDING_GUIDELINES.md) 與 16 dp 表面圓角。數值皆為 Flutter 邏輯像素（dp）；這是專案設定，不是 Material 官方尺寸表。

## 元件用途與選擇

| 名稱 | 用途 | 專案實作 |
| --- | --- | --- |
| List | 連續、可掃讀的同類資料，列本身不再包一層卡片 | `ListView` 搭配 `ListTile`，樣式由 `AppTheme.listTileTheme` 提供 |
| ListCard | 每筆資料需要獨立表面、選取、編輯或拖曳 | `AppListCard`；需要拖曳時使用 `DraggableCardNode` |
| List 容器 | 清單標題、區域操作、捲動邊界與空狀態 | `CollectionPanel`；大集合使用 `.builder` |
| 區塊卡片 | 一組內容的標題與整體留白 | `AppSectionCard`，不是每筆資料的 ListCard |

`CardList` 是既有的 Chip 集合與新增輸入元件，保留其用途；它不是本規範的 ListCard。同一集合應採用同一種列呈現，不交錯混用 List 與 ListCard。選單選項、核取／切換列與圖表節點可保留用途所需的專用配置。

## 共同視覺基準

| 項目 | 統一設定 |
| --- | --- |
| List 容器 | `surfaceContainerLowest` 底色、16 dp 圓角、無邊框；清單內距四側 8 dp |
| ListCard | `surfaceContainerLowest` 底色、16 dp 圓角、無邊框、elevation 0、不加 surface tint；外距由集合配置 |
| 區塊表面 | `surfaceContainerLow`，內距 24 dp；避免對清單列重複使用區塊內距 |
| 列內距 | 水平 12 dp、上下至少 8 dp；ListTile 以 `minVerticalPadding` 管理上下留白 |
| 列高度 | 最小 40 dp；文字、多行內容、操作區與使用者字級可增加高度 |
| ListCard 間距 | 8 dp；拖曳列由 `DraggableCardNode` 的底部外距提供，呼叫端不再疊加 |
| Leading 與文字、文字與尾端操作 | 12 dp；純文字列不保留空的 leading 欄位 |
| 主文與輔文 | ListCard 間距 4 dp；ListTile 由原生文字排版處理 |
| 圖示 | 一般 24 dp、資料列操作 20 dp；操作點擊區至少 40 × 40 dp，隨文字縮放增加 |
| 密度 | `VisualDensity.standard`；一般資料列不使用 `dense: true` 或負密度 |

顏色取自 `ColorScheme`，字體取自 `TextTheme`。明暗主題與自訂主題色使用相同幾何配置，避免頁面自行設定灰底、固定字級、陰影或半透明選取底色。

## 內容層級與對齊

每列依閱讀方向排列 **leading → 主文／輔文 → trailing**，文字置於可伸縮區域。一般圖示與尾端操作垂直置中，多行文字保持起始邊對齊。

| 層級 | 樣式 | 內容 |
| --- | --- | --- |
| 主文 | `bodyLarge`、`onSurface` | 名稱或主要識別資訊；ListCard 一般字重 400、選取時 600 |
| 輔文 | `bodyMedium`、`onSurfaceVariant` | 摘要、類型或關聯數，不重複主文 |
| 中繼資料 | `bodySmall` 或 `labelSmall` | 來源、時間、狀態等；需要區分時使用標籤或圖示 |
| 區塊標題 | `titleMedium` | 集合或區塊名稱，不套用到每一列 |

主文預設可換行。需要單行摘要時明確指定 `maxLines` 與 `TextOverflow.ellipsis`，完整內容應可在詳情或 Tooltip 讀取。不可用固定高度、縮小字級或 `FittedBox` 隱藏長文字問題。頁面提供自訂 `Text` 樣式時，僅覆寫必要的語意，例如已完成項目的刪除線。

## 互動與狀態

| 狀態 | 顯示與行為 |
| --- | --- |
| 一般 | List 透明列底色；ListCard 使用一般表面，容器與卡片皆無邊框 |
| Hover／Focus／Pressed | 使用 Material 的 Ink 狀態層與鍵盤焦點；卡片裁切為相同 16 dp 圓角 |
| Selected | `secondaryContainer` 底色與 `onSecondaryContainer` 文字；ListCard 主文字重 600，提供 selected 語意，維持無邊框 |
| Disabled | 停用列的主要點擊回呼；ListCard 預設文字為 `onSurface` 的 38% 透明度；內部操作需各自以 null 回呼停用 |
| Dragging | 原位置以透明度降低標示，拖曳預覽沿用 16 dp 圓角與無邊框；合法放置區依 before／child／after 顯示位置提示 |
| Empty | 保留集合範圍，使用 `AppEmptyState` 的圖示、標題與簡短下一步說明 |
| Loading／Error | 保留集合布局；載入指示或錯誤說明放在內容區，失敗時提供重試操作 |

整列點擊只執行主要動作，例如選取或開啟詳情；編輯、刪除等尾端操作使用獨立按鈕及 Tooltip，不能觸發整列動作。優先使用 `ItemActionBar`，相同集合的操作順序固定，刪除置於最後並使用 error 色。不要將 hover 當成唯一能發現操作的途徑。

來源、類型等資訊使用輔文、圖示或標籤表達，保持一般表面一致；特別底色覆寫僅用於有明確語意的元件例外，不能取代選取或禁用狀態。

OutlineView 的故事線、事件與場景清單容器使用 `surfaceContainerLowest`，與未選取項目背景同色，維持無邊框與 16 dp 圓角；空狀態文字沿用主題色，拖曳目標以主題色疊加於清單底色提示。資料卡片沿用共用表面與選取色。

## 響應式與捲動

- 以列的實際可用寬度判斷布局，包括樹狀縮排後的寬度。`AppListCard` 在可用寬度小於 320 dp 時將 trailing 移到內容下方、尾端對齊，兩區間距 8 dp。
- 更窄的容器或操作很多時，呼叫端應將次要動作收進選單，或讓操作區自行換行；不要提供超過卡片可用寬度的固定 `Row`。
- 樹狀縮排使用閱讀方向的 start 邊；列間距維持 8 dp，縮排不改變卡片內距。容器負責邊界留白，列不再額外加左右外距。
- 避免在同一方向配置無界的巢狀捲動。`CollectionPanel` 的預設高度範圍 192–320 dp；主清單可依所在版面傳入高度與 `ScrollController`。
- 大集合使用 builder，資料列使用穩定的 `ValueKey`；拖曳與重排保留項目身分。

## 實作入口與範例

共用列設定位於 `lib/ui_library/list_style.dart` 的 `AppListStyle`；ListCard 位於 `lib/ui_library/collections.dart`，均透過 `bin/ui_library.dart` 匯出。

```dart
CollectionPanel.builder(
  title: "資料清單",
  itemCount: entries.length,
  itemBuilder: (context, index) => Padding(
    padding: const EdgeInsets.only(bottom: AppListStyle.cardGap),
    child: AppListCard(
      key: ValueKey(entries[index].id),
      title: Text(entries[index].name),
      subtitle: Text(entries[index].summary),
      selected: entries[index].id == selectedId,
      onTap: () => selectEntry(entries[index].id),
      trailing: ItemActionBar.editDelete(
        onEdit: () => editEntry(entries[index].id),
        onDelete: () => deleteEntry(entries[index].id),
      ),
    ),
  ),
)
```

拖曳版本使用 `DraggableCardNode`，省略外層 bottom Padding。

## 套用範圍與驗收

共用主題統一原生 ListTile 的預設值，拖曳清單統一使用 `AppListCard`；角色與詞語清單沿用容器內距，詞條不再疊加卡片間距，物品主清單採用相同卡片與操作圖示。既有頁面的顯式樣式仍會覆寫預設，特殊清單不代表已全部遷移。

變更清單時確認明／暗主題、長文字、320 dp 邊界、窄版、RTL 與放大文字都能閱讀；整列與尾端操作不互相觸發；選取與拖曳仍保有狀態及資料身分。共用行為由 `test/list_display_test.dart` 覆蓋。
