import 'package:flutter_test/flutter_test.dart';
import 'package:monogatari_assistant/bin/file.dart';
import 'package:monogatari_assistant/features/revision_tracking/application/revision_session_codec.dart';
import 'package:monogatari_assistant/features/revision_tracking/application/revision_snapshot_builder.dart';
import 'package:monogatari_assistant/features/revision_tracking/domain/revision_models.dart';

void main() {
  test(
    'revision session survives project XML round-trip without recursive growth',
    () {
      final project = ProjectData.empty();
      final baseline = RevisionBaseline(
        id: 'first',
        label: '起點',
        createdAt: DateTime.utc(2026, 9, 28),
        snapshot: RevisionSnapshotBuilder.capture(project, version: 'v1'),
      );
      final checkpoint = RevisionBaseline(
        id: 'later',
        label: '第二版',
        createdAt: DateTime.utc(2026, 9, 29),
        snapshot: RevisionSnapshotBuilder.capture(project, version: 'v2'),
      );
      final encoded = RevisionSessionCodec.encode(
        RevisionSessionData(
          selectedBaselineId: 'first',
          baselines: [baseline, checkpoint],
          acceptedEvents: {'field:accepted'},
        ),
      );
      project.revisionTrackingJson = encoded;
      final xml = FileService.generateProjectXMLWithoutLatestSaveUpdate(
        project,
      );
      final parsed = FileService.parseProjectXML(xml);
      expect(parsed.revisionTrackingJson, encoded);
      final restored = RevisionSessionCodec.decode(
        parsed.revisionTrackingJson!,
        projectId: parsed.projectUUID,
      );
      expect(restored.baselines.map((item) => item.id), ['first', 'later']);
      expect(restored.acceptedEvents, contains('field:accepted'));
      expect(
        FileService.generateProjectXMLWithoutLatestSaveUpdate(parsed),
        xml,
      );
    },
  );

  test('older project has no session and mismatched baseline is rejected', () {
    final project = ProjectData.empty();
    final xml = FileService.generateProjectXMLWithoutLatestSaveUpdate(project);
    expect(FileService.parseProjectXML(xml).revisionTrackingJson, isNull);
    final baseline = RevisionBaseline(
      id: 'first',
      label: '起點',
      createdAt: DateTime.utc(2026),
      snapshot: RevisionSnapshotBuilder.capture(project, version: 'v1'),
    );
    final encoded = RevisionSessionCodec.encode(
      RevisionSessionData(
        selectedBaselineId: 'first',
        baselines: [baseline],
        acceptedEvents: {},
      ),
    );
    expect(
      () => RevisionSessionCodec.decode(
        encoded,
        projectId: ProjectData.createProjectUUID(),
      ),
      throwsFormatException,
    );
  });

  test('damaged revision block stays available for recovery', () {
    final project = ProjectData.empty();
    final xml = FileService.generateProjectXMLWithoutLatestSaveUpdate(project)
        .replaceFirst(
          '</Project>',
          '<Type><Name>RevisionTracking</Name><Data>bad%%%payload</Data></Type></Project>',
        );
    final parsed = FileService.parseProjectXML(xml);
    expect(parsed.revisionTrackingJson, 'bad%%%payload');
    expect(
      () => RevisionSessionCodec.decode(
        parsed.revisionTrackingJson!,
        projectId: parsed.projectUUID,
      ),
      throwsFormatException,
    );
  });

  test(
    'schema 1 sessions remain readable and review decisions have a stable digest',
    () {
      final project = ProjectData.empty();
      final baseline = RevisionBaseline(
        id: 'first',
        label: '起點',
        createdAt: DateTime.utc(2026),
        snapshot: RevisionSnapshotBuilder.capture(project, version: 'v1'),
      );
      final encoded = RevisionSessionCodec.encode(
        RevisionSessionData(
          selectedBaselineId: 'first',
          baselines: [baseline],
          acceptedEvents: {'b', 'a'},
        ),
      );
      final legacy = encoded.replaceFirst(
        '"schemaVersion":2',
        '"schemaVersion":1',
      );
      final restored = RevisionSessionCodec.decode(
        legacy,
        projectId: project.projectUUID,
      );
      expect(restored.baselines.single.readOnly, isFalse);
      expect(restored.acceptedEvents, {'a', 'b'});
      expect(RevisionSessionCodec.decisionDigest(encoded), '["a","b"]');
      expect(RevisionSessionCodec.decisionDigest(legacy), '["a","b"]');
    },
  );
}
