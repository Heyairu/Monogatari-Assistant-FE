# MonoAshi MCP Phase 2：唯讀 Protocol Server

日期：2026-09-20  
狀態：實作完成；外部 MCP Inspector smoke pending  
範圍：MCP SDK、stdio executable、tools、resources、structured output、cursor、錯誤映射與 protocol tests；不包含 App IPC、session UI 或 Plan validator  
上位計畫：[MCP_IMPLEMENTATION_PLAN.md](MCP_IMPLEMENTATION_PLAN.md)  
前置共用層：[MCP_PHASE1_IMPLEMENTATION.md](MCP_PHASE1_IMPLEMENTATION.md)

## 1. SDK 決策

`pubspec.yaml` 精確鎖定 `mcp_dart: 2.4.2`。選擇原因：

- 支援 Dart VM／Flutter desktop 的 stdio server。
- 支援 tools、resources、JSON Schema 與 `structuredContent`。
- request handler 提供 cancellation signal。
- stable profile 可協商 MCP 2026-07-28，並向 initialization-era protocol fallback。
- SDK runtime diagnostics 預設寫入 stderr，符合 stdout purity 要求。

未選用 `dart_mcp 0.5.2`，因其公開支援矩陣目前將 cancellation 標為不支援；MonoAshi 的 Phase 2 契約要求 cancellation。

SDK 仍屬快速演進中的套件，因此使用 exact pin，不使用 caret range。升級前必須重跑 protocol compatibility tests。
`mcp_dart` 目前尚未取得官方 MCP SDK tier；此選擇是基於功能完整度與本專案測試結果，仍須在 Phase 5 持續追蹤 SDK audit／維護狀態。

## 2. Production 結構

```text
bin/
└── monoashi_mcp.dart

lib/features/mcp/
├── domain/
│   ├── mcp_gateway.dart
│   └── mcp_protocol_models.dart
└── application/
    ├── mcp_cursor_codec.dart
    ├── monoashi_mcp_adapter.dart
    └── monoashi_mcp_server.dart
```

### 2.1 邊界

- `MonoAshiMcpAdapter` 只依賴 `MonoAshiMcpGateway` 與 Phase 1 `story_read` API。
- protocol adapter 不 import Widget、Riverpod、`.mnproj` file service、Copilot UI 或網路 client。
- `DisconnectedMonoAshiMcpGateway` 是 Phase 2 executable 的預設 gateway；未完成 Phase 3 handshake 前不會讀取磁碟或作品資料。
- `FixedMonoAshiMcpGateway` 僅用於 deterministic fake-gateway tests。
- Phase 3 可以新增 secure IPC gateway，而不改 tool contract。

## 3. 已公開的唯讀 Tools

| Tool | Phase 2 行為 |
| --- | --- |
| `get_project_summary` | 回傳 bounded overview、類型計數與 omission metadata。 |
| `list_chapters` | metadata-only、預設 50／最大 100 筆、opaque cursor。 |
| `get_chapter` | 指定 stable chapter ID，最大 72 KiB UTF-8。 |
| `search_project_entities` | 搜尋 allowlisted entity types，只回傳 metadata。 |
| `get_project_entity` | 指定 type／ID，單筆最大 8 KiB。 |
| `get_context_bundle` | 與 Copilot Ask 相同的 chapter＋overview 或 chapter＋explicit resources context。 |

所有 tool 均宣告：

- `readOnlyHint: true`
- `destructiveHint: false`
- `idempotentHint: true`
- `openWorldHint: false`
- strict object-root input schema，拒絕未知欄位
- object-root output schema 與 `structuredContent`

`validate_readonly_plan` 依原計畫保留給 Phase 4；Phase 2 不先公開尚未實作的工具。

## 4. Output envelope

成功結果至少包含：

```json
{
  "schemaVersion": "1",
  "sessionId": "session scoped",
  "projectId": "project-session-scoped-id",
  "snapshotGeneration": 1
}
```

單筆 resource 另外包含：

