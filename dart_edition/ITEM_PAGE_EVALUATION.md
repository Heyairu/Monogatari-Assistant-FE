# 物品三種管理模式與物品／地點時間軸快照評估

更新日期：2026-09-13  
狀態：需求與架構提案，尚未實作。此版取代原先推薦 A 方案及將快照延後的範圍。

後續施工請參考：[物品管理與物品／地點快照實作計畫](ITEM_SNAPSHOT_IMPLEMENTATION_PLAN.md)，包含 P0–P8 相依順序、工作清單、修改入口與完成條件。

## 1. 已確認方向

採用 B 方案，將物品從世界設定獨立為專案資料，提供「專用／半專用／非專用」三種管理模式；物品可連結地點、人物、事件，同時支援時間軸快照，並將快照擴及地點樹的每個節點。

| 模式 | 使用者指定的行為 | 建議資料語意 |
| --- | --- | --- |
| 專用 | 獨立 ID | 每件物品都有穩定 instanceId，可獨立設定與追蹤歷程 |
| 半專用 | 收在一個 Class，Class 可展開各件已有歸屬的物品 | Class 保存共用設定；有歸屬的單件建立 instanceId，收在 Class 下 |
| 非專用 | 一個 Class | 只管理類別，不替每件實物建立 ID；可用數量／分配資料描述歸屬 |

本文件將 Class 解讀為「物品類別資料」，不是每種物品產生一個 Dart class。三種模式用一個互斥的三段式開關切換，避免三個布林開關產生無效組合。

以下是落地設計建議：模式以每個物品 Class 為單位，因此同一專案可混用三種模式；「專用」指獨立識別，不限制只能有一位所有者。「地點每個節點」包含所有深度的 location 節點；組織與規則可共用未來介面，但不自動納入本次地點快照範圍。

## 2. 現有程式依據

| 基礎 | 已觀察行為 | 影響 |
| --- | --- | --- |
| `lib/models/world_settings_data.dart` | `LocationData` 有 UUID、名稱、分類、備註、自訂欄位、child；`WorldNodeType` 已含 item | 遷移既有物品，地點快照以原節點 ID 為主鍵 |
| `lib/models/outline_data.dart` | 故事線、事件、場景都有字串 item 清單；場景 location 也是文字 | 舊文字不能直接當 ID，需保留及手動連結 |
| `lib/models/character_snapshot_data.dart` | 角色預設狀態、patch、場景變更與 Tick resolver 已存在 | 沿用時間解析與狀態推導概念，新增物品／地點型別 |
| `lib/presentation/providers/character_snapshot_providers.dart` | 使用時間軸 currentTick 投影角色快照 | 三種實體應共享同一時間游標 |
| `lib/models/character_data.dart` | `CharacterPossessionEntry` 目前為 name、quantity、description，沒有物品 ID | 必須新增正式物品引用，處理角色持有物與物品歸屬的一致性 |
| `lib/models/project_data.dart` | 有世界、角色、角色狀態與 timelineDocument 等集合 | 新集合需納入所有建構、複製、歷史、存取與同步路徑 |

角色快照規劃文件可作背景，但部分段落仍描述舊階段；本評估以目前模型與 resolver 程式行為為準。

## 3. 三種模式的具體體驗

### 3.1 專用

例：「祖父的銀色懷錶」。每件都有獨立 ID，清單直接顯示單件，可記錄獨有名稱、設定、所有者、持有者、所在地、完好程度與場景歷程。

底層仍可保留 Class 作共用定義，但介面不強迫顯示只有一件物品的分類外框。尚無歸屬的專用物品也有 ID；獨立身份不依歸屬而存在。

### 3.2 半專用

例：「學院制服」。清單先顯示 Class，展開後顯示「小夏的制服」「悠人的制服」等已建立歸屬的單件。

