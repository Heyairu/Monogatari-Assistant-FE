# MonoAshi™ Mosaic System 實作計畫

> 文件狀態：草案 v0.3  
> 建立日期：2026-09-07  
> 系統名稱：**MonoAshi™ Mosaic System**  
> UI 用語：面向使用者的按鈕、選單、Tooltip 與設定仍統一使用「標記」，不以「Mosaic」取代功能名稱。  
> 目標：在主編輯器支援可儲存於正文、可解析、可高亮並可攜帶註記的 `//...//` 語法，同時提供 Discord 式投影編輯、純顯示文字複製、標記詳情與 IntelliSense，並維持搜尋、校對、協作、游標與專案儲存的既有行為。

## 1. 已確認語法

### 1.1 一般格式

```text
//[類型][狀態][^色碼]<[UUID|]文字>[{註記}]//
```

- `{註記}` 可省略。
- 狀態可省略。
- 類型標記沒有 `^` 時仍採預設色 `B0`。
- 只有 `^` 後方可以附加色碼。
- 單獨使用 `^` 代表純高亮，並歸類為重點。
- 人物、地點、事件、伏筆與計畫等語意類型必須保存對象 UUID，格式為 `<UUID|顯示文字>`。
- 純高亮／重點不綁定專案對象，維持 `<顯示文字>`，不要求 UUID。
- `|` 是 `< >` 內的 UUID／顯示文字分隔符；字面 `|` 必須跳脫為 `\|`。
- 跳脫規則沿用一般反斜線跳脫規則。

UUID 是穩定識別，顯示文字則可採角色主名稱、角色別名或對象目前名稱。重新命名、移名與階層移動皆以 UUID 解決連結，不以顯示文字猜測對象。

### 1.2 類型

| 符號 | 類型 |
| --- | --- |
| `@` | 人物 |
| `!` | 地點 |
| `#` | 事件 |
| `?` | 伏筆 |
| `&` | 計畫 |
| `^`（無其他類型） | 純高亮／重點 |

### 1.3 狀態

| 符號 | 狀態 |
| --- | --- |
| `+` | 開始 |
| `-` | 結束 |
| 省略 | 無狀態 |

狀態只適用於有類型的標記。純高亮不接受 `+` 或 `-`。

### 1.4 色碼

色碼由「背景」與「文字」兩個位置組成：

```text
^      -> B0
^X     -> X0
^XY    -> XY
```

| 色碼 | 顏色 |
| --- | --- |
| `0` | 自動 |
| `A` | 綠色 |
| `B` | 藍色 |
| `C` | 粉紅色；避免與搜尋高亮混淆 |
| `D` | 紫色 |
| `E` | 黃色 |
| `F` | 灰色 |

解析器只接受 `0`、`A`、`B`、`C`、`D`、`E`、`F`。小寫色碼是否接受，列入第 11 節待確認事項。

### 1.5 合法範例

```text
//^<需要注意的文字>//
//^C<粉紅背景、自動文字色>//
//^CE<粉紅背景、黃色文字>//

//@<4e251fc2-1e2b-4f78-93da-91f8c76d9a92|艾莉絲>//
//@+<4e251fc2-1e2b-4f78-93da-91f8c76d9a92|小艾>{以別名首次登場}//
//@-^AF<4e251fc2-1e2b-4f78-93da-91f8c76d9a92|艾莉絲>{離開隊伍}//
//!<c05404a8-8ff7-4df8-8db5-a738a14bb1f0|舊教堂>{主要場景}//
//#+<a9b0f260-895b-4e25-ae02-33c0610e31c9|王都暴動>{事件開始}//
//?-^E<db43f91a-e50f-4ef4-a777-287e638d515e|破裂的懷錶>{伏筆回收}//
//&+^D0<8a876eee-43cd-46ac-9e25-9dadc547fa4d|逃離王都>{計畫開始}//
```

## 2. 顯示、編輯與儲存原則

### 2.1 權威資料

完整標記直接保存在章節正文中，不另建一份必須同步的註記資料表：

```text
正文原始值：她撿起了 //?^CE<db43f91a-e50f-4ef4-a777-287e638d515e|破裂的懷錶>{第一章伏筆}//。
```

因此既有 XML 儲存、undo/redo、專案歷史與 P2P 文字同步可自然保留標記，不需要第一版就修改專案格式版本。

