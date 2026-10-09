# 參考文件索引

更新日期：2026-10-09

[文件中心](README.md) · [統一說明文件](GUIDE.md) · [統一 API 文件](API.md)

## 查閱方式

日常使用與開發先看說明文件，介面參數與目前契約先看 API 文件。下表只列出仍保留、有獨立內容的專題規格、操作手冊、設計與發布驗收文件。

已被統一文件取代的舊操作指南、重複效能／稽核報告、已完成的階段紀錄及 Flutter 樣板 README 已移除；原先提交過的歷史內容可由 Git 查閱。

設計計畫保留細部欄位、取捨、未納入實作的需求及驗收條件，不作為目前功能或版本的保證。例如早期 Beta 8 與同步替代架構的版本、排程和功能範圍，應配合現行說明及程式碼閱讀。發布驗收中的測試數量與 hash 只適用於記錄當時的版本。

`MNPROJ_FILE_STRUCTURE.md` 是 App 使用的內建 asset，維持原路徑。授權、商標及平台資源說明亦保留。

目前有 **4** 份統一入口文件與 **46** 份參考文件，共 **50** 份 Markdown。

## 專題規格與開發參考

| 文件 | 內容 |
| --- | --- |
| [MATERIAL_DESIGN_3_GUIDELINES.md](../MATERIAL_DESIGN_3_GUIDELINES.md) | Material Design 3 設計規範（非 Expressive） |
| [CODE_TEXT_FIELD_BEHAVIOR_BASELINE.md](../dart_edition/CODE_TEXT_FIELD_BEHAVIOR_BASELINE.md) | Code Text Field Migration Baseline (Step 1) |
| [COMPONENT_SIZE_GUIDELINES.md](../dart_edition/COMPONENT_SIZE_GUIDELINES.md) | 元件尺寸規範 |
| [LIST_DISPLAY_GUIDELINES.md](../dart_edition/LIST_DISPLAY_GUIDELINES.md) | List、ListCard 顯示規範 |
| [MINI_TIMELINE.md](../dart_edition/MINI_TIMELINE.md) | 微型時間軸 |
| [MNPROJ_FILE_STRUCTURE.md](../dart_edition/MNPROJ_FILE_STRUCTURE.md) | `.mnproj` 檔案結構 |
| [NEON_UI_ICON_BUTTON_SPEC.md](../dart_edition/NEON_UI_ICON_BUTTON_SPEC.md) | NeonUI：平面圖示工具列設計規範 |
| [PADDING_GUIDELINES.md](../dart_edition/PADDING_GUIDELINES.md) | Padding 規範 |
| [PHASE_4_5_GUARDRAILS.md](../dart_edition/PHASE_4_5_GUARDRAILS.md) | Phase 4/5 Guardrails |
| [QUILL_PLAIN_TEXT_EDITOR_PHASE0.md](../dart_edition/QUILL_PLAIN_TEXT_EDITOR_PHASE0.md) | Quill 純文字正文編輯器：Phase 0 規格 |
| [RHODANTHE_SPEC.md](../dart_edition/RHODANTHE_SPEC.md) | MonoAshi™ Rhodanthe* 即時 RichText 引擎規格 |
| [SLIDER_I18N_MAPPING.md](../dart_edition/SLIDER_I18N_MAPPING.md) | 滑桿標籤國際化對照表 |
| [RHODANTHE.md](../dart_edition/benchmark/RHODANTHE.md) | Rhodanthe benchmarks |
| [README.md](../dart_edition/lib/features/revision_tracking/README.md) | Revision tracking |
| [README.md](../dart_edition/lib/infrastructure/rhodanthe/README.md) | Rhodanthe Dart infrastructure |
| [PACKAGING.md](../dart_edition/rust/PACKAGING.md) | Rhodanthe native packaging |
| [README.md](../dart_edition/rust/README.md) | Rhodanthe Rust workspace |
| [README.md](../dart_edition/rust/rhodanthe-bridge/README.md) | Rhodanthe bridge |

## 使用與發布手冊

| 文件 | 內容 |
| --- | --- |
| [COPILOT_ASK_PLAN_RELEASE_RUNBOOK.md](../dart_edition/COPILOT_ASK_PLAN_RELEASE_RUNBOOK.md) | Copilot Ask／Plan Beta 發布與回滾手冊 |
| [ITEMS_AND_SCENE_SNAPSHOTS_GUIDE.md](../dart_edition/ITEMS_AND_SCENE_SNAPSHOTS_GUIDE.md) | 物品與 Scene 快照使用及遷移說明 |

## 保留的設計計畫

