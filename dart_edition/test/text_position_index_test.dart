import 'package:flutter_test/flutter_test.dart';
import 'package:monogatari_assistant/utils/text_position_index.dart';

void main() {
  test('lineColumnFromOffset preserves cursor position semantics', () {
    final index = TextPositionIndex('abc\ndef\n');

    expect(index.lineColumnFromOffset(0), (line: 1, column: 1));
    expect(index.lineColumnFromOffset(3), (line: 1, column: 4));
    expect(index.lineColumnFromOffset(4), (line: 2, column: 1));
    expect(index.lineColumnFromOffset(5), (line: 2, column: 2));
    expect(index.lineColumnFromOffset(7), (line: 2, column: 4));
    expect(index.lineColumnFromOffset(8), (line: 3, column: 1));
    expect(index.lineColumnFromOffset(9), (line: 3, column: 1));
    expect(index.lineColumnFromOffset(999), (line: 3, column: 1));
  });

  test('lineColumnFromOffset stays below 1ms for 500KB end cursor lookups', () {
    final text = 'abcdefghi\n' * 50000;
    final index = TextPositionIndex(text);
    final stopwatch = Stopwatch()..start();

    for (int i = 0; i < 100; i++) {
      expect(index.lineColumnFromOffset(text.length), (line: 50001, column: 1));
    }

    stopwatch.stop();
    final double averageMicros = stopwatch.elapsedMicroseconds / 100;
    expect(averageMicros, lessThan(1000));
  });

  test(
    'rebuildIfTextChanged reuses unchanged index and rebuilds changed text',
    () {
      final index = TextPositionIndex('first\nline');

      expect(index.rebuildIfTextChanged('first\nline'), same(index));

      final rebuilt = index.rebuildIfTextChanged('first\nline\nsecond');
      expect(rebuilt, isNot(same(index)));
      expect(rebuilt.lineColumnFromOffset(11), (line: 3, column: 1));
      expect(rebuilt.lineColumnFromOffset(18), (line: 3, column: 7));
    },
  );
}
