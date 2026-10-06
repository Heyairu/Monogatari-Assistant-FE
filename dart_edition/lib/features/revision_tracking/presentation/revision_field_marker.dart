import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../ui_library/spacing.dart";
import "../../../domain/collaboration/typed_operation_log.dart";
import "../../../presentation/providers/revision_tracking_provider.dart";
import "../application/revision_review_service.dart";
import "../domain/revision_models.dart";
import "../domain/revision_target.dart";

/// A field marker reads the same comparison as the revision pane.
class RevisionFieldMarker extends ConsumerWidget {
  final ProjectRecordKey recordKey;
  final String field;
  const RevisionFieldMarker({
    super.key,
    required this.recordKey,
    required this.field,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(revisionTrackingProvider);
    if (state.status != RevisionComparisonStatus.complete) {
      return const SizedBox.shrink();
    }
    RevisionFieldChange? change;
    RevisionRecordChange? containingRecord;
    for (final record
        in state.comparison?.records ?? <RevisionRecordChange>[]) {
      if (record.key != recordKey) continue;
      for (final candidate in record.fields) {
        if (candidate.target.fieldPath.length == 1 &&
            candidate.target.fieldPath.single == field) {
          change = candidate;
          containingRecord = record;
          break;
        }
      }
      break;
    }
    if (change == null) return const SizedBox.shrink();
    if (!state.showAccepted &&
        containingRecord != null &&
        state.acceptedEvents.contains(
          RevisionReviewService.recordKey(
            state.baseline!,
            containingRecord,
            change,
          ),
        )) {
      return const SizedBox.shrink();
    }
    final kind = change.kind;
    final label = switch (kind) {
      RevisionChangeKind.added => "+",
      RevisionChangeKind.removed => "−",
      RevisionChangeKind.modified => "*",
    };
    final color = switch (kind) {
      RevisionChangeKind.added => Colors.green.shade700,
      RevisionChangeKind.removed => Colors.red.shade700,
      RevisionChangeKind.modified => Colors.orange.shade800,
    };
    return Semantics(
      label: "$field 修訂：$label",
      button: true,
      child: TextButton(
        onPressed: () => ref
            .read(revisionTrackingProvider.notifier)
            .select(RevisionTarget.field(recordKey, [field])),
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          minimumSize: const Size(32, 24),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}

class RevisionRecordMarker extends ConsumerWidget {
  final ProjectRecordKey recordKey;
  const RevisionRecordMarker({super.key, required this.recordKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(revisionTrackingProvider);
    if (state.status != RevisionComparisonStatus.complete) {
      return const SizedBox.shrink();
    }
    final matches = state.comparison?.records.where(
      (record) => record.key == recordKey,
    );
    if (matches == null || matches.isEmpty) return const SizedBox.shrink();
    final record = matches.first;
    final fullyAccepted = record.fields.isEmpty
        ? state.acceptedEvents.contains(
            RevisionReviewService.recordKey(state.baseline!, record, null),
          )
        : record.fields.every(
            (field) => state.acceptedEvents.contains(
              RevisionReviewService.recordKey(state.baseline!, record, field),
            ),
          );
    if (!state.showAccepted && fullyAccepted) {
      return const SizedBox.shrink();
    }
    final label = switch (record.kind) {
      RevisionChangeKind.added => "+",
      RevisionChangeKind.removed => "−",
      RevisionChangeKind.modified => "Modified",
    };
    return Semantics(
      label: "項目修訂：$label",
      button: true,
      child: TextButton(
        onPressed: () => ref
            .read(revisionTrackingProvider.notifier)
            .select(RevisionTarget.field(recordKey, const [])),
        style: TextButton.styleFrom(minimumSize: const Size(32, 24)),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}
