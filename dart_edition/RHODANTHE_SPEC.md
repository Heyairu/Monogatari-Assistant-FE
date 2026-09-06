# MonoAshi™ Rhodanthe* 即時 RichText 引擎規格

| 欄位 | 內容 |
| --- | --- |
| 狀態 | Draft v0.1 |
| 日期 | 2026-08-25 |
| Contract version | 1 |
| 適用專案 | Monogatari Assistant FE / `dart_edition` |
| 引擎名 | MonoAshi™ Rhodanthe* |
| 實作邊界 | Rust 負責文字分析與樣式仲裁；Flutter 負責編輯、`TextSpan`、layout 與 paint |
| 實作進度 | Phase 0 進行中；core、document state、literal search 與 filler analyzer 已通過 Rust 1.75 驗證 |

## 1. 摘要

Rhodanthe 是一個由 Rust 驅動的即時文字標註與 RichText 樣式規劃引擎。它接收不可變文字快照或增量編輯，產生已完成重疊切割與優先級仲裁的 `RenderRun`。Flutter 介面只需將 `RenderRun` 線性轉換為 `TextSpan`。

第一階段支援：

- 搜尋結果高亮，包含目前結果。
- 贅字變色或底線標註。
- 現有校對／標點診斷的相容接入。
- 預留 Mention 的辨識、顯示與交互資料模型。

Rhodanthe 不直接建立 Flutter widget，不接管 IME、游標、選取、排版或繪圖。

## 2. 目標與非目標

### 2.1 目標

1. 用單一管線統一搜尋、贅字、Mention 與後續診斷的範圍處理。
2. 以 Ring 0–8 建立可預期、可測試的重疊規則。
3. 同一段文字可同時保留不同視覺通道，例如「搜尋背景 + Mention 前景色」。
4. 所有非同步結果皆使用 document revision 防止過期回寫。
5. 對中日韓文、組合字與 emoji 保持 Dart 游標位置一致。
6. 在 Rust 不可用、crash 或結果逾時時，編輯器仍可編輯並回退至 Dart 路徑。

### 2.2 非目標

- 不用 Rust 取代 Flutter `EditableText`、`CodeField` 或 `TextPainter`。
- 不在 FFI 內傳遞 Flutter `Color`、`TextStyle` 或 widget。
- 不將突破效能當成導入 Rust 的預設結論；必須以 benchmark 驗證。
- v1 不定義 Mention 的完整輸入 UI、後端協作或專案檔遷移。
- v1 不支援任意 HTML/CSS 或完整文件格式。

## 3. 名詞

- **Annotation**：由搜尋、贅字、Mention 或診斷產生的區間標註。
- **Ring**：數值越小、優先級越高的樣式層級，範圍為 0–8。
- **Style channel**：可獨立仲裁的樣式屬性，包含 foreground、background、weight、decoration 與 interaction。
- **RenderRun**：一段連續、且最終樣式完全相同的 UTF-16 區間。
- **Semantic token**：如 `search.current.background` 的主題鍵，由 Flutter 解析成實際顏色與樣式。
- **Revision**：單一文件內單調遞增的 `u64`，代表文字版本。

## 4. Ring 優先級

### 4.1 規則

1. Ring 範圍固定為 0–8，`0` 最高，其後依序為 `2` > `4` > `6` > `8`。
2. `1`、`3`、`5`、`7` 為協定保留值；正式功能不得佔用。
3. 數值越小者在「同一 style channel」衝突時勝出，不同 channel 可同時存在。
4. 同 Ring、同 channel 衝突時，較小的 `source_order` 勝出；再相同時由字典序較小的 `annotation_id` 勝出。結果必須可重現。
5. 未知 Ring 或保留 Ring 在 release mode 必須拒絕，不得悄悄降級。

### 4.2 預設分配

| Ring | 狀態 | 預設用途 | 建議視覺 | 備註 |
| ---: | --- | --- | --- | --- |
| 0 | 使用 | 目前聚焦的搜尋結果 | 強調背景 + 高對比前景 | 只允許一個 active match |
| 1 | 保留 | 未指定 | — | 僅可在明確版本協定後啟用 |
| 2 | 使用 | 一般搜尋結果 | 次強調背景 | 與 Ring 0 共用 match id |
| 3 | 保留 | 未指定 | — | 同上 |
| 4 | 使用 | Mention | 語意前景色 + 底線 | v1 可僅接收外部範圍 |
| 5 | 保留 | 未指定 | — | 同上 |
| 6 | 使用 | 贅字 | 警示前景色或波浪底線 | 不應遮蓋搜尋背景 |
| 7 | 保留 | 未指定 | — | 同上 |
| 8 | 使用 | 一般校對、標點或 fallback annotation | 低強度底線 | 最低優先級 |

Ring 是協定常數，不得讓使用者在主題設定中重新排序。使用者可改變 semantic token 對應的顏色，但不可破壞衝突規則。

### 4.3 衝突範例

Mention 與搜尋結果重疊時：

- background channel 來自 Ring 2 搜尋結果。
- foreground 與 underline channel 來自 Ring 4 Mention。
- 若該搜尋結果為當前項，background 改由 Ring 0 接管。
- 如果 Ring 0 也明確指定 foreground，則它在 foreground channel 中覆蓋 Mention。

## 5. 系統邊界與架構

