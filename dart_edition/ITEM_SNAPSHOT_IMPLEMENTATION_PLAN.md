# 物品管理與物品／地點快照實作計畫

日期：2026-09-13  
最後更新：2026-09-16
狀態：P1–P8 已完成；功能、遷移、整合驗收與交付文件均完成，待後續正式發布。
需求依據：[物品三模式與快照評估](ITEM_PAGE_EVALUATION.md)。

## 1. 交付目標與範圍

採 B 方案，新增獨立物品 Class／實例資料。完整交付包含：

- 每個 Class 可切換專用、半專用、非專用；專用具有單件 ID、半專用展開具歸屬實例、非專用只管理 Class 與聚合分配。
- 地點、人物、大綱事件的正式 ID 關聯與雙向跳轉。
- Class、物品實例與地點樹所有 location 節點的場景快照，共用角色時間軸游標。
- 角色持有物與地點物品反查使用同一份時間狀態。
- 舊資料遷移、模式轉換、存檔、備份、復原、匯入匯出、即時協作及 P2P 合併。

不在本次加入圖片附件、完整庫存帳本、容器物理推演、分支宇宙時間線，以及組織／規則節點快照。地點樹的編輯父子結構不做歷史化。

## 2. 開工採用的設計決策

| 主題 | 實作預設 |
| --- | --- |
| 模式粒度 | 每個 Class 一個 enum，介面用互斥三段開關 |
| 主資料 | itemClasses 與 itemInstances 分開保存；不再以世界 item 節點當權威 |
| 時間模型 | 主資料的 defaultState＋Scene 綁定 patch；不逐 Tick 複製資料 |
| 快照時間 | 沿用角色的 placement 選取、fallbackTick 與 sequence 規則 |
| 半專用 ID | 一旦建立實例就保留；解除歸屬或故事中毀損不刪除 ID |
| Class 與實例 | 同 Tick 解析 Class，再套用實例覆寫；區分繼承、清空與設定 |
| 歸屬權威 | 物品快照；角色與地點已連結物品列表僅為投影 |
| 一般關聯 | 製作者、相關事件等存 itemRelations；持有者／所在地不重複存為現況關聯 |
| 數量 | 聚合分配採選填非負整數，未知不等於 0；無換算與自動補帳 |
| 模式轉換 | 管理設定變更，涉及身份／數量的部分另記場景變更及轉換來源 |
| 降級轉換 | 有歷史者保留原身份與唯讀歷史，另建聚合 Class；不破壞性覆蓋 |

開工先將這些決策化為模型不變條件和驗收測試，不再以需求探索取代施工。發現與既有程式相衝突時，記錄具體差異後調整實作。

## 3. 工作相依與提交原則

```text
P0 基線與契約 → P1 模型／保存／遷移 → P2 共用時間核心
                                    ↓
                          P3 物品狀態與操作
                            ↙              ↘
                  P4 物品頁與關聯     P5 地點節點快照
                            ↘              ↙
                         P6 角色與時間軸整合
                                    ↓
                         P7 三模式安全轉換
                                    ↓
                         P8 整合驗收與發布
```

協作、P2P、codec 與復原不是 P8 才補做：P1 定義資料通道，P3 完成交易通道，各階段都帶對應測試。P4／P5 在資料與時間契約穩定後可分工，但同時修改 `ProjectData`、主狀態 provider 或協作 record enum 的工作須由同一整合者處理。

每個提交應可編譯，包含該變更的保存與測試；新入口在資料完整性完成前維持內部開發狀態。開發入口控制與使用者的三模式開關是不同概念。

## 4. P0：建立基線與實作契約

### 工作

- [x] 確認當下工作樹與既有修改，避免覆寫其他工作；若採分支，使用 `codex/` 前綴。
- [x] 盤點所有 `ProjectData(...)` 建構、empty／collaborationShell、snapshot、migration、parse／write、merge 路徑。
- [x] 盤點世界、大綱與角色的獨立匯入／匯出入口，以及頁面選取與草稿提交方式。
- [x] 執行既有角色快照、專案遷移、歷史、codec、P2P 核心測試，記錄原有失敗。
- [x] 建立固定 UUID 的小型測試專案：三模式物品、同名物品、三層地點、兩角色、同 Tick 場景、多 placement、失效引用與混合世界子樹。
- [x] 明確定義格式版本、record 種類、patch 清空／繼承語意、轉換來源與交易完成條件。

