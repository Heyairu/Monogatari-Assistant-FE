# Monogatari Assistant 統一說明文件

更新日期：2026-10-09

適用版本：App `0.9.31`；專案格式 `1.18`

[文件中心](README.md) · [API 文件](API.md) · [參考文件索引](SOURCES.md)

## 1. 專案介紹

Monogatari Assistant（物語 Assistant／MonoAshi）是以 Flutter 開發的故事創作工具，把正文、章節、大綱、角色、世界觀、物品、時間軸與校稿資料放在同一個工作區。作品主要保存為本機 `.mnproj` 專案檔。

原始碼採 [Apache License 2.0](../LICENSE.md)。名稱與標誌的使用另見 [商標說明](../TRADEMARKS.md)，第三方聲明見 [NOTICE](../NOTICE.md)。

## 2. 功能與目前範圍

| 功能 | 用途與行為 |
| --- | --- |
| 故事設定 | 保存作品名稱、作者、簡介、類型及基本企劃資料 |
| 章節與正文 | 用資料夾／章節樹組織稿件，編輯、排序與匯出正文 |
| 大綱與時間軸 | 管理故事線、事件、Scene 和 placement，依 Tick 查看故事狀態 |
| 角色與關係圖 | 保存角色檔案、關係與 Scene 狀態變更 |
| 世界設定 | 保存階層式地點、設定欄位及地點快照 |
| 物品 | 管理 Class、instance、歸屬、數量、正式關聯與歷史快照 |
| 搜尋與取代 | 提供一般文字、正則表示式、大小寫、全半形及忽略字元選項 |
| 標記與短語 | 正文中的 UUID 標記、註記、顯示投影，以及專案短語庫與 PoppinSense 插入 |
| 企劃與校稿 | 整理伏筆、更新計畫與正文檢查資料 |
| 修訂追蹤 | 比較正文與結構化資料，保存本機 checkpoint，檢視與處理支援的差異 |
| Copilot | Chat 與依 build 開關提供的 Ask／Plan；使用自備 API Key 直接連到 provider |
| MCP | 授權本機 Host 唯讀查看作品，提供 7 個工具與 resource URI |
| P2P／協作 | 內網端點探測、配對、加密快照交換與即時協作資料流 |

Copilot Ask／Plan 預設由編譯旗標關閉；Plan 只提供建議、驗證、檢視及匯出，Agent 尚未開放。Git 同步與 Sync Hub 等替代架構仍屬設計參考，不能依計畫文件推定已提供。

## 3. 建立、開啟與保存作品

1. 從歡迎頁建立或開啟專案，填寫故事基本資料。
2. 在章節頁建立資料夾與章節，選取章節後撰寫正文。
3. 依需要補上大綱、角色、地點、物品與術語等設定。
4. 使用「儲存」寫回目前位置，或以「另存為」建立新檔。
5. 使用正文匯出產生 `.txt`／`.md`；需要保留結構時使用專案檔或支援的局部 XML／Markdown 匯出。

完整專案檔是 UTF-8 XML，副檔名為 `.mnproj`。局部 Markdown 匯出含可讀內容及 lossless XML 區塊；一般正文文字匯出不等同完整專案備份。

舊格式開啟時會在記憶體中遷移，使用者儲存前不覆寫原檔；再次儲存輸出 `1.18`。較新且不支援的格式會被拒絕。找不到可靠引用目標的舊資料保留原 ID 或文字，不以同名物件自動配對。

### 自動儲存、備份與復原

自動儲存使用已知檔案位置；沒有可用位置時不應以背景另存對話框代替。AutoBackup 另寫備份檔，維持目前專案位置與未儲存狀態，並依設定的總容量整理備份。

在設定中確認備份目錄、容量及可用空間。升級專案格式、批次取代、匯入或模式轉換前，可先另存副本。Undo／Redo 用於目前工作階段；跨啟動復原應使用已保存的專案、備份或 checkpoint。

