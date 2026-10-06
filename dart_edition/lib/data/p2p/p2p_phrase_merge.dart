import '../../domain/models/p2p_sync_models.dart';
import '../../features/phrases/phrase_entry.dart';

/// Three-way merge for project phrases. Each phrase is an atomic record so its
/// body, derived name, tags and timestamps cannot be mixed across versions.
final class P2pPhraseMergePlan {
  final List<_PhraseChoice> _choices;
  final P2pFieldConflictItem? _shortcutConflict;
  final List<PhraseEntry> _local;
  final List<PhraseEntry> _remote;
  final String? _resolvedRecovery;
  final String? _localRecovery;
  final String? _remoteRecovery;
  final P2pFieldConflictItem? _recoveryConflict;
  final List<P2pFieldConflictItem> conflicts;

  P2pPhraseMergePlan._(
    this._choices,
    this._shortcutConflict,
    this._local,
    this._remote,
    this._resolvedRecovery,
    this._localRecovery,
    this._remoteRecovery,
    this._recoveryConflict,
  ) : conflicts = List.unmodifiable([
        if (_shortcutConflict != null) _shortcutConflict,
        if (_recoveryConflict != null) _recoveryConflict,
        if (_shortcutConflict == null)
          for (final choice in _choices)
            if (choice.conflict != null) choice.conflict!,
      ]);

  factory P2pPhraseMergePlan.create({
    required String projectUuid,
    List<PhraseEntry>? base,
    required List<PhraseEntry> local,
    required List<PhraseEntry> remote,
    String? baseRecovery,
    String? localRecovery,
    String? remoteRecovery,
  }) {
    validatePhraseLibrary(local);
    validatePhraseLibrary(remote);
    if (base != null) validatePhraseLibrary(base);
    final localById = {for (final phrase in local) phrase.id: phrase};
    final remoteById = {for (final phrase in remote) phrase.id: phrase};
    final baseById = {
      for (final phrase in base ?? <PhraseEntry>[]) phrase.id: phrase,
    };
    String? resolvedRecovery;
    P2pFieldConflictItem? recoveryConflict;
    if (localRecovery == remoteRecovery) {
      resolvedRecovery = localRecovery;
    } else if (base != null && localRecovery == baseRecovery) {
      resolvedRecovery = remoteRecovery;
    } else if (base != null && remoteRecovery == baseRecovery) {
      resolvedRecovery = localRecovery;
    } else if (base == null && localRecovery == null) {
      resolvedRecovery = remoteRecovery;
    } else if (base == null && remoteRecovery == null) {
      resolvedRecovery = localRecovery;
    } else {
      recoveryConflict = P2pFieldConflictItem(
        groupId: projectUuid,
        groupType: 'phraseLibrary',
        groupLabel: '短語庫',
        fieldPathSegments: const ['短語庫', '未識別資料'],
        base: _recoveryValue(baseRecovery),
        local: _recoveryValue(localRecovery),
        remote: _recoveryValue(remoteRecovery),
      );
    }

    // Different IDs with the same shortcut cannot both be inserted. Let the
    // user select a complete side instead of silently discarding one phrase.
    final localShortcutIds = {
      for (final phrase in local) phrase.normalizedShortcut: phrase.id,
    };
    final collision = remote.where((phrase) {
      final localId = localShortcutIds[phrase.normalizedShortcut];
      return localId != null && localId != phrase.id;
    }).toList();
    if (collision.isNotEmpty) {
      final shortcut = collision.first.shortcut;
      return P2pPhraseMergePlan._(
        const [],
        P2pFieldConflictItem(
          groupId: projectUuid,
          groupType: 'phraseLibrary',
          groupLabel: '短語庫',
          fieldPathSegments: ['短語庫', '重複短碼 $shortcut'],
          base: P2pFieldValue.present([
            for (final phrase in base ?? <PhraseEntry>[]) phrase.toJson(),
          ]),
          local: P2pFieldValue.present([
            for (final phrase in local) phrase.toJson(),
          ]),
          remote: P2pFieldValue.present([
            for (final phrase in remote) phrase.toJson(),
          ]),
        ),
        List.unmodifiable(local),
        List.unmodifiable(remote),
        resolvedRecovery,
        localRecovery,
        remoteRecovery,
        recoveryConflict,
      );
    }

    final ids = <String>{
      ...baseById.keys,
      ...localById.keys,
      ...remoteById.keys,
    }.toList()..sort();
    return P2pPhraseMergePlan._(
      [
        for (final id in ids)
          _PhraseChoice.create(
            id: id,
            base: baseById[id],
            local: localById[id],
            remote: remoteById[id],
            hasBase: base != null,
          ),
      ],
      null,
      List.unmodifiable(local),
      List.unmodifiable(remote),
      resolvedRecovery,
      localRecovery,
      remoteRecovery,
      recoveryConflict,
    );
  }

