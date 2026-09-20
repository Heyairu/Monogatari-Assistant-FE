# Copilot Ask／Plan 模式詳細設計與實作計畫

日期：2026-09-18（最後更新：2026-09-19）  
狀態：實作中；部署架構採用選項 A（Direct／BYOK）  
適用範圍：Flutter 版本（`dart_edition/`）  
主要入口：`lib/modules/copliot.dart`  

## 1. 文件目的

本文件定義 `CopilotView` 啟用 Ask 與 Plan 模式所需的產品邊界、架構調整、資料契約、安全措施、分階段實作、測試、部署、觀測與回滾方式。

這份計畫將「可顯示一個新模式」與「模式真的安全可用」分開處理。Ask 必須能在明確範圍內讀取作品資料並回答；Plan 必須產生可驗證、可追溯的結構化計畫。單純解除下拉選單的停用狀態不算完成功能。

## 2. 結論與建議路線

| 能力 | 可行性 | 建議首版 | 風險 |
| --- | --- | --- | --- |
| Ask：目前章節問答 | 高 | 優先交付 | 作品內容外傳、上下文截斷 |
| Ask：跨專案資料問答 | 高 | 範圍勾選後交付 | token／成本、來源準確度 |
| Plan：唯讀修改計畫 | 高 | 優先交付 | JSON 格式不穩定、引用失效 |
| Plan：加入既有更新計畫 | 中高 | 第二階段，使用者確認後寫入 | 重複項目、協作同步 |
| Agent：自動修改正文或設定 | 中 | 不納入首版 | 資料毀損、衝突、undo、權限 |
| Agent：自主多步執行 | 中低 | 本計畫不啟用 | 工具安全、prompt injection、審批 |

建議採下列順序：

```text
P0 基線、安全與拆分
  → P1 上下文契約與 provider adapter
    → P2 Ask MVP
      → P3 Plan 唯讀 MVP
        → P4 安全性、效能與跨平台驗收
          → P5 分階段部署
            → P6 可選：受控套用計畫
```

正式第一版確定採用選項 A：使用者自備 API key，由 App 直接呼叫模型，不新增、不依賴 Copilot 後端。若未來提供官方額度、帳號配額或集中模型政策，必須另立提案與安全審查，不能默認納入本輪範圍。

### 2.1 已確認決策：選項 A

選項 A 的首版交付契約如下：

- App 直接連線使用者選擇的 OpenAI、Gemini、Anthropic、Grok、OpenRouter、自訂 OpenAI-compatible endpoint 或 Ollama。
- API key 由使用者提供，只保存在裝置的 Secure Storage。
- Monogatari Assistant 不代管 provider key、不提供官方 token 額度，也不經手模型費用。
- 作品 context 由 App 直接傳送到使用者選定的 endpoint，不經過 Monogatari Assistant 伺服器。
- 不建置帳號、付款、quota、集中 provider routing 或 server-side prompt logging。
- 首版的緊急停用依賴 build-time feature flag 與新版發布；若日後需要遠端 kill switch，必須是獨立、只能縮小權限的設定服務。
- Gateway 僅保留為未來替代架構說明，不是 P0～P6 的相依項或交付項。

## 3. 現況基線

### 3.0 實作進度（2026-09-19）

已完成 Ask／Plan 的安全垂直切片，並開始收斂可測試架構：

