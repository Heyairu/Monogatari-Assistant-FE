import "package:flutter_quill/flutter_quill.dart" show Document;
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/editor/plain_text_quill_adapter.dart";

void main() {
  group("PlainTextQuillAdapter", () {
    test("adds and removes exactly one Quill sentinel newline", () {
      final empty = PlainTextQuillAdapter.fromPlainText("");
      final singleLine = PlainTextQuillAdapter.fromPlainText("第一行");
      final trailingNewline = PlainTextQuillAdapter.fromPlainText("第一行\n");
      final trailingBlankLine = PlainTextQuillAdapter.fromPlainText("第一行\n\n");

      expect(empty.editorText, "\n");
      expect(singleLine.editorText, "第一行\n");
      expect(trailingNewline.editorText, "第一行\n\n");
      expect(trailingBlankLine.editorText, "第一行\n\n\n");

      expect(PlainTextQuillAdapter.toPlainText(empty.document), "");
      expect(PlainTextQuillAdapter.toPlainText(singleLine.document), "第一行");
      expect(
        PlainTextQuillAdapter.toPlainText(trailingNewline.document),
        "第一行\n",
      );
      expect(
        PlainTextQuillAdapter.toPlainText(trailingBlankLine.document),
        "第一行\n\n",
      );
    });

    test("normalizes legacy line endings only inside the Quill document", () {
      final value = PlainTextQuillAdapter.fromPlainText("甲\r\n乙\r丙\n丁");

      expect(value.rawText, "甲\r\n乙\r丙\n丁");
      expect(value.editorText, "甲\n乙\n丙\n丁\n");
      expect(PlainTextQuillAdapter.toPlainText(value.document), "甲\n乙\n丙\n丁");
    });

    test("round-trips multilingual text and Mosaic syntax", () {
      const raw = "繁中、かな、한국어、emoji 👩🏽‍💻\n//^<重點>//\nمرحبا";
      final value = PlainTextQuillAdapter.fromPlainText(raw);

      expect(PlainTextQuillAdapter.toPlainText(value.document), raw);
    });

    test("uses Quill's Unicode-aware whole-word CJK search", () {
      final document = PlainTextQuillAdapter.fromPlainText("甲乙 乙 乙丙").document;

      expect(document.search("乙", wholeWord: true), <int>[3]);
    });

    test("maps CRLF raw offsets without exposing the sentinel", () {
      final value = PlainTextQuillAdapter.fromPlainText("甲\r\n乙");

      expect(
        List<int>.generate(
          value.rawText.length + 1,
          value.rawOffsetToDocumentOffset,
        ),
        <int>[0, 1, 1, 2, 3],
      );
      expect(
        List<int>.generate(
          value.editorText.length + 1,
          value.documentOffsetToRawOffset,
        ),
        <int>[0, 1, 3, 4, 4],
      );
      expect(value.rawOffsetToDocumentOffset(-1), 0);
      expect(value.rawOffsetToDocumentOffset(100), 3);
      expect(value.documentOffsetToRawOffset(100), 4);
    });

    test("rejects formatting attributes", () {
      final document = Document.fromJson(<Map<String, dynamic>>[
        <String, dynamic>{
          "insert": "粗體",
          "attributes": <String, dynamic>{"bold": true},
        },
        <String, dynamic>{"insert": "\n"},
      ]);

      expect(
        () => PlainTextQuillAdapter.toPlainText(document),
        throwsA(isA<PlainTextQuillAdapterException>()),
      );
    });

    test("rejects embeds", () {
      final document = Document.fromJson(<Map<String, dynamic>>[
        <String, dynamic>{
          "insert": <String, dynamic>{"image": "file:///cover.png"},
        },
        <String, dynamic>{"insert": "\n"},
      ]);

      expect(
        () => PlainTextQuillAdapter.toPlainText(document),
        throwsA(isA<PlainTextQuillAdapterException>()),
      );
    });
  });
}
