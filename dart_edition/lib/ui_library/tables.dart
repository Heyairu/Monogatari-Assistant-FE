import "package:flutter/material.dart";

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
      return bodyHeight == null
          ? empty
          : SizedBox(height: bodyHeight, child: empty);
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

    return SizedBox(
      height: bodyHeight,
      child: showScrollbar
          ? Scrollbar(controller: controller, child: list)
          : list,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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

typedef AppTwoColumnTableSubmit =
    void Function(String firstValue, String secondValue);
typedef AppTwoColumnTableValidator =
    bool Function(String firstValue, String secondValue);

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
  final EdgeInsetsGeometry fieldContentPadding;
  final int secondFieldMaxLines;

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
    this.fieldContentPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 8,
    ),
    this.secondFieldMaxLines = 1,
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
                  child: AppTextField(
                    controller: firstController,
                    labelText: firstLabel,
                    hintText: firstHint,
                    textInputAction: TextInputAction.next,
                    contentPadding: fieldContentPadding,
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
              contentPadding: fieldContentPadding,
              onSubmitted: secondFieldMaxLines == 1 ? (_) => _submit() : null,
            ),
          ],
        );
      },
    );
  }
}
