import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../presentation/providers/project_state_providers.dart';
import 'phrase_entry.dart';
import 'phrase_library_codec.dart';
import 'phrase_transfer.dart';

final class GlobalPhrasesNotifier extends AsyncNotifier<List<PhraseEntry>> {
  static const _storageKey = 'global_phrase_library_v1';

  @override
  Future<List<PhraseEntry>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final source = prefs.getString(_storageKey);
    if (source == null) return const [];
    final phrases = PhraseLibraryCodec.decode(source);
    if (phrases.any(phraseHasMention)) {
      throw const FormatException('全域短語庫包含 Mention，請先修復資料');
    }
    return phrases;
  }

  Future<void> setPhrases(Iterable<PhraseEntry> phrases) async {
    final entries = List<PhraseEntry>.unmodifiable(phrases);
    validatePhraseLibrary(entries);
    if (entries.any(phraseHasMention)) {
      throw const FormatException('含 Mention 的短語只能儲存在目前專案');
    }
    await future;
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      _storageKey,
      PhraseLibraryCodec.encode(entries),
    );
    if (!saved) throw StateError('無法儲存全域短語庫');
    state = AsyncData(entries);
  }
}

final globalPhrasesProvider =
    AsyncNotifierProvider<GlobalPhrasesNotifier, List<PhraseEntry>>(
      GlobalPhrasesNotifier.new,
    );

final availablePhrasesProvider = Provider<List<PhraseEntry>>((ref) {
  return availablePhrases(
    ref.watch(phrasesProvider),
    ref.watch(globalPhrasesProvider).valueOrNull ?? const [],
  );
});
