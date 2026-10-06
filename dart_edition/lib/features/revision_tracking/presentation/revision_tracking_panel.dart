import "package:flutter/material.dart";
import "package:flutter/foundation.dart" show listEquals;
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../ui_library/spacing.dart";
import "../../../presentation/providers/revision_tracking_provider.dart";
import "../../../presentation/providers/project_state_providers.dart";
import "../../../models/chapter_selection_data.dart";
import "../application/revision_field_registry.dart";
import "../application/revision_review_service.dart";
import "../domain/revision_models.dart";
import "../domain/revision_target.dart";

class RevisionTrackingPanel extends ConsumerWidget {
  final VoidCallback onStart;
  final VoidCallback onClose;
  final void Function(RevisionTextDiff, RevisionTextHunk, int) onNavigateText;
  final void Function(RevisionRecordChange, RevisionFieldChange?)
  onNavigateRecord;
  final int sidebarPageIndex;
  final void Function(RevisionTextDiff, RevisionTextHunk)? onRejectText;
  final void Function(Map<RevisionTextDiff, List<RevisionTextHunk>>)?
  onRejectTextScope;
  final void Function(RevisionRecordChange, RevisionFieldChange?)?
  onRejectRecord;
  const RevisionTrackingPanel({
    super.key,
    required this.onStart,
    required this.onClose,
    required this.onNavigateText,
    required this.onNavigateRecord,
    required this.sidebarPageIndex,
    this.onRejectText,
    this.onRejectTextScope,
    this.onRejectRecord,
  });

