# MonoAshi MCP Phase 1：共用唯讀作品資料層

日期：2026-09-20  
狀態：完成  
範圍：共用 domain、immutable snapshot、查詢服務與 Copilot parity；不包含 MCP dependency、server、IPC、socket 或 UI 變更  
上位計畫：[MCP_IMPLEMENTATION_PLAN.md](MCP_IMPLEMENTATION_PLAN.md)  
前置基線：[MCP_PHASE0_BASELINE.md](MCP_PHASE0_BASELINE.md)

## 1. 完成項目

- 新增與 Flutter Widget、Riverpod、網路及檔案 I/O 無關的 `features/story_read` domain。
- 集中定義 resource type、UTF-8 byte budget、分頁上限、截斷與 fingerprint。
- 從 `ProjectData` 與 glossary snapshot 建立 immutable `ProjectReadSnapshot`。
- 建立章節索引、chapter getter、entity search、entity getter、selected resources 與 context bundle API。
- 空白／重複 stable ID 不會進入可查詢 resource，並以 omission reason 留下結構化紀錄。
- Copilot context builder 改為 shared read layer 的相容 facade。
- Copilot context resource 截斷與 snapshot fingerprint 改用 shared domain 實作。
- 加入 ProjectRead ↔ Copilot 的 canonical JSON、byte budget 與 fingerprint parity tests。

## 2. Production 結構

```text
lib/features/story_read/
├── domain/
│   └── project_read_models.dart
└── application/
    ├── project_read_snapshot_builder.dart
    └── project_read_service.dart
```

### 2.1 Domain models

| Model | 責任 |
| --- | --- |
| `ProjectReadBudget` | 集中管理 chapter、overview、selected resources、catalog 與 page 上限。 |
| `ProjectReadResource` | bounded UTF-8 內容、truncated flag 與 deterministic fingerprint。 |
| `ProjectReadChapter` | snapshot 中的不可變章節資料；只在 getter 時依需求截斷。 |
| `ProjectReadSelectableResource` | 角色、世界觀、大綱、術語的 immutable serialized resource。 |
| `ProjectReadSnapshot` | 單一 `ProjectData` 世代的 overview、chapters、entities 與 omissions。 |
| `ProjectReadContextBundle` | 一個主章節與 bounded supplemental resources 的 canonical fingerprint。 |
| `ProjectReadPage<T>` | offset-based internal pagination result；MCP cursor encoding 留給 Phase 2。 |

### 2.2 Snapshot builder

`ProjectReadSnapshotBuilder.build()` 接受明確傳入的 `ProjectData` 與 glossary map。它不讀 provider、不觀察目前畫面、不讀檔，也不保存 model reference 作為日後查詢來源；章節欄位與 entity JSON 都在 capture 時固定。

目前保持與 Copilot 相同的 resource catalog：

```text
character → worldSetting → outlineEvent → glossaryTerm
```

同 type 先按 lowercase title，再按 stable ID 排序。catalog 上限與現有 Copilot 完全相同。

### 2.3 Read service

| API | 行為 |
| --- | --- |
| `listChapters` | 回傳 metadata-only chapter page，不包含正文。 |
| `getChapter` | 以 chapter ID 取得最多 72 KiB UTF-8 的正文 resource。 |
| `searchEntities` | 依 title、description、stable ID 與 allowlisted types 搜尋。 |
| `getEntity` | 取得單筆最多 8 KiB 的 entity resource。 |
| `buildSelectedResources` | 最多 12 筆、合計 32 KiB，依 snapshot canonical order 輸出。 |
| `buildContextBundle` | 建立 current chapter、chapter＋overview 或 chapter＋selected resources scope。 |

`includeProjectOverview` 與 `resourceRefs` 互斥，以維持目前 Copilot Ask scope 的清楚資料邊界。外部輸入可選擇 `rejectMissing: true`；Copilot compatibility path 則維持已刪除 selection 被忽略的既有行為。

