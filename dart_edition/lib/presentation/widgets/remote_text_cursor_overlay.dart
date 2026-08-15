import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../providers/collaboration_providers.dart";

final class RemoteTextCursorPosition {
  final RemoteCursorState cursor;
  final Offset offset;
  final double caretHeight;

  const RemoteTextCursorPosition({
    required this.cursor,
    required this.offset,
    required this.caretHeight,
  });
}

/// Paints remote carets in the coordinate space of the sibling editable.
///
/// The caret itself stays exactly at [RenderEditable.getLocalRectForCaret].
/// Its IP label is positioned independently above the caret, so label height
/// and text scale can never shift the cursor indicator.
class RemoteTextCursorOverlay extends StatefulWidget {
  final TextEditingController controller;
  final List<RemoteCursorState> cursors;

  const RemoteTextCursorOverlay({
    super.key,
    required this.controller,
    required this.cursors,
  });

  @override
  State<RemoteTextCursorOverlay> createState() =>
      RemoteTextCursorOverlayState();
}

class RemoteTextCursorOverlayState extends State<RemoteTextCursorOverlay> {
  List<RemoteTextCursorPosition> _positions =
      const <RemoteTextCursorPosition>[];
  bool _measurementScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(refresh);
  }

  @override
  void didUpdateWidget(covariant RemoteTextCursorOverlay oldWidget) {
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
    final positions = <RemoteTextCursorPosition>[];
    for (final cursor in widget.cursors) {
      final offset = cursor.focusOffset
          .clamp(0, widget.controller.text.length)
          .toInt();
      final caretRect = editable.getLocalRectForCaret(
        TextPosition(offset: offset),
      );
      final global = editable.localToGlobal(caretRect.topLeft);
      final local = layerBox.globalToLocal(global);
      if (local.dx < -1 ||
          local.dx > layerBox.size.width + 1 ||
          local.dy < -caretRect.height ||
          local.dy > layerBox.size.height) {
        continue;
      }
      positions.add(
        RemoteTextCursorPosition(
          cursor: cursor,
          offset: local,
          caretHeight: caretRect.height,
        ),
      );
    }
    if (_samePositions(_positions, positions)) return;
    setState(() => _positions = positions);
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
    List<RemoteTextCursorPosition> left,
    List<RemoteTextCursorPosition> right,
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
        children: [
          for (final position in _positions)
            Positioned(
              left: position.offset.dx,
              top: position.offset.dy,
              child: _RemoteCaretMarker(position: position),
            ),
        ],
      ),
    );
  }
}

class _RemoteCaretMarker extends StatelessWidget {
  final RemoteTextCursorPosition position;

