import "dart:convert";
import "dart:math";

import "package:cryptography/cryptography.dart";

import "../domain/mcp_protocol_models.dart";

final class MonoAshiMcpCursor {
  final String kind;
  final int offset;
  final String scope;

  const MonoAshiMcpCursor({
    required this.kind,
    required this.offset,
    required this.scope,
  });
}

final class MonoAshiMcpCursorCodec {
  final SecretKey _key;
  final Hmac _hmac;

  MonoAshiMcpCursorCodec._(this._key) : _hmac = Hmac.sha256();

  factory MonoAshiMcpCursorCodec.random() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return MonoAshiMcpCursorCodec._(SecretKey(bytes));
  }

  factory MonoAshiMcpCursorCodec.forTesting(List<int> keyBytes) {
    if (keyBytes.length < 16) {
      throw ArgumentError.value(keyBytes.length, "keyBytes", "too short");
    }
    return MonoAshiMcpCursorCodec._(SecretKey(List<int>.from(keyBytes)));
  }

  Future<String> encode({
    required String kind,
    required int offset,
    required String scope,
  }) async {
    final payload = utf8.encode(
      jsonEncode(<String, Object?>{
        "v": 1,
        "kind": kind,
        "offset": offset,
        "scope": scope,
      }),
    );
    final mac = await _hmac.calculateMac(payload, secretKey: _key);
    return "${base64Url.encode(payload)}.${base64Url.encode(mac.bytes)}";
  }

  Future<MonoAshiMcpCursor> decode(
    String cursor, {
    required String expectedKind,
    required String expectedScope,
  }) async {
    try {
      final parts = cursor.split(".");
      if (parts.length != 2) throw const FormatException();
      final payload = base64Url.decode(base64Url.normalize(parts[0]));
      final suppliedMac = base64Url.decode(base64Url.normalize(parts[1]));
      final expectedMac = await _hmac.calculateMac(payload, secretKey: _key);
      if (!_constantTimeEquals(suppliedMac, expectedMac.bytes)) {
        throw const FormatException();
      }
      final decoded = jsonDecode(utf8.decode(payload));
      if (decoded is! Map<String, dynamic> ||
          decoded["v"] != 1 ||
          decoded["kind"] != expectedKind ||
          decoded["scope"] != expectedScope ||
          decoded["offset"] is! int ||
          (decoded["offset"] as int) < 0) {
        throw const FormatException();
      }
      return MonoAshiMcpCursor(
        kind: decoded["kind"] as String,
        offset: decoded["offset"] as int,
        scope: decoded["scope"] as String,
      );
    } on MonoAshiMcpException {
      rethrow;
    } catch (_) {
      throw const MonoAshiMcpException(
        MonoAshiMcpErrorCode.invalidCursor,
        "Cursor 無效、已被修改或不屬於目前查詢。",
      );
    }
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    var difference = left.length ^ right.length;
    final length = left.length < right.length ? left.length : right.length;
    for (var index = 0; index < length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }
}