- API key 已改存 Secure Storage，包含舊 SharedPreferences 明文 key 的驗證後遷移與刪除。
- Ask／Plan 已加入 build-time feature flag，標準 build 預設關閉。
- `CopilotView` 已接入 Riverpod，Ask／Plan 只擷取已保存的目前章節快照。
- 目前章節 context 已具有 72 KiB UTF-8 上限、截斷標記與 deterministic fingerprint。
- OpenAI-compatible、Gemini、Anthropic、Ollama 已使用各自正確的 system instruction 欄位。
- `MNPROJ_FILE_STRUCTURE.md` 已列入 Flutter assets；Ask／Plan 每次請求會把內容加入受信任的 system format reference，Agent policy 亦已預備相同規則但 Agent 仍停用，Chat 不會附帶此文件。
- 雲端送出作品內容前會顯示目的 host 與章節名稱，需使用者確認。
- Plan v1 已具備 JSON parser、schema、target/action allowlist、ID、fingerprint 與 dependency 驗證。
- Plan `create` 是合法的唯讀提案 action，可使用 null 或最長 200 字元的新目標識別；它只會顯示／匯出，不會建立章節、角色或任何專案資料。
- Plan 已有唯讀步驟、風險、問題預覽，沒有套用入口。
- Ask 已有 JSON answer／citation／uncertainty 契約；不存在於 request context 的引用會被丟棄並提示。
- Ask 的章節與選取資源 citation 可點擊定位至對應章節或功能頁；專案索引摘要維持不可導覽的來源標籤。
- Ask 可選「目前章節」、「目前章節＋專案索引摘要」或「目前章節＋選取資源」；摘要不包含其他章節正文，且上限 24 KiB。
- 選取資源支援搜尋角色、世界觀、大綱／事件與詞語；最多 12 項、每項 8 KiB、合計 32 KiB，並依類型、標題與穩定 ID deterministic 排序。
- 使用者可取消進行中的 HTTP request；取消或失敗會恢復輸入且不留下重複 user message。
- Plan 可複製或經系統儲存對話框匯出格式化 JSON；章節內容變更後會顯示 stale 提示，無效 Plan 則保留原始回覆但不建立計畫。
- 雲端 API 強制 HTTPS；HTTP 只允許 loopback，HTTP redirect 不自動跟隨。
- UI 錯誤已分類並移除原始 network exception／URL，避免 Gemini query key 或 request 細節外洩。
- provider-specific request／response mapping 已抽成純 Dart adapter；OpenAI-compatible、Gemini、Anthropic、Ollama fixture 可不依賴 widget 測試。
- bounded HTTP transport 已抽離 widget，集中處理 redirect 關閉、request／response byte budget、timeout client recovery、取消與 dispose。
- HTTP status、timeout、超限與無效 response 已由 domain error policy 分類；未知 exception、URL、query key、response source 與 prompt 細節不會進入 UI 訊息。
- latest-wins generation、設定／模式一致性與取消已抽成純 Dart request coordinator；舊 ticket 無法發布 response。
- bounded conversation buffer 已抽離 Widget，集中處理模式隔離、200 則／1 MiB UI history、24 則／128 KiB model context，以及取消或失敗時的 pending user message rollback。
- conversation presentation orchestration 已抽成純 Dart controller，active operation、sending state、精確 pending rollback、stale publication 與取消失效不再由 Widget 個別維護。
- 非 2xx status guard 已集中至 domain error policy；loopback mock server 驗證 401、429、500 不洩漏 response body，oversize、timeout 與取消後 HTTP client 均可恢復。
- OpenAI-compatible、Gemini、Anthropic、Ollama 已通過 models、Ask 與 Plan 真實 loopback round-trip；測試會驗證 provider-specific system 欄位、untrusted context、認證位置、結構化 Ask parser 與 Plan validator。
- `CopilotView` 支援 constructor-only 測試旗標與 settings store injection；production 預設仍由 build-time flags 與 Secure Storage 決定。Widget tests 已覆蓋 disabled flags、Ask／Plan composer policy／hint，以及 settings load 完成晚於 dispose 的 mounted guard。
- active HTTP Widget tests 已驗證 dispose 會關閉 transport；使用者取消會撤回 pending message、恢復原輸入、顯示取消狀態並 rotate client，晚到錯誤不會發布。
- provider error／retry Widget flow 已驗證 429 不顯示 response body、輸入可恢復並再次送出；Ask scope 切換會同步更新隱私摘要，且選取資源 action 只在對應 scope 顯示。
- provider host 變更 Widget guardrail 已驗證：對舊 host 的 API Key 傳送同意不會沿用到新 host，重新確認前不會送出 HTTP request。
- Copilot 頁面已加入可展開的隱私／第三方服務／已知限制告知，以及需確認的 Secure Storage API Key 手動清除流程。
- Plan Widget tests 已驗證唯讀 card、風險／問題、stale banner、invalid raw fallback 與沒有套用入口；Ask citation tests 已驗證章節／資源導覽、專案摘要不可點擊及 invalid citation 提示。
- selected-resource dialog 已驗證搜尋、空結果、12 項 hard limit、確認數量與已刪除資源清理；並修正 dialog 退場動畫期間過早 dispose 搜尋 controller 的 lifecycle bug。
- 100 KiB、500 KiB、1 MiB chapter benchmark 均固定輸出 72 KiB context／prompt，兩次 deterministic build 分別約 99 ms、64 ms、80 ms（本機 debug test），總時間低於 5 秒 budget。
- 新增 Copilot domain、project overview／selected resources、settings migration、provider adapter、HTTP transport、error policy、request coordinator、conversation buffer、conversation controller、Widget、benchmark 與 guardrail 測試；81 項相關測試通過。
- Copilot 範圍 `flutter analyze` 無問題；Windows 預設關閉版與 Ask／Plan 皆開啟的 internal release build 均已成功。
- Windows flags-on artifact 已記錄 SHA-256、Flutter／Dart 版本與 git base commit；repository／release 目錄基本 secret pattern scan 無命中。
- 新增 `tool/copilot_release_check.ps1`，自動驗證 variant flags、focused analyze、Copilot／完整測試、Windows build、provider key pattern scan 與逐檔 artifact hash；dirty 或跳步 rehearsal 會強制標示為不可發布。
- 全專案 `flutter analyze` 無 error／warning，但仍有 158 項既有 info lint；最近完整 test suite checkpoint 為 757 passed、1 skipped、0 failed，後續新增的 2 項 `create` validator focused tests 亦通過。
- 已修正 Character／Location 物品數量對話框在 route 退場動畫前過早 dispose `TextEditingController` 的 lifecycle bug；原 6 個 full-suite blockers 全數解除。

尚未完成：其餘平台 release build 驗收與 rollout。真實 endpoint smoke test 改列建議性營運驗證，不再阻擋 Ask／Plan 啟用；傳送授權由每個 host 的 Dialog 確認負責。

### 3.1 已存在能力

- `CopilotMode` 已包含 `chat`、`ask`、`plan`、`agent`。
- 已支援 OpenAI-compatible、Gemini、Anthropic、Ollama。
- 已能讀取模型清單、送出對話並解析各 provider 的文字回覆。
- 已有 request、response、context 與 UI history 大小限制。
- 已有 timeout、request generation、latest-wins 與 `http.Client` lifecycle 管理。
- `projectDataProvider` 可建立目前完整 `ProjectData`。
- `selectedChapterStoredContentProvider` 可取得已保存的目前章節內容。
- 專案已依賴 `flutter_secure_storage`，可直接用於 API key。

### 3.2 尚未完成