### 完成條件

有可重用測試 fixture、既有失敗紀錄和所有資料入口清單；不先修改 UI。具體版本號在實作時依 `ProjectMigrator.currentVersion` 遞增，與 pubspec 的應用程式版本分開管理。

## 5. P1：獨立物品模型、完整保存與遷移

### 建議新增

- `lib/models/item_data.dart`：模式、Class、實例、聚合分配、一般關聯及轉換來源資料。
- `lib/models/item_snapshot_data.dart`：Class／實例狀態與強型別 patch、變更封套。
- `lib/models/location_snapshot_data.dart`：地點預設狀態、patch、變更。
- `lib/models/codecs/item_codec.dart`、`item_snapshot_codec.dart`、`location_snapshot_codec.dart`。

若採 Freezed，依現有版本產生檔案，不能手改 `.freezed.dart`。

### 必改既有入口

`lib/models/project_data.dart`、`world_settings_data.dart`、`project_migrator.dart`；`lib/bin/file.dart`；`lib/presentation/providers/project_snapshot_utils.dart`、`project_state_providers.dart`、`project_io_providers.dart`、`project_history_provider.dart`；協作與 P2P 資料通道。

### 工作

- [x] 新增集合與安全空預設；所有 ProjectData 重建路徑完整傳遞新欄位。
- [x] 地點 defaultState 成為可變描述／屬性的唯一來源；既有欄位保留讀取相容，禁止兩邊獨立寫入。
- [x] 既有世界 item 逐筆移為專用實例，原 id 保留為 instanceId，另建 Class；不按同名合併。
- [x] 處理 item 下的非 item 子節點提升與順序保存；記錄來源路徑及遷移警告。
- [x] 遷移需可重入：對已遷移資料不重複新增；先於記憶體完成，不覆寫原檔，存檔才寫新版。
- [x] 舊大綱字串與角色 possession 歷史原樣保留。
- [x] 擴充 XML、備份、局部匯入／匯出選項、record codec、P2P 序列化與合併。
- [x] 更新新格式／協作能力檢查；不相容的同步端拒絕參與新資料編輯。已發布舊版可能仍可強制開檔，不能宣稱新版能完全阻止它丟欄位；提供版本提示與原檔備份。

### 驗證與完成條件

新增 `item_codec_test.dart`、`location_snapshot_codec_test.dart`；擴充 `project_migration_test.dart`、`project_record_codec_test.dart`、`project_history_provider_test.dart`、`p2p_project_merge_test.dart`。fixture 經「讀取→遷移→存檔→重開→snapshot／record 往返」後 ID、欄位與引用一致。

## 6. P2：抽取共用時間解析，維持角色行為

### 建議新增

`lib/models/story_state_time.dart`：僅共用時間錨點解析及排序；各領域 patch 保持獨立型別。角色模型保留對外 API，以委派方式漸進改用共用核心。

### 工作

- [x] 為目前角色時間解析補充行為測試，再抽取函式，避免以重構改變規則。
- [x] 保留指定 small placement 優先、同 Scene 候選排序、最後使用 fallbackTick 的行為。
- [x] 使用 `(resolvedTick, sequence, stateChangeId)` 穩定排序；重排與 tick 邊界一致。
- [x] 將「指定來源失效但找到其他候選」與「完全 fallback」分開回報給 UI。
- [x] 實作按主體 ID 的變更索引，以及按時間軸／資料修訂失效的快取；不在全域保存每個 Tick 的完整專案。

### 驗證與完成條件

新增 `story_state_time_test.dart`；既有 `character_snapshot_test.dart` 維持通過。測試負 Tick、同 Tick、指定來源遺失、場景多 placement、無 placement、時間軸移動後重算。

## 7. P3：物品快照、歸屬操作與交易

### 建議新增

- `lib/presentation/providers/item_providers.dart`、`item_snapshot_providers.dart`。
- `lib/application/items/item_operations.dart`、`item_relation_resolver.dart`。
- 共用專案交易服務，實際位置依現有 history／collaboration 邊界決定。

### 工作

