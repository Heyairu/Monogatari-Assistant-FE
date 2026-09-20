# Copilot Ask／Plan Beta 發布與回滾手冊

日期：2026-09-19  
架構：選項 A（Direct／BYOK）  
適用範圍：Flutter `dart_edition/`  
狀態：Windows build 已驗證；其餘平台待 release build 驗證；endpoint smoke 不再是強制 gate

## 1. 發布範圍

- Ask 可讀取目前章節，並可由使用者明確選擇專案摘要或最多 12 個補充資源。
- Plan 只產生、驗證、顯示與匯出唯讀 JSON 計畫。
- Plan 不會修改專案；Agent 維持停用。
- Ask／Plan 的 system instruction 會附帶 App 內建 `MNPROJ_FILE_STRUCTURE.md` 格式參考；future Agent policy 已採同規則，Chat 不附帶。
- 對話與 Plan 只保留在目前畫面工作階段，不寫入專案，也不跨 App 啟動保存。
- 使用者自備 provider API Key；Monogatari Assistant 不提供額度、不代管 Key，也不轉送請求。

## 2. 對外隱私告知

建議 release notes／測試邀請使用以下文字：

> Ask 與 Plan Beta 會把畫面標示的作品上下文直接傳送到你設定的模型 provider 與 API URL，不經 Monogatari Assistant 伺服器。API Key 只保存在此裝置的安全儲存空間，可隨時從 Copilot 頁面清除。第三方 provider 是否保存或使用資料，依該服務的條款與帳號設定決定。AI 回覆可能不正確；Plan 只供檢視與匯出，不會自動修改作品。

補充告知：

- Chat 會傳送使用者輸入的訊息。
- Ask／Plan 另會傳送送出前顯示的目前章節與使用者選定資源。
- Ask／Plan 會一併傳送 App 內建的 `.mnproj` 格式說明文件，供模型辨識專案資料結構；此文件不含使用者作品內容。
- `localhost` Ollama 可在本機處理；其他自訂 URL 不應視為本機或私密服務。
- 自訂雲端 URL 必須使用 HTTPS；HTTP 只允許 loopback host。

## 3. Build variants

所有正式 build 都必須明確指定旗標。未指定時 Ask 與 Plan 預設關閉。

### 3.1 一般版／緊急回滾版

```powershell
flutter build windows --release
```

等同於：

```powershell
flutter build windows --release `
  --dart-define=COPILOT_ASK_ENABLED=false `
  --dart-define=COPILOT_PLAN_ENABLED=false
```

### 3.2 Internal：Ask 與 Plan

```powershell
flutter build windows --release `
  --dart-define=COPILOT_ASK_ENABLED=true `
  --dart-define=COPILOT_PLAN_ENABLED=true
```

### 3.3 Ask-only canary

```powershell
flutter build windows --release `
  --dart-define=COPILOT_ASK_ENABLED=true `
  --dart-define=COPILOT_PLAN_ENABLED=false
```

目前沒有遠端百分比 rollout。5%／25% 等階段必須透過發行渠道、測試群組或分開的 build variant 控制；不得把 Plan build 發給只允許 Ask 的 cohort。

Android 對應使用相同 defines：

```powershell
flutter build appbundle --release `
  --dart-define=COPILOT_ASK_ENABLED=true `
  --dart-define=COPILOT_PLAN_ENABLED=false
```

Android、macOS、Linux 與 iOS 仍應在各平台 runner 完成 release build 與必要平台權限驗證。真實 provider／Ollama endpoint smoke test 屬建議性營運驗證，不影響功能開關或 release eligibility。

## 4. 發布前檢查

Windows 可使用下列腳本一次執行 focused analyze、Copilot tests、完整 suite、variant build、secret scan 與 artifact manifest：

```powershell
.\tool\copilot_release_check.ps1 -Variant internal
```

可用 variants：`default`、`ask`、`internal`。正式執行預設拒絕 dirty worktree；`-AllowDirty`、`-SkipFullTests`、`-SkipBuild` 只供本機 rehearsal，產出的 JSON 會將 `releaseEligible` 設為 `false`。證據檔輸出到 `build/copilot-release-evidence/`。

腳本 rehearsal 已驗證：dirty worktree 搭配跳步時成功產生 manifest，但 `releaseEligible` 為 `false`；未提供 `-AllowDirty` 時會在 analyze、測試與 build 前 fail closed。

