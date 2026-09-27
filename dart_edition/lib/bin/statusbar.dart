/************************************************************
 * 
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
 * 
 ************************************************************/

import "dart:ui" as ui;

import "package:flutter/material.dart";

class MonogatariStatusBar extends StatelessWidget {
  final String displayText;
  final String saveTimeText;
  final int cursorLine;
  final int cursorColumn;
  final int currentWords;
  final int totalWords;
  final double iconSize;
  final int tabSpaceCount;
  final bool tabFullWidth;
  final ValueChanged<int>? onTabSpaceCountChanged;
  final ValueChanged<bool>? onTabFullWidthChanged;
  final bool overwriteMode;
  final VoidCallback? onToggleOverwrite;

  const MonogatariStatusBar({
    super.key,
    required this.displayText,
    required this.saveTimeText,
    required this.cursorLine,
    required this.cursorColumn,
    required this.currentWords,
    required this.totalWords,
    required this.iconSize,
    this.tabSpaceCount = 2,
    this.tabFullWidth = true,
    this.onTabSpaceCountChanged,
    this.onTabFullWidthChanged,
    this.overwriteMode = false,
    this.onToggleOverwrite,
  });

  @override
  Widget build(BuildContext context) {
    final statusTextStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(height: 1.2);
    final statusButtonStyle = TextButton.styleFrom(
      textStyle: statusTextStyle,
      minimumSize: const Size(0, 24),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.description,
                  size: iconSize,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _ScrollingText(
                    text: displayText,
                    style: statusTextStyle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.access_time,
            size: iconSize,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(saveTimeText, style: statusTextStyle),
          const SizedBox(width: 12),
          Icon(
            Icons.pin_drop_outlined,
            size: iconSize,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text("$cursorLine:$cursorColumn", style: statusTextStyle),
          const SizedBox(width: 12),
          _TabSpacesMenu(
            buttonStyle: statusButtonStyle,
            count: tabSpaceCount,
            fullWidth: tabFullWidth,
            onCountChanged: onTabSpaceCountChanged,
            onFullWidthChanged: onTabFullWidthChanged,
          ),
          Tooltip(
            message: overwriteMode ? "Overtype Mode (Ins)" : "Default Mode (Ins)",
            child: Focus(
              canRequestFocus: false,
              descendantsAreFocusable: false,
              child: TextButton(
                style: statusButtonStyle,
                onPressed: onToggleOverwrite,
                child: Text(overwriteMode ? "[OVR]" : "[DEF]"),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              "$currentWords / $totalWords 字",
              style: statusTextStyle?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-column menu: space width on the left, insertion count on the right.
class _TabSpacesMenu extends StatelessWidget {
  const _TabSpacesMenu({
    required this.buttonStyle,
    required this.count,
    required this.fullWidth,
    this.onCountChanged,
    this.onFullWidthChanged,
  });

  final ButtonStyle buttonStyle;
  final int count;
  final bool fullWidth;
  final ValueChanged<int>? onCountChanged;
  final ValueChanged<bool>? onFullWidthChanged;

  Widget _choice({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback? onPressed,
  }) => MenuItemButton(
    key: key,
    onPressed: onPressed,
    leadingIcon: selected
        ? const Icon(Icons.check, size: 16)
        : const SizedBox(width: 16),
    style: const ButtonStyle(fixedSize: WidgetStatePropertyAll(Size(100, 48))),
    child: Text(label),
  );

  @override
  Widget build(BuildContext context) => MenuAnchor(
    alignmentOffset: const Offset(0, -8),
    menuChildren: [
      // MenuItemButton labels contain flex children, so both columns must
      // receive finite horizontal constraints rather than shrink-wrap in a Row.
      SizedBox(
        width: 201,
        height: 384,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _choice(
                    key: const Key("tab-full-width-choice"),
                    label: "全形",
                    selected: fullWidth,
                    onPressed: onFullWidthChanged == null
                        ? null
                        : () => onFullWidthChanged!(true),
                  ),
                  _choice(
                    key: const Key("tab-half-width-choice"),
                    label: "半形",
                    selected: !fullWidth,
                    onPressed: onFullWidthChanged == null
                        ? null
                        : () => onFullWidthChanged!(false),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var value = 1; value <= 8; value++)
                    _choice(
                      key: ValueKey("tab-space-count-$value"),
                      label: "$value",
                      selected: count == value,
                      onPressed: onCountChanged == null
                          ? null
                          : () => onCountChanged!(value),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
    builder: (context, controller, child) => Tooltip(
      message: "Tab 插入空格",
      child: TextButton(
        key: const Key("statusbar-tab-spaces"),
        style: buttonStyle,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        child: Text("[${fullWidth ? '全形' : '半形'}:$count]"),
      ),
    ),
  );
}

class _ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const _ScrollingText({required this.text, this.style});

  @override
  State<_ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<_ScrollingText>
    with WidgetsBindingObserver {
  late ScrollController _scrollController;
  bool _shouldScroll = false;
  bool _isAppActive = true;
  int _scrollGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addObserver(this);

    _scheduleScrollCheck();
  }

  @override
  void didUpdateWidget(_ScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _stopScrolling(resetPosition: true);
      _scheduleScrollCheck();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isActive = state == AppLifecycleState.resumed;
    if (_isAppActive == isActive) return;
    _isAppActive = isActive;
    if (isActive) {
      _scheduleScrollCheck();
    } else {
      _stopScrolling(resetPosition: false);
    }
  }

  void _scheduleScrollCheck() {
    final generation = ++_scrollGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _scrollGeneration) return;
      _checkScroll();
    });
  }

  void _checkScroll() {
    if (!mounted) return;

    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 0 && !_shouldScroll && _isAppActive) {
        setState(() {
          _shouldScroll = true;
        });
        final generation = ++_scrollGeneration;
        _runMarquee(generation);
      } else if (maxScroll <= 0 && _shouldScroll) {
        _stopScrolling(resetPosition: true);
      }
    }
  }

  bool _canContinue(int generation) {
    return mounted &&
        _isAppActive &&
        _shouldScroll &&
        generation == _scrollGeneration &&
        _scrollController.hasClients;
  }

  Future<void> _runMarquee(int generation) async {
    try {
      while (_canContinue(generation)) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(
            milliseconds: (widget.text.length * 200).clamp(2000, 30000),
          ),
          curve: Curves.linear,
        );
        if (!_canContinue(generation)) return;
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!_canContinue(generation)) return;
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOut,
        );
        if (!_canContinue(generation)) return;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    } catch (_) {
      // jumpTo/dispose can cancel an in-flight animation; generation owns restart.
    }
  }

  void _stopScrolling({required bool resetPosition}) {
    _scrollGeneration++;
    _shouldScroll = false;
    if (resetPosition && _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollGeneration++;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textSpan = TextSpan(text: widget.text, style: widget.style);
        final textPainter = TextPainter(
          text: textSpan,
          maxLines: 1,
          textDirection: ui.TextDirection.ltr,
        )..layout();

        if (textPainter.size.width <= constraints.maxWidth) {
          return Text(
            widget.text,
            style: widget.style,
            overflow: TextOverflow.visible,
          );
        }

        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Text(widget.text, style: widget.style),
        );
      },
    );
  }
}
