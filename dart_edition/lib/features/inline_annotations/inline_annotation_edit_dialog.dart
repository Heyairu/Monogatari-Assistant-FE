import "package:flutter/material.dart";

import "../../ui_library/dialogs.dart";
import "inline_annotation.dart";
import "inline_annotation_anchored_popup.dart";
import "inline_annotation_parser.dart";
import "inline_annotation_syntax.dart";

abstract final class InlineAnnotationEditDialog {
  static Future<String?> show({
    required BuildContext context,
    required InlineAnnotation annotation,
    String? rawSyntax,
    Rect? anchor,
  }) {
    return InlineAnnotationAnchoredPopup.show<String>(
      context: context,
      anchor: anchor,
      width: 460,
      barrierDismissible: false,
      builder: (_) => _InlineAnnotationEditForm(
        annotation: annotation,
        rawSyntax: rawSyntax,
        anchored: anchor != null,
      ),
    );
  }
}

class _InlineAnnotationEditForm extends StatefulWidget {
  final InlineAnnotation annotation;
  final String? rawSyntax;
  final bool anchored;

  const _InlineAnnotationEditForm({
    required this.annotation,
    required this.rawSyntax,
    required this.anchored,
  });

  @override
  State<_InlineAnnotationEditForm> createState() =>
      _InlineAnnotationEditFormState();
}

class _InlineAnnotationEditFormState extends State<_InlineAnnotationEditForm> {
  late InlineAnnotationKind _kind;
  late InlineAnnotationState _annotationState;
  late String _background;
  late String _foreground;
  late final TextEditingController _targetController;
  late final TextEditingController _displayController;
  late final TextEditingController _noteController;
  late final TextEditingController _rawSyntaxController;
  late final String _initialRawSyntax;
  String? _errorText;

  static const _colorCodes = <String>["0", "A", "B", "C", "D", "E", "F"];

  @override
  void initState() {
    super.initState();
    final annotation = widget.annotation;
    _kind = annotation.kind;
    _annotationState = annotation.state;
    _background = annotation.colors.background;
    _foreground = annotation.colors.foreground;
    _targetController = TextEditingController(text: annotation.targetId ?? "");
    _displayController = TextEditingController(text: annotation.displayText);
    _noteController = TextEditingController(text: annotation.note ?? "");
    _initialRawSyntax =
        widget.rawSyntax ??
        InlineAnnotationSyntax.format(
          kind: annotation.kind,
          state: annotation.state,
          colors: annotation.colors,
          targetId: annotation.targetId,
          displayText: annotation.displayText,
          note: annotation.note,
        );
    _rawSyntaxController = TextEditingController(text: _initialRawSyntax);
  }

