# Monogatari Assistant 記憶體、效能、資源與維護性稽核

評估日期：2026-07-31  
評估範圍：`dart_edition/lib`、`assets`、`pubspec.yaml`、測試／CI、現有 release/build 產物  
評估基準：目前工作樹，包含尚未提交的既有修改  
評估方式：靜態程式碼審查、生命週期配對、資料流／複雜度分析、資產與生成物實測

> 本報告把「unreachable object leak」、「仍可到達但不必要的長駐資料」、「短期配置尖峰」分開看待。這次沒有發現普遍性的 controller 永久洩漏；更大的風險來自全頁面長駐、無上限結果集合、完整專案的重複序列化／拷貝、不可取消背景工作與沒有淘汰策略的磁碟備份。
>
> 本機 Flutter SDK 未加入 PATH，且在既有 Flutter/Dart 程序運作期間，`flutter analyze --no-pub` 與直接 `dart analyze --fatal-infos` 均未在時限內完成。因此以下結論是靜態證據，不是 DevTools heap／frame profile；尚未量測的影響均使用「可能」、「最壞情況」或複雜度描述。

## 結論先行

最優先的風險不是零碎補 `dispose`，而是：

1. **Replace All 與校對 worker 會物化全部命中。** 大型重複文本可建立與文字長度同量級的物件，跨 isolate 時還可能短暫存在兩份。
2. **History 每次在 UI isolate 做三次 snapshot traversal、兩次完整 XML，並保留兩份完整 XML；其中一份完全未被使用。**
3. **14 個功能頁每個 session 一次建立。** 隱藏 BaseInfo 仍每 200 ms idle commit 同步掃全文算字數，校對頁啟用自動檢查時也會在背景工作。
4. **字數管線同一份內容可能由 UI 與 worker 重算，cache lookup 又會退化為 O(章節數²)。**
5. **AutoBackup 沒有代數、期限或總容量上限。** 啟用預設 5 分鐘間隔後，持續修改的 10 MB 專案理論上可新增約 2.88 GB／日。
6. **多條 persistence／I/O 路徑沒有 single-writer 或 session guard。** 除了 CPU、heap、磁碟尖峰，也會產生舊資料覆寫新資料、舊專案回寫新 session 的風險。
7. **唯一 CI workflow 放在錯誤目錄，實際不會被 GitHub Actions 發現。** 目前沒有可運作的 analyze、test、生成碼 freshness guard。

## 優先級總表

| 優先級 | ID | 問題 | 主要影響 |
| --- | --- | --- | --- |
| P0 | C-01 | History 重複 snapshot／XML 且保留未使用完整字串 | UI 卡頓、GC、常駐 heap |
| P0 | C-02 | Replace All 無上限建立 matches 與 prefix index | OOM、雙重全文掃描 |
| P1 | H-01 | 字數 worker 被同步 fallback 抵消，cache 加總 O(C²) | 長篇輸入卡頓、重複 CPU |
| P1 | H-02 | 校對結果在 worker／主 isolate 全量保存 | heap 尖峰、跨 isolate 傳輸 |
| P1 | H-03 | 靈感筆記每字全量 JSON 寫檔且可重疊 | I/O、配置、資料競態 |
| P1 | H-04 | AutoBackup 無保留政策且未變更也先完整序列化 | 磁碟無界成長、CPU／heap |
| P1 | H-05 | 專案 I/O 缺少共用 mutex 與 session generation | 多重序列化、跨專案競態 |
| P1 | H-06 | 游標 provider 使根畫面重建並更新全部 page wrapper | 掉幀、隱藏頁重建 |
| P1 | H-07 | 世界／詞庫保存所有 descendant closure | 退化樹 O(N²) heap／重建 |
| P1 | H-08 | 詞庫與巢狀 domain state 每字／每欄位全量深拷貝 | GC、輸入延遲、擴充性 |
| P1 | H-09 | 每次文字變更同步重建全文換行索引 | 每鍵 O(全文長度) |
| P1 | H-10 | 搜尋 compute 不可取消、舊查詢可覆蓋新結果 | isolate 疊加、錯誤 UI |
| P1 | H-11 | CharacterView 在 dispose 回寫 provider | 舊專案 draft 污染新專案 |
| P1 | H-12 | GitHub Actions workflow 位於無效位置 | 回歸無法被 CI 擋下 |
| P2 | M-01 | Copilot history／request／response 無容量 budget | heap、網路與模型成本 |
| P2 | M-02 | HTTP 不可取消、await 後 lifecycle guard 不完整 | socket 長駐、setState-after-dispose |
| P2 | M-03 | 巨型檔案、重複 codec／規則、直接循環 import | 修改成本、回歸風險 |
| P2 | M-04 | raw XML、backup baseline 等序列化陰影副本長駐 | 大型專案額外 heap |
| P2 | M-05 | 狀態列 marquee 沒有可取消單一工作鏈 | 永久動畫、重疊 continuation |
| P3 | L-01 | 生成物、機器路徑檔、dead code、全文 debug log | 磁碟、雜訊、隱私／維護 |
| P3 | L-02 | Outline rename controller 的 cleanup contract 缺口 | lifecycle hygiene |