- [x] `flutter analyze` 沒有 error 或 warning；全專案另有 158 項既有 info lint。
- [x] Copilot 測試全部通過。
- [x] 全專案 test suite checkpoint 通過：757 passed、1 skipped、0 failed；其後新增的 2 項 Plan `create` validator focused tests 通過。
- [x] Endpoint 授權 gate 採每個 host（包含 loopback）的 Dialog 確認；真實 provider／Ollama smoke test 不作為強制發布條件。
- [x] 使用合成稿件驗證 Ask、Plan、取消、timeout、401、429 與 500。
- [x] 確認 build variant 的 Ask／Plan 選項符合 cohort。
- [x] 確認 Agent 不可用，Plan 畫面沒有套用入口。
- [x] 確認送出作品與 API Key 前顯示正確目的 host。
- [x] 確認更換 host 後重新要求同意。
- [x] 確認「清除已儲存 Key」會移除 Secure Storage 中的 Key。
- [x] 基本 secret pattern scan 未在 repository 或 Windows release 目錄找到 provider key pattern／測試 Key；正式 CI 仍應使用專用 secret scanner。
- [ ] 保存 build command、commit SHA、Flutter version、artifact hash 與測試結果。

## 5. Rollout

1. Internal：Ask／Plan 皆開啟，只使用合成資料、local mock 或核准的測試帳號。
2. Ask 5%：Ask-only build，目前章節 scope；觀察至少 48 小時。
3. Ask 25%：開放專案摘要與選取資源；觀察至少 48 小時。
4. Ask Beta 100%：Plan 仍僅 internal。
5. Plan 10% → 50% → 100%：每階段需重新確認 crash、錯誤率、延遲、隱私回報與 provider 相容性。

升階前不得有未處理的 P0／P1 security finding、Key 洩漏、stale response 或專案寫入。選項 A 不蒐集 prompt／response telemetry；觀測資料只能是去識別化的本機錯誤分類或測試紀錄。

## 6. 回滾

目前是 compile-time flag，緊急停用必須重發 build：

1. 關閉 Plan：發布 Ask-only build。
2. 關閉 Ask：發布兩個旗標皆為 `false` 的 build。
3. 從測試／發行渠道停止分發舊 build。
4. 保留使用者 Secure Storage Key；不得在升級或回滾時自動刪除。
5. 通知使用者可在 Copilot 頁面手動清除 Key。

若未來加入遠端 kill switch，它只能縮小既有權限，不能遠端開啟未被 build 允許的 Ask／Plan，也不能接收作品、prompt、response 或 API Key。

## 7. 已知限制與未解除 gate

- Windows release build 已驗證；macOS、Linux、Android、iOS 尚待各平台 release build／權限驗證。
- 真實 provider／Ollama endpoint smoke test 為建議性營運檢查；使用者確認目標 host（包含 loopback）的 Dialog 才是送出作品與 API Key 的強制授權 gate。
- 原有 6 個 Character／Location Widget lifecycle failures 已修正；數量對話框不再於 route 退場動畫前 dispose controller。
- 全專案 analyze 目前有 158 項既有 info lint，沒有 error／warning。
- 沒有遠端 kill switch；停用依賴新版發布。
- context 有 byte budget，過大的內容會截斷並顯示標記。
- citation 只驗證是否來自本次 context，不保證模型推論正確。
- 對話與 Plan 不持久化；離開工作階段後無法還原。
- Plan schema v1 僅支援 allowlist 中的 target／action，且沒有套用能力。
- Direct／BYOK 的費用、配額、內容保留與服務可用性由使用者選擇的 provider 負責。

## 8. Windows 已驗證結果

- 預設 flags-off release build：成功。
- Ask／Plan flags-on internal release build：成功。
- 目前執行檔：`build/windows/x64/runner/Release/dart_edition.exe`（最後一次建置為 Ask／Plan flags-on internal variant）。
- Copilot focused tests：75/75 通過；發布前仍以對應 commit 的最新 CI 結果為準。
- Copilot focused analyze：無問題。

本機驗證證據：

- Flutter：`3.44.8 stable`；Dart `3.12.2`。
- Git base commit：`56e0634290a6efb917d0d89b2a47c3d047e8fa47`；本輪尚有未提交變更，因此不能把此 SHA 視為 artifact 的完整 source identity。
- flags-on Windows Dart AOT `data/app.so` SHA-256：`89ED7BC0CFE395AC6462CCDE5027A4168B236842697ED3BB0572682DE5CB49C8`。
- Windows launcher `dart_edition.exe` SHA-256：`DF0D947325E8613138958D16A40D6AA02D4A62E49EB7B60624B0DC085F6785DB`；launcher 不包含本次 Dart 功能差異，不可單獨作為 source identity。
- repository scan 排除 `.git`、`.dart_tool`、`build`；artifact scan 包含 `build/windows/x64/runner/Release`。兩者均未找到設定的 provider key pattern、`stored-secret` 或 `test-key`。
- 產物在任何重新建置後都會改變；正式發布必須重新產生 hash，並以乾淨、已提交的 source revision 建置。