- `_sendMessage()` 只接受 Chat 模式。
- Ask、Plan、Agent 在下拉選單中被停用。
- 輸入框與送出按鈕只在 Chat 模式啟用。
- `CopilotView` 是 `StatefulWidget`，尚未讀取 Riverpod 專案狀態。
- system message 會被 context builder 排除，各 provider 也沒有模式指令 adapter。
- 沒有 context scope、來源引用、token budget、摘要或檢索流程。
- 沒有 Plan schema、parser、validator、預覽或持久化規則。
- API key 目前寫入 `SharedPreferences`，不符合正式發布要求。
- `copliot.dart` 超過 1,200 行，UI、設定、傳輸與 parsing 耦合。
- 現有 `copilot_resource_guardrail_test.dart` 只覆蓋靜態資源上限，未驗證模式行為。

### 3.3 單純解除 UI 停用不可行的原因

即使將 Ask／Plan 的 `enabled: false` 移除，仍會遇到：

1. `_sendMessage()` 因模式不是 Chat 而直接 return。
2. 沒有模式專用 system instruction，模型無法區分 Chat、Ask、Plan。
3. 沒有把作品資料加入 request。
4. Plan 回覆仍只是普通字串，無法驗證或呈現步驟。
5. API key 仍以明文保存。

因此必須先完成 P0、P1，再開啟入口。

## 4. 產品契約

### 4.1 Chat

維持現有一般對話，不自動讀取專案內容。後續可允許使用者手動附加內容，但不納入本次必要範圍。

### 4.2 Ask

Ask 是唯讀作品問答，允許模型根據使用者明確選取的上下文回答，但不能回傳或觸發任何專案寫入操作。

首版支援的上下文範圍：

- `currentChapter`：目前章節，預設值。
- `currentChapterAndReferences`：目前章節加上被引用或勾選的角色、地點、術語與大綱項目。
- `selectedResources`：只傳送使用者勾選的資料。
- `projectOverview`：專案摘要與資料索引，不傳全部正文。

首版不提供 `entireProjectRaw`。完整專案內容必須先經過摘要、檢索或使用者明確選取，避免無上限上傳稿件。

Ask 回覆應包含：

- 主回答。
- 引用來源列表。
- 使用的 context scope。
- 被截斷或未納入的資料提示。
- 模型無法從現有資料確認時，明確標示不確定。

### 4.3 Plan

Plan 首版只產生唯讀計畫，不修改正文、角色、世界觀、大綱、時間軸或其他 provider。

計畫必須包含：

- 目標與摘要。
- 有順序的步驟。
- 每個步驟的目標類型與穩定 ID。
- 建議動作、理由與預期結果。
- 風險、相依性與待使用者回答的問題。
- context 版本指紋，供後續判斷計畫是否過期。

Plan 不得把模型產生的自由文字直接解讀為可執行操作。只有通過 schema、ID 與 action allowlist 驗證的資料，才能進入計畫預覽。

### 4.4 非目標

首版明確不包含：

- 未經確認直接修改作品。
- 檔案系統、網路、shell 或任意程式執行工具。
- 自主循環呼叫模型。
- 背景常駐 Agent。
- 自動上傳整個專案。
- 在 telemetry 或錯誤回報中保存正文、prompt、response 或 API key。
- 對所有 provider 保證完全相同的 structured-output 能力。

## 5. 架構設計

### 5.1 建議目錄

```text
lib/features/copilot/
├── application/
│   ├── copilot_controller.dart
│   ├── copilot_context_builder.dart
│   ├── copilot_prompt_policy.dart
│   ├── copilot_request_budget.dart
│   └── copilot_plan_parser.dart
├── data/
│   ├── copilot_settings_store.dart
│   ├── copilot_secure_settings_store.dart
│   ├── copilot_transport.dart
│   └── providers/
│       ├── openai_compatible_adapter.dart
│       ├── anthropic_adapter.dart
│       ├── gemini_adapter.dart
│       └── ollama_adapter.dart
├── domain/
│   ├── copilot_context.dart
│   ├── copilot_message.dart
│   ├── copilot_mode.dart
│   ├── copilot_plan.dart
│   ├── copilot_provider.dart
│   └── copilot_response.dart
└── presentation/
    ├── copilot_view.dart
    └── widgets/
        ├── copilot_context_scope_selector.dart
        ├── copilot_message_bubble.dart
        ├── copilot_plan_card.dart
        └── copilot_privacy_summary.dart
```

實作過渡期間可保留 `lib/modules/copliot.dart` 作為 re-export 或薄 wrapper，避免一次修改太多 import。完成遷移後，再獨立修正 `copliot` 拼字。

### 5.2 元件責任

| 元件 | 責任 | 不應負責 |
| --- | --- | --- |
| `CopilotView` | 顯示狀態、收集使用者輸入 | 組 request、直接存 key |
| `CopilotController` | mode workflow、取消、狀態轉換 | provider-specific JSON |
| `CopilotContextBuilder` | 從 snapshot 建立有限上下文 | 修改 project provider |
| `CopilotPromptPolicy` | 建立模式規則與資料邊界 | 直接發 HTTP |
| Provider adapter | request／response 格式轉換 | 讀取 Flutter widget 狀態 |
| `CopilotPlanParser` | JSON 清理、schema 與語意驗證 | 自動套用計畫 |
| Settings store | 非敏感設定 | 儲存 API key |
| Secure settings store | API key lifecycle | 儲存對話或作品內容 |

### 5.3 狀態管理

建議使用 Riverpod Notifier／AsyncNotifier 管理 Copilot session，而不是把更多狀態加回 widget。

```dart
enum CopilotRequestStatus { idle, preparingContext, sending, parsing, done, failed }

class CopilotSessionState {
  final CopilotMode mode;
  final CopilotRequestStatus status;
  final List<CopilotMessage> messages;
  final CopilotContextScope scope;
  final CopilotPlan? latestPlan;
  final CopilotUsage? usage;
  final String? errorMessage;
}
```

