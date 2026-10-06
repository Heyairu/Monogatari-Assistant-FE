import "package:xml/xml.dart" as xml;

import "../../models/item_data.dart";
import "../../models/project_data.dart";
import "../../models/world_settings_data.dart";
import "../../features/inline_annotations/inline_annotation_target_resolver.dart";
import "../../features/phrases/phrase_body_validator.dart";
import "../../features/phrases/phrase_entry.dart";

enum SelectiveProjectModule {
  baseInfo("BaseInfo", "故事設定"),
  chapters("Chapters", "章節內容"),
  outline("Outline", "大綱與時間軸"),
  plans("Plans", "更新計畫與伏筆"),
  worldSettings("WorldSettings", "世界設定與地點快照"),
  characters("Characters", "角色設定與快照"),
  items("Items", "物品設定與快照"),
  phrases("Phrases", "短語庫");

  final String id;
  final String label;

  const SelectiveProjectModule(this.id, this.label);
}

class SelectiveProjectImportManifest {
  final Set<String> typeNames;
  final Set<SelectiveProjectModule> declaredModules;
  final Set<SelectiveProjectModule> availableModules;

  SelectiveProjectImportManifest._(
    this.typeNames,
    this.declaredModules,
    this.availableModules,
  );

  factory SelectiveProjectImportManifest.fromXml(String sourceXml) {
    final document = xml.XmlDocument.parse(sourceXml);
    final root = document.rootElement;
    if (root.name.local != "Project") {
      throw const FormatException("匯入檔案的根節點必須是 Project。");
    }
    final names = <String>{
      for (final type in root.findElements("Type"))
        if (type.getElement("Name") case final name?) name.innerText.trim(),
    };
    final declared = <SelectiveProjectModule>{};
    for (final value
        in root
            .findElements("SelectiveExport")
            .expand((element) => element.findElements("Module"))) {
      final id = value.innerText.trim();
      for (final module in SelectiveProjectModule.values) {
        if (module.id == id) declared.add(module);
      }
    }
    final modules = <SelectiveProjectModule>{...declared};
    void addWhen(SelectiveProjectModule module, Iterable<String> candidates) {
      if (candidates.any(names.contains)) modules.add(module);
    }

    addWhen(SelectiveProjectModule.baseInfo, const <String>["BaseInfo"]);
    addWhen(SelectiveProjectModule.chapters, const <String>[
      "ChapterSelection",
    ]);
    addWhen(SelectiveProjectModule.outline, const <String>[
      "Outline",
      "Timeline",
    ]);
    addWhen(SelectiveProjectModule.plans, const <String>["PlanSettings"]);
    addWhen(SelectiveProjectModule.worldSettings, const <String>[
      "WorldSettings",
      "LocationStateChanges",
    ]);
    addWhen(SelectiveProjectModule.characters, const <String>[
      "Characters",
      "CharacterStates",
      "CharacterStateBaselines",
      "CharacterStateChanges",
    ]);
    addWhen(SelectiveProjectModule.items, const <String>[
      "ItemClasses",
      "ItemInstances",
      "ItemRelations",
      "ItemClassStateChanges",
      "ItemInstanceStateChanges",
    ]);
    addWhen(SelectiveProjectModule.phrases, const <String>["Phrases"]);
    return SelectiveProjectImportManifest._(
      Set<String>.unmodifiable(names),
      Set<SelectiveProjectModule>.unmodifiable(declared),
      Set<SelectiveProjectModule>.unmodifiable(modules),
    );
  }

  bool containsType(String name) => typeNames.contains(name);
}

class SelectiveProjectImportWarning {
  final String code;
  final String message;

  const SelectiveProjectImportWarning({
    required this.code,
    required this.message,
  });
}

class SelectiveProjectImportResult {
  final ProjectData data;
  final List<SelectiveProjectImportWarning> warnings;

  const SelectiveProjectImportResult({
    required this.data,
    required this.warnings,
  });
}

class SelectiveProjectImporter {
  const SelectiveProjectImporter();

