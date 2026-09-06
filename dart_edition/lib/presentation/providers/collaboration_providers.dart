import "dart:async";
import "dart:convert";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:uuid/uuid.dart";

import "../../application/collaboration/project_record_codec.dart";
import "../../application/collaboration/project_collaborative_text_codec.dart";
import "../../bin/settings_manager.dart";
import "../../data/p2p/p2p_endpoint_service.dart";
import "../../domain/collaboration/collaboration_document.dart";
import "../../domain/collaboration/collaboration_operation.dart";
import "../../domain/collaboration/collaboration_protocol.dart";
import "../../domain/collaboration/collaborative_text.dart";
import "../../domain/collaboration/typed_operation_log.dart";
import "../../models/chapter_selection_data.dart";
import "../../models/project_data.dart";
import "../../models/project_file.dart";
import "../../domain/models/p2p_sync_models.dart";
import "editor_coordinator_provider.dart";
import "p2p_sync_providers.dart";
import "project_state_providers.dart";

enum CollaborationConnectionStatus { inactive, connecting, live, error }

sealed class RemoteCursorState {
  final String replicaId;
  final String ipAddress;
  final int anchorOffset;
  final int focusOffset;
  final int presenceSequence;
  final DateTime observedAt;

  const RemoteCursorState({
    required this.replicaId,
    required this.ipAddress,
    required this.anchorOffset,
    required this.focusOffset,
    required this.presenceSequence,
    required this.observedAt,
  });

  String get label => ipAddress;
}

final class RemoteChapterCursorState extends RemoteCursorState {
  final String chapterId;

  const RemoteChapterCursorState({
    required super.replicaId,
    required super.ipAddress,
    required this.chapterId,
    required super.anchorOffset,
    required super.focusOffset,
    required super.presenceSequence,
    required super.observedAt,
  });
}

final class RemoteProjectFieldCursorState extends RemoteCursorState {
  final String fieldId;

  const RemoteProjectFieldCursorState({
    required super.replicaId,
    required super.ipAddress,
    required this.fieldId,
    required super.anchorOffset,
    required super.focusOffset,
    required super.presenceSequence,
    required super.observedAt,
  });
}

final class RemoteProjectTextCursorState extends RemoteCursorState {
  final String documentId;

  const RemoteProjectTextCursorState({
    required super.replicaId,
    required super.ipAddress,
    required this.documentId,
    required super.anchorOffset,
    required super.focusOffset,
    required super.presenceSequence,
    required super.observedAt,
  });
}

final class LocalTextSelectionRebase {
  final String documentId;
  final String expectedText;
  final int anchorOffset;
  final int focusOffset;
  final int revision;

  const LocalTextSelectionRebase({
    required this.documentId,
    required this.expectedText,
    required this.anchorOffset,
    required this.focusOffset,
    required this.revision,
  });
}

sealed class _LocalCursorLocation {
  const _LocalCursorLocation();
}

final class _LocalChapterCursorLocation extends _LocalCursorLocation {
  final String chapterId;
  final int anchorOffset;
  final int focusOffset;

  const _LocalChapterCursorLocation({
    required this.chapterId,
    required this.anchorOffset,
    required this.focusOffset,
  });
}

final class _LocalProjectFieldCursorLocation extends _LocalCursorLocation {
  final String fieldId;
  final int anchorOffset;
  final int focusOffset;

  const _LocalProjectFieldCursorLocation({
    required this.fieldId,
    required this.anchorOffset,
    required this.focusOffset,
  });
}

final class _LocalProjectTextCursorLocation extends _LocalCursorLocation {
  final String documentId;
  final int anchorOffset;
  final int focusOffset;

  const _LocalProjectTextCursorLocation({
    required this.documentId,
    required this.anchorOffset,
    required this.focusOffset,
  });
}

final class CollaborationState {
  final CollaborationConnectionStatus connectionStatus;
  final CollaborationDocument? document;
  final Map<String, RemoteCursorState> remoteCursors;
  final LocalTextSelectionRebase? localSelectionRebase;
  final List<ProjectDataRecordOperation> unappliedProjectOperations;
  final String? errorMessage;

  const CollaborationState({
    this.connectionStatus = CollaborationConnectionStatus.inactive,
    this.document,
    this.remoteCursors = const <String, RemoteCursorState>{},
    this.localSelectionRebase,
    this.unappliedProjectOperations = const <ProjectDataRecordOperation>[],
    this.errorMessage,
  });

