import "package:flutter/material.dart";
import "package:flutter_quill/flutter_quill.dart";

import "../../infrastructure/rhodanthe/rhodanthe_theme.dart";
import "plain_text_quill_render_range.dart";
import "plain_text_quill_geometry.dart";

/// Render-only highlights for host-owned search and proofreading ranges.
///
/// The ranges are measured against Quill's plain-text document but never
/// written into its Delta, so formatting cannot leak into persistence, undo,
/// clipboard data, or collaboration messages.
class PlainTextQuillRangeOverlay extends StatefulWidget {
  const PlainTextQuillRangeOverlay({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.matches,
    required this.currentMatchIndex,
    required this.proofreadingRanges,
    required this.renderRanges,
    this.revisionMarkers = const [],
  });

  final QuillController controller;
  final ScrollController scrollController;
  final List<TextRange> matches;
  final int currentMatchIndex;
  final List<TextRange> proofreadingRanges;
  final List<PlainTextQuillRenderRange> renderRanges;
  final List<PlainTextQuillRevisionMarker> revisionMarkers;

  @override
  State<PlainTextQuillRangeOverlay> createState() =>
      _PlainTextQuillRangeOverlayState();
}

class _PlainTextQuillRangeOverlayState
    extends State<PlainTextQuillRangeOverlay> {
  List<_MeasuredRange> _ranges = const <_MeasuredRange>[];
  List<({String label, double top})> _markers = const [];
  bool _measurementScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(refresh);
    widget.scrollController.addListener(refresh);
  }

  @override
  void didUpdateWidget(covariant PlainTextQuillRangeOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(refresh);
      widget.controller.addListener(refresh);
    }
    if (!identical(oldWidget.scrollController, widget.scrollController)) {
      oldWidget.scrollController.removeListener(refresh);
      widget.scrollController.addListener(refresh);
    }
    refresh();
  }

  @override
  void dispose() {
    widget.controller.removeListener(refresh);
    widget.scrollController.removeListener(refresh);
    super.dispose();
  }

  void refresh() {
    if (!mounted || _measurementScheduled) return;
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (mounted) _measure();
    });
  }

  void _measure() {
    final layerBox = context.findRenderObject();
    if (layerBox is! RenderBox || !layerBox.hasSize) return;
    final editor = _findRenderEditor(layerBox.parent);
    if (editor == null || !editor.hasSize) return;

    final documentLength = (widget.controller.document.length - 1)
        .clamp(0, widget.controller.document.length)
        .toInt();
    final measured = <_MeasuredRange>[];
    final markers = <({String label, double top})>[];
    for (final marker in widget.revisionMarkers) {
      final offset = marker.offset.clamp(0, documentLength).toInt();
      final caret = quillCaretGlobalRect(editor, TextPosition(offset: offset));
      markers.add((
        label: marker.label,
        top: layerBox.globalToLocal(caret.topLeft).dy,
      ));
    }
    for (var index = 0; index < widget.matches.length; index += 1) {
      _appendMeasuredRange(
        measured,
        layerBox: layerBox,
        editor: editor,
        range: widget.matches[index],
        documentLength: documentLength,
        kind: index == widget.currentMatchIndex
            ? _RangeKind.currentMatch
            : _RangeKind.match,
        identity: "search-$index",
      );
    }
    for (var index = 0; index < widget.proofreadingRanges.length; index += 1) {
      _appendMeasuredRange(
        measured,
        layerBox: layerBox,
        editor: editor,
        range: widget.proofreadingRanges[index],
        documentLength: documentLength,
        kind: _RangeKind.proofreading,
        identity: "proofreading-$index",
      );
    }
    for (var index = 0; index < widget.renderRanges.length; index += 1) {
      final renderRange = widget.renderRanges[index];
      _appendMeasuredRange(
        measured,
        layerBox: layerBox,
        editor: editor,
        range: renderRange.range,
        documentLength: documentLength,
        kind: _RangeKind.render,
        identity: "rhodanthe-$index",
        backgroundColor: renderRange.backgroundColor,
        decorationColor: renderRange.decorationColor,
        decorationThickness: renderRange.decorationThickness,
        doubleUnderline: renderRange.doubleUnderline,
      );
    }
    if (_sameRanges(_ranges, measured) &&
        _markers.length == markers.length &&
        List.generate(
          markers.length,
          (index) => index,
        ).every((index) => _markers[index] == markers[index])) {
      return;
    }
    setState(() {
      _ranges = measured;
      _markers = markers;
    });
  }

  void _appendMeasuredRange(
    List<_MeasuredRange> output, {
    required RenderBox layerBox,
    required RenderEditor editor,
    required TextRange range,
    required int documentLength,
    required _RangeKind kind,
    required String identity,
    Color? backgroundColor,
    Color? decorationColor,
    double decorationThickness = 1,
    bool doubleUnderline = false,
  }) {
    final start = range.start.clamp(0, documentLength).toInt();
    final end = range.end.clamp(start, documentLength).toInt();
    if (start == end) return;

    final boxes = quillSelectionGlobalRects(
      editor,
      TextRange(start: start, end: end),
    );
    for (var index = 0; index < boxes.length; index++) {
      final box = boxes[index];
      output.add(
        _MeasuredRange(
          identity: index == 0 ? identity : "$identity-$index",
          kind: kind,
          rect: Rect.fromPoints(
            layerBox.globalToLocal(box.topLeft),
            layerBox.globalToLocal(box.bottomRight),
          ),
          backgroundColor: backgroundColor,
          decorationColor: decorationColor,
          decorationThickness: decorationThickness,
          doubleUnderline: doubleUnderline,
        ),
      );
    }
  }

  RenderEditor? _findRenderEditor(RenderObject? root) {
    if (root == null) return null;
    if (root is RenderEditor) return root;
    RenderEditor? result;
    root.visitChildren((child) => result ??= _findRenderEditor(child));
    return result;
  }

  bool _sameRanges(List<_MeasuredRange> left, List<_MeasuredRange> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    refresh();
    final colors = Theme.of(context).colorScheme;
    final rhodanthe = RhodantheTheme.resolve(context);
    return IgnorePointer(
      child: Stack(
        children: <Widget>[
          for (final range in _ranges)
            Positioned.fromRect(
              rect: range.rect,
              child: CustomPaint(
                key: ValueKey<String>("plain-text-quill-${range.identity}"),
                painter: _RangePainter(
                  backgroundColor: range.kind == _RangeKind.render
                      ? range.backgroundColor?.withValues(alpha: 0.42)
                      : range.kind == _RangeKind.currentMatch
                      ? rhodanthe
                            .resolveColor("search.current.highlight")
                            ?.withValues(alpha: 0.34)
                      : range.kind == _RangeKind.match
                      ? rhodanthe
                            .resolveColor("search.match.highlight")
                            ?.withValues(alpha: 0.30)
                      : null,
                  outlineColor: range.kind == _RangeKind.currentMatch
                      ? rhodanthe
                            .resolveColor("search.current.outline")
                            ?.withValues(alpha: 0.95)
                      : range.kind == _RangeKind.match
                      ? rhodanthe
                            .resolveColor("search.match.outline")
                            ?.withValues(alpha: 0.95)
                      : null,
                  decorationColor: range.kind == _RangeKind.render
                      ? range.decorationColor
                      : range.kind == _RangeKind.proofreading
                      ? colors.error
                      : null,
                  decorationThickness: range.kind == _RangeKind.proofreading
                      ? 2
                      : range.decorationThickness,
                  doubleUnderline: range.doubleUnderline,
                ),
              ),
            ),
          for (final marker in _markers)
            Positioned(
              left: 1,
              top: marker.top,
              child: Text(
                marker.label,
                style: TextStyle(
                  color: marker.label.contains('+')
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _RangeKind { match, currentMatch, proofreading, render }

@immutable
class _MeasuredRange {
  const _MeasuredRange({
    required this.identity,
    required this.kind,
    required this.rect,
    this.backgroundColor,
    this.decorationColor,
    this.decorationThickness = 1,
    this.doubleUnderline = false,
  });

  final String identity;
  final _RangeKind kind;
  final Rect rect;
  final Color? backgroundColor;
  final Color? decorationColor;
  final double decorationThickness;
  final bool doubleUnderline;

  @override
  bool operator ==(Object other) =>
      other is _MeasuredRange &&
      other.identity == identity &&
      other.kind == kind &&
      other.rect == rect &&
      other.backgroundColor == backgroundColor &&
      other.decorationColor == decorationColor &&
      other.decorationThickness == decorationThickness &&
      other.doubleUnderline == doubleUnderline;

  @override
  int get hashCode => Object.hash(
    identity,
    kind,
    rect,
    backgroundColor,
    decorationColor,
    decorationThickness,
    doubleUnderline,
  );
}

final class _RangePainter extends CustomPainter {
  const _RangePainter({
    this.backgroundColor,
    this.outlineColor,
    this.decorationColor,
    this.decorationThickness = 1,
    this.doubleUnderline = false,
  });

  final Color? backgroundColor;
  final Color? outlineColor;
  final Color? decorationColor;
  final double decorationThickness;
  final bool doubleUnderline;

  @override
  void paint(Canvas canvas, Size size) {
    if (backgroundColor case final color?) {
      canvas.drawRect(Offset.zero & size, Paint()..color = color);
    }
    if (outlineColor case final color?) {
      final outline = Paint()
        ..color = color
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      final bottom = size.height - 0.5;
      canvas.drawLine(Offset(0, bottom), Offset(size.width, bottom), outline);
    }
    if (decorationColor case final color?) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = decorationThickness
        ..style = PaintingStyle.stroke;
      final bottom = size.height - decorationThickness / 2;
      canvas.drawLine(Offset(0, bottom), Offset(size.width, bottom), paint);
      if (doubleUnderline) {
        final upper = bottom - decorationThickness - 2;
        canvas.drawLine(Offset(0, upper), Offset(size.width, upper), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RangePainter oldDelegate) =>
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.outlineColor != outlineColor ||
      oldDelegate.decorationColor != decorationColor ||
      oldDelegate.decorationThickness != decorationThickness ||
      oldDelegate.doubleUnderline != doubleUnderline;
}
