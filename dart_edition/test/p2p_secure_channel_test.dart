import "dart:convert";

import "package:cryptography/cryptography.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/data/p2p/p2p_identity_store.dart";
import "package:monogatari_assistant/data/p2p/p2p_secure_channel.dart";

class _MemorySecureStore implements P2pSecureKeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _ChannelPair {
  final P2pSecureChannel first;
  final P2pSecureChannel second;

  const _ChannelPair(this.first, this.second);

  void destroy() {
    first.destroy();
    second.destroy();
  }
}

Future<_ChannelPair> _createChannelPair() async {
  final firstStore = P2pIdentityStore(storage: _MemorySecureStore());
  final secondStore = P2pIdentityStore(storage: _MemorySecureStore());
  final firstChallenge = await firstStore.createPairingChallenge();
  final secondChallenge = await secondStore.createPairingChallenge();
  await firstStore.trustPeer(secondChallenge);
  await secondStore.trustPeer(firstChallenge);
  final firstConfirmation = await firstStore.createPairingConfirmation(
    firstChallenge,
    secondChallenge,
  );
  final secondConfirmation = await secondStore.createPairingConfirmation(
    secondChallenge,
    firstChallenge,
  );
  final firstKeys = await firstStore.deriveAuthenticatedSessionKeys(
    localChallenge: firstChallenge,
    remoteChallenge: secondChallenge,
    localConfirmation: firstConfirmation,
    remoteConfirmation: secondConfirmation,
  );
  final secondKeys = await secondStore.deriveAuthenticatedSessionKeys(
    localChallenge: secondChallenge,
    remoteChallenge: firstChallenge,
    localConfirmation: secondConfirmation,
    remoteConfirmation: firstConfirmation,
  );
  return _ChannelPair(
    P2pSecureChannel(firstKeys),
    P2pSecureChannel(secondKeys),
  );
}

void main() {
  test("signed ephemeral ECDH derives bidirectional session keys", () async {
    final channels = await _createChannelPair();
    addTearDown(channels.destroy);

    final request = await channels.first.encryptJson(<String, Object?>{
      "type": "revisionSummaryRequest",
      "projectUuid": "123e4567-e89b-12d3-a456-426614174000",
    });
    final wireJson = jsonEncode(request.toJson());
    expect(wireJson, isNot(contains("revisionSummaryRequest")));
    expect(wireJson, isNot(contains("123e4567-e89b-12d3-a456-426614174000")));
    expect(
      await channels.second.decryptJson(request),
      containsPair("type", "revisionSummaryRequest"),
    );

    final response = await channels.second.encryptJson(<String, Object?>{
      "type": "revisionSummaryResponse",
      "heads": <Object?>[],
    });
    expect(
      await channels.first.decryptJson(response),
      containsPair("type", "revisionSummaryResponse"),
    );
  });

  test("authenticated encryption rejects a tampered frame", () async {
    final channels = await _createChannelPair();
    addTearDown(channels.destroy);
    final frame = await channels.first.encryptJson(<String, Object?>{
      "type": "revisionSummaryRequest",
    });
    final body = base64Decode(frame.encryptedBodyBase64);
    body[0] ^= 0x01;
    final tampered = P2pEncryptedFrame(
      sessionId: frame.sessionId,
      senderDeviceId: frame.senderDeviceId,
      sequence: frame.sequence,
      encryptedBodyBase64: base64Encode(body),
    );

    expect(
      () => channels.second.decryptJson(tampered),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test("authenticated encryption rejects replayed sequence numbers", () async {
    final channels = await _createChannelPair();
    addTearDown(channels.destroy);
    final frame = await channels.first.encryptJson(<String, Object?>{
      "type": "revisionSummaryRequest",
    });

    await channels.second.decryptJson(frame);

    expect(
      () => channels.second.decryptJson(frame),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    "authenticated encryption accepts bounded out-of-order frames",
    () async {
      final channels = await _createChannelPair();
      addTearDown(channels.destroy);
      final first = await channels.first.encryptJson(<String, Object?>{
        "value": 1,
      });
      final second = await channels.first.encryptJson(<String, Object?>{
        "value": 2,
      });
      final third = await channels.first.encryptJson(<String, Object?>{
        "value": 3,
      });

      expect(
        await channels.second.decryptJson(third),
        containsPair("value", 3),
      );
      expect(
        await channels.second.decryptJson(first),
        containsPair("value", 1),
      );
      expect(
        await channels.second.decryptJson(second),
        containsPair("value", 2),
      );
      await expectLater(
        channels.second.decryptJson(first),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test(
    "authenticated encryption rejects frames older than replay window",
    () async {
      final channels = await _createChannelPair();
      addTearDown(channels.destroy);
      final frames = <P2pEncryptedFrame>[];
      for (var index = 0; index < 130; index++) {
        frames.add(
          await channels.first.encryptJson(<String, Object?>{"value": index}),
        );
      }

      await channels.second.decryptJson(frames.last);
      await expectLater(
        channels.second.decryptJson(frames.first),
        throwsA(isA<FormatException>()),
      );
      expect(
        await channels.second.decryptJson(frames[2]),
        containsPair("value", 2),
      );
    },
  );

  test("session derivation refuses an untrusted remote identity", () async {
    final firstStore = P2pIdentityStore(storage: _MemorySecureStore());
    final secondStore = P2pIdentityStore(storage: _MemorySecureStore());
    final firstChallenge = await firstStore.createPairingChallenge();
    final secondChallenge = await secondStore.createPairingChallenge();
    final firstConfirmation = await firstStore.createPairingConfirmation(
      firstChallenge,
      secondChallenge,
    );
    final secondConfirmation = await secondStore.createPairingConfirmation(
      secondChallenge,
      firstChallenge,
    );

    expect(
      () => firstStore.deriveAuthenticatedSessionKeys(
        localChallenge: firstChallenge,
        remoteChallenge: secondChallenge,
        localConfirmation: firstConfirmation,
        remoteConfirmation: secondConfirmation,
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
