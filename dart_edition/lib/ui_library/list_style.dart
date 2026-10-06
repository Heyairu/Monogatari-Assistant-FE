import "package:flutter/material.dart";

import "control_size.dart";
import "spacing.dart";
import "surface_shape.dart";

/// Shared presentation for plain list rows and list cards.
abstract final class AppListStyle {
  static const contentPadding = EdgeInsetsDirectional.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.sm,
  );
  static const cardGap = AppSpacing.sm;
  static const contentGap = AppSpacing.md;
  static const supportingGap = AppSpacing.xs;
  // Use the row's available width, including tree indentation, not screen size.
  static const stackedActionsBreakpoint = 320.0;

  static ListTileThemeData themeFor(ThemeData theme) => ListTileThemeData(
    dense: false,
    visualDensity: VisualDensity.standard,
    minTileHeight: AppControlSize.height,
    contentPadding: const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.md,
    ),
    minVerticalPadding: AppSpacing.sm,
    horizontalTitleGap: contentGap,
    minLeadingWidth: AppControlSize.icon,
    shape: AppSurfaceShape.shape,
    tileColor: Colors.transparent,
    selectedTileColor: theme.colorScheme.secondaryContainer,
    selectedColor: theme.colorScheme.onSecondaryContainer,
    // ListTile.textColor overrides both text roles; leave it unset so the
    // supporting role keeps its own color and disabled states use Material.
    iconColor: theme.colorScheme.onSurfaceVariant,
    titleTextStyle: theme.textTheme.bodyLarge,
    subtitleTextStyle: theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );
}
