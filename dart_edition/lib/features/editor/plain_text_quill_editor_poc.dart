// The only available flutter_quill API for disabling external rich paste is
// currently experimental. The PoC deliberately depends on it so rich Delta
// content cannot enter the plain-text boundary.
// ignore_for_file: experimental_member_use

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_quill/flutter_quill.dart";

import "../../presentation/providers/collaboration_providers.dart";
import "plain_text_quill_adapter.dart";
import "plain_text_quill_remote_cursor_overlay.dart";

/// Reports a local plain-text selection to the existing collaboration layer.
/// The callback offsets exclude Quill's final document sentinel newline.
typedef PlainTextQuillCursorReporter =
    void Function({required int anchorOffset, required int focusOffset});

/// Commands that a host AppBar or keyboard binding can invoke on the focused
/// plain-text Quill editor.
///
/// The object is deliberately separate from [QuillController], so callers
/// cannot accidentally insert Delta data or formatting into the plain-text
/// boundary. It has no effect while it is detached from an editor widget.
final class PlainTextQuillEditorCommands {
  _PlainTextQuillEditorPocState? _state;

  bool get hasFocus => _state?._focusNode.hasFocus ?? false;
  bool get canUndo => _state?._controller.hasUndo ?? false;
  bool get canRedo => _state?._controller.hasRedo ?? false;

  void requestFocus() => _state?._requestFocus();
  void undo() => _state?._undo();
  void redo() => _state?._redo();
  void selectAll() => _state?._selectAll();
  Future<void> copy() => _state?._copy() ?? Future<void>.value();
  Future<void> cut() => _state?._cut() ?? Future<void>.value();
  Future<void> paste() => _state?._paste() ?? Future<void>.value();

  /// Replaces the current selection with known plain text.
  ///
  /// This is useful for command hosts that already own a clipboard abstraction.
  /// The text is normalized to LF before it reaches Quill.
  void replaceSelectionWith(String text) => _state?._replaceSelectionWith(text);

  void _attach(_PlainTextQuillEditorPocState state) {
    _state = state;
  }

  void _detach(_PlainTextQuillEditorPocState state) {
    if (_state == state) _state = null;
  }
}

class _PlainTextUndoIntent extends Intent {
  const _PlainTextUndoIntent();
}

class _PlainTextRedoIntent extends Intent {
  const _PlainTextRedoIntent();
}

class _PlainTextSelectAllIntent extends Intent {
  const _PlainTextSelectAllIntent();
}

class _PlainTextCopyIntent extends Intent {
  const _PlainTextCopyIntent();
}

class _PlainTextCutIntent extends Intent {
  const _PlainTextCutIntent();
}

class _PlainTextPasteIntent extends Intent {
  const _PlainTextPasteIntent();
}

/// Immutable search and proofreading ranges expressed in document UTF-16
/// offsets. They are UI metadata and are never written to Quill.
@immutable
class PlainTextQuillSearchState {
  const PlainTextQuillSearchState({
    this.query = "",
    this.matches = const <TextRange>[],
    this.currentMatchIndex = -1,
    this.proofreadingRanges = const <TextRange>[],
  });

  final String query;
  final List<TextRange> matches;
  final int currentMatchIndex;
  final List<TextRange> proofreadingRanges;

  PlainTextQuillSearchState copyWith({
    String? query,
    List<TextRange>? matches,
    int? currentMatchIndex,
    List<TextRange>? proofreadingRanges,
  }) {
    return PlainTextQuillSearchState(
      query: query ?? this.query,
      matches: matches ?? this.matches,
      currentMatchIndex: currentMatchIndex ?? this.currentMatchIndex,
      proofreadingRanges: proofreadingRanges ?? this.proofreadingRanges,
    );
  }
}

/// Search, replace and proofreading bridge for [PlainTextQuillEditorPoc].
///
/// Searches operate on adapter-extracted plain text, so every range maps
/// directly to a Quill document offset. New searches supersede pending ones;
/// a changed document clears all stale highlights before they can be applied.
final class PlainTextQuillSearchController extends ChangeNotifier {
  _PlainTextQuillEditorPocState? _editor;
  PlainTextQuillSearchState _state = const PlainTextQuillSearchState();
  int _generation = 0;
  bool _caseSensitive = false;
  bool _wholeWord = false;
  bool _useRegexp = false;

