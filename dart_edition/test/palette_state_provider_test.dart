import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/data/repositories/palette_repository.dart";
import "package:monogatari_assistant/models/palette_data.dart";
import "package:monogatari_assistant/presentation/providers/palette_state_provider.dart";

class _MemoryPaletteRepository implements PaletteRepository {
  String? userData;
  String seedData = '{"version":1,"slotEntryIds":{},"entries":{}}';
  int writeCount = 0;

  @override
  Future<String?> readUserData() async => userData;

  @override
  Future<String> readSeedData() async => seedData;

  @override
  Future<void> writeUserData(String content) async {
    userData = content;
    writeCount++;
  }
}

void main() {
  test("loads seed and persists mutations", () async {
    final _MemoryPaletteRepository repository = _MemoryPaletteRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [paletteRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final PaletteStateNotifier notifier = container.read(
      paletteStateProvider.notifier,
    );

    final PaletteLoadResult loadResult = await notifier.loadFromRepository();
    expect(loadResult.usedSeed, isTrue);

    final PaletteMutationResult added = notifier.addEntry(
      slotId: "h000-s100-v020",
      text: "焦灼",
    );
    expect(added.changed, isTrue);
    expect(
      notifier.addEntry(slotId: "h000-s100-v020", text: " 焦灼 ").error,
      "此色格已有相同詞條",
    );

    await notifier.flushPalettePersistence();
    final PaletteDecodeResult persisted = PaletteDataCodec.decode(
      repository.userData!,
    );
    expect(persisted.data.entryIndex[added.entryId]?.text, "焦灼");
    expect(repository.writeCount, greaterThanOrEqualTo(1));
  });

  test("renames, sorts, removes, and restores entries", () async {
    final _MemoryPaletteRepository repository = _MemoryPaletteRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [paletteRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final PaletteStateNotifier notifier = container.read(
      paletteStateProvider.notifier,
    );
    await notifier.loadFromRepository();

    final String firstId = notifier
        .addEntry(slotId: "h000-s100-v020", text: "B")
        .entryId!;
    final String secondId = notifier
        .addEntry(slotId: "h000-s100-v020", text: "A")
        .entryId!;
    expect(notifier.sortSlotByText("h000-s100-v020"), isTrue);
    expect(
      container.read(paletteStateProvider).slotEntryIds["h000-s100-v020"],
      <String>[secondId, firstId],
    );

    expect(notifier.renameEntry(entryId: firstId, text: "C").changed, isTrue);
    final PaletteEntryRemovalRecord? record = notifier.removeEntry(secondId);
    expect(record, isNotNull);
    expect(
      container.read(paletteStateProvider).entryIndex,
      isNot(contains(secondId)),
    );
    expect(notifier.restoreEntry(record!), isTrue);
    expect(container.read(paletteStateProvider).entryIndex, contains(secondId));
  });
}
