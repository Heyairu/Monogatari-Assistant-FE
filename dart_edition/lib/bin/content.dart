import "package:code_text_field/code_text_field.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../presentation/providers/global_state_providers.dart";

class EditorTextBox extends ConsumerStatefulWidget {
  final CodeController controller;
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
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant EditorTextBox oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      setState(() {});
    }

    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChange);
      widget.focusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = ref.watch(
      settingsStateProvider.select(
        (state) => state.valueOrNull?.fontSize ?? 12.0,
      ),
    );
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      height: 1.6,
      fontSize: fontSize,
    );
    final editorBackground = colorScheme.surfaceContainerLowest;

    return RepaintBoundary(
      child: AnimatedContainer(
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
                    controller: widget.controller,
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
      ),
    );
  }
}
