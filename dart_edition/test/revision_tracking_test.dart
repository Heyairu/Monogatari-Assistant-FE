import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:monogatari_assistant/domain/collaboration/collaboration_operation.dart';
import 'package:monogatari_assistant/domain/collaboration/typed_operation_log.dart';
import 'package:monogatari_assistant/features/revision_tracking/application/revision_comparison_service.dart';
import 'package:monogatari_assistant/features/revision_tracking/application/revision_field_registry.dart';
import 'package:monogatari_assistant/features/revision_tracking/application/revision_record_diff_service.dart';
import 'package:monogatari_assistant/features/revision_tracking/application/revision_review_service.dart';
import 'package:monogatari_assistant/features/revision_tracking/application/revision_snapshot_builder.dart';
import 'package:monogatari_assistant/features/revision_tracking/application/revision_text_diff_service.dart';
import 'package:monogatari_assistant/features/revision_tracking/domain/revision_models.dart';
import 'package:monogatari_assistant/models/character_data.dart';
import 'package:monogatari_assistant/models/chapter_selection_data.dart';
import 'package:monogatari_assistant/models/project_data.dart';
import 'package:monogatari_assistant/models/outline_data.dart';
import 'package:monogatari_assistant/models/item_data.dart';
import 'package:monogatari_assistant/models/world_settings_data.dart';

const _character = ProjectRecordKey(
  kind: ProjectRecordKind.character,
  recordId: 'same-id',
);
RevisionSnapshot _snapshot(
  List<RevisionRecord> records, {
  String version = 'v1',
}) => RevisionSnapshot(
  projectId: 'project',
  version: version,
  chapterTexts: {},
  records: {for (final record in records) record.key: record},
  unsupportedKinds: {},
);
RevisionRecord _record(
  Map<String, Object?> fields, {
  ProjectRecordKey key = _character,
  String? parent,
}) => RevisionRecord(key: key, parentId: parent, fields: fields);

String _rebuild(RevisionTextDiff diff, {required bool target}) {
  final lines = diff.lines
      .where((line) => target ? line.after != null : line.before != null)
      .map((line) => target ? line.after!.text : line.before!.text)
      .toList();
  return lines.join('\n') +
      ((target ? diff.newTrailingNewline : diff.oldTrailingNewline)
          ? '\n'
          : '');
}

