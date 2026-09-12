import "package:flutter/material.dart";

/// Editable terms with the same chip/inline-editor interaction as WordPalettes.
class AliasTerms extends StatefulWidget {
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final void Function(String oldName, String newName)? onRenamed;

  const AliasTerms({
    super.key,
    required this.values,
    required this.onChanged,
    this.onRenamed,
  });

  @override
  State<AliasTerms> createState() => _AliasTermsState();
}

class _AliasTermsState extends State<AliasTerms> {
  final _editor = TextEditingController();
  String? _original;
  bool _editing = false;
  String? _error;

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  void _begin([String? original]) {
    setState(() {
      _original = original;
      _editor.text = original ?? "";
      _editing = true;
      _error = null;
    });
  }

  void _commit() {
    final text = _editor.text.trim();
    if (text.isEmpty || (text != _original && widget.values.contains(text))) {
      setState(() => _error = text.isEmpty ? "請輸入別名" : "別名已存在");
      return;
    }
    final next = [...widget.values];
    if (_original == null) {
      next.add(text);
    } else {
      final index = next.indexOf(_original!);
      if (index < 0) {
        setState(() => _error = "此別名已移除，請取消後重試");
        return;
      }
      next[index] = text;
    }
    widget.onChanged(next);
    if (_original != null && _original != text) {
      widget.onRenamed?.call(_original!, text);
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("別名"),
      const SizedBox(height: 8),
      Wrap(
        spacing: 7,
        runSpacing: 7,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final value in widget.values)
            InputChip(
              label: Text(value),
              tooltip: "編輯「$value」",
              onPressed: () => _begin(value),
              onDeleted: () =>
                  widget.onChanged([...widget.values]..remove(value)),
            ),
          if (!_editing)
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text("新增別名"),
              onPressed: () => _begin(),
            ),
          if (_editing)
            SizedBox(
              width: 300,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _editor,
                      autofocus: true,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: "輸入別名",
                        errorText: _error,
                      ),
                      onSubmitted: (_) => _commit(),
                    ),
                  ),
                  IconButton(
                    tooltip: "儲存",
                    onPressed: _commit,
                    icon: const Icon(Icons.check),
                  ),
                  IconButton(
                    tooltip: "取消",
                    onPressed: () => setState(() => _editing = false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
        ],
      ),
    ],
  );
}