  const _RemoteCaretMarker({required this.position});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: "${position.cursor.ipAddress} 的游標",
      child: SizedBox(
        key: ValueKey<String>("remote-caret-${position.cursor.replicaId}"),
        width: 2,
        height: position.caretHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
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

/// Compact IP badges used by chapter selectors when collaborators are editing
/// chapters other than the one currently open on this device.
class ChapterRemotePresenceBadges extends ConsumerWidget {
  final String chapterId;

  const ChapterRemotePresenceBadges({super.key, required this.chapterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cursors = ref.watch(chapterRemoteCursorsProvider(chapterId));
    if (cursors.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final cursor in cursors)
            Semantics(
              label: "${cursor.ipAddress} 正在編輯此章節",
              child: Tooltip(
                message: "${cursor.ipAddress} 正在編輯此章節",
                child: Container(
                  key: ValueKey(
                    "chapter-presence-$chapterId-${cursor.replicaId}",
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_location_alt_outlined,
                        size: 12,
                        color: colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        cursor.ipAddress,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Adds field-scoped presence reporting and remote caret painting around a
/// text field. The supplied [focusNode] must also be used by [child].
class CollaborativeProjectTextFieldRegion extends ConsumerStatefulWidget {
  final String fieldId;
  final String? crdtDocumentId;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool Function()? shouldPublishTextChanges;
  final Widget child;

  const CollaborativeProjectTextFieldRegion({
    super.key,
    required this.fieldId,
    this.crdtDocumentId,
    required this.controller,
    required this.focusNode,
    this.shouldPublishTextChanges,
    required this.child,
  });

  @override
  ConsumerState<CollaborativeProjectTextFieldRegion> createState() =>
      _CollaborativeProjectTextFieldRegionState();
}

class _CollaborativeProjectTextFieldRegionState
    extends ConsumerState<CollaborativeProjectTextFieldRegion> {
  final GlobalKey<RemoteTextCursorOverlayState> _overlayKey =
      GlobalKey<RemoteTextCursorOverlayState>();
  bool _textSyncScheduled = false;
  late final CollaborationNotifier _collaborationNotifier;

  @override
  void initState() {
    super.initState();
    _collaborationNotifier = ref.read(collaborationProvider.notifier);
    widget.controller.addListener(_publishSelection);
    widget.focusNode.addListener(_handleFocusChange);
    if (widget.focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _publishSelection();
      });
    }
  }

  @override
  void didUpdateWidget(
    covariant CollaborativeProjectTextFieldRegion oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_publishSelection);
      widget.controller.addListener(_publishSelection);
    }
    if (!identical(oldWidget.focusNode, widget.focusNode)) {
      oldWidget.focusNode.removeListener(_handleFocusChange);
      widget.focusNode.addListener(_handleFocusChange);
    }
    if (oldWidget.fieldId != widget.fieldId ||
        oldWidget.crdtDocumentId != widget.crdtDocumentId) {
      _clearCursorFor(oldWidget);
      if (widget.focusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _publishSelection();
        });
      }
    }
  }

  @override
  void dispose() {
    _clearCursorFor(widget);
    widget.controller.removeListener(_publishSelection);
    widget.focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    if (widget.focusNode.hasFocus) {
      _publishSelection();
    } else {
      _clearCursorFor(widget);
    }
  }

  void _clearCursorFor(CollaborativeProjectTextFieldRegion target) {
    final documentId = target.crdtDocumentId;
    if (documentId == null) {
      _collaborationNotifier.clearLocalProjectFieldCursor(target.fieldId);
    } else {
      _collaborationNotifier.clearLocalProjectTextCursor(documentId);
    }
  }

  void _publishSelection() {
    if (!widget.focusNode.hasFocus) return;
    final selection = widget.controller.selection;
    if (!selection.isValid) return;
    final anchorOffset = selection.baseOffset
        .clamp(0, widget.controller.text.length)
        .toInt();
    final focusOffset = selection.extentOffset
        .clamp(0, widget.controller.text.length)
        .toInt();
    final notifier = ref.read(collaborationProvider.notifier);
    final documentId = widget.crdtDocumentId;
    if (documentId == null) {
      notifier.updateLocalProjectFieldCursor(
        fieldId: widget.fieldId,
        anchorOffset: anchorOffset,
        focusOffset: focusOffset,
      );
    } else {
      // A detail editor commonly reuses one controller while switching
      // between owners. Its old region is still mounted while the parent
      // loads the next owner's text, so publishing that programmatic change
      // would write the new text into the previous owner's CRDT document.
      if (widget.shouldPublishTextChanges?.call() == false) return;
      notifier.recordLocalProjectTextEdit(
        documentId: documentId,
        nextText: widget.controller.text,
        anchorOffset: anchorOffset,
        focusOffset: focusOffset,
      );
    }
  }

  void _scheduleCollaborativeTextSync(
    String documentId,
    String text,
    LocalTextSelectionRebase? rebase,
  ) {
    final shouldApplyRebase =
        rebase?.documentId == documentId && rebase?.expectedText == text;
    if (_textSyncScheduled ||
        (!shouldApplyRebase && widget.controller.text == text)) {
      return;
    }
    _textSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textSyncScheduled = false;
      if (!mounted || widget.crdtDocumentId != documentId) return;
      final activeRebase = ref.read(collaborationProvider).localSelectionRebase;
      final useRebase =
          activeRebase?.documentId == documentId &&
          activeRebase?.expectedText == text;
      final currentSelection = widget.controller.selection;
      final nextSelection = useRebase
          ? TextSelection(
              baseOffset: activeRebase!.anchorOffset
                  .clamp(0, text.length)
                  .toInt(),
              extentOffset: activeRebase.focusOffset
                  .clamp(0, text.length)
                  .toInt(),
            )
          : TextSelection(
              baseOffset: currentSelection.isValid
                  ? currentSelection.baseOffset.clamp(0, text.length).toInt()
                  : text.length,
              extentOffset: currentSelection.isValid
                  ? currentSelection.extentOffset.clamp(0, text.length).toInt()
                  : text.length,
            );
      if (widget.controller.text != text ||
          widget.controller.selection != nextSelection) {
        widget.controller.value = widget.controller.value.copyWith(
          text: text,
          selection: nextSelection,
          composing: TextRange.empty,
        );
      }
      if (useRebase && activeRebase != null) {
        ref
            .read(collaborationProvider.notifier)
            .consumeLocalSelectionRebase(activeRebase.revision);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final documentId = widget.crdtDocumentId;
    final List<RemoteCursorState> cursors = documentId == null
        ? ref.watch(projectFieldRemoteCursorsProvider(widget.fieldId))
        : ref.watch(projectTextRemoteCursorsProvider(documentId));
    if (documentId != null) {
      final text = ref.watch(collaborativeTextValueProvider(documentId));
      final rebase = ref.watch(
        collaborationProvider.select((state) => state.localSelectionRebase),
      );
      if (text != null) {
        _scheduleCollaborativeTextSync(documentId, text, rebase);
      }
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _overlayKey.currentState?.refresh();
        return false;
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          Positioned.fill(
            child: RemoteTextCursorOverlay(
              key: _overlayKey,
              controller: widget.controller,
              cursors: cursors,
            ),
          ),
        ],
      ),
    );
  }
}
