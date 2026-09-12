import "package:flutter/material.dart";
import "package:flutter/foundation.dart";
import "package:flutter/rendering.dart";

import "inline_annotation.dart";
import "inline_annotation_palette.dart";
import "inline_annotation_projection.dart";
import "mosaic_editing_controller.dart";

final class InlineAnnotationSymbolPosition {
  final InlineAnnotation annotation;
  final Offset offset;
  final double lineHeight;
  final double slotWidth;
  final List<Rect> hoverRects;

  const InlineAnnotationSymbolPosition({
    required this.annotation,
    required this.offset,
    required this.lineHeight,
    required this.slotWidth,
    this.hoverRects = const [],
  });
}

/// Paints the annotation kind inside the projection's reserved badge slot.
class InlineAnnotationSymbolOverlay extends StatefulWidget {
  final MosaicEditingController controller;
  final String Function(InlineAnnotation)? tooltipFor;

  const InlineAnnotationSymbolOverlay({
    super.key,
    required this.controller,
    this.tooltipFor,
  });

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
    final composing = widget.controller.value.composing;
    final useTransientOffsets = composing.isValid && !composing.isCollapsed;
    var transientSearchOffset = 0;
    for (final entry in widget.controller.projection.projectedAnnotations) {
      if (entry.isExpanded || entry.badgeRange.isCollapsed) continue;
      final badgeStart = useTransientOffsets
          ? widget.controller.text.indexOf(
              inlineAnnotationPlaceholder,
              transientSearchOffset,
            )
          : entry.badgeRange.start;
      if (badgeStart < 0 || badgeStart >= widget.controller.text.length) break;
      final badgeEnd = badgeStart + inlineAnnotationPlaceholder.length;
      transientSearchOffset = badgeEnd;
      final caretRect = editable.getLocalRectForCaret(
        TextPosition(offset: badgeStart),
      );
      final afterBadgeRect = editable.getLocalRectForCaret(
        TextPosition(offset: badgeEnd),
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
          hoverRects: useTransientOffsets
              ? const []
              : [
                  for (final box in editable.getBoxesForSelection(
                    TextSelection(
                      baseOffset: entry.displayRange.start,
                      extentOffset: entry.displayRange.end,
                    ),
                  ))
                    box.toRect().shift(
                      layerBox.globalToLocal(
                        editable.localToGlobal(Offset.zero),
                      ),
                    ),
                ],
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
      if (left[index].annotation != right[index].annotation ||
          !listEquals(left[index].hoverRects, right[index].hoverRects) ||
          left[index].annotation.sourceRange !=
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final position in _positions)
          Positioned(
            left: position.offset.dx,
            top: position.offset.dy,
            child: IgnorePointer(
              child: _AnnotationKindBadge(
                position.annotation,
                width: position.slotWidth,
                height: position.lineHeight,
              ),
            ),
          ),
        if (widget.tooltipFor != null)
          for (final position in _positions)
            for (final rect in position.hoverRects)
              Positioned.fromRect(
                rect: rect,
                child: _HoverPassthrough(
                  child: Tooltip(
                    message: widget.tooltipFor!(position.annotation),
                    waitDuration: const Duration(milliseconds: 500),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
      ],
    );
  }
}

/// Keeps tooltip hover entries while allowing the editor below to receive taps
/// and selection drags.
class _HoverPassthrough extends SingleChildRenderObjectWidget {
  const _HoverPassthrough({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHoverPassthrough();
}

class _RenderHoverPassthrough extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    super.hitTest(result, position: position);
    return false;
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