  static RevisionSidebarPage? _page(int index) => switch (index) {
    1 => RevisionSidebarPage.baseInfo,
    2 => RevisionSidebarPage.chapters,
    3 => RevisionSidebarPage.outline,
    5 => RevisionSidebarPage.characters,
    7 => RevisionSidebarPage.world,
    8 => RevisionSidebarPage.items,
    _ => null,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(revisionTrackingProvider);
    final notifier = ref.read(revisionTrackingProvider.notifier);
    final selectedChapter = ref.watch(editorSelectionProvider).selectedChapID;
    final chapterNames = {
      for (final location in ChapterTree.chaptersDepthFirst(
        ref.watch(segmentsDataProvider),
      ))
        location.chapter.chapterUUID: location.chapter.chapterName,
    };
    final result = state.comparison;
    final currentOnly = state.scope == RevisionViewScope.current;
    final texts =
        result?.texts
            .where(
              (text) =>
                  state.filter != RevisionViewFilter.settings &&
                  (!currentOnly || text.chapterId == selectedChapter),
            )
            .toList() ??
        [];
    final records =
        result?.records
            .where(
              (record) =>
                  state.filter != RevisionViewFilter.text &&
                  (!currentOnly ||
                      RevisionFieldRegistry.pageFor(record.key.kind) ==
                          _page(sidebarPageIndex)),
            )
            .toList() ??
        [];
    final visibleHunks =
        <({RevisionTextDiff text, RevisionTextHunk hunk, int index})>[];
    for (final text in texts) {
      for (var index = 0; index < text.hunks.length; index++) {
        final hunk = text.hunks[index];
        if (state.showAccepted ||
            !state.acceptedEvents.contains(
              RevisionReviewService.textKey(state.baseline!, text, hunk),
            )) {
          visibleHunks.add((text: text, hunk: hunk, index: index));
        }
      }
    }
    final visibleRecords = records.where((record) {
      if (state.showAccepted) return true;
      if (record.fields.isEmpty) {
        return !state.acceptedEvents.contains(
          RevisionReviewService.recordKey(state.baseline!, record, null),
        );
      }
      return record.fields.any(
        (field) => !state.acceptedEvents.contains(
          RevisionReviewService.recordKey(state.baseline!, record, field),
        ),
      );
    }).toList();
    final pendingKeys = <String>{
      for (final entry in visibleHunks)
        RevisionReviewService.textKey(state.baseline!, entry.text, entry.hunk),
      for (final record in visibleRecords)
        if (record.fields.isEmpty)
          RevisionReviewService.recordKey(state.baseline!, record, null)
        else
          for (final field in record.fields)
            RevisionReviewService.recordKey(state.baseline!, record, field),
    }.difference(state.acceptedEvents);
    final pendingText = <RevisionTextDiff, List<RevisionTextHunk>>{};
    for (final entry in visibleHunks) {
      final key = RevisionReviewService.textKey(
        state.baseline!,
        entry.text,
        entry.hunk,
      );
      if (!state.acceptedEvents.contains(key)) {
        pendingText.putIfAbsent(entry.text, () => []).add(entry.hunk);
      }
    }
    final navigation = <({RevisionTarget target, VoidCallback run})>[];
    for (final entry in visibleHunks) {
      final text = entry.text;
      final hunk = entry.hunk;
      final index = entry.index;
      navigation.add((
        target: RevisionTarget.chapter(text.chapterId, hunkIndex: index),
        run: () => _selectText(ref, text, hunk, index),
      ));
    }
    for (final record in visibleRecords) {
      if (record.fields.isEmpty) {
        navigation.add((
          target: RevisionTarget.field(record.key, const []),
          run: () => _selectRecord(ref, record, null),
        ));
      } else {
        for (final field in record.fields) {
          if (!state.showAccepted &&
              state.acceptedEvents.contains(
                RevisionReviewService.recordKey(state.baseline!, record, field),
              )) {
            continue;
          }
          navigation.add((
            target: RevisionTarget.field(record.key, field.target.fieldPath),
            run: () => _selectRecord(ref, record, field),
          ));
        }
      }
    }
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                const Icon(Icons.rate_review_outlined, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "修訂追蹤",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: "收合修訂窗格",
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          if (state.baseline == null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.space20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.status == RevisionComparisonStatus.unavailable
                            ? (state.error ?? "追蹤資料無法讀取")
                            : "從目前內容建立比較基準，開始查看修訂。",
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: onStart,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text("開始追蹤"),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "基準：${state.baseline!.label}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "${state.baseline!.readOnly ? "唯讀版本" : "建立"}：${state.baseline!.createdAt.toLocal().toString().substring(0, 16)} · 目標：目前內容",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (state.baseline!.sourceRevisionId case final revisionId?)
                    Text(
                      "P2P revision：$revisionId",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: state.baseline!.id,
                          items: [
                            for (final baseline in state.baselines)
                              DropdownMenuItem(
                                value: baseline.id,
                                child: Text(
                                  baseline.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (id) {
                            if (id != null) notifier.selectBaseline(id);
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: "儲存目前內容為檢查點並套用",
                        onPressed: () => notifier.saveCheckpoint(),
                        icon: const Icon(Icons.bookmark_add_outlined),
                      ),
                    ],
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text("顯示已接受"),
                    value: state.showAccepted,
                    onChanged: (value) =>
                        notifier.setShowAccepted(value ?? false),
                  ),
                  TextButton.icon(
                    onPressed: notifier.stop,
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: const Text("結束追蹤"),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Wrap(
                spacing: 3,
                children: [
                  for (final (label, filter) in [
                    ("全部", RevisionViewFilter.all),
                    ("正文", RevisionViewFilter.text),
                    ("設定", RevisionViewFilter.settings),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: state.filter == filter,
                      onSelected: (_) => notifier.setFilter(filter),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                children: [
                  const Text("範圍："),
                  Expanded(
                    child: DropdownButton<RevisionViewScope>(
                      isExpanded: true,
                      value: state.scope,
                      items: const [
                        DropdownMenuItem(
                          value: RevisionViewScope.current,
                          child: Text("目前章節／頁面"),
                        ),
                        DropdownMenuItem(
                          value: RevisionViewScope.allProject,
                          child: Text("全專案"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) notifier.setScope(value);
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (result != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  "正文 +${result.addedLines} / -${result.removedLines} 行 · 設定 +${result.recordCount(RevisionChangeKind.added)} / -${result.recordCount(RevisionChangeKind.removed)} / M${result.recordCount(RevisionChangeKind.modified)}",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (pendingKeys.isNotEmpty && !state.baseline!.readOnly)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => notifier.acceptEvents(pendingKeys),
                  icon: const Icon(Icons.done_all, size: 16),
                  label: Text("接受此範圍 ${pendingKeys.length} 筆"),
                ),
              ),
            if (pendingText.values.fold<int>(
                      0,
                      (sum, hunks) => sum + hunks.length,
                    ) >
                    1 &&
                !state.baseline!.readOnly &&
                onRejectTextScope != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => onRejectTextScope!(pendingText),
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text("拒絕此範圍正文"),
                ),
              ),
            if (result != null && result.texts.any((text) => text.isCoarse))
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text("大型差異已簡化，行數可能非最小值"),
              ),
            if (result != null && result.unsupportedKinds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  "部分資料類型尚未納入比較",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: "上一筆",
                  onPressed: navigation.isEmpty
                      ? null
                      : () => _step(ref, navigation, -1),
                  icon: const Icon(Icons.keyboard_arrow_up),
                ),
                IconButton(
                  tooltip: "下一筆",
                  onPressed: navigation.isEmpty
                      ? null
                      : () => _step(ref, navigation, 1),
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: switch (state.status) {
                RevisionComparisonStatus.computing => const Center(
                  child: CircularProgressIndicator(),
                ),
                RevisionComparisonStatus.failed => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text("計算修訂失敗：${state.error ?? "未知錯誤"}"),
                  ),
                ),
                RevisionComparisonStatus.unavailable => const Center(
                  child: Text("比較來源尚未取得"),
                ),
                _ when visibleHunks.isEmpty && visibleRecords.isEmpty =>
                  const Center(child: Text("此範圍沒有修訂")),
                _ => ListView.builder(
                  itemCount: visibleHunks.length + visibleRecords.length,
                  itemBuilder: (context, index) {
                    if (index < visibleHunks.length) {
                      final entry = visibleHunks[index];
                      final text = entry.text;
                      final hunk = entry.hunk;
                      final key = RevisionReviewService.textKey(
                        state.baseline!,
                        text,
                        hunk,
                      );
                      return _TextHunkCard(
                        text: text,
                        chapterName:
                            chapterNames[text.chapterId] ?? text.chapterId,
                        hunk: hunk,
                        index: entry.index,
                        onTap: () => _selectText(ref, text, hunk, entry.index),
                        accepted: state.acceptedEvents.contains(key),
                        onAccept: state.baseline!.readOnly
                            ? null
                            : () => notifier.acceptEvent(key),
                        onUnaccept: state.baseline!.readOnly
                            ? null
                            : () => notifier.unacceptEvent(key),
                        onReject:
                            state.baseline!.readOnly || onRejectText == null
                            ? null
                            : () => onRejectText!(text, hunk),
                      );
                    }
                    final record = visibleRecords[index - visibleHunks.length];
                    return _RecordCard(
                      record: record,
                      onTap: (field) => _selectRecord(ref, record, field),
                      baseline: state.baseline!,
                      acceptedEvents: state.acceptedEvents,
                      showAccepted: state.showAccepted,
                      onAccept: state.baseline!.readOnly
                          ? null
                          : notifier.acceptEvent,
                      onUnaccept: state.baseline!.readOnly
                          ? null
                          : notifier.unacceptEvent,
                      onReject:
                          state.baseline!.readOnly || onRejectRecord == null
                          ? null
                          : (field) => onRejectRecord!(record, field),
                    );
                  },
                ),
              },
            ),
          ],
        ],
      ),
    );
  }

  void _selectText(
    WidgetRef ref,
    RevisionTextDiff text,
    RevisionTextHunk hunk,
    int index,
  ) {
    ref
        .read(revisionTrackingProvider.notifier)
        .select(RevisionTarget.chapter(text.chapterId, hunkIndex: index));
    onNavigateText(text, hunk, index);
  }

  void _selectRecord(
    WidgetRef ref,
    RevisionRecordChange record,
    RevisionFieldChange? field,
  ) {
    ref
        .read(revisionTrackingProvider.notifier)
        .select(
          RevisionTarget.field(record.key, field?.target.fieldPath ?? const []),
        );
    onNavigateRecord(record, field);
  }

  void _step(
    WidgetRef ref,
    List<({RevisionTarget target, VoidCallback run})> actions,
    int direction,
  ) {
    final selected = ref.read(revisionTrackingProvider).selectedTarget;
    final index = selected == null
        ? -1
        : actions.indexWhere(
            (entry) =>
                entry.target.chapterId == selected.chapterId &&
                entry.target.hunkIndex == selected.hunkIndex &&
                entry.target.recordKey == selected.recordKey &&
                listEquals(entry.target.fieldPath, selected.fieldPath),
          );
    final next = index < 0
        ? (direction > 0 ? 0 : actions.length - 1)
        : (index + direction + actions.length) % actions.length;
    actions[next].run();
  }
}

class _TextHunkCard extends StatelessWidget {
  final RevisionTextDiff text;
  final String chapterName;
  final RevisionTextHunk hunk;
  final int index;
  final VoidCallback onTap;
  final bool accepted;
  final VoidCallback? onAccept;
  final VoidCallback? onUnaccept;
  final VoidCallback? onReject;
  const _TextHunkCard({
    required this.text,
    required this.chapterName,
    required this.hunk,
    required this.index,
    required this.onTap,
    required this.accepted,
    required this.onAccept,
    required this.onUnaccept,
    required this.onReject,
  });
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.fromLTRB(8, 5, 8, 2),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "正文／$chapterName · 舊 ${hunk.oldStart + 1} → 新 ${hunk.newStart + 1}",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            for (final line in hunk.lines.take(12))
              Text(
                "${line.kind == RevisionLineKind.added ? "+" : "-"} ${line.after?.text ?? line.before?.text ?? ""}",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: line.kind == RevisionLineKind.added
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
              ),
            if (hunk.lines.length > 12) Text("另有 ${hunk.lines.length - 12} 行…"),
            if (hunk.lines.isEmpty && text.trailingNewlineChanged)
              Text(
                "行尾換行：${text.oldTrailingNewline ? "有" : "無"} → ${text.newTrailingNewline ? "有" : "無"}",
              ),
            if (text.isCoarse)
              const Text("大型差異概略呈現", style: TextStyle(fontSize: 11)),
            Wrap(
              spacing: 4,
              children: [
                TextButton(
                  onPressed: () => _showFullDiff(context),
                  child: const Text("完整標記"),
                ),
                if (onAccept != null)
                  TextButton(
                    onPressed: accepted ? onUnaccept : onAccept,
                    child: Text(accepted ? "取消接受" : "接受"),
                  ),
                if (!accepted && onReject != null)
                  TextButton(onPressed: onReject, child: const Text("拒絕")),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  void _showFullDiff(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$chapterName · 完整標記"),
        content: SizedBox(
          width: (MediaQuery.sizeOf(context).width - 80).clamp(200.0, 640.0),
          height: (MediaQuery.sizeOf(context).height - 180).clamp(200.0, 500.0),
          child: ListView.builder(
            itemCount: text.lines.length,
            itemBuilder: (context, index) {
              final line = text.lines[index];
              final sign = switch (line.kind) {
                RevisionLineKind.added => "+",
                RevisionLineKind.removed => "−",
                RevisionLineKind.equal => " ",
              };
              final value = line.after?.text ?? line.before?.text ?? "";
              return SelectableText(
                "$sign $value",
                style: TextStyle(
                  color: line.kind == RevisionLineKind.added
                      ? Colors.green.shade700
                      : line.kind == RevisionLineKind.removed
                      ? Colors.red.shade700
                      : null,
                  decoration: line.kind == RevisionLineKind.removed
                      ? TextDecoration.lineThrough
                      : null,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("關閉"),
          ),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final RevisionRecordChange record;
  final void Function(RevisionFieldChange?) onTap;
  final RevisionBaseline baseline;
  final Set<String> acceptedEvents;
  final bool showAccepted;
  final void Function(String)? onAccept;
  final void Function(String)? onUnaccept;
  final void Function(RevisionFieldChange?)? onReject;
  const _RecordCard({
    required this.record,
    required this.onTap,
    required this.baseline,
    required this.acceptedEvents,
    required this.showAccepted,
    required this.onAccept,
    required this.onUnaccept,
    required this.onReject,
  });
  String _display(Object? value) => value == null ? "null" : value.toString();
  @override
  Widget build(BuildContext context) {
    final badge = switch (record.kind) {
      RevisionChangeKind.added => "+",
      RevisionChangeKind.removed => "-",
      RevisionChangeKind.modified => "Modified",
    };
    final page = RevisionFieldRegistry.pageFor(record.key.kind);
    final label = page == null
        ? record.key.kind.name
        : RevisionFieldRegistry.pageLabel(page);
    final name =
        record.after?.fields["displayName"] ??
        record.after?.fields["name"] ??
        record.after?.fields["event"] ??
        record.before?.fields["displayName"] ??
        record.before?.fields["name"] ??
        record.before?.fields["event"] ??
        (record.key.kind.name == "baseInfo" ? "專案資訊" : record.key.recordId);
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 5, 8, 2),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text("$label／$name"),
              trailing: Text(badge),
              onTap: () => onTap(null),
            ),
            if (record.fields.isEmpty)
              Text(record.kind == RevisionChangeKind.added ? "新增項目" : "刪除項目"),
            if (record.fields.isEmpty) _reviewActions(null),
            if (record.fields.isEmpty)
              for (final entry
                  in (record.after ?? record.before)!.fields.entries
                      .where(
                        (entry) => !RevisionFieldRegistry.excluded(entry.key),
                      )
                      .take(8))
                Text(
                  "${RevisionFieldRegistry.labelFor([entry.key])}：${_display(entry.value)}",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            for (final field in record.fields)
              if (showAccepted ||
                  !acceptedEvents.contains(
                    RevisionReviewService.recordKey(baseline, record, field),
                  ))
                InkWell(
                  onTap: () => onTap(field),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${RevisionFieldRegistry.labelFor(field.target.fieldPath)}  "
                          "${switch (field.kind) {
                            RevisionChangeKind.added => "+",
                            RevisionChangeKind.removed => "-",
                            RevisionChangeKind.modified => "Modified",
                          }}",
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        if (field.oldExists)
                          Text(
                            "- ${_display(field.oldValue)}",
                            style: TextStyle(color: Colors.red.shade700),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (field.newExists)
                          Text(
                            "+ ${_display(field.newValue)}",
                            style: TextStyle(color: Colors.green.shade700),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        _reviewActions(field),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _reviewActions(RevisionFieldChange? field) {
    if (onAccept == null) return const SizedBox.shrink();
    final key = RevisionReviewService.recordKey(baseline, record, field);
    final accepted = acceptedEvents.contains(key);
    return Wrap(
      spacing: 4,
      children: [
        TextButton(
          onPressed: () =>
              accepted ? onUnaccept?.call(key) : onAccept?.call(key),
          child: Text(accepted ? "取消接受" : "接受"),
        ),
        if (!accepted &&
            onReject != null &&
            field != null &&
            RevisionReviewService.canRejectField(record, field))
          TextButton(
            onPressed: () => onReject!(field),
            child: const Text("拒絕"),
          ),
      ],
    );
  }
}
