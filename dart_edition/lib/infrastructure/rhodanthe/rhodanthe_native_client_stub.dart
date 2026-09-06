import "rhodanthe_protocol.dart";

final class RhodantheNativeLoadException implements Exception {
  final String message;

  const RhodantheNativeLoadException(this.message);

  @override
  String toString() => "RhodantheNativeLoadException: $message";
}

final class RhodantheNativeClient {
  RhodantheNativeClient._();

  static bool get isSupported => false;

  static RhodantheNativeClient open({String? libraryPath}) {
    throw const RhodantheNativeLoadException(
      "Rhodanthe native bridge is unavailable on this platform",
    );
  }

  int get abiVersion => throw StateError("Rhodanthe native bridge is closed");

  RhodantheResponse sendSync(RhodantheRequest request) {
    throw StateError("Rhodanthe native bridge is unavailable");
  }

  String sendEncodedSync(String encodedRequest) {
    throw StateError("Rhodanthe native bridge is unavailable");
  }

  void dispose() {}
}
