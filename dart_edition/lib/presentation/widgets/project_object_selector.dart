import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../models/item_data.dart";
import "../../models/world_settings_data.dart";
import "../providers/project_state_providers.dart";
import "../providers/timeline_providers.dart";
import "../../ui_library/forms.dart";

enum ProjectObjectKind {
  itemClass,
  itemInstance,
  character,
  location,
  event,
  scene,
}

class ProjectObjectSelection {
  final ProjectObjectKind kind;
  final String id;
  final String label;
  final String? classId;

  const ProjectObjectSelection({
    required this.kind,
    required this.id,
    required this.label,
    this.classId,
  });

  String get key => "${kind.name}:$id";

  ItemReferenceKind? get itemReferenceKind => switch (kind) {
    ProjectObjectKind.itemClass => ItemReferenceKind.itemClass,
    ProjectObjectKind.itemInstance => ItemReferenceKind.instance,
    _ => null,
  };

  ItemRelationTargetKind? get relationTargetKind => switch (kind) {
    ProjectObjectKind.character => ItemRelationTargetKind.character,
    ProjectObjectKind.location => ItemRelationTargetKind.location,
    ProjectObjectKind.event => ItemRelationTargetKind.event,
    ProjectObjectKind.scene => ItemRelationTargetKind.scene,
    _ => null,
  };
}

Future<ProjectObjectSelection?> showProjectObjectSelector({
  required BuildContext context,
  required Set<ProjectObjectKind> allowedKinds,
  Set<String> excludedKeys = const {},
  String title = "選擇物件",
}) {
  return showDialog<ProjectObjectSelection>(
    context: context,
    builder: (context) => ProjectObjectSelectorDialog(
      allowedKinds: allowedKinds,
      excludedKeys: excludedKeys,
      title: title,
    ),
  );
}

class ProjectObjectSelectorDialog extends ConsumerStatefulWidget {
  final Set<ProjectObjectKind> allowedKinds;
  final Set<String> excludedKeys;
  final String title;

  const ProjectObjectSelectorDialog({
    super.key,
    required this.allowedKinds,
    this.excludedKeys = const {},
    this.title = "選擇物件",
  });

  @override
  ConsumerState<ProjectObjectSelectorDialog> createState() =>
      _ProjectObjectSelectorDialogState();
}