  CollaborationState copyWith({
    CollaborationConnectionStatus? connectionStatus,
    Object? document = _unset,
    Map<String, RemoteCursorState>? remoteCursors,
    Object? localSelectionRebase = _unset,
    List<ProjectDataRecordOperation>? unappliedProjectOperations,
    Object? errorMessage = _unset,
  }) {
    return CollaborationState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      document: identical(document, _unset)
          ? this.document
          : document as CollaborationDocument?,
      remoteCursors: Map<String, RemoteCursorState>.unmodifiable(
        remoteCursors ?? this.remoteCursors,
      ),
      localSelectionRebase: identical(localSelectionRebase, _unset)
          ? this.localSelectionRebase
          : localSelectionRebase as LocalTextSelectionRebase?,
      unappliedProjectOperations: List<ProjectDataRecordOperation>.unmodifiable(
        unappliedProjectOperations ?? this.unappliedProjectOperations,
      ),
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _unset = Object();

class CollaborationNotifier extends Notifier<CollaborationState> {
  static const Duration _tickInterval = Duration(milliseconds: 80);
  static const Duration _idleExchangeInterval = Duration(milliseconds: 750);
  static const Duration _cursorExpiry = Duration(seconds: 5);

  final String _ephemeralReplicaId = const Uuid().v4();
  final Map<String, String> _checkpointTexts = <String, String>{};
  final Map<String, String> _checkpointProjectTexts = <String, String>{};
  final Map<String, String> _capturedProjectTexts = <String, String>{};
  final Map<ProjectRecordKey, ProjectRecordOperation> _projectRecords =
      <ProjectRecordKey, ProjectRecordOperation>{};
  final Map<String, int> _remoteAcknowledgedSequences = <String, int>{};
  Timer? _timer;
  StreamSubscription<P2pInboundCollaborationBatch>? _inboundSubscription;
  bool _exchangeInProgress = false;
  bool _disposed = false;
  int _presenceSequence = 0;
  int _selectionRebaseRevision = 0;
  _LocalCursorLocation? _localCursorLocation;
  CollaboratorPresence? _localPresence;
  DateTime? _lastExchangeAt;
  DateTime? _lastLocalActivityAt;
  String? _operationBootstrapProjectUuid;
  String? _preparedOperationBootstrapProjectUuid;

  P2pEndpointService get _endpoint => ref.read(p2pEndpointServiceProvider);

  @override
  CollaborationState build() {
    final endpoint = ref.watch(p2pEndpointServiceProvider);
    _inboundSubscription = endpoint.inboundCollaborationBatches.listen(
      (event) => _applyRemoteBatch(event.batch),
      onError: (Object error, StackTrace stackTrace) {
        if (_disposed) return;
        state = state.copyWith(
          connectionStatus: CollaborationConnectionStatus.error,
          errorMessage: "即時協作接收失敗：$error",
        );
      },
    );
    _timer = Timer.periodic(_tickInterval, (_) => unawaited(_tick()));
    ref.listen<P2pSyncState>(p2pSyncProvider, (previous, next) {
      _rememberOperationBootstrapRole(next);
      if (!next.hasAuthenticatedTransport) {
        _remoteAcknowledgedSequences.clear();
        _localPresence = null;
        endpoint.updateLocalCollaborationBatch(null);
        if (state.connectionStatus != CollaborationConnectionStatus.inactive) {
          state = state.copyWith(
            connectionStatus: CollaborationConnectionStatus.inactive,
            remoteCursors: const <String, RemoteCursorState>{},
          );
        }
        return;
      }
      _ensureInMemoryRemoteProject(
        next,
        resetExistingMemoryProject: previous?.hasAuthenticatedTransport != true,
      );
      _ensureAuthenticatedReplica(next);
      _prepareOperationBootstrapIfNeeded(next);
      _publishLocalBatch();
    });
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
      _timer = null;
      unawaited(_inboundSubscription?.cancel());
      _inboundSubscription = null;
      endpoint.updateLocalCollaborationBatch(null);
    });
    return const CollaborationState();
  }

  void openProject(ProjectData data) {
    final p2pState = ref.read(p2pSyncProvider);
    final replicaId = p2pState.localIdentity?.deviceId ?? _ephemeralReplicaId;
    _checkpointTexts
      ..clear()
      ..addEntries(
        ChapterTree.chaptersDepthFirst(data.segmentsData).map(
          (location) => MapEntry(
            location.chapter.chapterUUID,
            location.chapter.chapterContent,
          ),
        ),
      );
    _remoteAcknowledgedSequences.clear();
    _checkpointProjectTexts
      ..clear()
      ..addAll(ProjectCollaborativeTextCodec.snapshot(data));
    _capturedProjectTexts
      ..clear()
      ..addAll(_checkpointProjectTexts);
    _projectRecords
      ..clear()
      ..addAll(ProjectRecordCodec.snapshot(data, omitCollaborativeText: true));
    _localCursorLocation = null;
    _localPresence = null;
    _presenceSequence = 0;
    _preparedOperationBootstrapProjectUuid = null;
    state = CollaborationState(
      document: CollaborationDocument.seeded(
        projectUuid: data.projectUUID,
        replicaId: replicaId,
        chapterTexts: _checkpointTexts,
        projectTexts: _checkpointProjectTexts,
      ),
    );
    if (p2pState.hasAuthenticatedTransport) {
      _ensureAuthenticatedReplica(p2pState);
      _publishLocalBatch();
    }
  }

  void closeProject() {
    _checkpointTexts.clear();
    _checkpointProjectTexts.clear();
    _capturedProjectTexts.clear();
    _projectRecords.clear();
    _remoteAcknowledgedSequences.clear();
    _localCursorLocation = null;
    _localPresence = null;
    _operationBootstrapProjectUuid = null;
    _preparedOperationBootstrapProjectUuid = null;
    _endpoint.updateLocalCollaborationBatch(null);
    state = const CollaborationState();
  }

  void recordLocalTextEdit({
    required String chapterId,
    required CollaborativeTextDelta delta,
    required int anchorOffset,
    required int focusOffset,
  }) {
    var current = state.document;
    if (current == null) return;
    if (current.chapter(chapterId) == null) {
      final location = ChapterTree.findChapter(
        ref.read(segmentsDataProvider),
        chapterId: chapterId,
      );
      if (location == null) return;
      current = current.ensureChapter(
        chapterId: chapterId,
        initialText: location.chapter.chapterContent,
      );
    }
    if (current.chapterText(chapterId)?.length != delta.baseTextLength) {
      return;
    }
    final edited = current.createLocalTextDelta(
      documentId: chapterId,
      delta: delta,
    );
    if (!identical(edited, state.document)) {
      state = state.copyWith(document: edited, errorMessage: null);
      _lastLocalActivityAt = DateTime.now();
    }
    updateLocalCursor(
      chapterId: chapterId,
      anchorOffset: anchorOffset,
      focusOffset: focusOffset,
    );
  }

  void recordLocalProjectTextEdit({
    required String documentId,
    required CollaborativeTextDelta delta,
    required int anchorOffset,
    required int focusOffset,
  }) {
    var current = state.document;
    if (current == null ||
        !ProjectCollaborativeTextCodec.isProjectTextDocumentId(documentId)) {
      return;
    }
    current = current.ensureProjectText(documentId: documentId);
    if (current.text(documentId)?.length != delta.baseTextLength) {
      return;
    }
    final next = current.createLocalTextDelta(
      documentId: documentId,
      delta: delta,
    );
    if (!identical(next, state.document)) {
      state = state.copyWith(document: next, errorMessage: null);
      _lastLocalActivityAt = DateTime.now();
    }
    updateLocalProjectTextCursor(
      documentId: documentId,
      anchorOffset: anchorOffset,
      focusOffset: focusOffset,
    );
  }

