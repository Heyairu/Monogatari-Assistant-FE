import "dart:io";

import "package:flutter/services.dart";

enum P2pAndroidProbeFailure { noLocalNetwork, connect, response, incompatible }

class P2pAndroidProbeException implements Exception {
  final P2pAndroidProbeFailure failure;
  final String message;

  const P2pAndroidProbeException({
    required this.failure,
    required this.message,
  });

  @override
  String toString() => message;
}

abstract class P2pAndroidProbeGateway {
  bool get isSupported;

  Future<void> probe({
    required String host,
    required int port,
    required Duration connectTimeout,
    required Duration readTimeout,
  });

  Future<String> exchangeLine({
    required String host,
    required int port,
    required String requestLine,
    required int maxResponseBytes,
    required Duration connectTimeout,
    required Duration readTimeout,
  });

  Future<List<String>> exchangeLines({
    required String host,
    required int port,
    required List<String> requestLines,
    required int maxResponseBytes,
    required Duration connectTimeout,
    required Duration readTimeout,
  });
}

/// Uses Android's `Network.bindSocket` through a platform channel so the
/// outbound P2P probe is pinned to Wi-Fi/Ethernet instead of a VPN or cellular
/// default route. The binding applies only to this socket.
class MethodChannelP2pAndroidProbeGateway implements P2pAndroidProbeGateway {
  static const MethodChannel _channel = MethodChannel(
    "com.heyairu.monogatari_assistant/p2p",
  );

  @override
  bool get isSupported => Platform.isAndroid;

  @override
  Future<void> probe({
    required String host,
    required int port,
    required Duration connectTimeout,
    required Duration readTimeout,
  }) async {
    if (!isSupported) {
      throw const P2pAndroidProbeException(
        failure: P2pAndroidProbeFailure.noLocalNetwork,
        message: "Android Wi-Fi probe is unavailable on this platform.",
      );
    }

    try {
      await _channel.invokeMethod<bool>("probeWifiEndpoint", <String, Object>{
        "host": host,
        "port": port,
        "connectTimeoutMillis": connectTimeout.inMilliseconds,
        "readTimeoutMillis": readTimeout.inMilliseconds,
      });
    } on MissingPluginException {
      throw const P2pAndroidProbeException(
        failure: P2pAndroidProbeFailure.noLocalNetwork,
        message: "Android Wi-Fi probe 尚未註冊，請完整重啟並重新安裝應用程式。",
      );
    } on PlatformException catch (error) {
      final failure = switch (error.code) {
        "NO_LOCAL_NETWORK" => P2pAndroidProbeFailure.noLocalNetwork,
        "RESPONSE_TIMEOUT" ||
        "RESPONSE_FAILED" => P2pAndroidProbeFailure.response,
        "INCOMPATIBLE_ENDPOINT" => P2pAndroidProbeFailure.incompatible,
        _ => P2pAndroidProbeFailure.connect,
      };
      final message = switch (failure) {
        P2pAndroidProbeFailure.noLocalNetwork =>
          "Android 找不到可用的 Wi-Fi／Ethernet 網路。",
        P2pAndroidProbeFailure.connect =>
          "Android 已將 socket 強制綁定 Wi-Fi，但 TCP 仍無法建立（${error.code}）。",
        P2pAndroidProbeFailure.response =>
          "Android 已透過 Wi-Fi 建立 TCP，但對方未完成 probe 回應（${error.code}）。",
        P2pAndroidProbeFailure.incompatible =>
          "Android 已連到目標 Port，但對方不是相容的 P2P 端點。",
      };
      throw P2pAndroidProbeException(failure: failure, message: message);
    }
  }

