# Arch Linux 故障排除指南

本文件提供針對 Arch Linux 用戶的常見問題解決方案。

## 🔍 快速診斷

### 檢查您的系統配置

```bash
# 檢查顯示伺服器類型
echo $XDG_SESSION_TYPE

# 檢查 GTK 版本
pkg-config --modversion gtk+-3.0

# 檢查 OpenGL 支援
glxinfo | grep "OpenGL version"

# 檢查顯卡驅動
lspci | grep VGA
```

## ⚡ 常見問題

### 問題 1：應用程式啟動後畫面閃爍或撕裂

**症狀**：
- 視窗內容不斷閃爍
- 文字顯示時出現畫面撕裂
- 滾動時有拖影

**解決方案**：

#### 方案 A：強制使用 X11（推薦）
```bash
export GDK_BACKEND=x11
flutter run -d linux --release
```

#### 方案 B：調整 VSync 設定
```bash
# 啟用 VSync
export vblank_mode=1

# 或停用 VSync
export vblank_mode=0

flutter run -d linux --release
```

#### 方案 C：更新顯卡驅動
```bash
# NVIDIA
sudo pacman -S nvidia nvidia-utils

# AMD
sudo pacman -S mesa vulkan-radeon

# Intel
sudo pacman -S mesa vulkan-intel

# 重新啟動系統
sudo reboot
```

### 問題 2：UI 操作卡頓、輸入延遲

**症狀**：
- 文字輸入有明顯延遲（>100ms）
- 按鈕點擊響應緩慢
- 頁面切換不流暢

**解決方案**：

#### 方案 A：啟用硬體加速
```bash
export GDK_RENDERING=gl
flutter run -d linux --release
```

#### 方案 B：使用 Release 模式
Debug 模式會顯著降低性能：
```bash
# 不要使用
flutter run -d linux  # Debug 模式

# 應該使用
flutter run -d linux --release  # Release 模式
```

#### 方案 C：減少背景程序
```bash
# 檢查 CPU 使用率
htop

# 關閉不必要的程序
```

#### 方案 D：增加系統資源限制
```bash
# 編輯 /etc/security/limits.conf
sudo nano /etc/security/limits.conf

# 添加以下行：
* soft nofile 65536
* hard nofile 65536
```

### 問題 3：字體顯示異常或缺失

**症狀**：
- 中文字顯示為方塊
- 字體渲染模糊
- 字型不一致

**解決方案**：

```bash
# 安裝中文字體
sudo pacman -S noto-fonts-cjk noto-fonts-emoji

# 安裝其他常用字體
sudo pacman -S ttf-dejavu ttf-liberation

# 重建字體快取
fc-cache -fv

# 驗證字體安裝
fc-list | grep -i "noto"
```

### 問題 4：在 Wayland 下無法正常顯示

**症狀**：
- 應用程式視窗無法顯示
- 視窗顯示位置錯誤
- 拖曳視窗時崩潰

**解決方案**：

#### 方案 A：使用 X11（推薦）
```bash
# 在 GDM 登入畫面選擇 "GNOME on Xorg"
# 或設置環境變數
export GDK_BACKEND=x11
```

#### 方案 B：安裝 XWayland
```bash
sudo pacman -S xorg-xwayland
```

#### 方案 C：切換到 X11 會話
編輯 `~/.xinitrc` 或使用顯示管理器選擇 X11 會話。

### 問題 5：應用程式無法啟動

**症狀**：
- 執行後沒有任何反應
- 立即崩潰並退出
- 顯示 "Segmentation fault"

**解決方案**：

#### 步驟 1：檢查依賴
```bash
# 檢查缺少的動態庫
ldd ./build/linux/x64/release/bundle/monogatari_assistant

# 安裝缺少的依賴
sudo pacman -S gtk3 glib2 pango cairo
```

#### 步驟 2：檢查權限
```bash
# 確保執行檔有執行權限
chmod +x ./build/linux/x64/release/bundle/monogatari_assistant

# 檢查目錄權限
ls -la ./build/linux/x64/release/bundle/
```

#### 步驟 3：查看詳細錯誤
```bash
# 使用 strace 追蹤系統調用
strace ./build/linux/x64/release/bundle/monogatari_assistant

# 查看 Flutter 日誌
flutter run -d linux --verbose
```

#### 步驟 4：重新建置
```bash
flutter clean
flutter pub get
flutter build linux --release
```

### 問題 6：在特定視窗管理器下顯示異常

**症狀**（針對 i3, bspwm, dwm 等 tiling WM）：
- 視窗大小不正確
- 視窗無法調整大小
- 視窗標題列缺失