- Class 保存共用名稱、用途、材質與預設屬性；單件保存差異和獨立歷程。
- 新增歸屬時建立一件實例，或選取已存在的實例轉移；不能每次轉手都建立新 ID。
- 已實例化的物品即使解除歸屬、遺失或損毀，仍保留原 ID 與歷程；介面可收在「無歸屬／歷史物品」篩選下。
- 共用定義可先存在，不必憑空產生未指派單件；若使用者要指定某件無主但重要的物品，可明確建立實例。
- 在時間 T 展開，只顯示 T 時已存在的實例；未來才取得歸屬的物品不能洩漏到較早快照。提供「全部歷程」模式檢查未來紀錄。

### 3.3 非專用

例：「金幣」。只顯示一個 Class，不展開單件；可顯示「小夏 20 枚、倉庫 100 枚」等聚合分配。

Class 本身仍有 classId 供關聯及快照使用；分配列可有 allocationId 作編輯、合併與同步的技術識別，但不是單件物品 ID。

數量建議採選填非負整數與 Class 單位。未知數量用未設定，不以 0 代替；第一版不加入重量換算及完整庫存帳本。若數量未知，不提供宣稱已驗證守恆的扣轉操作。

## 4. 獨立資料模型（擬議）

```text
ProjectData
  itemClasses: Map<classId, ItemClassData>
  itemInstances: Map<instanceId, ItemInstanceData>
  itemRelations: List<ItemRelationData>
  itemClassStateChanges: List<ItemClassStateChange>
  itemInstanceStateChanges: List<ItemInstanceStateChange>
  locationStateChanges: List<LocationStateChange>

ItemClassData
  classId, mode: dedicated | semiDedicated | generic
  name, category, description, unit, customFields
  defaultState: ItemClassState

ItemInstanceData
  instanceId, classId, nameOverride, description
  defaultState: ItemInstanceState
  migrationOrigin: 原世界節點 ID／路徑（選填）

ItemRelationData
  relationId
  subjectType: itemClass | itemInstance
  subjectId
  targetType: location | character | event
  targetId, relationType, note

StateChange（共用封套；patch 維持各領域的強型別）
  stateChangeId, subjectId
  sceneUUID, sourcePlacementUUID?
  fallbackTick, sequence, transactionId?, note
  patch: ItemClassPatch | ItemInstancePatch | LocationPatch
```

這些名稱皆是新設計，尚不存在於程式。預設狀態只保存一份：物品放主資料，地點放節點的 defaultState；不新增另一份可同時編輯的 baseline 表。既有角色 baseline 相容流程仍保留。

ID、classId 歸屬與模式是資料管理設定，不隨故事 Tick 自動切換。半專用實例的「何時開始存在」由快照中的 exists 狀態處理；在場景新增者預設 exists=false，該場景設為 true；故事開始前已有者在預設狀態設為 true。exists=false 不等同資料刪除。

## 5. 快照可變欄位

| 對象 | 可快照內容 | 不隨 Tick 改變 |
| --- | --- | --- |
| 物品 Class | 共用用途／狀態、自訂屬性；非專用模式的數量分配 | classId、管理模式、索引用名稱、分類 |
| 物品實例 | exists、所有者、持有者、所在地、狀態、實例屬性覆寫 | instanceId、classId、作者設定筆記 |
| 每個地點節點 | exists、當時名稱、描述、地點狀態、控制者／管理者、可進入性、自訂屬性 | nodeId、nodeType、編輯樹 parent、作者筆記 |

所有者、持有者與所在地分開建模，不因「屬於某人」就推定正在隨身攜帶。已識別角色與地點均存 ID，未知狀態用明確的未設定／未知值。

單件建議預設一個實際持有者與一個實際所在地；共同所有權可用所有者清單表達。容器、多人共同攜帶及依人物移動自動推算位置不在此版自動處理。

Class 屬性採「該 Tick 的 Class 狀態＋該 Tick 的實例覆寫」解析。未覆寫的值會繼承 Class 變更；明確覆寫者保持原值。屬性編輯必須區分「繼承」「清空」「設定」，不能把清空誤當成恢復繼承。

