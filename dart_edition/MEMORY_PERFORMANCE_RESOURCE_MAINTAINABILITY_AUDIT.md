# Monogatari Assistant 記憶體、效能、資源與維護性評估

評估日期：2026-07-31  
評估範圍：`dart_edition/lib`、`dart_edition/assets`、Flutter 專案設定與版本控制狀態  
評估方式：靜態程式碼審查、生命週期配對檢查、資料流與配置路徑分析、檔案／資產大小盤點

> 本報告依目前工作樹（包含尚未提交的既有修改）評估。環境沒有可用的 `flutter` 指令，因此無法執行 `flutter analyze`、DevTools heap snapshot 或實機 frame profiling；所有效能影響均標示為靜態分析結論，實際數字仍需用代表性大型專案量測。

## 摘要

目前最需要優先處理的並不是大量未釋放的 `TextEditingController`，而是以下三種問題：

1. **長駐型資源占用**：14 個功能頁由 `IndexedStack` 一次建立並持續保留，隱藏頁面仍執行監聽、I/O 與背景校對。
2. **高配置量與重複運算**：專案歷史、詞庫更新與巢狀狀態更新會重複深拷貝、序列化完整資料。
3. **無上限資料結構**：Copilot 對話與搜尋正規化快取會隨使用時間持續成長。

風險分布：

| 等級 | 數量 | 說明 |
| --- | ---: | --- |
| 嚴重（Critical） | 2 | 容易在一般使用流程持續消耗 CPU／記憶體，並隨文件大小明顯惡化 |
| 高（High） | 4 | 大型專案、長文或密集輸入時容易掉幀、產生大量 GC 或背景工作 |
| 中（Medium） | 6 | 長時間使用、特定功能或維護變更時會放大成本 |
| 低（Low） | 1 | 主要影響開發環境整潔與後續維護 |

建議先完成：

1. 改為延遲建立功能頁，並讓隱藏的校對頁停止監聽與分析。
2. 重寫歷史快照，只建立一次不可變快照與一次比較內容，避免三次深拷貝、兩次 XML 生成。
3. 將詞庫輸入改為局部更新，且 debounce 之後才建立持久化快照。
4. 把游標狀態列與根畫面重建隔離，避免每次游標移動重建整個主畫面。

## 已確認做得正確的部分

