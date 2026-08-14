import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";
import "dart:typed_data";

import "package:cryptography/cryptography.dart";

import "../../domain/models/p2p_pairing_models.dart";
import "../../domain/models/p2p_revision_models.dart";
import "../../domain/models/p2p_resolution_models.dart";
import "../../domain/models/p2p_snapshot_models.dart";
import "../../domain/models/p2p_sync_models.dart";
import "p2p_android_probe_gateway.dart";
import "p2p_secure_channel.dart";

class P2pListeningEndpoint {
  final int port;

  const P2pListeningEndpoint({required this.port});
}

class P2pInboundProbe {
  final String remoteAddress;

  const P2pInboundProbe({required this.remoteAddress});
}

class P2pInboundProjectOffer {
  final String remoteAddress;
  final P2pProjectOffer offer;

  const P2pInboundProjectOffer({
    required this.remoteAddress,
    required this.offer,
  });
}

class P2pInboundPairingChallenge {
  final String remoteAddress;
  final P2pPairingChallenge challenge;

  const P2pInboundPairingChallenge({
    required this.remoteAddress,
    required this.challenge,
  });
}

class P2pInboundPairingConfirmation {
  final String remoteAddress;
  final P2pPairingConfirmation confirmation;

  const P2pInboundPairingConfirmation({
    required this.remoteAddress,
    required this.confirmation,
  });
}

class P2pInboundRevisionSummary {
  final String remoteAddress;
  final int? remoteServicePort;
  final P2pRevisionSummary summary;
  final P2pSnapshotManifest? headManifest;
  final P2pSnapshotSyncRequest? syncRequest;
  final P2pResolutionAck? resolutionAck;

  const P2pInboundRevisionSummary({
    required this.remoteAddress,
    this.remoteServicePort,
    required this.summary,
    this.headManifest,
    this.syncRequest,
    this.resolutionAck,
  });
}

class P2pInboundRevisionGraph {
  final String remoteAddress;
  final String transferId;
  final P2pRevisionGraph graph;

  const P2pInboundRevisionGraph({
    required this.remoteAddress,
    required this.transferId,
    required this.graph,
  });
}

class P2pRevisionSummaryExchange {
  final P2pRevisionSummary summary;
  final int? remoteServicePort;
  final P2pSnapshotManifest? headManifest;
  final P2pSnapshotSyncRequest? syncRequest;
  final P2pResolutionAck? resolutionAck;

  const P2pRevisionSummaryExchange({
    required this.summary,
    this.remoteServicePort,
    this.headManifest,
    this.syncRequest,
    this.resolutionAck,
  });
}

class P2pRevisionGraphPageExchange {
  final int acknowledgedLocalPageIndex;
  final P2pRevisionGraphPage remotePage;

  const P2pRevisionGraphPageExchange({
    required this.acknowledgedLocalPageIndex,
    required this.remotePage,
  });
}

enum P2pProbeFailureStage { connect, response }

class P2pProbeException implements Exception {
  final P2pProbeFailureStage stage;
  final Object cause;

  const P2pProbeException({required this.stage, required this.cause});

  @override
  String toString() {
    final platformDetail = cause is P2pAndroidProbeException
        ? " ${(cause as P2pAndroidProbeException).message}"
        : "";
    return switch (stage) {
      P2pProbeFailureStage.connect =>
        "TCP 連線逾時或無法建立。$platformDetail 請確認兩台裝置連到同一個 Wi-Fi、對方已開啟服務，並使用對方的 Wi-Fi IPv4；若對方是 Windows，請允許物語 Assistant 通過目前網路類型的防火牆。",
      P2pProbeFailureStage.response =>
        "TCP 已建立，但對方沒有及時回覆 P2P probe。$platformDetail 請確認 Port 正確，且雙方都是相容版本。",
    };
  }
}

/// LAN endpoint abstraction with a strict authenticated transport boundary.
///
/// Project identity offers and pairing frames remain bounded pre-auth messages.
/// Revision summaries are available only after [installAuthenticatedSession]
/// and are always wrapped in an authenticated encrypted frame.
abstract class P2pEndpointService {
  Stream<P2pInboundProbe> get inboundProbes;
  Stream<P2pInboundProjectOffer> get inboundProjectOffers;
  Stream<P2pInboundPairingChallenge> get inboundPairingChallenges;
  Stream<P2pInboundPairingConfirmation> get inboundPairingConfirmations;
  Stream<P2pInboundRevisionSummary> get inboundRevisionSummaries;
  Stream<P2pInboundRevisionGraph> get inboundRevisionGraphs;

  void updateLocalProjectOffer(P2pProjectOffer offer);

  void requestDisconnectOnNextExchange();

  void updateLocalPairingChallenge(P2pPairingChallenge? challenge);

  void updateLocalPairingConfirmation(P2pPairingConfirmation? confirmation);

  void installAuthenticatedSession(P2pSecureSessionKeys? keys);

  void updateLocalRevisionSummary(P2pRevisionSummary? summary);

  void updateLocalRevisionGraph(P2pRevisionGraph? graph);

  void updateLocalResolutionAck(P2pResolutionAck? ack);

  void updateLocalSnapshotManifests(Iterable<P2pSnapshotManifest> manifests);

  void updateLocalSnapshotSyncRequest(P2pSnapshotSyncRequest? request);

  void configureSnapshotContentTransfer({
    required bool enabled,
    P2pSnapshotChunkLoader? loader,
  });

  Future<List<String>> listPrivateIpv4Addresses();

  Future<P2pListeningEndpoint> start({required int port});

  Future<void> stop();

  Future<void> probe(
    P2pEndpoint endpoint, {
    Duration timeout = const Duration(seconds: 8),
  });

  Future<P2pProjectOffer> negotiateProjectOffer(
    P2pEndpoint endpoint,
    P2pProjectOffer localOffer, {
    Duration timeout = const Duration(seconds: 8),
  });

  Future<void> notifyDisconnect(
    P2pEndpoint endpoint, {
    Duration timeout = const Duration(seconds: 3),
  });

  Future<P2pPairingChallenge?> negotiatePairingChallenge(
    P2pEndpoint endpoint,
    P2pPairingChallenge localChallenge, {
    Duration timeout = const Duration(seconds: 3),
  });

  Future<P2pPairingConfirmation?> negotiatePairingConfirmation(
    P2pEndpoint endpoint,
    P2pPairingConfirmation? localConfirmation, {
    Duration timeout = const Duration(seconds: 3),
  });

  Future<P2pRevisionSummaryExchange> negotiateRevisionSummary(
    P2pEndpoint endpoint,
    P2pRevisionSummary localSummary, {
    Duration timeout = const Duration(seconds: 5),
  });

  Future<P2pRevisionGraphPageExchange> negotiateRevisionGraphPage(
    P2pEndpoint endpoint, {
    required int localPageIndex,
    required int remotePageIndex,
    Duration timeout = const Duration(seconds: 8),
  });

  Future<P2pSnapshotManifest?> negotiateSnapshotManifest(
    P2pEndpoint endpoint, {
    required String projectUuid,
    required String revisionId,
    Duration timeout = const Duration(seconds: 5),
  });

  Future<P2pSnapshotChunk?> negotiateSnapshotChunk(
    P2pEndpoint endpoint,
    P2pSnapshotChunkRequest request, {
    Duration timeout = const Duration(seconds: 12),
  });

  Future<List<P2pSnapshotChunk?>> negotiateSnapshotChunks(
    P2pEndpoint endpoint,
    List<P2pSnapshotChunkRequest> requests, {
    Duration timeout = const Duration(seconds: 12),
  });

