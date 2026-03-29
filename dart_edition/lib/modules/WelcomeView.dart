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

class WelcomeView extends StatefulWidget {
  const WelcomeView(
    {
      super.key,
    }
  );
  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView> {
  // MARK: - UI 介面建構
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標題
            Text(
              "Welcome to",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              "ものがたり·アシスタント",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "—— For Refined Editing. Powered by Heyairu.",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Start
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.format_list_bulleted,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Start",
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      style: Theme.of(context).textButtonTheme.style,
                      onPressed: () {},
                      child: Row(
                        children: const [
                          Icon(Icons.create_outlined, size: 18),
                          SizedBox(width: 4),
                          Text("New Project"),
                        ],
                      )
                    ),
                    TextButton(
                      style: Theme.of(context).textButtonTheme.style,
                      onPressed: () {},
                      child: Row(
                        children: const [
                          Icon(Icons.folder_open, size: 18),
                          SizedBox(width: 4),
                          Text("Open File"),
                        ],
                      )
                    ),
                    TextButton(
                      style: Theme.of(context).textButtonTheme.style,
                      onPressed: () {},
                      child: Row(
                        children: const [
                          Icon(Icons.code, size: 18),
                          SizedBox(width: 4),
                          Text("Open GitHub Repository for This Project"),
                        ],
                      )
                    ),
                    TextButton(
                      style: Theme.of(context).textButtonTheme.style,
                      onPressed: () {},
                      child: Row(
                        children: const [
                          Icon(Icons.person_pin, size: 18),
                          SizedBox(width: 4),
                          Text("Heyairu's Profile on KadoKado"),
                        ],
                      )
                    ),
                    TextButton(
                      style: Theme.of(context).textButtonTheme.style,
                      onPressed: () {},
                      child: Row(
                        children: const [
                          Icon(Icons.coffee, size: 18),
                          SizedBox(width: 4),
                          Text("Heyairu's Ko-fi"),
                        ],
                      )
                    ),
                  ],
                ),
              ),
            ),

            // Recent Files
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.folder,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Recent",
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    TextButton(
                      style: Theme.of(context).textButtonTheme.style,
                      onPressed: () {},
                      child: const Text("Example/DemoFile1.mga"),
                    ),
                    TextButton(
                      style: Theme.of(context).textButtonTheme.style,
                      onPressed: () {},
                      child: const Text("Example/DemoFile2.mga"),
                    ),
                    TextButton(
                      style: Theme.of(context).textButtonTheme.style,
                      onPressed: () {},
                      child: const Text("Example/DemoFile3.mga"),
                    ),
                    TextButton(
                      style: Theme.of(context).textButtonTheme.style,
                      onPressed: () {},
                      child: const Text("Example/DemoFile4.mga"),
                    ),
                    TextButton(
                      style: Theme.of(context).textButtonTheme.style,
                      onPressed: () {},
                      child: const Text("Example/DemoFile5.mga"),
                    ),
                  ],
                ),
              ),
            ),

            // Did you know?
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Did you know?",
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "因為梓喵就是梓喵阿，小律就是小律，小澪就是小澪，小紬就是小紬阿。", //Content
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      "平沢唯 in 《K-ON!!》", //Source
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
                    Row(
                      children: [
                        Icon(
                          Icons.sync_alt_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "內容同步",
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "姓名產生器",
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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