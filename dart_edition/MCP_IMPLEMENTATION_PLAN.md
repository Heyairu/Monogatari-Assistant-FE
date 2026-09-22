# MonoAshi MCP 唯讀整合實作計畫

日期：2026-09-20  
狀態：Phase 0–4 實作完成；Phase 5 自動化與 Windows 驗收完成，macOS／Linux 打包及第二個外部 Host 人工驗收 pending
適用範圍：`dart_edition/` 的 Windows、macOS、Linux 桌面版  
關聯文件：[Copilot Ask／Plan 計畫](COPILOT_ASK_PLAN_IMPLEMENTATION_PLAN.md)、[Beta 8 開發計畫](BETA8_DEVELOPMENT_PLAN.md)、[P2P 同步設計](P2P_LAN_SYNC_DESIGN.md)

## 1. 目標與結論

本計畫讓外部 MCP Host（例如支援 MCP 的 AI 助理）可以以**受使用者授權、受大小限制、僅唯讀**的方式查詢目前開啟的 MonoAshi 專案。

首版的目標不是複製 Copilot 的聊天 UI，也不是讓外部模型直接改稿；而是讓 MCP 與 Copilot Ask／Plan 共用同一份作品 context 契約、穩定 ID、資料上限與 Plan 驗證規則。外部 Host 負責選擇模型、管理模型帳號與產生對話；MonoAshi MCP 只提供受控的作品資料與唯讀驗證能力。

### 1.1 成功定義

1. 使用者在桌面版明確啟用 MCP、選擇目前專案後，MCP Host 可以以 stdio 連線並列出唯讀工具。
2. MCP tool 對同一個 `ProjectData` 輸出的資料，與 Copilot Ask 所見的資料具有一致的 stable ID、內容截斷、資源排序與 fingerprint。
3. 外部 Host 能取得章節、專案摘要、角色、世界觀、大綱事件、術語資料，並可搜尋與分頁，不會預設傳出整部作品正文。
4. 模型產生的 Plan 可由 MonoAshi 驗證 schema、目標 ID、action allowlist 與 context fingerprint，但 MCP 不會套用任何變更。
5. 未啟用、未開啟專案、IPC 驗證失敗、工具輸入無效或超出資料預算時，回傳安全且可理解的錯誤，不洩漏作品內容、路徑、token 或 API key。

### 1.2 首版不包含

- 將 Copilot Chat history、provider、API key 或模型設定同步到 MCP Host。
- 自動傳送整份 `.mnproj`、所有正文或背景索引。
- 修改章節、角色、世界觀、大綱、時間軸或設定。
- 檔案系統、Shell、網路或任意程式執行工具。
- LAN / 公網 MCP endpoint、雲端 gateway、帳號、配額或 telemetry。
- Android、iOS、Web 的 MCP server。
- Agent 自主迴圈或多步寫入。

## 2. Copilot 與 MCP 的功能對照

| Copilot 功能 | MCP 對應 | 首版處理方式 |
| --- | --- | --- |
| Chat（不自動附帶作品內容） | 外部 Host 的一般對話 | 不由 MonoAshi MCP 實作。 |
| Ask：目前章節 | `get_chapter`、`get_context_bundle` | 依章節 ID 讀取，回傳 bounded snapshot 與 fingerprint。 |
| Ask：章節＋專案索引 | `get_project_summary`、`list_chapters` | 僅傳 metadata／索引，不傳其他章節正文。 |
| Ask：選取角色、世界觀、大綱、術語 | `search_project_entities` 及類型 getter | 呼叫端先搜尋或使用 ID 明確選取；沿用每筆與合計 byte budget。 |
| Ask：來源引用 | `monoashi://` URI、resource ID、fingerprint | 每個結果帶可追溯來源，不將顯示名稱當 key。 |
| Plan：唯讀提案 | `validate_readonly_plan` | Host 產生 JSON，MonoAshi 驗證但不寫入。 |
| Agent：寫入與多步執行 | 無 | 明確不公開。 |

> **重要差異：** MCP server 不會呼叫 Copilot 已設定的模型 provider。因此 MCP 的「同步」是同步**作品資料契約與安全邊界**，不是同步聊天內容、API key 或模型回覆。

## 3. 架構決策

### 3.1 採用：共用唯讀查詢層 + stdio sidecar + localhost IPC

```text
ProjectData / Riverpod providers
              |
              v
     StoryReadApi / ProjectReadSnapshot
       |                          |
       v                          v
Copilot Ask / Plan          MonoAshi App IPC bridge
                                      |
                                      v
                    monoashi-mcp sidecar（stdio / JSON-RPC）
                                      |
                                      v
                                MCP Host / 外部模型
```