  Future<void> dispose();
}

class IoP2pEndpointService implements P2pEndpointService {
  static const String _probeRequest = "MONOGATARI_P2P_PROBE/1\n";
  static const String _probeResponse = "MONOGATARI_P2P_REACHABLE/1\n";
  static const String _offerPrefix = "MONOGATARI_P2P_OFFER/2 ";
  static const String _pairingPrefix = "MONOGATARI_P2P_PAIR/7 ";
  static const String _pairingConfirmationPrefix =
      "MONOGATARI_P2P_PAIR_CONFIRM/7 ";
  static const String _secureFramePrefix = "MONOGATARI_P2P_SECURE/1 ";
  static const int _maxProbeBytes = 128;
  static const int _maxOfferBytes = 2048;
  static const int _maxSecureFrameBytes = P2pEncryptedFrame.maxEncodedLength;
  static const Duration _probeReadTimeout = Duration(seconds: 8);
  static const Duration _gracefulCloseTimeout = Duration(seconds: 2);

  ServerSocket? _server;
  StreamSubscription<Socket>? _connectionSubscription;
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
  final P2pAndroidProbeGateway _androidProbeGateway;
  P2pProjectOffer _localProjectOffer = const P2pProjectOffer.none();
  bool _disconnectOnNextExchange = false;
  P2pPairingChallenge? _localPairingChallenge;
  P2pPairingConfirmation? _localPairingConfirmation;
  P2pRevisionSummary? _localRevisionSummary;
  P2pRevisionGraph? _localRevisionGraph;
  P2pResolutionAck? _localResolutionAck;
  final Map<String, P2pRevisionGraphAssembler> _inboundGraphAssemblers =
      <String, P2pRevisionGraphAssembler>{};
  final Set<String> _completedInboundGraphTransfers = <String>{};
  Map<String, P2pSnapshotManifest> _localSnapshotManifests =
      const <String, P2pSnapshotManifest>{};
  P2pSnapshotSyncRequest? _localSnapshotSyncRequest;
  bool _snapshotContentTransferEnabled = false;
  P2pSnapshotChunkLoader? _snapshotChunkLoader;
  P2pSecureChannel? _secureChannel;
  final Random _secureRandom = Random.secure();

  IoP2pEndpointService({P2pAndroidProbeGateway? androidProbeGateway})
    : _androidProbeGateway =
          androidProbeGateway ?? MethodChannelP2pAndroidProbeGateway();

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
  void updateLocalProjectOffer(P2pProjectOffer offer) {
    _localProjectOffer = offer;
  }

  @override
  void requestDisconnectOnNextExchange() {
    _disconnectOnNextExchange = true;
  }

  @override
  void updateLocalPairingChallenge(P2pPairingChallenge? challenge) {
    _localPairingChallenge = challenge;
  }

  @override
  void updateLocalPairingConfirmation(P2pPairingConfirmation? confirmation) {
    _localPairingConfirmation = confirmation;
  }

  @override
  void installAuthenticatedSession(P2pSecureSessionKeys? keys) {
    _secureChannel?.destroy();
    _secureChannel = keys == null ? null : P2pSecureChannel(keys);
    _snapshotContentTransferEnabled = false;
    _snapshotChunkLoader = null;
    if (keys == null) _localSnapshotSyncRequest = null;
    _inboundGraphAssemblers.clear();
    _completedInboundGraphTransfers.clear();
  }

  @override
  void updateLocalRevisionSummary(P2pRevisionSummary? summary) {
    _localRevisionSummary = summary;
  }

  @override
  void updateLocalRevisionGraph(P2pRevisionGraph? graph) {
    _localRevisionGraph = graph;
    final ack = _localResolutionAck;
    final revision = ack == null
        ? null
        : graph?.revisions[ack.resolutionRevisionId];
    if (graph == null ||
        (ack != null && (revision == null || !ack.matchesRevision(revision)))) {
      _localResolutionAck = null;
    }
  }

  @override
  void updateLocalResolutionAck(P2pResolutionAck? ack) {
    if (ack != null) {
      final revision = _localRevisionGraph?.revisions[ack.resolutionRevisionId];
      if (revision == null || !ack.matchesRevision(revision)) {
        throw const FormatException("P2P resolution ACK 與本機 graph 不一致。");
      }
    }
    _localResolutionAck = ack;
  }

  @override
  void updateLocalSnapshotManifests(Iterable<P2pSnapshotManifest> manifests) {
    final indexed = <String, P2pSnapshotManifest>{};
    for (final manifest in manifests) {
      if (indexed.containsKey(manifest.revisionId)) {
        throw const FormatException(
          "P2P snapshot manifests 不可有重複 revision ID。",
        );
      }
      indexed[manifest.revisionId] = manifest;
    }
    _localSnapshotManifests = Map.unmodifiable(indexed);
    final syncRequest = _localSnapshotSyncRequest;
    if (syncRequest != null && !indexed.values.any(syncRequest.matches)) {
      _localSnapshotSyncRequest = null;
    }
  }

  @override
  void updateLocalSnapshotSyncRequest(P2pSnapshotSyncRequest? request) {
    if (request != null &&
        !_localSnapshotManifests.values.any(request.matches)) {
      throw const FormatException("P2P snapshot 同步要求必須對應本機已宣告的 manifest。");
    }
    _localSnapshotSyncRequest = request;
  }

  @override
  void configureSnapshotContentTransfer({
    required bool enabled,
    P2pSnapshotChunkLoader? loader,
  }) {
    if (enabled && loader == null) throw ArgumentError.notNull("loader");
    _snapshotContentTransferEnabled = enabled;
    _snapshotChunkLoader = enabled ? loader : null;
  }

