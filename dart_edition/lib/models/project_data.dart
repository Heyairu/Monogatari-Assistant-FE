import "base_info_data.dart";
import "chapter_selection_data.dart";
import "character_data.dart";
import "outline_data.dart";
import "plan_data.dart";
import "world_settings_data.dart";

class ProjectData {
  BaseInfoData baseInfoData;
  List<SegmentData> segmentsData;
  List<StorylineData> outlineData;
  List<ForeshadowItem> foreshadowData;
  List<UpdatePlanItem> updatePlanData;
  List<LocationData> worldSettingsData;
  Map<String, CharacterEntryData> characterData;
  List<CharacterState> characterStates;
  int totalWords;
  String contentText;
  bool isDirty;

  ProjectData({
    required this.baseInfoData,
    required this.segmentsData,
    required this.outlineData,
    required this.foreshadowData,
    required this.updatePlanData,
    required this.worldSettingsData,
    required this.characterData,
    this.characterStates = const <CharacterState>[],
    this.totalWords = 0,
    this.contentText = "",
    this.isDirty = false,
  });

  factory ProjectData.empty() {
    return ProjectData(
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
    );
  }
}

class ProjectParseResult {
  final String? projectVersion;
  final ProjectData data;
  final List<ProjectMigrationWarning> migrationWarnings;
  final bool wasMigrated;

  const ProjectParseResult({
    required this.projectVersion,
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