void main() {
  group('line diff', () {
    const service = RevisionTextDiffService();
    test('replacement, independent line numbers and deletion anchor', () {
      final diff = service.compare(
        chapterId: 'chapter',
        before: '一\n二\n三',
        after: '一\n新\n三',
      );
      expect(diff.addedLines, 1);
      expect(diff.removedLines, 1);
      expect(diff.hunks.single.oldStart, 1);
      expect(diff.hunks.single.newStart, 1);
      expect(diff.hunks.single.oldOffset, 2);
      expect(
        diff.lines
            .where((line) => line.kind == RevisionLineKind.removed)
            .single
            .after,
        isNull,
      );
      final deleted = service.compare(
        chapterId: 'chapter',
        before: '一\n二',
        after: '一',
      );
      expect(deleted.hunks.single.newOffset, 1);
    });
    test('CRLF normalization retains original UTF-16 offsets', () {
      final diff = service.compare(
        chapterId: 'chapter',
        before: '😀\r\n舊\r\n',
        after: '😀\n新\n',
      );
      expect(diff.hunks.single.oldOffset, 4);
      expect(diff.hunks.single.newOffset, 3);
      expect(diff.hunks.single.lines.first.before!.number, 2);
      expect(
        service
            .compare(chapterId: '', before: '甲\r\n乙\r\n', after: '甲\n乙\n')
            .hasChanges,
        isFalse,
      );
    });
    test('terminal newline has no phantom line; actual blank lines count', () {
      final terminal = service.compare(
        chapterId: '',
        before: '甲',
        after: '甲\n',
      );
      expect(terminal.addedLines, 0);
      expect(terminal.removedLines, 0);
      expect(terminal.trailingNewlineChanged, isTrue);
      expect(terminal.hunks.single.lines, isEmpty);
      expect(terminal.hunks.single.newOffset, 2);
      expect(
        service.compare(chapterId: '', before: '', after: '\n').addedLines,
        1,
      );
      expect(
        service
            .compare(chapterId: '', before: '甲\n', after: '甲\n\n')
            .addedLines,
        1,
      );
      expect(
        service.compare(chapterId: '', before: ' ', after: '').removedLines,
        1,
      );
    });
    test(
      'random edits reconstruct both documents and match minimal edit count',
      () {
        final random = Random(20260928);
        for (var sample = 0; sample < 250; sample++) {
          List<String> make() => List.generate(
            random.nextInt(14),
            (_) => ['甲', '乙', '😀', ' ', ''][random.nextInt(5)],
          );
          String document(List<String> lines) =>
              lines.isEmpty ? '' : '${lines.join('\n')}\n';
          final oldText = document(make());
          final newText = document(make());
          final diff = service.compare(
            chapterId: '',
            before: oldText,
            after: newText,
          );
          expect(_rebuild(diff, target: false), oldText);
          expect(_rebuild(diff, target: true), newText);
          final old = diff.lines
              .where((line) => line.before != null)
              .map((line) => line.before!.text)
              .toList();
          final next = diff.lines
              .where((line) => line.after != null)
              .map((line) => line.after!.text)
              .toList();
          final table = List.generate(
            old.length + 1,
            (_) => List.filled(next.length + 1, 0),
          );
          for (var i = old.length - 1; i >= 0; i--) {
            for (var j = next.length - 1; j >= 0; j--) {
              table[i][j] = old[i] == next[j]
                  ? 1 + table[i + 1][j + 1]
                  : max(table[i + 1][j], table[i][j + 1]);
            }
          }
          expect(
            diff.addedLines + diff.removedLines,
            old.length + next.length - 2 * table[0][0],
          );
        }
      },
    );
    test('bounded coarse fallback still reconstructs target', () {
      final diff = const RevisionTextDiffService(
        maximumTraceEntries: 0,
      ).compare(chapterId: '', before: '相同\n甲\n結束', after: '相同\n乙\n結束');
      expect(diff.isCoarse, isTrue);
      expect(_rebuild(diff, target: true), '相同\n乙\n結束');
    });
  });

  group('record diff', () {
    test('empty stable-ID collection produces member add/remove', () {
      final before = _snapshot([
        _record({'customValues': <Object?>[]}),
      ]);
      final after = _snapshot([
        _record({
          'customValues': [
            {'id': 'weather', 'key': '氣候', 'val': '冷'},
          ],
        }),
      ]);
      final added = RevisionRecordDiffService.compare(
        before,
        after,
      ).single.fields.single;
      expect(added.target.fieldPath, ['customValues', 'weather']);
      expect(added.kind, RevisionChangeKind.added);
      final removed = RevisionRecordDiffService.compare(
        after,
        before,
      ).single.fields.single;
      expect(removed.kind, RevisionChangeKind.removed);
    });
    test(
      'unregistered list ordering is visible rather than silently ignored',
      () {
        final before = _snapshot([
          _record({
            'aliases': [
              {'id': 'a', 'value': '甲'},
              {'id': 'b', 'value': '乙'},
            ],
          }),
        ]);
        final after = _snapshot([
          _record({
            'aliases': [
              {'id': 'b', 'value': '乙'},
              {'id': 'a', 'value': '甲'},
            ],
          }),
        ]);
        expect(
          RevisionRecordDiffService.compare(
            before,
            after,
          ).single.fields.single.target.fieldPath,
          ['aliases'],
        );
      },
    );
    test('same names with different IDs remain separate records', () {
      final first = _record({'displayName': '澪'});
      final second = _record(
        {'displayName': '澪'},
        key: const ProjectRecordKey(
          kind: ProjectRecordKind.character,
          recordId: 'another-id',
        ),
      );
      final changes = RevisionRecordDiffService.compare(
        _snapshot([first]),
        _snapshot([first, second]),
      );
      expect(changes.single.key.recordId, 'another-id');
      expect(changes.single.kind, RevisionChangeKind.added);
    });
    test('rename and single field change retain identity', () {
      final changes = RevisionRecordDiffService.compare(
        _snapshot([
          _record({'displayName': '林澪', 'age': '17'}),
        ]),
        _snapshot([
          _record({'displayName': '澪', 'age': '17'}),
        ]),
      );
      expect(changes.single.kind, RevisionChangeKind.modified);
      expect(changes.single.fields.single.target.fieldPath, ['displayName']);
      expect(
        RevisionFieldRegistry.pageFor(changes.single.key.kind),
        RevisionSidebarPage.characters,
      );
    });
    test(
      'presence is distinct from null and empty, nested names remain segments',
      () {
        final changes = RevisionRecordDiffService.compare(
          _snapshot([
            _record({
              'age': '17',
              'customFields': {
                'a/b': {'rawValue': '黑'},
              },
            }),
          ]),
          _snapshot([
            _record({
              'age': '',
              'nullable': null,
              'customFields': {
                'a/b': {'rawValue': '銀'},
              },
            }),
          ]),
        );
        final fields = changes.single.fields;
        expect(
          fields.map((field) => field.target.fieldPath),
          contains(orderedEquals(['customFields', 'a/b', 'rawValue'])),
        );
        final added = fields.singleWhere(
          (field) => field.target.fieldPath.first == 'nullable',
        );
        expect(added.kind, RevisionChangeKind.added);
        expect(added.oldExists, isFalse);
        expect(added.newExists, isTrue);
        expect(added.newValue, isNull);
        expect(
          fields
              .singleWhere((field) => field.target.fieldPath.first == 'age')
              .kind,
          RevisionChangeKind.modified,
        );
        final removed = RevisionRecordDiffService.compare(
          _snapshot([
            _record({'nullable': null}),
          ]),
          _snapshot([_record({})]),
        );
        expect(removed.single.fields.single.kind, RevisionChangeKind.removed);
      },
    );
    test('whole objects counted once with detached preview', () {
      final source = <String, Object?>{
        'nested': <String, Object?>{'value': 'old'},
      };
      final record = _record(source);
      (source['nested'] as Map)['value'] = 'new';
      final added = RevisionRecordDiffService.compare(
        _snapshot([]),
        _snapshot([record]),
      ).single;
      expect(added.kind, RevisionChangeKind.added);
      expect(added.fields, isEmpty);
      expect((added.after!.fields['nested'] as Map)['value'], 'old');
      expect(
        () => (added.after!.fields['nested'] as Map)['value'] = 'bad',
        throwsUnsupportedError,
      );
      expect(
        RevisionRecordDiffService.compare(
          _snapshot([record]),
          _snapshot([]),
        ).single.kind,
        RevisionChangeKind.removed,
      );
    });
    test(
      'stable list members avoid index drift and wire schema changes ignored',
      () {
        final changes = RevisionRecordDiffService.compare(
          _snapshot([
            _record({
              'schemaVersion': 1,
              'customValues': [
                {'id': 'a', 'val': '舊'},
              ],
            }),
          ]),
          _snapshot([
            _record({
              'schemaVersion': 2,
              'customValues': [
                {'id': 'b', 'val': '新'},
                {'id': 'a', 'val': '舊'},
              ],
            }),
          ]),
        );
        expect(changes.single.fields.single.target.fieldPath, [
          'customValues',
          'b',
        ]);
        expect(changes.single.fields.single.kind, RevisionChangeKind.added);
      },
    );
    test(
      'insertion/deletion shifts are ignored; real reorder and parent move shown',
      () {
        RevisionRecord folder(String id, int order, {String? parent}) =>
            _record(
              {'name': id, 'order': order},
              key: ProjectRecordKey(
                kind: ProjectRecordKind.chapterMetadata,
                recordId: id,
              ),
              parent: parent,
            );
        final before = _snapshot([folder('a', 0), folder('b', 1)]);
        final inserted = RevisionRecordDiffService.compare(
          before,
          _snapshot([folder('x', 0), folder('a', 1), folder('b', 2)]),
        );
        expect(inserted.length, 1);
        expect(inserted.single.kind, RevisionChangeKind.added);
        expect(
          RevisionRecordDiffService.compare(
            before,
            _snapshot([folder('b', 0)]),
          ).single.kind,
          RevisionChangeKind.removed,
        );
        final reordered = RevisionRecordDiffService.compare(
          before,
          _snapshot([folder('b', 0), folder('a', 1)]),
        );
        expect(reordered.length, 1);
        expect(reordered.single.fields.single.target.fieldPath, [r'$order']);
        final parent = RevisionRecordDiffService.compare(
          before,
          _snapshot([folder('a', 0, parent: 'new'), folder('b', 1)]),
        );
        expect(parent.single.fields.single.target.fieldPath, [r'$parent']);
      },
    );
  });

  test(
    'large chapter local edit remains exact and preserves separate hunks',
    () {
      final before = List.generate(10000, (i) => '行 $i');
      final after = [...before]
        ..[20] = '修订甲'
        ..[9980] = '修订乙';
      final diff = const RevisionTextDiffService().compare(
        chapterId: 'large',
        before: before.join('\n'),
        after: after.join('\n'),
      );
      expect(diff.isCoarse, isFalse);
      expect(diff.hunks.length, 2);
      expect(diff.addedLines, 2);
      expect(diff.removedLines, 2);
      expect(_rebuild(diff, target: true), after.join('\n'));
    },
  );

  test(
    'duplicate chapter identities fail instead of overwriting baseline text',
    () {
      final project = ProjectData.empty();
      project.segmentsData = [
        SegmentData(
          chapters: [
            ChapterData(chapterUUID: 'duplicate', chapterContent: '甲'),
            ChapterData(chapterUUID: 'duplicate', chapterContent: '乙'),
          ],
        ),
      ];
      expect(
        () => RevisionSnapshotBuilder.capture(project, version: 'base'),
        throwsStateError,
      );
    },
  );

  test(
    'project baseline uses chapter body, preserves text and reports unsupported kinds',
    () {
      final project = ProjectData.empty();
      project.characterData = {
        'character': CharacterEntryData(
          characterId: 'character',
          displayName: '澪',
          age: '17',
        ),
      };
      project.contentText = 'not chapter body';
      project.segmentsData = [
        SegmentData(
          segmentName: '資料夾',
          chapters: [
            ChapterData(
              chapterUUID: 'chapter',
              chapterName: '第一章',
              chapterContent: '舊正文',
            ),
          ],
        ),
      ];
      project.worldSettingsData = [
        LocationData(
          id: 'world',
          localName: '北境',
          customVal: [LocationCustomize(id: 'custom', key: '氣候', val: '冷')],
        ),
      ];
      final source = RevisionSnapshotBuilder.capture(project, version: 'base');
      project.characterData['character'] = project.characterData['character']!
          .copyWith(age: '18');
      project.segmentsData = [
        project.segmentsData.single.copyWith(
          chapters: [
            project.segmentsData.single.chapters.single.copyWith(
              chapterContent: '新正文',
            ),
          ],
        ),
      ];
      final baseline = RevisionBaseline(
        id: 'tracking',
        label: '開始追蹤',
        createdAt: DateTime.utc(2026),
        snapshot: source,
      );
      final target = RevisionSnapshotBuilder.capture(
        project,
        version: 'target',
      );
      final result = const RevisionComparisonService().compare(
        baseline,
        target,
      );
      expect(source.chapterTexts['chapter'], '舊正文');
      expect(result.addedLines, 1);
      expect(result.removedLines, 1);
      expect(result.records.single.fields.single.target.fieldPath, ['age']);
      expect(result.records.single.fields.single.oldValue, '17');
      expect(result.records.single.fields.single.newValue, '18');
      expect(
        result.unsupportedKinds,
        isNot(contains(ProjectRecordKind.outlineStoryline)),
      );
      final worldKey = const ProjectRecordKey(
        kind: ProjectRecordKind.worldNode,
        recordId: 'world',
      );
      expect(source.records[worldKey]!.fields['name'], '北境');
      final saved = RevisionSnapshotBuilder.capture(project, version: 'saved');
      expect(
        const RevisionComparisonService().compare(baseline, saved).hasChanges,
        isTrue,
      );
      project.projectUUID = ProjectData.createProjectUUID();
      expect(
        () => const RevisionComparisonService().compare(
          baseline,
          RevisionSnapshotBuilder.capture(project, version: 'other'),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'outline and item changes retain stable records and field review rules',
    () {
      final project = ProjectData.empty();
      project.outlineData = [
        StorylineData(
          chapterUUID: 'story',
          storylineName: '舊故事線',
          scenes: [
            StoryEventData(
              storyEventUUID: 'event',
              storyEvent: '舊事件',
              scenes: [SceneData(sceneUUID: 'scene', sceneName: '舊場景')],
            ),
          ],
        ),
      ];
      project.itemClasses = {
        'class': ItemClassData(
          classId: 'class',
          name: '舊物品',
          description: '舊設定',
        ),
      };
      final baseline = RevisionBaseline(
        id: 'baseline',
        label: '舊版',
        createdAt: DateTime.utc(2026),
        snapshot: RevisionSnapshotBuilder.capture(project, version: 'before'),
      );
      project.outlineData = [
        project.outlineData.single.copyWith(
          storylineName: '新故事線',
          scenes: [
            project.outlineData.single.scenes.single.copyWith(
              scenes: [SceneData(sceneUUID: 'scene', sceneName: '新場景')],
            ),
          ],
        ),
      ];
      project.itemClasses = {
        'class': project.itemClasses['class']!.copyWith(description: '新設定'),
      };
      final result = const RevisionComparisonService().compare(
        baseline,
        RevisionSnapshotBuilder.capture(project, version: 'after'),
      );
      final byKind = {
        for (final record in result.records) record.key.kind: record,
      };
      expect(
        byKind[ProjectRecordKind.outlineStoryline]!
            .fields
            .single
            .target
            .fieldPath,
        ['name'],
      );
      expect(
        byKind[ProjectRecordKind.outlineScene]!.fields.single.target.fieldPath,
        ['name'],
      );
      expect(
        byKind[ProjectRecordKind.itemClass]!.fields.single.target.fieldPath,
        ['description'],
      );
      expect(
        RevisionReviewService.canRejectField(
          byKind[ProjectRecordKind.itemClass]!,
          byKind[ProjectRecordKind.itemClass]!.fields.single,
        ),
        isTrue,
      );
      expect(
        RevisionFieldRegistry.pageFor(ProjectRecordKind.outlineEvent),
        RevisionSidebarPage.outline,
      );
      expect(
        RevisionFieldRegistry.pageFor(ProjectRecordKind.itemRelation),
        RevisionSidebarPage.items,
      );
    },
  );

  test('item class fields do not duplicate mirrored default state text', () {
    const key = ProjectRecordKey(
      kind: ProjectRecordKind.itemClass,
      recordId: 'item',
    );
    final before = _snapshot([
      _record({
        'name': '舊',
        'defaultState': {'name': '舊'},
      }, key: key),
    ]);
    final after = _snapshot([
      _record({
        'name': '新',
        'defaultState': {'name': '新'},
      }, key: key),
    ], version: 'v2');
    final diff = RevisionRecordDiffService.compare(before, after);
    expect(diff.single.fields.map((field) => field.target.fieldPath), [
      ['name'],
    ]);
  });
}
