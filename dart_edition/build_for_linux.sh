#!/bin/bash
# Monogatari Assistant - Linux 建置腳本
# 
# 使用方法：
#   chmod +x build_for_linux.sh
#   ./build_for_linux.sh

echo "==========================================="
echo "  Monogatari Assistant - Linux 建置"
echo "==========================================="
echo ""

# 檢測是否在 Linux 系統上
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "錯誤：此腳本僅適用於 Linux 系統"
    exit 1
fi

# 檢查 Flutter 是否安裝
if ! command -v flutter &> /dev/null; then
    echo "錯誤：未找到 Flutter，請先安裝 Flutter"
    echo "安裝方法：https://docs.flutter.dev/get-started/install/linux"
    exit 1
fi

# 檢查必要的系統依賴
echo "正在檢查系統依賴..."
MISSING_DEPS=()

if ! pkg-config --exists gtk+-3.0; then
    MISSING_DEPS+=("gtk3")
fi

if ! pkg-config --exists glib-2.0; then
    MISSING_DEPS+=("glib2")
fi

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo "錯誤：缺少以下依賴套件："
    for dep in "${MISSING_DEPS[@]}"; do
        echo "  - $dep"
    done
    echo ""
    echo "請執行以下命令安裝："
    echo "  sudo pacman -S ${MISSING_DEPS[*]}"
    exit 1
fi

echo "✓ 系統依賴檢查完成"
echo ""

# 顯示系統資訊
echo "系統資訊："
echo "  OS: $(uname -s) $(uname -r)"
echo "  Flutter: $(flutter --version | head -n 1)"
echo "  GTK3: $(pkg-config --modversion gtk+-3.0)"
echo ""

# 清理舊的建置
echo "正在清理舊的建置..."
flutter clean
echo "✓ 清理完成"
echo ""

# 獲取依賴
echo "正在獲取依賴..."
flutter pub get
echo "✓ 依賴獲取完成"
echo ""

# 選擇建置模式
echo "請選擇建置模式："
echo "  1) Debug - 用於開發和調試"
echo "  2) Release - 用於發布（推薦）"
echo "  3) Profile - 用於性能分析"
echo ""
read -p "請輸入選項 (1/2/3，預設為 2): " mode

BUILD_MODE="release"
case $mode in
    1)
        BUILD_MODE="debug"
        ;;
    3)
        BUILD_MODE="profile"
        ;;
    *)
        BUILD_MODE="release"
        ;;
esac

# 執行建置
echo ""
echo "正在以 $BUILD_MODE 模式建置..."
echo ""

if flutter build linux --$BUILD_MODE; then
    echo ""
    echo "==========================================="
    echo "  ✓ 建置成功！"
    echo "==========================================="
    echo ""
    echo "執行檔位置："
    echo "  ./build/linux/x64/$BUILD_MODE/bundle/monogatari_assistant"
    echo ""
    echo "執行方法："
    echo "  cd build/linux/x64/$BUILD_MODE/bundle"
    echo "  ./monogatari_assistant"
    echo ""
    echo "或使用優化啟動腳本："
    echo "  GDK_BACKEND=x11 GDK_RENDERING=gl ./build/linux/x64/$BUILD_MODE/bundle/monogatari_assistant"
    echo ""
else
    echo ""
    echo "==========================================="
    echo "  ✗ 建置失敗"
    echo "==========================================="
    echo ""
    echo "請檢查錯誤訊息並參考 LINUX_OPTIMIZATION.md"
    exit 1
fi

# 詢問是否立即執行
echo ""
read -p "是否要立即執行應用程式？(y/N): " run_now

if [[ "$run_now" =~ ^[Yy]$ ]]; then
    echo ""
    echo "正在啟動應用程式..."
    echo ""
    
    # 設置優化環境變數
    export GDK_BACKEND=x11
    export GDK_RENDERING=gl
    export GTK_THEME=Adwaita
    export vblank_mode=1
    
    cd "build/linux/x64/$BUILD_MODE/bundle"
    ./monogatari_assistant
fi

echo ""
echo "==========================================="
echo "  建置完成"
echo "==========================================="
