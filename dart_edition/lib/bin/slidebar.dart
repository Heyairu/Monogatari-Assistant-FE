import "package:flutter/material.dart";

class MonogatariRailSection extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final TextStyle? selectedLabelTextStyle;
  final TextStyle? unselectedLabelTextStyle;

  const MonogatariRailSection({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.selectedLabelTextStyle,
    required this.unselectedLabelTextStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MonogatariNavigationSidebar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          selectedLabelTextStyle: selectedLabelTextStyle,
          unselectedLabelTextStyle: unselectedLabelTextStyle,
        ),
        const VerticalDivider(thickness: 1, width: 1),
      ],
    );
  }
}

class MonogatariNavigationSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final TextStyle? selectedLabelTextStyle;
  final TextStyle? unselectedLabelTextStyle;

  const MonogatariNavigationSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.selectedLabelTextStyle,
    required this.unselectedLabelTextStyle,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: IntrinsicHeight(
        child: NavigationRail(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          labelType: NavigationRailLabelType.all,
          selectedLabelTextStyle: selectedLabelTextStyle,
          unselectedLabelTextStyle: unselectedLabelTextStyle,
          backgroundColor: Theme.of(context).colorScheme.surface,
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.home),
              label: Text("主頁"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.book),
              label: Text("故事設定"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.menu_book),
              label: Text("章節選擇"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.list),
              label: Text("大綱調整"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.public),
              label: Text("世界設定"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.person),
              label: Text("角色設定"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.view_timeline_outlined),
              label: Text("時間軸"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.group),
              label: Text("關係設定"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.assessment),
              label: Text("計畫規劃"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.library_books),
              label: Text("詞語參考"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.spellcheck),
              label: Text("文本校正"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.auto_awesome),
              label: Text("Copilot"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.settings),
              label: Text("設定"),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.info),
              label: Text("關於"),
            ),
          ],
        ),
      ),
    );
  }
}

class MonogatariResizeDivider extends StatelessWidget {
  final GestureDragUpdateCallback onPanUpdate;

  const MonogatariResizeDivider({super.key, required this.onPanUpdate});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: onPanUpdate,
        child: Container(
          width: 8,
          color: Theme.of(context).colorScheme.surface,
          alignment: Alignment.center,
          child: VerticalDivider(
            thickness: 1,
            width: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}
