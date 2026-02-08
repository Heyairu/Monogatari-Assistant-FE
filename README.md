# Monogatari Assistant FE

![Title](/Title.png "Title")

> 一款專為故事創作者設計的寫作助手應用程式

[![License](https://img.shields.io/badge/License-BSL%201.1-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-%5E3.9.2-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows|macOS|Linux||Android|iOS-green)](#支援平台)

- **Material Design 介面** - 支援亮色/暗色主題，響應式佈局
- **章節管理** - 分部章節組織，拖拽排序，快速切換
- **角色設定** - 詳細的角色資料卡，包含外觀、性格、能力等多維度設定
- **世界設定** - 地點、文化、歷史等世界觀資料管理
- **大綱規劃** - 結構化故事線管理，支援場景、事件和衝突點規劃
- **搜尋** - 支援正則表達式、大小寫敏感、全形半形不敏感搜尋

「物語Assistant」是一款專為小說家與創作者設計的輕量級編輯工具。它能讓你更直觀地整理與構築故事中的場景、對話、動作以及事件等要素。不同於傳統文字編輯器，本工具強調視覺化與結構化的工作流程，能在寫作過程中即時預覽故事的進展，大幅減少不必要的修正工作。

無論是長篇小說、輕小說，還是短篇故事，都能靈活支援。透過模組化設計，創作者能迅速將靈感轉化為稿件。「物語Assistant」不僅僅是寫作工具，更是協助你維持故事一致性與條理性的「創作夥伴」，讓寫作流程更加順暢。

Logo靈感來源於 ProgrammingVTuberLogos / GitHub@Aikoyori

## 配置需求

### Windows / macOS / Linux

| Items | Minimum Requirements | Recommended |
|------|----------|----------|
| CPU | x64/Arm64, 1GHz up, Intel Celeron | i5-4570 equivalent & greater |
| RAM | 2 GiB up | 8 GiB up |
| Storage | 500MiB Available | 1GiB Available |
| System | Win10(1809) / macOS 10.14 / Ubuntu 20.04 | Win10(22H2)+ / macOS 14+ / Ubuntu 20.04+ |

### Android

| Items | Minimum Requirements | Recommended |
|------|----------|----------|
| System | Android 5 (API Level 21) | Android 8+ |
| RAM | 2 GiB up | 6 GiB up |
| Storage | 200MiB Available | 500MiB Available |

### iOS

| Items | Minimum Requirements | Recommended |
|------|----------|----------|
| System | iOS 12.0 | iOS 15+ |
| Device | iPhone 6s equivalent & greater | iPhone 8 equivalent & greater |
| Storage | 200 MiB Available | 500 MiB Available |

## 功能說明
### 1. 故事設定
管理故事的基本資訊，包括：
- 故事名稱、作者、類型
- 故事簡介和目標讀者
### 2. 章節選擇
- **分部管理**: 將作品分為多個部分（如：第一部、第二部）
- **章節組織**: 每個部分包含多個章節
- **拖拽排序**: 透過拖拽重新排序章節
- **快速切換**: 點擊章節名稱即可切換編輯內容
- **即時同步**: 編輯器內容自動與選中章節同步
### 3. 大綱調整
結構化的故事線管理：
- **故事線分類**: 支援「起承轉合」、「三幕劇」等類型
- **事件管理**: 每條故事線包含多個事件
- **場景細節**: 每個事件包含多個場景
- **衝突點**: 記錄故事的衝突和轉折點
- **備註功能**: 為故事線、事件和場景添加備註

### 4. 世界設定
管理故事的世界觀設定：
- 地點名稱和描述
- 歷史背景
- 文化特色
- 地理環境
- 可新增、編輯和刪除地點資料

### 5. 角色設定
詳細的角色資料管理系統：
- **基本資料**
  - 姓名、暱稱、年齡、性別
- **外觀特徵**
  - 身高、體重、體型、髮型、瞳色、五官特徵、穿著
- **性格設定**
  - MBTI 人格類型、個性描述
  - 阻礙事件（角色成長的障礙）
- **能力評估**
  - 生活技能評估（料理、清潔、理財等）
  - 喜愛、討厭、害怕做的事
- **社交特質**
  - 社交傾向（內向/外向、低調/高調等）
  - 性格特質（悲觀/樂觀、保守/開放等）
- **其他資訊**
  - 原文姓名、喜歡/討厭的人事物
  - 口頭禪、角色註解

## 使用技巧
### 建立新專案
1. 點擊頂部工具列的 📁 圖示
2. 選擇「新建檔案」
3. 在「故事設定」中填寫基本資訊
4. 在「章節選擇」中建立章節結構
5. 開始在編輯器中撰寫內容
### 組織章節
1. 切換到「章節選擇」頁面
2. 使用 ➕ 按鈕新增部或章節
3. 拖拽章節卡片來調整順序
4. 點擊章節名稱切換到該章節進行編輯
5. 使用 🗑️ 圖示刪除不需要的章節
### 角色管理
1. 切換到「角色設定」頁面
2. 點擊右下角的 ➕ 按鈕新增角色
3. 切換不同分頁填寫角色資料：
   - **基本**: 基本資料
   - **外觀**: 外觀特徵
   - **性格**: 性格和心理特質
   - **能力**: 技能和能力
   - **社交**: 社交特質
   - **其他**: 補充資訊
4. 使用滑桿調整數值型特質
5. 使用清單管理項目型資料

## 🛠️ 技術架構

- **框架**: Flutter 3.9.2+
- **語言**: Dart 3.9.2+
- **狀態管理**: StatefulWidget + setState
- **檔案格式**: XML
- **UI 設計**: Material Design 3

### 主要依賴

```yaml
dependencies:
  flutter: sdk
  file_picker: ^8.1.2         # 檔案選擇器
  path_provider: ^2.1.4       # 路徑提供者
  path: ^1.9.0                # 路徑處理
  intl: ^0.18.1               # 國際化
  uuid: ^4.5.0                # UUID 生成
  shared_preferences: ^2.3.3  # 本地儲存
  window_manager: ^0.4.3      # 視窗管理（桌面平台）
```

### 專案結構

```
lib/
├── main.dart                      # 主程式入口
├── bin/
│   ├── file.dart                  # 檔案操作服務
│   ├── findreplace.dart           # 搜尋取代功能
│   ├── theme_manager.dart         # 主題管理
│   └── settings_manager.dart      # 設定管理
└── modules/
    ├── baseinfoview.dart          # 故事設定模組
    ├── chapterselectionview.dart  # 章節選擇模組
    ├── outlineview.dart           # 大綱調整模組
    ├── worldsettingsview.dart     # 世界設定模組
    ├── characterview.dart         # 角色設定模組
    ├── settingview.dart           # 設定模組
    └── AboutView.dart             # 關於模組
```