```text
Flutter editor
  ├─ text/edit events + query + external annotations
  ├─ debounce/coalesce + revision ownership
  └─ Rhodanthe bridge
       └─ Rust worker
            ├─ UTF-16/UTF-8 offset map
            ├─ search matcher
            ├─ filler-word matcher
            ├─ mention adapter
            ├─ Ring/channel arbiter
            └─ RenderPlan
                 └─ Flutter TextSpan adapter
```

### 5.1 Rust 負責

- 維護每份文件的文字快照、revision 與 offset map。
- 執行搜尋、贅字比對與後續 Mention 解析。
- 驗證、正規化、排序與上限範圍。
- 按所有 boundary 切割區間，並逐 channel 套用 Ring 仲裁。
- 合併相鄰且樣式相同的 run。
- 回傳不含字串切片的 UTF-16 ranges，避免回傳重複文字。

### 5.2 Flutter 負責

- 擁有 `TextEditingValue`、selection、composing range 與文件生命週期。
- 發送快照或合併後的 edits，並分配 revision。
- 僅採用 `response.revision == currentRevision` 的結果。
- 將 semantic token 解析為 Material theme 的 `TextStyle`。
- 依 `startUtf16` / `endUtf16` 建立 `TextSpan`，保留 IME 的 composing style。
- 處理 Mention 點擊、tooltip、焦點與無障礙語意。
- 管理 Dart fallback 與引擎降級。

### 5.3 Bridge

- 建議使用 `flutter_rust_bridge` 產生 Dart/Rust bindings，對外 DTO 保持簡單整數、字串、enum 與連續 list。
- Rust core 不得依賴 Flutter bridge；bridge 必須是可替換的 adapter。
- 一次 request 必須同時處理啟用的所有 analyzer，不得為搜尋、贅字、Mention 各自跨一次 FFI。
- native v1 目標為 Windows、macOS、Linux、Android 與 iOS。Web 保留 Dart fallback，直到 WASM adapter 通過相同 contract tests。

## 6. 資料協定

以下為規範層級的 Rust 形狀；實際 bridge 可產生等價 DTO。

```rust
pub type Revision = u64;

#[repr(u8)]
pub enum Ring {
    Critical = 0,
    Search = 2,
    Mention = 4,
    Filler = 6,
    Diagnostic = 8,
}

pub struct Utf16Range {
    pub start: u32,
    pub end: u32, // exclusive
}

pub enum StyleChannel {
    Foreground,
    Background,
    Weight,
    Slant,
    Decoration,
    Interaction,
}

pub struct StylePatch {
    pub foreground: Option<String>,
    pub background: Option<String>,
    pub weight: Option<String>,
    pub slant: Option<String>,
    pub decoration: Option<DecorationSpec>,
    pub interaction: Option<String>,
}

pub struct Annotation {
    pub annotation_id: String,
    pub source: String,
    pub source_order: u32,
    pub ring: Ring,
    pub range: Utf16Range,
    pub style: StylePatch,
    pub payload_id: Option<String>,
}

pub struct RenderRun {
    pub range: Utf16Range,
    pub style_token_set_id: u32,
    pub annotation_ids: Vec<String>,
}

pub struct RenderPlan {
    pub document_id: String,
    pub revision: Revision,
    pub text_len_utf16: u32,
    pub runs: Vec<RenderRun>,
    pub token_sets: Vec<StylePatch>,
    pub status: AnalysisStatus,
}
```

### 6.1 不變條件

1. 所有 range 為 `[start, end)`，且使用 UTF-16 code-unit offset。
2. `0 <= start < end <= text_len_utf16`；空區間不輸出。
3. `RenderRun` 依 `start` 升冪、不重疊，且不得切斷 surrogate pair。
4. 無樣式區間可省略；Flutter 以 base style 顯示。
5. 相鄰、`style_token_set_id` 與 annotation metadata 相同的 run 必須合併。
6. 顏色值不跨 FFI；僅傳 semantic token，以支援深淺主題與無障礙配色。

### 6.2 請求類型

```text
OpenDocument(documentId, revision, fullText)
ApplyEdits(documentId, baseRevision, revision, edits[])
Analyze(documentId, revision, options, query?, externalAnnotations[], budget)
SetActiveMatch(documentId, revision, annotationId?)
CloseDocument(documentId)
```

`ApplyEdits` 的每筆 edit 包含 UTF-16 `range` 與 `replacement` 。如 `baseRevision` 不符，Rust 必須回傳 `RevisionMismatch` 要求完整快照，不可自行猜測或套用。

## 7. 功能規格

### 7.1 搜尋

- 保留現有選項：大小寫、全字、正規表達式、全形半形、略過標點、略過空白。
- 一般結果使用 Ring 2；當前結果只在樣式仲裁時動態提升為 Ring 0，不重新掃描內文。
- match id 必須在文字與 query 未變時穩定，格式建議為 `search:<queryRevision>:<ordinal>`。
- 預設最多回傳 2,048 個可視高亮，但可另外回傳總數與 `truncated = true`。
- 正規表達式必須有輸入長度、時間與結果數上限；逾時不得阻塞編輯。
- query 為空字串時立即清除 Ring 0/2 annotation。

### 7.2 贅字

