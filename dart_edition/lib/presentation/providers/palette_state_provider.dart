import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:uuid/uuid.dart";

import "../../data/repositories/palette_repository.dart";
import "../../models/palette_data.dart";

final paletteRepositoryProvider = Provider<PaletteRepository>(
  (Ref ref) => AppSupportPaletteRepository(),
);

@immutable
class PaletteLoadResult {
  final bool usedSeed;
  final List<String> warnings;

  const PaletteLoadResult({required this.usedSeed, required this.warnings});
}

@immutable
class PaletteMutationResult {
  final bool changed;
  final String? entryId;
  final String? error;

  const PaletteMutationResult._({
    required this.changed,
    this.entryId,
    this.error,
  });

  const PaletteMutationResult.success(String entryId)
    : this._(changed: true, entryId: entryId);

  const PaletteMutationResult.failure(String error)
    : this._(changed: false, error: error);
}

@immutable
class PaletteEntryRemovalRecord {
  final PaletteEntry entry;
  final Map<String, int> slotIndexes;

  const PaletteEntryRemovalRecord({
    required this.entry,
    required this.slotIndexes,
  });
}

class PaletteStateNotifier extends Notifier<PaletteStateData> {
  static const Duration _persistDebounce = Duration(milliseconds: 260);

  final Uuid _uuid = const Uuid();
  Timer? _persistTimer;
  Future<void> _writeQueue = Future<void>.value();
  late PaletteRepository _repository;
  bool _hydrated = false;
  bool _disposed = false;

  @override
  PaletteStateData build() {
    _repository = ref.read(paletteRepositoryProvider);
    ref.onDispose(() {
      _disposed = true;
      _persistTimer?.cancel();
      _persistTimer = null;
    });
    return PaletteStateData.empty();
  }

  Future<PaletteLoadResult> loadFromRepository() async {
    if (_hydrated) {
      return const PaletteLoadResult(usedSeed: false, warnings: <String>[]);
    }

    final String? userRaw = await _repository.readUserData();
    final bool usedSeed = userRaw == null;
    final String raw = userRaw ?? await _repository.readSeedData();
    final PaletteDecodeResult decoded = PaletteDataCodec.decode(raw);
    for (final String warning in decoded.warnings) {
      debugPrint("Palettes data warning: $warning");
    }

    hydrateFromStorage(decoded.data);
    _hydrated = true;
    if (usedSeed) {
      unawaited(
        flushPalettePersistence().catchError((Object error) {
          debugPrint("Initial Palettes persistence failed: $error");
        }),
      );
    }
    return PaletteLoadResult(usedSeed: usedSeed, warnings: decoded.warnings);
  }

  void hydrateFromStorage(PaletteStateData value) {
    state = immutablePaletteState(
      slotEntryIds: value.slotEntryIds,
      entryIndex: value.entryIndex,
      persistenceError: value.persistenceError,
    );
    _hydrated = true;
  }

