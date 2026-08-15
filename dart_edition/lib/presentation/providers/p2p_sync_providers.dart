import "dart:async";
import "dart:convert";

import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../data/p2p/p2p_endpoint_service.dart";
import "../../data/p2p/p2p_identity_store.dart";
import "../../data/p2p/p2p_lan_permission_gateway.dart";
import "../../data/p2p/p2p_project_merge.dart";
import "../../data/p2p/p2p_project_merge_service.dart";
import "../../data/p2p/p2p_revision_store.dart";
import "../../data/p2p/p2p_secure_channel.dart";
import "../../data/p2p/p2p_snapshot_content_store.dart";
import "../../data/p2p/p2p_snapshot_download.dart";
import "../../data/p2p/p2p_snapshot_endpoint_gateway.dart";
import "../../data/p2p/p2p_snapshot_quarantine.dart";
import "../../domain/models/p2p_bootstrap_models.dart";
import "../../domain/models/p2p_pairing_models.dart";
import "../../domain/models/p2p_revision_models.dart";
import "../../domain/models/p2p_resolution_models.dart";
import "../../domain/models/p2p_snapshot_models.dart";
import "../../domain/models/p2p_sync_models.dart";
import "global_state_providers.dart";

const int defaultP2pPort = 45510;

class P2pSyncState {
  final P2pServiceStatus serviceStatus;
  final P2pConnectionStatus connectionStatus;
  final List<String> localAddresses;
  final int configuredPort;
  final int? listeningPort;
  final P2pEndpoint? reachablePeer;
  final String? inboundPeerAddress;
  final P2pProjectOffer localProjectOffer;
  final P2pProjectOffer? remoteProjectOffer;
  final P2pProjectNegotiationResult? projectNegotiation;
  final P2pProjectSource? selectedProjectSource;
  final String? sessionProjectUuid;
  final P2pDeviceIdentity? localIdentity;
  final P2pPairingStatus pairingStatus;
  final P2pPairingChallenge? localPairingChallenge;
  final P2pPairingChallenge? remotePairingChallenge;
  final P2pPairingConfirmation? localPairingConfirmation;
  final P2pPairingConfirmation? remotePairingConfirmation;
  final String? pairingCode;
  final P2pTrustedPeer? trustedPeer;
  final P2pRevisionGraph? localRevisionGraph;
  final P2pSnapshotManifest? localSnapshotManifest;
  final Set<String> localDraftHeadIds;
  final P2pRevisionDelta? localRevisionDelta;
  final bool isRevisionMetadataLoading;
  final String? revisionMetadataError;
  final P2pSecureTransportStatus secureTransportStatus;
  final P2pRevisionSummary? remoteRevisionSummary;
  final P2pRevisionSummaryRelation? revisionSummaryRelation;
  final P2pRevisionGraph? remoteRevisionGraph;
  final Set<String> commonAncestorRevisionIds;
  final bool isRevisionGraphLoading;
  final String? revisionGraphError;
  final P2pResolutionAck? localResolutionAck;
  final P2pResolutionAck? remoteResolutionAck;
  final P2pSnapshotManifest? remoteSnapshotManifest;
  final P2pSnapshotManifestStatus snapshotManifestStatus;
  final String? snapshotManifestError;
  final P2pSnapshotSyncRequest? incomingSnapshotSyncRequest;
  final int incomingSnapshotSyncRequestGeneration;
  final String? secureTransportError;
  final int negotiationGeneration;
  final String? message;
  final String? errorMessage;

  const P2pSyncState({
    this.serviceStatus = P2pServiceStatus.stopped,
    this.connectionStatus = P2pConnectionStatus.idle,
    this.localAddresses = const <String>[],
    this.configuredPort = defaultP2pPort,
    this.listeningPort,
    this.reachablePeer,
    this.inboundPeerAddress,
    this.localProjectOffer = const P2pProjectOffer.none(),
    this.remoteProjectOffer,
    this.projectNegotiation,
    this.selectedProjectSource,
    this.sessionProjectUuid,
    this.localIdentity,
    this.pairingStatus = P2pPairingStatus.idle,
    this.localPairingChallenge,
    this.remotePairingChallenge,
    this.localPairingConfirmation,
    this.remotePairingConfirmation,
    this.pairingCode,
    this.trustedPeer,
    this.localRevisionGraph,
    this.localSnapshotManifest,
    this.localDraftHeadIds = const <String>{},
    this.localRevisionDelta,
    this.isRevisionMetadataLoading = false,
    this.revisionMetadataError,
    this.secureTransportStatus = P2pSecureTransportStatus.inactive,
    this.remoteRevisionSummary,
    this.revisionSummaryRelation,
    this.remoteRevisionGraph,
    this.commonAncestorRevisionIds = const <String>{},
    this.isRevisionGraphLoading = false,
    this.revisionGraphError,
    this.localResolutionAck,
    this.remoteResolutionAck,
    this.remoteSnapshotManifest,
    this.snapshotManifestStatus = P2pSnapshotManifestStatus.inactive,
    this.snapshotManifestError,
    this.incomingSnapshotSyncRequest,
    this.incomingSnapshotSyncRequestGeneration = 0,
    this.secureTransportError,
    this.negotiationGeneration = 0,
    this.message,
    this.errorMessage,
  });

  bool get isServiceBusy {
    return serviceStatus == P2pServiceStatus.starting ||
        serviceStatus == P2pServiceStatus.stopping;
  }

  bool get isListening => serviceStatus == P2pServiceStatus.listening;

  bool get isConnecting => connectionStatus == P2pConnectionStatus.connecting;

  bool get hasReachablePeer =>
      connectionStatus == P2pConnectionStatus.reachableUnpaired;

  bool get canBeginPairing => hasReachablePeer && localIdentity != null;

  bool get isSingleDeviceConfirmationNegotiated =>
      localPairingChallenge?.allowsSingleDeviceConfirmation == true &&
      remotePairingChallenge?.allowsSingleDeviceConfirmation == true;

  bool get isPersistentVerificationNegotiated =>
      localPairingChallenge?.allowsPersistentVerification == true &&
      remotePairingChallenge?.allowsPersistentVerification == true;

  P2pRevisionMetadata? get localRevisionHead => localRevisionGraph?.singleHead;

  bool get localHeadIsDraft {
    final head = localRevisionHead;
    return head != null && localDraftHeadIds.contains(head.revisionId);
  }

  bool get remoteHeadIsDraft {
    final summary = remoteRevisionSummary;
    return summary != null &&
        summary.heads.length == 1 &&
        summary.isDraft(summary.heads.single.revisionId);
  }

  bool get hasAuthenticatedTransport =>
      secureTransportStatus == P2pSecureTransportStatus.authenticated;

  bool get hasSnapshotContentTransfer =>
      hasAuthenticatedTransport && sessionProjectUuid != null;

  bool get canDownloadRemoteSnapshot {
    final manifest = remoteSnapshotManifest;
    return hasAuthenticatedTransport &&
        reachablePeer != null &&
        trustedPeer != null &&
        sessionProjectUuid != null &&
        manifest != null &&
        manifest.projectUuid == sessionProjectUuid &&
        snapshotManifestStatus == P2pSnapshotManifestStatus.available &&
        (revisionSummaryRelation == P2pRevisionSummaryRelation.remoteAhead ||
            revisionSummaryRelation == P2pRevisionSummaryRelation.concurrent);
  }

  bool get canRequestPeerSnapshotSync {
    final manifest = localSnapshotManifest;
    return hasAuthenticatedTransport &&
        reachablePeer != null &&
        trustedPeer != null &&
        sessionProjectUuid != null &&
        manifest != null &&
        manifest.projectUuid == sessionProjectUuid &&
        revisionSummaryRelation == P2pRevisionSummaryRelation.localAhead;
  }

