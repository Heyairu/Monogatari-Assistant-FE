import "../../models/character_data.dart";
import "../../models/outline_data.dart";
import "../../models/plan_data.dart";
import "../../models/world_settings_data.dart";
import "inline_annotation.dart";

final class InlineAnnotationTargetInfo {
  final String id;
  final String primaryName;
  final String displayName;
  final bool displayNameIsAlias;
  final String? path;
  final List<String> aliases;
  final List<InlineAnnotationTargetInfo> children;

  const InlineAnnotationTargetInfo({
    required this.id,
    required this.primaryName,
    required this.displayName,
    required this.displayNameIsAlias,
    this.path,
    this.aliases = const [],
    this.children = const [],
  });
}

final class InlineAnnotationTargetResolver {
  const InlineAnnotationTargetResolver();

  List<InlineAnnotationTargetInfo> candidates({
    required InlineAnnotationKind kind,
    Map<String, CharacterEntryData> characters = const {},
    List<LocationData> locations = const [],
    List<StorylineData> outline = const [],
    List<ForeshadowItem> foreshadows = const [],
    List<UpdatePlanItem> plans = const [],
  }) {
    final results = switch (kind) {
      InlineAnnotationKind.character => <InlineAnnotationTargetInfo>[
        for (final entry in characters.entries)
          InlineAnnotationTargetInfo(
            id: entry.value.characterId.trim().isEmpty
                ? entry.key
                : entry.value.characterId,
            primaryName: entry.value.displayName,
            displayName: entry.value.displayName,
            displayNameIsAlias: false,
            aliases: _characterAliases(entry.value),
          ),
      ],
      InlineAnnotationKind.location => _locationCandidates(locations),
      InlineAnnotationKind.event => _eventCandidates(outline),
      InlineAnnotationKind.foreshadowing => <InlineAnnotationTargetInfo>[
        for (final item in foreshadows)
          _info(item.id, item.title, item.isRevealed ? "已回收" : "未回收"),
      ],
      InlineAnnotationKind.plan => <InlineAnnotationTargetInfo>[
        for (final item in plans)
          _info(item.id, item.title, item.isDone ? "已完成" : "進行中"),
      ],
      InlineAnnotationKind.emphasis => const <InlineAnnotationTargetInfo>[],
    };
    results.sort((left, right) {
      final byName = left.primaryName.toLowerCase().compareTo(
        right.primaryName.toLowerCase(),
      );
      return byName != 0 ? byName : left.id.compareTo(right.id);
    });
    return List<InlineAnnotationTargetInfo>.unmodifiable(results);
  }

  InlineAnnotationTargetInfo? resolve({
    required InlineAnnotation annotation,
    Map<String, CharacterEntryData> characters = const {},
    List<LocationData> locations = const [],
    List<StorylineData> outline = const [],
    List<ForeshadowItem> foreshadows = const [],
    List<UpdatePlanItem> plans = const [],
  }) {
    final id = annotation.targetId;
    if (id == null) return null;
    return switch (annotation.kind) {
      InlineAnnotationKind.character => _character(
        id,
        annotation.displayText,
        characters,
      ),
      InlineAnnotationKind.location => _location(id, locations),
      InlineAnnotationKind.event => _event(id, outline),
      InlineAnnotationKind.foreshadowing => _foreshadow(id, foreshadows),
      InlineAnnotationKind.plan => _plan(id, plans),
      InlineAnnotationKind.emphasis => null,
    };
  }

  InlineAnnotationTargetInfo? _character(
    String id,
    String projectedName,
    Map<String, CharacterEntryData> characters,
  ) {
    CharacterEntryData? entry = characters[id];
    if (entry == null) {
      for (final candidate in characters.values) {
        if (candidate.characterId == id) {
          entry = candidate;
          break;
        }
      }
    }
    if (entry == null) return null;
    final aliases = _characterAliases(entry);
    final isAlias =
        projectedName != entry.displayName &&
        aliases.any((alias) => alias == projectedName);
    return InlineAnnotationTargetInfo(
      id: id,
      primaryName: entry.displayName,
      displayName: projectedName,
      displayNameIsAlias: isAlias,
      aliases: aliases,
    );
  }

  List<String> _characterAliases(CharacterEntryData entry) {
    return List<String>.unmodifiable({
      for (final alias in entry.aliases)
        for (final value in alias.values)
          if (value.trim().isNotEmpty && value != entry.displayName)
            value.trim(),
    });
  }