地點固定名稱用於搜尋；快照可另顯示當時名稱。新欄位應從既有 localName、note、customVal 建立預設資料，並明確指定後續單一編輯來源，不能讓新舊欄位各保存不同的可變描述。

## 6. 時間軸與場景錨點

物品、地點和角色共用 `TimelineViewState.currentTick`。快照是指定時間的推導結果，與 undo/redo 的專案歷史快照不同；不逐 Tick 儲存完整複本。

時間解析沿用目前角色 resolver：

1. 變更綁定 sceneUUID；若 sourcePlacementUUID 對應同一 Scene 的 small placement，採該 placement。
2. 未指定或指定 placement 無法使用時，從同一 Scene 的 small placements 按 `(startTick, track.order, placementUUID)` 選第一筆。
3. 找不到候選時才採 fallbackTick，顯示「未排定／連結失效」。指定來源失效但改用其他候選時，也補充顯示來源已改變。
4. 同一對象的變更依 `(resolvedTick, sequence, stateChangeId)` 排序，套用所有 `resolvedTick <= currentTick` 的 patch。
5. 場景移動後重新推導；同 Tick 的 sequence 可明確調整，UUID 只作穩定排序的最後依據。

事件頁的關聯以 storyEventUUID 為目標；時間變更以 Scene 為錨點，兩者用途不同。從事件新增變更時需選該事件的 Scene，沒有 Scene 時可快速建立，不把事件 UUID 填入 sceneUUID。

Patch 未提供欄位代表不變更；空集合代表清空；可空純量採明確 keep／set／clear 語意。自訂屬性需額外表達 inherit。一般編輯只寫實際差異；「複製完整快照」可明確寫入全部欄位，且不得共享可變集合。

場景／placement 遺失時保留狀態變更及回退時間，提供修復入口。平行軌道先共用一條狀態序列，不能宣稱支援平行宇宙分支；來源 placement 只是時間定位，不是分支隔離。

## 7. 地點樹每個節點的快照

- 根節點、中間節點、葉節點均可獨立新增場景變更，不只最末層地點。
- 移動播放頭時，整棵樹以同一 Tick 投影；展開父節點後再按需載入子節點狀態。
- 父節點狀態不自動覆蓋子節點。例如城市被占領，不直接修改所有房屋的管理者。
- 若需要同場景改變一整個地區，提供「套用至選取節點」預覽；為各節點建立明確變更並共用 transactionId，可整批復原。
- 編輯樹只表示資料整理結構，移動節點不改寫過去；地理隸屬隨時間變動是另一個需額外建模的欄位，不能借用編輯樹 parent。
- 父節點在 T 不存在、子節點卻存在時，保留樹殼並顯示不一致提示，不靜默隱藏子節點；作者可修正或保留其設定。
- 「本地點物品」由同 Tick 的實例所在地及非專用分配反查，不在地點快照再存一份庫存。
- 地點毀損或消失使用故事狀態，不直接刪除資料；永久刪除需處理子節點與所有歷史引用。

## 8. 歸屬資料與角色快照一致性

必須區分不帶時間的「相關人物／製作者／相關事件」與帶時間的「所有者／持有者／所在地」。後者以物品狀態為唯一權威，不同時寫入 itemRelations 當作另一份現況。

角色目前的 possessions 是純文字表格。建議角色頁保留「未連結文字」，新增「已連結物品」區塊，於同 Tick 從物品狀態反查：專用與半專用指向 instanceId，非專用指向 classId 的聚合分配。

