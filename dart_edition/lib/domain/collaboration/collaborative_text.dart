import "dart:collection";
import "dart:convert";

import "package:characters/characters.dart";

import "collaboration_operation.dart";

final class ReplicaClock {
  final String replicaId;
  int _nextSequence;
  int _lamport;

  ReplicaClock({required this.replicaId, int lastSequence = 0, int lamport = 0})
    : _nextSequence = lastSequence + 1,
      _lamport = lamport {
    if (replicaId.trim().isEmpty || lastSequence < 0 || lamport < 0) {
      throw ArgumentError("ReplicaClock 初始值無效。");
    }
  }

  int get lastSequence => _nextSequence - 1;
  int get lamport => _lamport;

  ({OperationId id, int lamport}) nextOperation() {
    _lamport += 1;
    return (
      id: OperationId(replicaId: replicaId, sequence: _nextSequence++),
      lamport: _lamport,
    );
  }

  void observe(CollaborationOperation operation) {
    _lamport = operation.lamport >= _lamport ? operation.lamport + 1 : _lamport;
  }
}

final class CollaborativeTextEdit {
  final CollaborativeText document;
  final List<CollaborationOperation> operations;

  const CollaborativeTextEdit({
    required this.document,
    required this.operations,
  });
}

/// One contiguous replacement against a known text revision.
///
/// Offsets use Dart/Flutter UTF-16 code units. [between] only scans the common
/// prefix and suffix; it does not materialize either complete string as a
/// grapheme list. [baseTextLength] prevents applying a UI delta to a different
/// length revision by accident.
final class CollaborativeTextDelta {
  final int baseTextLength;
  final int startOffset;
  final int endOffset;
  final String replacementText;

  const CollaborativeTextDelta({
    required this.baseTextLength,
    required this.startOffset,
    required this.endOffset,
    required this.replacementText,
  }) : assert(baseTextLength >= 0),
       assert(startOffset >= 0),
       assert(endOffset >= startOffset),
       assert(endOffset <= baseTextLength);

  factory CollaborativeTextDelta.between(String previous, String next) {
    if (previous == next) {
      return CollaborativeTextDelta(
        baseTextLength: previous.length,
        startOffset: 0,
        endOffset: 0,
        replacementText: "",
      );
    }
    var prefixLength = 0;
    final sharedLength = previous.length < next.length
        ? previous.length
        : next.length;
    while (prefixLength < sharedLength &&
        previous.codeUnitAt(prefixLength) == next.codeUnitAt(prefixLength)) {
      prefixLength += 1;
    }

    var suffixLength = 0;
    while (suffixLength < previous.length - prefixLength &&
        suffixLength < next.length - prefixLength &&
        previous.codeUnitAt(previous.length - 1 - suffixLength) ==
            next.codeUnitAt(next.length - 1 - suffixLength)) {
      suffixLength += 1;
    }
    return CollaborativeTextDelta(
      baseTextLength: previous.length,
      startOffset: prefixLength,
      endOffset: previous.length - suffixLength,
      replacementText: next.substring(prefixLength, next.length - suffixLength),
    );
  }

  bool get isNoop => startOffset == endOffset && replacementText.isEmpty;
}

/// Replicated growable array (RGA) for one independently addressed text field.
///
/// Inserts are chained below a stable atom and concurrent siblings are sorted
/// by [TextAtomId]. Deletes are tombstones. Operations are idempotent and can
/// arrive out of order; inserts with a missing parent stay pending until their
/// dependency arrives.
final class CollaborativeText {
  final String documentId;
  final Map<TextAtomId, TextAtom> _atoms;
  final Set<TextAtomId> _tombstones;
  final Map<TextAtomId, TextAtom> _pendingAtoms;
  _CollaborativeTextView? _cachedView;
  int _fullViewBuildCount = 0;