class _ProjectObjectSelectorDialogState
    extends ConsumerState<ProjectObjectSelectorDialog> {
  final _searchController = TextEditingController();
  bool _includeArchived = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildEntries();
    final query = _searchController.text.trim().toLowerCase();
    final visible = entries
        .where((entry) => !widget.excludedKeys.contains(entry.selection.key))
        .where(
          (entry) =>
              query.isEmpty || entry.searchText.toLowerCase().contains(query),
        )
        .toList(growable: false);
    final supportsArchived =
        widget.allowedKinds.contains(ProjectObjectKind.itemClass) ||
        widget.allowedKinds.contains(ProjectObjectKind.itemInstance);

    return AlertDialog(
      key: const Key("project-object-selector"),
      title: Text(widget.title),
      content: SizedBox(
        width: 620,
        height: 520,
        child: Column(
          children: [
            TextField(
              key: const Key("project-object-selector-search"),
              controller: _searchController,
              autofocus: true,
              decoration: appFieldDecoration(
                context,
                decoration: const InputDecoration(
                  labelText: "搜尋名稱、類型或所屬資訊",
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (supportsArchived)
              Align(
                alignment: Alignment.centerLeft,
                child: CheckboxListTile(
                  key: const Key("project-object-selector-archived"),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text("顯示封存物品"),
                  value: _includeArchived,
                  onChanged: (value) =>
                      setState(() => _includeArchived = value ?? false),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text("沒有符合條件的物件。"))
                  : ListView.separated(
                      key: const Key("project-object-selector-results"),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = visible[index];
                        return ListTile(
                          key: ValueKey(
                            "project-object-${entry.selection.kind.name}-${entry.selection.id}",
                          ),
                          leading: Icon(entry.icon),
                          title: Text(entry.selection.label),
                          subtitle: Text(entry.subtitle),
                          onTap: () => Navigator.pop(context, entry.selection),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("取消"),
        ),
      ],
    );
  }

  List<_ProjectObjectEntry> _buildEntries() {
    final result = <_ProjectObjectEntry>[];
    final characters = ref.watch(characterDataProvider);
    final locations = <String, String>{};
    void collectLocations(List<LocationData> nodes, [String path = ""]) {
      for (final node in nodes) {
        final name = node.localName.trim().isEmpty ? "未命名地點" : node.localName;
        final label = path.isEmpty ? name : "$path / $name";
        locations[node.id] = label;
        collectLocations(node.child, label);
      }
    }

    collectLocations(ref.watch(worldSettingsDataProvider));

    if (widget.allowedKinds.contains(ProjectObjectKind.character)) {
      for (final entry in characters.entries) {
        final name = entry.value.displayName.trim();
        result.add(
          _ProjectObjectEntry(
            selection: ProjectObjectSelection(
              kind: ProjectObjectKind.character,
              id: entry.key,
              label: name.isEmpty ? "未命名人物" : name,
            ),
            subtitle:
                "人物${entry.value.roleOrOccupation.trim().isEmpty ? "" : "・${entry.value.roleOrOccupation}"}",
            icon: Icons.person_outline,
          ),
        );
      }
    }
    if (widget.allowedKinds.contains(ProjectObjectKind.location)) {
      for (final entry in locations.entries) {
        result.add(
          _ProjectObjectEntry(
            selection: ProjectObjectSelection(
              kind: ProjectObjectKind.location,
              id: entry.key,
              label: entry.value,
            ),
            subtitle: "地點",
            icon: Icons.place_outlined,
          ),
        );
      }
    }

    final outline = ref.watch(outlineDataProvider);
    for (final storyline in outline) {
      for (final event in storyline.scenes) {
        final eventName = event.storyEvent.trim().isEmpty
            ? "未命名事件"
            : event.storyEvent;
        if (widget.allowedKinds.contains(ProjectObjectKind.event)) {
          result.add(
            _ProjectObjectEntry(
              selection: ProjectObjectSelection(
                kind: ProjectObjectKind.event,
                id: event.storyEventUUID,
                label: eventName,
              ),
              subtitle: "事件・${storyline.storylineName}",
              icon: Icons.event_note_outlined,
            ),
          );
        }
        if (widget.allowedKinds.contains(ProjectObjectKind.scene)) {
          for (final scene in event.scenes) {
            final sceneName = scene.sceneName.trim().isEmpty
                ? "未命名場景"
                : scene.sceneName;
            result.add(
              _ProjectObjectEntry(
                selection: ProjectObjectSelection(
                  kind: ProjectObjectKind.scene,
                  id: scene.sceneUUID,
                  label: "$eventName / $sceneName",
                ),
                subtitle: "場景・${storyline.storylineName}",
                icon: Icons.movie_outlined,
              ),
            );
          }
        }
      }
    }

    final needsItems =
        widget.allowedKinds.contains(ProjectObjectKind.itemClass) ||
        widget.allowedKinds.contains(ProjectObjectKind.itemInstance);
    if (needsItems) {
      final workspace = ref.watch(itemWorkspaceProvider);
      final snapshotIndex = ref.watch(projectStoryStateIndexProvider);
      final tick = ref.watch(
        timelineViewProvider.select((state) => state.currentTick),
      );
      final classes = workspace.itemClasses.values.toList(growable: false)
        ..sort((a, b) => a.name.compareTo(b.name));
      for (final itemClass in classes) {
        if (itemClass.archived && !_includeArchived) continue;
        final classState = snapshotIndex.resolveItemClass(itemClass, tick);
        final className = classState.name.trim().isNotEmpty
            ? classState.name
            : itemClass.name.trim().isEmpty
            ? "未命名物品 Class"
            : itemClass.name;
        if (widget.allowedKinds.contains(ProjectObjectKind.itemClass)) {
          final allocationText = classState.allocations.isEmpty
              ? "未分配"
              : "${classState.allocations.length} 筆分配";
          result.add(
            _ProjectObjectEntry(
              selection: ProjectObjectSelection(
                kind: ProjectObjectKind.itemClass,
                id: itemClass.classId,
                classId: itemClass.classId,
                label: className,
              ),
              subtitle:
                  "物品 Class・${_modeLabel(itemClass.mode)}・$allocationText${itemClass.archived ? "・已封存" : ""}",
              icon: Icons.category_outlined,
            ),
          );
        }
        if (!widget.allowedKinds.contains(ProjectObjectKind.itemInstance)) {
          continue;
        }
        for (final instance in workspace.itemInstances.values.where(
          (value) => value.classId == itemClass.classId,
        )) {
          if ((itemClass.archived || instance.archived) && !_includeArchived) {
            continue;
          }
          final state = snapshotIndex.resolveItemInstance(
            itemClass: itemClass,
            instance: instance,
            atTick: tick,
          );
          final name = state.name.trim().isNotEmpty
              ? state.name
              : instance.name.trim().isEmpty
              ? className
              : instance.name;
          final assignment = <String>[
            if (state.holderCharacterId != null)
              "持有人：${characters[state.holderCharacterId]?.displayName ?? state.holderCharacterId}",
            if (state.locationId != null)
              "所在地：${locations[state.locationId] ?? state.locationId}",
          ];
          result.add(
            _ProjectObjectEntry(
              selection: ProjectObjectSelection(
                kind: ProjectObjectKind.itemInstance,
                id: instance.instanceId,
                classId: itemClass.classId,
                label: name,
              ),
              subtitle:
                  "單件物品・$className・${assignment.isEmpty ? "未指派" : assignment.join("・")}${instance.archived ? "・已封存" : ""}",
              icon: Icons.inventory_2_outlined,
            ),
          );
        }
      }
    }

    result.sort((a, b) {
      final byKind = a.selection.kind.index.compareTo(b.selection.kind.index);
      return byKind != 0
          ? byKind
          : a.selection.label.compareTo(b.selection.label);
    });
    return result;
  }
}

String _modeLabel(ItemMode mode) => switch (mode) {
  ItemMode.dedicated => "專用",
  ItemMode.semiDedicated => "半專用",
  ItemMode.generic => "非專用",
};

class _ProjectObjectEntry {
  final ProjectObjectSelection selection;
  final String subtitle;
  final IconData icon;

  const _ProjectObjectEntry({
    required this.selection,
    required this.subtitle,
    required this.icon,
  });

  String get searchText => "${selection.label} $subtitle ${selection.id}";
}
