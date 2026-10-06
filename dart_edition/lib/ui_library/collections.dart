import "package:flutter/material.dart";

import "control_size.dart";
import "spacing.dart";
import "feedback.dart";
import "layout.dart";
import "list_style.dart";
import "surface_shape.dart";

/// One list item with its own surface. The parent owns spacing between cards.
/// Unlike ListTile, this layout does not cap the height of action controls.
class AppListCard extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final bool enabled;
  final Color? backgroundColor;
  final Color? selectedColor;

  const AppListCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.enabled = true,
    this.backgroundColor,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = !enabled
        ? scheme.onSurface.withValues(alpha: 0.38)
        : selected
        ? scheme.onSecondaryContainer
        : scheme.onSurface;
    final supportingColor = !enabled
        ? foreground
        : selected
        ? foreground
        : scheme.onSurfaceVariant;
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DefaultTextStyle.merge(
          style: theme.textTheme.bodyLarge!.copyWith(
            color: foreground,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
          child: title,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppListStyle.supportingGap),
          DefaultTextStyle.merge(
            style: theme.textTheme.bodyMedium!.copyWith(color: supportingColor),
            child: subtitle!,
          ),
        ],
      ],
    );

    return Semantics(
      selected: selected,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        color: selected
            ? (selectedColor ?? scheme.secondaryContainer)
            : (backgroundColor ?? scheme.surfaceContainerLowest),
        shape: AppSurfaceShape.shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: AppSurfaceShape.borderRadius,
          child: IconTheme.merge(
            data: IconThemeData(
              size: AppControlSize.icon,
              color: supportingColor,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stackActions =
                    trailing != null &&
                    constraints.maxWidth <
                        AppListStyle.stackedActionsBreakpoint;
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: AppControlSize.heightForContext(context),
                  ),
                  child: Padding(
                    padding: AppListStyle.contentPadding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            if (leading != null) ...[
                              leading!,
                              const SizedBox(width: AppListStyle.contentGap),
                            ],
                            Expanded(child: text),
                            if (trailing != null && !stackActions) ...[
                              const SizedBox(width: AppListStyle.contentGap),
                              trailing!,
                            ],
                          ],
                        ),
                        if (stackActions) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: trailing!,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Single-line status chip aligned with adjacent fields and action controls.
class AppControlChip extends StatelessWidget {
  final String label;
  final Widget? avatar;

  const AppControlChip({super.key, required this.label, this.avatar});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge!;
    return Chip(
      label: Text(label, style: style),
      avatar: avatar,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        // Material adds the 1dp outline on both sides of the chip's content.
        vertical: (AppControlSize.verticalPaddingForStyle(context, style) - 1)
            .clamp(0.0, double.infinity),
      ),
    );
  }
}

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
    this.iconSize = AppControlSize.smallIcon,
    this.visualDensity = VisualDensity.standard,
    this.alignment = MainAxisAlignment.end,
  }) : assert(iconSize > 0);

  ItemActionBar.editDelete({
    super.key,
    required VoidCallback? onEdit,
    required VoidCallback? onDelete,
    String editTooltip = "重新命名",
    String deleteTooltip = "刪除",
    this.iconSize = AppControlSize.smallIcon,
    this.visualDensity = VisualDensity.standard,
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
          style: ButtonStyle(
            minimumSize: WidgetStatePropertyAll<Size>(
              Size.square(AppControlSize.heightForContext(context)),
            ),
            padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
              AppSpacing.iconButtonPadding,
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
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
    this.listPadding = AppSpacing.listPadding,
    this.cardPadding = AppSpacing.regularSection,
    this.minHeight = AppControlSize.collectionMinHeight,
    this.maxHeight = AppControlSize.collectionMaxHeight,
    this.controller,
    this.showScrollbar = false,
    this.backgroundColor,
    this.footer,
    this.footerSpacing = AppSpacing.md,
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
    this.listPadding = AppSpacing.listPadding,
    this.cardPadding = AppSpacing.regularSection,
    this.minHeight = AppControlSize.collectionMinHeight,
    this.maxHeight = AppControlSize.collectionMaxHeight,
    this.controller,
    this.showScrollbar = false,
    this.backgroundColor,
    this.footer,
    this.footerSpacing = AppSpacing.md,
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
    this.listPadding = AppSpacing.listPadding,
    this.cardPadding = AppSpacing.regularSection,
    this.minHeight = AppControlSize.collectionMinHeight,
    this.maxHeight = AppControlSize.collectionMaxHeight,
    this.controller,
    this.showScrollbar = false,
    this.backgroundColor,
    this.footer,
    this.footerSpacing = AppSpacing.md,
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
            borderRadius: AppSurfaceShape.borderRadius,
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