  void recordLocalProjectOperation(ProjectRecordOperation operation) {
    final current = state.document;
    if (current == null) return;
    state = state.copyWith(
      document: current.createLocalProjectOperation(operation),
      errorMessage: null,
    );
    _lastLocalActivityAt = DateTime.now();
    _publishLocalBatch();
  }

  void captureProjectData(ProjectData data) {
    var document = state.document;
    if (document == null ||
        document.projectUuid != data.projectUUID.toLowerCase()) {
      return;
    }
    for (final location in ChapterTree.chaptersDepthFirst(data.segmentsData)) {
      document = document!.ensureChapter(
        chapterId: location.chapter.chapterUUID,
        initialText: location.chapter.chapterContent,
      );
    }
    final nextProjectTexts = ProjectCollaborativeTextCodec.snapshot(data);
    for (final entry in nextProjectTexts.entries) {
      document = document!.ensureProjectText(
        documentId: entry.key,
        initialText: entry.value,
      );
      if (_capturedProjectTexts[entry.key] != entry.value &&
          document.text(entry.key) != entry.value) {
        document = document.createLocalTextEdit(
          documentId: entry.key,
          nextText: entry.value,
        );
      }
    }
    _capturedProjectTexts
      ..clear()
      ..addAll(nextProjectTexts);
    final nextRecords = ProjectRecordCodec.snapshot(
      data,
      omitCollaborativeText: true,
    );
    final operations = ProjectRecordCodec.diff(_projectRecords, nextRecords);
    _projectRecords
      ..clear()
      ..addAll(nextRecords);
    var nextDocument = document!;
    for (final operation in operations) {
      nextDocument = nextDocument.createLocalProjectOperation(operation);
    }
    if (identical(nextDocument, state.document) && operations.isEmpty) return;
    state = state.copyWith(document: nextDocument, errorMessage: null);
    _lastLocalActivityAt = DateTime.now();
    _publishLocalBatch();
  }

