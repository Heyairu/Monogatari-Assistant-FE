import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "collections.dart";
import "forms.dart";

/// A consistent two-column table surface for compact editor data.
///
/// Rows can be read-only, selectable, or contain form controls. Use
/// [AppTwoColumnTableRow] for the standard cell layout.
class AppTwoColumnTable extends StatelessWidget {
  final String firstHeader;
  final String secondHeader;
  final List<Widget> rows;
  final Widget? emptyState;
  final int firstFlex;
  final int secondFlex;
  final double? bodyHeight;
  final EdgeInsetsGeometry headerPadding;
  final TextStyle? headerStyle;
  final Color? headerColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final bool hasTrailingColumn;
  final double trailingColumnWidth;
  final ScrollController? controller;
  final bool showScrollbar;
  final VoidCallback? onSelectionCleared;

  const AppTwoColumnTable({
    super.key,
    required this.firstHeader,
    required this.secondHeader,
    required this.rows,
    this.emptyState,
    this.firstFlex = 1,
    this.secondFlex = 1,
    this.bodyHeight,
    this.headerPadding = const EdgeInsets.all(12),
    this.headerStyle,
    this.headerColor,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 4,
    this.hasTrailingColumn = false,
    this.trailingColumnWidth = 48,
    this.controller,
    this.showScrollbar = false,
    this.onSelectionCleared,
  }) : assert(firstFlex > 0),
       assert(secondFlex > 0),
       assert(bodyHeight == null || bodyHeight > 0),
       assert(borderRadius >= 0),
       assert(trailingColumnWidth > 0),
       assert(
         !showScrollbar || controller != null,
         "A controller is required when showScrollbar is true.",
       );

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedStyle =
        headerStyle ??
        theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        );

    return ColoredBox(
      color: headerColor ?? theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: headerPadding,
        child: Row(
          children: [
            Expanded(
              flex: firstFlex,
              child: Text(firstHeader, style: resolvedStyle),
            ),
            Expanded(
              flex: secondFlex,
              child: Text(secondHeader, style: resolvedStyle),
            ),
            if (hasTrailingColumn) SizedBox(width: trailingColumnWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (rows.isEmpty) {
      final empty = emptyState ?? const SizedBox.shrink();
      final body = bodyHeight == null
          ? empty
          : SizedBox(height: bodyHeight, child: empty);
      return onSelectionCleared == null
          ? body
          : GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: onSelectionCleared,
              child: body,
            );
    }

    if (bodyHeight == null) {
      return Column(mainAxisSize: MainAxisSize.min, children: rows);
    }

    final list = ListView.builder(
      controller: controller,
      primary: false,
      padding: EdgeInsets.zero,
      itemCount: rows.length,
      itemBuilder: (context, index) => rows[index],
    );

    final body = SizedBox(
      height: bodyHeight,
      child: showScrollbar
          ? Scrollbar(controller: controller, child: list)
          : list,
    );
    return onSelectionCleared == null
        ? body
        : GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onSelectionCleared,
            child: body,
          );
  }

  @override
  Widget build(BuildContext context) {
    final table = Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor ?? Colors.grey.shade300),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_buildHeader(context), _buildBody()],
      ),
    );
    if (onSelectionCleared == null) return table;

    return Focus(
      onKeyEvent: (node, event) {
        if (node.hasPrimaryFocus &&
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          onSelectionCleared!.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) => Listener(
          onPointerDown: (_) => Focus.of(context).requestFocus(),
          child: table,
        ),
      ),
    );
  }
}

/// Standard row layout for [AppTwoColumnTable].
class AppTwoColumnTableRow extends StatelessWidget {
  final Widget firstCell;
  final Widget secondCell;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final int firstFlex;
  final int secondFlex;
  final EdgeInsetsGeometry cellPadding;
  final double trailingColumnWidth;
  final Color? selectedColor;
  final Color? backgroundColor;
  final Color? dividerColor;
  final bool showDivider;
  final CrossAxisAlignment crossAxisAlignment;

  const AppTwoColumnTableRow({
    super.key,
    required this.firstCell,
    required this.secondCell,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.firstFlex = 1,
    this.secondFlex = 1,
    this.cellPadding = const EdgeInsets.all(12),
    this.trailingColumnWidth = 48,
    this.selectedColor,
    this.backgroundColor,
    this.dividerColor,
    this.showDivider = true,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  }) : assert(firstFlex > 0),
       assert(secondFlex > 0),
       assert(trailingColumnWidth > 0);

