// Copyright 2025-2026 Heyairu（部屋伊琉）
// Licensed under the Apache License, Version 2.0.
// https://www.apache.org/licenses/LICENSE-2.0

import "../features/help/help_controller.dart";
import "../features/help/help_scope.dart";
import "../features/help/help_topic.dart";
import "dart:developer" as developer;

import "package:flutter/material.dart";
import "package:material_ribbon/material_ribbon.dart";

import "../models/toolbar_mode.dart";
import "findreplace.dart";

/// Three presentations sharing commands, editor targets, and project history.
class MonogatariTopAppBar extends StatefulWidget
    implements PreferredSizeWidget {
  final ValueChanged<String>? onHelpAction;
  final double iconSize;
  final ToolbarMode mode;
  final ToolbarMode? modePreference;
  final ValueChanged<ToolbarMode?> onModeChanged;
  final Widget? statusIndicator;
  final bool isProjectIoBusy;
  final bool showPunctuationPanel;
  final bool showFindReplaceWindow;
  final Future<void> Function(String) onFileAction;
  final Future<void> Function(String) onEditorAction;
  final VoidCallback onEditorActionPointerDown;
  final VoidCallback onEditorActionInteractionEnd;
  final VoidCallback onTogglePunctuationPanel;
  final VoidCallback onToggleFindReplaceWindow;
  final RibbonController? controller;
  final FindReplaceOptions? searchOptions;
  final String searchQuery;
  final ValueChanged<FindReplaceOption>? onSearchOptionChanged;

  const MonogatariTopAppBar({
    super.key,
    this.onHelpAction,
    required this.iconSize,
    required this.mode,
    required this.modePreference,
    required this.onModeChanged,
    this.statusIndicator,
    this.isProjectIoBusy = false,
    required this.showPunctuationPanel,
    required this.showFindReplaceWindow,
    required this.onFileAction,
    required this.onEditorAction,
    required this.onEditorActionPointerDown,
    required this.onEditorActionInteractionEnd,
    required this.onTogglePunctuationPanel,
    required this.onToggleFindReplaceWindow,
    this.controller,
    this.searchOptions,
    this.searchQuery = "",
    this.onSearchOptionChanged,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(mode == ToolbarMode.full ? 210 : 108);

  @override
  State<MonogatariTopAppBar> createState() => _MonogatariTopAppBarState();
}

class _MonogatariTopAppBarState extends State<MonogatariTopAppBar> {
  static const _ribbonContext = RibbonContext();
  static const _fileIds = [
    "save",
    "new",
    "open",
    "saveAs",
    "import_selective",
    "export_selective",
  ];
  static const _editIds = ["selectAll", "cut", "copy", "paste"];
  final _running = <String>{};
  final _scrollController = ScrollController();
  bool _menuOpen = false;
  String _selectedTabId = "home";
  final _defaultSearchOptions = FindReplaceOptions();

  @override
  void initState() {
    super.initState();
    if (widget.showFindReplaceWindow) _selectedTabId = "search";
  }

  @override
  void didUpdateWidget(covariant MonogatariTopAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.showFindReplaceWindow && widget.showFindReplaceWindow) {
      _selectTab("search");
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openMenu() {
    _menuOpen = true;
    widget.onEditorActionPointerDown();
  }

  void _endInteraction() {
    // Pointer-up reaches this listener before PopupMenuButton.onOpened.
    // Wait until the menu has claimed focus before releasing the editor target.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_menuOpen) widget.onEditorActionInteractionEnd();
    });
  }

  void _closeMenu() {
    _menuOpen = false;
    _endInteraction();
  }

  Map<String, RibbonCommand> get _commands {
    RibbonCommand command(
      String id,
      String label,
      IconData icon, {
      bool? selected,
      bool enabled = true,
      String? disabledReason,
      RibbonCommandSize size = RibbonCommandSize.medium,
    }) => RibbonCommand(
      id: id,
      label: label,
      icon: icon,
      size: size,
      type: selected == null
          ? RibbonCommandType.action
          : RibbonCommandType.toggle,
      checkState: (_) => selected == true
          ? RibbonCheckState.checked
          : RibbonCheckState.unchecked,
      isEnabled: (_) =>
          enabled &&
          (!_fileIds.contains(id) ||
              (!widget.isProjectIoBusy && !_running.any(_fileIds.contains))),
      disabledReason: (_) => disabledReason,
      isBusy: (_) => _running.contains(id),
      onInvoked: (event) => _invoke(event.commandId),
    );
    final commands = [
      command(
        "save",
        "儲存檔案",
        Icons.save_outlined,
        size: RibbonCommandSize.large,
      ),
      command("new", "新建檔案", Icons.note_add_outlined),
      command("open", "開啟檔案", Icons.folder_open_outlined),
      command("saveAs", "另存新檔", Icons.save_as_outlined),
      command("import_selective", "匯入", Icons.input),
      command("export_selective", "匯出", Icons.output),
      command("selectAll", "全選", Icons.select_all),
      command("cut", "剪下", Icons.content_cut),
      command("copy", "複製", Icons.content_copy),
      command(
        "paste",
        "貼上",
        Icons.content_paste,
        size: RibbonCommandSize.large,
      ),
      command("undo", "復原", Icons.undo),
      command("redo", "重做", Icons.redo),
      command(
        "punctuation",
        "標點符號",
        Icons.keyboard_alt_outlined,
        selected: widget.showPunctuationPanel,
      ),
      command(
        "find",
        "搜尋",
        Icons.search,
        selected: widget.showFindReplaceWindow,
      ),
    ];
    final options = widget.searchOptions ?? _defaultSearchOptions;
    for (final (option, label, icon) in [
      (FindReplaceOption.matchCase, "大小寫需相同", Icons.text_fields),
      (FindReplaceOption.wholeWord, "全字拼寫相符", Icons.text_format),
      (FindReplaceOption.useRegexp, "使用正則表示", Icons.data_object),
      (FindReplaceOption.matchWidth, "全半形須相符", Icons.width_normal),
      (FindReplaceOption.ignorePunctuation, "略過標點符號", Icons.format_quote),
      (FindReplaceOption.ignoreWhitespace, "略過空白字元", Icons.space_bar),
    ]) {
      final enabled = options.enabledFor(option, widget.searchQuery);
      commands.add(
        command(
          "search.${option.name}",
          label,
          icon,
          selected: options.valueFor(option),
          enabled: enabled && widget.onSearchOptionChanged != null,
          disabledReason: enabled
              ? null
              : options.useRegexp
              ? "正則表示模式固定大小寫與全半形相符，並停用全字拼寫。"
              : "搜尋文字含全形字元、標點或空白，無法使用全字拼寫。",
        ),
      );
    }
    return {for (final command in commands) command.id: command};
  }

  /// Validate again when executing, regardless of the presentation or KeyTip.
  Future<void> _invoke(String id) async {
    final command = _commands[id];
    if (command == null ||
        !command.enabledFor(_ribbonContext) ||
        command.busyFor(_ribbonContext)) {
      return;
    }
    setState(() => _running.add(id));
    try {
      if (_fileIds.contains(id)) {
        await widget.onFileAction(id);
      } else if (_editIds.contains(id) || id == "undo" || id == "redo") {
        await widget.onEditorAction(id);
      } else if (id == "punctuation") {
        widget.onTogglePunctuationPanel();
      } else if (id == "find") {
        widget.onToggleFindReplaceWindow();
      } else if (id.startsWith("search.")) {
        final option = FindReplaceOption.values.firstWhere(
          (option) => id == "search.${option.name}",
        );
        widget.onSearchOptionChanged?.call(option);
      }
    } catch (error, stackTrace) {
      developer.log(
        "Toolbar command failed: $id",
        name: "MonoAshi.Toolbar",
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("無法完成「${command.label}」，請重試。")));
      }
    } finally {
      if (mounted) setState(() => _running.remove(id));
      _endInteraction();
    }
  }

  List<RibbonTab> _tabs(Map<String, RibbonCommand> commands) => [
    RibbonTab(
      id: "file",
      label: "檔案",
      keyTip: "F",
      groups: [
        RibbonGroup(
          id: "project",
          label: "專案",
          rows: 3,
          commands: [
            for (final id
                in widget.mode == ToolbarMode.full
                    ? ["save", "new", "open", "saveAs"]
                    : ["new", "open", "save", "saveAs"])
              commands[id]!,
          ],
        ),
        RibbonGroup(
          id: "transfer",
          label: "資料交換",
          commands: [
            commands["import_selective"]!,
            commands["export_selective"]!,
          ],
        ),
      ],
    ),
    RibbonTab(
      id: "home",
      label: "常用",
      keyTip: "H",
      groups: [
        RibbonGroup(
          id: "clipboard",
          label: "剪貼簿",
          rows: 3,
          commands: [
            for (final id in ["paste", "cut", "copy", "selectAll"])
              commands[id]!,
          ],
        ),
        RibbonGroup(
          id: "history",
          label: "歷史",
          commands: [commands["undo"]!, commands["redo"]!],
        ),
        RibbonGroup(
          id: "tools",
          label: "寫作工具",
          commands: [commands["punctuation"]!, commands["find"]!],
        ),
      ],
    ),
    RibbonTab(
      id: "search",
      label: "搜尋",
      keyTip: "S",
      groups: [
        RibbonGroup(
          id: "search-panel",
          label: "尋找與取代",
          commands: [commands["find"]!],
        ),
        RibbonGroup(
          id: "search-match",
          label: "符合條件",
          rows: 3,
          commands: [
            for (final option in [
              FindReplaceOption.matchCase,
              FindReplaceOption.wholeWord,
              FindReplaceOption.matchWidth,
            ])
              commands["search.${option.name}"]!,
          ],
        ),
        RibbonGroup(
          id: "search-mode",
          label: "搜尋方式",
          rows: 3,
          commands: [
            for (final option in [
              FindReplaceOption.useRegexp,
              FindReplaceOption.ignorePunctuation,
              FindReplaceOption.ignoreWhitespace,
            ])
              commands["search.${option.name}"]!,
          ],
        ),
      ],
    ),
  ];

  void _selectTab(String id) {
    if (_selectedTabId == id) return;
    setState(() => _selectedTabId = id);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    if (id == "search" && !widget.showFindReplaceWindow) {
      widget.onToggleFindReplaceWindow();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller?.scrollToTab(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final commands = _commands;
    final tabs = _tabs(commands);
    final selectedTab = tabs.firstWhere((tab) => tab.id == _selectedTabId);
    final full = widget.mode == ToolbarMode.full;
    return HelpScope(
      topicId: HelpTopicId.toolbar,
      child: Listener(
        onPointerDown: (_) => widget.onEditorActionPointerDown(),
        onPointerUp: (_) => _endInteraction(),
        onPointerCancel: (_) => _endInteraction(),
        child: SafeArea(
          bottom: false,
          child: Material(
            key: Key("toolbar-${widget.mode.name}"),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MaterialRibbon(
                  key: const Key("toolbar-ribbon"),
                  controller: widget.controller,
                  commandWrapperBuilder: (context, command, child) =>
                      HelpTarget(
                        topicId: HelpTopicId.forCommand(command.id),
                        child: child,
                      ),
                  compact: false,
                  collapsed: !full,
                  context: _ribbonContext,
                  localizations: RibbonLocalizations.traditionalChinese,
                  selectedTabId: _selectedTabId,
                  onSelectedTabChanged: _selectTab,
                  bodyScrollController: _scrollController,
                  onCollapsedChanged: (_) => widget.onModeChanged(
                    full ? ToolbarMode.concise : ToolbarMode.full,
                  ),
                  headerActions: [
                    _HelpMenu(
                      onAction: widget.onHelpAction,
                      onOpened: _openMenu,
                      onClosed: _closeMenu,
                    ),
                    if (widget.statusIndicator != null) widget.statusIndicator!,
                    HelpTarget(
                      topicId: HelpTopicId.toolbarMode,
                      child: _ToolbarModeMenu(
                        preference: widget.modePreference,
                        onChanged: widget.onModeChanged,
                        onOpened: _openMenu,
                        onClosed: _closeMenu,
                      ),
                    ),
                  ],
                  quickAccessCommands: [
                    commands["save"]!,
                    commands["undo"]!,
                    commands["redo"]!,
                  ],
                  tabs: tabs,
                ),
                if (!full)
                  SizedBox(
                    height: 56,
                    child: Scrollbar(
                      controller: _scrollController,
                      child: SingleChildScrollView(
                        key: const Key("toolbar-command-scroll"),
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            for (final group in selectedTab.groups)
                              for (final command in group.commands)
                                _ToolbarCommandButton(
                                  command: command,
                                  showLabel:
                                      widget.mode == ToolbarMode.moderate,
                                  iconSize: widget.iconSize,
                                  onInvoke: () => _invoke(command.id),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarCommandButton extends StatelessWidget {
  const _ToolbarCommandButton({
    required this.command,
    required this.showLabel,
    required this.iconSize,
    required this.onInvoke,
  });
  final RibbonCommand command;
  final bool showLabel;
  final double iconSize;
  final VoidCallback onInvoke;

  @override
  Widget build(BuildContext context) {
    final busy = command.busyFor(const RibbonContext());
    final selected = command.type == RibbonCommandType.toggle
        ? command.stateFor(const RibbonContext()) == RibbonCheckState.checked
        : null;
    final searchState = command.id.startsWith("search.") ? selected : null;
    return HelpTarget(
      topicId: HelpTopicId.forCommand(command.id),
      child: Semantics(
        toggled: searchState,
        child: IconButton(
          key: ValueKey("toolbar-command-${command.id}"),
          tooltip: [
            command.label,
            if (!command.enabledFor(const RibbonContext()) &&
                command.disabledReasonFor(const RibbonContext()) != null)
              command.disabledReasonFor(const RibbonContext())!,
          ].join("\n"),
          isSelected: selected,
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: searchState == true
                ? Theme.of(context).colorScheme.secondaryContainer
                : null,
          ),
          onPressed: command.enabledFor(const RibbonContext()) && !busy
              ? onInvoke
              : null,
          icon: _ToolbarButtonContent(
            icon: command.icon,
            iconSize: iconSize,
            label: showLabel ? command.label : null,
            busy: busy,
            searchState: searchState,
          ),
        ),
      ),
    );
  }
}

class _ToolbarButtonContent extends StatelessWidget {
  const _ToolbarButtonContent({
    required this.icon,
    required this.iconSize,
    this.label,
    this.busy = false,
    this.searchState,
  });
  final IconData icon;
  final double iconSize;
  final String? label;
  final bool busy;
  final bool? searchState;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (busy)
        const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      else
        Icon(icon, size: iconSize),
      if (label != null) ...[
        const SizedBox(width: 6),
        Text(label!, style: Theme.of(context).textTheme.labelLarge),
      ],
      if (searchState != null) ...[
        const SizedBox(width: 4),
        ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            decoration: BoxDecoration(
              color: searchState!
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  searchState! ? Icons.check : Icons.close,
                  size: 12,
                  color: searchState!
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                if (label != null)
                  Text(
                    searchState! ? "開" : "關",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: searchState!
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ],
  );
}

class _ToolbarModeMenu extends StatelessWidget {
  const _ToolbarModeMenu({
    required this.preference,
    required this.onChanged,
    required this.onOpened,
    required this.onClosed,
  });
  final ToolbarMode? preference;
  final ValueChanged<ToolbarMode?> onChanged;
  final VoidCallback onOpened;
  final VoidCallback onClosed;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    key: const Key("toolbar-mode-menu"),
    tooltip: "工具列模式",
    icon: const Icon(Icons.view_compact_outlined),
    onOpened: onOpened,
    onCanceled: onClosed,
    onSelected: (value) {
      onChanged(ToolbarMode.fromPreference(value));
      onClosed();
    },
    itemBuilder: (_) => [
      CheckedPopupMenuItem(
        value: "automatic",
        checked: preference == null,
        child: const Text("自動（桌面 Full／手機 Moderate）"),
      ),
      for (final mode in ToolbarMode.values)
        CheckedPopupMenuItem(
          value: mode.name,
          checked: preference == mode,
          child: Text(mode.label),
        ),
    ],
  );
}

class _HelpMenu extends StatefulWidget {
  const _HelpMenu({
    this.onAction,
    required this.onOpened,
    required this.onClosed,
  });
  final ValueChanged<String>? onAction;
  final VoidCallback onOpened;
  final VoidCallback onClosed;
  @override
  State<_HelpMenu> createState() => _HelpMenuState();
}

class _HelpMenuState extends State<_HelpMenu> {
  bool _pointerCaptured = false;

  @override
  Widget build(BuildContext context) {
    final help = HelpController.maybeOf(context);
    return HelpTarget(
      topicId: HelpTopicId.usingHelp,
      child: Listener(
        onPointerDown: (_) {
          help?.beginMenu();
          _pointerCaptured = true;
        },
        child: PopupMenuButton<String>(
          tooltip: '說明',
          onOpened: () {
            if (!_pointerCaptured) help?.beginMenu();
            _pointerCaptured = false;
            widget.onOpened();
          },
          onCanceled: () {
            help?.endMenu();
            widget.onClosed();
          },
          icon: const Icon(Icons.help_outline),
          onSelected: (action) {
            widget.onClosed();
            if (widget.onAction != null) {
              widget.onAction!(action);
              help?.endMenu();
              return;
            }
            switch (action) {
              case 'home':
                help?.showTopic(HelpTopicId.home);
              case 'context':
                help?.showCapturedContext();
              case 'pick':
                help?.togglePicking(useCapturedContext: true);
            }
            help?.endMenu();
          },
          itemBuilder: (_) => [
            for (final (id, label) in const [
              ('home', '說明首頁'),
              ('context', '目前功能說明（F1）'),
              ('pick', '這是什麼？（Shift+F1）'),
            ])
              HelpPopupMenuItem(
                topicId: HelpTopicId.usingHelp,
                value: id,
                child: HelpTarget(
                  topicId: HelpTopicId.usingHelp,
                  child: Text(label),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
