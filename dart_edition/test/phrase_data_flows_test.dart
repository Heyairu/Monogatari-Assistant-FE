import 'package:flutter_test/flutter_test.dart';
import 'package:monogatari_assistant/application/collaboration/project_record_codec.dart';
import 'package:monogatari_assistant/application/project_import/selective_project_import.dart';
import 'package:monogatari_assistant/domain/collaboration/collaboration_operation.dart';
import 'package:monogatari_assistant/features/phrases/phrase_entry.dart';
import 'package:monogatari_assistant/models/project_data.dart';

const projectId = '11111111-1111-4111-8111-111111111111';
const firstId = '8f680e3c-90c1-4f37-ae35-f70c4dc7fe8f';

PhraseEntry phrase(String id, String shortcut, String body) => PhraseEntry(
  id: id,
  name: shortcut,
  shortcut: shortcut,
  body: body,
  createdAt: DateTime.utc(2026, 9, 30),
  updatedAt: DateTime.utc(2026, 9, 30),
);

void main() {
  test('selective import carries phrases as their own module', () {
    final current = ProjectData.empty(projectUUID: projectId);
    final source = ProjectData.empty(projectUUID: projectId)
      ..phrases = [phrase(firstId, 'hello', '正文')];
    final manifest = SelectiveProjectImportManifest.fromXml(
      '<Project><Type><Name>Phrases</Name><Data>x</Data></Type></Project>',
    );
    expect(manifest.availableModules, contains(SelectiveProjectModule.phrases));
    final result = const SelectiveProjectImporter().apply(
      current: current,
      source: source,
      manifest: manifest,
      selectedModules: {SelectiveProjectModule.phrases},
    );
    expect(result.data.phrases.single.id, firstId);
    expect(result.data.segmentsData, current.segmentsData);
  });

  test('cross-project phrase import marks Mentions for explicit relink', () {
    final current = ProjectData.empty(projectUUID: projectId);
    final source =
        ProjectData.empty(projectUUID: '33333333-3333-4333-8333-333333333333')
          ..phrases = [
            phrase(
              firstId,
              'hello',
              '//@<4e251fc2-1e2b-4f78-93da-91f8c76d9a92|艾莉絲>//',
            ),
          ];
    final manifest = SelectiveProjectImportManifest.fromXml(
      '<Project><Type><Name>Phrases</Name><Data>x</Data></Type></Project>',
    );
    final result = const SelectiveProjectImporter().apply(
      current: current,
      source: source,
      manifest: manifest,
      selectedModules: {SelectiveProjectModule.phrases},
    );
    expect(result.data.phrases.single.requiresRelink, isTrue);
    expect(
      result.warnings.any(
        (warning) => warning.code.startsWith('phrase-relink:'),
      ),
      isTrue,
    );
  });

  test('collaboration records detect phrase edits by stable ID', () {
    final before = ProjectData.empty(projectUUID: projectId);
    final after = ProjectData.empty(projectUUID: projectId)
      ..phrases = [phrase(firstId, 'hello', '正文')];
    final previous = ProjectRecordCodec.snapshot(before);
    final next = ProjectRecordCodec.snapshot(after);
    final diff = ProjectRecordCodec.diff(previous, next);
    expect(
      diff.where((op) => op.recordKind == ProjectRecordKind.phrase),
      hasLength(1),
    );
    expect(ProjectRecordCodec.decodePhrases(next).single.body, '正文');
  });

}
