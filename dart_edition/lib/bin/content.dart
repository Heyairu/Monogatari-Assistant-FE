import "package:flutter/material.dart";

class EditorTextBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const EditorTextBox({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: null,
        expands: true,
        decoration: InputDecoration(
          hintText: "在此輸入您的故事內容...",
          hintStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          contentPadding: const EdgeInsets.all(16),
        ),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(height: 1.6),
      ),
    );
  }
}