此架構保留 MCP 的 stdio 相容性，同時由 App 提供目前記憶體中的專案狀態。sidecar 只做 MCP lifecycle、schema 驗證、分頁與轉送；它不能直接存取任意檔案，也不能自行建立網路 listener。

### 3.2 不採用方案

| 方案 | 不採用原因 |
| --- | --- |
| sidecar 直接讀取 `.mnproj` | 工期較低，但與 App 內目前狀態、選取章節及尚未寫入磁碟的資料可能不同，無法保證與 Copilot 一致。 |
| App 直接公開 Streamable HTTP | 部分 Host 只支援 stdio；還要處理 endpoint 發現、Origin、CORS、認證與 HTTP session。可作為後續選配 transport。 |
| 將 MCP server 放到雲端 | 改變 MonoAshi local-first 與 BYOK 邊界，會新增帳號、內容保存、權限、網路與營運責任。 |
| MCP 直接 dispatch Riverpod notifier | 任何模型或 Host 錯誤都可能改動專案，且無法滿足 preview、確認、history、undo、P2P conflict requirements。 |

### 3.3 平台與啟動策略

- 首版只封裝 Windows、macOS、Linux 的 `monoashi-mcp` companion executable。
- 使用者在 MonoAshi 設定頁啟用「MCP 唯讀整合」，App 才建立 IPC endpoint 與短期 session secret。
- MCP Host 以設定檔啟動 sidecar；sidecar 從受限的 app-private session descriptor 取得 loopback endpoint 與一次性 secret。
- App 關閉、切換專案、使用者停用整合或 session 過期時，立即撤銷 capability；sidecar 後續呼叫一律失敗，不嘗試讀取磁碟 fallback。
- IPC 僅可綁定 loopback，禁止 `0.0.0.0` 或 LAN listener。

## 4. 共用資料契約

### 4.1 新增 domain 邊界

建立 `lib/features/story_read/`，而不是讓 MCP import `CopilotView` 或反向依賴 Riverpod UI：

```text
lib/features/story_read/
├── domain/
│   ├── project_read_snapshot.dart
│   ├── project_read_resource.dart
│   ├── project_read_query.dart
│   ├── project_read_result.dart
│   └── readonly_plan_validation.dart
├── application/
│   ├── project_read_snapshot_builder.dart
│   ├── project_entity_search.dart
│   ├── project_read_budget.dart
│   └── readonly_plan_validator.dart
└── data/
    └── project_read_gateway.dart
```

`CopilotProjectContextBuilder` 逐步改為使用這個 domain API，MCP bridge 也只接收已建立的 immutable `ProjectReadSnapshot`。domain 層不得讀取 Widget、`BuildContext`、socket 或直接修改 provider。

### 4.2 資源類型與 stable ID

首版 resource allowlist：

| type | ID | 預計支援資料 |
| --- | --- | --- |
| `project` | session-scoped project ID | 基本資訊、統計與摘要索引 |
| `chapter` | `chapterUUID` | 章節標題與受限正文 |
| `character` | `characterId` | 角色設定與摘要 |
| `worldSetting` | `LocationData.id` | 世界觀／地點樹節點 |
| `outlineEvent` | storyline / event UUID | 大綱、事件、場景摘要 |
| `glossaryTerm` | glossary entry ID | 術語資料 |
| `foreshadow` | 既有 foreshadow stable ID | 僅在 ID／codec 穩定後啟用 |
| `updatePlan` | 既有 update plan stable ID | 僅在 ID／codec 穩定後啟用 |

不得以顯示名稱、列表 index、檔案路徑或永久 `projectUUID` 當作 MCP 對外識別碼。對外 project ID 應由 `projectUUID + session nonce` 派生，且 session 結束即失效。

### 4.3 資料限制

初始值對齊 Copilot 現況；所有上限都必須集中於 `ProjectReadBudget`，不可讓 Copilot 與 MCP 各自定義。

| 項目 | 上限 |
| --- | ---: |
| 單一章節正文 | 72 KiB UTF-8 |
| 專案摘要 | 24 KiB UTF-8 |
| 補充 resource 數量 | 12 |
| 單一補充 resource | 8 KiB UTF-8 |
| 補充 resource 合計 | 32 KiB UTF-8 |
| MCP `list_*` 預設頁面 | 50 筆 |
| MCP `list_*` 最大頁面 | 100 筆 |
| tool result 最大序列化大小 | 依 transport 實作設定，初始 256 KiB |

