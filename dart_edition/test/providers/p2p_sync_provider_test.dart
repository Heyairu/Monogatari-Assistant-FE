import "dart:async";
import "dart:convert";
import "dart:io";

import "package:cryptography/cryptography.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/application/collaboration/project_collaborative_text_codec.dart";
import "package:monogatari_assistant/application/collaboration/project_record_codec.dart";
import "package:monogatari_assistant/data/p2p/p2p_endpoint_service.dart";
import "package:monogatari_assistant/data/p2p/p2p_identity_store.dart";
import "package:monogatari_assistant/data/p2p/p2p_lan_permission_gateway.dart";
import "package:monogatari_assistant/data/p2p/p2p_revision_store.dart";
import "package:monogatari_assistant/data/p2p/p2p_secure_channel.dart";
import "package:monogatari_assistant/data/p2p/p2p_snapshot_content_store.dart";
import "package:monogatari_assistant/data/p2p/p2p_snapshot_download.dart";
import "package:monogatari_assistant/data/p2p/p2p_snapshot_endpoint_gateway.dart";
import "package:monogatari_assistant/data/p2p/p2p_snapshot_quarantine.dart";
import "package:monogatari_assistant/domain/collaboration/collaboration_protocol.dart";
import "package:monogatari_assistant/domain/collaboration/collaboration_document.dart";
import "package:monogatari_assistant/domain/collaboration/collaboration_operation.dart";
import "package:monogatari_assistant/domain/models/p2p_pairing_models.dart";
import "package:monogatari_assistant/domain/models/p2p_revision_models.dart";
import "package:monogatari_assistant/domain/models/p2p_resolution_models.dart";
import "package:monogatari_assistant/domain/models/p2p_snapshot_models.dart";
import "package:monogatari_assistant/domain/models/p2p_sync_models.dart";
import "package:monogatari_assistant/models/base_info_data.dart";
import "package:monogatari_assistant/models/chapter_selection_data.dart";
import "package:monogatari_assistant/models/character_data.dart";
import "package:monogatari_assistant/models/project_data.dart";
import "package:monogatari_assistant/presentation/providers/collaboration_providers.dart";
import "package:monogatari_assistant/presentation/providers/editor_coordinator_provider.dart";
import "package:monogatari_assistant/presentation/providers/global_state_providers.dart";
import "package:monogatari_assistant/presentation/providers/p2p_sync_providers.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";
import "package:shared_preferences/shared_preferences.dart";

P2pProjectStatus _savedProject(String uuid, String name) {
  return P2pProjectStatus(
    fileName: name,
    hasPersistentLocation: true,
    hasUnsavedChanges: false,
    projectUuid: uuid,
    isPersistedSnapshotValidated: true,
  );
}

ProjectData _multiBatchBootstrapProject(String projectUuid) {
  final chapters = List<ChapterData>.generate(
    40,
    (index) => ChapterData(
      chapterUUID: "chapter-$index",
      chapterName: "Chapter $index",
      chapterContent: "Content $index",
    ),
  );
  return ProjectData.empty(projectUUID: projectUuid)
    ..baseInfoData = const BaseInfoData(
      bookName: "Synced Book",
      author: "Author",
    )
    ..segmentsData = <SegmentData>[
      SegmentData(
        segmentUUID: "folder-1",
        segmentName: "Folder",
        chapters: chapters,
        childNodeOrder: chapters
            .map((chapter) => chapter.chapterUUID)
            .toList(growable: false),
      ),
    ]
    ..characterData = const <String, CharacterEntryData>{
      "character-1": CharacterEntryData(
        characterId: "character-1",
        displayName: "Synced Character",
      ),
    };
}

class _MemorySecureStore implements P2pSecureKeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _DelayedSecureStore extends _MemorySecureStore {
  final Completer<void> ready = Completer<void>();

  @override
  Future<String?> read(String key) async {
    await ready.future;
    return super.read(key);
  }
}

class _MemoryRevisionStore implements P2pRevisionKeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _MemorySnapshotContentStore implements P2pSnapshotContentStore {
  final Map<String, List<int>> snapshots = <String, List<int>>{};

  @override
  Future<void> writeSnapshot(
    P2pSnapshotManifest manifest,
    List<int> bytes,
  ) async {
    snapshots[manifest.revisionId] = List<int>.unmodifiable(bytes);
  }

  @override
  Future<bool> containsVerifiedSnapshot(P2pSnapshotManifest manifest) async {
    return snapshots[manifest.revisionId]?.length == manifest.contentLength;
  }

  @override
  Future<P2pSnapshotChunk> readChunk(
    P2pSnapshotManifest manifest,
    int chunkIndex,
  ) async {
    final bytes = snapshots[manifest.revisionId];
    if (bytes == null) throw StateError("snapshot missing");
    final start = chunkIndex * manifest.chunkSize;
    final end = (start + manifest.chunkSize) < bytes.length
        ? start + manifest.chunkSize
        : bytes.length;
    return P2pSnapshotChunk(
      projectUuid: manifest.projectUuid,
      revisionId: manifest.revisionId,
      chunkIndex: chunkIndex,
      chunkCount: manifest.chunkCount,
      bytes: bytes.sublist(start, end),
    );
  }
}

class _FakeP2pEndpointService implements P2pEndpointService {
  bool collaborationStreamActive = false;
  bool collaborationStreamSupported = true;
  _FakeP2pEndpointService? collaborationPeer;
  String collaborationRemoteAddress = "192.168.1.30";
  final StreamController<P2pInboundProbe> _inboundProbeController =
      StreamController<P2pInboundProbe>.broadcast();
  final StreamController<P2pInboundProjectOffer>
  _inboundProjectOfferController =
      StreamController<P2pInboundProjectOffer>.broadcast();
  final StreamController<P2pInboundPairingChallenge>
  _inboundPairingChallengeController =
      StreamController<P2pInboundPairingChallenge>.broadcast();
  final StreamController<P2pInboundPairingConfirmation>
  _inboundPairingConfirmationController =
      StreamController<P2pInboundPairingConfirmation>.broadcast();
  final StreamController<P2pInboundRevisionSummary>
  _inboundRevisionSummaryController =
      StreamController<P2pInboundRevisionSummary>.broadcast();
  final StreamController<P2pInboundRevisionGraph>
  _inboundRevisionGraphController =
      StreamController<P2pInboundRevisionGraph>.broadcast();
  final StreamController<P2pInboundCollaborationBatch>
  _inboundCollaborationBatchController =
      StreamController<P2pInboundCollaborationBatch>.broadcast();
  List<String> addresses = const <String>["192.168.1.20"];
  Object? startError;
  Object? probeError;
  int? startedPort;
  P2pEndpoint? probedEndpoint;
  int stopCount = 0;
  int disposeCount = 0;
  int disconnectNoticeCount = 0;
  bool disconnectOnNextExchange = false;
  P2pProjectOffer localOffer = const P2pProjectOffer.none();
  P2pProjectOffer negotiatedRemoteOffer = const P2pProjectOffer.none();
  P2pPairingChallenge? localPairingChallenge;
  P2pPairingChallenge? negotiatedRemotePairingChallenge;
  P2pPairingConfirmation? localPairingConfirmation;
  P2pPairingConfirmation? negotiatedRemotePairingConfirmation;
  P2pSecureSessionKeys? installedSessionKeys;
  P2pRevisionSummary? localRevisionSummary;
  P2pRevisionSummary? negotiatedRemoteRevisionSummary;
  P2pRevisionGraph? localRevisionGraph;
  P2pRevisionGraph? negotiatedRemoteRevisionGraph;
  CollaborationSyncBatch? localCollaborationBatch;
  CollaborationSyncBatch? negotiatedRemoteCollaborationBatch;
  P2pResolutionAck? localResolutionAck;
  P2pResolutionAck? negotiatedRemoteResolutionAck;
  P2pSnapshotManifest? localSnapshotManifest;
  P2pSnapshotManifest? negotiatedRemoteSnapshotManifest;
  P2pSnapshotSyncRequest? localSnapshotSyncRequest;
  P2pSnapshotSyncRequest? negotiatedRemoteSnapshotSyncRequest;
  bool snapshotContentTransferEnabled = false;
  P2pSnapshotChunkLoader? snapshotChunkLoader;
  P2pSnapshotChunkLoader? negotiatedSnapshotChunkLoader;

  @override
  bool get hasActiveCollaborationStream => collaborationStreamActive;

  @override
  Stream<P2pInboundProbe> get inboundProbes => _inboundProbeController.stream;

  @override
  Stream<P2pInboundProjectOffer> get inboundProjectOffers =>
      _inboundProjectOfferController.stream;

  @override
  Stream<P2pInboundPairingChallenge> get inboundPairingChallenges =>
      _inboundPairingChallengeController.stream;

  @override
  Stream<P2pInboundPairingConfirmation> get inboundPairingConfirmations =>
      _inboundPairingConfirmationController.stream;

  @override
  Stream<P2pInboundRevisionSummary> get inboundRevisionSummaries =>
      _inboundRevisionSummaryController.stream;

  @override
  Stream<P2pInboundRevisionGraph> get inboundRevisionGraphs =>
      _inboundRevisionGraphController.stream;

  @override
  Stream<P2pInboundCollaborationBatch> get inboundCollaborationBatches =>
      _inboundCollaborationBatchController.stream;

  void emitInboundProbe(String remoteAddress) {
    _inboundProbeController.add(P2pInboundProbe(remoteAddress: remoteAddress));
  }

  void emitInboundProjectOffer(String remoteAddress, P2pProjectOffer offer) {
    _inboundProjectOfferController.add(
      P2pInboundProjectOffer(remoteAddress: remoteAddress, offer: offer),
    );
  }

  void emitInboundCollaborationBatch(
    String remoteAddress,
    CollaborationSyncBatch batch,
  ) {
    _inboundCollaborationBatchController.add(
      P2pInboundCollaborationBatch(remoteAddress: remoteAddress, batch: batch),
    );
  }

  void emitInboundPairingChallenge(
    String remoteAddress,
    P2pPairingChallenge challenge,
  ) {
    _inboundPairingChallengeController.add(
      P2pInboundPairingChallenge(
        remoteAddress: remoteAddress,
        challenge: challenge,
      ),
    );
  }