  void updateLocalCursor({
    required String chapterId,
    required int anchorOffset,
    required int focusOffset,
  }) {
    var document = state.document;
    if (document == null) return;
    var chapter = document.chapter(chapterId);
    if (chapter == null) {
      final location = ChapterTree.findChapter(
        ref.read(segmentsDataProvider),
        chapterId: chapterId,
      );
      if (location == null) return;
      document = document.ensureChapter(
        chapterId: chapterId,
        initialText: location.chapter.chapterContent,
      );
      chapter = document.chapter(chapterId);
      state = state.copyWith(document: document);
    }
    if (chapter == null) return;
    _localCursorLocation = _LocalChapterCursorLocation(
      chapterId: chapterId,
      anchorOffset: anchorOffset,
      focusOffset: focusOffset,
    );
    final p2pState = ref.read(p2pSyncProvider);
    final ipAddress = p2pState.localAddresses.isEmpty
        ? "127.0.0.1"
        : p2pState.localAddresses.first;
    _presenceSequence += 1;
    _localPresence = CollaboratorPresence(
      replicaId: document.replicaId,
      ipAddress: ipAddress,
      target: ChapterTextCursorTarget(
        chapterId: chapterId,
        anchor: chapter.anchorAtOffset(anchorOffset),
        focus: chapter.anchorAtOffset(focusOffset),
      ),
      presenceSequence: _presenceSequence,
      sentAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
    _lastLocalActivityAt = DateTime.now();
    _publishLocalBatch();
  }

  void updateLocalProjectFieldCursor({
    required String fieldId,
    required int anchorOffset,
    required int focusOffset,
  }) {
    final document = state.document;
    final normalizedFieldId = fieldId.trim();
    if (document == null ||
        normalizedFieldId.isEmpty ||
        anchorOffset < 0 ||
        focusOffset < 0) {
      return;
    }
    _localCursorLocation = _LocalProjectFieldCursorLocation(
      fieldId: normalizedFieldId,
      anchorOffset: anchorOffset,
      focusOffset: focusOffset,
    );
    final p2pState = ref.read(p2pSyncProvider);
    final ipAddress = p2pState.localAddresses.isEmpty
        ? "127.0.0.1"
        : p2pState.localAddresses.first;
    _presenceSequence += 1;
    _localPresence = CollaboratorPresence(
      replicaId: document.replicaId,
      ipAddress: ipAddress,
      target: ProjectFieldCursorTarget(
        fieldId: normalizedFieldId,
        anchorOffset: anchorOffset,
        focusOffset: focusOffset,
      ),
      presenceSequence: _presenceSequence,
      sentAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
    _lastLocalActivityAt = DateTime.now();
    _publishLocalBatch();
  }

  void updateLocalProjectTextCursor({
    required String documentId,
    required int anchorOffset,
    required int focusOffset,
  }) {
    var document = state.document;
    if (document == null ||
        !ProjectCollaborativeTextCodec.isProjectTextDocumentId(documentId)) {
      return;
    }
    var textDocument = document.textDocument(documentId);
    if (textDocument == null) {
      document = document.ensureProjectText(documentId: documentId);
      textDocument = document.textDocument(documentId);
      state = state.copyWith(document: document);
    }
    if (textDocument == null) return;
    _localCursorLocation = _LocalProjectTextCursorLocation(
      documentId: documentId,
      anchorOffset: anchorOffset,
      focusOffset: focusOffset,
    );
    final p2pState = ref.read(p2pSyncProvider);
    final ipAddress = p2pState.localAddresses.isEmpty
        ? "127.0.0.1"
        : p2pState.localAddresses.first;
    _presenceSequence += 1;
    _localPresence = CollaboratorPresence(
      replicaId: document.replicaId,
      ipAddress: ipAddress,
      target: ProjectTextCursorTarget(
        documentId: documentId,
        anchor: textDocument.anchorAtOffset(anchorOffset),
        focus: textDocument.anchorAtOffset(focusOffset),
      ),
      presenceSequence: _presenceSequence,
      sentAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
    _lastLocalActivityAt = DateTime.now();
    _publishLocalBatch();
  }

  void clearLocalProjectFieldCursor(String fieldId) {
    final location = _localCursorLocation;
    if (location is! _LocalProjectFieldCursorLocation ||
        location.fieldId != fieldId) {
      return;
    }
    _localCursorLocation = null;
    _localPresence = null;
    _lastLocalActivityAt = DateTime.now();
    _publishLocalBatch();
  }

  void clearLocalProjectTextCursor(String documentId) {
    final location = _localCursorLocation;
    if (location is! _LocalProjectTextCursorLocation ||
        location.documentId != documentId) {
      return;
    }
    _localCursorLocation = null;
    _localPresence = null;
    _lastLocalActivityAt = DateTime.now();
    _publishLocalBatch();
  }

  void consumeLocalSelectionRebase(int revision) {
    if (state.localSelectionRebase?.revision != revision) return;
    state = state.copyWith(localSelectionRebase: null);
  }

  Future<void> _tick() async {
    if (_disposed || _exchangeInProgress) return;
    _pruneStaleCursors();
    final p2pState = ref.read(p2pSyncProvider);
    _rememberOperationBootstrapRole(p2pState);
    _ensureInMemoryRemoteProject(p2pState);
    var document = state.document;
    final endpoint = p2pState.reachablePeer;
    if (document == null ||
        endpoint == null ||
        !p2pState.hasAuthenticatedTransport ||
        p2pState.sessionProjectUuid != document.projectUuid) {
      return;
    }
    _ensureAuthenticatedReplica(p2pState);
    _prepareOperationBootstrapIfNeeded(p2pState);
    document = state.document;
    if (document == null) return;
    final now = DateTime.now();
    if (_endpoint.hasActiveCollaborationStream) {
      if (_lastExchangeAt == null ||
          now.difference(_lastExchangeAt!) >= _idleExchangeInterval) {
        switch (_localCursorLocation) {
          case final _LocalChapterCursorLocation location:
            updateLocalCursor(
              chapterId: location.chapterId,
              anchorOffset: location.anchorOffset,
              focusOffset: location.focusOffset,
            );
          case final _LocalProjectFieldCursorLocation location:
            updateLocalProjectFieldCursor(
              fieldId: location.fieldId,
              anchorOffset: location.anchorOffset,
              focusOffset: location.focusOffset,
            );
          case final _LocalProjectTextCursorLocation location:
            updateLocalProjectTextCursor(
              documentId: location.documentId,
              anchorOffset: location.anchorOffset,
              focusOffset: location.focusOffset,
            );
          case null:
            _publishLocalBatch();
        }
        _lastExchangeAt = now;
      }
      if (state.connectionStatus != CollaborationConnectionStatus.live) {
        state = state.copyWith(
          connectionStatus: CollaborationConnectionStatus.live,
          errorMessage: null,
        );
      }
      return;
    }
    final hasPendingOperations = document
        .operationsAfter(_remoteAcknowledgedSequences, limit: 1)
        .isNotEmpty;
    final recentlyActive =
        _lastLocalActivityAt != null &&
        now.difference(_lastLocalActivityAt!) < _idleExchangeInterval;
    if (!hasPendingOperations &&
        !recentlyActive &&
        _lastExchangeAt != null &&
        now.difference(_lastExchangeAt!) < _idleExchangeInterval) {
      return;
    }

    _exchangeInProgress = true;
    if (state.connectionStatus != CollaborationConnectionStatus.live) {
      state = state.copyWith(
        connectionStatus: CollaborationConnectionStatus.connecting,
      );
    }
    try {
      final localBatch = _buildLocalBatch();
      if (localBatch == null) return;
      _endpoint.updateLocalCollaborationBatch(localBatch);
      final streamOpened = await _endpoint.openCollaborationStream(endpoint);
      if (streamOpened) {
        _lastExchangeAt = DateTime.now();
        if (!_disposed) {
          state = state.copyWith(
            connectionStatus: CollaborationConnectionStatus.live,
            errorMessage: null,
          );
        }
        return;
      }
      final remoteBatch = await _endpoint.negotiateCollaborationBatch(
        endpoint,
        localBatch,
      );
      _lastExchangeAt = DateTime.now();
      _applyRemoteBatch(remoteBatch);
      if (!_disposed) {
        state = state.copyWith(
          connectionStatus: CollaborationConnectionStatus.live,
          errorMessage: null,
        );
      }
    } on Exception catch (error) {
      if (!_disposed) {
        state = state.copyWith(
          connectionStatus: CollaborationConnectionStatus.error,
          errorMessage: "即時協作交換失敗：$error",
        );
      }
    } finally {
      _exchangeInProgress = false;
    }
  }

  void _applyRemoteBatch(CollaborationSyncBatch batch) {
    if (_disposed) return;
    if (state.document == null) {
      _ensureInMemoryRemoteProject(ref.read(p2pSyncProvider));
    }
    final document = state.document;
    if (document == null || batch.projectUuid != document.projectUuid) return;
    for (final entry in batch.acknowledgedSequences.entries) {
      final current = _remoteAcknowledgedSequences[entry.key] ?? 0;
      if (entry.value > current) {
        _remoteAcknowledgedSequences[entry.key] = entry.value;
      }
    }
    final result = document.applyBatch(batch);
    var mergedDocument = result.document;
    LocalTextSelectionRebase? localSelectionRebase;
    final localPresenceTarget = _localPresence?.target;
    final localTextTarget = switch (localPresenceTarget) {
      final ChapterTextCursorTarget target => (
        documentId: target.chapterId,
        anchor: target.anchor,
        focus: target.focus,
        isChapter: true,
      ),
      final ProjectTextCursorTarget target => (
        documentId: target.documentId,
        anchor: target.anchor,
        focus: target.focus,
        isChapter: false,
      ),
      _ => null,
    };
    if (localTextTarget != null &&
        result.changedTextDocumentIds.contains(localTextTarget.documentId)) {
      final rebasedText = mergedDocument.textDocument(
        localTextTarget.documentId,
      );
      if (rebasedText != null) {
        final anchorOffset = rebasedText.resolveAnchor(localTextTarget.anchor);
        final focusOffset = rebasedText.resolveAnchor(localTextTarget.focus);
        _localCursorLocation = localTextTarget.isChapter
            ? _LocalChapterCursorLocation(
                chapterId: localTextTarget.documentId,
                anchorOffset: anchorOffset,
                focusOffset: focusOffset,
              )
            : _LocalProjectTextCursorLocation(
                documentId: localTextTarget.documentId,
                anchorOffset: anchorOffset,
                focusOffset: focusOffset,
              );
        _selectionRebaseRevision += 1;
        localSelectionRebase = LocalTextSelectionRebase(
          documentId: localTextTarget.documentId,
          expectedText: rebasedText.text,
          anchorOffset: anchorOffset,
          focusOffset: focusOffset,
          revision: _selectionRebaseRevision,
        );
      }
    }
    final nextRemoteCursors = Map<String, RemoteCursorState>.from(
      state.remoteCursors,
    );
    final presence = batch.presence;
    if (presence != null) {
      final existing = nextRemoteCursors[presence.replicaId];
      if (existing == null ||
          presence.presenceSequence > existing.presenceSequence) {
        switch (presence.target) {
          case final ChapterTextCursorTarget target:
            var chapter = mergedDocument.chapter(target.chapterId);
            if (chapter == null) {
              mergedDocument = mergedDocument.ensureChapter(
                chapterId: target.chapterId,
              );
              chapter = mergedDocument.chapter(target.chapterId);
            }
            if (chapter != null) {
              nextRemoteCursors[presence.replicaId] = RemoteChapterCursorState(
                replicaId: presence.replicaId,
                ipAddress: presence.ipAddress,
                chapterId: target.chapterId,
                anchorOffset: chapter.resolveAnchor(target.anchor),
                focusOffset: chapter.resolveAnchor(target.focus),
                presenceSequence: presence.presenceSequence,
                observedAt: DateTime.now(),
              );
            }
          case final ProjectFieldCursorTarget target:
            nextRemoteCursors[presence.replicaId] =
                RemoteProjectFieldCursorState(
                  replicaId: presence.replicaId,
                  ipAddress: presence.ipAddress,
                  fieldId: target.fieldId,
                  anchorOffset: target.anchorOffset,
                  focusOffset: target.focusOffset,
                  presenceSequence: presence.presenceSequence,
                  observedAt: DateTime.now(),
                );
          case final ProjectTextCursorTarget target:
            var textDocument = mergedDocument.textDocument(target.documentId);
            if (textDocument == null &&
                ProjectCollaborativeTextCodec.isProjectTextDocumentId(
                  target.documentId,
                )) {
              mergedDocument = mergedDocument.ensureProjectText(
                documentId: target.documentId,
              );
              textDocument = mergedDocument.textDocument(target.documentId);
            }
            if (textDocument != null) {
              nextRemoteCursors[presence.replicaId] =
                  RemoteProjectTextCursorState(
                    replicaId: presence.replicaId,
                    ipAddress: presence.ipAddress,
                    documentId: target.documentId,
                    anchorOffset: textDocument.resolveAnchor(target.anchor),
                    focusOffset: textDocument.resolveAnchor(target.focus),
                    presenceSequence: presence.presenceSequence,
                    observedAt: DateTime.now(),
                  );
            }
        }
      }
    }
    var nextState = state.copyWith(
      document: mergedDocument,
      remoteCursors: nextRemoteCursors,
    );
    if (localSelectionRebase != null) {
      nextState = nextState.copyWith(
        localSelectionRebase: localSelectionRebase,
      );
    }
    state = nextState;
    final hasMaterializedChanges =
        result.appliedProjectOperations.isNotEmpty ||
        result.changedTextDocumentIds.isNotEmpty;
    final coordinator = ref.read(editorCoordinatorProvider.notifier);
    final beganApplying =
        hasMaterializedChanges && coordinator.beginApplyingProjectData();
    try {
      if (result.appliedProjectOperations.isNotEmpty) {
        final materialized = _applyProjectOperations(
          result.appliedProjectOperations,
          mergedDocument,
        );
        final incomingIds = result.appliedProjectOperations
            .map((operation) => operation.id)
            .toSet();
        if (materialized) {
          final touchedRecords = result.appliedProjectOperations
              .map(
                (operation) => ProjectRecordKey(
                  kind: operation.record.recordKind,
                  recordId: operation.record.recordId,
                ),
              )
              .toSet();
          state = state.copyWith(
            unappliedProjectOperations: state.unappliedProjectOperations
                .where(
                  (operation) => !touchedRecords.contains(
                    ProjectRecordKey(
                      kind: operation.record.recordKind,
                      recordId: operation.record.recordId,
                    ),
                  ),
                )
                .toList(growable: false),
          );
        } else {
          state = state.copyWith(
            unappliedProjectOperations: <ProjectDataRecordOperation>[
              ...state.unappliedProjectOperations.where(
                (operation) => !incomingIds.contains(operation.id),
              ),
              ...result.appliedProjectOperations,
            ],
          );
        }
      }
      for (final documentId in result.changedTextDocumentIds) {
        if (ProjectCollaborativeTextCodec.isProjectTextDocumentId(documentId)) {
          _applyCollaborativeProjectText(documentId, mergedDocument);
        } else {
          _applyChapterTextToProject(documentId, mergedDocument);
        }
      }
      _reconcileEditorSelectionAfterRemoteBootstrap(batch, mergedDocument);
    } finally {
      if (beganApplying) coordinator.endApplyingProjectData();
    }
    if (hasMaterializedChanges) {
      coordinator.markAsModified();
    }
    _publishLocalBatch();
  }

  void _reconcileEditorSelectionAfterRemoteBootstrap(
    CollaborationSyncBatch batch,
    CollaborationDocument document,
  ) {
    final advertisedSequence =
        batch.acknowledgedSequences[batch.senderReplicaId];
    final appliedSequence =
        document.acknowledgedSequences[batch.senderReplicaId] ?? 0;
    if (advertisedSequence == null || appliedSequence < advertisedSequence) {
      return;
    }

    final segments = ref.read(segmentsDataProvider);
    final selection = ref.read(editorSelectionProvider);
    final selectedChapter = selection.selectedChapID == null
        ? null
        : ChapterTree.findChapter(
            segments,
            folderId: selection.selectedSegID,
            chapterId: selection.selectedChapID!,
          );
    if (selectedChapter != null) return;

    final firstChapter = ChapterTree.firstChapter(segments);
    if (firstChapter == null) {
      ref
          .read(editorSelectionProvider.notifier)
          .setSelectionAndCursor(
            selectedSegID: null,
            selectedChapID: null,
            cursorOffset: 0,
          );
      if (ref.read(editorContentProvider).isNotEmpty) {
        ref.read(editorContentProvider.notifier).setContent("");
      }
      return;
    }

    ref
        .read(editorCoordinatorProvider.notifier)
        .navigateToChapter(firstChapter.chapter.chapterUUID);
  }

  bool _applyProjectOperations(
    List<ProjectDataRecordOperation> operations,
    CollaborationDocument document,
  ) {
    final previousRecords = Map<ProjectRecordKey, ProjectRecordOperation>.from(
      _projectRecords,
    );
    final changedKinds = <ProjectRecordKind>{};
    for (final operation in operations) {
      final record = operation.record;
      final key = ProjectRecordKey(
        kind: record.recordKind,
        recordId: record.recordId,
      );
      final materialized = document.projectOperationLog.lookup(
        record.recordKind,
        record.recordId,
      );
      if (materialized == null || materialized.operationId != operation.id) {
        continue;
      }
      if (materialized.isRemoved) {
        _projectRecords.remove(key);
      } else {
        _projectRecords[key] = materialized.operation;
      }
      changedKinds.add(record.recordKind);
    }
    if (changedKinds.isEmpty) return true;
    final projectTextValues = <String, String>{
      for (final entry in document.projectTexts.entries)
        entry.key: entry.value.text,
    };
    try {
      if (changedKinds.contains(ProjectRecordKind.baseInfo)) {
        ref
            .read(baseInfoDataProvider.notifier)
            .setBaseInfoData(
              ProjectRecordCodec.decodeBaseInfo(_projectRecords),
            );
      }
      if (changedKinds.contains(ProjectRecordKind.chapterFolder) ||
          changedKinds.contains(ProjectRecordKind.chapterMetadata)) {
        final chapterTexts = <String, String>{
          for (final entry in document.chapters.entries)
            entry.key: entry.value.text,
        };
        ref
            .read(segmentsDataProvider.notifier)
            .setSegmentsData(
              ProjectRecordCodec.decodeSegments(_projectRecords, chapterTexts),
            );
      }
      if (changedKinds.contains(ProjectRecordKind.outlineStoryline) ||
          changedKinds.contains(ProjectRecordKind.outlineEvent) ||
          changedKinds.contains(ProjectRecordKind.outlineScene)) {
        ref
            .read(outlineDataProvider.notifier)
            .setOutlineData(
              ProjectCollaborativeTextCodec.overlayOutline(
                ProjectRecordCodec.decodeOutline(_projectRecords),
                projectTextValues,
              ),
            );
      }
      if (changedKinds.contains(ProjectRecordKind.foreshadow)) {
        ref
            .read(foreshadowDataProvider.notifier)
            .setForeshadowData(
              ProjectRecordCodec.decodeForeshadows(_projectRecords),
            );
      }
      if (changedKinds.contains(ProjectRecordKind.updatePlan)) {
        ref
            .read(updatePlanDataProvider.notifier)
            .setUpdatePlanData(
              ProjectRecordCodec.decodeUpdatePlans(_projectRecords),
            );
      }
      if (changedKinds.contains(ProjectRecordKind.worldNode)) {
        ref
            .read(worldSettingsDataProvider.notifier)
            .setWorldSettingsData(
              ProjectCollaborativeTextCodec.overlayWorldSettings(
                ProjectRecordCodec.decodeWorldSettings(_projectRecords),
                projectTextValues,
              ),
            );
      }
      if (changedKinds.contains(ProjectRecordKind.character)) {
        ref
            .read(characterDataProvider.notifier)
            .setCharacterData(
              ProjectCollaborativeTextCodec.overlayCharacters(
                ProjectRecordCodec.decodeCharacters(_projectRecords),
                projectTextValues,
              ),
            );
      }
      if (changedKinds.contains(ProjectRecordKind.characterState)) {
        ref
            .read(characterStatesProvider.notifier)
            .setCharacterStates(
              ProjectRecordCodec.decodeCharacterStates(_projectRecords),
            );
      }
      if (changedKinds.contains(ProjectRecordKind.characterStateBaseline)) {
        ref
            .read(characterStateBaselinesProvider.notifier)
            .setBaselines(
              ProjectRecordCodec.decodeCharacterBaselines(_projectRecords),
            );
      }
      if (changedKinds.contains(ProjectRecordKind.characterStateChange)) {
        ref
            .read(characterStateChangesProvider.notifier)
            .setChanges(
              ProjectRecordCodec.decodeCharacterChanges(_projectRecords),
            );
      }
      if (changedKinds.contains(ProjectRecordKind.timelineGrid) ||
          changedKinds.contains(ProjectRecordKind.timelineTrack) ||
          changedKinds.contains(ProjectRecordKind.timelinePlacement)) {
        ref
            .read(timelineDocumentProvider.notifier)
            .setDocument(ProjectRecordCodec.decodeTimeline(_projectRecords));
      }
      if (changedKinds.contains(ProjectRecordKind.outlineChapterLink)) {
        ref
            .read(outlineChapterLinksProvider.notifier)
            .setLinks(
              ProjectRecordCodec.decodeOutlineChapterLinks(_projectRecords),
            );
      }
      return true;
    } on FormatException catch (error) {
      _projectRecords
        ..clear()
        ..addAll(previousRecords);
      state = state.copyWith(
        connectionStatus: CollaborationConnectionStatus.error,
        errorMessage: "遠端 typed ProjectData operation 無效：$error",
      );
      return false;
    }
  }

  void _applyChapterTextToProject(
    String chapterId,
    CollaborationDocument document,
  ) {
    final content = document.chapterText(chapterId);
    if (content == null) return;
    final segments = ref.read(segmentsDataProvider);
    final location = ChapterTree.findChapter(segments, chapterId: chapterId);
    if (location == null) return;
    ref
        .read(segmentsDataProvider.notifier)
        .updateChapterContent(
          segmentID: location.folder.segmentUUID,
          chapterID: chapterId,
          content: content,
        );
    final selectedChapterId = ref.read(editorSelectionProvider).selectedChapID;
    if (selectedChapterId == chapterId &&
        ref.read(editorContentProvider) != content) {
      ref.read(editorContentProvider.notifier).setContent(content);
    }
  }

  void _applyCollaborativeProjectText(
    String documentId,
    CollaborationDocument document,
  ) {
    final text = document.text(documentId);
    final address = ProjectCollaborativeTextCodec.tryParse(documentId);
    if (text == null || address == null) return;
    switch (address.kind) {
      case ProjectCollaborativeTextKind.outlineStoryline:
      case ProjectCollaborativeTextKind.outlineEvent:
      case ProjectCollaborativeTextKind.outlineScene:
        final current = ref.read(outlineDataProvider);
        final next = ProjectCollaborativeTextCodec.applyToOutline(
          current,
          documentId,
          text,
        );
        if (!identical(current, next)) {
          ref.read(outlineDataProvider.notifier).setOutlineData(next);
        }
      case ProjectCollaborativeTextKind.character:
      case ProjectCollaborativeTextKind.characterCustomField:
        final current = ref.read(characterDataProvider);
        final next = ProjectCollaborativeTextCodec.applyToCharacters(
          current,
          documentId,
          text,
        );
        if (!identical(current, next)) {
          ref.read(characterDataProvider.notifier).setCharacterData(next);
        }
      case ProjectCollaborativeTextKind.worldNode:
      case ProjectCollaborativeTextKind.worldCustomValue:
        final current = ref.read(worldSettingsDataProvider);
        final next = ProjectCollaborativeTextCodec.applyToWorldSettings(
          current,
          documentId,
          text,
        );
        if (!identical(current, next)) {
          ref
              .read(worldSettingsDataProvider.notifier)
              .setWorldSettingsData(next);
        }
    }
  }

  void _rememberOperationBootstrapRole(P2pSyncState p2pState) {
    final sessionUuid = p2pState.sessionProjectUuid;
    if (sessionUuid == null) {
      _operationBootstrapProjectUuid = null;
      _preparedOperationBootstrapProjectUuid = null;
      return;
    }
    final remoteOffer = p2pState.remoteProjectOffer;
    if (p2pState.selectedProjectSource == P2pProjectSource.local &&
        (remoteOffer?.hasProject == false ||
            remoteOffer?.projectUuid == sessionUuid)) {
      _operationBootstrapProjectUuid = sessionUuid;
    }
  }

  void _ensureInMemoryRemoteProject(
    P2pSyncState p2pState, {
    bool resetExistingMemoryProject = false,
  }) {
    if (!p2pState.hasAuthenticatedTransport) return;
    final sessionUuid = p2pState.sessionProjectUuid;
    final remoteOffer = p2pState.remoteProjectOffer;
    final currentFile = ref.read(currentProjectFileProvider);
    final hasPersistentLocation =
        (currentFile?.filePath?.trim().isNotEmpty ?? false) ||
        (currentFile?.uri?.trim().isNotEmpty ?? false);
    final shouldResetMemoryProject =
        resetExistingMemoryProject &&
        currentFile != null &&
        !hasPersistentLocation &&
        state.document?.projectUuid == sessionUuid;
    if (sessionUuid == null ||
        p2pState.selectedProjectSource != P2pProjectSource.remote ||
        remoteOffer == null ||
        remoteOffer.projectUuid != sessionUuid ||
        (state.document != null && !shouldResetMemoryProject) ||
        (currentFile != null && !shouldResetMemoryProject)) {
      return;
    }

    final data = ProjectData.collaborationShell(projectUUID: sessionUuid);
    final coordinator = ref.read(editorCoordinatorProvider.notifier);
    final mode =
        ref.read(editorCoordinatorProvider).wordCountMode ??
        WordCountMode.wordsAndCharacters;
    final initialState = coordinator.calculateInitialState(data, mode);
    final beganApplying = coordinator.beginApplyingProjectData();
    try {
      coordinator.applyProjectData(data: data, initialState: initialState);
    } finally {
      if (beganApplying) coordinator.endApplyingProjectData();
    }
    openProject(data);
    ref
        .read(currentProjectFileProvider.notifier)
        .setCurrentProjectFile(
          ProjectFile(
            fileName:
                currentFile?.fileName ?? remoteOffer.fileName ?? "即時協作.mnproj",
            filePath: null,
            content: "",
          ),
        );
    coordinator.resetAfterProjectLoaded();
    coordinator.markAsModified();
  }

  void _prepareOperationBootstrapIfNeeded(P2pSyncState p2pState) {
    final projectUuid = _operationBootstrapProjectUuid;
    final current = state.document;
    if (!p2pState.hasAuthenticatedTransport ||
        projectUuid == null ||
        current == null ||
        current.projectUuid != projectUuid ||
        _preparedOperationBootstrapProjectUuid == projectUuid) {
      return;
    }
    final sortedRecords = _projectRecords.entries.toList(growable: false)
      ..sort((left, right) {
        final byKind = left.key.kind.index.compareTo(right.key.kind.index);
        return byKind != 0
            ? byKind
            : left.key.recordId.compareTo(right.key.recordId);
      });
    final chapterTexts = <String, String>{
      for (final entry in current.chapters.entries) entry.key: entry.value.text,
    };
    final projectTexts = <String, String>{
      for (final entry in current.projectTexts.entries)
        entry.key: entry.value.text,
    };
    _remoteAcknowledgedSequences.clear();
    state = state.copyWith(
      document: CollaborationDocument.operationBacked(
        projectUuid: current.projectUuid,
        replicaId: current.replicaId,
        chapterTexts: chapterTexts,
        projectTexts: projectTexts,
        projectRecords: sortedRecords.map((entry) => entry.value),
      ),
      errorMessage: null,
    );
    _preparedOperationBootstrapProjectUuid = projectUuid;
    _lastLocalActivityAt = DateTime.now();
  }

  void _ensureAuthenticatedReplica(P2pSyncState p2pState) {
    final identity = p2pState.localIdentity;
    final current = state.document;
    if (identity == null ||
        current == null ||
        current.replicaId == identity.deviceId) {
      return;
    }
    final currentTexts = <String, String>{
      for (final entry in current.textDocuments.entries)
        entry.key: entry.value.text,
    };
    var rebound = CollaborationDocument.seeded(
      projectUuid: current.projectUuid,
      replicaId: identity.deviceId,
      chapterTexts: _checkpointTexts,
      projectTexts: _checkpointProjectTexts,
    );
    for (final entry in currentTexts.entries) {
      if (rebound.textDocument(entry.key) == null) {
        rebound =
            ProjectCollaborativeTextCodec.isProjectTextDocumentId(entry.key)
            ? rebound.ensureProjectText(documentId: entry.key)
            : rebound.ensureChapter(chapterId: entry.key);
      }
      rebound = rebound.createLocalTextEdit(
        documentId: entry.key,
        nextText: entry.value,
      );
    }
    state = state.copyWith(document: rebound);
    switch (_localCursorLocation) {
      case final _LocalChapterCursorLocation location:
        updateLocalCursor(
          chapterId: location.chapterId,
          anchorOffset: location.anchorOffset,
          focusOffset: location.focusOffset,
        );
      case final _LocalProjectFieldCursorLocation location:
        updateLocalProjectFieldCursor(
          fieldId: location.fieldId,
          anchorOffset: location.anchorOffset,
          focusOffset: location.focusOffset,
        );
      case final _LocalProjectTextCursorLocation location:
        updateLocalProjectTextCursor(
          documentId: location.documentId,
          anchorOffset: location.anchorOffset,
          focusOffset: location.focusOffset,
        );
      case null:
        break;
    }
  }

  CollaborationSyncBatch? _buildLocalBatch() {
    final document = state.document;
    if (document == null) return null;
    final pending = document.operationsAfter(
      _remoteAcknowledgedSequences,
      limit: 32,
    );
    var count = pending.length;
    while (true) {
      final batch = CollaborationSyncBatch(
        projectUuid: document.projectUuid,
        senderReplicaId: document.replicaId,
        acknowledgedSequences: document.acknowledgedSequences,
        operations: pending.take(count),
        presence: _localPresence,
      );
      if (utf8.encode(jsonEncode(batch.toJson())).length <= 30 * 1024 ||
          count == 0) {
        return batch;
      }
      if (count == 1) {
        throw const FormatException(
          "單一即時協作 operation 超過 30 KiB；必須拆成更小的文字或 record fields。",
        );
      }
      count -= 1;
    }
  }

  void _publishLocalBatch() {
    try {
      final p2pState = ref.read(p2pSyncProvider);
      final document = state.document;
      final localOfferMatches =
          p2pState.localProjectOffer.projectUuid == document?.projectUuid;
      final receivingRemoteProject =
          p2pState.selectedProjectSource == P2pProjectSource.remote &&
          p2pState.remoteProjectOffer?.projectUuid == document?.projectUuid;
      if (document == null ||
          !p2pState.hasAuthenticatedTransport ||
          p2pState.sessionProjectUuid != document.projectUuid ||
          (!localOfferMatches && !receivingRemoteProject)) {
        return;
      }
      final batch = _buildLocalBatch();
      if (batch == null) return;
      _endpoint.updateLocalCollaborationBatch(batch);
    } on FormatException catch (error) {
      state = state.copyWith(
        connectionStatus: CollaborationConnectionStatus.error,
        errorMessage: "即時協作 operation 無法送出：$error",
      );
    }
  }

  void _pruneStaleCursors() {
    if (state.remoteCursors.isEmpty) return;
    final now = DateTime.now();
    final retained = <String, RemoteCursorState>{
      for (final entry in state.remoteCursors.entries)
        if (now.difference(entry.value.observedAt) <= _cursorExpiry)
          entry.key: entry.value,
    };
    if (retained.length != state.remoteCursors.length) {
      state = state.copyWith(remoteCursors: retained);
    }
  }
}

final collaborationProvider =
    NotifierProvider<CollaborationNotifier, CollaborationState>(
      CollaborationNotifier.new,
    );

final activeChapterRemoteCursorsProvider =
    Provider<List<RemoteChapterCursorState>>((ref) {
      final chapterId = ref.watch(editorSelectionProvider).selectedChapID;
      if (chapterId == null) return const <RemoteChapterCursorState>[];
      return ref.watch(chapterRemoteCursorsProvider(chapterId));
    });

final chapterRemoteCursorsProvider =
    Provider.family<List<RemoteChapterCursorState>, String>((ref, chapterId) {
      final cursors =
          ref
              .watch(collaborationProvider)
              .remoteCursors
              .values
              .whereType<RemoteChapterCursorState>()
              .where((cursor) => cursor.chapterId == chapterId)
              .toList(growable: false)
            ..sort((left, right) => left.ipAddress.compareTo(right.ipAddress));
      return List<RemoteChapterCursorState>.unmodifiable(cursors);
    });

final projectFieldRemoteCursorsProvider =
    Provider.family<List<RemoteProjectFieldCursorState>, String>((
      ref,
      fieldId,
    ) {
      final cursors =
          ref
              .watch(collaborationProvider)
              .remoteCursors
              .values
              .whereType<RemoteProjectFieldCursorState>()
              .where((cursor) => cursor.fieldId == fieldId)
              .toList(growable: false)
            ..sort((left, right) => left.ipAddress.compareTo(right.ipAddress));
      return List<RemoteProjectFieldCursorState>.unmodifiable(cursors);
    });

final projectTextRemoteCursorsProvider =
    Provider.family<List<RemoteProjectTextCursorState>, String>((
      ref,
      documentId,
    ) {
      final cursors =
          ref
              .watch(collaborationProvider)
              .remoteCursors
              .values
              .whereType<RemoteProjectTextCursorState>()
              .where((cursor) => cursor.documentId == documentId)
              .toList(growable: false)
            ..sort((left, right) => left.ipAddress.compareTo(right.ipAddress));
      return List<RemoteProjectTextCursorState>.unmodifiable(cursors);
    });

final collaborativeTextValueProvider = Provider.family<String?, String>((
  ref,
  documentId,
) {
  return ref.watch(
    collaborationProvider.select((state) => state.document?.text(documentId)),
  );
});
