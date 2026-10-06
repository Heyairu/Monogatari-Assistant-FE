# Padding 規範

本專案以 **4 dp 為基本單位**：固定 Padding 的每一側皆使用 `4 × n dp`，其中 `n` 為非負整數。Flutter 實作以邏輯像素表示 dp，共用值沿用 `lib/ui_library/spacing.dart` 的 `AppSpacing`。這是專案設計規範。

## 數值階梯

| n | Padding | 共用常數 | 使用情境 |
| --- | --- | --- | --- |
| 0 | 0 dp | `EdgeInsets.zero` | 不需要額外內距、由父容器統一留白 |
| 1 | 4 dp | `AppSpacing.xs` | Chip 上下內距、細小內容留白 |
| 2 | 8 dp | `AppSpacing.sm` | 緊湊元件、圖示按鈕、清單容器 |
| 3 | 12 dp | `AppSpacing.md` | 輸入欄左右內距、表格儲存格、通知 |
| 4 | 16 dp | `AppSpacing.lg` | 窄版頁面、緊湊區塊 |
| 5 | 20 dp | `AppSpacing.space20` | 對話框內容頂部 |
| 6 | 24 dp | `AppSpacing.xl` | 一般區塊、寬版頁面、按鈕左右內距 |
| 8 | 32 dp | `AppSpacing.xxl` | 需要更大留白的容器，須有明確用途 |
| 10 | 40 dp | `AppSpacing.space40` | 對話框與畫面左右邊界 |

優先使用 **4、8、12、16、24、32 dp**。其他 4 的倍數（例如 20、28、40）可用於明確的元件需求；重複使用時應集中到 `AppSpacing`。不得以 5、10、14、18 等值作為新的固定 Padding。

## 元件預設

下表為固定設計內距；輸入欄等元件的實際垂直內距可能依文字行高調整，見後述例外。

| 元件／容器 | 水平 Padding | 垂直 Padding | 既有共用值 |
| --- | --- | --- | --- |
| 一般按鈕 | 24 dp | 8 dp | `buttonPadding` |
| 圖示按鈕 | 8 dp | 8 dp | `iconButtonPadding` |
| 文字輸入／下拉輸入 | 12 dp | 8 dp | `fieldPadding` |
| 表格儲存格 | 12 dp | 12 dp | `cellPadding` |
| 清單容器 | 8 dp | 8 dp | `listPadding` |
| 緊湊卡片／區塊 | 16 dp | 16 dp | `compactSection` |
| 一般卡片／區塊 | 24 dp | 24 dp | `regularSection` |
| 頁面（可用寬度 < 600 dp） | 16 dp | 16 dp | 使用 `compactSection` |
| 頁面（可用寬度 ≥ 600 dp） | 24 dp | 24 dp | 使用 `regularSection` |
| 對話框內容 | 24 dp | 上 20 dp、下 0 dp | `dialogContent` |
| 對話框畫面邊界 | 40 dp | 24 dp | `dialogInset`；此項為外部留白 |

元件尺寸、最小高度與點擊區另依 [元件尺寸規範](COMPONENT_SIZE_GUIDELINES.md)。Padding 不代表元件最終尺寸。

## 配置原則

- **每側獨立遵守 4 dp 單位**：例如左右 12、上下 8 合規，不要求四側相同。
- **同類元件一致**：同一用途與密度的元件使用相同內距，避免各頁面自行微調。
- **由容器負責邊界留白**：頁面先設定外層 Padding；沒有獨立表面的子區塊不重複添加同一層留白。具有獨立表面的卡片仍保留自身內距。
- **區分內距與間距**：Padding 是容器邊界到內容的距離；元件間距用 `SizedBox`、`gap` 等配置，也沿用 4 dp 階梯。不要靠兩個相鄰元件的 Padding 拼出間距。
- **響應式選用階梯**：依可用寬度切換 16／24 等既定值，不以容器寬度百分比計算固定設計內距。
- **保留文字與互動空間**：文字放大時容器可增高或換行，不壓縮 Padding 來維持固定高度。

## 動態內距與例外