必要不變條件：

- 同時間只允許一個 active request。
- 修改 provider、URL、model、key 或 scope 後，舊 response 不得寫回新 session。
- view dispose 後不得更新 UI。
- mode 切換不得沿用不相容的 system policy 或 plan parsing 狀態。
- retry 必須重建當下 context snapshot，不得混用部分舊資料。

## 6. 上下文資料契約

### 6.1 Snapshot

```dart
class CopilotContextSnapshot {
  final String sessionProjectId;
  final String scope;
  final DateTime capturedAt;
  final String contentFingerprint;
  final List<CopilotContextResource> resources;
  final CopilotContextBudget budget;
}

class CopilotContextResource {
  final String type;
  final String id;
  final String title;
  final String content;
  final String fingerprint;
  final bool truncated;
}
```

`sessionProjectId` 不應直接使用可跨服務追蹤的永久識別碼；可用 project UUID 與本機 session nonce 計算不可逆短期 ID。

### 6.2 Resource 類型

首版 allowlist：

- `chapter`
- `character`
- `location`
- `worldSetting`
- `outlineEvent`
- `glossaryTerm`
- `foreshadow`
- `updatePlan`
- `projectSummary`

未知類型不加入 request。每種 resource 由獨立 formatter 產生穩定、可測試的純文字或 JSON 片段。

### 6.3 Context budget

現有 128 KiB byte cap 繼續作為 transport guardrail，但另加邏輯預算：

1. 保留 system policy 與使用者問題空間。
2. 目前章節優先。
3. 明確勾選資料次之。
4. 相關索引與摘要再次之。
5. 舊對話最後加入。

建議預設：

| 項目 | 建議預算 |
| --- | ---: |
| system／模式規則 | 8% |
| 使用者問題 | 8% |
| 作品 context | 64% |
| 對話歷史 | 12% |
| 回覆保留 | 8% 以上，由模型 output limit 另控 |

token estimator 可先用保守字元估算，之後再依 provider tokenizer 精準化。任何截斷都必須在 UI 與 request metadata 中揭露。

### 6.4 Prompt injection 防護

作品內容一律視為不可信資料，即使其中包含「忽略前面規則」或類似文字，也不得改變 Copilot policy。

必要措施：

- system policy 明確標記 `<project_content>` 只供引用。
- `.mnproj` 格式文件以 `<mnproj_structure_reference>` 放在 system instruction，明確標示為受信任的 App 文件；上限 64 KiB，不存入 conversation history，Chat 不附帶。
- context 與 instructions 分欄傳送，不以字串拼接模擬 system role。
- Ask／Plan 不提供寫入工具。
- 引用只接受 snapshot 中存在的 resource ID。
- response 中出現的 URL、命令或工具要求只作為文字顯示。

## 7. Provider adapter 契約

### 7.1 統一輸入

```dart
class CopilotRequest {
  final CopilotMode mode;
  final String model;
  final String systemInstruction;
  final List<CopilotMessage> messages;
  final CopilotContextSnapshot? context;
  final CopilotOutputContract outputContract;
  final int maxOutputTokens;
}
```

### 7.2 Provider 對應

| Provider | system instruction | Ask | Plan JSON |
| --- | --- | --- | --- |
| OpenAI-compatible | system／developer message | 支援 | 能力偵測；否則 prompt JSON |
| Anthropic | request 頂層 `system` | 支援 | tool／schema 能力可選；需文字 fallback |
| Gemini | `systemInstruction` | 支援 | response schema 能力可選；需文字 fallback |
| Ollama | system message | 支援 | 視模型而定；預設文字 JSON fallback |

不得假設 OpenAI-compatible endpoint 一定支援特定廠商的 `response_format`、tool calling 或 streaming extension。能力應由 preset 宣告，未知 provider 採最小共同功能。

### 7.3 錯誤分類

建立可測試的 domain error：

- `invalidConfiguration`
- `authenticationFailed`
- `rateLimited`
- `modelUnavailable`
- `contextTooLarge`
- `responseTooLarge`
- `requestTimedOut`
- `invalidResponse`
- `invalidPlan`
- `networkUnavailable`
- `cancelled`

UI 不直接顯示原始 exception。HTTP response preview 必須移除 key、header 與可能包含完整 prompt 的欄位。

## 8. Ask 模式實作

### 8.1 Request 流程

```text
使用者選 Ask
  → 選擇 context scope
  → 輸入問題
  → 建立 immutable ProjectData snapshot
  → 建立並裁切 CopilotContextSnapshot
  → 顯示／確認將傳送的資料摘要
  → provider adapter 組 request
  → 發送
  → 解析回答與 citation IDs
  → 驗證 citation 存在
  → 顯示回答、來源與截斷提示
```

### 8.2 Ask output contract

首版可要求模型回傳 JSON；解析失敗時降級顯示文字，但不得偽造引用。

```json
{
  "answer": "回答內容",
  "citations": [
    {
      "resourceId": "chapter-uuid",
      "quoteHint": "可定位的短片段或段落描述"
    }
  ],
  "uncertainties": ["尚未提供第四章內容"]
}
```

驗證規則：

- `answer` 必須是非空字串。
- citation ID 必須存在於送出的 snapshot。
- `quoteHint` 只用於定位，不直接信任為原文。
- 無有效 citation 時顯示「模型未提供可驗證來源」。
- 不將 provider 的 token usage 當成必定存在。

### 8.3 Ask UI