- [x] CRUD Class／實例／關聯，依型別驗證 ID，反查不儲存第二份資料。
- [x] 實作 Class 與實例 resolver；支援 exists、歸屬、所在地、屬性覆寫與明確清空。
- [x] 半專用場景新增實例以 exists=false 為預設、該 Scene 變更為 true；預設建立則自故事初始存在。
- [x] 實作單件轉交、聚合分配扣轉、解除歸屬、故事中毀損及刪除影響分析。
- [x] 已知數量不足時拒絕扣轉；未知數量提供明確直接設定操作，不假裝完成可驗證轉帳。
- [x] 本機操作一次提交 history、dirty 與狀態；失敗時不留部分資料。
- [x] 協作交易帶穩定 ID、預期操作清單或數量及完成標記；接收端完整驗證後一次投影。重送去重，不完整交易暫存且可重取／回報，不能靠一次 transport batch 當完整交易。
- [x] 定義並行修改同一持有者／分配的衝突顯示；P2P 合併不得拼出一半新、一半舊的交易。

P2P 三方合併已把物品工作區從一般專案區段拆開。兩端同時修改同一 Class、Scene 與 allocation 時，衝突對話框顯示具體物品、場景及 allocation ID，並以完整物品工作區為原子單位採用本機或對方版本；單邊變更則自動採用。即時協作交易支援跨 transport batch 暫存、亂序組裝、完整後一次投影及重送去重。

### 既有整合位置

`lib/domain/collaboration/collaboration_operation.dart`、`collaboration_protocol.dart`、`collaboration_document.dart`；`lib/application/collaboration/`；`lib/presentation/providers/collaboration_providers.dart`；`lib/data/p2p/p2p_project_merge.dart`、`p2p_project_merge_service.dart`。

現有協作有大小限制與分批送出，需測跨批、亂序與重連。若新增封套改動過大，可採能保證同等原子性的既有機制，但須以測試證明。

### 驗證與完成條件

新增 `item_snapshot_test.dart`、`item_operations_test.dart`、`project_transaction_test.dart`，擴充 collaboration／P2P 測試。三模式資料在 UI 尚未完成前已能透過操作 API 保存、推導、復原與完整同步。

## 8. P4：物品頁面、正式關聯與導覽

### 建議新增及調整

新增 `lib/modules/itemview.dart` 與物品專用元件；修改 `lib/main.dart`、`worldsettingsview.dart`、`characterview.dart`、`outlineview.dart` 的入口與選取請求。

### 工作

- [x] 清單提供搜尋、分類、模式及歸屬篩選；同名使用路徑／識別資訊區分。
- [x] 專用以單件顯示、半專用可展開實例、非專用顯示 Class 與聚合分配。
- [x] 表單包含基本設定、三段模式開關、屬性繼承狀態、一般關聯與快照入口。
- [x] 模式轉換透過預覽及專用操作提交；不直接改 enum，過期預覽會拒絕提交。
- [x] 共用物件選擇器可搜尋地點／人物／事件／場景／物品 Class／單件物品並存 ID；物品模式、所屬 Class 與目前歸屬資訊會一併顯示。
- [x] 地點、人物及事件頁加入相關物品反查，點擊可跨頁選取並展開。
- [x] 舊大綱事件及場景文字可逐筆確認「建立並連結／連結既有」；提交前重驗來源，新增關聯和移除原文字同步提交，失敗時回復原狀態。
- [x] 桌面雙欄、窄螢幕清單→詳情；物品表單直接寫入 provider，沒有跨頁遺留草稿。

### 驗證與完成條件

新增 `itemview_test.dart`、`item_selection_request_test.dart`、`item_relations_test.dart`。三種模式完成基本管理與連結，存檔重開仍保持，改名／移動後跳轉正確；沿用現有 Material 3 元件與文字處理慣例。

## 9. P5：地點樹各層快照

### 建議新增

`lib/presentation/providers/location_snapshot_providers.dart`、`lib/application/locations/location_state_operations.dart`，以及世界頁內的快照編輯元件。

### 工作

- [x] 所有 location 節點提供預設、跟隨時間軸、指定 Scene 三種檢視。
- [x] 可變欄位包含存在性、當時名稱、描述、狀態、控制者／管理者、可進入性、自訂屬性。
- [x] 固定 nodeId、nodeType、編輯樹 parent 不由快照覆寫。
- [x] 父節點變更不傳染子節點；父不存在時以樹殼呈現仍存在的子節點並提示。
- [x] 批次套用先預覽選取節點及差異，逐節點建立強型別變更，以同一交易提交。
- [x] 同 Tick 反查當地物品與聚合分配；不新增地點庫存權威表。
- [x] 移動編輯樹不改寫過去快照；永久刪除與故事中消失分開處理。

