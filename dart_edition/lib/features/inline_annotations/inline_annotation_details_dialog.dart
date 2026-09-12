import "package:flutter/material.dart";

import "inline_annotation.dart";
import "inline_annotation_anchored_popup.dart";
import "inline_annotation_parser.dart";
import "inline_annotation_syntax.dart";
import "inline_annotation_target_resolver.dart";

enum InlineAnnotationDetailsAction {
  applyDisplayText,
  applySyntax,
  editAnnotation,
  navigateToTarget,
  relinkTarget,
  copySyntax,
  updateToPrimaryName,
  removeKeepText,
}

final class InlineAnnotationDetailsResult {
  final InlineAnnotationDetailsAction action;
  final String? displayText;
  final String? rawSyntax;

  const InlineAnnotationDetailsResult(
    this.action, {
    this.displayText,
    this.rawSyntax,
  });
}

abstract final class InlineAnnotationDetailsDialog {
  static Future<InlineAnnotationDetailsResult?> show({
    required BuildContext context,
    required InlineAnnotation annotation,
    required String rawSyntax,
    InlineAnnotationTargetInfo? target,
    Rect? anchor,
  }) {
    return InlineAnnotationAnchoredPopup.show<InlineAnnotationDetailsResult>(
      context: context,
      anchor: anchor,
      width: 320,
      builder: (_) => _InlineAnnotationQuickEditor(
        annotation: annotation,
        rawSyntax: rawSyntax,
        target: target,
      ),
    );
  }
}

class _InlineAnnotationQuickEditor extends StatefulWidget {
  final InlineAnnotation annotation;
  final String rawSyntax;
  final InlineAnnotationTargetInfo? target;

  const _InlineAnnotationQuickEditor({
    required this.annotation,
    required this.rawSyntax,
    required this.target,
  });

  @override
  State<_InlineAnnotationQuickEditor> createState() =>
      _InlineAnnotationQuickEditorState();
}