**解決方案**：

#### i3wm 配置
編輯 `~/.config/i3/config`：
```
# 讓 Flutter 應用程式浮動
for_window [class="Monogatari_assistant"] floating enable
for_window [class="Monogatari_assistant"] resize set 1200 800

# 或者將其設為平鋪但固定大小
for_window [class="Monogatari_assistant"] floating disable
```

#### bspwm 配置
編輯 `~/.config/bspwm/bspwmrc`：
```bash
bspc rule -a Monogatari_assistant state=floating
```

#### dwm
需要修改 `config.h` 並重新編譯 dwm。

### 問題 7：記憶體使用過高

**症狀**：
- 應用程式佔用大量記憶體（>1GB）
- 系統變慢
- OOM killer 終止程序

**解決方案**：

#### 方案 A：使用 Release 模式
```bash
flutter run -d linux --release
```

#### 方案 B：監控記憶體使用
```bash
# 即時監控
watch -n 1 'ps aux | grep monogatari_assistant'

# 使用 valgrind 檢查記憶體洩漏
valgrind --leak-check=full ./build/linux/x64/release/bundle/monogatari_assistant
```

#### 方案 C：限制記憶體使用
```bash
# 使用 systemd-run 限制記憶體
systemd-run --scope -p MemoryLimit=512M ./build/linux/x64/release/bundle/monogatari_assistant
```

## 🔧 進階診斷

### 啟用 Flutter 偵錯日誌

```bash
# 設置日誌級別
export FLUTTER_ENGINE_LOG_LEVEL=info

# 執行並查看詳細日誌
flutter run -d linux --verbose
```

### 檢查 OpenGL 渲染

```bash
# 測試 OpenGL
glxgears

# 查看 OpenGL 資訊
glxinfo | grep -E "OpenGL version|OpenGL renderer"

# 測試 Vulkan（如果使用）
vulkaninfo
```

### 效能分析

```bash
# 使用 Flutter DevTools
flutter run -d linux --profile
# 然後在瀏覽器中開啟 DevTools

# 使用 perf 分析 CPU 使用
sudo perf record -F 99 -p $(pgrep monogatari_assistant)
sudo perf report
```

## 📋 完整的環境變數列表

將以下內容添加到 `~/.bashrc` 或 `~/.zshrc`：

```bash
# Monogatari Assistant 優化設定

# 強制使用 X11（解決 Wayland 問題）
export GDK_BACKEND=x11

# 啟用 OpenGL 渲染（提高性能）
export GDK_RENDERING=gl

# 統一主題（避免衝突）
export GTK_THEME=Adwaita

# VSync 設定（1=啟用，0=停用）
export vblank_mode=1

# Flutter 渲染優化
export FLUTTER_ENGINE_SWITCH_UNSAFE_RENDERING=1

# GTK 3 設定
export GTK_USE_PORTAL=0
export GTK_IM_MODULE=ibus
```

重新載入配置：
```bash
source ~/.bashrc  # 或 source ~/.zshrc
```

## 🆘 仍然無法解決？

### 收集系統資訊

執行以下命令並將結果附在問題回報中：

```bash
#!/bin/bash
echo "=== 系統資訊 ==="
uname -a
echo ""

echo "=== Flutter 版本 ==="
flutter --version
echo ""

echo "=== GTK 版本 ==="
pkg-config --modversion gtk+-3.0
echo ""

echo "=== 顯示伺服器 ==="
echo "XDG_SESSION_TYPE=$XDG_SESSION_TYPE"
echo ""

echo "=== 顯卡資訊 ==="
lspci | grep VGA
echo ""

echo "=== OpenGL 支援 ==="
glxinfo | grep "OpenGL version"
echo ""

echo "=== 已安裝的相關套件 ==="
pacman -Q | grep -E "gtk3|mesa|flutter|vulkan"
echo ""

echo "=== 環境變數 ==="
env | grep -E "GDK|GTK|FLUTTER"
```

### 聯繫支援

請在 GitHub Issues 中提供：
1. 上述系統資訊
2. 詳細的錯誤描述
3. 錯誤截圖（如適用）
4. 已嘗試的解決方案

## 📚 相關資源

- [Flutter Linux 文件](https://docs.flutter.dev/platform-integration/linux/building)
- [Arch Linux Flutter Wiki](https://wiki.archlinux.org/title/Flutter)
- [GTK 3 文件](https://docs.gtk.org/gtk3/)
- [主要文件：LINUX_OPTIMIZATION.md](LINUX_OPTIMIZATION.md)

---
**最後更新**: 2025-11-08