  String? resolveRecovery(P2pConflictResolutionResult resolutions) {
    final conflict = _recoveryConflict;
    if (conflict == null) return _resolvedRecovery;
    return resolutions.sideFor(conflict) == P2pConflictSide.remote
        ? _remoteRecovery
        : _localRecovery;
  }

  List<PhraseEntry> apply(P2pConflictResolutionResult resolutions) {
    final shortcutConflict = _shortcutConflict;
    if (shortcutConflict != null) {
      return resolutions.sideFor(shortcutConflict) == P2pConflictSide.remote
          ? _remote
          : _local;
    }
    final result = <PhraseEntry>[
      for (final choice in _choices)
        if (choice.resolve(resolutions) case final phrase?) phrase,
    ];
    validatePhraseLibrary(result);
    return List.unmodifiable(result);
  }
}

final class _PhraseChoice {
  final PhraseEntry? resolved;
  final PhraseEntry? local;
  final PhraseEntry? remote;
  final P2pFieldConflictItem? conflict;

  const _PhraseChoice._({
    this.resolved,
    this.local,
    this.remote,
    this.conflict,
  });

  factory _PhraseChoice.create({
    required String id,
    required PhraseEntry? base,
    required PhraseEntry? local,
    required PhraseEntry? remote,
    required bool hasBase,
  }) {
    if (_same(local, remote)) {
      return _PhraseChoice._(resolved: _newer(local, remote));
    }
    if (hasBase) {
      if (_same(local, base)) return _PhraseChoice._(resolved: remote);
      if (_same(remote, base)) return _PhraseChoice._(resolved: local);
    } else {
      if (local == null) return _PhraseChoice._(resolved: remote);
      if (remote == null) return _PhraseChoice._(resolved: local);
    }
    return _PhraseChoice._(
      local: local,
      remote: remote,
      conflict: P2pFieldConflictItem(
        groupId: id,
        groupType: 'phrase',
        groupLabel:
            '短語：${local?.shortcut ?? remote?.shortcut ?? base?.shortcut ?? id}',
        fieldPathSegments: const ['短語庫', '內容'],
        base: base == null
            ? const P2pFieldValue.absent()
            : P2pFieldValue.present(base.toJson()),
        local: local == null
            ? const P2pFieldValue.absent()
            : P2pFieldValue.present(local.toJson()),
        remote: remote == null
            ? const P2pFieldValue.absent()
            : P2pFieldValue.present(remote.toJson()),
      ),
    );
  }

  PhraseEntry? resolve(P2pConflictResolutionResult resolutions) {
    final item = conflict;
    if (item == null) return resolved;
    return resolutions.sideFor(item) == P2pConflictSide.remote ? remote : local;
  }
}

bool _same(PhraseEntry? left, PhraseEntry? right) {
  if (left == null || right == null) return left == right;
  final leftJson = left.toJson()..remove('updatedAt');
  final rightJson = right.toJson()..remove('updatedAt');
  return P2pThreeWayMerge.deepEquals(leftJson, rightJson);
}

PhraseEntry? _newer(PhraseEntry? left, PhraseEntry? right) {
  if (left == null) return right;
  if (right == null) return left;
  return right.updatedAt.isAfter(left.updatedAt) ? right : left;
}

P2pFieldValue _recoveryValue(String? source) => source == null
    ? const P2pFieldValue.absent()
    : P2pFieldValue.present(source);
