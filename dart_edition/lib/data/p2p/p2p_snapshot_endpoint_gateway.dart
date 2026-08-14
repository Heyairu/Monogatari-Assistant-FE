import "package:monogatari_assistant/data/p2p/p2p_endpoint_service.dart";
import "package:monogatari_assistant/data/p2p/p2p_snapshot_download.dart";
import "package:monogatari_assistant/domain/models/p2p_snapshot_models.dart";
import "package:monogatari_assistant/domain/models/p2p_sync_models.dart";

/// Adapter between the resumable coordinator and authenticated wire.
class AuthenticatedP2pSnapshotChunkGateway implements P2pSnapshotChunkGateway {
  static const int defaultInitialBatchSize = 8;
  static const int defaultMinBatchSize = 1;
  static const int defaultMaxBatchSize = 32;

  final P2pEndpointService _endpointService;
  final P2pEndpoint _endpoint;
  final Duration _timeout;
  final _P2pAdaptiveBatchWindow _batchWindow;
  final Map<int, P2pSnapshotChunk> _prefetchedChunks =
      <int, P2pSnapshotChunk>{};
  P2pSnapshotManifest? _prefetchedManifest;

  AuthenticatedP2pSnapshotChunkGateway({
    required P2pEndpointService endpointService,
    required P2pEndpoint endpoint,
    Duration timeout = const Duration(seconds: 12),
    int initialBatchSize = defaultInitialBatchSize,
    int minBatchSize = defaultMinBatchSize,
    int maxBatchSize = defaultMaxBatchSize,
  }) : _endpointService = endpointService,
       _endpoint = endpoint,
       _timeout = timeout,
       _batchWindow = _P2pAdaptiveBatchWindow(
         initialSize: initialBatchSize,
         minSize: minBatchSize,
         maxSize: maxBatchSize,
       );

  int get currentBatchSize => _batchWindow.currentSize;

  @override
  Future<P2pSnapshotChunk> requestChunk(
    P2pSnapshotManifest manifest,
    int chunkIndex,
  ) async {
    if (chunkIndex < 0 || chunkIndex >= manifest.chunkCount) {
      throw const P2pSnapshotChunkTransportException(
        "snapshot chunk index 超出 manifest 範圍。",
        isTransient: false,
      );
    }
    if (_prefetchedManifest != manifest) {
      _prefetchedManifest = manifest;
      _prefetchedChunks.clear();
    }
    final prefetched = _prefetchedChunks.remove(chunkIndex);
    if (prefetched != null) return prefetched;

    try {
      final remaining = manifest.chunkCount - chunkIndex;
      final currentWindow = _batchWindow.currentSize;
      final batchSize = remaining < currentWindow ? remaining : currentWindow;
      final requests = List<P2pSnapshotChunkRequest>.generate(
        batchSize,
        (offset) => P2pSnapshotChunkRequest(
          manifest: manifest,
          chunkIndex: chunkIndex + offset,
        ),
        growable: false,
      );
      final chunks = await _endpointService.negotiateSnapshotChunks(
        _endpoint,
        requests,
        timeout: _timeout,
      );
      if (chunks.length != requests.length) {
        throw const P2pSnapshotChunkTransportException(
          "對方回傳的 snapshot chunk 數量與 request 不符。",
          isTransient: false,
        );
      }
      for (var offset = 0; offset < chunks.length; offset += 1) {
        final chunk = chunks[offset];
        if (chunk == null) {
          _prefetchedChunks.clear();
          throw const P2pSnapshotChunkTransportException(
            "對方沒有要求的 immutable snapshot chunk。",
            isTransient: false,
          );
        }
        final expectedIndex = chunkIndex + offset;
        chunk.validateAgainst(manifest);
        if (chunk.chunkIndex != expectedIndex) {
          _prefetchedChunks.clear();
          throw const P2pSnapshotChunkTransportException(
            "對方回傳的 snapshot chunk 順序不符。",
            isTransient: false,
          );
        }
        _prefetchedChunks[expectedIndex] = chunk;
      }
      _batchWindow.recordSuccess(filledWindow: batchSize == currentWindow);
      return _prefetchedChunks.remove(chunkIndex)!;
    } on P2pSnapshotChunkTransportException {
      _prefetchedChunks.clear();
      _batchWindow.recordFailure(isResponsePressure: false);
      rethrow;
    } on P2pProbeException catch (error) {
      _prefetchedChunks.clear();
      _batchWindow.recordFailure(
        isResponsePressure: error.stage == P2pProbeFailureStage.response,
      );
      throw P2pSnapshotChunkTransportException(
        error.toString(),
        isTransient: true,
      );
    } on StateError catch (error) {
      _prefetchedChunks.clear();
      _batchWindow.recordFailure(isResponsePressure: false);
      throw P2pSnapshotChunkTransportException(
        error.message,
        isTransient: false,
      );
    } on FormatException catch (error) {
      _prefetchedChunks.clear();
      _batchWindow.recordFailure(isResponsePressure: false);
      throw P2pSnapshotChunkTransportException(
        error.message,
        isTransient: false,
      );
    }
  }
}

final class P2pSnapshotTransferAuthorization {
  final P2pEndpoint endpoint;
  final String projectUuid;
  final P2pSnapshotManifest remoteManifest;
  final int generation;

  const P2pSnapshotTransferAuthorization._({
    required this.endpoint,
    required this.projectUuid,
    required this.remoteManifest,
    required this.generation,
  });
}

