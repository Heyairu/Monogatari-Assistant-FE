import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:monogatari_assistant/features/inline_annotations/alias_mention_updates.dart";

void main() {
  test("primary rename preserves aliases and other characters", () {
    const id = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";
    const other = "65388495-7eb2-4a2c-9258-3af82aa27791";
    const raw = "艾莉絲 //@<$id|艾莉絲>{主角}// //@<$id|小艾>// //@<$other|艾莉絲>//";
    expect(
      rewriteAliasMentions(
        raw,
        const AliasRename(id, "艾莉絲", "艾莉", isPrimaryName: true),
      ),
      "艾莉絲 //@<$id|艾莉>{主角}// //@<$id|小艾>// //@<$other|艾莉絲>//",
    );
  });
  test("rename matches UUID and exact label while retaining metadata", () {
    const id = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";
    const other = "65388495-7eb2-4a2c-9258-3af82aa27791";
    const raw = "小艾 //@<$id|小艾>{備註}// //@<$other|小艾>// //@<$id|艾莉絲>//";
    expect(
      rewriteAliasMentions(raw, const AliasRename(id, "小艾", "小|莉")),
      "小艾 //@<$id|小\\|莉>{備註}// //@<$other|小艾>// //@<$id|艾莉絲>//",
    );
  });
  test("setting persists disabled state", () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      await container.read(aliasMentionUpdatesEnabledProvider.future),
      isTrue,
    );
    await container
        .read(aliasMentionUpdatesEnabledProvider.notifier)
        .setEnabled(false);
    final reloaded = ProviderContainer();
    addTearDown(reloaded.dispose);
    expect(
      await reloaded.read(aliasMentionUpdatesEnabledProvider.future),
      isFalse,
    );
  });
}
