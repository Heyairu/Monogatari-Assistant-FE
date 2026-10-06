import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monogatari_assistant/features/phrases/global_phrases_provider.dart';
import 'package:monogatari_assistant/features/phrases/phrase_entry.dart';
import 'package:monogatari_assistant/features/phrases/phrase_transfer.dart';
import 'package:monogatari_assistant/presentation/providers/project_state_providers.dart';

PhraseEntry entry(String id, String shortcut, String body) => PhraseEntry(
  id: id,
  name: shortcut,
  shortcut: shortcut,
  body: body,
  createdAt: DateTime.utc(2026, 10, 2),
  updatedAt: DateTime.utc(2026, 10, 2),
);

void main() {
  const globalId = '6f6cbb80-0988-47b5-9ec6-14649c19b1b2';
  const projectId = 'f77ed855-8cc6-40eb-b529-ab2d40b01ad1';
  const mention = '//@<4e251fc2-1e2b-4f78-93da-91f8c76d9a92|艾莉絲>//';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'global phrases survive project changes and provider recreation',
    () async {
      final container = ProviderContainer();
      await container.read(globalPhrasesProvider.future);
      await container.read(globalPhrasesProvider.notifier).setPhrases([
        entry(globalId, 'Hello', '你好'),
      ]);
      container.read(phrasesProvider.notifier).setPhrases([
        entry(projectId, 'Scene', '場景'),
      ]);
      expect(container.read(availablePhrasesProvider), hasLength(2));
      container.read(phrasesProvider.notifier).setPhrases([]);
      expect(container.read(availablePhrasesProvider).single.shortcut, 'Hello');
      container.dispose();

      final reopened = ProviderContainer();
      addTearDown(reopened.dispose);
      expect(await reopened.read(globalPhrasesProvider.future), hasLength(1));
      expect(reopened.read(availablePhrasesProvider).single.id, globalId);
    },
  );

  test(
    'project shortcut wins over global and mentions cannot be global',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(globalPhrasesProvider.future);
      await container.read(globalPhrasesProvider.notifier).setPhrases([
        entry(globalId, 'Hello', '通用'),
      ]);
      container.read(phrasesProvider.notifier).setPhrases([
        entry(projectId, 'hello', '專案'),
      ]);
      expect(container.read(availablePhrasesProvider).single.id, projectId);
      await expectLater(
        container.read(globalPhrasesProvider.notifier).setPhrases([
          entry(globalId, 'Hello', mention),
        ]),
        throwsFormatException,
      );
      expect(container.read(globalPhrasesProvider).value!.single.body, '通用');
    },
  );

  test('transfer keeps scope and forces mentions into current project', () {
    final source = PhraseTransferCodec.encode([
      ScopedPhrase(entry(globalId, 'Hello', '通用'), PhraseScope.global),
      ScopedPhrase(entry(projectId, 'Scene', mention), PhraseScope.project),
    ]);
    final decoded = PhraseTransferCodec.decode(source);
    expect(decoded.map((item) => item.scope), [
      PhraseScope.global,
      PhraseScope.project,
    ]);
    expect(phraseHasMention(decoded.last.phrase), isTrue);
    expect(decoded.last.phrase.requiresRelink, isTrue);
    expect(
      () => PhraseTransferCodec.encode([
        ScopedPhrase(entry(projectId, 'Scene', mention), PhraseScope.global),
      ]),
      throwsFormatException,
    );
  });

  test('conflicting shortcuts can be copied with a valid unique suffix', () {
    final original = entry(globalId, '12345678901234567890123456789012', '一');
    final shortcut = nextAvailableShortcut(original.shortcut, [original]);
    expect(shortcut, '123456789012345678901234567890_2');
    expect(PhraseEntry.isValidShortcut(shortcut), isTrue);
  });

  test('import conflict choices preserve unrelated phrases', () {
    final original = entry(globalId, 'hello', '舊');
    final unrelated = entry(projectId, 'scene', '場景');
    final incoming = ScopedPhrase(
      entry('66054514-d456-40eb-97c5-5e771a6c44ee', 'HELLO', '新'),
      PhraseScope.global,
    );
    final projects = [unrelated];
    final globals = [original];

    expect(
      applyPhraseImport(
        incoming: incoming,
        projects: projects,
        globals: globals,
        choice: PhraseImportChoice.skip,
      ),
      isNull,
    );
    expect(globals.single.body, '舊');

    final copied = applyPhraseImport(
      incoming: incoming,
      projects: projects,
      globals: globals,
      choice: PhraseImportChoice.copy,
      copyId: 'a8014821-5f91-49a1-ae29-deb057683dde',
    );
    expect(copied?.shortcut, 'HELLO_2');
    expect(globals.map((item) => item.body), ['舊', '新']);

    applyPhraseImport(
      incoming: incoming,
      projects: projects,
      globals: globals,
      choice: PhraseImportChoice.replace,
    );
    expect(globals.map((item) => item.shortcut), ['HELLO_2', 'HELLO']);
    expect(projects.single.id, unrelated.id);
  });
}