  @override
  void dispose() {
    _targetController.dispose();
    _displayController.dispose();
    _noteController.dispose();
    _rawSyntaxController.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      if (_rawSyntaxController.text != _initialRawSyntax) {
        final source = _rawSyntaxController.text;
        final parsed = const InlineAnnotationParser().parse(source);
        if (parsed.length != 1 ||
            parsed.single.sourceRange.start != 0 ||
            parsed.single.sourceRange.end != source.length) {
          throw const FormatException("完整語法無效");
        }
        Navigator.of(context).pop(source);
        return;
      }
      final enteredDisplayText = _displayController.text;
      final source = InlineAnnotationSyntax.format(
        kind: _kind,
        state: _kind == InlineAnnotationKind.emphasis
            ? InlineAnnotationState.none
            : _annotationState,
        colors: InlineAnnotationColorCode(
          background: _background,
          foreground: _foreground,
        ),
        targetId: _kind == InlineAnnotationKind.emphasis
            ? null
            : _targetController.text.trim(),
        displayText: enteredDisplayText.trim().isEmpty
            ? widget.annotation.displayText
            : enteredDisplayText,
        note: _noteController.text,
      );
      Navigator.of(context).pop(source);
    } on FormatException catch (error) {
      setState(() => _errorText = _formatError(error));
    }
  }

  String _formatError(FormatException error) {
    if (_kind != InlineAnnotationKind.emphasis &&
        _targetController.text.trim().isEmpty) {
      return "此標記類型需要 UUID。";
    }
    return "標記資料無效：${error.message}";
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: "編輯標記",
      icon: Icons.edit_note_outlined,
      scrollable: true,
      maxWidth: 440,
      insetPadding: widget.anchored
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      content: SizedBox(
        width: 408,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<InlineAnnotationKind>(
              key: const ValueKey("inline-annotation-kind"),
              initialValue: _kind,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: _decoration("類型"),
              items: [
                for (final kind in InlineAnnotationKind.values)
                  DropdownMenuItem(value: kind, child: Text(_kindLabel(kind))),
              ],
              onChanged: (kind) {
                if (kind == null) return;
                setState(() {
                  _kind = kind;
                  if (kind == InlineAnnotationKind.emphasis) {
                    _annotationState = InlineAnnotationState.none;
                  }
                  _errorText = null;
                });
              },
            ),
            const SizedBox(height: 8),
            if (_kind != InlineAnnotationKind.emphasis) ...[
              DropdownButtonFormField<InlineAnnotationState>(
                key: const ValueKey("inline-annotation-state"),
                initialValue: _annotationState,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: _decoration("狀態"),
                items: [
                  for (final state in InlineAnnotationState.values)
                    DropdownMenuItem(
                      value: state,
                      child: Text(_stateLabel(state)),
                    ),
                ],
                onChanged: (state) {
                  if (state != null) setState(() => _annotationState = state);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey("inline-annotation-target"),
                controller: _targetController,
                decoration: _decoration("UUID"),
                autocorrect: false,
                enableSuggestions: false,
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              key: const ValueKey("inline-annotation-display-text"),
              controller: _displayController,
              decoration: _decoration("顯示文字"),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: const ValueKey("inline-annotation-background"),
                    initialValue: _background,
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: _decoration("背景色碼"),
                    items: _colorItems,
                    onChanged: (value) {
                      if (value != null) setState(() => _background = value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: const ValueKey("inline-annotation-foreground"),
                    initialValue: _foreground,
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: _decoration("文字色碼"),
                    items: _colorItems,
                    onChanged: (value) {
                      if (value != null) setState(() => _foreground = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey("inline-annotation-note"),
              controller: _noteController,
              decoration: _decoration("備註（可留空）"),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey("inline-annotation-raw-syntax-editor"),
              controller: _rawSyntaxController,
              decoration: _decoration("完整語法", helperText: "直接修改此欄會優先套用完整語法。"),
              minLines: 2,
              maxLines: 4,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(fontFamily: "monospace"),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorText!,
                  key: const ValueKey("inline-annotation-edit-error"),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("取消"),
        ),
        FilledButton(
          key: const ValueKey("inline-annotation-save"),
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
          onPressed: _submit,
          child: const Text("儲存"),
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> get _colorItems => [
    for (final code in _colorCodes)
      DropdownMenuItem(value: code, child: Text(code == "0" ? "0（自動）" : code)),
  ];

  InputDecoration _decoration(String label, {String? helperText}) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );
  }

  static String _kindLabel(InlineAnnotationKind kind) => switch (kind) {
    InlineAnnotationKind.character => "人物",
    InlineAnnotationKind.location => "地點",
    InlineAnnotationKind.event => "事件",
    InlineAnnotationKind.foreshadowing => "伏筆",
    InlineAnnotationKind.plan => "計畫",
    InlineAnnotationKind.emphasis => "高亮",
  };

  static String _stateLabel(InlineAnnotationState state) => switch (state) {
    InlineAnnotationState.none => "一般",
    InlineAnnotationState.start => "開始",
    InlineAnnotationState.end => "結束",
  };
}
