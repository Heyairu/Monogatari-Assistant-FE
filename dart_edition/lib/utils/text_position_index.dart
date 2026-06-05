class TextPositionIndex {
  TextPositionIndex(String text)
    : text = text,
      newlineOffsets = _collectNewlineOffsets(text);

  const TextPositionIndex._(this.text, this.newlineOffsets);

  factory TextPositionIndex.empty() => const TextPositionIndex._("", <int>[]);

  final String text;
  final List<int> newlineOffsets;

  TextPositionIndex rebuildIfTextChanged(String nextText) {
    if (identical(text, nextText) || text == nextText) {
      return this;
    }
    return TextPositionIndex(nextText);
  }

  ({int line, int column}) lineColumnFromOffset(int offset) {
    final int safeOffset = offset.clamp(0, text.length);
    final int newlinesBeforeCursor = _lowerBound(newlineOffsets, safeOffset);
    final int previousNewlineOffset = newlinesBeforeCursor == 0
        ? -1
        : newlineOffsets[newlinesBeforeCursor - 1];

    return (
      line: newlinesBeforeCursor + 1,
      column: safeOffset - previousNewlineOffset,
    );
  }

  static List<int> _collectNewlineOffsets(String text) {
    final offsets = <int>[];
    for (int i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 0x0A) {
        offsets.add(i);
      }
    }
    return offsets;
  }

  static int _lowerBound(List<int> values, int target) {
    int low = 0;
    int high = values.length;

    while (low < high) {
      final int mid = low + ((high - low) >> 1);
      if (values[mid] < target) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }

    return low;
  }
}
