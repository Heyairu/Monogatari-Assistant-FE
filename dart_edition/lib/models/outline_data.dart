import "package:freezed_annotation/freezed_annotation.dart";
import "package:uuid/uuid.dart";

part "outline_data.freezed.dart";

String _generateOutlineId() {
  return const Uuid().v4();
}

@Freezed(equal: false)
class StorylineData with _$StorylineData {
  const StorylineData._();

  const factory StorylineData.raw({
    @Default("") String storylineName,
    @Default("") String storylineType,
    @Default(<StoryEventData>[]) List<StoryEventData> scenes,
    @Default("") String memo,
    @Default("") String conflictPoint,
    @Default(<String>[]) List<String> people,
    @Default(<String>[]) List<String> item,
    required String chapterUUID,
  }) = _StorylineData;

  factory StorylineData({
    String storylineName = "",
    String storylineType = "",
    List<StoryEventData>? scenes,
    String memo = "",
    String conflictPoint = "",
    List<String>? people,
    List<String>? item,
    String? chapterUUID,
  }) {
    final resolvedUUID = chapterUUID?.trim().isNotEmpty == true
        ? chapterUUID!.trim()
        : _generateOutlineId();

    return StorylineData.raw(
      storylineName: storylineName,
      storylineType: storylineType,
      scenes: scenes ?? const <StoryEventData>[],
      memo: memo,
      conflictPoint: conflictPoint,
      people: people ?? const <String>[],
      item: item ?? const <String>[],
      chapterUUID: resolvedUUID,
    );
  }

  String get id => chapterUUID;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StorylineData &&
            runtimeType == other.runtimeType &&
            chapterUUID == other.chapterUUID;
  }

  @override
  int get hashCode => chapterUUID.hashCode;
}

@Freezed(equal: false)
class StoryEventData with _$StoryEventData {
  const StoryEventData._();

  const factory StoryEventData.raw({
    @Default("") String storyEvent,
    @Default(<SceneData>[]) List<SceneData> scenes,
    @Default("") String memo,
    @Default("") String conflictPoint,
    @Default(<String>[]) List<String> people,
    @Default(<String>[]) List<String> item,
    required String storyEventUUID,
  }) = _StoryEventData;

  factory StoryEventData({
    String storyEvent = "",
    List<SceneData>? scenes,
    String memo = "",
    String conflictPoint = "",
    List<String>? people,
    List<String>? item,
    String? storyEventUUID,
  }) {
    final resolvedUUID = storyEventUUID?.trim().isNotEmpty == true
        ? storyEventUUID!.trim()
        : _generateOutlineId();

    return StoryEventData.raw(
      storyEvent: storyEvent,
      scenes: scenes ?? const <SceneData>[],
      memo: memo,
      conflictPoint: conflictPoint,
      people: people ?? const <String>[],
      item: item ?? const <String>[],
      storyEventUUID: resolvedUUID,
    );
  }

  String get id => storyEventUUID;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StoryEventData &&
            runtimeType == other.runtimeType &&
            storyEventUUID == other.storyEventUUID;
  }

  @override
  int get hashCode => storyEventUUID.hashCode;
}

@Freezed(equal: false)
class SceneData with _$SceneData {
  const SceneData._();

  const factory SceneData.raw({
    @Default("") String sceneName,
    @Default("") String time,
    String? timePointIso8601,
    @Default("") String location,
    @Default("") String focusPoint,
    @Default("") String conflictPoint,
    @Default(<String>[]) List<String> people,
    @Default(<String>[]) List<String> item,
    @Default(<String>[]) List<String> doingThings,
    @Default("") String memo,
    required String sceneUUID,
  }) = _SceneData;

  factory SceneData({
    String sceneName = "",
    String time = "",
    String? timePointIso8601,
    String location = "",
    String focusPoint = "",
    String conflictPoint = "",
    List<String>? people,
    List<String>? item,
    List<String>? doingThings,
    String memo = "",
    String? sceneUUID,
  }) {
    final resolvedUUID = sceneUUID?.trim().isNotEmpty == true
        ? sceneUUID!.trim()
        : _generateOutlineId();

    final resolvedTimePoint = timePointIso8601?.trim().isNotEmpty == true
        ? timePointIso8601!.trim()
        : DateTime.tryParse(time)?.toIso8601String();

    return SceneData.raw(
      sceneName: sceneName,
      time: time,
      timePointIso8601: resolvedTimePoint,
      location: location,
      focusPoint: focusPoint,
      conflictPoint: conflictPoint,
      people: people ?? const <String>[],
      item: item ?? const <String>[],
      doingThings: doingThings ?? const <String>[],
      memo: memo,
      sceneUUID: resolvedUUID,
    );
  }

  String get id => sceneUUID;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SceneData &&
            runtimeType == other.runtimeType &&
            sceneUUID == other.sceneUUID;
  }

  @override
  int get hashCode => sceneUUID.hashCode;
}
