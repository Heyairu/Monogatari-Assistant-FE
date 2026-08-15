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

import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math" as math;

import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../bin/ui_library.dart";
import "../models/palette_data.dart";
import "../presentation/providers/palette_state_provider.dart";

class PalettesView extends ConsumerStatefulWidget {
  const PalettesView({super.key});

  @override
  ConsumerState<PalettesView> createState() => _PalettesViewState();
}

class _PalettesViewState extends ConsumerState<PalettesView> {
  final TextEditingController _searchController = TextEditingController();
  TextEditingController? _entryEditorController;
  FocusNode? _entryEditorFocusNode;

  bool _isLoading = true;
  bool _hasLoaded = false;
  String? _loadError;
  String? _loadWarning;
  int _selectedHue = 0;
  String? _addingSlotId;
  String? _editingEntryId;
  late final PaletteStateNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(paletteStateProvider.notifier);
    _searchController.addListener(_handleSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_load());
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    if (_hasLoaded) {
      _commitActiveEditor(updateUi: false, showFeedback: false);
    }
    _disposeEntryEditor();
    if (_hasLoaded) {
      unawaited(_notifier.flushPalettePersistence().catchError((Object _) {}));
    }
    super.dispose();
  }

  void _handleSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasLoaded = false;
      _loadError = null;
      _loadWarning = null;
    });
    try {
      final PaletteLoadResult result = await _notifier.loadFromRepository();
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _hasLoaded = true;
        _loadWarning = result.warnings.isEmpty
            ? null
            : "已略過或修復 ${result.warnings.length} 項調色盤資料問題。";
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _hasLoaded = false;
        _loadError = "調色盤資料無法讀取：$error";
      });
    }
  }

  void _disposeEntryEditor() {
    _entryEditorController?.dispose();
    _entryEditorFocusNode?.dispose();
    _entryEditorController = null;
    _entryEditorFocusNode = null;
  }

  void _finishEntryEditor() {
    final TextEditingController? controller = _entryEditorController;
    final FocusNode? focusNode = _entryEditorFocusNode;
    setState(() {
      _addingSlotId = null;
      _editingEntryId = null;
      _entryEditorController = null;
      _entryEditorFocusNode = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller?.dispose();
      focusNode?.dispose();
    });
  }

  bool _prepareForAnotherEditor() {
    if (_addingSlotId == null && _editingEntryId == null) {
      return true;
    }
    return _commitActiveEditor();
  }

  void _beginAdd(String slotId) {
    if (!_prepareForAnotherEditor()) {
      return;
    }
    _disposeEntryEditor();
    setState(() {
      _addingSlotId = slotId;
      _editingEntryId = null;
      _entryEditorController = TextEditingController();
      _entryEditorFocusNode = FocusNode();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entryEditorFocusNode?.requestFocus();
    });
  }

  void _beginEdit(PaletteEntry entry) {
    if (!_prepareForAnotherEditor()) {
      return;
    }
    _disposeEntryEditor();
    setState(() {
      _addingSlotId = null;
      _editingEntryId = entry.id;
      _entryEditorController = TextEditingController(text: entry.text)
        ..selection = TextSelection.collapsed(offset: entry.text.length);
      _entryEditorFocusNode = FocusNode();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entryEditorFocusNode?.requestFocus();
    });
  }

  bool _commitActiveEditor({bool updateUi = true, bool showFeedback = true}) {
    final TextEditingController? controller = _entryEditorController;
    if (controller == null) {
      return true;
    }

    PaletteMutationResult result;
    if (_addingSlotId != null) {
      result = _notifier.addEntry(
        slotId: _addingSlotId!,
        text: controller.text,
      );
    } else if (_editingEntryId != null) {
      result = _notifier.renameEntry(
        entryId: _editingEntryId!,
        text: controller.text,
      );
    } else {
      return true;
    }

    if (!result.changed) {
      if (showFeedback && mounted) {
        AppFeedback.warning(context, result.error ?? "無法儲存詞條");
      }
      return false;
    }

    if (updateUi && mounted) {
      _finishEntryEditor();
    }
    return true;
  }

  void _cancelActiveEditor() {
    _finishEntryEditor();
  }

  void _selectHue(int hue) {
    if (!_commitActiveEditor()) {
      return;
    }
    setState(() {
      _selectedHue = hue;
    });
  }

  void _removeEntry(PaletteEntry entry) {
    if (_editingEntryId == entry.id) {
      _cancelActiveEditor();
    }
    final PaletteEntryRemovalRecord? record = _notifier.removeEntry(entry.id);
    if (record == null) {
      return;
    }
    AppFeedback.show(
      context,
      message: "已刪除「${entry.text}」",
      tone: AppFeedbackTone.warning,
      actionLabel: "復原",
      onAction: () {
        _notifier.restoreEntry(record);
      },
    );
  }

  Color _slotColor(PaletteSlotDefinition slot) {
    final double hue = slot.hue == 360 ? 0 : slot.hue.toDouble();
    return HSVColor.fromAHSV(
      1,
      hue,
      slot.saturation / 100,
      slot.value / 100,
    ).toColor();
  }

  Color _contentColorFor(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  List<_PaletteSearchHit> _searchHits(PaletteStateData state) {
    final String query = normalizePaletteTerm(_searchController.text);
    if (query.isEmpty) {
      return const <_PaletteSearchHit>[];
    }
    final List<_PaletteSearchHit> hits = <_PaletteSearchHit>[];
    for (final PaletteSlotDefinition slot in allPaletteSlots) {
      for (final String entryId
          in state.slotEntryIds[slot.id] ?? const <String>[]) {
        final PaletteEntry? entry = state.entryIndex[entryId];
        if (entry != null && normalizePaletteTerm(entry.text).contains(query)) {
          hits.add(_PaletteSearchHit(slot: slot, entry: entry));
        }
      }
    }
    return hits;
  }

  Future<void> _exportPalette() async {
    if (!_commitActiveEditor()) {
      return;
    }
    final String? savedPath = await FilePicker.platform.saveFile(
      dialogTitle: "匯出文字色票",
      fileName: "Palettes.yaml",
      type: FileType.custom,
      allowedExtensions: const <String>["yaml", "yml"],
    );
    if (!mounted || savedPath == null) {
      return;
    }

    final String resolvedPath =
        savedPath.toLowerCase().endsWith(".yaml") ||
            savedPath.toLowerCase().endsWith(".yml")
        ? savedPath
        : "$savedPath.yaml";
    try {
      final String content = PaletteYamlCodec.encode(
        ref.read(paletteStateProvider),
      );
      await File(resolvedPath).writeAsString(content, flush: true);
      if (!mounted) {
        return;
      }
      final String fileName = resolvedPath
          .replaceAll("\\", "/")
          .split("/")
          .last;
      AppFeedback.success(
        context,
        "色票匯出完成：$fileName",
        duration: const Duration(seconds: 2),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppFeedback.error(
        context,
        "色票匯出失敗：$error",
        duration: const Duration(seconds: 2),
      );
    }
  }

  Future<void> _importPalette() async {
    if (!_commitActiveEditor()) {
      return;
    }
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: "匯入文字色票",
      type: FileType.custom,
      allowedExtensions: const <String>["yaml", "yml"],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    try {
      final PlatformFile picked = result.files.first;
      String? raw;
      if (picked.bytes != null) {
        raw = utf8.decode(picked.bytes!);
      } else if (picked.path != null) {
        raw = await File(picked.path!).readAsString();
      }
      if (raw == null || raw.trim().isEmpty) {
        throw const FormatException("檔案沒有內容");
      }

      final PaletteDecodeResult decoded = PaletteYamlCodec.decode(raw);
      final PaletteImportMergeResult merged = _notifier.mergeImportedData(
        decoded.data,
      );
      if (merged.changed) {
        await _notifier.flushPalettePersistence();
      }
      if (!mounted) {
        return;
      }

      final String warningText = decoded.warnings.isEmpty
          ? ""
          : "，另略過 ${decoded.warnings.length} 項格式問題";
      if (merged.changed) {
        AppFeedback.success(
          context,
          "匯入完成：新增 ${merged.addedPlacements} 個色票詞條、略過 ${merged.skippedDuplicates} 個重複詞條$warningText",
          duration: const Duration(seconds: 3),
        );
      } else {
        AppFeedback.info(
          context,
          "沒有新增色票；已略過 ${merged.skippedDuplicates} 個重複詞條$warningText",
          duration: const Duration(seconds: 2),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppFeedback.error(
        context,
        "色票匯入失敗：檔案格式錯誤或無法讀取",
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final PaletteStateData state = ref.watch(paletteStateProvider);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AppNoticeBanner(
              title: "調色盤載入失敗",
              message: _loadError!,
              tone: AppFeedbackTone.error,
              action: FilledButton.tonal(
                onPressed: _load,
                child: const Text("重試"),
              ),
            ),
          ),
        ),
      );
    }

    final String searchQuery = _searchController.text.trim();
    final List<_PaletteSearchHit> hits = _searchHits(state);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildHeader(context),
          if (_loadWarning != null) ...<Widget>[
            const SizedBox(height: 12),
            AppNoticeBanner(
              message: _loadWarning!,
              tone: AppFeedbackTone.warning,
              compact: true,
              onDismiss: () => setState(() => _loadWarning = null),
            ),
          ],
          if (state.persistenceError != null) ...<Widget>[
            const SizedBox(height: 12),
            AppNoticeBanner(
              title: "尚未寫入磁碟",
              message: state.persistenceError!,
              tone: AppFeedbackTone.error,
              compact: true,
              action: TextButton(
                onPressed: () async {
                  try {
                    await _notifier.flushPalettePersistence();
                  } catch (_) {}
                },
                child: const Text("重試"),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: searchQuery.isNotEmpty
                ? _buildSearchResults(hits, searchQuery)
                : _buildPaletteContent(state),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final menuIconColor = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LargeTitle(icon: Icons.palette_outlined, text: "文字色票"),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Expanded(
              child: AppTextField(
                key: const ValueKey<String>("palette-search-field"),
                controller: _searchController,
                hintText: "搜尋詞條……",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: "清除搜尋",
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              key: const ValueKey<String>("palette-import-export-menu"),
              tooltip: "匯入或匯出色票",
              iconColor: menuIconColor,
              onSelected: (String value) {
                switch (value) {
                  case "import":
                    unawaited(_importPalette());
                    break;
                  case "export":
                    unawaited(_exportPalette());
                    break;
                }
              },
              itemBuilder: (BuildContext context) =>
                  const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: "import",
                      child: ListTile(
                        leading: Icon(Icons.file_open_outlined),
                        title: Text("匯入色票……"),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: "export",
                      child: ListTile(
                        leading: Icon(Icons.save_alt_outlined),
                        title: Text("匯出色票……"),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
              icon: Icon(
                Icons.import_export_outlined,
                color: menuIconColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaletteContent(PaletteStateData state) {
    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(child: _buildHuePicker()),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverToBoxAdapter(
          child: Text(
            "Hue $_selectedHue°",
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        SliverToBoxAdapter(
          child: _buildSlotWrap(paletteSlotsForHue(_selectedHue), state),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        SliverToBoxAdapter(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              initiallyExpanded: true,
              leading: const Icon(Icons.gradient_outlined),
              title: const Text("灰階"),
              subtitle: const Text("S 0% · V 0 / 20 / 50 / 80 / 100%"),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: _buildSlotWrap(paletteGraySlots, state),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildHuePicker() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double availableWidth = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : 520;
                final double diameter = math.min(availableWidth, 520);
                return Center(
                  child: SizedBox.square(
                    dimension: diameter,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: const _HueRingPainter(),
                            ),
                          ),
                        ),
                        Center(
                          child: Container(
                            width: diameter * 0.28,
                            height: diameter * 0.28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerLowest,
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  "Hue",
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                        color: HSVColor.fromAHSV(
                                          1,
                                          _selectedHue.toDouble(),
                                          0.6,
                                          0.8,
                                        ).toColor(),
                                  ),
                                ),
                                Text(
                                  "$_selectedHue°",
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: HSVColor.fromAHSV(
                                          1,
                                          _selectedHue.toDouble(),
                                          0.6,
                                          0.8,
                                        ).toColor(),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        for (final int hue in paletteHueDegrees)
                          ..._buildHueRingItems(hue, diameter),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildHueRingItems(int hue, double diameter) {
    final bool selected = hue == _selectedHue;
    final Color swatchColor = HSVColor.fromAHSV(
      1,
      hue.toDouble(),
      0.8,
      1,
    ).toColor();
    final Color foregroundColor = _contentColorFor(swatchColor);
    final Color outlineColor = selected
        ? Theme.of(context).colorScheme.onSurface
        : foregroundColor.withAlpha(120);
    final double angle = (hue - 90) * math.pi / 180;
    final double center = diameter / 2;
    final double buttonSize = diameter < 360 ? 40 : 48;
    final double buttonRadius = diameter * 0.405;
    final double labelRadius = diameter * 0.29;
    final Offset direction = Offset(math.cos(angle), math.sin(angle));
    final Offset buttonCenter =
        Offset(center, center) + direction * buttonRadius;
    final Offset labelCenter = Offset(center, center) + direction * labelRadius;

    return <Widget>[
      Positioned(
        left: buttonCenter.dx - buttonSize / 2,
        top: buttonCenter.dy - buttonSize / 2,
        width: buttonSize,
        height: buttonSize,
        child: Semantics(
          label: "色相 $hue°，飽和度 80%，明度 100%",
          button: true,
          selected: selected,
          child: IconButton(
            key: ValueKey<String>("palette-hue-$hue"),
            tooltip: "Hue $hue°",
            onPressed: () => _selectHue(hue),
            style: IconButton.styleFrom(
              backgroundColor: swatchColor,
              foregroundColor: foregroundColor,
              side: BorderSide(color: outlineColor, width: selected ? 3 : 1),
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            icon: Icon(
              selected ? Icons.check : Icons.circle,
              size: selected ? 22 : 8,
            ),
          ),
        ),
      ),
      Positioned(
        left: labelCenter.dx - 27,
        top: labelCenter.dy - 12,
        width: 54,
        height: 24,
        child: ExcludeSemantics(
          child: Center(
            child: Text(
              "$hue°",
              maxLines: 1,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? Colors.green
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildSlotWrap(
    List<PaletteSlotDefinition> slots,
    PaletteStateData state,
  ) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth;
        final int columns = maxWidth >= 1160
            ? 4
            : maxWidth >= 820
            ? 3
            : maxWidth >= 540
            ? 2
            : 1;
        const double gap = 10;
        final double itemWidth = (maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final PaletteSlotDefinition slot in slots)
              SizedBox(width: itemWidth, child: _buildSlotCard(slot, state)),
          ],
        );
      },
    );
  }

  Widget _buildSlotCard(PaletteSlotDefinition slot, PaletteStateData state) {
    final List<String> ids = state.slotEntryIds[slot.id] ?? const <String>[];
    final List<PaletteEntry> entries = ids
        .map((String id) => state.entryIndex[id])
        .whereType<PaletteEntry>()
        .toList(growable: false);
    final Color pureColor = _slotColor(slot);
    final Color cardColor = Color.alphaBlend(
      pureColor.withAlpha(54),
      Theme.of(context).colorScheme.surfaceContainerLow,
    );
    final Color chipColor = Color.alphaBlend(
      pureColor.withAlpha(170),
      Theme.of(context).colorScheme.surfaceContainerHighest,
    );
    final Color chipForeground = _contentColorFor(chipColor);
    final String title = slot.isGray
        ? "V ${slot.value}%"
        : "S ${slot.saturation}% · V ${slot.value}%";

    return Semantics(
      container: true,
      label: "${slot.semanticsLabel}，${entries.length} 個詞條",
      child: Card(
        key: ValueKey<String>("palette-slot-${slot.id}"),
        color: cardColor,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          initiallyExpanded: entries.isNotEmpty,
          leading: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: pureColor,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          title: Text(title),
          subtitle: Text("${entries.length} 個詞條"),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PopupMenuButton<String>(
                tooltip: "色格操作",
                onSelected: (String value) {
                  if (value == "sort") {
                    final bool changed = _notifier.sortSlotByText(slot.id);
                    if (!changed) {
                      AppFeedback.info(context, "目前不需要重新排序");
                    }
                  }
                },
                itemBuilder: (BuildContext context) =>
                    const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: "sort",
                        child: Text("依文字排序"),
                      ),
                    ],
              ),
              const Icon(Icons.expand_more),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  for (final PaletteEntry entry in entries)
                    if (_editingEntryId == entry.id)
                      _buildInlineEditor(key: "edit-${entry.id}")
                    else
                      InputChip(
                        key: ValueKey<String>("palette-entry-${entry.id}"),
                        label: Text(entry.text),
                        tooltip: "編輯「${entry.text}」",
                        backgroundColor: chipColor,
                        labelStyle: TextStyle(color: chipForeground),
                        deleteIconColor: chipForeground,
                        side: BorderSide(color: chipForeground.withAlpha(150)),
                        onPressed: () => _beginEdit(entry),
                        onDeleted: () => _removeEntry(entry),
                      ),
                  if (_addingSlotId == slot.id)
                    _buildInlineEditor(key: "add-${slot.id}")
                  else
                    ActionChip(
                      key: ValueKey<String>("palette-add-${slot.id}"),
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text("新增詞條"),
                      onPressed: () => _beginAdd(slot.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineEditor({required String key}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 250),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: AppTextField(
              key: ValueKey<String>("palette-editor-$key"),
              controller: _entryEditorController,
              focusNode: _entryEditorFocusNode,
              maxLength: paletteTermMaxLength,
              hintText: "輸入詞條",
              decoration: const InputDecoration(counterText: ""),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _commitActiveEditor(),
            ),
          ),
          IconButton(
            tooltip: "儲存",
            visualDensity: VisualDensity.compact,
            onPressed: _commitActiveEditor,
            icon: const Icon(Icons.check),
          ),
          IconButton(
            tooltip: "取消",
            visualDensity: VisualDensity.compact,
            onPressed: _cancelActiveEditor,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(List<_PaletteSearchHit> hits, String searchQuery) {
    if (hits.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.search_off,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text("找不到包含「$searchQuery」的詞條"),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: hits.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        final _PaletteSearchHit hit = hits[index];
        return ListTile(
          leading: CircleAvatar(backgroundColor: _slotColor(hit.slot)),
          title: Text(hit.entry.text),
          subtitle: Text(hit.slot.semanticsLabel),
          trailing: const Icon(Icons.arrow_forward),
          onTap: () {
            if (!hit.slot.isGray) {
              _selectedHue = hit.slot.hue;
            }
            _searchController.clear();
          },
        );
      },
    );
  }
}

@immutable
class _PaletteSearchHit {
  final PaletteSlotDefinition slot;
  final PaletteEntry entry;

  const _PaletteSearchHit({required this.slot, required this.entry});
}

class _HueRingPainter extends CustomPainter {
  const _HueRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final Offset center = bounds.center;
    final double radius = size.shortestSide * 0.405;
    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(8, size.shortestSide * 0.026)
      ..shader = const SweepGradient(
        colors: <Color>[
          Color(0xFFFF3333),
          Color(0xFFFFFF33),
          Color(0xFF33FF33),
          Color(0xFF33FFFF),
          Color(0xFF3333FF),
          Color(0xFFFF33FF),
          Color(0xFFFF3333),
        ],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(bounds);
    canvas.drawCircle(center, radius, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _HueRingPainter oldDelegate) => false;
}
