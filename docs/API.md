# Monogatari Assistant 統一 API 文件

更新日期：2026-10-09

適用範圍：目前儲存庫已實作的整合與主要開發介面

[文件中心](README.md) · [說明文件](GUIDE.md) · [參考文件索引](SOURCES.md)

## 1. 介面與版本總覽

本專案以本機 Flutter App 為核心，以下介面各自使用獨立契約。

| 介面 | 傳輸／呼叫方式 | 版本 | 使用者 |
| --- | --- | --- | --- |
| MCP 唯讀工具與 resources | Host ↔ sidecar：stdio MCP | server `0.1.0`，payload `schemaVersion: "1"` | 外部 MCP Host |
| MCP App bridge | sidecar ↔ App：loopback HTTP | descriptor `version: 1`、`contractVersion: "0.1.0"` | App／sidecar 內部 |
| 專案檔案 API | Dart use case／repository／FileService | XML `1.18` | App 開發者 |
| Rhodanthe | Dart worker → C ABI → UTF-8 JSON | ABI `1`、contract `1` | 編輯器／原生整合 |
| Copilot provider adapter | App → 設定的 provider：HTTP JSON | 依 adapter 選定的 protocol | App 開發者 |
| P2P 快照與協作 | LAN TCP、配對與加密 frame | 各 frame 前綴獨立版本；協作 schema `6` | 相容的 App 裝置 |

UTF-8 byte budget 與 UTF-16 offset 是不同單位；`KiB = 1024 bytes`。MCP 的 `schemaVersion` 是字串，Rhodanthe 的 `contractVersion` 是整數。本文 JSON 中的 `session-example`、`chapter-example`、`fingerprint-example` 等是示意值；實際 ID、cursor 與 fingerprint 必須使用前一個回應提供的值。

## 2. MCP 唯讀 API

來源：[工具註冊與 schema](../dart_edition/lib/features/mcp/application/monoashi_mcp_server.dart)、[adapter](../dart_edition/lib/features/mcp/application/monoashi_mcp_adapter.dart)、[contract](../dart_edition/lib/features/mcp/domain/mcp_protocol_models.dart)、[讀取 budget](../dart_edition/lib/features/story_read/domain/project_read_models.dart)。

### 2.1 啟動與授權

先在 App 設定啟用 MCP，再使用 App 產生的 Host 設定。開發時可在 `dart_edition/` 執行：

```powershell
dart run bin/monoashi_mcp.dart --descriptor "C:\path\to\session.json"
```

`--descriptor` 未提供時使用環境變數 `MONOASHI_MCP_DESCRIPTOR`；兩者皆未提供時使用 disconnected gateway。可用 `dart run tool/build_mcp_sidecar.dart` 編譯隨附執行檔。

Host 設定格式如下，路徑請使用 App 複製的實際值：

```json
{
  "mcpServers": {
    "monoashi": {
      "command": "C:\\path\\to\\monoashi-mcp.exe",
      "args": ["--descriptor", "C:\\path\\to\\session.json"]
    }
  }
}
```

所有工具宣告 `readOnlyHint: true`、`destructiveHint: false`、`idempotentHint: true`、`openWorldHint: false`。工具輸入拒絕未知欄位；`plan` 內層由共用 validator 另外驗證。工具註冊不包含任何作品寫入或套用方法。

### 2.2 共用回傳格式

成功結果位於 MCP `CallToolResult.structuredContent`。所有成功的工具結果均帶下列 envelope，其餘欄位依工具而定：

```json
{
  "schemaVersion": "1",
  "sessionId": "session-example",
  "projectId": "project-example",
  "snapshotGeneration": 1
}
```

`projectId` 是 session／generation 範圍內的衍生 ID。`snapshotGeneration` 表示授權 generation，不能當成每次內容變更都遞增的 revision；同一 generation 仍可更新 snapshot。內容比對使用回應的 fingerprint。

完整 resource 物件的欄位：

| 欄位 | 型別 | 說明 |
| --- | --- | --- |
| `schemaVersion` | string | 固定 `"1"` |
| `type` | string | `project`、`chapter` 或支援的 entity 類型 |
| `id` | string | 資源 ID；project summary 使用外部 scoped project ID |
| `title` | string | 顯示標題 |
| `truncated` | boolean | 內容是否因 byte budget 截斷 |
| `fingerprint` | string | 此 resource 的內容識別；不要自行重算後代替回傳值 |
| `sourceUri` | string | 目前授權 session 的 resource URI |
| `content` | string | 受限的文字內容 |

章節清單回傳 metadata：上述欄位省略 `content`，另有 `order: integer`。entity 搜尋 metadata 省略 `content`，另有 `description: string`。

### 2.3 工具參照

以下「必填」欄位之外均可省略。一般 ID 長度為 1–256，且不能是純空白字串。entity 類型僅接受 `character`、`worldSetting`、`outlineEvent`、`glossaryTerm`。

