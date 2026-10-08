import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import "../../ui_library/spacing.dart";
import '../../bin/content.dart';
import '../../presentation/providers/project_state_providers.dart';
import '../inline_annotations/inline_annotation_edit_dialog.dart';
import '../inline_annotations/inline_annotation.dart';
import '../inline_annotations/inline_annotation_parser.dart';
import '../inline_annotations/inline_annotation_syntax.dart';
import '../inline_annotations/mosaic_editing_controller.dart';
import 'phrase_body_validator.dart';
import 'phrase_entry.dart';
import 'phrase_display_preview.dart';
import 'global_phrases_provider.dart';
import 'phrase_search_index.dart';
import 'phrase_transfer.dart';
import 'phrase_transfer_io.dart';
import "../../ui_library/forms.dart";

final class PhraseLibraryDialog extends ConsumerStatefulWidget {
  final String? initialBody;

  const PhraseLibraryDialog({super.key, this.initialBody});

  static Future<void> show({
    required BuildContext context,
    String? initialBody,
  }) => showDialog<void>(
    context: context,
    builder: (_) => PhraseLibraryDialog(initialBody: initialBody),
  );

  @override
  ConsumerState<PhraseLibraryDialog> createState() =>
      _PhraseLibraryDialogState();
}

final class _PhraseLibraryDialogState
    extends ConsumerState<PhraseLibraryDialog> {
  final TextEditingController _search = TextEditingController();
  List<PhraseEntry>? _indexedPhrases;
  List<PhraseEntry>? _indexedGlobalPhrases;
  PhraseSearchIndex? _index;
  PhraseEntry? _editing;
  PhraseScope _editingScope = PhraseScope.project;
  String? _newBody;
  List<String> _newTags = const [];

  @override
  void initState() {
    super.initState();
    _newBody = widget.initialBody;
    _search.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _search.removeListener(_refresh);
    _search.dispose();
    super.dispose();
  }

  void _openEditor([
    PhraseEntry? phrase,
    String? body,
    PhraseScope scope = PhraseScope.project,
  ]) => setState(() {
    _editing = phrase;
    _editingScope = scope;
    _newBody = body ?? (phrase == null ? '' : null);
    _newTags = const [];
  });

  void _copyPhrase(PhraseEntry phrase, PhraseScope scope) => setState(() {
    _editing = null;
    _editingScope = scope;
    _newBody = phrase.body;
    _newTags = phrase.tags;
  });

  void _closeEditor() => setState(() {
    _editing = null;
    _newBody = null;
    _newTags = const [];
  });

  Future<void> _save(ScopedPhrase entry, {PhraseScope? originalScope}) async {
    var phrase = entry.phrase;
    if (entry.scope == PhraseScope.global && phraseHasMention(phrase)) {
      throw const FormatException('含 Mention 的短語只能儲存在目前專案');
    }
    final projects = ref.read(phrasesProvider);
    final globals =
        ref.read(globalPhrasesProvider).valueOrNull ?? const <PhraseEntry>[];
    if (entry.scope == PhraseScope.global &&
        !ref.read(globalPhrasesProvider).hasValue) {
      throw StateError('全域短語庫尚未載入');
    }
    final sourceScope = originalScope ?? entry.scope;
    final sourceItems = sourceScope == PhraseScope.project ? projects : globals;
    final sourceItem = [
      for (final item in sourceItems)
        if (item.id == phrase.id) item,
    ];
    final unchangedShortcut =
        sourceScope == entry.scope &&
        sourceItem.isNotEmpty &&
        sourceItem.first.normalizedShortcut == phrase.normalizedShortcut;
    final remainingProjects = [
      for (final item in projects)
        if (sourceScope != PhraseScope.project || item.id != phrase.id) item,
    ];
    final remainingGlobals = [
      for (final item in globals)
        if (sourceScope != PhraseScope.global || item.id != phrase.id) item,
    ];
    final remaining = [...remainingProjects, ...remainingGlobals];
    if (!unchangedShortcut &&
        remaining.any(
          (item) => item.normalizedShortcut == phrase.normalizedShortcut,
        )) {
      throw const FormatException('短碼已被使用，請使用其他短碼');
    }
    if (remaining.any((item) => item.id == phrase.id)) {
      phrase = copyPhrase(phrase, id: const Uuid().v4());
    }
    final nextProjects = [
      ...remainingProjects,
      if (entry.scope == PhraseScope.project) phrase,
    ];
    final nextGlobals = [
      ...remainingGlobals,
      if (entry.scope == PhraseScope.global) phrase,
    ];
    validatePhraseLibrary(nextProjects);
    validatePhraseLibrary(nextGlobals);
    if (entry.scope == PhraseScope.global ||
        sourceScope == PhraseScope.global) {
      await ref.read(globalPhrasesProvider.notifier).setPhrases(nextGlobals);
    }
    if (!mounted) return;
    if (entry.scope == PhraseScope.project ||
        sourceScope == PhraseScope.project) {
      ref.read(phrasesProvider.notifier).setPhrases(nextProjects);
    }
    setState(() {
      _editing = null;
      _newBody = null;
      _newTags = const [];
    });
  }

  Future<void> _delete(PhraseEntry phrase, PhraseScope scope) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除短語？'),
        content: Text('短碼「${phrase.shortcut}」會從短語庫移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      if (scope == PhraseScope.global) {
        await ref
            .read(globalPhrasesProvider.notifier)
            .setPhrases(
              ref
                  .read(globalPhrasesProvider)
                  .valueOrNull!
                  .where((item) => item.id != phrase.id),
            );
      } else {
        ref
            .read(phrasesProvider.notifier)
            .setPhrases(
              ref.read(phrasesProvider).where((item) => item.id != phrase.id),
            );
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  void _showError(Object error) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$error')));

  Future<void> _export() async {
    try {
      final globals = await ref.read(globalPhrasesProvider.future);
      final source = PhraseTransferCodec.encode([
        for (final phrase in ref.read(phrasesProvider))
          ScopedPhrase(phrase, PhraseScope.project),
        for (final phrase in globals) ScopedPhrase(phrase, PhraseScope.global),
      ]);
      final saved = await PhraseTransferIo.exportText(source);
      if (mounted && saved) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('短語庫已匯出')));
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<PhraseImportChoice?> _resolveConflict(
    PhraseEntry incoming,
    List<ScopedPhrase> conflicts,
    String newShortcut,
  ) => showDialog<PhraseImportChoice>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('短碼「${incoming.shortcut}」發生衝突'),
      content: Text(
        '匯入項目與現有短語的 ID 或短碼相同：\n'
        '${conflicts.map((item) => '${item.phrase.shortcut}（${item.scope == PhraseScope.global ? '所有專案' : '目前專案'}）').join('、')}\n\n'
        '可以保留現有項目、覆蓋，或以「$newShortcut」另存一份。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('取消匯入'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(dialogContext, PhraseImportChoice.skip),
          child: const Text('保留現有'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(dialogContext, PhraseImportChoice.copy),
          child: const Text('另存一份'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(dialogContext, PhraseImportChoice.replace),
          child: const Text('覆蓋'),
        ),
      ],
    ),
  );

  Future<void> _import() async {
    try {
      final source = await PhraseTransferIo.importText();
      if (source == null || !mounted) return;
      final incoming = PhraseTransferCodec.decode(source);
      final originalProjects = ref.read(phrasesProvider);
      final originalGlobals = await ref.read(globalPhrasesProvider.future);
      if (!mounted) return;
      final projects = [...originalProjects];
      final globals = [...originalGlobals];
      var imported = 0;
      var skipped = 0;
      var mentionsMoved = 0;
      for (final item in incoming) {
        if (!mounted) return;
        final hasMention = phraseHasMention(item.phrase);
        if (hasMention) mentionsMoved++;
        final phrase = item.phrase;
        final conflicts = phraseImportConflicts(phrase, projects, globals);
        var choice = PhraseImportChoice.replace;
        if (conflicts.isNotEmpty) {
          final newShortcut = nextAvailableShortcut(phrase.shortcut, [
            ...projects,
            ...globals,
          ]);
          final selected = await _resolveConflict(
            phrase,
            conflicts,
            newShortcut,
          );
          if (selected == null || !mounted) return;
          choice = selected;
          if (choice == PhraseImportChoice.skip) {
            skipped++;
            continue;
          }
        }
        applyPhraseImport(
          incoming: item,
          projects: projects,
          globals: globals,
          choice: choice,
          copyId: choice == PhraseImportChoice.copy ? const Uuid().v4() : null,
        );
        imported++;
      }
      validatePhraseLibrary(projects);
      validatePhraseLibrary(globals);
      if (!listEquals(globals, originalGlobals)) {
        await ref.read(globalPhrasesProvider.notifier).setPhrases(globals);
      }
      if (!mounted) return;
      if (!listEquals(projects, originalProjects)) {
        ref.read(phrasesProvider.notifier).setPhrases(projects);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '已匯入 $imported 筆，保留 $skipped 筆現有短語。'
              '${mentionsMoved > 0 ? '含 Mention 的短語已限於目前專案，插入前須重新連結。' : ''}',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phrases = ref.watch(phrasesProvider);
    final globalState = ref.watch(globalPhrasesProvider);
    final globalPhrases = globalState.valueOrNull ?? const <PhraseEntry>[];
    final scoped = [
      for (final phrase in phrases) ScopedPhrase(phrase, PhraseScope.project),
      for (final phrase in globalPhrases)
        ScopedPhrase(phrase, PhraseScope.global),
    ];
    final scopeByPhrase = {for (final item in scoped) item.phrase: item.scope};
    if (!identical(_indexedPhrases, phrases) ||
        !identical(_indexedGlobalPhrases, globalPhrases)) {
      _indexedPhrases = phrases;
      _indexedGlobalPhrases = globalPhrases;
      _index = PhraseSearchIndex(scoped.map((item) => item.phrase));
    }
    final editing = _editing != null || _newBody != null;
    final results = _index!.search(_search.text, limit: 1000);
    final disabled = scoped.where((item) {
      final phrase = item.phrase;
      return !phrase.enabled &&
          (phraseDisplayPreview(
                phrase.body,
              ).toLowerCase().contains(_search.text.toLowerCase()) ||
              phrase.shortcut.toLowerCase().contains(
                _search.text.toLowerCase(),
              ) ||
              phrase.tags.any(
                (tag) => tag.toLowerCase().contains(_search.text.toLowerCase()),
              ));
    });
    return Dialog(
      child: SizedBox(
        width: 680,
        height: editing ? 680 : 560,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space20),
          child: editing
              ? _PhraseEditForm(
                  key: ValueKey(_editing?.id ?? 'new'),
                  original: _editing,
                  initialBody: _newBody,
                  initialTags: _newTags,
                  initialScope: _editingScope,
                  globalReady: globalState.hasValue,
                  existing: scoped.map((item) => item.phrase).toList(),
                  onCancel: _closeEditor,
                  onSave: (entry) => _save(
                    entry,
                    originalScope: _editing == null ? null : _editingScope,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Text('短語庫', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              OutlinedButton.icon(
                                onPressed: globalState.hasValue
                                    ? _import
                                    : null,
                                icon: const Icon(Icons.file_open_outlined),
                                label: const Text('匯入'),
                              ),
                              OutlinedButton.icon(
                                onPressed: globalState.hasValue
                                    ? _export
                                    : null,
                                icon: const Icon(Icons.save_alt),
                                label: const Text('匯出'),
                              ),
                              FilledButton.icon(
                                onPressed: () => _openEditor(null, ''),
                                icon: const Icon(Icons.add),
                                label: const Text('新增短語'),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close),
                                tooltip: '關閉',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (globalState.hasError)
                      Text(
                        '全域短語庫讀取失敗：${globalState.error}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    TextField(
                      controller: _search,
                      decoration: appFieldDecoration(
                        context,
                        decoration: const InputDecoration(
                          labelText: '搜尋內容、短碼或標籤',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final result in results)
                            _tile(
                              result.phrase,
                              scopeByPhrase[result.phrase]!,
                              result.preview,
                            ),
                          for (final item in disabled)
                            _tile(item.phrase, item.scope, '已停用'),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _tile(
    PhraseEntry phrase,
    PhraseScope scope,
    String preview,
  ) => ListTile(
    title: Text(phrase.shortcut),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          scope == PhraseScope.global ? '所有專案' : '目前專案',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        Text(
          preview.replaceAll('\n', ' '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (phrase.tags.isNotEmpty)
          Wrap(
            spacing: 4,
            children: [
              for (final tag in phrase.tags)
                Chip(label: Text(tag), visualDensity: VisualDensity.compact),
            ],
          ),
      ],
    ),
    onTap: () => _openEditor(phrase, null, scope),
    trailing: Wrap(
      children: [
        IconButton(
          tooltip: '複製短語',
          icon: const Icon(Icons.copy),
          onPressed: () => _copyPhrase(phrase, scope),
        ),
        IconButton(
          tooltip: phrase.enabled ? '停用' : '啟用',
          icon: Icon(phrase.enabled ? Icons.visibility_off : Icons.visibility),
          onPressed: () async {
            try {
              await _save(
                ScopedPhrase(
                  copyPhrase(
                    phrase,
                    enabled: !phrase.enabled,
                    updatedAt: DateTime.now().toUtc(),
                  ),
                  scope,
                ),
                originalScope: scope,
              );
            } catch (error) {
              if (mounted) _showError(error);
            }
          },
        ),
        IconButton(
          tooltip: '刪除',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _delete(phrase, scope),
        ),
      ],
    ),
  );
}

final class _PhraseEditForm extends StatefulWidget {
  final PhraseEntry? original;
  final String? initialBody;
  final List<String> initialTags;
  final PhraseScope initialScope;
  final bool globalReady;
  final List<PhraseEntry> existing;
  final VoidCallback onCancel;
  final Future<void> Function(ScopedPhrase) onSave;

  const _PhraseEditForm({
    super.key,
    required this.original,
    required this.initialBody,
    required this.initialTags,
    required this.initialScope,
    required this.globalReady,
    required this.existing,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_PhraseEditForm> createState() => _PhraseEditFormState();
}

final class _PhraseEditFormState extends State<_PhraseEditForm> {
  late final TextEditingController _shortcut;
  late final TextEditingController _tagInput;
  late final FocusNode _bodyFocus;
  late final List<String> _tags;
  late final MosaicEditingController _body;
  late PhraseScope _scope;
  String? _error;
  bool _bodyHovered = false;

  @override
  void initState() {
    super.initState();
    final phrase = widget.original;
    _shortcut = TextEditingController(text: phrase?.shortcut ?? '');
    _tagInput = TextEditingController();
    _bodyFocus = FocusNode();
    _tags = [...?phrase?.tags, ...widget.initialTags];
    _scope = widget.initialScope;
    _body = MosaicEditingController(
      rawText: widget.initialBody ?? phrase?.body ?? '',
    );
    _body.addListener(_refresh);
  }

  void _refresh() => setState(() {
    if (_body.annotations.any((annotation) => annotation.hasTarget)) {
      _scope = PhraseScope.project;
    }
  });

  @override
  void dispose() {
    _body.removeListener(_refresh);
    _shortcut.dispose();
    _tagInput.dispose();
    _bodyFocus.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _editMention(int index) async {
    final annotations = _body.annotations;
    if (index < 0 || index >= annotations.length) return;
    final annotation = annotations[index];
    final original = _body.rawText;
    final range = annotation.sourceRange;
    final result = await InlineAnnotationEditDialog.show(
      context: context,
      annotation: annotation,
      rawSyntax: original.substring(range.start, range.end),
    );
    if (!mounted || result == null || _body.rawText != original) return;
    _body.replaceRawRange(range, result);
  }

  TextRange get _bodySelectionRange {
    final selection = _body.selection;
    return selection.isValid
        ? _body.projection.displayRangeToRaw(
            TextRange(start: selection.start, end: selection.end),
          )
        : TextRange.collapsed(_body.rawText.length);
  }

  void _insertTarget(String trigger) {
    final range = _bodySelectionRange;
    _bodyFocus.requestFocus();
    _body.replaceRawRange(range, trigger);
  }

  Future<void> _insertMark() async {
    final original = _body.rawText;
    final range = _bodySelectionRange;
    final syntax = InlineAnnotationSyntax.format(
      kind: InlineAnnotationKind.emphasis,
      displayText: _body.selection.isValid
          ? _body.plainTextForSelection(_body.selection)
          : '',
    );
    final result = await InlineAnnotationEditDialog.show(
      context: context,
      annotation: const InlineAnnotationParser().parse(syntax).single,
      rawSyntax: syntax,
    );
    if (!mounted || result == null || _body.rawText != original) return;
    _body.replaceRawRange(range, result);
    _bodyFocus.requestFocus();
  }

  void _addTag(String value) {
    final tag = value.trim();
    if (tag.isEmpty) return;
    if (!_tags.any((existing) => existing.toLowerCase() == tag.toLowerCase())) {
      setState(() => _tags.add(tag));
    }
    _tagInput.clear();
  }

  Future<void> _submit() async {
    try {
      final shortcut = _shortcut.text.trim();
      if (widget.existing.any(
        (phrase) =>
            phrase.id != widget.original?.id &&
            phrase.normalizedShortcut == shortcut.toLowerCase(),
      )) {
        throw const FormatException('短碼已被使用');
      }
      final validation = const PhraseBodyValidator().validate(_body.rawText);
      if (!validation.isValid) {
        throw const FormatException('Mosaic 內容不完整');
      }
      if (_body.rawText.trim().isEmpty) {
        throw const FormatException('內容不能為空');
      }
      _addTag(_tagInput.text);
      final display = phraseDisplayPreview(_body.rawText).trim();
      final firstLine = display.split('\n').first.trim();
      final name = firstLine.isEmpty
          ? shortcut
          : firstLine.substring(0, firstLine.length.clamp(0, 48));
      final now = DateTime.now().toUtc();
      await widget.onSave(
        ScopedPhrase(
          PhraseEntry(
            id: widget.original?.id ?? const Uuid().v4(),
            name: name,
            shortcut: shortcut,
            category: widget.original?.category ?? '',
            tags: _tags,
            body: _body.rawText,
            enabled: widget.original?.enabled ?? true,
            requiresRelink: widget.original?.requiresRelink ?? false,
            createdAt: widget.original?.createdAt ?? now,
            updatedAt: now,
          ),
          _scope,
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final validation = const PhraseBodyValidator().validate(_body.rawText);
    final hasMention = validation.annotations.any(
      (annotation) => annotation.hasTarget,
    );
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.original == null ? '新增短語' : '編輯短語',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('phrase-shortcut'),
                  controller: _shortcut,
                  autofocus: true,
                  decoration: appFieldDecoration(
                    context,
                    decoration: const InputDecoration(
                      labelText: '短碼（1–32 位英數、_、-）',
                    ),
                  ),
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  children: [
                    const Text('所有專案可用'),
                    Switch(
                      key: const ValueKey('phrase-global-scope'),
                      value: _scope == PhraseScope.global && !hasMention,
                      onChanged: hasMention || !widget.globalReady
                          ? null
                          : (value) => setState(() {
                              _scope = value
                                  ? PhraseScope.global
                                  : PhraseScope.project;
                            }),
                    ),
                    if (hasMention) const Text('含 Mention，只能用於目前專案'),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('標籤'),
                Wrap(
                  key: const ValueKey('phrase-tags'),
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final tag in _tags)
                      InputChip(
                        label: Text(tag),
                        onDeleted: () => setState(() => _tags.remove(tag)),
                      ),
                    SizedBox(
                      width: 160,
                      child: TextField(
                        key: const ValueKey('phrase-tag-input'),
                        controller: _tagInput,
                        decoration: appFieldDecoration(
                          context,
                          decoration: const InputDecoration(
                            hintText: '新增標籤',
                            isDense: true,
                          ),
                        ),
                        onSubmitted: _addTag,
                      ),
                    ),
                    IconButton(
                      tooltip: '新增標籤',
                      onPressed: () => _addTag(_tagInput.text),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.notes_rounded, size: 18, color: colors.primary),
                    const SizedBox(width: 6),
                    const Text('內容'),
                    Expanded(
                      child: Text(
                        '提及限目前專案；文字標記可供所有專案使用',
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final target in const [
                      (label: '人物', trigger: '@', icon: Icons.person_outline),
                      (
                        label: '物品',
                        trigger: '*',
                        icon: Icons.inventory_2_outlined,
                      ),
                      (label: '地點', trigger: '!', icon: Icons.place_outlined),
                      (label: '事件', trigger: '#', icon: Icons.event_outlined),
                    ])
                      OutlinedButton.icon(
                        key: ValueKey('phrase-insert-${target.trigger}'),
                        onPressed: () => _insertTarget(target.trigger),
                        icon: Icon(target.icon),
                        label: Text(target.label),
                      ),
                    OutlinedButton.icon(
                      key: const ValueKey('phrase-insert-mark'),
                      onPressed: _insertMark,
                      icon: const Icon(Icons.highlight_outlined),
                      label: const Text('標記'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 220,
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _bodyHovered = true),
                    onExit: (_) => setState(() => _bodyHovered = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        border: Border.all(
                          color: _bodyHovered
                              ? colors.primary
                              : colors.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        // EditorTextBox already leaves 4px on the left for CodeField.
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xs,
                          AppSpacing.sm,
                          AppSpacing.sm,
                          AppSpacing.sm,
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            hoverColor: Colors.transparent,
                            inputDecorationTheme: Theme.of(context)
                                .inputDecorationTheme
                                .copyWith(
                                  fillColor: colors.surfaceContainerHighest,
                                  contentPadding: EdgeInsets.zero,
                                ),
                          ),
                          child: KeyedSubtree(
                            key: const ValueKey('phrase-body'),
                            child: EditorTextBox(
                              controller: _body,
                              focusNode: _bodyFocus,
                              usePlainTextQuillEditor: false,
                              showPhraseActions: false,
                              backgroundColor: colors.surfaceContainerHighest,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_body.annotations.isNotEmpty)
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (var i = 0; i < _body.annotations.length; i++)
                          TextButton(
                            onPressed: () => _editMention(i),
                            child: Text(
                              'Mention：${_body.annotations[i].displayText}',
                            ),
                          ),
                      ],
                    ),
                  ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (!validation.isValid) const Text('Mosaic 語法不完整'),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: widget.onCancel, child: const Text('返回')),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(onPressed: _submit, child: const Text('儲存')),
          ],
        ),
      ],
    );
  }
}
