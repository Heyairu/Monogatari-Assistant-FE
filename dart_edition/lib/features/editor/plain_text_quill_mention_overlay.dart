import "package:flutter/material.dart";
import "package:flutter_quill/flutter_quill.dart";

import "../inline_annotations/inline_annotation.dart";
import "../inline_annotations/inline_annotation_palette.dart";
import "plain_text_quill_geometry.dart";

@immutable
final class PlainTextQuillMentionMarker {
  const PlainTextQuillMentionMarker({
    required this.offset,
    required this.annotation,
  });

  final int offset;
  final InlineAnnotation annotation;
}

/// Paints Mosaic mention-kind symbols over their reserved Quill character.
/// The markers are presentation-only and never enter the Quill Delta.
class PlainTextQuillMentionOverlay extends StatefulWidget {
  const PlainTextQuillMentionOverlay({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.markers,
  });

  final QuillController controller;
  final ScrollController scrollController;
  final List<PlainTextQuillMentionMarker> markers;

  @override
  State<PlainTextQuillMentionOverlay> createState() =>
      _PlainTextQuillMentionOverlayState();
}

class _PlainTextQuillMentionOverlayState
    extends State<PlainTextQuillMentionOverlay> {
  List<_MeasuredMarker> _markers = const <_MeasuredMarker>[];
  bool _measurementScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    widget.scrollController.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant PlainTextQuillMentionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
    if (!identical(oldWidget.scrollController, widget.scrollController)) {
      oldWidget.scrollController.removeListener(_refresh);
      widget.scrollController.addListener(_refresh);
    }
    _refresh();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    widget.scrollController.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
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
    final documentLength = widget.controller.document.length - 1;
    final measured = <_MeasuredMarker>[];
    for (final marker in widget.markers) {
      if (marker.offset < 0 || marker.offset >= documentLength) continue;
      final boxes = quillSelectionGlobalRects(
        editor,
        TextRange(start: marker.offset, end: marker.offset + 1),
      );
      if (boxes.isEmpty) continue;
      final box = boxes.first;
      final rect = Rect.fromPoints(
        layerBox.globalToLocal(box.topLeft),
        layerBox.globalToLocal(box.bottomRight),
      );
      measured.add(_MeasuredMarker(marker: marker, rect: rect));
    }
    if (_sameMarkers(_markers, measured)) return;
    setState(() => _markers = measured);
  }

  RenderEditor? _findRenderEditor(RenderObject? root) {
    if (root == null) return null;
    if (root is RenderEditor) return root;
    RenderEditor? result;
    root.visitChildren((child) => result ??= _findRenderEditor(child));
    return result;
  }

  bool _sameMarkers(List<_MeasuredMarker> left, List<_MeasuredMarker> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    _refresh();
    final palette = InlineAnnotationPalette.of(context);
    return IgnorePointer(
      child: Stack(
        children: <Widget>[
          for (final measured in _markers)
            Positioned.fromRect(
              rect: measured.rect,
              child: _MentionBadge(marker: measured.marker, palette: palette),
            ),
        ],
      ),
    );
  }
}

@immutable
final class _MeasuredMarker {
  const _MeasuredMarker({required this.marker, required this.rect});

  final PlainTextQuillMentionMarker marker;
  final Rect rect;

  @override
  bool operator ==(Object other) =>
      other is _MeasuredMarker &&
      other.marker.offset == marker.offset &&
      identical(other.marker.annotation, marker.annotation) &&
      other.rect == rect;

  @override
  int get hashCode => Object.hash(marker.offset, marker.annotation, rect);
}

class _MentionBadge extends StatelessWidget {
  const _MentionBadge({required this.marker, required this.palette});

  final PlainTextQuillMentionMarker marker;
  final InlineAnnotationPalette palette;

  @override
  Widget build(BuildContext context) {
    final annotation = marker.annotation;
    final background =
        palette.backgrounds[annotation.colors.background] ??
        Theme.of(context).colorScheme.secondaryContainer;
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      key: ValueKey<String>("plain-text-quill-mention-${marker.offset}"),
      label: "${_kindLabel(annotation.kind)}標記：${annotation.displayText}",
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(color: background.withValues(alpha: 0.42)),
          child: Center(
            child: Text(
              _symbol(annotation.kind),
              style: TextStyle(
                color: foreground,
                fontSize: 16,
                height: 1.15,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _kindLabel(InlineAnnotationKind kind) => switch (kind) {
    InlineAnnotationKind.character => "人物",
    InlineAnnotationKind.location => "地點",
    InlineAnnotationKind.event => "事件",
    InlineAnnotationKind.foreshadowing => "伏筆",
    InlineAnnotationKind.plan => "計畫",
    InlineAnnotationKind.item => "物品",
    InlineAnnotationKind.emphasis => "高亮",
  };

  String _symbol(InlineAnnotationKind kind) => switch (kind) {
    InlineAnnotationKind.character => "@",
    InlineAnnotationKind.location => "!",
    InlineAnnotationKind.event => "#",
    InlineAnnotationKind.foreshadowing => "?",
    InlineAnnotationKind.plan => "&",
    InlineAnnotationKind.item => "*",
    InlineAnnotationKind.emphasis => "^",
  };
}