### 2.2 Discord 式投影顯示

編輯器底層保存原始字串，畫面則顯示投影後文字：

```text
原始字串：她撿起了 //?+^CE<db43f91a-e50f-4ef4-a777-287e638d515e|破裂的懷錶>{第一章伏筆}//。
畫面顯示：她撿起了 破裂的懷錶。
```

- 平常隱藏 `//`、類型、狀態、`^XY`、`< >` 與 `{註記}`，只顯示 `<文字>`。
- `<文字>` 套用指定背景色與文字色。
- 游標進入或選取該標記時，局部展開完整語法供直接編輯；離開後重新折疊。
- 未完成或不合法的語法保持原文可見，不能因 parser 失敗而讓使用者無法修正。
- 多個標記相鄰時，只展開目前 active annotation，不造成整段內容跳動。
- IME composing 期間暫停受影響標記的折疊，避免中文輸入法候選與游標錯位。

### 2.3 Raw／display 雙座標

Discord 式顯示使「儲存 offset」與「畫面 offset」不同，因此投影層必須提供：

```text
raw UTF-16 offset <-> display UTF-16 offset
raw selection    <-> display selection
raw range        <-> display range
```

- 專案儲存、CRDT/P2P、undo/redo 與 parser 一律使用 raw offset。
- 畫面游標、滑鼠命中、複製與遠端游標由 projection map 轉換。
- offset map 必須定義隱藏區段的 affinity：點在顯示文字前緣映射至 `<` 後，後緣映射至 `>` 前。
- projection cache 以文件 ID、text revision 與 active annotation ID 為 key。
- 不允許字數、搜尋、複製、匯出各自實作不同版本的標記剝除邏輯。

### 2.4 複製規則

- 一般複製只輸出選取範圍的顯示文字，不包含類型、狀態、色碼、括號或 `{註記}`。
- 選取跨越普通文字與多個標記時，以同一 display projection 組合輸出。
- 點擊詳情中的「複製語法」才複製完整 raw annotation。
- 剪下必須把 display selection 映射回 raw range；完整選取一個標記時移除整段 raw annotation。
- 若只選取標記內部分顯示文字，剪下後保留合法標記並只修改 `<文字>`；若無法安全維持語法，先展開再執行原始文字編輯。

### 2.5 編輯控制器架構

現有 `CodeField`、`HighlightTextEditingController` 與 Rhodanthe 都假設 controller text 和畫面文字等長。Discord 式折疊後此假設不成立，因此不能只把語法設為透明或零字級；那會讓游標、selection box、IME 與遠端游標錯位。

建議新增 `MosaicEditingController`（名稱可依實作調整）：

```text
editorContentProvider / XML / CRDT
              raw text
                  |
          MosaicDocumentProjection
         /          |             \
 display text   offset map   parsed annotations
         \          |             /
          MosaicEditingController
                  |
              CodeField
```

- `rawText` 是唯一可持久化權威值。
- `displayText` 是交給 `CodeField` 的目前投影；active annotation 可在此投影中局部展開。
- 一般輸入先形成 display edit，再由 projection 映射為 raw edit。
- 會破壞標記邊界的 display edit 必須採明確規則處理，不可靠猜測修復。
- `textRevision` 至少拆成 raw revision 與 presentation revision；折疊／展開雖不改 raw text，仍會改 display text 與 render plan。
- 現有 `editorContentProvider` listener、章節提交、協作游標和 undo/redo 都需要經過 controller adapter，不再直接假設 `textController.text` 是儲存內容。

Phase 1 先用 prototype 驗證 `CodeField` 是否能穩定接受這種雙表示控制器。若套件限制無法安全處理，須先評估自訂 `EditableText` adapter，不能以隱藏字級的方式勉強上線。

## 3. 解析器設計

### 3.1 新增純 Dart 解析層

建議新增：

```text
lib/features/inline_annotations/
  inline_annotation.dart
  inline_annotation_parser.dart
  inline_annotation_palette.dart
  inline_annotation_rhodanthe_adapter.dart
```

解析器不可只使用單一大型正則表達式。使用單次線性掃描，才能正確處理跳脫、錯誤復原與 UTF-16 range。

預期資料模型：

