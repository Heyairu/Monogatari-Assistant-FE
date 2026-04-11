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

  const MonogatariStatusBar({
    super.key,
    required this.displayText,
    required this.saveTimeText,
    required this.cursorLine,
    required this.cursorColumn,
    required this.currentWords,
    required this.totalWords,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
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
                    style: Theme.of(context).textTheme.labelSmall,
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
          Text(saveTimeText, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(width: 12),
          Icon(
            Icons.pin_drop_outlined,
            size: iconSize,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            "$cursorLine:$cursorColumn",
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              "$currentWords / $totalWords 字",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
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

class _ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const _ScrollingText({required this.text, this.style});

  @override
  State<_ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<_ScrollingText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  bool _shouldScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScroll();
    });
  }

  @override
  void didUpdateWidget(_ScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _animationController.reset();
      _shouldScroll = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkScroll();
      });
    }
  }

  void _checkScroll() {
    if (!mounted) return;

    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 0 && !_shouldScroll) {
        setState(() {
          _shouldScroll = true;
        });
        _startScrolling();
      } else if (maxScroll <= 0 && _shouldScroll) {
        _animationController.stop();
        setState(() {
          _shouldScroll = false;
        });
      }
    }
  }

  void _startScrolling() {
    if (!mounted || !_shouldScroll) return;

    _scrollController
        .animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(
            milliseconds: (widget.text.length * 200).clamp(2000, 30000),
          ),
          curve: Curves.linear,
        )
        .then((_) async {
          if (!mounted) return;
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) return;
          _scrollController
              .animateTo(
                0,
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOut,
              )
              .then((_) async {
                if (!mounted) return;
                await Future.delayed(const Duration(seconds: 2));
                if (!mounted) return;
                _startScrolling();
              });
        });
  }

  @override
  void dispose() {
    _animationController.dispose();
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
