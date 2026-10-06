import '../domain/revision_models.dart';

final class RevisionTextDiffService {
  /// Bounds the Myers trace for unrelated large chapters. A coarse fallback
  /// preserves reconstruction and explicitly marks non-minimal statistics.
  final int maximumTraceEntries;
  const RevisionTextDiffService({this.maximumTraceEntries = 1000000});

  RevisionTextDiff compare({
    required String chapterId,
    required String before,
    required String after,
  }) {
    final oldLines = _parse(before);
    final newLines = _parse(after);
    var prefix = 0;
    while (prefix < oldLines.length &&
        prefix < newLines.length &&
        oldLines[prefix].text == newLines[prefix].text) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < oldLines.length - prefix &&
        suffix < newLines.length - prefix &&
        oldLines[oldLines.length - suffix - 1].text ==
            newLines[newLines.length - suffix - 1].text) {
      suffix++;
    }
    final oldMiddle = oldLines.sublist(prefix, oldLines.length - suffix);
    final newMiddle = newLines.sublist(prefix, newLines.length - suffix);
    final script = _myers(oldMiddle, newMiddle);
    final kinds = <RevisionLineKind>[
      ...List.filled(prefix, RevisionLineKind.equal),
      ...script.kinds,
      ...List.filled(suffix, RevisionLineKind.equal),
    ];
    final lines = <RevisionLineChange>[];
    final hunks = <RevisionTextHunk>[];
    var oldIndex = 0;
    var newIndex = 0;
    var hunkOld = 0;
    var hunkNew = 0;
    final pending = <RevisionLineChange>[];
    int offset(List<RevisionLogicalLine> source, int index, String raw) =>
        index < source.length ? source[index].startOffset : raw.length;
    void flush() {
      if (pending.isEmpty) return;
      hunks.add(
        RevisionTextHunk(
          lines: pending,
          oldStart: hunkOld,
          newStart: hunkNew,
          oldOffset: offset(oldLines, hunkOld, before),
          newOffset: offset(newLines, hunkNew, after),
        ),
      );
      pending.clear();
    }

    for (final kind in kinds) {
      if (kind == RevisionLineKind.equal) {
        flush();
      } else if (pending.isEmpty) {
        hunkOld = oldIndex;
        hunkNew = newIndex;
      }
      final line = RevisionLineChange(
        kind,
        before: kind == RevisionLineKind.added ? null : oldLines[oldIndex++],
        after: kind == RevisionLineKind.removed ? null : newLines[newIndex++],
      );
      lines.add(line);
      if (kind != RevisionLineKind.equal) pending.add(line);
    }
    flush();
    if (before.endsWith('\n') != after.endsWith('\n')) {
      hunks.add(
        RevisionTextHunk(
          lines: const [],
          oldStart: oldLines.length,
          newStart: newLines.length,
          oldOffset: before.length,
          newOffset: after.length,
        ),
      );
    }
    return RevisionTextDiff(
      chapterId: chapterId,
      lines: lines,
      hunks: hunks,
      oldTrailingNewline: before.endsWith('\n'),
      newTrailingNewline: after.endsWith('\n'),
      isCoarse: script.coarse,
    );
  }

  List<RevisionLogicalLine> _parse(String text) {
    final lines = <RevisionLogicalLine>[];
    var start = 0;
    while (start < text.length) {
      final newline = text.indexOf('\n', start);
      final end = newline == -1 ? text.length : newline;
      final contentEnd =
          newline != -1 && end > start && text.codeUnitAt(end - 1) == 13
          ? end - 1
          : end;
      lines.add(
        RevisionLogicalLine(
          text.substring(start, contentEnd),
          lines.length + 1,
          start,
          contentEnd,
        ),
      );
      start = newline == -1 ? text.length : newline + 1;
    }
    return lines;
  }

  ({List<RevisionLineKind> kinds, bool coarse}) _myers(
    List<RevisionLogicalLine> oldLines,
    List<RevisionLogicalLine> newLines,
  ) {
    final n = oldLines.length;
    final m = newLines.length;
    if (n == 0) {
      return (kinds: List.filled(m, RevisionLineKind.added), coarse: false);
    }
    if (m == 0) {
      return (kinds: List.filled(n, RevisionLineKind.removed), coarse: false);
    }
    var frontier = <int, int>{1: 0};
    final trace = <Map<int, int>>[];
    var entries = 0;
    for (var d = 0; d <= n + m; d++) {
      entries += frontier.length;
      if (entries > maximumTraceEntries) {
        return (
          kinds: [
            ...List.filled(n, RevisionLineKind.removed),
            ...List.filled(m, RevisionLineKind.added),
          ],
          coarse: true,
        );
      }
      trace.add(frontier);
      final next = <int, int>{};
      for (var k = -d; k <= d; k += 2) {
        var x =
            k == -d ||
                (k != d && (frontier[k - 1] ?? -1) < (frontier[k + 1] ?? -1))
            ? frontier[k + 1] ?? 0
            : (frontier[k - 1] ?? 0) + 1;
        var y = x - k;
        while (x < n && y < m && oldLines[x].text == newLines[y].text) {
          x++;
          y++;
        }
        next[k] = x;
        if (x >= n && y >= m) {
          final reversed = <RevisionLineKind>[];
          var bx = n;
          var by = m;
          for (var depth = d; depth >= 0; depth--) {
            final previous = trace[depth];
            final diagonal = bx - by;
            final previousDiagonal =
                diagonal == -depth ||
                    (diagonal != depth &&
                        (previous[diagonal - 1] ?? -1) <
                            (previous[diagonal + 1] ?? -1))
                ? diagonal + 1
                : diagonal - 1;
            final px = previous[previousDiagonal] ?? 0;
            final py = px - previousDiagonal;
            while (bx > px && by > py) {
              reversed.add(RevisionLineKind.equal);
              bx--;
              by--;
            }
            if (depth == 0) break;
            if (bx == px) {
              reversed.add(RevisionLineKind.added);
              by--;
            } else {
              reversed.add(RevisionLineKind.removed);
              bx--;
            }
          }
          return (kinds: reversed.reversed.toList(), coarse: false);
        }
      }
      frontier = next;
    }
    throw StateError('Unreachable diff state');
  }
}
