import "dart:io";

import "package:flutter/services.dart";

abstract class P2pLanPermissionGateway {
  Future<bool> ensureAccess();
}

class P2pLanPermissionDeniedException implements Exception {
  const P2pLanPermissionDeniedException();

  @override
  String toString() => "Android 已拒絕附近裝置權限；允許後才能開啟或連線至 LAN P2P 服務。";
}

/// Requests Android's temporary local-network permission when it is needed.
///
/// The app currently targets SDK 36. Android 16 only enforces this permission
/// when Local Network Protection is enabled for testing. SDK 36 and lower keep
/// implicit LAN access through INTERNET on other Android versions.
class PlatformP2pLanPermissionGateway implements P2pLanPermissionGateway {
  static const MethodChannel _channel = MethodChannel(
    "com.heyairu.monogatari_assistant/p2p",
  );

  @override
  Future<bool> ensureAccess() async {
    if (!Platform.isAndroid) return true;

    try {
      return await _channel.invokeMethod<bool>(
            "ensureLocalNetworkPermission",
          ) ??
          false;
    } on MissingPluginException {
      throw StateError("Android 本機網路權限通道尚未註冊，請完整重啟應用程式。");
    } on PlatformException catch (error) {
      final message = error.message?.trim();
      throw StateError(
        message == null || message.isEmpty ? "無法取得 Android 本機網路權限。" : message,
      );
    }
  }
}
