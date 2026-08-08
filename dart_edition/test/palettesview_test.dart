import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/data/repositories/palette_repository.dart";
import "package:monogatari_assistant/bin/ui_library.dart";
import "package:monogatari_assistant/modules/palettesview.dart";
import "package:monogatari_assistant/presentation/providers/palette_state_provider.dart";

class _WidgetPaletteRepository implements PaletteRepository {
  String? userData;
  int writeCount = 0;

  @override
  Future<String?> readUserData() async => userData;

  @override
  Future<String> readSeedData() async {
    return '{"version":1,"slotEntryIds":{},"entries":{}}';
  }

  @override
  Future<void> writeUserData(String content) async {
    userData = content;
    writeCount++;
  }
}

void main() {
  testWidgets("adds and searches a palette chip", (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final _WidgetPaletteRepository repository = _WidgetPaletteRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [paletteRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scaffold(body: PalettesView())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("文字調色盤"), findsOneWidget);
    expect(find.byType(AppTextField), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>("palette-hue-342")),
      findsOneWidget,
    );
    final ChoiceChip hueButton = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey<String>("palette-hue-342")),
    );
    final Color expectedHueColor = HSVColor.fromAHSV(1, 342, 0.8, 1).toColor();
    expect(hueButton.backgroundColor, expectedHueColor);
    expect(hueButton.selectedColor, expectedHueColor);

    await tester.tap(find.text("S 100% · V 20%").first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>("palette-add-h000-s100-v020")),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey<String>("palette-editor-add-h000-s100-v020")),
      "焦灼",
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text("焦灼"), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey<String>("palette-search-field")),
      "焦",
    );
    await tester.pump();
    expect(find.text("焦灼"), findsOneWidget);
    expect(find.text("色相 0 度，飽和度 100%，明度 20%"), findsOneWidget);
  });

  testWidgets("does not overwrite a corrupt user file", (
    WidgetTester tester,
  ) async {
    final _WidgetPaletteRepository repository = _WidgetPaletteRepository()
      ..userData = "not-json";

    await tester.pumpWidget(
      ProviderScope(
        overrides: [paletteRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scaffold(body: PalettesView())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("調色盤載入失敗"), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(repository.userData, "not-json");
    expect(repository.writeCount, 0);
  });
}
