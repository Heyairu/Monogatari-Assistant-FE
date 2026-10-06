import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monogatari_assistant/bin/file.dart';
import 'package:monogatari_assistant/features/inline_annotations/inline_annotation.dart';
import 'package:monogatari_assistant/features/inline_annotations/mosaic_editing_controller.dart';
import 'package:monogatari_assistant/features/phrases/phrase_body_validator.dart';
import 'package:monogatari_assistant/features/phrases/phrase_display_preview.dart';
import 'package:monogatari_assistant/features/phrases/phrase_entry.dart';
import 'package:monogatari_assistant/features/phrases/phrase_insertion_service.dart';
import 'package:monogatari_assistant/features/phrases/phrase_library_codec.dart';
import 'package:monogatari_assistant/features/phrases/phrase_search_index.dart';

const phraseId = '8f680e3c-90c1-4f37-ae35-f70c4dc7fe8f';
const characterId = '4e251fc2-1e2b-4f78-93da-91f8c76d9a92';
const mosaicMention = '//@<$characterId|艾莉絲>//';

PhraseEntry phrase({
  String body = '你好，$mosaicMention',
  String shortcut = 'Hello',
}) => PhraseEntry(
  id: phraseId,
  name: '問候',
  shortcut: shortcut,
  body: body,
  createdAt: DateTime.utc(2026, 9, 30),
  updatedAt: DateTime.utc(2026, 9, 30),
);