每個結果至少回傳 `schemaVersion`、`type`、`id`、`title`、`truncated`、`fingerprint` 與 `sourceUri`。若資料因預算被排除，回傳 `omitted` / `nextCursor` 等 metadata，不靜默宣稱結果完整。

## 5. MCP Tool 與 Resource 契約

### 5.1 首版工具

| Tool | 輸入 | 輸出 | 資料邊界 |
| --- | --- | --- | --- |
| `get_project_summary` | 無 | 專案摘要、種類計數、索引截斷資訊 | 不含其他章節正文。 |
| `list_chapters` | `cursor`、`limit` | 章節 ID、標題、排序位置 | metadata only。 |
| `get_chapter` | `chapterId`、可選 `maxBytes` | bounded 正文、fingerprint | 最大值不能突破 server budget。 |
| `search_project_entities` | `query`、`types`、`cursor`、`limit` | 可選資源 ID／標題／類型／摘要 | 不回傳完整內容。 |
| `get_project_entity` | `type`、`id`、可選 `maxBytes` | 單一受限資源 | type 與 id 必須存在於 allowlist。 |
| `get_context_bundle` | `chapterId`、`resourceRefs[]` | 對應 Copilot Ask 的 bounded context 與 fingerprint | resourceRefs 最多 12 個。 |
| `validate_readonly_plan` | `plan`、`contextFingerprint` | validation result、errors、resolved targets | 不持久化、不執行。 |

`get_context_bundle` 是「與 Copilot Ask 同步」的主要工具：呼叫端需要跨資源問答時，必須主動指定章節與 resource IDs，而非讓 server 預設匯出全專案。

### 5.2 Resources

首版 resources 是 tools 的可追溯補充，不做自動訂閱：

```text
monoashi://session/{sessionId}/project/summary
monoashi://session/{sessionId}/chapter/{chapterId}
monoashi://session/{sessionId}/{type}/{id}
```

- URI 只在目前 session 有效。
- resource read 採與對應 tool 相同的 permission 與 byte budget。
- v1 不宣告 `subscribe`，避免 editor 每次變更都對外推送內容。
- project 切換或 snapshot generation 改變時，可送出 list-changed notification；實際 support 與否必須依 Host compatibility 測試決定。

### 5.3 Plan 驗證契約

`validate_readonly_plan` 沿用 Copilot 的 `CopilotPlan` schema，並新增／保留以下不可變規則：

1. raw JSON 與每個文字欄位皆有 byte / length limit。
2. `schemaVersion` 必須相容。
3. `contextFingerprint` 必須與剛剛提供的 context 完全相符。
4. `targetType` 與 `action` 必須在 allowlist。
5. 非 `create` action 的 `targetId` 必須位於提供給 Host 的 context snapshot。
6. step ID 與順序唯一，依賴關係無循環。
7. 合法結果只作為「可顯示的唯讀提案」；結果不能被 converter 自動轉成 `UpdatePlanItem` 或 notifier 呼叫。

## 6. 安全與隱私需求

### 6.1 權限模型

1. 預設關閉 MCP。
2. App 以目前開啟的專案為唯一 scope；切換或關閉專案後撤銷舊 session。
3. 使用者啟用時，UI 顯示將公開的 resource types、資料上限與「僅本機」性質。
4. 可隨時在 App 中停止 session；停止後 sidecar 不可存取快取的作品內容。
5. App 不記錄正文、prompt 或 MCP 回傳內容到 telemetry；audit log 只記錄時間、tool 名稱、成功／失敗與截斷狀態，且可關閉。

### 6.2 IPC 與 transport

- sidecar 與 App 使用 random、短期、單 session capability token；不得使用硬編碼 token、永久 token 或 API key。
- token 不出現在 stdout、錯誤文字、log、URI、process command line 或 crash report。
- loopback HTTP 必須限制 Host header、驗證 Origin，拒絕 redirect；或優先採 named pipe / Unix domain socket，並實作等效的 peer/session 驗證。
- 每個 IPC / MCP request 有 timeout、body size limit、cancellation 與 per-session concurrency limit。
- 所有 JSON schema 都拒絕未預期欄位與過深／過大的巢狀結構。

### 6.3 Prompt injection 與資料品質

- 作品正文、角色備註、世界觀與大綱皆是**不可信資料**，MCP output 要提供資料而不是解讀其中的命令。
- tool description 不宣稱資料完整或可安全執行寫入。
- 所有 tool 輸入都先驗證 type、ID、cursor、page size 與 byte budget。
- 搜尋結果、resource title 與 error message 都要清理，不把檔案路徑、內部例外、session secret 或未授權內容放到 Host。