  PlainTextQuillSearchState get state => _state;

  Future<void> find(
    String query, {
    bool caseSensitive = false,
    bool wholeWord = false,
    bool useRegexp = false,
    bool forward = true,
  }) async {
    final editor = _editor;
    if (editor == null) return;

    final text = editor._plainText;
    final revision = editor._textRevision;
    final generation = ++_generation;
    _caseSensitive = caseSensitive;
    _wholeWord = wholeWord;
    _useRegexp = useRegexp;

    if (query.isEmpty || text.isEmpty) {
      _state = _state.copyWith(
        query: query,
        matches: const <TextRange>[],
        currentMatchIndex: -1,
      );
      notifyListeners();
      return;
    }

    // Yield a microtask before searching so a newer query, edit, or explicit
    // cancellation can invalidate this request without changing the document.
    // A microtask is intentional: an event-queue Future can stall while a
    // Flutter widget test is awaiting this method without pumping a frame.
    late final List<TextRange> matches;
    try {
      matches = await Future<List<TextRange>>.microtask(
        () => _findAll(
          text,
          query,
          caseSensitive: caseSensitive,
          wholeWord: wholeWord,
          useRegexp: useRegexp,
        ),
      );
    } on FormatException {
      if (!identical(editor, _editor) || generation != _generation) return;
      _state = _state.copyWith(
        query: query,
        matches: const <TextRange>[],
        currentMatchIndex: -1,
      );
      notifyListeners();
      return;
    }
    if (!identical(editor, _editor) ||
        generation != _generation ||
        revision != editor._textRevision ||
        text != editor._plainText) {
      return;
    }

    final currentOffset = editor._editableSelection.start;
    final currentIndex = _initialMatchIndex(
      matches,
      currentOffset: currentOffset,
      forward: forward,
    );
    _state = _state.copyWith(
      query: query,
      matches: matches,
      currentMatchIndex: currentIndex,
    );
    _selectCurrentMatch();
    notifyListeners();
  }

  Future<void> findNext() => _moveMatch(forward: true);
  Future<void> findPrevious() => _moveMatch(forward: false);

  Future<void> _moveMatch({required bool forward}) async {
    if (_state.query.isEmpty) return;
    if (_state.matches.isEmpty) {
      return find(
        _state.query,
        caseSensitive: _caseSensitive,
        wholeWord: _wholeWord,
        useRegexp: _useRegexp,
        forward: forward,
      );
    }
    final count = _state.matches.length;
    final index = _state.currentMatchIndex < 0
        ? _initialMatchIndex(
            _state.matches,
            currentOffset: _editor?._editableSelection.start ?? 0,
            forward: forward,
          )
        : (forward
              ? (_state.currentMatchIndex + 1) % count
              : (_state.currentMatchIndex - 1 + count) % count);
    _state = _state.copyWith(currentMatchIndex: index);
    _selectCurrentMatch();
    notifyListeners();
  }

  Future<void> replaceCurrent(String replacement) async {
    final editor = _editor;
    if (editor == null || _state.query.isEmpty) return;
    if (_state.currentMatchIndex < 0 || _state.matches.isEmpty) {
      await find(
        _state.query,
        caseSensitive: _caseSensitive,
        wholeWord: _wholeWord,
        useRegexp: _useRegexp,
      );
      return;
    }
    final range = _state.matches[_state.currentMatchIndex];
    editor._replaceDocumentRange(range, replacement);
    await find(
      _state.query,
      caseSensitive: _caseSensitive,
      wholeWord: _wholeWord,
      useRegexp: _useRegexp,
    );
  }

  Future<void> replaceAll(String replacement) async {
    final editor = _editor;
    if (editor == null || _state.query.isEmpty) return;

    final text = editor._plainText;
    final matches = _findAll(
      text,
      _state.query,
      caseSensitive: _caseSensitive,
      wholeWord: _wholeWord,
      useRegexp: _useRegexp,
    );
    if (matches.isEmpty) return;

    var nextText = text;
    final canonicalReplacement = _canonicalizeLineEndings(replacement);
    for (var index = matches.length - 1; index >= 0; index -= 1) {
      final range = matches[index];
      nextText = nextText.replaceRange(
        range.start,
        range.end,
        canonicalReplacement,
      );
    }
    editor._replaceAllPlainText(nextText);
    await find(
      _state.query,
      caseSensitive: _caseSensitive,
      wholeWord: _wholeWord,
      useRegexp: _useRegexp,
    );
  }

