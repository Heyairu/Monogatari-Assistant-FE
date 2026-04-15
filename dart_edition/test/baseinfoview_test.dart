import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/modules/baseinfoview.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";
import "package:shared_preferences/shared_preferences.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets("BaseInfoView writes text input back to provider state", (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: BaseInfoView(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final firstField = find.byType(TextField).first;
    await tester.enterText(firstField, "新書名");
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(BaseInfoView)));
    expect(container.read(baseInfoDataProvider).bookName, "新書名");
  });
}
