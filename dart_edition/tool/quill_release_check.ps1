param(
    [string]$FlutterCommand = "flutter",
    [switch]$SkipFullSuite,
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    # The repository accepts existing info-level lints. Warnings and errors
    # remain release blockers.
    & $FlutterCommand analyze --no-fatal-infos
    if ($LASTEXITCODE -ne 0) { throw "flutter analyze failed" }

    $focusedTests = @(
        "test/plain_text_quill_adapter_test.dart",
        "test/plain_text_quill_editor_poc_test.dart",
        "test/editor_text_box_quill_integration_test.dart",
        "test/editor_text_box_mosaic_clipboard_test.dart",
        "test/editor_text_box_mosaic_intellisense_test.dart",
        "test/project_xml_parser_test.dart",
        "test/xml_text_codec_test.dart",
        "test/providers/project_io_status_test.dart",
        "test/collaboration_text_crdt_test.dart",
        "test/collaboration_protocol_test.dart",
        "test/providers/editor_coordinator_sync_test.dart",
        "test/project_history_provider_test.dart"
    )
    & $FlutterCommand test @focusedTests --timeout 30s
    if ($LASTEXITCODE -ne 0) { throw "Quill focused tests failed" }

    if (-not $SkipFullSuite) {
        & $FlutterCommand test --timeout 30s
        if ($LASTEXITCODE -ne 0) { throw "full Flutter test suite failed" }
    }

    if (-not $SkipBuild) {
        & $FlutterCommand build windows --debug
        if ($LASTEXITCODE -ne 0) { throw "Windows debug build failed" }
    }
    Write-Host "Plain-text Quill release checks passed." -ForegroundColor Green
} finally {
    Pop-Location
}