  void emitInboundPairingConfirmation(
    String remoteAddress,
    P2pPairingConfirmation confirmation,
  ) {
    _inboundPairingConfirmationController.add(
      P2pInboundPairingConfirmation(
        remoteAddress: remoteAddress,
        confirmation: confirmation,
      ),
    );
  }

  void emitInboundRevisionSummary(
    String remoteAddress,
    P2pRevisionSummary summary, {
    int? remoteServicePort,
    P2pSnapshotManifest? headManifest,
  }) {
    _inboundRevisionSummaryController.add(
      P2pInboundRevisionSummary(
        remoteAddress: remoteAddress,
        remoteServicePort: remoteServicePort,
        summary: summary,
        headManifest: headManifest,
      ),
    );
  }

  @override
  void updateLocalProjectOffer(P2pProjectOffer offer) {
    localOffer = offer;
  }

  @override
  void requestDisconnectOnNextExchange() {
    disconnectOnNextExchange = true;
  }

  @override
  void updateLocalPairingChallenge(P2pPairingChallenge? challenge) {
    localPairingChallenge = challenge;
  }

  @override
  void updateLocalPairingConfirmation(P2pPairingConfirmation? confirmation) {
    localPairingConfirmation = confirmation;
  }

  @override
  void installAuthenticatedSession(P2pSecureSessionKeys? keys) {
    installedSessionKeys?.destroy();
    installedSessionKeys = keys;
    if (keys == null) localSnapshotSyncRequest = null;
    snapshotContentTransferEnabled = false;
    snapshotChunkLoader = null;
  }

  @override
  void updateLocalRevisionSummary(P2pRevisionSummary? summary) {
    localRevisionSummary = summary;
  }

  @override
  void updateLocalRevisionGraph(P2pRevisionGraph? graph) {
    localRevisionGraph = graph;
  }

  @override
  void updateLocalCollaborationBatch(CollaborationSyncBatch? batch) {
    localCollaborationBatch = batch;
  }

  @override
  void updateLocalResolutionAck(P2pResolutionAck? ack) {
    localResolutionAck = ack;
  }

  @override
  void updateLocalSnapshotManifests(Iterable<P2pSnapshotManifest> manifests) {
    localSnapshotManifest = manifests.firstOrNull;
  }

  @override
  void updateLocalSnapshotSyncRequest(P2pSnapshotSyncRequest? request) {
    localSnapshotSyncRequest = request;
  }

  @override
  void configureSnapshotContentTransfer({
    required bool enabled,
    P2pSnapshotChunkLoader? loader,
  }) {
    snapshotContentTransferEnabled = enabled;
    snapshotChunkLoader = enabled ? loader : null;
  }

  @override
  Future<List<String>> listPrivateIpv4Addresses() async => addresses;