- 模式選擇器啟用 Ask。
- 輸入框 hint 改成 Ask 專用文字。
- composer 上方加入 context chip／selector。
- 首次向雲端 provider 傳送作品時顯示一次性確認。
- 發送前可展開「將傳送的內容」。
- message bubble 顯示來源 chips，點擊後跳至對應資料。
- 截斷、未找到來源或 stale citation 顯示非阻斷警告。

## 9. Plan 模式實作

### 9.1 Domain model

```dart
class CopilotPlan {
  final String schemaVersion;
  final String goal;
  final String summary;
  final String contextFingerprint;
  final List<CopilotPlanStep> steps;
  final List<String> risks;
  final List<String> questions;
}

class CopilotPlanStep {
  final String id;
  final int order;
  final String targetType;
  final String? targetId;
  final String action;
  final String reason;
  final String proposal;
  final List<String> dependsOn;
}
```

### 9.2 首版 allowlist

`targetType`：

- `chapter`
- `character`
- `location`
- `worldSetting`
- `outlineEvent`
- `glossaryTerm`
- `foreshadow`
- `updatePlan`
- `project`

`action`：

- `review`
- `revise`
- `add`
- `removeSuggestion`
- `reorderSuggestion`
- `clarify`
- `research`

這些 action 在 P3 都只是描述，不可直接 dispatch 到現有 notifier。

### 9.3 JSON contract

```json
{
  "schemaVersion": "1",
  "goal": "加強第三章伏筆",
  "summary": "調整三處對話並補足角色動機",
  "contextFingerprint": "sha256:...",
  "steps": [
    {
      "id": "step-1",
      "order": 1,
      "targetType": "chapter",
      "targetId": "chapter-uuid",
      "action": "revise",
      "reason": "提前建立線索",
      "proposal": "在開場對話加入對失蹤事件的間接提及",
      "dependsOn": []
    }
  ],
  "risks": ["過早揭露可能降低懸疑感"],
  "questions": ["伏筆預計在第幾章回收？"]
}
```

### 9.4 Parser 與語意驗證

順序：

1. 限制 raw response bytes。
2. 移除單一外層 Markdown JSON fence。
3. `jsonDecode`。
4. 驗證必要欄位、型別、字串與陣列長度。
5. 驗證 schema version。
6. 驗證 `targetType` 與 `action` allowlist。
7. 驗證 target ID 是否存在於 request snapshot。
8. 驗證 step ID 唯一、order 唯一且依賴無循環。
9. 比較 context fingerprint。
10. 建立 immutable `CopilotPlan`。

任何步驟失敗都不得形成可套用計畫。UI 顯示可理解錯誤，並允許查看或複製原始文字。

### 9.5 Plan UI

- 啟用 Plan 選項。
- 顯示 goal、summary、risks、questions。
- 步驟以排序卡片呈現。
- target ID 可解析時顯示名稱與跳轉入口。
- context 已變更時標記「計畫可能已過期」。
- 首版按鈕：複製、重新產生、匯出 JSON、清除。
- 「套用」按鈕在 P3 不存在，避免誤導。

### 9.6 可選：加入既有更新計畫

若 P6 啟用，必須是明確的二次操作：

1. 使用者選擇要匯入的 step。
2. 預覽轉換後的 `UpdatePlanItem`。
3. 檢查重複內容。
4. 使用者確認。
5. 透過正式 notifier 寫入。
6. 寫入歷史／協作 transaction。

不得直接把完整 `CopilotPlan` 當成既有 `UpdatePlanItem`，兩者語意與生命週期不同。

## 10. 設定與金鑰安全

### 10.1 儲存分流

| 資料 | 儲存位置 |
| --- | --- |
| provider 名稱 | SharedPreferences |
| API URL | SharedPreferences |
| model | SharedPreferences |
| 預設 context scope | SharedPreferences |
| API key | FlutterSecureStorage |
| 對話／作品內容 | 首版僅記憶體，不持久化 |
| Plan | 首版僅記憶體；匯出需使用者明確操作 |

### 10.2 明文 key 遷移

```text
啟動 Copilot 設定
  → 讀 Secure Storage
  → 若不存在，再讀舊 SharedPreferences key
  → 寫入 Secure Storage
  → 驗證可讀回
  → 刪除舊 SharedPreferences key
  → 保存 migration version
```

如果 secure write 失敗，不刪除舊值；UI 顯示設定無法安全保存，並禁止靜默繼續使用明文。

### 10.3 URL 與憑證規則

- 雲端 provider 預設只允許 HTTPS。
- `http://localhost`、loopback 或明確 LAN Ollama 由平台能力與使用者確認決定。
- provider host 改變後，不自動把既有 key 發送到新 host。
- 自訂 URL 首次送出前顯示 hostname。
- redirect 不得把 Authorization header 帶到不同 host。
- production log 不輸出 request body、response body、Authorization、query key。

## 11. 跨平台與部署架構

### 11.1 已採用方案 A：Direct／BYOK

App 直接連線 OpenAI、Gemini、Anthropic、OpenRouter、Grok 或 Ollama，使用者自行提供 key。這是本輪確定採用的正式部署架構。

適用：Ask／Plan MVP、桌面優先、內測與低營運成本版本。

優點：

- 不需部署新後端。
- 可沿用現有 transport。
- 使用者可選 provider 與本機 Ollama。
- 官方不代管 API key 或作品內容。

限制：

- App 需維護 provider 差異。
- 無法集中控制 quota、模型下架或成本。
- 行動平台無法用 `localhost` 連使用者電腦上的 Ollama。
- 自訂 URL 可能有憑證與資料外洩風險。

### 11.2 未採用方案 B：Copilot Gateway（未來參考）

本輪不實作、不部署 Gateway。未來若另行決定提供官方服務，才考慮下列統一 API：

