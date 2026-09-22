# MonoAshi MCP Phase 4：Plan 驗證與 Copilot parity

日期：2026-09-20
狀態：實作完成；Phase 5 發布驗收尚未開始
上位計畫：[MCP_IMPLEMENTATION_PLAN.md](MCP_IMPLEMENTATION_PLAN.md)

## 完成內容

- 新增共用 `ReadonlyPlanValidator`，Copilot `CopilotPlan.parse` 與 MCP 使用同一組 schema、欄位上限、target/action allowlist、context target、dependency 與 cycle 規則。
- 新增 MCP `validate_readonly_plan` tool；只回傳 canonical plan、machine-readable errors、`stale` 與 resolved target metadata，不執行或持久化任何步驟。
- `get_context_bundle` 會在 sidecar 記憶體中保存最多八個 session/generation-scoped validation context；未先取得的 fingerprint 一律視為 stale。
- validation context 綁定完整 immutable snapshot fingerprint。同一 generation 的內容更新後，舊 plan 也會標記 stale，必須重新取得 context bundle。
- raw JSON 上限為 128 KiB，所有 object 拒絕未知欄位，文字、陣列、步驟數、ID 與 dependency 均有上限。
- `create` 只代表建立提案；其他 action 的 target 必須存在於先前提供的 context。

## 輸出

```json
{
  "valid": false,
  "stale": true,
  "errors": [
    {
      "code": "staleContext",
      "path": "$.contextFingerprint",
      "message": "..."
    }
  ],
  "resolvedTargets": [],
  "plan": null
}
```

錯誤以資料回傳，不把合法性失敗轉成 server internal error。error code 包含 malformed JSON、oversize、schema、stale context、欄位、allowlist、context target、重複步驟、未知 dependency 與 cycle。

## 唯讀保證

- MCP tool registry 仍沒有 `create_*`、`update_*`、`delete_*` 或 `apply_plan`。
- validator 不 import Riverpod notifier、專案 repository、檔案 API 或 write use case。
- valid plan 只是一份 canonical JSON proposal，不會轉成 `UpdatePlanItem`。
- validation 前後的 snapshot canonical payload 完全相同。

## 驗證

- Phase 4、Copilot model、Phase 2 adapter/protocol 聚焦測試：29 passed、0 failed。
- 聚焦 `flutter analyze`：No issues found。
- 覆蓋 canonical fingerprint、allowlist、valid plan、resolved targets、stale/unknown context、unknown fields/actions 與 read-only snapshot invariant。

## Phase 5 邊界

Phase 5 才處理 malformed/oversize/timeout/concurrency/token secret 的完整安全矩陣、跨平台 sidecar packaging、MCP Inspector、兩個以上 Host 與三個桌面平台 smoke test，以及 release artifact hash/secret scan。