  SelectiveProjectImportResult apply({
    required ProjectData current,
    required ProjectData source,
    required SelectiveProjectImportManifest manifest,
    required Set<SelectiveProjectModule> selectedModules,
  }) {
    if (selectedModules.isEmpty) {
      throw const FormatException("至少選擇一個匯入模組。");
    }
    final unavailable = selectedModules.difference(manifest.availableModules);
    if (unavailable.isNotEmpty) {
      throw FormatException(
        "來源檔不包含：${unavailable.map((item) => item.label).join('、')}。",
      );
    }
    bool selected(SelectiveProjectModule module) =>
        selectedModules.contains(module);
    bool use(String type, SelectiveProjectModule module) =>
        selected(module) &&
        (manifest.declaredModules.contains(module) ||
            manifest.containsType(type));

    final result = ProjectData(
      projectUUID: current.projectUUID,
      baseInfoData: use("BaseInfo", SelectiveProjectModule.baseInfo)
          ? source.baseInfoData
          : current.baseInfoData,
      segmentsData: use("ChapterSelection", SelectiveProjectModule.chapters)
          ? List.unmodifiable(source.segmentsData)
          : List.unmodifiable(current.segmentsData),
      outlineData: use("Outline", SelectiveProjectModule.outline)
          ? List.unmodifiable(source.outlineData)
          : List.unmodifiable(current.outlineData),
      foreshadowData: use("PlanSettings", SelectiveProjectModule.plans)
          ? List.unmodifiable(source.foreshadowData)
          : List.unmodifiable(current.foreshadowData),
      updatePlanData: use("PlanSettings", SelectiveProjectModule.plans)
          ? List.unmodifiable(source.updatePlanData)
          : List.unmodifiable(current.updatePlanData),
      worldSettingsData:
          use("WorldSettings", SelectiveProjectModule.worldSettings)
          ? List.unmodifiable(source.worldSettingsData)
          : List.unmodifiable(current.worldSettingsData),
      itemClasses: use("ItemClasses", SelectiveProjectModule.items)
          ? Map.unmodifiable(source.itemClasses)
          : Map.unmodifiable(current.itemClasses),
      itemInstances: use("ItemInstances", SelectiveProjectModule.items)
          ? Map.unmodifiable(source.itemInstances)
          : Map.unmodifiable(current.itemInstances),
      itemRelations: use("ItemRelations", SelectiveProjectModule.items)
          ? List.unmodifiable(source.itemRelations)
          : List.unmodifiable(current.itemRelations),
      itemClassStateChanges:
          use("ItemClassStateChanges", SelectiveProjectModule.items)
          ? List.unmodifiable(source.itemClassStateChanges)
          : List.unmodifiable(current.itemClassStateChanges),
      itemInstanceStateChanges:
          use("ItemInstanceStateChanges", SelectiveProjectModule.items)
          ? List.unmodifiable(source.itemInstanceStateChanges)
          : List.unmodifiable(current.itemInstanceStateChanges),
      locationStateChanges:
          use("LocationStateChanges", SelectiveProjectModule.worldSettings)
          ? List.unmodifiable(source.locationStateChanges)
          : List.unmodifiable(current.locationStateChanges),
      characterData: use("Characters", SelectiveProjectModule.characters)
          ? Map.unmodifiable(source.characterData)
          : Map.unmodifiable(current.characterData),
      characterStates: use("CharacterStates", SelectiveProjectModule.characters)
          ? List.unmodifiable(source.characterStates)
          : List.unmodifiable(current.characterStates),
      characterStateBaselines:
          use("CharacterStateBaselines", SelectiveProjectModule.characters)
          ? Map.unmodifiable(source.characterStateBaselines)
          : Map.unmodifiable(current.characterStateBaselines),
      characterStateChanges:
          use("CharacterStateChanges", SelectiveProjectModule.characters)
          ? List.unmodifiable(source.characterStateChanges)
          : List.unmodifiable(current.characterStateChanges),
      timelineDocument: use("Timeline", SelectiveProjectModule.outline)
          ? source.timelineDocument
          : current.timelineDocument,
      outlineChapterLinks: use("Timeline", SelectiveProjectModule.outline)
          ? List.unmodifiable(source.outlineChapterLinks)
          : List.unmodifiable(current.outlineChapterLinks),
      totalWords: use("BaseInfo", SelectiveProjectModule.baseInfo)
          ? source.totalWords
          : current.totalWords,
      contentText: use("BaseInfo", SelectiveProjectModule.baseInfo)
          ? source.contentText
          : current.contentText,
      isDirty: true,
      revisionTrackingJson: current.revisionTrackingJson,
      phrases: use("Phrases", SelectiveProjectModule.phrases)
          ? List.unmodifiable([
              for (final phrase in source.phrases)
                source.projectUUID == current.projectUUID ||
                        !const PhraseBodyValidator()
                            .validate(phrase.body)
                            .annotations
                            .any((annotation) => annotation.targetId != null)
                    ? phrase
                    : PhraseEntry.fromJson({
                        ...phrase.toJson(),
                        "requiresRelink": true,
                      }),
            ])
          : List.unmodifiable(current.phrases),
      phrasesRecoveryPayload: use("Phrases", SelectiveProjectModule.phrases)
          ? source.phrasesRecoveryPayload
          : current.phrasesRecoveryPayload,
    );
    return SelectiveProjectImportResult(
      data: result,
      warnings: List.unmodifiable(_referenceWarnings(result)),
    );
  }
}