```text
GET  /v1/copilot/models
POST /v1/copilot/ask
POST /v1/copilot/plan
POST /v1/copilot/feedback        # 選配，不含正文
GET  /v1/copilot/capabilities
```

Gateway 負責：

- 身份驗證、quota、rate limit。
- server-side provider key。
- provider routing 與 fallback。
- JSON schema 正規化。
- 使用量與成本統計。
- 模型 allowlist、kill switch 與版本政策。
- 隱私安全的 audit metadata。

後端最低部署元件：

- HTTPS API service。
- Secret manager。
- Authentication service。
- Rate-limit／quota store。
- Metrics、error tracking 與 alert。
- 不記錄 prompt／response 的 logging filter。

P0～P6 不得引入 Gateway 相依、Gateway URL、官方帳號、付費或 server-side provider key。未來若需求改變，另建獨立後端實作計畫。

### 11.3 平台注意事項

| 平台 | 雲端 HTTPS | 本機 Ollama HTTP | 準備 |
| --- | --- | --- | --- |
| Windows | 可 | 通常可 | release smoke、installer／ZIP 驗證 |
| macOS | 可，已有 network client entitlement | 可，但需簽章實測 | notarization、sandbox 實測 |
| Linux | 可 | 可 | CA bundle、AppImage／套件實測 |
| Android | 已有 INTERNET 權限 | cleartext 常被阻擋 | 雲端 provider 使用 HTTPS；Ollama 僅在受控 local／LAN policy 下支援 |
| iOS | 可 | ATS／localhost 語意限制 | ATS 與 Local Network 實機測試 |

不要為了 Ollama 全域放寬 cleartext。若要支援，只允許明確的 local／LAN 開發情境，並在 release policy 中記錄例外。

## 12. 分階段實作清單

## P0：基線、安全與拆分

目標：不改變 Chat 使用者行為，先建立可測試架構。

- [x] 記錄 Chat request mapping 與各 provider response fixture。
- [x] 建立 `CopilotMode`、message、provider、error domain model。
- [x] 抽出 provider request／response adapter。
- [x] 抽出 bounded、可取消的 HTTP transport。
- [x] 抽出 latest-wins／取消 request coordinator。
- [x] 抽出 bounded conversation buffer（模式隔離、history／context budget、pending rollback）。
- [x] 抽出 conversation presentation orchestration controller；timeout 與 response limits 已由 transport 負責。
- [x] 拆出 settings store。
- [x] 導入 Secure Storage API key。
- [x] 完成舊 SharedPreferences key 遷移與刪除。
- [x] 對自訂 URL 加入 HTTPS、API key／作品內容目的 host 確認。
- [x] 保留原 Chat UI 與所有既有 provider。
- [x] 增加 Ask／Plan feature flag，預設關閉。

完成條件：

- Chat 行為、資源上限與 provider 相容性無回歸。
- SharedPreferences 不再含 API key。
- transport／parser 可在沒有 widget 的 unit test 中測試。
- Ask／Plan UI 仍不可對一般使用者啟用。

## P1：上下文與模式 policy

目標：建立 Ask／Plan 共用但唯讀的 context pipeline。

- [x] 將 Copilot presentation 接至 Riverpod。
- [x] 建立 `CopilotContextSnapshot` 與目前章節 formatter。
- [x] 支援目前章節、受限專案索引摘要與任意資源搜尋／勾選。
- [x] 建立目前章節與多資源 byte budget、截斷、deterministic 排序與 fingerprint。
- [x] 建立 Ask／Plan system instruction。
- [x] 在四類 provider request 中正確放置 system instruction。
- [x] 將作品內容標記為 untrusted context。
- [x] 建立 context 大小／截斷摘要與送出前隱私確認。
- [x] 確保目前章節 context builder 沒有任何寫入 provider 的參考。

完成條件：

- 固定 fixture 對相同 snapshot 產生 deterministic context。
- 超出 budget 時依優先級截斷，且 UI 可見。
- 作品中的 prompt injection 字串不會取代 system policy。
- 切換章節或 provider 後，舊 response 不會發布。

## P2：Ask MVP

目標：交付目前章節與選取資源的可追溯問答。

- [x] Ask dropdown option 已由 feature flag 控制。
- [x] 允許已開旗標的 Ask 模式輸入與送出。
- [x] 加入目前章節／專案摘要／選取資源 context scope selector。
- [x] 建立 Ask request／response contract與純文字降級。
- [x] 驗證 citation ID，只接受 request context 內的 resource。
- [x] 顯示引用、uncertainty、無效引用與 truncation。
- [x] 章節與選取資源 citation 可點擊並定位至對應章節或功能頁。
- [x] 支援取消與以恢復輸入重新送出的 retry。
- [x] 失敗時保留使用者輸入，但不重複加入歷史。
- [x] 首次向每個雲端 host 傳送時顯示隱私確認。
- [x] 加入 Ask build-time feature flag；遠端 kill switch 待辦。

完成條件：

- 使用者能對目前章節提問並取得答案。
- 引用只能指向實際送出的 resource。
- Ask 無法改變專案 provider。
- request 過大、timeout、401、429 與無效 response 均有清楚錯誤。

## P3：Plan 唯讀 MVP

目標：產生可驗證、可預覽但不可自動套用的計畫。

