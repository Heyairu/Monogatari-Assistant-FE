import "package:freezed_annotation/freezed_annotation.dart";

import "../bin/content_manager.dart";
import "../bin/settings_manager.dart";

part "base_info_data.freezed.dart";

@freezed
class BaseInfoData with _$BaseInfoData {
  const BaseInfoData._();

  const factory BaseInfoData({
    @Default("") String bookName,
    @Default("") String author,
    @Default("") String purpose,
    @Default("") String toRecap,
    @Default("") String storyType,
    @Default("") String intro,
    @Default(<String>[]) List<String> tags,
    DateTime? latestSave,
    @Default(0) int nowWords,
  }) = _BaseInfoData;

  bool get isEffectivelyEmpty {
    return bookName.trim().isEmpty &&
        author.trim().isEmpty &&
        storyType.trim().isEmpty &&
        intro.trim().isEmpty &&
        tags.isEmpty;
  }

  BaseInfoData withRecalculatedNowWords(
    String content, {
    WordCountMode mode = WordCountMode.characters,
  }) {
    return copyWith(
      nowWords: ContentManager.calculateWordCount(content, mode: mode),
    );
  }
}