- 詞庫輸入為已正規化的詞條集合，引擎應使用 Aho–Corasick 或等價的多模式單次掃描。
- 預設區分大小寫，並沿用專案的寬度正規化規則；任何正規化都必須保留 offset map。
- 詞條彼此重疊時，統計採用 `leftmost-longest`；除錯 metadata 可保留所有同起點候選，但視覺範圍不得重複計數。
- 視覺使用 Ring 6。預設 token 為 `filler.foreground` 與 `filler.decoration`。
- 點擊贅字結果只改變 Flutter selection，不將該項提升到 Ring 0；如需焦點樣式，應另建正式 Ring 協定。

### 7.3 Mention（預留）

- Mention annotation 預設使用 Ring 4。
- 最小 payload 包含 `mentionId`、`entityId`、`displayText`、`entityType` 與可選 `resolved`。
- v1 只要求引擎接受由 Flutter/domain layer 提供的 UTF-16 range 與 payload id，不要求引擎來源解析。
- 未解析 Mention 使用 `mention.unresolved.*`，已解析使用 `mention.resolved.*`。
- Mention 互動是 Flutter 責任；Rust 只回傳 `interaction = "mention:<mentionId>"`。
- 編輯交叉 Mention 邊界時，domain layer 必須選擇「擴張」、「縮短」或「解除 Mention」；Rhodanthe 不自行修改內文。

### 7.4 高亮與變色

必須支援以下 semantic style channel：

| Channel | Flutter 對應 | 仲裁方式 |
| --- | --- | --- |
| foreground | `TextStyle.color` | 最高優先 Ring 勝出 |
| background | `TextStyle.backgroundColor` | 最高優先 Ring 勝出 |
| weight | `TextStyle.fontWeight` | 最高優先 Ring 勝出 |
| slant | `TextStyle.fontStyle` | 最高優先 Ring 勝出 |
| decoration | `decoration`, `decorationStyle`, `decorationColor` | 一組原子屬性，由最高優先 Ring 勝出 |
| interaction | recognizer/overlay metadata | 最高優先 Ring 勝出 |

主題必須同時提供 light、dark 與 high-contrast 變體。不得只依賴色相區分贅字與 Mention；至少有一個類型同時使用底線樣式或 font weight。

#### 7.4.1 支援的樣式白名單

| 樣式 | 支援值 | 用途與限制 |
| --- | --- | --- |
| 文字前景色 | semantic color token | 文字變色；實際 ARGB 由 Flutter theme 解析 |
| 背景高亮 | semantic color token | 搜尋、焦點結果或狀態強調 |
| 字重 | `regular`、`medium`、`semibold`、`bold` | 對應 Flutter `w400`、`w500`、`w600`、`w700` |
| 字型傾斜 | `normal`、`italic` | 不改變字型家族 |
| 裝飾線位置 | `underline`、`overline`、`lineThrough` | 單一 decoration 可包含一個或多個位置 |
| 裝飾線樣式 | `solid`、`double`、`dotted`、`dashed`、`wavy` | 對應 Flutter `TextDecorationStyle` |
| 裝飾線顏色 | semantic color token | 與前景色獨立仲裁 |
| 裝飾線粗細 | `1.0`–`3.0` multiplier | 超出範圍時 clamp，預設 `1.0` |
| 交互提示 | semantic interaction token | 例如 `mention:<id>`；由 Flutter 建立點擊、hover、tooltip 與無障礙行為 |

Decoration 是一組原子樣式，資料形狀等價於：

```rust
pub struct DecorationSpec {
    pub lines: Vec<DecorationLine>,
    pub style: DecorationStyle,
    pub color: String,
    pub thickness: f32,
}
```

不同 Ring 不會分別覆蓋 decoration 的位置、線型、顏色或粗細；最高優先的完整 `DecorationSpec` 勝出，避免組合出無法預期的線條。

#### 7.4.2 各 Ring 預設樣式

| Ring / 狀態 | Foreground | Background | Weight | Slant | Decoration | Interaction |
| --- | --- | --- | --- | --- | --- | --- |
| Ring 0／目前搜尋 | `search.current.foreground` | `search.current.background` | `semibold` | 繼承 | 無 | 無 |
| Ring 2／其他搜尋 | 繼承 | `search.match.background` | 繼承 | 繼承 | 無 | 無 |
| Ring 4／已解析 Mention | `mention.resolved.foreground` | 無 | `medium` | 繼承 | `underline/solid` | `mention:<id>` |
| Ring 4／未解析 Mention | `mention.unresolved.foreground` | 無 | `medium` | `italic` | `underline/dashed` | `mention:<id>` |
| Ring 6／贅字 | `filler.foreground` | 無 | 繼承 | 繼承 | `underline/wavy` | `filler:<id>` |
| Ring 8／一般診斷 | 繼承 | 無 | 繼承 | 繼承 | `underline/dotted` | `diagnostic:<id>` |

「繼承」表示該 annotation 不提供此 channel，使用基礎編輯器樣式或其他 Ring 的仲裁結果；「無」表示此功能的預設樣式不產生該效果，亦不會清除其他 Ring 的效果。

#### 7.4.3 v1 明確不支援的樣式

| 不支援項目 | 原因 |
| --- | --- |
| 字型家族 | 可造成字形寬度、fallback 與 CJK 字體不一致 |
| 字體大小 | 會改變行高與換行，不適合即時診斷標註 |
| 行高、字距、字詞間距 | 會使 layout 與游標定位抖動 |
| baseline shift、上標、下標 | 不在搜尋、贅字、Mention 的 v1 範圍 |
| 陰影、模糊、漸層 | 可讀性與 paint 成本高，且無必要的語意價值 |
| `WidgetSpan` 或內嵌圖示 | 會影響文字 offset、selection 與 IME；Mention 圖示應由 overlay 處理 |
| 任意 RGBA 或任意 Flutter `TextStyle` | 破壞主題、無障礙與 FFI 的平台中立性 |

