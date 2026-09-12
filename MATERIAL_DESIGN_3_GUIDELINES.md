# Material Design 3 設計規範（非 Expressive）

整理日期：2026-09-12｜語言：繁體中文｜用途：介面設計、開發與設計審查

> 本文件採用原版 Material Design 3（M3／Material You）的設計基礎，明確排除 Material 3 Expressive（M3E）。這是實務摘要，不是官方規範的逐頁翻譯，也不涵蓋每個元件的全部尺寸與狀態 token。

## 1. 版本範圍與判定原則

官方目前把 Expressive 視為 M3 的擴充，而不是獨立的「Material 4」。因此僅憑文件標題包含 M3，不能判定它是原版。現行官網與 SDK 文件也可能同時收錄兩者。[官方版本說明](https://developer.android.com/develop/ui/compose/designsystems/material3)

本文件的基礎數值優先採用 Google Material Web 中標示 **Google Material 3、design system version v0.192** 的版本化 token。這是設計 token 的版本，不是要求專案安裝 Material Web，也不代表所有平台實作完全一致。連結位於官方儲存庫的 `main` 分支，並非不可變的歷史快照。

| 項目 | 本文件採用 | 本文件排除 |
| --- | --- | --- |
| 色彩 | 語意色彩角色、明暗主題、可選的動態配色 | 為追求 Expressive 展示風格而重新配置整體視覺 |
| 字體 | 原版 15 級 type scale | Expressive 新增的 emphasized 字級系統與互動字形變化 |
| 形狀 | 原版圓角階梯；本專案以圓角矩形與圓形覆寫 Full | Expressive 的擴充形狀集合、膠囊形與裝飾性形狀變換 |
| 動畫 | 原版 duration／easing token 與有意義的轉場 | Expressive motion physics 作為全站預設、強烈彈跳與形變 |
| 元件 | 原版按鈕、FAB、chips、導覽、輸入與回饋元件 | Expressive button groups、FAB menu、形狀變換 loading indicator，以及 Expressive 元件變體 |
| 進度顯示 | 傳統直線與圓形進度指示 | 波浪式進度外觀作為預設 |

**膠囊按鈕、大圓角、動態配色、色調表面與選取指示背景都不是 M3E 專屬。** 不過，本專案基於視覺偏好，會把膠囊形元件改為圓角矩形或具有明確幾何意義的圓形元件。這是專案覆寫，不是原版 M3 的要求。品牌色鮮明也不等於使用 M3E；本專案採取克制風格同樣屬於產品選擇。

Expressive 邊界參考：[官方更新介紹](https://m3.material.io/blog/building-with-m3-expressive)。

## 2. 規範層級與單位

本文件用以下方式區別要求：

- **基礎預設**：原版 M3 的 token 或元件基準，可作為設計起點。
- **使用原則**：元件的語意、層級與互動方式。
- **專案建議**：為繁體中文、桌面工具與非 Expressive 偏好提出的落地選擇，不冒充官方強制規則。

尺寸使用密度無關單位 `dp`；字級以 `sp` 表達。Web token 的 `px` 是 CSS 邏輯像素，不能直接當作螢幕實體像素。字級表的 Web 換算以根字級 16px 為基準；實作時須保留使用者縮放能力。

## 3. 設計 token 與一致性

以「參考值 → 語意角色 → 元件用途」組織設計值。例如品牌色衍生出 `primary`，按鈕再引用 `primary` 與 `onPrimary`，而不是每個按鈕各自填入 HEX。

| 系統 | 應集中管理的內容 |
| --- | --- |
| Color | 品牌色、表面、前景、描邊、錯誤與明暗主題 |
| Typography | 字型、字級、字重、行高、字距 |
| Shape | 容器圓角與元件形狀 |
| Elevation | 表面層級、陰影 |
| State | hover、focus、pressed、dragged、disabled |
| Motion | 時長、緩動、轉場行為 |

同一語意與元件在不同頁面應有一致的視覺及互動。個別差異應透過集中定義的變體管理。[官方主題系統](https://developer.android.com/develop/ui/compose/designsystems/material3)

## 4. 色彩 Color

### 4.1 語意角色

| 角色 | 用途 |
| --- | --- |
| `primary`／`onPrimary` | 高強調操作及其文字、圖示 |
| `primaryContainer`／`onPrimaryContainer` | 主色系容器及容器前景 |
| `secondary`／`onSecondary` | 次要強調及其前景 |
| `secondaryContainer`／`onSecondaryContainer` | 次色系容器，例如部分選取狀態 |
| `tertiary`／`onTertiary` | 補充強調色及其前景 |
| `tertiaryContainer`／`onTertiaryContainer` | 第三色系容器及前景 |
| `surface`／`onSurface` | 一般表面與主要內容 |
| `onSurfaceVariant` | 次要文字或圖示，仍須確保可讀性 |
| `surfaceContainerLowest` 至 `surfaceContainerHighest` | 五級表面容器色：Lowest、Low、一般、High、Highest |
| `surfaceDim`／`surfaceBright` | 較暗／較亮的表面角色 |
| `outline`／`outlineVariant` | 較明確的邊界／較低強調的分隔 |
| `error`／`onError` | 錯誤強調與前景 |
| `errorContainer`／`onErrorContainer` | 錯誤容器與前景 |
| `inverseSurface`／`inverseOnSurface`／`inversePrimary` | 反相表面、文字及強調色 |
| `shadow`／`scrim` | 陰影／模態遮罩 |

配色時將容器與對應的 `on…` 角色成對使用；不假設白字適合每一種品牌色。一般文字優先採用完整的語意色，而不是到處以透明度製造深淺。

`surfaceContainer…` 與 fixed color roles 是 Expressive 前已存在的 M3 色彩演進，不應一律視為 M3E。舊文件中的 `background`、`onBackground`、`surfaceVariant` 可能在新 SDK 中被替代或棄用；應保留語意，依使用版本映射。Fixed 系列可用於希望明暗主題維持相同色調的區域，不是必要選項。[官方 Color 角色與表面更新](https://github.com/material-components/material-components-android/blob/master/docs/theming/Color.md)

### 4.2 明暗主題與動態色

- 分別建立 light／dark 色彩方案，不能只把背景變黑或反轉所有顏色。
- 品牌種子色可用來產生色彩方案；產出的 `primary` 不必與種子色 HEX 相同。
- 動態配色是可選的個人化能力；固定品牌配色也能符合 M3。
- 圖表、狀態、分類等自訂顏色應另建語意角色，並在兩種主題下驗證。

來源：[官方 M3 配色與動態色](https://developer.android.com/develop/ui/compose/designsystems/material3)。

## 5. 字體 Typography

### 5.1 原版 15 級基礎字級

以下為原版基準，字重 400 表示 Regular，500 表示 Medium。字距是絕對邏輯值，不是百分比。

| Token | 字級 | 行高 | 字重 | 字距 |
| --- | ---: | ---: | ---: | ---: |
| `displayLarge` | 57 | 64 | 400 | -0.25 |
| `displayMedium` | 45 | 52 | 400 | 0 |
| `displaySmall` | 36 | 44 | 400 | 0 |
| `headlineLarge` | 32 | 40 | 400 | 0 |
| `headlineMedium` | 28 | 36 | 400 | 0 |
| `headlineSmall` | 24 | 32 | 400 | 0 |
| `titleLarge` | 22 | 28 | 400 | 0 |
| `titleMedium` | 16 | 24 | 500 | 0.15 |
| `titleSmall` | 14 | 20 | 500 | 0.1 |
| `bodyLarge` | 16 | 24 | 400 | 0.5 |
| `bodyMedium` | 14 | 20 | 400 | 0.25 |
| `bodySmall` | 12 | 16 | 400 | 0.4 |
| `labelLarge` | 14 | 20 | 500 | 0.1 |
| `labelMedium` | 12 | 16 | 500 | 0.5 |
| `labelSmall` | 11 | 16 | 500 | 0.5 |

數值來源：[Google Material 3 v0.192 Typography tokens](https://raw.githubusercontent.com/material-components/material-web/main/tokens/versions/v0_192/_md-sys-typescale.scss)。本表的 `titleLarge` 使用原版 token 的 Regular，不採現行 Compose 文件中已更新的 Medium。

### 5.2 使用原則與中文調整

- Display 適合少量大型展示文字；Headline 適合頁面或區塊標題；Title 適合元件標題；Body 用於內文；Label 用於操作與短標示。
- 不必在一個產品中用完 15 級，但應保留清楚的語意映射。
- **專案建議**：繁體中文採用具有完整中文字形的字型，例如 Noto Sans TC 或平台字型回退；不要把 Roboto 當成完整繁中字型。
- **專案建議**：中文段落可從 0 字距開始調整，依混排、行高與閱讀密度驗證；這屬於本地化覆寫。
- 長文、編輯器與重要提示不宜一律套用最小 Label；文字縮放後不得被固定高度裁切。

## 6. 形狀 Shape

| 原版 token | 圓角半徑 |
| --- | ---: |
| None | 0dp |
| Extra small | 4dp |
| Small | 8dp |
| Medium | 12dp |
| Large | 16dp |
| Extra large | 28dp |
| Full | 完整圓形或膠囊形，依容器尺寸決定 |

部分元件僅套用上方或側邊圓角。Full 在 Web 可用足夠大的 radius 實現，不表示元件必須具有固定的巨大半徑。上述值是官方原版階梯，不是本專案必須逐項採用的形狀清單，也不是所有容器都用 28dp 的要求。[官方 Shape tokens](https://raw.githubusercontent.com/material-components/material-web/main/tokens/versions/v0_192/_md-sys-shape.scss)

### 6.1 本專案的非膠囊形狀策略

本專案不把 `corner-full` 套用到長方形容器。形狀依元件功能分成兩類：

- **圓角矩形**：用於帶文字的操作、輸入、選取容器、卡片、選單與面板。圓角是固定 token，不隨元件高度自動變成半高。
- **圓形**：只用於寬高相等且具有明確中心的元件，例如頭像、單一圖示按鈕、單選圓點、圓形進度指示或圓形色票。文字按鈕、chip、標籤與分段選項不使用圓形。

| 元件 | 建議形狀 | 建議圓角／規則 |
| --- | --- | --- |
| Filled／Tonal／Elevated／Outlined button | 圓角矩形 | 8dp；較大型按鈕可用 12dp |
| Text button 的狀態層 | 圓角矩形 | 8dp |
| Chip、tag、filter | 圓角矩形 | 8dp；高度增加時仍維持 8dp |
| Segmented button 外框 | 圓角矩形群組 | 外框 12dp；內部分段共用直線邊界 |
| FAB／Extended FAB | 圓角正方形／圓角矩形 | 16dp；Extended FAB 不使用半高圓角 |
| 一般 icon button | 圓角正方形 | 8dp 或 12dp |
| 獨立圓形 icon button | 圓形 | 僅在寬高相等、圓形能表達獨立操作時使用 |
| Search bar、text field | 圓角矩形 | 8dp 或 12dp；不使用兩端半圓 |
| Cards、dialogs、menus | 圓角矩形 | 12dp、16dp 或 28dp，按容器層級選擇 |
| Navigation 選取指示 | 圓角矩形 | 8dp 或 12dp；寬度由內容與版面決定 |
| Switch 軌道 | 小圓角矩形 | 固定 8dp 或 12dp；thumb 保持圓形 |
| Avatar、radio、圓形進度 | 圓形 | 寬高必須相等 |

設計 token 可另外建立 `componentRadiusSmall = 8dp`、`componentRadiusMedium = 12dp`、`containerRadiusLarge = 16dp`、`containerRadiusExtraLarge = 28dp` 與 `circle = 50%`。不要讓一般元件直接引用 `corner-full`；如框架預設使用 Full，應在全域主題或共用元件層覆寫，而不是在各畫面重複修改。

圓角矩形與圓形之間應保持功能差異：圓形偏向單一圖像、狀態或身份；圓角矩形承載文字、複合資訊與多步操作。互動時只改變色彩、層級或狀態層，不在按壓時切換成另一種形狀。

## 7. 層級 Elevation

| 層級 | 高度 |
| --- | ---: |
| Level 0 | 0dp |
| Level 1 | 1dp |
| Level 2 | 3dp |
| Level 3 | 6dp |
| Level 4 | 8dp |
| Level 5 | 12dp |

這些值表示層級，不是 CSS `box-shadow` 的 blur 值。實際陰影由元件實作決定。[官方 Elevation tokens](https://raw.githubusercontent.com/material-components/material-web/main/tokens/versions/v0_192/_md-sys-elevation.scss)

早期 M3 會以 primary tint 疊色表示 tonal elevation；後續 M3 元件改用具名的 surface container 角色。應依元件版本選擇一致的表面策略，避免在已指定的容器色上再任意疊加 tint。陰影也不必套用到每張卡片。[官方表面策略更新](https://github.com/material-components/material-components-android/blob/master/docs/theming/Color.md)

## 8. 互動狀態 State

| 原版狀態層 | 不透明度 |
| --- | ---: |
| Hover | 8% |
| Focus | 12% |
| Pressed | 12% |
| Dragged | 16% |

來源：[官方 v0.192 State tokens](https://raw.githubusercontent.com/material-components/material-web/main/tokens/versions/v0_192/_md-sys-state.scss)。

狀態層是疊在元件底色上的回饋，不是把整個元件或文字設為這個透明度。顏色應依該元件的狀態 token 決定，也不能把多種狀態透明度任意相加。選取狀態屬於持續性的內容狀態，不等於 Pressed。

Disabled 依元件個別定義。例如原版 Filled button 使用 `onSurface` 的 12% 作容器、38% 作文字與圖示；Filled text field 的 disabled 容器則是 4%，因此不能建立「所有 disabled 都 12%」的通則。[Button tokens](https://raw.githubusercontent.com/material-components/material-web/main/tokens/versions/v0_192/_md-comp-filled-button.scss)、[Text field tokens](https://raw.githubusercontent.com/material-components/material-web/main/tokens/versions/v0_192/_md-comp-filled-text-field.scss)

**專案建議**：桌面端的鍵盤焦點應清楚可辨，必要時加上焦點框；不能只設計滑鼠 hover。

## 9. 動畫 Motion

### 9.1 原版時長 token

| 群組 | 1 | 2 | 3 | 4 |
| --- | ---: | ---: | ---: | ---: |
| Short | 50ms | 100ms | 150ms | 200ms |
| Medium | 250ms | 300ms | 350ms | 400ms |
| Long | 450ms | 500ms | 550ms | 600ms |
| Extra long | 700ms | 800ms | 900ms | 1000ms |

### 9.2 原版緩動參考

| Token | cubic-bezier |
| --- | --- |
| Standard | `(0.2, 0, 0, 1)` |
| Standard accelerate | `(0.3, 0, 1, 1)` |
| Standard decelerate | `(0, 0, 0, 1)` |
| Emphasized accelerate | `(0.3, 0, 0.8, 0.15)` |
| Emphasized decelerate | `(0.05, 0.7, 0.1, 1)` |
| Linear | `(0, 0, 1, 1)` |

來源：[官方 Motion tokens](https://raw.githubusercontent.com/material-components/material-web/main/tokens/versions/v0_192/_md-sys-motion.scss)。**原版動畫中的 Emphasized 名稱不等於 Material 3 Expressive**。完整 emphasized 路徑在不同平台的表示方式可能不同，不應把單一 CSS 曲線宣稱為所有平台的精確實作。

**專案建議**：小範圍回饋優先從 Short 選取，展開與面板切換從 Medium 選取，再按移動距離與內容調整。這是選用建議，不是每種操作的官方固定時長。保留必要的淡入、位移、ripple 與狀態切換；避免無功能的循環動畫、強烈彈跳與裝飾性形變，並尊重減少動態效果偏好。

## 10. 版面與自適應 Layout

### 10.1 原版三段視窗寬度

| 寬度類別 | 可用寬度 | 版面方向（非強制一對一） |
| --- | --- | --- |
| Compact | 小於 600dp | 單欄、底部導覽或模態抽屜 |
| Medium | 600dp 至小於 840dp | Navigation rail，視內容考慮雙欄 |
| Expanded | 840dp 以上 | Rail／常駐抽屜、清單與詳情、輔助面板 |

依據的是應用程式的可用視窗，不是「手機／平板／桌機」名稱。也要考慮高度、鍵盤、系統 inset 與分割視窗。現行 Android 文件另外增加 1200dp、1600dp 級距；本文件保留原版三段模型，不把新級距列成原版必備規範。[官方 Window size classes](https://developer.android.com/develop/ui/compose/layouts/adaptive/use-window-size-classes)

### 10.2 間距與密度

**專案建議，非全部元件通用的官方 token：**

- 用 4dp 作為小幅調整步進，常用間距集中為 4、8、12、16、24、32dp。
- 窄視窗頁面邊距可從 16dp 起，較寬視窗從 24dp 起，再依內容調整。
- 同一組內容內部間距小於不同區塊之間的間距。
- 桌面編輯器可設密度變體，但保留可讀性、鍵盤操作與適合輸入方式的命中區。
- 多欄不足寬時改為切換或收合，不強迫每一欄持續縮小。

## 11. 元件使用清單

以下整理原版 M3 的主要元件家族與選用原則；個別 variant 的 padding、最小寬度與狀態需查對應平台的元件規格。官網的現行元件頁可能顯示 Expressive，不能直接照最新示範替換本基線。

| 元件家族 | 使用原則 |
| --- | --- |
| Filled button | 主要、較高強調操作 |
| Filled tonal button | 次於 Filled 的強調操作 |
| Elevated button | 需要與背景分離的操作；不代表最高優先級 |
| Outlined button | 中低強調的次要操作 |
| Text button | 低強調操作，例如取消或輔助操作 |
| Icon button | 圖示可清楚傳意的操作；提供可讀名稱與必要 tooltip |
| FAB／Extended FAB | 畫面的關鍵主要動作；不將每一種操作都做成 FAB |
| Segmented buttons | 少量相關選項的單選或多選；不是 Expressive button groups |
| Chips | Assist 表示輔助操作、Filter 表示篩選、Input 表示輸入實體、Suggestion 表示建議 |
| Cards | 組織相關內容；依需要選 Filled、Outlined 或 Elevated |
| Lists | 顯示可掃讀的同類項目，區分主文、輔文與尾端操作 |
| Dividers | 分隔確實不同的群組，不在所有容器上重複加線 |
| Top app bar | 頁面標題、導覽與畫面層級操作 |
| Bottom app bar | 底部操作容器，與目的地導覽列用途不同 |
| Navigation bar | 少量主要目的地的底部導覽 |
| Navigation rail／drawer | 側邊主要導覽，依空間、目的地數量與標籤需求選用 |
| Tabs | 同層相關內容分類，不替代所有層級導覽 |
| Search bar／view | 搜尋入口、查詢輸入與結果流程 |
| Text fields | Filled／Outlined 輸入；保留 label、必要說明及錯誤訊息 |
| Checkbox | 多選或獨立勾選，必要時表示部分選取 |
| Radio button | 同一群組中的互斥選擇 |
| Switch | 開／關設定；需明確表達目前狀態 |
| Slider | 範圍值調整；精確數值需求另提供可輸入或可微調方式 |
| Menus | 與觸發位置相關的操作或選項 |
| Dialogs | 必須處理的決策或聚焦任務，不用於每次一般狀態回報 |
| Bottom／side sheets | 補充任務或內容；模態版本需處理焦點與關閉行為 |
| Date／time pickers | 日期時間選取，遵守地區格式與可輸入需求 |
| Snackbar | 短暫操作回饋，適合提供復原；關鍵錯誤不只依賴它 |
| Progress indicators | 已知進度顯示 determinate，未知進度用 indeterminate |
| Badges | 數量或狀態提示，提供輔助科技可理解的語意 |
| Tooltips | 補充簡短說明，不承擔唯一的必要操作指引 |
| Carousel | 有順序的視覺內容瀏覽；不是每個內容列表都需要 |

入口：[官方元件目錄](https://m3.material.io/components)。上述用途包含本文件的實務整理；元件尺寸以版本化 token 與實際平台規格優先。

### 11.1 已核對的基礎數值範例

| 元件／項目 | 原版基準 |
| --- | --- |
| Filled button 容器高度 | 40dp 等值邏輯尺寸 |
| Filled button 官方形狀／文字 | Full／`labelLarge` |
| Filled button 專案覆寫 | 8dp 圓角矩形；大型版本可用 12dp |
| Filled button 內圖示 | 18dp 等值邏輯尺寸 |
| Filled text field 上方圓角 | 4dp 等值邏輯尺寸 |
| Filled text field 底線 | 一般 1dp、focus 2dp 等值邏輯尺寸 |

來源：[Filled button tokens](https://raw.githubusercontent.com/material-components/material-web/main/tokens/versions/v0_192/_md-comp-filled-button.scss)、[Filled text field tokens](https://raw.githubusercontent.com/material-components/material-web/main/tokens/versions/v0_192/_md-comp-filled-text-field.scss)。**視覺容器高度不是可觸控區高度**；40dp 按鈕仍應配置適當觸控命中區。

## 12. 可及性與內容

- 可觸控互動目標以至少 **48 × 48dp** 為 Android／Material 基準，可由外部命中區補足較小的視覺元件。
- 一般文字對比至少 **4.5:1**；符合大字定義的文字至少 **3:1**。Android 指引中的大字門檻為 18sp，或 14sp 粗體；不要把所有 14sp 文字都視為大字。
- 支援放大文字、螢幕閱讀器標籤與合理的閱讀順序。
- 錯誤、選取與成功狀態不能只靠顏色；應搭配文字、形狀或圖示。

來源：[Android 官方可及性指引](https://developer.android.com/guide/topics/ui/accessibility/apps)。

**專案建議：**

- 桌面主要功能可用鍵盤完成，包含焦點移動、啟動、關閉彈窗與返回原觸發位置。
- 操作文案使用具體動詞，例如「儲存」「匯出」「刪除角色」，避免只寫「確定」。
- 錯誤訊息交代問題與可採取的下一步，並保留使用者輸入。
- 裝飾圖示不重複朗讀；純圖示按鈕必須有名稱。
- 破壞性且不可復原的操作採取與風險相稱的確認；可復原操作可提供 Undo。

## 13. 本專案的非 Expressive 落地建議

此節是建議，尚未修改應用程式或設定。

1. 將本文件作為原版 M3 基線；建立 light／dark 主題、15 級文字角色及原版圓角階梯。
2. 用少量重點色建立操作層級，讓編輯內容保有視覺主導權。
3. 將按鈕、chip、搜尋列與選取指示覆寫為固定圓角矩形；圓形僅用於等寬高且具有明確幾何意義的元件。
4. 為桌面工作區集中管理間距與密度變體，避免逐頁任意縮小元件。
5. 在框架升級時檢查元件樣式與預設值的改動，不能只靠「啟用 Material 3」選項保證視覺永遠停在原版。
6. 若 SDK 已更改某元件預設，只針對已確認的差異覆寫主題或元件變體，記錄對應版本與理由。

## 14. 設計審查清單

- [ ] 使用原版 M3 基線，未混入 M3E 專屬元件或變體。
- [ ] 品牌、表面、前景與錯誤使用語意色彩角色。
- [ ] 明暗主題均已檢查文字、邊界與狀態的可辨識度。
- [ ] 字體角色、圓角及間距一致；中文與文字放大不裁切。
- [ ] 元件容器尺寸與實際命中區分開檢查。
- [ ] Hover、focus、pressed、selected、disabled 狀態完整。
- [ ] 主要操作有清楚層級，導覽與動作按鈕用途正確。
- [ ] 窄、中、寬視窗與低高度情境都能使用。
- [ ] 鍵盤與螢幕閱讀器可完成主要流程。
- [ ] 動畫具有功能目的，並支援減少動態效果。
- [ ] 例外與自訂值已集中記錄，而非散落硬編碼。
- [ ] SDK 更新後比對既有畫面，避免預設值悄悄帶入 Expressive 外觀。

## 15. 來源與維護方式

本文件已於各節附上官方來源。數值以 Google 官方版本化 token 為主要依據；平台操作與可及性以 Android 官方說明補充。M3 官網部分頁面需要 JavaScript，且現行內容會更新，因此不能將目前首頁當作原版的固定快照。

維護時，分別記錄「原版 M3 基線」「平台實作差異」「專案自訂」；新增資料若標示 Expressive 或無法確認原版來源，不直接納入此文件的基礎預設。
