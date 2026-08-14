import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:cryptography/cryptography.dart";

import "../../domain/models/p2p_sync_models.dart";

enum P2pSecureTransportStatus { inactive, establishing, authenticated, error }

class P2pSecureSessionKeys {
  final String sessionId;
  final String localDeviceId;
  final String remoteDeviceId;
  final SecretKeyData sendKey;
  final SecretKeyData receiveKey;

  P2pSecureSessionKeys({
    required this.sessionId,
    required this.localDeviceId,
    required this.remoteDeviceId,
    required this.sendKey,
    required this.receiveKey,
  }) {
    if (!_isSha256Hex(sessionId) ||
        !P2pProjectStatus.isValidProjectUuid(localDeviceId) ||
        !P2pProjectStatus.isValidProjectUuid(remoteDeviceId) ||
        localDeviceId == remoteDeviceId ||
        sendKey.bytes.length != 32 ||
        receiveKey.bytes.length != 32) {
      throw const FormatException("P2P secure session keys 無效。");
    }
  }

  void destroy() {
    sendKey.destroy();
    receiveKey.destroy();
  }

  static bool _isSha256Hex(String value) =>
      RegExp(r"^[0-9a-f]{64}$").hasMatch(value);
}

class P2pEncryptedFrame {
  static const int maxEncodedLength = 64 * 1024;
  static const int _macLength = 16;

  final String sessionId;
  final String senderDeviceId;
  final int sequence;
  final String encryptedBodyBase64;

  const P2pEncryptedFrame({
    required this.sessionId,
    required this.senderDeviceId,
    required this.sequence,
    required this.encryptedBodyBase64,
  });

  String get authenticatedHeader =>
      "MONOGATARI_P2P_SECURE_FRAME/1|$sessionId|$senderDeviceId|$sequence";

  Map<String, Object?> toJson() => <String, Object?>{
    "sessionId": sessionId,
    "senderDeviceId": senderDeviceId,
    "sequence": sequence,
    "body": encryptedBodyBase64,
  };

  factory P2pEncryptedFrame.fromJson(Map<String, Object?> json) {
    final sessionId = json["sessionId"];
    final senderDeviceId = json["senderDeviceId"];
    final sequence = json["sequence"];
    final body = json["body"];
    if (sessionId is! String ||
        senderDeviceId is! String ||
        sequence is! int ||
        body is! String ||
        !P2pSecureSessionKeys._isSha256Hex(sessionId) ||
        !P2pProjectStatus.isValidProjectUuid(senderDeviceId) ||
        sequence < 1) {
      throw const FormatException("P2P encrypted frame 欄位無效。");
    }
    final encryptedBytes = _decodeBase64(body);
    if (encryptedBytes.length <= _macLength ||
        encryptedBytes.length > maxEncodedLength) {
      throw const FormatException("P2P encrypted frame 大小無效。");
    }
    final frame = P2pEncryptedFrame(
      sessionId: sessionId,
      senderDeviceId: senderDeviceId.toLowerCase(),
      sequence: sequence,
      encryptedBodyBase64: body,
    );
    if (jsonEncode(frame.toJson()).length > maxEncodedLength) {
      throw const FormatException("P2P encrypted frame 超過大小限制。");
    }
    return frame;
  }

  static List<int> _decodeBase64(String value) {
    try {
      return base64Decode(value);
    } on FormatException {
      throw const FormatException("P2P encrypted frame body 不是有效 Base64。");
    }
  }
}

class P2pSecureChannel {
  static const int _macLength = 16;
  static const int _maximumClearTextBytes = 40 * 1024;
  static const int _receiveReplayWindowSize = 128;

  final P2pSecureSessionKeys _keys;
  final Chacha20 _cipher;
  int _nextSendSequence = 1;
  int _highestReceivedSequence = 0;
  final Set<int> _receivedSequences = <int>{};
  Future<void> _receiveTail = Future<void>.value();
  bool _destroyed = false;

  P2pSecureChannel(this._keys, {Chacha20? cipher})
    : _cipher = cipher ?? Chacha20.poly1305Aead();