void main() {
  test('Mosaic preview keeps only its symbol and display text', () {
    expect(phraseDisplayPreview('前 $mosaicMention 後'), '前 @艾莉絲 後');
    expect(phraseDisplayPreview('文字 //^<重點>//'), '文字 ^重點');
  });

  test('phrase codec preserves Mosaic raw body and enforces shortcuts', () {
    final entry = phrase(body: '第一行\n$mosaicMention\\/第二行');
    final decoded = PhraseLibraryCodec.decode(
      PhraseLibraryCodec.encode([entry]),
    );
    expect(decoded.single.body, entry.body);
    expect(decoded.single.normalizedShortcut, 'hello');
    expect(
      () => validatePhraseLibrary([entry, phrase(shortcut: 'hello')]),
      throwsFormatException,
    );
  });

  test(
    'search index ranks shortcut before body and excludes disabled entries',
    () {
      final exact = phrase(shortcut: 'bell', body: '鐘聲');
      final other = PhraseEntry(
        id: '33216d48-feb2-4a8c-b987-740a1a9c45e6',
        name: '鐘聲場景',
        shortcut: 'scene',
        body: 'bell $mosaicMention',
        createdAt: DateTime.utc(2026, 9, 30),
        updatedAt: DateTime.utc(2026, 9, 30),
      );
      final disabled = PhraseEntry(
        id: '92bcb303-48b6-4f70-a7c5-b113d45ec61d',
        name: '停用',
        shortcut: 'bell-hidden',
        body: 'bell',
        enabled: false,
        createdAt: DateTime.utc(2026, 9, 30),
        updatedAt: DateTime.utc(2026, 9, 30),
      );
      final results = PhraseSearchIndex([
        other,
        disabled,
        exact,
      ]).search('bell');
      expect(results.map((result) => result.phrase.id), [exact.id, other.id]);
      expect(results.last.preview, contains('艾莉絲'));
    },
  );

  test('validator catches malformed Mosaic that parser would omit', () {
    const validator = PhraseBodyValidator();
    expect(validator.validate('文字 $mosaicMention').isValid, isTrue);
    expect(validator.validate('文字 //@<bad|艾莉絲>//').isValid, isFalse);
    expect(validator.validate(r'字面 \/\/@<bad|艾莉絲>//').isValid, isTrue);
  });

  test('project XML round trip carries phrases and older XML reads empty', () {
    final project = ProjectData.empty()..phrases = [phrase()];
    final xml = FileService.generateProjectXMLWithoutLatestSaveUpdate(project);
    expect(FileService.parseProjectXML(xml).phrases.single.body, phrase().body);

    final older = FileService.generateProjectXMLWithoutLatestSaveUpdate(
      ProjectData.empty(),
    );
    expect(FileService.parseProjectXML(older).phrases, isEmpty);
  });

  test('unreadable phrase payload survives a project save', () {
    final project = ProjectData.empty()
      ..phrasesRecoveryPayload = '%%%future-payload%%%';
    final xml = FileService.generateProjectXMLWithoutLatestSaveUpdate(project);
    final restored = FileService.parseProjectXML(xml);
    expect(restored.phrases, isEmpty);
    expect(restored.phrasesRecoveryPayload, '%%%future-payload%%%');
    restored.phrases = [phrase()];
    final saved = FileService.generateProjectXMLWithoutLatestSaveUpdate(
      restored,
    );
    final reopened = FileService.parseProjectXML(saved);
    expect(reopened.phrases.single.id, phraseId);
    expect(reopened.phrasesRecoveryPayload, '%%%future-payload%%%');
  });

  test('insertion is atomic and refuses stale prepared edits', () {
    final controller = MosaicEditingController(rawText: '前後');
    addTearDown(controller.dispose);
    final prepared = const PhraseInsertionService().prepare(
      phrase: phrase(body: mosaicMention),
      controller: controller,
      displaySelection: const TextSelection.collapsed(offset: 1),
      targetExists: (kind, id) =>
          kind == InlineAnnotationKind.character && id == characterId,
    );
    expect(prepared.missingMentions, isEmpty);
    expect(
      const PhraseInsertionService().commit(
        prepared: prepared,
        controller: controller,
        targetExists: (kind, id) => id == characterId,
      ),
      isTrue,
    );
    expect(controller.rawText, '前$mosaicMention後');

    final stale = const PhraseInsertionService().prepare(
      phrase: phrase(),
      controller: controller,
      displaySelection: const TextSelection.collapsed(offset: 0),
      targetExists: (kind, id) => id == characterId,
    );
    controller.replaceRawRange(const TextRange(start: 0, end: 0), '新');
    expect(
      const PhraseInsertionService().commit(
        prepared: stale,
        controller: controller,
        targetExists: (kind, id) => id == characterId,
      ),
      isFalse,
    );
  });

  test('insertion rechecks Mention existence at commit', () {
    final controller = MosaicEditingController(rawText: '正文');
    addTearDown(controller.dispose);
    final prepared = const PhraseInsertionService().prepare(
      phrase: phrase(body: mosaicMention),
      controller: controller,
      displaySelection: const TextSelection.collapsed(offset: 2),
      targetExists: (kind, id) => true,
    );
    expect(
      () => const PhraseInsertionService().commit(
        prepared: prepared,
        controller: controller,
        targetExists: (kind, id) => false,
      ),
      throwsStateError,
    );
    expect(controller.rawText, '正文');
  });

  test('missing Mention needs a decision and can be flattened', () {
    final controller = MosaicEditingController(rawText: '正文');
    addTearDown(controller.dispose);
    final prepared = const PhraseInsertionService().prepare(
      phrase: phrase(body: mosaicMention),
      controller: controller,
      displaySelection: const TextSelection.collapsed(offset: 2),
      targetExists: (kind, id) => false,
    );
    expect(prepared.missingMentions, hasLength(1));
    expect(
      () => const PhraseInsertionService().commit(
        prepared: prepared,
        controller: controller,
        targetExists: (kind, id) => false,
      ),
      throwsStateError,
    );
    expect(
      const PhraseInsertionService().commit(
        prepared: prepared,
        controller: controller,
        targetExists: (kind, id) => false,
        resolutions: {0: const FlattenPhraseMention()},
      ),
      isTrue,
    );
    expect(controller.rawText, '正文艾莉絲');
  });

  test('foreign phrase requires relink even when an ID exists locally', () {
    final foreign = PhraseEntry.fromJson({
      ...phrase(body: mosaicMention).toJson(),
      'requiresRelink': true,
    });
    final controller = MosaicEditingController(rawText: '正文');
    addTearDown(controller.dispose);
    final prepared = const PhraseInsertionService().prepare(
      phrase: foreign,
      controller: controller,
      displaySelection: const TextSelection.collapsed(offset: 2),
      targetExists: (kind, id) => id == characterId,
    );
    expect(prepared.missingMentions, hasLength(1));
    expect(
      const PhraseInsertionService().commit(
        prepared: prepared,
        controller: controller,
        targetExists: (kind, id) => id == characterId,
        resolutions: {0: const RelinkPhraseMention(characterId)},
      ),
      isTrue,
    );
    expect(controller.rawText, '正文$mosaicMention');
  });

  test('partial Mention selection expands to its full raw syntax', () {
    final controller = MosaicEditingController(rawText: '前$mosaicMention後');
    addTearDown(controller.dispose);
    final labelStart = controller.displayText.indexOf('艾莉絲');
    final prepared = const PhraseInsertionService().prepare(
      phrase: phrase(body: '替代'),
      controller: controller,
      displaySelection: TextSelection(
        baseOffset: labelStart,
        extentOffset: labelStart + 1,
      ),
      targetExists: (kind, id) => true,
    );
    expect(prepared.rawRange.start, 1);
    expect(prepared.rawRange.end, 1 + mosaicMention.length);
    expect(
      const PhraseInsertionService().commit(
        prepared: prepared,
        controller: controller,
        targetExists: (kind, id) => true,
      ),
      isTrue,
    );
    expect(controller.rawText, '前替代後');
  });
}