  @override
  Future<P2pListeningEndpoint> start({required int port}) async {
    final error = startError;
    if (error != null) throw error;
    startedPort = port;
    return P2pListeningEndpoint(port: port);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> probe(
    P2pEndpoint endpoint, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final error = probeError;
    if (error != null) throw error;
    probedEndpoint = endpoint;
  }

  @override
  Future<P2pProjectOffer> negotiateProjectOffer(
    P2pEndpoint endpoint,
    P2pProjectOffer localOffer, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final error = probeError;
    if (error != null) throw error;
    probedEndpoint = endpoint;
    this.localOffer = localOffer;
    if (disconnectOnNextExchange) {
      disconnectOnNextExchange = false;
      return const P2pProjectOffer.disconnect();
    }
    return negotiatedRemoteOffer;
  }

  @override
  Future<void> notifyDisconnect(
    P2pEndpoint endpoint, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    disconnectNoticeCount++;
  }

  @override
  Future<P2pPairingChallenge?> negotiatePairingChallenge(
    P2pEndpoint endpoint,
    P2pPairingChallenge challenge, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    localPairingChallenge = challenge;
    return negotiatedRemotePairingChallenge;
  }

  @override
  Future<P2pPairingConfirmation?> negotiatePairingConfirmation(
    P2pEndpoint endpoint,
    P2pPairingConfirmation? confirmation, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    localPairingConfirmation = confirmation;
    return negotiatedRemotePairingConfirmation;
  }

  @override
  Future<P2pRevisionSummaryExchange> negotiateRevisionSummary(
    P2pEndpoint endpoint,
    P2pRevisionSummary localSummary, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (installedSessionKeys == null) {
      throw StateError("secure session missing");
    }
    localRevisionSummary = localSummary;
    return P2pRevisionSummaryExchange(
      summary: negotiatedRemoteRevisionSummary ?? localSummary,
      headManifest: negotiatedRemoteSnapshotManifest,
      syncRequest: negotiatedRemoteSnapshotSyncRequest,
      resolutionAck: negotiatedRemoteResolutionAck,
    );
  }

  @override
  Future<P2pRevisionGraphPageExchange> negotiateRevisionGraphPage(
    P2pEndpoint endpoint, {
    required int localPageIndex,
    required int remotePageIndex,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (installedSessionKeys == null) {
      throw StateError("secure session missing");
    }
    final graph = negotiatedRemoteRevisionGraph ?? localRevisionGraph;
    if (graph == null) throw StateError("remote graph missing");
    final revisions = graph.topologicallySortedRevisions;
    final pageCount = revisions.isEmpty
        ? 1
        : (revisions.length + P2pRevisionGraphPage.maxRevisionsPerPage - 1) ~/
              P2pRevisionGraphPage.maxRevisionsPerPage;
    if (remotePageIndex < 0 || remotePageIndex >= pageCount) {
      throw const FormatException("remote page index invalid");
    }
    final digest = await Sha256().hash(utf8.encode(jsonEncode(graph.toJson())));
    final start = remotePageIndex * P2pRevisionGraphPage.maxRevisionsPerPage;
    final end = (start + P2pRevisionGraphPage.maxRevisionsPerPage).clamp(
      0,
      revisions.length,
    );
    return P2pRevisionGraphPageExchange(
      acknowledgedLocalPageIndex: localPageIndex,
      remotePage: P2pRevisionGraphPage(
        projectUuid: graph.projectUuid,
        transferId: digest.bytes
            .map((value) => value.toRadixString(16).padLeft(2, "0"))
            .join(),
        pageIndex: remotePageIndex,
        pageCount: pageCount,
        totalRevisionCount: revisions.length,
        revisions: revisions.sublist(start, end),
        headIds: graph.headIds,
      ),
    );
  }

  @override
  Future<CollaborationSyncBatch> negotiateCollaborationBatch(
    P2pEndpoint endpoint,
    CollaborationSyncBatch localBatch, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    localCollaborationBatch = localBatch;
    collaborationPeer?.emitInboundCollaborationBatch(
      collaborationRemoteAddress,
      localBatch,
    );
    return negotiatedRemoteCollaborationBatch ??
        collaborationPeer?.localCollaborationBatch ??
        localBatch;
  }

  @override
  Future<bool> openCollaborationStream(
    P2pEndpoint endpoint, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!collaborationStreamSupported) return false;
    collaborationStreamActive = true;
    return true;
  }

  @override
  Future<P2pSnapshotManifest?> negotiateSnapshotManifest(
    P2pEndpoint endpoint, {
    required String projectUuid,
    required String revisionId,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (installedSessionKeys == null) {
      throw StateError("secure session missing");
    }
    final manifest = negotiatedRemoteSnapshotManifest;
    return manifest?.projectUuid == projectUuid &&
            manifest?.revisionId == revisionId
        ? manifest
        : null;
  }

  @override
  Future<P2pSnapshotChunk?> negotiateSnapshotChunk(
    P2pEndpoint endpoint,
    P2pSnapshotChunkRequest request, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (installedSessionKeys == null || !snapshotContentTransferEnabled) {
      throw StateError("snapshot transport unavailable");
    }
    return negotiatedSnapshotChunkLoader?.call(
      request.manifest,
      request.chunkIndex,
    );
  }

  @override
  Future<List<P2pSnapshotChunk?>> negotiateSnapshotChunks(
    P2pEndpoint endpoint,
    List<P2pSnapshotChunkRequest> requests, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (installedSessionKeys == null || !snapshotContentTransferEnabled) {
      throw StateError("snapshot transport unavailable");
    }
    final chunks = <P2pSnapshotChunk?>[];
    for (final request in requests) {
      chunks.add(
        await negotiatedSnapshotChunkLoader?.call(
          request.manifest,
          request.chunkIndex,
        ),
      );
    }
    return chunks;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    await _inboundProbeController.close();
    await _inboundProjectOfferController.close();
    await _inboundPairingChallengeController.close();
    await _inboundPairingConfirmationController.close();
    await _inboundRevisionSummaryController.close();
    await _inboundRevisionGraphController.close();
    await _inboundCollaborationBatchController.close();
    installedSessionKeys?.destroy();
  }
}

class _FakeP2pLanPermissionGateway implements P2pLanPermissionGateway {
  bool granted;
  int requestCount = 0;

  _FakeP2pLanPermissionGateway({required this.granted});

  @override
  Future<bool> ensureAccess() async {
    requestCount++;
    return granted;
  }
}

class _FixedP2pSyncNotifier extends P2pSyncNotifier {
  final P2pSyncState initialState;

  _FixedP2pSyncNotifier(this.initialState);

  @override
  P2pSyncState build() => initialState;

  void replaceState(P2pSyncState nextState) {
    state = nextState;
  }
}

void main() {
  test("P2P provider initializes, starts, probes, and stops", () async {
    final service = _FakeP2pEndpointService();
    final container = ProviderContainer(
      overrides: [p2pEndpointServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(p2pSyncProvider.notifier);

    await notifier.initialize();
    expect(container.read(p2pSyncProvider).localAddresses, const <String>[
      "192.168.1.20",
    ]);

    expect(await notifier.startService(42942), isTrue);
    expect(service.startedPort, 42942);
    expect(container.read(p2pSyncProvider).isListening, isTrue);

    const endpoint = P2pEndpoint(host: "192.168.1.30", port: 42942);
    expect(await notifier.probePeer(endpoint), isTrue);
    expect(service.probedEndpoint, endpoint);
    expect(
      container.read(p2pSyncProvider).connectionStatus,
      P2pConnectionStatus.reachableUnpaired,
    );

    await notifier.stopService();
    expect(service.stopCount, 1);
    expect(
      container.read(p2pSyncProvider).serviceStatus,
      P2pServiceStatus.stopped,
    );
    expect(
      container.read(p2pSyncProvider).connectionStatus,
      P2pConnectionStatus.idle,
    );
  });

  test(
    "P2P provider never reports success when start or probe fails",
    () async {
      final service = _FakeP2pEndpointService()
        ..startError = StateError("address in use");
      final container = ProviderContainer(
        overrides: [p2pEndpointServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(p2pSyncProvider.notifier);

      expect(await notifier.startService(42942), isFalse);
      expect(
        container.read(p2pSyncProvider).serviceStatus,
        P2pServiceStatus.error,
      );

      service.probeError = TimeoutException("timeout");
      const endpoint = P2pEndpoint(host: "192.168.1.30", port: 42942);
      expect(await notifier.probePeer(endpoint), isFalse);
      expect(
        container.read(p2pSyncProvider).connectionStatus,
        P2pConnectionStatus.error,
      );
      expect(container.read(p2pSyncProvider).reachablePeer, isNull);
    },
  );

  test(
    "P2P provider blocks sockets when Android LAN access is denied",
    () async {
      final service = _FakeP2pEndpointService();
      final permission = _FakeP2pLanPermissionGateway(granted: false);
      final container = ProviderContainer(
        overrides: [
          p2pEndpointServiceProvider.overrideWithValue(service),
          p2pLanPermissionGatewayProvider.overrideWithValue(permission),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(p2pSyncProvider.notifier);

      expect(await notifier.startService(42942), isFalse);
      expect(service.startedPort, isNull);
      expect(container.read(p2pSyncProvider).errorMessage, contains("附近裝置權限"));

      const endpoint = P2pEndpoint(host: "192.168.1.30", port: 42942);
      expect(await notifier.probePeer(endpoint), isFalse);
      expect(service.probedEndpoint, isNull);
      expect(permission.requestCount, 2);
    },
  );

  test("P2P provider accepts an inbound probe as reachable", () async {
    final service = _FakeP2pEndpointService();
    final container = ProviderContainer(
      overrides: [p2pEndpointServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    container.read(p2pSyncProvider);

    service.emitInboundProbe("192.168.1.30");
    await pumpEventQueue();

    final state = container.read(p2pSyncProvider);
    expect(state.connectionStatus, P2pConnectionStatus.reachableUnpaired);
    expect(state.inboundPeerAddress, "192.168.1.30");
    expect(state.errorMessage, isNull);
    expect(state.message, contains("不需要再從本機反向連線"));
  });

  test("P2P provider automatically uses the only available project", () async {
    final service = _FakeP2pEndpointService()
      ..negotiatedRemoteOffer = P2pProjectOffer.project(
        projectUuid: "123e4567-e89b-12d3-a456-426614174000",
        fileName: "remote.mnproj",
      );
    final container = ProviderContainer(
      overrides: [p2pEndpointServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(p2pSyncProvider.notifier);

    expect(
      await notifier.connectAndNegotiate(
        const P2pEndpoint(host: "192.168.1.30", port: 42942),
        null,
      ),
      isTrue,
    );

    final state = container.read(p2pSyncProvider);
    expect(
      state.projectNegotiation?.kind,
      P2pProjectNegotiationKind.remoteProvides,
    );
    expect(state.selectedProjectSource, P2pProjectSource.remote);
    expect(state.projectNegotiation?.requiresDialog, isFalse);
  });

  test("P2P provider asks only for missing-both or UUID mismatch", () async {
    final service = _FakeP2pEndpointService();
    final container = ProviderContainer(
      overrides: [p2pEndpointServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(p2pSyncProvider.notifier);
    const endpoint = P2pEndpoint(host: "192.168.1.30", port: 42942);

    expect(await notifier.connectAndNegotiate(endpoint, null), isTrue);
    expect(
      container.read(p2pSyncProvider).projectNegotiation?.selectionReason,
      P2pProjectSelectionReason.bothMissing,
    );

    service.negotiatedRemoteOffer = P2pProjectOffer.project(
      projectUuid: "223e4567-e89b-12d3-a456-426614174000",
      fileName: "remote.mnproj",
    );
    expect(
      await notifier.connectAndNegotiate(
        endpoint,
        _savedProject("123e4567-e89b-12d3-a456-426614174000", "local.mnproj"),
      ),
      isTrue,
    );
    expect(
      container.read(p2pSyncProvider).projectNegotiation?.selectionReason,
      P2pProjectSelectionReason.projectUuidMismatch,
    );
    notifier.selectProjectSource(P2pProjectSource.remote);
    expect(
      container.read(p2pSyncProvider).selectedProjectSource,
      P2pProjectSource.remote,
    );
  });

  test(
    "P2P provider disconnects a peer without stopping its listener",
    () async {
      final service = _FakeP2pEndpointService();
      final container = ProviderContainer(
        overrides: [p2pEndpointServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(p2pSyncProvider.notifier);

      await notifier.startService(42942);
      service.emitInboundProbe("192.168.1.30");
      await pumpEventQueue();
      notifier.disconnectPeer();

      final state = container.read(p2pSyncProvider);
      expect(state.isListening, isTrue);
      expect(state.connectionStatus, P2pConnectionStatus.idle);
      expect(state.remoteProjectOffer, isNull);
    },
  );

  test(
    "P2P provider closes missing-file negotiation when local opens one",
    () async {
      final service = _FakeP2pEndpointService();
      final container = ProviderContainer(
        overrides: [p2pEndpointServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(p2pSyncProvider.notifier);
      const endpoint = P2pEndpoint(host: "192.168.1.30", port: 42942);

      expect(await notifier.connectAndNegotiate(endpoint, null), isTrue);
      expect(
        container.read(p2pSyncProvider).projectNegotiation?.selectionReason,
        P2pProjectSelectionReason.bothMissing,
      );

      notifier.updateLocalProjectStatus(
        _savedProject("123e4567-e89b-12d3-a456-426614174000", "local.mnproj"),
      );
      await pumpEventQueue();

      final state = container.read(p2pSyncProvider);
      expect(state.projectNegotiation?.requiresDialog, isFalse);
      expect(state.selectedProjectSource, P2pProjectSource.local);
      expect(state.sessionProjectUuid, "123e4567-e89b-12d3-a456-426614174000");
    },
  );

  test(
    "P2P provider keeps the original source after receiver adopts its UUID",
    () async {
      final service = _FakeP2pEndpointService();
      final container = ProviderContainer(
        overrides: [p2pEndpointServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(p2pSyncProvider.notifier);
      const endpoint = P2pEndpoint(host: "192.168.1.30", port: 42942);
      const projectUuid = "123e4567-e89b-12d3-a456-426614174000";

      expect(
        await notifier.connectAndNegotiate(
          endpoint,
          _savedProject(projectUuid, "local.mnproj"),
        ),
        isTrue,
      );
      expect(
        container.read(p2pSyncProvider).selectedProjectSource,
        P2pProjectSource.local,
      );

      service.negotiatedRemoteOffer = P2pProjectOffer.project(
        projectUuid: projectUuid,
        fileName: "記憶體專案",
      );
      await notifier.refreshPeerOffer();

      final state = container.read(p2pSyncProvider);
      expect(
        state.projectNegotiation?.kind,
        P2pProjectNegotiationKind.sameProject,
      );
      expect(state.selectedProjectSource, P2pProjectSource.local);
      expect(state.sessionProjectUuid, projectUuid);
    },
  );

  test(
    "memory receiver selects the first chapter after operation bootstrap",
    () async {
      const projectUuid = "123e4567-e89b-12d3-a456-426614174000";
      const remoteAddress = "192.168.1.30";
      final service = _FakeP2pEndpointService();
      final fixedP2p = _FixedP2pSyncNotifier(const P2pSyncState());
      final container = ProviderContainer(
        overrides: [
          p2pEndpointServiceProvider.overrideWithValue(service),
          p2pSyncProvider.overrideWith(() => fixedP2p),
        ],
      );
      addTearDown(container.dispose);
      container.read(collaborationProvider);

      final remoteOffer = P2pProjectOffer.project(
        projectUuid: projectUuid,
        fileName: "memory.mnproj",
      );
      fixedP2p.replaceState(
        P2pSyncState(
          reachablePeer: const P2pEndpoint(host: remoteAddress, port: 45510),
          remoteProjectOffer: remoteOffer,
          selectedProjectSource: P2pProjectSource.remote,
          sessionProjectUuid: projectUuid,
          secureTransportStatus: P2pSecureTransportStatus.authenticated,
        ),
      );

      expect(container.read(segmentsDataProvider), isEmpty);
      expect(container.read(editorSelectionProvider).selectedChapID, isNull);

      final data = ProjectData.empty(projectUUID: projectUuid);
      final folder = data.segmentsData.single;
      final chapter = folder.chapters.single.copyWith(
        chapterName: "Remote Chapter",
        chapterContent: "遠端章節內容",
      );
      data.segmentsData = [
        folder.copyWith(
          chapters: [chapter],
          childNodeOrder: <String>[chapter.chapterUUID],
        ),
      ];
      final source = CollaborationDocument.operationBacked(
        projectUuid: projectUuid,
        replicaId: "desktop-replica",
        chapterTexts: <String, String>{
          chapter.chapterUUID: chapter.chapterContent,
        },
        projectTexts: ProjectCollaborativeTextCodec.snapshot(data),
        projectRecords: ProjectRecordCodec.snapshot(
          data,
          omitCollaborativeText: true,
        ).values,
      );
      final operations = source.operationsAfter(const <String, int>{});
      expect(operations.length, greaterThan(1));

      CollaborationSyncBatch batch(
        Iterable<CollaborationOperation> selectedOperations,
      ) {
        return CollaborationSyncBatch(
          projectUuid: projectUuid,
          senderReplicaId: source.replicaId,
          acknowledgedSequences: source.acknowledgedSequences,
          operations: selectedOperations,
        );
      }

      service.emitInboundCollaborationBatch(
        remoteAddress,
        batch(operations.take(operations.length - 1)),
      );
      await pumpEventQueue();

      expect(container.read(editorSelectionProvider).selectedChapID, isNull);

      service.emitInboundCollaborationBatch(
        remoteAddress,
        batch(operations.skip(operations.length - 1)),
      );
      await pumpEventQueue();

      expect(
        container.read(editorSelectionProvider).selectedChapID,
        chapter.chapterUUID,
      );
      expect(container.read(editorContentProvider), "遠端章節內容");
    },
  );

  test(
    "operation bootstrap advances from CRDT text batches to typed records",
    () async {
      const projectUuid = "123e4567-e89b-12d3-a456-426614174000";
      const sourceAddress = "192.168.1.20";
      const receiverAddress = "192.168.1.30";
      final sourceService = _FakeP2pEndpointService();
      final receiverService = _FakeP2pEndpointService();
      final sourceP2p = _FixedP2pSyncNotifier(const P2pSyncState());
      final receiverP2p = _FixedP2pSyncNotifier(const P2pSyncState());
      final sourceContainer = ProviderContainer(
        overrides: [
          p2pEndpointServiceProvider.overrideWithValue(sourceService),
          p2pSyncProvider.overrideWith(() => sourceP2p),
        ],
      );
      final receiverContainer = ProviderContainer(
        overrides: [
          p2pEndpointServiceProvider.overrideWithValue(receiverService),
          p2pSyncProvider.overrideWith(() => receiverP2p),
        ],
      );
      addTearDown(sourceContainer.dispose);
      addTearDown(receiverContainer.dispose);

      final data = _multiBatchBootstrapProject(projectUuid);
      final chapters = data.segmentsData.single.chapters;
      sourceContainer.read(collaborationProvider.notifier).openProject(data);
      receiverContainer.read(collaborationProvider);

      final sourceOffer = P2pProjectOffer.project(
        projectUuid: projectUuid,
        fileName: "source.mnproj",
      );
      sourceP2p.replaceState(
        P2pSyncState(
          reachablePeer: const P2pEndpoint(host: receiverAddress, port: 45510),
          localProjectOffer: sourceOffer,
          remoteProjectOffer: const P2pProjectOffer.none(),
          selectedProjectSource: P2pProjectSource.local,
          sessionProjectUuid: projectUuid,
          secureTransportStatus: P2pSecureTransportStatus.authenticated,
        ),
      );
      receiverP2p.replaceState(
        P2pSyncState(
          reachablePeer: const P2pEndpoint(host: sourceAddress, port: 45510),
          remoteProjectOffer: sourceOffer,
          selectedProjectSource: P2pProjectSource.remote,
          sessionProjectUuid: projectUuid,
          secureTransportStatus: P2pSecureTransportStatus.authenticated,
        ),
      );

      final firstSourceBatch = sourceService.localCollaborationBatch;
      expect(firstSourceBatch, isNotNull);
      expect(firstSourceBatch!.operations, hasLength(32));
      expect(
        firstSourceBatch.operations.whereType<ProjectDataRecordOperation>(),
        isEmpty,
      );

      var completed = false;
      for (var exchange = 0; exchange < 10; exchange += 1) {
        receiverService.emitInboundCollaborationBatch(
          sourceAddress,
          sourceService.localCollaborationBatch!,
        );
        await pumpEventQueue();
        sourceService.emitInboundCollaborationBatch(
          receiverAddress,
          receiverService.localCollaborationBatch!,
        );
        await pumpEventQueue();
        completed =
            receiverContainer.read(baseInfoDataProvider).bookName ==
                "Synced Book" &&
            receiverContainer
                    .read(segmentsDataProvider)
                    .singleOrNull
                    ?.chapters
                    .length ==
                chapters.length &&
            receiverContainer
                .read(characterDataProvider)
                .containsKey("character-1");
        if (completed) break;
      }

      expect(completed, isTrue);
      expect(
        receiverContainer.read(editorSelectionProvider).selectedChapID,
        chapters.first.chapterUUID,
      );
      expect(
        receiverContainer.read(editorContentProvider),
        chapters.first.chapterContent,
      );
    },
  );

  test(
    "bounded collaboration polling completes a multi-batch memory project",
    () async {
      const projectUuid = "123e4567-e89b-12d3-a456-426614174000";
      const sourceAddress = "192.168.1.20";
      const receiverAddress = "192.168.1.30";
      final sourceService = _FakeP2pEndpointService()
        ..collaborationStreamSupported = false
        ..collaborationRemoteAddress = sourceAddress;
      final receiverService = _FakeP2pEndpointService()
        ..collaborationStreamSupported = false
        ..collaborationRemoteAddress = receiverAddress;
      sourceService.collaborationPeer = receiverService;
      receiverService.collaborationPeer = sourceService;
      final sourceP2p = _FixedP2pSyncNotifier(const P2pSyncState());
      final receiverP2p = _FixedP2pSyncNotifier(const P2pSyncState());
      final sourceContainer = ProviderContainer(
        overrides: [
          p2pEndpointServiceProvider.overrideWithValue(sourceService),
          p2pSyncProvider.overrideWith(() => sourceP2p),
        ],
      );
      final receiverContainer = ProviderContainer(
        overrides: [
          p2pEndpointServiceProvider.overrideWithValue(receiverService),
          p2pSyncProvider.overrideWith(() => receiverP2p),
        ],
      );
      addTearDown(sourceContainer.dispose);
      addTearDown(receiverContainer.dispose);

      final data = _multiBatchBootstrapProject(projectUuid);
      sourceContainer.read(collaborationProvider.notifier).openProject(data);
      receiverContainer.read(collaborationProvider);
      final aggregateSubscription = receiverContainer.listen<int>(
        projectDataAggregateProvider,
        (previous, next) {
          if (previous == null ||
              previous == next ||
              receiverContainer
                  .read(editorCoordinatorProvider)
                  .isApplyingProjectData) {
            return;
          }
          receiverContainer
              .read(collaborationProvider.notifier)
              .captureProjectData(
                receiverContainer
                    .read(editorCoordinatorProvider.notifier)
                    .collectProjectData(),
              );
        },
      );
      addTearDown(aggregateSubscription.close);
      final sourceOffer = P2pProjectOffer.project(
        projectUuid: projectUuid,
        fileName: "source.mnproj",
      );
      final sourceAuthenticatedState = P2pSyncState(
        reachablePeer: const P2pEndpoint(host: receiverAddress, port: 45510),
        localProjectOffer: sourceOffer,
        remoteProjectOffer: const P2pProjectOffer.none(),
        selectedProjectSource: P2pProjectSource.local,
        sessionProjectUuid: projectUuid,
        secureTransportStatus: P2pSecureTransportStatus.authenticated,
      );
      final receiverAuthenticatedState = P2pSyncState(
        reachablePeer: const P2pEndpoint(host: sourceAddress, port: 45510),
        remoteProjectOffer: sourceOffer,
        selectedProjectSource: P2pProjectSource.remote,
        sessionProjectUuid: projectUuid,
        secureTransportStatus: P2pSecureTransportStatus.authenticated,
      );
      sourceP2p.replaceState(sourceAuthenticatedState);
      receiverP2p.replaceState(receiverAuthenticatedState);

      bool receiverIsComplete() =>
          receiverContainer.read(baseInfoDataProvider).bookName ==
              "Synced Book" &&
          receiverContainer
                  .read(segmentsDataProvider)
                  .singleOrNull
                  ?.chapters
                  .length ==
              40 &&
          receiverContainer
              .read(characterDataProvider)
              .containsKey("character-1");

      Future<bool> waitForReceiver() async {
        for (var attempt = 0; attempt < 60; attempt += 1) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (receiverIsComplete()) return true;
        }
        return false;
      }

      expect(await waitForReceiver(), isTrue);
      expect(
        receiverContainer.read(editorContentProvider),
        data.segmentsData.single.chapters.first.chapterContent,
      );

      sourceP2p.replaceState(const P2pSyncState());
      receiverP2p.replaceState(const P2pSyncState());
      sourceP2p.replaceState(sourceAuthenticatedState);
      receiverP2p.replaceState(receiverAuthenticatedState);

      expect(receiverContainer.read(segmentsDataProvider), isEmpty);
      expect(await waitForReceiver(), isTrue);
      expect(
        receiverContainer.read(editorContentProvider),
        data.segmentsData.single.chapters.first.chapterContent,
      );
    },
  );

  test(
    "P2P provider refresh observes a remote file opened after both missing",
    () async {
      final service = _FakeP2pEndpointService();
      final container = ProviderContainer(
        overrides: [p2pEndpointServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(p2pSyncProvider.notifier);
      const endpoint = P2pEndpoint(host: "192.168.1.30", port: 42942);

      expect(await notifier.connectAndNegotiate(endpoint, null), isTrue);
      service.negotiatedRemoteOffer = P2pProjectOffer.project(
        projectUuid: "223e4567-e89b-12d3-a456-426614174000",
        fileName: "remote.mnproj",
      );
      await notifier.refreshPeerOffer();

      final state = container.read(p2pSyncProvider);
      expect(state.projectNegotiation?.requiresDialog, isFalse);
      expect(state.selectedProjectSource, P2pProjectSource.remote);
      expect(state.sessionProjectUuid, "223e4567-e89b-12d3-a456-426614174000");
    },
  );

  test(
    "P2P provider disconnects both sides when local switches project",
    () async {
      final sameOffer = P2pProjectOffer.project(
        projectUuid: "123e4567-e89b-12d3-a456-426614174000",
        fileName: "remote.mnproj",
      );
      final service = _FakeP2pEndpointService()
        ..negotiatedRemoteOffer = sameOffer;
      final container = ProviderContainer(
        overrides: [p2pEndpointServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(p2pSyncProvider.notifier);
      const endpoint = P2pEndpoint(host: "192.168.1.30", port: 42942);
      await notifier.connectAndNegotiate(
        endpoint,
        _savedProject("123e4567-e89b-12d3-a456-426614174000", "local.mnproj"),
      );

      notifier.updateLocalProjectStatus(
        _savedProject("323e4567-e89b-12d3-a456-426614174000", "other.mnproj"),
      );
      await pumpEventQueue();

      final state = container.read(p2pSyncProvider);
      expect(state.connectionStatus, P2pConnectionStatus.idle);
      expect(state.sessionProjectUuid, isNull);
      expect(state.message, contains("本機已更換同步文件"));
      expect(service.disconnectNoticeCount, 1);
    },
  );

  test(
    "P2P provider disconnects when refreshed peer switches project",
    () async {
      final service = _FakeP2pEndpointService()
        ..negotiatedRemoteOffer = P2pProjectOffer.project(
          projectUuid: "123e4567-e89b-12d3-a456-426614174000",
          fileName: "remote.mnproj",
        );
      final container = ProviderContainer(
        overrides: [p2pEndpointServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(p2pSyncProvider.notifier);
      const endpoint = P2pEndpoint(host: "192.168.1.30", port: 42942);
      await notifier.connectAndNegotiate(
        endpoint,
        _savedProject("123e4567-e89b-12d3-a456-426614174000", "local.mnproj"),
      );

      service.negotiatedRemoteOffer = P2pProjectOffer.project(
        projectUuid: "423e4567-e89b-12d3-a456-426614174000",
        fileName: "other.mnproj",
      );
      await notifier.refreshPeerOffer();

      final state = container.read(p2pSyncProvider);
      expect(state.connectionStatus, P2pConnectionStatus.idle);
      expect(state.message, contains("對方已更換同步文件"));
    },
  );

  test("P2P provider accepts an explicit peer disconnect notice", () async {
    final service = _FakeP2pEndpointService()
      ..negotiatedRemoteOffer = P2pProjectOffer.project(
        projectUuid: "123e4567-e89b-12d3-a456-426614174000",
        fileName: "remote.mnproj",
      );
    final container = ProviderContainer(
      overrides: [p2pEndpointServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(p2pSyncProvider.notifier);
    await notifier.connectAndNegotiate(
      const P2pEndpoint(host: "192.168.1.30", port: 42942),
      _savedProject("123e4567-e89b-12d3-a456-426614174000", "local.mnproj"),
    );

    service.emitInboundProjectOffer(
      "192.168.1.30",
      const P2pProjectOffer.disconnect(),
    );
    await pumpEventQueue();

    final state = container.read(p2pSyncProvider);
    expect(state.connectionStatus, P2pConnectionStatus.idle);
    expect(state.message, contains("對方已更換同步文件"));
  });

  test("P2P provider compares a signed code before trusting a peer", () async {
    final service = _FakeP2pEndpointService();
    final localIdentityStore = P2pIdentityStore(storage: _MemorySecureStore());
    final remoteIdentityStore = P2pIdentityStore(storage: _MemorySecureStore());
    service.negotiatedRemotePairingChallenge = await remoteIdentityStore
        .createPairingChallenge();
    final container = ProviderContainer(
      overrides: [
        p2pEndpointServiceProvider.overrideWithValue(service),
        p2pIdentityStoreProvider.overrideWithValue(localIdentityStore),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(p2pSyncProvider.notifier);
    await notifier.initialize();
    await notifier.connectAndNegotiate(
      const P2pEndpoint(host: "192.168.1.30", port: 42942),
      null,
    );

    expect(await notifier.beginPairing(), isTrue);
    final comparison = container.read(p2pSyncProvider);
    expect(comparison.pairingStatus, P2pPairingStatus.comparisonRequired);
    expect(comparison.pairingCode, matches(RegExp(r"^[0-9]{6}$")));

    expect(await notifier.confirmPairingCode(), isTrue);
    final waiting = container.read(p2pSyncProvider);
    expect(waiting.pairingStatus, P2pPairingStatus.waitingForPeerConfirmation);
    expect(waiting.trustedPeer?.deviceId, isNotNull);
    expect(waiting.localPairingConfirmation, isNotNull);
    expect(await localIdentityStore.loadTrustedPeers(), isNotEmpty);
    expect(waiting.hasAuthenticatedTransport, isFalse);
    expect(service.installedSessionKeys, isNull);

    final remoteConfirmation = await remoteIdentityStore
        .createPairingConfirmation(
          service.negotiatedRemotePairingChallenge!,
          waiting.localPairingChallenge!,
        );
    service.emitInboundPairingConfirmation("192.168.1.30", remoteConfirmation);
    service.emitInboundPairingConfirmation("192.168.1.30", remoteConfirmation);
    await pumpEventQueue();

    final confirmed = container.read(p2pSyncProvider);
    expect(confirmed.pairingStatus, P2pPairingStatus.mutuallyConfirmed);
    expect(confirmed.remotePairingConfirmation, isNotNull);
    expect(confirmed.hasAuthenticatedTransport, isTrue);
    expect(service.installedSessionKeys, isNotNull);
    expect(service.snapshotContentTransferEnabled, isFalse);
    final installedKeys = service.installedSessionKeys;

    service.emitInboundPairingConfirmation("192.168.1.30", remoteConfirmation);
    await pumpEventQueue();

    final afterDuplicate = container.read(p2pSyncProvider);
    expect(afterDuplicate.hasAuthenticatedTransport, isTrue);
    expect(afterDuplicate.secureTransportError, isNull);
    expect(service.installedSessionKeys, same(installedKeys));
  });

  test("P2P provider also completes when the peer confirms first", () async {
    final service = _FakeP2pEndpointService();
    final localIdentityStore = P2pIdentityStore(storage: _MemorySecureStore());
    final remoteIdentityStore = P2pIdentityStore(storage: _MemorySecureStore());
    final remoteChallenge = await remoteIdentityStore.createPairingChallenge();
    service.negotiatedRemotePairingChallenge = remoteChallenge;
    final container = ProviderContainer(
      overrides: [
        p2pEndpointServiceProvider.overrideWithValue(service),
        p2pIdentityStoreProvider.overrideWithValue(localIdentityStore),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(p2pSyncProvider.notifier);
    await notifier.initialize();
    await notifier.connectAndNegotiate(
      const P2pEndpoint(host: "192.168.1.30", port: 42942),
      null,
    );
    await notifier.beginPairing(allowSingleDeviceConfirmation: false);
    final localChallenge = container
        .read(p2pSyncProvider)
        .localPairingChallenge!;
    final remoteConfirmation = await remoteIdentityStore
        .createPairingConfirmation(remoteChallenge, localChallenge);

    service.emitInboundPairingConfirmation("192.168.1.30", remoteConfirmation);
    await pumpEventQueue();
    final peerFirst = container.read(p2pSyncProvider);
    expect(peerFirst.pairingStatus, P2pPairingStatus.comparisonRequired);
    expect(peerFirst.remotePairingConfirmation, isNotNull);

    expect(await notifier.confirmPairingCode(), isTrue);
    expect(
      container.read(p2pSyncProvider).pairingStatus,
      P2pPairingStatus.mutuallyConfirmed,
    );
    expect(
      container.read(p2pSyncProvider).secureTransportStatus,
      P2pSecureTransportStatus.authenticated,
    );
  });

  test("production chunk gateway follows the authenticated project session", () async {
    const projectUuid = "123e4567-e89b-12d3-a456-426614174000";
    const endpoint = P2pEndpoint(host: "192.168.1.30", port: 42942);
    final contentStore = _MemorySnapshotContentStore();
    final revisionStore = P2pRevisionStore(
      storage: _MemoryRevisionStore(),
      contentStore: contentStore,
    );
    final service = _FakeP2pEndpointService()
      ..negotiatedRemoteOffer = P2pProjectOffer.project(
        projectUuid: projectUuid,
        fileName: "remote.mnproj",
      );
    final localIdentityStore = P2pIdentityStore(storage: _MemorySecureStore());
    final remoteIdentityStore = P2pIdentityStore(storage: _MemorySecureStore());
    final remoteChallenge = await remoteIdentityStore.createPairingChallenge();
    service.negotiatedRemotePairingChallenge = remoteChallenge;
    final quarantineDirectory = await Directory.systemTemp.createTemp(
      "monogatari_p2p_transfer_provider_",
    );
    addTearDown(() async {
      if (await quarantineDirectory.exists()) {
        await quarantineDirectory.delete(recursive: true);
      }
    });
    final quarantineStorage = FileSystemP2pSnapshotQuarantineStorage(
      baseDirectory: () async => quarantineDirectory,
    );
    final container = ProviderContainer(
      overrides: [
        p2pEndpointServiceProvider.overrideWithValue(service),
        p2pIdentityStoreProvider.overrideWithValue(localIdentityStore),
        p2pSnapshotContentStoreProvider.overrideWithValue(contentStore),
        p2pRevisionStoreProvider.overrideWithValue(revisionStore),
        p2pSnapshotQuarantineStorageProvider.overrideWithValue(
          quarantineStorage,
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(p2pSyncProvider.notifier);
    await notifier.initialize();
    notifier.updateLocalProjectStatus(
      _savedProject(projectUuid, "local.mnproj"),
    );
    await pumpEventQueue();
    expect(
      await notifier.recordPersistedSnapshot(
        projectUuid: projectUuid,
        xmlContent: "<Project />",
        formatVersion: "1.0",
      ),
      isTrue,
    );
    service.negotiatedRemoteSnapshotManifest = container
        .read(p2pSyncProvider)
        .localSnapshotManifest;
    await notifier.connectAndNegotiate(
      endpoint,
      _savedProject(projectUuid, "local.mnproj"),
    );
    await notifier.beginPairing(allowSingleDeviceConfirmation: false);
    final localChallenge = container
        .read(p2pSyncProvider)
        .localPairingChallenge!;
    final remoteConfirmation = await remoteIdentityStore
        .createPairingConfirmation(remoteChallenge, localChallenge);
    service.emitInboundPairingConfirmation(endpoint.host, remoteConfirmation);
    await pumpEventQueue();
    expect(await notifier.confirmPairingCode(), isTrue);

    final authenticated = container.read(p2pSyncProvider);
    final manifest = authenticated.localSnapshotManifest!;
    expect(authenticated.hasAuthenticatedTransport, isTrue);
    expect(authenticated.hasSnapshotContentTransfer, isTrue);
    expect(authenticated.sessionProjectUuid, projectUuid);
    expect(service.snapshotContentTransferEnabled, isTrue);
    expect(service.snapshotChunkLoader, isNotNull);
    service.emitInboundRevisionSummary(
      endpoint.host,
      P2pRevisionSummary.fromGraph(authenticated.localRevisionGraph!),
      remoteServicePort: 45510,
      headManifest: manifest,
    );
    await pumpEventQueue();
    expect(
      container.read(p2pSyncProvider).reachablePeer,
      const P2pEndpoint(host: "192.168.1.30", port: 45510),
      reason: "the authenticated inbound service port enables a reverse pull",
    );
    expect(
      container.read(p2pSnapshotTransferSessionProvider).current?.endpoint,
      const P2pEndpoint(host: "192.168.1.30", port: 45510),
    );
    service.emitInboundProjectOffer(
      endpoint.host,
      P2pProjectOffer.project(
        projectUuid: projectUuid,
        fileName: "remote-renamed.mnproj",
      ),
    );
    await pumpEventQueue();
    expect(
      container.read(p2pSyncProvider).reachablePeer,
      const P2pEndpoint(host: "192.168.1.30", port: 45510),
      reason:
          "a plaintext project-offer refresh must not revoke the authenticated service endpoint",
    );
    expect(
      container.read(p2pSnapshotTransferSessionProvider).current?.endpoint,
      const P2pEndpoint(host: "192.168.1.30", port: 45510),
    );
    final gateway = container.read(p2pSnapshotChunkGatewayProvider);
    expect(gateway, isA<SessionAwareP2pSnapshotChunkGateway>());
    final unadvertisedManifest = P2pSnapshotManifest(
      projectUuid: projectUuid,
      revisionId: List<String>.filled(64, "a").join(),
      contentSha256: List<String>.filled(64, "b").join(),
      contentLength: 1,
      formatVersion: "1.0",
    );
    await expectLater(
      gateway.requestChunk(unadvertisedManifest, 0),
      throwsA(
        isA<P2pSnapshotChunkTransportException>().having(
          (error) => error.isTransient,
          "isTransient",
          isFalse,
        ),
      ),
    );

    final servedChunk = await service.snapshotChunkLoader!(manifest, 0);
    expect(servedChunk?.bytes, utf8.encode("<Project />"));

    service.negotiatedSnapshotChunkLoader = contentStore.readChunk;
    final downloadedChunk = await gateway.requestChunk(manifest, 0);
    expect(downloadedChunk.bytes, utf8.encode("<Project />"));

    service
      ..negotiatedRemoteRevisionSummary = P2pRevisionSummary(
        projectUuid: projectUuid,
        heads: const <P2pRevisionMetadata>[],
      )
      ..negotiatedRemoteSnapshotManifest = null;
    await notifier.refreshRevisionSummary();
    expect(
      container.read(p2pSyncProvider).revisionSummaryRelation,
      P2pRevisionSummaryRelation.localAhead,
    );
    expect(await notifier.requestImmediateSync(), isTrue);
    expect(service.localSnapshotSyncRequest?.matches(manifest), isTrue);

    final remoteContentStore = _MemorySnapshotContentStore();
    final remoteRevisionStore = P2pRevisionStore(
      storage: _MemoryRevisionStore(),
      contentStore: remoteContentStore,
    );
    await remoteRevisionStore.installVerifiedGraph(
      authenticated.localRevisionGraph!,
    );
    final remoteXml = '<Project UUID="$projectUuid"><ver>1.0</ver></Project>';
    final remoteGraph = await remoteRevisionStore.recordPersistedSnapshot(
      projectUuid: projectUuid,
      authorDeviceId: remoteChallenge.deviceId,
      xmlContent: remoteXml,
      formatVersion: "1.0",
    );
    final remoteManifest = await remoteRevisionStore.loadSnapshotManifest(
      projectUuid: projectUuid,
      revisionId: remoteGraph.singleHead!.revisionId,
    );
    service
      ..negotiatedRemoteRevisionSummary = P2pRevisionSummary.fromGraph(
        remoteGraph,
      )
      ..negotiatedRemoteRevisionGraph = remoteGraph
      ..negotiatedRemoteSnapshotManifest = remoteManifest
      ..negotiatedRemoteSnapshotSyncRequest = P2pSnapshotSyncRequest(
        requestId: "remote-sync-request-0001",
        projectUuid: remoteManifest!.projectUuid,
        revisionId: remoteManifest.revisionId,
        contentSha256: remoteManifest.contentSha256,
      )
      ..negotiatedSnapshotChunkLoader = remoteContentStore.readChunk;
    await notifier.refreshRevisionSummary();
    await notifier.refreshRevisionGraph();
    await pumpEventQueue();
    final remoteAheadState = container.read(p2pSyncProvider);
    expect(
      remoteAheadState.revisionSummaryRelation,
      P2pRevisionSummaryRelation.remoteAhead,
    );
    expect(remoteAheadState.incomingSnapshotSyncRequestGeneration, 1);
    expect(
      remoteAheadState.incomingSnapshotSyncRequest?.matches(remoteManifest),
      isTrue,
    );
    await notifier.refreshRevisionSummary();
    expect(
      container.read(p2pSyncProvider).incomingSnapshotSyncRequestGeneration,
      1,
    );

    final transferNotifier = container.read(
      p2pSnapshotTransferProvider.notifier,
    );
    expect(
      await transferNotifier.downloadRemoteSnapshot(),
      isTrue,
      reason:
          "${container.read(p2pSnapshotTransferProvider).errorMessage} / ${container.read(p2pSyncProvider).revisionMetadataError}",
    );
    expect(
      container.read(p2pSnapshotTransferProvider).status,
      P2pSnapshotTransferStatus.verified,
    );
    expect(
      container.read(p2pSnapshotTransferProvider).verifiedSnapshot?.xmlContent,
      remoteXml,
    );
    expect(
      container
          .read(p2pSyncProvider)
          .remoteRevisionGraph
          ?.singleHead
          ?.revisionId,
      remoteGraph.singleHead!.revisionId,
    );
    var appliedExactVerifiedSnapshot = false;
    final applied = await transferNotifier.applyVerifiedSnapshot((
      snapshot,
    ) async {
      appliedExactVerifiedSnapshot = snapshot.manifest == remoteManifest;
      // Mirrors overwriting an existing same-UUID file: the file/provider
      // layer republishes the local project before remote history commits.
      notifier.updateLocalProjectStatus(
        _savedProject(projectUuid, "local.mnproj"),
      );
      return true;
    });
    expect(
      applied,
      isTrue,
      reason:
          "${container.read(p2pSnapshotTransferProvider).status}: ${container.read(p2pSnapshotTransferProvider).message} / ${container.read(p2pSnapshotTransferProvider).errorMessage} / ${container.read(p2pSyncProvider).revisionMetadataError}",
    );
    expect(appliedExactVerifiedSnapshot, isTrue);
    expect(
      container.read(p2pSnapshotTransferProvider).status,
      P2pSnapshotTransferStatus.applied,
    );

    expect(
      await notifier.recordPersistedSnapshot(
        projectUuid: projectUuid,
        xmlContent:
            '<Project UUID="$projectUuid"><ver>1.0</ver><live>true</live></Project>',
        formatVersion: "1.0",
      ),
      isTrue,
    );
    final liveManifest = container.read(p2pSyncProvider).localSnapshotManifest!;
    expect(liveManifest.revisionId, isNot(remoteManifest.revisionId));
    expect(service.localSnapshotSyncRequest?.matches(liveManifest), isTrue);
    expect(service.localSnapshotSyncRequest?.requestId, startsWith("live-"));
    expect(
      container.read(p2pSnapshotTransferProvider).status,
      P2pSnapshotTransferStatus.idle,
      reason:
          "a new local revision must invalidate the previous applied UI state",
    );
    expect(await transferNotifier.downloadRemoteSnapshot(), isFalse);
    expect(
      container.read(p2pSnapshotTransferProvider).status,
      P2pSnapshotTransferStatus.idle,
      reason:
          "a failed remote download is stale once this device becomes the provider",
    );

    final remoteBranchGraph = await remoteRevisionStore.recordPersistedSnapshot(
      projectUuid: projectUuid,
      authorDeviceId: remoteChallenge.deviceId,
      xmlContent:
          '<Project UUID="$projectUuid"><ver>1.0</ver><remote>true</remote></Project>',
      formatVersion: "1.0",
    );
    final mergedConcurrentGraph = await remoteRevisionStore
        .mergeVerifiedRemoteGraph(
          container.read(p2pSyncProvider).localRevisionGraph!,
        );
    expect(mergedConcurrentGraph.headIds, hasLength(2));
    expect(
      mergedConcurrentGraph.headIds,
      contains(remoteBranchGraph.singleHead!.revisionId),
    );
    final resolvedXml =
        '<Project UUID="$projectUuid"><ver>1.0</ver><resolved>true</resolved></Project>';
    final resolvedGraph = await remoteRevisionStore.recordResolvedSnapshot(
      projectUuid: projectUuid,
      authorDeviceId: remoteChallenge.deviceId,
      parentRevisionIds: mergedConcurrentGraph.headIds,
      xmlContent: resolvedXml,
      formatVersion: "1.0",
    );
    final resolvedHead = resolvedGraph.singleHead!;
    final resolvedManifest = (await remoteRevisionStore.loadSnapshotManifest(
      projectUuid: projectUuid,
      revisionId: resolvedHead.revisionId,
    ))!;
    final remoteAck = P2pResolutionAck(
      projectUuid: projectUuid,
      resolutionRevisionId: resolvedHead.revisionId,
      contentSha256: resolvedHead.contentSha256,
      acceptedByDeviceId: remoteChallenge.deviceId,
      acceptedAtEpochSeconds: 1,
    );
    service
      ..negotiatedRemoteRevisionSummary = P2pRevisionSummary.fromGraph(
        resolvedGraph,
      )
      ..negotiatedRemoteRevisionGraph = resolvedGraph
      ..negotiatedRemoteSnapshotManifest = resolvedManifest
      ..negotiatedRemoteResolutionAck = remoteAck
      ..negotiatedSnapshotChunkLoader = remoteContentStore.readChunk;

    // The summary carries the ACK before the graph page containing the
    // resolve revision. It must remain pending, not be rejected as a mismatch.
    await notifier.refreshRevisionSummary();
    await pumpEventQueue(times: 8);
    final pendingAckState = container.read(p2pSyncProvider);
    expect(pendingAckState.revisionGraphError, isNull);
    expect(pendingAckState.remoteResolutionAck, isNull);
    expect(pendingAckState.message, contains("等待下載並安裝"));
    expect(
      pendingAckState.canDownloadRemoteSnapshot,
      isTrue,
      reason: "a verified pending resolve ACK must not disable its snapshot",
    );
    expect(
      container.read(p2pSnapshotTransferProvider).status,
      P2pSnapshotTransferStatus.idle,
      reason: "a stale pre-manifest authorization error must be cleared",
    );
    expect(
      pendingAckState.remoteRevisionGraph?.revisions,
      contains(resolvedHead.revisionId),
    );

    final delayedChunk = Completer<P2pSnapshotChunk>();
    service.negotiatedSnapshotChunkLoader = (_, _) => delayedChunk.future;
    final lateResponse = gateway.requestChunk(resolvedManifest, 0);
    await pumpEventQueue();
    notifier.disconnectPeer();
    delayedChunk.complete(
      await remoteContentStore.readChunk(resolvedManifest, 0),
    );
    await expectLater(
      lateResponse,
      throwsA(
        isA<P2pSnapshotChunkTransportException>().having(
          (error) => error.isTransient,
          "isTransient",
          isTrue,
        ),
      ),
    );
    expect(service.snapshotContentTransferEnabled, isFalse);
    expect(container.read(p2pSnapshotTransferSessionProvider).current, isNull);
    await expectLater(
      gateway.requestChunk(manifest, 0),
      throwsA(
        isA<P2pSnapshotChunkTransportException>().having(
          (error) => error.isTransient,
          "isTransient",
          isFalse,
        ),
      ),
    );
  });

  test("receiver without a local file accepts the encrypted remote head", () async {
    const projectUuid = "523e4567-e89b-12d3-a456-426614174000";
    const endpoint = P2pEndpoint(host: "192.168.1.30", port: 42942);
    final remoteIdentityStore = P2pIdentityStore(storage: _MemorySecureStore());
    final remoteChallenge = await remoteIdentityStore.createPairingChallenge(
      allowSingleDeviceConfirmation: false,
    );
    final remoteContentStore = _MemorySnapshotContentStore();
    final remoteRevisionStore = P2pRevisionStore(
      storage: _MemoryRevisionStore(),
      contentStore: remoteContentStore,
    );
    final remoteGraph = await remoteRevisionStore.recordPersistedSnapshot(
      projectUuid: projectUuid,
      authorDeviceId: remoteChallenge.deviceId,
      xmlContent: '<Project UUID="$projectUuid"><ver>1.0</ver></Project>',
      formatVersion: "1.0",
    );
    final remoteManifest = (await remoteRevisionStore.loadSnapshotManifest(
      projectUuid: projectUuid,
      revisionId: remoteGraph.singleHead!.revisionId,
    ))!;
    final service = _FakeP2pEndpointService()
      ..negotiatedRemoteOffer = P2pProjectOffer.project(
        projectUuid: projectUuid,
        fileName: "remote.mnproj",
      )
      ..negotiatedRemotePairingChallenge = remoteChallenge
      ..negotiatedRemoteRevisionSummary = P2pRevisionSummary.fromGraph(
        remoteGraph,
      )
      ..negotiatedRemoteRevisionGraph = remoteGraph
      ..negotiatedRemoteSnapshotManifest = remoteManifest
      ..negotiatedRemoteSnapshotSyncRequest = P2pSnapshotSyncRequest(
        requestId: "remote-empty-receiver-0001",
        projectUuid: projectUuid,
        revisionId: remoteManifest.revisionId,
        contentSha256: remoteManifest.contentSha256,
      )
      ..negotiatedSnapshotChunkLoader = remoteContentStore.readChunk;
    final localContentStore = _MemorySnapshotContentStore();
    final quarantineDirectory = await Directory.systemTemp.createTemp(
      "monogatari_p2p_empty_receiver_",
    );
    addTearDown(() async {
      if (await quarantineDirectory.exists()) {
        await quarantineDirectory.delete(recursive: true);
      }
    });
    final container = ProviderContainer(
      overrides: [
        p2pEndpointServiceProvider.overrideWithValue(service),
        p2pIdentityStoreProvider.overrideWithValue(
          P2pIdentityStore(storage: _MemorySecureStore()),
        ),
        p2pSnapshotContentStoreProvider.overrideWithValue(localContentStore),
        p2pRevisionStoreProvider.overrideWithValue(
          P2pRevisionStore(
            storage: _MemoryRevisionStore(),
            contentStore: localContentStore,
          ),
        ),
        p2pSnapshotQuarantineStorageProvider.overrideWithValue(
          FileSystemP2pSnapshotQuarantineStorage(
            baseDirectory: () async => quarantineDirectory,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(p2pSyncProvider.notifier);
    await notifier.initialize();
    expect(await notifier.connectAndNegotiate(endpoint, null), isTrue);
    expect(
      container.read(p2pSyncProvider).projectNegotiation?.kind,
      P2pProjectNegotiationKind.remoteProvides,
    );
    expect(
      await notifier.beginPairing(allowSingleDeviceConfirmation: false),
      isTrue,
    );
    final localChallenge = container
        .read(p2pSyncProvider)
        .localPairingChallenge!;
    final remoteConfirmation = await remoteIdentityStore
        .createPairingConfirmation(remoteChallenge, localChallenge);
    service.emitInboundPairingConfirmation(endpoint.host, remoteConfirmation);
    await pumpEventQueue();
    expect(await notifier.confirmPairingCode(), isTrue);

    final state = container.read(p2pSyncProvider);
    expect(state.localRevisionGraph, isNull);
    expect(state.hasAuthenticatedTransport, isTrue);
    expect(
      state.revisionSummaryRelation,
      P2pRevisionSummaryRelation.remoteAhead,
    );
    expect(state.remoteSnapshotManifest, remoteManifest);
    expect(state.incomingSnapshotSyncRequestGeneration, 1);

    final transferNotifier = container.read(
      p2pSnapshotTransferProvider.notifier,
    );
    expect(
      await transferNotifier.downloadRemoteSnapshot(),
      isTrue,
      reason:
          "${container.read(p2pSnapshotTransferProvider).errorMessage} / ${container.read(p2pSyncProvider).revisionMetadataError}",
    );
    final applied = await transferNotifier.applyVerifiedSnapshot((_) async {
      // Mirrors WelcomeView rebuilding immediately after the received file
      // is persisted and opened, before its remote DAG is installed.
      notifier.updateLocalProjectStatus(
        _savedProject(projectUuid, "remote.mnproj"),
      );
      return true;
    });

    expect(
      applied,
      isTrue,
      reason:
          "${container.read(p2pSnapshotTransferProvider).errorMessage} / ${container.read(p2pSyncProvider).revisionMetadataError}",
    );
    final installed = container.read(p2pSyncProvider);
    expect(installed.hasAuthenticatedTransport, isTrue);
    expect(installed.sessionProjectUuid, projectUuid);
    expect(
      installed.localRevisionGraph?.singleHead?.revisionId,
      remoteGraph.singleHead?.revisionId,
    );
    expect(installed.remoteRevisionGraph, isNotNull);
    expect(installed.revisionSummaryRelation, P2pRevisionSummaryRelation.equal);
    expect(installed.revisionMetadataError, isNull);
  });

  test(
    "P2P provider auto-confirms after one peer confirms when both allow it",
    () async {
      final service = _FakeP2pEndpointService();
      final localIdentityStore = P2pIdentityStore(
        storage: _MemorySecureStore(),
      );
      final remoteIdentityStore = P2pIdentityStore(
        storage: _MemorySecureStore(),
      );
      final remoteChallenge = await remoteIdentityStore
          .createPairingChallenge();
      service.negotiatedRemotePairingChallenge = remoteChallenge;
      final container = ProviderContainer(
        overrides: [
          p2pEndpointServiceProvider.overrideWithValue(service),
          p2pIdentityStoreProvider.overrideWithValue(localIdentityStore),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(p2pSyncProvider.notifier);
      await notifier.initialize();
      await notifier.connectAndNegotiate(
        const P2pEndpoint(host: "192.168.1.30", port: 42942),
        null,
      );
      await notifier.beginPairing();
      final localChallenge = container
          .read(p2pSyncProvider)
          .localPairingChallenge!;
      final remoteConfirmation = await remoteIdentityStore
          .createPairingConfirmation(remoteChallenge, localChallenge);

      service.emitInboundPairingConfirmation(
        "192.168.1.30",
        remoteConfirmation,
      );
      await pumpEventQueue();

      final confirmed = container.read(p2pSyncProvider);
      expect(confirmed.isSingleDeviceConfirmationNegotiated, isTrue);
      expect(confirmed.pairingStatus, P2pPairingStatus.mutuallyConfirmed);
      expect(confirmed.localPairingConfirmation, isNotNull);
      expect(confirmed.remotePairingConfirmation, remoteConfirmation);
      expect(await localIdentityStore.loadTrustedPeers(), isNotEmpty);
      expect(confirmed.hasAuthenticatedTransport, isTrue);
      expect(service.installedSessionKeys, isNotNull);
    },
  );

  test(
    "P2P provider passively starts pairing and auto-confirms after peer confirmation",
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final service = _FakeP2pEndpointService();
      final localIdentityStore = P2pIdentityStore(
        storage: _MemorySecureStore(),
      );
      final remoteIdentityStore = P2pIdentityStore(
        storage: _MemorySecureStore(),
      );
      final remoteChallenge = await remoteIdentityStore
          .createPairingChallenge();
      final container = ProviderContainer(
        overrides: [
          p2pEndpointServiceProvider.overrideWithValue(service),
          p2pIdentityStoreProvider.overrideWithValue(localIdentityStore),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(p2pSyncProvider.notifier);
      await notifier.initialize();
      await container.read(settingsStateProvider.future);

      service.emitInboundPairingChallenge("192.168.1.30", remoteChallenge);
      service.emitInboundPairingChallenge("192.168.1.30", remoteChallenge);
      await pumpEventQueue(times: 8);

      final challenged = container.read(p2pSyncProvider);
      expect(challenged.localPairingChallenge, isNotNull);
      expect(challenged.remotePairingChallenge, remoteChallenge);
      expect(challenged.pairingStatus, P2pPairingStatus.comparisonRequired);
      final localChallenge = challenged.localPairingChallenge!;
      final remoteConfirmation = await remoteIdentityStore
          .createPairingConfirmation(remoteChallenge, localChallenge);

      service.emitInboundPairingConfirmation(
        "192.168.1.30",
        remoteConfirmation,
      );
      await pumpEventQueue(times: 8);

      final confirmed = container.read(p2pSyncProvider);
      expect(confirmed.pairingStatus, P2pPairingStatus.mutuallyConfirmed);
      expect(confirmed.localPairingConfirmation, isNotNull);
      expect(confirmed.remotePairingConfirmation, remoteConfirmation);
      expect(confirmed.hasAuthenticatedTransport, isTrue);
    },
  );

  test(
    "P2P provider retains an inbound challenge received during identity initialization",
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final service = _FakeP2pEndpointService();
      final delayedStorage = _DelayedSecureStore();
      final remoteIdentityStore = P2pIdentityStore(
        storage: _MemorySecureStore(),
      );
      final remoteChallenge = await remoteIdentityStore
          .createPairingChallenge();
      final container = ProviderContainer(
        overrides: [
          p2pEndpointServiceProvider.overrideWithValue(service),
          p2pIdentityStoreProvider.overrideWithValue(
            P2pIdentityStore(storage: delayedStorage),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(p2pSyncProvider.notifier);
      final initialization = notifier.initialize();
      service.emitInboundPairingChallenge("192.168.1.30", remoteChallenge);
      await pumpEventQueue(times: 2);

      delayedStorage.ready.complete();
      await initialization;
      await pumpEventQueue(times: 10);

      final state = container.read(p2pSyncProvider);
      expect(state.localIdentity, isNotNull);
      expect(state.localPairingChallenge, isNotNull);
      expect(state.remotePairingChallenge, remoteChallenge);
      expect(state.inboundPeerAddress, "192.168.1.30");
      expect(state.pairingStatus, P2pPairingStatus.comparisonRequired);
    },
  );

  test(
    "P2P provider reuses and renews mutually enabled persistent verification",
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final service = _FakeP2pEndpointService();
      final localIdentityStore = P2pIdentityStore(
        storage: _MemorySecureStore(),
      );
      final remoteIdentityStore = P2pIdentityStore(
        storage: _MemorySecureStore(),
      );
      final remoteChallenge = await remoteIdentityStore.createPairingChallenge(
        allowPersistentVerification: true,
      );
      await localIdentityStore.trustPeer(
        remoteChallenge,
        persistentVerification: true,
      );
      final previousExpiry = (await localIdentityStore.loadTrustedPeers())
          .values
          .single
          .persistentVerificationUntilEpochSeconds!;
      final container = ProviderContainer(
        overrides: [
          p2pEndpointServiceProvider.overrideWithValue(service),
          p2pIdentityStoreProvider.overrideWithValue(localIdentityStore),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(p2pSyncProvider.notifier);
      await notifier.initialize();
      await container.read(settingsStateProvider.future);
      await container
          .read(settingsStateProvider.notifier)
          .setAllowPersistentP2pVerification(true);

      service.emitInboundPairingChallenge("192.168.1.30", remoteChallenge);
      await pumpEventQueue(times: 8);

      final challenged = container.read(p2pSyncProvider);
      expect(challenged.localPairingChallenge, isNotNull);
      expect(
        challenged.localPairingChallenge?.allowsPersistentVerification,
        isTrue,
      );
      expect(
        challenged.pairingStatus,
        P2pPairingStatus.waitingForPeerConfirmation,
      );
      expect(challenged.pairingCode, isNull);
      expect(challenged.localPairingConfirmation, isNotNull);
      final remoteConfirmation = await remoteIdentityStore
          .createPairingConfirmation(
            remoteChallenge,
            challenged.localPairingChallenge!,
          );

      service.emitInboundPairingConfirmation(
        "192.168.1.30",
        remoteConfirmation,
      );
      await pumpEventQueue(times: 8);

      final authenticated = container.read(p2pSyncProvider);
      expect(authenticated.hasAuthenticatedTransport, isTrue);
      expect(
        authenticated.trustedPeer?.persistentVerificationUntilEpochSeconds,
        greaterThanOrEqualTo(previousExpiry),
      );
    },
  );

  test(
    "P2P provider ignores expired challenges and stale confirmations",
    () async {
      final service = _FakeP2pEndpointService();
      final localIdentityStore = P2pIdentityStore(
        storage: _MemorySecureStore(),
      );
      final remoteIdentityStore = P2pIdentityStore(
        storage: _MemorySecureStore(),
      );
      final firstRemoteChallenge = await remoteIdentityStore
          .createPairingChallenge();
      service.negotiatedRemotePairingChallenge = firstRemoteChallenge;
      final container = ProviderContainer(
        overrides: [
          p2pEndpointServiceProvider.overrideWithValue(service),
          p2pIdentityStoreProvider.overrideWithValue(localIdentityStore),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(p2pSyncProvider.notifier);
      await notifier.initialize();
      await notifier.connectAndNegotiate(
        const P2pEndpoint(host: "192.168.1.30", port: 42942),
        null,
      );
      await notifier.beginPairing();
      final localChallenge = container
          .read(p2pSyncProvider)
          .localPairingChallenge!;
      final staleConfirmation = await remoteIdentityStore
          .createPairingConfirmation(firstRemoteChallenge, localChallenge);
      final nextRemoteChallenge = await remoteIdentityStore
          .createPairingChallenge();
      service.emitInboundPairingChallenge("192.168.1.30", nextRemoteChallenge);
      await pumpEventQueue();

      service.emitInboundPairingConfirmation("192.168.1.30", staleConfirmation);
      await pumpEventQueue();
      expect(
        container.read(p2pSyncProvider).pairingStatus,
        isNot(P2pPairingStatus.error),
      );
      expect(container.read(p2pSyncProvider).remotePairingConfirmation, isNull);

      final expiredChallenge = await remoteIdentityStore.createPairingChallenge(
        lifetime: const Duration(seconds: -1),
      );
      service.emitInboundPairingChallenge("192.168.1.30", expiredChallenge);
      await pumpEventQueue();
      final afterExpired = container.read(p2pSyncProvider);
      expect(afterExpired.pairingStatus, isNot(P2pPairingStatus.error));
      expect(afterExpired.remotePairingChallenge, isNull);
      expect(afterExpired.message, contains("已忽略"));
    },
  );

  test("P2P provider records immutable content and metadata", () async {
    final contentStore = _MemorySnapshotContentStore();
    final revisionStore = P2pRevisionStore(
      storage: _MemoryRevisionStore(),
      contentStore: contentStore,
    );
    final service = _FakeP2pEndpointService();
    final container = ProviderContainer(
      overrides: [
        p2pEndpointServiceProvider.overrideWithValue(service),
        p2pIdentityStoreProvider.overrideWithValue(
          P2pIdentityStore(storage: _MemorySecureStore()),
        ),
        p2pRevisionStoreProvider.overrideWithValue(revisionStore),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(p2pSyncProvider.notifier);
    await notifier.initialize();
    notifier.updateLocalProjectStatus(
      _savedProject("123e4567-e89b-12d3-a456-426614174000", "legacy.mnproj"),
    );
    await pumpEventQueue();
    expect(container.read(p2pSyncProvider).localRevisionHead, isNull);

    expect(
      await notifier.recordPersistedSnapshot(
        projectUuid: "123e4567-e89b-12d3-a456-426614174000",
        xmlContent: "<Project />",
        formatVersion: "1.0",
      ),
      isTrue,
    );
    final state = container.read(p2pSyncProvider);
    expect(state.localRevisionHead, isNotNull);
    expect(state.localRevisionGraph?.revisions, hasLength(1));
    expect(state.localSnapshotManifest, isNotNull);
    expect(state.localSnapshotManifest?.contentLength, 11);
    expect(
      contentStore.snapshots[state.localRevisionHead!.revisionId],
      utf8.encode("<Project />"),
    );
    expect(service.localSnapshotManifest, state.localSnapshotManifest);
    expect(state.revisionMetadataError, isNull);

    const draftXml = "<Project><Title>draft</Title></Project>";
    expect(
      await notifier.recordDraftSnapshot(
        projectUuid: "123e4567-e89b-12d3-a456-426614174000",
        xmlContent: draftXml,
        formatVersion: "1.0",
      ),
      isTrue,
    );
    final draftState = container.read(p2pSyncProvider);
    expect(draftState.localHeadIsDraft, isTrue);
    expect(draftState.localRevisionDelta, isNotNull);
    expect(
      service.localRevisionSummary?.isDraft(
        draftState.localRevisionHead!.revisionId,
      ),
      isTrue,
    );
    expect(service.localRevisionSummary?.delta, isNotNull);

    expect(
      await notifier.recordPersistedSnapshot(
        projectUuid: "123e4567-e89b-12d3-a456-426614174000",
        xmlContent: draftXml,
        formatVersion: "1.0",
      ),
      isTrue,
    );
    expect(container.read(p2pSyncProvider).localHeadIsDraft, isFalse);
  });

  test(
    "P2P provider keeps the session when the same project becomes dirty",
    () async {
      final service = _FakeP2pEndpointService()
        ..negotiatedRemoteOffer = P2pProjectOffer.project(
          projectUuid: "123e4567-e89b-12d3-a456-426614174000",
          fileName: "remote.mnproj",
        );
      final container = ProviderContainer(
        overrides: [p2pEndpointServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(p2pSyncProvider.notifier);
      await notifier.connectAndNegotiate(
        const P2pEndpoint(host: "192.168.1.30", port: 42942),
        _savedProject("123e4567-e89b-12d3-a456-426614174000", "local.mnproj"),
      );

      notifier.updateLocalProjectStatus(
        const P2pProjectStatus(
          fileName: "local.mnproj",
          hasPersistentLocation: true,
          hasUnsavedChanges: true,
          projectUuid: "123e4567-e89b-12d3-a456-426614174000",
          isPersistedSnapshotValidated: true,
        ),
      );

      expect(
        container.read(p2pSyncProvider).connectionStatus,
        P2pConnectionStatus.reachableUnpaired,
      );
      expect(container.read(p2pSyncProvider).sessionProjectUuid, isNotNull);
    },
  );
}
