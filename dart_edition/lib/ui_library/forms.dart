import "package:flutter/material.dart";
import "package:flutter/services.dart";

/// A consistently decorated text form field for single and multiline input.
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final bool? selectAllOnFocus;
  final bool expands;
  final bool isDense;
  final bool? filled;
  final Color? fillColor;
  final EdgeInsetsGeometry? contentPadding;
  final double borderRadius;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextStyle? style;
  final TextAlign textAlign;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final VoidCallback? onTap;
  final TapRegionCallback? onTapOutside;
  final FormFieldSetter<String>? onSaved;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final InputDecoration? decoration;

  const AppTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.selectAllOnFocus,
    this.expands = false,
    this.isDense = true,
    this.filled,
    this.fillColor,
    this.contentPadding,
    this.borderRadius = 12,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.textAlign = TextAlign.start,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.onTap,
    this.onTapOutside,
    this.onSaved,
    this.validator,
    this.autovalidateMode,
    this.inputFormatters,
    this.autofillHints,
    this.decoration,
  }) : assert(
         controller == null || initialValue == null,
         "controller and initialValue cannot both be supplied.",
       ),
       assert(borderRadius >= 0),
       assert(
         !expands || (minLines == null && maxLines == null),
         "minLines and maxLines must be null when expands is true.",
       );

  @override
  Widget build(BuildContext context) {
    final defaultBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    );
    final resolvedDecoration = (decoration ?? const InputDecoration()).copyWith(
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      errorText: errorText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      isDense: isDense,
      filled: filled,
      fillColor: fillColor,
      contentPadding: contentPadding,
      border: decoration?.border ?? defaultBorder,
    );

    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      focusNode: focusNode,
      decoration: resolvedDecoration,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      obscureText: obscureText,
      enabled: enabled,
      readOnly: readOnly,
      autofocus: autofocus,
      selectAllOnFocus: selectAllOnFocus,
      expands: expands,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: style,
      textAlign: textAlign,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      onEditingComplete: onEditingComplete,
      onTap: onTap,
      onTapOutside: onTapOutside,
      onSaved: onSaved,
      validator: validator,
      autovalidateMode: autovalidateMode,
      inputFormatters: inputFormatters,
      autofillHints: autofillHints,
    );
  }
}

enum LabeledSliderLayout { stacked, inline }

/// A slider with a title, formatted value, and optional endpoint labels.
class LabeledSlider extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final String? leftLabel;
  final String? rightLabel;
  final String Function(double value)? valueLabelBuilder;
  final bool showValue;
  final IconData? icon;
  final LabeledSliderLayout layout;
  final double inlineTitleWidth;
  final EdgeInsetsGeometry padding;

  const LabeledSlider({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.divisions,
    this.onChangeStart,
    this.onChangeEnd,
    this.leftLabel,
    this.rightLabel,
    this.valueLabelBuilder,
    this.showValue = true,
    this.icon,
    this.layout = LabeledSliderLayout.stacked,
    this.inlineTitleWidth = 72,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  }) : assert(max > min),
       assert(value >= min && value <= max),
       assert(divisions == null || divisions > 0),
       assert(inlineTitleWidth > 0);

  String _formatValue(double sliderValue) {
    if (valueLabelBuilder != null) {
      return valueLabelBuilder!(sliderValue);
    }
    return sliderValue == sliderValue.roundToDouble()
        ? sliderValue.toStringAsFixed(0)
        : sliderValue.toStringAsFixed(1);
  }

  Widget _buildControl(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leftLabel != null || rightLabel != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(leftLabel ?? "", style: textTheme.bodySmall),
              Text(rightLabel ?? "", style: textTheme.bodySmall),
            ],
          ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: _formatValue(value),
          onChanged: onChanged,
          onChangeStart: onChangeStart,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }

  Widget _buildTitle(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        if (showValue) ...[
          const SizedBox(width: 8),
          Text(
            _formatValue(value),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: layout == LabeledSliderLayout.inline
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: inlineTitleWidth, child: _buildTitle(context)),
                const SizedBox(width: 8),
                Expanded(child: _buildControl(context)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [_buildTitle(context), _buildControl(context)],
            ),
    );
  }
}

