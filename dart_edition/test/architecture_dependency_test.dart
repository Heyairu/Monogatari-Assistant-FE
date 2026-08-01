import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as path;

void main() {
  test("presentation providers and views have no circular import path", () {
    final lib = Directory("lib");
    final dartFiles = lib
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith(".dart"));
    final importsByFile = <String, Set<String>>{};

    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      final imports = RegExp(r'''^import\s+["']([^"']+)["']''', multiLine: true)
          .allMatches(source)
          .map((match) => match.group(1)!)
          .where(
            (value) =>
                !value.startsWith("dart:") && !value.startsWith("package:"),
          );
      importsByFile[_normalize(file.path)] = imports
          .map((value) => _resolveImport(file, value))
          .toSet();
    }

    final unresolvedImports = <String>[];
    for (final entry in importsByFile.entries) {
      for (final target in entry.value) {
        if (!importsByFile.containsKey(target)) {
          unresolvedImports.add("${entry.key} -> $target");
        }
      }
    }
    expect(
      unresolvedImports,
      isEmpty,
      reason:
          "Architecture graph could not resolve:\n${unresolvedImports.join("\n")}",
    );

    final providers = importsByFile.keys.where(_isProvider);
    final views = importsByFile.keys.where(_isView);
    final cycles = <String>[];
    for (final provider in providers) {
      for (final view in views) {
        if (_isReachable(importsByFile, provider, view, <String>{}) &&
            _isReachable(importsByFile, view, provider, <String>{})) {
          cycles.add("$provider <-> $view");
        }
      }
    }

    expect(cycles, isEmpty, reason: cycles.join("\n"));
  });

  test("domain layer does not import data, bin, modules, or presentation", () {
    final violations = <String>[];
    for (final file
        in Directory("lib/domain")
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith(".dart"))) {
      final source = file.readAsStringSync();
      for (final match in RegExp(
        r'''^import\s+["']([^"']+)["']''',
        multiLine: true,
      ).allMatches(source)) {
        final value = match.group(1)!;
        if (value.contains("/data/") ||
            value.contains("/bin/") ||
            value.contains("/modules/") ||
            value.contains("/presentation/")) {
          violations.add("${file.path}: $value");
        }
      }
    }
    expect(violations, isEmpty, reason: violations.join("\n"));
  });
}

String _resolveImport(File source, String importPath) {
  final resolved = File(
    "${source.parent.path}${Platform.pathSeparator}$importPath",
  ).absolute.path;
  return _normalize(resolved);
}

String _normalize(String value) {
  return path.normalize(path.absolute(value)).replaceAll("\\", "/");
}

bool _isProvider(String path) => path.contains("/presentation/providers/");

bool _isView(String path) =>
    path.contains("/modules/") && path.toLowerCase().endsWith("view.dart");

bool _isReachable(
  Map<String, Set<String>> graph,
  String current,
  String target,
  Set<String> visited,
) {
  if (current == target) return true;
  if (!visited.add(current)) return false;
  for (final next in graph[current] ?? const <String>{}) {
    if (_isReachable(graph, next, target, visited)) return true;
  }
  return false;
}