  CollaborativeText._({
    required this.documentId,
    required Map<TextAtomId, TextAtom> atoms,
    required Set<TextAtomId> tombstones,
    required Map<TextAtomId, TextAtom> pendingAtoms,
    _CollaborativeTextView? cachedView,
  }) : _atoms = atoms,
       _tombstones = tombstones,
       _pendingAtoms = pendingAtoms,
       _cachedView = cachedView;

  factory CollaborativeText.seeded({
    required String documentId,
    required String text,
  }) {
    final normalizedDocumentId = documentId.trim();
    if (normalizedDocumentId.isEmpty) {
      throw ArgumentError.value(documentId, "documentId", "不可為空");
    }
    final atoms = <TextAtomId, TextAtom>{};
    TextAtomId? parentId;
    var atomIndex = 0;
    for (final grapheme in text.characters) {
      final atomId = TextAtomId.seed(normalizedDocumentId, atomIndex++);
      atoms[atomId] = TextAtom(id: atomId, parentId: parentId, value: grapheme);
      parentId = atomId;
    }
    return CollaborativeText._(
      documentId: normalizedDocumentId,
      atoms: atoms,
      tombstones: <TextAtomId>{},
      pendingAtoms: <TextAtomId, TextAtom>{},
    );
  }

  CollaborativeText copy() => CollaborativeText._(
    documentId: documentId,
    atoms: Map<TextAtomId, TextAtom>.from(_atoms),
    tombstones: Set<TextAtomId>.from(_tombstones),
    pendingAtoms: Map<TextAtomId, TextAtom>.from(_pendingAtoms),
  );

  int get atomCount => _atoms.length;
  int get tombstoneCount => _tombstones.length;
  int get pendingAtomCount => _pendingAtoms.length;

  /// Number of full RGA tree materializations performed by this version.
  /// Useful for performance regression tests and runtime diagnostics.
  int get fullViewBuildCount => _fullViewBuildCount;

  _CollaborativeTextView get _view {
    final cached = _cachedView;
    if (cached != null) return cached;
    _fullViewBuildCount += 1;
    return _cachedView = _buildView();
  }

  String get text => _view.text;

  List<TextAtomId> get visibleAtomIds =>
      UnmodifiableListView<TextAtomId>(_view.visibleAtomIds);

  CollaborativeText apply(CollaborationOperation operation) {
    return applyAll(<CollaborationOperation>[operation]);
  }

  /// Applies a batch directly to the notifier-owned CRDT engine.
  CollaborativeText applyAll(Iterable<CollaborationOperation> operations) {
    var applied = false;
    for (final operation in operations) {
      if (operation.textDocumentId != documentId) continue;
      applied = true;
      switch (operation) {
        case final TextInsertOperation insert:
          _applyInsert(insert);
        case final TextDeleteOperation delete:
          _tombstones.addAll(delete.atomIds);
        case ProjectDataRecordOperation():
          break;
      }
    }
    if (applied) _cachedView = null;
    return this;
  }

  CollaborativeTextEdit createLocalEdit({
    required String nextText,
    required ReplicaClock clock,
  }) => createLocalDelta(
    delta: CollaborativeTextDelta.between(text, nextText),
    clock: clock,
  );