- [x] 建立 `CopilotPlan` 與 `CopilotPlanStep`。
- [x] 建立 JSON schema／版本。
- [x] 實作 fence cleanup、parser、validator。
- [x] 驗證 ID、allowlist、排序、依賴與 fingerprint。
- [x] Plan dropdown option 已由 feature flag 控制。
- [x] 建立 Plan 專用 composer 說明。
- [x] 建立 plan／step／risk／question 唯讀 UI。
- [x] 支援複製 JSON 與使用系統儲存對話框匯出 JSON。
- [x] context 改變時標示 stale。
- [x] 解析失敗只顯示 raw response，不提供套用入口。
- [x] 加入 Plan build-time feature flag；遠端 kill switch 待辦。

完成條件：

- 四類 provider 至少能以 fallback JSON prompt 產生計畫。
- malformed、超大、未知 action、失效 ID 與循環依賴全部被拒絕。
- UI 中沒有直接修改專案的入口。

## P4：完整驗收與效能

- [x] 100 KiB、500 KiB、1 MiB 章節 context benchmark；72 KiB bounded output、deterministic fingerprint 與 5 秒 debug／CI budget。
- [x] 250 則輸入下驗證 200 則／1 MiB UI history 上限。
- [x] request coordinator 與 conversation controller 的快速重送／取消／設定與模式切換 latest-wins unit tests；Widget concurrency 待辦。
- [x] active HTTP request Widget dispose、settings load late-completion mounted guard，以及 HTTP timeout／取消後 client recovery。
- [x] loopback mock server 401、429、500、timeout、取消與 response oversize error paths。
- [x] 四類 provider 的 models、Ask、Plan loopback round-trip 與 parser／validator integration。
- [x] API key migration、error redaction unit tests 與 provider host change 重新同意 Widget test。
- [x] Ask／Plan 與 future Agent prompt policy 會附帶完整 `.mnproj` 結構參考；asset 存在性、64 KiB 上限與 16 個持久化模組清單有自動測試。
- [x] 取消強制 endpoint smoke gate；作品內容與 API Key 在每個 host（包含 loopback）首次傳送前以 Dialog 確認，更換 host 必須重新同意。
- [ ] 真實 provider／Ollama endpoint smoke test（建議性營運驗證，不阻擋啟用或發布）。
- [x] Ollama `/v1` 與 `/api/chat` request／response fixture；實機測試待辦。
- [x] Copilot 範圍 Flutter analyze 無問題；Windows 預設關閉版與 Ask／Plan flags-on internal release build 均成功。
- [x] 全專案 analyze／test gate：analyze 無 error／warning但有 158 項既有 info lint；完整 suite checkpoint 為 757 passed、1 skipped、0 failed，後續 2 項 `create` validator focused tests 通過。
- [x] 隱私文字、第三方 provider 告知、已知限制與 release／rollback runbook 完成。

完成條件：

- 沒有 P0／P1 security finding。
- 無 crash、stale response 或 key 洩漏。
- context build 不造成可感知 UI 卡頓；大型資料需 isolate 時完成移轉。
- release artifact 可透過 flag 關閉新模式。

## P5：部署與逐步開放

建議 rollout：

1. Internal：feature flag 開啟，固定測試 key／local mock。
2. Canary 5%：只啟用 Ask、目前章節 scope。
3. Canary 25%：Ask 加選取資源。
4. Beta 100%：Ask 全量；Plan 僅 internal。
5. Plan 10% → 50% → 100%。
6. 穩定後才評估 P6。

每階段觀察至少：

- request success rate。
- timeout、401、429、invalid response 比例。
- context bytes、截斷比例與 latency 分布。
- Plan parse／validation success rate。
- crash-free sessions。
- 使用者主動回報的資料範圍誤解。

監測資料只保存技術 metadata，不保存 prompt、正文、回答、API key 或可還原作品內容的 fingerprint。

## P6：可選的受控套用

此階段不屬於 Ask／Plan 首版完成條件。

- [ ] 先只支援將選定 step 轉為 `UpdatePlanItem`。
- [ ] 顯示轉換 diff 與重複偵測。
- [ ] 使用者逐項確認。
- [ ] 使用正式 notifier 與 collaboration transaction。
- [ ] 支援 undo／redo 與 P2P conflict。
- [ ] 套用前比較 context fingerprint／target revision。
- [ ] stale plan 必須重新確認或重新產生。
- [ ] 正文 patch 另立設計文件與安全審查，不和此階段綁定。

## 13. 測試矩陣

### 13.1 Unit tests

- Provider request mapping：system、messages、model、token limit。
- Provider response parsing：正常、空值、多段、錯誤格式。
- Context priority、budget、UTF-8、極長單一 resource。
- Fingerprint deterministic 與內容變更。
- Ask citation validation。
- Plan schema、allowlist、ID、依賴環、順序、數量上限。
- Secure Storage migration 與 failure recovery。
- URL normalization、redirect host 與 credential forwarding。
- Error redaction。

### 13.2 Widget tests

- [x] mode selector feature flag；Agent 固定停用。
- [x] Chat／Ask／Plan composer enable／hint；Agent composer 待進一步行為測試。
- [x] context selector、privacy summary 與 selected-resource action visibility。
- [x] selected-resource dialog 搜尋、12 項上限、確認與失效 selection 清理。
- [x] loading／cancel／prompt restore／provider error／retry success。
- [x] citation chip、chapter／resource target navigation、non-navigable project overview 與 invalid citation notice。
- [x] plan cards、read-only actions、invalid raw fallback、stale banner 與 no-apply guard。
- [x] settings load 與 active HTTP late completion 在 dispose 後不 setState，且 transport 會關閉。

### 13.3 Integration tests

- [x] mock server：OpenAI-compatible round-trip、302 redirect、401、429、500、timeout、取消、oversize 與 client recovery。
- [x] mock server：OpenAI-compatible、Gemini、Anthropic、Ollama models、Ask、Plan flows。
- request generation：舊 response 不覆蓋新設定。
- secure key 存取與舊 key 清除。
- 章節切換期間 snapshot 一致性。
- 協作更新期間 plan stale detection。
- release mode 真實 TLS endpoint。

