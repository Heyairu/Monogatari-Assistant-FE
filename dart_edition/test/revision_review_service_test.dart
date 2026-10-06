import 'package:flutter_test/flutter_test.dart';
import 'package:monogatari_assistant/features/revision_tracking/application/revision_review_service.dart';
import 'package:monogatari_assistant/features/revision_tracking/application/revision_text_diff_service.dart';

void main() {
  const service = RevisionTextDiffService();
  void check(
    String before,
    String after, {
    int hunk = 0,
    required String expected,
  }) {
    final diff = service.compare(
      chapterId: 'chapter',
      before: before,
      after: after,
    );
    expect(
      RevisionReviewService.rejectTextHunk(
        before: before,
        after: after,
        diff: diff,
        hunk: diff.hunks[hunk],
      ),
      expected,
    );
  }

  test('rejects insertion, deletion and replacement at EOF', () {
    check('a', 'a\nb', expected: 'a');
    check('a\nb', 'a', expected: 'a\nb');
    check('a\nb', 'a\nc', expected: 'a\nb');
  });

  test('rejects one middle hunk without changing another', () {
    check('a\nb\nc\nd\ne', 'a\nB\nc\nD\ne', expected: 'a\nb\nc\nD\ne');
  });

  test('rejects trailing newline independently', () {
    check('a\n', 'a', expected: 'a\n');
    check('a', 'a\n', expected: 'a');
    check('a\nb\n', 'a\nc', expected: 'a\nb');
    check('a\nb', 'a\nc\n', expected: 'a\nb\n');
  });

  test('preserves Unicode and CRLF text outside the hunk', () {
    check('甲\r\n😀\r\n乙', '甲\r\n✨\r\n乙', expected: '甲\r\n😀\r\n乙');
  });

  test('batch rejection uses one snapshot even when offsets shift', () {
    const before = 'a\nb\nc\nd\ne\n';
    const after = 'a\nB\nc\nD extra\ne';
    final diff = service.compare(
      chapterId: 'chapter',
      before: before,
      after: after,
    );
    expect(diff.hunks.length, 3);
    expect(
      RevisionReviewService.rejectTextHunks(
        before: before,
        after: after,
        diff: diff,
        hunks: diff.hunks,
      ),
      before,
    );
    expect(
      RevisionReviewService.rejectTextHunks(
        before: before,
        after: after,
        diff: diff,
        hunks: diff.hunks.take(2),
      ),
      'a\nb\nc\nd\ne',
    );
  });
}
