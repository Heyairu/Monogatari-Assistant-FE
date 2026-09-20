# MonoAshi MCP Phase 0：設計凍結與基線

日期：2026-09-20  
狀態：完成  
範圍：設計、風險盤點與測試資料；不包含 MCP dependency、server、IPC、socket 或 UI 變更  
上位計畫：[MCP_IMPLEMENTATION_PLAN.md](MCP_IMPLEMENTATION_PLAN.md)

## 1. 已凍結決策

| 決策 | Phase 0 結論 |
| --- | --- |
| 支援平台 | MCP server 首版只支援 Windows、macOS、Linux。Android、iOS、Web 不在 v1 範圍。 |
| MCP transport | 對 MCP Host 提供 stdio sidecar；App 與 sidecar 使用僅限本機、具短期 capability 的 IPC。 |
| 權限 | v1 只讀。不存在 write dispatcher，也不公開 create/update/delete/apply/file/shell/network tools。 |
| snapshot 來源 | 只讀目前 App 授權的 immutable in-memory project snapshot；不直接讀取 `.mnproj` 作 fallback。 |
| 與 Copilot 同步的含義 | 共用作品 resource、排序、byte budget、fingerprint 與唯讀 Plan 驗證契約；不共用聊天、provider 或 API key。 |
| 網路邊界 | 不提供 LAN 或公開 endpoint；任何 bridge 只允許 loopback、named pipe 或 Unix domain socket。 |
| 版本 | MonoAshi MCP 結果 schema 首版固定為 `schemaVersion: "1"`。MCP wire protocol 版本與 Dart library 延至 Phase 2 選型並 pin。 |

## 2. v1 工具與資源 allowlist

工具名稱凍結如下；若 Phase 1 發現契約無法滿足安全或 deterministic 要求，必須更新本文件並提升 schema，而不是靜默改變語意。

| Tool | 性質 | 核心輸入 |
| --- | --- | --- |
| `get_project_summary` | 唯讀 | 無 |
| `list_chapters` | 唯讀、分頁 | `cursor?`, `limit?` |
| `get_chapter` | 唯讀、bounded | `chapterId`, `maxBytes?` |
| `search_project_entities` | 唯讀、分頁 | `query`, `types?`, `cursor?`, `limit?` |
| `get_project_entity` | 唯讀、bounded | `type`, `id`, `maxBytes?` |
| `get_context_bundle` | 唯讀、bounded | `chapterId`, `resourceRefs[]` |
| `validate_readonly_plan` | 純驗證 | `plan`, `contextFingerprint` |

v1 resource types：`project`、`chapter`、`character`、`worldSetting`、`outlineEvent`、`glossaryTerm`。

共同 output envelope 必須包含：

```json
{
  "schemaVersion": "1",
  "snapshotGeneration": "opaque-session-generation",
  "data": {},
  "truncated": false,
  "omitted": 0,
  "nextCursor": null
}
```

`snapshotGeneration`、cursor 與 resource URI 都是 session-scoped opaque value，不得包含檔案路徑、API key、永久 project UUID 或可跨 session 追蹤的識別資訊。

## 3. Stable ID 盤點

