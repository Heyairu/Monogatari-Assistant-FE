# PalettesView Module（文字調色盤）規劃

## 1. 目標與範圍

`PalettesView` 是讓創作者依視覺情緒收集與查找文字詞條的獨立模組。每個 HSV 色彩格可保存多個 Material `Chip`，例如把「焦灼」放入高飽和、低明度的紅色格，把「空靈」放入低飽和、高明度的格。

本規劃涵蓋固定 HSV 分類、Chip 的新增/編輯/刪除/排序、搜尋、Riverpod 狀態與獨立 JSON 持久化。資料屬於使用者層級的參考字庫，和現有 `GlossaryView` 相同，不隨 `.mnproj` 故事專案切換。

v1 不包含自訂色盤、圖片取色、跨格拖曳、匯入/匯出，或寫入故事專案檔。

## 2. HSV 分類規格

### Hue

Hue 採 HSV 標準的 `0 <= H < 360` 度。從 0 起，每 18 度新增一刻度，最後一格為 342；360 與 0 同色，因此不建立重複格。

| 項目 | 定義 |
| --- | --- |
| 起點 | `0°` |
| 間距 | `18°` |
| 終點 | `342°` |
| 格數 | `20` |
| 清單 | `0, 18, 36, 54, 72, 90, 108, 126, 144, 162, 180, 198, 216, 234, 252, 270, 288, 306, 324, 342` |

以 `List.generate(20, (index) => index * 18)` 產生，避免將色相值散落在多個檔案。

### 彩色色格的 S/V 組合

括號一律解讀為 **`(Saturation%, Value%)`**。目前規格明確定義下列 12 組 preset；其顯示與儲存順序即為表格順序，不再進行去重或重排。

| 順序 | slot preset | S | V | 原始位置 |
| ---: | --- | ---: | ---: | --- |
|  1 | `s100-v20` | 100% |  20% |  1 |
|  2 | `s50-v20`  | 50%  |  20% |  2 |
|  3 | `s50-v50`  | 50%  |  50% |  3 |
|  4 | `s80-v50`  | 80%  |  50% |  4 |
|  5 | `s100-v50` | 100% |  50% |  5 |
|  6 | `s100-v80` | 100% |  80% |  6 |
|  7 | `s100-v100`| 100% | 100% |  7 |
|  8 | `s80-v100` | 80%  | 100% |  8 |
|  9 | `s50-v80`  | 50%  |  80% |  9 |
| 10 | `s50-v100` | 50%  | 100% | 10 |
| 11 | `s20-v80`  | 20%  |  80% | 11 |
| 12 | `s20-v100` | 20%  | 100% | 12 |

彩色色格總數為 `20 × 12 = 240`。

### 灰階

灰色另成一個區段，不隸屬於 Hue。灰階固定使用 `S = 0%`，並以 `H = 360°` 作為 JSON 的 canonical 值（此時 Hue 沒有視覺意義，僅供排序使用）。

| slot ID | H | S | V | 顯示名稱 |
| --- | ---: | ---: | ---: | --- |
| `gray-v000` | 360° | 0% |   0% | 灰階 · V   0% |
| `gray-v020` | 360° | 0% |  20% | 灰階 · V  20% |
| `gray-v050` | 360° | 0% |  50% | 灰階 · V  50% |
| `gray-v080` | 360° | 0% |  80% | 灰階 · V  80% |
| `gray-v100` | 360° | 0% | 100% | 灰階 · V 100% |

v1 合計 `240 + 5 = 245` 個可放置詞條的固定格位。色彩一律由 Flutter 的 `HSVColor.fromAHSV(1, h, s / 100, v / 100).toColor()` 產生；JSON 不儲存可推導的 RGB 或 HEX。

## 3. 畫面與操作

不一次展開 20 × 12 + 1 × 5 的矩陣，否則文字 Chip 沒有足夠寬度。採用「Hue 選擇器 + 當前 Hue 的可折疊區塊」：