  @override
  Future<List<String>> listPrivateIpv4Addresses() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      includeLinkLocal: false,
      type: InternetAddressType.IPv4,
    );
    final addresses = <String>{};
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (P2pEndpoint.isPrivateIpv4(address.address)) {
          addresses.add(address.address);
        }
      }
    }
    final result = addresses.toList()..sort();
    return List.unmodifiable(result);
  }

  @override
  Future<P2pListeningEndpoint> start({required int port}) async {
    if (!P2pEndpoint.isValidPort(port)) {
      throw const FormatException("Port 必須介於 1–65535。");
    }
    if (_server != null) {
      return P2pListeningEndpoint(port: _server!.port);
    }

    final server = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      port,
      shared: false,
    );
    _server = server;
    _connectionSubscription = server.listen(
      (socket) {
        unawaited(_handleProbe(socket));
      },
      onError: (_) {},
      cancelOnError: false,
    );
    return P2pListeningEndpoint(port: server.port);
  }

  @override
  Future<void> stop() async {
    final subscription = _connectionSubscription;
    final server = _server;
    _connectionSubscription = null;
    _server = null;
    _disconnectOnNextExchange = false;
    _localPairingChallenge = null;
    _localPairingConfirmation = null;
    _localRevisionSummary = null;
    _localRevisionGraph = null;
    _localResolutionAck = null;
    _localSnapshotManifests = const <String, P2pSnapshotManifest>{};
    installAuthenticatedSession(null);
    await subscription?.cancel();
    await server?.close();
  }

  @override
  Future<void> probe(
    P2pEndpoint endpoint, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (_androidProbeGateway.isSupported) {
      try {
        await _androidProbeGateway.probe(
          host: endpoint.host,
          port: endpoint.port,
          connectTimeout: timeout,
          readTimeout: timeout,
        );
        return;
      } on P2pAndroidProbeException catch (error) {
        switch (error.failure) {
          case P2pAndroidProbeFailure.incompatible:
            throw const FormatException("目標不是相容的物語 Assistant P2P 端點。");
          case P2pAndroidProbeFailure.response:
            throw P2pProbeException(
              stage: P2pProbeFailureStage.response,
              cause: error,
            );
          case P2pAndroidProbeFailure.noLocalNetwork:
          case P2pAndroidProbeFailure.connect:
            throw P2pProbeException(
              stage: P2pProbeFailureStage.connect,
              cause: error,
            );
        }
      }
    }

    Socket? socket;
    var receivedCompatibleResponse = false;
    try {
      try {
        socket = await Socket.connect(
          endpoint.host,
          endpoint.port,
          timeout: timeout,
        );
      } on TimeoutException catch (error) {
        throw P2pProbeException(
          stage: P2pProbeFailureStage.connect,
          cause: error,
        );
      } on SocketException catch (error) {
        throw P2pProbeException(
          stage: P2pProbeFailureStage.connect,
          cause: error,
        );
      }
      socket.setOption(SocketOption.tcpNoDelay, true);
      late final String response;
      try {
        socket.add(utf8.encode(_probeRequest));
        await socket.flush();
        response = await _readBoundedLine(
          socket,
          timeout: timeout,
          maxBytes: _maxProbeBytes,
        );
      } on TimeoutException catch (error) {
        throw P2pProbeException(
          stage: P2pProbeFailureStage.response,
          cause: error,
        );
      } on SocketException catch (error) {
        throw P2pProbeException(
          stage: P2pProbeFailureStage.response,
          cause: error,
        );
      }
      if (response != _probeResponse.trim()) {
        throw const FormatException("目標不是相容的物語 Assistant P2P 端點。");
      }
      receivedCompatibleResponse = true;
    } finally {
      final connectedSocket = socket;
      if (connectedSocket != null) {
        if (receivedCompatibleResponse) {
          await _closeGracefully(connectedSocket);
        } else {
          connectedSocket.destroy();
        }
      }
    }
  }

  @override
  Future<P2pProjectOffer> negotiateProjectOffer(
    P2pEndpoint endpoint,
    P2pProjectOffer localOffer, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    updateLocalProjectOffer(localOffer);
    final requestLine = "$_offerPrefix${jsonEncode(localOffer.toJson())}";
    final response = await _exchangeLine(
      endpoint,
      requestLine: requestLine,
      timeout: timeout,
      maxResponseBytes: _maxOfferBytes,
    );
    if (!response.startsWith(_offerPrefix)) {
      throw const FormatException("對方不支援 P2P project offer 協商。");
    }
    return P2pProjectOffer.fromJson(
      _decodeJsonObject(response.substring(_offerPrefix.length)),
    );
  }

  @override
  Future<void> notifyDisconnect(
    P2pEndpoint endpoint, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    const disconnectOffer = P2pProjectOffer.disconnect();
    final requestLine = "$_offerPrefix${jsonEncode(disconnectOffer.toJson())}";
    await _exchangeLine(
      endpoint,
      requestLine: requestLine,
      timeout: timeout,
      maxResponseBytes: _maxOfferBytes,
    );
  }

  @override
  Future<P2pPairingChallenge?> negotiatePairingChallenge(
    P2pEndpoint endpoint,
    P2pPairingChallenge localChallenge, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    updateLocalPairingChallenge(localChallenge);
    final requestLine = "$_pairingPrefix${jsonEncode(localChallenge.toJson())}";
    final response = await _exchangeLine(
      endpoint,
      requestLine: requestLine,
      timeout: timeout,
      maxResponseBytes: P2pPairingChallenge.maxEncodedLength,
    );
    if (!response.startsWith(_pairingPrefix)) {
      throw const FormatException("對方不支援 P2P pairing challenge。");
    }
    final payload = _decodeJsonObject(
      response.substring(_pairingPrefix.length),
    );
    if (payload["available"] != true) return null;
    final challenge = payload["challenge"];
    if (challenge is! Map) {
      throw const FormatException("對方 pairing challenge 回應無效。");
    }
    return P2pPairingChallenge.fromJson(
      challenge.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  @override
  Future<P2pPairingConfirmation?> negotiatePairingConfirmation(
    P2pEndpoint endpoint,
    P2pPairingConfirmation? localConfirmation, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (localConfirmation != null) {
      updateLocalPairingConfirmation(localConfirmation);
    }
    final requestLine =
        "$_pairingConfirmationPrefix${jsonEncode(<String, Object?>{"available": localConfirmation != null, if (localConfirmation != null) "confirmation": localConfirmation.toJson()})}";
    final response = await _exchangeLine(
      endpoint,
      requestLine: requestLine,
      timeout: timeout,
      maxResponseBytes: P2pPairingConfirmation.maxEncodedLength + 256,
    );
    if (!response.startsWith(_pairingConfirmationPrefix)) {
      throw const FormatException("對方不支援 P2P pairing confirmation。");
    }
    final payload = _decodeJsonObject(
      response.substring(_pairingConfirmationPrefix.length),
    );
    if (payload["available"] != true) return null;
    final confirmation = payload["confirmation"];
    if (confirmation is! Map) {
      throw const FormatException("對方 pairing confirmation 回應無效。");
    }
    return P2pPairingConfirmation.fromJson(
      confirmation.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  @override
  Future<P2pRevisionSummaryExchange> negotiateRevisionSummary(
    P2pEndpoint endpoint,
    P2pRevisionSummary localSummary, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final channel = _secureChannel;
    if (channel == null) {
      throw StateError("尚未建立 authenticated encrypted transport。");
    }
    if (localSummary.projectUuid != _localRevisionSummary?.projectUuid) {
      throw const FormatException("本機 revision summary 尚未安裝或 project 不一致。");
    }
    final requestId = base64UrlEncode(
      List<int>.generate(16, (_) => _secureRandom.nextInt(256)),
    ).replaceAll("=", "");
    final requestFrame = await channel.encryptJson(<String, Object?>{
      "type": "revisionSummaryRequest",
      "requestId": requestId,
      if (_server?.port case final servicePort?) "servicePort": servicePort,
      "summary": localSummary.toJson(),
      if (_headManifestForSummary(localSummary) case final manifest?)
        "headManifest": manifest.toJson(),
      if (_syncRequestForSummary(localSummary) case final syncRequest?)
        "syncRequest": syncRequest.toJson(),
      if (_localResolutionAck case final ack?) "resolutionAck": ack.toJson(),
    });
    final response = await _exchangeLine(
      endpoint,
      requestLine: "$_secureFramePrefix${jsonEncode(requestFrame.toJson())}",
      timeout: timeout,
      maxResponseBytes: _maxSecureFrameBytes,
    );
    if (!response.startsWith(_secureFramePrefix)) {
      throw const FormatException(
        "對方未使用 authenticated encrypted transport 回應。",
      );
    }
    final responseFrame = P2pEncryptedFrame.fromJson(
      _decodeJsonObject(response.substring(_secureFramePrefix.length)),
    );
    final clearResponse = await channel.decryptJson(responseFrame);
    if (clearResponse["type"] != "revisionSummaryResponse" ||
        clearResponse["requestId"] != requestId) {
      throw const FormatException("加密 revision summary response 與 request 不符。");
    }
    final summary = _revisionSummaryFromEncryptedPayload(
      clearResponse["summary"],
    );
    if (summary.projectUuid != localSummary.projectUuid) {
      throw const FormatException("遠端 revision summary project UUID 不一致。");
    }
    final headManifest = _validatedHeadManifestForSummary(
      summary,
      clearResponse["headManifest"],
    );
    final syncRequest = _validatedSnapshotSyncRequest(
      headManifest,
      clearResponse["syncRequest"],
    );
    final resolutionAck = _validatedResolutionAck(
      summary,
      clearResponse["resolutionAck"],
    );
    return P2pRevisionSummaryExchange(
      summary: summary,
      remoteServicePort: _validatedOptionalServicePort(
        clearResponse["servicePort"],
      ),
      headManifest: headManifest,
      syncRequest: syncRequest,
      resolutionAck: resolutionAck,
    );
  }

  @override
  Future<P2pRevisionGraphPageExchange> negotiateRevisionGraphPage(
    P2pEndpoint endpoint, {
    required int localPageIndex,
    required int remotePageIndex,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final channel = _secureChannel;
    final localGraph = _localRevisionGraph;
    if (channel == null) {
      throw StateError("尚未建立 authenticated encrypted transport。");
    }
    if (localGraph == null || remotePageIndex < 0) {
      throw const FormatException("本機 revision graph 尚未安裝或 page 無效。");
    }
    final localPage = await _revisionGraphPage(localGraph, localPageIndex);
    final requestId = base64UrlEncode(
      List<int>.generate(16, (_) => _secureRandom.nextInt(256)),
    ).replaceAll("=", "");
    final requestFrame = await channel.encryptJson(<String, Object?>{
      "type": "revisionGraphPageRequest",
      "requestId": requestId,
      "localPage": localPage.toJson(),
      "remotePageIndex": remotePageIndex,
    });
    final response = await _exchangeLine(
      endpoint,
      requestLine: "$_secureFramePrefix${jsonEncode(requestFrame.toJson())}",
      timeout: timeout,
      maxResponseBytes: _maxSecureFrameBytes,
    );
    if (!response.startsWith(_secureFramePrefix)) {
      throw const FormatException(
        "對方未使用 authenticated encrypted transport 回應 graph page。",
      );
    }
    final responseFrame = P2pEncryptedFrame.fromJson(
      _decodeJsonObject(response.substring(_secureFramePrefix.length)),
    );
    final clearResponse = await channel.decryptJson(responseFrame);
    if (clearResponse["type"] != "revisionGraphPageResponse" ||
        clearResponse["requestId"] != requestId ||
        clearResponse["ackLocalPageIndex"] != localPageIndex) {
      throw const FormatException(
        "加密 revision graph page response 與 request 不符。",
      );
    }
    final remotePage = _revisionGraphPageFromEncryptedPayload(
      clearResponse["remotePage"],
    );
    if (remotePage.projectUuid != localGraph.projectUuid ||
        remotePage.pageIndex != remotePageIndex) {
      throw const FormatException("遠端 revision graph page 與 request 不一致。");
    }
    return P2pRevisionGraphPageExchange(
      acknowledgedLocalPageIndex: localPageIndex,
      remotePage: remotePage,
    );
  }

  @override
  Future<P2pSnapshotManifest?> negotiateSnapshotManifest(
    P2pEndpoint endpoint, {
    required String projectUuid,
    required String revisionId,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final channel = _secureChannel;
    if (channel == null) {
      throw StateError("尚未建立 authenticated encrypted transport。");
    }
    final normalizedProjectUuid = projectUuid.trim().toLowerCase();
    final normalizedRevisionId = revisionId.trim().toLowerCase();
    if (!P2pProjectStatus.isValidProjectUuid(normalizedProjectUuid) ||
        !RegExp(r"^[0-9a-f]{64}$").hasMatch(normalizedRevisionId)) {
      throw const FormatException("P2P snapshot manifest request 無效。");
    }
    final requestId = base64UrlEncode(
      List<int>.generate(16, (_) => _secureRandom.nextInt(256)),
    ).replaceAll("=", "");
    final requestFrame = await channel.encryptJson(<String, Object?>{
      "type": "snapshotManifestRequest",
      "requestId": requestId,
      "projectUuid": normalizedProjectUuid,
      "revisionId": normalizedRevisionId,
    });
    final response = await _exchangeLine(
      endpoint,
      requestLine: "$_secureFramePrefix${jsonEncode(requestFrame.toJson())}",
      timeout: timeout,
      maxResponseBytes: _maxSecureFrameBytes,
    );
    if (!response.startsWith(_secureFramePrefix)) {
      throw const FormatException(
        "對方未使用 authenticated encrypted transport 回應。",
      );
    }
    final responseFrame = P2pEncryptedFrame.fromJson(
      _decodeJsonObject(response.substring(_secureFramePrefix.length)),
    );
    final clearResponse = await channel.decryptJson(responseFrame);
    if (clearResponse["type"] != "snapshotManifestResponse" ||
        clearResponse["requestId"] != requestId ||
        clearResponse["available"] is! bool) {
      throw const FormatException(
        "加密 snapshot manifest response 與 request 不符。",
      );
    }
    if (clearResponse["available"] == false) return null;
    final manifest = _snapshotManifestFromEncryptedPayload(
      clearResponse["manifest"],
    );
    if (manifest.projectUuid != normalizedProjectUuid ||
        manifest.revisionId != normalizedRevisionId) {
      throw const FormatException("遠端 snapshot manifest 與 request 不一致。");
    }
    return manifest;
  }

  @override
  Future<P2pSnapshotChunk?> negotiateSnapshotChunk(
    P2pEndpoint endpoint,
    P2pSnapshotChunkRequest request, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final chunks = await negotiateSnapshotChunks(
      endpoint,
      <P2pSnapshotChunkRequest>[request],
      timeout: timeout,
    );
    return chunks.single;
  }

  @override
  Future<List<P2pSnapshotChunk?>> negotiateSnapshotChunks(
    P2pEndpoint endpoint,
    List<P2pSnapshotChunkRequest> requests, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final channel = _secureChannel;
    if (channel == null) {
      throw StateError("尚未建立 authenticated encrypted transport。");
    }
    if (!_snapshotContentTransferEnabled) {
      throw StateError("snapshot 內容傳輸尚未啟用。");
    }
    if (requests.isEmpty || requests.length > 32) {
      throw const FormatException("每次只能要求 1–32 個 snapshot chunks。");
    }
    final manifest = requests.first.manifest;
    final chunkIndexes = <int>{};
    for (final request in requests) {
      if (request.manifest != manifest ||
          !chunkIndexes.add(request.chunkIndex)) {
        throw const FormatException(
          "同批 snapshot chunk request 必須使用相同 manifest 且 index 不可重複。",
        );
      }
    }

    final requestIds = <String>[];
    final requestLines = <String>[];
    for (final request in requests) {
      final requestId = base64UrlEncode(
        List<int>.generate(16, (_) => _secureRandom.nextInt(256)),
      ).replaceAll("=", "");
      final requestFrame = await channel.encryptJson(<String, Object?>{
        "type": "snapshotChunkRequest",
        "requestId": requestId,
        "request": request.toJson(),
      });
      requestIds.add(requestId);
      requestLines.add(
        "$_secureFramePrefix${jsonEncode(requestFrame.toJson())}",
      );
    }

    final responses = await _exchangeLines(
      endpoint,
      requestLines: requestLines,
      timeout: timeout,
      maxResponseBytes: _maxSecureFrameBytes,
    );
    final chunks = <P2pSnapshotChunk?>[];
    for (var index = 0; index < responses.length; index += 1) {
      chunks.add(
        await _decodeSnapshotChunkResponse(
          channel: channel,
          response: responses[index],
          requestId: requestIds[index],
          request: requests[index],
        ),
      );
    }
    return List<P2pSnapshotChunk?>.unmodifiable(chunks);
  }

  Future<P2pSnapshotChunk?> _decodeSnapshotChunkResponse({
    required P2pSecureChannel channel,
    required String response,
    required String requestId,
    required P2pSnapshotChunkRequest request,
  }) async {
    if (!response.startsWith(_secureFramePrefix)) {
      throw const FormatException(
        "對方未使用 authenticated encrypted transport 回應 snapshot chunk。",
      );
    }
    final responseFrame = P2pEncryptedFrame.fromJson(
      _decodeJsonObject(response.substring(_secureFramePrefix.length)),
    );
    final clearResponse = await channel.decryptJson(responseFrame);
    final available = clearResponse["available"];
    final expectedResponseKeys = available == true
        ? const <String>{"type", "requestId", "available", "ack", "chunk"}
        : const <String>{"type", "requestId", "available", "ack"};
    if (clearResponse["type"] != "snapshotChunkResponse" ||
        clearResponse["requestId"] != requestId ||
        available is! bool ||
        clearResponse.length != expectedResponseKeys.length ||
        !clearResponse.keys.every(expectedResponseKeys.contains)) {
      throw const FormatException("加密 snapshot chunk response 與 request 不符。");
    }
    final ack = _snapshotChunkAckFromEncryptedPayload(clearResponse["ack"]);
    if (!ack.matches(request.manifest, request.chunkIndex)) {
      throw const FormatException("加密 snapshot chunk ACK 與 request 不符。");
    }
    if (!available) return null;
    final chunk = _snapshotChunkFromEncryptedPayload(clearResponse["chunk"]);
    chunk.validateAgainst(request.manifest);
    if (chunk.chunkIndex != request.chunkIndex) {
      throw const FormatException("遠端 snapshot chunk index 與 request 不符。");
    }
    return chunk;
  }

  Future<String> _exchangeLine(
    P2pEndpoint endpoint, {
    required String requestLine,
    required Duration timeout,
    required int maxResponseBytes,
  }) async {
    if (_androidProbeGateway.isSupported) {
      try {
        return await _androidProbeGateway.exchangeLine(
          host: endpoint.host,
          port: endpoint.port,
          requestLine: requestLine,
          maxResponseBytes: maxResponseBytes,
          connectTimeout: timeout,
          readTimeout: timeout,
        );
      } on P2pAndroidProbeException catch (error) {
        final stage = error.failure == P2pAndroidProbeFailure.response
            ? P2pProbeFailureStage.response
            : P2pProbeFailureStage.connect;
        if (error.failure == P2pAndroidProbeFailure.incompatible) {
          throw const FormatException(
            "對方未完成相容的 P2P 回應；可能是版本不一致、回應超過限制，或加密驗證拒絕了封包。",
          );
        }
        throw P2pProbeException(stage: stage, cause: error);
      }
    }

    Socket? socket;
    var receivedLine = false;
    try {
      try {
        socket = await Socket.connect(
          endpoint.host,
          endpoint.port,
          timeout: timeout,
        );
      } on TimeoutException catch (error) {
        throw P2pProbeException(
          stage: P2pProbeFailureStage.connect,
          cause: error,
        );
      } on SocketException catch (error) {
        throw P2pProbeException(
          stage: P2pProbeFailureStage.connect,
          cause: error,
        );
      }
      socket.setOption(SocketOption.tcpNoDelay, true);
      try {
        socket.add(utf8.encode("$requestLine\n"));
        await socket.flush();
        final response = await _readBoundedLine(
          socket,
          timeout: timeout,
          maxBytes: maxResponseBytes,
        );
        receivedLine = true;
        return response;
      } on TimeoutException catch (error) {
        throw P2pProbeException(
          stage: P2pProbeFailureStage.response,
          cause: error,
        );
      } on SocketException catch (error) {
        throw P2pProbeException(
          stage: P2pProbeFailureStage.response,
          cause: error,
        );
      }
    } finally {
      final connectedSocket = socket;
      if (connectedSocket != null) {
        if (receivedLine) {
          await _closeGracefully(connectedSocket);
        } else {
          connectedSocket.destroy();
        }
      }
    }
  }

  Future<List<String>> _exchangeLines(
    P2pEndpoint endpoint, {
    required List<String> requestLines,
    required Duration timeout,
    required int maxResponseBytes,
  }) async {
    if (requestLines.isEmpty || requestLines.length > 32) {
      throw const FormatException("每次只能交換 1–32 行 P2P 訊息。");
    }
    if (_androidProbeGateway.isSupported) {
      try {
        return await _androidProbeGateway.exchangeLines(
          host: endpoint.host,
          port: endpoint.port,
          requestLines: requestLines,
          maxResponseBytes: maxResponseBytes,
          connectTimeout: timeout,
          readTimeout: timeout,
        );
      } on P2pAndroidProbeException catch (error) {
        final stage = error.failure == P2pAndroidProbeFailure.response
            ? P2pProbeFailureStage.response
            : P2pProbeFailureStage.connect;
        if (error.failure == P2pAndroidProbeFailure.incompatible) {
          throw const FormatException("對方不是相容的 P2P encrypted transport 端點。");
        }
        throw P2pProbeException(stage: stage, cause: error);
      }
    }

    Socket? socket;
    _P2pSocketLineReader? reader;
    var receivedAllLines = false;
    try {
      try {
        socket = await Socket.connect(
          endpoint.host,
          endpoint.port,
          timeout: timeout,
        );
      } on TimeoutException catch (error) {
        throw P2pProbeException(
          stage: P2pProbeFailureStage.connect,
          cause: error,
        );
      } on SocketException catch (error) {
        throw P2pProbeException(
          stage: P2pProbeFailureStage.connect,
          cause: error,
        );
      }
      socket.setOption(SocketOption.tcpNoDelay, true);
      reader = _P2pSocketLineReader(socket);
      final responses = <String>[];
      try {
        for (final requestLine in requestLines) {
          socket.add(utf8.encode("$requestLine\n"));
          await socket.flush();
          responses.add(
            await reader.readLine(timeout: timeout, maxBytes: maxResponseBytes),
          );
        }
      } on TimeoutException catch (error) {
        throw P2pProbeException(
          stage: P2pProbeFailureStage.response,
          cause: error,
        );
      } on SocketException catch (error) {
        throw P2pProbeException(
          stage: P2pProbeFailureStage.response,
          cause: error,
        );
      }
      receivedAllLines = true;
      return List<String>.unmodifiable(responses);
    } finally {
      await reader?.cancel();
      final connectedSocket = socket;
      if (connectedSocket != null) {
        if (receivedAllLines) {
          await _closeGracefully(connectedSocket);
        } else {
          connectedSocket.destroy();
        }
      }
    }
  }

  Future<void> _handleProbe(Socket socket) async {
    var sentCompatibleResponse = false;
    var isCompatibilityProbe = false;
    var respondedWithDisconnect = false;
    String? remoteAddress;
    _P2pSocketLineReader? reader;
    P2pSecureChannel? snapshotChunkStreamChannel;
    try {
      socket.setOption(SocketOption.tcpNoDelay, true);
      final peerAddress = socket.remoteAddress;
      final isLoopback = peerAddress.isLoopback;
      if (!isLoopback && !P2pEndpoint.isPrivateIpv4(peerAddress.address)) {
        return;
      }
      remoteAddress = peerAddress.address;
      reader = _P2pSocketLineReader(socket);
      final request = await reader.readLine(
        timeout: _probeReadTimeout,
        maxBytes: _maxSecureFrameBytes,
      );
      P2pProjectOffer? remoteOffer;
      P2pPairingChallenge? remotePairingChallenge;
      P2pPairingConfirmation? remotePairingConfirmation;
      P2pRevisionSummary? remoteRevisionSummary;
      P2pSnapshotManifest? remoteHeadManifest;
      P2pSnapshotSyncRequest? remoteSnapshotSyncRequest;
      P2pResolutionAck? remoteResolutionAck;
      int? remoteServicePort;
      P2pRevisionGraph? remoteRevisionGraph;
      String? remoteRevisionGraphTransferId;
      late final String response;
      if (request == _probeRequest.trim()) {
        isCompatibilityProbe = true;
        response = _probeResponse;
      } else if (request.startsWith(_offerPrefix)) {
        remoteOffer = P2pProjectOffer.fromJson(
          _decodeJsonObject(request.substring(_offerPrefix.length)),
        );
        final responseOffer = _disconnectOnNextExchange
            ? const P2pProjectOffer.disconnect()
            : _localProjectOffer;
        _disconnectOnNextExchange = false;
        respondedWithDisconnect = responseOffer.disconnectRequested;
        response = "$_offerPrefix${jsonEncode(responseOffer.toJson())}\n";
      } else if (request.startsWith(_pairingPrefix)) {
        remotePairingChallenge = P2pPairingChallenge.fromJson(
          _decodeJsonObject(request.substring(_pairingPrefix.length)),
        );
        final localChallenge = _localPairingChallenge;
        response =
            "$_pairingPrefix${jsonEncode(<String, Object?>{"available": localChallenge != null, if (localChallenge != null) "challenge": localChallenge.toJson()})}\n";
      } else if (request.startsWith(_pairingConfirmationPrefix)) {
        final confirmationPayload = _decodeJsonObject(
          request.substring(_pairingConfirmationPrefix.length),
        );
        if (confirmationPayload["available"] == true) {
          final confirmation = confirmationPayload["confirmation"];
          if (confirmation is! Map) return;
          remotePairingConfirmation = P2pPairingConfirmation.fromJson(
            confirmation.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
        final localConfirmation = _localPairingConfirmation;
        response =
            "$_pairingConfirmationPrefix${jsonEncode(<String, Object?>{"available": localConfirmation != null, if (localConfirmation != null) "confirmation": localConfirmation.toJson()})}\n";
      } else if (request.startsWith(_secureFramePrefix)) {
        final channel = _secureChannel;
        if (channel == null) return;
        final frame = P2pEncryptedFrame.fromJson(
          _decodeJsonObject(request.substring(_secureFramePrefix.length)),
        );
        final clearRequest = await channel.decryptJson(frame);
        final requestId = clearRequest["requestId"];
        if (requestId is! String ||
            requestId.isEmpty ||
            requestId.length > 64) {
          return;
        }
        final type = clearRequest["type"];
        if (type == "revisionSummaryRequest") {
          final localSummary = _localRevisionSummary;
          if (localSummary == null) return;
          remoteRevisionSummary = _revisionSummaryFromEncryptedPayload(
            clearRequest["summary"],
          );
          remoteServicePort = _validatedOptionalServicePort(
            clearRequest["servicePort"],
          );
          if (remoteRevisionSummary.projectUuid != localSummary.projectUuid) {
            return;
          }
          remoteHeadManifest = _validatedHeadManifestForSummary(
            remoteRevisionSummary,
            clearRequest["headManifest"],
          );
          remoteSnapshotSyncRequest = _validatedSnapshotSyncRequest(
            remoteHeadManifest,
            clearRequest["syncRequest"],
          );
          remoteResolutionAck = _validatedResolutionAck(
            remoteRevisionSummary,
            clearRequest["resolutionAck"],
          );
          final localHeadManifest = _headManifestForSummary(localSummary);
          final localSyncRequest = _syncRequestForSummary(localSummary);
          final responseFrame = await channel.encryptJson(<String, Object?>{
            "type": "revisionSummaryResponse",
            "requestId": requestId,
            if (_server?.port case final servicePort?)
              "servicePort": servicePort,
            "summary": localSummary.toJson(),
            if (localHeadManifest != null)
              "headManifest": localHeadManifest.toJson(),
            if (localSyncRequest != null)
              "syncRequest": localSyncRequest.toJson(),
            if (_localResolutionAck != null)
              "resolutionAck": _localResolutionAck!.toJson(),
          });
          response =
              "$_secureFramePrefix${jsonEncode(responseFrame.toJson())}\n";
        } else if (type == "revisionGraphPageRequest") {
          final localGraph = _localRevisionGraph;
          final remotePageIndex = clearRequest["remotePageIndex"];
          if (localGraph == null || remotePageIndex is! int) return;
          final inboundPage = _revisionGraphPageFromEncryptedPayload(
            clearRequest["localPage"],
          );
          if (inboundPage.projectUuid != localGraph.projectUuid) return;
          final assembler = _inboundGraphAssemblers.putIfAbsent(
            inboundPage.transferId,
            P2pRevisionGraphAssembler.new,
          );
          assembler.add(inboundPage);
          if (assembler.isComplete &&
              _completedInboundGraphTransfers.add(inboundPage.transferId)) {
            remoteRevisionGraph = assembler.assemble();
            remoteRevisionGraphTransferId = inboundPage.transferId;
            _inboundGraphAssemblers.remove(inboundPage.transferId);
          }
          final localPage = await _revisionGraphPage(
            localGraph,
            remotePageIndex,
          );
          final responseFrame = await channel.encryptJson(<String, Object?>{
            "type": "revisionGraphPageResponse",
            "requestId": requestId,
            "ackLocalPageIndex": inboundPage.pageIndex,
            "remotePage": localPage.toJson(),
          });
          response =
              "$_secureFramePrefix${jsonEncode(responseFrame.toJson())}\n";
        } else if (type == "snapshotManifestRequest") {
          final projectUuid = clearRequest["projectUuid"];
          final revisionId = clearRequest["revisionId"];
          if (projectUuid is! String ||
              revisionId is! String ||
              !P2pProjectStatus.isValidProjectUuid(projectUuid) ||
              !RegExp(r"^[0-9a-f]{64}$").hasMatch(revisionId)) {
            return;
          }
          final manifest = _localSnapshotManifests[revisionId];
          final available = manifest?.projectUuid == projectUuid;
          final responseFrame = await channel.encryptJson(<String, Object?>{
            "type": "snapshotManifestResponse",
            "requestId": requestId,
            "available": available,
            if (available) "manifest": manifest!.toJson(),
          });
          response =
              "$_secureFramePrefix${jsonEncode(responseFrame.toJson())}\n";
        } else if (type == "snapshotChunkRequest") {
          final chunkResponse = await _buildSnapshotChunkResponse(
            channel: channel,
            clearRequest: clearRequest,
            requestId: requestId,
          );
          if (chunkResponse == null) return;
          response = chunkResponse;
          snapshotChunkStreamChannel = channel;
        } else {
          return;
        }
      } else {
        return;
      }
      socket.add(utf8.encode(response));
      await socket.flush();
      sentCompatibleResponse = true;
      if (snapshotChunkStreamChannel case final channel?) {
        await _serveSnapshotChunkContinuations(
          socket: socket,
          reader: reader,
          channel: channel,
        );
      }
      if (isCompatibilityProbe) {
        _inboundProbeController.add(
          P2pInboundProbe(remoteAddress: remoteAddress),
        );
      }
      if (remoteOffer != null && !respondedWithDisconnect) {
        _inboundProjectOfferController.add(
          P2pInboundProjectOffer(
            remoteAddress: remoteAddress,
            offer: remoteOffer,
          ),
        );
      }
      if (remotePairingChallenge != null) {
        _inboundPairingChallengeController.add(
          P2pInboundPairingChallenge(
            remoteAddress: remoteAddress,
            challenge: remotePairingChallenge,
          ),
        );
      }
      if (remotePairingConfirmation != null) {
        _inboundPairingConfirmationController.add(
          P2pInboundPairingConfirmation(
            remoteAddress: remoteAddress,
            confirmation: remotePairingConfirmation,
          ),
        );
      }
      if (remoteRevisionSummary != null) {
        _inboundRevisionSummaryController.add(
          P2pInboundRevisionSummary(
            remoteAddress: remoteAddress,
            remoteServicePort: remoteServicePort,
            summary: remoteRevisionSummary,
            headManifest: remoteHeadManifest,
            syncRequest: remoteSnapshotSyncRequest,
            resolutionAck: remoteResolutionAck,
          ),
        );
      }
      if (remoteRevisionGraph != null) {
        _inboundRevisionGraphController.add(
          P2pInboundRevisionGraph(
            remoteAddress: remoteAddress,
            transferId: remoteRevisionGraphTransferId!,
            graph: remoteRevisionGraph,
          ),
        );
      }
    } on SecretBoxAuthenticationError {
      // Authentication failures are intentionally indistinguishable from an
      // unknown client and receive no response.
    } on StateError {
      // The session may have been cleared while this request was in flight.
    } on Exception {
      // Unknown, oversized, or stalled clients receive no information.
    } finally {
      await reader?.cancel();
      if (sentCompatibleResponse) {
        await _closeGracefully(socket);
      } else {
        socket.destroy();
      }
    }
  }

  Future<String?> _buildSnapshotChunkResponse({
    required P2pSecureChannel channel,
    required Map<String, Object?> clearRequest,
    required String requestId,
  }) async {
    if (!_snapshotContentTransferEnabled) return null;
    final loader = _snapshotChunkLoader;
    if (loader == null) return null;
    const expectedRequestKeys = <String>{"type", "requestId", "request"};
    if (clearRequest.length != expectedRequestKeys.length ||
        !clearRequest.keys.every(expectedRequestKeys.contains)) {
      return null;
    }
    final chunkRequest = _snapshotChunkRequestFromEncryptedPayload(
      clearRequest["request"],
    );
    final requestedManifest = chunkRequest.manifest;
    final localManifest = _localSnapshotManifests[requestedManifest.revisionId];
    final manifestMatches = localManifest == requestedManifest;
    final chunk = manifestMatches
        ? await loader(localManifest!, chunkRequest.chunkIndex)
        : null;
    if (chunk != null) {
      chunk.validateAgainst(requestedManifest);
      if (chunk.chunkIndex != chunkRequest.chunkIndex) return null;
    }
    final ack = P2pSnapshotChunkAck(
      projectUuid: requestedManifest.projectUuid,
      revisionId: requestedManifest.revisionId,
      contentSha256: requestedManifest.contentSha256,
      chunkIndex: chunkRequest.chunkIndex,
    );
    final responseFrame = await channel.encryptJson(<String, Object?>{
      "type": "snapshotChunkResponse",
      "requestId": requestId,
      "available": chunk != null,
      "ack": ack.toJson(),
      if (chunk != null) "chunk": chunk.toJson(),
    });
    return "$_secureFramePrefix${jsonEncode(responseFrame.toJson())}\n";
  }

  Future<void> _serveSnapshotChunkContinuations({
    required Socket socket,
    required _P2pSocketLineReader reader,
    required P2pSecureChannel channel,
  }) async {
    // The first request was handled by _handleProbe. Keep a strict bound so a
    // peer cannot monopolize a listener connection indefinitely.
    for (var remaining = 31; remaining > 0; remaining -= 1) {
      try {
        final request = await reader.readLine(
          timeout: _probeReadTimeout,
          maxBytes: _maxSecureFrameBytes,
        );
        if (!request.startsWith(_secureFramePrefix)) return;
        final frame = P2pEncryptedFrame.fromJson(
          _decodeJsonObject(request.substring(_secureFramePrefix.length)),
        );
        final clearRequest = await channel.decryptJson(frame);
        final requestId = clearRequest["requestId"];
        if (clearRequest["type"] != "snapshotChunkRequest" ||
            requestId is! String ||
            requestId.isEmpty ||
            requestId.length > 64) {
          return;
        }
        final response = await _buildSnapshotChunkResponse(
          channel: channel,
          clearRequest: clearRequest,
          requestId: requestId,
        );
        if (response == null) return;
        socket.add(utf8.encode(response));
        await socket.flush();
      } on Exception {
        // EOF, authentication failures, malformed frames, and idle peers all
        // terminate only this bounded content-transfer connection.
        return;
      }
    }
  }

  Future<void> _closeGracefully(Socket socket) async {
    try {
      await socket.close().timeout(_gracefulCloseTimeout);
    } on Exception {
      socket.destroy();
    }
  }

  Future<String> _readBoundedLine(
    Socket socket, {
    required Duration timeout,
    required int maxBytes,
  }) {
    return (() async {
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in socket) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const FormatException("P2P probe 超過大小限制。");
        }
        final newlineIndex = chunk.indexOf(10);
        if (newlineIndex >= 0) {
          bytes.add(chunk.sublist(0, newlineIndex));
          return utf8.decode(bytes.takeBytes(), allowMalformed: false);
        }
        bytes.add(chunk);
      }
      throw const FormatException("P2P probe 未完整結束。");
    })().timeout(timeout);
  }

  Map<String, Object?> _decodeJsonObject(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException("P2P project offer 必須是 JSON object。");
    }
    final result = <String, Object?>{};
    for (final entry in decoded.entries) {
      if (entry.key is! String) {
        throw const FormatException("P2P project offer JSON key 無效。");
      }
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  int? _validatedOptionalServicePort(Object? value) {
    if (value == null) return null;
    if (value is! int || value < 1 || value > 65535) {
      throw const FormatException("加密端點的服務 Port 無效。");
    }
    return value;
  }

  P2pRevisionSummary _revisionSummaryFromEncryptedPayload(Object? value) {
    if (value is! Map) {
      throw const FormatException("加密 revision summary payload 無效。");
    }
    final mapped = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw const FormatException("加密 revision summary key 無效。");
      }
      mapped[entry.key as String] = entry.value;
    }
    return P2pRevisionSummary.fromJson(mapped);
  }

  P2pSnapshotManifest _snapshotManifestFromEncryptedPayload(Object? value) {
    if (value is! Map) {
      throw const FormatException("加密 snapshot manifest payload 無效。");
    }
    final mapped = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw const FormatException("加密 snapshot manifest key 無效。");
      }
      mapped[entry.key as String] = entry.value;
    }
    return P2pSnapshotManifest.fromJson(mapped);
  }

  P2pRevisionGraphPage _revisionGraphPageFromEncryptedPayload(Object? value) {
    return P2pRevisionGraphPage.fromJson(
      _stringKeyedEncryptedPayload(value, "revision graph page"),
    );
  }

  Future<P2pRevisionGraphPage> _revisionGraphPage(
    P2pRevisionGraph graph,
    int pageIndex,
  ) async {
    final revisions = graph.topologicallySortedRevisions;
    final pageCount = revisions.isEmpty
        ? 1
        : (revisions.length + P2pRevisionGraphPage.maxRevisionsPerPage - 1) ~/
              P2pRevisionGraphPage.maxRevisionsPerPage;
    if (pageIndex < 0 || pageIndex >= pageCount) {
      throw const FormatException("P2P revision graph page index 無效。");
    }
    final transferId = _hex(
      (await Sha256().hash(utf8.encode(jsonEncode(graph.toJson())))).bytes,
    );
    final start = pageIndex * P2pRevisionGraphPage.maxRevisionsPerPage;
    final end = (start + P2pRevisionGraphPage.maxRevisionsPerPage).clamp(
      0,
      revisions.length,
    );
    final page = P2pRevisionGraphPage(
      projectUuid: graph.projectUuid,
      transferId: transferId,
      pageIndex: pageIndex,
      pageCount: pageCount,
      totalRevisionCount: revisions.length,
      revisions: revisions.sublist(start, end),
      headIds: graph.headIds,
    );
    if (utf8.encode(jsonEncode(page.toJson())).length >
        P2pRevisionGraphPage.maxEncodedLength) {
      throw const FormatException("P2P revision graph page 超過大小限制。");
    }
    return page;
  }

  P2pSnapshotChunkRequest _snapshotChunkRequestFromEncryptedPayload(
    Object? value,
  ) {
    return P2pSnapshotChunkRequest.fromJson(
      _stringKeyedEncryptedPayload(value, "snapshot chunk request"),
    );
  }

  P2pSnapshotChunkAck _snapshotChunkAckFromEncryptedPayload(Object? value) {
    return P2pSnapshotChunkAck.fromJson(
      _stringKeyedEncryptedPayload(value, "snapshot chunk ACK"),
    );
  }

  P2pSnapshotChunk _snapshotChunkFromEncryptedPayload(Object? value) {
    return P2pSnapshotChunk.fromJson(
      _stringKeyedEncryptedPayload(value, "snapshot chunk"),
    );
  }

  Map<String, Object?> _stringKeyedEncryptedPayload(
    Object? value,
    String label,
  ) {
    if (value is! Map) {
      throw FormatException("加密 $label payload 無效。");
    }
    final mapped = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw FormatException("加密 $label key 無效。");
      }
      mapped[entry.key as String] = entry.value;
    }
    return mapped;
  }

  P2pSnapshotManifest? _headManifestForSummary(P2pRevisionSummary summary) {
    if (summary.heads.length != 1) return null;
    final head = summary.heads.single;
    final manifest = _localSnapshotManifests[head.revisionId];
    if (manifest == null ||
        !manifest.matchesRevision(
          revisionProjectUuid: head.projectUuid,
          revisionId: head.revisionId,
          revisionContentSha256: head.contentSha256,
          revisionFormatVersion: head.formatVersion,
        )) {
      return null;
    }
    return manifest;
  }

  String _hex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, "0")).join();

  P2pSnapshotSyncRequest? _syncRequestForSummary(P2pRevisionSummary summary) {
    final manifest = _headManifestForSummary(summary);
    final request = _localSnapshotSyncRequest;
    return manifest != null && request != null && request.matches(manifest)
        ? request
        : null;
  }

  P2pSnapshotManifest? _validatedHeadManifestForSummary(
    P2pRevisionSummary summary,
    Object? value,
  ) {
    if (value == null) return null;
    if (summary.heads.length != 1) {
      throw const FormatException(
        "多 head revision summary 不可宣告單一 snapshot manifest。",
      );
    }
    final manifest = _snapshotManifestFromEncryptedPayload(value);
    final head = summary.heads.single;
    if (!manifest.matchesRevision(
      revisionProjectUuid: head.projectUuid,
      revisionId: head.revisionId,
      revisionContentSha256: head.contentSha256,
      revisionFormatVersion: head.formatVersion,
    )) {
      throw const FormatException(
        "snapshot manifest 與 revision summary head 不符。",
      );
    }
    return manifest;
  }

  P2pSnapshotSyncRequest? _validatedSnapshotSyncRequest(
    P2pSnapshotManifest? manifest,
    Object? value,
  ) {
    if (value == null) return null;
    if (manifest == null) {
      throw const FormatException("snapshot 同步要求缺少相符的 manifest。");
    }
    final request = P2pSnapshotSyncRequest.fromJson(
      _stringKeyedEncryptedPayload(value, "snapshot sync request"),
    );
    if (!request.matches(manifest)) {
      throw const FormatException("snapshot 同步要求與 revision manifest 不符。");
    }
    return request;
  }

  P2pResolutionAck? _validatedResolutionAck(
    P2pRevisionSummary summary,
    Object? value,
  ) {
    if (value == null) return null;
    final ack = P2pResolutionAck.fromJson(
      _stringKeyedEncryptedPayload(value, "resolution ACK"),
    );
    if (ack.projectUuid != summary.projectUuid) {
      throw const FormatException(
        "resolution ACK 與 revision summary project 不符。",
      );
    }
    return ack;
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _inboundProbeController.close();
    await _inboundProjectOfferController.close();
    await _inboundPairingChallengeController.close();
    await _inboundPairingConfirmationController.close();
    await _inboundRevisionSummaryController.close();
    await _inboundRevisionGraphController.close();
  }
}

