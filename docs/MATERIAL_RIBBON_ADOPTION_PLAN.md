# MonoAshi Material Ribbon 導入評估與計畫

評估日期：2026-10-18。以下保留原始採用評估；目前已完成 Full／Moderate／Concise 三種工具列呈現、平台預設與本機設定保存，操作說明見 [統一說明文件](GUIDE.md#工具列模式)。其餘創作工作流與上游套件修正仍屬後續計畫。

目前 Full 只使用 Ribbon 命令、頁籤與群組，沒有加入 Ribbon 文字輸入控制項，也沒有接入套件的快捷鍵 registry。快捷鍵沿用 App 既有作用域，工具列執行邊界重新檢查可用與 busy 狀態，避免在目前導入範圍觸發下列已知限制。這些整合措施不代表上游缺陷已修正。

三種模式目前均保留 Ribbon 頁籤，切換模式保留選取。套件來源固定於下列 commit，專案內 `packages/material_ribbon` 僅加上指令 viewport 撐滿寬度的修正，使 Full 命令靠左；輸入與派送限制仍維持原評估。

評估基準：MonoAshi `0.9.31`、本機 HEAD `63d0704c55cd5a7bdfcc82b111b73c04d7b645b8`；套件 `material_ribbon` `1.3.0`、[commit `29833e0`](https://github.com/Heyairu/flutter_material_ribbon/tree/29833e0dbd4126e289b56119100ad1aefb648291)。本機原有未提交變更保持原狀。

## 1. 採用建議

**建議有條件採用，先做可切換的桌面正文命令區試點。** 套件已具備受控頁籤、命令模型、非同步派送、狀態、個人化與本地化，適合改善 MonoAshi 的功能可發現性。但目前實測有輸入與命令停用缺陷，應先修正再導入預設介面。

首階段保留現有功能導覽與資料架構，把 Ribbon 定位成「目前工作內容可以執行的操作」。正文工具、搜尋、標記、短語與修訂入口最值得集中整理；角色、世界、物品及時間軸先維持既有頁面與 NeonUI 工具列，待試點通過再評估頁面專用命令區。

MonoAshi 的正文持久化仍為純文字。Ribbon 的字型、顏色與 gallery 不能因此被理解成可保存的富文字格式。若提供字級或主題控制，應清楚標示為顯示設定；粗體、字色、圖片及表格等持久化格式需要另一份資料格式與協作計畫。

## 2. 相容性與整合成本

| 項目 | 現況與判斷 |
| --- | --- |
| SDK | MonoAshi 宣告 Dart `^3.12.0`，套件要求 `^3.12.1`；導入時須同步最低版本與 CI。此次本機 Flutter `3.47.7`／Dart `3.13.5` 可編譯套件測試。 |
| 執行期相依 | 套件只依賴 Flutter SDK，沒有額外狀態管理或原生外掛；Riverpod 可以繼續由宿主提供狀態。 |
| 設計系統 | 套件採用 Material Theme，但使用自有尺寸與控制項；需與 MonoAshi 的字級、Material 3、NeonUI 和高對比規範逐項驗收。 |
| 資料格式 | 單純換命令介面不需要修改 `.mnproj`、Quill 純文字契約、Rhodanthe 或協作 schema。 |
| 授權資訊 | 套件為 BSD-3-Clause；導入時依其 LICENSE 保留第三方版權、條件與免責聲明，並更新產品第三方聲明。 |
| 發布與維護 | 此次 GitHub API 查詢沒有 Release 或 Actions run，檔案樹也沒有 `.github` workflow；不能將版本字串視為已驗證發布。本次未確認 pub.dev 發布狀態，試點應固定經驗證的 commit。 |
| 文件可靠性 | `pubspec.yaml`／CHANGELOG 是 1.3.0，API 首段仍寫 1.2.0；外部接管建議亦包含已實作的舊限制，應以該 commit 的程式及測試判讀。 |

套件為單一主要實作檔，約 3,300 行，測試亦集中於一檔。這不阻止試點，但應在持續維護前加入 CI、穩定版本標記與回歸測試；避免直接追蹤浮動 `main`。

## 3. 已確認的阻擋項目與限制

### P0：先修正輸入導覽與停用檢查

1. **文字輸入被 Ribbon 導覽攔截。** 在 `RibbonGroup.controls` 放入 `RibbonTextBox`，點擊欄位後按右方向鍵，實測會切換到另一個頁籤，欄位也跟著消失。`_onKey` 在辨識焦點目標前處理方向鍵、Home、End。應只在適當的頁籤／命令焦點處理導覽，並讓文字輸入、選取、IME 與 popup 先取得所需按鍵。
2. **停用命令可經快捷鍵執行。** 對 `isEnabled: (_) => false` 的命令設定同 ID 的 `RibbonShortcut`，在 Ribbon 取得焦點後按快捷鍵，實測 handler 執行一次。`_invokeShortcut` 只檢查 shortcut 的條件，`_invoke` 沒有統一檢查 command 的 enabled／外部 busy。套件應在執行邊界檢查，宿主 dispatcher 也需重新驗證權限、章節與 I/O 狀態。

來源：[命令派送與按鍵處理](https://github.com/Heyairu/flutter_material_ribbon/blob/29833e0dbd4126e289b56119100ad1aefb648291/lib/src/material_ribbon_base.dart#L1894)。此處 P0 指 MonoAshi 導入前的必要修正，不代表已存在於現行 MonoAshi。

### P1：宿主必須接好的行為

- **編輯焦點與選取。** MonoAshi 的 AppBar 已在 pointer down 前保留編輯目標，且一般輸入框與 Quill 使用不同命令橋接。Ribbon 切頁也會主動要求焦點，直接換上可能清空 `_lastFocusedEditableNode` 或選區。須記錄「原始操作目標」，並分開處理滑鼠點擊、鍵盤進入、popup 開關與命令完成後的焦點恢復；不能把整個 Ribbon 設為不可聚焦。
- **一致的命令生命週期。** `MaterialRibbon` 的內部 `_invoke` 有 busy／error／feedback；獨立 `RibbonCommandPalette` 直接呼叫 handler，`RibbonShortcutRegistry.bindingsFor` 也直接執行 callback。所有入口須進入宿主同一個 dispatcher，由宿主管理跨入口重入、錯誤與進度。勿僅依賴單一 Ribbon widget 的 busy 集合。
- **檔案命令必須等待實際完成。** 現有 `_handleFileAction` 是 `void`，只啟動 async 方法。不能直接包成看似 async 的 Ribbon handler，否則 busy 與成功回饋會過早結束。應等待既有儲存／匯入／匯出 Future，或由 I/O provider 提供最終狀態；取消操作也要與成功區分。
- **快捷鍵作用域。** Ribbon 的 Focus 是編輯器的兄弟區域，不會自然收到正文輸入時的 Alt／F10。保留現有根層 `Shortcuts/Actions`，以宿主協調 KeyTip 的進入、退出與回焦；不要把整個編輯器包入 Ribbon 導覽 Focus。macOS 使用現有 Command 修飾鍵，Option／中文輸入及一般欄位的標準快捷鍵須有明確優先權。

來源：[現有 AppBar](../dart_edition/lib/bin/appbar.dart)、[App 整合](../dart_edition/lib/main.dart)、[Quill 命令橋接](../dart_edition/lib/features/editor/plain_text_quill_editor_poc.dart)、[命令搜尋與 registry](https://github.com/Heyairu/flutter_material_ribbon/blob/29833e0dbd4126e289b56119100ad1aefb648291/lib/src/material_ribbon_base.dart#L3239)。

### 版面與產品限制

- MonoAshi 工作區目前使用 **800 logical pixels** 斷點，Ribbon 自動窄版預設 **720**。首輪建議對齊宿主 800，並以實際容器寬度決定；桌面作業系統的小視窗也應使用窄版。
- 原始碼的預設高度為展開 **210**、窄版 **112**、收合 **52**。應取代原命令列，避免與原 56 高 AppBar 重複堆疊；低高度視窗優先收合。若調低展開高度，須連同固定高度命令與群組內容驗證，不能只改 `height`。
- 窄版只由 `compactCommands` 或 `group.commands` 產生內容，**不呈現 `group.controls`**。此次測試已確認。每個自訂欄位都需要等價的窄版命令或對話框入口。
- 一般命令與 QAT 多使用 **40** 高度，手機觸控範圍與文字放大須另行驗收。支援平台宣告不能等同觸控體驗已通過。
- 群組主要靠橫向捲動；目前沒有完整的 contextual tab set 與群組 overflow 工作流。應控制每頁命令數，情境頁籤出現時避免每次選取變動都強制切頁。

來源：[版面實作](https://github.com/Heyairu/flutter_material_ribbon/blob/29833e0dbd4126e289b56119100ad1aefb648291/lib/src/material_ribbon_base.dart#L2075)、[窄版實作](https://github.com/Heyairu/flutter_material_ribbon/blob/29833e0dbd4126e289b56119100ad1aefb648291/lib/src/material_ribbon_base.dart#L2750)。

## 4. 建議的資訊架構

| 區域 | 首階段內容 | 後續擴充 |
| --- | --- | --- |
| 快速存取工具列（QAT） | 儲存、復原、重做 | 使用者釘選常用命令 |
| 檔案選單 | 新建、開啟、另存、匯入、匯出 | 視需要再建 Backstage，初期沿用既有對話框 |
| 常用 | 剪下、複製、貼上、全選、搜尋取代、標點面板 | 章節操作，前提是已提供可重用命令介面 |
| 檢視 | 修訂面板入口、顯示字級／主題的既有設定入口 | 經驗證的工作區配置切換 |
| 校稿 | 既有校稿頁與修訂工作流入口 | 分析、差異導航與受支援的處理命令 |
| 文字選取情境 | 第二階段加入新增 Mention、存成短語 | 編輯／解除既有標記，沿用 formatter 與 offset 映射 |
| Scene／時間軸情境 | 維持現有頁面工具列 | 待頁面 adapter 完成後，再評估 placement／快照命令 |

保留 Rail／Drawer 的「角色、世界、物品、時間軸」頁面導覽；Ribbon 頁籤表達操作分類。現有游標附近的選單仍適合高頻選取操作，與上方 Ribbon 共用命令即可。

## 5. 建議的程式邊界

以下均為待新增的設計，並非目前已有的 API。

1. `AppCommandId`／命令定義：使用 `project.save`、`edit.copy`、`view.revisions.toggle` 等穩定 ID；業務命令不依賴套件型別。
2. `AppCommandDispatcher`：接收 typed payload，重新確認可執行條件與目標，等待非同步完成，統一回報取消、成功、失敗與 busy。剪貼簿針對使用者最後選定的輸入框；正文標記命令明確要求正文目標。
3. `RibbonContextAdapter`：由 Riverpod 選取目前頁面、章節、選取、組字、I/O busy 與歷史狀態，轉成精簡 `RibbonContext`。不把正文全文或整份專案塞入 `values`，避免逐字輸入重建整個 App。
4. `MonoAshiRibbon`：只處理呈現、受控 tab／collapsed 與套件事件轉接；Ribbon、命令搜尋、快捷鍵及既有選單共用 dispatcher。
5. 個人化儲存 adapter：沿用 app-local settings／SharedPreferences，版本化保存命令 ID、頁籤排序與收合偏好。使用者偏好不寫入作品 XML，也不產生協作操作。`validated` 用完整命令目錄清理舊 ID，避免切換情境時刪掉暫時不可見命令。

檔案操作沿用 `projectIoControllerProvider` 與 session coordinator；復原／重做沿用目前 project history 路徑。不要因 Ribbon 或 Quill 各有 API 就另建一套歷史堆疊。標記與短語沿用既有 raw／display offset、UUID 與 atomic selection 規則。

## 6. 分階段執行與退出條件

| 階段 | 交付內容 | 進入下一階段條件 | 粗估人日 |
| --- | --- | --- | --- |
| 0：套件修正與固定 | 修正兩個阻擋缺陷、本地化測試、CI；固定修正後 commit | 輸入／停用回歸測試與套件測試通過 | 2–3 |
| 1：桌面試點 | app-local 開關；只替換正文命令列，包含檔案、剪貼簿、搜尋、標點與 QAT | 現行工具列行為無退步；關閉開關可回到原介面 | 3–5 |
| 2：創作工作流 | Mention／短語／校稿／修訂入口、個人化、命令搜尋 | 所有入口狀態一致，選區與 Undo/Redo 正確 | 3–5 |
| 3：窄版與發布 | 等價窄版入口、觸控尺寸、跨平台焦點、放大字體與人工驗收 | 目標平台 gate 通過後再逐步調整預設 | 3–5 |

粗估合計 **11–18 人日**，假設一名熟悉現有程式的工程師且可修改此套件；這是實作評估，不是排程承諾。不含新富文字能力、全面導覽改版或所有功能頁工具列遷移。若第一階段的頻繁操作仍比原工具列繁瑣，應縮減命令與頁籤後重新評估。

## 7. 驗收清單

- 套件回歸：文字欄位方向鍵／Home／End、IME、停用命令在按鈕／KeyTip／快捷鍵／搜尋四個入口的一致性、busy 期間跨入口重入。
- 沿用並擴充 [editor_toolbar_quill_test.dart](../dart_edition/test/editor_toolbar_quill_test.dart)：Quill 與搜尋欄位切換、反向選取、Mention 原子邊界、剪貼簿投影、命令後回焦；另覆蓋 CodeField fallback。
- 檔案：匯入／匯出／另存實際完成前持續 busy；取消與失敗回饋正確；切換專案後，舊命令不提交到新 session。
- 正文：純文字存檔與往返、一次操作對應既有歷史交易、選取與顯示設定不增加 dirty／P2P delta、中文組字不被工具列打斷。
- 版面：至少涵蓋 390／799／800／1024／1440 logical pixels、低高度視窗、100%／150%／200% 文字縮放、明暗／高對比；檢查實際命令可達性。
- 平台：Windows／macOS／Linux 鍵盤操作分別驗證；觸控平台人工驗證目標尺寸、捲動與 popup；web 僅在產品發布範圍內另行驗證。
- 個人化：空 QAT、舊 schema、未知命令 ID、隱藏所有可用頁籤後的復原入口、重設偏好、重新啟動與 rollback。
- 正文輸入期間只更新必要命令狀態，避免每次按鍵重建整個工作區；在代表性大型稿件上與原工具列比較輸入與版面表現。

## 8. 本次驗證證據與範圍

在 `/private/tmp/monoashi-ribbon-eval-20261018` 以固定 commit 的 library 與原始測試建立隔離套件，重用本機 MonoAshi 已解析的 Flutter 測試相依，未執行新的 pub 解析。這證明的是上述 SDK／已解析相依組合的行為，不是套件所有宣告平台或最低 SDK 的驗證。

| 測試 | 結果 |
| --- | --- |
| 套件原始 `material_ribbon_test.dart` | 37 項：36 通過、1 失敗。失敗項為 customization panel 測試尋找中文 `下移 首頁` tooltip，但未提供中文 localizations，預設為英文；不應解讀成已證明重排功能失效。 |
| 新增隔離風險測試：欄位按右方向鍵 | 失敗，選中頁籤由 `home` 變為 `review`，重現輸入攔截缺陷。 |
| 新增隔離風險測試：停用命令快捷鍵 | 失敗，預期執行 0 次，實際 1 次。 |
| 新增隔離風險測試：窄版自訂控制項 | 通過，確認窄版不會呈現 `group.controls`；宿主需提供替代命令。 |

原始評估階段未修改上游套件、加入產品 dependency 或切換 UI，也未宣稱跨平台發布驗收完成。隔離測試位於暫存目錄，可能被系統清除；後續上游修正應將兩個失敗案例正式納入套件測試。目前三模式實作的操作契約見統一說明與 API 文件。

## 9. 參考來源

- [套件 README](https://github.com/Heyairu/flutter_material_ribbon/blob/29833e0dbd4126e289b56119100ad1aefb648291/README.md)、[pubspec](https://github.com/Heyairu/flutter_material_ribbon/blob/29833e0dbd4126e289b56119100ad1aefb648291/pubspec.yaml)、[CHANGELOG](https://github.com/Heyairu/flutter_material_ribbon/blob/29833e0dbd4126e289b56119100ad1aefb648291/CHANGELOG.md)、[LICENSE](https://github.com/Heyairu/flutter_material_ribbon/blob/29833e0dbd4126e289b56119100ad1aefb648291/LICENSE)。
- [套件測試](https://github.com/Heyairu/flutter_material_ribbon/blob/29833e0dbd4126e289b56119100ad1aefb648291/test/material_ribbon_test.dart)、[UX 差異盤點](https://github.com/Heyairu/flutter_material_ribbon/blob/29833e0dbd4126e289b56119100ad1aefb648291/MS_RIBBON_UX_GAP_ANALYSIS.md)。
- [MonoAshi 功能與架構](GUIDE.md)、[正文純文字契約](../dart_edition/QUILL_PLAIN_TEXT_EDITOR_PHASE0.md)、[NeonUI 規範](../dart_edition/NEON_UI_ICON_BUTTON_SPEC.md)。
