import '../../../application/collaboration/project_record_codec.dart';
import '../../../domain/collaboration/collaboration_operation.dart';
import '../../../domain/collaboration/typed_operation_log.dart';
import '../../../models/chapter_selection_data.dart';
import '../../../models/project_data.dart';
import '../domain/revision_models.dart';
import 'revision_field_registry.dart';

abstract final class RevisionSnapshotBuilder {
  /// Caller must synchronize any editor draft before capturing a baseline.
  static RevisionSnapshot capture(
    ProjectData project, {
    required String version,
  }) {
    final chapters = <String, String>{};
    void visit(List<SegmentData> folders) {
      for (final folder in folders) {
        for (final chapter in folder.chapters) {
          if (chapters.containsKey(chapter.chapterUUID)) {
            throw StateError('Duplicate chapter ID: ${chapter.chapterUUID}');
          }
          chapters[chapter.chapterUUID] = chapter.chapterContent;
        }
        visit(folder.childSegments);
      }
    }

    visit(project.segmentsData);
    final records = <ProjectRecordKey, RevisionRecord>{};
    // Keep collaborative scalar text; the wire codec can otherwise omit it.
    for (final entry in ProjectRecordCodec.snapshot(
      project,
      omitCollaborativeText: false,
    ).entries) {
      if (!RevisionFieldRegistry.supportedKinds.contains(entry.key.kind)) {
        continue;
      }
      records[entry.key] = RevisionRecord(
        key: entry.key,
        parentId: entry.value.parentId,
        fields: entry.value.fields,
      );
    }
    return RevisionSnapshot(
      projectId: project.projectUUID,
      version: version,
      chapterTexts: chapters,
      records: records,
      unsupportedKinds: ProjectRecordKind.values.toSet().difference(
        RevisionFieldRegistry.supportedKinds,
      ),
    );
  }
}