Iterable<SelectiveProjectImportWarning> _referenceWarnings(
  ProjectData project,
) sync* {
  const phraseValidator = PhraseBodyValidator();
  const resolver = InlineAnnotationTargetResolver();
  for (final phrase in project.phrases) {
    if (phrase.requiresRelink) {
      yield SelectiveProjectImportWarning(
        code: "phrase-relink:${phrase.id}",
        message: "短語 ${phrase.name} 來自其他專案，Mention 插入前需確認目標。",
      );
    }
    for (final annotation in phraseValidator.validate(phrase.body).annotations) {
      if (annotation.targetId == null) continue;
      if (resolver.resolve(
            annotation: annotation,
            characters: project.characterData,
            locations: project.worldSettingsData,
            outline: project.outlineData,
            foreshadows: project.foreshadowData,
            plans: project.updatePlanData,
            itemClasses: project.itemClasses,
          ) == null) {
        yield SelectiveProjectImportWarning(
          code: "missing-phrase-target:${phrase.id}:${annotation.sourceRange.start}",
          message: "短語 ${phrase.name} 的 Mention 找不到目標，插入前需重新連結。",
        );
      }
    }
  }
  final characterIds = project.characterData.values
      .map((item) => item.characterId)
      .toSet();
  final locationIds = <String>{};
  void addLocations(Iterable<LocationData> nodes) {
    for (final node in nodes) {
      locationIds.add(node.id);
      addLocations(node.child);
    }
  }

  addLocations(project.worldSettingsData);
  final eventIds = <String>{};
  final sceneIds = <String>{};
  for (final storyline in project.outlineData) {
    for (final event in storyline.scenes) {
      eventIds.add(event.storyEventUUID);
      sceneIds.addAll(event.scenes.map((scene) => scene.sceneUUID));
    }
  }
  final itemIds = <String>{
    ...project.itemClasses.keys,
    ...project.itemInstances.keys,
  };
  for (final relation in project.itemRelations) {
    if (!itemIds.contains(relation.itemId)) {
      yield SelectiveProjectImportWarning(
        code: "missing-item:${relation.relationId}",
        message: "物品關聯 ${relation.relationId} 找不到物品 ${relation.itemId}。",
      );
    }
    final targets = switch (relation.targetKind) {
      ItemRelationTargetKind.character => characterIds,
      ItemRelationTargetKind.location => locationIds,
      ItemRelationTargetKind.event => eventIds,
      ItemRelationTargetKind.scene => sceneIds,
    };
    if (!targets.contains(relation.targetId)) {
      yield SelectiveProjectImportWarning(
        code: "missing-target:${relation.relationId}",
        message:
            "物品關聯 ${relation.relationId} 找不到目標 ${relation.targetId}，已保留 ID 供稍後修復。",
      );
    }
  }
  for (final instance in project.itemInstances.values) {
    if (!project.itemClasses.containsKey(instance.classId)) {
      yield SelectiveProjectImportWarning(
        code: "missing-class:${instance.instanceId}",
        message:
            "物品 ${instance.instanceId} 找不到 Class ${instance.classId}，已保留原始 ID。",
      );
    }
  }
  for (final change in project.itemClassStateChanges) {
    if (!project.itemClasses.containsKey(change.classId)) {
      yield SelectiveProjectImportWarning(
        code: "missing-class-change:${change.stateChangeId}",
        message: "Class 快照 ${change.stateChangeId} 找不到 ${change.classId}。",
      );
    }
  }
  for (final change in project.itemInstanceStateChanges) {
    if (!project.itemInstances.containsKey(change.instanceId)) {
      yield SelectiveProjectImportWarning(
        code: "missing-instance-change:${change.stateChangeId}",
        message: "物品快照 ${change.stateChangeId} 找不到 ${change.instanceId}。",
      );
    }
  }
}
