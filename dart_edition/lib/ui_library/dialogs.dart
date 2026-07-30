import "package:flutter/material.dart";

import "feedback.dart";
import "forms.dart";

/// Standard application dialog shell plus common dialog workflows.
class AppDialog extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final IconData? icon;
  final AppFeedbackTone tone;
  final Widget? content;
  final List<Widget> actions;
  final bool scrollable;
  final double maxWidth;
  final EdgeInsets insetPadding;
  final EdgeInsetsGeometry contentPadding;

  const AppDialog({
    super.key,
    this.title,
    this.titleWidget,
    this.icon,
    this.tone = AppFeedbackTone.neutral,
    this.content,
    this.actions = const [],
    this.scrollable = false,
    this.maxWidth = 520,
    this.insetPadding = const EdgeInsets.symmetric(
      horizontal: 40,
      vertical: 24,
    ),
    this.contentPadding = const EdgeInsets.fromLTRB(24, 20, 24, 0),
  }) : assert(
         title == null || titleWidget == null,
         "Use either title or titleWidget, not both.",
       ),
       assert(maxWidth > 0);

  Widget? _buildTitle(BuildContext context) {
    if (titleWidget != null) {
      return titleWidget;
    }
    if (title == null) {
      return null;
    }

    final visuals = AppFeedbackTheme.resolve(context, tone);
    return Row(
      children: [
        Icon(icon ?? visuals.icon, color: visuals.foregroundColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title!, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _buildTitle(context),
      content: content == null
          ? null
          : ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: content,
            ),
      actions: actions,
      scrollable: scrollable,
      insetPadding: insetPadding,
      contentPadding: contentPadding,
    );
  }

  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? message,
    Widget? content,
    IconData? icon,
    AppFeedbackTone tone = AppFeedbackTone.neutral,
    List<Widget> Function(BuildContext dialogContext)? actionsBuilder,
    bool barrierDismissible = true,
    bool scrollable = false,
    double maxWidth = 520,
  }) {
    assert(
      message == null || content == null,
      "Use either message or custom content, not both.",
    );

    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) => AppDialog(
        title: title,
        icon: icon,
        tone: tone,
        content: content ?? (message == null ? null : Text(message)),
        actions: actionsBuilder?.call(dialogContext) ?? const [],
        scrollable: scrollable,
        maxWidth: maxWidth,
      ),
    );
  }

  /// Shows a fully custom dialog while keeping raw [showDialog] calls inside
  /// the UI Library.
  static Future<T?> showCustom<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color? barrierColor,
    String? barrierLabel,
    bool useSafeArea = true,
    bool useRootNavigator = true,
    RouteSettings? routeSettings,
  }) {
    return showDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      useSafeArea: useSafeArea,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
    );
  }

  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String cancelLabel = "取消",
    String confirmLabel = "確定",
    bool destructive = false,
    bool barrierDismissible = true,
    IconData? icon,
  }) async {
    final result = await show<bool>(
      context: context,
      title: title,
      message: message,
      icon: icon,
      tone: destructive ? AppFeedbackTone.error : AppFeedbackTone.warning,
      barrierDismissible: barrierDismissible,
      actionsBuilder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ];
      },
    );
    return result ?? false;
  }

  static Future<String?> prompt({
    required BuildContext context,
    required String title,
    String? message,
    String initialValue = "",
    String? labelText,
    String? hintText,
    String cancelLabel = "取消",
    String confirmLabel = "確定",
    bool allowEmpty = false,
    bool trimInput = true,
    bool barrierDismissible = true,
    IconData icon = Icons.edit_outlined,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) => _AppPromptDialog(
        title: title,
        message: message,
        initialValue: initialValue,
        labelText: labelText,
        hintText: hintText,
        cancelLabel: cancelLabel,
        confirmLabel: confirmLabel,
        allowEmpty: allowEmpty,
        trimInput: trimInput,
        icon: icon,
      ),
    );
  }

  static Future<void> message({
    required BuildContext context,
    required String title,
    required String message,
    String closeLabel = "關閉",
    AppFeedbackTone tone = AppFeedbackTone.info,
    IconData? icon,
    bool barrierDismissible = true,
  }) {
    return show<void>(
      context: context,
      title: title,
      message: message,
      tone: tone,
      icon: icon,
      barrierDismissible: barrierDismissible,
      actionsBuilder: (dialogContext) => [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(closeLabel),
        ),
      ],
    );
  }
}

class _AppPromptDialog extends StatefulWidget {
  final String title;
  final String? message;
  final String initialValue;
  final String? labelText;
  final String? hintText;
  final String cancelLabel;
  final String confirmLabel;
  final bool allowEmpty;
  final bool trimInput;
  final IconData icon;

  const _AppPromptDialog({
    required this.title,
    required this.message,
    required this.initialValue,
    required this.labelText,
    required this.hintText,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.allowEmpty,
    required this.trimInput,
    required this.icon,
  });

  @override
  State<_AppPromptDialog> createState() => _AppPromptDialogState();
}

class _AppPromptDialogState extends State<_AppPromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _value {
    return widget.trimInput ? _controller.text.trim() : _controller.text;
  }

  bool get _canSubmit => widget.allowEmpty || _value.isNotEmpty;

  void _submit() {
    if (_canSubmit) {
      Navigator.of(context).pop(_value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.title,
      icon: widget.icon,
      tone: AppFeedbackTone.info,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.message != null) ...[
            Text(widget.message!),
            const SizedBox(height: 16),
          ],
          AppTextField(
            controller: _controller,
            labelText: widget.labelText,
            hintText: widget.hintText,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, child) {
            return FilledButton(
              onPressed: _canSubmit ? _submit : null,
              child: Text(widget.confirmLabel),
            );
          },
        ),
      ],
    );
  }
}