/// Display/edit switch for inline renaming.
///
/// When [controller] is omitted, the widget owns a temporary controller while
/// editing. A caller-owned controller remains useful for list-wide rename
/// coordination.
class InlineEditableText extends StatefulWidget {
  final String value;
  final TextEditingController? controller;
  final bool isEditing;
  final VoidCallback? onEdit;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onCanceled;
  final String emptyText;
  final String? hintText;
  final TextStyle? style;
  final int maxLines;
  final bool editOnTap;
  final bool showActions;
  final bool autofocus;
  final TextAlign textAlign;
  final TapRegionCallback? onTapOutside;

  const InlineEditableText({
    super.key,
    required this.value,
    this.controller,
    required this.isEditing,
    required this.onSubmitted,
    this.onEdit,
    this.onCanceled,
    this.emptyText = "（未命名）",
    this.hintText,
    this.style,
    this.maxLines = 1,
    this.editOnTap = false,
    this.showActions = false,
    this.autofocus = true,
    this.textAlign = TextAlign.start,
    this.onTapOutside,
  }) : assert(maxLines > 0);

  @override
  State<InlineEditableText> createState() => _InlineEditableTextState();
}

class _InlineEditableTextState extends State<InlineEditableText> {
  TextEditingController? _internalController;

  TextEditingController get _effectiveController {
    return widget.controller ??
        (_internalController ??= TextEditingController(text: widget.value));
  }

  @override
  void initState() {
    super.initState();
    if (widget.controller == null && widget.isEditing) {
      _internalController = TextEditingController(text: widget.value);
    }
  }

  @override
  void didUpdateWidget(InlineEditableText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != null) {
      _internalController?.dispose();
      _internalController = null;
      return;
    }

    if (widget.isEditing && !oldWidget.isEditing) {
      _internalController?.dispose();
      _internalController = TextEditingController(text: widget.value);
    } else if (widget.isEditing &&
        widget.value != oldWidget.value &&
        _internalController?.text == oldWidget.value) {
      _internalController!.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    } else if (!widget.isEditing && oldWidget.isEditing) {
      _internalController?.dispose();
      _internalController = null;
    }
  }

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSubmitted(_effectiveController.text);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEditing) {
      return Semantics(
        button: widget.onEdit != null,
        child: MouseRegion(
          cursor: widget.onEdit == null
              ? MouseCursor.defer
              : SystemMouseCursors.text,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.editOnTap ? widget.onEdit : null,
            onDoubleTap: widget.editOnTap ? null : widget.onEdit,
            child: Text(
              widget.value.isEmpty ? widget.emptyText : widget.value,
              maxLines: widget.maxLines,
              overflow: widget.maxLines == 1 ? TextOverflow.ellipsis : null,
              textAlign: widget.textAlign,
              style: widget.style,
            ),
          ),
        ),
      );
    }

    final suffix = widget.showActions
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: "儲存",
                visualDensity: VisualDensity.compact,
                onPressed: _submit,
                icon: const Icon(Icons.check),
              ),
              if (widget.onCanceled != null)
                IconButton(
                  tooltip: "取消",
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onCanceled,
                  icon: const Icon(Icons.close),
                ),
            ],
          )
        : null;

    return CallbackShortcuts(
      bindings: {
        if (widget.onCanceled != null)
          const SingleActivator(LogicalKeyboardKey.escape): widget.onCanceled!,
      },
      child: AppTextField(
        controller: _effectiveController,
        hintText: widget.hintText,
        autofocus: widget.autofocus,
        maxLines: widget.maxLines,
        textAlign: widget.textAlign,
        suffixIcon: suffix,
        onSubmitted: (_) => _submit(),
        onTapOutside: widget.onTapOutside,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
    );
  }
}
