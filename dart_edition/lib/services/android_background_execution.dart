import "package:flutter/foundation.dart";
import "package:flutter/services.dart";

/// Bridge for Android's user-controlled battery-optimization exemption.
///
/// This exemption lets work that the user explicitly enables be less likely to
/// be stopped while the app is in the background. It does not bypass Android's
/// force-stop action and it is deliberately only requested from Settings.
class AndroidBackgroundExecution {
  AndroidBackgroundExecution._();

  static const MethodChannel _channel = MethodChannel(
    "com.heyairu.monogatari_assistant/background_execution",
  );

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> isBatteryOptimizationExempt() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>("isBatteryOptimizationExempt") ??
        false;
  }

  /// Opens Android's system approval prompt when the exemption is not granted.
  ///
  /// Android owns the result of this prompt, so callers should query the state
  /// again after the activity resumes instead of assuming approval.
  static Future<void> requestBatteryOptimizationExemption() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>("requestBatteryOptimizationExemption");
  }
}
