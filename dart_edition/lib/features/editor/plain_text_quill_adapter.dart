import "package:flutter_quill/flutter_quill.dart";

/// Converts the persisted plain-text chapter format to a Quill document.
///
/// The Quill document always contains one final newline that exists solely to
/// terminate the document. [toPlainText] removes exactly that one newline.
/// Formatting and embeds are deliberately rejected: this migration stage
/// treats Quill as an input surface, not as a rich-text persistence format.
/// Mosaic annotations are likewise ordinary source text at this boundary.
/// Their `//…//` syntax is never converted into a Quill attribute, embed, or
/// placeholder, so it survives editing, storage, export, and collaboration.
final class PlainTextQuillAdapter {
  const PlainTextQuillAdapter._();

  static const _loaderMarkerAttribute = "plain-text-loader-marker";
  static const _loaderMarkerValues = <String>{"even", "odd"};

  /// Builds a plain-text Quill document and its raw/document offset mapping.
  static PlainTextQuillDocument fromPlainText(String rawText) {
    return PlainTextQuillDocument._(rawText);
  }

  /// Extracts canonical LF plain text from a Quill document.
  ///
  /// A document must consist solely of unformatted string insertions and end
  /// with a newline. The final newline is the Quill document sentinel; any
  /// preceding newlines are user content and are preserved.
  static String toPlainText(Document document) {
    final buffer = StringBuffer();
    final operations = document.toDelta().toJson();

    for (final operation in operations) {
      if (!operation.containsKey("insert")) {
        throw const PlainTextQuillAdapterException(
          "Plain-text Quill documents may only contain insert operations.",
        );
      }

      final attributes = operation["attributes"];
      if (attributes != null &&
          (attributes is! Map || !_containsOnlyLoaderMarker(attributes))) {
        throw const PlainTextQuillAdapterException(
          "Plain-text Quill documents cannot contain formatting attributes.",
        );
      }

      final inserted = operation["insert"];
      if (inserted is! String) {
        throw const PlainTextQuillAdapterException(
          "Plain-text Quill documents cannot contain embeds.",
        );
      }
      buffer.write(inserted);
    }

    final editorText = buffer.toString();
    if (!editorText.endsWith("\n")) {
      throw const PlainTextQuillAdapterException(
        "Quill document must end with its sentinel newline.",
      );
    }
    return editorText.substring(0, editorText.length - 1);
  }

  static bool _containsOnlyLoaderMarker(Map attributes) {
    return attributes.length == 1 &&
        attributes[_loaderMarkerAttribute] is String &&
        _loaderMarkerValues.contains(attributes[_loaderMarkerAttribute]);
  }

  static String _normalizeLineEndings(String value) {
    return value.replaceAll("\r\n", "\n").replaceAll("\r", "\n");
  }
}

/// A Quill document paired with the original persisted text and offset maps.
///
/// [rawText] is never mutated. [editorText] uses canonical LF line endings
/// and includes the mandatory final Quill sentinel newline.
final class PlainTextQuillDocument {
  PlainTextQuillDocument._(this.rawText)
    : editorText = "${PlainTextQuillAdapter._normalizeLineEndings(rawText)}\n",
      _rawToDocumentOffsets = _buildRawToDocumentOffsets(rawText) {
    document = _buildDocument(editorText);
    _documentToRawOffsets = _buildDocumentToRawOffsets(
      rawText: rawText,
      editorText: editorText,
    );
  }

  /// The persisted chapter content before the editor normalizes line endings.
  final String rawText;

  /// The unformatted Quill text, including its final sentinel newline.
  final String editorText;

  late final Document document;
  final List<int> _rawToDocumentOffsets;
  late final List<int> _documentToRawOffsets;

  /// Quill's Delta loader recursively splits a string for every newline it
  /// contains. A chapter-sized string with many paragraphs can therefore
  /// overflow that recursion. Keep every physical line in a separate Delta
  /// operation using a namespaced ignored marker. The marker is an in-memory
  /// loader detail only; [PlainTextQuillAdapter.toPlainText] never persists it.
  static Document _buildDocument(String editorText) {
    final operations = <Map<String, dynamic>>[];
    var lineStart = 0;
    var lineNumber = 0;

    for (var offset = 0; offset < editorText.length; offset += 1) {
      if (editorText.codeUnitAt(offset) != 0x0a) continue;
      operations.add(<String, dynamic>{
        "insert": editorText.substring(lineStart, offset + 1),
        // An unknown Quill attribute is ignored by rendering. Alternating its
        // value keeps adjacent line operations from compacting into one huge
        // string before the document tree is created.
        "attributes": <String, dynamic>{
          PlainTextQuillAdapter._loaderMarkerAttribute: lineNumber.isEven
              ? "even"
              : "odd",
        },
      });
      lineStart = offset + 1;
      lineNumber += 1;
    }

    final document = Document.fromJson(operations);
    document.history.clear();
    return document;
  }

  /// Converts a persisted raw-text UTF-16 offset to a Quill document offset.
  int rawOffsetToDocumentOffset(int rawOffset) {
    return _rawToDocumentOffsets[_clamp(rawOffset, rawText.length)];
  }

  /// Converts a Quill document UTF-16 offset to a persisted raw-text offset.
  ///
  /// The sentinel position clamps to the end of [rawText].
  int documentOffsetToRawOffset(int documentOffset) {
    return _documentToRawOffsets[_clamp(documentOffset, editorText.length)];
  }

  static List<int> _buildRawToDocumentOffsets(String rawText) {
    final result = List<int>.filled(rawText.length + 1, 0);
    var rawOffset = 0;
    var documentOffset = 0;
    result[0] = 0;

    while (rawOffset < rawText.length) {
      final unit = rawText.codeUnitAt(rawOffset);
      if (unit == 0x0d) {
        result[rawOffset] = documentOffset;
        rawOffset += 1;
        if (rawOffset < rawText.length &&
            rawText.codeUnitAt(rawOffset) == 0x0a) {
          result[rawOffset] = documentOffset;
          rawOffset += 1;
        }
        documentOffset += 1;
        result[rawOffset] = documentOffset;
        continue;
      }

      rawOffset += 1;
      documentOffset += 1;
      result[rawOffset] = documentOffset;
    }
    return result;
  }

  static List<int> _buildDocumentToRawOffsets({
    required String rawText,
    required String editorText,
  }) {
    final result = List<int>.filled(editorText.length + 1, rawText.length);
    var rawOffset = 0;
    var documentOffset = 0;
    result[0] = 0;

    while (rawOffset < rawText.length) {
      if (rawText.codeUnitAt(rawOffset) == 0x0d) {
        rawOffset += 1;
        if (rawOffset < rawText.length &&
            rawText.codeUnitAt(rawOffset) == 0x0a) {
          rawOffset += 1;
        }
      } else {
        rawOffset += 1;
      }
      documentOffset += 1;
      result[documentOffset] = rawOffset;
    }

    // The last editor position is after the Quill-only sentinel newline.
    result[editorText.length] = rawText.length;
    return result;
  }

  static int _clamp(int offset, int maximum) {
    return offset.clamp(0, maximum).toInt();
  }
}

final class PlainTextQuillAdapterException implements Exception {
  const PlainTextQuillAdapterException(this.message);

  final String message;

  @override
  String toString() => "PlainTextQuillAdapterException: $message";
}