## 7. 分階段實作步驟

### Phase 0：設計凍結與基線（2–3 人日）

執行結果與凍結決策見 [MCP_PHASE0_BASELINE.md](MCP_PHASE0_BASELINE.md)。

1. 確認 desktop-only、stdio sidecar、readonly-only 與不讀磁碟 fallback 四項決策。
2. 盤點每種資料的 stable ID；未穩定的 `foreshadow` / `updatePlan` 從 v1 移除。
3. 為 3 組匿名化測試專案建立 fixture：小型、長章節／大量資源、特殊字元／重複名稱／失效引用。
4. 以現有 Copilot builder 輸出作為 parity 基線，記錄 byte size、排序、truncation 與 fingerprint。
5. 建立 threat model：惡意 Host、惡意作品文字、sidecar 被替換、DNS rebinding、過大 payload、舊 session 重放。

**完成條件：** 有 tool 名稱、schema 版本、資源 type allowlist、支持平台與 threat model 的書面決策；不修改產品行為。

### Phase 1：抽出共用唯讀讀取層（4–6 人日）

執行結果與共用 API 見 [MCP_PHASE1_IMPLEMENTATION.md](MCP_PHASE1_IMPLEMENTATION.md)。

1. 建立 `story_read` domain models、`ProjectReadBudget` 與 immutable snapshot builder。
2. 將 `CopilotProjectContextBuilder` 的資源選取、排序、UTF-8 截斷與 overview 組裝遷移至共用層。
3. 新增 chapter index、entity search、單筆 entity resolve 與 context bundle builder。
4. 以 project snapshot 而非 widget state 當輸入；bridge 只在 UI 層取用 `projectDataProvider` 與目前選取章節。
5. 替 Copilot 加入 regression tests，驗證抽取後 Ask／Plan payload 不改變。

**完成條件：** Copilot 與 mock MCP caller 對相同 fixture 取得 byte-identical canonical resource payload 和相同 fingerprint。

### Phase 2：唯讀 MCP protocol server（4–6 人日）

執行結果與 protocol contract 見 [MCP_PHASE2_IMPLEMENTATION.md](MCP_PHASE2_IMPLEMENTATION.md)。

1. 選定並 pin Dart MCP library；確認其支援目標 MCP protocol version、stdio、tools、resources、structured output 與 cancellation。
2. 建立 `monoashi-mcp` executable，實作 initialization、`tools/list`、`tools/call`、resources list/read 與 graceful shutdown。
3. 依第 5 章建立 input / output JSON Schema，實作 cursor encoding、分頁、tool error mapping。
4. 加入 stdout purity guard：stdout 只可輸出 MCP JSON-RPC；診斷只可寫 stderr 且不得含機密。
5. 以 MCP Inspector 和 loopback fake gateway 做 protocol compatibility tests。

**完成條件：** sidecar 未連 App 時安全失敗；連到 fake gateway 時能以 stdio 完成所有 v1 read tools，且 schema / pagination / cancellation tests 通過。

### Phase 3：App ↔ sidecar secure bridge（4–7 人日）

執行結果與安全邊界見 [MCP_PHASE3_IMPLEMENTATION.md](MCP_PHASE3_IMPLEMENTATION.md)。

1. 在 App 建立 session lifecycle notifier：啟用、停止、專案切換、App dispose、secret rotation。
2. 實作 localhost IPC endpoint、app-private session descriptor 與 sidecar handshake；endpoint、token、project scope 都必須綁定同一 generation。
3. 透過 bridge 取得 immutable `ProjectReadSnapshot`，禁止 sidecar 直接碰 `.mnproj` 或 provider 內部資料。
4. 讓 session 在專案切換、停用、App 背景 policy 或授權過期時撤銷，並令已發出的請求 latest-wins / cancel。
5. 實作 MCP 設定 UI、目前選取 scope、狀態與停止按鈕；勿讓 UI 顯示 token 或完整 endpoint。

**完成條件：** MCP client 只能存取使用者目前授權的一個專案；project switch、停止、App 關閉與舊 token replay 都不會洩漏舊資料。

### Phase 4：Plan 驗證與 Copilot parity（3–4 人日）

執行結果與唯讀保證見 [MCP_PHASE4_IMPLEMENTATION.md](MCP_PHASE4_IMPLEMENTATION.md)。