  P2pSyncState copyWith({
    P2pServiceStatus? serviceStatus,
    P2pConnectionStatus? connectionStatus,
    List<String>? localAddresses,
    int? configuredPort,
    Object? listeningPort = _p2pUnset,
    Object? reachablePeer = _p2pUnset,
    Object? inboundPeerAddress = _p2pUnset,
    P2pProjectOffer? localProjectOffer,
    Object? remoteProjectOffer = _p2pUnset,
    Object? projectNegotiation = _p2pUnset,
    Object? selectedProjectSource = _p2pUnset,
    Object? sessionProjectUuid = _p2pUnset,
    Object? localIdentity = _p2pUnset,
    P2pPairingStatus? pairingStatus,
    Object? localPairingChallenge = _p2pUnset,
    Object? remotePairingChallenge = _p2pUnset,
    Object? localPairingConfirmation = _p2pUnset,
    Object? remotePairingConfirmation = _p2pUnset,
    Object? pairingCode = _p2pUnset,
    Object? trustedPeer = _p2pUnset,
    Object? localRevisionGraph = _p2pUnset,
    Object? localSnapshotManifest = _p2pUnset,
    Set<String>? localDraftHeadIds,
    Object? localRevisionDelta = _p2pUnset,
    bool? isRevisionMetadataLoading,
    Object? revisionMetadataError = _p2pUnset,
    P2pSecureTransportStatus? secureTransportStatus,
    Object? remoteRevisionSummary = _p2pUnset,
    Object? revisionSummaryRelation = _p2pUnset,
    Object? remoteRevisionGraph = _p2pUnset,
    Set<String>? commonAncestorRevisionIds,
    bool? isRevisionGraphLoading,
    Object? revisionGraphError = _p2pUnset,
    Object? localResolutionAck = _p2pUnset,
    Object? remoteResolutionAck = _p2pUnset,
    Object? remoteSnapshotManifest = _p2pUnset,
    P2pSnapshotManifestStatus? snapshotManifestStatus,
    Object? snapshotManifestError = _p2pUnset,
    Object? incomingSnapshotSyncRequest = _p2pUnset,
    int? incomingSnapshotSyncRequestGeneration,
    Object? secureTransportError = _p2pUnset,
    int? negotiationGeneration,
    Object? message = _p2pUnset,
    Object? errorMessage = _p2pUnset,
  }) {
    return P2pSyncState(
      serviceStatus: serviceStatus ?? this.serviceStatus,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      localAddresses: localAddresses ?? this.localAddresses,
      configuredPort: configuredPort ?? this.configuredPort,
      listeningPort: identical(listeningPort, _p2pUnset)
          ? this.listeningPort
          : listeningPort as int?,
      reachablePeer: identical(reachablePeer, _p2pUnset)
          ? this.reachablePeer
          : reachablePeer as P2pEndpoint?,
      inboundPeerAddress: identical(inboundPeerAddress, _p2pUnset)
          ? this.inboundPeerAddress
          : inboundPeerAddress as String?,
      localProjectOffer: localProjectOffer ?? this.localProjectOffer,
      remoteProjectOffer: identical(remoteProjectOffer, _p2pUnset)
          ? this.remoteProjectOffer
          : remoteProjectOffer as P2pProjectOffer?,
      projectNegotiation: identical(projectNegotiation, _p2pUnset)
          ? this.projectNegotiation
          : projectNegotiation as P2pProjectNegotiationResult?,
      selectedProjectSource: identical(selectedProjectSource, _p2pUnset)
          ? this.selectedProjectSource
          : selectedProjectSource as P2pProjectSource?,
      sessionProjectUuid: identical(sessionProjectUuid, _p2pUnset)
          ? this.sessionProjectUuid
          : sessionProjectUuid as String?,
      localIdentity: identical(localIdentity, _p2pUnset)
          ? this.localIdentity
          : localIdentity as P2pDeviceIdentity?,
      pairingStatus: pairingStatus ?? this.pairingStatus,
      localPairingChallenge: identical(localPairingChallenge, _p2pUnset)
          ? this.localPairingChallenge
          : localPairingChallenge as P2pPairingChallenge?,
      remotePairingChallenge: identical(remotePairingChallenge, _p2pUnset)
          ? this.remotePairingChallenge
          : remotePairingChallenge as P2pPairingChallenge?,
      localPairingConfirmation: identical(localPairingConfirmation, _p2pUnset)
          ? this.localPairingConfirmation
          : localPairingConfirmation as P2pPairingConfirmation?,
      remotePairingConfirmation: identical(remotePairingConfirmation, _p2pUnset)
          ? this.remotePairingConfirmation
          : remotePairingConfirmation as P2pPairingConfirmation?,
      pairingCode: identical(pairingCode, _p2pUnset)
          ? this.pairingCode
          : pairingCode as String?,
      trustedPeer: identical(trustedPeer, _p2pUnset)
          ? this.trustedPeer
          : trustedPeer as P2pTrustedPeer?,
      localRevisionGraph: identical(localRevisionGraph, _p2pUnset)
          ? this.localRevisionGraph
          : localRevisionGraph as P2pRevisionGraph?,
      localSnapshotManifest: identical(localSnapshotManifest, _p2pUnset)
          ? this.localSnapshotManifest
          : localSnapshotManifest as P2pSnapshotManifest?,
      localDraftHeadIds: Set<String>.unmodifiable(
        localDraftHeadIds ?? this.localDraftHeadIds,
      ),
      localRevisionDelta: identical(localRevisionDelta, _p2pUnset)
          ? this.localRevisionDelta
          : localRevisionDelta as P2pRevisionDelta?,
      isRevisionMetadataLoading:
          isRevisionMetadataLoading ?? this.isRevisionMetadataLoading,
      revisionMetadataError: identical(revisionMetadataError, _p2pUnset)
          ? this.revisionMetadataError
          : revisionMetadataError as String?,
      secureTransportStatus:
          secureTransportStatus ?? this.secureTransportStatus,
      remoteRevisionSummary: identical(remoteRevisionSummary, _p2pUnset)
          ? this.remoteRevisionSummary
          : remoteRevisionSummary as P2pRevisionSummary?,
      revisionSummaryRelation: identical(revisionSummaryRelation, _p2pUnset)
          ? this.revisionSummaryRelation
          : revisionSummaryRelation as P2pRevisionSummaryRelation?,
      remoteRevisionGraph: identical(remoteRevisionGraph, _p2pUnset)
          ? this.remoteRevisionGraph
          : remoteRevisionGraph as P2pRevisionGraph?,
      commonAncestorRevisionIds: Set<String>.unmodifiable(
        commonAncestorRevisionIds ?? this.commonAncestorRevisionIds,
      ),
      isRevisionGraphLoading:
          isRevisionGraphLoading ?? this.isRevisionGraphLoading,
      revisionGraphError: identical(revisionGraphError, _p2pUnset)
          ? this.revisionGraphError
          : revisionGraphError as String?,
      localResolutionAck: identical(localResolutionAck, _p2pUnset)
          ? this.localResolutionAck
          : localResolutionAck as P2pResolutionAck?,
      remoteResolutionAck: identical(remoteResolutionAck, _p2pUnset)
          ? this.remoteResolutionAck
          : remoteResolutionAck as P2pResolutionAck?,
      remoteSnapshotManifest: identical(remoteSnapshotManifest, _p2pUnset)
          ? this.remoteSnapshotManifest
          : remoteSnapshotManifest as P2pSnapshotManifest?,
      snapshotManifestStatus:
          snapshotManifestStatus ?? this.snapshotManifestStatus,
      snapshotManifestError: identical(snapshotManifestError, _p2pUnset)
          ? this.snapshotManifestError
          : snapshotManifestError as String?,
      incomingSnapshotSyncRequest:
          identical(incomingSnapshotSyncRequest, _p2pUnset)
          ? this.incomingSnapshotSyncRequest
          : incomingSnapshotSyncRequest as P2pSnapshotSyncRequest?,
      incomingSnapshotSyncRequestGeneration:
          incomingSnapshotSyncRequestGeneration ??
          this.incomingSnapshotSyncRequestGeneration,
      secureTransportError: identical(secureTransportError, _p2pUnset)
          ? this.secureTransportError
          : secureTransportError as String?,
      negotiationGeneration:
          negotiationGeneration ?? this.negotiationGeneration,
      message: identical(message, _p2pUnset)
          ? this.message
          : message as String?,
      errorMessage: identical(errorMessage, _p2pUnset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _p2pUnset = Object();

final p2pEndpointServiceProvider = Provider<P2pEndpointService>((ref) {
  final service = IoP2pEndpointService();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

final p2pLanPermissionGatewayProvider = Provider<P2pLanPermissionGateway>((
  ref,
) {
  return PlatformP2pLanPermissionGateway();
});

final p2pIdentityStoreProvider = Provider<P2pIdentityStore>((ref) {
  return P2pIdentityStore();
});

final p2pSnapshotContentStoreProvider = Provider<P2pSnapshotContentStore>((
  ref,
) {
  return FileSystemP2pSnapshotContentStore();
});

final p2pRevisionStoreProvider = Provider<P2pRevisionStore>((ref) {
  return P2pRevisionStore(
    contentStore: ref.watch(p2pSnapshotContentStoreProvider),
  );
});

final p2pProjectMergeServiceProvider = Provider<P2pProjectMergeService>(
  (ref) => const P2pProjectMergeService(),
);

final p2pBootstrapConsensusPlannerProvider =
    Provider<P2pBootstrapConsensusPlanner>((ref) {
      return const P2pBootstrapConsensusPlanner();
    });

final p2pSnapshotQuarantineStorageProvider =
    Provider<P2pSnapshotQuarantineStorage>((ref) {
      final storage = FileSystemP2pSnapshotQuarantineStorage();
      ref.onDispose(() => unawaited(storage.dispose()));
      return storage;
    });

final p2pSnapshotTransferSessionProvider =
    Provider<P2pSnapshotTransferSessionController>((ref) {
      return P2pSnapshotTransferSessionController();
    });

final p2pSnapshotChunkGatewayProvider = Provider<P2pSnapshotChunkGateway>((
  ref,
) {
  return SessionAwareP2pSnapshotChunkGateway(
    endpointService: ref.watch(p2pEndpointServiceProvider),
    sessionController: ref.watch(p2pSnapshotTransferSessionProvider),
  );
});

final p2pSnapshotDownloadCoordinatorProvider =
    Provider<P2pSnapshotDownloadCoordinator>((ref) {
      final coordinator = P2pSnapshotDownloadCoordinator(
        gateway: ref.watch(p2pSnapshotChunkGatewayProvider),
        quarantineStorage: ref.watch(p2pSnapshotQuarantineStorageProvider),
      );
      ref.onDispose(() => unawaited(coordinator.dispose()));
      return coordinator;
    });

class P2pSyncNotifier extends Notifier<P2pSyncState> {
  static const Duration _offerRefreshInterval = Duration(milliseconds: 500);
  static const Duration _offerRefreshTimeout = Duration(seconds: 3);

  bool _initialized = false;
  Future<void>? _initialization;
  Future<void> _pairingEventTail = Future<void>.value();
  int _operationGeneration = 0;
  Timer? _offerRefreshTimer;
  Timer? _pairingChallengeRefreshTimer;
  bool _offerRefreshInProgress = false;
  Future<void>? _revisionSummaryRefreshOperation;
  bool _revisionSummaryRefreshPending = false;
  bool _revisionGraphRefreshInProgress = false;
  DateTime? _lastRevisionSummaryRefreshAt;
  String? _loadedRevisionProjectUuid;
  String? _currentLocalProjectUuid;
  bool _disposed = false;
  int _secureTransportGeneration = 0;
  Future<void>? _secureTransportEstablishment;
  Future<P2pPairingChallenge?>? _localPairingChallengeCreation;
  String? _lastAcceptedSnapshotSyncRequestId;
  int _snapshotSyncRequestCounter = 0;
  P2pResolutionAck? _pendingRemoteResolutionAck;
  Map<String, P2pSnapshotManifest> _localSnapshotManifests =
      const <String, P2pSnapshotManifest>{};

  P2pEndpointService get _endpointService =>
      ref.read(p2pEndpointServiceProvider);

  P2pIdentityStore get _identityStore => ref.read(p2pIdentityStoreProvider);

  P2pRevisionStore get _revisionStore => ref.read(p2pRevisionStoreProvider);

  P2pSnapshotContentStore get _snapshotContentStore =>
      ref.read(p2pSnapshotContentStoreProvider);

  P2pSnapshotTransferSessionController get _snapshotTransferSession =>
      ref.read(p2pSnapshotTransferSessionProvider);

  @override
  P2pSyncState build() {
    final probeSubscription = _endpointService.inboundProbes.listen(
      _handleInboundProbe,
    );
    final offerSubscription = _endpointService.inboundProjectOffers.listen(
      _handleInboundProjectOffer,
    );
    final pairingSubscription = _endpointService.inboundPairingChallenges
        .listen(
          (inbound) => _enqueuePairingEvent(
            () => _handleInboundPairingChallenge(inbound),
          ),
        );
    final pairingConfirmationSubscription = _endpointService
        .inboundPairingConfirmations
        .listen(
          (inbound) => _enqueuePairingEvent(
            () => _handleInboundPairingConfirmation(inbound),
          ),
        );
    final revisionSummarySubscription = _endpointService
        .inboundRevisionSummaries
        .listen(_handleInboundRevisionSummary);
    final revisionGraphSubscription = _endpointService.inboundRevisionGraphs
        .listen((inbound) => unawaited(_handleInboundRevisionGraph(inbound)));
    final endpointService = _endpointService;
    final snapshotTransferSession = _snapshotTransferSession;
    ref.onDispose(() {
      _disposed = true;
      snapshotTransferSession.revoke();
      endpointService.configureSnapshotContentTransfer(enabled: false);
      _offerRefreshTimer?.cancel();
      _pairingChallengeRefreshTimer?.cancel();
      unawaited(probeSubscription.cancel());
      unawaited(offerSubscription.cancel());
      unawaited(pairingSubscription.cancel());
      unawaited(pairingConfirmationSubscription.cancel());
      unawaited(revisionSummarySubscription.cancel());
      unawaited(revisionGraphSubscription.cancel());
    });
    return const P2pSyncState();
  }

  void _handleInboundProbe(P2pInboundProbe probe) {
    ++_operationGeneration;
    state = state.copyWith(
      connectionStatus: P2pConnectionStatus.reachableUnpaired,
      reachablePeer: state.hasAuthenticatedTransport
          ? state.reachablePeer
          : null,
      inboundPeerAddress: probe.remoteAddress,
      message: "${probe.remoteAddress} 已連入並驗證本機端點；TCP 可雙向通訊，不需要再從本機反向連線。",
      errorMessage: null,
    );
  }

  void _handleInboundProjectOffer(P2pInboundProjectOffer inbound) {
    ++_operationGeneration;
    final authenticatedEndpoint = state.hasAuthenticatedTransport
        ? state.reachablePeer
        : null;
    // Project offers are deliberately available before pairing, so they do
    // not carry the authenticated service port.  Once a secure revision
    // summary has established that port, an offer refresh must not erase it:
    // doing so would leave a verified manifest/DAG in state but make the
    // snapshot gateway unable to contact the peer.  Also ignore offers from
    // another LAN address while this authenticated session is active.
    if (authenticatedEndpoint != null &&
        authenticatedEndpoint.host != inbound.remoteAddress) {
      return;
    }
    if (inbound.offer.disconnectRequested) {
      _disconnectForProjectChange(remoteChanged: true);
      return;
    }
    if (_isDifferentFromSession(inbound.offer, remoteSide: true)) {
      _disconnectForProjectChange(remoteChanged: true);
      return;
    }
    if (state.remoteProjectOffer == inbound.offer && state.hasReachablePeer) {
      return;
    }
    final negotiation = P2pProjectNegotiationResult.evaluate(
      local: state.localProjectOffer,
      remote: inbound.offer,
    );
    _applyNegotiation(
      negotiation: negotiation,
      remoteOffer: inbound.offer,
      connectionStatus: P2pConnectionStatus.reachableUnpaired,
      reachablePeer: authenticatedEndpoint,
      inboundPeerAddress: inbound.remoteAddress,
    );
  }

  Future<void> _handleInboundPairingChallenge(
    P2pInboundPairingChallenge inbound,
  ) async {
    await initialize();
    if (_disposed) return;
    state = state.copyWith(
      connectionStatus: P2pConnectionStatus.reachableUnpaired,
      inboundPeerAddress: inbound.remoteAddress,
      message: "${inbound.remoteAddress} 已送達安全配對要求；本機正在自動回應。",
      errorMessage: null,
    );
    await _acceptRemotePairingChallenge(inbound.challenge);
  }

  Future<void> _handleInboundPairingConfirmation(
    P2pInboundPairingConfirmation inbound,
  ) async {
    await initialize();
    if (_disposed) return;
    state = state.copyWith(
      connectionStatus: P2pConnectionStatus.reachableUnpaired,
      inboundPeerAddress: inbound.remoteAddress,
    );
    await _acceptRemotePairingConfirmation(inbound.confirmation);
  }

  void _enqueuePairingEvent(Future<void> Function() action) {
    _pairingEventTail = _pairingEventTail.then((_) => action()).catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      if (!_disposed) {
        state = state.copyWith(
          pairingStatus: P2pPairingStatus.error,
          errorMessage: "處理遠端安全配對事件失敗：${_describeError(error)}",
        );
      }
    });
  }

  void _handleInboundRevisionSummary(P2pInboundRevisionSummary inbound) {
    if (!state.hasAuthenticatedTransport) return;
    final localGraph = _effectiveLocalRevisionGraph();
    if (localGraph == null ||
        inbound.summary.projectUuid != localGraph.projectUuid) {
      return;
    }
    final localSummary = _summaryForGraph(localGraph);
    final relation = localSummary.compare(inbound.summary);
    final authenticatedEndpoint = inbound.remoteServicePort == null
        ? state.reachablePeer
        : P2pEndpoint(
            host: inbound.remoteAddress,
            port: inbound.remoteServicePort!,
          );
    state = state.copyWith(
      reachablePeer: authenticatedEndpoint,
      inboundPeerAddress: inbound.remoteAddress,
      remoteRevisionSummary: inbound.summary,
      revisionSummaryRelation: relation,
      remoteSnapshotManifest: inbound.headManifest,
      snapshotManifestStatus: _snapshotManifestStatus(
        inbound.summary,
        inbound.headManifest,
      ),
      snapshotManifestError: null,
      secureTransportError: null,
    );
    _refreshSnapshotTransferAuthorization();
    _acceptRemoteSnapshotSyncRequest(
      request: inbound.syncRequest,
      relation: relation,
      manifest: inbound.headManifest,
    );
    _acceptRemoteResolutionAck(inbound.resolutionAck);
    if (relation != P2pRevisionSummaryRelation.equal) {
      unawaited(refreshRevisionGraph());
    }
  }

  Future<void> _handleInboundRevisionGraph(
    P2pInboundRevisionGraph inbound,
  ) async {
    if (!state.hasAuthenticatedTransport ||
        inbound.graph.projectUuid != state.sessionProjectUuid) {
      return;
    }
    try {
      await _revisionStore.verifyRemoteGraphTransfer(
        graph: inbound.graph,
        transferId: inbound.transferId,
      );
      if (_disposed || !state.hasAuthenticatedTransport) return;
      final localGraph = _effectiveLocalRevisionGraph();
      if (localGraph == null) return;
      state = state.copyWith(
        remoteRevisionGraph: inbound.graph,
        commonAncestorRevisionIds: localGraph.commonAncestorIds(inbound.graph),
        revisionGraphError: null,
      );
      _revalidatePendingRemoteResolutionAck(inbound.graph);
    } on FormatException catch (error) {
      state = state.copyWith(
        revisionGraphError: "已拒絕無效的遠端 revision graph：${error.message}",
      );
    }
  }

  P2pSnapshotManifestStatus _snapshotManifestStatus(
    P2pRevisionSummary summary,
    P2pSnapshotManifest? manifest,
  ) {
    if (summary.heads.length != 1) {
      return P2pSnapshotManifestStatus.inactive;
    }
    return manifest == null
        ? P2pSnapshotManifestStatus.unavailable
        : P2pSnapshotManifestStatus.available;
  }

  Future<void> _acceptRemotePairingChallenge(
    P2pPairingChallenge challenge,
  ) async {
    final identity = state.localIdentity;
    if (identity == null || challenge.deviceId == identity.deviceId) return;
    if (challenge.isExpiredAt(DateTime.now())) {
      state = state.copyWith(
        pairingStatus: state.localPairingChallenge == null
            ? P2pPairingStatus.waitingForPeer
            : state.pairingStatus,
        remotePairingChallenge: null,
        remotePairingConfirmation: null,
        pairingCode: null,
        message: "已忽略對方上一輪過期的配對 challenge，等待自動更新。",
        errorMessage: null,
      );
      return;
    }
    if (!await _identityStore.verifyPairingChallenge(challenge)) {
      state = state.copyWith(
        pairingStatus: P2pPairingStatus.error,
        remotePairingChallenge: null,
        pairingCode: null,
        errorMessage: "對方的配對 challenge 無效、遭竄改或已過期。",
      );
      return;
    }
    final trustedPeers = await _identityStore.loadTrustedPeers();
    final existing = trustedPeers[challenge.deviceId];
    if (existing != null &&
        existing.publicKeyBase64 != challenge.publicKeyBase64) {
      state = state.copyWith(
        pairingStatus: P2pPairingStatus.error,
        remotePairingChallenge: null,
        pairingCode: null,
        errorMessage: "已信任裝置的公開金鑰發生變更；已拒絕配對。",
      );
      return;
    }
    final localChallenge =
        await _ensureFreshLocalPairingChallenge() ??
        await _createLocalPairingChallengeFromSettings();
    if (localChallenge == null) {
      state = state.copyWith(
        pairingStatus: P2pPairingStatus.waitingForPeer,
        remotePairingChallenge: challenge,
        pairingCode: null,
        message: "對方要求安全配對，但本機暫時無法建立 challenge；正在等待重試。",
        errorMessage: null,
      );
      return;
    }
    final previous = state.remotePairingChallenge;
    final sameTranscript =
        previous?.canonicalPayload == challenge.canonicalPayload;
    if (sameTranscript &&
        (state.pairingStatus == P2pPairingStatus.waitingForPeerConfirmation ||
            state.pairingStatus == P2pPairingStatus.mutuallyConfirmed)) {
      return;
    }
    if (!sameTranscript) {
      _endpointService.updateLocalPairingConfirmation(null);
      _clearAuthenticatedTransport();
    }
    final code = await _identityStore.pairingCode(localChallenge, challenge);
    state = state.copyWith(
      pairingStatus: P2pPairingStatus.comparisonRequired,
      remotePairingChallenge: challenge,
      localPairingConfirmation: null,
      remotePairingConfirmation: null,
      pairingCode: code,
      trustedPeer: existing,
      message: "請在兩台裝置上比較六位數配對碼；完全相同才可確認。",
      errorMessage: null,
    );
    if (_persistentVerificationNegotiated(localChallenge, challenge) &&
        await _identityStore.hasValidPersistentVerification(challenge)) {
      try {
        final confirmation = await _identityStore.createPairingConfirmation(
          localChallenge,
          challenge,
        );
        _endpointService.updateLocalPairingConfirmation(confirmation);
        state = state.copyWith(
          pairingStatus: P2pPairingStatus.waitingForPeerConfirmation,
          localPairingConfirmation: confirmation,
          pairingCode: null,
          message: "雙端 14 天持久驗證仍有效；已自動回簽本次短期 session。",
        );
        final endpoint = state.reachablePeer;
        if (endpoint != null) await _refreshPairingConfirmation(endpoint);
      } catch (error) {
        state = state.copyWith(
          pairingStatus: P2pPairingStatus.error,
          errorMessage: "持久驗證自動回簽失敗：${_describeError(error)}",
        );
      }
    }
  }

  Future<void> _acceptRemotePairingConfirmation(
    P2pPairingConfirmation confirmation,
  ) async {
    final localChallenge = state.localPairingChallenge;
    final remoteChallenge = state.remotePairingChallenge;
    if (localChallenge == null || remoteChallenge == null) return;
    final isDuplicateConfirmation =
        state.remotePairingConfirmation?.canonicalPayload ==
        confirmation.canonicalPayload;
    if (isDuplicateConfirmation &&
        (state.hasAuthenticatedTransport ||
            _secureTransportEstablishment != null)) {
      return;
    }
    final expectedTranscriptHash = await _identityStore.pairingTranscriptHash(
      localChallenge,
      remoteChallenge,
    );
    if (confirmation.transcriptHashBase64 != expectedTranscriptHash) {
      state = state.copyWith(
        message: "已忽略上一輪的 pairing confirmation，等待目前 challenge 的回簽。",
        errorMessage: null,
      );
      return;
    }
    final isValid = await _identityStore.verifyPairingConfirmation(
      confirmation,
      localChallenge: localChallenge,
      remoteChallenge: remoteChallenge,
    );
    if (!isValid) {
      state = state.copyWith(
        pairingStatus: P2pPairingStatus.error,
        remotePairingConfirmation: null,
        errorMessage: "對方的 pairing confirmation 簽章或 transcript 不一致。",
      );
      return;
    }
    if (state.localPairingConfirmation == null &&
        _singleDeviceConfirmationNegotiated(localChallenge, remoteChallenge)) {
      try {
        await _identityStore.trustPeer(
          remoteChallenge,
          persistentVerification: _persistentVerificationNegotiated(
            localChallenge,
            remoteChallenge,
          ),
        );
        final localConfirmation = await _identityStore
            .createPairingConfirmation(localChallenge, remoteChallenge);
        final trustedPeers = await _identityStore.loadTrustedPeers();
        _endpointService.updateLocalPairingConfirmation(localConfirmation);
        _pairingChallengeRefreshTimer?.cancel();
        _pairingChallengeRefreshTimer = null;
        state = state.copyWith(
          pairingStatus: P2pPairingStatus.mutuallyConfirmed,
          localPairingConfirmation: localConfirmation,
          remotePairingConfirmation: confirmation,
          pairingCode: null,
          trustedPeer: trustedPeers[remoteChallenge.deviceId],
          message: "對方已確認配對碼；雙方皆允許單端確認，本機驗證簽章後已自動回簽。",
          errorMessage: null,
        );
        await _establishAuthenticatedTransport();
        final endpoint = state.reachablePeer;
        if (endpoint != null) await _refreshPairingConfirmation(endpoint);
      } catch (error) {
        state = state.copyWith(
          pairingStatus: P2pPairingStatus.error,
          errorMessage: "無法自動完成安全配對：${_describeError(error)}",
        );
      }
      return;
    }
    final mutuallyConfirmed = state.localPairingConfirmation != null;
    if (mutuallyConfirmed) {
      _pairingChallengeRefreshTimer?.cancel();
      _pairingChallengeRefreshTimer = null;
    }
    state = state.copyWith(
      pairingStatus: mutuallyConfirmed
          ? P2pPairingStatus.mutuallyConfirmed
          : state.pairingStatus,
      remotePairingConfirmation: confirmation,
      message: mutuallyConfirmed
          ? "雙方已簽署確認同一份配對 transcript；正在建立 authenticated encrypted transport。"
          : "對方已確認配對碼；目前設定要求本機也必須確認。",
      errorMessage: null,
    );
    if (mutuallyConfirmed) await _establishAuthenticatedTransport();
  }

  Future<void> _establishAuthenticatedTransport() async {
    if (state.hasAuthenticatedTransport) return;
    final activeEstablishment = _secureTransportEstablishment;
    if (activeEstablishment != null) {
      await activeEstablishment;
      return;
    }
    final operation = _performAuthenticatedTransportEstablishment();
    _secureTransportEstablishment = operation;
    try {
      await operation;
    } finally {
      if (identical(_secureTransportEstablishment, operation)) {
        _secureTransportEstablishment = null;
      }
    }
  }

  Future<void> _performAuthenticatedTransportEstablishment() async {
    final localChallenge = state.localPairingChallenge;
    final remoteChallenge = state.remotePairingChallenge;
    final localConfirmation = state.localPairingConfirmation;
    final remoteConfirmation = state.remotePairingConfirmation;
    if (state.pairingStatus != P2pPairingStatus.mutuallyConfirmed ||
        localChallenge == null ||
        remoteChallenge == null ||
        localConfirmation == null ||
        remoteConfirmation == null) {
      return;
    }
    final secureGeneration = ++_secureTransportGeneration;
    _revisionSummaryRefreshOperation = null;
    _revisionSummaryRefreshPending = false;
    state = state.copyWith(
      secureTransportStatus: P2pSecureTransportStatus.establishing,
      remoteRevisionSummary: null,
      revisionSummaryRelation: null,
      secureTransportError: null,
    );
    try {
      final keys = await _identityStore.deriveAuthenticatedSessionKeys(
        localChallenge: localChallenge,
        remoteChallenge: remoteChallenge,
        localConfirmation: localConfirmation,
        remoteConfirmation: remoteConfirmation,
      );
      if (_disposed || secureGeneration != _secureTransportGeneration) {
        keys.destroy();
        return;
      }
      _endpointService.installAuthenticatedSession(keys);
      final localGraph = _effectiveLocalRevisionGraph();
      _endpointService.updateLocalRevisionGraph(localGraph);
      _endpointService.updateLocalResolutionAck(state.localResolutionAck);
      _endpointService.updateLocalRevisionSummary(
        localGraph == null ? null : _summaryForGraph(localGraph),
      );
      _endpointService.updateLocalSnapshotManifests(
        _localSnapshotManifests.values,
      );
      state = state.copyWith(
        secureTransportStatus: P2pSecureTransportStatus.authenticated,
        message:
            "authenticated encrypted transport 已建立；revision summary 與 snapshot chunks 僅透過此通道交換。",
        secureTransportError: null,
      );
      if (_persistentVerificationNegotiated(localChallenge, remoteChallenge)) {
        final renewedPeer = await _identityStore.renewPersistentVerification(
          remoteChallenge,
        );
        if (_disposed || secureGeneration != _secureTransportGeneration) {
          return;
        }
        state = state.copyWith(trustedPeer: renewedPeer);
      }
      _enableSnapshotContentTransfer();
      await refreshRevisionSummary();
    } on FormatException catch (error) {
      if (_disposed || secureGeneration != _secureTransportGeneration) return;
      _endpointService.installAuthenticatedSession(null);
      state = state.copyWith(
        secureTransportStatus: P2pSecureTransportStatus.error,
        secureTransportError: "無法驗證加密通道的裝置身分或 transcript：${error.message}",
      );
    } on StateError catch (error) {
      if (_disposed || secureGeneration != _secureTransportGeneration) return;
      _endpointService.installAuthenticatedSession(null);
      state = state.copyWith(
        secureTransportStatus: P2pSecureTransportStatus.error,
        secureTransportError: "無法建立加密通道：${error.message}",
      );
    }
  }

  Future<void> refreshRevisionSummary() {
    if (!state.hasAuthenticatedTransport) return Future<void>.value();
    final active = _revisionSummaryRefreshOperation;
    if (active != null) {
      _revisionSummaryRefreshPending = true;
      return active.then((_) async {
        if (!_revisionSummaryRefreshPending) return;
        _revisionSummaryRefreshPending = false;
        await refreshRevisionSummary();
      });
    }
    late final Future<void> operation;
    operation = _performRevisionSummaryRefresh().whenComplete(() {
      if (identical(_revisionSummaryRefreshOperation, operation)) {
        _revisionSummaryRefreshOperation = null;
      }
    });
    _revisionSummaryRefreshOperation = operation;
    return operation;
  }

  Future<void> _performRevisionSummaryRefresh() async {
    final endpoint = state.reachablePeer;
    final localGraph = _effectiveLocalRevisionGraph();
    if (endpoint == null || localGraph == null) return;
    final secureGeneration = _secureTransportGeneration;
    final localSummary = _summaryForGraph(localGraph);
    _lastRevisionSummaryRefreshAt = DateTime.now().toUtc();
    _endpointService.updateLocalRevisionSummary(localSummary);
    try {
      final exchange = await _endpointService.negotiateRevisionSummary(
        endpoint,
        localSummary,
      );
      final remoteSummary = exchange.summary;
      if (_disposed ||
          secureGeneration != _secureTransportGeneration ||
          !state.hasAuthenticatedTransport ||
          state.reachablePeer != endpoint ||
          _effectiveLocalRevisionGraph()?.projectUuid !=
              remoteSummary.projectUuid) {
        return;
      }
      final relation = localSummary.compare(remoteSummary);
      final authenticatedEndpoint = exchange.remoteServicePort == null
          ? endpoint
          : P2pEndpoint(host: endpoint.host, port: exchange.remoteServicePort!);
      state = state.copyWith(
        reachablePeer: authenticatedEndpoint,
        remoteRevisionSummary: remoteSummary,
        revisionSummaryRelation: relation,
        remoteSnapshotManifest: exchange.headManifest,
        snapshotManifestStatus: _snapshotManifestStatus(
          remoteSummary,
          exchange.headManifest,
        ),
        snapshotManifestError: null,
        secureTransportError: null,
      );
      _refreshSnapshotTransferAuthorization();
      _acceptRemoteSnapshotSyncRequest(
        request: exchange.syncRequest,
        relation: relation,
        manifest: exchange.headManifest,
      );
      _acceptRemoteResolutionAck(exchange.resolutionAck);
      if (relation != P2pRevisionSummaryRelation.equal) {
        unawaited(refreshRevisionGraph());
      }
    } on P2pProbeException catch (error) {
      if (_disposed || secureGeneration != _secureTransportGeneration) return;
      state = state.copyWith(
        secureTransportError: "加密 revision summary 暫時無法交換：$error",
      );
    } on FormatException catch (error) {
      if (_disposed || secureGeneration != _secureTransportGeneration) return;
      _snapshotTransferSession.revoke();
      state = state.copyWith(
        secureTransportError: "已拒絕無效的加密 revision summary：${error.message}",
      );
    } on StateError catch (error) {
      if (_disposed || secureGeneration != _secureTransportGeneration) return;
      _snapshotTransferSession.revoke();
      state = state.copyWith(
        secureTransportError: "加密通道目前不可用：${error.message}",
      );
    }
  }

  Future<void> refreshRevisionGraph() async {
    if (!state.hasAuthenticatedTransport || _revisionGraphRefreshInProgress) {
      return;
    }
    final endpoint = state.reachablePeer;
    final localGraph = _effectiveLocalRevisionGraph();
    if (endpoint == null || localGraph == null) return;
    final secureGeneration = _secureTransportGeneration;
    _revisionGraphRefreshInProgress = true;
    _endpointService.updateLocalRevisionGraph(localGraph);
    state = state.copyWith(
      isRevisionGraphLoading: true,
      revisionGraphError: null,
    );
    try {
      final assembler = P2pRevisionGraphAssembler();
      final localPageCount = localGraph.revisions.isEmpty
          ? 1
          : (localGraph.revisions.length +
                    P2pRevisionGraphPage.maxRevisionsPerPage -
                    1) ~/
                P2pRevisionGraphPage.maxRevisionsPerPage;
      final first = await _endpointService.negotiateRevisionGraphPage(
        endpoint,
        localPageIndex: 0,
        remotePageIndex: 0,
      );
      assembler.add(first.remotePage);
      final remotePageCount = first.remotePage.pageCount;
      final exchangeCount = localPageCount > remotePageCount
          ? localPageCount
          : remotePageCount;
      for (var index = 1; index < exchangeCount; index++) {
        final exchange = await _endpointService.negotiateRevisionGraphPage(
          endpoint,
          localPageIndex: index % localPageCount,
          remotePageIndex: index % remotePageCount,
        );
        assembler.add(exchange.remotePage);
      }
      final remoteGraph = assembler.assemble();
      await _revisionStore.verifyRemoteGraphTransfer(
        graph: remoteGraph,
        transferId: first.remotePage.transferId,
      );
      if (_disposed ||
          secureGeneration != _secureTransportGeneration ||
          state.reachablePeer != endpoint ||
          state.sessionProjectUuid != remoteGraph.projectUuid) {
        return;
      }
      state = state.copyWith(
        remoteRevisionGraph: remoteGraph,
        commonAncestorRevisionIds: localGraph.commonAncestorIds(remoteGraph),
        isRevisionGraphLoading: false,
        revisionGraphError: null,
      );
      _revalidatePendingRemoteResolutionAck(remoteGraph);
    } on FormatException catch (error) {
      if (!_disposed && secureGeneration == _secureTransportGeneration) {
        state = state.copyWith(
          isRevisionGraphLoading: false,
          revisionGraphError: "已拒絕無效的加密 revision graph：${error.message}",
        );
      }
    } on P2pProbeException catch (error) {
      if (!_disposed && secureGeneration == _secureTransportGeneration) {
        state = state.copyWith(
          isRevisionGraphLoading: false,
          revisionGraphError: "revision graph 傳輸暫時中斷，可重新連線續傳：$error",
        );
      }
    } on StateError catch (error) {
      if (!_disposed && secureGeneration == _secureTransportGeneration) {
        state = state.copyWith(
          isRevisionGraphLoading: false,
          revisionGraphError: "revision graph 目前不可用：${error.message}",
        );
      }
    } finally {
      _revisionGraphRefreshInProgress = false;
    }
  }

  Future<bool> requestImmediateSync() async {
    final manifest = state.localSnapshotManifest;
    final canRequest = state.canRequestPeerSnapshotSync;
    if (!canRequest || manifest == null) {
      state = state.copyWith(
        errorMessage: state.reachablePeer == null
            ? "尚未取得已驗證的對方服務端點；請等待加密 revision summary 交換完成。"
            : "目前沒有可透過已驗證連線提供給對方的 snapshot。",
      );
      return false;
    }
    final request = P2pSnapshotSyncRequest(
      requestId:
          "sync-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${(++_snapshotSyncRequestCounter).toRadixString(36)}",
      projectUuid: manifest.projectUuid,
      revisionId: manifest.revisionId,
      contentSha256: manifest.contentSha256,
    );
    try {
      _endpointService.updateLocalSnapshotSyncRequest(request);
      state = state.copyWith(
        message: "已透過加密通道送出同步要求；等待接收端下載並選擇儲存位置。",
        errorMessage: null,
      );
      if (state.reachablePeer != null) {
        await refreshRevisionSummary();
      }
      return true;
    } catch (error) {
      state = state.copyWith(errorMessage: "無法送出同步要求：${_describeError(error)}");
      return false;
    }
  }

  void _acceptRemoteSnapshotSyncRequest({
    required P2pSnapshotSyncRequest? request,
    required P2pRevisionSummaryRelation relation,
    required P2pSnapshotManifest? manifest,
  }) {
    if (request == null ||
        request.requestId == _lastAcceptedSnapshotSyncRequestId) {
      return;
    }
    final canAccept =
        state.hasAuthenticatedTransport &&
        state.trustedPeer != null &&
        (relation == P2pRevisionSummaryRelation.remoteAhead ||
            relation == P2pRevisionSummaryRelation.concurrent) &&
        manifest != null &&
        manifest.projectUuid == state.sessionProjectUuid &&
        request.matches(manifest);
    if (!canAccept) return;
    _lastAcceptedSnapshotSyncRequestId = request.requestId;
    state = state.copyWith(
      incomingSnapshotSyncRequest: request,
      incomingSnapshotSyncRequestGeneration:
          state.incomingSnapshotSyncRequestGeneration + 1,
      message: "對方已透過加密通道要求同步；正在準備下載 snapshot。",
      errorMessage: null,
    );
  }

  void _acceptRemoteResolutionAck(P2pResolutionAck? ack) {
    if (ack == null) return;
    final trustedPeer = state.trustedPeer;
    if (!state.hasAuthenticatedTransport ||
        trustedPeer == null ||
        ack.acceptedByDeviceId != trustedPeer.deviceId ||
        ack.projectUuid != state.sessionProjectUuid) {
      _pendingRemoteResolutionAck = null;
      state = state.copyWith(
        revisionGraphError: "已拒絕身分或 project session 不一致的遠端 ACK。",
      );
      return;
    }

    final revision =
        _effectiveLocalRevisionGraph()?.revisions[ack.resolutionRevisionId];
    if (revision == null) {
      // Revision summaries and their ACK can legitimately arrive before the
      // authenticated revision graph page containing the resolve revision.
      // Keep the ACK pending instead of treating normal packet ordering as a
      // malicious mismatch. The graph transfer performs the authoritative
      // revision/hash/parent validation.
      _pendingRemoteResolutionAck = ack;
      state = state.copyWith(
        revisionGraphError: null,
        message: "已收到對方 resolve ACK；等待已驗證 revision graph 完成後確認。",
      );
      if (!_revisionGraphRefreshInProgress) {
        unawaited(refreshRevisionGraph());
      }
      return;
    }
    if (!ack.matchesRevision(revision)) {
      _pendingRemoteResolutionAck = null;
      state = state.copyWith(
        revisionGraphError: "已拒絕內容或 parent 與本機 resolve revision 不一致的遠端 ACK。",
      );
      return;
    }

    _pendingRemoteResolutionAck = null;
    state = state.copyWith(
      remoteResolutionAck: ack,
      revisionGraphError: null,
      message: "對方已 ACK resolve revision；雙方 revision DAG 已收斂。",
    );
    _endpointService.updateLocalSnapshotSyncRequest(null);
  }

  void _revalidatePendingRemoteResolutionAck(P2pRevisionGraph remoteGraph) {
    final ack = _pendingRemoteResolutionAck;
    if (ack == null) return;

    final localRevision =
        _effectiveLocalRevisionGraph()?.revisions[ack.resolutionRevisionId];
    if (localRevision != null) {
      _acceptRemoteResolutionAck(ack);
      return;
    }

    final remoteRevision = remoteGraph.revisions[ack.resolutionRevisionId];
    if (remoteRevision == null || !ack.matchesRevision(remoteRevision)) {
      _pendingRemoteResolutionAck = null;
      state = state.copyWith(
        revisionGraphError: "已拒絕未包含於對方已驗證 revision graph 的遠端 ACK。",
      );
      return;
    }

    state = state.copyWith(
      revisionGraphError: null,
      message: "對方已 ACK 遠端 resolve revision；等待下載並安裝該 revision。",
    );
  }

  Future<bool> beginPairing({
    bool allowSingleDeviceConfirmation = true,
    bool allowPersistentVerification = false,
  }) async {
    if (!state.canBeginPairing) return false;
    try {
      final challenge = await _identityStore.createPairingChallenge(
        allowSingleDeviceConfirmation: allowSingleDeviceConfirmation,
        allowPersistentVerification: allowPersistentVerification,
      );
      _endpointService.updateLocalPairingChallenge(challenge);
      _endpointService.updateLocalPairingConfirmation(null);
      _clearAuthenticatedTransport();
      state = state.copyWith(
        pairingStatus: P2pPairingStatus.waitingForPeer,
        localPairingChallenge: challenge,
        localPairingConfirmation: null,
        remotePairingConfirmation: null,
        pairingCode: null,
        trustedPeer: null,
        message: "已建立十分鐘有效的配對 challenge，等待對方開始配對。",
        errorMessage: null,
      );
      _startPairingChallengeRefresh();
      final remote = state.remotePairingChallenge;
      if (remote != null) await _acceptRemotePairingChallenge(remote);
      final endpoint = state.reachablePeer;
      if (endpoint != null) await _refreshPairingChallenge(endpoint);
      return true;
    } catch (error) {
      state = state.copyWith(
        pairingStatus: P2pPairingStatus.error,
        errorMessage: "無法開始安全配對：${_describeError(error)}",
      );
      return false;
    }
  }

  Future<bool> confirmPairingCode() async {
    final local = state.localPairingChallenge;
    final remote = state.remotePairingChallenge;
    if (state.pairingStatus != P2pPairingStatus.comparisonRequired ||
        local == null ||
        remote == null ||
        state.pairingCode == null) {
      return false;
    }
    try {
      await _identityStore.trustPeer(
        remote,
        persistentVerification: _persistentVerificationNegotiated(
          local,
          remote,
        ),
      );
      final confirmation = await _identityStore.createPairingConfirmation(
        local,
        remote,
      );
      final trusted = (await _identityStore
          .loadTrustedPeers())[remote.deviceId];
      _endpointService.updateLocalPairingConfirmation(confirmation);
      state = state.copyWith(
        pairingStatus: P2pPairingStatus.waitingForPeerConfirmation,
        localPairingConfirmation: confirmation,
        trustedPeer: trusted,
        message: state.isSingleDeviceConfirmationNegotiated
            ? "本機已簽署確認；等待對方驗證後自動回簽。"
            : "本機已簽署確認並加入信任清單；等待對方手動確認同一配對 transcript。",
        errorMessage: null,
      );
      final remoteConfirmation = state.remotePairingConfirmation;
      if (remoteConfirmation != null) {
        await _acceptRemotePairingConfirmation(remoteConfirmation);
      }
      final endpoint = state.reachablePeer;
      if (endpoint != null) await _refreshPairingConfirmation(endpoint);
      return true;
    } catch (error) {
      state = state.copyWith(
        pairingStatus: P2pPairingStatus.error,
        errorMessage: "儲存信任裝置失敗：${_describeError(error)}",
      );
      return false;
    }
  }

  void cancelPairing() {
    _pairingChallengeRefreshTimer?.cancel();
    _pairingChallengeRefreshTimer = null;
    _endpointService.updateLocalPairingChallenge(null);
    _endpointService.updateLocalPairingConfirmation(null);
    _clearAuthenticatedTransport();
    state = state.copyWith(
      pairingStatus: P2pPairingStatus.idle,
      localPairingChallenge: null,
      remotePairingChallenge: null,
      localPairingConfirmation: null,
      remotePairingConfirmation: null,
      pairingCode: null,
      trustedPeer: null,
      message: "已取消本次配對。",
      errorMessage: null,
    );
  }

  void handlePairingPreferenceChanged() {
    if (state.pairingStatus == P2pPairingStatus.idle) return;
    cancelPairing();
    state = state.copyWith(message: "配對確認設定已變更；請重新開始配對。", errorMessage: null);
  }

  void _clearAuthenticatedTransport() {
    ++_secureTransportGeneration;
    _revisionSummaryRefreshOperation = null;
    _revisionSummaryRefreshPending = false;
    _revisionGraphRefreshInProgress = false;
    _lastRevisionSummaryRefreshAt = null;
    _lastAcceptedSnapshotSyncRequestId = null;
    _pendingRemoteResolutionAck = null;
    _snapshotTransferSession.revoke();
    _endpointService.configureSnapshotContentTransfer(enabled: false);
    _endpointService.installAuthenticatedSession(null);
    _endpointService.updateLocalRevisionGraph(null);
    _endpointService.updateLocalResolutionAck(null);
    _endpointService.updateLocalRevisionSummary(null);
    _endpointService.updateLocalSnapshotManifests(
      const <P2pSnapshotManifest>[],
    );
    state = state.copyWith(
      secureTransportStatus: P2pSecureTransportStatus.inactive,
      remoteRevisionSummary: null,
      revisionSummaryRelation: null,
      remoteRevisionGraph: null,
      commonAncestorRevisionIds: const <String>{},
      isRevisionGraphLoading: false,
      revisionGraphError: null,
      localResolutionAck: null,
      remoteResolutionAck: null,
      remoteSnapshotManifest: null,
      snapshotManifestStatus: P2pSnapshotManifestStatus.inactive,
      snapshotManifestError: null,
      incomingSnapshotSyncRequest: null,
      secureTransportError: null,
    );
  }

  void _enableSnapshotContentTransfer() {
    final projectUuid = state.sessionProjectUuid;
    if (!state.hasAuthenticatedTransport || projectUuid == null) {
      _snapshotTransferSession.revoke();
      _endpointService.configureSnapshotContentTransfer(enabled: false);
      return;
    }
    _refreshSnapshotTransferAuthorization();
    final secureGeneration = _secureTransportGeneration;
    _endpointService.configureSnapshotContentTransfer(
      enabled: true,
      loader: (manifest, chunkIndex) => _loadAuthorizedSnapshotChunk(
        manifest,
        chunkIndex,
        secureGeneration: secureGeneration,
        projectUuid: projectUuid,
      ),
    );
  }

  void _refreshSnapshotTransferAuthorization() {
    final endpoint = state.reachablePeer;
    final projectUuid = state.sessionProjectUuid;
    final remoteManifest = state.remoteSnapshotManifest;
    if (!state.hasAuthenticatedTransport ||
        endpoint == null ||
        projectUuid == null ||
        state.snapshotManifestStatus != P2pSnapshotManifestStatus.available ||
        remoteManifest == null ||
        remoteManifest.projectUuid != projectUuid) {
      _snapshotTransferSession.revoke();
      return;
    }
    _snapshotTransferSession.authorize(
      endpoint: endpoint,
      projectUuid: projectUuid,
      remoteManifest: remoteManifest,
    );
  }

  Future<P2pSnapshotChunk?> _loadAuthorizedSnapshotChunk(
    P2pSnapshotManifest manifest,
    int chunkIndex, {
    required int secureGeneration,
    required String projectUuid,
  }) async {
    if (_disposed ||
        secureGeneration != _secureTransportGeneration ||
        !state.hasAuthenticatedTransport ||
        state.sessionProjectUuid != projectUuid ||
        manifest.projectUuid != projectUuid ||
        _localSnapshotManifests[manifest.revisionId] != manifest) {
      return null;
    }
    if (!await _snapshotContentStore.containsVerifiedSnapshot(manifest)) {
      return null;
    }
    if (_disposed ||
        secureGeneration != _secureTransportGeneration ||
        !state.hasAuthenticatedTransport ||
        state.sessionProjectUuid != projectUuid ||
        _localSnapshotManifests[manifest.revisionId] != manifest) {
      return null;
    }
    final chunk = await _snapshotContentStore.readChunk(manifest, chunkIndex);
    if (_disposed ||
        secureGeneration != _secureTransportGeneration ||
        !state.hasAuthenticatedTransport ||
        state.sessionProjectUuid != projectUuid ||
        _localSnapshotManifests[manifest.revisionId] != manifest) {
      return null;
    }
    return chunk;
  }

  void updateLocalProjectStatus(P2pProjectStatus? status) {
    final currentUuid = _validUuidFromStatus(status);
    final sessionUuid = state.sessionProjectUuid;
    final isRetainingAuthenticatedSessionProject =
        currentUuid != null &&
        currentUuid == sessionUuid &&
        state.hasAuthenticatedTransport &&
        state.remoteRevisionGraph?.projectUuid == currentUuid;
    _currentLocalProjectUuid = currentUuid;
    if (currentUuid == null) {
      _loadedRevisionProjectUuid = null;
      _localSnapshotManifests = const <String, P2pSnapshotManifest>{};
      _endpointService.updateLocalRevisionGraph(null);
      _endpointService.updateLocalRevisionSummary(null);
      state = state.copyWith(
        localRevisionGraph: null,
        localSnapshotManifest: null,
        localDraftHeadIds: const <String>{},
        localRevisionDelta: null,
        remoteRevisionGraph: null,
        commonAncestorRevisionIds: const <String>{},
        isRevisionGraphLoading: false,
        revisionGraphError: null,
        localResolutionAck: null,
        remoteResolutionAck: null,
        isRevisionMetadataLoading: false,
        revisionMetadataError: null,
      );
    } else if (_loadedRevisionProjectUuid != currentUuid) {
      _loadedRevisionProjectUuid = currentUuid;
      _localSnapshotManifests = const <String, P2pSnapshotManifest>{};
      _endpointService.updateLocalRevisionGraph(null);
      _endpointService.updateLocalRevisionSummary(null);
      state = state.copyWith(
        localRevisionGraph: null,
        localSnapshotManifest: null,
        localDraftHeadIds: const <String>{},
        localRevisionDelta: null,
        // Persisting a verified snapshot republishes the same project from
        // the file/provider layer. The remote DAG is still the capability
        // needed by installAppliedRemoteSnapshot(), both for an initially
        // empty receiver and when overwriting an older same-UUID file.
        remoteRevisionGraph: isRetainingAuthenticatedSessionProject
            ? state.remoteRevisionGraph
            : null,
        commonAncestorRevisionIds: isRetainingAuthenticatedSessionProject
            ? state.commonAncestorRevisionIds
            : const <String>{},
        isRevisionGraphLoading: false,
        revisionGraphError: null,
        isRevisionMetadataLoading: !isRetainingAuthenticatedSessionProject,
        revisionMetadataError: null,
      );
      if (!isRetainingAuthenticatedSessionProject) {
        unawaited(_loadRevisionMetadata(currentUuid));
      }
    }
    final switchedProject =
        sessionUuid != null &&
        (currentUuid != null
            ? currentUuid != sessionUuid
            : state.selectedProjectSource != P2pProjectSource.remote);
    var offer = P2pProjectOffer.fromStatus(status);
    if (!switchedProject &&
        sessionUuid != null &&
        currentUuid == sessionUuid &&
        !offer.hasProject) {
      // Dirty state pauses content sync, but it is still the same open file.
      offer = state.localProjectOffer;
    }
    if (state.localProjectOffer == offer && !switchedProject) return;

    _endpointService.updateLocalProjectOffer(offer);
    state = state.copyWith(localProjectOffer: offer);
    if (switchedProject) {
      final endpoint = state.reachablePeer;
      if (endpoint == null) {
        _endpointService.requestDisconnectOnNextExchange();
        _disconnectForProjectChange(remoteChanged: false);
      } else {
        unawaited(_announceProjectChangeAndDisconnect(endpoint));
      }
      return;
    }

    final remoteOffer = state.remoteProjectOffer;
    if (state.hasReachablePeer && remoteOffer != null) {
      final negotiation = P2pProjectNegotiationResult.evaluate(
        local: offer,
        remote: remoteOffer,
      );
      _applyNegotiation(
        negotiation: negotiation,
        remoteOffer: remoteOffer,
        connectionStatus: state.connectionStatus,
        reachablePeer: state.reachablePeer,
        inboundPeerAddress: state.inboundPeerAddress,
      );
      if (state.reachablePeer != null) unawaited(refreshPeerOffer());
    }
  }

  Future<void> _loadRevisionMetadata(String projectUuid) async {
    try {
      final graph = await _revisionStore.loadGraph(projectUuid);
      final identity =
          state.localIdentity ?? await _identityStore.loadOrCreateIdentity();
      final workingRevision = _workingRevisionForGraph(
        graph,
        localDeviceId: identity.deviceId,
      );
      final manifest = workingRevision == null
          ? null
          : await _revisionStore.loadSnapshotManifest(
              projectUuid: graph.projectUuid,
              revisionId: workingRevision.revisionId,
            );
      final manifests = await _loadAvailableManifests(graph);
      final draftState = await _revisionStore.loadDraftState(projectUuid);
      final resolutionAck = await _revisionStore.loadResolutionAck(projectUuid);
      if (_disposed || _loadedRevisionProjectUuid != projectUuid) return;
      _localSnapshotManifests = manifests;
      state = state.copyWith(
        localIdentity: identity,
        localRevisionGraph: graph,
        localSnapshotManifest: manifest,
        localDraftHeadIds: draftState.draftHeadIds,
        localRevisionDelta: draftState.delta,
        isRevisionMetadataLoading: false,
        revisionMetadataError: null,
        localResolutionAck: resolutionAck,
      );
      _endpointService.updateLocalRevisionGraph(graph);
      _endpointService.updateLocalResolutionAck(resolutionAck);
      _endpointService.updateLocalRevisionSummary(_summaryForGraph(graph));
      _endpointService.updateLocalSnapshotManifests(manifests.values);
      if (state.hasAuthenticatedTransport) {
        unawaited(refreshRevisionSummary());
      }
    } catch (error) {
      if (_disposed || _loadedRevisionProjectUuid != projectUuid) return;
      state = state.copyWith(
        localRevisionGraph: null,
        localSnapshotManifest: null,
        localDraftHeadIds: const <String>{},
        localRevisionDelta: null,
        isRevisionMetadataLoading: false,
        revisionMetadataError:
            "無法載入 revision metadata：${_describeError(error)}",
      );
      _localSnapshotManifests = const <String, P2pSnapshotManifest>{};
      _endpointService.updateLocalRevisionGraph(null);
      _endpointService.updateLocalResolutionAck(null);
      _endpointService.updateLocalRevisionSummary(null);
      _endpointService.updateLocalSnapshotManifests(
        const <P2pSnapshotManifest>[],
      );
    }
  }

  Future<bool> recordPersistedSnapshot({
    required String projectUuid,
    required String xmlContent,
    required String formatVersion,
  }) async {
    final normalizedProjectUuid = projectUuid.trim().toLowerCase();
    if (!P2pProjectStatus.isValidProjectUuid(normalizedProjectUuid)) {
      state = state.copyWith(
        revisionMetadataError: "無法建立 revision：project UUID 無效。",
      );
      return false;
    }
    if (_currentLocalProjectUuid == normalizedProjectUuid) {
      state = state.copyWith(
        isRevisionMetadataLoading: true,
        revisionMetadataError: null,
      );
    }
    final previousHeadRevisionId =
        state.localRevisionGraph?.singleHead?.revisionId;
    try {
      final identity =
          state.localIdentity ?? await _identityStore.loadOrCreateIdentity();
      final previousWorkingRevision = state.localRevisionGraph == null
          ? null
          : _workingRevisionForGraph(
              state.localRevisionGraph!,
              localDeviceId: identity.deviceId,
              preferredRevisionId: state.localSnapshotManifest?.revisionId,
            );
      final graph = await _revisionStore.recordPersistedSnapshot(
        projectUuid: normalizedProjectUuid,
        authorDeviceId: identity.deviceId,
        xmlContent: xmlContent,
        formatVersion: formatVersion,
        preferredParentRevisionId: previousWorkingRevision?.revisionId,
      );
      final workingRevision = _workingRevisionForGraph(
        graph,
        localDeviceId: identity.deviceId,
        preferredRevisionId: previousWorkingRevision?.revisionId,
      );
      final manifest = workingRevision == null
          ? null
          : await _revisionStore.loadSnapshotManifest(
              projectUuid: graph.projectUuid,
              revisionId: workingRevision.revisionId,
            );
      final manifests = await _loadAvailableManifests(graph);
      final draftState = await _revisionStore.loadDraftState(
        normalizedProjectUuid,
      );
      if (_disposed || _currentLocalProjectUuid != normalizedProjectUuid) {
        return true;
      }
      _loadedRevisionProjectUuid = normalizedProjectUuid;
      _localSnapshotManifests = manifests;
      state = state.copyWith(
        localIdentity: identity,
        localRevisionGraph: graph,
        localSnapshotManifest: manifest,
        localDraftHeadIds: draftState.draftHeadIds,
        localRevisionDelta: draftState.delta,
        isRevisionMetadataLoading: false,
        revisionMetadataError: null,
      );
      _endpointService.updateLocalRevisionGraph(graph);
      _endpointService.updateLocalRevisionSummary(_summaryForGraph(graph));
      _endpointService.updateLocalSnapshotManifests(manifests.values);
      if (state.hasAuthenticatedTransport) {
        if (manifest != null &&
            manifest.revisionId != previousHeadRevisionId &&
            state.sessionProjectUuid == manifest.projectUuid) {
          _endpointService.updateLocalSnapshotSyncRequest(
            P2pSnapshotSyncRequest(
              requestId:
                  "live-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${(++_snapshotSyncRequestCounter).toRadixString(36)}",
              projectUuid: manifest.projectUuid,
              revisionId: manifest.revisionId,
              contentSha256: manifest.contentSha256,
            ),
          );
          state = state.copyWith(message: "已儲存新 revision；正在透過加密通道即時通知對方同步。");
        }
        unawaited(refreshRevisionSummary());
      }
      return true;
    } catch (error) {
      if (!_disposed && _currentLocalProjectUuid == normalizedProjectUuid) {
        state = state.copyWith(
          isRevisionMetadataLoading: false,
          revisionMetadataError:
              "無法建立 revision metadata：${_describeError(error)}",
        );
      }
      return false;
    }
  }

  Future<bool> recordDraftSnapshot({
    required String projectUuid,
    required String xmlContent,
    required String formatVersion,
  }) async {
    final normalizedProjectUuid = projectUuid.trim().toLowerCase();
    if (!P2pProjectStatus.isValidProjectUuid(normalizedProjectUuid) ||
        _currentLocalProjectUuid != normalizedProjectUuid) {
      return false;
    }
    final previousHeadRevisionId =
        state.localRevisionGraph?.singleHead?.revisionId;
    try {
      final identity =
          state.localIdentity ?? await _identityStore.loadOrCreateIdentity();
      final previousWorkingRevision = state.localRevisionGraph == null
          ? null
          : _workingRevisionForGraph(
              state.localRevisionGraph!,
              localDeviceId: identity.deviceId,
              preferredRevisionId: state.localSnapshotManifest?.revisionId,
            );
      final record = await _revisionStore.recordDraftSnapshot(
        projectUuid: normalizedProjectUuid,
        authorDeviceId: identity.deviceId,
        xmlContent: xmlContent,
        formatVersion: formatVersion,
        preferredParentRevisionId: previousWorkingRevision?.revisionId,
      );
      if (_disposed || _currentLocalProjectUuid != normalizedProjectUuid) {
        return true;
      }
      final manifests = await _loadAvailableManifests(record.graph);
      _loadedRevisionProjectUuid = normalizedProjectUuid;
      _localSnapshotManifests = manifests;
      state = state.copyWith(
        localIdentity: identity,
        localRevisionGraph: record.graph,
        localSnapshotManifest: record.manifest,
        localDraftHeadIds: record.draftState.draftHeadIds,
        localRevisionDelta: record.draftState.delta,
        isRevisionMetadataLoading: false,
        revisionMetadataError: null,
      );
      _endpointService.updateLocalRevisionGraph(record.graph);
      _endpointService.updateLocalRevisionSummary(
        _summaryForGraph(record.graph),
      );
      _endpointService.updateLocalSnapshotManifests(manifests.values);
      if (state.hasAuthenticatedTransport &&
          state.sessionProjectUuid == normalizedProjectUuid &&
          record.manifest.revisionId != previousHeadRevisionId) {
        _endpointService.updateLocalSnapshotSyncRequest(
          P2pSnapshotSyncRequest(
            requestId:
                "draft-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${(++_snapshotSyncRequestCounter).toRadixString(36)}",
            projectUuid: record.manifest.projectUuid,
            revisionId: record.manifest.revisionId,
            contentSha256: record.manifest.contentSha256,
          ),
        );
        state = state.copyWith(
          message: record.draftState.delta == null
              ? "draft revision 已建立；正在透過加密通道傳送 summary。"
              : "draft revision 已建立；正在透過加密通道傳送 summary/delta。",
        );
        unawaited(refreshRevisionSummary());
      }
      return true;
    } catch (error) {
      if (!_disposed && _currentLocalProjectUuid == normalizedProjectUuid) {
        state = state.copyWith(
          revisionMetadataError: "無法建立 draft revision：${_describeError(error)}",
        );
      }
      return false;
    }
  }

  Future<P2pVerifiedSnapshot?> materializeRemoteDelta(
    P2pSnapshotManifest manifest,
  ) async {
    final summary = state.remoteRevisionSummary;
    final delta = summary?.delta;
    final localGraph = state.localRevisionGraph;
    if (!state.hasAuthenticatedTransport ||
        summary == null ||
        delta == null ||
        localGraph == null ||
        delta.projectUuid != manifest.projectUuid ||
        delta.targetRevisionId != manifest.revisionId ||
        delta.targetContentSha256 != manifest.contentSha256 ||
        summary.heads.length != 1 ||
        summary.heads.single.revisionId != manifest.revisionId) {
      return null;
    }
    final baseRevision = localGraph.revisions[delta.baseRevisionId];
    final targetRevision = summary.heads.single;
    if (baseRevision == null ||
        !delta.matchesRevisions(base: baseRevision, target: targetRevision)) {
      return null;
    }
    try {
      final baseXml = await _revisionStore.loadSnapshotXml(
        projectUuid: manifest.projectUuid,
        revisionId: baseRevision.revisionId,
      );
      if (baseXml == null) return null;
      final targetBytes = delta.applyTo(utf8.encode(baseXml));
      return verifyP2pSnapshotBytes(manifest, targetBytes);
    } catch (error) {
      if (!_disposed) {
        state = state.copyWith(
          revisionMetadataError:
              "已拒絕無效的 revision delta，將改用完整 snapshot：${_describeError(error)}",
        );
      }
      return null;
    }
  }

  Future<bool> installAppliedRemoteSnapshot(
    P2pVerifiedSnapshot snapshot, {
    required P2pRevisionGraph verifiedRemoteGraph,
    required P2pSnapshotTransferAuthorization transferAuthorization,
    required String expectedPeerDeviceId,
  }) async {
    final manifest = snapshot.manifest;
    final projectUuid = state.sessionProjectUuid;
    final invalidReasons = <String>[
      if (!state.hasAuthenticatedTransport) "加密通道已失效",
      if (!_snapshotTransferSession.isCurrent(transferAuthorization))
        "snapshot session capability 已撤銷",
      if (projectUuid == null ||
          projectUuid != transferAuthorization.projectUuid)
        "project session 已變更",
      if (state.reachablePeer != transferAuthorization.endpoint)
        "peer endpoint 已變更",
      if (state.trustedPeer?.deviceId != expectedPeerDeviceId) "信任裝置已變更",
      if (manifest != transferAuthorization.remoteManifest)
        "snapshot manifest 已變更",
      if (verifiedRemoteGraph.projectUuid != projectUuid)
        "revision graph project 不符",
      if (verifiedRemoteGraph.revisions[manifest.revisionId] == null)
        "revision graph 不含目標 snapshot",
    ];
    if (invalidReasons.isNotEmpty) {
      state = state.copyWith(
        revisionMetadataError: "無法保存遠端歷史：${invalidReasons.join("、")}。",
      );
      return false;
    }
    final activeProjectUuid = transferAuthorization.projectUuid;
    try {
      final remoteSummary = state.remoteRevisionSummary;
      await _revisionStore.installVerifiedRemoteSnapshot(
        remoteGraph: verifiedRemoteGraph,
        manifest: manifest,
        xmlContent: snapshot.xmlContent,
        remoteDraftHeadIds: remoteSummary?.draftHeadIds ?? const <String>{},
        remoteDelta: remoteSummary?.delta,
      );
      final graph = await _revisionStore.loadGraph(activeProjectUuid);
      final manifests = await _loadAvailableManifests(graph);
      final draftState = await _revisionStore.loadDraftState(activeProjectUuid);
      final head = graph.singleHead;
      final headManifest = head == null ? null : manifests[head.revisionId];
      if (_disposed ||
          !_snapshotTransferSession.isCurrent(transferAuthorization) ||
          state.sessionProjectUuid != activeProjectUuid ||
          state.reachablePeer != transferAuthorization.endpoint ||
          state.trustedPeer?.deviceId != expectedPeerDeviceId) {
        return false;
      }
      _loadedRevisionProjectUuid = activeProjectUuid;
      _currentLocalProjectUuid = activeProjectUuid;
      _localSnapshotManifests = manifests;
      P2pResolutionAck? resolutionAck = state.localResolutionAck;
      if (head != null && head.parents.length >= 2) {
        final identity =
            state.localIdentity ?? await _identityStore.loadOrCreateIdentity();
        resolutionAck = P2pResolutionAck(
          projectUuid: activeProjectUuid,
          resolutionRevisionId: head.revisionId,
          contentSha256: head.contentSha256,
          acceptedByDeviceId: identity.deviceId,
          acceptedAtEpochSeconds:
              DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
        );
        await _revisionStore.saveResolutionAck(resolutionAck);
      }
      final installedRemoteSummary =
          remoteSummary ?? P2pRevisionSummary.fromGraph(verifiedRemoteGraph);
      state = state.copyWith(
        localRevisionGraph: graph,
        localSnapshotManifest: headManifest,
        localDraftHeadIds: draftState.draftHeadIds,
        localRevisionDelta: draftState.delta,
        isRevisionMetadataLoading: false,
        revisionMetadataError: null,
        remoteRevisionSummary: installedRemoteSummary,
        remoteRevisionGraph: verifiedRemoteGraph,
        commonAncestorRevisionIds: graph.commonAncestorIds(verifiedRemoteGraph),
        localResolutionAck: resolutionAck,
      );
      final localSummary = _summaryForGraph(graph);
      state = state.copyWith(
        revisionSummaryRelation: localSummary.compare(installedRemoteSummary),
      );
      _endpointService.updateLocalRevisionGraph(graph);
      _endpointService.updateLocalResolutionAck(resolutionAck);
      _endpointService.updateLocalRevisionSummary(localSummary);
      _endpointService.updateLocalSnapshotManifests(manifests.values);
      final pendingRemoteAck = _pendingRemoteResolutionAck;
      if (pendingRemoteAck != null) {
        _acceptRemoteResolutionAck(pendingRemoteAck);
      }
      if (state.hasAuthenticatedTransport) {
        unawaited(refreshRevisionSummary());
      }
      return true;
    } catch (error) {
      if (!_disposed) {
        state = state.copyWith(
          revisionMetadataError:
              "遠端 snapshot 已開啟，但保存 revision DAG 失敗：${_describeError(error)}",
        );
      }
      return false;
    }
  }

  Future<bool> stageConcurrentRemoteSnapshot(
    P2pVerifiedSnapshot snapshot,
  ) async {
    final remoteGraph = state.remoteRevisionGraph;
    final manifest = snapshot.manifest;
    if (!state.hasAuthenticatedTransport ||
        state.revisionSummaryRelation !=
            P2pRevisionSummaryRelation.concurrent ||
        remoteGraph == null ||
        remoteGraph.projectUuid != state.sessionProjectUuid ||
        remoteGraph.revisions[manifest.revisionId] == null) {
      state = state.copyWith(
        revisionMetadataError: "無法暫存遠端 conflict snapshot：session 或 DAG 已失效。",
      );
      return false;
    }
    try {
      final remoteSummary = state.remoteRevisionSummary;
      await _revisionStore.installVerifiedRemoteSnapshot(
        remoteGraph: remoteGraph,
        manifest: manifest,
        xmlContent: snapshot.xmlContent,
        remoteDraftHeadIds: remoteSummary?.draftHeadIds ?? const <String>{},
        remoteDelta: remoteSummary?.delta,
      );
      final graph = await _revisionStore.loadGraph(manifest.projectUuid);
      final manifests = await _loadAvailableManifests(graph);
      final draftState = await _revisionStore.loadDraftState(
        manifest.projectUuid,
      );
      if (_disposed || state.sessionProjectUuid != manifest.projectUuid) {
        return false;
      }
      _localSnapshotManifests = manifests;
      state = state.copyWith(
        localRevisionGraph: graph,
        // This manifest identifies the currently open local branch even after
        // the verified remote branch is added to the same DAG.
        localSnapshotManifest: state.localSnapshotManifest,
        localDraftHeadIds: draftState.draftHeadIds,
        localRevisionDelta: draftState.delta,
        revisionMetadataError: null,
      );
      _endpointService.updateLocalRevisionGraph(graph);
      _endpointService.updateLocalRevisionSummary(_summaryForGraph(graph));
      _endpointService.updateLocalSnapshotManifests(manifests.values);
      return true;
    } catch (error) {
      if (!_disposed) {
        state = state.copyWith(
          revisionMetadataError:
              "無法暫存遠端 conflict snapshot：${_describeError(error)}",
        );
      }
      return false;
    }
  }

  Future<P2pProjectMergePlan?> prepareConcurrentMerge(
    P2pVerifiedSnapshot remoteSnapshot,
  ) async {
    final localGraph = state.localRevisionGraph;
    final remoteGraph = state.remoteRevisionGraph;
    final commonAncestors = state.commonAncestorRevisionIds;
    final localRevision = localGraph == null
        ? null
        : _workingRevisionForGraph(
            localGraph,
            localDeviceId: state.localIdentity?.deviceId,
            preferredRevisionId: state.localSnapshotManifest?.revisionId,
          );
    if (!state.hasAuthenticatedTransport ||
        state.revisionSummaryRelation !=
            P2pRevisionSummaryRelation.concurrent ||
        localRevision == null ||
        remoteGraph?.singleHead == null ||
        remoteSnapshot.manifest.revisionId !=
            remoteGraph!.singleHead!.revisionId ||
        commonAncestors.length > 1) {
      state = state.copyWith(
        revisionMetadataError: commonAncestors.length > 1
            ? "偵測到多個 maximal common ancestors；必須先取得 recursive merge base，未進行猜測式合併。"
            : "無法建立欄位合併：authenticated session 或 concurrent heads 已失效。",
      );
      return null;
    }
    final activeLocalGraph = localGraph!;
    final remoteRevision = remoteGraph.singleHead!;
    try {
      final localXml = await _revisionStore.loadSnapshotXml(
        projectUuid: activeLocalGraph.projectUuid,
        revisionId: localRevision.revisionId,
      );
      if (localXml == null) {
        throw StateError("本機 head snapshot 尚未保存在本機。");
      }
      final mergeService = ref.read(p2pProjectMergeServiceProvider);
      final sessionId =
          "${state.trustedPeer!.deviceId}:${localRevision.revisionId}:${remoteRevision.revisionId}";
      late final P2pProjectMergePlan plan;
      if (commonAncestors.isEmpty) {
        plan = mergeService.createPlanFromUnrelatedVerifiedXml(
          sessionId: sessionId,
          localRevision: localRevision,
          remoteRevision: remoteRevision,
          localXml: localXml,
          remoteXml: remoteSnapshot.xmlContent,
        );
      } else {
        final baseRevisionId = commonAncestors.single;
        final baseRevision =
            activeLocalGraph.revisions[baseRevisionId] ??
            remoteGraph.revisions[baseRevisionId];
        if (baseRevision == null) {
          throw StateError("共同祖先 metadata 不存在。");
        }
        final baseXml = await _revisionStore.loadSnapshotXml(
          projectUuid: activeLocalGraph.projectUuid,
          revisionId: baseRevision.revisionId,
        );
        if (baseXml == null) {
          throw StateError("共同祖先 snapshot 尚未保存在本機。");
        }
        plan = mergeService.createPlanFromVerifiedXml(
          sessionId: sessionId,
          baseRevision: baseRevision,
          localRevision: localRevision,
          remoteRevision: remoteRevision,
          baseXml: baseXml,
          localXml: localXml,
          remoteXml: remoteSnapshot.xmlContent,
        );
      }
      if (!await stageConcurrentRemoteSnapshot(remoteSnapshot)) return null;
      return plan;
    } catch (error) {
      if (!_disposed) {
        state = state.copyWith(
          revisionMetadataError:
              "無法建立 ProjectData 欄位合併：${_describeError(error)}",
        );
      }
      return null;
    }
  }

  Future<P2pRevisionGraph?> recordResolvedSnapshot({
    required Iterable<String> parentRevisionIds,
    required String xmlContent,
    required String formatVersion,
  }) async {
    final projectUuid = state.sessionProjectUuid;
    if (projectUuid == null || !state.hasAuthenticatedTransport) return null;
    try {
      final identity =
          state.localIdentity ?? await _identityStore.loadOrCreateIdentity();
      final graph = await _revisionStore.recordResolvedSnapshot(
        projectUuid: projectUuid,
        authorDeviceId: identity.deviceId,
        parentRevisionIds: parentRevisionIds,
        xmlContent: xmlContent,
        formatVersion: formatVersion,
      );
      final manifests = await _loadAvailableManifests(graph);
      final head = graph.singleHead;
      final manifest = head == null ? null : manifests[head.revisionId];
      if (_disposed || state.sessionProjectUuid != projectUuid) return null;
      _localSnapshotManifests = manifests;
      state = state.copyWith(
        localIdentity: identity,
        localRevisionGraph: graph,
        localSnapshotManifest: manifest,
        localDraftHeadIds: const <String>{},
        localRevisionDelta: null,
        remoteRevisionSummary: null,
        revisionSummaryRelation: null,
        remoteRevisionGraph: null,
        commonAncestorRevisionIds: const <String>{},
        localResolutionAck: null,
        remoteResolutionAck: null,
        revisionMetadataError: null,
        message: "已建立雙 parent resolve revision；等待透過加密通道傳播。",
      );
      _endpointService.updateLocalRevisionGraph(graph);
      _endpointService.updateLocalResolutionAck(null);
      _endpointService.updateLocalRevisionSummary(_summaryForGraph(graph));
      _endpointService.updateLocalSnapshotManifests(manifests.values);
      if (manifest != null) {
        _endpointService.updateLocalSnapshotSyncRequest(
          P2pSnapshotSyncRequest(
            requestId:
                "resolve-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${(++_snapshotSyncRequestCounter).toRadixString(36)}",
            projectUuid: manifest.projectUuid,
            revisionId: manifest.revisionId,
            contentSha256: manifest.contentSha256,
          ),
        );
      }
      unawaited(refreshRevisionSummary());
      return graph;
    } catch (error) {
      if (!_disposed) {
        state = state.copyWith(
          revisionMetadataError:
              "無法建立 resolve revision：${_describeError(error)}",
        );
      }
      return null;
    }
  }

  Future<Map<String, P2pSnapshotManifest>> _loadAvailableManifests(
    P2pRevisionGraph graph,
  ) async {
    final manifests = <String, P2pSnapshotManifest>{};
    for (final revision in graph.topologicallySortedRevisions) {
      final manifest = await _revisionStore.loadSnapshotManifest(
        projectUuid: graph.projectUuid,
        revisionId: revision.revisionId,
      );
      if (manifest != null) manifests[revision.revisionId] = manifest;
    }
    return Map.unmodifiable(manifests);
  }

  P2pRevisionMetadata? _workingRevisionForGraph(
    P2pRevisionGraph graph, {
    required String? localDeviceId,
    String? preferredRevisionId,
  }) {
    final singleHead = graph.singleHead;
    if (singleHead != null) return singleHead;
    final preferred = preferredRevisionId?.trim().toLowerCase();
    if (preferred != null && graph.headIds.contains(preferred)) {
      final direct = graph.revisions[preferred]!;
      final descendants = graph.heads
          .where((revision) => revision.parents.contains(preferred))
          .toList(growable: false);
      return descendants.length == 1 ? descendants.single : direct;
    }
    final normalizedDeviceId = localDeviceId?.trim().toLowerCase();
    if (normalizedDeviceId == null) return null;
    final localHeads = graph.heads
        .where((revision) => revision.authorDeviceId == normalizedDeviceId)
        .toList(growable: false);
    return localHeads.length == 1 ? localHeads.single : null;
  }

  P2pRevisionSummary _summaryForGraph(P2pRevisionGraph graph) {
    if (!graph.hasConflict) {
      return P2pRevisionSummary.fromGraph(
        graph,
        draftHeadIds: state.localDraftHeadIds.where(graph.headIds.contains),
        delta:
            state.localRevisionDelta?.targetRevisionId ==
                graph.singleHead?.revisionId
            ? state.localRevisionDelta
            : null,
      );
    }
    final workingRevision = _workingRevisionForGraph(
      graph,
      localDeviceId: state.localIdentity?.deviceId,
      preferredRevisionId: state.localSnapshotManifest?.revisionId,
    );
    return workingRevision == null
        ? P2pRevisionSummary.fromGraph(
            graph,
            draftHeadIds: state.localDraftHeadIds.where(graph.headIds.contains),
          )
        : P2pRevisionSummary(
            projectUuid: graph.projectUuid,
            heads: <P2pRevisionMetadata>[workingRevision],
            draftHeadIds:
                state.localDraftHeadIds.contains(workingRevision.revisionId)
                ? <String>{workingRevision.revisionId}
                : const <String>{},
            delta:
                state.localRevisionDelta?.targetRevisionId ==
                    workingRevision.revisionId
                ? state.localRevisionDelta
                : null,
          );
  }

  String? _validUuidFromStatus(P2pProjectStatus? status) {
    final value = status?.projectUuid?.trim().toLowerCase();
    return P2pProjectStatus.isValidProjectUuid(value) ? value : null;
  }

  bool _isDifferentFromSession(
    P2pProjectOffer offer, {
    required bool remoteSide,
  }) {
    final sessionUuid = state.sessionProjectUuid;
    if (sessionUuid == null) return false;
    if (offer.hasProject) return offer.projectUuid != sessionUuid;
    final source = state.selectedProjectSource;
    if (source == null) return true;
    return remoteSide
        ? source == P2pProjectSource.remote
        : source == P2pProjectSource.local;
  }

  void _applyNegotiation({
    required P2pProjectNegotiationResult negotiation,
    required P2pProjectOffer remoteOffer,
    required P2pConnectionStatus connectionStatus,
    required P2pEndpoint? reachablePeer,
    required String? inboundPeerAddress,
  }) {
    final automaticSource = negotiation.automaticSource;
    final sessionProjectUuid = switch (negotiation.kind) {
      P2pProjectNegotiationKind.sameProject =>
        state.localProjectOffer.projectUuid,
      P2pProjectNegotiationKind.localProvides =>
        state.localProjectOffer.projectUuid,
      P2pProjectNegotiationKind.remoteProvides => remoteOffer.projectUuid,
      P2pProjectNegotiationKind.selectionRequired => null,
    };
    final selectedProjectSource =
        automaticSource ??
        (sessionProjectUuid != null &&
                state.sessionProjectUuid == sessionProjectUuid
            ? state.selectedProjectSource
            : null);
    state = state.copyWith(
      connectionStatus: connectionStatus,
      reachablePeer: reachablePeer,
      inboundPeerAddress: inboundPeerAddress,
      remoteProjectOffer: remoteOffer,
      projectNegotiation: negotiation,
      selectedProjectSource: selectedProjectSource,
      sessionProjectUuid: sessionProjectUuid,
      negotiationGeneration: state.negotiationGeneration + 1,
      message: _negotiationMessage(negotiation),
      errorMessage: null,
    );
  }

  void _startOfferRefresh() {
    _offerRefreshTimer?.cancel();
    _offerRefreshTimer = Timer.periodic(
      _offerRefreshInterval,
      (_) => unawaited(refreshPeerOffer()),
    );
  }

  void _startPairingChallengeRefresh() {
    _pairingChallengeRefreshTimer?.cancel();
    _pairingChallengeRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_ensureFreshLocalPairingChallenge()),
    );
  }

  bool _singleDeviceConfirmationNegotiated(
    P2pPairingChallenge localChallenge,
    P2pPairingChallenge remoteChallenge,
  ) {
    return localChallenge.allowsSingleDeviceConfirmation &&
        remoteChallenge.allowsSingleDeviceConfirmation;
  }

  bool _persistentVerificationNegotiated(
    P2pPairingChallenge localChallenge,
    P2pPairingChallenge remoteChallenge,
  ) {
    return localChallenge.allowsPersistentVerification &&
        remoteChallenge.allowsPersistentVerification;
  }

  Future<P2pPairingChallenge?>
  _createLocalPairingChallengeFromSettings() async {
    if (state.localPairingChallenge != null) {
      return state.localPairingChallenge;
    }
    final activeCreation = _localPairingChallengeCreation;
    if (activeCreation != null) return activeCreation;
    final operation = _performCreateLocalPairingChallengeFromSettings();
    _localPairingChallengeCreation = operation;
    try {
      return await operation;
    } finally {
      if (identical(_localPairingChallengeCreation, operation)) {
        _localPairingChallengeCreation = null;
      }
    }
  }

  Future<P2pPairingChallenge?>
  _performCreateLocalPairingChallengeFromSettings() async {
    try {
      final settings = await ref.read(settingsStateProvider.future);
      if (_disposed || state.localPairingChallenge != null) {
        return state.localPairingChallenge;
      }
      final challenge = await _identityStore.createPairingChallenge(
        allowSingleDeviceConfirmation:
            settings.allowSingleDevicePairingConfirmation,
        allowPersistentVerification: settings.allowPersistentP2pVerification,
      );
      if (_disposed) return null;
      _endpointService.updateLocalPairingChallenge(challenge);
      _endpointService.updateLocalPairingConfirmation(null);
      state = state.copyWith(
        pairingStatus: P2pPairingStatus.waitingForPeer,
        localPairingChallenge: challenge,
        localPairingConfirmation: null,
        pairingCode: null,
        message: "已自動回應對方的安全配對要求，正在建立比較碼。",
        errorMessage: null,
      );
      _startPairingChallengeRefresh();
      return challenge;
    } catch (error) {
      if (!_disposed) {
        state = state.copyWith(
          pairingStatus: P2pPairingStatus.error,
          errorMessage: "無法自動建立本機 pairing challenge：${_describeError(error)}",
        );
      }
      return null;
    }
  }

  Future<P2pPairingChallenge?> _ensureFreshLocalPairingChallenge() async {
    final current = state.localPairingChallenge;
    if (current == null ||
        state.pairingStatus == P2pPairingStatus.mutuallyConfirmed) {
      return current;
    }
    final refreshAt = DateTime.now().toUtc().add(const Duration(minutes: 1));
    final refreshAtSeconds = refreshAt.millisecondsSinceEpoch ~/ 1000;
    if (current.expiresAtEpochSeconds > refreshAtSeconds) return current;
    try {
      final renewed = await _identityStore.createPairingChallenge(
        allowSingleDeviceConfirmation: current.allowsSingleDeviceConfirmation,
        allowPersistentVerification: current.allowsPersistentVerification,
      );
      _endpointService.updateLocalPairingChallenge(renewed);
      _endpointService.updateLocalPairingConfirmation(null);
      _clearAuthenticatedTransport();
      state = state.copyWith(
        pairingStatus: P2pPairingStatus.waitingForPeer,
        localPairingChallenge: renewed,
        remotePairingChallenge: null,
        localPairingConfirmation: null,
        remotePairingConfirmation: null,
        pairingCode: null,
        trustedPeer: null,
        message: "配對 challenge 已自動更新；等待對方取得新比較碼。",
        errorMessage: null,
      );
      return renewed;
    } catch (error) {
      state = state.copyWith(
        pairingStatus: P2pPairingStatus.error,
        errorMessage: "無法更新配對 challenge：${_describeError(error)}",
      );
      return null;
    }
  }

  Future<void> refreshPeerOffer() async {
    final endpoint = state.reachablePeer;
    if (endpoint == null ||
        !state.hasReachablePeer ||
        _offerRefreshInProgress) {
      return;
    }
    _offerRefreshInProgress = true;
    try {
      final remoteOffer = await _endpointService.negotiateProjectOffer(
        endpoint,
        state.localProjectOffer,
        timeout: _offerRefreshTimeout,
      );
      if (state.reachablePeer != endpoint || !state.hasReachablePeer) return;
      await _refreshPairingChallenge(endpoint);
      await _refreshPairingConfirmation(endpoint);
      final lastSummaryRefresh = _lastRevisionSummaryRefreshAt;
      if (state.hasAuthenticatedTransport &&
          (lastSummaryRefresh == null ||
              DateTime.now().toUtc().difference(lastSummaryRefresh) >=
                  const Duration(seconds: 3))) {
        await refreshRevisionSummary();
      }
      if (remoteOffer.disconnectRequested ||
          _isDifferentFromSession(remoteOffer, remoteSide: true)) {
        _disconnectForProjectChange(remoteChanged: true);
        return;
      }
      if (remoteOffer == state.remoteProjectOffer) return;
      final negotiation = P2pProjectNegotiationResult.evaluate(
        local: state.localProjectOffer,
        remote: remoteOffer,
      );
      _applyNegotiation(
        negotiation: negotiation,
        remoteOffer: remoteOffer,
        connectionStatus: P2pConnectionStatus.reachableUnpaired,
        reachablePeer: endpoint,
        inboundPeerAddress: null,
      );
    } catch (_) {
      // A foreground refresh is best-effort. The explicit connect action keeps
      // detailed network errors; a transient missed refresh is retried.
    } finally {
      _offerRefreshInProgress = false;
    }
  }

  Future<void> _refreshPairingChallenge(P2pEndpoint endpoint) async {
    final localChallenge = await _ensureFreshLocalPairingChallenge();
    if (localChallenge == null) return;
    try {
      final remote = await _endpointService.negotiatePairingChallenge(
        endpoint,
        localChallenge,
        timeout: _offerRefreshTimeout,
      );
      if (remote != null && state.reachablePeer == endpoint) {
        await _acceptRemotePairingChallenge(remote);
      }
    } catch (_) {
      // Pairing refresh is retried while the short-lived challenge is valid.
    }
  }

  Future<void> _refreshPairingConfirmation(P2pEndpoint endpoint) async {
    final localConfirmation = state.localPairingConfirmation;
    if (state.localPairingChallenge == null ||
        state.remotePairingChallenge == null) {
      return;
    }
    try {
      final remote = await _endpointService.negotiatePairingConfirmation(
        endpoint,
        localConfirmation,
        timeout: _offerRefreshTimeout,
      );
      if (remote != null && state.reachablePeer == endpoint) {
        await _acceptRemotePairingConfirmation(remote);
      }
    } catch (_) {
      // Confirmation delivery is retried while the peer session remains live.
    }
  }

  Future<void> _announceProjectChangeAndDisconnect(P2pEndpoint endpoint) async {
    try {
      await _endpointService.notifyDisconnect(
        endpoint,
        timeout: _offerRefreshTimeout,
      );
    } catch (_) {
      // Local safety does not depend on the peer acknowledging the notice.
    } finally {
      if (state.sessionProjectUuid != null) {
        _disconnectForProjectChange(remoteChanged: false);
      }
    }
  }

  void _disconnectForProjectChange({required bool remoteChanged}) {
    _offerRefreshTimer?.cancel();
    _offerRefreshTimer = null;
    _pairingChallengeRefreshTimer?.cancel();
    _pairingChallengeRefreshTimer = null;
    _endpointService.updateLocalPairingChallenge(null);
    _endpointService.updateLocalPairingConfirmation(null);
    _clearAuthenticatedTransport();
    ++_operationGeneration;
    state = state.copyWith(
      connectionStatus: P2pConnectionStatus.idle,
      reachablePeer: null,
      inboundPeerAddress: null,
      remoteProjectOffer: null,
      projectNegotiation: null,
      selectedProjectSource: null,
      sessionProjectUuid: null,
      pairingStatus: P2pPairingStatus.idle,
      localPairingChallenge: null,
      remotePairingChallenge: null,
      localPairingConfirmation: null,
      remotePairingConfirmation: null,
      pairingCode: null,
      trustedPeer: null,
      negotiationGeneration: state.negotiationGeneration + 1,
      message: remoteChanged ? "對方已更換同步文件，連線已中斷。" : "本機已更換同步文件，連線已中斷。",
      errorMessage: null,
    );
  }

  Future<void> initialize() async {
    if (_initialized && state.localIdentity != null) return;
    final activeInitialization = _initialization;
    if (activeInitialization != null) return activeInitialization;
    final operation = _performInitialize();
    _initialization = operation;
    try {
      await operation;
    } finally {
      if (identical(_initialization, operation)) _initialization = null;
    }
  }

  Future<void> _performInitialize() async {
    await refreshLocalAddresses();
    try {
      final identity = await _identityStore.loadOrCreateIdentity();
      if (_disposed) return;
      state = state.copyWith(localIdentity: identity);
      _initialized = true;
    } catch (error) {
      _initialized = false;
      state = state.copyWith(
        pairingStatus: P2pPairingStatus.error,
        errorMessage: "無法初始化裝置安全身分：${_describeError(error)}",
      );
    }
  }

  Future<void> handleAppResumed() async {
    if (!_initialized) {
      await initialize();
      return;
    }
    await refreshLocalAddresses();
    await _ensureFreshLocalPairingChallenge();
    if (state.reachablePeer != null && state.hasReachablePeer) {
      await refreshPeerOffer();
    }
  }

  Future<void> refreshLocalAddresses() async {
    try {
      final addresses = await _endpointService.listPrivateIpv4Addresses();
      state = state.copyWith(localAddresses: addresses, errorMessage: null);
    } catch (error) {
      state = state.copyWith(
        localAddresses: const <String>[],
        errorMessage: "無法取得本機 LAN IP：${_describeError(error)}",
      );
    }
  }

  Future<bool> startService(int port) async {
    if (!P2pEndpoint.isValidPort(port) || state.isServiceBusy) return false;
    if (state.isListening) return true;

    final generation = ++_operationGeneration;
    state = state.copyWith(
      serviceStatus: P2pServiceStatus.starting,
      configuredPort: port,
      listeningPort: null,
      message: "正在開啟本機服務…",
      errorMessage: null,
    );
    try {
      final hasLanAccess = await ref
          .read(p2pLanPermissionGatewayProvider)
          .ensureAccess();
      if (!hasLanAccess) throw const P2pLanPermissionDeniedException();
      await initialize();
      final endpoint = await _endpointService.start(port: port);
      if (generation != _operationGeneration) return false;
      state = state.copyWith(
        serviceStatus: P2pServiceStatus.listening,
        listeningPort: endpoint.port,
        message: "本機端點已開啟；完成安全配對後可交換加密 revision 與 snapshot chunks。",
        errorMessage: null,
      );
      await refreshLocalAddresses();
      return true;
    } catch (error) {
      if (generation != _operationGeneration) return false;
      state = state.copyWith(
        serviceStatus: P2pServiceStatus.error,
        listeningPort: null,
        message: null,
        errorMessage: "無法開啟 Port $port：${_describeError(error)}",
      );
      return false;
    }
  }

  Future<void> stopService() async {
    if (state.serviceStatus == P2pServiceStatus.stopped ||
        state.serviceStatus == P2pServiceStatus.stopping) {
      return;
    }
    ++_operationGeneration;
    _offerRefreshTimer?.cancel();
    _offerRefreshTimer = null;
    _pairingChallengeRefreshTimer?.cancel();
    _pairingChallengeRefreshTimer = null;
    _endpointService.updateLocalPairingChallenge(null);
    _endpointService.updateLocalPairingConfirmation(null);
    _clearAuthenticatedTransport();
    state = state.copyWith(
      serviceStatus: P2pServiceStatus.stopping,
      message: "正在停止本機服務…",
      errorMessage: null,
    );
    try {
      await _endpointService.stop();
      state = state.copyWith(
        serviceStatus: P2pServiceStatus.stopped,
        connectionStatus: P2pConnectionStatus.idle,
        listeningPort: null,
        reachablePeer: null,
        inboundPeerAddress: null,
        remoteProjectOffer: null,
        projectNegotiation: null,
        selectedProjectSource: null,
        sessionProjectUuid: null,
        pairingStatus: P2pPairingStatus.idle,
        localPairingChallenge: null,
        remotePairingChallenge: null,
        localPairingConfirmation: null,
        remotePairingConfirmation: null,
        pairingCode: null,
        trustedPeer: null,
        negotiationGeneration: state.negotiationGeneration + 1,
        message: "本機服務已停止。",
        errorMessage: null,
      );
    } catch (error) {
      state = state.copyWith(
        serviceStatus: P2pServiceStatus.error,
        listeningPort: null,
        message: null,
        errorMessage: "停止本機服務失敗：${_describeError(error)}",
      );
    }
  }

  Future<bool> probePeer(P2pEndpoint endpoint) async {
    if (state.isConnecting) return false;
    final generation = ++_operationGeneration;
    state = state.copyWith(
      connectionStatus: P2pConnectionStatus.connecting,
      reachablePeer: null,
      inboundPeerAddress: null,
      message: "正在測試 ${endpoint.host}:${endpoint.port}…",
      errorMessage: null,
    );
    try {
      final hasLanAccess = await ref
          .read(p2pLanPermissionGatewayProvider)
          .ensureAccess();
      if (!hasLanAccess) throw const P2pLanPermissionDeniedException();
      await _endpointService.probe(endpoint);
      if (generation != _operationGeneration) return false;
      state = state.copyWith(
        connectionStatus: P2pConnectionStatus.reachableUnpaired,
        reachablePeer: endpoint,
        inboundPeerAddress: null,
        message: "端點可達；完成安全配對後才會啟用加密內容通道。",
        errorMessage: null,
      );
      return true;
    } catch (error) {
      if (generation != _operationGeneration) return false;
      state = state.copyWith(
        connectionStatus: P2pConnectionStatus.error,
        reachablePeer: null,
        message: null,
        errorMessage: "無法連線至 $endpoint：${_describeError(error)}",
      );
      return false;
    }
  }

  Future<bool> connectAndNegotiate(
    P2pEndpoint endpoint,
    P2pProjectStatus? localStatus,
  ) async {
    if (state.isConnecting) return false;
    _pairingChallengeRefreshTimer?.cancel();
    _pairingChallengeRefreshTimer = null;
    _endpointService.updateLocalPairingChallenge(null);
    _endpointService.updateLocalPairingConfirmation(null);
    _clearAuthenticatedTransport();
    updateLocalProjectStatus(localStatus);
    final generation = ++_operationGeneration;
    state = state.copyWith(
      connectionStatus: P2pConnectionStatus.connecting,
      reachablePeer: null,
      inboundPeerAddress: null,
      remoteProjectOffer: null,
      projectNegotiation: null,
      selectedProjectSource: null,
      sessionProjectUuid: null,
      pairingStatus: P2pPairingStatus.idle,
      localPairingChallenge: null,
      remotePairingChallenge: null,
      localPairingConfirmation: null,
      remotePairingConfirmation: null,
      pairingCode: null,
      trustedPeer: null,
      message: "正在連線並協商同步文件 ${endpoint.host}:${endpoint.port}…",
      errorMessage: null,
    );
    try {
      final hasLanAccess = await ref
          .read(p2pLanPermissionGatewayProvider)
          .ensureAccess();
      if (!hasLanAccess) throw const P2pLanPermissionDeniedException();
      final remoteOffer = await _endpointService.negotiateProjectOffer(
        endpoint,
        state.localProjectOffer,
      );
      if (generation != _operationGeneration) return false;
      if (remoteOffer.disconnectRequested) {
        _disconnectForProjectChange(remoteChanged: true);
        return false;
      }
      final negotiation = P2pProjectNegotiationResult.evaluate(
        local: state.localProjectOffer,
        remote: remoteOffer,
      );
      _applyNegotiation(
        negotiation: negotiation,
        remoteOffer: remoteOffer,
        connectionStatus: P2pConnectionStatus.reachableUnpaired,
        reachablePeer: endpoint,
        inboundPeerAddress: null,
      );
      _startOfferRefresh();
      return true;
    } catch (error) {
      if (generation != _operationGeneration) return false;
      state = state.copyWith(
        connectionStatus: P2pConnectionStatus.error,
        reachablePeer: null,
        remoteProjectOffer: null,
        projectNegotiation: null,
        selectedProjectSource: null,
        sessionProjectUuid: null,
        message: null,
        errorMessage: "無法連線至 $endpoint：${_describeError(error)}",
      );
      return false;
    }
  }

  void selectProjectSource(P2pProjectSource source) {
    final negotiation = state.projectNegotiation;
    final remoteOffer = state.remoteProjectOffer;
    if (negotiation == null || remoteOffer == null) return;
    if (source == P2pProjectSource.local &&
        !state.localProjectOffer.hasProject) {
      return;
    }
    if (source == P2pProjectSource.remote && !remoteOffer.hasProject) return;
    final sessionProjectUuid = source == P2pProjectSource.local
        ? state.localProjectOffer.projectUuid
        : remoteOffer.projectUuid;
    state = state.copyWith(
      selectedProjectSource: source,
      sessionProjectUuid: sessionProjectUuid,
      message: source == P2pProjectSource.local
          ? "已選擇由本機提供同步文件。"
          : "已選擇由對方提供同步文件。",
      errorMessage: null,
    );
    if (state.hasAuthenticatedTransport) {
      unawaited(refreshRevisionSummary());
    }
  }

  P2pRevisionGraph? _effectiveLocalRevisionGraph() {
    final graph = state.localRevisionGraph;
    if (graph != null) return graph;
    final sessionUuid = state.sessionProjectUuid;
    final isReceivingInitialProject =
        sessionUuid != null &&
        !state.localProjectOffer.hasProject &&
        state.selectedProjectSource == P2pProjectSource.remote;
    return isReceivingInitialProject
        ? P2pRevisionGraph.empty(sessionUuid)
        : null;
  }

  void disconnectPeer() {
    ++_operationGeneration;
    _offerRefreshTimer?.cancel();
    _offerRefreshTimer = null;
    _pairingChallengeRefreshTimer?.cancel();
    _pairingChallengeRefreshTimer = null;
    _endpointService.updateLocalPairingChallenge(null);
    _endpointService.updateLocalPairingConfirmation(null);
    _clearAuthenticatedTransport();
    final endpoint = state.reachablePeer;
    if (endpoint != null) {
      unawaited(_notifyDisconnectBestEffort(endpoint));
    } else if (state.hasReachablePeer) {
      _endpointService.requestDisconnectOnNextExchange();
    }
    state = state.copyWith(
      connectionStatus: P2pConnectionStatus.idle,
      reachablePeer: null,
      inboundPeerAddress: null,
      remoteProjectOffer: null,
      projectNegotiation: null,
      selectedProjectSource: null,
      sessionProjectUuid: null,
      pairingStatus: P2pPairingStatus.idle,
      localPairingChallenge: null,
      remotePairingChallenge: null,
      localPairingConfirmation: null,
      remotePairingConfirmation: null,
      pairingCode: null,
      trustedPeer: null,
      negotiationGeneration: state.negotiationGeneration + 1,
      message: state.isListening ? "已中斷目前 peer；本機服務仍在監聽。" : "已中斷目前 peer。",
      errorMessage: null,
    );
  }

  Future<void> _notifyDisconnectBestEffort(P2pEndpoint endpoint) async {
    try {
      await _endpointService.notifyDisconnect(
        endpoint,
        timeout: _offerRefreshTimeout,
      );
    } catch (_) {
      // Manual/local disconnect must remain safe when the peer is unavailable.
    }
  }

  String _negotiationMessage(P2pProjectNegotiationResult negotiation) {
    return switch (negotiation.kind) {
      P2pProjectNegotiationKind.sameProject => "雙方 UUID 相同，已選定同一份同步文件。",
      P2pProjectNegotiationKind.localProvides => "對方沒有目標文件，將由本機提供文件。",
      P2pProjectNegotiationKind.remoteProvides => "本機沒有目標文件，將由對方提供文件。",
      P2pProjectNegotiationKind.selectionRequired =>
        negotiation.selectionReason == P2pProjectSelectionReason.bothMissing
            ? "雙方都沒有可同步文件，需要先決定文件。"
            : "雙方文件 UUID 不同，需要選擇同步文件。",
    };
  }

  String _describeError(Object error) {
    final value = error.toString().trim();
    return value.isEmpty ? "未知錯誤" : value;
  }
}

final p2pSyncProvider = NotifierProvider<P2pSyncNotifier, P2pSyncState>(
  P2pSyncNotifier.new,
);

enum P2pSnapshotTransferStatus {
  idle,
  downloading,
  verified,
  applying,
  applied,
  failed,
  cancelled,
}

class P2pSnapshotTransferState {
  final P2pSnapshotTransferStatus status;
  final P2pSnapshotManifest? manifest;
  final P2pVerifiedSnapshot? verifiedSnapshot;
  final String? message;
  final String? errorMessage;

  const P2pSnapshotTransferState({
    this.status = P2pSnapshotTransferStatus.idle,
    this.manifest,
    this.verifiedSnapshot,
    this.message,
    this.errorMessage,
  });

  bool get isBusy =>
      status == P2pSnapshotTransferStatus.downloading ||
      status == P2pSnapshotTransferStatus.applying;

  bool get hasVerifiedSnapshot => verifiedSnapshot != null;
}

class P2pSnapshotTransferNotifier extends Notifier<P2pSnapshotTransferState> {
  int _generation = 0;
  bool _disposed = false;
  _P2pSnapshotTransferAuthorization? _authorization;

  P2pSnapshotDownloadCoordinator get _coordinator =>
      ref.read(p2pSnapshotDownloadCoordinatorProvider);

  @override
  P2pSnapshotTransferState build() {
    ref.listen<P2pSyncState>(p2pSyncProvider, (previous, next) {
      final authorization = _authorization;
      if (authorization != null &&
          state.status != P2pSnapshotTransferStatus.applying &&
          !authorization.matches(next)) {
        unawaited(_invalidateForSessionChange());
      } else if (authorization == null &&
          state.status == P2pSnapshotTransferStatus.applied &&
          !_appliedSnapshotIsCurrent(next)) {
        state = const P2pSnapshotTransferState();
      } else if (authorization == null &&
          state.status == P2pSnapshotTransferStatus.failed &&
          state.manifest == null &&
          (next.canDownloadRemoteSnapshot ||
              ((next.revisionSummaryRelation ==
                          P2pRevisionSummaryRelation.localAhead ||
                      next.revisionSummaryRelation ==
                          P2pRevisionSummaryRelation.equal) &&
                  previous?.revisionSummaryRelation !=
                      next.revisionSummaryRelation))) {
        // An early tap can fail before the summary's verified manifest is
        // installed. The same failure is also stale when this peer is now the
        // provider (or already equal), because a remote download is no longer
        // the requested operation. Failures tied to a concrete manifest
        // (chunk/hash/XML errors) remain visible.
        state = const P2pSnapshotTransferState();
      }
    });
    ref.onDispose(() {
      _disposed = true;
      ++_generation;
    });
    return const P2pSnapshotTransferState();
  }

  bool _appliedSnapshotIsCurrent(P2pSyncState syncState) {
    final appliedManifest = state.manifest;
    return appliedManifest != null &&
        syncState.hasAuthenticatedTransport &&
        syncState.sessionProjectUuid == appliedManifest.projectUuid &&
        syncState.localSnapshotManifest == appliedManifest &&
        syncState.remoteSnapshotManifest == appliedManifest &&
        syncState.revisionSummaryRelation == P2pRevisionSummaryRelation.equal;
  }

  Future<bool> downloadRemoteSnapshot() async {
    if (state.isBusy) return false;
    final syncState = ref.read(p2pSyncProvider);
    final authorization = _P2pSnapshotTransferAuthorization.tryCreate(
      syncState,
    );
    if (authorization == null) {
      state = const P2pSnapshotTransferState(
        status: P2pSnapshotTransferStatus.failed,
        errorMessage: "目前沒有可在已驗證連線中下載的遠端 snapshot。",
      );
      return false;
    }

    final generation = ++_generation;
    _authorization = authorization;
    state = P2pSnapshotTransferState(
      status: P2pSnapshotTransferStatus.downloading,
      manifest: authorization.manifest,
      message: "正在透過 authenticated encrypted transport 重建或下載並驗證 snapshot…",
    );
    try {
      final deltaVerified = await ref
          .read(p2pSyncProvider.notifier)
          .materializeRemoteDelta(authorization.manifest);
      final verified =
          deltaVerified ?? await _coordinator.download(authorization.manifest);
      if (_disposed ||
          generation != _generation ||
          !authorization.matches(ref.read(p2pSyncProvider))) {
        await _coordinator.cancel();
        return false;
      }
      state = P2pSnapshotTransferState(
        status: P2pSnapshotTransferStatus.verified,
        manifest: authorization.manifest,
        verifiedSnapshot: verified,
        message: deltaVerified == null
            ? "snapshot 已完成 chunk、SHA-256、XML、UUID 與版本驗證；尚未寫入專案。"
            : "snapshot 已由加密 delta 重建，並完成 SHA-256、XML、UUID 與版本驗證；尚未寫入專案。",
      );
      return true;
    } on P2pSnapshotDownloadCancelledException {
      if (!_disposed && generation == _generation) {
        state = P2pSnapshotTransferState(
          status: P2pSnapshotTransferStatus.cancelled,
          manifest: authorization.manifest,
          message: "snapshot 下載已取消。",
        );
      }
      return false;
    } catch (error) {
      if (!_disposed && generation == _generation) {
        state = P2pSnapshotTransferState(
          status: P2pSnapshotTransferStatus.failed,
          manifest: authorization.manifest,
          errorMessage: "snapshot 下載或驗證失敗：${_describeError(error)}",
        );
      }
      return false;
    }
  }

  Future<bool> applyVerifiedSnapshot(
    Future<bool> Function(P2pVerifiedSnapshot snapshot) apply,
  ) async {
    if (state.isBusy) return false;
    final verified = state.verifiedSnapshot;
    final authorization = _authorization;
    if (ref.read(p2pSyncProvider).revisionSummaryRelation ==
        P2pRevisionSummaryRelation.concurrent) {
      state = P2pSnapshotTransferState(
        status: P2pSnapshotTransferStatus.verified,
        manifest: verified?.manifest,
        verifiedSnapshot: verified,
        errorMessage:
            "雙方 revisions concurrent；必須完成逐欄 conflict resolution，不能直接覆寫本機文件。",
      );
      return false;
    }
    if (verified == null ||
        authorization == null ||
        verified.manifest != authorization.manifest ||
        !authorization.matches(ref.read(p2pSyncProvider))) {
      state = const P2pSnapshotTransferState(
        status: P2pSnapshotTransferStatus.failed,
        errorMessage: "已驗證 snapshot 已失效；請重新建立安全連線後下載。",
      );
      return false;
    }

    var syncState = ref.read(p2pSyncProvider);
    var remoteGraph = syncState.remoteRevisionGraph;
    if (remoteGraph == null ||
        remoteGraph.projectUuid != authorization.projectUuid ||
        remoteGraph.revisions[verified.manifest.revisionId] == null) {
      await ref.read(p2pSyncProvider.notifier).refreshRevisionGraph();
      if (_disposed) return false;
      syncState = ref.read(p2pSyncProvider);
      remoteGraph = syncState.remoteRevisionGraph;
    }
    if (!authorization.matches(syncState) ||
        remoteGraph == null ||
        remoteGraph.projectUuid != authorization.projectUuid ||
        remoteGraph.revisions[verified.manifest.revisionId] == null) {
      state = P2pSnapshotTransferState(
        status: P2pSnapshotTransferStatus.failed,
        manifest: verified.manifest,
        verifiedSnapshot: verified,
        errorMessage: "尚未取得包含此 snapshot 的已驗證 revision graph；未寫入專案。",
      );
      return false;
    }
    final transferAuthorization = ref
        .read(p2pSnapshotTransferSessionProvider)
        .current;
    final expectedPeerDeviceId = syncState.trustedPeer?.deviceId;
    if (transferAuthorization == null ||
        expectedPeerDeviceId == null ||
        transferAuthorization.endpoint != authorization.endpoint ||
        transferAuthorization.projectUuid != authorization.projectUuid ||
        transferAuthorization.remoteManifest != authorization.manifest) {
      state = P2pSnapshotTransferState(
        status: P2pSnapshotTransferStatus.failed,
        manifest: verified.manifest,
        verifiedSnapshot: verified,
        errorMessage: "authenticated snapshot session capability 不存在；未寫入專案。",
      );
      return false;
    }

    final generation = ++_generation;
    state = P2pSnapshotTransferState(
      status: P2pSnapshotTransferStatus.applying,
      manifest: verified.manifest,
      verifiedSnapshot: verified,
      message: "等待確認儲存位置並安全開啟 snapshot…",
    );
    try {
      final applied = await apply(verified);
      if (_disposed || generation != _generation) return false;
      if (!authorization.matches(ref.read(p2pSyncProvider))) {
        state = P2pSnapshotTransferState(
          status: P2pSnapshotTransferStatus.cancelled,
          manifest: verified.manifest,
          message: "同步 session 已變更；已停止將 snapshot 套用至編輯器。",
        );
        return false;
      }
      if (applied) {
        final historyInstalled = await ref
            .read(p2pSyncProvider.notifier)
            .installAppliedRemoteSnapshot(
              verified,
              verifiedRemoteGraph: remoteGraph,
              transferAuthorization: transferAuthorization,
              expectedPeerDeviceId: expectedPeerDeviceId,
            );
        if (_disposed || generation != _generation) return false;
        if (!historyInstalled) {
          state = P2pSnapshotTransferState(
            status: P2pSnapshotTransferStatus.failed,
            manifest: verified.manifest,
            verifiedSnapshot: verified,
            errorMessage: "snapshot 已另存並開啟，但遠端 revision 歷史尚未保存；請勿繼續編輯並重試同步。",
          );
          return false;
        }
        _authorization = null;
      }
      state = P2pSnapshotTransferState(
        status: applied
            ? P2pSnapshotTransferStatus.applied
            : P2pSnapshotTransferStatus.verified,
        manifest: verified.manifest,
        verifiedSnapshot: applied ? null : verified,
        message: applied ? "遠端 snapshot 已另存並開啟。" : "已取消套用；驗證結果仍保留在記憶體中。",
      );
      return applied;
    } catch (error) {
      if (!_disposed && generation == _generation) {
        state = P2pSnapshotTransferState(
          status: P2pSnapshotTransferStatus.failed,
          manifest: verified.manifest,
          verifiedSnapshot: verified,
          errorMessage: "無法儲存或開啟 snapshot：${_describeError(error)}",
        );
      }
      return false;
    }
  }

  void completeConcurrentResolution(P2pVerifiedSnapshot snapshot) {
    if (state.verifiedSnapshot != snapshot) return;
    ++_generation;
    _authorization = null;
    state = P2pSnapshotTransferState(
      status: P2pSnapshotTransferStatus.applied,
      manifest: snapshot.manifest,
      message: "concurrent snapshot 已完成逐欄合併並建立 resolve revision。",
    );
  }

  Future<void> cancel() async {
    ++_generation;
    _authorization = null;
    await _coordinator.cancel();
    if (_disposed) return;
    state = const P2pSnapshotTransferState(
      status: P2pSnapshotTransferStatus.cancelled,
      message: "snapshot 傳輸已取消。",
    );
  }

  Future<void> _invalidateForSessionChange() async {
    if (_authorization == null) return;
    ++_generation;
    _authorization = null;
    await _coordinator.cancel();
    if (_disposed) return;
    state = const P2pSnapshotTransferState(
      status: P2pSnapshotTransferStatus.cancelled,
      message: "連線、文件或 revision 已變更；舊 snapshot 已失效。",
    );
  }

  String _describeError(Object error) {
    final value = error.toString().trim();
    return value.isEmpty ? "未知錯誤" : value;
  }
}

class _P2pSnapshotTransferAuthorization {
  final P2pEndpoint endpoint;
  final String projectUuid;
  final String peerDeviceId;
  final P2pSnapshotManifest manifest;

  const _P2pSnapshotTransferAuthorization({
    required this.endpoint,
    required this.projectUuid,
    required this.peerDeviceId,
    required this.manifest,
  });

  static _P2pSnapshotTransferAuthorization? tryCreate(P2pSyncState state) {
    final endpoint = state.reachablePeer;
    final projectUuid = state.sessionProjectUuid;
    final peerDeviceId = state.trustedPeer?.deviceId;
    final manifest = state.remoteSnapshotManifest;
    final canDownload = state.canDownloadRemoteSnapshot;
    if (!canDownload ||
        endpoint == null ||
        projectUuid == null ||
        peerDeviceId == null ||
        manifest == null) {
      return null;
    }
    return _P2pSnapshotTransferAuthorization(
      endpoint: endpoint,
      projectUuid: projectUuid,
      peerDeviceId: peerDeviceId,
      manifest: manifest,
    );
  }

  bool matches(P2pSyncState state) {
    return state.hasAuthenticatedTransport &&
        state.reachablePeer == endpoint &&
        state.sessionProjectUuid == projectUuid &&
        state.trustedPeer?.deviceId == peerDeviceId &&
        state.remoteSnapshotManifest == manifest &&
        state.snapshotManifestStatus == P2pSnapshotManifestStatus.available &&
        (state.revisionSummaryRelation ==
                P2pRevisionSummaryRelation.remoteAhead ||
            state.revisionSummaryRelation ==
                P2pRevisionSummaryRelation.concurrent);
  }
}

final p2pSnapshotTransferProvider =
    NotifierProvider<P2pSnapshotTransferNotifier, P2pSnapshotTransferState>(
      P2pSnapshotTransferNotifier.new,
    );
