#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"
flutter_bin="${FLUTTER_BIN:-flutter}"

# The repository currently has an accepted backlog of info-level lints.
# Release validation still fails on analyzer warnings and errors.
"$flutter_bin" analyze --no-fatal-infos
"$flutter_bin" test \
  test/mcp_phase0_baseline_test.dart \
  test/mcp_phase2_adapter_test.dart \
  test/mcp_phase2_protocol_test.dart \
  test/mcp_phase3_bridge_test.dart \
  test/mcp_host_configuration_test.dart \
  test/mcp_phase4_plan_validation_test.dart \
  test/mcp_phase5_security_test.dart \
  test/copilot_models_test.dart \
  test/copilot_project_context_builder_test.dart

if [[ "${MCP_SKIP_FULL_SUITE:-0}" != "1" ]]; then
  "$flutter_bin" test
fi

if grep -REn 'Bearer [A-Za-z0-9_-]{24,}|bootstrapToken[[:space:]]*[:=][[:space:]]*["'"'][A-Za-z0-9_-]{24,}["'"']|0\.0\.0\.0' lib/features/mcp bin/monoashi_mcp.dart; then
  echo "MCP secret/listener scan failed" >&2
  exit 1
fi

if [[ "${MCP_SKIP_BUILD:-0}" != "1" ]]; then
  "$flutter_bin" pub run tool/build_mcp_sidecar.dart
fi
echo "MonoAshi MCP release checks passed."