```dart
enum InlineAnnotationKind { character, location, event, foreshadowing, plan, emphasis }
enum InlineAnnotationState { none, start, end }

final class InlineAnnotationColorCode {
  final String background;
  final String foreground;
}

final class InlineAnnotation {
  final InlineAnnotationKind kind;
  final InlineAnnotationState state;
  final InlineAnnotationColorCode colors;
  final String? targetId;
  final String displayText;
  final String? note;
  final TextRange sourceRange;
  final TextRange displayRange;
  final TextRange? noteRange;
}
```

所有 range 均採 Dart `String`／Flutter 使用的 UTF-16 offset，禁止以 Unicode code point 數量取代。

### 3.2 建議解析流程

1. 從未跳脫的 `//` 尋找標記起點。
2. 解析可選類型 `@ ! # ? &`。
3. 解析可選狀態 `+ -`；若為純 `^` 則不接受狀態。
4. 解析可選 `^` 與其後 0 至 2 個合法色碼。
5. 要求未跳脫的 `<`，並掃描至未跳脫的 `>`。
6. 語意類型解析第一個未跳脫的 `|`，其左側必須是合法 UUID，右側是顯示文字；純高亮不解析 UUID。
7. 解析可選 `{註記}`。
8. 要求未跳脫的結尾 `//`。
9. 產生 annotation、target UUID 與 display/note 的精確 UTF-16 range。
10. 從結尾後繼續掃描，總時間複雜度維持 O(n)。

### 3.3 錯誤復原

- 缺少 `<文字>`、結尾 `//` 或括號未閉合時，整段保留為普通文字，不套用部分高亮。
- 非法色碼不應吞掉後續正文；該標記視為無效，並從下一個可能的未跳脫 `//` 繼續掃描。
- 超過兩碼的色碼視為無效，不偷偷截斷成前兩碼。
- 語意類型缺少 UUID、UUID 格式錯誤或缺少未跳脫 `|` 時，標記保持原文可見並標示為無效。
- UUID 存在但目前專案找不到對象時，語法仍屬合法；UI 顯示「遺失的對象」並提供重新連結，不可丟棄標記。
- 不允許巢狀 annotation；內層 `//` 若未跳脫，依最接近且可完整解析的結構處理。
- 解析失敗不得拋出到輸入事件或阻塞 UI。

### 3.4 跳脫測試基準

至少涵蓋：

```text
\//                  普通雙斜線，不是起點
\< \>                顯示文字中的字面角括號
\{ \}                註記中的字面大括號
\|                    顯示文字中的字面 UUID 分隔符
\/\/                 標記內容中的字面雙斜線
\\                   字面反斜線
```

實際解碼時只移除語法定義需要的跳脫，不可任意改寫一般正文中的反斜線。

## 4. 色彩與無障礙

### 4.1 語意色票

在 `rhodanthe_theme.dart` 加入背景與前景 token，不直接把 Flutter `Color` 寫進 parser：

```text
annotation.green.background
annotation.green.foreground
annotation.blue.background
annotation.blue.foreground
annotation.pink.background
annotation.pink.foreground
annotation.purple.background
annotation.purple.foreground
annotation.yellow.background
annotation.yellow.foreground
annotation.gray.background
annotation.gray.foreground
```

`0` 代表該 channel 不指定顏色，交由基礎文字樣式或主題自動決定。例如 `B0` 只提供藍色背景，不覆寫文字顏色。

### 4.2 主題要求

- Light、Dark、High Contrast 分別定義可讀色值。
- 背景與自動文字色組合須達到可接受對比。
- 搜尋目前項目仍使用既有 Search Ring；搜尋樣式可暫時覆蓋正文 annotation，離開搜尋結果後恢復原色。
- 粉紅色 `C` 必須與既有黃色搜尋匹配、深紅目前搜尋項目保持可辨識。

## 5. 串接既有 Rhodanthe 管線

### 5.1 Annotation 轉換

由 `inline_annotation_rhodanthe_adapter.dart` 將 parser 結果轉成 `RhodantheExternalAnnotation`：

- `range` 使用目前 display projection 中 `<文字>` 的 display range，而不是 raw source range。
- 建議使用 Ring 4，讓 Ring 2 搜尋樣式優先、Ring 6 贅詞與 Ring 8 診斷維持既有階層。
- `source` 使用 `inlineMarkup`。
- `annotationId` 由文件 revision、source range 與順序產生，不使用文字內容，避免將正文寫入 log 或遙測。
- `interaction` 指向可在 Dart 端查回的 annotation ID。
- `payloadId` 保存標記中的 target UUID；純重點可為 `null`。註記全文只留在當次 parser 結果的記憶體索引，不送入 payload、log 或遙測。