| 工具 | 用途 | 結果額外欄位 |
| --- | --- | --- |
| `get_project_summary` | 受限摘要與 snapshot 物件數量，不含其他章節正文 | `resource`、`counts`、`omitted` |
| `list_chapters` | 分頁章節 metadata | `items`、`total`、`nextCursor`、`omitted` |
| `get_chapter` | 明確指定的一章正文 | `resource` |
| `search_project_entities` | entity metadata 搜尋 | `items`、`total`、`nextCursor`、`omitted` |
| `get_project_entity` | 明確指定的一筆 entity 內容 | `resource` |
| `get_context_bundle` | 一章加上明確選取的摘要／補充資源 | `primary`、`supplemental`、`fingerprint`、`omitted` |
| `validate_readonly_plan` | 依先前取得的 context 驗證唯讀提案 | `valid`、`stale`、`errors`、`resolvedTargets`、`plan` |

#### get_project_summary

輸入為 `{}`。`counts` 以 `chapter` 及四種 entity 類型為 key，計算授權 snapshot 中的數量。`omitted` 每筆包含 `type`、`sourceKey`、`reason`；可能反映缺少 stable ID 等資料省略原因。摘要內容最多 24 KiB。

#### list_chapters

| 參數 | 型別 | 必填 | 預設與限制 |
| --- | --- | --- | --- |
| `cursor` | string | 否 | 首頁省略；使用上一頁 `nextCursor`，最長 2048 |
| `limit` | integer | 否 | `50`；範圍 1–100 |

`nextCursor: null` 表示最後一頁。cursor 是不透明且經驗證的值，綁定 session、generation 與清單類型；不能自行修改或在新 session 重用。

#### get_chapter

| 參數 | 型別 | 必填 | 預設與限制 |
| --- | --- | --- | --- |
| `chapterId` | string | 是 | 從章節清單取得 |
| `maxBytes` | integer | 否 | `73728`；範圍 1–73728，UTF-8 bytes |

超過指定 byte budget 時回傳截斷 resource 並標記 `truncated`；不存在的章節回傳 `notFound`。

#### search_project_entities

| 參數 | 型別 | 必填 | 預設與限制 |
| --- | --- | --- | --- |
| `query` | string | 否 | 空字串；最長 512 |
| `types` | string[] | 否 | 空集合代表四種 entity；最多 4 個且不可重複 |
| `cursor` | string | 否 | 首頁省略；最長 2048 |
| `limit` | integer | 否 | `50`；範圍 1–100 |

依 title、description 與 resource ID 做 trim 後、不分大小寫的包含搜尋，回傳 metadata。cursor 額外綁定 query 與類型集合；改搜尋條件後重新從首頁讀取。

#### get_project_entity

| 參數 | 型別 | 必填 | 預設與限制 |
| --- | --- | --- | --- |
| `type` | string | 是 | 四種 entity 類型之一 |
| `id` | string | 是 | 從 entity 搜尋取得 |
| `maxBytes` | integer | 否 | `8192`；範圍 1–8192 |

#### get_context_bundle

| 參數 | 型別 | 必填 | 預設與限制 |
| --- | --- | --- | --- |
| `chapterId` | string | 是 | 一章正文作為 primary |
| `includeProjectOverview` | boolean | 否 | `false` |
| `resourceRefs` | object[] | 否 | `[]`；最多 12 筆，每筆只有必填 `type`、`id`，不可重複 |

primary 最多 72 KiB；選取的 entity 每筆最多 8 KiB、合計最多 32 KiB；若包含摘要，摘要另有 24 KiB 上限。`includeProjectOverview: true` 與非空 `resourceRefs` 互斥，同時指定會失敗。缺少引用目標時請求失敗；選取資源按 snapshot 順序填入總預算，可能無法包含全部選取項目。回傳的頂層 `fingerprint` 是 context fingerprint；每個 resource 自己亦有 fingerprint，兩者用途不同。

adapter 在 sidecar 記憶體中保存最多 8 個 validation context，綁定 session、generation 及完整 snapshot fingerprint。App 資料變更、換 session、sidecar 重啟或較舊 context 被移出後，必須重新取得 bundle。

#### validate_readonly_plan

| 參數 | 型別 | 必填 | 說明 |
| --- | --- | --- | --- |
| `plan` | object | 是 | 下節的 schema v1 JSON object |
| `contextFingerprint` | string | 是 | 先前 bundle 的頂層 fingerprint；1–256 |

輸入錯誤與計畫驗證失敗不同：缺少合法外層參數屬 `invalidArgument`；計畫無效回傳正常 envelope，搭配 `valid: false` 與結構化 `errors`。合法計畫回傳 canonical JSON，仍不修改作品。

### 2.4 唯讀 Plan schema

來源：[ReadonlyPlanValidator](../dart_edition/lib/features/story_read/domain/readonly_plan_validation.dart)。

| 頂層欄位 | 型別 | 限制 |
| --- | --- | --- |
| `schemaVersion` | string | 必填，`"1"` |
| `goal` | string | 必填，非空，最長 500 |
| `summary` | string | 必填，非空，最長 4000 |
| `contextFingerprint` | string | 必填，非空，最長 256，須和 validation context 相符 |
| `steps` | object[] | 必填，1–50 筆 |
| `risks`、`questions` | string[] | 必填，各最多 20 筆；每個字串非空、最長 4000 |