  void setProofreadingRanges(Iterable<TextRange> ranges) {
    final maxOffset = _editor?._editableContentLength ?? 0;
    final normalized = <TextRange>[
      for (final range in ranges)
        if (range.start >= 0 &&
            range.end > range.start &&
            range.end <= maxOffset)
          range,
    ]..sort((left, right) => left.start.compareTo(right.start));
    _state = _state.copyWith(proofreadingRanges: normalized);
    notifyListeners();
  }

  void clear() {
    _generation += 1;
    _state = const PlainTextQuillSearchState();
    notifyListeners();
  }

  void _handleDocumentChanged() {
    _generation += 1;
    if (_state.matches.isEmpty && _state.proofreadingRanges.isEmpty) return;
    _state = _state.copyWith(
      matches: const <TextRange>[],
      currentMatchIndex: -1,
      proofreadingRanges: const <TextRange>[],
    );
    notifyListeners();
  }

  void _selectCurrentMatch() {
    final editor = _editor;
    final index = _state.currentMatchIndex;
    if (editor == null || index < 0 || index >= _state.matches.length) return;
    final range = _state.matches[index];
    editor._controller.updateSelection(
      TextSelection(baseOffset: range.start, extentOffset: range.end),
      ChangeSource.silent,
    );
    editor._requestFocus();
  }

  void _attach(_PlainTextQuillEditorPocState editor) {
    _editor = editor;
  }

  void _detach(_PlainTextQuillEditorPocState editor) {
    if (identical(_editor, editor)) _editor = null;
    clear();
  }

  static List<TextRange> _findAll(
    String text,
    String query, {
    required bool caseSensitive,
    required bool wholeWord,
    required bool useRegexp,
  }) {
    final expression = RegExp(
      useRegexp ? query : RegExp.escape(query),
      caseSensitive: caseSensitive,
    );
    return <TextRange>[
      for (final match in expression.allMatches(text))
        if (match.start != match.end &&
            (!wholeWord || _hasWordBoundaries(text, match.start, match.end)))
          TextRange(start: match.start, end: match.end),
    ];
  }

  static int _initialMatchIndex(
    List<TextRange> matches, {
    required int currentOffset,
    required bool forward,
  }) {
    if (matches.isEmpty) return -1;
    if (forward) {
      final index = matches.indexWhere((range) => range.start >= currentOffset);
      return index == -1 ? 0 : index;
    }
    final index = matches.lastIndexWhere((range) => range.end <= currentOffset);
    return index == -1 ? matches.length - 1 : index;
  }

  static bool _hasWordBoundaries(String text, int start, int end) {
    final leftIsWord = start > 0 && _isAsciiWord(text.codeUnitAt(start - 1));
    final rightIsWord = end < text.length && _isAsciiWord(text.codeUnitAt(end));
    return !leftIsWord && !rightIsWord;
  }

  static bool _isAsciiWord(int value) =>
      value == 0x5f ||
      (value >= 0x30 && value <= 0x39) ||
      (value >= 0x41 && value <= 0x5a) ||
      (value >= 0x61 && value <= 0x7a);
}

String _canonicalizeLineEndings(String text) =>
    text.replaceAll("\r\n", "\n").replaceAll("\r", "\n");

/// An isolated Quill input surface for validating the Phase 1 plain-text
/// contract before it is connected to the production chapter editor.
///
/// This widget does not read or write Riverpod state, project files, history,
/// or collaboration messages. Its [onChanged] callback is the only output and
/// always carries canonical LF plain text without Quill's final newline.
/// Mosaic annotations deliberately remain visible source syntax here. The
/// existing CodeField-only projection uses placeholder offsets and cannot be
/// introduced into this plain-text Quill document without a separate,
/// render-only mapping layer.
class PlainTextQuillEditorPoc extends StatefulWidget {
  const PlainTextQuillEditorPoc({
    super.key,
    required this.content,
    required this.onChanged,
    this.commands,
    this.searchController,
    this.remoteCursors = const <RemoteCursorState>[],
    this.onLocalCursorChanged,
    this.selectionOffset = 0,
    this.placeholder = "開始撰寫正文…",
  });

