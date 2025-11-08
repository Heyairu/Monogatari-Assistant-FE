# Linux 平台優化指南（針對 Arch Linux）

## 問題說明

在 Arch Linux 上運行 Flutter 應用程式時，可能會遇到以下問題：
1. **顯示問題**：畫面撕裂、閃爍、渲染異常
2. **操作卡頓**：UI 響應遲鈍、輸入延遲

這些問題主要由以下原因造成：
- GTK3 和 Wayland 的相容性問題
- OpenGL 渲染設置不當
- 預設渲染後端選擇不佳

## 已實施的優化

### 1. 強制使用 X11 後端
```cpp
g_setenv("GDK_BACKEND", "x11", TRUE);
```
- Wayland 在某些情況下可能導致顯示問題
- X11 提供更穩定的渲染體驗

### 2. 啟用 OpenGL 渲染
```cpp
g_setenv("GDK_RENDERING", "gl", TRUE);
```
- 使用硬體加速渲染
- 大幅改善性能和流暢度

### 3. 統一 GTK 主題
```cpp
g_setenv("GTK_THEME", "Adwaita", FALSE);
```
- 避免自訂主題與 Flutter 的衝突
- 確保一致的視覺效果

## 其他建議優化

### 系統層級優化

#### 1. 安裝必要的圖形驅動程式
```bash
# NVIDIA 顯卡
sudo pacman -S nvidia nvidia-utils

# AMD 顯卡
sudo pacman -S mesa vulkan-radeon

# Intel 顯卡
sudo pacman -S mesa vulkan-intel
```

#### 2. 安裝 OpenGL 支援
```bash
sudo pacman -S mesa-demos
# 測試 OpenGL 是否正常工作
glxinfo | grep "OpenGL version"
```

#### 3. 確保 GTK3 正確安裝
```bash
sudo pacman -S gtk3
```

### Flutter 應用層級優化

#### 1. 在 `main.dart` 中啟用硬體加速
已在 `main.dart` 中實施：
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  runApp(const MainApp());
}
```

#### 2. 建議在開發時使用 Release 模式測試性能
```bash
# 開發模式（Debug）
flutter run -d linux

# 發布模式（更流暢）
flutter run -d linux --release
```

#### 3. 編譯優化
在 `linux/CMakeLists.txt` 中已設置：
```cmake
target_compile_options(${TARGET} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:-O3>")
```

### 執行時環境變數（如果修改 main.cc 後仍有問題）

您可以在執行應用程式時設置環境變數：

```bash
# 強制使用 X11
export GDK_BACKEND=x11

# 啟用 OpenGL 渲染
export GDK_RENDERING=gl

# 停用 vsync（如果仍有撕裂）
export vblank_mode=0

# 執行應用程式
./build/linux/x64/release/bundle/monogatari_assistant
```

### Wayland 用戶的替代方案

如果您堅持使用 Wayland，請嘗試：

```bash
# 確保 Wayland 支援正確安裝
sudo pacman -S xorg-xwayland

# 設置 Wayland 環境變數
export GDK_BACKEND=wayland
export QT_QPA_PLATFORM=wayland
export MOZ_ENABLE_WAYLAND=1

# 執行應用程式
flutter run -d linux
```

## 編譯與測試

### 重新編譯應用程式
```bash
# 清理舊的建置
flutter clean

# 重新獲取依賴
flutter pub get

# 建置 Release 版本
flutter build linux --release

# 執行
./build/linux/x64/release/bundle/monogatari_assistant
```

### 效能測試

1. **測試 UI 流暢度**
   - 快速切換頁面
   - 大量文字輸入
   - 搜尋與取代功能

2. **監控資源使用**
```bash
# 使用 htop 監控 CPU 和記憶體使用
htop

# 使用 nvidia-smi（NVIDIA 顯卡）監控 GPU 使用
watch -n 1 nvidia-smi
```

## 常見問題排除

### Q1: 應用程式無法啟動
**A:** 檢查是否安裝了所有必要的依賴：
```bash
ldd ./build/linux/x64/release/bundle/monogatari_assistant
```

### Q2: 仍然有畫面撕裂
**A:** 嘗試啟用 VSync：
```bash
export vblank_mode=1  # 啟用 vsync
```

### Q3: 字體顯示異常
**A:** 安裝中文字體：
```bash
sudo pacman -S noto-fonts-cjk noto-fonts-emoji
```

### Q4: 視窗管理器相關問題
**A:** 某些視窗管理器（如 i3、bspwm）可能需要額外配置：
```bash
# 在 ~/.config/i3/config 中添加
for_window [class="Monogatari_assistant"] floating enable
```

## 驗證優化效果

1. **啟動時間**：應在 2-3 秒內啟動
2. **文字輸入延遲**：應小於 50ms
3. **頁面切換**：應該流暢無卡頓
4. **搜尋功能**：大文件（10000+ 字）搜尋應在 100ms 內完成

## 進一步優化建議

如果以上方法仍無法解決問題，可以考慮：

1. **降低 UI 複雜度**
   - 減少同時渲染的組件數量
   - 使用 `ListView.builder` 替代 `ListView`

2. **啟用 Flutter 的效能分析**
```bash
flutter run --profile -d linux
```

3. **報告問題**
   如果問題持續存在，請收集以下資訊並回報：
   - Arch Linux 版本：`uname -a`
   - Flutter 版本：`flutter --version`
   - GTK 版本：`pkg-config --modversion gtk+-3.0`
   - 顯卡資訊：`lspci | grep VGA`
   - 桌面環境/視窗管理器
   - 具體的錯誤訊息或日誌

## 參考資源

- [Flutter Linux 桌面支援文件](https://docs.flutter.dev/platform-integration/linux/building)
- [Arch Linux Flutter 套件](https://archlinux.org/packages/extra/x86_64/flutter/)
- [GTK3 性能優化指南](https://wiki.archlinux.org/title/GTK)

---
**最後更新**: 2025-11-08
**適用版本**: Flutter 3.9+, Arch Linux (滾動更新)
