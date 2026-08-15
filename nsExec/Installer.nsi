!include MUI2.nsh

!define MUI_ICON "inst.ico"
!define APP_SOURCE_DIR "Release"
!define APP_EXE "dart_edition.exe"
!define APP_NAME "Monogatari Assistant"
!define APP_VERSION "0.8.93 Beta 7"
!define UNINSTALL_REG_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\MonogatariAssistant"
!define PROJECT_FILE_EXTENSION ".mnproj"
!define PROJECT_FILE_PROGID "MonogatariAssistant.Project"
!define PROJECT_FILE_DESCRIPTION "Monogatari Assistant Project"

Name "Monogatari Assistant" ; 安裝程式名稱
OutFile "Monogatari Assistant Installer.exe" ; 輸出檔名
RequestExecutionLevel admin ; 執行所需權限
Unicode True ; 以 Unicode 編碼的安裝檔
InstallDir $PROGRAMFILES\MonogatariAssistant  ; 預設安裝路徑
InstallDirRegKey HKLM "${UNINSTALL_REG_KEY}" "InstallLocation"

BrandingText "Heyairu(2025-2026) All rights reserved." ; 安裝程式底部的版權訊息

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "LICENSE.txt"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_DIRECTORY
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

!insertmacro MUI_LANGUAGE "TradChinese"
!insertmacro MUI_LANGUAGE "English"


Function .onInit
    !insertmacro MUI_LANGDLL_DISPLAY

    ; 優先從 HKLM 找既有安裝，找不到再試 HKCU
    ReadRegStr $0 HKLM "${UNINSTALL_REG_KEY}" "InstallLocation"
    StrCmp $0 "" 0 +2
    ReadRegStr $0 HKCU "${UNINSTALL_REG_KEY}" "InstallLocation"
    StrCmp $0 "" checkProcess

    ; 找到安裝路徑就沿用，避免升級時路徑漂移
    StrCpy $INSTDIR "$0"

checkProcess:
    ; 若主程式正在執行，先詢問是否強制關閉
    ExecWait '"$SYSDIR\cmd.exe" /C tasklist /FI $\"IMAGENAME eq ${APP_EXE}$\" /NH | find /I $\"${APP_EXE}$\" >nul' $1
    IntCmp $1 0 appRunning done done

appRunning:
    MessageBox MB_ICONQUESTION|MB_YESNO "偵測到 ${APP_EXE} 正在執行，是否強制關閉後繼續安裝？" IDYES forceClose IDNO cancelInstall

forceClose:
    ExecWait '"$SYSDIR\taskkill.exe" /F /T /IM "${APP_EXE}"' $2
    IntCmp $2 0 done
    MessageBox MB_ICONSTOP "無法關閉 ${APP_EXE}，請先手動關閉後再重試。"
    Abort

cancelInstall:
    Abort

done:
FunctionEnd

Function RefreshShellFileAssociations
    ; 讓 Explorer 立即重新讀取副檔名與圖示關聯，不必登出或重開機。
    System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, p 0, p 0)'
FunctionEnd

Function un.RefreshShellFileAssociations
    System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, p 0, p 0)'
FunctionEnd

Section "Install"
    SetOutPath $INSTDIR

    !if /FileExists "${APP_SOURCE_DIR}\*.*"
        File /r "${APP_SOURCE_DIR}\*.*"
    !else
        !error "Source folder '${APP_SOURCE_DIR}' not found. Please put build output in ${APP_SOURCE_DIR}."
    !endif

    File "LICENSE.txt"
    File "inst.ico"

    WriteUninstaller "$INSTDIR\Uninstall.exe"

    CreateDirectory "$SMPROGRAMS\${APP_NAME}"
    CreateShortcut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}" "" "$INSTDIR\inst.ico"
    CreateShortcut "$SMPROGRAMS\${APP_NAME}\Uninstall ${APP_NAME}.lnk" "$INSTDIR\Uninstall.exe"
    CreateShortcut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}" "" "$INSTDIR\inst.ico"

    ; 將 .mnproj 註冊為本程式的專案檔，Explorer 會以完整路徑作為 %1 傳入。
    WriteRegStr HKLM "Software\Classes\${PROJECT_FILE_EXTENSION}" "" "${PROJECT_FILE_PROGID}"
    WriteRegStr HKLM "Software\Classes\${PROJECT_FILE_PROGID}" "" "${PROJECT_FILE_DESCRIPTION}"
    WriteRegStr HKLM "Software\Classes\${PROJECT_FILE_PROGID}\DefaultIcon" "" "$INSTDIR\inst.ico"
    WriteRegStr HKLM "Software\Classes\${PROJECT_FILE_PROGID}\shell\open\command" "" '"$INSTDIR\${APP_EXE}" "%1"'
    Call RefreshShellFileAssociations

    WriteRegStr HKLM "${UNINSTALL_REG_KEY}" "InstallLocation" "$INSTDIR"
    WriteRegStr HKLM "${UNINSTALL_REG_KEY}" "DisplayName" "Monogatari Assistant"
    WriteRegStr HKLM "${UNINSTALL_REG_KEY}" "DisplayVersion" "${APP_VERSION}"
    WriteRegStr HKLM "${UNINSTALL_REG_KEY}" "Publisher" "Heyairu(2025-2026)"
    WriteRegStr HKLM "${UNINSTALL_REG_KEY}" "UninstallString" "$INSTDIR\Uninstall.exe"
    WriteRegStr HKLM "${UNINSTALL_REG_KEY}" "DisplayIcon" "$INSTDIR\inst.ico"
    WriteRegDWORD HKLM "${UNINSTALL_REG_KEY}" "NoModify" 1
    WriteRegDWORD HKLM "${UNINSTALL_REG_KEY}" "NoRepair" 1
SectionEnd

Section "Uninstall"
    Delete "$DESKTOP\${APP_NAME}.lnk"
    Delete "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk"
    Delete "$SMPROGRAMS\${APP_NAME}\Uninstall ${APP_NAME}.lnk"
    RMDir "$SMPROGRAMS\${APP_NAME}"

    Delete /REBOOTOK "$INSTDIR\LICENSE.txt"
    Delete /REBOOTOK "$INSTDIR\inst.ico"
    Delete /REBOOTOK "$INSTDIR\Uninstall.exe"

    ; 只移除仍指向本程式的副檔名，避免覆蓋使用者後來選擇的預設程式。
    ReadRegStr $0 HKLM "Software\Classes\${PROJECT_FILE_EXTENSION}" ""
    StrCmp $0 "${PROJECT_FILE_PROGID}" 0 +2
    DeleteRegKey HKLM "Software\Classes\${PROJECT_FILE_EXTENSION}"
    DeleteRegKey HKLM "Software\Classes\${PROJECT_FILE_PROGID}"
    Call un.RefreshShellFileAssociations

    DeleteRegKey HKLM "${UNINSTALL_REG_KEY}"
    DeleteRegKey HKCU "${UNINSTALL_REG_KEY}"

    RMDir /r /REBOOTOK "$INSTDIR"
SectionEnd