  /// Plain text supplied by the host. Changing this value simulates selecting
  /// a different chapter without persisting a Quill document.
  final String content;

  /// Receives the canonical plain-text representation after a user edit.
  final ValueChanged<String> onChanged;

  /// Optional command bridge for AppBar actions and other host-owned controls.
  final PlainTextQuillEditorCommands? commands;

  /// Optional render-only search and proofreading bridge.
  final PlainTextQuillSearchController? searchController;

  /// Remote cursors supplied by the existing pure-text collaboration state.
  /// These offsets map directly to this adapter's canonical plain text.
  final List<RemoteCursorState> remoteCursors;

  /// Emits local plain-text selection changes while this editor has focus.
  /// A Phase 7 host forwards this to `updateLocalCursor` without Delta data.
  final PlainTextQuillCursorReporter? onLocalCursorChanged;

  /// A raw-text offset in [content]. It is mapped through the adapter when a
  /// new document is loaded.
  final int selectionOffset;
  final String placeholder;

  @override
  State<PlainTextQuillEditorPoc> createState() =>
      _PlainTextQuillEditorPocState();
}

class _PlainTextQuillEditorPocState extends State<PlainTextQuillEditorPoc> {
  late PlainTextQuillDocument _plainTextDocument;
  late QuillController _controller;
  late FocusNode _focusNode;
  late ScrollController _scrollController;
  late String _lastEmittedText;
  late TextSelection _lastReportedSelection;
  int _textRevision = 0;
  bool _isApplyingExternalContent = false;