## P0：應先處理 // OK

### C-01：History 同步重複建立完整專案表示 // OK

`ProjectHistoryEntry` 在 [`project_history_provider.dart#L16`](lib/presentation/providers/project_history_provider.dart#L16)：

- 呼叫 `snapshotProjectData` 三次；
- 呼叫完整 XML serializer 兩次；
- `_normalizeHistoryXml` 再建立一份比較字串；
- 將 `data`、`xmlContent`、`xmlComparisonKey` 同時保留。

靜態搜尋確認 `ProjectHistoryEntry.xmlContent` 除宣告／賦值外沒有任何讀取端，因此每筆都白白保留一份完整 XML。`xmlComparisonKey` 才是實際比較欄位；history 最多保留 50 筆（[`project_history_provider.dart#L52`](lib/presentation/providers/project_history_provider.dart#L52)）。

額外放大因素：

- 焦點離開任何 editable 就會嘗試記錄（[`main.dart#L319`](lib/main.dart#L319)）。
- 輸入 idle 500 ms 後記錄（[`main.dart#L517`](lib/main.dart#L517)）。
- 記錄時同步 editor 到 chapter，aggregate listener 又可能再排一筆 500 ms history（[`main.dart#L926`](lib/main.dart#L926)）；第二筆直到完成全部 snapshot／XML 後才被判定重複。
- History 使用同步 `FileService.generateProjectXML`，這條路徑不是一般 save 所使用的背景 `compute`，所以成本直接發生在 UI isolate。

以 10 MB XML 粗估，僅兩個 retained XML 欄位 × 50 筆就接近 1 GB 原始字串資料，尚未計算 object graph、正規化暫存字串與 Dart 表示成本。

建議：

1. 立即刪除未使用的 `xmlContent`。
2. 在建構 entry 前，以 project revision／dirty revision 判斷是否真的變更。
3. 一次 snapshot、一次 serialization；比較使用 stable hash，不保留第二份 XML。
4. 合併 history 排程來源，避免同一 revision 記錄兩次。
5. History 同時限制筆數與總 byte budget；中期改成 command/delta history。

驗收：10 MB 專案形成 50 筆 history 時，timeline 每筆只允許一次 snapshot／serialization；heap 不應保留 100 份完整 XML。

### C-02：Replace All 對全部匹配建立物件，沒有結果／輸出上限 // OK

`performReplaceAll` 在 [`findreplace.dart#L824`](lib/bin/findreplace.dart#L824) 呼叫 `findAllMatchesAsync` 時沒有 `maxResults`。worker 會：

- 為每筆命中建立一個 `TextSelection`；
- 再建立同長度的 `prefixMaxEnds`（[`findreplace.dart#L555`](lib/bin/findreplace.dart#L555)）；
- 將兩個完整 list 傳回主 isolate。

搜尋單一重複字元時，命中數 R 可接近文件長度 N，記憶體為 O(R) 大量物件。regex 路徑收到全部 matches 後，還在 UI isolate 再執行一次 `replaceAllMapped`（[`findreplace.dart#L856`](lib/bin/findreplace.dart#L856)），形成雙重全文掃描；輸出 bytes 與 regex 執行時間也沒有上限。

建議：

- 把「搜尋＋取代」整段放在單一 worker，以 streaming `StringBuffer` 完成，只回傳新文字、取代數與摘要。
- 設定 match count、輸出 bytes、執行時間上限；大操作先顯示預估並要求確認。
- regex 提供 timeout／可取消 worker；避免把全部 match object 傳回 UI。

驗收：10 MB 重複字元文件 Replace All 的 peak heap 應接近輸入＋輸出大小，而不是與數百萬個 match object 成正比。

## P1：高風險效能／資源問題 // OK

### H-01：字數管線重複運算，cache 加總退化為 O(C²) // OK

同一份文字目前可被多條路徑計算：

1. 隱藏 BaseInfo 在 200 ms commit 後同步掃全文。
2. 主畫面在 500 ms 後啟動 `compute`（[`main.dart#L517`](lib/main.dart#L517)、[`content_manager.dart#L20`](lib/bin/content_manager.dart#L20)）。
3. History 同步 chapter 後觸發 segments listener，立刻在 UI isolate `_recalculateSumFast`（[`main.dart#L662`](lib/main.dart#L662)、[`main.dart#L1228`](lib/main.dart#L1228)）。
4. 新內容尚未進 cache 時，`getWordCount` 又同步掃全文（[`chapter_selection_data.dart#L122`](lib/models/chapter_selection_data.dart#L122)），抵消背景 worker 的目的。

此外，每次 `getWordCount` 都先對全域 cache 執行 `removeWhere`（[`chapter_selection_data.dart#L41`](lib/models/chapter_selection_data.dart#L41)）。全書 C 章逐一加總且 cache K≈C 時為 O(C×K)，即 O(C²)，即使全部 cache hit 也要掃描。

舊一輪 `compute` 只能用 generation 忽略結果，不能取消已啟動工作；每輪最多 6 個只是 invocation 內限制，不是跨 invocation 的全域 worker pool（[`main.dart#L1151`](lib/main.dart#L1151)）。

建議：單一 word-count service；cache 使用 `(chapterId, mode) -> {contentRevision, count}` O(1) lookup；pending 時不可同步 fallback；total 以新舊 chapter count 差額增量更新；長駐 worker pool 只保留最新 revision。

### H-02：校對 UI 有分頁，但 worker result 沒有上限 // OK

Worker 會建立並回傳所有 issue list（[`proofreadingview.dart#L3587`](lib/modules/proofreadingview.dart#L3587)）。贅字 matcher 對每次命中保存 position（[`proofreadingview.dart#L4202`](lib/modules/proofreadingview.dart#L4202)、[`proofreadingview.dart#L4810`](lib/modules/proofreadingview.dart#L4810)），主 isolate 再全量保存（[`proofreadingview.dart#L945`](lib/modules/proofreadingview.dart#L945)）。

UI 的每詞 50 個位置與 2048 個 highlight 限制只限制 render（[`proofreadingview.dart#L1016`](lib/modules/proofreadingview.dart#L1016)、[`proofreadingview.dart#L3174`](lib/modules/proofreadingview.dart#L3174)），無法降低 worker heap、跨 isolate 複製或 retained result。

建議：每個 detector 都有 total result budget；worker 只回 count、前 K 個 sample 與 truncated flag；需要更多時以章節／區段分頁重跑。

### H-03：靈感筆記每字整檔寫入 // OK

標題與內容 listener 在每個字元變更時呼叫 `_saveInspirationToDisk`（[`planview.dart#L667`](lib/modules/planview.dart#L667)）。每次都重建全部 folders/notes payload、同步 `jsonEncode`、重新解析路徑並覆寫完整 JSON（[`planview.dart#L817`](lib/modules/planview.dart#L817)）。

呼叫沒有 await、debounce 或 single-writer queue。若輸入速度快於磁碟完成速度，舊 payload、JSON string、Future 與 file write 會堆疊；較舊寫入若最後完成，還會覆蓋較新內容。

建議：local draft；idle/blur debounce；latest-wins serial writer；temp file + atomic rename；dispose／專案切換前 flush。

### H-04：AutoBackup 無容量／代數／期限上限 // OK

每次內容有變便用 timestamp 建立新完整專案檔（[`file.dart#L2271`](lib/bin/file.dart#L2271)）。目前只與上一份 XML 比較（[`project_io_providers.dart#L302`](lib/presentation/providers/project_io_providers.dart#L302)），沒有 generations、age 或 total bytes 淘汰。

功能預設關閉；一旦啟用，預設間隔是 5 分鐘（[`app_state_data.dart#L25`](lib/models/app_state_data.dart#L25)）。持續修改的 10 MB 專案理論上每天新增 288 份、約 2.88 GB。

即使內容未變，也要先 snapshot 並生成完整 XML 才能比較。

建議：每專案同時設定 generations、age、total-byte 上限；寫入成功後清理；寫前檢查可用空間；用 dirty revision 在 serialization 前跳過；UI 顯示實際占用與清理入口。

### H-05：AutoSave、AutoBackup、manual save/open/new 沒有共用 session guard // OK

AutoSave 與 AutoBackup 使用不同 timer／bool（[`main.dart#L825`](lib/main.dart#L825)），manual save 又是另一條路徑（[`main.dart#L2844`](lib/main.dart#L2844)）。它們可同時 snapshot、XML serialization 與 file I/O。

更嚴重的是：舊專案 AutoSave await 期間若使用者開啟新專案，完成後仍可能把 `currentProject` 設回舊專案並標成已儲存（[`main.dart#L863`](lib/main.dart#L863)）；舊 AutoBackup 也能覆寫新 session baseline。

建議：所有 project I/O 經單一 coordinator／serial queue；切換前 await 或取消；每次 async 回寫前核對 session generation 與 project identity；同一 revision 的 save/backup 共用 snapshot／XML。

### H-06：游標移動會讓根 ContentView 重建 // OK

`_buildMobileStatusBar` 在根 `ContentView.build` 的呼叫路徑中執行 `ref.watch`：

- cursor/selection；
- 完整 segments list；
- total words。

證據在 [`main.dart#L1507`](lib/main.dart#L1507)。游標更新 provider（[`main.dart#L582`](lib/main.dart#L582)）後，根 `Shortcuts`、`Actions`、`Scaffold`、layout、editor/status wrapper 與 14 個 IndexedStack page widget configuration 都會重新建立。`select((segments) => segments)`（[`main.dart#L1523`](lib/main.dart#L1523)）沒有縮小 watched value。

建議：StatusBar 成為獨立 `ConsumerWidget`；建立只輸出 chapter label／cursor tuple 的 derived provider；navigation、editor、status 分離 rebuild boundary；用 Track Widget Builds 驗證游標移動只重建狀態列。

### H-07：世界與詞庫為每個節點保留所有後代 ID // OK

World 在每次建 index 時，為每個節點建立完整 descendant set（[`worldsettingsview.dart#L344`](lib/modules/worldsettingsview.dart#L344)）；Glossary 使用相同結構（[`glossaryview.dart#L374`](lib/modules/glossaryview.dart#L374)）。

若樹退化成 N 層鏈，會保存 `N(N-1)/2` 個 ID reference，時間與 retained heap 都是 O(N²)。World 在欄位更新後可能立即 rebuild index，provider build 又建一次；Glossary build 也無條件 rebuild（[`glossaryview.dart#L2135`](lib/modules/glossaryview.dart#L2135)）。

建議：使用 parent map 或 DFS entry/exit interval 判斷祖先；只在 tree structure 變更時更新 index；拖曳時只計算 source subtree。

### H-08：詞庫與巢狀 state 採全量 deep-copy // OK

Glossary 欄位每次 `onChanged` 直接更新 provider（[`glossaryview.dart#L1396`](lib/modules/glossaryview.dart#L1396)）。單字更新會複製 entry、完整 entry index、分類樹；`_setIfChanged` 與 persistence 排程又建立完整 snapshot（[`project_state_providers.dart#L1131`](lib/presentation/providers/project_state_providers.dart#L1131)、[`project_state_providers.dart#L1312`](lib/presentation/providers/project_state_providers.dart#L1312)、[`project_state_providers.dart#L1357`](lib/presentation/providers/project_state_providers.dart#L1357)）。Debounce 只延後寫檔，snapshot 在等待前就已配置。

相同模式也出現在：

- World：先 deep-copy 全樹，再於 setter snapshot 全樹（[`project_state_providers.dart#L502`](lib/presentation/providers/project_state_providers.dart#L502)、[`project_state_providers.dart#L678`](lib/presentation/providers/project_state_providers.dart#L678)）。
- Character：單一角色更新先 copy 全 map／entry，再由 setter copy 全 map（[`project_state_providers.dart#L797`](lib/presentation/providers/project_state_providers.dart#L797)）。
- Outline：欄位 listener 後重建完整索引／snapshot。

不是所有 provider 都會複製所有 String；問題是大型巢狀集合的 traversal/container/deep-copy。建議 normalized entity map + path-copying，未變子樹維持 identity；表單先 local draft、idle/blur 才 commit。

### H-09：每次文字變更同步重建全文換行索引 // OK

Editor controller listener 每次文字不同都呼叫 `rebuildIfTextChanged`（[`main.dart#L554`](lib/main.dart#L554)）。`TextPositionIndex` 從頭掃全文並配置 newline offset list（[`text_position_index.dart#L13`](lib/utils/text_position_index.dart#L13)），每鍵 O(全文長度) 且發生在 UI isolate。

建議：依 `TextEditingDelta` 增量更新受影響區段；至少對大文件 debounce；小文件才走同步全文路徑。

### H-10：搜尋背景工作不具 latest-wins // OK

Find bar 的 100 ms debounce 只能取消尚未開始的 timer（[`findreplace.dart#L1544`](lib/bin/findreplace.dart#L1544)）。一旦 `compute` 啟動便不可取消（[`findreplace.dart#L916`](lib/bin/findreplace.dart#L916)）；主畫面 await 後只檢查 `mounted`，沒有比對 query、options 或 text revision（[`main.dart#L1911`](lib/main.dart#L1911)）。

大型文件中多個搜尋可同時保留全文與結果；慢的舊 regex 可能最後回來，覆蓋新查詢。

建議：不可變 request snapshot + generation；單一長駐 worker/latest-only queue；回寫前核對完整 request；regex 設時間／資源上限。

### H-11：CharacterView.dispose 可能把舊 draft 寫進新專案 // OK

CharacterView 在 debounce 尚 active 時，`dispose` 會呼叫 `_saveCurrentCharacterData`（[`characterview.dart#L1464`](lib/modules/characterview.dart#L1464)）。專案切換的 `setState` 先套用新 provider data，舊 keyed subtree 到下一次 build 才 dispose（[`main.dart#L2652`](lib/main.dart#L2652)）。

因此「編輯角色後一秒內切換專案」可讓舊 view 在 dispose 時讀取新專案 provider，並把舊 draft 寫入新專案（[`characterview.dart#L2440`](lib/modules/characterview.dart#L2440)）。

建議：切換前明確 flush 舊 session；dispose 只 cancel、不改 provider；所有 draft save 帶 session ID。

### H-12：唯一 GitHub Actions workflow 實際不會執行 // OK

Git repo root 是 `Monogatari-Assistant-FE`，但唯一 workflow 放在 [`dart_edition/.github/workflows/state-policy-guard.yml`](.github/workflows/state-policy-guard.yml)。GitHub Actions 只掃描 repo root 的 `.github/workflows`，所以目前完全不會發現它。

即使移到 root，現有 path filter 仍是 `lib/**`／`pubspec.yaml`，command 也沒有 `working-directory: dart_edition`（[`state-policy-guard.yml#L5`](.github/workflows/state-policy-guard.yml#L5)、[`state-policy-guard.yml#L35`](.github/workflows/state-policy-guard.yml#L35）。

建議：

- 移到 repo root `.github/workflows/`；
- path 全部加 `dart_edition/`；
- 設定 working directory；
- 至少執行 format check、`flutter analyze`、`flutter test`、build_runner generate + clean diff；
- 另加大型資料 benchmark／memory regression job。

## P2：中等風險與維護成本 // OK

### M-01：Copilot 對話與 payload 無 budget // OK

`_messages` 沒有自動上限（[`copliot.dart#L127`](lib/modules/copliot.dart#L127)），每次 request 將完整歷史 JSON encode 並傳送（[`copliot.dart#L441`](lib/modules/copliot.dart#L441)），response 也完整 buffer／decode。使用者可手動 clear，但沒有 message、byte、token 或 response budget；頁面又是 root-lifetime。

建議：UI history 與 model context 分離；context sliding window／摘要；request/response byte/token 上限；streaming response。

### M-02：HTTP／async lifecycle 管理不完整 // OK

Copilot 使用 top-level `http.get/post(...).timeout(...)`，State 沒有可 close 的 `http.Client`（[`copliot.dart#L143`](lib/modules/copliot.dart#L143)）。`Future.timeout` 停止等待，不保證中止底層 transport。

真正缺 `mounted` 的 await 後路徑位於模型讀取 [`copliot.dart#L370`](lib/modules/copliot.dart#L370)／catch，以及送出訊息 [`copliot.dart#L551`](lib/modules/copliot.dart#L551)／catch；不是 await 前的 setState。

World template load、Proofreading filler load、new/open/recent project 也有 await 後缺 lifecycle/session guard 的路徑。修正 C-03 的 lazy eviction 後，這些問題會更常暴露。

建議：State-owned cancelable client；每次 await 後檢查 mounted；交錯操作還需 generation/session identity。

Copilot 設定欄位也在每字 `unawaited(_saveSettings())`，每次依序寫四個 SharedPreferences key（[`copliot.dart#L172`](lib/modules/copliot.dart#L172)）；應 debounce 並保存 snapshot。

### M-03：大型檔案、重複邏輯與直接循環 import // OK

可重現基線：

- `lib` 64 個 Dart 檔、46,657 行；
- 手寫 56 檔、40,594 行；
- 8 個手寫檔超過 2,000 行；
- `proofreadingview.dart` 4,973 行、`characterview.dart` 3,190 行、`outlineview.dart` 3,073 行、`main.dart` 2,997 行。

具體維護風險：

- Proofreading UI state 與 worker analyzer 有至少 39 個同名 private 方法，規則容易只改一份。
- 6 個 view 各自複製 66 行 XML helper，共 396 行；其中一組已出現 `node.value`／`node.text` 差異。
- `project_state_providers.dart` 第 13–17 行 import 五個 view；這些 view 又反向 import provider，已形成至少五組直接 file-level circular import，不只是「可能有風險」。
- `domain/usecases` 直接 import data repository／`bin/file.dart`，data repository 又依賴 `bin`，layer 名稱與實際依賴方向不一致。

建議：先抽 `models/codecs` 與純 domain service，再拆 presentation；校對 UI/worker 共用唯一 analyzer；用 dependency rule 禁止 presentation/provider 與 view 互相 import。

### M-04：完整 XML 的陰影副本長駐 // OK

除 History 外：

- `ProjectFile.content` 長駐 raw XML（[`file.dart#L1084`](lib/bin/file.dart#L1084)），同時 providers 已保存解析後 object graph。
- `_lastAutoBackupContent` 保存完整 XML（[`main.dart#L271`](lib/main.dart#L271)、[`main.dart#L908`](lib/main.dart#L908)）。
- 停用 AutoBackup 只取消 timer，不清 baseline（[`main.dart#L876`](lib/main.dart#L876)）。

建議：`ProjectFile` 在 parse/write 後只保留 metadata/path；backup baseline 改 project revision／hash，停用時立即清除。

### M-05：狀態列 marquee 是不可取消的遞迴工作鏈 // OK

溢出文字使用 `ScrollController.animateTo → Future.delayed → animateTo → delay → _startScrolling()` 永久遞迴（[`statusbar.dart#L161`](lib/bin/statusbar.dart#L161)），未觀察 app inactive/minimized。`didUpdateWidget` 又會重新啟動（[`statusbar.dart#L130`](lib/bin/statusbar.dart#L130)），沒有 generation；宣告的 `AnimationController` 並未控制這條 ScrollController chain。

建議：單一可取消 animation/generation，在 inactive/minimized 停止；不需要時移除未使用 AnimationController。

## P3：清理與 hygiene

### L-01：生成物、機器專屬檔、dead code 與全文 log

本機實測：

| 路徑 | 大小 | 檔案數 | 狀態 |
| --- | ---: | ---: | --- |
| `build/` | 1.69 GiB | 7,294 | ignored、可再生成 |
| `.dart_tool/` | 0.40 GiB | 18,874 | 部分檔案仍被 Git 追蹤 |
| 合計 | 2.09 GiB | 26,168 | 會增加備份／掃描成本 |

其他問題：

- Git 追蹤 `-IRU-PC.flutter-plugins-dependencies`，內容自稱 generated／不可提交，且含本機絕對路徑。
- `.vscode/settings.json` 仍追蹤舊 `D:/...` 絕對路徑。
- 8 個 tracked `*.freezed.dart` 共 6,063 行，但失效 CI 無 freshness guard。
- `editor_adapter.dart`、`input_assist.dart` 無 incoming import；後者與現用 `punctuation_panel.dart` 高度重複。
- `SettingsManager` 舊 persistence layer 與 repository 並存；另有 `SimpleLocation`、`DragPayload` 等無外部使用宣告。
- Copy/Cut/Paste 的 debug log 會輸出 selected text、clipboard text，甚至整份修改後 chapter（[`main.dart#L2476`](lib/main.dart#L2476)、[`main.dart#L2517`](lib/main.dart#L2517)、[`main.dart#L2570`](lib/main.dart#L2570)）。大型貼上會造成大量 console I/O，也可能洩露內容。

建議：停止追蹤機器生成檔與絕對路徑；CI 驗證生成碼；移除 dead/duplicate code；全文 log 改成長度／hash 且只在明確 debug flag 啟用。

### L-02：一個 controller cleanup 缺口 // OK

Outline 動態建立 `_renameListController`，正常結束 rename 才 dispose；State.dispose 沒有處理它。正在 rename 時切換專案會略過明確 cleanup。整個 State 最終仍可 GC，所以不能直接證明為永久 leak，但應補上 `dispose` 以維持 ownership contract。

## 已確認做得正確的部分

- 主畫面的 timer、Riverpod manual subscription、window/focus listener 與 controllers 都在 [`main.dart#L768`](lib/main.dart#L768) 清理。
- 多數功能頁 controllers／scroll controllers 有對應 dispose。
- Proofreading worker 在頁面真正銷毀時會 kill isolate、close port 並完成／清除 pending request。
- Chapter word-count cache 有 4096 entry 上限，project switch 會 prune；問題在 lookup 複雜度與 key retained content，不是完全無限制。
- History 有 50 筆上限；缺的是 byte budget 與 representation efficiency。
- 一般搜尋 highlight 有結果上限；這個保護不涵蓋 Replace All。

## 已修正的誤判／措辭

1. **Native normalization cache 不是長駐 leak。** Production 的 `findAllMatchesSync` 只在 `compute` task 中使用；native task isolate 結束時 cache 一起回收。Web 上 `compute` 同 event loop，cache 才會跨搜尋成長；key 又是單一 UTF-16 code unit × 兩個布林，理論上最多 262,144 entries。Web 可改固定容量，但優先級低於搜尋 worker latest-wins。
2. **不是 14 頁都永久到 app 結束。** 6 個 project-backed page 會在 project session 切換後重建；eager creation 與 hidden work 仍然成立。
3. **不是所有 provider 都完整 deep-copy 所有資料。** Segments 主要 traversal／container copy，未改 String／Chapter 可共用；World、Character、Glossary 等才有明確重複 deep-copy。
4. **Controller cleanup 不是零缺口。** Outline rename controller 是已確認的低風險漏配對。

## 建議執行順序

### 第一批：避免 OOM、磁碟膨脹與跨專案競態

1. Replace All 改 worker streaming，加入 match/output/time budget。
2. History 移除 `xmlContent`、改一次 snapshot／hash、合併 debounce。
3. Proofreading worker 只回 bounded samples。
4. AutoBackup 加 generations/age/bytes retention。
5. Project I/O 加 single queue + session generation；修 Character dispose 回寫。

### 第二批：恢復長篇輸入效能

1. 單一 word-count service，移除 BaseInfo 隱藏全文 listener與同步 fallback。
2. Cache 改 O(1)，total count 增量更新。
3. TextPositionIndex 改增量。
4. StatusBar 拆 rebuild boundary。
5. World/Glossary 移除 descendant closure、索引只在 structure change 重建。
6. Glossary／nested state 改 local draft + path-copying。

### 第三批：縮小長駐與交付資源

1. 功能頁 lazy construction + visibility lifecycle。
2. Copilot context budget、cancelable client、debounced settings。
3. 移除 Quill 等未使用 dependencies。
4. 依語系拆分／subset 62.63 MiB 字型。
5. raw XML／backup baseline 改 metadata + revision/hash。

### 第四批：降低維護成本

1. 修正 repo-root CI，加入 analyze/test/generator drift/benchmark。
2. 拆 Proofreading、File、Provider 巨型檔案。
3. 合併 XML helpers、校對規則與標點面板。
4. 移除循環 import、legacy state/persistence、dead code 與機器生成追蹤檔。

## 建議量測與驗收情境

| 情境 | 驗收重點 |
| --- | --- |
| 冷啟動、未進功能頁 | 不應建立 14 頁 State；無 proofreading/plan/world I/O |
| 1 MB 單章連續輸入 60 秒 | UI 不同步掃全文；每次 revision 只計算一次字數；無 O(C²) cache scan |
| 100 章／10 MB 專案形成 50 筆 history | 每筆一次 snapshot／serialization；retained heap 有 byte budget |
| 10 MB 重複字元 Replace All | peak heap 接近 input+output，不建立數百萬 match objects |
| 2 MB 贅字密集校對 | worker/main result 均受 K 限制，回傳 truncated count |
| 10,000 詞條／深層分類樹連續輸入 | 每字不 copy 全樹、不 rebuild O(N²) descendant closure |
| 靈感筆記連續輸入 100 字 | 只發生一次或少量 serial writes，最後檔案必為最新 revision |
| AutoBackup 連續運行 | generations/age/bytes 均不超限，可用空間不足時安全停止 |
| AutoSave 中切換專案 | 舊工作不得更新新 session、currentProject 或 dirty flag |
| Copilot 100 輪 | context 受 token/byte budget，request 可取消 |
| CI pull request | format、analyze、test、generated diff、關鍵 benchmark 全部實際執行 |

Heap 驗證應記錄操作前、操作後、強制 GC 後三個點，分辨 temporary allocation peak 與 retained leak。效能門檻需用固定大型 fixture、release/profile mode 與最低支援硬體校準。
