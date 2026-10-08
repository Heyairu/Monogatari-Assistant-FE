import "package:flutter/material.dart";

import "control_size.dart";
import "neon_status_icon.dart";
import "neon_ui_theme.dart";

/// Material supplies keyboard activation, focus, ripple and toggle semantics.
class NeonIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool? selected;
  final NeonAccent accent;
  final NeonAccent selectedAccent;
  final NeonStatus status;
  final bool busy;
  final bool destructive;
  final String? statusLabel;
  final double iconSize;

  const NeonIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected,
    this.accent = NeonAccent.neutral,
    this.selectedAccent = NeonAccent.green,
    this.status = NeonStatus.idle,
    this.busy = false,
    this.destructive = false,
    this.statusLabel,
    this.iconSize = AppControlSize.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = NeonUiTheme.resolve(context);
    final media = MediaQuery.maybeOf(context);
    final desktop = switch (theme.platform) {
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.macOS => true,
      _ => false,
    };
    final targetSize = desktop ? AppControlSize.height : 48.0;
    final description = [
      label,
      if (selected != null) selected! ? "已啟用" : "未啟用",
      if (status != NeonStatus.idle || statusLabel != null)
        statusLabel ??
            switch (status) {
              NeonStatus.idle => "待命",
              NeonStatus.error => "錯誤",
              NeonStatus.warning => "異常需要處理",
              NeonStatus.notice => "待確認",
              NeonStatus.active => "持續生效",
              NeonStatus.connected => "已連結",
              NeonStatus.info => "資訊",
              NeonStatus.preview => "歷史預覽",
            },
      if (busy) "處理中",
    ].join("，");
    final statusIcon = NeonStatusIcon(
      icon: icon,
      size: iconSize,
      selected: selected == true,
      accent: accent,
      selectedAccent: selectedAccent,
      status: status,
      disabled: onPressed == null,
      busy: busy,
      destructive: destructive,
    );
    return Tooltip(
      message: description,
      child: IconButton(
        onPressed: busy ? null : onPressed,
        isSelected: selected,
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size.square(targetSize)),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          animationDuration: media?.disableAnimations == true
              ? Duration.zero
              : const Duration(milliseconds: 150),
          shape: const WidgetStatePropertyAll(CircleBorder()),
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(color: colors.color(NeonStatus.idle), width: 2)
                : BorderSide.none,
          ),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return Colors.transparent;
            }
            if (states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.focused)) {
              return colors.pressed;
            }
            if (states.contains(WidgetState.hovered)) {
              return colors.hover;
            }
            return Colors.transparent;
          }),
        ),
        icon: statusIcon,
        selectedIcon: statusIcon,
      ),
    );
  }
}
