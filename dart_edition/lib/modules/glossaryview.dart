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
 * Competing products (≥3 overlapping modules or similar UI structure)
 * and repackaging without permission are prohibited.
 */

import "package:flutter/material.dart";
import "../bin/ui_library.dart";

class GlossaryView extends StatefulWidget {
  const GlossaryView(
    {
      super.key,
    }
  );
  @override
  State<GlossaryView> createState() => _GlossaryViewState();
}

class _GlossaryViewState extends State<GlossaryView> {
  Widget _buildWarningCard() {
    return Card(
      elevation: 0,
      color: Colors.redAccent,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_outlined,
              color: Colors.yellow,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "本功能正在開發中，使用時可能出現錯誤。",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // MARK: - UI 介面建構
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 標題

            const Align(
              alignment: Alignment.centerLeft,
              child: HeadlineLargeTitle(
                icon: Icons.library_books_outlined,
                text: "詞語參考",
              ),
            ),

            const SizedBox(height: 32),

            // 警語
            _buildWarningCard(),

            // 詞語參考功能卡片
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LargeTitle(
                      icon: Icons.folder,
                      text: "詞語類別",
                    ),
                  ],
                ),
              ),
            ),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LargeTitle(
                      icon: Icons.format_list_bulleted,
                      text: "詞語條目",
                    ),
                  ],
                ),
              ),
            ),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LargeTitle(
                      icon: Icons.library_books,
                      text: "詞語解釋、例句",
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}