  PaletteMutationResult addEntry({
    required String slotId,
    required String text,
  }) {
    if (!paletteSlotById.containsKey(slotId)) {
      return const PaletteMutationResult.failure("找不到指定的調色盤格位");
    }
    final String? validationError = validatePaletteTerm(text);
    if (validationError != null) {
      return PaletteMutationResult.failure(validationError);
    }

    final String trimmed = text.trim();
    final List<String> currentIds = state.slotEntryIds[slotId] ?? const [];
    final String normalized = normalizePaletteTerm(trimmed);
    final bool duplicated = currentIds.any(
      (String id) =>
          normalizePaletteTerm(state.entryIndex[id]?.text ?? "") == normalized,
    );
    if (duplicated) {
      return const PaletteMutationResult.failure("此色格已有相同詞條");
    }

    final String entryId = "palette-entry-${_uuid.v4()}";
    final String timestamp = DateTime.now().toUtc().toIso8601String();
    final PaletteEntry entry = PaletteEntry(
      id: entryId,
      text: trimmed,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    final Map<String, List<String>> nextSlots = _copySlots();
    nextSlots[slotId] = <String>[...currentIds, entryId];
    final Map<String, PaletteEntry> nextEntries = <String, PaletteEntry>{
      ...state.entryIndex,
      entryId: entry,
    };
    _commit(nextSlots, nextEntries);
    return PaletteMutationResult.success(entryId);
  }

  PaletteMutationResult renameEntry({
    required String entryId,
    required String text,
  }) {
    final PaletteEntry? current = state.entryIndex[entryId];
    if (current == null) {
      return const PaletteMutationResult.failure("找不到指定的詞條");
    }
    final String? validationError = validatePaletteTerm(text);
    if (validationError != null) {
      return PaletteMutationResult.failure(validationError);
    }

    final String trimmed = text.trim();
    if (trimmed == current.text) {
      return PaletteMutationResult.success(entryId);
    }
    final String normalized = normalizePaletteTerm(trimmed);
    for (final MapEntry<String, List<String>> slot
        in state.slotEntryIds.entries) {
      if (!slot.value.contains(entryId)) {
        continue;
      }
      final bool duplicated = slot.value.any(
        (String id) =>
            id != entryId &&
            normalizePaletteTerm(state.entryIndex[id]?.text ?? "") ==
                normalized,
      );
      if (duplicated) {
        return const PaletteMutationResult.failure("此色格已有相同詞條");
      }
    }

    final Map<String, PaletteEntry> nextEntries = <String, PaletteEntry>{
      ...state.entryIndex,
      entryId: current.copyWith(
        text: trimmed,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      ),
    };
    _commit(_copySlots(), nextEntries);
    return PaletteMutationResult.success(entryId);
  }

  PaletteEntryRemovalRecord? removeEntry(String entryId) {
    final PaletteEntry? entry = state.entryIndex[entryId];
    if (entry == null) {
      return null;
    }

    final Map<String, List<String>> nextSlots = _copySlots();
    final Map<String, int> indexes = <String, int>{};
    for (final MapEntry<String, List<String>> slot in nextSlots.entries) {
      final int index = slot.value.indexOf(entryId);
      if (index >= 0) {
        indexes[slot.key] = index;
        slot.value.removeAt(index);
      }
    }
    nextSlots.removeWhere((String _, List<String> ids) => ids.isEmpty);
    final Map<String, PaletteEntry> nextEntries = <String, PaletteEntry>{
      ...state.entryIndex,
    }..remove(entryId);
    _commit(nextSlots, nextEntries);
    return PaletteEntryRemovalRecord(
      entry: entry,
      slotIndexes: Map<String, int>.unmodifiable(indexes),
    );
  }

  bool restoreEntry(PaletteEntryRemovalRecord record) {
    if (state.entryIndex.containsKey(record.entry.id) ||
        record.slotIndexes.isEmpty) {
      return false;
    }
    final Map<String, List<String>> nextSlots = _copySlots();
    for (final MapEntry<String, int> placement in record.slotIndexes.entries) {
      if (!paletteSlotById.containsKey(placement.key)) {
        continue;
      }
      final List<String> ids = nextSlots.putIfAbsent(
        placement.key,
        () => <String>[],
      );
      final int index = placement.value.clamp(0, ids.length).toInt();
      ids.insert(index, record.entry.id);
    }
    final Map<String, PaletteEntry> nextEntries = <String, PaletteEntry>{
      ...state.entryIndex,
      record.entry.id: record.entry,
    };
    _commit(nextSlots, nextEntries);
    return true;
  }

  bool sortSlotByText(String slotId) {
    final List<String>? current = state.slotEntryIds[slotId];
    if (current == null || current.length < 2) {
      return false;
    }
    final List<String> sorted = List<String>.from(current)
      ..sort(
        (String left, String right) => normalizePaletteTerm(
          state.entryIndex[left]?.text ?? "",
        ).compareTo(normalizePaletteTerm(state.entryIndex[right]?.text ?? "")),
      );
    if (listEquals(current, sorted)) {
      return false;
    }
    final Map<String, List<String>> nextSlots = _copySlots();
    nextSlots[slotId] = sorted;
    _commit(nextSlots, <String, PaletteEntry>{...state.entryIndex});
    return true;
  }

  Future<void> flushPalettePersistence() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    final PaletteStateData snapshot = immutablePaletteState(
      slotEntryIds: state.slotEntryIds,
      entryIndex: state.entryIndex,
    );
    final Future<void> operation = _writeQueue.then((_) async {
      await _repository.writeUserData(PaletteDataCodec.encode(snapshot));
      if (!_disposed) {
        state = state.copyWith(clearPersistenceError: true);
      }
    });
    _writeQueue = operation.catchError((Object _) {});
    try {
      await operation;
    } catch (error) {
      if (!_disposed) {
        state = state.copyWith(persistenceError: "調色盤儲存失敗：$error");
      }
      rethrow;
    }
  }

  Map<String, List<String>> _copySlots() {
    return <String, List<String>>{
      for (final MapEntry<String, List<String>> item
          in state.slotEntryIds.entries)
        item.key: List<String>.from(item.value),
    };
  }

  void _commit(
    Map<String, List<String>> slotEntryIds,
    Map<String, PaletteEntry> entryIndex,
  ) {
    state = immutablePaletteState(
      slotEntryIds: slotEntryIds,
      entryIndex: entryIndex,
      persistenceError: state.persistenceError,
    );
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDebounce, () {
      _persistTimer = null;
      unawaited(
        flushPalettePersistence().catchError((Object error) {
          debugPrint("Palettes persistence failed: $error");
        }),
      );
    });
  }
}

final paletteStateProvider =
    NotifierProvider<PaletteStateNotifier, PaletteStateData>(
      PaletteStateNotifier.new,
    );
