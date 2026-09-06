/************************************************************
 * Copyright 2025-2026 Heyairu（部屋伊琉）
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 ************************************************************/

import "package:code_text_field/code_text_field.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../presentation/providers/collaboration_providers.dart";
import "../presentation/providers/global_state_providers.dart";
import "../presentation/providers/project_state_providers.dart";
import "../presentation/widgets/remote_text_cursor_overlay.dart";

class EditorTextBox extends ConsumerStatefulWidget {
  final CodeController controller;
  final FocusNode focusNode;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final ValueChanged<int>? onInteractionOffset;

  const EditorTextBox({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onUndo,
    this.onRedo,
    this.onInteractionOffset,
  });

  @override
  ConsumerState<EditorTextBox> createState() => _EditorTextBoxState();
}

class _EditorTextBoxState extends ConsumerState<EditorTextBox> {
  final GlobalKey<RemoteTextCursorOverlayState> _remoteCursorLayerKey =
      GlobalKey<RemoteTextCursorOverlayState>();

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant EditorTextBox oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      setState(() {});
    }

    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChange);
      widget.focusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    if (!mounted) {
      return;
    }
    if (widget.focusNode.hasFocus) {
      final chapterId = ref.read(editorSelectionProvider).selectedChapID;
      final selection = widget.controller.selection;
      if (chapterId != null && selection.isValid) {
        ref
            .read(collaborationProvider.notifier)
            .updateLocalCursor(
              chapterId: chapterId,
              anchorOffset: selection.baseOffset
                  .clamp(0, widget.controller.text.length)
                  .toInt(),
              focusOffset: selection.extentOffset
                  .clamp(0, widget.controller.text.length)
                  .toInt(),
            );
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = ref.watch(
      settingsStateProvider.select(
        (state) => state.valueOrNull?.fontSize ?? 12.0,
      ),
    );
    final colorScheme = Theme.of(context).colorScheme;
    final remoteCursors = ref.watch(activeChapterRemoteCursorsProvider);
    final textStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(height: 1.6, fontSize: fontSize);
    final editorBackground = colorScheme.surfaceContainerLowest;
    final bool isApple =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.iOS);

    return RepaintBoundary(
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          SingleActivator(
            LogicalKeyboardKey.keyZ,
            control: !isApple,
            meta: isApple,
          ): const _EditorUndoIntent(),
          SingleActivator(
            LogicalKeyboardKey.keyZ,
            control: !isApple,
            meta: isApple,
            shift: true,
          ): const _EditorRedoIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _EditorUndoIntent: CallbackAction<_EditorUndoIntent>(
              onInvoke: (intent) {
                widget.onUndo?.call();
                return null;
              },
            ),
            _EditorRedoIntent: CallbackAction<_EditorRedoIntent>(
              onInvoke: (intent) {
                widget.onRedo?.call();
                return null;
              },
            ),
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(color: editorBackground),
            child: ClipRect(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  const double gutterCompensation = 4;
                  final double compensatedWidth =
                      constraints.maxWidth + gutterCompensation * 2;
                  return Transform.translate(
                    // code_text_field 1.1.0 adds a fixed 8px left inset when
                    // lineNumbers is disabled. Shift left and widen equally so
                    // no visual strip appears on either side.
                    offset: const Offset(-gutterCompensation, 0),
                    child: SizedBox(
                      width: compensatedWidth,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          _remoteCursorLayerKey.currentState?.refresh();
                          return false;
                        },
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Listener(
                                onPointerUp: (_) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (!mounted) return;
                                    final selection =
                                        widget.controller.selection;
                                    if (selection.isValid &&
                                        selection.isCollapsed) {
                                      widget.onInteractionOffset?.call(
                                        selection.extentOffset,
                                      );
                                    }
                                  });
                                },
                                child: CodeField(
                                  controller: widget.controller,
                                  focusNode: widget.focusNode,
                                  expands: true,
                                  maxLines: null,
                                  minLines: null,
                                  wrap: true,
                                  horizontalScroll: false,
                                  lineNumbers: false,
                                  background: editorBackground,
                                  textStyle: textStyle,
                                  cursorColor: colorScheme.primary,
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: RemoteTextCursorOverlay(
                                key: _remoteCursorLayerKey,
                                controller: widget.controller,
                                cursors: remoteCursors,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorUndoIntent extends Intent {
  const _EditorUndoIntent();
}

class _EditorRedoIntent extends Intent {
  const _EditorRedoIntent();
}
