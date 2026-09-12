# 物品管理與物品／地點快照實作計畫

日期：2026-09-13  
狀態：待實作；本次只完成規劃。  
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

- [ ] 確認當下工作樹與既有修改，避免覆寫其他工作；若採分支，使用 `codex/` 前綴。
- [ ] 盤點所有 `ProjectData(...)` 建構、empty／collaborationShell、snapshot、migration、parse／write、merge 路徑。
- [ ] 盤點世界、大綱與角色的獨立匯入／匯出入口，以及頁面選取與草稿提交方式。
- [ ] 執行既有角色快照、專案遷移、歷史、codec、P2P 核心測試，記錄原有失敗。
- [ ] 建立固定 UUID 的小型測試專案：三模式物品、同名物品、三層地點、兩角色、同 Tick 場景、多 placement、失效引用與混合世界子樹。
- [ ] 明確定義格式版本、record 種類、patch 清空／繼承語意、轉換來源與交易完成條件。

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

- [ ] 新增集合與安全空預設；所有 ProjectData 重建路徑完整傳遞新欄位。
- [ ] 地點 defaultState 成為可變描述／屬性的唯一來源；既有欄位保留讀取相容，禁止兩邊獨立寫入。
- [ ] 既有世界 item 逐筆移為專用實例，原 id 保留為 instanceId，另建 Class；不按同名合併。
- [ ] 處理 item 下的非 item 子節點提升與順序保存；記錄來源路徑及遷移警告。
- [ ] 遷移需可重入：對已遷移資料不重複新增；先於記憶體完成，不覆寫原檔，存檔才寫新版。
- [ ] 舊大綱字串與角色 possession 歷史原樣保留。
- [ ] 擴充 XML、備份、局部匯出選項、record codec、P2P 序列化與合併。
- [ ] 更新新格式／協作能力檢查；不相容的同步端拒絕參與新資料編輯。已發布舊版可能仍可強制開檔，不能宣稱新版能完全阻止它丟欄位；提供版本提示與原檔備份。

### 驗證與完成條件

新增 `item_codec_test.dart`、`location_snapshot_codec_test.dart`；擴充 `project_migration_test.dart`、`project_record_codec_test.dart`、`project_history_provider_test.dart`、`p2p_project_merge_test.dart`。fixture 經「讀取→遷移→存檔→重開→snapshot／record 往返」後 ID、欄位與引用一致。

## 6. P2：抽取共用時間解析，維持角色行為

### 建議新增

`lib/models/story_state_time.dart`：僅共用時間錨點解析及排序；各領域 patch 保持獨立型別。角色模型保留對外 API，以委派方式漸進改用共用核心。

### 工作

- [ ] 為目前角色時間解析補充行為測試，再抽取函式，避免以重構改變規則。
- [ ] 保留指定 small placement 優先、同 Scene 候選排序、最後使用 fallbackTick 的行為。
- [ ] 使用 `(resolvedTick, sequence, stateChangeId)` 穩定排序；重排與 tick 邊界一致。
- [ ] 將「指定來源失效但找到其他候選」與「完全 fallback」分開回報給 UI。
- [ ] 實作按主體 ID 的變更索引，以及按時間軸／資料修訂失效的快取；不在全域保存每個 Tick 的完整專案。

### 驗證與完成條件

新增 `story_state_time_test.dart`；既有 `character_snapshot_test.dart` 維持通過。測試負 Tick、同 Tick、指定來源遺失、場景多 placement、無 placement、時間軸移動後重算。

## 7. P3：物品快照、歸屬操作與交易

### 建議新增

- `lib/presentation/providers/item_providers.dart`、`item_snapshot_providers.dart`。
- `lib/application/items/item_operations.dart`、`item_relation_resolver.dart`。
- 共用專案交易服務，實際位置依現有 history／collaboration 邊界決定。

### 工作

- [ ] CRUD Class／實例／關聯，依型別驗證 ID，反查不儲存第二份資料。
- [ ] 實作 Class 與實例 resolver；支援 exists、歸屬、所在地、屬性覆寫與明確清空。
- [ ] 半專用場景新增實例以 exists=false 為預設、該 Scene 變更為 true；預設建立則自故事初始存在。
- [ ] 實作單件轉交、聚合分配扣轉、解除歸屬、故事中毀損及刪除影響分析。
- [ ] 已知數量不足時拒絕扣轉；未知數量提供明確直接設定操作，不假裝完成可驗證轉帳。
- [ ] 本機操作一次提交 history、dirty 與狀態；失敗時不留部分資料。
- [ ] 協作交易帶穩定 ID、預期操作清單或數量及完成標記；接收端完整驗證後一次投影。重送去重，不完整交易暫存且可重取／回報，不能靠一次 transport batch 當完整交易。
- [ ] 定義並行修改同一持有者／分配的衝突顯示；P2P 合併不得拼出一半新、一半舊的交易。

