import "dart:convert";
import "dart:io";

import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_editor_session.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_rollout_audit.dart";

Future<void> main(List<String> arguments) async {
  try {
    final inputPath = _argument(arguments, "--input");
    final expectedBuildId = _argument(arguments, "--expected-build-id");
    final currentMode = _mode(_argument(arguments, "--current-mode"));
    final requiredMode = _mode(_argument(arguments, "--require-mode"));
    if (inputPath == null ||
        expectedBuildId == null ||
        currentMode == null ||
        requiredMode == null) {
      stderr.writeln(
        "Usage: dart run tool/check_rhodanthe_rollout.dart "
        "--input <audit.json> --expected-build-id <id> "
        "--current-mode <shadow|searchCanary|full> "
        "--require-mode <shadow|searchCanary|full>",
      );
      exitCode = 64;
      return;
    }
    final decoded = jsonDecode(await File(inputPath).readAsString());
    if (decoded is! Map) {
      throw const FormatException("audit report must be a JSON object");
    }
    final result = checkRhodantheRolloutAudit(
      report: Map<String, Object?>.from(decoded),
      expectedBuildId: expectedBuildId,
      currentMode: currentMode,
      requiredRecommendation: requiredMode,
    );
    stdout.writeln(jsonEncode(result.toJson()));
    if (!result.ok) exitCode = 1;
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 65;
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    exitCode = 66;
  }
}

String? _argument(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index < 0 || index + 1 >= arguments.length) return null;
  return arguments[index + 1];
}

RhodantheRolloutMode? _mode(String? value) {
  if (value == null) return null;
  final normalized = value == "search" ? "searchCanary" : value;
  try {
    final mode = RhodantheRolloutMode.values.byName(normalized);
    return mode == RhodantheRolloutMode.disabled ? null : mode;
  } on ArgumentError {
    return null;
  }
}
