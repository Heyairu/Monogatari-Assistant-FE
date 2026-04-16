import "package:code_text_field/code_text_field.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../presentation/providers/global_state_providers.dart";

class EditorTextBox extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const EditorTextBox({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  @override
  ConsumerState<EditorTextBox> createState() => _EditorTextBoxState();
}

class _EditorTextBoxState extends ConsumerState<EditorTextBox> {
  late CodeController _codeController;
  bool _ownsCodeController = false;
  bool _bridgeEnabled = false;
  bool _isSyncingFromExternal = false;
  bool _isSyncingFromCodeField = false;

  @override
  void initState() {
    super.initState();
    _attachController(widget.controller);
    widget.focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant EditorTextBox oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      _detachController(oldWidget.controller);
      if (_ownsCodeController) {
        _codeController.dispose();
      }
      _attachController(widget.controller);
    }

    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChange);
      widget.focusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    _detachController(widget.controller);
    if (_ownsCodeController) {
      _codeController.dispose();
    }
    super.dispose();
  }

  void _attachController(TextEditingController externalController) {
    if (externalController is CodeController) {
      _codeController = externalController;
      _ownsCodeController = false;
      _bridgeEnabled = false;
      _codeController.addListener(_handleVisualChange);
      return;
    }

    _codeController = CodeController(text: externalController.text);
    _ownsCodeController = true;
    _bridgeEnabled = true;

    _syncExternalToCode();
    externalController.addListener(_handleExternalControllerChanged);
    _codeController.addListener(_handleCodeControllerChanged);
    _codeController.addListener(_handleVisualChange);
  }

  void _detachController(TextEditingController externalController) {
    _codeController.removeListener(_handleVisualChange);
    if (!_bridgeEnabled) {
      return;
    }

    externalController.removeListener(_handleExternalControllerChanged);
    _codeController.removeListener(_handleCodeControllerChanged);
  }

  void _handleFocusChange() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _handleVisualChange() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _handleExternalControllerChanged() {
    if (!_bridgeEnabled || _isSyncingFromCodeField) {
      return;
    }
    _syncExternalToCode();
  }

  void _syncExternalToCode() {
    final externalValue = widget.controller.value;
    final normalizedSelection = _clampSelection(
      externalValue.selection,
      externalValue.text.length,
    );
    final normalizedValue = externalValue.copyWith(selection: normalizedSelection);

    if (_codeController.value == normalizedValue) {
      return;
    }

    _isSyncingFromExternal = true;
    _codeController.value = normalizedValue;
    _isSyncingFromExternal = false;
  }

  void _handleCodeControllerChanged() {
    if (!_bridgeEnabled || _isSyncingFromExternal) {
      return;
    }

    final codeValue = _codeController.value;
    final normalizedSelection = _clampSelection(
      codeValue.selection,
      codeValue.text.length,
    );
    final normalizedValue = codeValue.copyWith(selection: normalizedSelection);

    if (widget.controller.value == normalizedValue) {
      return;
    }

    _isSyncingFromCodeField = true;
    widget.controller.value = normalizedValue;
    _isSyncingFromCodeField = false;
  }

  TextSelection _clampSelection(TextSelection selection, int textLength) {
    if (!selection.isValid) {
      return const TextSelection.collapsed(offset: 0);
    }

    final int base = selection.baseOffset.clamp(0, textLength);
    final int extent = selection.extentOffset.clamp(0, textLength);
    return TextSelection(
      baseOffset: base,
      extentOffset: extent,
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsStateProvider).valueOrNull ??
        const AppSettingsStateData();
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      height: 1.6,
      fontSize: settingsState.fontSize,
    );
    final editorBackground = colorScheme.surfaceContainerLowest;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: editorBackground,
      ),
      child: ClipRect(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const double gutterCompensation = 4;
            final double compensatedWidth =
                constraints.maxWidth + gutterCompensation * 2;
            return Transform.translate(
              // code_text_field 1.1.0 adds a fixed 8px left inset when
              // lineNumbers is disabled. Shift left and widen equally so no
              // visual strip appears on either side.
              offset: const Offset(-gutterCompensation, 0),
              child: SizedBox(
                width: compensatedWidth,
                child: CodeField(
                  controller: _codeController,
                  focusNode: widget.focusNode,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  wrap: true,
                  horizontalScroll: false,
                  lineNumbers: false,
                  background: editorBackground,
                  textStyle: textStyle,
                  cursorColor: colorScheme.primary,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