  CollaborativeTextEdit createLocalDelta({
    required CollaborativeTextDelta delta,
    required ReplicaClock clock,
  }) {
    final view = _view;
    if (delta.baseTextLength != view.text.length) {
      throw StateError(
        "CRDT text delta revision mismatch: "
        "${delta.baseTextLength} != ${view.text.length}",
      );
    }
    if (delta.startOffset < 0 ||
        delta.endOffset < delta.startOffset ||
        delta.endOffset > view.text.length) {
      throw RangeError.range(
        delta.endOffset,
        delta.startOffset,
        view.text.length,
        "delta.endOffset",
      );
    }

    final startAtomIndex =
        _upperBound(view.visibleUtf16Offsets, delta.startOffset) - 1;
    final endAtomIndex = _lowerBound(view.visibleUtf16Offsets, delta.endOffset);
    final safeStart = view.visibleUtf16Offsets[startAtomIndex];
    final safeEnd = view.visibleUtf16Offsets[endAtomIndex];
    final insertedText = StringBuffer()
      ..write(view.text.substring(safeStart, delta.startOffset))
      ..write(delta.replacementText)
      ..write(view.text.substring(delta.endOffset, safeEnd));
    final normalizedInsertedText = insertedText.toString();
    if (view.text.substring(safeStart, safeEnd) == normalizedInsertedText) {
      return CollaborativeTextEdit(
        document: this,
        operations: const <CollaborationOperation>[],
      );
    }

    final currentIds = view.visibleAtomIds;
    final removedIds = currentIds.sublist(startAtomIndex, endAtomIndex);
    final inserted = normalizedInsertedText.characters.toList(growable: false);
    if (removedIds.isEmpty && inserted.isEmpty) {
      return CollaborativeTextEdit(
        document: this,
        operations: const <CollaborationOperation>[],
      );
    }

    final operations = <CollaborationOperation>[];
    if (removedIds.isNotEmpty) {
      final stamp = clock.nextOperation();
      final operation = TextDeleteOperation(
        id: stamp.id,
        lamport: stamp.lamport,
        textDocumentId: documentId,
        atomIds: removedIds,
      );
      operations.add(operation);
    }

    final insertedAtoms = <TextAtom>[];
    if (inserted.isNotEmpty) {
      TextAtomId? parentId = startAtomIndex == 0
          ? null
          : currentIds[startAtomIndex - 1];
      for (final chunk in _wireSafeInsertChunks(inserted)) {
        final stamp = clock.nextOperation();
        final atoms = <TextAtom>[];
        for (var index = 0; index < chunk.length; index += 1) {
          final id = TextAtomId(
            replicaId: stamp.id.replicaId,
            operationSequence: stamp.id.sequence,
            atomIndex: index,
          );
          final atom = TextAtom(
            id: id,
            parentId: parentId,
            value: chunk[index],
          );
          atoms.add(atom);
          insertedAtoms.add(atom);
          parentId = id;
        }
        final operation = TextInsertOperation(
          id: stamp.id,
          lamport: stamp.lamport,
          textDocumentId: documentId,
          atoms: atoms,
        );
        operations.add(operation);
      }
    }

    for (final operation in operations) {
      switch (operation) {
        case final TextInsertOperation insert:
          _applyInsert(insert);
        case final TextDeleteOperation delete:
          _tombstones.addAll(delete.atomIds);
        case ProjectDataRecordOperation():
          break;
      }
    }
    final firstInsertedAtom = insertedAtoms.firstOrNull;
    final previousLeadingChild =
        view.leadingChildIds[firstInsertedAtom?.parentId];
    final canCarryViewForward =
        firstInsertedAtom == null ||
        previousLeadingChild == null ||
        firstInsertedAtom.id.compareTo(previousLeadingChild) > 0;
    if (canCarryViewForward) {
      final nextText = view.text.replaceRange(
        delta.startOffset,
        delta.endOffset,
        delta.replacementText,
      );
      view.replaceVisibleRange(
        startAtomIndex,
        endAtomIndex,
        insertedAtoms,
        nextText: nextText,
      );
      _cachedView = view;
    } else {
      _cachedView = null;
    }

    return CollaborativeTextEdit(
      document: this,
      operations: List<CollaborationOperation>.unmodifiable(operations),
    );
  }

  Iterable<List<String>> _wireSafeInsertChunks(List<String> graphemes) sync* {
    var chunk = <String>[];
    var byteLength = 0;
    for (final grapheme in graphemes) {
      final graphemeBytes = utf8.encode(grapheme).length;
      if (graphemeBytes > CollaborationSchema.maximumInsertedTextBytes) {
        throw const FormatException("單一 grapheme 超過 CRDT operation 上限。");
      }
      if (chunk.isNotEmpty &&
          byteLength + graphemeBytes >
              CollaborationSchema.preferredInsertedTextChunkBytes) {
        yield chunk;
        chunk = <String>[];
        byteLength = 0;
      }
      chunk.add(grapheme);
      byteLength += graphemeBytes;
    }
    if (chunk.isNotEmpty) yield chunk;
  }

