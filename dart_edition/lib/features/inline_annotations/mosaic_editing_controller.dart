/*
 * Copyright 2025-2026 Heyairu（部屋伊琉）
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 ************************************************************/

import "package:code_text_field/code_text_field.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "inline_annotation.dart";
import "inline_annotation_palette.dart";
import "inline_annotation_parser.dart";
import "inline_annotation_projection.dart";
import "inline_annotation_syntax.dart";

/// Technical prototype for editing a raw Mosaic document through CodeField.
///
/// CodeField receives [displayText] through the inherited controller value;
/// persistence and collaboration consumers must use [rawText]. This controller
/// is intentionally not wired into the main editor until IME and selection
/// widget tests prove the adapter safe on all supported platforms.
class MosaicEditingController extends CodeController {
  MosaicEditingController({
    String rawText = "",
    InlineAnnotationParser parser = const InlineAnnotationParser(),
  }) : _rawText = rawText,
       _parser = parser,
       _projection = InlineAnnotationProjection.build(rawText, parser: parser),
       super(text: "") {
    _ready = true;
    _publishing = true;
    super.value = TextEditingValue(
      text: _projection.displayText,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _publishing = false;
  }

  final InlineAnnotationParser _parser;
  String _rawText;
  late InlineAnnotationProjection _projection;
  bool _ready = false;
  bool _publishing = false;
  TextEditingValue? _compositionBaseValue;
  InlineAnnotationProjection? _compositionBaseProjection;
  String? _compositionBaseRawText;
  int _rawRevision = 0;
  final int _presentationRevision = 0;

  /// Lets the editor consume Tab for IntelliSense before CodeController
  /// inserts a literal tab character.
  bool Function()? onTabKeyPressed;

  String get rawText => _rawText;
  String get displayText => text;
  String get readerText => _projection.readerText;
  InlineAnnotationProjection get projection => _projection;
  List<InlineAnnotation> get annotations => _projection.annotations;
  int get rawRevision => _rawRevision;
  int get presentationRevision => _presentationRevision;
  int? get activeAnnotationStart => null;

  @override
  // code_text_field 1.1.0 still exposes its keyboard hook with RawKeyEvent.
  // ignore: deprecated_member_use
  KeyEventResult onKey(RawKeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.tab &&
        (onTabKeyPressed?.call() ?? false)) {
      return KeyEventResult.handled;
    }
    return super.onKey(event);
  }

  List<MosaicStyleRange> inlineStyleRanges(BuildContext context) {
    final palette = InlineAnnotationPalette.of(context);
    return <MosaicStyleRange>[
      for (final entry in _projection.projectedAnnotations)
        if (_displayTextRange(entry) case final range when !range.isCollapsed)
          MosaicStyleRange(
            range: range,
            style: palette.styleFor(entry.annotation.colors),
          ),
    ];
  }

