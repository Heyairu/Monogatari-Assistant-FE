[CmdletBinding()]
param(
    [ValidateSet('Export', 'Import')]
    [string]$Mode = 'Export',

    [string]$ManifestPath = (Join-Path $PSScriptRoot 'winget-apps.json'),

    [switch]$IncludeUnknown,

    [switch]$AcceptSourceAgreements
)

$ErrorActionPreference = 'Stop'

function Assert-WingetAvailable {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw '找不到 winget。請先安裝或更新 App Installer（Microsoft.DesktopAppInstaller）。'
    }
}

function Invoke-Winget {
    param([Parameter(Mandatory)][string[]]$Arguments)

    & winget.exe @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "winget 執行失敗，結束碼：$LASTEXITCODE"
    }
}

Assert-WingetAvailable

$manifestDirectory = Split-Path -Parent $ManifestPath
if ($manifestDirectory -and -not (Test-Path -LiteralPath $manifestDirectory)) {
    New-Item -ItemType Directory -Path $manifestDirectory -Force | Out-Null
}

if ($Mode -eq 'Export') {
    $exportArguments = @('export', '--output', $ManifestPath, '--accept-source-agreements')
    if ($IncludeUnknown) {
        $exportArguments += '--include-unknown'
    }

    Write-Host "正在匯出已安裝軟體清單至：$ManifestPath" -ForegroundColor Cyan
    Invoke-Winget -Arguments $exportArguments
    Write-Host '匯出完成。請將 winget-apps.json 複製到重置後的電腦。' -ForegroundColor Green
    exit 0
}

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "找不到清單檔案：$ManifestPath。請先在重置前執行 -Mode Export。"
}

$importArguments = @(
    'import',
    '--import-file', $ManifestPath,
    '--accept-package-agreements'
)

if ($AcceptSourceAgreements) {
    $importArguments += '--accept-source-agreements'
}

Write-Host '即將依照清單安裝軟體。部分套件可能需要管理員權限，且可能會顯示 UAC 提示。' -ForegroundColor Yellow
Invoke-Winget -Arguments $importArguments
Write-Host '還原完成。建議重新開機後檢查常用軟體。' -ForegroundColor Green