  @override
  Widget build(BuildContext context) {
    final resolvedColor = selected
        ? selectedColor ?? Theme.of(context).primaryColor.withValues(alpha: 0.1)
        : backgroundColor ?? Colors.transparent;

    final content = Container(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(color: dividerColor ?? Colors.grey.shade300),
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Expanded(
            flex: firstFlex,
            child: Padding(padding: cellPadding, child: firstCell),
          ),
          Expanded(
            flex: secondFlex,
            child: Padding(padding: cellPadding, child: secondCell),
          ),
          if (trailing != null)
            SizedBox(
              width: trailingColumnWidth,
              child: Center(child: trailing),
            ),
        ],
      ),
    );

    return Material(
      color: resolvedColor,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// A table cell that switches to a text field with a single click.
///
/// Press Enter or click outside the field to save. Escape cancels the edit.
class AppEditableTableCell extends StatefulWidget {
  final String value;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onEditStarted;
  final VoidCallback? onEditCanceled;
  final bool selected;
  final String emptyText;
  final String? hintText;
  final TextStyle? style;
  final int maxLines;
  final TextAlign textAlign;

  const AppEditableTableCell({
    super.key,
    required this.value,
    required this.onSubmitted,
    this.onEditStarted,
    this.onEditCanceled,
    this.selected = false,
    this.emptyText = "（空白）",
    this.hintText,
    this.style,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
  }) : assert(maxLines > 0);

  @override
  State<AppEditableTableCell> createState() => _AppEditableTableCellState();
}

class _AppEditableTableCellState extends State<AppEditableTableCell> {
  late final TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(AppEditableTableCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected && !widget.selected) {
      _isEditing = false;
      _controller.text = widget.value;
    }
    if (!_isEditing && widget.value != oldWidget.value) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startEditing() {
    _controller.value = TextEditingValue(
      text: widget.value,
      selection: TextSelection(
        baseOffset: 0,
        extentOffset: widget.value.length,
      ),
    );
    widget.onEditStarted?.call();
    setState(() => _isEditing = true);
  }

  void _submit(String value) {
    if (!_isEditing) return;
    setState(() => _isEditing = false);
    widget.onSubmitted(value);
  }

  void _cancel() {
    _controller.text = widget.value;
    setState(() => _isEditing = false);
    widget.onEditCanceled?.call();
  }

  @override
  Widget build(BuildContext context) {
    return InlineEditableText(
      value: widget.value,
      controller: _controller,
      isEditing: _isEditing,
      onEdit: _startEditing,
      onSubmitted: _submit,
      onCanceled: _cancel,
      onTapOutside: (_) => _submit(_controller.text),
      emptyText: widget.emptyText,
      hintText: widget.hintText,
      style: widget.style,
      maxLines: widget.maxLines,
      editOnTap: true,
      showActions: widget.maxLines > 1,
      textAlign: widget.textAlign,
    );
  }
}

typedef AppTwoColumnTableSubmit =
    void Function(String firstValue, String secondValue);
typedef AppTwoColumnTableValidator =
    bool Function(String firstValue, String secondValue);
typedef AppTwoColumnTableFieldBuilder =
    Widget Function(BuildContext context, TextEditingController controller);

/// Shared add/update editor for [AppTwoColumnTable].
///
/// The selected table row remains read-only. Its values are loaded into this
/// editor, where the primary action changes from add to update and the delete
/// action becomes available.
class AppTwoColumnTableEditor extends StatelessWidget {
  final TextEditingController firstController;
  final TextEditingController secondController;
  final String firstLabel;
  final String secondLabel;
  final String? firstHint;
  final String? secondHint;
  final bool isEditing;
  final AppTwoColumnTableSubmit onSubmit;
  final VoidCallback? onDelete;
  final AppTwoColumnTableValidator? canSubmit;
  final String addTooltip;
  final String updateTooltip;
  final String deleteTooltip;
  final int secondFieldMaxLines;
  final AppTwoColumnTableFieldBuilder? firstFieldBuilder;

  const AppTwoColumnTableEditor({
    super.key,
    required this.firstController,
    required this.secondController,
    required this.firstLabel,
    required this.secondLabel,
    required this.isEditing,
    required this.onSubmit,
    this.onDelete,
    this.canSubmit,
    this.firstHint,
    this.secondHint,
    this.addTooltip = "新增",
    this.updateTooltip = "更新",
    this.deleteTooltip = "刪除",
    this.secondFieldMaxLines = 1,
    this.firstFieldBuilder,
  }) : assert(secondFieldMaxLines > 0);

  bool _canSubmit() {
    final firstValue = firstController.text;
    final secondValue = secondController.text;
    return canSubmit?.call(firstValue, secondValue) ??
        (firstValue.trim().isNotEmpty && secondValue.trim().isNotEmpty);
  }

  void _submit() {
    if (_canSubmit()) {
      onSubmit(firstController.text, secondController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([firstController, secondController]),
      builder: (context, child) {
        final submitEnabled = _canSubmit();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child:
                      firstFieldBuilder?.call(context, firstController) ??
                      AppTextField(
                        controller: firstController,
                        labelText: firstLabel,
                        hintText: firstHint,
                        textInputAction: TextInputAction.next,
                      ),
                ),
                const SizedBox(width: 8),
                ItemActionBar(
                  actions: [
                    ItemAction.edit(
                      icon: isEditing ? Icons.save_outlined : Icons.add,
                      tooltip: isEditing ? updateTooltip : addTooltip,
                      onPressed: submitEnabled ? _submit : null,
                    ),
                    ItemAction.delete(
                      tooltip: deleteTooltip,
                      onPressed: isEditing ? onDelete : null,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            AppTextField(
              controller: secondController,
              labelText: secondLabel,
              hintText: secondHint,
              maxLines: secondFieldMaxLines,
              textInputAction: secondFieldMaxLines == 1
                  ? TextInputAction.done
                  : TextInputAction.newline,
              onSubmitted: secondFieldMaxLines == 1 ? (_) => _submit() : null,
            ),
          ],
        );
      },
    );
  }
}
