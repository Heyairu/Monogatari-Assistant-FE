import "dart:convert";
import "dart:math";

import "package:cryptography/cryptography.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:uuid/uuid.dart";

import "../../domain/models/p2p_pairing_models.dart";
import "../../domain/models/p2p_sync_models.dart";
import "p2p_secure_channel.dart";

abstract class P2pSecureKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

class FlutterP2pSecureKeyValueStore implements P2pSecureKeyValueStore {
  final FlutterSecureStorage _storage;

  const FlutterP2pSecureKeyValueStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

class P2pIdentityStore {
  static const String _identityStorageKey = "p2p.device_identity.v1";
  static const String _trustedPeersStorageKey = "p2p.trusted_peers.v1";
  static const Duration _pairingChallengeLifetime = Duration(minutes: 10);
  static const Duration _maximumClockSkew = Duration(minutes: 5);
  static const Duration persistentVerificationLifetime = Duration(days: 14);

  final P2pSecureKeyValueStore _storage;
  final Ed25519 _signatureAlgorithm;
  final X25519 _keyExchangeAlgorithm;
  final Hkdf _sessionKdf;
  final Sha256 _sha256;
  final Random _secureRandom;
  final Uuid _uuid;

  SimpleKeyPair? _keyPair;
  P2pDeviceIdentity? _identity;
  final Map<String, KeyPair> _pairingEphemeralKeys = <String, KeyPair>{};

  P2pIdentityStore({
    P2pSecureKeyValueStore? storage,
    Ed25519? signatureAlgorithm,
    X25519? keyExchangeAlgorithm,
    Sha256? sha256,
    Random? secureRandom,
    Uuid? uuid,
  }) : _storage = storage ?? const FlutterP2pSecureKeyValueStore(),
       _signatureAlgorithm = signatureAlgorithm ?? Ed25519(),
       _keyExchangeAlgorithm = keyExchangeAlgorithm ?? X25519(),
       _sessionKdf = Hkdf(hmac: Hmac.sha256(), outputLength: 64),
       _sha256 = sha256 ?? Sha256(),
       _secureRandom = secureRandom ?? Random.secure(),
       _uuid = uuid ?? const Uuid();

  Future<P2pDeviceIdentity> loadOrCreateIdentity() async {
    final cached = _identity;
    if (cached != null) return cached;
    final stored = await _storage.read(_identityStorageKey);
    if (stored != null) {
      try {
        final decoded = jsonDecode(stored);
        if (decoded is Map) {
          final deviceId = decoded["deviceId"];
          final seedBase64 = decoded["seed"];
          if (deviceId is String &&
              P2pProjectStatus.isValidProjectUuid(deviceId) &&
              seedBase64 is String) {
            final seed = base64Decode(seedBase64);
            if (seed.length == 32) {
              return _installIdentity(deviceId, seed);
            }
          }
        }
      } on FormatException {
        // Corrupt identity material is replaced atomically below.
      } on ArgumentError {
        // Corrupt identity material is replaced atomically below.
      }
    }

    final seed = List<int>.generate(32, (_) => _secureRandom.nextInt(256));
    final deviceId = _uuid.v4().toLowerCase();
    final identity = await _installIdentity(deviceId, seed);
    await _storage.write(
      _identityStorageKey,
      jsonEncode(<String, Object?>{
        "deviceId": deviceId,
        "seed": base64Encode(seed),
      }),
    );
    return identity;
  }

  Future<P2pDeviceIdentity> _installIdentity(
    String deviceId,
    List<int> seed,
  ) async {
    if (!P2pProjectStatus.isValidProjectUuid(deviceId) || seed.length != 32) {
      throw const FormatException("P2P device identity 無效。");
    }
    final keyPair = await _signatureAlgorithm.newKeyPairFromSeed(seed);
    final publicKey = await keyPair.extractPublicKey();
    final publicKeyBase64 = base64Encode(publicKey.bytes);
    final fingerprint = await _fingerprint(publicKey.bytes);
    final identity = P2pDeviceIdentity(
      deviceId: deviceId,
      publicKeyBase64: publicKeyBase64,
      fingerprint: fingerprint,
    );
    _keyPair = keyPair;
    _identity = identity;
    return identity;
  }

