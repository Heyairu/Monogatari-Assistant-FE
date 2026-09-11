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

import "dart:async";
import "dart:math" as math;

import "package:code_text_field/code_text_field.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/character_data.dart" as character_model;
import "../models/outline_data.dart" as outline_model;
import "../models/plan_data.dart" as plan_model;
import "../models/world_settings_data.dart" as world_model;
import "../presentation/providers/collaboration_providers.dart";
import "../presentation/providers/global_state_providers.dart";
import "../presentation/providers/project_state_providers.dart";
import "../presentation/widgets/remote_text_cursor_overlay.dart";
import "../features/inline_annotations/inline_annotation_target_resolver.dart";
import "../features/inline_annotations/inline_annotation.dart";
import "../features/inline_annotations/inline_annotation_syntax.dart";
import "../features/inline_annotations/inline_annotation_symbol_overlay.dart";
import "../features/inline_annotations/mosaic_editing_controller.dart";
import "../features/poppin/poppin.dart";

final class EditorTextInteraction {
  final int displayOffset;
  final Offset globalPosition;

  const EditorTextInteraction({
    required this.displayOffset,
    required this.globalPosition,
  });
}

class EditorTextBox extends ConsumerStatefulWidget {
  final CodeController controller;
  final FocusNode focusNode;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final ValueChanged<EditorTextInteraction>? onInteractionOffset;

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
  static const _intelliSenseEngine = MosaicIntelliSenseEngine();
  static const _targetResolver = InlineAnnotationTargetResolver();
  final GlobalKey<RemoteTextCursorOverlayState> _remoteCursorLayerKey =
      GlobalKey<RemoteTextCursorOverlayState>();
  final GlobalKey<InlineAnnotationSymbolOverlayState>
  _annotationSymbolLayerKey = GlobalKey<InlineAnnotationSymbolOverlayState>();
  final GlobalKey _editorStackKey = GlobalKey();
  MosaicCompletionSession? _completionSession;
  Offset? _completionAnchor;
  bool _completionMeasurementScheduled = false;
  bool _completionRefreshScheduled = false;
  late final PoppinNavigation<MosaicCompletionCandidate> _poppin =
      PoppinNavigation<MosaicCompletionCandidate>(
        childrenOf: (candidate) => candidate.children,
        labelOf: (candidate) => candidate.label,
      );

  List<MosaicCompletionCandidate>? get _activeCompletionCandidates =>
      _poppin.activeItems;

  @override
  void initState() {
    super.initState();
    _attachControllerKeyHandler(widget.controller);
    widget.focusNode.addListener(_handleFocusChange);
    widget.controller.addListener(_handleControllerChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshCompletion());
  }