## 3. Copilot 相容層

`CopilotProjectContextBuilder` 的 public API 與常數名稱保持不變，既有 Widget 與 tests 不必改 import。內部改為：

1. `ProjectReadSnapshotBuilder` 產生 canonical resources。
2. `ProjectReadService` 套用 selected-resource budget 與排序。
3. 最後才轉成 `CopilotContextResource`。

`CopilotContextSnapshot.currentChapter()` 也改由 `ProjectReadContextBundle` 計算截斷與 fingerprint。Phase 0 fixture 的固定 baseline 仍為：

| Baseline | 值 |
| --- | --- |
| small overview | 740 UTF-8 bytes |
| small context fingerprint | `eb2b894d` |
| large chapter | 72 KiB、truncated |
| large overview | 24 KiB、truncated |
| large context fingerprint | `de2231d0` |

因此 Phase 1 沒有改變 Copilot Ask／Plan 的 request context 語意。

## 4. ID 與 omission 規則

- Chapter 與 entity 最終 ID 必須非空。
- 同 resource type 的 ID 在 snapshot 內必須唯一。
- legacy character / glossary 的 model ID 為空時，仍沿用現有 map key 作相容 fallback；fallback 後仍為空則 omission。
- Chapter 空白或重複 ID 以 folder ID 作 `sourceKey` 記錄 omission。
- Entity 空白／重複 ID 以來源 map key 或 model ID 作 `sourceKey`。
- omission reason 首版為 `empty_id` 或 `duplicate_id`。
- omission 不會偷偷改用顯示名稱作識別碼。

## 5. 測試覆蓋

`test/story_read_phase1_test.dart` 覆蓋：

- capture 後修改原 `ProjectData` 不影響 snapshot。
- snapshot collections 不可修改。
- 重複 stable ID 被排除並產生 omission。
- chapter metadata pagination 不包含正文。
- entity title／description／ID／type 搜尋。
- 單筆 resource byte budget 與超限拒絕。
- project overview scope 與 Copilot fingerprint parity。
- selected resources canonical ordering、JSON 與 Copilot fingerprint parity。
- mixed scope 與 missing resource 的 strict validation。

## 6. Phase 2 邊界

Phase 1 刻意不實作下列項目：

- MCP SDK、JSON-RPC lifecycle、stdio executable。
- MCP `structuredContent` envelope 與 output schema。
- 對外 opaque cursor；目前 `ProjectReadPage` 僅使用內部 integer offset。
- session-scoped project ID、snapshot generation、resource URI。
- App ↔ sidecar IPC 或 capability token。
- write tools、Plan apply 或任何 notifier dispatch。

Phase 2 可直接將 protocol adapter 接到 immutable `ProjectReadSnapshot` 與 `ProjectReadService`，但不得讓 MCP server import Copilot UI、Riverpod provider 或 `.mnproj` file service。

## 7. 完成檢查

- [x] 建立共用 domain models 與集中 budget。
- [x] 建立 immutable project read snapshot。
- [x] 建立 chapter index、search、resolve、selected resources 與 context bundle。
- [x] Copilot context builder 改接共用 API。
- [x] Copilot resource truncation 與 context fingerprint 改接共用 API。
- [x] Phase 0 byte／fingerprint baseline 無變化。
- [x] 新增 Phase 1 unit 與 parity tests。
- [x] 未新增 MCP dependency、server、socket、IPC 或 UI 行為。

## 8. 驗證結果

驗證日期：2026-09-20

| 檢查 | 結果 |
| --- | --- |
| Phase 0／1 與 Copilot focused tests | 92 passed、0 failed |
| Targeted analyze | No issues found |
| Full project analyze | 0 error、0 warning；158 項既有 info lint |
| Full Flutter test suite | 771 passed、1 skipped、0 failed |

完整測試的 skip 為專案既有測試標記；本次 Phase 1 沒有新增 skipped test。
