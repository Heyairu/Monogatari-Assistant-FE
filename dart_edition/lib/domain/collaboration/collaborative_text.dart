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

  CollaborativeText._({
    required this.documentId,
    required Map<TextAtomId, TextAtom> atoms,
    required Set<TextAtomId> tombstones,
    required Map<TextAtomId, TextAtom> pendingAtoms,
  }) : _atoms = atoms,
       _tombstones = tombstones,
       _pendingAtoms = pendingAtoms;

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

  String get text {
    final buffer = StringBuffer();
    for (final atom in _orderedAtoms()) {
      if (!_tombstones.contains(atom.id)) buffer.write(atom.value);
    }
    return buffer.toString();
  }

  List<TextAtomId> get visibleAtomIds => List<TextAtomId>.unmodifiable(
    _orderedAtoms()
        .where((atom) => !_tombstones.contains(atom.id))
        .map((atom) => atom.id),
  );

  CollaborativeText apply(CollaborationOperation operation) {
    if (operation.textDocumentId != documentId) return this;
    final next = copy();
    switch (operation) {
      case final TextInsertOperation insert:
        next._applyInsert(insert);
      case final TextDeleteOperation delete:
        next._tombstones.addAll(delete.atomIds);
      case ProjectDataRecordOperation():
        break;
    }
    return next;
  }

  CollaborativeTextEdit createLocalEdit({
    required String nextText,
    required ReplicaClock clock,
  }) {
    final currentGraphemes = text.characters.toList(growable: false);
    final nextGraphemes = nextText.characters.toList(growable: false);
    var prefixLength = 0;
    while (prefixLength < currentGraphemes.length &&
        prefixLength < nextGraphemes.length &&
        currentGraphemes[prefixLength] == nextGraphemes[prefixLength]) {
      prefixLength += 1;
    }

    var suffixLength = 0;
    while (suffixLength < currentGraphemes.length - prefixLength &&
        suffixLength < nextGraphemes.length - prefixLength &&
        currentGraphemes[currentGraphemes.length - 1 - suffixLength] ==
            nextGraphemes[nextGraphemes.length - 1 - suffixLength]) {
      suffixLength += 1;
    }

    final currentIds = visibleAtomIds;
    final removedEnd = currentIds.length - suffixLength;
    final removedIds = currentIds.sublist(prefixLength, removedEnd);
    final insertedEnd = nextGraphemes.length - suffixLength;
    final inserted = nextGraphemes.sublist(prefixLength, insertedEnd);
    if (removedIds.isEmpty && inserted.isEmpty) {
      return CollaborativeTextEdit(
        document: this,
        operations: const <CollaborationOperation>[],
      );
    }

    var nextDocument = this;
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
      nextDocument = nextDocument.apply(operation);
    }

    if (inserted.isNotEmpty) {
      TextAtomId? parentId = prefixLength == 0
          ? null
          : currentIds[prefixLength - 1];
      for (final chunk in _wireSafeInsertChunks(inserted)) {
        final stamp = clock.nextOperation();
        final atoms = <TextAtom>[];
        for (var index = 0; index < chunk.length; index += 1) {
          final id = TextAtomId(
            replicaId: stamp.id.replicaId,
            operationSequence: stamp.id.sequence,
            atomIndex: index,
          );
          atoms.add(TextAtom(id: id, parentId: parentId, value: chunk[index]));
          parentId = id;
        }
        final operation = TextInsertOperation(
          id: stamp.id,
          lamport: stamp.lamport,
          textDocumentId: documentId,
          atoms: atoms,
        );
        operations.add(operation);
        nextDocument = nextDocument.apply(operation);
      }
    }

    return CollaborativeTextEdit(
      document: nextDocument,
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
    final bounded = utf16Offset.clamp(0, text.length).toInt();
    var consumed = 0;
    TextAtomId? previous;
    for (final atom in _orderedAtoms()) {
      if (_tombstones.contains(atom.id)) continue;
      final nextConsumed = consumed + atom.value.length;
      if (bounded <= consumed) {
        return TextCursorAnchor(atomId: previous, fallbackOffset: bounded);
      }
      if (bounded < nextConsumed) {
        return TextCursorAnchor(atomId: previous, fallbackOffset: bounded);
      }
      consumed = nextConsumed;
      previous = atom.id;
    }
    return TextCursorAnchor(atomId: previous, fallbackOffset: bounded);
  }

  int resolveAnchor(TextCursorAnchor anchor) {
    final targetId = anchor.atomId;
    if (targetId == null) return 0;
    var offset = 0;
    for (final atom in _orderedAtoms()) {
      if (!_tombstones.contains(atom.id)) offset += atom.value.length;
      if (atom.id == targetId) return offset;
    }
    return anchor.fallbackOffset.clamp(0, text.length).toInt();
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

  Iterable<TextAtom> _orderedAtoms() sync* {
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

    yield* visit(null);
  }
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
