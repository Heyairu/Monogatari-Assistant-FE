import "dart:convert";

enum P2pPairingStatus {
  idle,
  waitingForPeer,
  comparisonRequired,
  trustedLocally,
  waitingForPeerConfirmation,
  mutuallyConfirmed,
  error,
}

class P2pDeviceIdentity {
  final String deviceId;
  final String publicKeyBase64;
  final String fingerprint;

  const P2pDeviceIdentity({
    required this.deviceId,
    required this.publicKeyBase64,
    required this.fingerprint,
  });

  String get shortFingerprint {
    final compact = fingerprint.replaceAll(":", "");
    final length = compact.length < 16 ? compact.length : 16;
    return _groupHex(compact.substring(0, length));
  }

  static String _groupHex(String value) {
    final parts = <String>[];
    for (var index = 0; index < value.length; index += 4) {
      final end = (index + 4).clamp(0, value.length);
      parts.add(value.substring(index, end));
    }
    return parts.join(" ");
  }
}

class P2pPairingChallenge {
  static const int maxEncodedLength = 2048;

  final String deviceId;
  final String publicKeyBase64;
  final String ephemeralKeyBase64;
  final String nonceBase64;
  final int expiresAtEpochSeconds;
  final bool allowsSingleDeviceConfirmation;
  final bool allowsPersistentVerification;
  final String signatureBase64;

  const P2pPairingChallenge({
    required this.deviceId,
    required this.publicKeyBase64,
    required this.ephemeralKeyBase64,
    required this.nonceBase64,
    required this.expiresAtEpochSeconds,
    required this.allowsSingleDeviceConfirmation,
    this.allowsPersistentVerification = false,
    required this.signatureBase64,
  });

  String get canonicalPayload =>
      "MONOGATARI_P2P_PAIR/7|$deviceId|$publicKeyBase64|$ephemeralKeyBase64|$nonceBase64|$expiresAtEpochSeconds|${allowsSingleDeviceConfirmation ? 1 : 0}|${allowsPersistentVerification ? 1 : 0}";

  bool isExpiredAt(DateTime now) =>
      expiresAtEpochSeconds <= now.toUtc().millisecondsSinceEpoch ~/ 1000;

  Map<String, Object?> toJson() => <String, Object?>{
    "deviceId": deviceId,
    "publicKey": publicKeyBase64,
    "ephemeralKey": ephemeralKeyBase64,
    "nonce": nonceBase64,
    "expiresAt": expiresAtEpochSeconds,
    "allowSingleConfirmation": allowsSingleDeviceConfirmation,
    "allowPersistentVerification": allowsPersistentVerification,
    "signature": signatureBase64,
  };

  factory P2pPairingChallenge.fromJson(Map<String, Object?> json) {
    final deviceId = json["deviceId"];
    final publicKey = json["publicKey"];
    final ephemeralKey = json["ephemeralKey"];
    final nonce = json["nonce"];
    final expiresAt = json["expiresAt"];
    final allowSingleConfirmation = json["allowSingleConfirmation"];
    final allowPersistentVerification = json["allowPersistentVerification"];
    final signature = json["signature"];
    if (deviceId is! String ||
        publicKey is! String ||
        ephemeralKey is! String ||
        nonce is! String ||
        expiresAt is! int ||
        allowSingleConfirmation is! bool ||
        allowPersistentVerification is! bool ||
        signature is! String) {
      throw const FormatException("P2P pairing challenge 欄位不完整。");
    }
    if (!_isUuid(deviceId) ||
        !_hasDecodedLength(publicKey, 32) ||
        !_hasDecodedLength(ephemeralKey, 32) ||
        !_hasDecodedLength(nonce, 32) ||
        !_hasDecodedLength(signature, 64)) {
      throw const FormatException("P2P pairing challenge 格式無效。");
    }
    final challenge = P2pPairingChallenge(
      deviceId: deviceId.toLowerCase(),
      publicKeyBase64: publicKey,
      ephemeralKeyBase64: ephemeralKey,
      nonceBase64: nonce,
      expiresAtEpochSeconds: expiresAt,
      allowsSingleDeviceConfirmation: allowSingleConfirmation,
      allowsPersistentVerification: allowPersistentVerification,
      signatureBase64: signature,
    );
    if (jsonEncode(challenge.toJson()).length > maxEncodedLength) {
      throw const FormatException("P2P pairing challenge 超過大小限制。");
    }
    return challenge;
  }

  static bool _isUuid(String value) => RegExp(
    r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
  ).hasMatch(value.trim());