  @override
  void didUpdateWidget(covariant EditorTextBox oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      _detachControllerKeyHandler(oldWidget.controller);
      oldWidget.controller.removeListener(_handleControllerChange);
      _attachControllerKeyHandler(widget.controller);
      widget.controller.addListener(_handleControllerChange);
      _refreshCompletion();
    }

    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChange);
      widget.focusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    _detachControllerKeyHandler(widget.controller);
    widget.focusNode.removeListener(_handleFocusChange);
    widget.controller.removeListener(_handleControllerChange);
    super.dispose();
  }

  void _handleControllerChange() {
    _refreshCompletion();
    if (_completionRefreshScheduled) return;
    _completionRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _completionRefreshScheduled = false;
      if (mounted) _refreshCompletion();
    });
  }

  void _attachControllerKeyHandler(CodeController controller) {
    if (controller case final MosaicEditingController mosaicController) {
      mosaicController.onTabKeyPressed = _acceptCompletionFromTab;
    }
  }

  void _detachControllerKeyHandler(CodeController controller) {
    if (controller case final MosaicEditingController mosaicController) {
      mosaicController.onTabKeyPressed = null;
    }
  }

  bool _acceptCompletionFromTab() {
    final poppinEnabled =
        ref.read(settingsStateProvider).valueOrNull?.poppinEnabled ?? true;
    if (!poppinEnabled ||
        !widget.focusNode.hasFocus ||
        _hasActiveComposition(widget.controller.value) ||
        _completionSession == null) {
      return false;
    }
    final candidates = _activeCompletionCandidates;
    if (candidates == null || candidates.isEmpty) return false;
    _selectCompletion(_poppin.selectedIndex);
    return true;
  }

  void _refreshCompletion() {
    if (!mounted) return;
    final controller = widget.controller;
    final selection = controller.selection;
    MosaicCompletionSession? nextSession;
    final poppinEnabled =
        ref.read(settingsStateProvider).valueOrNull?.poppinEnabled ?? true;
    if (poppinEnabled &&
        controller is MosaicEditingController &&
        selection.isValid &&
        selection.isCollapsed &&
        !_hasActiveComposition(controller.value)) {
      final rawSelection = controller.projection.displaySelectionToRaw(
        selection,
      );
      nextSession = _intelliSenseEngine.build(
        rawText: controller.rawText,
        rawCaret: rawSelection.extentOffset,
        loadTargets: (kind) => _targetResolver.candidates(
          kind: kind,
          characters: ref.read(characterDataProvider),
          locations: ref.read(worldSettingsDataProvider),
          outline: ref.read(outlineDataProvider),
          foreshadows: ref.read(foreshadowDataProvider),
          plans: ref.read(updatePlanDataProvider),
        ),
      );
    }
    setState(() {
      _completionSession = nextSession;
      if (nextSession == null) _completionAnchor = null;
      _poppin.reset(nextSession?.candidates);
    });
    if (nextSession != null) _scheduleCompletionAnchorMeasurement();
  }

  static bool _hasActiveComposition(TextEditingValue value) =>
      value.composing.isValid && !value.composing.isCollapsed;

  void _scheduleCompletionAnchorMeasurement() {
    if (_completionMeasurementScheduled) return;
    _completionMeasurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _completionMeasurementScheduled = false;
      if (!mounted || _completionSession == null) return;
      final stackBox = _editorStackKey.currentContext?.findRenderObject();
      if (stackBox is! RenderBox || !stackBox.hasSize) return;
      final editable = _findRenderEditable(stackBox);
      if (editable == null || !editable.hasSize) return;
      final offset = widget.controller.selection.extentOffset
          .clamp(0, widget.controller.text.length)
          .toInt();
      final caretRect = editable.getLocalRectForCaret(
        TextPosition(offset: offset),
      );
      final global = editable.localToGlobal(caretRect.bottomLeft);
      final local = stackBox.globalToLocal(global);
      if (_completionAnchor == local) return;
      setState(() => _completionAnchor = local);
    });
  }

  RenderEditable? _findRenderEditable(RenderObject root) {
    if (root is RenderEditable) return root;
    RenderEditable? result;
    root.visitChildren((child) {
      result ??= _findRenderEditable(child);
    });
    return result;
  }

  void _moveCompletion(int delta) {
    if (_poppin.activeItems case final items? when items.isNotEmpty) {
      setState(() => _poppin.move(delta));
    }
  }

  void _enterCompletionLevel([int? index]) {
    if (_poppin.activeItems == null) return;
    setState(() => _poppin.enter(index));
  }

  void _exitCompletionLevel() {
    if (!_poppin.canGoBack) return;
    setState(_poppin.exit);
  }

  void _selectCompletion(int index) {
    final candidates = _activeCompletionCandidates;
    if (candidates == null || index < 0 || index >= candidates.length) return;
    final createKind = candidates[index].createTargetKind;
    if (createKind != null) {
      unawaited(_createCompletionTarget(candidates[index]));
      return;
    }
    if (candidates[index].submenuOnly &&
        candidates[index].children.isNotEmpty) {
      _enterCompletionLevel(index);
      return;
    }
    _acceptCompletion(index);
  }

  Future<void> _createCompletionTarget(
    MosaicCompletionCandidate candidate,
  ) async {
    final kind = candidate.createTargetKind;
    if (kind == null) return;
    final session = _completionSession;
    final controller = widget.controller;
    if (session == null || controller is! MosaicEditingController) return;
    final originalRawText = controller.rawText;
    final name = await _showCreateTargetDialog(
      kind,
      title: candidate.label.replaceAll("…", ""),
    );
    if (!mounted || name == null || controller.rawText != originalRawText) {
      widget.focusNode.requestFocus();
      return;
    }

    final target = _persistNewTarget(
      kind,
      name,
      parentId: candidate.createParentId,
      depth: candidate.createDepth,
    );
    if (target == null) {
      widget.focusNode.requestFocus();
      return;
    }
    controller.replaceRawRange(
      session.rawReplacementRange,
      InlineAnnotationSyntax.format(
        kind: kind,
        state: InlineAnnotationState.none,
        colors: const InlineAnnotationColorCode(
          background: "B",
          foreground: "0",
        ),
        targetId: target.id,
        displayText: target.primaryName,
      ),
    );
    _dismissCompletion();
    widget.focusNode.requestFocus();
  }

  Future<String?> _showCreateTargetDialog(
    InlineAnnotationKind kind, {
    String? title,
  }) async {
    var draftName = "";
    final label = switch (kind) {
      InlineAnnotationKind.character => "人物",
      InlineAnnotationKind.location => "地點",
      InlineAnnotationKind.event => "事件",
      InlineAnnotationKind.foreshadowing => "伏筆",
      InlineAnnotationKind.plan => "計畫",
      InlineAnnotationKind.emphasis => "重點",
    };
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title ?? "新增$label"),
        content: SizedBox(
          width: 320,
          child: TextField(
            key: const ValueKey("mosaic-create-target-name"),
            autofocus: true,
            decoration: const InputDecoration(labelText: "名稱", isDense: true),
            onChanged: (value) => draftName = value,
            onSubmitted: (value) {
              final trimmed = value.trim();
              if (trimmed.isNotEmpty) {
                Navigator.of(dialogContext).pop(trimmed);
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("取消"),
          ),
          FilledButton(
            key: const ValueKey("mosaic-create-target-submit"),
            onPressed: () {
              final trimmed = draftName.trim();
              if (trimmed.isNotEmpty) {
                Navigator.of(dialogContext).pop(trimmed);
              }
            },
            child: const Text("建立"),
          ),
        ],
      ),
    );
  }

  InlineAnnotationTargetInfo? _persistNewTarget(
    InlineAnnotationKind kind,
    String name, {
    String? parentId,
    int depth = 0,
  }) {
    switch (kind) {
      case InlineAnnotationKind.character:
        final entry = character_model.CharacterEntryData.withName(name);
        final added = ref
            .read(characterDataProvider.notifier)
            .setCharacterEntry(characterId: entry.characterId, entry: entry);
        return added
            ? InlineAnnotationTargetInfo(
                id: entry.characterId,
                primaryName: entry.displayName,
                displayName: entry.displayName,
                displayNameIsAlias: false,
              )
            : null;
      case InlineAnnotationKind.location:
        final location = world_model.LocationData(localName: name);
        var inserted = parentId == null;
        List<world_model.LocationData> insertBelow(
          List<world_model.LocationData> nodes,
        ) {
          return [
            for (final node in nodes)
              if (node.id == parentId)
                node.copyWith(child: [...node.child, location])
              else
                node.copyWith(child: insertBelow(node.child)),
          ];
        }

        ref.read(worldSettingsDataProvider.notifier).updateWorldSettingsData((
          current,
        ) {
          if (parentId == null) return [...current, location];
          final updated = insertBelow(current);
          inserted = updated.any(
            (node) => _locationTreeContains(node, location.id),
          );
          return inserted ? updated : current;
        });
        if (!inserted) return null;
        return InlineAnnotationTargetInfo(
          id: location.id,
          primaryName: location.localName,
          displayName: location.localName,
          displayNameIsAlias: false,
        );
      case InlineAnnotationKind.event:
        if (parentId == null || depth == 0) {
          final storyline = outline_model.StorylineData(storylineName: name);
          ref
              .read(outlineDataProvider.notifier)
              .updateOutlineData((current) => [...current, storyline]);
          return InlineAnnotationTargetInfo(
            id: storyline.chapterUUID,
            primaryName: storyline.storylineName,
            displayName: storyline.storylineName,
            displayNameIsAlias: false,
          );
        }
        if (depth == 1) {
          final event = outline_model.StoryEventData(storyEvent: name);
          var inserted = false;
          ref.read(outlineDataProvider.notifier).updateOutlineData((current) {
            return [
              for (final storyline in current)
                if (storyline.chapterUUID == parentId)
                  (() {
                    inserted = true;
                    return storyline.copyWith(
                      scenes: [...storyline.scenes, event],
                    );
                  })()
                else
                  storyline,
            ];
          });
          return inserted
              ? InlineAnnotationTargetInfo(
                  id: event.storyEventUUID,
                  primaryName: event.storyEvent,
                  displayName: event.storyEvent,
                  displayNameIsAlias: false,
                )
              : null;
        }
        final scene = outline_model.SceneData(sceneName: name);
        var inserted = false;
        ref.read(outlineDataProvider.notifier).updateOutlineData((current) {
          return [
            for (final storyline in current)
              storyline.copyWith(
                scenes: [
                  for (final event in storyline.scenes)
                    if (event.storyEventUUID == parentId)
                      (() {
                        inserted = true;
                        return event.copyWith(scenes: [...event.scenes, scene]);
                      })()
                    else
                      event,
                ],
              ),
          ];
        });
        return inserted
            ? InlineAnnotationTargetInfo(
                id: scene.sceneUUID,
                primaryName: scene.sceneName,
                displayName: scene.sceneName,
                displayNameIsAlias: false,
              )
            : null;
      case InlineAnnotationKind.foreshadowing:
        final item = plan_model.ForeshadowItem(title: name);
        ref.read(foreshadowDataProvider.notifier).addForeshadowItem(item);
        return InlineAnnotationTargetInfo(
          id: item.id,
          primaryName: item.title,
          displayName: item.title,
          displayNameIsAlias: false,
        );
      case InlineAnnotationKind.plan:
        final item = plan_model.UpdatePlanItem(title: name);
        ref.read(updatePlanDataProvider.notifier).addUpdatePlanItem(item);
        return InlineAnnotationTargetInfo(
          id: item.id,
          primaryName: item.title,
          displayName: item.title,
          displayNameIsAlias: false,
        );
      case InlineAnnotationKind.emphasis:
        return null;
    }
  }

  bool _locationTreeContains(world_model.LocationData node, String id) {
    if (node.id == id) return true;
    return node.child.any((child) => _locationTreeContains(child, id));
  }

  void _acceptCompletion([int? index]) {
    final session = _completionSession;
    final controller = widget.controller;
    final candidates = _activeCompletionCandidates;
    if (session == null ||
        candidates == null ||
        candidates.isEmpty ||
        controller is! MosaicEditingController) {
      return;
    }
    final selectedIndex = index ?? _poppin.selectedIndex;
    final candidate = candidates[selectedIndex];
    controller.replaceRawRange(
      session.rawReplacementRange,
      candidate.insertText,
    );
    setState(() {
      _completionSession = null;
      _completionAnchor = null;
      _poppin.dismiss();
    });
  }

  void _dismissCompletion() {
    if (_completionSession == null) return;
    setState(() {
      _completionSession = null;
      _completionAnchor = null;
      _poppin.dismiss();
    });
  }

  void _moveAcrossAtomicMention(int direction) {
    final controller = widget.controller;
    if (controller is! MosaicEditingController ||
        !controller.selection.isValid ||
        !controller.selection.isCollapsed) {
      return;
    }
    final target = controller.atomicNavigationTarget(
      controller.selection.extentOffset,
      direction,
    );
    if (target == null) return;
    controller.selection = TextSelection.collapsed(offset: target);
  }

  void _deleteAtomicMention({required bool backward}) {
    final controller = widget.controller;
    if (controller is! MosaicEditingController ||
        !controller.selection.isValid ||
        !controller.selection.isCollapsed) {
      return;
    }
    controller.deleteAtomicAnnotationAt(
      controller.selection.extentOffset,
      backward: backward,
    );
  }

  void _handleFocusChange() {
    if (!mounted) {
      return;
    }
    if (widget.focusNode.hasFocus) {
      final chapterId = ref.read(editorSelectionProvider).selectedChapID;
      final displaySelection = widget.controller.selection;
      final selection = widget.controller is MosaicEditingController
          ? (widget.controller as MosaicEditingController).projection
                .displaySelectionToRaw(displaySelection)
          : displaySelection;
      if (chapterId != null && selection.isValid) {
        ref
            .read(collaborationProvider.notifier)
            .updateLocalCursor(
              chapterId: chapterId,
              anchorOffset: selection.baseOffset
                  .clamp(
                    0,
                    widget.controller is MosaicEditingController
                        ? (widget.controller as MosaicEditingController)
                              .rawText
                              .length
                        : widget.controller.text.length,
                  )
                  .toInt(),
              focusOffset: selection.extentOffset
                  .clamp(
                    0,
                    widget.controller is MosaicEditingController
                        ? (widget.controller as MosaicEditingController)
                              .rawText
                              .length
                        : widget.controller.text.length,
                  )
                  .toInt(),
            );
      }
    }
    setState(() {});
  }

  Future<void> _copySelection({required bool cut}) async {
    final controller = widget.controller;
    final selection = controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final selectedText = controller is MosaicEditingController
        ? controller.plainTextForSelection(selection)
        : controller.text.substring(selection.start, selection.end);
    final originalText = controller.text;
    await Clipboard.setData(ClipboardData(text: selectedText));
    if (!cut || !mounted || controller.text != originalText) return;

    controller.value = controller.value.copyWith(
      text: originalText.replaceRange(selection.start, selection.end, ""),
      selection: TextSelection.collapsed(offset: selection.start),
      composing: TextRange.empty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = ref.watch(
      settingsStateProvider.select(
        (state) => state.valueOrNull?.fontSize ?? 12.0,
      ),
    );
    final poppinEnabled = ref.watch(
      settingsStateProvider.select(
        (state) => state.valueOrNull?.poppinEnabled ?? true,
      ),
    );
    final isComposing = _hasActiveComposition(widget.controller.value);
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
    final completionCandidates = poppinEnabled
        ? _activeCompletionCandidates ?? const <MosaicCompletionCandidate>[]
        : const <MosaicCompletionCandidate>[];
    final hasCompletionCandidates = completionCandidates.isNotEmpty;
    final canEnterCompletionLevel = _poppin.canEnterSelected;
    if (poppinEnabled &&
        _completionSession != null &&
        _completionAnchor == null) {
      _scheduleCompletionAnchorMeasurement();
    }
    final completionAnchor = _completionAnchor ?? const Offset(8, 8);
    final mosaicController = widget.controller is MosaicEditingController
        ? widget.controller as MosaicEditingController
        : null;
    final atomicSelection = mosaicController?.selection;
    final atomicOffset =
        atomicSelection?.isValid == true && atomicSelection?.isCollapsed == true
        ? atomicSelection!.extentOffset
        : null;
    final skipLeft = atomicOffset == null
        ? null
        : mosaicController?.atomicNavigationTarget(atomicOffset, -1);
    final skipRight = atomicOffset == null
        ? null
        : mosaicController?.atomicNavigationTarget(atomicOffset, 1);
    final deleteBackward =
        atomicOffset != null &&
        mosaicController!.canDeleteAtomicAnnotationAt(
          atomicOffset,
          backward: true,
        );
    final deleteForward =
        atomicOffset != null &&
        mosaicController!.canDeleteAtomicAnnotationAt(
          atomicOffset,
          backward: false,
        );
    final shortcuts = <ShortcutActivator, Intent>{
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
      SingleActivator(
        LogicalKeyboardKey.keyC,
        control: !isApple,
        meta: isApple,
      ): const _EditorCopyIntent(),
      SingleActivator(
        LogicalKeyboardKey.keyX,
        control: !isApple,
        meta: isApple,
      ): const _EditorCutIntent(),
      if (!isComposing && hasCompletionCandidates) ...{
        const SingleActivator(LogicalKeyboardKey.arrowUp):
            const PoppinMoveIntent(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown):
            const PoppinMoveIntent(1),
        if (_poppin.canGoBack)
          const SingleActivator(LogicalKeyboardKey.arrowLeft):
              const PoppinLevelIntent(-1),
        if (canEnterCompletionLevel)
          const SingleActivator(LogicalKeyboardKey.arrowRight):
              const PoppinLevelIntent(1),
        const SingleActivator(LogicalKeyboardKey.enter):
            const PoppinAcceptIntent(),
        const SingleActivator(LogicalKeyboardKey.tab):
            const PoppinAcceptIntent(),
        const SingleActivator(LogicalKeyboardKey.escape):
            const PoppinDismissIntent(),
      },
      if (!isComposing && !hasCompletionCandidates && skipLeft != null)
        const SingleActivator(LogicalKeyboardKey.arrowLeft):
            const _AtomicMentionMoveIntent(-1),
      if (!isComposing && !hasCompletionCandidates && skipRight != null)
        const SingleActivator(LogicalKeyboardKey.arrowRight):
            const _AtomicMentionMoveIntent(1),
      if (!isComposing && deleteBackward)
        const SingleActivator(LogicalKeyboardKey.backspace):
            const _AtomicMentionDeleteIntent(backward: true),
      if (!isComposing && deleteForward)
        const SingleActivator(LogicalKeyboardKey.delete):
            const _AtomicMentionDeleteIntent(backward: false),
    };

    return RepaintBoundary(
      child: Shortcuts(
        shortcuts: shortcuts,
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
            _EditorCopyIntent: CallbackAction<_EditorCopyIntent>(
              onInvoke: (intent) {
                unawaited(_copySelection(cut: false));
                return null;
              },
            ),
            _EditorCutIntent: CallbackAction<_EditorCutIntent>(
              onInvoke: (intent) {
                unawaited(_copySelection(cut: true));
                return null;
              },
            ),
            PoppinMoveIntent: CallbackAction<PoppinMoveIntent>(
              onInvoke: (intent) {
                _moveCompletion(intent.delta);
                return null;
              },
            ),
            PoppinAcceptIntent: CallbackAction<PoppinAcceptIntent>(
              onInvoke: (intent) {
                _selectCompletion(_poppin.selectedIndex);
                return null;
              },
            ),
            PoppinLevelIntent: CallbackAction<PoppinLevelIntent>(
              onInvoke: (intent) {
                if (intent.direction < 0) {
                  _exitCompletionLevel();
                } else {
                  _enterCompletionLevel();
                }
                return null;
              },
            ),
            PoppinDismissIntent: CallbackAction<PoppinDismissIntent>(
              onInvoke: (intent) {
                _dismissCompletion();
                return null;
              },
            ),
            _AtomicMentionMoveIntent: CallbackAction<_AtomicMentionMoveIntent>(
              onInvoke: (intent) {
                _moveAcrossAtomicMention(intent.direction);
                return null;
              },
            ),
            _AtomicMentionDeleteIntent:
                CallbackAction<_AtomicMentionDeleteIntent>(
                  onInvoke: (intent) {
                    _deleteAtomicMention(backward: intent.backward);
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
                          _annotationSymbolLayerKey.currentState?.refresh();
                          _scheduleCompletionAnchorMeasurement();
                          return false;
                        },
                        child: Stack(
                          key: _editorStackKey,
                          children: [
                            Positioned.fill(
                              child: Listener(
                                onPointerUp: (event) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (!mounted) return;
                                    if (widget.controller
                                        case final MosaicEditingController
                                            controller) {
                                      controller.collapseAnnotations();
                                    }
                                    final selection =
                                        widget.controller.selection;
                                    if (selection.isValid &&
                                        selection.isCollapsed) {
                                      widget.onInteractionOffset?.call(
                                        EditorTextInteraction(
                                          displayOffset: selection.extentOffset,
                                          globalPosition: event.position,
                                        ),
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
                                offsetMapper:
                                    widget.controller is MosaicEditingController
                                    ? (widget.controller
                                              as MosaicEditingController)
                                          .projection
                                          .rawOffsetToDisplay
                                    : null,
                              ),
                            ),
                            if (widget.controller
                                case final MosaicEditingController controller)
                              Positioned.fill(
                                child: InlineAnnotationSymbolOverlay(
                                  key: _annotationSymbolLayerKey,
                                  controller: controller,
                                ),
                              ),
                            if (poppinEnabled && _completionSession != null)
                              Positioned(
                                key: const ValueKey("mosaic-completion-panel"),
                                left: math.max(
                                  8,
                                  math.min(
                                    completionAnchor.dx,
                                    constraints.maxWidth -
                                        math.min(
                                          360,
                                          constraints.maxWidth - 16,
                                        ) -
                                        8,
                                  ),
                                ),
                                top:
                                    completionAnchor.dy + 268 <=
                                        constraints.maxHeight
                                    ? completionAnchor.dy + 4
                                    : math.max(8, completionAnchor.dy - 264),
                                width: math.min(360, constraints.maxWidth - 16),
                                child: PoppinPanel<MosaicCompletionCandidate>(
                                  items: completionCandidates,
                                  selectedIndex: _poppin.selectedIndex,
                                  parentLabel: _poppin.parentPath,
                                  keyPrefix: "mosaic-completion",
                                  idOf: (candidate) => candidate.id,
                                  labelOf: (candidate) => candidate.label,
                                  detailOf: (candidate) => candidate.detail,
                                  hasChildren: (candidate) =>
                                      candidate.children.isNotEmpty,
                                  onBack: _exitCompletionLevel,
                                  onExpanded: _enterCompletionLevel,
                                  onSelected: _selectCompletion,
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

class _EditorCopyIntent extends Intent {
  const _EditorCopyIntent();
}

class _EditorCutIntent extends Intent {
  const _EditorCutIntent();
}

class _AtomicMentionMoveIntent extends Intent {
  final int direction;

  const _AtomicMentionMoveIntent(this.direction);
}

class _AtomicMentionDeleteIntent extends Intent {
  final bool backward;

  const _AtomicMentionDeleteIntent({required this.backward});
}
