/*
 * ものがたり·アシスタント - Monogatari Assistant
 * Copyright (c) 2025 Heyairu（部屋伊琉）
 *
 * Licensed under the Business Source License 1.1 (Modified).
 * You may not use this file except in compliance with the License.
 * Change Date: 2030-11-04 05:14 a.m. (UTC+8)
 * Change License: Apache License 2.0
 *
 * Commercial use allowed under conditions described in Section 1;
 */

import "package:flutter/material.dart";

class InputAssistBar extends StatefulWidget {
  final Function(String) onInsert;
  final VoidCallback? onClose;

  const InputAssistBar({
    super.key,
    required this.onInsert,
    this.onClose,
  });

  @override
  State<InputAssistBar> createState() => _InputAssistBarState();
}

class _InputAssistBarState extends State<InputAssistBar> {
  bool isFullWidth = true;

  // 全形符號列表
  // Note: "　" is full-width space
  final List<String> fullWidthSymbols = [
    "。", "，", "、", "；", "：", "？", "！", 
    "「", "」", "『", "』", "（", "）", 
    "……", "——", 
    "《", "》", "·", "　"
  ];

  // 半形符號列表
  final List<String> halfWidthSymbols = [
    ".", ",", ";", ":", "?", "!", 
    "\"", "'", "(", ")",
    "…", "-", "/", "¿", "¡"
  ];

  @override
  Widget build(BuildContext context) {
    final symbols = isFullWidth ? fullWidthSymbols : halfWidthSymbols;

    return Material(
      elevation: 4,
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
        ),
        child: Row(
          children: [
            // 全形/半形切換開關
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: true,
                    label: Text("全形", style: TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    label: Text("半形", style: TextStyle(fontSize: 12)),
                  ),
                ],
                selected: {isFullWidth},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    isFullWidth = newSelection.first;
                  });
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: WidgetStateProperty.all(EdgeInsets.zero),
                ),
                showSelectedIcon: false,
              ),
            ),
            
            // 標點符號按鈕列表
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: symbols.map((symbol) {
                    // 特殊處理顯示文字（如全形空格顯示為 [ ] 或其他可見符號）
                    String displayLabel = symbol;
                    if (symbol == "　") {
                      displayLabel = "␣";
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Material(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                        child: InkWell(
                          onTap: () => widget.onInsert(symbol),
                          canRequestFocus: false, // 關鍵：防止 InkWell 獲取焦點
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            alignment: Alignment.center,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              displayLabel,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
