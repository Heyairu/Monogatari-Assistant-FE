import "package:flutter/material.dart";

import "feedback.dart";
import "layout.dart";

@immutable
class ItemAction {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final AppFeedbackTone tone;
  final Color? color;

  const ItemAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.tone = AppFeedbackTone.neutral,
    this.color,
  });

  const ItemAction.edit({
    required this.onPressed,
    this.tooltip = "重新命名",
    this.icon = Icons.edit_outlined,
    this.color,
  }) : tone = AppFeedbackTone.info;

  const ItemAction.delete({
    required this.onPressed,
    this.tooltip = "刪除",
    this.icon = Icons.delete_outline,
    this.color,
  }) : tone = AppFeedbackTone.error;
}

/// Compact and consistently styled row of per-item actions.
class ItemActionBar extends StatelessWidget {
  final List<ItemAction> actions;
  final double iconSize;
  final VisualDensity visualDensity;
  final MainAxisAlignment alignment;

  const ItemActionBar({
    super.key,
    required this.actions,
    this.iconSize = 20,
    this.visualDensity = VisualDensity.compact,
    this.alignment = MainAxisAlignment.end,
  }) : assert(iconSize > 0);

  ItemActionBar.editDelete({
    super.key,
    required VoidCallback? onEdit,
    required VoidCallback? onDelete,
    String editTooltip = "重新命名",
    String deleteTooltip = "刪除",
    this.iconSize = 20,
    this.visualDensity = VisualDensity.compact,
    this.alignment = MainAxisAlignment.end,
  }) : actions = [
         ItemAction.edit(onPressed: onEdit, tooltip: editTooltip),
         ItemAction.delete(onPressed: onDelete, tooltip: deleteTooltip),
       ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      children: actions.map((action) {
        final semanticColor = switch (action.tone) {
          AppFeedbackTone.error => scheme.error,
          AppFeedbackTone.warning => scheme.secondary,
          AppFeedbackTone.success => scheme.tertiary,
          AppFeedbackTone.info => scheme.primary,
          AppFeedbackTone.neutral => scheme.onSurfaceVariant,
        };

        return IconButton(
          tooltip: action.tooltip,
          visualDensity: visualDensity,
          onPressed: action.onPressed,
          color: action.color ?? semanticColor,
          iconSize: iconSize,
          icon: Icon(action.icon),
        );
      }).toList(),
    );
  }
}

/// A titled, bounded list surface with a standard empty state.
class CollectionPanel extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<Widget> actions;
  final List<Widget>? children;
  final Widget? content;
  final int? itemCount;
  final IndexedWidgetBuilder? itemBuilder;
  final IndexedWidgetBuilder? separatorBuilder;
  final Widget? emptyState;
  final String emptyTitle;
  final String? emptyDescription;
  final IconData emptyIcon;
  final EdgeInsetsGeometry listPadding;
  final EdgeInsetsGeometry cardPadding;
  final double minHeight;
  final double maxHeight;
  final ScrollController? controller;
  final bool showScrollbar;
  final Color? backgroundColor;
  final Widget? footer;
  final double footerSpacing;
  final bool showSectionCard;

  const CollectionPanel({
    super.key,
    required this.title,
    this.icon,
    this.actions = const [],
    this.children = const [],
    this.emptyState,
    this.emptyTitle = "尚無資料",
    this.emptyDescription,
    this.emptyIcon = Icons.inbox_outlined,
    this.listPadding = const EdgeInsets.all(8),
    this.cardPadding = const EdgeInsets.all(24),
    this.minHeight = 180,
    this.maxHeight = 300,
    this.controller,
    this.showScrollbar = false,
    this.backgroundColor,
    this.footer,
    this.footerSpacing = 12,
    this.showSectionCard = true,
  }) : itemCount = null,
       itemBuilder = null,
       separatorBuilder = null,
       content = null,
       assert(maxHeight >= minHeight),
       assert(footerSpacing >= 0);

  const CollectionPanel.builder({
    super.key,
    required this.title,
    required int this.itemCount,
    required IndexedWidgetBuilder this.itemBuilder,
    this.separatorBuilder,
    this.icon,
    this.actions = const [],
    this.emptyState,
    this.emptyTitle = "尚無資料",
    this.emptyDescription,
    this.emptyIcon = Icons.inbox_outlined,
    this.listPadding = const EdgeInsets.all(8),
    this.cardPadding = const EdgeInsets.all(24),
    this.minHeight = 180,
    this.maxHeight = 300,
    this.controller,
    this.showScrollbar = false,
    this.backgroundColor,
    this.footer,
    this.footerSpacing = 12,
    this.showSectionCard = true,
  }) : children = null,
       content = null,
       assert(itemCount >= 0),
       assert(maxHeight >= minHeight),
       assert(footerSpacing >= 0);

  const CollectionPanel.custom({
    super.key,
    required this.title,
    required Widget this.content,
    this.icon,
    this.actions = const [],
    this.emptyState,
    this.emptyTitle = "尚無資料",
    this.emptyDescription,
    this.emptyIcon = Icons.inbox_outlined,
    this.listPadding = const EdgeInsets.all(8),
    this.cardPadding = const EdgeInsets.all(24),
    this.minHeight = 180,
    this.maxHeight = 300,
    this.controller,
    this.showScrollbar = false,
    this.backgroundColor,
    this.footer,
    this.footerSpacing = 12,
    this.showSectionCard = true,
  }) : children = null,
       itemCount = null,
       itemBuilder = null,
       separatorBuilder = null,
       assert(maxHeight >= minHeight),
       assert(footerSpacing >= 0);

  int get _itemCount => itemCount ?? children!.length;

  Widget _buildList() {
    if (content != null) {
      return content!;
    }

    if (_itemCount == 0) {
      return emptyState ??
          AppEmptyState(
            title: emptyTitle,
            description: emptyDescription,
            icon: emptyIcon,
            compact: true,
          );
    }

    Widget list;
    if (separatorBuilder != null) {
      list = ListView.separated(
        controller: controller,
        primary: false,
        padding: listPadding,
        itemCount: _itemCount,
        itemBuilder: itemBuilder ?? (context, index) => children![index],
        separatorBuilder: separatorBuilder!,
      );
    } else {
      list = ListView.builder(
        controller: controller,
        primary: false,
        padding: listPadding,
        itemCount: _itemCount,
        itemBuilder: itemBuilder ?? (context, index) => children![index],
      );
    }

    return showScrollbar
        ? Scrollbar(controller: controller, child: list)
        : list;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final panelBody = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: BoxConstraints(
            minHeight: minHeight,
            maxHeight: maxHeight,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(8),
            color: scheme.surfaceContainerLowest,
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildList(),
        ),
        if (footer != null) ...[SizedBox(height: footerSpacing), footer!],
      ],
    );

    if (!showSectionCard) {
      return panelBody;
    }

    return AppSectionCard(
      title: title,
      icon: icon,
      actions: actions,
      padding: cardPadding,
      backgroundColor: backgroundColor,
      child: panelBody,
    );
  }
}
