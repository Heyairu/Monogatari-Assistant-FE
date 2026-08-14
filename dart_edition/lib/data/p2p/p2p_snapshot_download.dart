import "dart:async";
import "dart:io";

import "package:monogatari_assistant/data/p2p/p2p_snapshot_quarantine.dart";
import "package:monogatari_assistant/domain/models/p2p_snapshot_models.dart";

enum P2pSnapshotDownloadStatus {
  idle,
  downloading,
  paused,
  verifying,
  verified,
  failed,
  cancelled,
}

class P2pSnapshotChunkTransportException implements Exception {
  final String message;
  final bool isTransient;

  const P2pSnapshotChunkTransportException(
    this.message, {
    required this.isTransient,
  });

  @override
  String toString() => message;
}

class P2pSnapshotDownloadCancelledException implements Exception {
  const P2pSnapshotDownloadCancelledException();

  @override
  String toString() => "P2P snapshot download 已取消。";
}

abstract class P2pSnapshotChunkGateway {
  Future<P2pSnapshotChunk> requestChunk(
    P2pSnapshotManifest manifest,
    int chunkIndex,
  );
}

class DisabledP2pSnapshotChunkGateway implements P2pSnapshotChunkGateway {
  const DisabledP2pSnapshotChunkGateway();

  @override
  Future<P2pSnapshotChunk> requestChunk(
    P2pSnapshotManifest manifest,
    int chunkIndex,
  ) {
    return Future<P2pSnapshotChunk>.error(
      const P2pSnapshotChunkTransportException(
        "snapshot 內容傳輸尚未通過安全審查，因此目前停用。",
        isTransient: false,
      ),
    );
  }
}

/// Coordinates resumable, sequential chunk retrieval into quarantine.
///
/// The gateway is intentionally abstract. No production socket implementation
/// is installed until the authenticated transport receives an independent
/// security review. A successful result is verified XML in memory only; this
/// class never writes to the active project file.
class P2pSnapshotDownloadCoordinator {
  final P2pSnapshotChunkGateway _gateway;
  final P2pSnapshotQuarantineStorage _quarantineStorage;
  final int _maxAttemptsPerChunk;
  final Future<void> Function(int attempt) _retryDelay;

  P2pSnapshotQuarantineSession? _session;
  P2pSnapshotManifest? _manifest;
  Future<P2pVerifiedSnapshot>? _inFlight;
  P2pSnapshotDownloadStatus _status = P2pSnapshotDownloadStatus.idle;
  int _generation = 0;
  bool _disposed = false;

  P2pSnapshotDownloadCoordinator({
    required P2pSnapshotChunkGateway gateway,
    required P2pSnapshotQuarantineStorage quarantineStorage,
    int maxAttemptsPerChunk = 3,
    Future<void> Function(int attempt)? retryDelay,
  }) : _gateway = gateway,
       _quarantineStorage = quarantineStorage,
       _maxAttemptsPerChunk = maxAttemptsPerChunk,
       _retryDelay = retryDelay ?? _defaultRetryDelay {
    if (maxAttemptsPerChunk < 1 || maxAttemptsPerChunk > 5) {
      throw ArgumentError.value(
        maxAttemptsPerChunk,
        "maxAttemptsPerChunk",
        "必須介於 1 與 5。",
      );
    }
  }

  P2pSnapshotDownloadStatus get status => _status;

  P2pSnapshotManifest? get manifest => _manifest;

  Set<int> get receivedChunkIndexes =>
      _session?.receivedChunkIndexes ?? const <int>{};

  double get progress => _session?.progress ?? 0;

  Future<P2pVerifiedSnapshot> download(P2pSnapshotManifest manifest) {
    if (_disposed) {
      return Future<P2pVerifiedSnapshot>.error(
        StateError("P2P snapshot download coordinator 已銷毀。"),
      );
    }
    final active = _inFlight;
    if (active != null) {
      if (_manifest == manifest) return active;
      return Future<P2pVerifiedSnapshot>.error(
        StateError("另一個 P2P snapshot download 正在進行。"),
      );
    }
    if (_status == P2pSnapshotDownloadStatus.failed) {
      return Future<P2pVerifiedSnapshot>.error(
        StateError("失敗的 P2P snapshot download 必須先取消再重新開始。"),
      );
    }
    if (_manifest != null && _manifest != manifest) {
      return Future<P2pVerifiedSnapshot>.error(
        StateError("必須先取消目前 download，才能切換 snapshot manifest。"),
      );
    }

    final operation = _runDownload(manifest, ++_generation);
    _inFlight = operation;
    unawaited(
      operation.then<void>(
        (_) => _clearInFlight(operation),
        onError: (Object _, StackTrace _) => _clearInFlight(operation),
      ),
    );
    return operation;
  }

