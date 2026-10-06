/*
 * Copyright 2025-2026 Heyairu（部屋伊琉）
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 ************************************************************/

import "package:flutter/material.dart";

import "slidebar.dart";
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

        Expanded(
          child: MonogatariNavigationLayout(
            modal: true,
            selectedIndex: selectedIndex.clamp(0, pageCount - 1),
            onDestinationSelected: (index) {
              onBeforePageSwitch();
              onPageSelected(index);
            },
            child: Column(
              children: [
                SizedBox(
                  height: 48,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 56, right: 16),
                      child: Text(
                        monogatariNavigationDestinations[selectedIndex.clamp(
                              0,
                              pageCount - 1,
                            )]
                            .label,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: selectedIndex.clamp(0, pageCount - 1),
                    children: [
                      for (var i = 0; i < pageCount; i++) pageBuilder(i),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
