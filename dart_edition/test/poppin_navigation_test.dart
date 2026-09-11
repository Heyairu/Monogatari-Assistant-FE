import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/poppin/poppin.dart";

void main() {
  late PoppinNavigation<_Entry> navigation;

  setUp(() {
    navigation = PoppinNavigation<_Entry>(
      childrenOf: (entry) => entry.children,
      labelOf: (entry) => entry.label,
    );
  });

  test("moves cyclically through the active level", () {
    navigation.reset(const [_Entry("one"), _Entry("two"), _Entry("three")]);

    expect(navigation.selectedIndex, 0);
    expect(navigation.move(-1), isTrue);
    expect(navigation.selectedIndex, 2);
    expect(navigation.move(1), isTrue);
    expect(navigation.selectedIndex, 0);
  });

  test("enters a submenu and restores its parent selection on exit", () {
    navigation.reset(const [
      _Entry("plain"),
      _Entry("people", [_Entry("Alice"), _Entry("Bob")]),
    ]);
    navigation.move(1);

    expect(navigation.canEnterSelected, isTrue);
    expect(navigation.enter(), isTrue);
    expect(navigation.parentPath, "people");
    expect(navigation.activeItems!.map((entry) => entry.label), [
      "Alice",
      "Bob",
    ]);
    navigation.move(1);

    expect(navigation.exit(), isTrue);
    expect(navigation.selectedIndex, 1);
    expect(navigation.parentPath, isNull);
  });

  test("reset clamps selection and dismiss clears the module state", () {
    navigation.reset(const [_Entry("one"), _Entry("two")]);
    navigation.move(1);
    navigation.reset(const [_Entry("only")]);

    expect(navigation.selectedIndex, 0);
    expect(navigation.activeItems, hasLength(1));

    navigation.dismiss();
    expect(navigation.activeItems, isNull);
    expect(navigation.canGoBack, isFalse);
    expect(navigation.selectedIndex, 0);
  });
}

final class _Entry {
  final String label;
  final List<_Entry> children;

  const _Entry(this.label, [this.children = const []]);
}
