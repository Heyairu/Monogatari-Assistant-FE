import "package:freezed_annotation/freezed_annotation.dart";
import "package:uuid/uuid.dart";

part "plan_data.freezed.dart";

String _generatePlanId() {
  return const Uuid().v4();
}

@freezed
class ForeshadowItem with _$ForeshadowItem {
  const ForeshadowItem._();

  const factory ForeshadowItem.raw({
    required String id,
    @Default("") String title,
    @Default("") String note,
    @Default(false) bool isRevealed,
  }) = _ForeshadowItem;

  factory ForeshadowItem({
    String? id,
    String title = "",
    String note = "",
    bool isRevealed = false,
  }) {
    final resolvedId = id?.trim().isNotEmpty == true
        ? id!.trim()
        : _generatePlanId();

    return ForeshadowItem.raw(
      id: resolvedId,
      title: title,
      note: note,
      isRevealed: isRevealed,
    );
  }
}

@freezed
class UpdatePlanItem with _$UpdatePlanItem {
  const UpdatePlanItem._();

  const factory UpdatePlanItem.raw({
    required String id,
    @Default("") String title,
    @Default("") String note,
    @Default(false) bool isDone,
  }) = _UpdatePlanItem;

  factory UpdatePlanItem({
    String? id,
    String title = "",
    String note = "",
    bool isDone = false,
  }) {
    final resolvedId = id?.trim().isNotEmpty == true
        ? id!.trim()
        : _generatePlanId();

    return UpdatePlanItem.raw(
      id: resolvedId,
      title: title,
      note: note,
      isDone: isDone,
    );
  }
}

@freezed
class PlanProjectData with _$PlanProjectData {
  const factory PlanProjectData({
    @Default(<ForeshadowItem>[]) List<ForeshadowItem> foreshadows,
    @Default(<UpdatePlanItem>[]) List<UpdatePlanItem> updatePlans,
  }) = _PlanProjectData;
}
