import "dart:collection";
import "dart:convert";

import "p2p_revision_models.dart";
import "p2p_snapshot_models.dart";
import "p2p_sync_models.dart";

enum P2pBootstrapPeerUnavailableReason {
  unreachable,
  noProject,
  invalidMetadata,
}

sealed class P2pBootstrapPeerObservation {
  final String peerDeviceId;

  P2pBootstrapPeerObservation({required String peerDeviceId})
    : peerDeviceId = _normalizeDeviceId(peerDeviceId);
}

final class P2pBootstrapPeerReply extends P2pBootstrapPeerObservation {
  final P2pRevisionSummary summary;
  final P2pSnapshotManifest? headManifest;

  P2pBootstrapPeerReply({
    required super.peerDeviceId,
    required this.summary,
    required this.headManifest,
  });
}

final class P2pBootstrapPeerUnavailable extends P2pBootstrapPeerObservation {
  final P2pBootstrapPeerUnavailableReason reason;

  P2pBootstrapPeerUnavailable({
    required super.peerDeviceId,
    required this.reason,
  });
}

sealed class P2pBootstrapDecision {
  const P2pBootstrapDecision();
}

final class P2pBootstrapNotEligible extends P2pBootstrapDecision {
  final int originalPeerCount;

  const P2pBootstrapNotEligible._({required this.originalPeerCount});
}

final class P2pBootstrapSourceUnavailable extends P2pBootstrapDecision {
  final Set<String> unavailablePeerDeviceIds;

  P2pBootstrapSourceUnavailable._({
    required Iterable<String> unavailablePeerDeviceIds,
  }) : unavailablePeerDeviceIds = UnmodifiableSetView(
         SplayTreeSet<String>.of(unavailablePeerDeviceIds),
       );
}

final class P2pBootstrapConflict extends P2pBootstrapDecision {
  final Set<String> conflictingPeerDeviceIds;

  P2pBootstrapConflict._({required Iterable<String> conflictingPeerDeviceIds})
    : conflictingPeerDeviceIds = UnmodifiableSetView(
        SplayTreeSet<String>.of(conflictingPeerDeviceIds),
      );
}

final class P2pBootstrapReady extends P2pBootstrapDecision {
  final String projectUuid;
  final P2pRevisionMetadata head;
  final P2pSnapshotManifest manifest;
  final String sourcePeerDeviceId;
  final Set<String> confirmingPeerDeviceIds;

  P2pBootstrapReady._({
    required this.projectUuid,
    required this.head,
    required this.manifest,
    required this.sourcePeerDeviceId,
    required Iterable<String> confirmingPeerDeviceIds,
  }) : confirmingPeerDeviceIds = UnmodifiableSetView(
         SplayTreeSet<String>.of(confirmingPeerDeviceIds),
       );
}

/// Plans a new-device bootstrap without downloading or applying project data.
///
/// Callers must provide the complete original peer roster. A missing reply is
/// therefore distinguishable from a group that contains only one original
/// peer. Production content transfer remains outside this domain planner.
final class P2pBootstrapConsensusPlanner {
  static const int maxOriginalPeerCount = 64;

  const P2pBootstrapConsensusPlanner();

  P2pBootstrapDecision plan({
    required String joiningDeviceId,
    required Iterable<String> originalPeerDeviceIds,
    required Iterable<P2pBootstrapPeerObservation> observations,
  }) {
    final normalizedJoiningDeviceId = _normalizeDeviceId(joiningDeviceId);
    final originalPeers = _normalizeUniquePeerIds(originalPeerDeviceIds);
    if (originalPeers.length > maxOriginalPeerCount) {
      throw const FormatException("P2P bootstrap 原始 peer 數量超過限制。");
    }
    if (originalPeers.contains(normalizedJoiningDeviceId)) {
      throw const FormatException("P2P bootstrap 加入裝置不可已存在於原始 peer roster。");
    }
    if (originalPeers.length < 2) {
      return P2pBootstrapNotEligible._(originalPeerCount: originalPeers.length);
    }

    final repliesByPeer = <String, P2pBootstrapPeerObservation>{};
    for (final observation in observations) {
      if (!originalPeers.contains(observation.peerDeviceId)) {
        throw const FormatException(
          "P2P bootstrap observation 不屬於原始 peer roster。",
        );
      }
      if (repliesByPeer.containsKey(observation.peerDeviceId)) {
        throw const FormatException("P2P bootstrap peer observation 不可重複。");
      }
      repliesByPeer[observation.peerDeviceId] = observation;
    }

    final unavailablePeers = <String>{};
    final verifiedReplies = <P2pBootstrapPeerReply>[];
    for (final peerDeviceId in originalPeers) {
      final observation = repliesByPeer[peerDeviceId];
      if (observation is! P2pBootstrapPeerReply) {
        unavailablePeers.add(peerDeviceId);
        continue;
      }
      final heads = observation.summary.heads;
      final manifest = observation.headManifest;
      if (heads.isEmpty || manifest == null) {
        unavailablePeers.add(peerDeviceId);
        continue;
      }
      if (heads.length != 1) {
        return P2pBootstrapConflict._(conflictingPeerDeviceIds: originalPeers);
      }
      final head = heads.single;
      if (!manifest.matchesRevision(
        revisionProjectUuid: head.projectUuid,
        revisionId: head.revisionId,
        revisionContentSha256: head.contentSha256,
        revisionFormatVersion: head.formatVersion,
      )) {
        unavailablePeers.add(peerDeviceId);
        continue;
      }
      verifiedReplies.add(observation);
    }
    if (unavailablePeers.isNotEmpty) {
      return P2pBootstrapSourceUnavailable._(
        unavailablePeerDeviceIds: unavailablePeers,
      );
    }

    final firstReply = verifiedReplies.first;
    final expectedKey = _consensusKey(firstReply);
    if (verifiedReplies.any((reply) => _consensusKey(reply) != expectedKey)) {
      return P2pBootstrapConflict._(conflictingPeerDeviceIds: originalPeers);
    }

    final sourcePeerDeviceId = originalPeers.first;
    final sourceReply =
        repliesByPeer[sourcePeerDeviceId]! as P2pBootstrapPeerReply;
    final head = sourceReply.summary.heads.single;
    return P2pBootstrapReady._(
      projectUuid: head.projectUuid,
      head: head,
      manifest: sourceReply.headManifest!,
      sourcePeerDeviceId: sourcePeerDeviceId,
      confirmingPeerDeviceIds: originalPeers,
    );
  }

  static SplayTreeSet<String> _normalizeUniquePeerIds(Iterable<String> values) {
    final result = SplayTreeSet<String>();
    for (final value in values) {
      final normalized = _normalizeDeviceId(value);
      if (!result.add(normalized)) {
        throw const FormatException("P2P bootstrap 原始 peer ID 不可重複。");
      }
    }
    return result;
  }

  static String _consensusKey(P2pBootstrapPeerReply reply) {
    return jsonEncode(<String, Object?>{
      "head": reply.summary.heads.single.toJson(),
      "manifest": reply.headManifest!.toJson(),
    });
  }
}

String _normalizeDeviceId(String value) {
  final normalized = value.trim().toLowerCase();
  if (!P2pProjectStatus.isValidProjectUuid(normalized)) {
    throw const FormatException("P2P bootstrap peer device ID 無效。");
  }
  return normalized;
}
