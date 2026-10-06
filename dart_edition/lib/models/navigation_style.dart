/// The user's desktop navigation preference. Store names rather than ordinals
/// so new styles can be added without changing existing preferences.
enum NavigationStyle {
  railTooltip("Navigation Rail + Tooltip", "僅顯示圖示，停留或聚焦時顯示名稱。"),
  railLabel("Navigation Rail + Label", "圖示下方常駐顯示名稱。"),
  railButtonDrawer(
    "Navigation Rail → 按鈕 → Navigation Drawer",
    "使用底部按鈕展開導覽，並推開內容側欄。",
  ),
  railHoverDrawer(
    "Navigation Rail → Hover → Navigation Drawer",
    "游標停留時預覽，移開後收合；固定開啟時推開內容側欄。",
  );

  const NavigationStyle(this.label, this.description);

  final String label;
  final String description;

  static NavigationStyle fromPreference(String? value) => values.firstWhere(
    (style) => style.name == value,
    orElse: () => railLabel,
  );
}