### 驗證與完成條件

新增 `location_snapshot_test.dart`、`location_snapshot_view_test.dart`。根／中間／葉節點在同 Tick 能呈現不同狀態，批次變更可原子復原及同步，三層 fixture 的早期快照不被改名或樹移動破壞。

## 10. P6：角色持有物與共用時間軸

### 工作

- [x] 角色頁新增已連結物品投影；既有 possessions 文字與歷史分開保留。
- [x] 正式物品引用可指向 Class 或 instance，角色端修改歸屬透過 P3 操作，不另寫可衝突的 possession 狀態。
- [x] 舊角色文字轉換提供預設及所有相關歷史的對照預覽；不能只搬當前表格就清除歷史文字。
- [x] 角色、物品、地點共用 currentTick；播放頭移動只更新必要投影。
- [x] 時間軸標記顯示同 Scene 受影響的角色／物品／地點，可篩選和跳轉。
- [x] 從事件新增快照時選擇或建立 Scene；多 placement 明確顯示選用來源。
- [x] 早期變更調整後顯示下游差異／衝突，不默改後續作者設定。

### 主要入口與完成條件

修改 `lib/models/character_data.dart`（如正式引用需持久化）、`lib/modules/characterview.dart`、`timelineview.dart`、`lib/presentation/providers/character_snapshot_providers.dart`、`timeline_providers.dart`。新增 `item_character_projection_test.dart` 與跨頁時間游標 Widget 測試。同一 Tick 的角色持有物、物品持有者、地點物品三者一致。

## 11. P7：模式轉換與歷史保全

### 建議新增

`lib/application/items/item_mode_conversion.dart`：先產生唯讀 conversion plan，再驗證修訂版本並提交；UI 只呈現預覽，不能自行改多份 provider。

### 工作

- [x] 專用↔半專用保留已有 instanceId；尚未實例化部分由使用者明確指定，不按未知數量大量生成。
- [x] 非專用→半專用／專用：選擇分配、數量、建立場景與新實例標籤。
- [x] 先驗證聚合量，再在同一交易扣除已拆分數量並建立實例；保留歷史 Class 分配以支援轉換前 Tick。
- [x] 專用／半專用→非專用：列出差異、歷史與引用；有身份歷史者另建聚合 Class、封存原 Class／實例並保留轉換對應。
- [x] 過去 Tick 查原身份，轉換後按有效狀態投影，不能同時把封存實例與新聚合量計入現況。
- [x] 數量未知、單件差異不可合併或引用不完整時回傳可理解原因；原模式保持不變。
- [x] 預覽後若同步改動涉及資料，拒絕提交過期計畫並重新預覽；取消不修改資料。
- [x] 封存資料可搜尋歷史但預設不出現在現況管理清單，不刪除其引用。

### 驗證與完成條件

新增 `item_mode_conversion_test.dart`，涵蓋六個方向、零／未知／大量數量、重送、過期預覽、歷史引用、取消及撤銷／重做。完成後啟用 P4 三段開關的全部安全轉換流程。

## 12. P8：整合驗收與交付

### 必要驗收情境

| 情境 | 通過條件 |
| --- | --- |
| 半專用制服在 Scene A 建立、B 轉交、C 遺失 | 各 Tick 顯示正確歸屬；ID 始終相同；A 之前不顯示 |
| 非專用金幣拆出專用紀念幣 | 拆出前仍為聚合量，拆出後不雙重計數，撤銷完整恢復 |
| 城市／街道／房屋各自改變狀態 | 各節點獨立快照，批次修改可一次撤銷 |
| 同場景轉交物品並改變地點狀態 | 本機／遠端只看到交易前或完成後的完整結果 |
| 舊專案含混合世界樹與同名物品 | 內容與 ID 保留，地點子樹不丟失，同名不誤合併 |
| 移動 Scene、移除指定 placement、重排同 Tick | 與角色時間解析一致，fallback／來源改變清楚可見 |
| 專用降級為非專用且已有歷史引用 | 原身份與引用可追溯，當前聚合不重複計數 |
| 存檔、局部匯出／匯入、備份、P2P、斷線重連 | 資料往返完整，缺少目標提示修復、不隨意匹配 |

### 檢查與交付物

