import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

import "package:monogatari_assistant/modules/baseinfoview.dart";
import "package:monogatari_assistant/modules/chapterselectionview.dart";
import "package:monogatari_assistant/modules/characterview.dart";
import "package:monogatari_assistant/modules/outlineview.dart";
import "package:monogatari_assistant/modules/planview.dart";
import "package:monogatari_assistant/modules/worldsettingsview.dart";
import "package:monogatari_assistant/presentation/providers/global_state_providers.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";

class _TestSettingsStateNotifier extends SettingsStateNotifier {
  @override
  Future<AppSettingsStateData> build() async {
    return const AppSettingsStateData();
  }
}

const MethodChannel _pathProviderChannel = MethodChannel(
  "plugins.flutter.io/path_provider",
);

Finder _textFieldByHint(String hintText) {
  return find.byWidgetPredicate((widget) {
    return widget is TextField && widget.decoration?.hintText == hintText;
  });
}

ProviderContainer _createContainer() {
  return ProviderContainer(
    overrides: [
      settingsStateProvider.overrideWith(_TestSettingsStateNotifier.new),
    ],
  );
}

Widget _buildHarness({
  required ProviderContainer container,
  required Widget child,
  bool wrapInScaffold = false,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: wrapInScaffold ? Scaffold(body: child) : child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (methodCall) async {
      final tempPath = Directory.systemTemp.path;
      switch (methodCall.method) {
        case "getTemporaryDirectory":
        case "getApplicationDocumentsDirectory":
        case "getApplicationSupportDirectory":
        case "getLibraryDirectory":
        case "getDownloadsDirectory":
        case "getExternalStorageDirectory":
          return tempPath;
        case "getExternalCacheDirectories":
        case "getExternalStorageDirectories":
          return <String>[tempPath];
        default:
          return tempPath;
      }
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
  });

  group("Phase 2 widget interaction validation", () {
    testWidgets("BaseInfoView updates baseInfoDataProvider after editing book name", (tester) async {
      final container = _createContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHarness(container: container, child: const BaseInfoView()),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await tester.enterText(_textFieldByHint("輸入書名"), "測試書名");
      await tester.pump(const Duration(milliseconds: 120));

      expect(container.read(baseInfoDataProvider).bookName, "測試書名");
    });

    testWidgets("ChapterSelectionView updates segmentsDataProvider after adding a segment", (tester) async {
      final container = _createContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHarness(container: container, child: const ChapterSelectionView()),
      );
      await tester.pump(const Duration(milliseconds: 250));

      await tester.enterText(_textFieldByHint("新增區段"), "測試區段");
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 150));

      final segments = container.read(segmentsDataProvider);
      expect(segments.any((segment) => segment.segmentName == "測試區段"), isTrue);
    });

    testWidgets("OutlineAdjustView updates outlineDataProvider after adding a storyline", (tester) async {
      final container = _createContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHarness(
          container: container,
          child: OutlineAdjustView(onStorylineChanged: (_) {}),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      await tester.enterText(_textFieldByHint("新增故事線名稱"), "主線A");
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 150));

      final outline = container.read(outlineDataProvider);
      expect(outline.any((storyline) => storyline.storylineName == "主線A"), isTrue);
    });

    testWidgets("WorldSettingsView updates worldSettingsDataProvider after adding a top-level location", (tester) async {
      final container = _createContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHarness(container: container, child: const WorldSettingsView()),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(_textFieldByHint("新增頂層地點"), "東京");
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 150));

      final locations = container.read(worldSettingsDataProvider);
      expect(locations.any((location) => location.localName == "東京"), isTrue);
    });

    testWidgets("CharacterView triggers provider update callback after adding a character", (tester) async {
      final container = _createContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHarness(
          container: container,
          wrapInScaffold: true,
          child: CharacterView(
            onDataChanged: (nextCharacterData) {
              container
                  .read(characterDataProvider.notifier)
                  .setCharacterData(nextCharacterData);
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      await tester.enterText(_textFieldByHint("新增角色名稱"), "Alice");
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 150));

      final characterData = container.read(characterDataProvider);
      expect(characterData.containsKey("Alice"), isTrue);
    });

    testWidgets("PlanView updates foreshadowDataProvider after adding a foreshadow item", (tester) async {
      final container = _createContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHarness(container: container, child: const PlanView()),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.enterText(_textFieldByHint("新增新增伏筆"), "伏筆A");
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 200));

      final foreshadows = container.read(foreshadowDataProvider);
      expect(foreshadows.any((item) => item.title == "伏筆A"), isTrue);
    });
  });
}
