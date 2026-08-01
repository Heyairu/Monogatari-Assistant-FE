import "package:xml/xml.dart" as xml;

/// Shared text encoding used by all project XML codecs.
abstract final class XmlTextCodec {
  static void writeTextElement(
    xml.XmlBuilder builder,
    String name,
    String value,
  ) {
    builder.element(name, nest: () => builder.text(encodeNewlines(value)));
  }

  static String readElementText(xml.XmlElement? element) {
    if (element == null) return "";
    if (element.children.isEmpty) {
      return decodeNewlines(element.innerText);
    }

    final cdataBuffer = StringBuffer();
    for (final node in element.children) {
      if (node is xml.XmlCDATA) cdataBuffer.write(node.value);
    }
    final cdataText = cdataBuffer.toString();
    if (cdataText.isNotEmpty) return decodeNewlines(cdataText);

    final textBuffer = StringBuffer();
    for (final node in element.children) {
      if (node is xml.XmlText || node is xml.XmlCDATA) {
        textBuffer.write(node.value);
      }
    }
    final text = textBuffer.toString();
    return decodeNewlines(text.isNotEmpty ? text : element.innerText);
  }

  static String encodeNewlines(String value) {
    if (value.isEmpty) return value;
    final normalized = value.replaceAll("\r\n", "\n").replaceAll("\r", "\n");
    final buffer = StringBuffer();
    for (final codeUnit in normalized.codeUnits) {
      switch (codeUnit) {
        case 10:
          buffer.write("&#10;");
          break;
        case 35:
          buffer.write("&#35;");
          break;
        case 59:
          buffer.write("&#59;");
          break;
        default:
          buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  static String decodeNewlines(String value) {
    return value
        .replaceAll("&#13;", "")
        .replaceAll("&#10;", "\n")
        .replaceAll("&#35;", "#")
        .replaceAll("&#59;", ";");
  }
}