- [x] 執行各階段相關測試，再執行完整 `flutter test` 及 `flutter analyze`；原有問題與本次新問題分開記錄。
- [x] 本輪未修改 Freezed 模型，無需執行 `dart run build_runner build --delete-conflicting-outputs`；既有產生碼未變動。
- [x] 使用 Windows profile runner 在 1200×900 與 600×900 實際確認建立、展開、連結、快照、轉換、返回、草稿保存與鍵盤焦點。
- [x] 效能 fixture 含 1,000 個地點、2,000 件實例、20,000 筆變更，量測首次索引與連續播放頭查詢；這是測試負載而非產品上限。
- [x] 以測試機 profile 模式記錄 frame、操作延遲及記憶體；以 500ms 明顯停頓作寬鬆回歸 guard，正式產品門檻仍由後續 P0 基線補定。
- [x] 更新使用說明、格式／協作版本說明、遷移與復原操作說明；列出尚未解決限制。
- [x] 建立 Windows x64 release candidate、驗證封裝內容並完成啟動 smoke test。
- [ ] P1–P7 完成條件全部通過後才將新功能納入正式發布；部署／發布是後續動作，本計畫不代表已執行。

## 13. 測試命令與提交拆分建議

命令在 `dart_edition/` 執行。各階段測試與大型資料效能測試均已建立並納入完整測試套件。

```powershell
# 開工先驗證既有核心
flutter test test/character_snapshot_test.dart test/project_migration_test.dart test/project_record_codec_test.dart test/p2p_project_merge_test.dart

# 各階段執行該階段實際新增／修改的測試
# 最後完整驗證
flutter test
flutter analyze
```

建議將每個 P 階段拆成「模型與操作」「存取／協作」「UI 與驗收」等可審查提交，但每個提交不得讓現有功能丟欄位。共享模型改動先整合，後續再分工 UI；提交或 PR 的建立待實際開發時進行。

## 14. 進度追蹤與風險

| 階段 | 狀態 | 最重要的退出條件 |
| --- | --- | --- |
| P0 | 已完成 | 資料入口及既有行為可驗證 |
| P1 | 已完成 | 格式 1.18、模型、codec、遷移、歷史、協作、P2P 與具 manifest 的局部匯入／匯出均已接入 |
| P2 | 已完成 | 角色、物品與地點共用 Scene 時間錨點；獨立 Tick 已移除 |
| P3 | 已完成 | 快照、聚合轉移與拆分可原子寫入；跨批協作交易與同一分配量的 P2P 原子衝突決議均已完成 |
| P4 | 已完成 | 三模式頁面、搜尋篩選、共用物件選擇器、四類目標 ID 關聯、跨頁跳轉及舊大綱文字轉換均可用 |
| P5 | 已完成 | 地點各層快照、樹殼提示、批次交易、同 Tick 物品數量及永久刪除影響清理均已完成 |
| P6 | 已完成 | 角色／物品／地點共用 Tick，時間軸有影響標記、篩選與跳轉；舊 possessions 可連同 Scene 歷史轉為正式物品 |
| P7 | 已完成 | 聚合拆出單件及專用／半專用反向建立新聚合 Class 均保留 Scene 歷史；六方向轉換均通過撤銷／重做矩陣驗收 |
| P8 | 已完成（待發布） | 自動測試、Windows profile 桌面／窄版驗收、大型資料基準、記憶體與交付文件均完成；正式發布仍是後續動作 |

### 2026-09-15 已完成的地點快照里程碑

- 所有地點層級可檢視預設、時間軸目前 Scene 與指定 Scene 狀態；快照只覆寫可變內容，不改寫節點 ID、類型或編輯樹父子關係。
- 父地點不存在時仍保留有獨立存在狀態的子地點樹殼及提示；批次建立與刪除以 transactionId 維持同批原子操作。
- 地點頁依共用 Tick 反查正式物品位置與聚合數量，不另建庫存資料來源。
- 永久刪除先預覽子樹、快照、物品關聯及位置記錄影響，確認後清除全部失效引用；故事中的消失由 Scene 快照的存在性表達。
- 批次建立快照會逐節點列出存在性、可進入性、狀態與控制者的前後差異，再以同一 transactionId 提交。

### 2026-09-17 整合驗收紀錄