## 8. 即時、增量與競態規則

1. Flutter 每次文字修改立即增加 revision，但可在 35–75 ms 視窗內合併 edits 後才跨 bridge。
2. 一份 document 同時只允許一個可發佈的 analysis generation；新 request 使舊 request 失效。
3. Rust 工作執行緒不得回呼 Flutter UI。
4. Flutter 不等待新 plan 才接受輸入；編輯始終優先。
5. 文字修改後，舊 plan 可暫時顯示，但 Flutter 必須先對交叉 edit 的 runs 做失效處理，不得將過期樣式錯套到新文字。
6. 完整快照只用於 open、revision mismatch、引擎恢復或增量編輯超過門檻；平常使用 `ApplyEdits`。
7. 關閉文件必須釋放 Rust 端文字、matcher 與 cache。

## 9. 效能預算與降級

以 release/profile build、中等筆電 CPU 的單章節基準測試：

| 情境 | 目標 |
| --- | ---: |
| 100 KiB 文字、單點編輯的 Rust 增量分析 p95 | ≤ 8 ms |
| 100 KiB 文字的 Rust 完整分析 p95 | ≤ 30 ms |
| 1 MiB 文字的 Rust 完整分析 p95 | ≤ 150 ms |
| 輸入至正確高亮可見 p95（100 KiB） | ≤ 75 ms |
| UI isolate 因 Rhodanthe 連續停頓 | < 16 ms |
| 預設可視 annotations | 每類 ≤ 2,048 |

這些是驗收門檻，不是導入 Rust 後自動成立的保證。測試必須分開記錄 Rust compute、bridge encode/copy、Dart adapter、`TextSpan` build 與 Flutter frame time。

降級順序：

1. 超過預算時先截斷 Ring 8。
2. 再截斷 Ring 6，但保留統計的 `truncated` 訊號。
3. Mention 由外部 annotation 提供時保留 Ring 4。
4. Ring 0/2 搜尋結果最後才降級，仍受 2,048 筆上限。
5. 引擎錯誤或逾時時切回 Dart fallback，並以非阻斷狀態提示；不得導致無法輸入。

## 10. 錯誤、安全與隱私

- 公開錯誤碼至少包含 `DocumentNotOpen`、`RevisionMismatch`、`InvalidRange`、`ReservedRing`、`BudgetExceeded`、`RegexRejected`、`Cancelled` 與 `Internal`。
- Rust FFI boundary 必須阻擋 panic，轉為結構化錯誤；不可 unwind 穿越 FFI。
- 日誌預設不記錄內文、query、Mention display text 或詞庫內容。只可記錄 byte/code-unit 長度、計數、revision、耗時與錯誤碼。
- regex 使用有限狀態或可中斷引擎；不允許未受限制的回溯阻塞 worker。
- 所有數量與長度在 allocation 前先檢查上限，並對整數加法使用 checked arithmetic。

## 11. 測試與驗收

### 11.1 Rust core

- Ring 排序、同 Ring deterministic tie-break 與逐 channel 仲裁。
- 交疊、嵌套、相鄰、零長度、越界與重複 annotation。
- UTF-16/UTF-8 offset property tests：中文、日文、韓文、emoji、ZWJ、combining marks、換行。
- 增量結果與完整重算結果的 property-based equivalence。
- 搜尋選項與現有 Dart 行為的 golden tests。
- 贅字重疊、leftmost-longest、統計與截斷。
- fuzz request decoder、range validation 與 regex 限制。

### 11.2 Flutter adapter

- `RenderPlan` 轉 `TextSpan` 的 golden/widget tests。
- 過期 revision 必須被丟棄。
- composing range 與 selection 不被高亮破壞。
- light、dark、high-contrast 主題下的 semantic token 映射。
- Rust 失敗、逾時、未載入與中途 crash 的 fallback。

### 11.3 必要驗收情境

1. 「目前搜尋 + Mention + 贅字」三者重疊，結果符合逐 channel Ring 仲裁。
2. 連續輸入 A → B → A 時，舊 revision 不得來回覆蓋新結果。
3. emoji 前後的搜尋、贅字與 Mention 範圍皆對準。
4. 2,049 個搜尋結果會截斷高亮但回報 truncated，編輯器仍可操作。
5. Rust 關閉後 Dart fallback 結果與基準功能一致。

## 12. 導入路線

### Phase 0：基準與 contract

- 保留現有 `HighlightTextEditingController` 為基準。
- 補齊 100 KiB、500 KiB、1 MiB 的 Dart sync、Dart isolate、Rust bridge 與完整 frame benchmark。
- 先實作 DTO、UTF-16 range contract 與 Ring arbiter tests。
- 設定 feature flag：`rhodantheEnabled`、`rhodantheShadowMode`。

### Phase 1：Shadow mode

- Rust 分析結果不顯示，僅與 Dart 結果比對 ranges、優先級與耗時。
- 差異日誌不得包含原文，只記錄 range 與類型。
- contract tests 與效能門檻通過後才可進入 Phase 2。

### Phase 2：搜尋與 RenderRun

