import "package:flutter/material.dart";
import "package:flutter_quill/flutter_quill.dart";

import "../../presentation/providers/collaboration_providers.dart";

final class PlainTextQuillRemoteCursorPosition {
  const PlainTextQuillRemoteCursorPosition({
    required this.cursor,
    required this.offset,
    required this.caretHeight,
  });

  final RemoteCursorState cursor;
  final Offset offset;
  final double caretHeight;
}

/// Measures remote plain-text offsets in a sibling [QuillEditor]'s render
/// tree and paints their carets without changing the Quill document.
///
/// Collaboration offsets are canonical plain-text UTF-16 offsets. The plain
/// text adapter makes those equal to editable Quill offsets; the final Quill
/// sentinel newline is deliberately excluded from the valid range.
class PlainTextQuillRemoteCursorOverlay extends StatefulWidget {
  const PlainTextQuillRemoteCursorOverlay({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.cursors,
  });

  final QuillController controller;
  final ScrollController scrollController;
  final List<RemoteCursorState> cursors;

  @override
  State<PlainTextQuillRemoteCursorOverlay> createState() =>
      _PlainTextQuillRemoteCursorOverlayState();
}

class _PlainTextQuillRemoteCursorOverlayState
    extends State<PlainTextQuillRemoteCursorOverlay> {
  List<PlainTextQuillRemoteCursorPosition> _positions =
      const <PlainTextQuillRemoteCursorPosition>[];
  bool _measurementScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(refresh);
    widget.scrollController.addListener(refresh);
  }

  @override
  void didUpdateWidget(covariant PlainTextQuillRemoteCursorOverlay oldWidget) {
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

    final editableLength = (widget.controller.document.length - 1)
        .clamp(0, widget.controller.document.length)
        .toInt();
    final positions = <PlainTextQuillRemoteCursorPosition>[];
    for (final cursor in widget.cursors) {
      final offset = cursor.focusOffset.clamp(0, editableLength).toInt();
      final caretRect = editor.getLocalRectForCaret(
        TextPosition(offset: offset),
      );
      final global = editor.localToGlobal(caretRect.topLeft);
      final local = layerBox.globalToLocal(global);
      if (local.dx < -1 ||
          local.dx > layerBox.size.width + 1 ||
          local.dy < -caretRect.height ||
          local.dy > layerBox.size.height) {
        continue;
      }
      positions.add(
        PlainTextQuillRemoteCursorPosition(
          cursor: cursor,
          offset: local,
          caretHeight: caretRect.height,
        ),
      );
    }
    if (_samePositions(_positions, positions)) return;
    setState(() => _positions = positions);
  }

  RenderEditor? _findRenderEditor(RenderObject? root) {
    if (root == null) return null;
    if (root is RenderEditor) return root;
    RenderEditor? result;
    root.visitChildren((child) {
      result ??= _findRenderEditor(child);
    });
    return result;
  }

  bool _samePositions(
    List<PlainTextQuillRemoteCursorPosition> left,
    List<PlainTextQuillRemoteCursorPosition> right,
  ) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index].cursor.replicaId != right[index].cursor.replicaId ||
          left[index].offset != right[index].offset ||
          left[index].caretHeight != right[index].caretHeight) {
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
        children: <Widget>[
          for (final position in _positions)
            Positioned(
              left: position.offset.dx,
              top: position.offset.dy,
              child: _PlainTextQuillRemoteCaretMarker(position: position),
            ),
        ],
      ),
    );
  }
}

class _PlainTextQuillRemoteCaretMarker extends StatelessWidget {
  const _PlainTextQuillRemoteCaretMarker({required this.position});

  final PlainTextQuillRemoteCursorPosition position;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: "${position.cursor.ipAddress} 的游標",
      child: SizedBox(
        key: ValueKey<String>(
          "plain-text-quill-remote-caret-${position.cursor.replicaId}",
        ),
        width: 2,
        height: position.caretHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(child: ColoredBox(color: colorScheme.tertiary)),
            Positioned(
              left: 0,
              bottom: position.caretHeight + 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  child: Text(
                    position.cursor.ipAddress,
                    maxLines: 1,
                    softWrap: false,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
