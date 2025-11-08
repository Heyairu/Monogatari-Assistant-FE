#!/bin/bash
# Monogatari Assistant - Arch Linux 優化啟動腳本
# 
# 使用方法：
#   chmod +x run_on_linux.sh
#   ./run_on_linux.sh

echo "==========================================="
echo "  Monogatari Assistant - Linux 優化啟動"
echo "==========================================="
echo ""

# 檢測是否在 Linux 系統上
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "錯誤：此腳本僅適用於 Linux 系統"
    exit 1
fi

# 設置環境變數以優化渲染
echo "正在設置優化環境變數..."

# 強制使用 X11 後端（更穩定）
export GDK_BACKEND=x11

# 啟用 OpenGL 渲染（硬體加速）
export GDK_RENDERING=gl

# 使用 Adwaita 主題避免衝突
export GTK_THEME=Adwaita

# 啟用 VSync（避免畫面撕裂）
export vblank_mode=1

# 優化 Flutter 渲染
export FLUTTER_ENGINE_SWITCH_UNSAFE_RENDERING=1

echo "✓ 環境變數設置完成"
echo ""

# 檢查 Flutter 是否安裝
if ! command -v flutter &> /dev/null; then
    echo "錯誤：未找到 Flutter，請先安裝 Flutter"
    exit 1
fi

# 檢查 GTK3 是否安裝
if ! pkg-config --exists gtk+-3.0; then
    echo "警告：未找到 GTK3，請執行：sudo pacman -S gtk3"
    echo ""
fi

# 顯示系統資訊
echo "系統資訊："
echo "  OS: $(uname -s) $(uname -r)"
echo "  Flutter: $(flutter --version | head -n 1)"
echo "  GTK3: $(pkg-config --modversion gtk+-3.0 2>/dev/null || echo '未安裝')"
echo "  顯示伺服器: $XDG_SESSION_TYPE"
echo ""

# 選擇執行模式
echo "請選擇執行模式："
echo "  1) 開發模式 (Debug) - 支援熱重載"
echo "  2) 發布模式 (Release) - 最佳性能"
echo "  3) 效能分析模式 (Profile) - 用於診斷"
echo ""
read -p "請輸入選項 (1/2/3，預設為 1): " mode

case $mode in
    2)
        echo ""
        echo "正在以 Release 模式啟動..."
        flutter run -d linux --release
        ;;
    3)
        echo ""
        echo "正在以 Profile 模式啟動..."
        flutter run -d linux --profile
        ;;
    *)
        echo ""
        echo "正在以 Debug 模式啟動..."
        flutter run -d linux
        ;;
esac

# 執行後顯示提示
echo ""
echo "==========================================="
echo "  如遇到問題，請參考 LINUX_OPTIMIZATION.md"
echo "==========================================="
