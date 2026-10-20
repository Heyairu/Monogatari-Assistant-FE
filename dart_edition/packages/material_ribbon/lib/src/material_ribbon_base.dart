import "dart:async";

import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";

// Single-row metrics; full-height commands and galleries size themselves.
const double _controlHeight = 40;
const double _galleryItemHeight = _controlHeight * 1.5;
const double _largeControlHeight = _controlHeight * 3;
const double _largeIconSize = 40;
const _controlIconStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size(_controlHeight, _controlHeight)),
  maximumSize: WidgetStatePropertyAll(Size(double.infinity, _controlHeight)),
  visualDensity: VisualDensity.standard,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

/// Immutable application state used to resolve ribbon visibility and commands.
@immutable
class RibbonContext {
  /// Creates context for the current selection and application-defined values.
  const RibbonContext({
    this.selectionType,
    this.selectionCount = 0,
    this.values = const {},
  });
  final String? selectionType;
  final int selectionCount;
  final Map<String, Object?> values;
  bool get hasSelection => selectionCount > 0;
}

enum RibbonCommandSize { small, medium, large }

enum RibbonCommandType { action, toggle, menu, split, gallery }

enum RibbonCheckState { unchecked, checked, mixed }

enum RibbonInvocationSource {
  button,
  keyTip,
  shortcut,
  commandPalette,
  menu,
  gallery,
}

enum RibbonKeyTipLevel { hidden, header, commands }

enum RibbonNavigationIntent { previousTab, nextTab, firstTab, lastTab }

enum RibbonShortcutScope { ribbon, application }

enum RibbonCommandReentryPolicy { ignore, allow }

enum RibbonLayoutMode { compact, expanded }

/// The lifecycle stage of an asynchronously dispatched command.
enum RibbonCommandFeedbackType { started, succeeded, failed }

typedef RibbonPersonalizationMigration =
    Map<String, Object?> Function(int sourceVersion, Map<String, Object?> json);

/// Strings used by built-in ribbon controls and their accessibility labels.
@immutable
class RibbonLocalizations {
  /// Creates a set of labels for the ribbon's built-in UI.
  const RibbonLocalizations({
    this.moreOptions = 'More options',
    this.customizeRibbon = 'Customize Ribbon',
    this.quickAccessToolbar = 'Quick Access Toolbar',
    this.ribbonTabs = 'Ribbon tabs',
    this.done = 'Done',
    this.expandQuickAccessToolbar = 'Expand Quick Access Toolbar',
    this.collapseQuickAccessToolbar = 'Collapse Quick Access Toolbar',
    this.customizeQuickAccessToolbar = 'Customize Quick Access Toolbar',
    this.moreQuickAccessCommands = 'More Quick Access commands',
    this.expandRibbon = 'Expand Ribbon (Ctrl+F1)',
    this.collapseRibbon = 'Collapse Ribbon (Ctrl+F1)',
    this.searchCommands = 'Search commands',
    this.textColor = 'Text color',
    this.color = 'Color',
    this.font = 'Font',
    this.increase = 'Increase',
    this.decrease = 'Decrease',
    this.tabSemanticsPattern = '{label} tab',
    this.moveTabUpPattern = 'Move {label} up',
    this.moveTabDownPattern = 'Move {label} down',
    this.commandsSemanticsPattern = '{label} commands',
    this.groupSemanticsPattern = '{label} group',
    this.tabNavigationSuffix = 'Use Left, Right, Home, or End to switch tabs.',
    this.resetToDefaults = 'Reset to defaults',
  });

  final String moreOptions;
  final String customizeRibbon;
  final String quickAccessToolbar;
  final String ribbonTabs;
  final String done;
  final String expandQuickAccessToolbar;
  final String collapseQuickAccessToolbar;
  final String customizeQuickAccessToolbar;
  final String moreQuickAccessCommands;
  final String expandRibbon;
  final String collapseRibbon;
  final String searchCommands;
  final String textColor;
  final String color;
  final String font;
  final String increase;
  final String decrease;
  final String tabSemanticsPattern;
  final String moveTabUpPattern;
  final String moveTabDownPattern;
  final String commandsSemanticsPattern;
  final String groupSemanticsPattern;
  final String tabNavigationSuffix;
  final String resetToDefaults;

  String _withLabel(String pattern, String label) =>
      pattern.replaceAll('{label}', label);
  String tabSemantics(String label) => _withLabel(tabSemanticsPattern, label);
  String moveTabUp(String label) => _withLabel(moveTabUpPattern, label);
  String moveTabDown(String label) => _withLabel(moveTabDownPattern, label);
  String commandsSemantics(String label) =>
      _withLabel(commandsSemanticsPattern, label);
  String groupSemantics(String label) =>
      _withLabel(groupSemanticsPattern, label);
  String get tabNavigationSemantics => '$ribbonTabs. $tabNavigationSuffix';

  /// Traditional Chinese strings for applications using a Chinese locale.
  static const traditionalChinese = RibbonLocalizations(
    moreOptions: '更多選項',
    customizeRibbon: '自訂功能區',
    quickAccessToolbar: '快速存取工具列',
    ribbonTabs: '功能區索引標籤',
    done: '完成',
    expandQuickAccessToolbar: '展開快速存取工具列',
    collapseQuickAccessToolbar: '收合快速存取工具列',
    customizeQuickAccessToolbar: '自訂快速存取工具列',
    moreQuickAccessCommands: '更多快速存取命令',
    expandRibbon: '展開 Ribbon (Ctrl+F1)',
    collapseRibbon: '收合 Ribbon (Ctrl+F1)',
    searchCommands: '搜尋命令',
    textColor: '文字色彩',
    tabSemanticsPattern: '{label} 索引標籤',
    moveTabUpPattern: '上移 {label}',
    moveTabDownPattern: '下移 {label}',
    commandsSemanticsPattern: '{label} 命令',
    groupSemanticsPattern: '{label} 群組',
    tabNavigationSuffix: '使用左右方向鍵、Home 或 End 切換。',
    resetToDefaults: '重設為預設值',
  );

  /// A delegate supporting English and Traditional Chinese automatically.
  static const LocalizationsDelegate<RibbonLocalizations> delegate =
      _RibbonLocalizationsDelegate();

  static RibbonLocalizations of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<RibbonLocalizationsScope>()
          ?.localizations ??
      Localizations.of<RibbonLocalizations>(context, RibbonLocalizations) ??
      const RibbonLocalizations();
}

class _RibbonLocalizationsDelegate
    extends LocalizationsDelegate<RibbonLocalizations> {
  const _RibbonLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'zh';
  @override
  Future<RibbonLocalizations> load(Locale locale) async =>
      locale.languageCode == 'zh'
      ? RibbonLocalizations.traditionalChinese
      : const RibbonLocalizations();
  @override
  bool shouldReload(_RibbonLocalizationsDelegate old) => false;
}

/// Makes [RibbonLocalizations] available to descendant ribbon controls.
class RibbonLocalizationsScope extends InheritedWidget {
  /// Creates a scope containing [localizations].
  const RibbonLocalizationsScope({
    super.key,
    required this.localizations,
    required super.child,
  });
  final RibbonLocalizations localizations;
  @override
  bool updateShouldNotify(RibbonLocalizationsScope oldWidget) =>
      localizations != oldWidget.localizations;
}

/// Describes a command request sent to a host command handler.
@immutable
class CommandInvocation {
  /// Creates an invocation with its command ID, source, and optional payload.
  const CommandInvocation({
    required this.commandId,
    required this.source,
    this.tabId,
    this.value,
  });
  final String commandId;
  final RibbonInvocationSource source;
  final String? tabId;
  final Object? value;
}

typedef RibbonCommandHandler =
    FutureOr<void> Function(CommandInvocation invocation);
typedef RibbonCommandErrorHandler =
    void Function(
      CommandInvocation invocation,
      Object error,
      StackTrace stackTrace,
    );

/// A lifecycle event that lets the host show progress, success, or error UI.
@immutable
class RibbonCommandFeedback {
  const RibbonCommandFeedback._({
    required this.type,
    required this.invocation,
    this.error,
    this.stackTrace,
  });
  const RibbonCommandFeedback.started(CommandInvocation invocation)
    : this._(type: RibbonCommandFeedbackType.started, invocation: invocation);
  const RibbonCommandFeedback.succeeded(CommandInvocation invocation)
    : this._(type: RibbonCommandFeedbackType.succeeded, invocation: invocation);
  const RibbonCommandFeedback.failed(
    CommandInvocation invocation,
    Object error,
    StackTrace stackTrace,
  ) : this._(
        type: RibbonCommandFeedbackType.failed,
        invocation: invocation,
        error: error,
        stackTrace: stackTrace,
      );
  final RibbonCommandFeedbackType type;
  final CommandInvocation invocation;
  final Object? error;
  final StackTrace? stackTrace;
}

typedef RibbonCommandFeedbackHandler =
    void Function(RibbonCommandFeedback feedback);

/// The externally observable state of the KeyTip interaction.
@immutable
class RibbonKeyTipState {
  /// Creates a KeyTip state at [level], optionally scoped to [tabId].
  const RibbonKeyTipState({required this.level, this.tabId});
  const RibbonKeyTipState.hidden()
    : level = RibbonKeyTipLevel.hidden,
      tabId = null;
  final RibbonKeyTipLevel level;
  final String? tabId;
}

/// Controls which KeyTip badges are visible on a [MaterialRibbon].
class RibbonKeyTipController extends ValueNotifier<RibbonKeyTipState> {
  /// Creates a controller with KeyTips hidden.
  RibbonKeyTipController() : super(const RibbonKeyTipState.hidden());
  void showHeader() =>
      value = const RibbonKeyTipState(level: RibbonKeyTipLevel.header);
  void showCommands(String tabId) => value = RibbonKeyTipState(
    level: RibbonKeyTipLevel.commands,
    tabId: tabId,
  );
  void hide() => value = const RibbonKeyTipState.hidden();
}

/// Selects ribbon tabs and reveals tabs or groups programmatically.
class RibbonController extends ChangeNotifier {
  /// Creates a controller for selecting and revealing ribbon content.
  RibbonController();
  String? _selectedTabId;
  Future<void> Function(String id)? _scrollToTab;
  Future<void> Function(String groupId, String? tabId)? _scrollToGroup;
  String? get selectedTabId => _selectedTabId;
  void selectTab(String id) {
    if (_selectedTabId == id) return;
    _selectedTabId = id;
    notifyListeners();
  }

  Future<void> scrollToTab(String id) async => _scrollToTab?.call(id);
  Future<void> scrollToGroup(String groupId, {String? tabId}) async =>
      _scrollToGroup?.call(groupId, tabId);
}

/// Registers an application-defined action for a KeyTip sequence.
@immutable
class RibbonKeyTipTarget {
  /// Creates a target invoked when [keyTip] is selected.
  const RibbonKeyTipTarget({
    required this.keyTip,
    required this.onInvoke,
    this.child,
  });
  final String keyTip;
  final VoidCallback onInvoke;
  final Widget? child;
}

/// Adds a visible KeyTip badge to an application-defined ribbon control.
class RibbonKeyTip extends StatelessWidget {
  /// Creates a wrapper that displays [keyTip] when [visible].
  const RibbonKeyTip({
    super.key,
    required this.keyTip,
    required this.visible,
    required this.child,
  });
  final String keyTip;
  final bool visible;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      _KeyTip(label: keyTip, visible: visible, child: child);
}

