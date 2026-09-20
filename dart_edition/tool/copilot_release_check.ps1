[CmdletBinding()]
param(
    [ValidateSet("default", "ask", "internal")]
    [string]$Variant = "internal",
    [string]$FlutterCommand = "flutter",
    [switch]$SkipFullTests,
    [switch]$SkipBuild,
    [switch]$AllowDirty
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$releaseRoot = Join-Path $projectRoot "build\windows\x64\runner\Release"
$evidenceRoot = Join-Path $projectRoot "build\copilot-release-evidence"
$secretPattern = "(?:sk-[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{20,}|xox[baprs]-[0-9A-Za-z-]{10,})"

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Command
    )

    Write-Host "`n==> $Label" -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [System.IO.Path]::GetRelativePath($BasePath, $Path).Replace("\", "/")
}

function Test-FileForSecretPattern {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [switch]$Binary
    )

    try {
        $content = if ($Binary) {
            [System.Text.Encoding]::Latin1.GetString(
                [System.IO.File]::ReadAllBytes($Path)
            )
        } else {
            [System.IO.File]::ReadAllText($Path)
        }
        return [regex]::IsMatch($content, $secretPattern)
    } catch {
        throw "Unable to scan '$Path': $($_.Exception.Message)"
    }
}

Push-Location $projectRoot
try {
    Invoke-CheckedCommand "Resolve git revision" {
        $script:gitCommit = (& git rev-parse HEAD).Trim()
    }
    $gitStatus = (& git status --porcelain=v1 | Out-String).Trim()
    $isDirty = $gitStatus.Length -gt 0
    if ($isDirty -and -not $AllowDirty) {
        throw "Working tree is dirty. Commit or stash changes, or use -AllowDirty for a non-release rehearsal."
    }

    Invoke-CheckedCommand "Read Flutter version" {
        $script:flutterVersion = (& $FlutterCommand --version 2>&1 | Out-String).Trim()
    }

    $copilotTestFiles = @(
        Get-ChildItem -LiteralPath (Join-Path $projectRoot "test") `
            -Filter "copilot*_test.dart" |
            Sort-Object FullName |
            ForEach-Object { $_.FullName }
    )
    if ($copilotTestFiles.Count -eq 0) {
        throw "No Copilot tests were found."
    }

    $analyzeTargets = @(
        "lib\modules\copliot.dart",
        "lib\features\copilot"
    ) + $copilotTestFiles
    Invoke-CheckedCommand "Analyze Copilot sources and tests" {
        & $FlutterCommand analyze @analyzeTargets
    }
    Invoke-CheckedCommand "Run Copilot tests" {
        & $FlutterCommand test @copilotTestFiles --reporter compact
    }

    $fullTestsRan = -not $SkipFullTests
    if ($fullTestsRan) {
        Invoke-CheckedCommand "Run full Flutter test suite" {
            & $FlutterCommand test --reporter compact
        }
    }

    $defines = switch ($Variant) {
        "default" {
            @(
                "--dart-define=COPILOT_ASK_ENABLED=false",
                "--dart-define=COPILOT_PLAN_ENABLED=false"
            )
        }
        "ask" {
            @(
                "--dart-define=COPILOT_ASK_ENABLED=true",
                "--dart-define=COPILOT_PLAN_ENABLED=false"
            )
        }
        "internal" {
            @(
                "--dart-define=COPILOT_ASK_ENABLED=true",
                "--dart-define=COPILOT_PLAN_ENABLED=true"
            )
        }
    }

    $buildRan = -not $SkipBuild
    if ($buildRan) {
        Invoke-CheckedCommand "Build Windows $Variant release" {
            & $FlutterCommand build windows --release @defines
        }
    }
    if (-not (Test-Path -LiteralPath $releaseRoot -PathType Container)) {
        throw "Windows release artifact is missing at '$releaseRoot'."
    }

    Write-Host "`n==> Scan repository and artifact for provider key patterns" -ForegroundColor Cyan
    $sourceExtensions = @(
        ".c", ".cc", ".cmake", ".cpp", ".dart", ".entitlements", ".gradle",
        ".h", ".java", ".json", ".kt", ".md", ".plist", ".properties",
        ".ps1", ".sh", ".swift", ".txt", ".xml", ".yaml", ".yml"
    )
    $trackedAndUntracked = @(
        & git ls-files --cached --others --exclude-standard
    ) | Where-Object { $_ }
    $sourceSecretFiles = @()
    foreach ($relativePath in $trackedAndUntracked) {
        $extension = [System.IO.Path]::GetExtension($relativePath).ToLowerInvariant()
        $fileName = [System.IO.Path]::GetFileName($relativePath)
        if ($extension -notin $sourceExtensions -and $fileName -ne "pubspec.lock") {
            continue
        }
        $absolutePath = Join-Path $projectRoot $relativePath
        if ((Test-Path -LiteralPath $absolutePath -PathType Leaf) -and
            (Test-FileForSecretPattern -Path $absolutePath)) {
            $sourceSecretFiles += $relativePath
        }
    }

    $artifactFiles = @(
        Get-ChildItem -LiteralPath $releaseRoot -Recurse -File | Sort-Object FullName
    )
    $artifactSecretFiles = @()
    foreach ($file in $artifactFiles) {
        if (Test-FileForSecretPattern -Path $file.FullName -Binary) {
            $artifactSecretFiles += Get-RelativePath -BasePath $releaseRoot -Path $file.FullName
        }
    }
    if ($sourceSecretFiles.Count -gt 0 -or $artifactSecretFiles.Count -gt 0) {
        $affectedFiles = @($sourceSecretFiles + $artifactSecretFiles) -join ", "
        throw "Secret pattern scan failed. Affected files: $affectedFiles"
    }

    $artifactManifest = @(
        foreach ($file in $artifactFiles) {
            [ordered]@{
                path = Get-RelativePath -BasePath $releaseRoot -Path $file.FullName
                length = $file.Length
                sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash
            }
        }
    )
    $appSo = $artifactManifest | Where-Object { $_.path -eq "data/app.so" }
    if ($null -eq $appSo) {
        throw "The Windows Dart AOT artifact data/app.so is missing."
    }

    New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null
    $timestamp = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ")
    $evidencePath = Join-Path $evidenceRoot "copilot-$Variant-$timestamp.json"
    $evidence = [ordered]@{
        schemaVersion = 1
        generatedAtUtc = [DateTime]::UtcNow.ToString("o")
        variant = $Variant
        dartDefines = $defines
        gitCommit = $gitCommit
        dirtyWorktree = $isDirty
        releaseEligible = (-not $isDirty) -and $fullTestsRan -and $buildRan
        flutterVersion = $flutterVersion
        copilotTestFileCount = $copilotTestFiles.Count
        fullTestsRan = $fullTestsRan
        buildRan = $buildRan
        endpointAuthorizationGate = "per-host-dialog"
        endpointSmokeTestRequired = $false
        secretPatternScanPassed = $true
        appSoSha256 = $appSo.sha256
        artifacts = $artifactManifest
    }
    $evidence | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $evidencePath -Encoding utf8

    Write-Host "`nCopilot release check passed." -ForegroundColor Green
    Write-Host "Variant: $Variant"
    Write-Host "Release eligible: $($evidence.releaseEligible)"
    Write-Host "Dart AOT SHA-256: $($appSo.sha256)"
    Write-Host "Evidence: $evidencePath"
} finally {
    Pop-Location
}