/// Session capability shared by the sync notifier and production gateway.
///
/// It contains no key material. Revoking it invalidates late chunk responses
/// even when an underlying socket operation completes after disconnection.
final class P2pSnapshotTransferSessionController {
  P2pSnapshotTransferAuthorization? _current;
  int _generation = 0;

  P2pSnapshotTransferAuthorization? get current => _current;

  P2pSnapshotTransferAuthorization authorize({
    required P2pEndpoint endpoint,
    required String projectUuid,
    required P2pSnapshotManifest remoteManifest,
  }) {
    final normalizedProjectUuid = projectUuid.trim().toLowerCase();
    if (!P2pEndpoint.isPrivateIpv4(endpoint.host) ||
        !P2pEndpoint.isValidPort(endpoint.port)) {
      throw const FormatException("P2P snapshot transfer endpoint 無效。");
    }
    if (!P2pProjectStatus.isValidProjectUuid(normalizedProjectUuid)) {
      throw const FormatException("P2P snapshot transfer project UUID 無效。");
    }
    if (remoteManifest.projectUuid != normalizedProjectUuid) {
      throw const FormatException(
        "P2P snapshot transfer manifest 不屬於目前 project。",
      );
    }
    final existing = _current;
    if (existing != null &&
        existing.endpoint == endpoint &&
        existing.projectUuid == normalizedProjectUuid &&
        existing.remoteManifest == remoteManifest) {
      return existing;
    }
    final authorization = P2pSnapshotTransferAuthorization._(
      endpoint: endpoint,
      projectUuid: normalizedProjectUuid,
      remoteManifest: remoteManifest,
      generation: ++_generation,
    );
    _current = authorization;
    return authorization;
  }

  void revoke() {
    ++_generation;
    _current = null;
  }

  bool isCurrent(P2pSnapshotTransferAuthorization authorization) {
    final current = _current;
    return current != null &&
        current.generation == authorization.generation &&
        identical(current, authorization);
  }
}

/// Production binding that requires a live authenticated session capability.
final class SessionAwareP2pSnapshotChunkGateway
    implements P2pSnapshotChunkGateway {
  final P2pEndpointService _endpointService;
  final P2pSnapshotTransferSessionController _sessionController;
  final Duration _timeout;
  AuthenticatedP2pSnapshotChunkGateway? _delegate;
  P2pSnapshotTransferAuthorization? _delegateAuthorization;

  SessionAwareP2pSnapshotChunkGateway({
    required P2pEndpointService endpointService,
    required P2pSnapshotTransferSessionController sessionController,
    Duration timeout = const Duration(seconds: 12),
  }) : _endpointService = endpointService,
       _sessionController = sessionController,
       _timeout = timeout;

  bool get hasAuthorizedSession => _sessionController.current != null;

  @override
  Future<P2pSnapshotChunk> requestChunk(
    P2pSnapshotManifest manifest,
    int chunkIndex,
  ) async {
    final authorization = _sessionController.current;
    if (authorization == null) {
      throw const P2pSnapshotChunkTransportException(
        "尚未授權 production snapshot content session。",
        isTransient: false,
      );
    }
    if (manifest != authorization.remoteManifest) {
      throw const P2pSnapshotChunkTransportException(
        "snapshot manifest 未由目前 authenticated revision summary 授權。",
        isTransient: false,
      );
    }
    var delegate = _delegate;
    if (!identical(_delegateAuthorization, authorization) || delegate == null) {
      _delegateAuthorization = authorization;
      delegate = AuthenticatedP2pSnapshotChunkGateway(
        endpointService: _endpointService,
        endpoint: authorization.endpoint,
        timeout: _timeout,
      );
      _delegate = delegate;
    }
    final chunk = await delegate.requestChunk(manifest, chunkIndex);
    if (!_sessionController.isCurrent(authorization)) {
      throw const P2pSnapshotChunkTransportException(
        "authenticated snapshot session 已在回應完成前失效。",
        isTransient: true,
      );
    }
    return chunk;
  }
}

class _P2pAdaptiveBatchWindow {
  final int minSize;
  final int maxSize;
  int _currentSize;
  int _consecutiveFilledSuccesses = 0;

  _P2pAdaptiveBatchWindow({
    required int initialSize,
    required this.minSize,
    required this.maxSize,
  }) : _currentSize = initialSize {
    if (minSize < 1 ||
        maxSize > 32 ||
        minSize > maxSize ||
        initialSize < minSize ||
        initialSize > maxSize) {
      throw ArgumentError(
        "P2P adaptive batch size 必須滿足 1 <= min <= initial <= max <= 32。",
      );
    }
  }

  int get currentSize => _currentSize;

  void recordSuccess({required bool filledWindow}) {
    if (!filledWindow) {
      _consecutiveFilledSuccesses = 0;
      return;
    }
    _consecutiveFilledSuccesses += 1;
    if (_consecutiveFilledSuccesses < 2 || _currentSize >= maxSize) return;
    final doubled = _currentSize * 2;
    _currentSize = doubled < maxSize ? doubled : maxSize;
    _consecutiveFilledSuccesses = 0;
  }

  void recordFailure({required bool isResponsePressure}) {
    _consecutiveFilledSuccesses = 0;
    if (!isResponsePressure || _currentSize <= minSize) return;
    final halved = _currentSize ~/ 2;
    _currentSize = halved > minSize ? halved : minSize;
  }
}
