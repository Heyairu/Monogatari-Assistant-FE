import "dart:async";
import "dart:collection";
import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter/services.dart";

/// Delivers `.mnproj` paths supplied while a desktop app is being opened.
///
/// Native runners hold startup files until Dart asks for them. macOS and
/// Android additionally deliver open-document events after startup.
class DesktopProjectLaunch {
  DesktopProjectLaunch._();

  static const _projectPayloadPrefix = "MNPROJ_PAYLOAD::";
  static const _channel = MethodChannel(
    "com.heyairu.monogatari_assistant/file",
  );
  static final Queue<String> _pendingPaths = Queue<String>();
  static FutureOr<void> Function(String path)? _onProjectRequested;
  static bool _initialized = false;

  static bool get _isSupportedDesktopPlatform =>
      !kIsWeb &&
      (Platform.isWindows ||
          Platform.isLinux ||
          Platform.isMacOS ||
          Platform.isAndroid);

  /// Starts receiving native open-document events and captures startup args.
  static Future<void> initialize({
    Iterable<String> startupArguments = const <String>[],
  }) async {
    if (_initialized || !_isSupportedDesktopPlatform) {
      return;
    }
    _initialized = true;

    if (Platform.isWindows || Platform.isMacOS || Platform.isAndroid) {
      if (Platform.isMacOS || Platform.isAndroid) {
        _channel.setMethodCallHandler((call) async {
          if (call.method != "openProjectFile") {
            throw MissingPluginException("Unsupported method: ${call.method}");
          }
          _enqueueNativeArgument(call.arguments);
        });
      }

      final pending = await _channel.invokeMethod<List<dynamic>>(
        "takePendingProjectFiles",
      );
      for (final rawProjectFile in pending ?? const <dynamic>[]) {
        _enqueueNativeArgument(rawProjectFile);
      }
    }

    if (Platform.isLinux) {
      // The Linux runner supplies these through
      // fl_dart_project_set_dart_entrypoint_arguments. They are arguments to
      // main(), not Dart VM arguments exposed by Platform.executableArguments.
      for (final argument in startupArguments) {
        _enqueue(argument);
      }
    }
  }

  /// Connects the initialized editor to queued and future open requests.
  static void bind(FutureOr<void> Function(String path) onProjectRequested) {
    _onProjectRequested = onProjectRequested;
    if (_initialized && Platform.isMacOS) {
      unawaited(
        _channel
            .invokeMethod<void>("flushPendingProjectFiles")
            .catchError((Object error) {}),
      );
    }
    _drain();
  }

  static void unbind() => _onProjectRequested = null;

  static void _enqueue(String candidate) {
    final path = normalizeProjectArgument(candidate);
    if (!_isProjectPath(path)) {
      return;
    }
    _pendingPaths.add(path);
    _drain();
  }

  /// Converts a file-manager launch argument into a path understood by the
  /// project I/O layer.
  ///
  /// Linux file managers can pass a dropped file as a percent-encoded
  /// `file://` URI instead of a native path. Passing that URI to [File] makes
  /// it look for a literal `file:` directory, so decode it before enqueueing.
  @visibleForTesting
  static String normalizeProjectArgument(String candidate) {
    final argument = candidate.trim();
    final uri = Uri.tryParse(argument);
    if (uri == null || uri.scheme.toLowerCase() != "file") {
      return argument;
    }

    try {
      return uri.toFilePath(windows: Platform.isWindows);
    } on FormatException {
      // Keep the original argument. It will be rejected by _isProjectPath or
      // reported by the normal project-open error path instead of crashing at
      // application startup.
      return argument;
    }
  }

  static void _enqueueNativeArgument(Object? argument) {
    if (argument is String) {
      _enqueue(argument);
      return;
    }
    if (argument is! Map) {
      return;
    }

    final bookmark = argument["bookmark"];
    final path = argument["path"];
    final content = argument["content"];
    final name = argument["name"];
    if (content is String && content.isNotEmpty) {
      _enqueue(
        "$_projectPayloadPrefix${jsonEncode({"name": name is String ? name : null, "path": path is String ? path : null, "bookmark": bookmark is String ? bookmark.trim() : null, "content": content})}",
      );
      return;
    }
    if (bookmark is String && bookmark.trim().isNotEmpty) {
      _enqueue('BKMK::${bookmark.trim()}::PATH::${path is String ? path : ""}');
      return;
    }
    if (path is String) {
      _enqueue(path);
    }
  }

  static bool _isProjectPath(String path) =>
      path.toLowerCase().endsWith(".mnproj") ||
      path.startsWith('BKMK::') ||
      path.startsWith(_projectPayloadPrefix) ||
      (Platform.isAndroid &&
          (path.startsWith("content://") || path.startsWith("file://")));

  static void _drain() {
    final handler = _onProjectRequested;
    if (handler == null || _pendingPaths.isEmpty) {
      return;
    }

    final path = _pendingPaths.removeFirst();
    unawaited(Future<void>.sync(() => handler(path)).whenComplete(_drain));
  }
}
