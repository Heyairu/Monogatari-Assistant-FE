import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/models/codecs/xml_text_codec.dart";
import "package:xml/xml.dart" as xml;

void main() {
  test("shared XML text codec preserves escaped newlines and punctuation", () {
    const source = "第一行\n#標題;內容";
    final productionBuilder = xml.XmlBuilder();
    XmlTextCodec.writeTextElement(productionBuilder, "Memo", source);
    final element = xml.XmlDocument.parse(
      productionBuilder.buildDocument().toXmlString(),
    ).rootElement;

    expect(XmlTextCodec.readElementText(element), source);
    expect(element.name.local, "Memo");
  });

  test("shared XML text codec reads CDATA consistently", () {
    final element = xml.XmlDocument.parse(
      "<Memo><![CDATA[first&#10;second]]></Memo>",
    ).rootElement;
    expect(XmlTextCodec.readElementText(element), "first\nsecond");
  });
}
