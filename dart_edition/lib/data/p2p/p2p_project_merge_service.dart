import "../../bin/file.dart";
import "../../domain/models/p2p_revision_models.dart";
import "../../domain/models/p2p_sync_models.dart";
import "../../models/base_info_data.dart";
import "p2p_project_merge.dart";

class P2pProjectMergeService {
  final P2pProjectMergeEngine _engine;

  const P2pProjectMergeService({
    P2pProjectMergeEngine engine = const P2pProjectMergeEngine(),
  }) : _engine = engine;

  P2pProjectMergePlan createPlanFromVerifiedXml({
    required String sessionId,
    required P2pRevisionMetadata baseRevision,
    required P2pRevisionMetadata localRevision,
    required P2pRevisionMetadata remoteRevision,
    required String baseXml,
    required String localXml,
    required String remoteXml,
  }) {
    final base = FileService.parseProjectXMLWithMetadata(baseXml);
    final local = FileService.parseProjectXMLWithMetadata(localXml);
    final remote = FileService.parseProjectXMLWithMetadata(remoteXml);
    final remainderSignatures = P2pProjectRemainderSignatures(
      base: _remainderSignature(base.data),
      local: _remainderSignature(local.data),
      remote: _remainderSignature(remote.data),
    );
    return _engine.createPlan(
      sessionId: sessionId,
      baseRevision: baseRevision,
      localRevision: localRevision,
      remoteRevision: remoteRevision,
      base: base.data,
      local: local.data,
      remote: remote.data,
      remainderSignatures: remainderSignatures,
    );
  }

  P2pProjectMergePlan createPlanFromUnrelatedVerifiedXml({
    required String sessionId,
    required P2pRevisionMetadata localRevision,
    required P2pRevisionMetadata remoteRevision,
    required String localXml,
    required String remoteXml,
  }) {
    final local = FileService.parseProjectXMLWithMetadata(localXml);
    final remote = FileService.parseProjectXMLWithMetadata(remoteXml);
    return _engine.createPlanWithoutCommonAncestor(
      sessionId: sessionId,
      localRevision: localRevision,
      remoteRevision: remoteRevision,
      local: local.data,
      remote: remote.data,
      localRemainderSignature: _remainderSignature(local.data),
      remoteRemainderSignature: _remainderSignature(remote.data),
    );
  }

  String resolveToXml(
    P2pProjectMergePlan plan,
    P2pConflictResolutionResult resolutions,
  ) {
    return FileService.generateProjectXMLWithoutLatestSaveUpdate(
      plan.apply(resolutions),
    );
  }

  String _remainderSignature(ProjectData data) {
    final remainder = ProjectData(
      projectUUID: data.projectUUID,
      baseInfoData: const BaseInfoData(),
      segmentsData: data.segmentsData,
      outlineData: data.outlineData,
      foreshadowData: data.foreshadowData,
      updatePlanData: data.updatePlanData,
      worldSettingsData: data.worldSettingsData,
      characterData: const {},
      characterStates: data.characterStates,
      characterStateBaselines: data.characterStateBaselines,
      characterStateChanges: data.characterStateChanges,
      timelineDocument: data.timelineDocument,
      outlineChapterLinks: data.outlineChapterLinks,
      totalWords: data.totalWords,
      contentText: data.contentText,
      isDirty: false,
    );
    return FileService.generateProjectXMLWithoutLatestSaveUpdate(remainder);
  }
}
