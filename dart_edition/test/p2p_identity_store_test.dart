import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/data/p2p/p2p_identity_store.dart";
import "package:monogatari_assistant/domain/models/p2p_pairing_models.dart";

class _MemorySecureStore implements P2pSecureKeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  test("device identity persists and keeps the same fingerprint", () async {
    final storage = _MemorySecureStore();
    final first = await P2pIdentityStore(
      storage: storage,
    ).loadOrCreateIdentity();
    final second = await P2pIdentityStore(
      storage: storage,
    ).loadOrCreateIdentity();

    expect(second.deviceId, first.deviceId);
    expect(second.publicKeyBase64, first.publicKeyBase64);
    expect(second.fingerprint, first.fingerprint);
  });

  test("signed pairing challenge rejects tampering and expiration", () async {
    final store = P2pIdentityStore(storage: _MemorySecureStore());
    final now = DateTime.utc(2026, 8, 10, 12);
    final challenge = await store.createPairingChallenge(now: now);

    expect(
      await store.verifyPairingChallenge(
        challenge,
        now: now.add(const Duration(seconds: 1)),
      ),
      isTrue,
    );
    final tampered = P2pPairingChallenge(
      deviceId: challenge.deviceId,
      publicKeyBase64: challenge.publicKeyBase64,
      ephemeralKeyBase64: challenge.ephemeralKeyBase64,
      nonceBase64: challenge.nonceBase64,
      expiresAtEpochSeconds: challenge.expiresAtEpochSeconds + 1,
      allowsSingleDeviceConfirmation: challenge.allowsSingleDeviceConfirmation,
      allowsPersistentVerification: challenge.allowsPersistentVerification,
      signatureBase64: challenge.signatureBase64,
    );
    expect(await store.verifyPairingChallenge(tampered, now: now), isFalse);
    final tamperedPreference = P2pPairingChallenge(
      deviceId: challenge.deviceId,
      publicKeyBase64: challenge.publicKeyBase64,
      ephemeralKeyBase64: challenge.ephemeralKeyBase64,
      nonceBase64: challenge.nonceBase64,
      expiresAtEpochSeconds: challenge.expiresAtEpochSeconds,
      allowsSingleDeviceConfirmation: !challenge.allowsSingleDeviceConfirmation,
      allowsPersistentVerification: challenge.allowsPersistentVerification,
      signatureBase64: challenge.signatureBase64,
    );
    expect(
      await store.verifyPairingChallenge(tamperedPreference, now: now),
      isFalse,
    );
    final tamperedPersistentPreference = P2pPairingChallenge(
      deviceId: challenge.deviceId,
      publicKeyBase64: challenge.publicKeyBase64,
      ephemeralKeyBase64: challenge.ephemeralKeyBase64,
      nonceBase64: challenge.nonceBase64,
      expiresAtEpochSeconds: challenge.expiresAtEpochSeconds,
      allowsSingleDeviceConfirmation: challenge.allowsSingleDeviceConfirmation,
      allowsPersistentVerification: true,
      signatureBase64: challenge.signatureBase64,
    );
    expect(
      await store.verifyPairingChallenge(
        tamperedPersistentPreference,
        now: now,
      ),
      isFalse,
    );
    expect(
      await store.verifyPairingChallenge(
        challenge,
        now: now.add(const Duration(minutes: 11)),
      ),
      isFalse,
    );
  });

  test("both peers derive the same six digit comparison code", () async {
    final firstStore = P2pIdentityStore(storage: _MemorySecureStore());
    final secondStore = P2pIdentityStore(storage: _MemorySecureStore());
    final first = await firstStore.createPairingChallenge();
    final second = await secondStore.createPairingChallenge();

    final firstCode = await firstStore.pairingCode(first, second);
    final secondCode = await secondStore.pairingCode(second, first);

    expect(firstCode, matches(RegExp(r"^[0-9]{6}$")));
    expect(secondCode, firstCode);
  });

  test("confirmed peer is persisted in the secure allowlist", () async {
    final localStorage = _MemorySecureStore();
    final local = P2pIdentityStore(storage: localStorage);
    final remote = P2pIdentityStore(storage: _MemorySecureStore());
    final remoteChallenge = await remote.createPairingChallenge();

    await local.trustPeer(remoteChallenge);
    final trusted = await P2pIdentityStore(
      storage: localStorage,
    ).loadTrustedPeers();

    expect(trusted[remoteChallenge.deviceId], isNotNull);
    expect(
      trusted[remoteChallenge.deviceId]?.publicKeyBase64,
      remoteChallenge.publicKeyBase64,
    );
  });

  test("persistent verification expires after 14 days and renews", () async {
    final localStorage = _MemorySecureStore();
    final local = P2pIdentityStore(storage: localStorage);
    final remote = P2pIdentityStore(storage: _MemorySecureStore());
    final startedAt = DateTime.utc(2026, 8, 10, 12);
    final remoteChallenge = await remote.createPairingChallenge(
      allowPersistentVerification: true,
      now: startedAt,
    );

    await local.trustPeer(
      remoteChallenge,
      persistentVerification: true,
      now: startedAt,
    );
    expect(
      await local.hasValidPersistentVerification(
        remoteChallenge,
        now: startedAt.add(const Duration(days: 13, hours: 23)),
      ),
      isTrue,
    );
    expect(
      await local.hasValidPersistentVerification(
        remoteChallenge,
        now: startedAt.add(const Duration(days: 14)),
      ),
      isFalse,
    );

    final renewedAt = startedAt.add(const Duration(days: 7));
    final renewedChallenge = await remote.createPairingChallenge(
      allowPersistentVerification: true,
      now: renewedAt,
    );
    await local.renewPersistentVerification(renewedChallenge, now: renewedAt);
    final renewed = (await local.loadTrustedPeers())[remoteChallenge.deviceId]!;
    expect(
      renewed.persistentVerificationUntilEpochSeconds,
      renewedAt
              .add(P2pIdentityStore.persistentVerificationLifetime)
              .millisecondsSinceEpoch ~/
          1000,
    );
  });

  test("signed confirmations bind both peers to the same transcript", () async {
    final now = DateTime.utc(2026, 8, 10, 12);
    final firstStore = P2pIdentityStore(storage: _MemorySecureStore());
    final secondStore = P2pIdentityStore(storage: _MemorySecureStore());
    final first = await firstStore.createPairingChallenge(now: now);
    final second = await secondStore.createPairingChallenge(now: now);

    final firstHash = await firstStore.pairingTranscriptHash(first, second);
    final secondHash = await secondStore.pairingTranscriptHash(second, first);
    expect(secondHash, firstHash);

    final confirmation = await secondStore.createPairingConfirmation(
      second,
      first,
      now: now.add(const Duration(seconds: 5)),
    );
    expect(
      await firstStore.verifyPairingConfirmation(
        confirmation,
        localChallenge: first,
        remoteChallenge: second,
        now: now.add(const Duration(seconds: 6)),
      ),
      isTrue,
    );

    final unrelated = await P2pIdentityStore(
      storage: _MemorySecureStore(),
    ).createPairingChallenge(now: now);
    expect(
      await firstStore.verifyPairingConfirmation(
        confirmation,
        localChallenge: first,
        remoteChallenge: unrelated,
        now: now.add(const Duration(seconds: 6)),
      ),
      isFalse,
    );
  });

  test("pairing tolerates bounded clock skew between devices", () async {
    final verifierNow = DateTime.utc(2026, 8, 10, 12);
    final signerNow = verifierNow.add(const Duration(minutes: 4));
    final verifierStore = P2pIdentityStore(storage: _MemorySecureStore());
    final signerStore = P2pIdentityStore(storage: _MemorySecureStore());
    final verifierChallenge = await verifierStore.createPairingChallenge(
      now: verifierNow,
    );
    final signerChallenge = await signerStore.createPairingChallenge(
      now: signerNow,
    );
    expect(
      await verifierStore.verifyPairingChallenge(
        signerChallenge,
        now: verifierNow,
      ),
      isTrue,
    );

    final confirmation = await signerStore.createPairingConfirmation(
      signerChallenge,
      verifierChallenge,
      now: signerNow,
    );

    expect(
      await verifierStore.verifyPairingConfirmation(
        confirmation,
        localChallenge: verifierChallenge,
        remoteChallenge: signerChallenge,
        now: verifierNow,
      ),
      isTrue,
    );
  });
}