| Step 欄位 | 型別 | 限制 |
| --- | --- | --- |
| `id` | string | 必填，非空、最長 100，steps 中不可重複 |
| `order` | integer | 必填，1–1000，steps 中不可重複 |
| `targetType` | string | 必填，使用下列 allowlist |
| `targetId` | string 或 null | 可省略／null；若提供為非空字串，最長 200 |
| `action` | string | 必填，使用下列 allowlist |
| `reason` | string | 必填，非空、最長 4000 |
| `proposal` | string | 必填，非空、最長 12000 |
| `dependsOn` | string[] | 必填，最多 50 筆，每筆非空、最長 4000，引用同一計畫中已存在的 step ID |

- targetType：`chapter`、`character`、`location`、`worldSetting`、`outlineEvent`、`glossaryTerm`、`foreshadow`、`updatePlan`、`project`。
- action：`review`、`revise`、`add`、`create`、`removeSuggestion`、`reorderSuggestion`、`clarify`、`research`。
- 除 `create` 外，target 必須存在於本次 context。validator allowlist 較 MCP v1 可讀類型廣，並不代表 MCP 可以讀取所有列出的類型。
- 所有 object 拒絕未知欄位；raw JSON 最多 128 KiB。dependency 不得引用未知 ID 或形成循環；canonical steps 按 `order` 排序。

示意輸入，呼叫前用實際 bundle 替換兩個 fingerprint 與 chapter ID：

```json
{
  "plan": {
    "schemaVersion": "1",
    "goal": "檢查第一章的角色動機",
    "summary": "提出一項正文審閱建議",
    "contextFingerprint": "fingerprint-example",
    "steps": [
      {
        "id": "step-1",
        "order": 1,
        "targetType": "chapter",
        "targetId": "chapter-example",
        "action": "review",
        "reason": "角色的決定需要更明確的前因",
        "proposal": "檢視出發前的對話並補充可供評估的動機建議",
        "dependsOn": []
      }
    ],
    "risks": [],
    "questions": []
  },
  "contextFingerprint": "fingerprint-example"
}
```

回傳 `errors` 每筆包含 `code`、`path`、`message`。code 包含 `malformedJson`、`resultTooLarge`、`invalidSchema`、`staleContext`、`invalidField`、`unsupportedTargetType`、`unsupportedAction`、`targetNotInContext`、`duplicateStep`、`unknownDependency`、`cyclicDependency`。目前 validator 以第一個失敗原因回傳，不保證一次列出所有錯誤。

### 2.5 Resources

resource template 為 `monoashi://session/{sessionId}/{type}/{id}`，MIME 為 `application/json`，cache scope 為 `private`。

| 類型 | URI 的 id |
| --- | --- |
| `project` | 固定 `summary` |
| `chapter` | 章節 ID |
| 四種 entity | entity ID |

優先使用工具或 resource list 提供的 `sourceUri`，讓 URI encoder 處理特殊字元。讀取回傳的 `TextResourceContents.text` 是 JSON envelope，內含 `resource`，不是單純正文。URI 綁定授權 session；舊 URI 不可用於新 session。沒有授權時 resource list 回傳空清單；讀取已失效的 resource 會出錯。

### 2.6 錯誤與呼叫順序

工具錯誤回傳 `isError: true`，文字內容含 `code: message`，structured content 為：

```json
{
  "schemaVersion": "1",
  "error": {"code": "unavailable", "message": "目前沒有可用的授權 session。"}
}
```

| Code | 處理方式 |
| --- | --- |
| `unavailable` | 檢查 App、授權與 sidecar；重新啟用並取得 Host 設定 |
| `invalidArgument` | 修正型別、必填參數、allowlist、未知欄位或範圍 |
| `invalidCursor` | 捨棄 cursor，依目前搜尋條件重新取得首頁 |
| `notFound` | 重新列出章節／entity 或取得目前 session URI |
| `cancelled` | 取消後停止使用該結果，需要時重送 |
| `resultTooLarge` | 結果超過 256 KiB；縮小頁數或選取範圍 |
| `internal` | 查閱本機診斷後重試；錯誤訊息不包含原始內部例外 |

Resource error 使用 MCP protocol error，而非上述 tool 的 `isError` envelope。一般整合順序：`get_project_summary` → `list_chapters` → `search_project_entities` → `get_context_bundle` → `validate_readonly_plan`。用 `get_chapter`／`get_project_entity` 可單獨讀取內容。

### 2.7 App ↔ sidecar 內部 HTTP bridge

來源：[bridge server](../dart_edition/lib/features/mcp/application/mcp_bridge_server.dart)、[gateway](../dart_edition/lib/features/mcp/data/mcp_bridge_gateway.dart)、[snapshot codec](../dart_edition/lib/features/mcp/data/mcp_snapshot_codec.dart)。Host 使用 stdio sidecar；以下為內部 IPC 契約。

