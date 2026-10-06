/*
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

import "dart:async";
import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../models/navigation_style.dart";
import "../ui_library/control_shape.dart";
import "../ui_library/control_size.dart";

@immutable
class MonogatariNavigationDestination {
  const MonogatariNavigationDestination(this.icon, this.label);
  final IconData icon;
  final String label;
}

// These indexes also identify pages in ContentView. All presentations share
// this list, including the fixed home and settings/about destinations.
const monogatariNavigationDestinations = [
  MonogatariNavigationDestination(Icons.home, "首頁"),
  MonogatariNavigationDestination(Icons.book, "故事設定"),
  MonogatariNavigationDestination(Icons.menu_book, "章節選擇"),
  MonogatariNavigationDestination(Icons.list, "大綱調整"),
  MonogatariNavigationDestination(Icons.view_timeline_outlined, "時間軸"),
  MonogatariNavigationDestination(Icons.person, "角色設定"),
  MonogatariNavigationDestination(Icons.group, "關係設定"),
  MonogatariNavigationDestination(Icons.public, "世界設定"),
  MonogatariNavigationDestination(Icons.inventory_2_outlined, "物品設定"),
  MonogatariNavigationDestination(Icons.assessment_outlined, "計畫規劃"),
  MonogatariNavigationDestination(Icons.library_books_outlined, "詞語參考"),
  MonogatariNavigationDestination(Icons.palette_outlined, "文字色票"),
  MonogatariNavigationDestination(Icons.spellcheck, "文本校正"),
  MonogatariNavigationDestination(Icons.auto_awesome, "Copilot"),
  MonogatariNavigationDestination(Icons.settings, "設定"),
  MonogatariNavigationDestination(Icons.info, "關於"),
];

/// Hover previews cover the content; manual or pinned drawers reserve space.
/// The child stays at the same tree location as the available width changes.
/// Modal layouts reserve no width and expose a drawer button instead.
class MonogatariNavigationLayout extends StatefulWidget {
  const MonogatariNavigationLayout({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
    this.style = NavigationStyle.railLabel,
    this.modal = false,
    this.selectedLabelTextStyle,
    this.unselectedLabelTextStyle,
  });
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;
  final NavigationStyle style;
  final bool modal;
  final TextStyle? selectedLabelTextStyle;
  final TextStyle? unselectedLabelTextStyle;

  @override
  State<MonogatariNavigationLayout> createState() =>
      _MonogatariNavigationLayoutState();
}

class _MonogatariNavigationLayoutState
    extends State<MonogatariNavigationLayout> {
  final _scrollController = ScrollController();
  final _panelFocus = FocusNode(skipTraversal: true);
  final _toggleFocus = FocusNode();
  final _launcherFocus = FocusNode();
  final _destinationKeys = List.generate(16, (_) => GlobalKey());
  Timer? _openTimer;
  Timer? _closeTimer;
  bool _expanded = false;
  bool _pinned = false;
  bool _pointerInside = false;
  bool _hoverSuppressed = false;

  bool get _usesHover =>
      !widget.modal && widget.style == NavigationStyle.railHoverDrawer;

  bool get _usesDrawer =>
      widget.modal ||
      widget.style == NavigationStyle.railButtonDrawer ||
      widget.style == NavigationStyle.railHoverDrawer;

  bool get _usesLabelRail =>
      !widget.modal && widget.style == NavigationStyle.railLabel;

  @override
  void initState() {
    super.initState();
    _revealSelection();
  }

  @override
  void didUpdateWidget(MonogatariNavigationLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.style != widget.style || oldWidget.modal != widget.modal) {
      _cancelTimers();
      _expanded = false;
      _pinned = false;
      _hoverSuppressed = _pointerInside;
    }
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.style != widget.style) {
      _revealSelection();
    }
  }

  @override
  void dispose() {
    _cancelTimers();
    _scrollController.dispose();
    _panelFocus.dispose();
    _toggleFocus.dispose();
    _launcherFocus.dispose();
    super.dispose();
  }

  void _cancelTimers() {
    _openTimer?.cancel();
    _closeTimer?.cancel();
  }

  void _revealSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.selectedIndex < 1 || widget.selectedIndex > 13) {
        return;
      }
      final itemContext = _destinationKeys[widget.selectedIndex].currentContext;
      if (itemContext != null) Scrollable.ensureVisible(itemContext);
    });
  }

  void _open({required bool pinned}) {
    _cancelTimers();
    setState(() {
      _expanded = true;
      _pinned = pinned;
    });
    if (pinned) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _expanded) _toggleFocus.requestFocus();
      });
    }
  }

  void _close() {
    _cancelTimers();
    final restoreFocus = _panelFocus.hasFocus;
    setState(() {
      _expanded = false;
      _pinned = false;
      _hoverSuppressed = _pointerInside;
    });
    if (restoreFocus) {
      if (widget.modal) {
        _launcherFocus.requestFocus();
      } else {
        _toggleFocus.requestFocus();
      }
    }
  }

  void _toggle() {
    if (_expanded && _pinned) {
      _close();
    } else {
      _open(pinned: true);
    }
  }

  void _onEnter(PointerEnterEvent event) {
    _pointerInside = true;
    _closeTimer?.cancel();
    if (!_usesHover || _expanded || _hoverSuppressed) return;
    _openTimer?.cancel();
    _openTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted && _pointerInside && !_hoverSuppressed) {
        _open(pinned: false);
      }
    });
  }

  void _onExit(PointerExitEvent event) {
    _pointerInside = false;
    _hoverSuppressed = false;
    _openTimer?.cancel();
    _scheduleClose();
  }

  void _scheduleClose() {
    _closeTimer?.cancel();
    if (!_usesHover || !_expanded || _pinned || _pointerInside) return;
    _closeTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted && !_pointerInside && !_pinned) {
        _close();
      }
    });
  }

  void _select(int index) {
    if (_expanded && (widget.modal || !_pinned)) _close();
    widget.onDestinationSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final railWidth = _usesLabelRail
        ? AppControlSize.navigationRailWidth
        : AppControlSize.navigationCompactRailWidth;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (node, event) {
        if (_expanded &&
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _close();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final drawerWidth = math.min(256.0, constraints.maxWidth);
          return Stack(
            children: [
              Positioned.fill(
                child: Row(
                  children: [
                    if (!widget.modal)
                      AnimatedContainer(
                        key: const Key("navigation-content-inset"),
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        width: _expanded && _pinned
                            ? drawerWidth
                            : railWidth + 1,
                      ),
                    Expanded(
                      child: ExcludeFocus(
                        excluding: widget.modal && _expanded,
                        child: widget.child,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.modal)
                Positioned(
                  top: 0,
                  left: 0,
                  child: SafeArea(
                    child: IconButton(
                      key: const Key("navigation-launcher"),
                      focusNode: _launcherFocus,
                      tooltip: "展開導覽",
                      icon: const Icon(Icons.menu),
                      onPressed: () => _open(pinned: true),
                    ),
                  ),
                ),
              if (_expanded && (widget.modal || !_pinned))
                Positioned.fill(
                  child: Semantics(
                    label: "關閉導覽",
                    button: true,
                    onTap: _close,
                    child: GestureDetector(
                      key: const Key("navigation-dismiss-area"),
                      behavior: HitTestBehavior.opaque,
                      onTap: _close,
                      child: ColoredBox(
                        color: widget.modal
                            ? colors.scrim.withValues(alpha: 0.32)
                            : Colors.transparent,
                      ),
                    ),
                  ),
                ),
              Positioned(
                key: const Key("navigation-panel-position"),
                top: 0,
                bottom: 0,
                left: 0,
                child: Offstage(
                  offstage: widget.modal && !_expanded,
                  child: AnimatedContainer(
                    key: const Key("navigation-surface"),
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    width: _expanded || widget.modal
                        ? drawerWidth
                        : railWidth + 1,
                    clipBehavior: Clip.hardEdge,
                    decoration: const BoxDecoration(),
                    // Keep labels at their final width throughout the
                    // animation; clipping reveals them without reflow.
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: _expanded || widget.modal
                          ? drawerWidth
                          : railWidth + 1,
                      maxWidth: _expanded || widget.modal
                          ? drawerWidth
                          : railWidth + 1,
                      child: MouseRegion(
                        onEnter: _onEnter,
                        onExit: _onExit,
                        child: FocusTraversalGroup(
                          child: Focus(
                            focusNode: _panelFocus,
                            child: Material(
                              elevation: _expanded ? 8 : 0,
                              color: _expanded
                                  ? colors.surfaceContainerLow
                                  : colors.surface,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: colors.outlineVariant,
                                    ),
                                  ),
                                ),
                                child: _buildPanel(
                                  context,
                                  constraints.maxHeight,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPanel(BuildContext context, double height) {
    // Retain room for the scroll area in short windows. Compact controls use
    // the application's 40dp size; names remain available through tooltips.
    final availableHeight = height - MediaQuery.paddingOf(context).vertical;
    final compact = availableHeight < 360;
    final showLabels =
        _usesLabelRail &&
        !compact &&
        !_expanded &&
        _railLabelsFit(context, availableHeight);
    final itemHeight = _usesLabelRail
        ? (compact ? 48.0 : 64.0)
        : AppControlSize.height;

    Widget destination(int index) {
      final item = monogatariNavigationDestinations[index];
      return _NavigationTile(
        key: _destinationKeys[index],
        itemKey: ValueKey("navigation-destination-$index"),
        label: item.label,
        icon: item.icon,
        selected: widget.selectedIndex == index,
        expanded: _expanded,
        showLabel: showLabels,
        compact: !_usesLabelRail,
        minHeight: itemHeight,
        labelTextStyle: widget.selectedIndex == index
            ? widget.selectedLabelTextStyle
            : widget.unselectedLabelTextStyle,
        onPressed: () => _select(index),
      );
    }

    final toggleLabel = !_expanded
        ? "展開導覽"
        : _pinned
        ? "收合導覽"
        : "固定導覽";
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          destination(0),
          const Divider(height: 1),
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              child: SingleChildScrollView(
                key: const Key("navigation-scroll-area"),
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 1; index <= 13; index++)
                      destination(index),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          if (_usesDrawer)
            _NavigationTile(
              itemKey: const Key("navigation-toggle"),
              label: toggleLabel,
              icon: !_expanded
                  ? Icons.menu_open
                  : _pinned
                  ? Icons.chevron_left
                  : Icons.push_pin_outlined,
              selected: false,
              expanded: _expanded,
              showLabel: showLabels,
              compact: true,
              minHeight: itemHeight,
              labelTextStyle: widget.unselectedLabelTextStyle,
              focusNode: _toggleFocus,
              onPressed: _toggle,
            ),
          destination(14),
          destination(15),
        ],
      ),
    );
  }

  bool _railLabelsFit(BuildContext context, double height) {
    var fixedHeight = 2.0; // Two separators.
    for (final index in [0, 14, 15]) {
      final style = index == widget.selectedIndex
          ? widget.selectedLabelTextStyle
          : widget.unselectedLabelTextStyle;
      final painter = TextPainter(
        text: TextSpan(
          text: monogatariNavigationDestinations[index].label,
          style: style ?? Theme.of(context).textTheme.labelSmall,
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: AppControlSize.navigationRailWidth - 12);
      fixedHeight += math.max(64, 32 + 2 + painter.height + 12);
      painter.dispose();
    }
    return height >= fixedHeight + 96;
  }
}

class _NavigationTile extends StatefulWidget {
  const _NavigationTile({
    super.key,
    required this.itemKey,
    required this.label,
    required this.icon,
    required this.selected,
    required this.expanded,
    required this.showLabel,
    required this.compact,
    required this.minHeight,
    required this.onPressed,
    this.labelTextStyle,
    this.focusNode,
  });

  final Key itemKey;
  final String label;
  final IconData icon;
  final bool selected;
  final bool expanded;
  final bool showLabel;
  final bool compact;
  final double minHeight;
  final VoidCallback onPressed;
  final TextStyle? labelTextStyle;
  final FocusNode? focusNode;

  @override
  State<_NavigationTile> createState() => _NavigationTileState();
}

class _NavigationTileState extends State<_NavigationTile> {
  final _tooltipKey = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    final expanded = widget.expanded;
    final showLabel = widget.showLabel;
    final selected = widget.selected;
    final label = widget.label;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = selected
        ? colors.onSecondaryContainer
        : colors.onSurfaceVariant;
    final labelStyle =
        (expanded
                ? theme.textTheme.labelLarge
                : widget.labelTextStyle ?? theme.textTheme.labelSmall)
            ?.copyWith(color: foreground);
    final iconWidget = Icon(
      widget.icon,
      size: widget.compact ? AppControlSize.smallIcon : AppControlSize.icon,
      color: foreground,
    );
    final content = expanded
        ? Row(
            children: [
              iconWidget,
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: labelStyle)),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: widget.compact ? 40 : 56,
                height: widget.compact ? 28 : 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? colors.secondaryContainer : null,
                  borderRadius: AppControlShape.borderRadius,
                ),
                child: iconWidget,
              ),
              if (showLabel) ...[
                const SizedBox(height: 2),
                Text(label, textAlign: TextAlign.center, style: labelStyle),
              ],
            ],
          );
    return Semantics(
      key: widget.itemKey,
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: TooltipVisibility(
        visible: !expanded && !showLabel,
        child: Tooltip(
          key: _tooltipKey,
          message: label,
          excludeFromSemantics: true,
          waitDuration: const Duration(milliseconds: 500),
          triggerMode: expanded || showLabel
              ? TooltipTriggerMode.manual
              : TooltipTriggerMode.longPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Ink(
              decoration: BoxDecoration(
                color: expanded && selected ? colors.secondaryContainer : null,
                borderRadius: AppControlShape.borderRadius,
              ),
              child: InkWell(
                focusNode: widget.focusNode,
                borderRadius: AppControlShape.borderRadius,
                onTap: widget.onPressed,
                onFocusChange: (focused) {
                  if (focused) {
                    Scrollable.ensureVisible(context);
                    if (!expanded && !showLabel) {
                      _tooltipKey.currentState?.ensureTooltipVisible();
                    }
                  } else {
                    Tooltip.dismissAllToolTips();
                  }
                },
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: widget.minHeight),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: expanded ? 12 : 2,
                      vertical: widget.compact ? 4 : 6,
                    ),
                    child: Center(child: content),
                  ),
                ),
              ),
            ),
          ),
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
