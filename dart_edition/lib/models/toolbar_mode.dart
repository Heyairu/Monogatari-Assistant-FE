import "package:flutter/foundation.dart";

/// Presentation only; commands and project data are shared across all modes.
enum ToolbarMode {
  full("Full", "完整功能區，顯示頁籤、群組與指令名稱。"),
  moderate("Moderate", "保留功能區頁籤，該頁指令以單行圖示與文字顯示，可橫向捲動。"),
  concise("Concise", "保留功能區頁籤，該頁指令以純圖示單行排列，可橫向捲動。");

  const ToolbarMode(this.label, this.description);

  final String label;
  final String description;

  static ToolbarMode defaultFor(TargetPlatform platform) => switch (platform) {
    TargetPlatform.android || TargetPlatform.iOS => moderate,
    _ => full,
  };

  /// Unknown values restore the platform default rather than another mode.
  static ToolbarMode? fromPreference(String? value) {
    for (final mode in values) {
      if (mode.name == value) return mode;
    }
    return null;
  }
}
