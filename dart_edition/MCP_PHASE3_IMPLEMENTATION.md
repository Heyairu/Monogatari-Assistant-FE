# MonoAshi MCP Phase 3：App ↔ sidecar secure bridge

日期：2026-09-20  
狀態：實作完成；跨平台封裝與外部 Host smoke test 留待 Phase 5  
範圍：桌面 App session lifecycle、loopback IPC、一次性 handshake、session descriptor、sidecar gateway、專案切換撤銷與設定 UI  
上位計畫：[MCP_IMPLEMENTATION_PLAN.md](MCP_IMPLEMENTATION_PLAN.md)  
前置協定層：[MCP_PHASE2_IMPLEMENTATION.md](MCP_PHASE2_IMPLEMENTATION.md)

## 1. 完成內容

- App 端新增 `McpBridgeNotifier`，負責啟用、停止、專案切換、到期與 dispose。
- bridge 僅綁定 `127.0.0.1` 的隨機 port，不建立 LAN 或公網 listener。
- 啟用時建立 app support directory 內的短期 session descriptor。
- descriptor 內的 bootstrap token 只能成功 handshake 一次；成功後立即刪除 descriptor，改用只存在 sidecar 記憶體中的 access token。
- token、endpoint、session ID、project scope 與 generation 綁定；切換專案會關閉舊 listener、撤銷舊 token、增加 generation 並建立新 descriptor。
- bridge 只傳送 `ProjectReadSnapshotBuilder` 建立的 immutable snapshot；sidecar 不 import Riverpod provider、不讀 `.mnproj`，也沒有磁碟 fallback。
- 同一專案內容變更以 250 ms latest-wins debounce 更新 snapshot，不旋轉 capability；不同 project UUID 的 snapshot 不能覆蓋目前 session，專案切換仍必須完整撤銷與重新 handshake。
- `monoashi_mcp` 可透過 `--descriptor <path>` 或 `MONOASHI_MCP_DESCRIPTOR` 取得 descriptor 路徑；token 不出現在命令列、環境變數、stdout 或錯誤文字。
- 設定頁新增「MCP 唯讀整合」、授權專案狀態與停止按鈕，不顯示 token 或完整 endpoint。
- App 進入 paused／detached、ProviderScope dispose、使用者停止或八小時授權到期時撤銷 session。

## 2. Handshake

```text
App enable
  ├─ build immutable ProjectReadSnapshot
  ├─ bind 127.0.0.1:<random-port>
  └─ atomically write session.json with one-time bootstrap token

sidecar
  ├─ read bounded descriptor
  ├─ POST /v1/handshake (Bearer bootstrap token)
  ├─ receive in-memory access token
  └─ GET /v1/session (access token + session ID + generation)

App
  ├─ delete descriptor after first successful handshake
  └─ return only the authorized immutable snapshot
```

所有 IPC request 都拒絕 redirect、非精確 loopback Host 與任何 `Origin` header。request body、descriptor、snapshot response、timeout 與同時請求數都有固定上限。比較 token 時使用不依第一個差異位置提前結束的比較方式。

## 3. 撤銷規則

| 事件 | 行為 |
| --- | --- |
| 使用者停止 | 強制關閉 listener、清除 snapshot 與所有 secret、刪除 descriptor。 |
| 切換專案 | 舊 listener/token/session 立即失效；新 scope 使用下一個 generation。 |
| App 背景／關閉 | paused、detached 或 provider dispose 時停止 bridge。 |
| 授權到期 | 預設八小時後停止；不自動續期。 |
| 舊 descriptor replay | bootstrap token 已消耗或 listener 已關閉，handshake 失敗。 |
| sidecar 未連 App | gateway 回傳 disconnected；MCP tool 安全失敗且不讀磁碟。 |

## 4. 主要檔案

- `lib/features/mcp/application/mcp_bridge_server.dart`：loopback server、session lifecycle、descriptor 與撤銷。
- `lib/features/mcp/data/mcp_bridge_gateway.dart`：sidecar handshake 與 bounded snapshot client。
- `lib/features/mcp/data/mcp_snapshot_codec.dart`：immutable snapshot wire codec。
- `lib/presentation/providers/mcp_providers.dart`：Riverpod lifecycle 與目前專案 scope。
- `lib/modules/settingview.dart`：使用者啟用、狀態與停止 UI。
- `bin/monoashi_mcp.dart`：descriptor-aware sidecar entrypoint。
- `test/mcp_phase3_bridge_test.dart`：handshake、replay、stop、rotation 與 Origin tests。

## 5. 安全邊界

- bridge API 沒有 write route，也不接受 project ID、檔案路徑或任意查詢作為 snapshot scope。
- 外部 project ID 仍由 `sessionId + generation + internal project UUID` 派生，內部 UUID 不作為 resource URI project scope。
- endpoint 與 token 不會出現在 UI；安全錯誤不含路徑、token、正文或內部 exception。
- snapshot response 上限為 32 MiB，超限會安全失敗，不改成 sidecar 直接讀檔。
- descriptor 路徑可以出現在 sidecar 設定；其內容僅位於 OS 的 app support directory，且 bootstrap capability 為一次性、短期資料。

## 6. 驗證

Phase 3 focused tests 覆蓋：

1. 正常 handshake 與 snapshot round-trip。
2. handshake 後 descriptor 刪除與擷取 descriptor replay 失敗。
3. 停止後已發出的 access token 無法再取得資料。
4. 專案切換後舊 endpoint/token 失效，新 session 使用下一 generation 與新 project scope。
5. 帶 `Origin` 的 request 被拒絕。
6. 同專案 snapshot refresh 保留 capability 並提供最新資料，跨專案 refresh 被拒絕。
7. Phase 2 adapter 與 protocol regression tests。

實際驗證結果：

- Phase 0–3 與 Copilot 聚焦回歸：96 passed、0 failed。
- 加入同專案 snapshot refresh 後的 MCP、設定頁與架構聚焦回歸：16 passed、0 failed。
- snapshot refresh 前的完整 `flutter test`：783 passed、1 skipped、0 failed；其後完整重跑因環境速度異常於 435 項時中止，當時 0 failed，最終變更已由上述 16 項聚焦回歸覆蓋。
- 完整 `flutter analyze`：0 errors、0 warnings；158 個既有 info lint。
- `git diff --check`：無 whitespace error。

## 7. Phase 4 邊界

Phase 3 不新增 `validate_readonly_plan`，也不建立任何 write dispatcher。Phase 4 才會抽出 Copilot Plan validator、加入 readonly validation tool，並完成 Copilot ↔ MCP golden parity。跨平台 sidecar packaging、外部 MCP Inspector 與多 Host smoke test仍屬 Phase 5。