  @override
  void initState() {
    super.initState();
    _plainTextDocument = PlainTextQuillAdapter.fromPlainText(widget.content);
    _lastEmittedText = PlainTextQuillAdapter.toPlainText(
      _plainTextDocument.document,
    );
    _controller = _newController(_plainTextDocument, widget.selectionOffset);
    _controller.addListener(_handleControllerChanged);
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChanged);
    _scrollController = ScrollController();
    _lastReportedSelection = _editableSelection;
    widget.commands?._attach(this);
    widget.searchController?._attach(this);
  }

  @override
  void didUpdateWidget(covariant PlainTextQuillEditorPoc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content ||
        oldWidget.selectionOffset != widget.selectionOffset) {
      _applyExternalContent(widget.content, widget.selectionOffset);
    }
    if (oldWidget.commands != widget.commands) {
      oldWidget.commands?._detach(this);
      widget.commands?._attach(this);
    }
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController?._detach(this);
      widget.searchController?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.commands?._detach(this);
    widget.searchController?._detach(this);
    _controller
      ..removeListener(_handleControllerChanged)
      ..dispose();
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  QuillController _newController(
    PlainTextQuillDocument document,
    int rawSelectionOffset,
  ) {
    return QuillController(
      document: document.document,
      selection: TextSelection.collapsed(
        offset: document.rawOffsetToDocumentOffset(rawSelectionOffset),
      ),
      config: const QuillControllerConfig(
        // Do not convert HTML/Markdown clipboard content into a Delta. The
        // Phase 0 contract only permits visible plain text in this editor.
        clipboardConfig: QuillClipboardConfig(enableExternalRichPaste: false),
      ),
    );
  }

  void _applyExternalContent(String rawText, int rawSelectionOffset) {
    final nextDocument = PlainTextQuillAdapter.fromPlainText(rawText);
    final previousDocument = _controller.document;
    _isApplyingExternalContent = true;
    try {
      _plainTextDocument = nextDocument;
      _lastEmittedText = PlainTextQuillAdapter.toPlainText(
        nextDocument.document,
      );
      _controller.document = nextDocument.document;
      _controller.updateSelection(
        TextSelection.collapsed(
          offset: nextDocument.rawOffsetToDocumentOffset(rawSelectionOffset),
        ),
        ChangeSource.silent,
      );
      _lastReportedSelection = _editableSelection;
      _textRevision += 1;
      widget.searchController?._handleDocumentChanged();
    } finally {
      _isApplyingExternalContent = false;
      previousDocument.close();
    }
  }

  void _handleControllerChanged() {
    if (_isApplyingExternalContent) return;

    _reportLocalSelectionIfNeeded();

    final nextText = PlainTextQuillAdapter.toPlainText(_controller.document);
    if (_lastEmittedText == nextText) return;
    _lastEmittedText = nextText;
    _textRevision += 1;
    widget.searchController?._handleDocumentChanged();
    widget.onChanged(nextText);
  }

  void _requestFocus() {
    _focusNode.requestFocus();
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) _reportLocalSelectionIfNeeded(force: true);
  }

  void _reportLocalSelectionIfNeeded({bool force = false}) {
    final selection = _editableSelection;
    if (!force && selection == _lastReportedSelection) return;
    _lastReportedSelection = selection;
    if (!_focusNode.hasFocus || !selection.isValid) return;
    widget.onLocalCursorChanged?.call(
      anchorOffset: selection.baseOffset,
      focusOffset: selection.extentOffset,
    );
  }

  int get _editableContentLength => _controller.document.length - 1;

  String get _plainText =>
      PlainTextQuillAdapter.toPlainText(_controller.document);

  TextSelection get _editableSelection {
    final selection = _controller.selection;
    final start = selection.start.clamp(0, _editableContentLength).toInt();
    final end = selection.end.clamp(0, _editableContentLength).toInt();
    return TextSelection(baseOffset: start, extentOffset: end);
  }

  void _undo() {
    _controller.undo();
    _requestFocus();
  }

  void _redo() {
    _controller.redo();
    _requestFocus();
  }

  void _selectAll() {
    _controller.updateSelection(
      TextSelection(baseOffset: 0, extentOffset: _editableContentLength),
      ChangeSource.local,
    );
    _requestFocus();
  }

  Future<void> _copy() async {
    final selection = _editableSelection;
    if (selection.isCollapsed) {
      _requestFocus();
      return;
    }
    final plainText = PlainTextQuillAdapter.toPlainText(_controller.document);
    await Clipboard.setData(
      ClipboardData(text: plainText.substring(selection.start, selection.end)),
    );
    _requestFocus();
  }

  Future<void> _cut() async {
    final selection = _editableSelection;
    if (selection.isCollapsed) {
      _requestFocus();
      return;
    }
    await _copy();
    _replaceSelectionWith("");
  }

  Future<void> _paste() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text;
    if (text != null && text.isNotEmpty) _replaceSelectionWith(text);
    _requestFocus();
  }

  void _replaceSelectionWith(String text) {
    final selection = _editableSelection;
    final canonicalText = _canonicalizeLineEndings(text);
    _controller.replaceText(
      selection.start,
      selection.end - selection.start,
      canonicalText,
      TextSelection.collapsed(offset: selection.start + canonicalText.length),
    );
    _requestFocus();
  }

  void _replaceDocumentRange(TextRange range, String replacement) {
    final start = range.start.clamp(0, _editableContentLength).toInt();
    final end = range.end.clamp(start, _editableContentLength).toInt();
    final canonicalReplacement = _canonicalizeLineEndings(replacement);
    _controller.replaceText(
      start,
      end - start,
      canonicalReplacement,
      TextSelection.collapsed(offset: start + canonicalReplacement.length),
    );
    _requestFocus();
  }

  void _replaceAllPlainText(String text) {
    final canonicalText = _canonicalizeLineEndings(text);
    _controller.replaceText(
      0,
      _editableContentLength,
      canonicalText,
      TextSelection.collapsed(offset: canonicalText.length),
    );
    _requestFocus();
  }

  bool get _isApplePlatform =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Map<ShortcutActivator, Intent> get _plainTextShortcuts {
    final isApple = _isApplePlatform;
    return <ShortcutActivator, Intent>{
      SingleActivator(
        LogicalKeyboardKey.keyZ,
        control: !isApple,
        meta: isApple,
      ): const _PlainTextUndoIntent(),
      SingleActivator(
        LogicalKeyboardKey.keyZ,
        control: !isApple,
        meta: isApple,
        shift: true,
      ): const _PlainTextRedoIntent(),
      if (!isApple)
        const SingleActivator(LogicalKeyboardKey.keyY, control: true):
            const _PlainTextRedoIntent(),
      SingleActivator(
        LogicalKeyboardKey.keyA,
        control: !isApple,
        meta: isApple,
      ): const _PlainTextSelectAllIntent(),
      SingleActivator(
        LogicalKeyboardKey.keyC,
        control: !isApple,
        meta: isApple,
      ): const _PlainTextCopyIntent(),
      SingleActivator(
        LogicalKeyboardKey.keyX,
        control: !isApple,
        meta: isApple,
      ): const _PlainTextCutIntent(),
      SingleActivator(
        LogicalKeyboardKey.keyV,
        control: !isApple,
        meta: isApple,
      ): const _PlainTextPasteIntent(),
    };
  }

  Map<Type, Action<Intent>> get _plainTextActions {
    return <Type, Action<Intent>>{
      _PlainTextUndoIntent: CallbackAction<_PlainTextUndoIntent>(
        onInvoke: (_) => _undo(),
      ),
      _PlainTextRedoIntent: CallbackAction<_PlainTextRedoIntent>(
        onInvoke: (_) => _redo(),
      ),
      _PlainTextSelectAllIntent: CallbackAction<_PlainTextSelectAllIntent>(
        onInvoke: (_) => _selectAll(),
      ),
      _PlainTextCopyIntent: CallbackAction<_PlainTextCopyIntent>(
        onInvoke: (_) => _copy(),
      ),
      _PlainTextCutIntent: CallbackAction<_PlainTextCutIntent>(
        onInvoke: (_) => _cut(),
      ),
      _PlainTextPasteIntent: CallbackAction<_PlainTextPasteIntent>(
        onInvoke: (_) => _paste(),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        QuillEditor.basic(
          key: const ValueKey<String>("plain-text-quill-editor"),
          controller: _controller,
          focusNode: _focusNode,
          scrollController: _scrollController,
          config: QuillEditorConfig(
            expands: true,
            padding: const EdgeInsets.all(16),
            placeholder: widget.placeholder,
            customShortcuts: _plainTextShortcuts,
            customActions: _plainTextActions,
          ),
        ),
        if (widget.remoteCursors.isNotEmpty)
          Positioned.fill(
            child: PlainTextQuillRemoteCursorOverlay(
              controller: _controller,
              scrollController: _scrollController,
              cursors: widget.remoteCursors,
            ),
          ),
      ],
    );
  }
}

