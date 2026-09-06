import "dart:convert";
import "dart:ffi";
import "dart:io";

import "package:ffi/ffi.dart";
import "package:path/path.dart" as path;

import "rhodanthe_protocol.dart";

final class RhodantheNativeLoadException implements Exception {
  final String message;
  final Object? cause;

  const RhodantheNativeLoadException(this.message, [this.cause]);

  @override
  String toString() => cause == null
      ? "RhodantheNativeLoadException: $message"
      : "RhodantheNativeLoadException: $message ($cause)";
}

final class _RhodantheHandle extends Opaque {}

final class _RhodantheBuffer extends Struct {
  external Pointer<Uint8> data;

  @UintPtr()
  external int len;

  @UintPtr()
  external int capacity;
}

typedef _AbiVersionNative = Uint32 Function();
typedef _AbiVersionDart = int Function();
typedef _EngineNewNative = Pointer<_RhodantheHandle> Function();
typedef _EngineNewDart = Pointer<_RhodantheHandle> Function();
typedef _EngineFreeNative = Void Function(Pointer<_RhodantheHandle>);
typedef _EngineFreeDart = void Function(Pointer<_RhodantheHandle>);
typedef _EngineRequestNative =
    _RhodantheBuffer Function(
      Pointer<_RhodantheHandle>,
      Pointer<Uint8>,
      UintPtr,
    );
typedef _EngineRequestDart =
    _RhodantheBuffer Function(Pointer<_RhodantheHandle>, Pointer<Uint8>, int);
typedef _BufferFreeNative = Void Function(_RhodantheBuffer);
typedef _BufferFreeDart = void Function(_RhodantheBuffer);

final class _Bindings {
  final _AbiVersionDart abiVersion;
  final _EngineNewDart engineNew;
  final _EngineFreeDart engineFree;
  final _EngineRequestDart engineRequest;
  final _BufferFreeDart bufferFree;

  _Bindings(DynamicLibrary library)
    : abiVersion = library.lookupFunction<_AbiVersionNative, _AbiVersionDart>(
        "rhodanthe_abi_version",
      ),
      engineNew = library.lookupFunction<_EngineNewNative, _EngineNewDart>(
        "rhodanthe_engine_new",
      ),
      engineFree = library.lookupFunction<_EngineFreeNative, _EngineFreeDart>(
        "rhodanthe_engine_free",
      ),
      engineRequest = library
          .lookupFunction<_EngineRequestNative, _EngineRequestDart>(
            "rhodanthe_engine_request",
          ),
      bufferFree = library.lookupFunction<_BufferFreeNative, _BufferFreeDart>(
        "rhodanthe_buffer_free",
      );
}

final class RhodantheNativeClient {
  final _Bindings _bindings;
  Pointer<_RhodantheHandle> _handle;
  bool _disposed = false;

  RhodantheNativeClient._(this._bindings, this._handle);

  static bool get isSupported =>
      Platform.isWindows ||
      Platform.isLinux ||
      Platform.isMacOS ||
      Platform.isAndroid ||
      Platform.isIOS;

  static RhodantheNativeClient open({String? libraryPath}) {
    if (!isSupported) {
      throw const RhodantheNativeLoadException(
        "Rhodanthe native bridge is unavailable on this platform",
      );
    }
    try {
      final library = _openLibrary(libraryPath);
      final bindings = _Bindings(library);
      final abiVersion = bindings.abiVersion();
      if (abiVersion != rhodantheAbiVersion) {
        throw RhodantheNativeLoadException(
          "Rhodanthe ABI $abiVersion does not match $rhodantheAbiVersion",
        );
      }
      final handle = bindings.engineNew();
      if (handle == nullptr) {
        throw const RhodantheNativeLoadException(
          "Rhodanthe engine allocation failed",
        );
      }
      return RhodantheNativeClient._(bindings, handle);
    } on RhodantheNativeLoadException {
      rethrow;
    } catch (error) {
      throw RhodantheNativeLoadException(
        "Unable to load the Rhodanthe native bridge",
        error,
      );
    }
  }

  int get abiVersion {
    _ensureOpen();
    return _bindings.abiVersion();
  }

  RhodantheResponse sendSync(RhodantheRequest request) {
    return RhodantheResponse.decode(sendEncodedSync(request.encode()));
  }

  String sendEncodedSync(String encodedRequest) {
    _ensureOpen();
    final bytes = utf8.encode(encodedRequest);
    final Pointer<Uint8> input = bytes.isEmpty
        ? nullptr
        : malloc<Uint8>(bytes.length);
    if (bytes.isNotEmpty) {
      input.asTypedList(bytes.length).setAll(0, bytes);
    }

    _RhodantheBuffer output;
    try {
      output = _bindings.engineRequest(_handle, input, bytes.length);
    } finally {
      if (input != nullptr) malloc.free(input);
    }
    if (output.data == nullptr) {
      throw const RhodantheNativeLoadException(
        "Rhodanthe returned a null response buffer",
      );
    }
    try {
      final responseBytes = List<int>.of(
        output.data.asTypedList(output.len),
        growable: false,
      );
      return utf8.decode(responseBytes);
    } finally {
      _bindings.bufferFree(output);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _bindings.engineFree(_handle);
    _handle = nullptr;
  }

  void _ensureOpen() {
    if (_disposed) throw StateError("Rhodanthe native bridge is closed");
  }
}

DynamicLibrary _openLibrary(String? explicitPath) {
  if (explicitPath != null) return DynamicLibrary.open(explicitPath);
  if (Platform.isIOS) return DynamicLibrary.process();

  final fileName = switch (Platform.operatingSystem) {
    "windows" => "rhodanthe_bridge.dll",
    "macos" => "librhodanthe_bridge.dylib",
    _ => "librhodanthe_bridge.so",
  };
  final candidates = <String>{
    path.join(File(Platform.resolvedExecutable).parent.path, fileName),
    path.join(File(Platform.resolvedExecutable).parent.path, "lib", fileName),
    path.join(
      File(Platform.resolvedExecutable).parent.parent.path,
      "Frameworks",
      fileName,
    ),
    path.join(Directory.current.path, fileName),
    path.join(Directory.current.path, "rust", "target", "release", fileName),
    path.join(
      Directory.current.path,
      "dart_edition",
      "rust",
      "target",
      "release",
      fileName,
    ),
  };
  Object? lastError;
  for (final candidate in candidates) {
    if (!File(candidate).existsSync()) continue;
    try {
      return DynamicLibrary.open(candidate);
    } catch (error) {
      lastError = error;
    }
  }
  try {
    return DynamicLibrary.open(fileName);
  } catch (error) {
    throw RhodantheNativeLoadException(
      "Could not find $fileName in the executable or development directories",
      lastError ?? error,
    );
  }
}
