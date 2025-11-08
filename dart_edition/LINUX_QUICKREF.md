# Arch Linux 快速參考

## 🚀 快速啟動

```bash
# 使用腳本（推薦）
./run_on_linux.sh

# 或手動啟動
export GDK_BACKEND=x11 && export GDK_RENDERING=gl && flutter run -d linux --release
```

## 🔧 常見問題一行解決

```bash
# 畫面閃爍 → 使用 X11
export GDK_BACKEND=x11

# UI 卡頓 → 啟用硬體加速
export GDK_RENDERING=gl

# 字體缺失 → 安裝中文字體
sudo pacman -S noto-fonts-cjk

# 無法啟動 → 檢查依賴
ldd ./build/linux/x64/release/bundle/monogatari_assistant

# 記憶體過高 → 使用 Release 模式
flutter run -d linux --release
```

## 📦 必要依賴安裝

```bash
sudo pacman -S flutter gtk3 glib2 noto-fonts-cjk
```

## 🎯 建置流程

```bash
# 完整建置
./build_for_linux.sh

# 或手動
flutter clean && flutter pub get && flutter build linux --release
```

## 📊 效能檢查

```bash
# CPU/記憶體監控
htop

# GPU 監控（NVIDIA）
watch -n 1 nvidia-smi

# OpenGL 測試
glxgears
```

## 🔗 相關文件

- 詳細優化：[LINUX_OPTIMIZATION.md](LINUX_OPTIMIZATION.md)
- 故障排除：[LINUX_TROUBLESHOOTING.md](LINUX_TROUBLESHOOTING.md)
- 專案說明：[README.md](README.md)

---
💡 **提示**: 大多數問題可以透過使用 `GDK_BACKEND=x11` 和 Release 模式解決！