  /// Returns reader-visible text even when the active annotation is expanded.
  /// This is the clipboard/export source; it never exposes UUIDs or notes.
  String plainTextForSelection(TextSelection displaySelection) {
    if (!displaySelection.isValid || displaySelection.isCollapsed) return "";
    final rawSelection = _projection.displaySelectionToRaw(displaySelection);
    final collapsed = InlineAnnotationProjection.build(
      _rawText,
      annotations: _projection.annotations,
    );
    final visibleSelection = collapsed.rawSelectionToDisplay(rawSelection);
    final start = visibleSelection.start;
    final end = visibleSelection.end;
    return collapsed.readerTextFor(TextRange(start: start, end: end));
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    bool? withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    if (_compositionBaseValue != null) {
      return _buildImeTextSpan(
        baseStyle: baseStyle,
        withComposing: withComposing == true,
      );
    }
    final annotationRanges = inlineStyleRanges(context);
    final badgeRanges = <TextRange>[
      for (final entry in _projection.projectedAnnotations)
        if (!entry.isExpanded) entry.badgeRange,
    ];
    final boundaries = <int>{0, text.length};
    for (final annotationRange in annotationRanges) {
      boundaries
        ..add(annotationRange.range.start)
        ..add(annotationRange.range.end);
    }
    for (final badgeRange in badgeRanges) {
      boundaries
        ..add(badgeRange.start)
        ..add(badgeRange.end);
    }

    final composing = value.composing;
    final showComposing =
        withComposing == true && composing.isValid && !composing.isCollapsed;
    if (showComposing) {
      boundaries
        ..add(composing.start)
        ..add(composing.end);
    }

    final sorted = boundaries.toList()..sort();
    final children = <InlineSpan>[];
    for (var index = 0; index + 1 < sorted.length; index++) {
      final start = sorted[index];
      final end = sorted[index + 1];
      if (start == end) continue;
      var segmentStyle = baseStyle;
      for (final annotationRange in annotationRanges) {
        if (start >= annotationRange.range.start &&
            end <= annotationRange.range.end) {
          segmentStyle = segmentStyle.merge(annotationRange.style);
          break;
        }
      }
      for (final badgeRange in badgeRanges) {
        if (start >= badgeRange.start && end <= badgeRange.end) {
          segmentStyle = baseStyle.copyWith(color: Colors.transparent);
          break;
        }
      }
      if (showComposing && start >= composing.start && end <= composing.end) {
        segmentStyle = segmentStyle.merge(
          const TextStyle(decoration: TextDecoration.underline),
        );
      }
      children.add(
        TextSpan(text: text.substring(start, end), style: segmentStyle),
      );
    }
    return TextSpan(style: baseStyle, children: children);
  }

  TextSpan _buildImeTextSpan({
    required TextStyle baseStyle,
    required bool withComposing,
  }) {
    final composing = value.composing;
    final showComposing =
        withComposing && composing.isValid && !composing.isCollapsed;
    final boundaries = <int>{0, text.length};
    if (showComposing) {
      boundaries
        ..add(composing.start.clamp(0, text.length))
        ..add(composing.end.clamp(0, text.length));
    }
    for (var offset = 0; offset < text.length; offset++) {
      if (text.codeUnitAt(offset) ==
          inlineAnnotationPlaceholder.codeUnitAt(0)) {
        boundaries
          ..add(offset)
          ..add(offset + 1);
      }
    }

    final sorted = boundaries.toList()..sort();
    final children = <InlineSpan>[];
    for (var index = 0; index + 1 < sorted.length; index++) {
      final start = sorted[index];
      final end = sorted[index + 1];
      if (start == end) continue;
      var segmentStyle = baseStyle;
      if (text.codeUnitAt(start) == inlineAnnotationPlaceholder.codeUnitAt(0)) {
        segmentStyle = segmentStyle.copyWith(color: Colors.transparent);
      } else if (showComposing &&
          start >= composing.start &&
          end <= composing.end) {
        segmentStyle = segmentStyle.merge(
          const TextStyle(decoration: TextDecoration.underline),
        );
      }
      children.add(
        TextSpan(text: text.substring(start, end), style: segmentStyle),
      );
    }
    return TextSpan(style: baseStyle, children: children);
  }

  TextRange _displayTextRange(ProjectedInlineAnnotation entry) {
    return entry.isExpanded
        ? TextRange(
            start: _projection.rawOffsetToDisplay(
              entry.annotation.displayTextSourceRange.start,
            ),
            end: _projection.rawOffsetToDisplay(
              entry.annotation.displayTextSourceRange.end,
            ),
          )
        : entry.labelRange;
  }

  void setRawText(String rawText, {TextSelection? rawSelection}) {
    _clearCompositionSession();
    final nextRawSelection =
        rawSelection ?? TextSelection.collapsed(offset: rawText.length);
    if (rawText == _rawText) {
      _publishProjection(_projection.rawSelectionToDisplay(nextRawSelection));
      return;
    }

    final previousProjectedValue = super.value;
    _rawText = rawText;
    _rawRevision++;
    _rebuildProjection();
    _publishProjection(_projection.rawSelectionToDisplay(nextRawSelection));
    _notifyIfProjectionStayedEqual(previousProjectedValue);
  }

