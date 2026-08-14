import "dart:convert";

import "package:flutter/material.dart";

import "../../domain/models/p2p_sync_models.dart";

class P2pConflictResolutionDialog extends StatefulWidget {
  final List<P2pFieldConflictItem> conflicts;
  final ValueChanged<P2pConflictResolutionResult> onApply;
  final VoidCallback onCancel;

  const P2pConflictResolutionDialog({
    super.key,
    required this.conflicts,
    required this.onApply,
    required this.onCancel,
  });

  static Future<P2pConflictResolutionResult?> show(
    BuildContext context, {
    required List<P2pFieldConflictItem> conflicts,
  }) {
    return showDialog<P2pConflictResolutionResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => P2pConflictResolutionDialog(
        conflicts: conflicts,
        onApply: (result) => Navigator.of(dialogContext).pop(result),
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  @override
  State<P2pConflictResolutionDialog> createState() =>
      _P2pConflictResolutionDialogState();
}

class _P2pConflictResolutionDialogState
    extends State<P2pConflictResolutionDialog> {
  final Map<String, P2pConflictSide?> _groupDefaults =
      <String, P2pConflictSide?>{};
  final Map<String, P2pFieldConflictChoice> _fieldChoices =
      <String, P2pFieldConflictChoice>{};

  List<_P2pConflictGroup> get _groups {
    final grouped = <String, List<P2pFieldConflictItem>>{};
    for (final conflict in widget.conflicts) {
      grouped
          .putIfAbsent(_groupKey(conflict), () => <P2pFieldConflictItem>[])
          .add(conflict);
    }
    final groups =
        grouped.entries.map((entry) {
          final first = entry.value.first;
          final conflicts = entry.value.toList()
            ..sort((a, b) => a.fieldPath.compareTo(b.fieldPath));
          return _P2pConflictGroup(
            key: entry.key,
            type: first.groupType,
            id: first.groupId,
            label: first.groupLabel,
            conflicts: conflicts,
          );
        }).toList()..sort((a, b) {
          final type = a.type.compareTo(b.type);
          return type != 0 ? type : a.label.compareTo(b.label);
        });
    return groups;
  }

  String _groupKey(P2pFieldConflictItem conflict) {
    return "${conflict.groupType.length}:${conflict.groupType}/"
        "${conflict.groupId.length}:${conflict.groupId}";
  }

  P2pConflictSide? _effectiveSide(
    _P2pConflictGroup group,
    P2pFieldConflictItem conflict,
  ) {
    return switch (_fieldChoices[conflict.conflictId] ??
        P2pFieldConflictChoice.inheritGroup) {
      P2pFieldConflictChoice.inheritGroup => _groupDefaults[group.key],
      P2pFieldConflictChoice.local => P2pConflictSide.local,
      P2pFieldConflictChoice.remote => P2pConflictSide.remote,
    };
  }

  bool get _isComplete {
    return _groups.every(
      (group) => group.conflicts.every(
        (conflict) => _effectiveSide(group, conflict) != null,
      ),
    );
  }

  void _setAllDefaults(P2pConflictSide side) {
    setState(() {
      for (final group in _groups) {
        _groupDefaults[group.key] = side;
      }
    });
  }

  void _apply() {
    if (!_isComplete) return;
    final resolved = <String, P2pConflictSide>{};
    for (final group in _groups) {
      for (final conflict in group.conflicts) {
        resolved[conflict.conflictId] = _effectiveSide(group, conflict)!;
      }
    }
    widget.onApply(P2pConflictResolutionResult(resolved));
  }

  @override
  Widget build(BuildContext context) {
    final unresolvedCount = _groups.fold<int>(
      0,
      (count, group) =>
          count +
          group.conflicts
              .where((conflict) => _effectiveSide(group, conflict) == null)
              .length,
    );
    return AlertDialog(
      title: const Text("同步衝突：選擇各欄位使用版本"),
      content: SizedBox(
        width: 760,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              unresolvedCount == 0
                  ? "所有 ${widget.conflicts.length} 個衝突欄位皆已決定"
                  : "尚有 $unresolvedCount 個衝突欄位未決定",
              key: const Key("p2p-conflict-progress"),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _setAllDefaults(P2pConflictSide.local),
                  child: const Text("全部欄位預設本機"),
                ),
                OutlinedButton(
                  onPressed: () => _setAllDefaults(P2pConflictSide.remote),
                  child: const Text("全部欄位預設對方"),
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: ListView(
                children: _groups.map(_buildGroup).toList(growable: false),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key("p2p-conflict-cancel"),
          onPressed: widget.onCancel,
          child: const Text("取消並保留兩個版本"),
        ),
        FilledButton(
          key: const Key("p2p-conflict-apply"),
          onPressed: _isComplete ? _apply : null,
          child: Text("套用 ${widget.conflicts.length} 個欄位選擇並完成同步"),
        ),
      ],
    );
  }

  Widget _buildGroup(_P2pConflictGroup group) {
    final defaultSide = _groupDefaults[group.key];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: Key("p2p-conflict-group-${group.key}"),
        initiallyExpanded: false,
        title: Text("${group.type}：${group.label}"),
        subtitle: Text(
          "${group.conflicts.length} 個衝突欄位 · ${_shortId(group.id)}",
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                const Text("預設使用："),
                ChoiceChip(
                  key: Key("p2p-group-local-${group.key}"),
                  label: const Text("本機版本"),
                  selected: defaultSide == P2pConflictSide.local,
                  onSelected: (_) => setState(() {
                    _groupDefaults[group.key] = P2pConflictSide.local;
                  }),
                ),
                ChoiceChip(
                  key: Key("p2p-group-remote-${group.key}"),
                  label: const Text("對方版本"),
                  selected: defaultSide == P2pConflictSide.remote,
                  onSelected: (_) => setState(() {
                    _groupDefaults[group.key] = P2pConflictSide.remote;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...group.conflicts.map(
            (conflict) => _buildFieldConflict(group, conflict),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldConflict(
    _P2pConflictGroup group,
    P2pFieldConflictItem conflict,
  ) {
    final choice =
        _fieldChoices[conflict.conflictId] ??
        P2pFieldConflictChoice.inheritGroup;
    final inherited = _groupDefaults[group.key];
    final inheritedLabel = switch (inherited) {
      P2pConflictSide.local => "同上（本機版本）",
      P2pConflictSide.remote => "同上（對方版本）",
      null => "同上（尚未設定）",
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ExpansionTile(
          key: Key("p2p-field-${conflict.conflictId}"),
          title: Text("衝突欄位：${conflict.fieldPath}"),
          subtitle: Text(
            _effectiveSide(group, conflict) == null ? "尚未決定" : "已決定",
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            _buildVersionPreview("共同祖先", conflict.base),
            _buildVersionPreview("本機", conflict.local),
            _buildVersionPreview("對方", conflict.remote),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    key: Key("p2p-field-inherit-${conflict.conflictId}"),
                    label: Text(inheritedLabel),
                    selected: choice == P2pFieldConflictChoice.inheritGroup,
                    onSelected: (_) => _setFieldChoice(
                      conflict,
                      P2pFieldConflictChoice.inheritGroup,
                    ),
                  ),
                  ChoiceChip(
                    key: Key("p2p-field-local-${conflict.conflictId}"),
                    label: const Text("本機版本"),
                    selected: choice == P2pFieldConflictChoice.local,
                    onSelected: (_) =>
                        _setFieldChoice(conflict, P2pFieldConflictChoice.local),
                  ),
                  ChoiceChip(
                    key: Key("p2p-field-remote-${conflict.conflictId}"),
                    label: const Text("對方版本"),
                    selected: choice == P2pFieldConflictChoice.remote,
                    onSelected: (_) => _setFieldChoice(
                      conflict,
                      P2pFieldConflictChoice.remote,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setFieldChoice(
    P2pFieldConflictItem conflict,
    P2pFieldConflictChoice choice,
  ) {
    setState(() {
      _fieldChoices[conflict.conflictId] = choice;
    });
  }

  Widget _buildVersionPreview(String label, P2pFieldValue value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(_displayValue(value)),
            ),
          ),
        ],
      ),
    );
  }

  String _displayValue(P2pFieldValue value) {
    if (!value.exists) return "（不存在／已刪除）";
    final raw = value.value;
    if (raw is Map || raw is List) {
      try {
        return const JsonEncoder.withIndent("  ").convert(raw);
      } catch (_) {
        return raw.toString();
      }
    }
    return raw?.toString() ?? "null";
  }

  String _shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);
}

class _P2pConflictGroup {
  final String key;
  final String type;
  final String id;
  final String label;
  final List<P2pFieldConflictItem> conflicts;

  const _P2pConflictGroup({
    required this.key,
    required this.type,
    required this.id,
    required this.label,
    required this.conflicts,
  });
}