- 先切換 Ring 0/2，Flutter 開始消費 `RenderPlan`。
- 保留 Dart 搜尋 fallback 與一鍵關閉。
- 將現有 `buildTextSpan()` 的 boundary 與優先級工作移出 UI isolate，但仍在 Flutter 建立 `TextSpan`。

### Phase 3：贅字與診斷

- 合併贅字、標點與校對的單次分析。
- 將現有 Ring 8 相容診斷接入相同 RenderPlan。
- 檢查詞庫更新、cache 釋放與大文件截斷行為。

### Phase 4：Mention

- 本輪明確排除 Mention 功能；Ring 4 僅保留 protocol 相容性，不提供 UI、專案儲存或編輯器互動。

### Phase 5：原生封裝

- Windows／Linux desktop build 由 CMake 呼叫 Cargo 並將動態函式庫安裝到應用程式輸出。
- CI 與 mobile／Apple staging 使用 `tool/build_rhodanthe_native.dart`，平台細節記錄於 `rust/PACKAGING.md`。

### Phase 6：啟動預檢

- worker 啟動後驗證 ABI、contract version 與 rollout mode 所需 capabilities。
- 預檢失敗不得進入 native 分析，並保留可觀測的 health snapshot。

### Phase 7：可重複 benchmark

- 分開量測 raw FFI、worker round trip、TextSpan build 與 Flutter layout。
- 100 KiB、500 KiB、1 MiB 統一輸出 JSON p50／p95／max；native 另記錄 RSS delta。

### Phase 8：Circuit breaker

- 連續三次分析失敗後開路 30 秒，期間直接使用 Dart fallback。
- 冷卻後允許一次 half-open retry；成功清零錯誤，失敗重新開路。

### Phase 9：Release acceptance

- Windows debug build 必須包含 `rhodanthe_bridge.dll`，Rust、Dart 與 Flutter 測試必須全數通過。
- release/profile benchmark 未達門檻時維持 `RHODANTHE_MODE=disabled`，不得預設開啟。

### Phase 10：Compact bridge

- `compactAnalysisV1` 由 handshake capability 協商；Dart analyze 預設要求 compact response。
- 搜尋範圍使用 flat UTF-16 start/end pairs，RenderRun 使用 start/end/token triples，不重送 analyzer annotations 與 annotation IDs。
- 舊 map response 仍可用 `compactResponse=false` 取得，維持 contract v1 相容路徑。

### Phase 11：Release benchmark gate

- `benchmark/rhodanthe_native_benchmark.dart --gate` 對 worker round trip 強制 p95：100 KiB ≤ 75 ms、500 KiB ≤ 100 ms、1 MiB ≤ 150 ms。
- gate 失敗必須回傳非零 exit code；不得在同時執行其他 CPU-heavy 工作時採信結果。

### Phase 12：Canary rollout guard

- Shadow 至少累積 100 筆完成樣本，Search canary 至少 500 筆。
- mismatch、timeout、fallback 或 p95 > 75 ms 都阻止升級；stale work 不列入分母。
- guard 只輸出下一個 build-time mode 建議，不得在執行中的 editor session 自動升級。

### Phase 13：Persistent rollout evidence

- SharedPreferences 只保存 bounded observation window：mode、elapsed、execution status、exact-match 與 published；不得保存內文、query、document ID、annotation payload 或 revision。
- Shadow 與 Search canary 樣本必須依 mode 分開計數，不得用 Shadow 樣本直接滿足 Search canary 門檻。
- evidence 以 `RHODANTHE_BUILD_ID` 隔離；build ID、schema version 不符或 JSON 損毀時安全清除，不阻止編輯器啟動。
- 寫入採 5 秒 debounce，editor dispose 前 flush，並提供不含內容的 JSON audit summary。

### Phase 14：Time-bounded evidence

- evidence schema v2 必須保存 UTC observation time，只採最近 7 天樣本。
- 超過目前時間 5 分鐘的 observation 視為不可信時鐘偏移並移除；過期／未來樣本不得進入 retained count 或 p95。
- schema v1 自動失效，不得和 v2 混用。

### Phase 15：Manual rollback recommendation

- Search canary 出現 failure 或 mismatch 時建議回到 Shadow；Full 出現 failure、mismatch 或 latency regression 時建議回到 Search canary。
- rollback 與 promotion 都只輸出 privacy-safe audit，不得在 runtime 自動更改 `RHODANTHE_MODE`。

### Phase 16：Audit report gate

- `tool/check_rhodanthe_rollout.dart` 驗證 evidence version、build ID、mode metrics 與 required recommendation。
- 合格回傳 exit 0；build／recommendation 不符回傳 exit 1；參數、格式與檔案錯誤使用獨立非零 exit code。
- CI 必須保存 audit JSON artifact，且只接受與待發布 binary 相同的 immutable `RHODANTHE_BUILD_ID`。

### Phase 17：Full soak default-on gate

- Full → default-on 必須累積獨立的 500 筆 Full 樣本，零 failure、零 mismatch 且 p95 ≤ 75 ms。
- audit 必須同時驗證 decision reason 與 metrics；`insufficientSamples` 即使推薦模式仍為 Full，也不得視為通過。
- audit 內的 policy 不得把 production minimum 放寬到 Shadow < 100、Canary／Full < 500 或 p95 > 75 ms。

### Phase 18：Release stage contract