  static bool _hasDecodedLength(String value, int expected) {
    try {
      return base64Decode(value).length == expected;
    } on FormatException {
      return false;
    }
  }
}

class P2pPairingConfirmation {
  static const int maxEncodedLength = 1024;

  final String deviceId;
  final String transcriptHashBase64;
  final int confirmedAtEpochSeconds;
  final String signatureBase64;

  const P2pPairingConfirmation({
    required this.deviceId,
    required this.transcriptHashBase64,
    required this.confirmedAtEpochSeconds,
    required this.signatureBase64,
  });

  String get canonicalPayload =>
      "MONOGATARI_P2P_PAIR_CONFIRM/6|$deviceId|$transcriptHashBase64|$confirmedAtEpochSeconds";

  Map<String, Object?> toJson() => <String, Object?>{
    "deviceId": deviceId,
    "transcriptHash": transcriptHashBase64,
    "confirmedAt": confirmedAtEpochSeconds,
    "signature": signatureBase64,
  };

  factory P2pPairingConfirmation.fromJson(Map<String, Object?> json) {
    final deviceId = json["deviceId"];
    final transcriptHash = json["transcriptHash"];
    final confirmedAt = json["confirmedAt"];
    final signature = json["signature"];
    if (deviceId is! String ||
        transcriptHash is! String ||
        confirmedAt is! int ||
        signature is! String) {
      throw const FormatException("P2P pairing confirmation 欄位不完整。");
    }
    if (!P2pPairingChallenge._isUuid(deviceId) ||
        !P2pPairingChallenge._hasDecodedLength(transcriptHash, 32) ||
        !P2pPairingChallenge._hasDecodedLength(signature, 64)) {
      throw const FormatException("P2P pairing confirmation 格式無效。");
    }
    final confirmation = P2pPairingConfirmation(
      deviceId: deviceId.toLowerCase(),
      transcriptHashBase64: transcriptHash,
      confirmedAtEpochSeconds: confirmedAt,
      signatureBase64: signature,
    );
    if (jsonEncode(confirmation.toJson()).length > maxEncodedLength) {
      throw const FormatException("P2P pairing confirmation 超過大小限制。");
    }
    return confirmation;
  }
}

class P2pTrustedPeer {
  final String deviceId;
  final String publicKeyBase64;
  final String fingerprint;
  final int trustedAtEpochSeconds;
  final int? persistentVerificationUntilEpochSeconds;

  const P2pTrustedPeer({
    required this.deviceId,
    required this.publicKeyBase64,
    required this.fingerprint,
    required this.trustedAtEpochSeconds,
    this.persistentVerificationUntilEpochSeconds,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    "deviceId": deviceId,
    "publicKey": publicKeyBase64,
    "fingerprint": fingerprint,
    "trustedAt": trustedAtEpochSeconds,
    if (persistentVerificationUntilEpochSeconds != null)
      "persistentVerificationUntil": persistentVerificationUntilEpochSeconds,
  };

  factory P2pTrustedPeer.fromJson(Map<String, Object?> json) {
    final deviceId = json["deviceId"];
    final publicKey = json["publicKey"];
    final fingerprint = json["fingerprint"];
    final trustedAt = json["trustedAt"];
    final persistentVerificationUntil = json["persistentVerificationUntil"];
    if (deviceId is! String ||
        publicKey is! String ||
        fingerprint is! String ||
        trustedAt is! int ||
        (persistentVerificationUntil != null &&
            persistentVerificationUntil is! int)) {
      throw const FormatException("Trusted peer 欄位不完整。");
    }
    if (!P2pPairingChallenge._isUuid(deviceId) ||
        !P2pPairingChallenge._hasDecodedLength(publicKey, 32) ||
        !RegExp(r"^(?:[0-9A-F]{2}:){31}[0-9A-F]{2}$").hasMatch(fingerprint) ||
        trustedAt < 0 ||
        (persistentVerificationUntil is int &&
            persistentVerificationUntil < 0)) {
      throw const FormatException("Trusted peer 格式無效。");
    }
    return P2pTrustedPeer(
      deviceId: deviceId.toLowerCase(),
      publicKeyBase64: publicKey,
      fingerprint: fingerprint,
      trustedAtEpochSeconds: trustedAt,
      persistentVerificationUntilEpochSeconds:
          persistentVerificationUntil as int?,
    );
  }

  bool hasPersistentVerificationAt(DateTime now) {
    final until = persistentVerificationUntilEpochSeconds;
    return until != null && until > now.toUtc().millisecondsSinceEpoch ~/ 1000;
  }
}
