import "package:flutter/material.dart";

/// Application dimensions in logical pixels. Heights are minimums so text and
/// multiline content can grow without clipping.
abstract final class AppControlSize {
  static const height = 40.0;
  static const buttonMinWidth = 64.0;
  static const icon = 24.0;
  static const smallIcon = 20.0;
  static const chipIcon = 18.0;
  static const emptyStateIcon = 48.0;
  static const compactEmptyStateIcon = 32.0;
  static const navigationBarHeight = 80.0;
  static const navigationRailWidth = 80.0;
  static const navigationCompactRailWidth = 56.0;
  static const appBarHeight = 64.0;
  static const tabHeight = 48.0;
  static const fab = 56.0;
  static const smallFab = 40.0;
  static const largeFab = 96.0;
  static const menuMaxHeight = 320.0;
  // Flutter's DropdownButton requires menu items to be at least 48dp high.
  static const menuItemHeight = 48.0;
  static const suggestionMaxHeight = 240.0;
  static const suggestionWidth = 320.0;
  static const dialogMaxWidth = 520.0;
  static const collectionMinHeight = 192.0;
  static const collectionMaxHeight = 320.0;
  static const fieldConstraints = BoxConstraints(minHeight: height);
  static const iconConstraints = BoxConstraints(
    minWidth: height,
    minHeight: height,
  );

  /// Compact fields use 8dp vertical padding and a 24dp default line box.
  static double heightForFontSize(double baseFontSize) {
    final scaledHeight = (16 + 24 * baseFontSize / 14).ceilToDouble();
    return scaledHeight > height ? scaledHeight : height;
  }

  static double heightForContext(BuildContext context) => heightForFontSize(
    MediaQuery.textScalerOf(
      context,
    ).scale(Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14),
  );

  /// Match the visible field/chip surface to the control height when its text
  /// role differs from the default bodyLarge line box.
  static double verticalPaddingForStyle(
    BuildContext context,
    TextStyle style, {
    double? contentHeight,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: "Mg", style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final lineHeight = contentHeight ?? painter.height;
    painter.dispose();
    return ((heightForContext(context) - lineHeight) / 2).clamp(
      0.0,
      double.infinity,
    );
  }
}
