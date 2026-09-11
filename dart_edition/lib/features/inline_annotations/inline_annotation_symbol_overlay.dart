import "package:flutter/material.dart";
import "package:flutter/rendering.dart";

import "inline_annotation.dart";
import "inline_annotation_palette.dart";
import "mosaic_editing_controller.dart";

final class InlineAnnotationSymbolPosition {
  final InlineAnnotation annotation;
  final Offset offset;
  final double lineHeight;
  final double slotWidth;

  const InlineAnnotationSymbolPosition({
    required this.annotation,
    required this.offset,
    required this.lineHeight,
    required this.slotWidth,
  });
}

/// Paints the annotation kind inside the projection's reserved badge slot.
class InlineAnnotationSymbolOverlay extends StatefulWidget {
  final MosaicEditingController controller;

  const InlineAnnotationSymbolOverlay({super.key, required this.controller});

  @override
  State<InlineAnnotationSymbolOverlay> createState() =>
      InlineAnnotationSymbolOverlayState();
}

class InlineAnnotationSymbolOverlayState
    extends State<InlineAnnotationSymbolOverlay> {
  List<InlineAnnotationSymbolPosition> _positions = const [];
  bool _measurementScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(refresh);
  }

  @override
  void didUpdateWidget(covariant InlineAnnotationSymbolOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(refresh);
      widget.controller.addListener(refresh);
    }
    refresh();
  }

  @override
  void dispose() {
    widget.controller.removeListener(refresh);
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
    final editable = _findRenderEditable(layerBox.parent);
    if (editable == null || !editable.hasSize) return;
    final next = <InlineAnnotationSymbolPosition>[];
    for (final entry in widget.controller.projection.projectedAnnotations) {
      if (entry.isExpanded || entry.badgeRange.isCollapsed) continue;
      final caretRect = editable.getLocalRectForCaret(
        TextPosition(offset: entry.badgeRange.start),
      );
      final afterBadgeRect = editable.getLocalRectForCaret(
        TextPosition(offset: entry.badgeRange.end),
      );
      final global = editable.localToGlobal(caretRect.topLeft);
      final local = layerBox.globalToLocal(global);
      if (local.dy < -caretRect.height || local.dy > layerBox.size.height) {
        continue;
      }
      next.add(
        InlineAnnotationSymbolPosition(
          annotation: entry.annotation,
          offset: local,
          lineHeight: caretRect.height,
          slotWidth: (afterBadgeRect.left - caretRect.left).abs(),
        ),
      );
    }
    if (_samePositions(_positions, next)) return;
    setState(() => _positions = next);
  }

  RenderEditable? _findRenderEditable(RenderObject? root) {
    if (root == null) return null;
    if (root is RenderEditable) return root;
    RenderEditable? result;
    root.visitChildren((child) {
      result ??= _findRenderEditable(child);
    });
    return result;
  }

  bool _samePositions(
    List<InlineAnnotationSymbolPosition> left,
    List<InlineAnnotationSymbolPosition> right,
  ) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index].annotation.sourceRange !=
              right[index].annotation.sourceRange ||
          left[index].offset != right[index].offset ||
          left[index].lineHeight != right[index].lineHeight ||
          left[index].slotWidth != right[index].slotWidth) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    refresh();
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final position in _positions)
            Positioned(
              left: position.offset.dx,
              top: position.offset.dy,
              child: _AnnotationKindBadge(
                position.annotation,
                width: position.slotWidth,
                height: position.lineHeight,
              ),
            ),
        ],
      ),
    );
  }
}

class _AnnotationKindBadge extends StatelessWidget {
  final InlineAnnotation annotation;
  final double width;
  final double height;

  const _AnnotationKindBadge(
    this.annotation, {
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final palette = InlineAnnotationPalette.of(context);
    final background =
        palette.backgrounds[annotation.colors.background] ??
        Theme.of(context).colorScheme.secondaryContainer;
    final foreground =
        palette.foregrounds[annotation.colors.foreground] ??
        Theme.of(context).colorScheme.onSecondaryContainer;
    return Semantics(
      key: ValueKey("inline-annotation-symbol-${annotation.sourceRange.start}"),
      label: "${_kindLabel(annotation.kind)}標記：${annotation.displayText}",
      child: ExcludeSemantics(
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(height * 0.22),
          ),
          child: Text(
            _symbol(annotation.kind),
            style: TextStyle(
              color: foreground,
              fontSize: height * 0.55,
              height: 1,
              fontWeight: FontWeight.w700,
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
    InlineAnnotationKind.emphasis => "高亮",
  };

  String _symbol(InlineAnnotationKind kind) => switch (kind) {
    InlineAnnotationKind.character => "@",
    InlineAnnotationKind.location => "!",
    InlineAnnotationKind.event => "#",
    InlineAnnotationKind.foreshadowing => "?",
    InlineAnnotationKind.plan => "&",
    InlineAnnotationKind.emphasis => "^",
  };
}