### 13.4 安全測試案例

- 正文包含「忽略 system prompt」。
- 模型回傳不存在的 target ID。
- 模型回傳未知 action／tool call。
- 自訂 URL 從可信 host 改為惡意 host。
- 30x redirect 至不同 host。
- 錯誤 body 回顯 Authorization 或 prompt。
- 超大 Unicode／surrogate pair／深層 JSON。
- Markdown fence、前後雜訊、重複 key、循環依賴。

## 14. CI／CD 調整

現有 Linux CI 保留，新增：

- Copilot unit／widget tests 納入一般 `flutter test`。
- 固定 mock server 測試不得依賴外網或真實 API key。
- secret scanner／測試確認 repository 與 artifact 無測試 key。
- Windows release build job。
- Windows 可先以 `tool/copilot_release_check.ps1` 作為本機／CI 共用 release gate；正式執行拒絕 dirty worktree。
- Android APK 或 App Bundle release build job。
- macOS／iOS 在可用 runner 上加入簽章前 smoke build。
- release checklist 驗證 feature flags、privacy copy 與 migration version。

CI 禁止輸出 request／response fixture 中的真實稿件；fixture 使用人工合成內容。

## 15. Feature flags 與回滾

建議 build defines：

```text
COPILOT_ASK_ENABLED
COPILOT_PLAN_ENABLED
```

選項 A 首版使用 compile-time flag，緊急關閉需要重發版本。若日後另建遠端 capabilities／kill switch，它不得在未更新 App 的情況下擴大權限，只能關閉既有能力或縮小 provider/model allowlist，而且不得接收 prompt、response、作品內容或 API key。

回滾順序：

1. 關閉 Plan。
2. 關閉跨資源 Ask，只保留目前章節。
3. 關閉 Ask，保留 Chat。
4. 關閉全部 Copilot 入口。

回滾不得刪除使用者 key；但 UI 必須允許使用者手動清除 secure key。

可執行的 build variants、發布檢查、對外文字、rollout 與回滾步驟另見 `COPILOT_ASK_PLAN_RELEASE_RUNBOOK.md`。

## 16. 隱私與發布文字

發布前需要明確說明：

- 哪些模式會把作品內容傳給第三方。
- 目的 provider 與 API URL。
- App 是否保存對話與計畫。
- 官方是否能看到內容；Direct／BYOK 模式下應明確說明資料直接送往使用者選擇的 provider。
- 第三方 provider 的資料保留政策由其服務條款決定。
- 本機 Ollama 不代表所有自訂 URL 都是本機或私密。
- AI 回覆可能不正確，Plan 首版不會自動修改作品。

## 17. 預估工期與相依性

以下以一名熟悉現有 Flutter／Riverpod 架構的工程師估算，不含外部審核與商店等待時間：

| 階段 | 預估 | 相依 |
| --- | ---: | --- |
| P0 基線、安全與拆分 | 2～4 工作天 | 無 |
| P1 context／policy | 3～5 工作天 | P0 |
| P2 Ask MVP | 3～5 工作天 | P1 |
| P3 Plan 唯讀 MVP | 4～7 工作天 | P1；建議 P2 穩定後 |
| P4 跨平台與 release 驗收 | 3～6 工作天 | P2、P3 |
| P5 rollout | 依觀察期 1～2 週 | P4 |
| P6 受控匯入更新計畫 | 3～6 工作天 | P3、協作交易確認 |

採選項 A 時，Ask＋Plan 唯讀版約 15～27 個工程工作天。Gateway、帳號、官方額度、付款與 server-side 資料治理不計入本輪；若未來新增，需另立後端計畫。

## 18. 開工前決策

以下決策應在 P0 開工時固定，避免中途擴張：

- [x] 第一版只發布 Direct／BYOK（選項 A）；不建置 Copilot Gateway。
- [x] 首發採桌面優先；Windows 先驗證，其餘平台保持 gate。
- [x] Ask 預設 scope 採 `currentChapter`。
- [x] Plan 首版明確禁止套用。
- [x] 對話與 Plan 首版不持久化。
- [x] 允許自訂 HTTPS URL；HTTP 只允許 localhost／loopback 受控例外。
- [x] 首版只使用 build-time feature flag；未實作遠端 kill switch。
- [x] Plan schema v1 使用固定 target／action allowlist。

## 19. 最終完成定義

Ask／Plan 模式只有在以下條件全部成立時才算完成：

- Ask 能讀取使用者明確選定、受預算限制的專案 snapshot。
- Ask 回覆可顯示有效來源，無效引用不被當成真實來源。
- Plan 能產生並驗證版本化結構，不把自由文字當成操作。
- Plan 首版不會修改任何專案狀態。
- API key 不存在 SharedPreferences、log、crash report 或 artifact。
- 四類 provider 有 fixture 測試與清楚降級策略。
- timeout、取消、設定切換與 widget dispose 不發布 stale response。
- 大型 context 不造成無界記憶體或 request。
- 預定發布平台完成 release build 與平台權限驗證；真實 endpoint smoke test 是建議項，不是完成或啟用 gate。
- 作品內容與 API Key 在每個 endpoint host（包含 loopback）首次傳送前顯示 Dialog，且 host 變更時重新確認。
- feature flag／kill switch 與回滾流程已驗證。
- 隱私告知、已知限制與 release notes 已完成。

在上述條件未完成前，Ask／Plan 應保持「暫不可用」或只對 internal build 開放。