  Future<P2pPairingChallenge> createPairingChallenge({
    Duration lifetime = _pairingChallengeLifetime,
    bool allowSingleDeviceConfirmation = true,
    bool allowPersistentVerification = false,
    DateTime? now,
  }) async {
    final identity = await loadOrCreateIdentity();
    final keyPair = _keyPair!;
    final nonce = List<int>.generate(32, (_) => _secureRandom.nextInt(256));
    final ephemeralKeyPair = await _keyExchangeAlgorithm.newKeyPair();
    final ephemeralPublicKey = await ephemeralKeyPair.extractPublicKey();
    var retainedForPairing = false;
    try {
      final expiresAt = (now ?? DateTime.now()).toUtc().add(lifetime);
      final unsigned = P2pPairingChallenge(
        deviceId: identity.deviceId,
        publicKeyBase64: identity.publicKeyBase64,
        ephemeralKeyBase64: base64Encode(ephemeralPublicKey.bytes),
        nonceBase64: base64Encode(nonce),
        expiresAtEpochSeconds: expiresAt.millisecondsSinceEpoch ~/ 1000,
        allowsSingleDeviceConfirmation: allowSingleDeviceConfirmation,
        allowsPersistentVerification: allowPersistentVerification,
        signatureBase64: base64Encode(List<int>.filled(64, 0)),
      );
      final signature = await _signatureAlgorithm.sign(
        utf8.encode(unsigned.canonicalPayload),
        keyPair: keyPair,
      );
      for (final previous in _pairingEphemeralKeys.values) {
        previous.destroy();
      }
      final signedChallenge = P2pPairingChallenge(
        deviceId: unsigned.deviceId,
        publicKeyBase64: unsigned.publicKeyBase64,
        ephemeralKeyBase64: unsigned.ephemeralKeyBase64,
        nonceBase64: unsigned.nonceBase64,
        expiresAtEpochSeconds: unsigned.expiresAtEpochSeconds,
        allowsSingleDeviceConfirmation: unsigned.allowsSingleDeviceConfirmation,
        allowsPersistentVerification: unsigned.allowsPersistentVerification,
        signatureBase64: base64Encode(signature.bytes),
      );
      _pairingEphemeralKeys
        ..clear()
        ..[unsigned.nonceBase64] = ephemeralKeyPair;
      retainedForPairing = true;
      return signedChallenge;
    } finally {
      if (!retainedForPairing) ephemeralKeyPair.destroy();
    }
  }

  Future<bool> verifyPairingChallenge(
    P2pPairingChallenge challenge, {
    DateTime? now,
  }) async {
    final current = (now ?? DateTime.now()).toUtc();
    if (challenge.isExpiredAt(current)) return false;
    final latestAllowed = current.add(
      _pairingChallengeLifetime + _maximumClockSkew,
    );
    if (challenge.expiresAtEpochSeconds >
        latestAllowed.millisecondsSinceEpoch ~/ 1000) {
      return false;
    }
    try {
      final publicKeyBytes = base64Decode(challenge.publicKeyBase64);
      final signatureBytes = base64Decode(challenge.signatureBase64);
      if (publicKeyBytes.length != 32 || signatureBytes.length != 64) {
        return false;
      }
      return _signatureAlgorithm.verify(
        utf8.encode(challenge.canonicalPayload),
        signature: Signature(
          signatureBytes,
          publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519),
        ),
      );
    } on FormatException {
      return false;
    } on ArgumentError {
      return false;
    }
  }

  Future<String> pairingCode(
    P2pPairingChallenge first,
    P2pPairingChallenge second,
  ) async {
    final hash = base64Decode(await pairingTranscriptHash(first, second));
    final value =
        ((hash[0] << 24) | (hash[1] << 16) | (hash[2] << 8) | hash[3]) &
        0x7fffffff;
    return (value % 1000000).toString().padLeft(6, "0");
  }

  Future<String> pairingTranscriptHash(
    P2pPairingChallenge first,
    P2pPairingChallenge second,
  ) async {
    final payloads = <String>[first.canonicalPayload, second.canonicalPayload]
      ..sort();
    final hash = await _sha256.hash(
      utf8.encode("MONOGATARI_P2P_PAIR_TRANSCRIPT/7|${payloads.join("|")}"),
    );
    return base64Encode(hash.bytes);
  }

  Future<P2pPairingConfirmation> createPairingConfirmation(
    P2pPairingChallenge localChallenge,
    P2pPairingChallenge remoteChallenge, {
    DateTime? now,
  }) async {
    final identity = await loadOrCreateIdentity();
    if (localChallenge.deviceId != identity.deviceId ||
        localChallenge.publicKeyBase64 != identity.publicKeyBase64) {
      throw const FormatException("本機 pairing challenge 與裝置身分不一致。");
    }
    final current = (now ?? DateTime.now()).toUtc();
    if (!await verifyPairingChallenge(localChallenge, now: current) ||
        !await verifyPairingChallenge(remoteChallenge, now: current)) {
      throw const FormatException("無法確認無效或已過期的 pairing transcript。");
    }
    final unsigned = P2pPairingConfirmation(
      deviceId: identity.deviceId,
      transcriptHashBase64: await pairingTranscriptHash(
        localChallenge,
        remoteChallenge,
      ),
      confirmedAtEpochSeconds: current.millisecondsSinceEpoch ~/ 1000,
      signatureBase64: base64Encode(List<int>.filled(64, 0)),
    );
    final signature = await _signatureAlgorithm.sign(
      utf8.encode(unsigned.canonicalPayload),
      keyPair: _keyPair!,
    );
    return P2pPairingConfirmation(
      deviceId: unsigned.deviceId,
      transcriptHashBase64: unsigned.transcriptHashBase64,
      confirmedAtEpochSeconds: unsigned.confirmedAtEpochSeconds,
      signatureBase64: base64Encode(signature.bytes),
    );
  }

