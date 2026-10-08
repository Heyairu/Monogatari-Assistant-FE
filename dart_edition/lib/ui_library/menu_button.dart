import "package:flutter/material.dart";

import "../bin/ui_library.dart" show DropdownOption;

/// A text menu for choices whose current value needs a readable name.
class AppMenuButton<T> extends StatelessWidget {
  final T value;
  final String labelText;
  final List<DropdownOption<T>> options;
  final ValueChanged<T?>? onChanged;

  const AppMenuButton({
    super.key,
    required this.value,
    required this.labelText,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final label = options.firstWhere((option) => option.value == value).label;
    return MenuAnchor(
      menuChildren: [
        for (final option in options)
          MenuItemButton(
            onPressed: onChanged == null
                ? null
                : () => onChanged!(option.value),
            leadingIcon: SizedBox.square(
              dimension: 20,
              child: option.value == value
                  ? const Icon(Icons.check, size: 20)
                  : null,
            ),
            child: Text(option.label),
          ),
      ],
      builder: (context, controller, child) => Tooltip(
        message: "$labelText：$label",
        child: TextButton.icon(
          onPressed: onChanged == null
              ? null
              : () {
                  controller.isOpen ? controller.close() : controller.open();
                },
          style: TextButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.expand_more, size: 20),
          label: Text(label),
        ),
      ),
    );
  }
}
