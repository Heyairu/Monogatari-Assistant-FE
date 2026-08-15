import "dart:async";
import "dart:collection";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter/services.dart";

/// Delivers `.mnproj` paths supplied while a desktop app is being opened.
///
/// Desktop runners hold paths until Dart asks for them. macOS additionally
/// delivers Finder open-document events after startup. The queue keeps either
/// source safe until the editor has finished initializing.
class DesktopProjectLaunch {
  DesktopProjectLaunch._();

  static const _channel = MethodChannel(
    "com.heyairu.monogatari_assistant/file",
  );
  static final Queue<String> _pendingPaths = Queue<String>();
  static FutureOr<void> Function(String path)? _onProjectRequested;
  static bool _initialized = false;

  static bool get _isSupportedDesktopPlatform =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /// Starts receiving native open-document events and captures startup args.
  static Future<void> initialize() async {
    if (_initialized || !_isSupportedDesktopPlatform) {
      return;
    }
    _initialized = true;

    if (Platform.isWindows || Platform.isMacOS) {
      if (Platform.isMacOS) {
        _channel.setMethodCallHandler((call) async {
          if (call.method != "openProjectFile") {
            throw MissingPluginException("Unsupported method: ${call.method}");
          }
          final rawPath = call.arguments;
          if (rawPath is String) {
            _enqueue(rawPath);
          }
        });
      }

      final pending = await _channel.invokeMethod<List<dynamic>>(
        "takePendingProjectFiles",
      );
      for (final rawPath in pending ?? const <dynamic>[]) {
        if (rawPath is String) {
          _enqueue(rawPath);
        }
      }
    }

    if (Platform.isLinux) {
      for (final argument in Platform.executableArguments) {
        _enqueue(argument);
      }
    }
  }

  /// Connects the initialized editor to queued and future open requests.
  static void bind(FutureOr<void> Function(String path) onProjectRequested) {
    _onProjectRequested = onProjectRequested;
    _drain();
  }

  static void unbind() => _onProjectRequested = null;

  static void _enqueue(String candidate) {
    final path = candidate.trim();
    if (!_isProjectPath(path)) {
      return;
    }
    _pendingPaths.add(path);
    _drain();
  }

  static bool _isProjectPath(String path) =>
      path.toLowerCase().endsWith(".mnproj");

  static void _drain() {
    final handler = _onProjectRequested;
    if (handler == null || _pendingPaths.isEmpty) {
      return;
    }

    final path = _pendingPaths.removeFirst();
    unawaited(Future<void>.sync(() => handler(path)).whenComplete(_drain));
  }
}
