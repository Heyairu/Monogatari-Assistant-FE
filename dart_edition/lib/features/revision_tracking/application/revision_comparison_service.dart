import '../domain/revision_models.dart';
import 'revision_record_diff_service.dart';
import 'revision_text_diff_service.dart';

final class RevisionComparisonService {
  final RevisionTextDiffService textDiff;
  const RevisionComparisonService({
    this.textDiff = const RevisionTextDiffService(),
  });

  RevisionComparison compare(
    RevisionBaseline baseline,
    RevisionSnapshot target, {
    Map<String, RevisionTextDiff> reusableTexts = const {},
  }) {
    final source = baseline.snapshot;
    if (source.projectId != target.projectId) {
      throw ArgumentError('Cannot compare different projects');
    }
    final texts = <RevisionTextDiff>[];
    final ids = {
      ...source.chapterTexts.keys,
      ...target.chapterTexts.keys,
    }.toList()..sort();
    for (final id in ids) {
      final before = source.chapterTexts[id] ?? '';
      final after = target.chapterTexts[id] ?? '';
      if (before == after) continue;
      final diff =
          reusableTexts[id] ??
          textDiff.compare(chapterId: id, before: before, after: after);
      if (diff.hasChanges) texts.add(diff);
    }
    return RevisionComparison(
      baselineVersion: source.version,
      targetVersion: target.version,
      texts: texts,
      records: RevisionRecordDiffService.compare(source, target),
      unsupportedKinds: {
        ...source.unsupportedKinds,
        ...target.unsupportedKinds,
      },
    );
  }
}
