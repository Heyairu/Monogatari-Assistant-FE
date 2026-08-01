import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/file.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("parseProjectXMLWithMetadata loads version and chapter data once", () {
    const xmlContent = """
<?xml version="1.0" encoding="UTF-8"?>
<Project>
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
}