- 角色頁編輯已連結物品的歸屬時，實際呼叫物品變更操作；不再另寫一筆可衝突的角色 possession 快照。
- 舊角色表格、舊角色快照的物品名稱原樣保留；使用者確認後才能轉成正式引用，不按同名自動對應。
- 未轉換的歷史文字與已連結物品分區呈現，不自動加總數量；轉換工具應顯示涉及的預設值和所有歷史快照，而非只改當前角色卡。
- 轉交專用／半專用物品使用同一 instanceId 更新持有者；非專用扣轉在同一個 Class patch 原子更新來源與目的分配，已知來源量不足時拒絕。
- 物品轉交與地點變更可共用 transactionId 一次存檔、復原和同步。transactionId 本身不足以保證原子性，提交端和協作端須實作完整交易或完整後才套用。
- 修改早期變更後重算下游並顯示衝突；不得為了符合新持有者而靜默改寫後續作者設定。

## 9. 三段開關的模式轉換

開關是資料轉換入口。無資料影響時可直接切換；涉及 ID、歷史或聚合時先呈現具體預覽，確認後以單一可復原操作提交。

| 轉換 | 建議規則 |
| --- | --- |
| 專用 → 半專用 | 保留所有 instanceId 與歷史，只改 Class 下的收合呈現；無歸屬單件不消失 |
| 半專用 → 專用 | 已有實例保留 ID；未實例化部分需明確建立哪些單件，不能自動按未知數量生出物品 |
| 非專用 → 半專用 | 選擇要識別的歸屬及數量，建立新 instanceId；以既有分配的明確拆分處理，避免雙重計數 |
| 非專用 → 專用 | 先列出需建立的單件；數量未知或極大時要求完成明確拆分，不能無上限自動產生 |
| 專用／半專用 → 非專用 | 預覽會失去的單件差異；有單件歷史或引用時，採另建聚合 Class、封存原實例的安全轉換，不直接刪除身份 |

模式屬編輯設定，不是時間事件；轉換若涉及數量拆分或身份建立，必須另記明確場景變更及 provenance。新增身份不代表過去已能辨識每一枚物品。

原 Class 與實例有不可合併的歷史時，不讓開關假裝無損切換成功。可保留原 Class 為唯讀歷史並連至新 Class；舊事件仍指向原 ID。在完成歷史映射前，維持原模式而非抹掉資料。

## 10. 頁面與互動

桌面採左清單、右詳細頁；窄螢幕分清單與詳細頁。保留篩選、展開、選取及返回位置。

Class 詳細頁包含名稱、分類、說明、自訂屬性、三段模式開關、關聯及快照。半專用顯示可展開實例，非專用顯示聚合分配，專用以單件為主要瀏覽單位。

物品與每個地點節點共用「預設／跟隨時間軸／選擇場景快照」操作：

- 預設：編輯故事變更之前的初始狀態，提示會影響未覆寫的歷史。
- 跟隨時間軸：唯讀顯示當前 Tick、來源 Scene、回退標記及差異摘要。
- 選擇場景快照：編輯該變更，或從已有快照複製；新增時先選擇／建立 Scene。
- 時間軸標記可按角色、物品、地點篩選；同場景可列出所有受影響對象並跳轉。

地點、人物、事件頁均顯示相關物品並依 ID 雙向跳轉。區分「一般關聯」與「此 Tick 的歸屬」，避免作者把全作品關係當成當前狀態。

## 11. 遷移、儲存與協作

1. 將既有世界 item 節點遷移成獨立物品，保留原 ID 作 instanceId，新增 classId；無法判斷用途時先採專用以保留身份，不按同名合併。
2. 原世界父路徑保存為遷移資訊，不自動推定為所在地或容器關係。物品節點下若有地點等非物品子節點，提升到最近保留祖先並保留順序／來源路徑，列出遷移警告；物品子節點各自遷移。
3. 地點保留原 ID，既有描述與自訂欄位轉為預設狀態；不憑空生成故事事件。
4. 大綱 item 與角色 possessions 舊文字先保留，提供確認連結；舊資料未指定時間則放預設或保持文字，不猜測 Scene。
5. 新集合與節點狀態完整納入 `.mnproj`、備份、XML codec、快照複製、dirty 狀態、專案切換及 undo/redo。
6. 協作 records、文字 codec、P2P 合併及能力版本一併更新。未知新格式的舊客戶端不能重新儲存後靜默丟掉物品／地點歷史。
7. 跨專案匯入需重映射 Class、實例、地點、Scene、placement 與交易引用；無法解析者保留失效資訊，不能以同名猜測。
8. 刪除物品／Class／地點前顯示整個引用與歷史影響；故事中的消失優先用狀態表示，永久刪除不得留下不可辨識的歷史。