  TextCursorAnchor anchorAtOffset(int utf16Offset) {
    final view = _view;
    final bounded = utf16Offset.clamp(0, view.text.length).toInt();
    final insertionIndex = _upperBound(view.visibleUtf16Offsets, bounded) - 1;
    final previousIndex = insertionIndex - 1;
    return TextCursorAnchor(
      atomId: previousIndex < 0 ? null : view.visibleAtoms[previousIndex].id,
      fallbackOffset: bounded,
    );
  }

  int resolveAnchor(TextCursorAnchor anchor) {
    final targetId = anchor.atomId;
    if (targetId == null) return 0;
    final view = _view;
    final index = view.visibleAtomIndex[targetId];
    if (index != null) return view.visibleUtf16Offsets[index + 1];
    return anchor.fallbackOffset.clamp(0, view.text.length).toInt();
  }

  void _applyInsert(TextInsertOperation operation) {
    for (final atom in operation.atoms) {
      if (_atoms.containsKey(atom.id) || _pendingAtoms.containsKey(atom.id)) {
        continue;
      }
      if (atom.parentId == null || _atoms.containsKey(atom.parentId)) {
        _atoms[atom.id] = atom;
      } else {
        _pendingAtoms[atom.id] = atom;
      }
    }
    var progressed = true;
    while (progressed && _pendingAtoms.isNotEmpty) {
      progressed = false;
      final readyIds = _pendingAtoms.values
          .where(
            (atom) =>
                atom.parentId == null || _atoms.containsKey(atom.parentId),
          )
          .map((atom) => atom.id)
          .toList(growable: false);
      for (final id in readyIds) {
        final atom = _pendingAtoms.remove(id);
        if (atom != null) {
          _atoms[id] = atom;
          progressed = true;
        }
      }
    }
  }

  _CollaborativeTextView _buildView() {
    final children = <TextAtomId?, SplayTreeSet<TextAtomId>>{};
    for (final atom in _atoms.values) {
      children
          .putIfAbsent(
            atom.parentId,
            // New insertions at an existing position must appear before the
            // older continuation atom. Concurrent siblings still use a total,
            // deterministic id order, so all replicas converge.
            () => SplayTreeSet<TextAtomId>(
              (left, right) => right.compareTo(left),
            ),
          )
          .add(atom.id);
    }

    Iterable<TextAtom> visit(TextAtomId? parentId) sync* {
      final childIds = children[parentId];
      if (childIds == null) return;
      for (final childId in childIds) {
        final atom = _atoms[childId];
        if (atom == null) continue;
        yield atom;
        yield* visit(childId);
      }
    }

    final visibleAtoms = visit(
      null,
    ).where((atom) => !_tombstones.contains(atom.id)).toList(growable: false);
    return _CollaborativeTextView.fromVisibleAtoms(
      visibleAtoms,
      leadingChildIds: <TextAtomId?, TextAtomId>{
        for (final entry in children.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value.first,
      },
    );
  }
}

final class _CollaborativeTextView {
  String text;
  final List<TextAtom> visibleAtoms;
  final List<TextAtomId> visibleAtomIds;
  final List<int> visibleUtf16Offsets;
  final Map<TextAtomId, int> visibleAtomIndex;
  final Map<TextAtomId?, TextAtomId> leadingChildIds;

  _CollaborativeTextView._({
    required this.text,
    required this.visibleAtoms,
    required this.visibleAtomIds,
    required this.visibleUtf16Offsets,
    required this.visibleAtomIndex,
    required this.leadingChildIds,
  });

