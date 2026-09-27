import "package:flutter/widgets.dart";

String editorTabSpaces(int count, bool fullWidth) =>
    List.filled(count.clamp(1, 8), fullWidth ? "\u3000" : " ").join();

/// Finds a UTF-16 range without splitting a grapheme or crossing protected text.
int overwriteEnd(
  String text,
  int start,
  String inserted, {
  Iterable<TextRange> protectedRanges = const [],
}) {
  if (inserted.isEmpty || inserted.contains("\n") || inserted.contains("\r")) {
    return start;
  }
  if (start < 0 || start > text.length) return start;
  if (start > 0) {
    final previous = text.substring(0, start).characters.last;
    // An accent, variation selector or ZWJ continuation extends the previous
    // character; it must not consume another character in overwrite mode.
    if ((previous + inserted).characters.first.length > previous.length) {
      return start;
    }
  }
  var offset = 0;
  var end = start;
  var remaining = inserted.characters.length;
  for (final character in text.characters) {
    final nextOffset = offset + character.length;
    if (offset < start) {
      if (nextOffset > start) return start;
      offset = nextOffset;
      continue;
    }
    if (remaining-- <= 0 ||
        character.contains("\n") ||
        character.contains("\r")) {
      break;
    }
    final next = end + character.length;
    if (protectedRanges.any((range) => end < range.end && next > range.start)) {
      break;
    }
    end = next;
    offset = nextOffset;
  }
  return end;
}

/// Only a pure insertion at the original collapsed caret is eligible.
TextEditingValue applyOverwrite(
  TextEditingValue before,
  TextEditingValue after, {
  Iterable<TextRange> protectedRanges = const [],
}) {
  final selection = before.selection;
  if (!selection.isValid || !selection.isCollapsed) return after;
  final start = selection.start;
  final added = after.text.length - before.text.length;
  if (added <= 0 ||
      start > before.text.length ||
      !after.text.startsWith(before.text.substring(0, start)) ||
      after.text.substring(start + added) != before.text.substring(start)) {
    return after;
  }
  final inserted = after.text.substring(start, start + added);
  final end = overwriteEnd(
    before.text,
    start,
    inserted,
    protectedRanges: protectedRanges,
  );
  if (end == start) return after;
  return after.copyWith(
    text: before.text.replaceRange(start, end, inserted),
    selection: TextSelection.collapsed(offset: start + inserted.length),
    composing: TextRange.empty,
  );
}

class InsertEditorSpacesIntent extends Intent {
  const InsertEditorSpacesIntent();
}

class ToggleEditorOverwriteIntent extends Intent {
  const ToggleEditorOverwriteIntent();
}