listener 綁定 `127.0.0.1` 的動態 port。要求正確的 `Host: 127.0.0.1:<port>`，拒絕帶 `Origin` 的請求。descriptor 具有 `version`、`contractVersion`、`endpoint`、`sessionId`、`generation`、`expiresAt` 與一次性 `bootstrapToken`。

| Endpoint | Header | 成功 JSON |
| --- | --- | --- |
| `POST /v1/handshake` | `Authorization: Bearer <bootstrapToken>` | `sessionId`、`generation`、`accessToken` |
| `GET /v1/session` | `Authorization: Bearer <accessToken>`、`x-monoashi-session`、`x-monoashi-generation` | `sessionId`、`projectId`、`generation`、codec 編碼的 `snapshot` |

handshake 消耗 bootstrap token 並刪除 descriptor；同一 descriptor 不可重複授權。預設 session 壽命 8 小時，最多 4 個 concurrent request；handshake body 上限 16 KiB，snapshot response 上限 32 MiB。gateway 的 descriptor 上限 16 KiB，HTTP 各階段有 5 秒 timeout 且不跟隨 redirect。

HTTP 狀態含 `200`、`400`、`401`、`403`、`404`、`410`、`429`、`500`；snapshot 超過上限亦可能回傳 `413`。token、完整 descriptor 與 snapshot 只供內部使用，不放入 Host 設定或文件範例的真實值。

## 3. 專案與檔案 API

來源：[ProjectFileUseCase](../dart_edition/lib/domain/usecases/project_file_usecase.dart)、[FileRepository](../dart_edition/lib/domain/repositories/file_repository.dart)、[FileService／ProjectManager](../dart_edition/lib/bin/file.dart)、[資料型別](../dart_edition/lib/models/project_file.dart)。

App 流程透過注入 `FileRepository` 的 `ProjectFileUseCase` 使用檔案服務。`ProjectManager` 整合編輯器同步、確認對話框、provider 及 UI；`FileService` 負責較低層的實際讀寫。舊文件的 `lib/file.dart` 已由目前的 `lib/bin/file.dart` 取代。

### 3.1 ProjectFileUseCase

下表皆為 instance 方法。

| 方法與參數 | 回傳 | 行為 |
| --- | --- | --- |
| `createNewProject()` | `Future<ProjectFile>` | 建立尚未有位置的檔案描述 |
| `openProject()` | `Future<ProjectFile?>` | 選檔；取消回傳 null |
| `openProjectFromPath(String filePath, {String? accessToken})` | `Future<ProjectFile>` | 從路徑與可選持久授權開啟 |
| `openProjectFromExternalUri(String uri)` | `Future<ProjectFile>` | 由平台外部 URI 開啟 |
| `saveProject(ProjectFile projectFile)` | `Future<ProjectFile>` | 寫回現有位置；需要時另存 |
| `saveProjectToKnownLocation(ProjectFile projectFile)` | `Future<ProjectFile>` | 只寫已知位置，不開啟另存對話框 |
| `saveProjectAs(ProjectFile projectFile)` | `Future<ProjectFile>` | 選新位置並寫入；取消會拋出 FileException |
| `generateProjectXml(ProjectData data, {bool updateLatestSave = true})` | `Future<String>` | 生成 XML；可保留原 LatestSave |
| `loadProjectFromXml(ProjectFile projectFile)` | `Future<ProjectData>` | 讀取、解析並遷移資料 |
| `loadProjectParseResultFromXml(ProjectFile projectFile)` | `Future<ProjectParseResult>` | 同上並保留 metadata／遷移資訊 |
| `exportText({required String content, required String fileName, required String extension})` | `Future<void>` | 輸出指定文字格式 |

### 3.2 備份 API

同名方法由 use case 提供，底層使用 `FileService`。

| 方法 | 回傳與限制 |
| --- | --- |
| `saveProjectAutoBackup({required String projectName, required String content, required int maxTotalBytes})` | `Future<String>`；回傳備份位置，不改目前路徑或 dirty 狀態；單檔不得超過容量限制 |
| `getAutoBackupDirectoryPath()` | `Future<String>` |
| `getAutoBackupDirectoryInfo()` | `Future<AutoBackupDirectoryInfo>`；含 path、isConfigured、isDefault、canReset、isAndroid、totalBytes、fileCount |
| `selectAutoBackupDirectory()`／`resetAutoBackupDirectory()` | `Future<String>`；選擇／還原目錄 |
| `openAutoBackupDirectory()` | `Future<String>`；開啟目錄並回傳位置 |
| `clearAutoBackups()` | `Future<AutoBackupCleanupResult>`；刪除備份，回傳 deletedFiles、freedBytes |

可用空間不足、平台授權失效或寫入失敗時拋出 `FileException`；操作前由 App UI 顯示對應訊息。

### 3.3 底層型別與 FileService

`ProjectFile` 包含可變的 `fileName`、`filePath`、`uri` 與一次性 `content`。`isNewFile` 在 path 與 URI 皆為 null 時成立；`takeContent()` 取出後清除 payload。解析與儲存亦會清除 content，因此已開啟作品的權威資料是 `ProjectData`，不要用已儲存的 `ProjectFile.content` 當作品快取。

