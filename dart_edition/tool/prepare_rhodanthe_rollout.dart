import "dart:convert";
import "dart:io";

import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_editor_session.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_release_plan.dart";

Future<void> main(List<String> arguments) async {
  try {
    final stage = _stage(_argument(arguments, "--stage"));
    final targetBuildId = _argument(arguments, "--target-build-id");
    final platform = RhodantheBuildPlatform.tryParse(
      _argument(arguments, "--platform") ?? "windows",
    );
    final buildMode = _buildMode(
      _argument(arguments, "--build-mode") ?? "profile",
    );
    final canaryPercent = _optionalIntArgument(arguments, "--canary-percent");
    if (stage == null ||
        targetBuildId == null ||
        platform == null ||
        buildMode == null) {
      _usage();
      exitCode = 64;
      return;
    }

    final evidencePath = _argument(arguments, "--evidence");
    final sourceBuildId = _argument(arguments, "--source-build-id");
    Map<String, Object?>? evidence;
    if (evidencePath != null) {
      final decoded = jsonDecode(await File(evidencePath).readAsString());
      if (decoded is! Map) {
        throw const FormatException("evidence must be a JSON object");
      }
      evidence = Map<String, Object?>.from(decoded);
    }

    final preparation = prepareRhodantheRollout(
      stage: stage,
      targetBuildId: targetBuildId,
      platform: platform,
      buildMode: buildMode,
      canaryPercent: canaryPercent,
      evidenceReport: evidence,
      sourceBuildId: sourceBuildId,
    );
    if (!preparation.approved) {
      stdout.writeln(jsonEncode(preparation.toJson()));
      exitCode = 1;
      return;
    }
    final receiptPath = _argument(arguments, "--receipt");
    if (receiptPath != null) {
      final receipt = RhodantheRolloutReceipt(
        generatedAt: DateTime.now(),
        preparation: preparation,
        sourceEvidence: evidence,
      );
      final receiptFile = File(receiptPath);
      await receiptFile.parent.create(recursive: true);
      await receiptFile.writeAsString(
        const JsonEncoder.withIndent("  ").convert(receipt.toJson()),
      );
    }
    stdout.writeln(
      jsonEncode(<String, Object?>{
        ...preparation.toJson(),
        if (receiptPath != null) "receiptPath": receiptPath,
      }),
    );
    if (!arguments.contains("--execute")) return;

    final flutterExecutable =
        _argument(arguments, "--flutter") ??
        (Platform.isWindows ? "flutter.bat" : "flutter");
    final process = await Process.start(
      flutterExecutable,
      preparation.flutterArguments,
      mode: ProcessStartMode.inheritStdio,
      runInShell: Platform.isWindows,
    );
    exitCode = await process.exitCode;
  } on ArgumentError catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 65;
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    exitCode = 66;
  } on ProcessException catch (error) {
    stderr.writeln(error.message);
    exitCode = 69;
  }
}

void _usage() {
  stderr.writeln(
    "Usage: dart run tool/prepare_rhodanthe_rollout.dart "
    "--stage <shadow|search|full|default-on> "
    "--target-build-id <id> "
    "[--platform <windows|linux|macos|apk|appbundle|ios>] "
    "[--build-mode <profile|release>] "
    "[--canary-percent <1..100>] "
    "[--evidence <audit.json> --source-build-id <id>] "
    "[--receipt <release-receipt.json>] "
    "[--execute] [--flutter <path>]",
  );
}

String? _argument(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index < 0 || index + 1 >= arguments.length) return null;
  return arguments[index + 1];
}

int? _optionalIntArgument(List<String> arguments, String name) {
  final source = _argument(arguments, name);
  if (source == null) return null;
  final value = int.tryParse(source);
  if (value == null) throw ArgumentError("$name must be an integer");
  return value;
}

RhodantheReleaseStage? _stage(String? value) => switch (value) {
  "shadow" => RhodantheReleaseStage.shadow,
  "search" || "searchCanary" => RhodantheReleaseStage.searchCanary,
  "full" || "fullCanary" => RhodantheReleaseStage.fullCanary,
  "default-on" || "defaultOn" => RhodantheReleaseStage.defaultOn,
  _ => null,
};

RhodantheBuildMode? _buildMode(String value) => switch (value) {
  "profile" => RhodantheBuildMode.profile,
  "release" => RhodantheBuildMode.release,
  _ => null,
};
