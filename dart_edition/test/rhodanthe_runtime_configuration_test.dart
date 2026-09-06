import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_editor_session.dart";

void main() {
  test("standard build defaults Rhodanthe to default-on Full", () {
    expect(configuredRhodantheReleaseStage, RhodantheReleaseStage.defaultOn);
    expect(configuredRhodantheRolloutMode, RhodantheRolloutMode.full);
    expect(isRhodantheKillSwitchActive, isFalse);
  });

  test("kill switch overrides every enabled configuration", () {
    expect(
      resolveRhodantheRuntimeMode(
        modeOverride: "full",
        releaseStage: "default-on",
        killSwitch: true,
      ),
      RhodantheRolloutMode.disabled,
    );
  });

  test("explicit mode override wins when kill switch is off", () {
    expect(
      resolveRhodantheRuntimeMode(
        modeOverride: "shadow",
        releaseStage: "default-on",
        killSwitch: false,
      ),
      RhodantheRolloutMode.shadow,
    );
    expect(
      resolveRhodantheRuntimeMode(
        modeOverride: "disabled",
        releaseStage: "default-on",
        killSwitch: false,
      ),
      RhodantheRolloutMode.disabled,
    );
  });

  test("invalid release stage fails closed", () {
    expect(
      resolveRhodantheRuntimeMode(
        modeOverride: "",
        releaseStage: "unexpected",
        killSwitch: false,
      ),
      RhodantheRolloutMode.disabled,
    );
  });
}