/// Retains bytes after a newline so several bounded frames can safely share
/// one TCP stream. Re-subscribing to [Socket] for every line can lose buffered
/// frames and is not supported by Dart's single-subscription socket stream.
class _P2pSocketLineReader {
  final StreamIterator<Uint8List> _iterator;
  Uint8List? _pending;
  int _pendingOffset = 0;

  _P2pSocketLineReader(Socket socket)
    : _iterator = StreamIterator<Uint8List>(socket);

  Future<String> readLine({required Duration timeout, required int maxBytes}) {
    return _readLine(maxBytes: maxBytes).timeout(timeout);
  }

  Future<String> _readLine({required int maxBytes}) async {
    final bytes = BytesBuilder(copy: false);
    while (true) {
      final pending = _pending;
      if (pending != null) {
        final newlineIndex = pending.indexOf(10, _pendingOffset);
        final end = newlineIndex < 0 ? pending.length : newlineIndex;
        final additionLength = end - _pendingOffset;
        if (bytes.length + additionLength > maxBytes) {
          throw const FormatException("P2P probe 超過大小限制。");
        }
        if (additionLength > 0) {
          bytes.add(pending.sublist(_pendingOffset, end));
        }
        if (newlineIndex >= 0) {
          _pendingOffset = newlineIndex + 1;
          if (_pendingOffset >= pending.length) {
            _pending = null;
            _pendingOffset = 0;
          }
          return utf8.decode(bytes.takeBytes(), allowMalformed: false);
        }
        _pending = null;
        _pendingOffset = 0;
      }

      if (!await _iterator.moveNext()) {
        throw const FormatException("P2P probe 未完整結束。");
      }
      _pending = _iterator.current;
    }
  }

  Future<void> cancel() => _iterator.cancel();
}

typedef P2pSnapshotChunkLoader =
    Future<P2pSnapshotChunk?> Function(
      P2pSnapshotManifest manifest,
      int chunkIndex,
    );