  Future<void> cancel() async {
    if (_status == P2pSnapshotDownloadStatus.cancelled && _session == null) {
      return;
    }
    ++_generation;
    final session = _session;
    _session = null;
    _manifest = null;
    _status = P2pSnapshotDownloadStatus.cancelled;
    if (session != null) await session.cancel();
  }

  Future<void> dispose() {
    if (_disposed) return Future<void>.value();
    _disposed = true;
    ++_generation;
    _session = null;
    _manifest = null;
    if (_status == P2pSnapshotDownloadStatus.downloading ||
        _status == P2pSnapshotDownloadStatus.verifying) {
      _status = P2pSnapshotDownloadStatus.paused;
    }
    return Future<void>.value();
  }

  Future<P2pVerifiedSnapshot> _runDownload(
    P2pSnapshotManifest manifest,
    int generation,
  ) async {
    _manifest = manifest;
    P2pSnapshotQuarantineSession? session = _session;
    try {
      session ??= await P2pSnapshotQuarantineSession.open(
        manifest: manifest,
        storage: _quarantineStorage,
      );
      if (_isCancelled(generation)) {
        if (!_disposed) await session.cancel();
        throw const P2pSnapshotDownloadCancelledException();
      }
      _session = session;
      _status = P2pSnapshotDownloadStatus.downloading;
      for (var index = 0; index < manifest.chunkCount; index++) {
        if (session.receivedChunkIndexes.contains(index)) continue;
        final chunk = await _requestWithRetry(manifest, index, generation);
        if (_isCancelled(generation)) {
          throw const P2pSnapshotDownloadCancelledException();
        }
        await session.addChunk(chunk);
      }
      if (_isCancelled(generation)) {
        throw const P2pSnapshotDownloadCancelledException();
      }
      _status = P2pSnapshotDownloadStatus.verifying;
      final verified = await session.finalize();
      _status = P2pSnapshotDownloadStatus.verified;
      return verified;
    } on P2pSnapshotChunkTransportException catch (error) {
      if (!_isCancelled(generation)) {
        if (error.isTransient) {
          _status = P2pSnapshotDownloadStatus.paused;
        } else {
          if (session != null) await session.cancel();
          _session = null;
          _status = P2pSnapshotDownloadStatus.failed;
        }
      }
      rethrow;
    } on P2pSnapshotDownloadCancelledException {
      rethrow;
    } on FormatException {
      if (session != null) await session.cancel();
      _session = null;
      _status = P2pSnapshotDownloadStatus.failed;
      rethrow;
    } on FileSystemException {
      if (session != null) await session.cancel();
      _session = null;
      _status = P2pSnapshotDownloadStatus.failed;
      rethrow;
    } on P2pSnapshotQuarantineCapacityException {
      if (session != null) await session.cancel();
      _session = null;
      _status = P2pSnapshotDownloadStatus.failed;
      rethrow;
    }
  }

  Future<P2pSnapshotChunk> _requestWithRetry(
    P2pSnapshotManifest manifest,
    int chunkIndex,
    int generation,
  ) async {
    for (var attempt = 1; attempt <= _maxAttemptsPerChunk; attempt++) {
      try {
        return await _gateway.requestChunk(manifest, chunkIndex);
      } on P2pSnapshotChunkTransportException catch (error) {
        if (!error.isTransient || attempt == _maxAttemptsPerChunk) rethrow;
        await _retryDelay(attempt);
        if (_isCancelled(generation)) {
          throw const P2pSnapshotDownloadCancelledException();
        }
      }
    }
    throw StateError("P2P snapshot chunk retry 狀態無效。");
  }

  bool _isCancelled(int generation) => _disposed || generation != _generation;

  void _clearInFlight(Future<P2pVerifiedSnapshot> operation) {
    if (identical(_inFlight, operation)) _inFlight = null;
  }

  static Future<void> _defaultRetryDelay(int attempt) {
    return Future<void>.delayed(Duration(milliseconds: 150 * attempt));
  }
}