```text
┌─────────────────────────────────────────────────────────────────┐
│ 文字調色盤                                      [搜尋詞條……]     │
│ Hue： [0°] [18°] [36°] … [342°]  （每個按鈕顯示對應色票）         │
├────────────────────────────────────────────────────────────────┤
│ H 198°                                                          │
│ ┌─────────────────────────────────────────────────────────┐    │
│ │ S80 · V100 []（顯示對應色票）                         V  │    │
│ │ [天藍色的 ×]                                             │    │
│ └─────────────────────────────────────────────────────────┘    │
│ ┌─────────────────────────────────────────────────────────┐    │
│ │ S100 · V100 []（顯示對應色票）                        >  │    │
│ └─────────────────────────────────────────────────────────┘    │  └────────────────────────────────────────────────────────────────┘
```

- Hue 選擇器用 `Wrap`；窄螢幕可使用水平捲動。每格除色票外都顯示數字，例如 `H 180°`，不只靠顏色表意。
- 選定 Hue 後，以 `GridView.builder` / `SliverGrid` 顯示 12 張 SV 卡。建議 `maxCrossAxisExtent: 280`，使桌面呈 2–4 欄、手機呈 1 欄。
- 灰階使用獨立的 `ExpansionTile` 區段，不隨 Hue 切換。
- 色格卡必顯示 H/S/V、色票、詞條數與 Chip 流；長文字 Chip 可換行，不截斷使用者資料。
- 卡片背景使用 HSV 色的 tonal surface。Chip 的文字、邊框與 delete icon 須依背景亮度選黑/白且達 4.5:1 對比；不可以色彩作為唯一狀態訊號。

| 使用者操作 | 行為 | 資料影響 |
| --- | --- | --- |
| 新增 | 點擊 `+ 新增詞條`，在該格顯示 inline `TextField`；Enter 或確認提交。 | 建立 entry，ID append 至該 slot。 |
| 編輯 | 點擊 Chip 文字，改為 inline `TextField`。 | 更新既有 entry 的 `text`、`updatedAt`。 |
| 刪除 | 點擊 Chip delete icon，顯示含「復原」的 `SnackBar`。 | 先移除 slot reference；SnackBar 結束後刪除不再被參照的 entry。 |
| 排序 | 卡片選單提供「依文字排序」。預設是新增順序。 | 僅重排該 slot 的 entry ID。 |
| 搜尋 | 不分大小寫、去首尾空白，比對所有詞條。 | 不修改資料；結果顯示原本 H/S/V 位置。 |

輸入驗證：`trim()` 後不可空白、上限 80 個 Unicode grapheme clusters；同一 slot 不可有相同的正規化文字（trim + Unicode NFC + case-fold）。不同色格可存相同詞條，因為同一物品可有不同顏色。

載入中顯示 progress/skeleton；資料檔損毀時顯示錯誤與重試，絕不直接以空資料覆寫可能可救援的 JSON。寫入失敗時保留記憶體中的修改並提供重試。

## 4. 模型與 JSON 設計

### 資料模型

沿用 Glossary 的「位置引用 + entry index」概念，而不是將 Chip 文字重複放入每一格。分類本身由固定規則產生，JSON 只需保存有資料的 slot 與詞條；空 slot 省略。

```dart
@unfreezed
class PaletteEntry with _$PaletteEntry {
  factory PaletteEntry({
    required String id,
    required String text,
    required String createdAt, // UTC ISO-8601
    required String updatedAt, // UTC ISO-8601
  }) = _PaletteEntry;
}

class PaletteStateData {
  final Map<String, List<String>> slotEntryIds;
  final Map<String, PaletteEntry> entryIndex;
}
```

建立 immutable `PaletteSlotDefinition`，含 `id`、`kind`、`hue`、`saturation`、`value`、`sortOrder`。`allPaletteSlots` 是 240 個彩色 slot 與 5 個灰階 slot 的唯一來源，供 UI、驗證與序列化共同使用。entry ID 以現有 `uuid` 依賴產生，例如 `palette-entry-<uuid-v4>`。

彩色 key 格式為 `h{HHH}-s{SSS}-v{VVV}`，例：`h018-s050-v100`；灰階 key 為 `gray-v{VVV}`，例：`gray-v020`。百分比固定是整數且補零。

