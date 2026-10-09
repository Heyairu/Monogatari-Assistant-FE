# Monogatari Assistant 文件中心

更新日期：2026-10-09

適用範圍：本儲存庫的 Flutter 應用程式與隨附整合介面

| 文件 | 讀者 | 內容 |
| --- | --- | --- |
| [統一說明文件](GUIDE.md) | 使用者、開發者 | 功能、操作、專案資料、環境設定、架構、建置與維護 |
| [統一 API 文件](API.md) | 開發者、整合者 | MCP、檔案 API、Rhodanthe、Copilot adapter、P2P 與協作契約 |
| [參考文件索引](SOURCES.md) | 維護者 | 保留的專題規格、使用指南、設計與發布驗收文件 |
| [專案首頁](../README.md) | 所有讀者 | 專案介紹、畫面預覽與快速啟動 |

## 文件使用原則

說明文件與 API 文件是日常查閱入口；細部規格由仍保留的專題文件承接。已被統一文件取代的舊指南、重複報告與完成階段紀錄已移除，歷史內容可由 Git 查閱。`MNPROJ_FILE_STRUCTURE.md` 同時是 App 的內建 asset，維持原路徑。

主文件以目前程式碼為依據。文件中的「已實作」表示可以在原始碼找到對應行為，不代表所有平台都已通過發布驗收。保留的發布紀錄中，測試數量、效能數值與 artifact hash 只適用於記錄當時的版本。

## 統一撰寫規範

- 使用繁體中文說明；程式識別字、協定欄位、檔案名稱維持原文。
- 一份文件使用一個一級標題，依序安排範圍、操作或介面、限制、驗證與來源。
- API 按介面列出用途、參數與預設值、回傳值、錯誤、版本及可執行或明確標示的示意範例。
- 區分對外 MCP、App 內部 HTTP bridge、Dart 呼叫介面與原生 C ABI；不要把它們混寫成 REST endpoint。
- 相對連結從文件所在目錄出發；程式來源連到實際檔案，避免只寫路徑而無法導覽。
- 新功能先更新說明文件與 API 文件；必要的設計與驗收資料另存專題文件，並更新參考文件索引。完成實作後合併重複內容，避免累積同主題的階段報告。
- 版本、限制和預設值以程式常數與 `pubspec.yaml` 為準；發布狀態以對應平台的最新驗收證據為準。

## 內容核對入口

| 項目 | 來源 |
| --- | --- |
| App 版本與 Dart SDK | [pubspec.yaml](../dart_edition/pubspec.yaml) |
| 專案 XML 版本 | [ProjectMigrator](../dart_edition/lib/models/project_migrator.dart) |
| MCP 工具與輸入 schema | [MCP server](../dart_edition/lib/features/mcp/application/monoashi_mcp_server.dart) |
| MCP 回傳值與預設值 | [MCP adapter](../dart_edition/lib/features/mcp/application/monoashi_mcp_adapter.dart) |
| 讀取容量限制 | [ProjectReadBudget](../dart_edition/lib/features/story_read/domain/project_read_models.dart) |
| 原生文字分析協定 | [Rhodanthe protocol](../dart_edition/lib/infrastructure/rhodanthe/rhodanthe_protocol.dart) |
| 即時協作版本 | [CollaborationSchema](../dart_edition/lib/domain/collaboration/collaboration_operation.dart) |