/// A standalone host page for manual desktop and Android Phase 2 validation.
/// It intentionally is not routed from the production application.
class PlainTextQuillEditorPocPage extends StatefulWidget {
  const PlainTextQuillEditorPocPage({super.key, this.initialContent = ""});

  final String initialContent;

  @override
  State<PlainTextQuillEditorPocPage> createState() =>
      _PlainTextQuillEditorPocPageState();
}

class _PlainTextQuillEditorPocPageState
    extends State<PlainTextQuillEditorPocPage> {
  late String _content = widget.initialContent;
  final _commands = PlainTextQuillEditorCommands();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quill 純文字正文 PoC"),
        actions: <Widget>[
          IconButton(
            tooltip: "復原",
            onPressed: _commands.undo,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: "重做",
            onPressed: _commands.redo,
            icon: const Icon(Icons.redo),
          ),
          IconButton(
            tooltip: "全選",
            onPressed: _commands.selectAll,
            icon: const Icon(Icons.select_all),
          ),
          IconButton(
            tooltip: "剪下",
            onPressed: _commands.cut,
            icon: const Icon(Icons.content_cut),
          ),
          IconButton(
            tooltip: "複製",
            onPressed: _commands.copy,
            icon: const Icon(Icons.content_copy),
          ),
          IconButton(
            tooltip: "貼上",
            onPressed: _commands.paste,
            icon: const Icon(Icons.content_paste),
          ),
        ],
      ),
      body: PlainTextQuillEditorPoc(
        content: _content,
        onChanged: (nextContent) => setState(() => _content = nextContent),
        commands: _commands,
      ),
    );
  }
}
