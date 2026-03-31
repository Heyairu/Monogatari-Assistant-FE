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

import "dart:convert";
import "dart:math";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "../bin/ui_library.dart";

class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key});
  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView> {
  static const String _didYouKnowAssetPath = "assets/jsons/didyouknow.json";
  static const _DidYouKnowData _fallbackDidYouKnowData = _DidYouKnowData(
    content: "中國最偉大、最永久的藝術，就是男人扮女人",
    source: "—— 魯迅（1881-1936）",
  );
  static final Random _random = Random();

  late Future<_DidYouKnowData> _didYouKnowFuture;

  @override
  void initState() {
    super.initState();
    _didYouKnowFuture = _loadDidYouKnowData();
  }

  void _reloadDidYouKnow() {
    setState(() {
      _didYouKnowFuture = _loadDidYouKnowData();
    });
  }

  Future<_DidYouKnowData> _loadDidYouKnowData() async {
    try {
      final String rawJson = await rootBundle.loadString(_didYouKnowAssetPath);
      if (rawJson.trim().isEmpty) {
        return _fallbackDidYouKnowData;
      }

      final dynamic decoded = jsonDecode(rawJson);
      final List<_DidYouKnowData> candidates = [];

      void collectFromList(List<dynamic> list) {
        for (final dynamic item in list) {
          if (item is Map<String, dynamic>) {
            final _DidYouKnowData? parsed = _parseDidYouKnowMap(item);
            if (parsed != null) {
              candidates.add(parsed);
            }
          }
        }
      }

      if (decoded is Map<String, dynamic>) {
        final _DidYouKnowData? fromDirectMap = _parseDidYouKnowMap(decoded);
        if (fromDirectMap != null) {
          candidates.add(fromDirectMap);
        }

        final dynamic items = decoded["items"];
        if (items is List) {
          collectFromList(items);
        }
      }

      if (decoded is List) {
        collectFromList(decoded);
      }

      if (candidates.isNotEmpty) {
        final int randomIndex = _random.nextInt(candidates.length);
        return candidates[randomIndex];
      }
    } catch (error) {
      debugPrint("Failed to load Did You Know JSON: $error");
    }

    return _fallbackDidYouKnowData;
  }

  _DidYouKnowData? _parseDidYouKnowMap(Map<String, dynamic> map) {
    final dynamic content = map["content"];
    final dynamic source = map["source"];
    if (content is String &&
        content.trim().isNotEmpty &&
        source is String &&
        source.trim().isNotEmpty) {
      return _DidYouKnowData(content: content, source: source);
    }
    return null;
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
                    const SmallTitle(
                      icon: Icons.format_list_bulleted,
                      text: "Start",
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
                      ),
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
                      ),
                    ),
                    TextButton(
                      style: Theme.of(context).textButtonTheme.style,
                      onPressed: () {},
                      child: Row(
                        children: const [
                          Icon(Icons.code, size: 18),
                          SizedBox(width: 4),
                          Text("Open GitHub Repo for This Project"),
                        ],
                      ),
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
                      ),
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
                      ),
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
                    const SmallTitle(icon: Icons.folder, text: "Recent"),
                    SizedBox(height: 12),
                    TextButton(
                      style: Theme.of(context).textButtonTheme.style,
                      onPressed: () {},
                      child: const Text("Example/DemoSlot1"),
                    ),
                    TextButton(
                      style: Theme.of(context).textButtonTheme.style,
                      onPressed: () {},
                      child: const Text("Example/DemoSlot2"),
                    ),
                    TextButton(
                      style: Theme.of(context).textButtonTheme.style,
                      onPressed: () {},
                      child: const Text("Example/DemoSlot3"),
                    ),
                    TextButton(
                      style: Theme.of(context).textButtonTheme.style,
                      onPressed: () {},
                      child: const Text("Example/DemoSlot4"),
                    ),
                    TextButton(
                      style: Theme.of(context).textButtonTheme.style,
                      onPressed: () {},
                      child: const Text("Example/DemoSlot5"),
                    ),
                  ],
                ),
              ),
            ),

            // Did you know?
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _reloadDidYouKnow,
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
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<_DidYouKnowData>(
                        future: _didYouKnowFuture,
                        builder: (context, snapshot) {
                          final _DidYouKnowData didYouKnowData =
                              snapshot.data ?? _fallbackDidYouKnowData;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                didYouKnowData.content, //Content
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                "——" + didYouKnowData.source, //Source
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
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
                    const SmallTitle(
                      icon: Icons.sync_alt_outlined,
                      text: "內容同步",
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
                    const SmallTitle(icon: Icons.person_outline, text: "姓名產生器"),
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

class _DidYouKnowData {
  const _DidYouKnowData({required this.content, required this.source});

  final String content;
  final String source;
}