- build-time stage 固定為 `off → shadow → search → full → default-on`；Full 與 default-on 使用相同 runtime 功能集，但保留不同發布語意。
- `RHODANTHE_RELEASE_STAGE` 為新 artifact 的標準入口；`RHODANTHE_MODE` 只保留為明確 compatibility override。
- 未提供 define 時仍為 `off`，不得因新增 stage contract 改變既有使用者路徑。

### Phase 19：Evidence-bound build preparation

- `tool/prepare_rhodanthe_rollout.dart` 將 stage、immutable target build ID、platform 與 build mode 轉為固定 Flutter build arguments。
- Search、Full、default-on 分別只接受 Shadow、Search、Full source binary 的合格 audit；build ID 不符或 gate 未過時不得執行 build。
- CLI 預設 dry-run，只有明確傳入 `--execute` 才啟動 Flutter build。

### Phase 20：Opening verification

- 四階段 transition、弱化 policy 拒絕、Full 樣本不足拒絕、build ID 隔離與 build arguments 必須有自動測試。
- Shadow／Search CLI dry-run 與既有 audit CLI fixture 必須實際通過。
- 完整 Rhodanthe Flutter test suite、targeted analyzer 與 Windows profile artifact 必須通過後，才開始收集真實 Shadow evidence。

### Phase 21：Observable sample progress

- rollout decision 必須包含 required、completed、remaining samples 與 0–100% bounded progress。
- audit JSON 同步輸出上述欄位，讓 CI 與人工檢查不必自行推算門檻。

### Phase 22：Sparse rollout notices

- runtime 只在 25%、50%、75% 各輸出一次進度，避免每次分析都污染 log。
- promotion、rollback 與 Full `default-on readiness` 各輸出一次 terminal notice 與完整 privacy-safe audit。
- Full 到達健康門檻時，即使 `recommendedMode` 仍為 Full，也必須輸出 default-on readiness，不得被「模式未改變」邏輯忽略。

### Phase 23：Release receipt

- rollout preparation 可用 `--receipt <path>` 保存 schema-versioned JSON receipt。
- receipt 包含 UTC 產生時間、source evidence、source／target build ID、目標 stage 與實際 Flutter arguments；不得包含原文、query 或 document ID。
- gate 未通過時不得產生 receipt，也不得執行 build。

### Phase 24：Operational rebuild

- progress、notice deduplication、Full readiness 與 receipt 必須有自動測試。
- analyzer、完整 Rhodanthe suite、receipt CLI 與 Windows Shadow Profile build 必須重新通過。

### Phase 25：Stable installation cohort

- 第一次進入非 off stage 時產生並持久保存 0–99 random bucket，後續 stage 重用同一 bucket。
- bucket 不得由帳號、硬體、project、document 或文字內容衍生，也不得保存其他識別資料。
- 無效或超界 bucket 必須安全重建；儲存失敗時維持 disabled，不可不受控地加入 Canary。

### Phase 26：Stage-aware effective mode

- Shadow 與 default-on 固定 100%；Search／Full Canary 預設 10%，可在 build-time 明確設定 1–100%。
- Search 未入選者維持 Shadow；Full 未入選者維持 Search；入選判斷為 `bucket < percentage`。
- observation 與 evidence 必須使用 effective mode 計數，不可誤用 artifact 的 target stage。

### Phase 27：Cohort-bound release receipt

- release preparation 必須將 `RHODANTHE_CANARY_PERCENT` 寫入 Flutter arguments 與 receipt。
- Shadow／default-on 若不是 100%，或 Canary percentage 不在 1–100，CLI 必須拒絕。
- legacy `RHODANTHE_MODE` 只供本機診斷 override，正式 release artifact 使用 stage + cohort contract。

### Phase 28：Canary integration verification

- cohort persistence、邊界選取、Search fallback、Full fallback、無效 bucket 修復與 percentage validation 必須有自動測試。
- 完整 Rhodanthe suite、targeted analyzer、CLI dry-run／receipt 與新的 immutable Shadow build 必須通過。

### Phase 29：Default enablement

- 標準 build 未提供任何 define 時，`RHODANTHE_RELEASE_STAGE` 預設為 `default-on`，effective mode 為 Full。
- Full 預設發布 Ring 0／2 搜尋、Ring 6 贅字與 Ring 8 診斷；Mention 仍明確排除。
- `RHODANTHE_MODE=shadow|search|full|disabled` 繼續作為明確 override，不得移除既有診斷能力。

### Phase 30：Emergency kill switch

- `RHODANTHE_KILL_SWITCH=true` 必須高於 mode override 與 release stage，強制 effective mode 為 disabled。
- kill switch 或任一 native startup／runtime failure 都維持 Dart fallback，不得阻止編輯器輸入。

### Phase 31：Enablement verification

- 自動測試必須證明標準設定為 default-on／Full、kill switch 最高優先、override 可降級及未知 stage fail closed。
- 本次依產品指示直接啟用；不得將自動測試樣本記錄成 production rollout evidence，既有 evidence gate 保留供監控與 rollback。

### Phase 32：Enabled artifact

- Windows Profile artifact 必須以新的 immutable build ID 並明確帶 `RHODANTHE_MODE=full` 建置。
- 完整 Rhodanthe suite、targeted analyzer、native DLL packaging 與 Full artifact build 必須通過。

## 13. 建議檔案佈局