### 5.2 主編輯器分析流程

調整 `main.dart` 中的 Rhodanthe analyze 呼叫：

1. 每次 raw revision 解析 inline annotations 並建立 display projection。
2. active annotation 改變時，以 presentation revision 重建局部展開 projection。
3. Rhodanthe document 同步目前 display text；其 range 與 `CodeField` 實際顯示內容保持一致。
4. 將 parser 結果快取於目前章節、raw revision、presentation revision 與 active annotation。
5. 在搜尋分析與校對分析的 `externalAnnotations` 中一併送入。
6. 即使沒有搜尋或校對，也要能請求只含 inline annotations 的 render plan。
7. revision 不一致時丟棄結果，沿用現有 latest-only 與 stale-plan 防護。

Rhodanthe revision 代表 display document revision；專案 dirty state 與儲存 revision 仍由 raw text 決定。兩者不可共用同一個遞增值後假設語意相同。

### 5.3 Web／native 不可用時的 fallback

Inline annotation 是正文格式，不能只在 Rhodanthe Full/native 模式生效：

- parser 必須是純 Dart 且所有平台可用。
- `HighlightTextEditingController` 增加一組 inline annotation ranges/styles。
- Rhodanthe 可用時由 render plan 統一合併樣式。
- Rhodanthe 不可用、kill switch 或 Web stub 時，Dart `buildTextSpan` 仍繪製相同顏色。
- 同一時間只允許 Rhodanthe 或 Dart fallback 其中一套輸出，避免重複套色。

## 6. 標記詳情與 IntelliSense

### 6.1 點擊標記

- `EditorTextBox.onInteractionOffset` 接回主頁，並先由 display offset 映射為 raw offset。
- 透過 `textController.rhodantheMetadataAt(offset)` 或 Dart fallback 的 range 索引找到 annotation。
- 點擊顯示文字時開啟標記詳情，至少顯示：
  - 完整語法。
  - 由 UUID 解析出的對象、目前名稱與對象類型。
  - 標記中實際保存的顯示文字；若是角色別名須標明。
  - 狀態（開始、結束或空白）。
  - 背景色與文字色。
  - 備註；未填時明確顯示「無備註」。
- 詳情提供「編輯標記」、「複製語法」、「移除標記但保留文字」。
- Popover 關閉後焦點與游標回到原位置。

### 6.2 IntelliSense 觸發

IntelliSense 有自動與手動兩種觸發方式：

