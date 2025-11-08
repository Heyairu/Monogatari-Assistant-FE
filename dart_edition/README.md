# Monogatari Assistant (物語 Assistant)

一個專為故事創作者設計的寫作輔助應用程式。

## 功能特色

- 📖 基本資訊管理
- 📚 章節選擇與編輯
- 📝 大綱調整
- 🌍 世界設定
- 👤 角色設定
- 🔍 搜尋與取代（支援正則表達式）
- 💾 專案檔案管理
- 🎨 淺色/深色主題切換

## 平台支援

✅ **Windows**  
✅ **macOS**  
✅ **Linux** (包含 Arch Linux 優化)  
✅ **Web**  
✅ **Android**  
✅ **iOS**

## 安裝與執行

### Linux (Arch Linux)

如果您在 Arch Linux 上遇到顯示問題或操作卡頓，我們提供了特別優化：

#### 方法 1：使用優化腳本（推薦）

```bash
# 給予執行權限
chmod +x run_on_linux.sh build_for_linux.sh

# 建置應用程式
./build_for_linux.sh

# 執行應用程式
./run_on_linux.sh
```

#### 方法 2：手動執行

```bash
# 設置優化環境變數
export GDK_BACKEND=x11
export GDK_RENDERING=gl
export GTK_THEME=Adwaita

# 執行
flutter run -d linux --release
```

#### Linux 系統需求

```bash
# 安裝必要的依賴
sudo pacman -S flutter gtk3 glib2

# 安裝字體支援（推薦）
sudo pacman -S noto-fonts-cjk noto-fonts-emoji
```

詳細的 Linux 優化指南請參考：[LINUX_OPTIMIZATION.md](LINUX_OPTIMIZATION.md)

### Windows

```bash
flutter run -d windows
```

### macOS

```bash
flutter run -d macos
```

### Web

```bash
flutter run -d chrome
```

## 開發

### 環境需求

- Flutter SDK 3.9.2 或更高版本
- Dart SDK (包含在 Flutter 中)

### 安裝依賴

```bash
flutter pub get
```

### 執行開發版本

```bash
flutter run -d <platform>
```

### 建置發布版本

```bash
# Linux
flutter build linux --release

# Windows
flutter build windows --release

# macOS
flutter build macos --release
```

## 專案結構

```
lib/
├── main.dart              # 主程式入口
├── bin/                   # 工具類別
│   ├── file.dart         # 檔案操作
│   ├── findreplace.dart  # 搜尋取代功能
│   ├── theme_manager.dart # 主題管理
│   └── settings_manager.dart # 設定管理
└── modules/              # 功能模組
    ├── baseinfoview.dart
    ├── chapterselectionview.dart
    ├── outlineview.dart
    ├── worldsettingsview.dart
    ├── characterview.dart
    └── settingview.dart
```

## 已知問題與解決方案

### Arch Linux 顯示問題

如果遇到：
- 畫面撕裂或閃爍
- UI 操作卡頓
- 渲染異常

請參考 [LINUX_OPTIMIZATION.md](LINUX_OPTIMIZATION.md) 中的詳細解決方案。

## 授權

商業源碼授權 1.1 (修改版)
變更日期：2030-11-04 05:14 a.m. (UTC+8)  
變更授權：Apache License 2.0

## 作者

Heyairu（部屋伊琉）

---

**注意**：本專案仍在活躍開發中，部分功能可能尚未完成。