- 完整 `flutter analyze`：0 error、0 warning；另有 160 項既有 info lint，集中在舊檔頭註解、命名、括號及 Flutter 棄用 API。
- 完整 `flutter test --no-pub --concurrency=2`：673 通過、1 跳過、0 失敗，約 3 分鐘完成。物品、地點、角色快照、物件選擇器、格式 1.18、匯入匯出、協作交易、P2P 物品衝突及大型資料效能均納入通過範圍；低併發避免測試機同時建立過多 Dart worker。
- 修正 P2P pending resolve ACK 訊息被同 UUID 一般協商狀態覆蓋、角色關係圖窄版工具列與主題選取色，以及新專案測試在等待 frame 前先等待 Future 所造成的逾時。
- 角色別名與 Hana 啟動畫面測試已同步現行介面契約。架構 guardrail 明列 25 組既有 `bin/file.dart`／view 傳遞循環作為 legacy allowlist，新增循環仍會使測試失敗；完整解耦保留為既有技術債。
- 新增共用 `ProjectStoryStateIndex`，物品／地點 snapshot provider 與物件選擇器不再為每個目標重掃全部變更；Scene placement 依 Scene 預先分組，查詢結果按 subject 快取。
- 大型資料 debug 測試含 1,000 個地點、2,000 件 instance 與 20,000 筆變更；最終完整回歸量測索引 26ms、首次完整投影 96ms、連續播放頭查詢 27ms。這些數字只作回歸基線；Windows profile 實機驗收結果另列於下。
- `ITEMS_AND_SCENE_SNAPSHOTS_GUIDE.md` 已整理三種物品模式、共用物件選擇器、Scene 快照、1.18 格式、協作 schema 6、舊檔遷移、備份復原與目前限制。
- Windows profile 整合測試在真實 runner 中切換 1200×900 與 600×900，完成建立、名稱保存、Scene 快照、專用→半專用、instance 展開、事件連結、返回與搜尋焦點；最終流程 5.76 秒、57 frames、build P95 10.7ms、raster P95 245.6ms、RSS 75→120MiB、max RSS 141MiB。raster 數字包含視窗縮放及首次開啟對話框，保留為後續優化基線。
- Windows Flutter Driver 在 profile mode 不會替 `TextFormField` 派送測試用 `onChanged`，因此整合測試先驗證實際 focus/input，再直接呼叫同一 callback；另有一般 widget 測試驗證名稱輸入確實寫回 workspace 與 default state。
- Windows x64 release build 於 135.3 秒完成；未壓縮內容 34 個檔案、101 MiB。啟動 smoke test 維持執行且介面有回應，主視窗標題為 `Monogatari Assistant`。封裝檔 `monogatari-assistant-0.9.19-windows-x64.zip` 為 54.56 MiB，含 EXE、Flutter DLL 與 data 目錄，SHA-256 為 `9C4B773E980B22B7C22B7AFC5AB88CB59F56DFC8841D77D33FF805FA6C6FBF0B`。

### 2026-09-15 已完成的模式轉換里程碑

- 非專用或半專用可在指定 Scene 從聚合分配拆出一件固定 ID；數量在同一狀態提交中扣除，轉換前 Tick 保留原聚合量。
- 只有一筆且數量為 1 的非專用分配可直接轉成專用；其他數量要求先用半專用逐件拆分。
- 專用或半專用轉為非專用時建立新的 Class ID，按該 Scene 當時仍存在的 instance 彙總持有人、所在地與未分配數量。
- 原 Class 與 instance 只封存，不改寫既有 conversionSource、一般關聯或快照；來源自轉換 Scene 起設為不存在，新聚合 Class 自同一 Scene 起存在。
- 資料層拒絕沿用同一 Class ID 直接改為非專用，並驗證反向聚合包含所有未封存 instance，避免半完成提交。
- 角色與地點的歷史投影會解析封存來源，因此轉換前仍可看到原單件，轉換後只計入新聚合數量。
- 聚合轉移、拆出單件與反向聚合均依所選 Scene 當下狀態計算；預覽期間物品或 placement 被修改時拒絕提交並要求重新預覽。
- 半專用只有在剩餘聚合量為零且最多一個固定 instance 時才能直接轉為專用；多個 ID 不會再被封存、合併或改寫關聯。

### 2026-09-15 已完成的物件選擇器里程碑