  Future<bool> verifyPairingConfirmation(
    P2pPairingConfirmation confirmation, {
    required P2pPairingChallenge localChallenge,
    required P2pPairingChallenge remoteChallenge,
    DateTime? now,
  }) async {
    return _verifyPairingConfirmationForSigner(
      confirmation,
      signerChallenge: remoteChallenge,
      localChallenge: localChallenge,
      remoteChallenge: remoteChallenge,
      now: now,
    );
  }

  Future<bool> _verifyPairingConfirmationForSigner(
    P2pPairingConfirmation confirmation, {
    required P2pPairingChallenge signerChallenge,
    required P2pPairingChallenge localChallenge,
    required P2pPairingChallenge remoteChallenge,
    DateTime? now,
  }) async {
    final current = (now ?? DateTime.now()).toUtc();
    final currentSeconds = current.millisecondsSinceEpoch ~/ 1000;
    if (localChallenge.isExpiredAt(current) ||
        remoteChallenge.isExpiredAt(current) ||
        confirmation.deviceId != signerChallenge.deviceId ||
        confirmation.transcriptHashBase64 !=
            await pairingTranscriptHash(localChallenge, remoteChallenge) ||
        confirmation.confirmedAtEpochSeconds >
            currentSeconds + _maximumClockSkew.inSeconds ||
        confirmation.confirmedAtEpochSeconds < currentSeconds - 900 ||
        confirmation.confirmedAtEpochSeconds >
            localChallenge.expiresAtEpochSeconds ||
        confirmation.confirmedAtEpochSeconds >
            remoteChallenge.expiresAtEpochSeconds) {
      return false;
    }
    try {
      final signatureBytes = base64Decode(confirmation.signatureBase64);
      final publicKeyBytes = base64Decode(signerChallenge.publicKeyBase64);
      if (signatureBytes.length != 64 || publicKeyBytes.length != 32) {
        return false;
      }
      return _signatureAlgorithm.verify(
        utf8.encode(confirmation.canonicalPayload),
        signature: Signature(
          signatureBytes,
          publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519),
        ),
      );
    } on FormatException {
      return false;
    } on ArgumentError {
      return false;
    }
  }

  Future<P2pSecureSessionKeys> deriveAuthenticatedSessionKeys({
    required P2pPairingChallenge localChallenge,
    required P2pPairingChallenge remoteChallenge,
    required P2pPairingConfirmation localConfirmation,
    required P2pPairingConfirmation remoteConfirmation,
  }) async {
    final identity = await loadOrCreateIdentity();
    if (localChallenge.deviceId != identity.deviceId ||
        localChallenge.publicKeyBase64 != identity.publicKeyBase64) {
      throw const FormatException("本機 pairing challenge 與裝置身分不一致。");
    }
    final trustedPeer = (await loadTrustedPeers())[remoteChallenge.deviceId];
    if (trustedPeer == null ||
        trustedPeer.publicKeyBase64 != remoteChallenge.publicKeyBase64) {
      throw const FormatException("遠端裝置尚未以相同身分金鑰加入信任清單。");
    }
    final localValid = await _verifyPairingConfirmationForSigner(
      localConfirmation,
      signerChallenge: localChallenge,
      localChallenge: localChallenge,
      remoteChallenge: remoteChallenge,
    );
    final remoteValid = await _verifyPairingConfirmationForSigner(
      remoteConfirmation,
      signerChallenge: remoteChallenge,
      localChallenge: localChallenge,
      remoteChallenge: remoteChallenge,
    );
    if (!localValid || !remoteValid) {
      throw const FormatException("雙端 pairing confirmation 尚未通過簽章驗證。");
    }
    final ephemeralKeyPair = _pairingEphemeralKeys.remove(
      localChallenge.nonceBase64,
    );
    if (ephemeralKeyPair == null || ephemeralKeyPair.hasBeenDestroyed) {
      throw const FormatException("本機短期 ECDH 私鑰不存在或已失效。");
    }
    final transcriptHashBase64 = await pairingTranscriptHash(
      localChallenge,
      remoteChallenge,
    );
    final transcriptHash = base64Decode(transcriptHashBase64);
    final orderedDeviceIds = <String>[
      localChallenge.deviceId,
      remoteChallenge.deviceId,
    ]..sort();
    SecretKey? sharedSecret;
    SecretKeyData? expandedKey;
    try {
      sharedSecret = await _keyExchangeAlgorithm.sharedSecretKey(
        keyPair: ephemeralKeyPair,
        remotePublicKey: SimplePublicKey(
          base64Decode(remoteChallenge.ephemeralKeyBase64),
          type: KeyPairType.x25519,
        ),
      );
      expandedKey = await _sessionKdf.deriveKey(
        secretKey: sharedSecret,
        nonce: transcriptHash,
        info: utf8.encode(
          "MONOGATARI_P2P_AUTHENTICATED_CHANNEL/1|${orderedDeviceIds.join("|")}",
        ),
      );
      final bytes = expandedKey.bytes;
      final localIsFirst = localChallenge.deviceId == orderedDeviceIds.first;
      final firstDirection = bytes.sublist(0, 32);
      final secondDirection = bytes.sublist(32, 64);
      return P2pSecureSessionKeys(
        sessionId: _hex(transcriptHash),
        localDeviceId: localChallenge.deviceId,
        remoteDeviceId: remoteChallenge.deviceId,
        sendKey: SecretKeyData(
          localIsFirst ? firstDirection : secondDirection,
          overwriteWhenDestroyed: true,
        ),
        receiveKey: SecretKeyData(
          localIsFirst ? secondDirection : firstDirection,
          overwriteWhenDestroyed: true,
        ),
      );
    } finally {
      ephemeralKeyPair.destroy();
      sharedSecret?.destroy();
      expandedKey?.destroy();
    }
  }

  Future<void> trustPeer(
    P2pPairingChallenge challenge, {
    bool persistentVerification = false,
    DateTime? now,
  }) async {
    final current = (now ?? DateTime.now()).toUtc();
    if (!await verifyPairingChallenge(challenge, now: current)) {
      throw const FormatException("無法信任無效或已過期的 pairing challenge。");
    }
    final peers = await loadTrustedPeers();
    final existing = peers[challenge.deviceId];
    if (existing != null &&
        existing.publicKeyBase64 != challenge.publicKeyBase64) {
      throw StateError("已信任 device ID 的公開金鑰不可被靜默替換。");
    }
    final fingerprint = await _fingerprint(
      base64Decode(challenge.publicKeyBase64),
    );
    peers[challenge.deviceId] = P2pTrustedPeer(
      deviceId: challenge.deviceId,
      publicKeyBase64: challenge.publicKeyBase64,
      fingerprint: fingerprint,
      trustedAtEpochSeconds: current.millisecondsSinceEpoch ~/ 1000,
      persistentVerificationUntilEpochSeconds: persistentVerification
          ? current
                    .add(persistentVerificationLifetime)
                    .millisecondsSinceEpoch ~/
                1000
          : existing?.persistentVerificationUntilEpochSeconds,
    );
    await _storage.write(
      _trustedPeersStorageKey,
      jsonEncode(peers.values.map((peer) => peer.toJson()).toList()),
    );
  }

  Future<bool> hasValidPersistentVerification(
    P2pPairingChallenge challenge, {
    DateTime? now,
  }) async {
    final peer = (await loadTrustedPeers())[challenge.deviceId];
    return peer != null &&
        peer.publicKeyBase64 == challenge.publicKeyBase64 &&
        peer.hasPersistentVerificationAt(now ?? DateTime.now());
  }

  Future<P2pTrustedPeer> renewPersistentVerification(
    P2pPairingChallenge challenge, {
    DateTime? now,
  }) async {
    await trustPeer(challenge, persistentVerification: true, now: now);
    return (await loadTrustedPeers())[challenge.deviceId]!;
  }

  Future<Map<String, P2pTrustedPeer>> loadTrustedPeers() async {
    final stored = await _storage.read(_trustedPeersStorageKey);
    if (stored == null) return <String, P2pTrustedPeer>{};
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! List) return <String, P2pTrustedPeer>{};
      final result = <String, P2pTrustedPeer>{};
      for (final value in decoded) {
        if (value is! Map) continue;
        final map = <String, Object?>{};
        for (final entry in value.entries) {
          if (entry.key is String) map[entry.key as String] = entry.value;
        }
        final peer = P2pTrustedPeer.fromJson(map);
        result[peer.deviceId] = peer;
      }
      return result;
    } on FormatException {
      return <String, P2pTrustedPeer>{};
    }
  }

  Future<String> _fingerprint(List<int> publicKeyBytes) async {
    final hash = await _sha256.hash(publicKeyBytes);
    return hash.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, "0").toUpperCase())
        .join(":");
  }

  String _hex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, "0")).join();
}
