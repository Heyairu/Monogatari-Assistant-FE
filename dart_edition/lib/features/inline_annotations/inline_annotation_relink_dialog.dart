import "package:flutter/material.dart";

import "../../ui_library/dialogs.dart";
import "inline_annotation_target_resolver.dart";

abstract final class InlineAnnotationRelinkDialog {
  static Future<InlineAnnotationTargetInfo?> show({
    required BuildContext context,
    required List<InlineAnnotationTargetInfo> candidates,
  }) {
    return AppDialog.showCustom<InlineAnnotationTargetInfo>(
      context: context,
      builder: (_) => _InlineAnnotationRelinkForm(candidates: candidates),
    );
  }
}

class _InlineAnnotationRelinkForm extends StatefulWidget {
  final List<InlineAnnotationTargetInfo> candidates;

  const _InlineAnnotationRelinkForm({required this.candidates});

  @override
  State<_InlineAnnotationRelinkForm> createState() =>
      _InlineAnnotationRelinkFormState();
}

class _InlineAnnotationRelinkFormState
    extends State<_InlineAnnotationRelinkForm> {
  static const int _resultLimit = 100;
  String _query = "";

  List<InlineAnnotationTargetInfo> get _visibleCandidates {
    final query = _query.trim().toLowerCase();
    return widget.candidates
        .where(
          (candidate) =>
              query.isEmpty ||
              candidate.primaryName.toLowerCase().contains(query) ||
              candidate.id.toLowerCase().contains(query) ||
              (candidate.path?.toLowerCase().contains(query) ?? false),
        )
        .take(_resultLimit)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _visibleCandidates;
    return AppDialog(
      title: "重新連結遺失對象",
      icon: Icons.add_link,
      maxWidth: 560,
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          children: [
            TextField(
              key: const ValueKey("inline-annotation-relink-search"),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "搜尋名稱、路徑或 UUID",
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: candidates.isEmpty
                  ? const Center(child: Text("沒有相符的可連結對象"))
                  : ListView.builder(
                      itemCount: candidates.length,
                      itemBuilder: (context, index) {
                        final candidate = candidates[index];
                        return ListTile(
                          key: ValueKey(
                            "inline-annotation-relink-${candidate.id}",
                          ),
                          leading: const Icon(Icons.link),
                          title: Text(
                            candidate.primaryName.isEmpty
                                ? "（未命名）"
                                : candidate.primaryName,
                          ),
                          subtitle: Text(
                            candidate.path?.isNotEmpty == true
                                ? candidate.path!
                                : candidate.id,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.of(context).pop(candidate),
                        );
                      },
                    ),
            ),
            if (widget.candidates.length > _resultLimit && _query.isEmpty)
              Text(
                "目前顯示前 $_resultLimit 筆，請輸入關鍵字縮小範圍。",
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("取消"),
        ),
      ],
    );
  }
}