### `Palettes.json` v1

```json
{
  "version": 1,
  "slotEntryIds": {
    "h000-s100-v020": ["palette-entry-90a1"],
    "h000-s050-v080": ["palette-entry-4bf2", "palette-entry-cc81"],
    "gray-v020": ["palette-entry-7d20"]
  },
  "entries": {
    "palette-entry-90a1": {
      "id": "palette-entry-90a1",
      "text": "焦灼",
      "createdAt": "2026-08-08T12:00:00.000Z",
      "updatedAt": "2026-08-08T12:00:00.000Z"
    },
    "palette-entry-4bf2": {
      "id": "palette-entry-4bf2",
      "text": "緋紅",
      "createdAt": "2026-08-08T12:01:00.000Z",
      "updatedAt": "2026-08-08T12:01:00.000Z"
    },
    "palette-entry-cc81": {
      "id": "palette-entry-cc81",
      "text": "溫熱",
      "createdAt": "2026-08-08T12:02:00.000Z",
      "updatedAt": "2026-08-08T12:02:00.000Z"
    },
    "palette-entry-7d20": {
      "id": "palette-entry-7d20",
      "text": "幽暗",
      "createdAt": "2026-08-08T12:03:00.000Z",
      "updatedAt": "2026-08-08T12:03:00.000Z"
    }
  }
}
```

寫入前應：移除空 slot、去除 slot 內重複或不存在的 entry ID、移除未被任何 slot 參照的 entry。這可維持小而一致的 JSON，也不需重複儲存 H/S/V。

### 載入與相容性

1. 讀取 App Support 目錄的 `Data/Palettes.json`。
2. 檔案不存在時，讀取 bundle 的 `assets/jsons/palettes.json`（空白 v1 seed），hydrate 後建立使用者資料檔。
3. 驗證 root、`version`、`slotEntryIds`、`entries` 的型別；只接受 `allPaletteSlots` 中的 key。
4. 忽略未知 slot、無效/重複 reference 與孤立 entry，記錄 `debugPrint` 警告；可安全修復的結果在下次成功儲存時寫回。
5. 未來遇到較新版本不可寫回原檔；遇到較舊版本必須有具名 migration。

H/S/V preset 不應由使用者 JSON 任意修改，否則可能產生 UI 無法呈現的分類並讓預設變更變成破壞性修改。

## 5. 架構與影響檔案

| 檔案 | 工作 |
| --- | --- |
| `dart_edition/lib/models/palette_data.dart` | HSV 常數、slot 定義、`PaletteEntry`、JSON encode/decode/normalizer。 |
| `dart_edition/lib/models/palette_data.freezed.dart` | 由 `build_runner` 產生，不手動編輯。 |
| `dart_edition/lib/data/repositories/palette_repository.dart` | 定義讀寫 abstraction；正式實作使用 App Support 的 `Data/Palettes.json`。 |
| `dart_edition/lib/presentation/providers/palette_state_provider.dart` | `PaletteStateData`、Notifier、mutation 與 debounce persistence。 |
| `dart_edition/lib/modules/palettesview.dart` | 載入、Hue 選擇、搜尋、色格及 Chip UI。 |
| `dart_edition/assets/jsons/palettes.json` | 空白 v1 seed。 |
| `dart_edition/pubspec.yaml` | 註冊新 JSON asset。 |
| `dart_edition/lib/main.dart` | 匯入並建立 `PalettesView`。 |
| `dart_edition/lib/bin/slidebar.dart` | 在「詞語參考」後新增「文字調色盤」（`Icons.palette_outlined`）。 |

Provider 應只暴露 immutable snapshot，view 不直接修改 map/list。建議 API：

```dart
Future<void> hydrateFromStorage(PaletteStateData value);
PaletteMutationResult addEntry({required String slotId, required String text});
bool renameEntry({required String entryId, required String text});
bool removeEntry({required String entryId});
bool restoreEntry(PaletteEntry entry, {required String slotId, required int index});
bool sortSlotByText(String slotId);
Future<void> flushPalettePersistence();
```