| 資料 | 現有 ID | 持久化／穩定性 | v1 |
| --- | --- | --- | --- |
| Project | `ProjectData.projectUUID` | 儲存在專案；不可直接對外，改派生 session project ID。 | 僅使用衍生 ID |
| Chapter folder | `SegmentData.segmentUUID` | 儲存於 chapter tree；舊格式可能是時間字串。 | 僅供排序／定位，不公開為主要 resource |
| Chapter | `ChapterData.chapterUUID` | 儲存於 chapter tree；目前 Copilot citation 已使用。 | 納入 |
| Character | `CharacterEntryData.characterId` | 新資料穩定；legacy 空值時目前 builder 會 fallback 到 map key。 | 納入，但 Phase 1 必須拒絕空白最終 ID |
| World setting | `LocationData.id` | UUID 類型並持久化。 | 納入 |
| Storyline | `StorylineData.chapterUUID` | UUID 類型並持久化。 | 以 `outlineEvent` 納入 |
| Story event | `StoryEventData.storyEventUUID` | UUID 類型並持久化。 | 以 `outlineEvent` 納入 |
| Scene | `SceneData.sceneUUID` | UUID 類型並持久化；目前作為 event 內嵌內容。 | 不作獨立 resource |
| Glossary | `GlossaryEntry.id` | 儲存在 glossary state；目前 Copilot 已使用。 | 納入 |
| Foreshadow | `ForeshadowItem.id` | 模型與 XML 已保存 ID，但 Copilot Ask 尚未公開，codec 仍位於 UI module。 | 延後 |
| Update plan | `UpdatePlanItem.id` | 模型與 XML 已保存 ID，但與 Copilot `CopilotPlan` 語意不同。 | 延後 |
| Timeline track / placement | `trackUUID` / `placementUUID` | 已有 stable ID，但不在目前 Copilot Ask scope。 | 延後 |
| Item class / instance / relation | `classId` / `instanceId` / `relationId` | 已有 stable ID，但資料與時間狀態契約較大。 | 延後 |
| Character / item / location state change | 各模型 ID | 有時間軸、baseline、失效引用與 resolver 語意。 | 延後 |

### 3.1 ID 不變條件

1. 顯示名稱、列表 index 與檔案路徑永遠不能作 ID。
2. resource ID 在 snapshot 內必須非空且唯一；不符合時排除該 resource 並回報 omitted reason。
3. 同名資料以 type、title、stable ID 依序排序，stable ID 是最後 tie-breaker。
4. MCP URI 使用 session ID 與 opaque resource reference；原始 stable ID 只放在已授權的 structured result。
5. 所有 target resolution 都綁定 snapshot generation；不得跨 project switch 重用。

## 4. 匿名化 fixture 與現有基線

fixture 位於 `test/fixtures/mcp_phase0_project_fixtures.dart`：

| Fixture | 內容 | 驗證目的 |
| --- | --- | --- |
| `small` | 2 章、2 角色、巢狀世界觀、故事線／事件／場景、術語 | 基本 resource mapping、排序、摘要不含其他章節正文。 |
| `large` | 320 章、220 角色、220 世界觀、105 故事線＋事件、220 術語、超過 1 MiB 的主章節 | catalog cap、UTF-8 byte budget、截斷、deterministic fingerprint。 |
| `boundary` | 重複名稱、空白 legacy character ID、XML/HTML 字元、emoji、NUL、prompt injection 文字、失效引用 | ID tie-break、encoding、untrusted data 邊界與 invalid reference policy。 |

`test/mcp_phase0_baseline_test.dart` 鎖定下列現有 Copilot 行為：

- resource type 排序為 character → worldSetting → outlineEvent → glossaryTerm。
- 同 type、同 title 時以 stable ID 排序。
- catalog 上限分別為 character 200、world 200、outline 200、glossary 200。
- chapter content 超過 72 KiB 時以有效 UTF-8 截斷，且相同輸入產生相同 fingerprint。
- 作品內即使包含 `Ignore previous instructions` 或偽造 XML closing tag，仍只被放入 untrusted project content。

Phase 1 必須以這些 fixture 建立更嚴格的 canonical JSON golden；Phase 0 不把完整作品 payload commit 為大型 golden 檔，避免 fixture 膨脹與正文重複保存。

## 5. Threat model

### 5.1 保護資產

- 尚未公開的作品正文、角色、世界觀、大綱、術語與未儲存修改。
- 專案／檔案路徑、永久 project UUID、最近開啟清單。
- Copilot provider URL、API key、模型設定與聊天內容。
- MCP session secret、IPC endpoint 與 audit metadata。
- 專案完整性、dirty state、history、P2P revision DAG。

### 5.2 信任邊界

```text
不可信作品文字
       |
       v
MonoAshi ProjectData --[immutable bounded snapshot]--> App IPC bridge
                                                    |
                                              不可信 MCP Host
                                                    |
                                              不可信外部模型
```

sidecar 屬於產品元件，但啟動它的 MCP Host、Host 傳入的參數、模型輸出及作品內容都視為不可信。相同 OS 帳號下的其他 process 也不能只因位於 localhost 就被視為已授權。