`4 × n dp` 適用於自行指定的固定設計值。系統安全區、鍵盤避讓、文字行高與描邊計算得到的內距可為非 4 的倍數，保留其計算結果，避免裁切與對齊偏差。例如 `AppTextField`、`AppDropdownField`、`AppControlChip` 的垂直內距可依文字及控制項高度計算。

使用 `SafeArea` 處理系統避讓；安全區與設計 Padding 相加後的總距離不要求為 4 的倍數。負值不得作為 Padding；視覺位置偏移應在對應的佈局機制處理。

新例外應於元件附近說明計算來源與用途。既有個別頁面的值可逐步整理；本文件不表示所有頁面已完成套用。

## 實作狀態

固定 Padding 已在 UI Library、主要頁面與功能面板改用 `AppSpacing`，原有非 4 倍數的固定內距已調整到鄰近階梯。表單外層使用 `formPadding`（上下 4 dp），小標籤使用 `badgePadding`（左右 8、上下 4 dp）。

一般捲動頁面使用 `AppPageScrollView`，可傳入原有 `ScrollController`；自行管理捲動的頁面可使用 `AppPagePadding` 或 `AppLayoutSpacing.pageForWidth`。上述元件依父層可用寬度，在 600 dp 邊界切換 16／24 dp。

## 輸入框一致性與檢查結果

一般輸入框使用 `AppTextField`、`AppDropdownField`。需要保留原生 `TextField`／`TextFormField`／`DropdownButtonFormField` API 的既有欄位，必須透過 `appFieldDecoration`／`appDropdownFieldDecoration` 設定裝飾。上述函式位於 `lib/ui_library/forms.dart`，同時保留欄位的標籤、提示、錯誤、前後圖示與驗證行為。

- 統一使用 `surfaceContainerLowest` 底色、共用圓角及一般／聚焦／錯誤邊框。明暗主題的原生欄位預設底色也使用相同角色。
- 水平內距 12 dp；垂直內距依文字行高計算，對齊共用控制項的可見框線高度。搜尋圖示區使用共用最小 40 × 40 dp 限制，不再使用原生較大的預設圖示區。
- 一般下拉選取文字與文字輸入使用相同 `bodyLarge` 字級；下拉內距另考慮 Flutter dense 選取區至少 24 dp 的高度。選單列至少 48 dp，與關閉狀態的輸入框高度分開處理。
- 多行欄位保留行數、換行與驗證配置，不以單行控制項高度裁切內容。

| 檢查部位 | 原有問題 | 調整 |
| --- | --- | --- |
| 短語庫搜尋、物品搜尋與詳情、其他一般表單 | 原生欄位與共用欄位使用不同底色、圖示區及高度計算 | 一律接到共用裝飾函式 |
| 物品篩選與其他下拉欄位 | 選取文字字級與一般輸入不同，原生下拉沒有使用共用高度計算 | 統一字級、選單列高度及下拉裝飾 |
| 短語庫工具列 | 按鈕間距 6 dp，搜尋框緊貼工具列 | 按鈕間距 8 dp，工具列與搜尋框間距 12 dp |
| 儲存確認框的核取列 | 0 dp 內距雖符合倍數規則，但文字及核取框貼近列邊界 | 左右內距 12 dp |
| 共用對話框 | 標題與動作區依賴框架預設，標題圖示間距為 10 dp | 標題左右與上方 24 dp；動作區左右及下方 24、上方 8 dp；標題圖示間距 12 dp |

正文編輯器、語法編輯器及時間軸數值步進器保留其專用編輯或複合控制項配置；系統安全區與文字行高計算仍遵循前述動態內距例外。零內距本身是有效數值，審查時仍須確認內容是否有足夠且一致的邊界留白。

## Flutter 實作

優先引用既有語意常數：

```dart
Padding(
  padding: AppSpacing.regularSection,
  child: content,
)
```

需要不同軸向內距時，組合階梯值；涉及文字方向時使用 `EdgeInsetsDirectional`：

```dart
const EdgeInsetsDirectional.symmetric(
  horizontal: AppSpacing.md,
  vertical: AppSpacing.sm,
)
```

檢視新增或調整的介面時，確認固定內距為 4 的倍數、同類元件一致、容器留白沒有意外疊加，且放大文字後內容仍可完整顯示。