class _InlineAnnotationQuickEditorState
    extends State<_InlineAnnotationQuickEditor> {
  late final TextEditingController _displayController;
  late final TextEditingController _rawSyntaxController;
  late final TextEditingController _noteController;
  String? _syntaxError;

  @override
  void initState() {
    super.initState();
    _displayController = TextEditingController(
      text: widget.annotation.displayText,
    );
    _rawSyntaxController = TextEditingController(text: widget.rawSyntax);
    _noteController = TextEditingController(text: widget.annotation.note ?? "");
  }

  @override
  void dispose() {
    _displayController.dispose();
    _rawSyntaxController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _apply() {
    if (_noteController.text != (widget.annotation.note ?? "")) {
      final parsed = const InlineAnnotationParser().parse(
        _rawSyntaxController.text,
      );
      if (parsed.length != 1 ||
          parsed.single.sourceRange.end != _rawSyntaxController.text.length ||
          parsed.single.sourceRange.start != 0) {
        setState(() => _syntaxError = "完整語法無效，請修正後再套用。");
        return;
      }
      final annotation = parsed.single;
      _rawSyntaxController.text = InlineAnnotationSyntax.format(
        kind: annotation.kind,
        state: annotation.state,
        colors: annotation.colors,
        targetId: annotation.targetId,
        displayText: _displayController.text.trim().isEmpty
            ? widget.annotation.displayText
            : _displayController.text,
        note: _noteController.text,
      );
    }
    final rawSyntax = _rawSyntaxController.text;
    if (rawSyntax != widget.rawSyntax) {
      final parsed = const InlineAnnotationParser().parse(rawSyntax);
      if (parsed.length != 1 ||
          parsed.single.sourceRange.start != 0 ||
          parsed.single.sourceRange.end != rawSyntax.length) {
        setState(() => _syntaxError = "完整語法無效，請修正後再套用。");
        return;
      }
      Navigator.of(context).pop(
        InlineAnnotationDetailsResult(
          InlineAnnotationDetailsAction.applySyntax,
          rawSyntax: rawSyntax,
        ),
      );
      return;
    }
    final entered = _displayController.text;
    Navigator.of(context).pop(
      InlineAnnotationDetailsResult(
        InlineAnnotationDetailsAction.applyDisplayText,
        displayText: entered.trim().isEmpty
            ? widget.annotation.displayText
            : entered,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey("inline-annotation-quick-editor"),
      elevation: 10,
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.alternate_email, size: 18, color: colors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Mention",
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: "關閉",
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              _buildDisplayField(),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey("inline-annotation-note"),
                controller: _noteController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "備註",
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                key: const ValueKey("inline-annotation-basic-info"),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    _InfoRow(
                      label: "類型",
                      value: _kindLabel(widget.annotation.kind),
                    ),
                    _InfoRow(
                      label: "對象",
                      value:
                          widget.target?.primaryName ??
                          (widget.annotation.targetId == null
                              ? "不適用"
                              : "遺失的對象"),
                    ),
                    if (widget.annotation.targetId case final targetId?)
                      _InfoRow(label: "UUID", value: targetId),
                    _InfoRow(
                      label: "狀態",
                      value: _stateLabel(widget.annotation.state),
                    ),
                    _InfoRow(
                      label: "色彩",
                      value:
                          "${widget.annotation.colors.background}${widget.annotation.colors.foreground}",
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildSyntaxField(context),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                runSpacing: 4,
                spacing: 8,
                children: [
                  if (widget.target != null)
                    TextButton.icon(
                      key: const ValueKey("inline-annotation-open-target"),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => Navigator.of(context).pop(
                        const InlineAnnotationDetailsResult(
                          InlineAnnotationDetailsAction.navigateToTarget,
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text("開啟節點"),
                    ),
                  _buildMoreMenu(),
                  OutlinedButton.icon(
                    key: const ValueKey("inline-annotation-edit"),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => Navigator.of(context).pop(
                      const InlineAnnotationDetailsResult(
                        InlineAnnotationDetailsAction.editAnnotation,
                      ),
                    ),
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text("編輯標記"),
                  ),
                  FilledButton(
                    key: const ValueKey("inline-annotation-quick-apply"),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _apply,
                    child: const Text("套用"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreMenu() {
    final canRelink =
        widget.target == null && widget.annotation.targetId != null;
    final canUpdateName =
        widget.target != null &&
        widget.target!.primaryName != widget.annotation.displayText;
    return PopupMenuButton<InlineAnnotationDetailsAction>(
      key: const ValueKey("inline-annotation-more"),
      tooltip: "更多標記操作",
      onSelected: (action) =>
          Navigator.of(context).pop(InlineAnnotationDetailsResult(action)),
      itemBuilder: (_) => [
        if (canUpdateName)
          const PopupMenuItem(
            key: ValueKey("inline-annotation-update-name"),
            value: InlineAnnotationDetailsAction.updateToPrimaryName,
            child: _AnnotationMenuLabel(
              icon: Icons.drive_file_rename_outline,
              label: "更新為目前名稱",
            ),
          ),
        if (canRelink)
          const PopupMenuItem(
            key: ValueKey("inline-annotation-relink"),
            value: InlineAnnotationDetailsAction.relinkTarget,
            child: _AnnotationMenuLabel(
              icon: Icons.add_link,
              label: "重新連結遺失對象",
            ),
          ),
        const PopupMenuItem(
          key: ValueKey("inline-annotation-remove-keep-text"),
          value: InlineAnnotationDetailsAction.removeKeepText,
          child: _AnnotationMenuLabel(icon: Icons.link_off, label: "移除標記但保留文字"),
        ),
      ],
      icon: const Icon(Icons.more_horiz, size: 18),
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

  Widget _buildDisplayField() {
    return TextField(
      key: const ValueKey("inline-annotation-quick-display-text"),
      controller: _displayController,
      autofocus: true,
      decoration: const InputDecoration(
        labelText: "顯示文字",
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _apply(),
    );
  }

  Widget _buildSyntaxField(BuildContext context) {
    return TextField(
      key: const ValueKey("inline-annotation-quick-syntax"),
      controller: _rawSyntaxController,
      maxLines: 1,
      autocorrect: false,
      enableSuggestions: false,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(fontFamily: "monospace", fontSize: 11),
      decoration: InputDecoration(
        labelText: "完整語法",
        errorText: _syntaxError,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        suffixIcon: IconButton(
          key: const ValueKey("inline-annotation-copy-syntax"),
          tooltip: "複製語法",
          visualDensity: VisualDensity.compact,
          onPressed: () => Navigator.of(context).pop(
            InlineAnnotationDetailsResult(
              InlineAnnotationDetailsAction.copySyntax,
              rawSyntax: _rawSyntaxController.text,
            ),
          ),
          icon: const Icon(Icons.copy_outlined, size: 16),
        ),
      ),
      onChanged: (_) {
        if (_syntaxError != null) setState(() => _syntaxError = null);
      },
    );
  }

  String _stateLabel(InlineAnnotationState state) => switch (state) {
    InlineAnnotationState.none => "一般",
    InlineAnnotationState.start => "開始",
    InlineAnnotationState.end => "結束",
  };
}

class _AnnotationMenuLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AnnotationMenuLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 10), Text(label)],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Text(
              label,
              style: style?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: style)),
        ],
      ),
    );
  }
}
