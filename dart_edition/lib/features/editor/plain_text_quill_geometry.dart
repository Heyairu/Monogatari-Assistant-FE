import "package:flutter/rendering.dart";
import "package:flutter_quill/flutter_quill.dart";

/// Uses the laid-out paragraph boxes, including padding, wrapping and bidi.
/// RenderEditor.getLocalRectForCaret in Quill 11.6 omits the child's x offset.
List<Rect> quillSelectionGlobalRects(RenderEditor editor, TextRange range) {
  final result = <Rect>[];
  var offset = range.start;
  while (offset < range.end) {
    final child = editor.childAtPosition(TextPosition(offset: offset));
    final start = child.container.documentOffset;
    final end = start + child.container.length;
    RenderParagraph? paragraph;
    void visit(RenderObject node) {
      if (node is RenderParagraph) {
        paragraph ??= node;
      } else {
        node.visitChildren(visit);
      }
    }

    visit(child);
    final body = paragraph;
    if (body != null) {
      final length = body.text.toPlainText().length;
      final selection = TextSelection(
        baseOffset: (offset - start).clamp(0, length),
        extentOffset: (range.end.clamp(offset, end) - start).clamp(0, length),
      );
      for (final box in body.getBoxesForSelection(selection)) {
        result.add(
          Rect.fromPoints(
            body.localToGlobal(box.toRect().topLeft),
            body.localToGlobal(box.toRect().bottomRight),
          ),
        );
      }
    }
    if (end <= offset) break;
    offset = end;
  }
  return result;
}

Rect quillCaretGlobalRect(RenderEditor editor, TextPosition position) {
  final child = editor.childAtPosition(position);
  final rect = child.getLocalRectForCaret(
    child.globalToLocalPosition(position),
  );
  return Rect.fromPoints(
    child.localToGlobal(rect.topLeft),
    child.localToGlobal(rect.bottomRight),
  );
}