Notifier 每次 mutation 建立新 snapshot，排程 240–300 ms debounce；`ref.onDispose` 取消 timer。View 的 inline draft 也做約 300 ms debounce，切換 Hue 或離開 view 前 flush。持久化採 UTF-8 與同目錄 temporary file + atomic rename，降低 app 中斷時毀損 JSON 的機率。

## 6. 導覽整合

目前 `main.dart` 和 `slidebar.dart` 以同一組整數 index 對應。若調色盤放在 Glossary 後面，必須在同一提交中同步完成：

1. Palettes 使用新的 index `10`。
2. Proofreading、Copilot、Settings、About 的 switch case 與 sidebar destination 都順延一格。
3. 將 Palettes 納入 `_ignoredPageTransitionIndexes`；它和 Glossary 一樣不應建立故事專案 history snapshot。
4. 不加入 `_projectBackedPageIndexes`，避免專案切換重設此獨立字庫。

把它放在「詞語參考」後，資訊架構最貼近功能；若要完全避免調整既有 index，才改為附加在 About 後。

## 7. 實作階段與驗收

### Phase 1：資料核心

1. 實作 Hue/SV/灰階定義、245 個 slot key 與測試。
2. 完成 `PaletteEntry`、JSON decoder/encoder、normalizer、seed asset。
3. 完成 notifier 的 hydrate、add、rename、remove、restore、sort、flush。

驗收：正確生成 20 個 Hue、12 組 SV、5 組灰階；JSON round-trip 保留 ID、文字、時間及 slot 順序。

### Phase 2：View

1. 實作 loading/error、Hue picker、SV grid、灰階區、搜尋。
2. 實作 inline 新增/編輯、刪除/復原、排序與驗證。
3. 加上 tooltip、semantics、keyboard focus order 與高對比文字。

驗收：任一 245 格皆可新增、修改、刪除詞條；切換 Hue 不遺失草稿；搜尋可找到彩色與灰階中的詞條。

### Phase 3：整合與品質

1. 接入 asset、側欄、main switch。
2. 撰寫 unit、widget/integration tests；執行 formatter、analyzer 與既有相關測試。
3. 在手機與窄桌面寬度驗證長詞、Grid 與鍵盤操作。

驗收：app 重啟後仍讀取 `Data/Palettes.json`；壞檔不被無聲覆寫；既有 Glossary、Proofreading 與後續導航頁均正確。

## 8. 測試清單

- Hue generator 只含 0–342、共 20 項且每項差 18。
- SV preset 恰有 12 項，順序與規格表一致；`allPaletteSlots` 恰有 245 項且 key 唯一。
- `h000-s100-v020`、`h342-s020-v100`、`gray-v000`、`gray-v100` 存在；灰階 S 均為 0。
- JSON round-trip 保留 slot 順序；空 slot 不寫出；未知 slot、壞 reference、孤立 entry 會被安全移除。
- 空白、過長、同 slot 重複詞條會被拒絕；不同 slot 可保存同文字。
- add/rename/remove/undo/sort 只影響目標資料，debounce 只寫最後 snapshot。
- 首次進入可選 Hue、看到 12 SV 與 5 灰階格；新增 Chip 後重建 provider 仍存在。
- 搜尋可定位詞條、窄寬不 overflow、長 Chip 可換行，且可透過 semantics/鍵盤操作。
- 側欄 index 與 main switch 同步，點擊「文字調色盤」會顯示 `PalettesView`。

## 9. 完成定義

- 側欄可進入「文字調色盤」。
- 分類精確含 20 Hue、12 組 S/V 與 5 組獨立灰階 Value。
- 每格均能以 Chip 新增、編輯、刪除、復原與排序文字詞條，並可搜尋。
- 資料以獨立 `Data/Palettes.json` 持久化，首次由 asset seed 建立。
- 格式錯誤、未知資料、寫檔失敗皆有安全處理；資料不會被靜默遺失。
- 單元、widget/integration、`flutter analyze` 與相關既有測試通過。