  factory _CollaborativeTextView.fromVisibleAtoms(
    Iterable<TextAtom> atoms, {
    String? text,
    Map<TextAtomId?, TextAtomId> leadingChildIds =
        const <TextAtomId?, TextAtomId>{},
  }) {
    final visibleAtoms = List<TextAtom>.of(atoms);
    final ids = <TextAtomId>[];
    final offsets = <int>[0];
    final indices = <TextAtomId, int>{};
    final buffer = text == null ? StringBuffer() : null;
    var offset = 0;
    for (var index = 0; index < visibleAtoms.length; index += 1) {
      final atom = visibleAtoms[index];
      ids.add(atom.id);
      indices[atom.id] = index;
      offset += atom.value.length;
      offsets.add(offset);
      buffer?.write(atom.value);
    }
    assert(text == null || text.length == offset);
    return _CollaborativeTextView._(
      text: text ?? buffer.toString(),
      visibleAtoms: visibleAtoms,
      visibleAtomIds: ids,
      visibleUtf16Offsets: offsets,
      visibleAtomIndex: indices,
      leadingChildIds: Map<TextAtomId?, TextAtomId>.of(leadingChildIds),
    );
  }

  void replaceVisibleRange(
    int start,
    int end,
    List<TextAtom> insertedAtoms, {
    required String nextText,
  }) {
    final removedIds = visibleAtomIds.sublist(start, end);
    final safeStart = visibleUtf16Offsets[start];
    final safeEnd = visibleUtf16Offsets[end];
    final replacementOffsets = <int>[];
    var replacementEnd = safeStart;
    for (final atom in insertedAtoms) {
      replacementEnd += atom.value.length;
      replacementOffsets.add(replacementEnd);
    }
    final offsetDelta = replacementEnd - safeEnd;

    visibleAtoms.replaceRange(start, end, insertedAtoms);
    visibleAtomIds.replaceRange(
      start,
      end,
      insertedAtoms.map((atom) => atom.id),
    );
    visibleUtf16Offsets.replaceRange(start + 1, end + 1, replacementOffsets);
    for (
      var index = start + 1 + replacementOffsets.length;
      index < visibleUtf16Offsets.length;
      index += 1
    ) {
      visibleUtf16Offsets[index] += offsetDelta;
    }

    for (final id in removedIds) {
      visibleAtomIndex.remove(id);
    }
    for (var index = start; index < visibleAtoms.length; index += 1) {
      visibleAtomIndex[visibleAtoms[index].id] = index;
    }
    for (final atom in insertedAtoms) {
      leadingChildIds[atom.parentId] = atom.id;
    }
    text = nextText;
  }
}

int _lowerBound(List<int> values, int target) {
  var low = 0;
  var high = values.length;
  while (low < high) {
    final middle = low + ((high - low) >> 1);
    if (values[middle] < target) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  return low;
}

int _upperBound(List<int> values, int target) {
  var low = 0;
  var high = values.length;
  while (low < high) {
    final middle = low + ((high - low) >> 1);
    if (values[middle] <= target) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  return low;
}

final class TextCursorAnchor {
  final TextAtomId? atomId;
  final int fallbackOffset;

  const TextCursorAnchor({required this.atomId, required this.fallbackOffset});

  factory TextCursorAnchor.fromJson(Map<String, Object?> json) {
    if (json.length != 2 ||
        !json.containsKey("atomId") ||
        !json.containsKey("fallbackOffset")) {
      throw const FormatException("cursor anchor schema 無效。");
    }
    final rawAtomId = json["atomId"];
    final fallbackOffset = json["fallbackOffset"];
    if (fallbackOffset is! int || fallbackOffset < 0) {
      throw const FormatException("cursor fallbackOffset 無效。");
    }
    return TextCursorAnchor(
      atomId: rawAtomId == null
          ? null
          : TextAtomId.fromJson(_asJsonObject(rawAtomId)),
      fallbackOffset: fallbackOffset,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    "atomId": atomId?.toJson(),
    "fallbackOffset": fallbackOffset,
  };

  static Map<String, Object?> _asJsonObject(Object value) {
    if (value is! Map) {
      throw const FormatException("cursor atomId 無效。");
    }
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
}