/// Controls the value supplied to [RibbonChip.onSelected] after a press.
///
/// Use [preserve] when a chip represents an action rather than a selectable
/// destination; use [select] or [deselect] for host-controlled navigation.
enum RibbonChipSelectionBehavior { toggle, select, deselect, preserve }

/// A selectable command chip for navigation surfaces such as a Backstage menu.
///
/// The parent owns [selected]. Use [onPressed] for an action, [onSelected] for
/// choice-style navigation, or both. [child] permits richer button content
/// while [label] covers the common icon-and-text case.
class RibbonChip extends StatelessWidget {
  /// Creates a controlled navigation or action chip.
  const RibbonChip({
    super.key,
    this.label,
    this.child,
    this.icon,
    this.selected = false,
    this.enabled = true,
    this.onPressed,
    this.onSelected,
    this.onLongPress,
    this.onHover,
    this.onFocusChange,
    this.focusNode,
    this.autofocus = false,
    this.tooltip,
    this.semanticLabel,
    this.style,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.minimumSize = const Size(0, _controlHeight),
    this.alignment = AlignmentDirectional.centerStart,
    this.selectionBehavior = RibbonChipSelectionBehavior.toggle,
  }) : assert(label != null || child != null, 'Provide either label or child.');

  final String? label;
  final Widget? child;
  final Widget? icon;
  final bool selected;
  final bool enabled;
  final VoidCallback? onPressed;
  final ValueChanged<bool>? onSelected;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onHover;
  final ValueChanged<bool>? onFocusChange;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? tooltip;
  final String? semanticLabel;
  final ButtonStyle? style;
  final EdgeInsetsGeometry padding;
  final Size minimumSize;
  final AlignmentGeometry alignment;
  final RibbonChipSelectionBehavior selectionBehavior;

  bool get _nextSelected => switch (selectionBehavior) {
    RibbonChipSelectionBehavior.toggle => !selected,
    RibbonChipSelectionBehavior.select => true,
    RibbonChipSelectionBehavior.deselect => false,
    RibbonChipSelectionBehavior.preserve => selected,
  };

  @override
  Widget build(BuildContext context) {
    final content = child ?? Text(label!);
    void activate() {
      onPressed?.call();
      onSelected?.call(_nextSelected);
    }

    final active = enabled && (onPressed != null || onSelected != null);
    final button = TextButton(
      onPressed: active ? activate : null,
      onLongPress: enabled ? onLongPress : null,
      onHover: onHover,
      onFocusChange: onFocusChange,
      focusNode: focusNode,
      autofocus: autofocus,
      style: ButtonStyle(
        alignment: alignment,
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: WidgetStatePropertyAll(minimumSize),
        padding: WidgetStatePropertyAll(padding),
        backgroundColor: WidgetStatePropertyAll(
          selected
              ? Theme.of(context).colorScheme.secondaryContainer
              : Colors.transparent,
        ),
        foregroundColor: selected
            ? WidgetStatePropertyAll(
                Theme.of(context).colorScheme.onSecondaryContainer,
              )
            : null,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ).merge(style),
      child: icon == null
          ? content
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon!,
                const SizedBox(width: 10),
                Flexible(child: content),
              ],
            ),
    );
    final semanticButton = Semantics(
      button: true,
      selected: selected,
      enabled: active,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      onTap: active ? activate : null,
      onLongPress: enabled ? onLongPress : null,
      child: button,
    );
    return tooltip == null
        ? semanticButton
        : Tooltip(
            message: tooltip!,
            excludeFromSemantics: true,
            child: semanticButton,
          );
  }
}

