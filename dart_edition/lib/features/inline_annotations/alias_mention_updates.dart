import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";

import "inline_annotation.dart";
import "inline_annotation_parser.dart";
import "inline_annotation_syntax.dart";

final aliasMentionUpdatesEnabledProvider =
    AsyncNotifierProvider<AliasMentionUpdatesSettings, bool>(
      AliasMentionUpdatesSettings.new,
    );

class AliasMentionUpdatesSettings extends AsyncNotifier<bool> {
  static const preferenceKey = "alias_mention_updates_enabled";

  @override
  Future<bool> build() async =>
      (await SharedPreferences.getInstance()).getBool(preferenceKey) ?? true;

  Future<void> setEnabled(bool enabled) async {
    await future;
    await (await SharedPreferences.getInstance()).setBool(
      preferenceKey,
      enabled,
    );
    state = AsyncData(enabled);
  }
}

class AliasRename {
  final String characterId;
  final String oldName;
  final String newName;
  final bool isPrimaryName;
  const AliasRename(
    this.characterId,
    this.oldName,
    this.newName, {
    this.isPrimaryName = false,
  });
}

final aliasRenameProvider = StateProvider<AliasRename?>((ref) => null);

String rewriteAliasMentions(String raw, AliasRename rename) {
  if (rename.oldName == rename.newName || rename.newName.trim().isEmpty) {
    return raw;
  }
  final matches = const InlineAnnotationParser().parse(raw);
  var result = raw;
  for (final annotation in matches.reversed) {
    if (annotation.kind != InlineAnnotationKind.character ||
        annotation.targetId != rename.characterId ||
        annotation.displayText != rename.oldName) {
      continue;
    }
    result = result.replaceRange(
      annotation.displayTextSourceRange.start,
      annotation.displayTextSourceRange.end,
      InlineAnnotationSyntax.escape(rename.newName),
    );
  }
  return result;
}
