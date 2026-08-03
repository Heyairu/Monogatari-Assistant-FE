import "package:flutter/material.dart";

import "../models/character_data.dart";
import "../ui_library/dialogs.dart";
import "../ui_library/forms.dart";
import "character_relationship_resolver.dart";

class CharacterRelationshipEditorResult {
  final String sourceCharacterId;
  final String person;
  final String description;
  final bool bidirectional;

  const CharacterRelationshipEditorResult({
    required this.sourceCharacterId,
    required this.person,
    required this.description,
    this.bidirectional = false,
  });
}

class CharacterRelationshipEditor {
  const CharacterRelationshipEditor._();

  static Future<CharacterRelationshipEditorResult?> show({
    required BuildContext context,
    required Map<String, CharacterEntryData> characters,
    String? sourceCharacterId,
    String initialPerson = "",
    String initialDescription = "",
    bool allowSourceSelection = true,
    bool allowBidirectional = true,
    String title = "新增人物關係",
  }) {
    return AppDialog.showCustom<CharacterRelationshipEditorResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _CharacterRelationshipEditorDialog(
        title: title,
        characters: characters,
        sourceCharacterId: sourceCharacterId,
        initialPerson: initialPerson,
        initialDescription: initialDescription,
        allowSourceSelection: allowSourceSelection,
        allowBidirectional: allowBidirectional,
      ),
    );
  }
}

class _CharacterRelationshipEditorDialog extends StatefulWidget {
  final String title;
  final Map<String, CharacterEntryData> characters;
  final String? sourceCharacterId;
  final String initialPerson;
  final String initialDescription;
  final bool allowSourceSelection;
  final bool allowBidirectional;

  const _CharacterRelationshipEditorDialog({
    required this.title,
    required this.characters,
    required this.sourceCharacterId,
    required this.initialPerson,
    required this.initialDescription,
    required this.allowSourceSelection,
    required this.allowBidirectional,
  });

  @override
  State<_CharacterRelationshipEditorDialog> createState() =>
      _CharacterRelationshipEditorDialogState();
}

class _CharacterRelationshipEditorDialogState
    extends State<_CharacterRelationshipEditorDialog> {
  late final TextEditingController _personController;
  late final TextEditingController _descriptionController;
  late String? _sourceCharacterId;
  bool _bidirectional = false;

  @override
  void initState() {
    super.initState();
    _personController = TextEditingController(text: widget.initialPerson);
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
    _sourceCharacterId =
        widget.sourceCharacterId ?? widget.characters.keys.firstOrNull;
  }

  @override
  void dispose() {
    _personController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _sourceCharacterId != null && _personController.text.trim().isNotEmpty;

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop(
      CharacterRelationshipEditorResult(
        sourceCharacterId: _sourceCharacterId!,
        person: _personController.text.trim(),
        description: _descriptionController.text.trim(),
        bidirectional: widget.allowBidirectional && _bidirectional,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final targetOptions = widget.characters.entries
        .where((entry) => entry.key != _sourceCharacterId)
        .map(
          (entry) => CharacterRelationshipResolver.displayLabel(
            entry.key,
            widget.characters,
          ),
        )
        .toList(growable: false);
    return AppDialog(
      title: widget.title,
      icon: Icons.hub_outlined,
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: const ValueKey("relationship-source-field"),
              initialValue: _sourceCharacterId,
              decoration: appFieldDecoration(
                context,
                decoration: const InputDecoration(labelText: "來源人物"),
              ),
              items: [
                for (final entry in widget.characters.entries)
                  DropdownMenuItem(
                    value: entry.key,
                    child: Text(
                      CharacterRelationshipResolver.displayLabel(
                        entry.key,
                        widget.characters,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: widget.allowSourceSelection
                  ? (value) {
                      setState(() => _sourceCharacterId = value);
                    }
                  : null,
            ),
            const SizedBox(height: 16),
            AppComboBoxField(
              key: const ValueKey("relationship-target-combobox"),
              controller: _personController,
              options: targetOptions,
              labelText: "目標人物",
              hintText: "選擇現有人物或輸入新人物名稱",
              onChanged: (_) => setState(() {}),
              onSelected: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            AppTextField(
              key: const ValueKey("relationship-description-field"),
              controller: _descriptionController,
              labelText: "關係",
              hintText: "例如：朋友、家人、競爭對手",
              maxLines: 1,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            if (widget.allowBidirectional) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                key: const ValueKey("bidirectional-relationship-checkbox"),
                value: _bidirectional,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text("雙向關係"),
                subtitle: const Text("同時建立目標人物指回來源人物的關係"),
                onChanged: (value) {
                  setState(() => _bidirectional = value ?? false);
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("取消"),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: const Text("儲存"),
        ),
      ],
    );
  }
}