  InlineAnnotationTargetInfo? _location(String id, List<LocationData> roots) {
    InlineAnnotationTargetInfo? visit(LocationData node, List<String> path) {
      final nextPath = <String>[...path, node.localName];
      if (node.id == id) {
        return InlineAnnotationTargetInfo(
          id: id,
          primaryName: node.localName,
          displayName: node.localName,
          displayNameIsAlias: false,
          path: nextPath.where((part) => part.isNotEmpty).join(" › "),
        );
      }
      for (final child in node.child) {
        final result = visit(child, nextPath);
        if (result != null) return result;
      }
      return null;
    }

    for (final root in roots) {
      final result = visit(root, const []);
      if (result != null) return result;
    }
    return null;
  }

  List<InlineAnnotationTargetInfo> _locationCandidates(
    List<LocationData> roots,
  ) {
    final results = <InlineAnnotationTargetInfo>[];
    InlineAnnotationTargetInfo build(LocationData node, List<String> path) {
      final nextPath = <String>[...path, node.localName];
      final info = InlineAnnotationTargetInfo(
        id: node.id,
        primaryName: node.localName,
        displayName: node.localName,
        displayNameIsAlias: false,
        path: nextPath.where((part) => part.isNotEmpty).join(" › "),
        children: [for (final child in node.child) build(child, nextPath)],
      );
      return info;
    }

    void flatten(InlineAnnotationTargetInfo target) {
      results.add(target);
      for (final child in target.children) {
        flatten(child);
      }
    }

    for (final root in roots) {
      final rootInfo = build(root, const []);
      flatten(rootInfo);
    }
    return results;
  }

  InlineAnnotationTargetInfo? _event(
    String id,
    List<StorylineData> storylines,
  ) {
    for (final storyline in storylines) {
      if (storyline.chapterUUID == id) {
        return _info(id, storyline.storylineName, storyline.storylineName);
      }
      for (final event in storyline.scenes) {
        if (event.storyEventUUID == id) {
          return _info(
            id,
            event.storyEvent,
            "${storyline.storylineName} › ${event.storyEvent}",
          );
        }
        for (final scene in event.scenes) {
          if (scene.sceneUUID == id) {
            return _info(
              id,
              scene.sceneName,
              "${storyline.storylineName} › ${event.storyEvent} › ${scene.sceneName}",
            );
          }
        }
      }
    }
    return null;
  }

  List<InlineAnnotationTargetInfo> _eventCandidates(
    List<StorylineData> storylines,
  ) {
    final results = <InlineAnnotationTargetInfo>[];
    for (final storyline in storylines) {
      final root = InlineAnnotationTargetInfo(
        id: storyline.chapterUUID,
        primaryName: storyline.storylineName,
        displayName: storyline.storylineName,
        displayNameIsAlias: false,
        path: storyline.storylineName,
        children: [
          for (final event in storyline.scenes)
            InlineAnnotationTargetInfo(
              id: event.storyEventUUID,
              primaryName: event.storyEvent,
              displayName: event.storyEvent,
              displayNameIsAlias: false,
              path: "${storyline.storylineName} › ${event.storyEvent}",
              children: [
                for (final scene in event.scenes)
                  _info(
                    scene.sceneUUID,
                    scene.sceneName,
                    "${storyline.storylineName} › ${event.storyEvent} › ${scene.sceneName}",
                  ),
              ],
            ),
        ],
      );

      void flatten(InlineAnnotationTargetInfo target) {
        results.add(target);
        for (final child in target.children) {
          flatten(child);
        }
      }

      flatten(root);
    }
    return results;
  }

  InlineAnnotationTargetInfo? _foreshadow(
    String id,
    List<ForeshadowItem> items,
  ) {
    for (final item in items) {
      if (item.id == id) {
        return _info(id, item.title, item.isRevealed ? "已回收" : "未回收");
      }
    }
    return null;
  }

  InlineAnnotationTargetInfo? _plan(String id, List<UpdatePlanItem> items) {
    for (final item in items) {
      if (item.id == id) {
        return _info(id, item.title, item.isDone ? "已完成" : "進行中");
      }
    }
    return null;
  }

  InlineAnnotationTargetInfo _info(String id, String name, String? path) {
    return InlineAnnotationTargetInfo(
      id: id,
      primaryName: name,
      displayName: name,
      displayNameIsAlias: false,
      path: path,
    );
  }
}
