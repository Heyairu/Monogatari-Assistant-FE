import "package:flutter/material.dart";

import "punctuation_panel.dart";

class MonogatariMobileLayout extends StatelessWidget {
  final bool isEditorMode;
  final Widget functionPage;
  final Widget editorPage;
  final Widget statusBar;
  final ValueChanged<int> onDestinationSelected;

  const MonogatariMobileLayout({
    super.key,
    required this.isEditorMode,
    required this.functionPage,
    required this.editorPage,
    required this.statusBar,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: isEditorMode ? 1 : 0,
        children: [functionPage, editorPage],
      ),
      bottomSheet: null,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          statusBar,
          NavigationBar(
            selectedIndex: isEditorMode ? 1 : 0,
            onDestinationSelected: onDestinationSelected,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard), label: "功能"),
              NavigationDestination(icon: Icon(Icons.edit_note), label: "編輯器"),
            ],
          ),
        ],
      ),
    );
  }
}

class MonogatariMobileFunctionPage extends StatelessWidget {
  final bool showPunctuationPanel;
  final ValueChanged<String> onInsertPunctuation;
  final VoidCallback onClosePunctuationPanel;
  final int pageCount;
  final int selectedIndex;
  final double fontSize;
  final VoidCallback onBeforePageSwitch;
  final ValueChanged<int> onPageSelected;
  final Widget Function(int pageIndex) pageBuilder;

  const MonogatariMobileFunctionPage({
    super.key,
    required this.showPunctuationPanel,
    required this.onInsertPunctuation,
    required this.onClosePunctuationPanel,
    required this.pageCount,
    required this.selectedIndex,
    required this.fontSize,
    required this.onBeforePageSwitch,
    required this.onPageSelected,
    required this.pageBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showPunctuationPanel)
          PunctuationPanel(
            onInsert: onInsertPunctuation,
            onClose: onClosePunctuationPanel,
          ),

        Container(
          height: 60,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                for (int i = 0; i < pageCount; i++)
                  _MobileNavigationChip(
                    index: i,
                    selectedIndex: selectedIndex,
                    fontSize: fontSize,
                    onBeforeSelected: onBeforePageSwitch,
                    onSelected: onPageSelected,
                  ),
              ],
            ),
          ),
        ),

        Expanded(
          child: IndexedStack(
            index: selectedIndex.clamp(0, (pageCount - 1)),
            children: [for (int i = 0; i < pageCount; i++) pageBuilder(i)],
          ),
        ),
      ],
    );
  }
}

class _MobileNavigationChip extends StatelessWidget {
  final int index;
  final int selectedIndex;
  final double fontSize;
  final VoidCallback onBeforeSelected;
  final ValueChanged<int> onSelected;

  const _MobileNavigationChip({
    required this.index,
    required this.selectedIndex,
    required this.fontSize,
    required this.onBeforeSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> functions = [
      {"icon": Icons.home, "label": "主頁"},
      {"icon": Icons.book, "label": "故事設定"},
      {"icon": Icons.menu_book, "label": "章節選擇"},
      {"icon": Icons.list, "label": "大綱調整"},
      {"icon": Icons.public, "label": "世界設定"},
      {"icon": Icons.person, "label": "角色設定"},
      {"icon": Icons.view_timeline_outlined, "label": "時間軸"},
      {"icon": Icons.group, "label": "關係設定"},
      {"icon": Icons.assessment, "label": "計畫規劃"},
      {"icon": Icons.library_books, "label": "詞語參考"},
      {"icon": Icons.spellcheck, "label": "文本校正"},
      {"icon": Icons.auto_awesome, "label": "Copilot"},
      {"icon": Icons.settings, "label": "設定"},
      {"icon": Icons.info, "label": "關於"},
    ];

    final function = functions[index];
    final bool isSelected = selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: FilterChip(
        selected: isSelected,
        onSelected: (selected) {
          if (!selected) return;
          onBeforeSelected();
          onSelected(index);
        },
        avatar: Icon(
          function["icon"] as IconData,
          size: fontSize + 4,
          color: isSelected
              ? Theme.of(context).colorScheme.onSecondaryContainer
              : Theme.of(context).colorScheme.onSurface,
        ),
        label: Text(
          function["label"] as String,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.secondaryContainer
            : null,
        selectedColor: Theme.of(context).colorScheme.secondaryContainer,
        checkmarkColor: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    );
  }
}
