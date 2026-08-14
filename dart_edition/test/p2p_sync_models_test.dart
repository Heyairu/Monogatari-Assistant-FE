import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/domain/models/p2p_sync_models.dart";

const String _projectUuid = "123e4567-e89b-12d3-a456-426614174000";

P2pProjectStatus _project({
  String uuid = _projectUuid,
  bool persisted = true,
  bool dirty = false,
  bool trusted = true,
}) {
  return P2pProjectStatus(
    fileName: "story.mnproj",
    hasPersistentLocation: persisted,
    hasUnsavedChanges: dirty,
    projectUuid: uuid,
    isPersistedSnapshotValidated: persisted,
    isTrusted: trusted,
  );
}

void main() {
  group("P2pEndpoint", () {
    test("accepts RFC1918 IPv4 addresses and valid ports", () {
      expect(P2pEndpoint.isPrivateIpv4("10.0.0.5"), isTrue);
      expect(P2pEndpoint.isPrivateIpv4("172.16.1.5"), isTrue);
      expect(P2pEndpoint.isPrivateIpv4("172.31.255.254"), isTrue);
      expect(P2pEndpoint.isPrivateIpv4("192.168.1.5"), isTrue);
      expect(P2pEndpoint.parsePort(" 42942 "), 42942);
      expect(
        P2pEndpoint.tryParse(host: "192.168.1.5", port: "42942"),
        const P2pEndpoint(host: "192.168.1.5", port: 42942),
      );
    });

    test("rejects public, loopback, malformed addresses and invalid ports", () {
      for (final value in <String>[
        "127.0.0.1",
        "169.254.1.1",
        "224.0.0.1",
        "8.8.8.8",
        "192.168.01.5",
        "192.168.1",
        "",
      ]) {
        expect(P2pEndpoint.isPrivateIpv4(value), isFalse, reason: value);
      }
      expect(P2pEndpoint.parsePort("0"), isNull);
      expect(P2pEndpoint.parsePort("65536"), isNull);
      expect(P2pEndpoint.parsePort("42x"), isNull);
    });
  });

  group("P2pProjectPreflight", () {
    test(
      "allows synchronization only for persisted matching clean projects",
      () {
        final result = P2pProjectPreflight.evaluate(
          local: _project(),
          remote: _project(),
        );
        expect(result.canSync, isTrue);
        expect(result.issues, isEmpty);
      },
    );

    test("blocks an unsaved or dirty local project", () {
      final unsaved = P2pProjectPreflight.evaluate(
        local: _project(persisted: false),
        requireRemote: false,
      );
      expect(
        unsaved.issues,
        contains(P2pProjectPreflightIssue.localProjectNotPersisted),
      );
      expect(unsaved.requiresSave, isTrue);

      final dirty = P2pProjectPreflight.evaluate(
        local: _project(dirty: true),
        requireRemote: false,
      );
      expect(
        dirty.issues,
        contains(P2pProjectPreflightIssue.localProjectDirty),
      );
      expect(dirty.canSync, isFalse);
    });

    test("blocks UUID mismatch and untrusted remote", () {
      final result = P2pProjectPreflight.evaluate(
        local: _project(),
        remote: _project(
          uuid: "223e4567-e89b-12d3-a456-426614174000",
          trusted: false,
        ),
      );
      expect(
        result.issues,
        contains(P2pProjectPreflightIssue.projectUuidMismatch),
      );
      expect(
        result.issues,
        contains(P2pProjectPreflightIssue.remoteProjectNotTrusted),
      );
      expect(result.canSync, isFalse);
    });
  });

  group("P2pProjectNegotiationResult", () {
    const none = P2pProjectOffer.none();
    final local = P2pProjectOffer.project(
      projectUuid: _projectUuid,
      fileName: "local.mnproj",
    );
    final sameRemote = P2pProjectOffer.project(
      projectUuid: _projectUuid,
      fileName: "remote.mnproj",
    );
    final differentRemote = P2pProjectOffer.project(
      projectUuid: "223e4567-e89b-12d3-a456-426614174000",
      fileName: "other.mnproj",
    );

    test("uses the only available project without a dialog", () {
      final remoteProvides = P2pProjectNegotiationResult.evaluate(
        local: none,
        remote: sameRemote,
      );
      expect(remoteProvides.kind, P2pProjectNegotiationKind.remoteProvides);
      expect(remoteProvides.automaticSource, P2pProjectSource.remote);
      expect(remoteProvides.requiresDialog, isFalse);

      final localProvides = P2pProjectNegotiationResult.evaluate(
        local: local,
        remote: none,
      );
      expect(localProvides.kind, P2pProjectNegotiationKind.localProvides);
      expect(localProvides.automaticSource, P2pProjectSource.local);
      expect(localProvides.requiresDialog, isFalse);
    });

    test("accepts matching UUIDs without a dialog", () {
      final result = P2pProjectNegotiationResult.evaluate(
        local: local,
        remote: sameRemote,
      );
      expect(result.kind, P2pProjectNegotiationKind.sameProject);
      expect(result.requiresDialog, isFalse);
    });

    test("requires a dialog only when both are missing or differ", () {
      final bothMissing = P2pProjectNegotiationResult.evaluate(
        local: none,
        remote: none,
      );
      expect(bothMissing.requiresDialog, isTrue);
      expect(
        bothMissing.selectionReason,
        P2pProjectSelectionReason.bothMissing,
      );

      final mismatch = P2pProjectNegotiationResult.evaluate(
        local: local,
        remote: differentRemote,
      );
      expect(mismatch.requiresDialog, isTrue);
      expect(
        mismatch.selectionReason,
        P2pProjectSelectionReason.projectUuidMismatch,
      );
    });

    test("serializes and validates project offers", () {
      expect(
        P2pProjectOffer.fromJson(local.toJson()).projectUuid,
        _projectUuid,
      );
      expect(P2pProjectOffer.fromJson(none.toJson()).hasProject, isFalse);
      final disconnect = P2pProjectOffer.fromJson(
        const P2pProjectOffer.disconnect().toJson(),
      );
      expect(disconnect.disconnectRequested, isTrue);
      expect(
        () => P2pProjectNegotiationResult.evaluate(
          local: local,
          remote: disconnect,
        ),
        throwsStateError,
      );
      expect(
        () => P2pProjectOffer.fromJson(<String, Object?>{
          "hasProject": true,
          "projectUuid": "invalid",
          "fileName": "bad.mnproj",
        }),
        throwsFormatException,
      );
    });
  });

  group("P2pThreeWayMerge", () {
    test("unions table entries with different keys", () {
      final result = P2pThreeWayMerge.mergeKeyedTable(
        groupId: "char-lia",
        groupType: "character",
        groupLabel: "莉亞",
        fieldPrefix: "人物關係",
        base: const <String, Object?>{},
        local: const <String, Object?>{"亞諾": "朋友"},
        remote: const <String, Object?>{"米亞": "同事"},
      );
      expect(result.conflicts, isEmpty);
      expect(result.mergedValues, <String, Object?>{"亞諾": "朋友", "米亞": "同事"});
    });

    test("creates a field conflict only for the same changed key", () {
      final result = P2pThreeWayMerge.mergeKeyedTable(
        groupId: "char-lia",
        groupType: "character",
        groupLabel: "莉亞",
        fieldPrefix: "人物關係",
        base: const <String, Object?>{"莉香": "朋友"},
        local: const <String, Object?>{"莉香": "摯友"},
        remote: const <String, Object?>{"莉香": "競爭對手"},
      );
      expect(result.conflicts, hasLength(1));
      expect(result.conflicts.single.fieldPath, "人物關係 > 莉香");
      expect(result.conflicts.single.local.value, "摯友");
      expect(result.conflicts.single.remote.value, "競爭對手");
    });

    test("two-way merge unions distinct keys and conflicts shared values", () {
      final result = P2pThreeWayMerge.mergeKeyedTableWithoutBase(
        groupId: "char-lia",
        groupType: "character",
        groupLabel: "莉亞",
        fieldPrefix: "人物關係",
        local: const <String, Object?>{"莉香": "朋友", "洛可": "同伴"},
        remote: const <String, Object?>{"莉香": "競爭對手", "米雅": "導師"},
      );

      expect(result.mergedValues, containsPair("洛可", "同伴"));
      expect(result.mergedValues, containsPair("米雅", "導師"));
      expect(result.conflicts, hasLength(1));
      expect(result.conflicts.single.fieldPath, "人物關係 > 莉香");
      expect(result.conflicts.single.base.exists, isFalse);
    });

    test("merges different columns within the same keyed row", () {
      final result = P2pThreeWayMerge.mergeKeyedTable(
        groupId: "char-lia",
        groupType: "character",
        groupLabel: "莉亞",
        fieldPrefix: "擁有物品",
        base: const <String, Object?>{
          "懷錶": <String, Object?>{"數量": 1, "描述": "銀色"},
        },
        local: const <String, Object?>{
          "懷錶": <String, Object?>{"數量": 2, "描述": "銀色"},
        },
        remote: const <String, Object?>{
          "懷錶": <String, Object?>{"數量": 1, "描述": "母親留下的銀色懷錶"},
        },
      );
      expect(result.conflicts, isEmpty);
      expect(result.mergedValues["懷錶"], <String, Object?>{
        "數量": 2,
        "描述": "母親留下的銀色懷錶",
      });
    });

    test("keeps field override separate from a group default", () {
      final result = P2pThreeWayMerge.mergeKeyedTable(
        groupId: "char-lia",
        groupType: "character",
        groupLabel: "莉亞",
        fieldPrefix: "欄位",
        base: const <String, Object?>{"性格": "冷靜", "備註": ""},
        local: const <String, Object?>{"性格": "謹慎", "備註": "本機"},
        remote: const <String, Object?>{"性格": "果斷", "備註": "對方"},
      );
      final personality = result.conflicts.firstWhere(
        (item) => item.fieldPath == "欄位 > 性格",
      );
      final note = result.conflicts.firstWhere(
        (item) => item.fieldPath == "欄位 > 備註",
      );
      final resolution = P2pConflictGroupResolution(
        defaultSide: P2pConflictSide.remote,
        fieldChoices: <String, P2pFieldConflictChoice>{
          note.conflictId: P2pFieldConflictChoice.local,
        },
      );
      expect(resolution.effectiveSide(personality), P2pConflictSide.remote);
      expect(resolution.effectiveSide(note), P2pConflictSide.local);
      expect(resolution.areAllResolved(result.conflicts), isTrue);
    });
  });
}