1. 抽取或重用 `CopilotPlan` parser / semantic validator 為共用 readonly plan validator。
2. 實作 `validate_readonly_plan`，回傳可機器讀取的 validation errors 與 resolved target metadata。
3. 驗證 context 變更後的 stale plan 必定失敗或標記 stale，不可繼續當成可用提案。
4. 新增 Copilot ↔ MCP 的 golden tests：resource ID、canonical JSON、budget、fingerprint、Plan allowlist 全部一致。

**完成條件：** MCP 不存在任何 write dispatcher；所有 valid plan 仍僅為 JSON 結果，無專案 dirty state 改動。

### Phase 5：安全、封裝與發布驗收（3–6 人日）

執行結果、release check 與待驗收項目見 [MCP_PHASE5_IMPLEMENTATION.md](MCP_PHASE5_IMPLEMENTATION.md)。

1. 建立 malformed JSON、oversize request、prompt injection text、cursor tampering、timeout、concurrent tool call、token replay 的測試矩陣。
2. 確認 token / URL / project path / 正文不出現在 stdout、UI error、audit log、crash log fixture 或 release artifact。
3. 在 Windows、macOS、Linux 打包 sidecar；驗證 App / sidecar version compatibility 與回退訊息。
4. 用至少兩個 MCP Host 做人工 smoke test，涵蓋 tool discovery、chapter query、跨資源 context、plan validation、停止授權。
5. 建立 release check：`flutter analyze`、focused tests、full suite、sidecar tests、MCP Inspector trace、secret scan、artifact hash。

**完成條件：** 所有 v1 platforms / hosts 通過驗收；任何不支援的 Host 或 version 都可安全失敗，且不影響 Copilot 正常使用。

## 8. 測試與驗收矩陣

| 類別 | 必測情境 |
| --- | --- |
| Domain | UTF-8 截斷、deterministic sorting、stable ID、空值、重複名稱、失效 reference、budget 計算。 |
| Copilot parity | 同一 snapshot 的 resource JSON、fingerprint、truncated／omitted 標示與 Plan validator 結果一致。 |
| MCP protocol | initialization、tools/resources list、call/read、structuredContent、pagination、cancel、unknown tool、invalid schema。 |
| IPC | 未啟用、App 未開啟、正確 handshake、過期 token、token replay、project switch、App dispose、timeout。 |
| 安全 | 作品中的 injection 指令、oversize body、malformed JSON、非法 cursor、path / secret / internal error redaction。 |
| 效能 | 100 KiB、500 KiB、1 MiB chapter fixture 保持 bounded output；不在 UI isolate 做長時間同步序列化。 |
| 手動 | 至少兩個 MCP Host、三個桌面平台、啟用／停止／重啟／開啟不同專案。 |

## 9. 工作量與排程

| 項目 | 預估 |
| --- | ---: |
| Phase 0 | 2–3 人日 |
| Phase 1 | 4–6 人日 |
| Phase 2 | 4–6 人日 |
| Phase 3 | 4–7 人日 |
| Phase 4 | 3–4 人日 |
| Phase 5 | 3–6 人日 |
| **唯讀 MCP MVP 合計** | **20–32 人日** |

若先採「sidecar 直接讀取使用者指定且已儲存的 `.mnproj`」的低保真方案，可縮短至約 10–15 人日，但會失去與 Copilot 目前 App snapshot 的一致性，且要額外處理檔案路徑權限與多專案選取；不建議作為正式方向。

## 10. 後續版本（不列入 MVP）

寫入 MCP 必須另立設計與安全審查，至少需要：

1. 由模型輸出 proposal，而非直接呼叫 notifier。
2. 使用者可見的逐項 diff 預覽與二次確認。
3. 全部寫入經既有 application operation / history transaction，而非改 model instance。
4. undo、審計紀錄、失敗原子性、cancel、stale fingerprint 防護。
5. P2P revision DAG、dirty state 和欄位衝突流程均能理解並保存該修改。
6. 每個工具有個別最小權限與可撤銷 capability。

在上述條件完成前，任何 `create_*`、`update_*`、`delete_*`、`apply_plan` 或檔案工具均不得列在 MCP `tools/list`。

## 11. 建議的第一個可合併切片

第一個 PR 只做 Phase 0 與 Phase 1：建立 `story_read` 共用 domain、將 Copilot context builder 改接共用 API，並加入 parity golden tests。它不加入 MCP dependency、不開 socket、不更改 UI，因此可先驗證「同步資料契約」這個關鍵前提。

待該 PR 穩定後，再用獨立 PR 導入 sidecar 與 fake IPC gateway；App bridge、設定 UI、Plan validator、跨平台封裝則各自分開，避免在同一變更內同時導入協定、傳輸與產品權限風險。