Android 檔案操作涉及 SAF URI，Apple 平台涉及持久存取授權；開檔與存檔必須沿用平台橋接，不要只把 URI 當桌面路徑。Web 的 Rhodanthe 使用 Dart fallback；本機檔案、FFI 與 P2P 能力不能直接套用到 Web。

資料格式細節見 [專案 XML 規格](../dart_edition/MNPROJ_FILE_STRUCTURE.md)，程式呼叫見 [檔案 API](API.md#3-專案與檔案-api)。

## 4. 搜尋與取代

從工具列的搜尋按鈕開啟視窗，輸入文字後使用上一個／下一個檢視匹配結果，再選擇單次或全部取代。桌面 App 主畫面亦註冊 `Ctrl+F`；焦點與平台快捷鍵行為以實際介面為準。

| 選項 | 說明 |
| --- | --- |
| 大小寫相同 | 開啟時區分 `Hero` 與 `hero` |
| 全字拼寫需相符 | 限制為完整詞邊界；中文與英文字詞不能假定採相同切詞方式 |
| 正則表示式 | 使用 regexp 語法；不要沿用舊指南把 `?`／`*` 當一般萬用字元 |
| 全半形須相符 | 開啟時區分 `１` 與 `1` |
| 略過標點符號 | 一般文字搜尋可忽略標點 |
| 略過空白字元 | 一般文字搜尋可忽略空格、Tab 與換行 |

正則模式會限制部分其他選項；Rust 原生搜尋不支援 look-around 和 backreference。先用簡單文字確認結果，再逐項調整選項。大量取代前先儲存並確認匹配範圍。標記正文的搜尋與讀者匯出使用投影內容，不能把畫面 offset 直接當 raw 語法 offset。

實作來源：[搜尋與取代](../dart_edition/lib/bin/findreplace.dart)、[App 快捷鍵](../dart_edition/lib/main.dart)。

## 5. 角色、地點、物品與 Scene 快照

時間軸 placement 決定 Scene 的位置；各功能頁依目前 Tick 投影該時刻的狀態。快照以 Scene UUID 連結，Tick 用於排序與 placement 遺失時的 fallback。

| 物品模式 | 結構 | 情境 |
| --- | --- | --- |
| 專用 | 一個 Class 與一個獨立 instance | 唯一且需追蹤個別歷史的物品 |
| 半專用 | 一個 Class、多個 instance，可保留聚合數量 | 同類物品中只有部分需個別追蹤 |
| 非專用 | 一個 Class，以分配量記錄歸屬 | 可互換且只需統計數量的物品 |

建立物品後，以物件選擇器連到人物、地點、事件或 Scene。新增快照先選 Scene；同一 Scene 有多個 placement 時可指定來源，未指定時使用固定排序規則。Scene 移動後，快照跟隨新的 Tick；placement 移除後，快照資料仍保留。

人物、地點、物品 Class 與 instance 的微型時間軸可查看、選取及複製支援的快照。對話框內的預覽只改本地選取，確認後才提交。地點每個節點有獨立狀態；父節點不存在時仍可保留子節點樹殼追溯。

故事中的消失以「此時已存在」等狀態記錄。永久刪除會影響引用；模式轉換會先預覽，並保留來源 ID 與歷史資料供追溯。詳見 [物品與 Scene 指南](../dart_edition/ITEMS_AND_SCENE_SNAPSHOTS_GUIDE.md) 與 [微型時間軸](../dart_edition/MINI_TIMELINE.md)。

## 6. 標記與短語

標記把人物、地點、事件、伏筆或計畫的 UUID 與顯示文字保存於正文。畫面呈現投影文字；儲存保留完整 raw 語法，重新命名以 UUID 維持連結。純高亮不要求 UUID。使用介面的標記選單與 formatter 建立內容，避免手動拼接未跳脫的字串。

短語庫保存目前專案內可重複插入的內容、短碼與標籤，支援建立、編輯、複製、停用與刪除。正文選區可存成短語；輸入 `;;` 查詢，或由 `\`／`/` 的手動選單進入短語分類。接受候選時一次替換 raw 範圍，碰到 Mention 時保留完整原子邊界。貼上與 IME 組字不觸發候選；Esc 保留字面輸入。

跨專案短語的 Mention 必須明確重新連結或轉純文字；刪除短語不會修改已插入的正文。詳見 [標記設計與實作紀錄](../dart_edition/INLINE_ANNOTATION_IMPLEMENTATION_PLAN.md) 和 [短語實作紀錄](../dart_edition/PHRASE_SYSTEM_PLAN.md)。

## 7. Copilot 與 MCP

### Copilot

設定 provider、API URL 與模型後，確認目的 host 再送出請求。API Key 保存在本機安全儲存，可從 Copilot 頁面清除；作品內容直接傳到設定的 provider。

- Chat 傳送對話訊息。
- Ask 傳送目前章節，可另選專案摘要或最多 12 個補充資源；摘要與補充資源是互斥 scope。
- Plan 產生唯讀 JSON 提案並驗證本次 context，沒有自動套用入口。

Ask／Plan 的章節上限為 72 KiB UTF-8，摘要 24 KiB，最多 12 個補充資源，每筆 8 KiB、合計 32 KiB。內容可能截斷；送出前應查看 scope。Ask／Plan 另附 App 內建格式參考；對話與 Plan 不跨 App 啟動保存。自訂雲端 URL 使用 HTTPS，HTTP 僅允許 loopback。

發布操作與平台待驗證項目見 [Copilot 發布手冊](../dart_edition/COPILOT_ASK_PLAN_RELEASE_RUNBOOK.md)。

### MCP

1. 在 App 開啟要授權的專案。
2. 從設定啟用「MCP 唯讀整合」。
3. 使用「複製 MCP Host 設定」，貼到支援 stdio MCP 的 Host。
4. Host 啟動 sidecar 後即可列出工具並讀取授權資料。
5. 停止授權或切換專案後，重新啟用並建立新連線。

授權預設 8 小時到期；一次性 descriptor 在 handshake 後刪除。App 停止授權或生命週期停止整合後，Host 的讀取會失敗。Host 設定只帶 sidecar 與 descriptor 路徑；整合契約見 [MCP API](API.md#2-mcp-唯讀-api)。

## 8. 內網同步、協作與修訂

P2P 裝置必須能經 LAN TCP 互通，依介面選擇作品並完成配對。端點可達不代表已授權讀取作品；摘要、快照與協作交換透過配對後的加密 session。

快照交換驗證 manifest、大小、完整雜湊及專案 XML。資料分歧時使用衝突處理或另存副本。即時協作 schema 為 `6`，XML 格式為 `1.18`；雙方需使用相容版本。多人操作的交易片段收齊後再套用，避免半完成狀態。

修訂追蹤以 detached baseline 比較目前正文與結構化 record；checkpoint 另外保存於本機應用程式支援目錄，並非所有差異都能直接還原。操作前依面板顯示的目標與支援動作確認，細節見 [修訂追蹤模組說明](../dart_edition/lib/features/revision_tracking/README.md)。

若 P2P 探測失敗，依序確認相同網路、正確 Wi-Fi IPv4／Port、對方服務已啟動及防火牆允許連線。版本不符時先各自保存作品再升級。介面與大小限制見 [P2P API](API.md#6-p2p-與即時協作-api)。

## 9. 開發環境與專案結構

目前 `pubspec.yaml` 要求 Dart `^3.12.0`；其中 Flutter Quill 11.6.0 註記要求 Flutter 3.44 以上。實際使用的 SDK 版本應記錄在各次建置證據中。原生 Rhodanthe 另需 Rust／Cargo；工具鏈以 [rust-toolchain.toml](../dart_edition/rust/rust-toolchain.toml) 為準。

```powershell
cd dart_edition
flutter pub get
flutter run
```

儲存庫含 Windows、macOS、Linux、Android、iOS 與 Web 平台目錄；各平台發布仍需該平台的建置與權限驗證，不能把舊 README 的最低 OS 表當成現行驗收保證。

```text
dart_edition/
├── lib/
│   ├── main.dart                 # App 啟動與整合
│   ├── bin/                      # 編輯器、檔案與 App 工具
│   ├── models/                   # 專案模型、codec 與遷移
│   ├── modules/                  # 功能頁面
│   ├── features/                 # Copilot、MCP、story_read、phrases、revision_tracking
│   ├── data/                     # Repository、P2P 與資料層
│   ├── domain/                   # Use case、repository 介面與協作模型
│   ├── infrastructure/rhodanthe/ # Rust FFI、worker 與 render adapter
│   ├── presentation/             # Provider 與共用 view
│   └── ui_library/               # 共用 UI 元件
├── rust/                         # Rhodanthe core、analyzer 與 C ABI
├── assets/                       # 圖示、字型與 JSON
├── test/                         # Flutter 測試
├── benchmark/                    # Rhodanthe 等效能量測
└── tool/                         # 建置、發布與政策檢查
```

狀態管理使用 Riverpod，資料模型使用 Freezed，正文整合 Code Text Field 與 Quill 路徑。作品檔案操作經 use case／repository 接入平台檔案服務；Copilot 與 MCP 共用 story_read 的唯讀 snapshot 與 context budget。

Rhodanthe 已接入 Dart worker 與 editor session；預設 release stage 為 `default-on`，失敗時回到 Dart highlighter。FFI 同步呼叫放在長駐 isolate，render plan 需通過版本、revision、UTF-16 與範圍驗證才發布。

## 10. 驗證、建置與發布

以下命令從 `dart_edition/` 執行：

```powershell
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/check_initstate_provider_assignments.dart
flutter analyze
flutter test
```

修改 Freezed／Riverpod annotation 後重新產生程式碼：

```powershell
dart run build_runner build --delete-conflicting-outputs
```

修改 Rust 後，從 `dart_edition/rust/` 執行：

```powershell
cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
```

Windows 範例：

```powershell
flutter build windows --release
dart run tool/build_mcp_sidecar.dart
```

Copilot internal build 需明確傳入 `--dart-define=COPILOT_ASK_ENABLED=true` 和 `--dart-define=COPILOT_PLAN_ENABLED=true`。Rhodanthe 平台封裝與手動升階流程見 [PACKAGING](../dart_edition/rust/PACKAGING.md) 和 [Dart infrastructure](../dart_edition/lib/infrastructure/rhodanthe/README.md)。

| 發布項目 | 專用流程 |
| --- | --- |
| MCP | [Windows gate](../dart_edition/tool/mcp_release_check.ps1)、[macOS／Linux gate](../dart_edition/tool/mcp_release_check.sh)、[驗收紀錄](../dart_edition/MCP_PHASE5_IMPLEMENTATION.md) |
| Copilot | [Windows gate](../dart_edition/tool/copilot_release_check.ps1)、[發布與回滾手冊](../dart_edition/COPILOT_ASK_PLAN_RELEASE_RUNBOOK.md) |
| Quill | [Windows gate](../dart_edition/tool/quill_release_check.ps1)、[遷移契約](../dart_edition/QUILL_PLAIN_TEXT_EDITOR_PHASE0.md) |
| Rhodanthe | [rollout preparation](../dart_edition/tool/prepare_rhodanthe_rollout.dart)、[audit checker](../dart_edition/tool/check_rhodanthe_rollout.dart)、[benchmark](../dart_edition/benchmark/RHODANTHE.md) |

MCP 原始 Phase 5 紀錄仍列有 macOS／Linux 與實際 Host 人工 gate；Copilot 原始發布手冊亦列有其他平台待驗證項目。歷史測試數量與 hash 不作為目前 checkout 的重新驗證結果。

## 11. 文件維護

變更功能時更新本文件的行為與限制；變更參數、版本、預算或錯誤碼時更新 [API 文件](API.md)。深層規格、UI 尺寸／間距規範、保留的設計與發布驗收資料依 [參考文件索引](SOURCES.md) 查閱。已取代的舊指南與重複紀錄已清理，歷史內容可由 Git 查閱；新增文件亦需加入索引。