```json
{
  "type": "chapter",
  "id": "stable-resource-id",
  "title": "display title",
  "truncated": false,
  "fingerprint": "deterministic fingerprint",
  "sourceUri": "monoashi://session/...",
  "content": "bounded untrusted project data"
}
```

tool result 序列化後硬上限集中於 `ProjectReadBudget.maxToolResultBytes`，目前為 256 KiB。

## 5. Cursor 與 resource URI

### 5.1 Opaque cursor

- cursor payload 包含 version、query kind、offset 與 query scope。
- 使用每個 server process 隨機產生的 256-bit key 與 HMAC-SHA256 簽章。
- cursor 綁定 session、snapshot generation、query 與 types。
- 修改內容、跨 query 重播或跨 generation 使用都回傳 `invalidCursor`。
- cursor 不包含正文、token、檔案路徑或永久 project UUID。

### 5.2 Resources

```text
monoashi://session/{sessionId}/project/summary
monoashi://session/{sessionId}/chapter/{chapterId}
monoashi://session/{sessionId}/{type}/{id}
```

resource template 動態提供 `resources/list` 與 `resources/read`。read 時重新驗證目前 session；舊 session URI 不會 fallback 到磁碟。

## 6. 錯誤與 stdout purity

- 已知錯誤只回傳穩定 code 與清理後訊息：`unavailable`、`invalidArgument`、`invalidCursor`、`notFound`、`cancelled`、`resultTooLarge`。
- 未知例外統一映射為 `internal`，不回傳 stack、路徑、project UUID 或 SDK exception。
- tool domain error 使用 `isError: true`；resource error 使用安全的 MCP error。
- `bin/monoashi_mcp.dart` 不呼叫 `print`，stdout 由 `StdioServerTransport` 獨占。
- SDK diagnostics 與 executable fatal message 只寫 stderr。
- stdin 關閉時由 stdio transport graceful close，不建立 socket 或 listener。

## 7. 測試

`test/mcp_phase2_adapter_test.dart` 覆蓋：

- session-scoped project ID，不公開永久 UUID。
- HMAC cursor 分頁、tamper detection 與跨 query replay rejection。
- 六個 read tools、byte budget、structured envelope 與 256 KiB result cap。
- resource traceability 與 stale session rejection。
- strict input、cancellation 與 disconnected gateway。

`test/mcp_phase2_protocol_test.dart` 使用 SDK client/server 與雙向 in-memory stream，實際覆蓋：

- initialization 與 MCP 2025-11-25 fallback negotiation。
- `tools/list`、input/output schema 與 readonly annotations。
- `tools/call` 與 `structuredContent`。
- invalid schema call。
- `resources/list` 與 `resources/read`。
- disconnected server initialize、安全錯誤與空 resource list。

## 8. 驗證結果

驗證日期：2026-09-20

| 檢查 | 結果 |
| --- | --- |
| Phase 2 adapter／protocol tests | 8 passed、0 failed |
| Phase 0–2＋Copilot regression suite | 100 passed、0 failed |
| Targeted analyze | No issues found |
| Full project analyze | 0 error、0 warning；158 項既有 info lint |
| Full Flutter test suite | 779 passed、1 skipped、0 failed |

官方 MCP Inspector CLI 需要 `npm`／`npx`；目前工作環境只有 Node 24、沒有 npm／npx，因此未執行外部 Inspector CLI。相同的 initialization、tool、resource 與 schema paths 已由 `mcp_dart` client 的 in-memory protocol integration tests 覆蓋。發布前仍須依 Phase 5 在具備 Inspector 的環境執行 `tools/list --strict`。

## 9. Phase 3 邊界

Phase 2 executable 目前刻意使用 disconnected gateway。Phase 3 才會加入：

- App-private session descriptor。
- localhost IPC／named pipe 或 Unix domain socket handshake。
- capability token、rotation、timeout 與 concurrency limit。
- project switch／App dispose／停用時的 session revoke。
- MCP 設定 UI 與 sidecar packaging。

在 Phase 3 完成前，sidecar 可被 MCP Host 啟動與 discover，但不會取得任何真實作品資料。