### 既有整合位置

`lib/domain/collaboration/collaboration_operation.dart`、`collaboration_protocol.dart`、`collaboration_document.dart`；`lib/application/collaboration/`；`lib/presentation/providers/collaboration_providers.dart`；`lib/data/p2p/p2p_project_merge.dart`、`p2p_project_merge_service.dart`。

現有協作有大小限制與分批送出，需測跨批、亂序與重連。若新增封套改動過大，可採能保證同等原子性的既有機制，但須以測試證明。

### 驗證與完成條件

新增 `item_snapshot_test.dart`、`item_operations_test.dart`、`project_transaction_test.dart`，擴充 collaboration／P2P 測試。三模式資料在 UI 尚未完成前已能透過操作 API 保存、推導、復原與完整同步。

## 8. P4：物品頁面、正式關聯與導覽

### 建議新增及調整

新增 `lib/modules/itemview.dart` 與物品專用元件；修改 `lib/main.dart`、`worldsettingsview.dart`、`characterview.dart`、`outlineview.dart` 的入口與選取請求。

### 工作

- [ ] 清單提供搜尋、分類、模式及歸屬篩選；同名使用路徑／識別資訊區分。
- [ ] 專用以單件顯示、半專用可展開實例、非專用顯示 Class 與聚合分配。
- [ ] 表單包含基本設定、三段模式開關、屬性繼承狀態、一般關聯與快照入口。
- [ ] 模式轉換 API 完成前，有資料的轉換入口明確停用，不提供看似可切換但只改 enum 的操作。
- [ ] 地點／人物／事件選擇器存 ID；目標不存在可修復，不按名稱補配。
- [ ] 三類頁面加入相關物品反查，點擊可跨頁選取、展開並返回原位置。
- [ ] 舊大綱文字可逐筆確認「建立並連結／連結既有」，新增關聯和移除原文字為同一交易。
- [ ] 桌面雙欄、窄螢幕清單→詳情；切頁／切專案先處理既有草稿提交。

### 驗證與完成條件

新增 `itemview_test.dart`、`item_selection_request_test.dart`、`item_relations_test.dart`。三種模式完成基本管理與連結，存檔重開仍保持，改名／移動後跳轉正確；沿用現有 Material 3 元件與文字處理慣例。

## 9. P5：地點樹各層快照

### 建議新增

`lib/presentation/providers/location_snapshot_providers.dart`、`lib/application/locations/location_state_operations.dart`，以及世界頁內的快照編輯元件。

### 工作

- [ ] 所有 location 節點提供預設、跟隨時間軸、指定 Scene 三種檢視。
- [ ] 可變欄位包含存在性、當時名稱、描述、狀態、控制者／管理者、可進入性、自訂屬性。
- [ ] 固定 nodeId、nodeType、編輯樹 parent 不由快照覆寫。
- [ ] 父節點變更不傳染子節點；父不存在時以樹殼呈現仍存在的子節點並提示。
- [ ] 批次套用先預覽選取節點及差異，逐節點建立強型別變更，以同一交易提交。
- [ ] 同 Tick 反查當地物品與聚合分配；不新增地點庫存權威表。
- [ ] 移動編輯樹不改寫過去快照；永久刪除與故事中消失分開處理。

### 驗證與完成條件

新增 `location_snapshot_test.dart`、`location_snapshot_view_test.dart`。根／中間／葉節點在同 Tick 能呈現不同狀態，批次變更可原子復原及同步，三層 fixture 的早期快照不被改名或樹移動破壞。

## 10. P6：角色持有物與共用時間軸

### 工作

- [ ] 角色頁新增已連結物品投影；既有 possessions 文字與歷史分開保留。
- [ ] 正式物品引用可指向 Class 或 instance，角色端修改歸屬透過 P3 操作，不另寫可衝突的 possession 狀態。
- [ ] 舊角色文字轉換提供預設及所有相關歷史的對照預覽；不能只搬當前表格就清除歷史文字。
- [ ] 角色、物品、地點共用 currentTick；播放頭移動只更新必要投影。
- [ ] 時間軸標記顯示同 Scene 受影響的角色／物品／地點，可篩選和跳轉。
- [ ] 從事件新增快照時選擇或建立 Scene；多 placement 明確顯示選用來源。
- [ ] 早期變更調整後顯示下游差異／衝突，不默改後續作者設定。