```text
dart_edition/
├─ rust/
│  ├─ Cargo.toml                 # workspace
│  ├─ rhodanthe-core/           # 純 Rust，無 Flutter 依賴
│  ├─ rhodanthe-analyzers/      # search/filler/mention adapters
│  └─ rhodanthe-bridge/         # FFI DTO 與 generated bindings
├─ lib/
│  └─ infrastructure/rhodanthe/
│     ├─ rhodanthe_client.dart
│     ├─ rhodanthe_text_span_adapter.dart
│     ├─ rhodanthe_theme.dart
│     └─ rhodanthe_fallback.dart
└─ test/
   └─ rhodanthe/
```

## 14. 完成定義

Rhodanthe v1 只有在以下條件全數成立時才算完成：

- Ring 0–8 的仲裁、保留值與 deterministic tie-break 已被自動測試覆蓋。
- 搜尋、贅字、Ring 8 診斷的可視行為不低於現有 Dart 版本。
- Mention Ring 4 可接收 external annotation，即使功能開關仍為關閉。
- 不會採用過期 revision，不會破壞 IME、selection 或 Unicode offset。
- 通過正確性、fuzz、widget、fallback 與 release/profile benchmark。
- 以實測證明 Rust 路徑對目標工作負載有淨收益；否則維持 Dart 為預設，Rust 繼續作為實驗功能。

## 15. 目前實作狀態

Phase 0 第一個可交付切片位於 `dart_edition/rust/rhodanthe-core`：

