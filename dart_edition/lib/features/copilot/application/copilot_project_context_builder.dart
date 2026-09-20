import "../../../models/glossary_data.dart";
import "../../../models/project_data.dart";
import "../../story_read/application/project_read_service.dart";
import "../../story_read/application/project_read_snapshot_builder.dart";
import "../../story_read/domain/project_read_models.dart";
import "../domain/copilot_models.dart";

/// Backwards-compatible Copilot presentation model backed by the shared
/// read-only story resource contract used by future MCP integration.
final class CopilotSelectableResource {
  final ProjectReadSelectableResource _delegate;

  CopilotSelectableResource({
    required String resourceType,
    required String resourceId,
    required String title,
    required String description,
    required String Function() contentBuilder,
  }) : _delegate = ProjectReadSelectableResource(
         resourceType: resourceType,
         resourceId: resourceId,
         title: title,
         description: description,
         content: contentBuilder(),
       );

  CopilotSelectableResource._(this._delegate);

  String get resourceType => _delegate.resourceType;
  String get resourceId => _delegate.resourceId;
  String get title => _delegate.title;
  String get description => _delegate.description;
  String get selectionKey => _delegate.selectionKey;

  CopilotContextResource toContextResource({required int maxBytes}) {
    return _toCopilotResource(_delegate.toResource(maxBytes: maxBytes));
  }
}

final class CopilotProjectContextBuilder {
  static const int maxOverviewBytes = ProjectReadBudget.maxOverviewBytes;
  static const int maxChapterIndexItems =
      ProjectReadBudget.maxChapterIndexItems;
  static const int maxCharacterItems = ProjectReadBudget.maxCharacterItems;
  static const int maxOutlineItems = ProjectReadBudget.maxOutlineItems;
  static const int maxWorldItems = ProjectReadBudget.maxWorldItems;
  static const int maxGlossaryItems = ProjectReadBudget.maxGlossaryItems;
  static const int maxSelectedResources =
      ProjectReadBudget.maxSelectedResources;
  static const int maxSelectedResourceBytes =
      ProjectReadBudget.maxSelectedResourceBytes;
  static const int maxSelectedResourcesBytes =
      ProjectReadBudget.maxSelectedResourcesBytes;

  const CopilotProjectContextBuilder._();

  static List<CopilotSelectableResource> selectableResources(
    ProjectData project, {
    Map<String, GlossaryEntry> glossaryEntries =
        const <String, GlossaryEntry>{},
  }) {
    return List<CopilotSelectableResource>.unmodifiable(
      ProjectReadSnapshotBuilder.selectableResources(
        project,
        glossaryEntries: glossaryEntries,
      ).map(CopilotSelectableResource._),
    );
  }

  static List<CopilotContextResource> buildSelectedResources(
    ProjectData project, {
    required Set<String> selectionKeys,
    Map<String, GlossaryEntry> glossaryEntries =
        const <String, GlossaryEntry>{},
  }) {
    if (selectionKeys.length > maxSelectedResources) {
      throw const FormatException("Ask 最多可選擇 12 個補充資源。");
    }
    final snapshot = ProjectReadSnapshotBuilder.build(
      project,
      glossaryEntries: glossaryEntries,
    );
    final refs = snapshot.entities
        .where((resource) => selectionKeys.contains(resource.selectionKey))
        .map(
          (resource) => ProjectReadResourceRef(
            resourceType: resource.resourceType,
            resourceId: resource.resourceId,
          ),
        );
    return List<CopilotContextResource>.unmodifiable(
      ProjectReadService.buildSelectedResources(
        snapshot,
        resourceRefs: refs,
      ).map(_toCopilotResource),
    );
  }

  static CopilotContextResource buildOverview(ProjectData project) {
    return _toCopilotResource(
      ProjectReadSnapshotBuilder.buildOverview(project),
    );
  }
}

CopilotContextResource _toCopilotResource(ProjectReadResource resource) {
  return CopilotContextResource(
    resourceType: resource.resourceType,
    resourceId: resource.resourceId,
    title: resource.title,
    content: resource.content,
    truncated: resource.truncated,
  );
}