- 新增共用搜尋對話框，可選人物、地點、事件、場景、物品 Class 與單件物品，並可排除已連結項目及選擇是否顯示封存物品。
- 物品 Class 顯示專用／半專用／非專用模式與目前分配數；單件物品顯示所屬 Class、目前持有人及所在地。
- 物品頁新增關聯改用選擇器；人物、地點及事件頁可反向選取物品建立正式 ID 關聯，並可解除既有關聯。

### 2026-09-15 已完成的舊大綱物件轉換里程碑

- 事件及場景的舊物件文字提供逐筆轉換按鈕，可選擇既有 Class／instance，或以專用、半專用、非專用模式建立新物品。
- 專用與半專用會建立 Class 及獨立 instance；非專用只建立 Class。正式關聯分別指向事件或場景 ID。
- 提交前重新核對原文字索引與目標物品；資料已變更時不移除文字、不建立關聯，跨 provider 寫入失敗時回復兩邊原狀態。

### 2026-09-15 已完成的模式轉換復原矩陣

- 專用→半專用、專用→非專用、半專用→專用、半專用→非專用、非專用→專用、非專用→半專用均以實際操作 API 建立轉換後資料。
- 每個方向都寫入 ProjectHistory 後執行 undo 與 redo，驗證作用中的 Class 模式及完整內容 digest 回到預期版本。

### 2026-09-15 已完成的跨批協作交易

- 即時協作 schema 升至 6；typed project record 可攜帶交易 ID、片段索引與總筆數，舊的非交易 record JSON 仍可解析。
- 本機同一次快照差異中的多筆物品／地點狀態 record 會自動組成一筆穩定交易；接收端先暫存片段，收齊後才一次投影。
- 已驗證 40 筆交易跨越 32 筆傳輸批次上限並亂序抵達時不會顯示半完成狀態；完成後重送去重，索引、總數或較新並行 record 衝突會整批拒絕並回報。

### 2026-09-15 已完成的選擇式匯出矩陣

- 匯出對話框新增「物品設定與快照」及「更新計畫與伏筆」選項；預設完整選取時不再漏掉這兩個模組。
- 物品 XML／Markdown 匯出包含 Class、instance、正式關聯、Class 快照及 instance 快照；XML 可重新開啟並保留模式、數量與 Scene 變更。
- 角色匯出一併保存舊 CharacterState、快照 baseline 與 Scene 變更；世界設定匯出一併保存所有地點節點快照；大綱匯出保留共用時間軸與章節連結。
- XML 矩陣測試會實際重新解析輸出，驗證物品、角色、地點、伏筆及更新計畫資料一致；Markdown 以可讀標題和 lossless XML 區塊保存結構化快照。

### 2026-09-15 已完成的局部匯入流程

- 檔案選單新增「匯入」，讀取來源 XML 後只列出實際可用模組，並在套用前預覽缺少的人物、地點、事件、場景、Class 或 instance 引用。
- 新版選擇式 XML 含明確模組 manifest；匯入已宣告模組時會原子替換完整模組，即使來源子集合為空也能正確清空。舊 XML 沒有 manifest 時只替換實際存在的 section，避免誤刪目前資料。
- 匯入保留目前 project UUID，未選模組維持原值，套用結果標記 dirty 並寫入專案復原歷史；失效引用保留原 ID，讓使用者可透過既有物件選擇器稍後修復。

### 2026-09-15 已完成的角色舊持有物轉換

- 角色頁的舊持有物可使用共用物件選擇器連結既有正式物品，或建立專用、半專用、非專用物品；數量大於一時預設採非專用模式。
- 預覽會統計角色預設／baseline、可定位的 Scene 快照及無法可靠映射 Scene 的舊 CharacterState。前三者一次轉換，後者保留原文字並明確提示。
- 專用／半專用建立 instance holder 狀態；非專用建立帶數量的 allocation。角色 Scene possession 清單的出現／消失會轉成同 Scene 的正式持有／解除狀態。
- 角色資料、baseline、Scene changes 與物品 workspace 以同一次提交更新，提交前重新計算以拒絕過期來源，任一 provider 失敗會回復所有原資料。

最高風險是模式降級的歷史映射、角色既有物品文字的轉換、協作交易跨批及新集合漏接保存路徑。這些以先做資料測試與明確預覽處理；不以先完成漂亮頁面代表功能完成。

建議從 P0 開始，先完成 P1–P3 的可保存、可推導、可復原資料核心，再開展介面。此計畫以工作依賴與完成條件控管，尚未承諾日期或人日；P0 完成後即可依實際需修改路徑估時。
