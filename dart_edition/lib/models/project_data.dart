import "package:uuid/uuid.dart";

import "base_info_data.dart";
import "chapter_selection_data.dart";
import "character_data.dart";
import "character_snapshot_data.dart";
import "outline_data.dart";
import "plan_data.dart";
import "timeline_data.dart";
import "world_settings_data.dart";

class ProjectData {
  static const Uuid _uuid = Uuid();
  static final RegExp _uuidPattern = RegExp(
    r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
  );

  String projectUUID;
  BaseInfoData baseInfoData;
  List<SegmentData> segmentsData;
  List<StorylineData> outlineData;
  List<ForeshadowItem> foreshadowData;
  List<UpdatePlanItem> updatePlanData;
  List<LocationData> worldSettingsData;
  Map<String, CharacterEntryData> characterData;
  List<CharacterState> characterStates;
  Map<String, CharacterStateBaseline> characterStateBaselines;
  List<CharacterStateChange> characterStateChanges;
  TimelineDocumentData timelineDocument;
  List<OutlineChapterLinkData> outlineChapterLinks;
  int totalWords;
  String contentText;
  bool isDirty;

  ProjectData({
    String? projectUUID,
    required this.baseInfoData,
    required this.segmentsData,
    required this.outlineData,
    required this.foreshadowData,
    required this.updatePlanData,
    required this.worldSettingsData,
    required this.characterData,
    this.characterStates = const <CharacterState>[],
    this.characterStateBaselines = const <String, CharacterStateBaseline>{},
    this.characterStateChanges = const <CharacterStateChange>[],
    TimelineDocumentData? timelineDocument,
    List<OutlineChapterLinkData>? outlineChapterLinks,
    this.totalWords = 0,
    this.contentText = "",
    this.isDirty = false,
  }) : projectUUID = isValidProjectUUID(projectUUID)
           ? projectUUID!.trim()
           : createProjectUUID(),
       timelineDocument = timelineDocument ?? TimelineDocumentData.initial(),
       outlineChapterLinks =
           outlineChapterLinks ?? const <OutlineChapterLinkData>[];

  static String createProjectUUID() => _uuid.v4();

  static bool isValidProjectUUID(String? value) {
    if (value == null) return false;
    return _uuidPattern.hasMatch(value.trim());
  }

  factory ProjectData.empty({String? projectUUID}) {
    return ProjectData(
      projectUUID: projectUUID,
      baseInfoData: BaseInfoData(),
      segmentsData: [
        SegmentData(
          segmentName: "Folder 1",
          chapters: [ChapterData(chapterName: "Chapter 1", chapterContent: "")],
        ),
      ],
      outlineData: [
        StorylineData(
          storylineName: "序章",
          storylineType: "開場",
          scenes: [],
          memo: "",
        ),
      ],
      foreshadowData: [],
      updatePlanData: [],
      worldSettingsData: [LocationData(localName: "主要場景")],
      characterData: {},
      characterStates: const <CharacterState>[],
      characterStateBaselines: const <String, CharacterStateBaseline>{},
      characterStateChanges: const <CharacterStateChange>[],
      timelineDocument: TimelineDocumentData.initial(),
      outlineChapterLinks: const <OutlineChapterLinkData>[],
    );
  }
}

class ProjectParseResult {
  final String? projectVersion;
  final String? sourceProjectUuid;
  final ProjectData data;
  final List<ProjectMigrationWarning> migrationWarnings;
  final bool wasMigrated;

  const ProjectParseResult({
    required this.projectVersion,
    this.sourceProjectUuid,
    required this.data,
    this.migrationWarnings = const <ProjectMigrationWarning>[],
    this.wasMigrated = false,
  });
}

class ProjectMigrationWarning {
  final String code;
  final String message;
  final String? originalText;

  const ProjectMigrationWarning({
    required this.code,
    required this.message,
    this.originalText,
  });
}