| 文件 | 內容 |
| --- | --- |
| [BETA8_DEVELOPMENT_PLAN.md](../dart_edition/BETA8_DEVELOPMENT_PLAN.md) | Monogatari Assistant Beta 8 開發計畫 |
| [CHARACTER_RELATIONSHIP_GRAPH_PLAN.md](../dart_edition/CHARACTER_RELATIONSHIP_GRAPH_PLAN.md) | 人物關係圖頁面功能分析與實作規劃 |
| [CHARACTER_RELATIONSHIP_LAYOUT_OPTIMIZATION_PLAN.md](../dart_edition/CHARACTER_RELATIONSHIP_LAYOUT_OPTIMIZATION_PLAN.md) | 角色關係圖：四條線與排列優化實作步驟 |
| [CHARACTER_SETTINGS_FIELDS_AND_SIMPLIFICATION_PLAN.md](../dart_edition/CHARACTER_SETTINGS_FIELDS_AND_SIMPLIFICATION_PLAN.md) | 角色設定欄位盤點與簡化計畫 |
| [CHARACTER_SNAPSHOT_TIMELINE_IMPLEMENTATION_PLAN.md](../dart_edition/CHARACTER_SNAPSHOT_TIMELINE_IMPLEMENTATION_PLAN.md) | 角色設定快照（串接時間軸）實作規劃 |
| [COPILOT_ASK_PLAN_IMPLEMENTATION_PLAN.md](../dart_edition/COPILOT_ASK_PLAN_IMPLEMENTATION_PLAN.md) | Copilot Ask／Plan 模式詳細設計與實作計畫 |
| [GIT_BASED_SYNC_DESIGN.md](../dart_edition/GIT_BASED_SYNC_DESIGN.md) | 物語 Assistant：Git 為核心的內網同步設計 |
| [INLINE_ANNOTATION_IMPLEMENTATION_PLAN.md](../dart_edition/INLINE_ANNOTATION_IMPLEMENTATION_PLAN.md) | MonoAshi™ Mosaic System 實作計畫 |
| [INTRANET_SYNC_DESIGN.md](../dart_edition/INTRANET_SYNC_DESIGN.md) | 物語 Assistant：內網同步設計與網路原理 |
| [ITEM_PAGE_EVALUATION.md](../dart_edition/ITEM_PAGE_EVALUATION.md) | 物品三種管理模式與物品／地點時間軸快照評估 |
| [ITEM_SNAPSHOT_IMPLEMENTATION_PLAN.md](../dart_edition/ITEM_SNAPSHOT_IMPLEMENTATION_PLAN.md) | 物品管理與物品／地點快照實作計畫 |
| [MCP_IMPLEMENTATION_PLAN.md](../dart_edition/MCP_IMPLEMENTATION_PLAN.md) | MonoAshi MCP 唯讀整合實作計畫 |
| [MINI_TIMELINE_SNAPSHOT_PREVIEW_ROADMAP.md](../dart_edition/MINI_TIMELINE_SNAPSHOT_PREVIEW_ROADMAP.md) | 微型時間軸快照預覽替換路線圖 |
| [P2P_LAN_SYNC_DESIGN.md](../dart_edition/P2P_LAN_SYNC_DESIGN.md) | 物語 Assistant：內網 P2P 同步設計 |
| [PALETTESVIEW_MODULE_PLAN.md](../dart_edition/PALETTESVIEW_MODULE_PLAN.md) | PalettesView Module（文字調色盤）規劃 |
| [PHRASE_SYSTEM_PLAN.md](../dart_edition/PHRASE_SYSTEM_PLAN.md) | MonoAshi 短語系統規劃（Mosaic／Mention） |
| [QUILL_PLAIN_TEXT_EDITOR_PLAN.md](../dart_edition/QUILL_PLAIN_TEXT_EDITOR_PLAN.md) | Quill 純文字正文編輯器替換計畫 |
| [REALTIME_COLLABORATION_DESIGN.md](../dart_edition/REALTIME_COLLABORATION_DESIGN.md) | 真即時協作系統設計 |
| [REVISION_TRACKING_VIEW_PLAN.md](../dart_edition/REVISION_TRACKING_VIEW_PLAN.md) | 修訂追蹤視圖規劃 |
| [TIMELINE_IMPLEMENTATION_EVALUATION.md](../dart_edition/TIMELINE_IMPLEMENTATION_EVALUATION.md) | 時間軸功能實作評估 |

## 發布驗收紀錄

| 文件 | 內容 |
| --- | --- |
| [MCP_PHASE5_IMPLEMENTATION.md](../dart_edition/MCP_PHASE5_IMPLEMENTATION.md) | MonoAshi MCP Phase 5 實作與發布驗收 |

## 專案入口、授權與平台資源

| 文件 | 內容 |
| --- | --- |
| [LICENSE.md](../LICENSE.md) | LICENSE.md |
| [NOTICE.md](../NOTICE.md) | NOTICE |
| [README.md](../README.md) | Monogatari Assistant FE |
| [TRADEMARKS.md](../TRADEMARKS.md) | Monogatari Assistant Trademark Policy |
| [README.md](../dart_edition/ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md) | Launch Screen Assets |