### 主要入口與完成條件

修改 `lib/models/character_data.dart`（如正式引用需持久化）、`lib/modules/characterview.dart`、`timelineview.dart`、`lib/presentation/providers/character_snapshot_providers.dart`、`timeline_providers.dart`。新增 `item_character_projection_test.dart` 與跨頁時間游標 Widget 測試。同一 Tick 的角色持有物、物品持有者、地點物品三者一致。

## 11. P7：模式轉換與歷史保全

### 建議新增

`lib/application/items/item_mode_conversion.dart`：先產生唯讀 conversion plan，再驗證修訂版本並提交；UI 只呈現預覽，不能自行改多份 provider。

### 工作

- [ ] 專用↔半專用保留已有 instanceId；尚未實例化部分由使用者明確指定，不按未知數量大量生成。
- [ ] 非專用→半專用／專用：選擇分配、數量、建立場景與新實例標籤。
- [ ] 先驗證聚合量，再在同一交易扣除已拆分數量並建立實例；保留歷史 Class 分配以支援轉換前 Tick。
- [ ] 專用／半專用→非專用：列出差異、歷史與引用；有身份歷史者另建聚合 Class、封存原 Class／實例並保留轉換對應。
- [ ] 過去 Tick 查原身份，轉換後按有效狀態投影，不能同時把封存實例與新聚合量計入現況。
- [ ] 數量未知、單件差異不可合併或引用不完整時回傳可理解原因；原模式保持不變。
- [ ] 預覽後若同步改動涉及資料，拒絕提交過期計畫並重新預覽；取消不修改資料。
- [ ] 封存資料可搜尋歷史但預設不出現在現況管理清單，不刪除其引用。

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

- [ ] 執行各階段相關測試，再執行完整 `flutter test` 及 `flutter analyze`；原有問題與本次新問題分開記錄。
- [ ] 只有修改 Freezed 模型時執行 `dart run build_runner build --delete-conflicting-outputs`，檢查產生碼差異。
- [ ] 使用桌面及窄螢幕實際確認建立、展開、連結、快照、轉換、返回、草稿保存與鍵盤焦點。
- [ ] 效能 fixture 建議含 1,000 個地點、2,000 件實例、20,000 筆變更，量測首次索引與連續播放頭查詢；這是測試負載而非產品上限。
- [ ] 以測試機 profile 模式記錄延遲、重建數及記憶體；以無明顯輸入卡頓、快取有界、未全樹逐筆重掃為驗收，正式數字門檻由 P0 基線補定。
- [ ] 更新使用說明、格式／協作版本說明、遷移與復原操作說明；列出尚未解決限制。
- [ ] P1–P7 完成條件全部通過後才將新功能納入正式發布；部署／發布是後續動作，本計畫不代表已執行。

## 13. 測試命令與提交拆分建議

命令在 `dart_edition/` 執行。新增測試檔須在實作後才可執行；本輪未建立這些程式或測試。

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
| P0 | 未開始 | 資料入口及既有行為可驗證 |
| P1 | 未開始 | 新舊資料全通道保存完整 |
| P2 | 未開始 | 角色解析行為不變，三領域可共用 |
| P3 | 未開始 | 狀態與交易可保存、復原、完整同步 |
| P4 | 未開始 | 三模式頁面與三類 ID 跳轉可用 |
| P5 | 未開始 | 地點每層快照與批次操作可用 |
| P6 | 未開始 | 角色／物品／地點同 Tick 一致 |
| P7 | 未開始 | 六方向轉換保留身份、數量與歷史 |
| P8 | 未開始 | 整合測試、UI、效能和文件完成 |

最高風險是模式降級的歷史映射、角色既有物品文字的轉換、協作交易跨批及新集合漏接保存路徑。這些以先做資料測試與明確預覽處理；不以先完成漂亮頁面代表功能完成。

建議從 P0 開始，先完成 P1–P3 的可保存、可推導、可復原資料核心，再開展介面。此計畫以工作依賴與完成條件控管，尚未承諾日期或人日；P0 完成後即可依實際需修改路徑估時。