- 已完成 contract version、Ring enum 與保留 Ring 拒絕。
- 已完成 UTF-16 range、surrogate-pair boundary 與 semantic token 驗證。
- 已完成 foreground、background、weight、slant、decoration、interaction 逐 channel 仲裁。
- 已完成 deterministic tie-break、style token set 去重與相鄰 `RenderRun` 合併。
- 已完成 `OpenDocument`、版本化 `Analyze`、原子 UTF-16 `ApplyEdits` 與 `CloseDocument` 生命週期。
- `ApplyEdits` 已拒絕 stale revision、非遞增 revision、未排序／重疊 edit 與 surrogate-pair 切割，驗證失敗時不會部分修改文件。
- 已建立 Rust core integration tests，涵蓋 Ring、重疊、Unicode、合併、revision、edit atomicity 與錯誤路徑。
- 已完成 `rhodanthe-analyzers` literal search：大小寫、whole-word、全形半形、平／片／半形假名、略過標點與略過空白。
- 已完成 strict regexp search：使用 Rust `regex` 語法、將 byte offsets 轉回 UTF-16、略過零長度 match，並對無效 pattern 回傳結構化錯誤。
- regexp 預設限制為 512 個 UTF-16 query code units、2 Mi 個 UTF-16 input code units，以及 2,048 筆可視結果；regexp 模式維持現有 Dart 路徑的大小寫與全半形嚴格語意。
- 已完成穩定 match ID、預設 2,048 筆 cap、總數／截斷 metadata，以及 active match Ring 2 → Ring 0 提升；active match 超出 cap 時仍保持可視。
- 已完成可重用 filler trie、failure links 與多詞單次掃描，並採用全域 leftmost-longest 解決不同詞條重疊。
- 已完成 Ring 6 贅字 annotations、穩定 payload ID、有效字數／贅字率、詞條排名，以及詞條、每詞位置、總位置、annotations 與 candidates 獨立 budget。
- 已完成搜尋 + 贅字單次文件分析入口，兩種 annotations 只進行一次 Ring 仲裁並產生一份版本化 `RenderPlan`。
- 已完成 `rhodanthe-bridge` 第一版 C ABI：opaque engine handle、UTF-8 JSON command envelope、ABI／contract 握手、Rust-owned response buffer、8 MiB request cap、panic containment 與結構化錯誤。
- bridge 已支援 `handshake`、`openDocument`、`applyEdits`、單次 search + filler + external annotations `analyze` 與 `closeDocument`，同一 handle 的請求會序列化。
- bridge 會在 engine session 內快取一份 filler trie；dictionary revision 或實際詞表變更時才重建，避免每次 proofreading analysis 重建詞庫。
- Rust 驗證結果：54 項測試通過、`rustfmt --check` 通過、Clippy `-D warnings` 零警告。
- 已完成 Dart typed protocol DTO、strict response decoder、條件式 native loader 與 raw `dart:ffi` client；Dart 會複製 UTF-8 response 後立即歸還 Rust-owned buffer。
- 已完成 latest-only coordinator：新 generation 或 `invalidate()` 會立即讓舊 Future 成為 stale，timeout／bridge error 只選擇 fallback，不向編輯器事件拋出未處理錯誤。
- 已完成長駐 `RhodantheWorkerExecutor`：worker isolate 獨佔 native client／engine handle，啟動時執行 ABI + contract handshake，使用 operation ID 對應 response，並支援 ordered commands、startup／exit error propagation 與有界 dispose。
- 已完成 Flutter semantic theme：提供 light、dark、high-contrast 預設色票，也允許透過 `ThemeExtension<RhodantheTheme>` 覆寫 token。
- 已完成 `RenderPlan` → `TextSpan` adapter：驗證 contract、revision、UTF-16 長度、run 順序／重疊、style token reference、semantic color 與 surrogate-pair boundary；任何不一致都回傳單一 base-style fallback span，不發布錯位樣式。
- adapter 會將 IME composing range 加入同一套切段邊界並合併 underline，不覆蓋既有 Rhodanthe decoration；interaction 與 annotation ID 以獨立 metadata 回傳，不在 adapter 配置 recognizer。
- 已完成 editor session ownership：文件切換、Unicode-safe 單一增量 edit、revision、ordered lifecycle、latest-only analysis 與 dispose 均在 `RhodantheEditorSession` 管理；Widget 不持有 native handle。
- 已完成 `RHODANTHE_MODE=shadow|search|full` rollout：shadow 僅比對 Dart／Rust ranges，search canary 發布 Ring 0/2，full 合併 Ring 0/2/4/6/8；標準設定現為 `default-on`／Full。
- proofreading 已將贅字詞庫接入 Ring 6，並將標點／行尾等既有 ranges 轉為 Ring 8 external diagnostics；搜尋、贅字與診斷由同一次 full-mode analysis 仲裁。
- Ring 4 僅保留既有 protocol／external annotation 相容性；本輪未接入 Mention UI、專案儲存或編輯器互動，且 Mention 明確不在 rollout 範圍。
- Rhodanthe Dart/Flutter 端 75 項相關測試通過，其中包含實際載入 Windows release DLL 的 channel arbitration、worker-isolate lifecycle、compact/legacy decoding、TextSpan、theme、IME、stale revision、Unicode、default-on runtime、kill switch、shadow/canary、stable cohort、stage-aware fallback、time-bounded rollout guard、persistent build-scoped evidence、manual rollback、sample progress、default-on readiness、release receipt、default-on soak gate、release plan、audit gate、capability preflight 與 circuit breaker 測試；既有 find/replace latest-wins 與 highlight 另 5 項回歸亦通過。
- 已完成 Windows／Linux CMake Cargo build hook、跨平台 staging tool 與 native loader bundle 路徑；Windows debug app 已驗證會攜帶 `rhodanthe_bridge.dll`。
- 已完成 ABI／contract／capability 啟動預檢、health snapshot，以及連續三次失敗開路 30 秒並 half-open retry 的 circuit breaker；任何失敗仍走 Dart fallback。
- 已加入 raw FFI、worker、TextSpan build、Flutter layout 的 100 KiB／500 KiB／1 MiB JSON benchmark；native release gate 已通過，標準 runtime 已切換為 default-on／Full。
- Rust RenderPlan 仲裁已改成只驗證實際 annotation UTF-16 端點並使用 sweep-line active set，避免為全文保存邊界與逐切段掃描全部 annotation。
- 已加入 `compactAnalysisV1`：省略重複 analyzer annotations，搜尋範圍與 RenderRun 改用 flat UTF-16 arrays；legacy response 仍可選用。
- ASCII literal search 使用直接 UTF-16/byte offset 路徑，不再為每個字元建立樹狀 boundary index。
- Windows 獨立 release gate 實測 worker p95：100 KiB 32.7 ms、500 KiB 71.5 ms、1 MiB 132.2 ms，三個門檻均通過。
- 已接入 bounded rollout guard；Shadow／Search canary 分別需要 100／500 筆無 mismatch、無失敗且 p95 ≤ 75 ms 的樣本才提出下一模式建議，執行期不會自動升級。
- 已接入 SharedPreferences evidence controller：依 rollout mode 與 `RHODANTHE_BUILD_ID` 隔離、5 秒 debounce、dispose flush、損毀安全清除，並輸出 privacy-safe audit summary。
- evidence schema 已升至 v2：七天有效視窗、五分鐘 future-clock tolerance；過期與不可信未來樣本會在保存與評估前移除。
- 已加入人工 rollback recommendation 與 `tool/check_rhodanthe_rollout.dart`；CI 可驗證 build ID 和指定 promotion／rollback，錯誤時以非零 exit code 阻止發布。
- 已加入 Full soak default-on gate、`RHODANTHE_RELEASE_STAGE` 四階段 contract 與 evidence-bound `tool/prepare_rhodanthe_rollout.dart`；沒有真實前階段 evidence 時只允許建立 Shadow artifact。
- Phase 28 的 `local-shadow-phase28` Shadow artifact 已被啟用版取代；舊的 phase20／phase24／phase28 evidence 不得與新版混用。
- rollout decision 已提供樣本進度，runtime 會輸出 sparse milestones 與 Full default-on readiness；CLI 可保存 privacy-safe release receipt。
- Search／Full 已加入不含識別資料的 stable installation cohort；未入選者停留在前一安全模式，percentage 由 build arguments 與 receipt 共同固定。
- 標準 build 已依產品指示啟用 default-on／Full；`RHODANTHE_KILL_SWITCH=true` 可強制 disabled，native 失敗仍自動走 Dart fallback。本次啟用沒有偽造或補寫 production evidence。
- 已以 `RHODANTHE_MODE=full`、`RHODANTHE_BUILD_ID=local-full-enabled-phase32`、`RHODANTHE_KILL_SWITCH=false` 成功建立 Windows Profile 啟用版，AOT `app.so` 已確認包含新的 immutable build ID，並隨附 `rhodanthe_bridge.dll`。
- Rust `regex` 不支援 look-around 與 backreference；若 Dart 相容性測試需要這些語法，必須明確走 Dart fallback，不得悄悄改變語意。
- raw FFI client 為同步 API，禁止在 UI isolate 直接呼叫；仍待針對目標裝置執行 release/profile 基準並降低高密度結果的 bridge 成本。Mention 功能不在本輪範圍。