  @override
  Future<String> exchangeLine({
    required String host,
    required int port,
    required String requestLine,
    required int maxResponseBytes,
    required Duration connectTimeout,
    required Duration readTimeout,
  }) async {
    if (!isSupported) {
      throw const P2pAndroidProbeException(
        failure: P2pAndroidProbeFailure.noLocalNetwork,
        message: "Android Wi-Fi exchange is unavailable on this platform.",
      );
    }

    try {
      final response = await _channel
          .invokeMethod<String>("exchangeWifiLine", <String, Object>{
            "host": host,
            "port": port,
            "requestLine": requestLine,
            "maxResponseBytes": maxResponseBytes,
            "connectTimeoutMillis": connectTimeout.inMilliseconds,
            "readTimeoutMillis": readTimeout.inMilliseconds,
          });
      if (response == null) {
        throw const P2pAndroidProbeException(
          failure: P2pAndroidProbeFailure.response,
          message: "Android Wi-Fi exchange 沒有回傳資料。",
        );
      }
      return response;
    } on MissingPluginException {
      throw const P2pAndroidProbeException(
        failure: P2pAndroidProbeFailure.noLocalNetwork,
        message: "Android Wi-Fi exchange 尚未註冊，請完整重啟並重新安裝應用程式。",
      );
    } on PlatformException catch (error) {
      final failure = switch (error.code) {
        "NO_LOCAL_NETWORK" => P2pAndroidProbeFailure.noLocalNetwork,
        "RESPONSE_TIMEOUT" ||
        "RESPONSE_FAILED" => P2pAndroidProbeFailure.response,
        "INCOMPATIBLE_ENDPOINT" => P2pAndroidProbeFailure.incompatible,
        _ => P2pAndroidProbeFailure.connect,
      };
      throw P2pAndroidProbeException(
        failure: failure,
        message: "Android Wi-Fi project offer exchange failed (${error.code}).",
      );
    }
  }

  @override
  Future<List<String>> exchangeLines({
    required String host,
    required int port,
    required List<String> requestLines,
    required int maxResponseBytes,
    required Duration connectTimeout,
    required Duration readTimeout,
  }) async {
    if (!isSupported) {
      throw const P2pAndroidProbeException(
        failure: P2pAndroidProbeFailure.noLocalNetwork,
        message:
            "Android Wi-Fi multi-line exchange is unavailable on this platform.",
      );
    }
    if (requestLines.isEmpty || requestLines.length > 32) {
      throw const P2pAndroidProbeException(
        failure: P2pAndroidProbeFailure.incompatible,
        message: "Android Wi-Fi multi-line exchange 數量無效。",
      );
    }
    try {
      final responses = await _channel
          .invokeListMethod<String>("exchangeWifiLines", <String, Object>{
            "host": host,
            "port": port,
            "requestLines": requestLines,
            "maxResponseBytes": maxResponseBytes,
            "connectTimeoutMillis": connectTimeout.inMilliseconds,
            "readTimeoutMillis": readTimeout.inMilliseconds,
          });
      if (responses == null || responses.length != requestLines.length) {
        throw const P2pAndroidProbeException(
          failure: P2pAndroidProbeFailure.response,
          message: "Android Wi-Fi multi-line exchange 回應數量不符。",
        );
      }
      return List<String>.unmodifiable(responses);
    } on MissingPluginException {
      throw const P2pAndroidProbeException(
        failure: P2pAndroidProbeFailure.noLocalNetwork,
        message: "Android Wi-Fi multi-line exchange 尚未註冊，請完整重啟並重新安裝應用程式。",
      );
    } on PlatformException catch (error) {
      final failure = switch (error.code) {
        "NO_LOCAL_NETWORK" => P2pAndroidProbeFailure.noLocalNetwork,
        "RESPONSE_TIMEOUT" ||
        "RESPONSE_FAILED" => P2pAndroidProbeFailure.response,
        "INCOMPATIBLE_ENDPOINT" ||
        "INVALID_REQUEST" => P2pAndroidProbeFailure.incompatible,
        _ => P2pAndroidProbeFailure.connect,
      };
      throw P2pAndroidProbeException(
        failure: failure,
        message: "Android Wi-Fi multi-line exchange failed (${error.code}).",
      );
    }
  }
}