  void replaceRawRange(TextRange rawRange, String replacement) {
    final start = rawRange.start.clamp(0, _rawText.length);
    final end = rawRange.end.clamp(start, _rawText.length);
    final updated = _rawText.replaceRange(start, end, replacement);
    setRawText(
      updated,
      rawSelection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  /// Replaces one projected range without flattening an enclosing annotation.
  ///
  /// Whole-label deletion through the normal EditableText path intentionally
  /// removes the complete annotation. Search/replace uses this method because
  /// replacing a label should retain its UUID and metadata.
  void replaceDisplayRange(TextRange displayRange, String replacement) {
    final start = displayRange.start.clamp(0, displayText.length);
    final end = displayRange.end.clamp(start, displayText.length);
    var rawRange = _projection.displayRangeToRaw(
      TextRange(start: start, end: end),
    );
    for (final entry in _projection.projectedAnnotations) {
      if (!entry.isExpanded &&
          start >= entry.displayRange.start &&
          end <= entry.displayRange.end) {
        rawRange = TextRange(
          start: _projection.displayOffsetToRaw(
            start,
            affinity: MosaicOffsetAffinity.downstream,
          ),
          end: _projection.displayOffsetToRaw(
            end,
            affinity: MosaicOffsetAffinity.upstream,
          ),
        );
        break;
      }
    }
    final updatedRaw = _rawText.replaceRange(
      rawRange.start,
      rawRange.end,
      replacement,
    );
    setRawText(
      updatedRaw,
      rawSelection: TextSelection.collapsed(
        offset: rawRange.start + replacement.length,
      ),
    );
  }

  String? rawSyntaxAtSourceStart(int sourceStart) {
    for (final annotation in annotations) {
      if (annotation.sourceRange.start == sourceStart) {
        return _rawText.substring(
          annotation.sourceRange.start,
          annotation.sourceRange.end,
        );
      }
    }
    return null;
  }

  bool updateAnnotationDisplayText(int sourceStart, String displayText) {
    for (final annotation in annotations) {
      if (annotation.sourceRange.start != sourceStart) continue;
      final effectiveDisplayText = displayText.trim().isEmpty
          ? annotation.displayText
          : displayText;
      final encoded = InlineAnnotationSyntax.escape(effectiveDisplayText);
      final updated = _rawText.replaceRange(
        annotation.displayTextSourceRange.start,
        annotation.displayTextSourceRange.end,
        encoded,
      );
      setRawText(
        updated,
        rawSelection: TextSelection.collapsed(
          offset: annotation.displayTextSourceRange.start + encoded.length,
        ),
      );
      return true;
    }
    return false;
  }

  bool replaceAnnotationSyntax(int sourceStart, String rawSyntax) {
    final parsed = _parser.parse(rawSyntax);
    if (parsed.length != 1 ||
        parsed.single.sourceRange.start != 0 ||
        parsed.single.sourceRange.end != rawSyntax.length) {
      return false;
    }
    for (final annotation in annotations) {
      if (annotation.sourceRange.start != sourceStart) continue;
      var replacementSyntax = rawSyntax;
      var replacement = parsed.single;
      if (replacement.displayText.trim().isEmpty &&
          annotation.displayText.isNotEmpty) {
        try {
          replacementSyntax = InlineAnnotationSyntax.format(
            kind: replacement.kind,
            state: replacement.state,
            colors: replacement.colors,
            targetId: replacement.targetId,
            displayText: annotation.displayText,
            note: replacement.note,
          );
          replacement = _parser.parse(replacementSyntax).single;
        } on FormatException {
          return false;
        }
      }
      final updated = _rawText.replaceRange(
        annotation.sourceRange.start,
        annotation.sourceRange.end,
        replacementSyntax,
      );
      setRawText(
        updated,
        rawSelection: TextSelection.collapsed(
          offset: sourceStart + replacement.displayTextSourceRange.end,
        ),
      );
      return true;
    }
    return false;
  }

  bool relinkAnnotationTarget({
    required int sourceStart,
    required String targetId,
    required String displayText,
  }) {
    for (final annotation in annotations) {
      if (annotation.sourceRange.start != sourceStart ||
          annotation.kind == InlineAnnotationKind.emphasis) {
        continue;
      }
      try {
        final source = InlineAnnotationSyntax.format(
          kind: annotation.kind,
          state: annotation.state,
          colors: annotation.colors,
          targetId: targetId,
          displayText: displayText,
          note: annotation.note,
        );
        return replaceAnnotationSyntax(sourceStart, source);
      } on FormatException {
        return false;
      }
    }
    return false;
  }

  bool removeAnnotationKeepText(int sourceStart) {
    for (final annotation in annotations) {
      if (annotation.sourceRange.start != sourceStart) continue;
      final updated = _rawText.replaceRange(
        annotation.sourceRange.start,
        annotation.sourceRange.end,
        annotation.displayText,
      );
      setRawText(
        updated,
        rawSelection: TextSelection.collapsed(
          offset: annotation.sourceRange.start + annotation.displayText.length,
        ),
      );
      return true;
    }
    return false;
  }

  void collapseAnnotations() {
    // Mentions are always collapsed. Kept for callers created before the
    // atomic Mention interaction replaced inline syntax expansion.
  }

  int? atomicNavigationTarget(int displayOffset, int direction) {
    if (direction == 0) return null;
    for (final entry in _projection.projectedAnnotations) {
      if (entry.isExpanded) continue;
      if (direction < 0 &&
          displayOffset > entry.displayRange.start &&
          displayOffset <= entry.displayRange.end) {
        return entry.displayRange.start;
      }
      if (direction > 0 &&
          displayOffset >= entry.displayRange.start &&
          displayOffset < entry.displayRange.end) {
        return entry.displayRange.end;
      }
    }
    return null;
  }

  bool canDeleteAtomicAnnotationAt(
    int displayOffset, {
    required bool backward,
  }) {
    return _atomicAnnotationAt(displayOffset, backward: backward) != null;
  }

  bool deleteAtomicAnnotationAt(int displayOffset, {required bool backward}) {
    final entry = _atomicAnnotationAt(displayOffset, backward: backward);
    if (entry == null) return false;
    replaceRawRange(entry.annotation.sourceRange, "");
    return true;
  }

  ProjectedInlineAnnotation? _atomicAnnotationAt(
    int displayOffset, {
    required bool backward,
  }) {
    for (final entry in _projection.projectedAnnotations) {
      if (entry.isExpanded) continue;
      final matches = backward
          ? displayOffset > entry.displayRange.start &&
                displayOffset <= entry.displayRange.end
          : displayOffset >= entry.displayRange.start &&
                displayOffset < entry.displayRange.end;
      if (matches) return entry;
    }
    return null;
  }

  @override
  set value(TextEditingValue newValue) {
    if (!_ready || _publishing) {
      super.value = newValue;
      return;
    }

    final oldValue = super.value;
    if (_hasActiveComposition(newValue)) {
      _compositionBaseValue ??= oldValue.copyWith(composing: TextRange.empty);
      _compositionBaseProjection ??= _projection;
      _compositionBaseRawText ??= _rawText;
      _publishTransientImeValue(newValue);
      return;
    }
    if (_compositionBaseValue != null) {
      _commitImeComposition(newValue);
      return;
    }

    if (newValue.text == oldValue.text) {
      super.value = newValue;
      return;
    }

    final edit = _diff(oldValue.text, newValue.text);
    final rawRange = _projection.displayRangeToRaw(
      TextRange(start: edit.oldStart, end: edit.oldEnd),
    );
    final inserted = newValue.text.substring(edit.newStart, edit.newEnd);
    final updatedRaw = _rawText.replaceRange(
      rawRange.start,
      rawRange.end,
      inserted,
    );

    final rawSelection = newValue.selection.isValid
        ? TextSelection(
            baseOffset: _mapNewDisplayOffsetToRaw(
              newValue.selection.baseOffset,
              projection: _projection,
              edit: edit,
              replacedRawRange: rawRange,
              affinity:
                  newValue.selection.baseOffset <=
                      newValue.selection.extentOffset
                  ? MosaicOffsetAffinity.downstream
                  : MosaicOffsetAffinity.upstream,
            ),
            extentOffset: _mapNewDisplayOffsetToRaw(
              newValue.selection.extentOffset,
              projection: _projection,
              edit: edit,
              replacedRawRange: rawRange,
              affinity:
                  newValue.selection.baseOffset <=
                      newValue.selection.extentOffset
                  ? MosaicOffsetAffinity.upstream
                  : MosaicOffsetAffinity.downstream,
            ),
            affinity: newValue.selection.affinity,
            isDirectional: newValue.selection.isDirectional,
          )
        : TextSelection.collapsed(offset: rawRange.start + inserted.length);
    final composingRaw =
        newValue.composing.isValid && !newValue.composing.isCollapsed
        ? TextRange(
            start: _mapNewDisplayOffsetToRaw(
              newValue.composing.start,
              projection: _projection,
              edit: edit,
              replacedRawRange: rawRange,
              affinity: MosaicOffsetAffinity.downstream,
            ),
            end: _mapNewDisplayOffsetToRaw(
              newValue.composing.end,
              projection: _projection,
              edit: edit,
              replacedRawRange: rawRange,
              affinity: MosaicOffsetAffinity.upstream,
            ),
          )
        : TextRange.empty;

    _rawText = updatedRaw;
    _rawRevision++;
    _rebuildProjection(composingRawRange: composingRaw);
    _publishProjection(
      _projection.rawSelectionToDisplay(rawSelection),
      composingRawRange: composingRaw,
    );
    _notifyIfProjectionStayedEqual(oldValue);
  }

  void _commitImeComposition(TextEditingValue committedValue) {
    final baseValue = _compositionBaseValue!;
    final baseProjection = _compositionBaseProjection!;
    final baseRawText = _compositionBaseRawText!;
    final previousPublishedValue = super.value;
    final edit = _diff(baseValue.text, committedValue.text);
    final rawRange = baseProjection.displayRangeToRaw(
      TextRange(start: edit.oldStart, end: edit.oldEnd),
    );
    final inserted = committedValue.text.substring(edit.newStart, edit.newEnd);
    final updatedRaw = baseRawText.replaceRange(
      rawRange.start,
      rawRange.end,
      inserted,
    );
    final rawSelection = committedValue.selection.isValid
        ? TextSelection(
            baseOffset: _mapNewDisplayOffsetToRaw(
              committedValue.selection.baseOffset,
              projection: baseProjection,
              edit: edit,
              replacedRawRange: rawRange,
              affinity:
                  committedValue.selection.baseOffset <=
                      committedValue.selection.extentOffset
                  ? MosaicOffsetAffinity.downstream
                  : MosaicOffsetAffinity.upstream,
            ),
            extentOffset: _mapNewDisplayOffsetToRaw(
              committedValue.selection.extentOffset,
              projection: baseProjection,
              edit: edit,
              replacedRawRange: rawRange,
              affinity:
                  committedValue.selection.baseOffset <=
                      committedValue.selection.extentOffset
                  ? MosaicOffsetAffinity.upstream
                  : MosaicOffsetAffinity.downstream,
            ),
            affinity: committedValue.selection.affinity,
            isDirectional: committedValue.selection.isDirectional,
          )
        : TextSelection.collapsed(offset: rawRange.start + inserted.length);

    _clearCompositionSession();
    if (_rawText != updatedRaw) {
      _rawText = updatedRaw;
      _rawRevision++;
    }
    _rebuildProjection();
    _publishProjection(_projection.rawSelectionToDisplay(rawSelection));
    _notifyIfProjectionStayedEqual(previousPublishedValue);
  }

  void _publishTransientImeValue(TextEditingValue value) {
    _publishing = true;
    try {
      applyProjectedValue(value);
    } finally {
      _publishing = false;
    }
  }

  static bool _hasActiveComposition(TextEditingValue value) =>
      value.composing.isValid && !value.composing.isCollapsed;

  void _clearCompositionSession() {
    _compositionBaseValue = null;
    _compositionBaseProjection = null;
    _compositionBaseRawText = null;
  }

  void _notifyIfProjectionStayedEqual(TextEditingValue previousValue) {
    // TextEditingController only notifies when its public value changes. Raw
    // edits such as the second character of `\\` can be immediately folded by
    // the projection into the same display value. Raw-aware listeners (Poppin,
    // persistence and collaboration) still need that notification.
    if (super.value == previousValue) notifyListeners();
  }

  void _rebuildProjection({TextRange composingRawRange = TextRange.empty}) {
    _projection = InlineAnnotationProjection.build(
      _rawText,
      parser: _parser,
      composingRawRange: composingRawRange,
    );
  }

  int _mapNewDisplayOffsetToRaw(
    int newOffset, {
    required InlineAnnotationProjection projection,
    required _DisplayEdit edit,
    required TextRange replacedRawRange,
    required MosaicOffsetAffinity affinity,
  }) {
    if (newOffset < edit.newStart) {
      return projection.displayOffsetToRaw(newOffset, affinity: affinity);
    }
    if (newOffset <= edit.newEnd) {
      return replacedRawRange.start + (newOffset - edit.newStart);
    }
    final oldOffset = edit.oldEnd + (newOffset - edit.newEnd);
    final oldRawOffset = projection.displayOffsetToRaw(
      oldOffset,
      affinity: affinity,
    );
    return oldRawOffset +
        (replacedRawRange.start +
            (edit.newEnd - edit.newStart) -
            replacedRawRange.end);
  }

  void _publishProjection(
    TextSelection displaySelection, {
    TextRange composingRawRange = TextRange.empty,
  }) {
    _publishing = true;
    try {
      applyProjectedValue(
        TextEditingValue(
          text: _projection.displayText,
          selection: displaySelection,
          composing: composingRawRange.isValid && !composingRawRange.isCollapsed
              ? TextRange(
                  start: _projection.rawOffsetToDisplay(
                    composingRawRange.start,
                  ),
                  end: _projection.rawOffsetToDisplay(composingRawRange.end),
                )
              : TextRange.empty,
        ),
      );
    } finally {
      _publishing = false;
    }
  }

  @protected
  void applyProjectedValue(TextEditingValue projectedValue) {
    super.value = projectedValue;
  }

  static _DisplayEdit _diff(String oldText, String newText) {
    var prefix = 0;
    final commonLength = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    while (prefix < commonLength &&
        oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
      prefix++;
    }

    var oldSuffix = oldText.length;
    var newSuffix = newText.length;
    while (oldSuffix > prefix &&
        newSuffix > prefix &&
        oldText.codeUnitAt(oldSuffix - 1) ==
            newText.codeUnitAt(newSuffix - 1)) {
      oldSuffix--;
      newSuffix--;
    }
    return _DisplayEdit(
      oldStart: prefix,
      oldEnd: oldSuffix,
      newStart: prefix,
      newEnd: newSuffix,
    );
  }
}

@immutable
final class MosaicStyleRange {
  final TextRange range;
  final TextStyle style;

  const MosaicStyleRange({required this.range, required this.style});
}

final class _DisplayEdit {
  final int oldStart;
  final int oldEnd;
  final int newStart;
  final int newEnd;

  const _DisplayEdit({
    required this.oldStart,
    required this.oldEnd,
    required this.newStart,
    required this.newEnd,
  });
}