- 主畫面的 timer、Riverpod 手動 subscription、window listener、focus listener 與 controller 都有在 [`main.dart#L768`](lib/main.dart#L768) 關閉。
- 章節、角色、Copilot、詞庫、大綱、計畫、校對等主要頁面的 controller／scroll controller 多數都有 `dispose`。
- 章節字數快取已有 4096 筆上限，且專案切換時會清除；專案 undo/redo 也限制為 50 筆。
- 校對 worker 在頁面真正銷毀時會終止 isolate、關閉 receive port，並清除 pending completer。
- 搜尋與校對結果顯示已有筆數上限或分頁，降低一次建立大量 widget 的風險。

因此，本次沒有發現「controller 忘記 dispose」這類明確且普遍的傳統洩漏；主要問題是頁面幾乎不會被銷毀、背景工作不因不可見而停止，以及資料結構／配置量隨使用成長。

## 問題明細

### C-01：所有功能頁一次建立並永久長駐，隱藏頁面仍執行工作

類型：記憶體、CPU、I/O、啟動效能  
風險：嚴重

桌面版在 [`main.dart#L1797`](lib/main.dart#L1797) 以 `IndexedStack` 一次建立 14 個頁面；手機版也在 [`mobile_function_page.dart#L102`](lib/bin/mobile_function_page.dart#L102) 建立全部頁面，外層又以另一個 `IndexedStack` 同時保留功能頁與編輯器（[`mobile_function_page.dart#L23`](lib/bin/mobile_function_page.dart#L23)）。

直接後果：

- 每個頁面的 `State`、controller、scroll controller、索引、表單暫存與 widget subtree 都會在應用生命週期中長駐。
- 校對頁即使從未被開啟，也會在初始化時讀取詞庫與偏好設定（[`proofreadingview.dart#L394`](lib/modules/proofreadingview.dart#L394)）。
- 校對頁持續監聽 `editorContentProvider`（[`proofreadingview.dart#L398`](lib/modules/proofreadingview.dart#L398)），文字變更後排程背景分析（[`proofreadingview.dart#L443`](lib/modules/proofreadingview.dart#L443)），因此使用者只是在編輯器打字，隱藏頁面仍可能啟動 isolate 並掃描全文。
- 計畫頁初始化時立即讀磁碟（[`planview.dart#L387`](lib/modules/planview.dart#L387)）、詞庫頁會在 post-frame 載入資料（[`glossaryview.dart#L163`](lib/modules/glossaryview.dart#L163)）、Copilot 頁會立即讀取設定（[`copliot.dart#L137`](lib/modules/copliot.dart#L137)）。

這是「刻意保留造成的高資源占用」，不一定會在 profiler 中呈現 unreachable leak，但使用者觀察到的常駐記憶體與背景 CPU 效果接近洩漏。

建議：

- 僅建立目前頁面；需要保留操作狀態時，將必要狀態移至 provider，而不是保留整棵 widget tree。
- 或採 lazy page cache，只快取最近 1～3 頁並提供明確淘汰策略。
- 校對監聽應受「頁面可見／功能啟用」控制；不可見時取消 timer、停止接收內容變更，必要時終止 worker。
- 將頁面首次 I/O 改為真正進入頁面後才執行。

驗證方式：

- 冷啟動後未開啟任何功能頁，heap 中不應已有所有頁面的 controller/state。
- 在編輯器連續輸入時，未開啟校對頁的情況下不應存在 proofreading isolate 或校對 CPU sample。

### C-02：每筆歷史記錄重複深拷貝三次、產生 XML 兩次，並同時保存多份完整專案

類型：記憶體、CPU、GC、輸入延遲  
風險：嚴重

`ProjectHistoryEntry` 建構時：

- `data` 呼叫一次 `snapshotProjectData`。
- `xmlContent` 又對原資料呼叫一次 `snapshotProjectData` 並生成 XML。
- `xmlComparisonKey` 再做第三次快照與第二次 XML 生成。

證據位於 [`project_history_provider.dart#L16`](lib/presentation/providers/project_history_provider.dart#L16)。

每份快照還會深拷貝世界設定與角色資料（[`project_snapshot_utils.dart#L134`](lib/presentation/providers/project_snapshot_utils.dart#L134)、[`project_snapshot_utils.dart#L143`](lib/presentation/providers/project_snapshot_utils.dart#L143)）。undo/redo 各筆同時保留 `ProjectData`、`xmlContent` 與幾乎同大小的 `xmlComparisonKey`，最多 50 筆（[`project_history_provider.dart#L52`](lib/presentation/providers/project_history_provider.dart#L52)）。

歷史記錄會在焦點離開輸入框、頁面切換或資料變更 debounce 後觸發（[`main.dart#L319`](lib/main.dart#L319)、[`main.dart#L926`](lib/main.dart#L926)、[`main.dart#L960`](lib/main.dart#L960)）。大型小說若 XML 為 10 MB，僅兩份 XML 字串乘 50 筆就可能達到約 1 GB 級別，尚未計算 Dart 字串表示、物件樹與三次快照過程中的暫時配置。

建議：

- 先建立一次 `snapshot`，後續全部重用。
- XML 只生成一次；比較鍵可由同一 XML 派生，或改用不包含時間欄位的穩定 hash。
- `xmlContent` 若只用來比較，應移除；若要還原，則不需要再同時保存完整 `ProjectData`。
- 更理想的做法是 command/delta history，只保存受影響的欄位或章節。
- 歷史上限應同時考慮「總位元組數」，不能只限制筆數。

驗證方式：

- 建立 10 MB、20 MB、50 MB 專案，連續形成 50 筆歷史後比較 heap retained size。
- timeline 中每次 record 不應出現三次完整資料 copy 與兩次 XML serialization。

### H-01：詞庫欄位每次輸入都會多次深拷貝完整詞庫

類型：CPU、記憶體配置、GC、磁碟 I/O  
風險：高

詞義與例句直接在 `onChanged` 呼叫 provider（[`glossaryview.dart#L1396`](lib/modules/glossaryview.dart#L1396)）。單次字元更新會：

1. 深拷貝目前 entry。
2. 深拷貝完整 `entryIndex`。
3. 線性掃描所有 index key 以尋找相同 ID。
4. 深拷貝完整分類樹。
5. `_setIfChanged` 再次深拷貝完整分類樹與完整 index。
6. `_schedulePersist` 在 debounce timer 啟動前又建立一份完整 snapshot。

核心路徑見 [`project_state_providers.dart#L1312`](lib/presentation/providers/project_state_providers.dart#L1312)、[`project_state_providers.dart#L1131`](lib/presentation/providers/project_state_providers.dart#L1131)、[`project_state_providers.dart#L1357`](lib/presentation/providers/project_state_providers.dart#L1357)。

雖然寫檔有 240 ms debounce，但完整 snapshot 在取消舊 timer 後、等待 debounce **之前**就已建立，因此快速輸入仍會每字配置整份詞庫。真正寫檔時，`toJson`、`jsonEncode` 也在主 isolate 建立完整 payload（[`project_state_providers.dart#L1365`](lib/presentation/providers/project_state_providers.dart#L1365)）。

建議：

- `entryIndex` 使用不可變 map 的淺拷貝，只替換單一 entry；未變更的 entry 與 category tree 應共用。
- entry 以 ID 作唯一 key，移除每次掃描所有 key 的相容路徑，或在匯入時一次正規化。
- 表單先維持 local draft；idle、blur 或 explicit save 時再提交 provider。
- debounce 到期後才擷取 snapshot；序列化移至 isolate，並用單一 writer queue 避免寫入競態。

### H-02：每次文字變更同步掃描全文建立換行索引

類型：輸入延遲、CPU、短期記憶體配置  
風險：高

主編輯器 controller listener 在每次文字變更都呼叫 `rebuildIfTextChanged`（[`main.dart#L554`](lib/main.dart#L554)）。只要內容不同，`TextPositionIndex` 就從頭掃描整份文件並建立新的換行 offset list（[`text_position_index.dart#L13`](lib/utils/text_position_index.dart#L13)、[`text_position_index.dart#L33`](lib/utils/text_position_index.dart#L33)）。

複雜度為每個按鍵 O(全文長度)，且發生在 UI isolate。長章節會造成輸入延遲與頻繁配置／回收 `List<int>`。

建議：

- 根據 `TextEditingDelta` 或共同前後綴只更新受影響區段的換行索引。
- 若無法取得 delta，至少 debounce 索引重建；狀態列可在短時間顯示上一筆位置。
- 對小文件使用同步路徑、大文件使用增量索引，避免為簡單游標資訊啟動昂貴全文處理。

### H-03：游標與內容狀態由根畫面監看，放大整體重建

類型：UI 重建、掉幀、CPU  
風險：高

`_buildMobileStatusBar` 由主 `ContentView.build` 呼叫，但在 helper 內 `ref.watch`：

- 完整的 `editorSelectionProvider` 選擇狀態；
- 完整 `segmentsDataProvider` list；
- total words 與 active chapter word count。

證據位於 [`main.dart#L1507`](lib/main.dart#L1507)。游標移動會更新 provider（[`main.dart#L582`](lib/main.dart#L582)），因此狀態列需求會讓根 `ContentView` 重建，重新建立 shortcuts、actions、scaffold、layout、editor 與功能頁容器。內容每 200 ms 提交後，完整 segments list 的 identity 改變也會觸發同一路徑。

建議：

- 將狀態列拆為獨立 `ConsumerWidget`，只重建狀態列。
- 建立 `selectedChapterLabelProvider`，不要為顯示名稱監看完整章節樹。
- 主畫面只監看真正影響佈局的狀態；editor、navigation、status bar 分成獨立 rebuild boundary。
- 用 `debugPrintRebuildDirtyWidgets` 或 DevTools Track Widget Builds 驗證游標移動的重建範圍。

### H-04：狀態更新採全量深拷貝，巢狀資料越大配置成本越高

類型：CPU、記憶體配置、GC、可擴充性  
風險：高

目前 provider 雖採不可變 state，但多個更新路徑先對完整資料做深拷貝，再由 snapshot 層重拷貝：

- 世界設定：`updateLocationById` 先 `_copyLocations(state)`，更新完成後 `setWorldSettingsData` 再 `snapshotWorldSettingsData` 深拷貝整棵樹（[`project_state_providers.dart#L502`](lib/presentation/providers/project_state_providers.dart#L502)、[`project_state_providers.dart#L678`](lib/presentation/providers/project_state_providers.dart#L678)）。
- 角色：更新單一角色時先 copy 整份 map、deep copy entry，再由 `setCharacterData` 對整份 map 建立 snapshot（[`project_state_providers.dart#L771`](lib/presentation/providers/project_state_providers.dart#L771)、[`project_state_providers.dart#L817`](lib/presentation/providers/project_state_providers.dart#L817)）。
- 大綱 snapshot 每次走訪全部 storyline/event/scene，重新建立各層 list（[`project_snapshot_utils.dart#L56`](lib/presentation/providers/project_snapshot_utils.dart#L56)）。

建議：

- 採 path-copying：只複製從根到被修改節點的容器，未修改子樹保持 identity。
- snapshot function 應辨識已不可變的物件並直接重用，避免「為了不可變而重複深拷貝」。
- 大型 domain state 可按 entity ID 正規化，將 tree order 與 entity map 分離。
- 為 1k、10k entity 更新單一欄位建立 microbenchmark，並設定配置量與耗時門檻。

### M-01：字數計算使用不可取消的 `compute`，重複請求可能疊加 isolate 工作

類型：CPU、isolate、記憶體尖峰  
風險：中

每次 debounce 後的章節字數計算都呼叫 `compute`（[`content_manager.dart#L20`](lib/bin/content_manager.dart#L20)）。全專案重算會每批同時啟動最多 6 個 chapter compute（[`main.dart#L1151`](lib/main.dart#L1151)）。

generation counter 只能忽略過期結果，不能取消已啟動的 isolate；若在前一輪完成前再次切換專案、切換字數模式或重算，舊工作仍持續消耗資源。對很短文字，建立 isolate 的固定成本也可能高於直接計算。

建議：

- 小於門檻的內容直接在主 isolate 計算。
- 長駐單一 word-count worker 或 worker pool，不要每章建立新 isolate。
- 將全專案內容合併為單次 worker request，或實作可取消的工作佇列。
- 新一輪開始時停止派送舊 jobs，並限制跨 invocation 的全域 concurrency。

### M-02：Copilot 對話與每次送出的 request body 沒有上限

類型：記憶體、網路、序列化、模型成本  
風險：中

`_messages` 是無上限 list（[`copliot.dart#L119`](lib/modules/copliot.dart#L119)）。每次請求會把全部歷史重新轉成 JSON 並送出（[`copliot.dart#L441`](lib/modules/copliot.dart#L441)），回應也以完整 `http.Response.body` 緩衝、解碼後再加入歷史（[`copliot.dart#L511`](lib/modules/copliot.dart#L511)）。

隨對話輪數增加：

- 常駐記憶體線性成長。
- 每次 request body 與 JSON encode 成本線性成長。
- 整個 session 的累積傳輸量接近二次成長。

建議：

- 設定 message、字元與估算 token 三種上限。
- 超出 context window 時採 sliding window 或摘要較舊訊息。
- 限制單次 response bytes／tokens；大量回應採 streaming。
- UI 可保留完整紀錄，但送給模型的 context 應獨立裁切。

### M-03：Copilot 的 in-flight HTTP 無法取消，部分 await 後直接 `setState`

類型：資源生命週期、穩定性  
風險：中

頁面 dispose 只釋放 controller（[`copliot.dart#L143`](lib/modules/copliot.dart#L143)），沒有可關閉的 `http.Client` 或 cancellation token。請求進行中若頁面被銷毀，網路仍可持續至 30／60 秒 timeout。

此外，部分 await 後的成功與錯誤路徑直接 `setState`，沒有先確認 `mounted`，例如模型載入（[`copliot.dart#L346`](lib/modules/copliot.dart#L346)）與送出訊息（[`copliot.dart#L511`](lib/modules/copliot.dart#L511)）。目前 C-01 讓頁面通常不會銷毀，反而掩蓋了這個生命週期問題；改成 lazy page 後更容易暴露。

建議：

- 由 State 擁有單一 `http.Client` 並在 dispose 關閉，或使用支援取消的 transport。
- 每次 await 後，在任何 `setState` 前檢查 `mounted`。
- 以 request generation 防止較舊回應覆蓋較新 provider/model 選擇。

### M-04：搜尋正規化全域快取沒有上限

類型：潛在記憶體洩漏、長時間使用  
風險：中

`findreplace.dart` 宣告全域 `_normalizationCache`，只在專案切換時由 coordinator 清空，沒有 entry/byte 上限或 LRU（[`findreplace.dart#L20`](lib/bin/findreplace.dart#L20)、[`findreplace.dart#L1090`](lib/bin/findreplace.dart#L1090)）。

key 包含字元與搜尋選項；處理多語系、罕見 Unicode 或長時間切換選項時會持續累積。雖然成長速度通常低於完整文件快取，但它是本次最接近「可到達物件永久保留」的典型 leak-like cache。

建議：

- 這類單字元正規化可直接計算，先量測快取是否真的有收益。
- 若保留，使用固定容量 LRU，並記錄 hit rate；容量應以 byte 或 entry 明確限制。
- 關閉搜尋列、切換文件與記憶體壓力通知時清空。

### M-05：字型資產約 62.75 MB，增加安裝包、下載與儲存占用

類型：套件大小、磁碟、下載資源  
風險：中

`pubspec.yaml` 同時打包 Noto Sans、Italic、HK、JP、KR、SC、TC、Thai 共 8 個 variable font（[`pubspec.yaml#L64`](pubspec.yaml#L64)）。實際盤點：

| 資產 | 約略大小 |
| --- | ---: |
| NotoSansSC | 16.95 MB |
| NotoSansTC | 11.37 MB |
| NotoSansHK | 11.34 MB |
| NotoSansKR | 9.92 MB |
| NotoSansJP | 8.71 MB |
| 其餘 3 款 | 4.35 MB |
| **總計** | **62.75 MB** |

這不代表所有字型會同時完整載入 RAM，但會直接影響 bundle／安裝包與更新成本，也可能增加首次使用特定字型時的字型解析與 glyph cache 壓力。

建議：

- 先用 release artifact analyzer 確認各平台實際是否會 tree-shake/subset。
- 依平台／語言建立 flavor 或 deferred asset；只打包使用者需要的語系。
- 評估 subset font，保留實際使用字集；同時確認授權與 fallback 行為。

### M-06：大型檔案、重複校對規則與 UI／domain 耦合使修改成本偏高

類型：維護成本、回歸風險、測試困難  
風險：中

目前 `lib` 共 64 個 Dart 檔、約 46,657 行；最大的手寫檔案包括：

| 檔案 | 行數 |
| --- | ---: |
| `proofreadingview.dart` | 4,973 |
| `characterview.dart` | 3,190 |
| `outlineview.dart` | 3,073 |
| `main.dart` | 2,997 |
| `file.dart` | 2,521 |
| `findreplace.dart` | 2,514 |
| `glossaryview.dart` | 2,216 |
| `project_state_providers.dart` | 2,051 |

`proofreadingview.dart` 同時包含 UI、worker protocol、isolate session、analyzer 與資料類別；靜態掃描發現至少 34 個 private 規則方法在 UI state 與 analyzer 內各有一份，例如 `_normalizePunctuation`（[`proofreadingview.dart#L1774`](lib/modules/proofreadingview.dart#L1774) 與 [`proofreadingview.dart#L4035`](lib/modules/proofreadingview.dart#L4035)）、`_detectLineEndingIssues`（[`proofreadingview.dart#L1389`](lib/modules/proofreadingview.dart#L1389) 與 [`proofreadingview.dart#L3964`](lib/modules/proofreadingview.dart#L3964)）。修改規則時容易只改到其中一份。

資料層也反向 import UI module 取得 model/codec，例如 [`project_state_providers.dart#L9`](lib/presentation/providers/project_state_providers.dart#L9)、[`project_snapshot_utils.dart#L3`](lib/presentation/providers/project_snapshot_utils.dart#L3)；`file.dart` 同時負責底層 I/O、專案格式與各 UI module codec（[`file.dart#L13`](lib/bin/file.dart#L13)）。這使循環依賴、測試替身與功能拆分更困難。

建議：

- 校對拆為 `domain/analyzer`、`worker`、`models`、`presentation`；UI 與 worker 共用同一套純函式規則。
- XML／JSON codec 移到 data/domain layer，view 只負責 widget。
- `file.dart` 依平台與職責拆分：project serializer、repository、platform file access、backup service。
- 為 layer import 加自動檢查，禁止 provider/repository import `modules/*view.dart`。
- 新增大型資料基準測試與 worker/UI 共用規則的 differential test。

### L-01：生成／暫存檔與重複舊程式增加開發維護雜訊

類型：版本控制、磁碟、死碼  
風險：低

- `.dart_tool/` 已在 [`dart_edition/.gitignore#L26`](.gitignore#L26) 忽略，但 Git 仍追蹤 `package_config.json` 與 `package_graph.json`；後者目前已因本機環境變更，容易製造與功能無關的 diff。
- 本機 `dart_edition/build` 約 1.69 GB。它已被 ignore，屬可再生成的開發產物，不是 repo 內容，但會占用工作磁碟與備份／掃描時間。
- [`input_assist.dart`](lib/bin/input_assist.dart) 與 [`punctuation_panel.dart`](lib/bin/punctuation_panel.dart) 幾乎是兩份相同的 `PunctuationPanel`，前者沒有任何 import 使用。
- `SettingsManager` 只有宣告、沒有外部引用（[`settings_manager.dart#L90`](lib/bin/settings_manager.dart#L90)）；`UILibrary` 的 ChangeNotifier 狀態也沒有實例使用，現況只引用其 static color map（[`ui_library.dart#L32`](lib/bin/ui_library.dart#L32)）。這些舊 state layer 與現行 Riverpod 並存，會誤導後續開發者。

建議：

- 從 Git index 移除 `.dart_tool` 兩個檔案，但保留本機檔案與 ignore 規則。
- 在 README／CI 說明安全的 build cache 清理方式，不把清理納入每次 build。
- 刪除未使用的 duplicate/dead code，或先用 deprecation 註解與測試確認無動態引用。
- 將可重用的 supported colors 移到單純常數檔，移除未使用的舊 ChangeNotifier。

## 建議執行順序

### 第一階段：阻止不必要的長駐與背景工作

1. 將 14 頁 `IndexedStack` 改為 lazy construction。
2. 加入 page visibility lifecycle；隱藏校對頁時停止監聽、timer 與 worker。
3. 把狀態列拆成獨立 Consumer rebuild boundary。
4. 建立冷啟動、閒置、連續輸入三種 DevTools baseline。

預期收益：降低冷啟動 I/O、常駐 heap、隱藏背景 CPU 與根畫面 rebuild。

### 第二階段：處理最大配置熱點

1. 歷史快照改為一次 snapshot／一次 serialization，加入總 byte budget。
2. 詞庫改為 local draft + 局部 immutable update，debounce 到期後才 snapshot。
3. 世界／角色／大綱改為 path-copying 或 normalized entity state。
4. 文字位置索引改為增量更新。

預期收益：大幅降低長文與大型專案的 GC、輸入延遲與記憶體尖峰。

### 第三階段：限制無上限資源

1. Copilot 加 context/message/token/response 上限與可取消 HTTP。
2. 正規化快取改固定容量 LRU，或量測後移除。
3. 字數工作改為共享 worker pool 並限制跨輪總 concurrency。
4. 依語系拆分或 subset 字型資產。

### 第四階段：降低維護成本

1. 拆分 `proofreadingview.dart`、`file.dart`、`project_state_providers.dart`。
2. 合併重複校對演算法與標點面板。
3. 移除 legacy state manager 與 Git 中的 `.dart_tool`。
4. 建立 layer boundary、檔案行數、benchmark 與 memory regression guardrail。

## 建議量測情境與驗收門檻

以下門檻需先依產品目標與最低硬體校準；重點是固定資料集並防止回歸：

| 情境 | 建議觀察 |
| --- | --- |
| 冷啟動、未開任何功能頁 | 啟動時間、首次 frame、heap、磁碟讀取次數、是否已有 worker isolate |
| 1 MB 單章連續輸入 60 秒 | UI/Raster frame、每鍵 CPU、GC 次數、換行索引配置量 |
| 100 章／10 MB 專案建立 50 筆 history | retained heap、單次 snapshot 時間、XML generation 次數 |
| 10,000 詞條中連續編輯 100 字 | 每鍵耗時、copy 次數、debounce 前配置量、磁碟寫入次數 |
| 校對頁隱藏時輸入 | proofreading worker CPU 應為 0、無新 proofreading request |
| Copilot 100 輪對話 | message heap、request body bytes、encode 時間、context 裁切是否生效 |
| 連續切換字數模式／專案 | 同時存在的 word-count isolate／job 數不得超過全域上限 |

建議將上述場景至少做成 integration benchmark；memory 測試可記錄「操作前、操作後、強制 GC 後」的 retained heap 差異，避免把短期配置尖峰誤判為真正洩漏。

## 結論

目前程式碼的生命週期釋放大致有被注意到，但 `IndexedStack` 讓多數頁面在實際使用中不會進入 dispose，形成長駐資源與隱藏背景工作。再加上歷史／詞庫／巢狀 state 的全量拷貝，文件越大時 CPU、heap 與 GC 成本會非線性地變得明顯。

最有效的改善方向不是先零碎地補 `dispose`，而是：

1. **不建立、不監聽、不計算不可見功能。**
2. **只複製真正改變的資料。**
3. **所有 cache、history、conversation、worker queue 都要有明確容量與淘汰策略。**
4. **將高成本 domain logic 從大型 UI 檔案抽離並共用。**

