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
import "package:monogatari_assistant/bin/ui_library.dart";

class ProofReadingView extends StatefulWidget {
  const ProofReadingView({super.key});
  @override
  State<ProofReadingView> createState() => _ProofReadingViewState();
}

class _ProofReadingViewState extends State<ProofReadingView> {
  // 警語元件
  Widget _buildWarningCard() {
    return Card(
      elevation: 0,
      color: Colors.redAccent,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_outlined, color: Colors.yellow),
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
              child: LargeTitle(icon: Icons.spellcheck, text: "文本校正"),
            ),
            const SizedBox(height: 32),
            // 警語
            _buildWarningCard(),

            // 校正功能卡片
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPlaceholderSetting(
                      "引號、括號閉合檢查",
                      Icons.data_array_rounded,
                    ),
                    _buildPlaceholderSetting("標點符號格式統一", Icons.edit_note),
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
                    _buildPlaceholderSetting("贅字檢查", Icons.grading),
                    _buildPlaceholderSetting(
                      "形容詞標記",
                      Icons.comment_bank_rounded,
                    ),
                    _buildPlaceholderSetting(
                      "常用字詞統計",
                      Icons.track_changes_outlined,
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

  // MARK: - 佔位元件
  Widget _buildPlaceholderSetting(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const Spacer(),
          Text(
            "即將推出",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
