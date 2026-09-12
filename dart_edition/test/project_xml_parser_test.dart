import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/file.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("parseProjectXMLWithMetadata loads version and chapter data once", () {
    const xmlContent = """
<?xml version="1.0" encoding="UTF-8"?>
<Project UUID="123e4567-e89b-42d3-a456-426614174000">
  <ver>9.99</ver>
  <Type>
    <Name>ChapterSelection</Name>
    <Segment Name="Part 1" UUID="segment-1">
      <Chapter Name="Chapter 1" UUID="chapter-1">
        <Content>Hello&#10;World</Content>
      </Chapter>
    </Segment>
  </Type>
</Project>
""";

    final result = FileService.parseProjectXMLWithMetadata(xmlContent);

    expect(result.projectVersion, "9.99");
    expect(result.sourceProjectUuid, "123e4567-e89b-42d3-a456-426614174000");
    expect(result.data.projectUUID, "123e4567-e89b-42d3-a456-426614174000");
    expect(result.data.segmentsData, hasLength(1));
    expect(result.data.segmentsData.first.segmentName, "Part 1");
    expect(result.data.segmentsData.first.chapters, hasLength(1));
    expect(
      result.data.segmentsData.first.chapters.first.chapterContent,
      "Hello\nWorld",
    );
  });

  test(
    "load clears the transient raw XML after handing it to the parser",
    () async {
      const xmlContent = "<Project><ver>1.0</ver></Project>";
      final projectFile = ProjectFile(
        fileName: "test.mnproj",
        filePath: "test.mnproj",
        content: xmlContent,
      );

      await ProjectManager.loadProjectParseResultFromXML(projectFile);

      expect(projectFile.content, isEmpty);
    },
  );

  test("project UUID round-trips and regular saves keep it unchanged", () {
    const projectUuid = "123e4567-e89b-42d3-a456-426614174001";
    final data = ProjectData.empty(projectUUID: projectUuid);

    final firstSave = FileService.generateProjectXML(data);
    final loaded = FileService.parseProjectXMLWithMetadata(firstSave);
    final secondSave = FileService.generateProjectXML(loaded.data);

    expect(firstSave, contains('<Project UUID="$projectUuid">'));
    expect(firstSave, contains("<ver>1.16</ver>"));
    expect(loaded.data.projectUUID, projectUuid);
    expect(secondSave, contains('<Project UUID="$projectUuid">'));
  });

  test("1.16 is supported while later project formats are rejected", () {
    expect(FileService.projectVersion, "1.16");
    expect(FileService.isProjectVersionNewerThanSupported("1.16"), isFalse);
    expect(FileService.isProjectVersionNewerThanSupported("1.16.0"), isFalse);
    expect(FileService.isProjectVersionNewerThanSupported("1.17"), isTrue);
    expect(FileService.isProjectVersionNewerThanSupported("2.0"), isTrue);
  });

  test("legacy project without UUID receives one while loading", () {
    final result = FileService.parseProjectXMLWithMetadata(
      "<Project><ver>1.12</ver></Project>",
    );

    expect(result.data.projectUUID, isNotEmpty);
    expect(result.sourceProjectUuid, isNull);
    expect(result.wasMigrated, true);
  });
}
