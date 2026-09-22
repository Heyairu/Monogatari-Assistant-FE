param(
    [string]$FlutterCommand = "flutter",
    [switch]$SkipFullSuite,
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    # The repository currently has an accepted backlog of info-level lints.
    # Release validation still fails on analyzer warnings and errors.
    & $FlutterCommand analyze --no-fatal-infos
    if ($LASTEXITCODE -ne 0) { throw "flutter analyze failed" }

    $focusedTests = @(
        "test/mcp_phase0_baseline_test.dart",
        "test/mcp_phase2_adapter_test.dart",
        "test/mcp_phase2_protocol_test.dart",
        "test/mcp_phase3_bridge_test.dart",
        "test/mcp_host_configuration_test.dart",
        "test/mcp_phase4_plan_validation_test.dart",
        "test/mcp_phase5_security_test.dart",
        "test/copilot_models_test.dart",
        "test/copilot_project_context_builder_test.dart"
    )
    & $FlutterCommand test @focusedTests
    if ($LASTEXITCODE -ne 0) { throw "MCP focused tests failed" }

    if (-not $SkipFullSuite) {
        & $FlutterCommand test
        if ($LASTEXITCODE -ne 0) { throw "full Flutter test suite failed" }
    }

    $forbidden = @(
        'Bearer [A-Za-z0-9_-]{24,}',
        'bootstrapToken\s*[:=]\s*["''][A-Za-z0-9_-]{24,}["'']',
        '0\.0\.0\.0'
    )
    $sources = Get-ChildItem lib/features/mcp,bin/monoashi_mcp.dart -Recurse -File
    foreach ($pattern in $forbidden) {
        $match = $sources | Select-String -Pattern $pattern
        if ($match) { throw "MCP secret/listener scan failed for pattern: $pattern" }
    }

    if (-not $SkipBuild) {
        & $FlutterCommand pub run tool/build_mcp_sidecar.dart
        if ($LASTEXITCODE -ne 0) { throw "sidecar build failed" }
    }
    Write-Host "MonoAshi MCP release checks passed." -ForegroundColor Green
} finally {
    Pop-Location
}
