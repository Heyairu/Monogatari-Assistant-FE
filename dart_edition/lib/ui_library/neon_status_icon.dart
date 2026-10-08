import "package:flutter/material.dart";

import "control_size.dart";
import "neon_ui_theme.dart";

/// Selection and data status color the icon itself, without decorations.
class NeonStatusIcon extends StatelessWidget {
  final IconData icon;
  final NeonStatus status;
  final NeonAccent accent;
  final NeonAccent selectedAccent;
  final bool selected;
  final bool disabled;
  final bool busy;
  final bool destructive;
  final double size;

  const NeonStatusIcon({
    super.key,
    required this.icon,
    this.status = NeonStatus.idle,
    this.accent = NeonAccent.neutral,
    this.selectedAccent = NeonAccent.green,
    this.selected = false,
    this.disabled = false,
    this.busy = false,
    this.destructive = false,
    this.size = AppControlSize.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NeonUiTheme.resolve(context);
    final media = MediaQuery.maybeOf(context);
    if (busy && !disabled) {
      return SizedBox.square(
        dimension: size,
        child: CircularProgressIndicator(
          value: media?.disableAnimations == true ? .7 : null,
          strokeWidth: media?.highContrast == true ? 3 : 2,
          color: colors.color(NeonStatus.info),
        ),
      );
    }
    return Icon(
      icon,
      size: size,
      color: colors.foreground(
        status: status,
        disabled: disabled,
        destructive: destructive,
        selected: selected,
        accent: accent,
        selectedAccent: selectedAccent,
      ),
    );
  }
}
