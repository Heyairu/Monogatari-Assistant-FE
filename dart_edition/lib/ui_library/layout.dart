import "package:flutter/material.dart";

enum ResponsiveSplitViewCompactMode { vertical, primaryOnly, secondaryOnly }

/// A responsive two-pane layout for list/detail and form/form compositions.
class ResponsiveSplitView extends StatelessWidget {
  final Widget primary;
  final Widget secondary;
  final double breakpoint;
  final double spacing;
  final int primaryFlex;
  final int secondaryFlex;
  final ResponsiveSplitViewCompactMode compactMode;
  final CrossAxisAlignment crossAxisAlignment;

  const ResponsiveSplitView({
    super.key,
    required this.primary,
    required this.secondary,
    this.breakpoint = 720,
    this.spacing = 16,
    this.primaryFlex = 1,
    this.secondaryFlex = 1,
    this.compactMode = ResponsiveSplitViewCompactMode.vertical,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  }) : assert(breakpoint >= 0),
       assert(spacing >= 0),
       assert(primaryFlex > 0),
       assert(secondaryFlex > 0);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= breakpoint) {
          return Row(
            crossAxisAlignment: crossAxisAlignment,
            children: [
              Expanded(flex: primaryFlex, child: primary),
              SizedBox(width: spacing),
              Expanded(flex: secondaryFlex, child: secondary),
            ],
          );
        }

        return switch (compactMode) {
          ResponsiveSplitViewCompactMode.primaryOnly => primary,
          ResponsiveSplitViewCompactMode.secondaryOnly => secondary,
          ResponsiveSplitViewCompactMode.vertical => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              primary,
              SizedBox(height: spacing),
              secondary,
            ],
          ),
        };
      },
    );
  }
}

/// Standard surface used for titled sections throughout the application.
class AppSectionCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget? header;
  final List<Widget> actions;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? backgroundColor;
  final Color? color;
  final double elevation;
  final TextStyle? titleStyle;
  final double headerSpacing;
  final bool showDivider;
  final BoxConstraints? constraints;
  final Clip clipBehavior;
  final bool useSectionLayout;

  const AppSectionCard({
    super.key,
    this.title,
    this.icon,
    this.header,
    this.actions = const [],
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.margin = EdgeInsets.zero,
    this.backgroundColor,
    this.color,
    this.elevation = 0,
    this.titleStyle,
    this.headerSpacing = 16,
    this.showDivider = false,
    this.constraints,
    this.clipBehavior = Clip.none,
    this.useSectionLayout = true,
  }) : assert(
         title == null || header == null,
         "Use either title or a custom header, not both.",
       ),
       assert(
         backgroundColor == null || color == null,
         "Use either backgroundColor or color, not both.",
       ),
       assert(headerSpacing >= 0);

  Widget? _buildHeader(BuildContext context) {
    if (header != null) {
      return Row(
        children: [
          Expanded(child: header!),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 8),
            Row(mainAxisSize: MainAxisSize.min, children: actions),
          ],
        ],
      );
    }

    if (title == null && icon == null && actions.isEmpty) {
      return null;
    }

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
        ],
        if (title != null)
          Expanded(
            child: Text(
              title!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle ?? Theme.of(context).textTheme.titleMedium,
            ),
          )
        else
          const Spacer(),
        if (actions.isNotEmpty)
          Row(mainAxisSize: MainAxisSize.min, children: actions),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sectionHeader = _buildHeader(context);
    final content = !useSectionLayout && sectionHeader == null
        ? child
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sectionHeader != null) ...[
                sectionHeader,
                if (showDivider) ...[
                  SizedBox(height: headerSpacing / 2),
                  const Divider(height: 1),
                  SizedBox(height: headerSpacing / 2),
                ] else
                  SizedBox(height: headerSpacing),
              ],
              child,
            ],
          );

    return Card(
      margin: margin,
      elevation: elevation,
      color:
          backgroundColor ??
          color ??
          Theme.of(context).colorScheme.surfaceContainerLow,
      clipBehavior: clipBehavior,
      child: Container(
        constraints: constraints,
        padding: padding,
        child: content,
      ),
    );
  }
}

/// Consistent empty, unavailable, and unselected state presentation.
class AppEmptyState extends StatelessWidget {
  final String title;
  final String? description;
  final IconData icon;
  final Widget? action;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;
  final bool compact;

  const AppEmptyState({
    super.key,
    required this.title,
    this.description,
    this.icon = Icons.inbox_outlined,
    this.action,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.padding = const EdgeInsets.all(24),
    this.compact = false,
  }) : assert(
         action == null || (actionLabel == null && onAction == null),
         "Use either action or actionLabel/onAction.",
       ),
       assert(
         (actionLabel == null) == (onAction == null),
         "actionLabel and onAction must be provided together.",
       );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final resolvedAction =
        action ??
        (actionLabel == null
            ? null
            : FilledButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.add),
                label: Text(actionLabel!),
              ));

    return Semantics(
      container: true,
      label: description == null ? title : "$title。$description",
      child: Center(
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: compact ? 32 : 48,
                color: scheme.onSurfaceVariant,
              ),
              SizedBox(height: compact ? 8 : 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: (compact ? textTheme.titleSmall : textTheme.titleMedium)
                    ?.copyWith(color: scheme.onSurface),
              ),
              if (description != null) ...[
                const SizedBox(height: 6),
                Text(
                  description!,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (resolvedAction != null) ...[
                SizedBox(height: compact ? 12 : 16),
                resolvedAction,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