/// An action chip using the shared Chip theme and application-owned behavior.
/// Can be placed in [MaterialRibbon.headerActions] or any scroll view.
class RibbonActionChip extends StatelessWidget {
  /// Creates an action chip suitable for a ribbon header or custom surface.
  const RibbonActionChip({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.tooltip,
    this.enabled = true,
    this.backgroundColor,
    this.labelStyle,
    this.focusNode,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final String? tooltip;
  final bool enabled;
  final Color? backgroundColor;
  final TextStyle? labelStyle;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => Center(
    widthFactor: 1,
    heightFactor: 1,
    child: ActionChip(
      label: Text(label),
      avatar: icon,
      onPressed: enabled ? onPressed : null,
      tooltip: tooltip,
      backgroundColor:
          backgroundColor ?? Theme.of(context).colorScheme.secondaryContainer,
      labelStyle: labelStyle,
      focusNode: focusNode,
      autofocus: autofocus,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
}

/// A standard popup surface for ribbon menus, galleries, and pickers.
///
/// [menuChildren] contains the popup content. Use [builder] to create the
/// control that opens it; the supplied [MenuController] can toggle the popup.
/// The component keeps popup styling and positioning consistent across ribbon
/// controls while retaining the keyboard and dismissal behaviour of
/// [MenuAnchor].
class RibbonPopup extends StatelessWidget {
  /// Creates a consistently styled [MenuAnchor] for ribbon popup content.
  const RibbonPopup({
    super.key,
    required this.menuChildren,
    required this.builder,
    this.controller,
    this.childFocusNode,
    this.style,
    this.alignmentOffset = Offset.zero,
    this.consumeOutsideTap = false,
    this.onOpen,
    this.onClose,
    this.crossAxisUnconstrained = true,
    this.useRootOverlay = false,
  });

  final List<Widget> menuChildren;
  final MenuAnchorChildBuilder builder;
  final MenuController? controller;
  final FocusNode? childFocusNode;
  final MenuStyle? style;
  final Offset alignmentOffset;
  final bool consumeOutsideTap;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;
  final bool crossAxisUnconstrained;
  final bool useRootOverlay;

  MenuStyle _defaultStyle(BuildContext context) => MenuStyle(
    backgroundColor: WidgetStatePropertyAll(
      Theme.of(context).colorScheme.surfaceContainer,
    ),
    elevation: const WidgetStatePropertyAll(4),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
  );

  @override
  Widget build(BuildContext context) => MenuAnchor(
    controller: controller,
    childFocusNode: childFocusNode,
    style: style ?? _defaultStyle(context),
    alignmentOffset: alignmentOffset,
    clipBehavior: Clip.antiAlias,
    consumeOutsideTap: consumeOutsideTap,
    onOpen: onOpen,
    onClose: onClose,
    crossAxisUnconstrained: crossAxisUnconstrained,
    useRootOverlay: useRootOverlay,
    menuChildren: menuChildren,
    builder: builder,
  );
}

/// A selectable value and its visual representation in a [RibbonGallery].
class RibbonGalleryItem<T> {
  /// Creates a gallery item with a required value and display label.
  const RibbonGalleryItem({
    required this.value,
    required this.label,
    this.icon,
    this.preview,
    this.tooltip,
    this.onSelected,
  });
  final T value;
  final String label;
  final IconData? icon;

  /// A thumbnail, colour swatch, or style sample shown in a gallery cell.
  final Widget? preview;
  final String? tooltip;
  final ValueChanged<T>? onSelected;
}

/// A dense, keyboard-accessible grid for pictures, colours, and document styles.
///
/// [onPreview] fires as the pointer enters a cell. Use [onPreviewEnd] to
/// restore an editor's original value when the pointer leaves the gallery.
class RibbonGallery<T> extends StatelessWidget {
  /// Creates a controlled gallery grid.
  const RibbonGallery({
    super.key,
    required this.items,
    required this.onSelected,
    this.selectedValue,
    this.onPreview,
    this.onPreviewEnd,
    this.columns = 4,
    this.cellSize = const Size(72, _galleryItemHeight),
    this.showLabels = true,
    this.enabled = true,
    this.padding = const EdgeInsets.all(6),
  }) : assert(columns > 0);

  final List<RibbonGalleryItem<T>> items;
  final ValueChanged<T> onSelected;
  final T? selectedValue;
  final ValueChanged<T>? onPreview;
  final VoidCallback? onPreviewEnd;
  final int columns;
  final Size cellSize;
  final bool showLabels;
  final bool enabled;

  /// Space around the cell grid. Popup galleries generally keep the default;
  /// embedded ribbon galleries can use [EdgeInsets.zero] for row alignment.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    const gap = 4.0;
    // A Wrap is deliberately used instead of a shrink-wrapped GridView.
    // MenuAnchor gives children unconstrained vertical space, which can make a
    // scrollable GridView repeatedly relayout and lock up when opening a palette.
    final gridWidth = columns * cellSize.width + (columns - 1) * gap;
    return MouseRegion(
      onExit: (_) => onPreviewEnd?.call(),
      child: Padding(
        padding: padding,
        child: SizedBox(
          width: gridWidth,
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: items.map((item) {
              final selected = item.value == selectedValue;
              final content = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(child: item.preview ?? Icon(item.icon)),
                  ),
                  if (showLabels)
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              );
              return Tooltip(
                message: item.tooltip ?? item.label,
                child: MouseRegion(
                  onEnter: (_) {
                    if (enabled) onPreview?.call(item.value);
                  },
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: item.label,
                    child: Material(
                      color: selected
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      child: InkWell(
                        onTap: enabled
                            ? () {
                                onSelected(item.value);
                                item.onSelected?.call(item.value);
                              }
                            : null,
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: cellSize.width,
                          height: cellSize.height,
                          child: content,
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
    );
  }
}

/// A compact gallery that keeps selected, high-frequency items in a ribbon
/// group and exposes the complete collection from its expansion button.
///
/// [featuredValues] identifies the items to keep visible. Values not present
/// in [items] are ignored, which lets an application tailor its featured set
/// to the current context without rebuilding the full gallery definition.
/// The full popup uses [RibbonGallery], so selection and hover-preview
/// behaviour are identical in both surfaces.
class RibbonFeaturedGallery<T> extends StatelessWidget {
  /// Creates a gallery with frequently used values kept visible in the ribbon.
  const RibbonFeaturedGallery({
    super.key,
    required this.items,
    required this.featuredValues,
    required this.onSelected,
    this.selectedValue,
    this.onPreview,
    this.onPreviewEnd,
    this.columns = 4,
    this.featuredCols = 3,
    this.featuredCellSize = const Size(68, _galleryItemHeight),
    this.galleryCellSize = const Size(72, _galleryItemHeight),
    this.galleryWidth = 312,
    this.moreTooltip = 'More items',
    this.enabled = true,
  }) : assert(columns > 0),
       assert(featuredCols > 0),
       assert(galleryWidth > 0);

  /// All values available from the expanded gallery.
  final List<RibbonGalleryItem<T>> items;

  /// Values shown directly in the ribbon, in display order.
  final List<T> featuredValues;
  final ValueChanged<T> onSelected;
  final T? selectedValue;
  final ValueChanged<T>? onPreview;
  final VoidCallback? onPreviewEnd;
  final int columns;
  final int featuredCols;
  final Size featuredCellSize;
  final Size galleryCellSize;
  final double galleryWidth;
  final String moreTooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    assert(featuredCellSize.height > 0);
    final featuredItems = <RibbonGalleryItem<T>>[];
    for (final value in featuredValues) {
      for (final item in items) {
        if (item.value == value) {
          featuredItems.add(item);
          break;
        }
      }
    }
    final featuredRows = (_largeControlHeight / featuredCellSize.height)
        .floor();
    assert(featuredRows > 0);
    final visibleFeaturedItems = featuredItems
        .take(featuredCols * featuredRows)
        .toList();
    final visibleRows = (visibleFeaturedItems.length / featuredCols).ceil();
    final width = featuredCols * featuredCellSize.width + 30;

    return RibbonPopup(
      menuChildren: [
        SizedBox(
          width: galleryWidth,
          child: RibbonGallery<T>(
            items: items,
            selectedValue: selectedValue,
            onSelected: onSelected,
            onPreview: onPreview,
            onPreviewEnd: onPreviewEnd,
            columns: columns,
            cellSize: galleryCellSize,
            enabled: enabled,
          ),
        ),
      ],
      builder: (context, controller, _) => MouseRegion(
        onExit: (_) => onPreviewEnd?.call(),
        child: SizedBox(
          width: width,
          height: _largeControlHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: featuredCols * featuredCellSize.width,
                  height: _largeControlHeight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var row = 0; row < visibleRows; row++)
                        SizedBox(
                          height: featuredCellSize.height,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (
                                var column = 0;
                                column < featuredCols;
                                column++
                              )
                                if (row * featuredCols + column <
                                    visibleFeaturedItems.length)
                                  _featuredButton(
                                    context,
                                    visibleFeaturedItems[row * featuredCols +
                                        column],
                                  )
                                else
                                  SizedBox(width: featuredCellSize.width),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 27,
                  height: _largeControlHeight,
                  child: IconButton(
                    tooltip: moreTooltip,
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    onPressed: enabled
                        ? () => controller.isOpen
                              ? controller.close()
                              : controller.open()
                        : null,
                    icon: const Icon(Icons.unfold_more),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _select(T value) {
    onSelected(value);
    for (final item in items) {
      if (item.value == value) item.onSelected?.call(value);
    }
  }

  Widget _featuredButton(BuildContext context, RibbonGalleryItem<T> item) {
    final selected = item.value == selectedValue;
    return SizedBox(
      width: featuredCellSize.width,
      height: featuredCellSize.height,
      child: Tooltip(
        message: item.tooltip ?? item.label,
        child: MouseRegion(
          onEnter: (_) {
            if (enabled) onPreview?.call(item.value);
          },
          child: TextButton(
            onPressed: enabled ? () => _select(item.value) : null,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.all(4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2),
              ),
              backgroundColor: selected
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child:
                        item.preview ??
                        (item.icon == null
                            ? const SizedBox.shrink()
                            : Icon(item.icon)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An item displayed by [RibbonComboBox].
class RibbonComboBoxItem<T> {
  /// Creates a combo-box item with a value, label, and optional leading widget.
  const RibbonComboBoxItem({
    required this.value,
    required this.label,
    this.leading,
  });
  final T value;
  final String label;
  final Widget? leading;
}

/// A compact labelled dropdown intended for a ribbon group.
class RibbonComboBox<T> extends StatelessWidget {
  /// Creates a controlled, ribbon-sized dropdown.
  const RibbonComboBox({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.label,
    this.width = 150,
    this.enabled = true,
  });
  final List<RibbonComboBoxItem<T>> items;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String? label;
  final double width;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: SizedBox(
      width: width,
      height: _controlHeight,
      child: MenuAnchor(
        menuChildren: items
            .map(
              (item) => MenuItemButton(
                onPressed: enabled ? () => onChanged(item.value) : null,
                leadingIcon: item.leading,
                child: Text(item.label),
              ),
            )
            .toList(),
        builder: (context, controller, _) => TextFormField(
          key: ValueKey(value),
          initialValue:
              items.where((item) => item.value == value).firstOrNull?.label ??
              '',
          readOnly: true,
          enabled: enabled,
          showCursor: false,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlignVertical: TextAlignVertical.center,
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
          decoration: InputDecoration(
            hintText: label,
            border: const OutlineInputBorder(),
            constraints: const BoxConstraints.tightFor(height: _controlHeight),
            isDense: false,
            visualDensity: VisualDensity.standard,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            suffixIconConstraints: const BoxConstraints.tightFor(
              width: 28,
              height: 32,
            ),
            suffixIcon: const Icon(Icons.arrow_drop_down, size: 20),
          ),
        ),
      ),
    ),
  );
}

/// A controlled text field sized for placement in a [RibbonGroup].
class RibbonTextBox extends StatelessWidget {
  /// Creates a controlled, ribbon-sized text field.
  const RibbonTextBox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.hintText,
    this.width = 150,
    this.enabled = true,
  });
  final String value;
  final ValueChanged<String> onChanged;
  final String? label, hintText;
  final double width;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: SizedBox(
      width: width,
      height: _controlHeight,
      child: TextFormField(
        key: ValueKey(value),
        initialValue: value,
        enabled: enabled,
        onChanged: onChanged,
        style: Theme.of(context).textTheme.bodyMedium,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          constraints: const BoxConstraints.tightFor(height: _controlHeight),
          hintText: hintText ?? label,
          border: const OutlineInputBorder(),
          isDense: false,
          visualDensity: VisualDensity.standard,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
        ),
      ),
    ),
  );
}

/// A numeric field with ribbon-sized increment and decrement affordances.
class RibbonSpinBox extends StatelessWidget {
  /// Creates a controlled numeric field with increment and decrement controls.
  const RibbonSpinBox({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.label,
    this.width = 108,
    this.decimalPlaces = 0,
  });
  final double value, min, max, step;
  final ValueChanged<double> onChanged;
  final String? label;
  final double width;
  final int decimalPlaces;
  double get _clamped => value.clamp(min, max).toDouble();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: _controlHeight,
    child: TextFormField(
      key: ValueKey(value),
      initialValue: _clamped.toStringAsFixed(decimalPlaces),
      style: Theme.of(context).textTheme.bodyMedium,
      textAlignVertical: TextAlignVertical.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onFieldSubmitted: (text) {
        final next = double.tryParse(text);
        if (next != null) onChanged(next.clamp(min, max).toDouble());
      },
      decoration: InputDecoration(
        hintText: label,
        border: const OutlineInputBorder(),
        constraints: const BoxConstraints.tightFor(height: _controlHeight),
        isDense: false,
        visualDensity: VisualDensity.standard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        suffixIconConstraints: const BoxConstraints.tightFor(
          width: 24,
          height: 32,
        ),
        suffixIcon: Column(
          children: [
            _stepButton(
              '${RibbonLocalizations.of(context).increase} ${label ?? ''}',
              Icons.arrow_drop_up,
              _clamped >= max
                  ? null
                  : () =>
                        onChanged((_clamped + step).clamp(min, max).toDouble()),
            ),
            _stepButton(
              '${RibbonLocalizations.of(context).decrease} ${label ?? ''}',
              Icons.arrow_drop_down,
              _clamped <= min
                  ? null
                  : () =>
                        onChanged((_clamped - step).clamp(min, max).toDouble()),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _stepButton(String tooltip, IconData icon, VoidCallback? onPressed) =>
      SizedBox(
        width: 24,
        height: 16,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.standard,
          ),
          iconSize: 16,
          icon: Icon(icon),
        ),
      );
}

/// A palette button backed by [RibbonGallery], with optional hover preview.
class RibbonColorPicker extends StatelessWidget {
  /// Creates a controlled colour palette button.
  const RibbonColorPicker({
    super.key,
    required this.colors,
    required this.value,
    required this.onChanged,
    this.onPreview,
    this.onPreviewEnd,
    this.label,
    this.columns = 6,
  });
  final List<Color> colors;
  final Color value;
  final ValueChanged<Color> onChanged;
  final ValueChanged<Color>? onPreview;
  final VoidCallback? onPreviewEnd;
  final String? label;
  final int columns;
  @override
  Widget build(BuildContext context) => RibbonPopup(
    menuChildren: [
      SizedBox(
        width: columns * 40.0 + (columns - 1) * 4.0 + 12,
        child: RibbonGallery<Color>(
          items: colors
              .map(
                (color) => RibbonGalleryItem(
                  value: color,
                  label: _colorName(color),
                  preview: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              )
              .toList(),
          selectedValue: value,
          onSelected: onChanged,
          onPreview: onPreview,
          onPreviewEnd: onPreviewEnd,
          columns: columns,
          cellSize: const Size(40, 40),
          showLabels: false,
        ),
      ),
    ],
    builder: (context, controller, _) => Tooltip(
      message: label ?? RibbonLocalizations.of(context).color,
      child: IconButton.outlined(
        style: _controlIconStyle,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: Icon(Icons.format_color_text, color: value),
      ),
    ),
  );
  static String _colorName(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}

/// A font family dropdown with each option rendered in its own typeface.
class RibbonFontPicker extends StatelessWidget {
  /// Creates a controlled dropdown of font family names.
  const RibbonFontPicker({
    super.key,
    required this.fonts,
    required this.value,
    required this.onChanged,
    this.width = 170,
    this.label,
  });
  final List<String> fonts;
  final String? value;
  final ValueChanged<String?> onChanged;
  final double width;
  final String? label;
  @override
  Widget build(BuildContext context) => RibbonComboBox<String>(
    width: width,
    label: label ?? RibbonLocalizations.of(context).font,
    value: value,
    onChanged: onChanged,
    items: fonts
        .map(
          (font) => RibbonComboBoxItem(
            value: font,
            label: font,
            leading: Text('A', style: TextStyle(fontFamily: font)),
          ),
        )
        .toList(),
  );
}

/// One command can expose an action, toggle, menu, split-button, or gallery.
class RibbonCommand {
  /// Creates a command definition.
  ///
  /// Supply exactly the behaviour needed by its [type], and provide either
  /// [onInvoke] or [onInvoked] as its action handler.
  const RibbonCommand({
    required this.id,
    required this.label,
    required this.icon,
    this.onInvoke,
    this.onInvoked,
    this.description,
    this.shortcut,
    this.keyTip,
    this.type = RibbonCommandType.action,
    this.size = RibbonCommandSize.medium,
    this.isEnabled,
    this.disabledReason,
    this.isBusy,
    this.checkState,
    this.selectedValue,
    this.menuCommands = const [],
    this.galleryItems = const [],
    this.onGalleryPreview,
    this.onGalleryPreviewEnd,
    this.onGallerySelected,
    this.onMenuOpen,
    this.onMenuClose,
    this.menuBuilder,
    this.reentryPolicy = RibbonCommandReentryPolicy.ignore,
  }) : assert(
         onInvoke != null || onInvoked != null,
         'Provide onInvoke or onInvoked.',
       );
  final String id, label;
  final String? description, shortcut, keyTip;
  final IconData icon;

  /// Legacy synchronous handler. Prefer [onInvoked] for payloads and Futures.
  final VoidCallback? onInvoke;
  final RibbonCommandHandler? onInvoked;
  final RibbonCommandType type;
  final RibbonCommandSize size;
  final bool Function(RibbonContext)? isEnabled;
  final String? Function(RibbonContext)? disabledReason;
  final bool Function(RibbonContext)? isBusy;
  final RibbonCheckState Function(RibbonContext)? checkState;
  final Object? Function(RibbonContext)? selectedValue;
  final List<RibbonCommand> menuCommands;
  final List<RibbonGalleryItem<Object?>> galleryItems;

  /// Optional temporary application while a gallery cell is hovered.
  final ValueChanged<Object?>? onGalleryPreview;

  /// Restore the pre-preview value when the gallery pointer exits.
  final VoidCallback? onGalleryPreviewEnd;
  final ValueChanged<Object?>? onGallerySelected;
  final VoidCallback? onMenuOpen;
  final VoidCallback? onMenuClose;
  final WidgetBuilder? menuBuilder;
  final RibbonCommandReentryPolicy reentryPolicy;
  bool enabledFor(RibbonContext context) => isEnabled?.call(context) ?? true;
  bool busyFor(RibbonContext context) => isBusy?.call(context) ?? false;
  RibbonCheckState stateFor(RibbonContext context) =>
      checkState?.call(context) ?? RibbonCheckState.unchecked;
  String? disabledReasonFor(RibbonContext context) =>
      disabledReason?.call(context);
}

/// A labelled group of commands and custom controls within a [RibbonTab].
class RibbonGroup {
  /// Creates a group with one to three command rows.
  const RibbonGroup({
    this.id,
    required this.label,
    this.commands = const [],
    this.controls = const [],
    this.rows = 2,
    this.width,
    this.onMoreOptions,
    this.moreOptionsTooltip,
  }) : assert(rows >= 1 && rows <= 3);
  final String? id;
  final String label;
  final List<RibbonCommand> commands;
  final List<Widget> controls;

  /// Fixed 1–3 command rows; controls remain available for custom composition.
  final int rows;
  final double? width;
  final VoidCallback? onMoreOptions;
  final String? moreOptionsTooltip;
}

/// A ribbon tab whose visibility can depend on the current [RibbonContext].
class RibbonTab {
  /// Creates a tab with a stable [id], label, and its command groups.
  const RibbonTab({
    required this.id,
    required this.label,
    required this.groups,
    this.icon,
    this.isVisible,
    this.compactCommands = const [],
    this.keyTip,
  });
  final String id, label;
  final List<RibbonGroup> groups;
  final IconData? icon;
  final bool Function(RibbonContext)? isVisible;

  /// Commands shown in compact mode. When empty, commands are derived from
  /// [groups], with medium commands rendered as small buttons.
  final List<RibbonCommand> compactCommands;
  final String? keyTip;
  bool visibleFor(RibbonContext context) => isVisible?.call(context) ?? true;
}

/// Immutable, serializable user choices for the Quick Access Toolbar and tabs.
@immutable
class RibbonPersonalization {
  static const int currentSchemaVersion = 1;

  /// Creates personalization values, using application defaults unless changed.
  const RibbonPersonalization({
    this.schemaVersion = currentSchemaVersion,
    this.quickAccessCommandIds = const [],
    this.quickAccessCustomized = false,
    this.tabOrder = const [],
    this.hiddenTabIds = const {},
  });
  final int schemaVersion;
  final List<String> quickAccessCommandIds, tabOrder;

  /// False uses the app's [MaterialRibbon.quickAccessCommands] defaults.
  /// True treats an empty [quickAccessCommandIds] list as an intentionally empty QAT.
  final bool quickAccessCustomized;
  final Set<String> hiddenTabIds;
  RibbonPersonalization copyWith({
    List<String>? quickAccessCommandIds,
    bool? quickAccessCustomized,
    List<String>? tabOrder,
    Set<String>? hiddenTabIds,
    int? schemaVersion,
  }) => RibbonPersonalization(
    schemaVersion: schemaVersion ?? this.schemaVersion,
    quickAccessCommandIds: quickAccessCommandIds ?? this.quickAccessCommandIds,
    quickAccessCustomized: quickAccessCustomized ?? this.quickAccessCustomized,
    tabOrder: tabOrder ?? this.tabOrder,
    hiddenTabIds: hiddenTabIds ?? this.hiddenTabIds,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'quickAccessCommandIds': quickAccessCommandIds,
    'quickAccessCustomized': quickAccessCustomized,
    'tabOrder': tabOrder,
    'hiddenTabIds': hiddenTabIds.toList(),
  };

  /// Returns a safe preference value for the commands and tabs still exposed
  /// by the application. Unknown IDs and duplicate IDs are removed.
  RibbonPersonalization validated({
    required Iterable<String> commandIds,
    required Iterable<String> tabIds,
  }) {
    final knownCommands = commandIds.toSet();
    final knownTabs = tabIds.toSet();
    List<String> valid(Iterable<String> ids, Set<String> known) =>
        ids.where(known.contains).toSet().toList();
    return RibbonPersonalization(
      quickAccessCommandIds: valid(quickAccessCommandIds, knownCommands),
      quickAccessCustomized: quickAccessCustomized,
      tabOrder: valid(tabOrder, knownTabs),
      hiddenTabIds: hiddenTabIds.where(knownTabs.contains).toSet(),
    );
  }

  /// Clears all user customizations and restores application defaults.
  static const RibbonPersonalization defaults = RibbonPersonalization();

  /// Decodes stored preferences, optionally migrating an older schema first.
  factory RibbonPersonalization.fromJson(
    Map<String, Object?> json, {
    RibbonPersonalizationMigration? migration,
  }) {
    final sourceVersion = json['schemaVersion'] is int
        ? json['schemaVersion']! as int
        : 0;
    final data = sourceVersion == currentSchemaVersion
        ? json
        : migration?.call(sourceVersion, Map<String, Object?>.from(json)) ??
              json;
    List<String> strings(String key) =>
        (data[key] as List<Object?>? ?? const []).whereType<String>().toList();
    return RibbonPersonalization(
      schemaVersion: currentSchemaVersion,
      quickAccessCommandIds: strings('quickAccessCommandIds'),
      quickAccessCustomized: data['quickAccessCustomized'] == true,
      tabOrder: strings('tabOrder'),
      hiddenTabIds: strings('hiddenTabIds').toSet(),
    );
  }
}

/// Adapter for app-owned persistence (SharedPreferences, database, etc.).
abstract class RibbonPersonalizationStore {
  Future<RibbonPersonalization?> load();
  Future<void> save(RibbonPersonalization personalization);
}

/// An application-defined keyboard shortcut that invokes a ribbon command.
///
/// Use a [SingleActivator], for example `SingleActivator(LogicalKeyboardKey.s,
/// control: true)`, to avoid platform-specific string parsing.
class RibbonShortcut {
  /// Creates a keyboard shortcut evaluated against the current ribbon context.
  const RibbonShortcut({
    required this.id,
    required this.activator,
    required this.onInvoke,
    this.isEnabled,
    this.description,
  });

  final String id;
  final ShortcutActivator activator;
  final VoidCallback onInvoke;
  final bool Function(RibbonContext context)? isEnabled;
  final String? description;
  bool enabledFor(RibbonContext context) => isEnabled?.call(context) ?? true;
}

/// A controlled customization surface for Quick Access commands and tab order.
///
/// The host persists [value] using [RibbonPersonalizationStore] or
/// [MaterialRibbon.onPersonalizationChanged]. It intentionally does not own
/// command definitions: applications remain in control of which commands and
/// tabs can be exposed.
class RibbonCustomizationPanel extends StatelessWidget {
  /// Creates a controlled panel for editing [RibbonPersonalization].
  const RibbonCustomizationPanel({
    super.key,
    required this.tabs,
    required this.commands,
    required this.value,
    required this.onChanged,
    this.showResetButton = true,
  });

  final List<RibbonTab> tabs;
  final List<RibbonCommand> commands;
  final RibbonPersonalization value;
  final ValueChanged<RibbonPersonalization> onChanged;
  final bool showResetButton;

  List<RibbonTab> get _orderedTabs {
    final order = {
      for (var i = 0; i < value.tabOrder.length; i++) value.tabOrder[i]: i,
    };
    return [...tabs]
      ..sort((a, b) => (order[a.id] ?? 9999).compareTo(order[b.id] ?? 9999));
  }

  void _move(String id, int direction) {
    final ids = _orderedTabs.map((tab) => tab.id).toList();
    final from = ids.indexOf(id);
    final to = from + direction;
    if (from < 0 || to < 0 || to >= ids.length) return;
    final item = ids.removeAt(from);
    ids.insert(to, item);
    onChanged(value.copyWith(tabOrder: ids));
  }

  @override
  Widget build(BuildContext context) {
    final strings = RibbonLocalizations.of(context);
    return Semantics(
      container: true,
      label: strings.customizeRibbon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showResetButton)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => onChanged(RibbonPersonalization.defaults),
                child: Text(RibbonLocalizations.of(context).resetToDefaults),
              ),
            ),
          Text(
            strings.quickAccessToolbar,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: commands
                .map(
                  (command) => FilterChip(
                    label: Text(command.label),
                    selected: value.quickAccessCommandIds.contains(command.id),
                    onSelected: (selected) {
                      final ids = [...value.quickAccessCommandIds];
                      selected ? ids.add(command.id) : ids.remove(command.id);
                      onChanged(
                        value.copyWith(
                          quickAccessCommandIds: ids.toSet().toList(),
                          quickAccessCustomized: true,
                        ),
                      );
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Text(
            strings.ribbonTabs,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 260,
            child: ListView(
              children: _orderedTabs.map((tab) {
                final hidden = value.hiddenTabIds.contains(tab.id);
                return Semantics(
                  label: strings.tabSemantics(tab.label),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: strings.moveTabUp(tab.label),
                        onPressed: () => _move(tab.id, -1),
                        icon: const Icon(Icons.keyboard_arrow_up),
                      ),
                      IconButton(
                        tooltip: strings.moveTabDown(tab.label),
                        onPressed: () => _move(tab.id, 1),
                        icon: const Icon(Icons.keyboard_arrow_down),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(tab.label),
                          value: !hidden,
                          onChanged: (visible) {
                            final hiddenIds = {...value.hiddenTabIds};
                            visible == true
                                ? hiddenIds.remove(tab.id)
                                : hiddenIds.add(tab.id);
                            onChanged(value.copyWith(hiddenTabIds: hiddenIds));
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// The top-level adaptive Material 3 ribbon command surface.
///
/// The host owns editor state through [context] and supplies [tabs]. It can
/// optionally control selection, collapse state, personalization, KeyTips,
/// scrolling, and command dispatch through the corresponding callbacks.
class MaterialRibbon extends StatefulWidget {
  /// Creates an adaptive ribbon from [tabs] and the current [context].
  const MaterialRibbon({
    super.key,
    required this.tabs,
    required this.context,
    this.height = 210,
    this.collapsed = false,
    this.onCollapsedChanged,
    this.compact,
    this.compactBreakpoint = 720,
    this.onLayoutModeChanged,
    this.leadingCommands = const [],
    this.quickAccessCommands = const [],
    this.personalization,
    this.personalizationStore,
    this.onPersonalizationChanged,
    this.commandPalette,
    this.quickAccessLimit = 4,
    this.quickAccessCollapsed = false,
    this.onQuickAccessCollapsedChanged,
    this.shortcuts = const [],
    this.showCustomizationButton = false,
    this.customizationDialogTitle,
    this.onBackstagePressed,
    this.backstageLabel = 'Backstage',
    this.backstageIcon = Icons.description_outlined,
    this.headerActions = const [],
    this.commandWrapperBuilder,
    this.controller,
    this.keyTipController,
    this.selectedTabId,
    this.onSelectedTabChanged,
    this.onCommandInvoked,
    this.onCommandError,
    this.onCommandFeedback,
    this.onKeyTipStateChanged,
    this.onKeyTipUnhandled,
    this.headerKeyTipTargets = const [],
    this.controlKeyTipTargets = const [],
    this.shortcutRegistry,
    this.shortcutScope = RibbonShortcutScope.ribbon,
    this.focusNode,
    this.autofocus = false,
    this.onNavigationIntent,
    this.localizations,
    this.headerScrollController,
    this.bodyScrollController,
  }) : assert(compactBreakpoint >= 0);
  final List<RibbonTab> tabs;
  final RibbonContext context;
  final double height;
  final bool collapsed;
  final ValueChanged<bool>? onCollapsedChanged;
  final bool? compact;
  final double compactBreakpoint;
  final ValueChanged<RibbonLayoutMode>? onLayoutModeChanged;

  /// Backward-compatible alias for [quickAccessCommands].
  final List<RibbonCommand> leadingCommands;
  final List<RibbonCommand> quickAccessCommands;
  final RibbonPersonalization? personalization;
  final RibbonPersonalizationStore? personalizationStore;
  final ValueChanged<RibbonPersonalization>? onPersonalizationChanged;

  /// Optional search surface supplied by the host, commonly [RibbonCommandPalette].
  /// It is placed in the ribbon header and is omitted automatically on narrow layouts.
  final Widget? commandPalette;
  final int quickAccessLimit;
  final bool quickAccessCollapsed;
  final ValueChanged<bool>? onQuickAccessCollapsedChanged;

  /// Application shortcuts. They are resolved while focus is inside the ribbon.
  final List<RibbonShortcut> shortcuts;

  /// Adds a dialog for changing Quick Access commands, tab visibility, and order.
  final bool showCustomizationButton;
  final String? customizationDialogTitle;

  /// Shows a Backstage chip in the header when supplied.
  final VoidCallback? onBackstagePressed;
  final String backstageLabel;
  final IconData backstageIcon;

  /// Custom actions placed before the tabs in their shared horizontal scroll area.
  final List<Widget> headerActions;

  /// Decorates command controls without changing their invocation or focus.
  /// Applied to regular commands, Quick Access and its overflow menu items.
  final Widget Function(
    BuildContext context,
    RibbonCommand command,
    Widget child,
  )?
  commandWrapperBuilder;
  final RibbonController? controller;
  final RibbonKeyTipController? keyTipController;
  final String? selectedTabId;
  final ValueChanged<String>? onSelectedTabChanged;
  final RibbonCommandHandler? onCommandInvoked;
  final RibbonCommandErrorHandler? onCommandError;

  /// Reports command start, success, and failure for host-owned feedback UI.
  final RibbonCommandFeedbackHandler? onCommandFeedback;
  final ValueChanged<RibbonKeyTipState>? onKeyTipStateChanged;
  final ValueChanged<String>? onKeyTipUnhandled;
  final List<RibbonKeyTipTarget> headerKeyTipTargets;
  final List<RibbonKeyTipTarget> controlKeyTipTargets;
  final RibbonShortcutRegistry? shortcutRegistry;
  final RibbonShortcutScope shortcutScope;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<RibbonNavigationIntent>? onNavigationIntent;

  /// Overrides locale-resolved strings for this ribbon only.
  final RibbonLocalizations? localizations;
  final ScrollController? headerScrollController;
  final ScrollController? bodyScrollController;
  @override
  State<MaterialRibbon> createState() => _MaterialRibbonState();
}

class _MaterialRibbonState extends State<MaterialRibbon> {
  List<RibbonTab> _visibleTabs = const [];
  String? _selectedTabId;
  RibbonPersonalization? _stored;
  final Set<String> _busyCommandIds = {};
  late RibbonKeyTipController _keyTips;
  late bool _ownsKeyTips;
  final FocusNode _fallbackFocusNode = FocusNode(debugLabel: 'MaterialRibbon');
  final Map<String, GlobalKey> _tabKeys = {};
  final Map<String, GlobalKey> _groupKeys = {};
  RibbonLayoutMode? _layoutMode;
  FocusNode get _focusNode => widget.focusNode ?? _fallbackFocusNode;

  @override
  void initState() {
    super.initState();
    _attachControllers();
    _load();
  }

  void _attachControllers() {
    _ownsKeyTips = widget.keyTipController == null;
    _keyTips = widget.keyTipController ?? RibbonKeyTipController();
    _keyTips.addListener(_onKeyTipChanged);
    widget.controller?.addListener(_onControllerChanged);
    widget.controller?._scrollToTab = _scrollToTab;
    widget.controller?._scrollToGroup = _scrollToGroup;
  }

  void _onKeyTipChanged() {
    if (mounted) setState(() {});
    final state = _keyTips.value;
    if (state.level == RibbonKeyTipLevel.commands && state.tabId != null) {
      _selectTab(state.tabId!);
    }
    widget.onKeyTipStateChanged?.call(_keyTips.value);
  }

  void _onControllerChanged() {
    final id = widget.controller?.selectedTabId;
    if (id != null) _selectTab(id);
  }

  Future<void> _load() async {
    final value = await widget.personalizationStore?.load();
    if (mounted && value != null && widget.personalization == null) {
      setState(() => _stored = value);
    }
  }

  RibbonPersonalization get _prefs =>
      (widget.personalization ?? _stored ?? RibbonPersonalization.defaults)
          .validated(
            commandIds: _allCommands.map((command) => command.id),
            tabIds: widget.tabs.map((tab) => tab.id),
          );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateTabs();
  }

  @override
  void didUpdateWidget(covariant MaterialRibbon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keyTipController != widget.keyTipController ||
        oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      oldWidget.controller?._scrollToTab = null;
      oldWidget.controller?._scrollToGroup = null;
      _keyTips.removeListener(_onKeyTipChanged);
      if (_ownsKeyTips) _keyTips.dispose();
      _attachControllers();
    }
    _updateTabs();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    widget.controller?._scrollToTab = null;
    widget.controller?._scrollToGroup = null;
    _keyTips.removeListener(_onKeyTipChanged);
    if (_ownsKeyTips) _keyTips.dispose();
    _fallbackFocusNode.dispose();
    super.dispose();
  }

  void _updateTabs() {
    final order = {
      for (var i = 0; i < _prefs.tabOrder.length; i++) _prefs.tabOrder[i]: i,
    };
    _visibleTabs =
        widget.tabs
            .where(
              (tab) =>
                  tab.visibleFor(widget.context) &&
                  !_prefs.hiddenTabIds.contains(tab.id),
            )
            .toList()
          ..sort(
            (a, b) => (order[a.id] ?? 9999).compareTo(order[b.id] ?? 9999),
          );
    final requested = widget.selectedTabId ?? widget.controller?.selectedTabId;
    if (requested != null && _visibleTabs.any((tab) => tab.id == requested)) {
      _selectedTabId = requested;
    }
    if (!_visibleTabs.any((tab) => tab.id == _selectedTabId)) {
      _selectedTabId = _visibleTabs.isEmpty ? null : _visibleTabs.first.id;
    }
  }

  List<RibbonCommand> get _allCommands => [
    ...widget.quickAccessCommands,
    ...widget.leadingCommands,
    for (final tab in widget.tabs)
      for (final group in tab.groups) ...group.commands,
  ];
  List<RibbonCommand> get _qat {
    final defaults = widget.quickAccessCommands.isEmpty
        ? widget.leadingCommands
        : widget.quickAccessCommands;
    if (!_prefs.quickAccessCustomized) return defaults;
    final byId = {for (final command in _allCommands) command.id: command};
    return _prefs.quickAccessCommandIds
        .map((id) => byId[id])
        .whereType<RibbonCommand>()
        .toList();
  }

  Future<void> _save(RibbonPersonalization next) async {
    setState(() {
      _stored = next;
      _updateTabs();
    });
    widget.onPersonalizationChanged?.call(next);
    await widget.personalizationStore?.save(next);
  }

  void _selectTab(String id, {bool showCommands = false}) {
    if (!_visibleTabs.any((tab) => tab.id == id)) return;
    if (_selectedTabId != id) {
      setState(() => _selectedTabId = id);
      widget.onSelectedTabChanged?.call(id);
      if (widget.controller?.selectedTabId != id) {
        widget.controller?.selectTab(id);
      }
    }
    if (showCommands) _keyTips.showCommands(id);
    _focusNode.requestFocus();
  }

  void _selectTabAt(int index, {bool showCommands = false}) {
    if (_visibleTabs.isEmpty) return;
    _selectTab(
      _visibleTabs[index.clamp(0, _visibleTabs.length - 1)].id,
      showCommands: showCommands,
    );
  }

  void _moveTab(int delta) {
    final current = _visibleTabs.indexWhere((tab) => tab.id == _selectedTabId);
    _selectTabAt((current < 0 ? 0 : current + delta) % _visibleTabs.length);
  }

  Future<void> _scrollToTab(String id) async {
    final key = _tabKeys[id];
    final target = key?.currentContext;
    if (target != null) {
      await Scrollable.ensureVisible(target, alignment: 0.5);
    }
  }

  Future<void> _scrollToGroup(String groupId, String? tabId) async {
    if (tabId != null) _selectTab(tabId);
    await WidgetsBinding.instance.endOfFrame;
    final key = _groupKeys[groupId];
    final target = key?.currentContext;
    if (target != null) {
      await Scrollable.ensureVisible(target, alignment: 0.5);
    }
  }

  void _reportLayoutMode(RibbonLayoutMode mode) {
    if (_layoutMode == mode) return;
    _layoutMode = mode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _layoutMode == mode) {
        widget.onLayoutModeChanged?.call(mode);
      }
    });
  }

  List<RibbonCommand> get _selectedCommands {
    final tab = _visibleTabs
        .where((tab) => tab.id == _selectedTabId)
        .firstOrNull;
    return tab == null
        ? const []
        : [for (final group in tab.groups) ...group.commands];
  }

  Future<void> _invoke(
    RibbonCommand command,
    RibbonInvocationSource source, {
    Object? value,
    String? tabId,
  }) async {
    if (_busyCommandIds.contains(command.id) &&
        command.reentryPolicy == RibbonCommandReentryPolicy.ignore) {
      return;
    }
    final invocation = CommandInvocation(
      commandId: command.id,
      source: source,
      tabId: tabId ?? _selectedTabId,
      value: value,
    );
    setState(() => _busyCommandIds.add(command.id));
    widget.onCommandFeedback?.call(RibbonCommandFeedback.started(invocation));
    try {
      if (widget.onCommandInvoked != null) {
        await widget.onCommandInvoked!(invocation);
      } else if (command.onInvoked != null) {
        await command.onInvoked!(invocation);
      } else {
        command.onInvoke?.call();
      }
      if (source == RibbonInvocationSource.gallery) {
        command.onGallerySelected?.call(value);
      }
      widget.onCommandFeedback?.call(
        RibbonCommandFeedback.succeeded(invocation),
      );
    } catch (error, stackTrace) {
      widget.onCommandError?.call(invocation, error, stackTrace);
      widget.onCommandFeedback?.call(
        RibbonCommandFeedback.failed(invocation, error, stackTrace),
      );
    } finally {
      if (mounted) setState(() => _busyCommandIds.remove(command.id));
    }
  }

  void _invokeShortcut(RibbonShortcut shortcut) {
    if (!shortcut.enabledFor(widget.context)) return;
    final command = _allCommands
        .where((item) => item.id == shortcut.id)
        .firstOrNull;
    if (command == null) {
      shortcut.onInvoke();
    } else {
      _invoke(command, RibbonInvocationSource.shortcut);
    }
  }

  void _showCustomizationDialog() => showDialog<void>(
    context: context,
    builder: (dialogContext) => RibbonLocalizationsScope(
      localizations: widget.localizations ?? RibbonLocalizations.of(context),
      child: AlertDialog(
        title: Text(
          widget.customizationDialogTitle ??
              (widget.localizations ?? RibbonLocalizations.of(context))
                  .customizeRibbon,
        ),
        content: SizedBox(
          width: 520,
          child: RibbonCustomizationPanel(
            tabs: widget.tabs,
            commands: _allCommands,
            value: _prefs,
            onChanged: _save,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              (widget.localizations ?? RibbonLocalizations.of(context)).done,
            ),
          ),
        ],
      ),
    ),
  );
  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.f1 &&
        HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isShiftPressed &&
        !HardwareKeyboard.instance.isAltPressed &&
        !HardwareKeyboard.instance.isMetaPressed) {
      widget.onCollapsedChanged?.call(!widget.collapsed);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.altLeft ||
        event.logicalKey == LogicalKeyboardKey.altRight ||
        event.logicalKey == LogicalKeyboardKey.f10) {
      _keyTips.value.level == RibbonKeyTipLevel.hidden
          ? _keyTips.showHeader()
          : _keyTips.hide();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape &&
        _keyTips.value.level != RibbonKeyTipLevel.hidden) {
      _keyTips.value.level == RibbonKeyTipLevel.commands
          ? _keyTips.showHeader()
          : _keyTips.hide();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        (event.logicalKey == LogicalKeyboardKey.tab &&
            HardwareKeyboard.instance.isControlPressed &&
            HardwareKeyboard.instance.isShiftPressed)) {
      widget.onNavigationIntent?.call(RibbonNavigationIntent.previousTab);
      _moveTab(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        (event.logicalKey == LogicalKeyboardKey.tab &&
            HardwareKeyboard.instance.isControlPressed)) {
      widget.onNavigationIntent?.call(RibbonNavigationIntent.nextTab);
      _moveTab(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.home) {
      widget.onNavigationIntent?.call(RibbonNavigationIntent.firstTab);
      _selectTabAt(0);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.end) {
      widget.onNavigationIntent?.call(RibbonNavigationIntent.lastTab);
      _selectTabAt(_visibleTabs.length - 1);
      return KeyEventResult.handled;
    }
    if (_keyTips.value.level == RibbonKeyTipLevel.hidden) {
      return KeyEventResult.ignored;
    }
    final key = event.character?.toUpperCase();
    if (key == null) return KeyEventResult.ignored;
    if (_keyTips.value.level == RibbonKeyTipLevel.header) {
      for (final tab in _visibleTabs) {
        if (tab.keyTip?.toUpperCase() == key) {
          _selectTab(tab.id, showCommands: true);
          return KeyEventResult.handled;
        }
      }
      for (final command in _qat) {
        if (command.keyTip?.toUpperCase() == key &&
            command.enabledFor(widget.context) &&
            !command.busyFor(widget.context)) {
          _invoke(command, RibbonInvocationSource.keyTip);
          _keyTips.hide();
          return KeyEventResult.handled;
        }
      }
      for (final target in widget.headerKeyTipTargets) {
        if (target.keyTip.toUpperCase() == key) {
          target.onInvoke();
          _keyTips.hide();
          return KeyEventResult.handled;
        }
      }
    }
    for (final command in _selectedCommands) {
      if (command.keyTip?.toUpperCase() == key &&
          command.enabledFor(widget.context) &&
          !command.busyFor(widget.context)) {
        _invoke(command, RibbonInvocationSource.keyTip);
        _keyTips.hide();
        return KeyEventResult.handled;
      }
    }
    for (final target in widget.controlKeyTipTargets) {
      if (target.keyTip.toUpperCase() == key) {
        target.onInvoke();
        _keyTips.hide();
        return KeyEventResult.handled;
      }
    }
    widget.onKeyTipUnhandled?.call(key);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    _updateTabs();
    if (_visibleTabs.isEmpty || _selectedTabId == null) {
      return const SizedBox.shrink();
    }
    final strings = widget.localizations ?? RibbonLocalizations.of(context);
    final selected = _visibleTabs.firstWhere((tab) => tab.id == _selectedTabId);
    final shortcutBindings = <ShortcutActivator, VoidCallback>{
      for (final shortcut
          in widget.shortcutRegistry?.shortcuts ?? const <RibbonShortcut>[])
        shortcut.activator: () => _invokeShortcut(shortcut),
      for (final shortcut in widget.shortcuts)
        shortcut.activator: () => _invokeShortcut(shortcut),
    };
    final content = FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: Focus(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onKeyEvent: _onKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Desktop command grids become unreadable before the common 600px phone
            // breakpoint; switch to the single-row command experience earlier.
            final compact =
                widget.compact ??
                constraints.maxWidth < widget.compactBreakpoint;
            _reportLayoutMode(
              compact ? RibbonLayoutMode.compact : RibbonLayoutMode.expanded,
            );
            return Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: SizedBox(
                height: compact
                    ? (widget.collapsed ? 52 : 112)
                    : (widget.collapsed ? 52 : widget.height),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 48,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(width: 8),
                          if (!widget.quickAccessCollapsed)
                            ..._qat
                                .take(widget.quickAccessLimit)
                                .map(
                                  (command) => SizedBox(
                                    width: 40,
                                    height: _controlHeight,
                                    child: _KeyTip(
                                      label: command.keyTip,
                                      visible:
                                          _keyTips.value.level ==
                                          RibbonKeyTipLevel.header,
                                      child: _QatButton(
                                        command,
                                        widget.context,
                                        (source, {value}) => _invoke(
                                          command,
                                          source,
                                          value: value,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          if (!widget.quickAccessCollapsed &&
                              _qat.length > widget.quickAccessLimit)
                            _QatMoreButton(
                              commands: _qat
                                  .skip(widget.quickAccessLimit)
                                  .toList(),
                              ribbonContext: widget.context,
                              invoke: _invoke,
                            ),
                          if (widget.onQuickAccessCollapsedChanged != null)
                            IconButton(
                              tooltip: widget.quickAccessCollapsed
                                  ? strings.expandQuickAccessToolbar
                                  : strings.collapseQuickAccessToolbar,
                              onPressed: () =>
                                  widget.onQuickAccessCollapsedChanged!(
                                    !widget.quickAccessCollapsed,
                                  ),
                              icon: Icon(
                                widget.quickAccessCollapsed
                                    ? Icons.keyboard_double_arrow_right
                                    : Icons.keyboard_double_arrow_left,
                              ),
                            ),
                          if (_qat.isNotEmpty &&
                              (widget.onPersonalizationChanged != null ||
                                  widget.personalizationStore != null))
                            _QatCustomizer(
                              commands: _allCommands,
                              selected: _prefs.quickAccessCommandIds,
                              onChanged: (ids) => _save(
                                _prefs.copyWith(
                                  quickAccessCommandIds: ids,
                                  quickAccessCustomized: true,
                                ),
                              ),
                            ),
                          if (widget.showCustomizationButton)
                            IconButton(
                              tooltip:
                                  widget.customizationDialogTitle ??
                                  strings.customizeRibbon,
                              onPressed: _showCustomizationDialog,
                              icon: const Icon(Icons.tune),
                            ),
                          Expanded(
                            child: Semantics(
                              container: true,
                              label: strings.tabNavigationSemantics,
                              child: RibbonHorizontalScrollView(
                                controller: widget.headerScrollController,
                                scrollbarPadding: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                children: [
                                  if (widget.onBackstagePressed != null)
                                    Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                        end: 8,
                                      ),
                                      child: RibbonActionChip(
                                        label: widget.backstageLabel,
                                        icon: Icon(
                                          widget.backstageIcon,
                                          size: 18,
                                        ),
                                        onPressed: widget.onBackstagePressed!,
                                      ),
                                    ),
                                  for (final action in widget.headerActions)
                                    Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                        end: 8,
                                      ),
                                      child: action,
                                    ),
                                  for (final target
                                      in widget.headerKeyTipTargets)
                                    if (target.child != null)
                                      Padding(
                                        padding:
                                            const EdgeInsetsDirectional.only(
                                              end: 8,
                                            ),
                                        child: RibbonKeyTip(
                                          keyTip: target.keyTip,
                                          visible:
                                              _keyTips.value.level ==
                                              RibbonKeyTipLevel.header,
                                          child: target.child!,
                                        ),
                                      ),
                                  ..._visibleTabs.map(
                                    (tab) => Padding(
                                      key: _tabKeys.putIfAbsent(
                                        tab.id,
                                        GlobalKey.new,
                                      ),
                                      padding: const EdgeInsetsDirectional.only(
                                        end: 8,
                                      ),
                                      child: SizedBox(
                                        height: _controlHeight,
                                        child: _KeyTip(
                                          label: tab.keyTip,
                                          visible:
                                              _keyTips.value.level ==
                                              RibbonKeyTipLevel.header,
                                          child: Center(
                                            child: ChoiceChip(
                                              avatar: tab.icon == null
                                                  ? null
                                                  : Icon(tab.icon, size: 18),
                                              label: Text(tab.label),
                                              selected:
                                                  tab.id == _selectedTabId,
                                              showCheckmark: false,
                                              visualDensity:
                                                  VisualDensity.compact,
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              backgroundColor:
                                                  tab.isVisible == null
                                                  ? null
                                                  : Theme.of(context)
                                                        .colorScheme
                                                        .secondaryContainer
                                                        .withValues(
                                                          alpha: 0.55,
                                                        ),
                                              selectedColor:
                                                  tab.isVisible == null
                                                  ? null
                                                  : Theme.of(context)
                                                        .colorScheme
                                                        .secondaryContainer,
                                              onSelected: (_) =>
                                                  _selectTab(tab.id),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (!compact && widget.commandPalette != null)
                            SizedBox(width: 260, child: widget.commandPalette!),
                          IconButton(
                            tooltip: widget.collapsed
                                ? strings.expandRibbon
                                : strings.collapseRibbon,
                            onPressed: widget.onCollapsedChanged == null
                                ? null
                                : () => widget.onCollapsedChanged!(
                                    !widget.collapsed,
                                  ),
                            icon: Icon(
                              widget.collapsed
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_up,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!widget.collapsed)
                      Expanded(
                        child: Semantics(
                          container: true,
                          label: strings.commandsSemantics(selected.label),
                          child: compact
                              ? _CompactActions(
                                  tab: selected,
                                  context: widget.context,
                                  showKeyTips:
                                      _keyTips.value.level ==
                                      RibbonKeyTipLevel.commands,
                                  invoke: _invoke,
                                  busyIds: _busyCommandIds,
                                  controller: widget.bodyScrollController,
                                )
                              : _TabBody(
                                  tab: selected,
                                  context: widget.context,
                                  showKeyTips:
                                      _keyTips.value.level ==
                                      RibbonKeyTipLevel.commands,
                                  invoke: _invoke,
                                  busyIds: _busyCommandIds,
                                  controller: widget.bodyScrollController,
                                  groupKeys: _groupKeys,
                                ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    final localized = RibbonLocalizationsScope(
      localizations: strings,
      child: _RibbonCommandWrappers(
        builder: widget.commandWrapperBuilder,
        child: content,
      ),
    );
    if (widget.shortcutScope == RibbonShortcutScope.application) {
      return localized;
    }
    return CallbackShortcuts(bindings: shortcutBindings, child: localized);
  }
}

class _KeyTip extends StatelessWidget {
  const _KeyTip({
    required this.label,
    required this.visible,
    required this.child,
  });
  final String? label;
  final bool visible;
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    fit: StackFit.passthrough,
    clipBehavior: Clip.none,
    children: [
      child,
      if (visible && label != null)
        Positioned(
          top: -2,
          right: -2,
          child: ExcludeSemantics(
            child: Material(
              color: Colors.black87,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  label!,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

typedef _CommandInvoker =
    Future<void> Function(
      RibbonCommand command,
      RibbonInvocationSource source, {
      Object? value,
      String? tabId,
    });

class _QatButton extends StatelessWidget {
  const _QatButton(this.command, this.context, this.invoke);
  final RibbonCommand command;
  final RibbonContext context;
  final void Function(RibbonInvocationSource source, {Object? value}) invoke;
  @override
  Widget build(BuildContext buildContext) => _RibbonCommandWrappers.wrap(
    buildContext,
    command,
    IconButton(
      tooltip: command.label,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: 40,
        height: _controlHeight,
      ),
      alignment: Alignment.center,
      visualDensity: VisualDensity.compact,
      onPressed: command.enabledFor(context) && !command.busyFor(context)
          ? () => invoke(RibbonInvocationSource.button)
          : null,
      icon: command.busyFor(context)
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(command.icon, size: 20),
    ),
  );
}

/// Mutable shortcut collection with conflict inspection. Wrap an application
/// root in [CallbackShortcuts] using [bindingsFor] for application-wide scope.
/// Mutable shortcut collection with conflict inspection.
///
/// Wrap an application root in [CallbackShortcuts] using [bindingsFor] for
/// application-wide scope.
class RibbonShortcutRegistry extends ChangeNotifier {
  /// Creates a registry and registers any initial [shortcuts].
  RibbonShortcutRegistry([Iterable<RibbonShortcut> shortcuts = const []]) {
    for (final shortcut in shortcuts) {
      register(shortcut);
    }
  }
  final Map<String, RibbonShortcut> _shortcuts = {};
  List<RibbonShortcut> get shortcuts => List.unmodifiable(_shortcuts.values);
  RibbonShortcut? register(RibbonShortcut shortcut) {
    final conflict = conflictFor(shortcut.activator, excludingId: shortcut.id);
    _shortcuts[shortcut.id] = shortcut;
    notifyListeners();
    return conflict;
  }

  bool unregister(String id) {
    final removed = _shortcuts.remove(id) != null;
    if (removed) notifyListeners();
    return removed;
  }

  RibbonShortcut? conflictFor(
    ShortcutActivator activator, {
    String? excludingId,
  }) {
    for (final shortcut in _shortcuts.values) {
      if (shortcut.id != excludingId && shortcut.activator == activator) {
        return shortcut;
      }
    }
    return null;
  }

  Map<ShortcutActivator, VoidCallback> bindingsFor(RibbonContext context) => {
    for (final shortcut in _shortcuts.values)
      shortcut.activator: () {
        if (shortcut.enabledFor(context)) shortcut.onInvoke();
      },
  };
}

class _QatCustomizer extends StatelessWidget {
  const _QatCustomizer({
    required this.commands,
    required this.selected,
    required this.onChanged,
  });
  final List<RibbonCommand> commands;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  @override
  Widget build(BuildContext context) => MenuAnchor(
    menuChildren: commands
        .map(
          (command) => CheckboxMenuButton(
            value: selected.contains(command.id),
            onChanged: (checked) {
              final next = [...selected];
              checked == true ? next.add(command.id) : next.remove(command.id);
              onChanged(next.toSet().toList());
            },
            child: Text(command.label),
          ),
        )
        .toList(),
    builder: (context, controller, _) => IconButton(
      tooltip: RibbonLocalizations.of(context).customizeQuickAccessToolbar,
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
      icon: const Icon(Icons.more_horiz),
    ),
  );
}

class _QatMoreButton extends StatelessWidget {
  const _QatMoreButton({
    required this.commands,
    required this.ribbonContext,
    required this.invoke,
  });
  final List<RibbonCommand> commands;
  final RibbonContext ribbonContext;
  final _CommandInvoker invoke;
  @override
  Widget build(BuildContext context) => MenuAnchor(
    menuChildren: commands
        .map(
          (command) => _RibbonCommandWrappers.wrap(
            context,
            command,
            MenuItemButton(
              onPressed: command.enabledFor(ribbonContext)
                  ? () => invoke(command, RibbonInvocationSource.menu)
                  : null,
              leadingIcon: Icon(command.icon),
              child: Text(command.label),
            ),
          ),
        )
        .toList(),
    builder: (context, controller, _) => IconButton(
      tooltip: RibbonLocalizations.of(context).moreQuickAccessCommands,
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
      icon: const Icon(Icons.more_horiz),
    ),
  );
}

/// A horizontally scrolling ribbon surface with a visible scrollbar.
class RibbonHorizontalScrollView extends StatefulWidget {
  /// Creates a scrolling surface for [children].
  const RibbonHorizontalScrollView({
    super.key,
    required this.children,
    this.padding,
    this.scrollbarPadding = 0,
    this.controller,
  });
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final double scrollbarPadding;
  final ScrollController? controller;
  @override
  State<RibbonHorizontalScrollView> createState() =>
      _RibbonHorizontalScrollViewState();
}

/// A compact vertical control stack for use inside a [RibbonGroup].
///
/// Children are arranged from top to bottom. A ribbon column intentionally
/// accepts no more than three children, matching the maximum command-row
/// count supported by [RibbonGroup].
class RibbonCol extends StatelessWidget {
  /// Creates a vertical stack of up to three controls.
  const RibbonCol({
    super.key,
    required this.children,
    this.spacing = 4,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  }) : assert(spacing >= 0);

  static const int maxChildren = 3;

  final List<Widget> children;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    assert(
      children.length <= maxChildren,
      'RibbonCol accepts at most $maxChildren children.',
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) SizedBox(height: spacing),
          children[index],
        ],
      ],
    );
  }
}

/// A compact control grid for use inside a [RibbonGroup].
///
/// Children are arranged from left to right in left-to-right locales, with at
/// most three children per row. Additional children are placed on the next
/// row.
class RibbonRowGrid extends StatelessWidget {
  /// Creates a control grid that wraps after three children per row.
  const RibbonRowGrid({
    super.key,
    required this.children,
    this.spacing = 4,
    this.runSpacing = 4,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  }) : assert(spacing >= 0),
       assert(runSpacing >= 0);

  static const int maxColumns = 3;

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final rows = <List<Widget>>[];
    for (var index = 0; index < children.length; index += maxColumns) {
      final end = (index + maxColumns).clamp(0, children.length).toInt();
      rows.add(children.sublist(index, end));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
          if (rowIndex > 0) SizedBox(height: runSpacing),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: crossAxisAlignment,
            children: [
              for (
                var columnIndex = 0;
                columnIndex < rows[rowIndex].length;
                columnIndex++
              ) ...[
                if (columnIndex > 0) SizedBox(width: spacing),
                rows[rowIndex][columnIndex],
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _RibbonHorizontalScrollViewState
    extends State<RibbonHorizontalScrollView> {
  late ScrollController _fallbackController;
  ScrollController get _controller => widget.controller ?? _fallbackController;
  @override
  void initState() {
    super.initState();
    _fallbackController = ScrollController();
  }

  void _handle(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_controller.hasClients) return;
    final p = _controller.position;
    _controller.jumpTo(
      (_controller.offset + event.scrollDelta.dy)
          .clamp(p.minScrollExtent, p.maxScrollExtent)
          .toDouble(),
    );
  }

  @override
  void dispose() {
    _fallbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerSignal: _handle,
    child: Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: (widget.padding ?? EdgeInsets.zero).add(
          EdgeInsets.only(bottom: widget.scrollbarPadding),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: widget.children),
      ),
    ),
  );
}

class _TabBody extends StatelessWidget {
  const _TabBody({
    required this.tab,
    required this.context,
    required this.showKeyTips,
    required this.invoke,
    required this.busyIds,
    required this.controller,
    required this.groupKeys,
  });
  final RibbonTab tab;
  final RibbonContext context;
  final bool showKeyTips;
  final _CommandInvoker invoke;
  final Set<String> busyIds;
  final ScrollController? controller;
  final Map<String, GlobalKey> groupKeys;
  @override
  Widget build(BuildContext buildContext) => RibbonHorizontalScrollView(
    controller: controller,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    children: List.generate(
      tab.groups.length,
      (i) => [
        Align(
          key: groupKeys.putIfAbsent(
            tab.groups[i].id ?? tab.groups[i].label,
            GlobalKey.new,
          ),
          alignment: Alignment.center,
          child: _Group(
            group: tab.groups[i],
            context: context,
            showKeyTips: showKeyTips,
            invoke: invoke,
            busyIds: busyIds,
          ),
        ),
        if (i < tab.groups.length - 1)
          const VerticalDivider(width: 24, indent: 4, endIndent: 4),
      ],
    ).expand((items) => items).toList(),
  );
}

class _CompactActions extends StatelessWidget {
  const _CompactActions({
    required this.tab,
    required this.context,
    required this.showKeyTips,
    required this.invoke,
    required this.busyIds,
    required this.controller,
  });
  final RibbonTab tab;
  final RibbonContext context;
  final bool showKeyTips;
  final _CommandInvoker invoke;
  final Set<String> busyIds;
  final ScrollController? controller;
  @override
  Widget build(BuildContext buildContext) {
    final commands = tab.compactCommands.isNotEmpty
        ? tab.compactCommands
        : tab.groups.expand((group) => group.commands).toList();
    return RibbonHorizontalScrollView(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: commands
          .map(
            (command) => Center(
              child: _KeyTip(
                label: command.keyTip,
                visible: showKeyTips,
                child: _CommandButton(
                  command,
                  context,
                  invoke: invoke,
                  busy: busyIds.contains(command.id),
                  compact: true,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.group,
    required this.context,
    required this.showKeyTips,
    required this.invoke,
    required this.busyIds,
  });
  final RibbonGroup group;
  final RibbonContext context;
  final bool showKeyTips;
  final _CommandInvoker invoke;
  final Set<String> busyIds;
  @override
  Widget build(BuildContext buildContext) {
    // Large commands occupy a whole command column while small and medium
    // commands tile vertically. This mirrors the dominant Office grouping
    // pattern without forcing callers to hand-build every column.
    final rowHeight = group.rows * _controlHeight + (group.rows - 1) * 4.0;
    final commandHeight = rowHeight < _largeControlHeight
        ? _largeControlHeight
        : rowHeight;
    return Semantics(
      container: true,
      label: RibbonLocalizations.of(buildContext).groupSemantics(group.label),
      child: SizedBox(
        width: group.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: commandHeight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (group.commands.isNotEmpty)
                    SizedBox(
                      height:
                          group.commands.any(
                            (command) =>
                                command.size == RibbonCommandSize.large,
                          )
                          ? commandHeight
                          : rowHeight,
                      child: Wrap(
                        direction: Axis.vertical,
                        spacing: 4,
                        runSpacing: 6,
                        children: group.commands
                            .map(
                              (command) => _KeyTip(
                                label: command.keyTip,
                                visible: showKeyTips,
                                child: _CommandButton(
                                  command,
                                  context,
                                  invoke: invoke,
                                  busy: busyIds.contains(command.id),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ...group.controls.map(
                    (control) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Theme(
                          data: Theme.of(buildContext).copyWith(
                            iconButtonTheme: IconButtonThemeData(
                              style: _controlIconStyle,
                            ),
                            // Keep native half-height marks centered in a full 40px hit target.
                            checkboxTheme: Theme.of(buildContext).checkboxTheme
                                .copyWith(
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.standard,
                                ),
                            radioTheme: Theme.of(buildContext).radioTheme
                                .copyWith(
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.standard,
                                ),
                          ),
                          child: control,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 20,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    group.label,
                    style: Theme.of(buildContext).textTheme.labelSmall,
                  ),
                  if (group.onMoreOptions != null)
                    IconButton(
                      tooltip:
                          group.moreOptionsTooltip ??
                          RibbonLocalizations.of(buildContext).moreOptions,
                      iconSize: 14,
                      visualDensity: VisualDensity.compact,
                      onPressed: group.onMoreOptions,
                      icon: const Icon(Icons.arrow_outward),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandButton extends StatelessWidget {
  const _CommandButton(
    this.command,
    this.context, {
    required this.invoke,
    required this.busy,
    this.compact = false,
  });
  final RibbonCommand command;
  final RibbonContext context;
  final _CommandInvoker invoke;
  final bool busy;
  final bool compact;
  @override
  Widget build(BuildContext buildContext) {
    final enabled = command.enabledFor(context);
    final isBusy = busy || command.busyFor(context);
    final state = command.stateFor(context);
    final compactSmall = compact && command.size == RibbonCommandSize.medium;
    final tooltip = [
      command.label,
      if (!enabled && command.disabledReasonFor(context) != null)
        command.disabledReasonFor(context)!,
      if (command.shortcut != null) command.shortcut!,
    ].join("\n");
    final icon = isBusy
        ? const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            command.icon,
            size: command.size == RibbonCommandSize.large && !compact
                ? _largeIconSize
                : 20,
          );
    void action() {
      if (enabled && !isBusy) invoke(command, RibbonInvocationSource.button);
    }

    final main = _button(
      buildContext,
      icon,
      action,
      enabled && !isBusy,
      state,
      compactSmall,
    );
    final child = switch (command.type) {
      RibbonCommandType.menu || RibbonCommandType.gallery => _MenuButton(
        command,
        context,
        icon,
        enabled && !isBusy,
        action,
        invokeCommand: invoke,
        compact: compact,
        compactSmall: compactSmall,
      ),
      RibbonCommandType.split => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          main,
          _MenuButton(
            command,
            context,
            const Icon(Icons.arrow_drop_down),
            enabled && !isBusy,
            action,
            invokeCommand: invoke,
            invoke: false,
            compact: false,
            compactSmall: compactSmall,
          ),
        ],
      ),
      _ => main,
    };
    final constrainedChild = command.size != RibbonCommandSize.large || compact
        ? SizedBox(height: _controlHeight, child: child)
        : child;
    return _RibbonCommandWrappers.wrap(
      buildContext,
      command,
      Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          enabled: enabled,
          checked: command.type == RibbonCommandType.toggle
              ? state == RibbonCheckState.checked
              : null,
          label: command.label,
          child: constrainedChild,
        ),
      ),
    );
  }

  Widget _button(
    BuildContext buildContext,
    Widget icon,
    VoidCallback action,
    bool enabled,
    RibbonCheckState state,
    bool compactSmall,
  ) {
    final selected =
        command.type == RibbonCommandType.toggle &&
        state == RibbonCheckState.checked;
    if (command.size == RibbonCommandSize.large && !compact) {
      return SizedBox(
        width: 76,
        height: _largeControlHeight,
        child: TextButton(
          onPressed: enabled ? action : null,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            alignment: Alignment.center,
            backgroundColor: selected
                ? Theme.of(buildContext).colorScheme.secondaryContainer
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(height: 5),
              Text(
                command.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }
    if ((command.size == RibbonCommandSize.medium && !compactSmall) ||
        (compact && command.size == RibbonCommandSize.large)) {
      return SizedBox(
        height: _controlHeight,
        child: TextButton.icon(
          onPressed: enabled ? action : null,
          icon: icon,
          label: Text(
            command.label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, _controlHeight),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            visualDensity: VisualDensity.standard,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: selected
                ? Theme.of(buildContext).colorScheme.secondaryContainer
                : null,
          ),
        ),
      );
    }
    return IconButton(
      style: _controlIconStyle,
      onPressed: enabled ? action : null,
      icon: icon,
      isSelected: selected,
      selectedIcon: icon,
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton(
    this.command,
    this.context,
    this.icon,
    this.enabled,
    this.onInvoke, {
    required this.invokeCommand,
    this.invoke = true,
    this.compact = false,
    this.compactSmall = false,
  });
  final RibbonCommand command;
  final RibbonContext context;
  final Widget icon;
  final bool enabled;
  final VoidCallback onInvoke;
  final _CommandInvoker invokeCommand;
  final bool invoke;
  final bool compact;
  final bool compactSmall;
  @override
  Widget build(BuildContext buildContext) => RibbonPopup(
    onOpen: command.onMenuOpen,
    onClose: command.onMenuClose,
    menuChildren: command.type == RibbonCommandType.gallery
        ? [
            SizedBox(
              width: 312,
              child: RibbonGallery<Object?>(
                items: command.galleryItems,
                selectedValue: command.selectedValue?.call(context),
                onSelected: enabled
                    ? (value) {
                        invokeCommand(
                          command,
                          RibbonInvocationSource.gallery,
                          value: value,
                        );
                      }
                    : (_) {},
                onPreview: command.onGalleryPreview,
                onPreviewEnd: command.onGalleryPreviewEnd,
                columns: 4,
                enabled: enabled,
              ),
            ),
          ]
        : [
            if (command.menuBuilder != null) command.menuBuilder!(buildContext),
            ...command.menuCommands.map(
              (item) => MenuItemButton(
                onPressed: item.enabledFor(context)
                    ? () => invokeCommand(item, RibbonInvocationSource.menu)
                    : null,
                leadingIcon: Icon(item.icon),
                child: Text(item.label),
              ),
            ),
          ],
    builder: (context, controller, _) {
      void openMenu() {
        if (invoke && command.type == RibbonCommandType.menu) onInvoke();
        controller.isOpen ? controller.close() : controller.open();
      }

      if (!compact && command.size == RibbonCommandSize.large && invoke) {
        return SizedBox(
          width: 76,
          height: _largeControlHeight,
          child: TextButton(
            onPressed: enabled ? openMenu : null,
            style: TextButton.styleFrom(padding: const EdgeInsets.all(6)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(height: 5),
                Text(
                  command.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        );
      }
      if (compact && command.type == RibbonCommandType.split) {
        return SizedBox(
          height: _controlHeight,
          child: TextButton(
            onPressed: enabled ? openMenu : null,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, _controlHeight),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.standard,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(width: 6),
                Text(
                  command.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        );
      }
      if ((command.size == RibbonCommandSize.medium && !compactSmall) ||
          (compact && command.size == RibbonCommandSize.large)) {
        return SizedBox(
          height: _controlHeight,
          child: TextButton.icon(
            onPressed: enabled ? openMenu : null,
            icon: icon,
            label: Text(
              command.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, _controlHeight),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.standard,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        );
      }
      return IconButton(
        style: _controlIconStyle,
        onPressed: enabled ? openMenu : null,
        icon: icon,
      );
    },
  );
}

/// A search field that filters and invokes a collection of ribbon commands.
class RibbonCommandPalette extends StatelessWidget {
  /// Creates a command palette for [commands] in the current [context].
  const RibbonCommandPalette({
    super.key,
    required this.commands,
    required this.context,
    this.onCommandInvoked,
    this.tabId,
    this.hintText,
  });
  final List<RibbonCommand> commands;
  final RibbonContext context;
  final RibbonCommandHandler? onCommandInvoked;
  final String? tabId;
  final String? hintText;
  @override
  Widget build(BuildContext buildContext) => SearchAnchor.bar(
    barHintText:
        hintText ?? RibbonLocalizations.of(buildContext).searchCommands,
    barLeading: const Icon(Icons.search),
    suggestionsBuilder: (searchContext, controller) {
      final query = controller.text.trim().toLowerCase();
      return commands
          .where(
            (command) =>
                command.enabledFor(context) &&
                !command.busyFor(context) &&
                (query.isEmpty ||
                    "${command.label} ${command.description ?? ""}"
                        .toLowerCase()
                        .contains(query)),
          )
          .map(
            (command) => ListTile(
              leading: Icon(command.icon),
              title: Text(command.label),
              subtitle: command.description == null
                  ? null
                  : Text(command.description!),
              trailing: command.shortcut == null
                  ? null
                  : Text(command.shortcut!),
              onTap: () {
                controller.closeView(command.label);
                final event = CommandInvocation(
                  commandId: command.id,
                  source: RibbonInvocationSource.commandPalette,
                  tabId: tabId,
                );
                if (onCommandInvoked != null) {
                  onCommandInvoked!(event);
                } else if (command.onInvoked != null) {
                  command.onInvoked!(event);
                } else {
                  command.onInvoke?.call();
                }
              },
            ),
          );
    },
  );
}

/// A ready-made font-size slider and text-colour picker row.
class TextFormatControls extends StatelessWidget {
  /// Creates controlled text-formatting controls.
  const TextFormatControls({
    super.key,
    required this.fontSize,
    required this.color,
    required this.onFontSizeChanged,
    required this.onColorChanged,
  });
  final double fontSize;
  final Color color;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<Color> onColorChanged;
  static const _colors = <Color>[
    Colors.black,
    Colors.red,
    Colors.orange,
    Colors.green,
    Colors.blue,
    Colors.purple,
  ];
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 132,
        height: _controlHeight,
        child: Slider(
          value: fontSize.clamp(8, 72),
          min: 8,
          max: 72,
          divisions: 64,
          label: "${fontSize.round()} pt",
          onChanged: onFontSizeChanged,
        ),
      ),
      MenuAnchor(
        menuChildren: _colors
            .map(
              (choice) => MenuItemButton(
                onPressed: () => onColorChanged(choice),
                child: Icon(Icons.circle, color: choice),
              ),
            )
            .toList(),
        builder: (context, controller, _) => IconButton.outlined(
          style: _controlIconStyle,
          tooltip: RibbonLocalizations.of(context).textColor,
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          icon: Icon(Icons.format_color_text, color: color),
        ),
      ),
    ],
  );
}

class _RibbonCommandWrappers extends InheritedWidget {
  const _RibbonCommandWrappers({required this.builder, required super.child});
  final Widget Function(BuildContext, RibbonCommand, Widget)? builder;
  static Widget wrap(
    BuildContext context,
    RibbonCommand command,
    Widget child,
  ) =>
      context
          .dependOnInheritedWidgetOfExactType<_RibbonCommandWrappers>()
          ?.builder
          ?.call(context, command, child) ??
      child;
  @override
  bool updateShouldNotify(_RibbonCommandWrappers oldWidget) =>
      builder != oldWidget.builder;
}