`FileService.generateProjectXML(ProjectData)` 與 `parseProjectXML(String)` 是同步的 codec 包裝；`generateProjectXMLWithoutLatestSaveUpdate` 保留 LatestSave，`parseProjectXMLWithMetadata` 回傳解析資訊。UI 流程優先使用上層 use case，以免把大型 XML 工作放到輸入路徑。

其他 static 方法：

| 方法 | 回傳／用途 |
| --- | --- |
| `exportTextWithResult({required String content, required String fileName, required String extension})` | `Future<bool>`；使用者取消回傳 false，適用需知道匯出結果的流程 |
| `readLocalFile(String fileName)` | `Future<String>`；讀取 App documents 目錄下的檔案 |
| `writeLocalFile(String fileName, String content)` | `Future<void>` |
| `getAppDocumentsPath()` | `Future<String>` |
| `fileExists(String filePath)` | `Future<bool>` |
| `deleteFile(String filePath)` | `Future<void>`；實際刪除指定檔案 |
| `getFileInfo(String filePath)` | `Future<FileInfo>`；name、path、size、modified、created |

錯誤型別 `FileException` 帶 `message`。Android 保存 SAF URI；Apple 使用平台持久授權。自動儲存到無有效位置時出錯；不要直接拿舊文件中的儲存權限宣告代替平台橋接。

可直接用於已注入 use case 的載入範例：

```dart
import 'package:monogatari_assistant/domain/usecases/project_file_usecase.dart';
import 'package:monogatari_assistant/models/project_data.dart';

Future<ProjectData?> openStory(ProjectFileUseCase files) async {
  final file = await files.openProject();
  if (file == null) return null;
  return files.loadProjectFromXml(file);
}
```

儲存前先把目前 editor draft 同步到 `ProjectData`，以 `generateProjectXml` 產生內容，填入待儲存 `ProjectFile.content` 後呼叫儲存方法。完整 UI 生命週期由 `ProjectManager`／既有 coordinator 負責。

### 3.4 XML 格式契約

現行格式由 `ProjectMigrator.currentVersion` 定義為 `1.18`。根為 `Project`，`UUID` 為專案 ID，`ver` 為格式版本；每個模組位於 `Type`，以直屬 `Name` 辨識。

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Project UUID="12345678-1234-4234-8234-123456789abc">
  <ver>1.18</ver>
  <Type>
    <Name>BaseInfo</Name>
    <General>
      <BookName>範例作品</BookName>
      <Author>作者</Author>
    </General>
  </Type>
