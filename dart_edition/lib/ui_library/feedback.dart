import "package:flutter/material.dart";

/// UI feedback semantics shared by banners, snack bars, and dialogs.
enum AppFeedbackTone { neutral, info, success, warning, error }

@immutable
class AppFeedbackVisuals {
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;

  const AppFeedbackVisuals({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
  });
}

/// Resolves semantic feedback tones against the active Material color scheme.
abstract final class AppFeedbackTheme {
  static AppFeedbackVisuals resolve(
    BuildContext context,
    AppFeedbackTone tone,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return switch (tone) {
      AppFeedbackTone.neutral => AppFeedbackVisuals(
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurfaceVariant,
        icon: Icons.notifications_none,
      ),
      AppFeedbackTone.info => AppFeedbackVisuals(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        icon: Icons.info_outline,
      ),
      AppFeedbackTone.success => AppFeedbackVisuals(
        backgroundColor: scheme.tertiaryContainer,
        foregroundColor: scheme.onTertiaryContainer,
        icon: Icons.check_circle_outline,
      ),
      AppFeedbackTone.warning => AppFeedbackVisuals(
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
        icon: Icons.warning_amber_outlined,
      ),
      AppFeedbackTone.error => AppFeedbackVisuals(
        backgroundColor: scheme.errorContainer,
        foregroundColor: scheme.onErrorContainer,
        icon: Icons.error_outline,
      ),
    };
  }
}

/// A persistent, in-layout message for information, success, warning, or errors.
class AppNoticeBanner extends StatelessWidget {
  final String message;
  final String? title;
  final AppFeedbackTone tone;
  final IconData? icon;
  final Widget? action;
  final VoidCallback? onDismiss;
  final EdgeInsetsGeometry padding;
  final bool compact;

  const AppNoticeBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = AppFeedbackTone.info,
    this.icon,
    this.action,
    this.onDismiss,
    this.padding = const EdgeInsets.all(12),
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final visuals = AppFeedbackTheme.resolve(context, tone);
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      liveRegion: tone == AppFeedbackTone.error,
      child: Material(
        color: visuals.backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(compact ? 8 : 12),
        ),
        child: Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: title == null
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Icon(
                icon ?? visuals.icon,
                color: visuals.foregroundColor,
                size: compact ? 20 : 24,
              ),
              SizedBox(width: compact ? 8 : 12),
              Expanded(
                child: title == null
                    ? Text(
                        message,
                        style: textTheme.bodyMedium?.copyWith(
                          color: visuals.foregroundColor,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title!,
                            style: textTheme.titleSmall?.copyWith(
                              color: visuals.foregroundColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            message,
                            style: textTheme.bodyMedium?.copyWith(
                              color: visuals.foregroundColor,
                            ),
                          ),
                        ],
                      ),
              ),
              if (action != null) ...[const SizedBox(width: 8), action!],
              if (onDismiss != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: "關閉",
                  onPressed: onDismiss,
                  color: visuals.foregroundColor,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centralized transient feedback displayed through [ScaffoldMessenger].
abstract final class AppFeedback {
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context, {
    required String message,
    AppFeedbackTone tone = AppFeedbackTone.neutral,
    Duration duration = const Duration(seconds: 3),
    SnackBarBehavior behavior = SnackBarBehavior.floating,
    String? actionLabel,
    VoidCallback? onAction,
    bool clearPrevious = false,
  }) {
    assert(
      (actionLabel == null) == (onAction == null),
      "actionLabel and onAction must be provided together.",
    );

    final messenger = ScaffoldMessenger.of(context);
    final visuals = AppFeedbackTheme.resolve(context, tone);

    if (clearPrevious) {
      messenger.clearSnackBars();
    }

    return messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: behavior,
        backgroundColor: visuals.backgroundColor,
        content: Row(
          children: [
            Icon(visuals.icon, color: visuals.foregroundColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: visuals.foregroundColor),
              ),
            ),
          ],
        ),
        action: actionLabel == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: visuals.foregroundColor,
                onPressed: onAction!,
              ),
      ),
    );
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> info(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    return show(
      context,
      message: message,
      tone: AppFeedbackTone.info,
      duration: duration,
    );
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> success(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    return show(
      context,
      message: message,
      tone: AppFeedbackTone.success,
      duration: duration,
    );
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> warning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    return show(
      context,
      message: message,
      tone: AppFeedbackTone.warning,
      duration: duration,
    );
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> error(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    return show(
      context,
      message: message,
      tone: AppFeedbackTone.error,
      duration: duration,
    );
  }
}

/// Functional API for callers that prefer a top-level helper.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppSnackBar(
  BuildContext context, {
  required String message,
  AppFeedbackTone tone = AppFeedbackTone.neutral,
  Duration duration = const Duration(seconds: 3),
  SnackBarBehavior behavior = SnackBarBehavior.floating,
  String? actionLabel,
  VoidCallback? onAction,
  bool clearPrevious = false,
}) {
  return AppFeedback.show(
    context,
    message: message,
    tone: tone,
    duration: duration,
    behavior: behavior,
    actionLabel: actionLabel,
    onAction: onAction,
    clearPrevious: clearPrevious,
  );
}
