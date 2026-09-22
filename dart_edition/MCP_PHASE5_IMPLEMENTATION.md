# MonoAshi MCP Phase 5 實作與發布驗收

日期：2026-09-20  
狀態：自動化與 Windows 本機驗收完成；macOS／Linux 實機打包、第二個外部 MCP Host 人工 smoke test 尚待 release 前執行

## 1. 本階段結論

Phase 5 已完成安全測試矩陣、App／sidecar contract version 檢查、跨平台封裝腳本、release check 與 Windows sidecar 的 MCP Inspector 驗證。MCP 對外仍只有 7 個唯讀工具；不相容 descriptor、過期或重放 token、停止授權、切換專案及無法連線情境均採 fail-closed。

目前 Windows 開發機能完成的自動化 gate 已建立並通過。因本輪沒有 macOS／Linux runner，也沒有第二個外部 MCP Host 的實際連線環境，這兩項保留為發布前人工 gate；在完成前不宣稱 Phase 5 的「所有平台／所有 Host」最終驗收完成。

## 2. 實作內容

### 2.1 Security matrix

新增 `test/mcp_phase5_security_test.dart`，並與既有 Phase 2–4 測試共同覆蓋：

| 威脅／失敗模式 | 驗證方式 | 結果 |
| --- | --- | --- |
| malformed JSON／未知 tool／不合法 schema | Phase 2 protocol tests | 自動化覆蓋 |
| oversize request | Phase 5 bridge body cap test | 400 或安全斷線，無 secret／project title 洩漏 |
| prompt injection text | Phase 5 inert-data test | 原樣視為資料，沒有 write tool |
| cursor tampering | Phase 2 opaque cursor tests | 安全拒絕 |
| timeout／無法連線 | Phase 5 bounded timeout test | 7 秒內 fail-closed |
| concurrent tool call | Phase 5 24-call test | session scoped，結果維持 256 KiB 上限 |
| token replay／project switch／stop／Origin | Phase 3 bridge tests | 舊 capability 無法讀取資料 |
| stale plan／未知 target／action allowlist | Phase 4 validator tests | 回傳 validation error，不寫入專案 |

### 2.2 App／sidecar version compatibility

- Session descriptor 新增 `contractVersion`，值與 `MonoAshiMcpContract.serverVersion` 一致。
- sidecar 同時驗證 descriptor format version 與 contract version。
- 任一版本不相容、欄位遺失或 descriptor 無效時，gateway 回傳 unavailable，不將 token、endpoint、路徑或內部例外帶到 MCP output。
- 不提供讀取 `.mnproj` 的 fallback；bridge 不可用時不會繞過 App 授權。

### 2.3 封裝與 release tooling

- `tool/build_mcp_sidecar.dart`：依目前 OS 產生 `monoashi-mcp`／`monoashi-mcp.exe`，並寫入含 contract version、平台、架構、檔案大小及 SHA-256 的 `manifest.json`。
- `tool/mcp_release_check.ps1`：Windows release gate。
- `tool/mcp_release_check.sh`：macOS／Linux release gate。
- 設定頁會顯示實際 descriptor 路徑並提供「複製 MCP Host 設定」；輸出的 JSON 只含 sidecar 與 descriptor 路徑，不含 token 或 loopback endpoint。
- release gate 包含 analyzer、Phase 0–5 與 Copilot parity focused tests、可選 full suite、secret／非 loopback listener scan，以及 sidecar build。
- repository 目前有既存 info-level lint backlog，因此 analyzer 使用 `--no-fatal-infos`；warning 與 error 仍會令 gate 失敗。

## 3. Windows 驗收證據

### 3.1 Sidecar artifact

| 欄位 | 值 |
| --- | --- |
| contract version | `0.1.0` |
| platform | `windows` |
| architecture | `x64` |
| artifact | `monoashi-mcp.exe` |
| bytes | `8,485,888` |
| SHA-256 | `38d47bab041c8acca0dc3eb8e93976a48f6cbe1894f02541929c11624f2339b7` |

產物位於 gitignored 的 `build/mcp-sidecar/`，不提交 binary 或 session descriptor。

### 3.2 MCP Inspector

使用 MCP Inspector 2.7.0 對正式編譯的 Windows executable 執行 stdio `tools/list`，exit code 為 0，成功列出：

1. `get_project_summary`
2. `list_chapters`
3. `get_chapter`
4. `search_project_entities`
5. `get_project_entity`
6. `get_context_bundle`
7. `validate_readonly_plan`

每個工具都宣告 `readOnlyHint: true`、`destructiveHint: false`、`idempotentHint: true`、`openWorldHint: false`，且 `taskSupport` 為 `forbidden`。

### 3.3 自動化結果

- Phase 5 quick release gate：47 tests passed；secret／listener scan passed。
- 完整 Flutter suite：793 tests passed、1 skipped、0 failed。
- Analyzer：0 warning、0 error；另有 158 個既有 info-level lint，已列為 repository lint backlog，未由本階段擴張修改範圍。

## 4. Release 操作

一般使用者不需要手動尋找 `session.json`：在 MonoAshi 設定頁開啟「MCP 唯讀整合」，按「複製 MCP Host 設定」，再把 JSON 貼入支援 stdio MCP 的 Host。成功 handshake 後按鈕會隱藏並顯示已連線狀態；如要更換 Host，停止後重新啟用即可輪替一次性授權。

Windows：

```powershell
.\tool\mcp_release_check.ps1
```

只跑快速 gate：

```powershell
.\tool\mcp_release_check.ps1 -SkipFullSuite -SkipBuild
```

macOS／Linux：

```bash
./tool/mcp_release_check.sh
```

CI 可用 `FLUTTER_BIN` 指定 Flutter，並以 `MCP_SKIP_FULL_SUITE=1` 或 `MCP_SKIP_BUILD=1` 跳過對應步驟。

## 5. 發布前人工 gate

| Gate | Windows | macOS | Linux |
| --- | --- | --- | --- |
| sidecar compile + manifest + hash | 通過 | 待實機 | 待實機 |
| MCP Inspector `tools/list` | 通過 | 待實機 | 待實機 |
| Host A：tool discovery／chapter／context／plan／stop | Inspector discovery 通過；完整 App session 待人工 | 待人工 | 待人工 |
| Host B：相同 smoke flow | 待人工 | 待人工 | 待人工 |

每個 Host 的人工流程：

1. 在 MonoAshi 開啟測試專案並啟用 MCP 唯讀整合。
2. 驗證 tool discovery 只有上述 7 個唯讀工具。
3. 讀取一章、搜尋並選取一個跨資源 context，確認 byte budget、source URI 與 fingerprint。
4. 送出合法及 stale 的 readonly plan，確認只回傳驗證結果且專案 dirty state 不變。
5. 在 App 停止授權，再由 Host 重試；必須安全失敗且不顯示 token、完整 endpoint、project path 或正文。
6. 切換專案後重放舊 session；必須失敗，新 session 只能看到新授權 scope。

## 6. 完成判定

程式與 Windows 自動化驗收已完成。正式標記 Phase 5 全面完成前，release owner 必須補齊：

- macOS sidecar build、hash、Inspector trace。
- Linux sidecar build、hash、Inspector trace。
- 至少兩個實際 MCP Host 的完整 App-session smoke 記錄。

任何 gate 失敗都應阻擋對應平台發布，但不得影響 MonoAshi Copilot 的既有 Ask／Plan 功能。