</Project>
```

此為結構示意，其他缺少的模組由讀取預設補上。不要沿用舊文件中 `<Type>BaseInfo</Type>` 加上平行 `<BaseInfo>` 的範例。詳細章節、角色、時間軸、物品與地點 schema 見 [MNPROJ_FILE_STRUCTURE](../dart_edition/MNPROJ_FILE_STRUCTURE.md)；短語另由 [phrase codec](../dart_edition/lib/features/phrases/phrase_library_codec.dart) 管理 payload。

## 4. Rhodanthe 原生 API

來源：[Dart protocol](../dart_edition/lib/infrastructure/rhodanthe/rhodanthe_protocol.dart)、[worker](../dart_edition/lib/infrastructure/rhodanthe/rhodanthe_worker_executor.dart)、[C header](../dart_edition/rust/rhodanthe-bridge/include/rhodanthe_bridge.h)、[bridge 說明](../dart_edition/rust/rhodanthe-bridge/README.md)。

### 4.1 呼叫與記憶體生命週期

| C ABI | 契約 |
| --- | --- |
| `uint32_t rhodanthe_abi_version(void)` | 先確認 ABI `1` |
| `RhodantheHandle *rhodanthe_engine_new(void)` | 建立 opaque engine；配置失敗回傳 NULL |
| `RhodantheBuffer rhodanthe_engine_request(const RhodantheHandle *, const uint8_t *, size_t)` | 借用輸入 bytes；回傳非 NUL 結尾的 UTF-8 buffer |
| `void rhodanthe_buffer_free(RhodantheBuffer)` | 複製／解碼後釋放每個回傳 buffer，恰好一次 |
| `void rhodanthe_engine_free(RhodantheHandle *)` | 關閉文件後釋放 engine，恰好一次；NULL 可接受 |

`RhodantheBuffer` 為 `data`、`len`、`capacity`。同一 engine 的請求會序列化；request 進行中不得同時 free engine。raw pointer 的有效性由呼叫端維護。

Dart 端使用 `RhodantheWorkerExecutor.start({String? libraryPath, Duration startupTimeout = 5 秒})`、`execute(RhodantheRequest)` 與 `dispose({Duration timeout = 2 秒})`。`RhodantheNativeClient.sendSync` 不應放在 Flutter UI isolate。timeout／invalidate 會停止等待並拒絕 stale 發布，但不會中斷 worker 中已開始的同步 native call。

### 4.2 JSON envelope 與命令

```json
{
  "contractVersion": 1,
  "requestId": 42,
  "command": "openDocument",
  "arguments": {"documentId": "chapter-1", "revision": 1, "fullText": "本文"}
}
```

`contractVersion` 必填；`requestId` 可選，Dart DTO 使用整數。request 最多 8 MiB。命令參數如下：

| command | arguments | 結果／行為 |
| --- | --- | --- |
| `handshake` | 省略 | 回傳 kind、abiVersion、contractVersion、capabilities |
| `openDocument` | documentId、revision、fullText | 建立文件，不允許重複開啟同 ID |
| `applyEdits` | documentId、baseRevision、revision、edits | 原子套用 edit batch；驗證 revision、排序、重疊與 surrogate 邊界 |
| `analyze` | documentId、revision；可選 compactResponse、search、filler、externalAnnotations | 一次分析並回傳版本化 render plan |
| `closeDocument` | documentId | 移除 engine 內文件 |

成功 response 形狀為 `{"ok":true,"contractVersion":1,"requestId":42,"result":{}}`；失敗形狀為：

```json
{
  "ok": false,
  "contractVersion": 1,
  "requestId": 42,
  "error": {"code": "revisionMismatch", "message": "..."}
}
```

所有 editor offset 都是 UTF-16 code units，edit 為半開區間 `[startUtf16, endUtf16)`，另有 `replacement` 字串；不得切開 surrogate pair。

### 4.3 analyze 參數

| 參數 | 型別 | 說明 |
| --- | --- | --- |
| `documentId`、`revision` | string、integer | 必須對應目前已開啟文件 |
| `compactResponse` | boolean | Dart DTO 預設 true；compact 能力須經 handshake 確認 |
| `search` | object | query、queryRevision、options；可選 maxResults、activeMatchIndex、maxInputCodeUnits、maxRegexpCodeUnits |
| `filler` | object | dictionaryRevision、words；可選 budget |
| `externalAnnotations` | object[] | 外部標註，由現有 DTO／validator 管理 |

`search.options` 有 `matchCase: true`、`wholeWord: false`、`useRegexp: false`、`matchWidth: true`、`ignorePunctuation: false`、`ignoreWhitespace: false` 的 Dart 預設值。預設可見搜尋結果上限 2048；regexp query 最多 512 UTF-16 code units、input 最多 2 Mi code units。Rust regexp 不支援 look-around 與 backreference。

`filler.budget` 可含 `maxWords`、`maxPositionsPerWord`、`maxPositionsTotal`、`maxAnnotations`、`maxCandidates`。不要假定搜尋與贅字分析共用同一預算。

compact response 使用平坦整數陣列表示可見 search range／render run；消費端使用 `RhodantheAnalysisResult` 與既有 span adapter 解碼，不自行把 legacy object schema 套到 compact array。render plan 發布前驗證 contract、document revision、UTF-16 長度、run 順序、style token 與 surrogate 邊界；失敗回傳 plain fallback。

### 4.4 錯誤與平台限制

native error 包含 `invalidRequest`、`incompatibleContract`、`documentNotOpen`、`documentAlreadyOpen`、`revisionMismatch`、`invalidRevision`、`invalidRange`、`budgetExceeded`、`regexRejected`、`invalidAnnotation`、`invalidHandle`、`internal`。

Web 使用 stub 與 Dart fallback。預設 `RHODANTHE_RELEASE_STAGE=default-on`；`RHODANTHE_KILL_SWITCH=true` 停用原生路徑。完整 rollout、circuit breaker 與平台 library 封裝參見 [Dart infrastructure](../dart_edition/lib/infrastructure/rhodanthe/README.md)、[PACKAGING](../dart_edition/rust/PACKAGING.md)、[核心規格](../dart_edition/RHODANTHE_SPEC.md)。

## 5. Copilot provider 與共用讀取 API

來源：[provider adapter](../dart_edition/lib/features/copilot/data/copilot_provider_adapter.dart)、[HTTP transport](../dart_edition/lib/features/copilot/data/copilot_http_transport.dart)、[ProjectReadService](../dart_edition/lib/features/story_read/application/project_read_service.dart)。以下描述本 App 的 adapter 行為；provider 自身的完整服務契約需依其文件維護。

### 5.1 Provider mapping

`CopilotProviderAdapter.modelsRequest`／`chatRequest` 產生 `CopilotProviderRequest`，包含 method、path、query、headers、body。path 由 App 與設定的 base URL 組合。

| protocol | 列出模型 | 對話 | 認證 |
| --- | --- | --- | --- |
| openAiCompatible | GET `/models` | POST `/chat/completions` | 非空 Key 放 `Authorization: Bearer` |
| gemini | GET `/v1beta/models` | POST `/v1beta/models/{model}:generateContent` | 非空 Key 放 query `key` |
| anthropic | GET `/models` | POST `/messages` | `x-api-key` 與 `anthropic-version: 2023-06-01` |
| ollama 原生 | GET `/api/tags` | POST `/api/chat` | JSON Content-Type；原生 body 設 `stream: false` |
| ollama OpenAI 路徑 | GET `/models` | POST `/chat/completions` | adapter 的 Ollama headers 不附 Bearer |

chatRequest 參數包含 protocol、apiKey、model、systemInstruction、messages、ollamaUsesOpenAiApi、maxOutputTokens。OpenAI 路徑使用 model／messages／temperature／max_tokens；Gemini 使用 systemInstruction／contents／generationConfig；Anthropic 使用 model／system／messages／max_tokens；Ollama 原生使用 model／messages／stream／options。

`extractModelIds` 與 `extractAssistantReply` 統一解碼各 provider 形狀。HTTP 使用 `CopilotHttpTransport.sendJson(String method, Uri uri, {headers, jsonBody, timeout, maxResponseBytes})`，不跟隨 redirect，依 constructor 的 maxRequestBytes 與每次 maxResponseBytes 限制內容。`cancel()` 關閉目前 client 並換新；`dispose()` 後不可再送請求。

### 5.2 共用作品讀取

`ProjectReadService` 是純 snapshot 讀取層，供 Copilot／MCP 共用。

| 方法 | 結果 |
| --- | --- |
| `listChapters(snapshot, {offset = 0, limit = 50})` | `ProjectReadPage<ProjectReadChapterSummary>` |
| `getChapter(snapshot, {required chapterId, maxBytes = 73728})` | `ProjectReadResource?` |
| `searchEntities(snapshot, {required query, resourceTypes = {}, offset = 0, limit = 50})` | `ProjectReadPage<ProjectReadEntitySummary>` |
| `getEntity(snapshot, {required ref, maxBytes = 8192})` | `ProjectReadResource?` |
| `buildContextBundle(snapshot, {required chapterId, includeProjectOverview = false, resourceRefs = [], rejectMissing = false})` | `ProjectReadContextBundle`；primary、supplementalResources、fingerprint |

此層使用 offset，而 MCP 使用 opaque cursor；資料不存在時的 nullable 結果由 adapter 映射為 MCP error。精確 signature 與 budget 以連結的原始碼為準。

## 6. P2P 與即時協作 API

來源：[P2pEndpointService](../dart_edition/lib/data/p2p/p2p_endpoint_service.dart)、[安全通道](../dart_edition/lib/data/p2p/p2p_secure_channel.dart)、[snapshot DTO](../dart_edition/lib/domain/models/p2p_snapshot_models.dart)、[協作 schema](../dart_edition/lib/domain/collaboration/collaboration_operation.dart)、[協作 protocol](../dart_edition/lib/domain/collaboration/collaboration_protocol.dart)。

### 6.1 生命週期與認證

`P2pEndpointService` 是 Dart 抽象類別，`IoP2pEndpointService` 提供 TCP 實作。先準備 local project offer／pairing 狀態，啟動 listener，再進行端點探測與配對。作品 revision、snapshot 與協作交換前必須 `installAuthenticatedSession(P2pSecureSessionKeys?)`；null 撤銷目前安全 session。

| 方法 | 回傳／規則 |
| --- | --- |
| `listPrivateIpv4Addresses()` | `Future<List<String>>` |
| `start({required int port})` | `Future<P2pListeningEndpoint>`；port 1–65535，回傳監聽 port |
| `stop()` | `Future<void>`；停止 listener 並清理本次 session 狀態 |
| `dispose()` | `Future<void>`；結束服務與 streams |
| `configureSnapshotContentTransfer({required bool enabled, P2pSnapshotChunkLoader? loader})` | 啟用／停用內容傳輸與 chunk loader |
| `updateLocalProjectOffer`、`updateLocalPairingChallenge`、`updateLocalPairingConfirmation` | 更新探測／配對資料 |
| `updateLocalRevisionSummary`、`updateLocalRevisionGraph`、`updateLocalCollaborationBatch` | 安裝本機交換資料 |
| `updateLocalResolutionAck`、`updateLocalSnapshotManifests`、`updateLocalSnapshotSyncRequest` | 安裝衝突解決確認與快照同步資料 |
| `requestDisconnectOnNextExchange()` | 標記下一次交換時告知對方斷線 |

輸入各 DTO 由其 constructor／fromJson 驗證；不要跳過現有配對 controller 自行安裝未知金鑰。

### 6.2 交換方法

所有方法首個 positional 參數為 `P2pEndpoint endpoint`；下表列出其餘參數與預設 timeout。

| 方法 | 其餘參數 | 回傳 | timeout |
| --- | --- | --- | --- |
| `probe` | 無 | `Future<void>` | 8 秒 |
| `negotiateProjectOffer` | `P2pProjectOffer localOffer` | `Future<P2pProjectOffer>` | 8 秒 |
| `notifyDisconnect` | 無 | `Future<void>` | 3 秒 |
| `negotiatePairingChallenge` | `P2pPairingChallenge localChallenge` | `Future<P2pPairingChallenge?>` | 3 秒 |
| `negotiatePairingConfirmation` | `P2pPairingConfirmation? localConfirmation` | `Future<P2pPairingConfirmation?>` | 3 秒 |
| `negotiateRevisionSummary` | `P2pRevisionSummary localSummary` | `Future<P2pRevisionSummaryExchange>` | 5 秒 |
| `negotiateRevisionGraphPage` | 必填 named localPageIndex、remotePageIndex | `Future<P2pRevisionGraphPageExchange>` | 8 秒 |
| `negotiateCollaborationBatch` | `CollaborationSyncBatch localBatch` | `Future<CollaborationSyncBatch>` | 3 秒 |
| `openCollaborationStream` | 無 | `Future<bool>` | 5 秒 |
| `negotiateSnapshotManifest` | 必填 named projectUuid、revisionId | `Future<P2pSnapshotManifest?>` | 5 秒 |
| `negotiateSnapshotChunk` | `P2pSnapshotChunkRequest request` | `Future<P2pSnapshotChunk?>` | 12 秒 |
| `negotiateSnapshotChunks` | `List<P2pSnapshotChunkRequest> requests`，1–32 筆 | `Future<List<P2pSnapshotChunk?>>` | 12 秒 |

timeout 為可選 named `Duration`。事件由 `inboundProbes`、`inboundProjectOffers`、`inboundPairingChallenges`、`inboundPairingConfirmations`、`inboundRevisionSummaries`、`inboundRevisionGraphs`、`inboundCollaborationBatches` streams 提供；`hasActiveCollaborationStream` 回報長連線狀態。

`probe` 可拋出 `P2pProbeException`，區分 connection／response 等失敗階段；協定欄位、對應 request、project UUID、session 或 frame 驗證不符時會拋出 `FormatException`。stream 斷線、timeout 或認證錯誤會關閉連線；上層依既有重連流程恢復。

### 6.3 TCP frame 與快照限制

訊息以 newline 結尾的有界 frame 交換；以下前綴後的空格表示接續 payload：

| 前綴 | 用途 |
| --- | --- |
| `MONOGATARI_P2P_PROBE/1` | 端點探測 |
| `MONOGATARI_P2P_REACHABLE/1` | 探測回應 |
| `MONOGATARI_P2P_OFFER/2 ` | project offer |
| `MONOGATARI_P2P_PAIR/7 ` | pairing challenge |
| `MONOGATARI_P2P_PAIR_CONFIRM/7 ` | pairing confirmation |
| `MONOGATARI_P2P_SECURE/1 ` | 配對後的認證加密 frame |

探測訊息最多 128 bytes，offer 最多 2048 bytes；加密 frame 上限由 `P2pEncryptedFrame.maxEncodedLength` 定義。未認證訊息只提供有界探測／配對資訊，正文透過安全 session 傳輸。

`P2pSnapshotManifest` 包含 projectUuid、revisionId、contentSha256、contentLength、chunkSize、chunkCount、formatVersion。最大 snapshot 為 64 MiB，預設 chunk 24 KiB，manifest encoded length 上限 2048。`revisionId` 與 `contentSha256` 驗證為 SHA-256 字串；接收端另驗證實際內容的完整雜湊及 XML 相容性。

`P2pSnapshotSyncRequest` 包含 requestId、projectUuid、revisionId、contentSha256；requestId 為 16–64 個英數／底線／連字號，encoded length 上限 512。只有與宣告 manifest 相符的要求才能提供內容。

### 6.4 即時協作與交易

`CollaborationSchema.currentVersion = 6`。單一 batch 最多 128 operations；單次插入最多 24 KiB，建議文字 chunk 4 KiB；單一刪除 operation 最多 1,000,000 atoms。協作 record／text 操作、vector、presence 與交易欄位由既有 codec 驗證；XML 僅作 checkpoint／持久化，不放入每個即時 operation。

`OperationId` 包含 replicaId 與正整數 sequence。游標 target 可為 chapterText、projectText、projectField；文字游標採 atom anchor 與 fallback offset，不能以畫面投影 offset 直接替換 raw 位置。多筆 record 的同一交易在收齊後一次套用。

同步設計脈絡見 [P2P 設計](../dart_edition/P2P_LAN_SYNC_DESIGN.md) 與 [即時協作設計](../dart_edition/REALTIME_COLLABORATION_DESIGN.md)。歷史設計的欄位或版本若與上述程式不同，以現行 codec 為準。

## 7. API 變更與驗證

新增介面時同步更新版本、輸入 schema、DTO／codec、allowlist、budget、失敗路徑與本文件。調整專案格式時同步處理 XML、遷移、歷史、匯入匯出、snapshot 與協作；只改 serializer 不足以維持一致性。

MCP 發布流程包含 focused tests、sidecar build、manifest 與 Host／平台 gate。Rhodanthe 包含 Rust tests、Dart protocol／worker／render tests 與 profile benchmark。P2P／檔案變更需依影響範圍驗證讀寫往返、失效授權、錯誤版本及中斷恢復。實際命令與發布手冊見 [說明文件](GUIDE.md#10-驗證建置與發布)。