- 輸入 `<`：立即開啟對象候選，不需先輸入 `/` 或 `\`。
- 輸入 `^`：立即開啟雙色色碼候選，不需先輸入 `/` 或 `\`。
- 輸入 `/` 或 `\`：保留為任何上下文都可使用的手動叫出功能。
- 觸發字元仍須能作為一般正文輸入；只有接受候選項時，才以單一 undo transaction 寫入或更新完整標記。

情境路由：

| 目前上下文 | IntelliSense 內容 |
| --- | --- |
| 空白／尚未指定內容 | 類型：人物、地點、事件、伏筆、計畫、重點 |
| `^` 後 | 背景色與文字色；支援先選背景、再選文字 |
| `< >` 內或準備填入 `<文字>` | 可引用的專案對象 |
| `{ }` 內 | 備註編輯提示與最近使用內容；MVP 不做 AI 自動生成 |
| `/` 或 `\` 手動叫出 | 類型、色彩、對象，以及「插入字面字元」操作 |

觸發鍵行為：

- `/` 與 `\` 都能開啟相同候選面板，照顧不同鍵盤配置與使用習慣。
- IntelliSense 提供「插入 `/`」與「插入 `\`」候選；插入內容必須先依目前語法上下文完成必要跳脫，且不得再次觸發同一面板。
- `Esc` 關閉面板且不修改文字。
- `Enter` 或 `Tab` 接受候選。
- `Up`／`Down` 移動同層候選。
- `Left`／`Right` 負責父子層級導覽，不移動編輯器游標。
- 面板關閉後，方向鍵恢復原本游標行為。

### 6.3 類型候選

空白上下文先列出：

```text
@ 人物
! 地點
# 事件
? 伏筆
& 計畫
^ 重點／純高亮
```

選擇類型後：

- 可選擇空白、`+` 開始或 `-` 結束。
- 可直接接受預設色 `B0`，或進入 `^` 色彩選擇。
- 接著進入 `<對象>` 候選。
- `{註記}` 是選填步驟，可直接完成標記。

### 6.4 色彩候選

輸入或選擇 `^` 後：

1. 第一層選背景：自動、綠、藍、粉紅、紫、黃、灰。
2. 第二層選文字：自動、綠、藍、粉紅、紫、黃、灰。
3. 即時預覽 `XY` 的實際外觀與對比。
4. 無選擇直接完成時使用 `B0`；只選一碼時正規化為 `X0`。

若組合對比過低，UI 顯示警告但不擅自改寫使用者色碼。

### 6.5 `<對象>` 階層導覽

候選資料直接讀取目前專案 provider，不複製一份獨立資料庫：

- 人物：同時檢測角色主名稱與全部別名，可依名稱、別名與關鍵字篩選。
  - 命中別名時仍寫入同一角色 UUID。
  - `Left`／`Right` 在該角色的主名稱與別名之間切換顯示文字，不改變 UUID。
  - 若角色模型存在主／父元件關係，`Left`／`Right` 同樣用於切換主元件與父元件；候選 Tips 必須清楚標明目前層級，避免和別名切換混淆。
- 事件：以大綱階層顯示。
  - 大綱按 `Right` 進入中綱。
  - 中綱按 `Right` 進入小綱。
  - 小綱或中綱按 `Left` 回上一層。
- 地點：按 `Right` 進入子地點，按 `Left` 回父地點。
- 伏筆：列出既有伏筆，可顯示開始／結束狀態摘要。
- 計畫：列出既有計畫，可顯示目前狀態摘要。
- 重點：不要求綁定專案對象，直接使用目前選取文字或輸入文字。

搜尋結果採扁平顯示：若命中項目本身是子元件，不另外顯示其父資料夾列；父層資訊只放在候選後方 Tips。只有使用者主動以 `Right` 瀏覽子層時，才進入資料夾式階層畫面。

候選列與後方 Tips 例如：

```text
城門衝突    Tips: 事件 · 第一卷 › 王都篇
教堂        Tips: 地點 · 王都 › 舊城區
小艾        Tips: 人物 · 艾莉絲的別名
```

接受候選後寫入 `<UUID|顯示文字>`。後續即使對象改名或移動階層，仍以 UUID 解析；UI 可提示顯示文字已過期，並提供更新為目前名稱或保留原文兩種操作。

### 6.6 從 IntelliSense 新增元件

每一種對象候選底部提供「新增……」：

- 新增人物。
- 在目前大綱層級新增事件。
- 在目前地點下新增子地點，或新增同層地點。
- 新增伏筆。
- 新增計畫。

新增流程要求：

- 使用既有 notifier/provider 的正式新增 API，不能由 IntelliSense 直接改底層集合。
- 最小表單至少要求名稱；其他欄位可稍後到對應模組補完。
- 成功建立後回到原 IntelliSense，預選新元件並可立即插入標記。
- 取消或建立失敗時保留原文字與選取範圍。
- 建立元件與插入正文標記是兩個可辨識的狀態交易；若第二步失敗，不可偷偷刪除已建立元件。
- 權限、唯讀或同步衝突時停用新增入口並說明原因。

### 6.7 標記寫入

- 有選取文字時，以選取內容預填 `<文字>`。
- 無選取文字時，在接受對象後寫入其 UUID，並以目前選定的主名稱或別名填入顯示文字。
- 純重點只寫入 `<顯示文字>`，不加入 UUID 分隔符。
- 「插入字面 `/`／`\`」依 parser escape API 產生內容，禁止 UI 自行拼接反斜線。
- 編輯既有 annotation 時，以完整 raw source range 一次替換。
- 提供移除標記但保留 `<文字>` 的操作。
- 所有寫入都重新經過 parser 驗證，無效結果不可自動折疊。

## 7. 與既有功能的相容性

### 7.1 搜尋與替換

- 預設搜尋以 display projection 為資料來源，不搜尋隱藏語法與註記。
- 搜尋結果 range 必須映射回 raw range，才能沿用既有選取與 Replace 流程。
- 進階選項可另提供「搜尋標記語法／備註」，但不作為預設行為。
- 搜尋命中 `<文字>` 時，Search Ring 暫時覆蓋 annotation 的相同 style channel。
- Replace/Replace All 若修改到標記結構，下一個 revision 重新解析；不得保留過期 range。
- 只替換 `<文字>` 的內容，不因 display range 擴張而刪除外層標記。

### 7.2 字數統計、複製與匯出

全部共用 projection API：

```text
原始：她撿起 //?<db43f91a-e50f-4ef4-a777-287e638d515e|懷錶>{伏筆}//。
投影：她撿起 懷錶。
```

- 字數統計排除語法符號與 `{註記}`，保留 `<文字>`。
- `Ctrl/Cmd+C` 預設寫入選取範圍的 display text。
- 匯出預設使用 display text；若要保留標記，提供明確的「包含標記原始碼」選項。
- 此變更需要獨立回歸測試，避免影響既有 debounce 與章節總字數。

### 7.3 儲存、歷史與同步

- XML 仍保存原始正文，不新增平行持久化欄位。
- undo/redo 以正文變更為準。
- P2P/CRDT 仍同步原始字串；parser 產物不透過網路傳輸。
- 章節切換後以新章節正文重建 annotation cache。
- 不將註記全文加入 Rhodanthe rollout evidence、debug log 或錯誤訊息。

## 8. 預計修改檔案

| 檔案／目錄 | 變更 |
| --- | --- |
| `lib/features/inline_annotations/` | 新增模型、parser、色票映射與 Rhodanthe adapter |
| `lib/features/inline_annotations/inline_annotation_projection.dart` | 建立 raw/display 文字與雙向 offset map |
| `lib/features/inline_annotations/mosaic_editing_controller.dart` | 管理 raw/display 雙表示、presentation revision 與 display edit 映射 |
| `lib/features/inline_annotations/inline_annotation_intellisense.dart` | 上下文判斷、候選模型與鍵盤導覽 |
| `lib/infrastructure/rhodanthe/rhodanthe_theme.dart` | 新增 annotation 語意色 token |
| `lib/infrastructure/rhodanthe/rhodanthe_annotations.dart` | 視需要新增共用 external annotation builder；避免放 parser 本身 |
| `lib/main.dart` | 管理解析 cache、送入 analyze、接收點擊互動 |
| `lib/bin/findreplace.dart` | 新增 Dart fallback ranges/style 與 metadata 查詢 |
| `lib/bin/content.dart` | 投影編輯、複製攔截、annotation 點擊與 Popover 入口 |
| `lib/presentation/widgets/mosaic_intellisense_overlay.dart` | IntelliSense 浮層、階層候選與新增元件入口 |
| `test/inline_annotation_parser_test.dart` | parser、跳脫、錯誤復原與 UTF-16 測試 |
| `test/inline_annotation_projection_test.dart` | raw/display offset、selection、copy/cut 測試 |
| `test/mosaic_intellisense_test.dart` | 觸發鍵、上下文、階層導覽與新增元件測試 |
| `test/inline_annotation_render_test.dart` | 色碼、Ring 優先權與 fallback 渲染測試 |
| `test/inline_annotation_interaction_test.dart` | 點擊、註記顯示與焦點回歸測試 |
| `benchmark/inline_annotation_benchmark_test.dart` | 大型章節的解析與 span 建立效能 |

第一版預期不需要修改 XML codec、Freezed 專案模型或 Rust contract。既有 `RhodantheExternalAnnotation` 已能承載 range、style 與 interaction。

## 9. 分期實作

### Phase 1：語法、parser 與 projection

- [ ] 建立 immutable annotation model。
- [ ] 建立 `CodeField` 雙表示 controller 技術 prototype，先驗證 selection、IME 與局部展開。
- [ ] 實作單次線性掃描 parser。
- [ ] 實作語意類型 UUID 驗證、遺失對象狀態與 `<UUID|顯示文字>` escaping。
- [ ] 實作色碼正規化：空碼 `B0`、單碼 `X0`、雙碼 `XY`。
- [ ] 實作反斜線跳脫與 malformed recovery。
- [ ] 實作 raw/display projection 與雙向 offset map。
- [ ] 定義 active annotation 展開／折疊及 IME composing 規則。
- [ ] 建立 UTF-16、emoji、代理對與大量文字測試。

完成條件：parser 對所有合法／非法 fixture 產生穩定 range，且 raw/display selection 可往返映射，不因不完整輸入拋錯。

### Phase 2：Discord 式編輯與高亮渲染

- [ ] 建立 Light/Dark/High Contrast 色票。
- [ ] 將 annotation 轉為 Ring 4 external annotations。
- [ ] 將 inline annotations 合併進所有 Rhodanthe analyze 路徑。
- [ ] 實作 Web/native failure 的 Dart fallback。
- [ ] 平常折疊語法、游標進入時局部展開。
- [ ] 攔截 copy/cut，預設只輸出 display text。
- [ ] 驗證搜尋目前項目、搜尋匹配、贅詞與診斷的優先權。

完成條件：同一份正文在 native 與 fallback 路徑顯示一致；游標、IME、複製與剪下皆符合 projection 規則，搜尋結束後原始 annotation 色彩正確恢復。

### Phase 3：標記詳情與 IntelliSense

- [ ] 接上 interaction offset。
- [ ] 點擊 `<文字>` 顯示語法、對象、類型、狀態、色彩與備註。
- [ ] `/` 與 `\` 觸發 IntelliSense。
- [ ] 實作類型、狀態與 `^` 雙色候選。
- [ ] 實作人物、事件大／中／小綱、地點父子、伏筆與計畫候選。
- [ ] 實作 `Left`／`Right` 階層導覽與麵包屑。
- [ ] 串接各類型的「新增元件」最小表單與正式 provider API。
- [ ] 新增標記插入／編輯表單。
- [ ] 新增移除標記但保留顯示文字。
- [ ] 驗證每次操作是單一 undo/redo 步驟。

完成條件：使用者不必手寫語法即可建立、搜尋、新增對象、查看、修改和移除標記。

### Phase 4：周邊功能整合

- [ ] 字數統計改採 display projection。
- [ ] 搜尋／替換改採 display projection 並安全映射 raw range。
- [ ] 匯出與唯讀預覽預設採 display projection。
- [ ] 增加「包含標記原始碼」的明確匯出／複製入口。
- [ ] 視需求加入依人物、地點、事件、伏筆、計畫、重點篩選的索引面板。

完成條件：所有需要「讀者可見正文」的功能都使用同一投影規則，不各自重新解析。

## 10. 測試與效能門檻

### 10.1 單元測試

- 六種語意類型與三種狀態結果。
- 無色碼、單色碼、雙色碼與非法色碼。
- 有／無 `{註記}`。
- escaped delimiter、括號與反斜線。
- UUID／顯示文字分隔、非法 UUID、遺失對象與 escaped `\|`。
- 不完整輸入逐字形成合法標記的過程。
- 中文、Latin、emoji、組合字元與換行。
- 相鄰、重疊企圖與大量 annotation。
- raw/display offset 在隱藏前綴、顯示文字、註記與結尾的 affinity。
- 跨越普通文字與多個標記的 projection selection。
- 人物、事件階層、地點階層、伏筆與計畫的候選排序。
- 人物主名稱／別名切換保持 UUID 不變。
- 命中子元件時扁平顯示，父資料夾只出現在 Tips。

### 10.2 Widget／整合測試

- 編輯時游標不跳動，IME composing 不被中斷。
- 標記平常折疊，游標進入時只展開目前標記。
- 複製只得到顯示文字；「複製語法」得到完整 raw annotation。
- 搜尋、替換、校對與 annotation 同時存在。
- 章節切換、undo/redo、儲存重開後結果一致。
- 點擊 annotation 可看到正確註記。
- native 關閉與 Web fallback 顯示一致。
- 遠端游標仍對齊原始文字 offset。
- `/`、`\`、`Esc`、`Enter`、`Tab` 與方向鍵行為正確。
- 輸入 `<` 或 `^` 可直接開啟正確上下文的 IntelliSense。
- 透過 IntelliSense 插入 `/` 或 `\` 時不遞迴觸發面板，且產生合法跳脫。
- 從事件／地點父子層級返回時，焦點與查詢字串保持。
- 從 IntelliSense 新增元件後可立即完成標記。

### 10.3 效能目標

- parser 對 100 KB 正文維持 O(n)，Profile mode 單次目標小於 10 ms。
- 不在每次 `buildTextSpan` 重跑 parser；以 text revision 快取。
- 快速連續輸入採 latest-only 結果，過期解析或 render plan 不得發布。
- 註記索引以排序 range 做二分查找，不在每次點擊線性掃描全部項目。
- projection 與 offset map 不得在游標每次閃爍時重建。
- IntelliSense 搜尋 debounce 不得阻塞鍵盤輸入；大型專案候選須限制首批筆數並可增量篩選。

## 11. 尚待確認

- [ ] annotation 是否允許跨行；MVP 建議允許，但必須有結尾 `//`。
- [ ] 色碼是否接受小寫 `a-f` 並正規化為大寫；MVP 建議接受。
- [ ] `{註記}` 中是否允許空字串 `{}`；建議解析為無註記並在格式化時省略。
- [ ] 點擊後的標記詳情使用浮動 Popover 或固定側欄；兩者都必須顯示語法、對象與備註。
- [ ] 匯出是否和複製相同，預設只輸出 display projection。
- [ ] `/` 或 `\` 手動叫出時，是先插入字元再開面板，或在取消面板後才補回字面字元。
- [ ] IntelliSense 的「新增事件」應建立大綱節點、時間軸 Scene，或依目前所在候選分類決定。
- [ ] 伏筆與計畫目前的權威資料來源及新增 API；實作前需對應既有 model/provider。
- [ ] UUID 的字串格式是否一律採 canonical lowercase、含連字號格式；MVP 建議輸出時統一，解析時接受大小寫。
- [ ] 使用別名建立標記後，角色刪除該別名時是保留原顯示文字並提示，或自動改回主名稱；MVP 建議保留原文。

## 12. 建議第一個實作切片

先完成 Phase 1 與最小 Discord 式編輯切片，不立即串接新增元件表單：

1. parser 與完整測試。
2. raw/display projection 與雙向 offset map。
3. `B0`、`C0`、`CE` 三組代表性色彩。
4. 平常只顯示並高亮 `<文字>`，游標進入時展開完整語法。
5. 複製只取得 display text。
6. 驗證 IME、搜尋、章節切換、儲存與 undo/redo 無回歸。
7. 再擴充完整色票、Rhodanthe 合併、標記詳情與 IntelliSense。

這個切片先驗證最關鍵的語法、投影、offset 與編輯器行為。通過後再接專案對象候選及「新增元件」，可避免資料寫入流程掩蓋底層游標或選取問題。

## 13. 實作完成紀錄（2026-09-10）

MonoAshi Mosaic 的規劃功能已完成整合。最終互動依產品驗收調整如下：

- Mention 永遠維持 Discord 式折疊，不再於游標進入時展開行內語法。
- 類型徽章使用單一 UTF-16 object replacement character 作為原子佔位符；方向鍵跳過，Backspace／Delete 刪除完整標記。
- 點擊 Mention 先開啟靠近 Mention 的精簡浮窗；顯示文字可直接修改，完整單行語法位於同一浮窗第一層並可編輯。
- IntelliSense 浮動於游標旁，支援半形 `@`、`!`、`#`、`?`、`&`、`^`、`<`、`/`、`\`，人物、事件與地點使用二級／階層選單。
- Enter／Tab 直接選定目標，右方向鍵或 `>` 展開下一層，左方向鍵返回；大型候選清單會保持目前選項可見。
- XML、P2P 與 CRDT 保存 raw text；搜尋、字數、一般複製及讀者匯出使用 display／reader projection。
- 遠端游標以 raw offset 傳輸，顯示時映射到 projection；UUID 與備註中的位置吸附至 Mention 可見邊界。
- projection 只在 raw revision 改變時重建；離線狀態不啟動協作輪詢 timer。

最終自動驗收基線：

- Mosaic parser、projection、CodeField、IME、徽章、剪貼簿、高亮、詳情、重新連結、IntelliSense 與新增元件測試均通過。
- 章節同步、XML 保存、讀者匯出、字數、搜尋／替換、CRDT 與遠端游標整合矩陣通過。
- 100 KB parser benchmark：30 次取樣 p50 1.553 ms、p95 8.021 ms，符合小於 10 ms 目標。
- 完整靜態分析無 error／warning；專案仍有既存 lint info。