### 5.3 威脅與必要控制

| ID | 威脅 | 影響 | 必要控制 | 驗證階段 |
| --- | --- | --- | --- | --- |
| T01 | 惡意 Host 列舉未授權專案或資源 | 作品外洩 | 預設關閉、單一 project scope、session capability、無專案清單 tool | Phase 3/5 |
| T02 | 作品文字含 prompt injection | 誘導 Host 洩漏或執行操作 | 內容標為 untrusted、只提供資料、不公開寫入／shell／network tools | Phase 1/5 |
| T03 | sidecar 被替換或非官方 client 連 bridge | 繞過 UI 授權 | app-private descriptor、短期 secret、generation binding、版本 handshake；正式包簽章 | Phase 3/5 |
| T04 | localhost HTTP 遭 DNS rebinding / cross-origin 存取 | 遠端網站呼叫本機服務 | 僅 loopback、Origin/Host 驗證、bearer capability；優先評估 named pipe / UDS | Phase 3/5 |
| T05 | 巨大／深層／畸形 JSON | 記憶體或 CPU DoS | request/response byte cap、depth/field/list cap、timeout、concurrency limit | Phase 2/5 |
| T06 | 舊 token、cursor 或 request 重放 | 讀取錯誤專案／舊資料 | random nonce、session expiry、snapshot generation、opaque signed/MAC cursor | Phase 2/3/5 |
| T07 | project switch 的 TOCTOU | 回傳前一專案資料 | capture 與 publish 前後檢查 generation；切換即撤銷 | Phase 3/5 |
| T08 | error/stdout/log 洩漏正文、路徑或 token | 持久性外洩 | stdout purity、錯誤分類、redaction、metadata-only audit | Phase 2/5 |
| T09 | stale plan 被視為可執行 | 錯誤建議或未來誤寫 | context fingerprint、target allowlist、read-only result、無 dispatcher | Phase 4/5 |
| T10 | resource ID 重複、空白或 dangling reference | 引用錯誤／資料混淆 | snapshot uniqueness validation、omitted reasons、不得以名稱 fallback | Phase 1/5 |
| T11 | MCP dependency 或 protocol 行為快速變動 | 相容性／供應鏈風險 | pin version、lockfile、license/source review、Inspector trace、version negotiation tests | Phase 2/5 |
| T12 | Host 高頻查詢造成 UI 卡頓 | 可用性下降 | immutable snapshot、取消、rate/concurrency limit、必要時 isolate | Phase 1/3/5 |

### 5.4 Phase 0 殘餘風險

Phase 0 尚未建立 server 或 IPC，因此沒有新增執行期攻擊面。T01–T12 均為後續 phase 的 release-blocking requirements；任何一項未驗證時，不得將 MCP feature flag 預設開啟。

## 6. Phase 0 完成檢查

- [x] 凍結 desktop-only、stdio sidecar、readonly-only、不讀磁碟 fallback。
- [x] 凍結 7 個 tool 名稱、6 種 resource type 與 MonoAshi schema version 1。
- [x] 完成 stable ID 盤點並排除尚未納入 Copilot 契約的資料。
- [x] 建立 small、large、boundary 三組匿名化 fixtures。
- [x] 建立排序、catalog cap、UTF-8 截斷、fingerprint 與 untrusted-content baseline tests。
- [x] 建立 threat model、信任邊界與後續驗證 phase。
- [x] 未加入 MCP dependency、server、socket、IPC 或 UI 行為。

Phase 1 的進入條件：本文件與 `mcp_phase0_baseline_test.dart` 通過 review，且 focused test、Copilot tests 與 `flutter analyze` 沒有新增問題。

## 7. 驗證紀錄

2026-09-20 本機驗證：

- `flutter test test/mcp_phase0_baseline_test.dart`：3 passed。
- Phase 0 baseline 加全部 `copilot*_test.dart`：84 passed、0 failed。
- `flutter analyze test/mcp_phase0_baseline_test.dart test/fixtures/mcp_phase0_project_fixtures.dart`：No issues found。
- 未執行全專案 test suite；Phase 0 沒有修改 production Dart code。