  String get sessionId => _keys.sessionId;
  String get localDeviceId => _keys.localDeviceId;
  String get remoteDeviceId => _keys.remoteDeviceId;

  Future<P2pEncryptedFrame> encryptJson(Map<String, Object?> clearJson) async {
    _ensureActive();
    final clearText = utf8.encode(jsonEncode(clearJson));
    if (clearText.isEmpty || clearText.length > _maximumClearTextBytes) {
      throw const FormatException("P2P encrypted payload 大小無效。");
    }
    final sequence = _nextSendSequence++;
    final frame = P2pEncryptedFrame(
      sessionId: sessionId,
      senderDeviceId: localDeviceId,
      sequence: sequence,
      encryptedBodyBase64: "",
    );
    final secretBox = await _cipher.encrypt(
      clearText,
      secretKey: _keys.sendKey,
      nonce: _nonceFor(sequence),
      aad: utf8.encode(frame.authenticatedHeader),
    );
    final encryptedBody = <int>[
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ];
    return P2pEncryptedFrame(
      sessionId: frame.sessionId,
      senderDeviceId: frame.senderDeviceId,
      sequence: frame.sequence,
      encryptedBodyBase64: base64Encode(encryptedBody),
    );
  }

  Future<Map<String, Object?>> decryptJson(P2pEncryptedFrame frame) {
    final completer = Completer<Map<String, Object?>>();
    _receiveTail = _receiveTail.then((_) async {
      try {
        completer.complete(await _decryptJsonNow(frame));
      } on SecretBoxAuthenticationError catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } on StateError catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } on Exception catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<Map<String, Object?>> _decryptJsonNow(P2pEncryptedFrame frame) async {
    _ensureActive();
    if (frame.sessionId != sessionId ||
        frame.senderDeviceId != remoteDeviceId ||
        _isRejectedSequence(frame.sequence)) {
      throw const FormatException(
        "P2P encrypted frame session、sender 或 sequence 無效。",
      );
    }
    final encryptedBody = base64Decode(frame.encryptedBodyBase64);
    final cipherTextLength = encryptedBody.length - _macLength;
    if (cipherTextLength < 1) {
      throw const FormatException("P2P encrypted frame body 無效。");
    }
    final secretBox = SecretBox(
      encryptedBody.sublist(0, cipherTextLength),
      nonce: _nonceFor(frame.sequence),
      mac: Mac(encryptedBody.sublist(cipherTextLength)),
    );
    final clearText = await _cipher.decrypt(
      secretBox,
      secretKey: _keys.receiveKey,
      aad: utf8.encode(frame.authenticatedHeader),
    );
    final decoded = jsonDecode(utf8.decode(clearText, allowMalformed: false));
    if (decoded is! Map) {
      throw const FormatException("P2P encrypted payload 必須是 JSON object。");
    }
    final result = <String, Object?>{};
    for (final entry in decoded.entries) {
      if (entry.key is! String) {
        throw const FormatException("P2P encrypted payload key 無效。");
      }
      result[entry.key as String] = entry.value;
    }
    _recordReceivedSequence(frame.sequence);
    return result;
  }

  bool _isRejectedSequence(int sequence) {
    if (_receivedSequences.contains(sequence)) return true;
    if (_highestReceivedSequence == 0) return false;
    return sequence <= _highestReceivedSequence - _receiveReplayWindowSize;
  }

  void _recordReceivedSequence(int sequence) {
    if (sequence > _highestReceivedSequence) {
      _highestReceivedSequence = sequence;
    }
    _receivedSequences.add(sequence);
    final oldestAllowed =
        _highestReceivedSequence - _receiveReplayWindowSize + 1;
    _receivedSequences.removeWhere((value) => value < oldestAllowed);
  }

  Uint8List _nonceFor(int sequence) {
    final nonce = ByteData(12);
    nonce.setUint32(0, 0x4d415331, Endian.big);
    nonce.setUint64(4, sequence, Endian.big);
    return nonce.buffer.asUint8List();
  }

  void destroy() {
    if (_destroyed) return;
    _destroyed = true;
    _keys.destroy();
  }

  void _ensureActive() {
    if (_destroyed) throw StateError("P2P secure channel 已銷毀。");
  }
}