## 12. 實作範圍與交付順序

| 階段 | 交付內容 | 相對工作量 |
| --- | --- | --- |
| 1. 資料基礎 | B 方案 Class／實例／關聯、三模式不變條件、世界物品遷移 | 大 |
| 2. 共用快照基礎 | 抽取並測試既有時間解析、各領域 patch、交易及 provider；角色行為不退化 | 大 |
| 3. 物品介面 | 三模式清單與表單、歸屬、事件／人物／地點關聯、轉換預覽 | 大 |
| 4. 時間整合 | Class／實例快照、角色持有物投影、時間軸標記 | 大 |
| 5. 地點快照 | 每層節點狀態、樹投影、批次變更、同 Tick 物品反查 | 大 |
| 6. 完整驗證 | 全格式往返、歷史、協作、P2P、匯入匯出、效能與跨裝置 UI | 大 |

各階段的資料保存與測試要隨功能完成，不能直到最後才加入。這是大型跨模組功能；物品與地點快照已是正式交付範圍，不再列為可省略的第二版。人日需待施工拆解後評估。

既有主要入口包括 `lib/models/project_data.dart`、`world_settings_data.dart`、`character_data.dart`、`character_snapshot_data.dart`、`project_migrator.dart`；`lib/presentation/providers/project_state_providers.dart`、`project_snapshot_utils.dart`、`project_history_provider.dart`、`character_snapshot_providers.dart`、`project_io_providers.dart`；`lib/modules/` 的世界、角色、大綱及時間軸頁；`lib/main.dart`、`lib/bin/file.dart`、`lib/models/codecs/`、`lib/application/collaboration/` 與 `lib/data/p2p/`。

新模組建議拆成物品主模型、物品快照、地點快照、共用時間解析及交易服務。共用封套和時間演算法即可，不把所有領域欄位塞進無型別 Map，也不直接重寫整套角色快照。

## 13. 驗收條件

- 三模式可並存，切換不產生無效組合；專用每件 ID 唯一、半專用 Class 可展開、非專用不產生單件 ID。
- 半專用物品轉手後 ID 不變；解除歸屬、損毀後仍可查歷史，早於建立時點不出現在當時清單。
- Class 屬性更新只影響繼承欄位；設定、清空及恢復繼承有不同結果。
- 同 Tick 的角色持有物、物品歸屬和地點物品列表一致；非專用分配不與已拆出的實例重複計數。
- 同 Tick 排序穩定；場景移動、多 placement、失效來源及 fallback 行為與角色快照一致並有提示。
- 地點根、中間、葉節點都能有不同歷程；父節點變更不靜默覆蓋子節點，批次操作可整批復原。
- 早期 patch 修改後下游重算；清空與未修改不同，場景快照不覆寫固定 ID 或管理模式。
- 有歷史的降級轉換不能丟失身份；封存與新聚合之間可追溯，取消預覽不改資料。
- 舊世界物品、混合子樹、舊大綱和角色持有物遷移不遺失；同名不自動錯配。
- 重開專案、備份還原、undo/redo、協作往返與 P2P 衝突處理後結果一致，不產生半完成轉交。
- 播放頭移動以對象 ID 索引變更，快取按時間軸與資料修訂失效；大樹不逐節點重掃全部歷史。

測試需涵蓋模型／codec、遷移、三模式轉換、resolver、跨實體交易、歷史與同步，以及清單展開、快照切換、三類跳轉的 Widget 測試。此輪只更新規劃文件，未修改應用程式或執行功能測試。
