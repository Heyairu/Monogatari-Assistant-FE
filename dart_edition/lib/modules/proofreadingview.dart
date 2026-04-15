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

import "dart:async";
import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter/services.dart";
import "package:monogatari_assistant/bin/ui_library.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";
import "package:shared_preferences/shared_preferences.dart";

enum _PunctuationProfile { zhTw, zhHk, zhHans, jp, kr, enOther }

class ProofReadingView extends ConsumerStatefulWidget {
  const ProofReadingView({
    super.key,
    required this.textController,
    required this.chapterSwitchVersion,
    this.onRequestFocusEditor,
  });

  final TextEditingController textController;
  final int chapterSwitchVersion;
  final VoidCallback? onRequestFocusEditor;

  @override
  ConsumerState<ProofReadingView> createState() => _ProofReadingViewState();
}

class _ProofReadingViewState extends ConsumerState<ProofReadingView> {
  static const String _fillerWordAssetPath = "assets/jsons/fillerwords.json";
  static const String _punctuationProfileKey =
      "proofreading_punctuation_profile";
  static const String _latinSentenceDetectionKey =
      "proofreading_latin_sentence_detection";
  static const String _pairCheckEnabledKey = "proofreading_pair_check_enabled";
  static const String _symbolCheckEnabledKey =
      "proofreading_symbol_check_enabled";
  static const String _lineEndingCheckEnabledKey =
      "proofreading_line_ending_check_enabled";
  static const String _punctuationNormalizationEnabledKey =
      "proofreading_punctuation_normalization_enabled";
  static const String _fillerWordCheckEnabledKey =
      "proofreading_filler_word_check_enabled";
  static const String _lineEndingIgnoreCommaKey =
      "proofreading_line_ending_ignore_comma";
  static const String _lineEndingIgnoreDashKey =
      "proofreading_line_ending_ignore_dash";
  static const String _lineEndingIgnoreEllipsisKey =
      "proofreading_line_ending_ignore_ellipsis";
  static const String _lineEndingIgnoreColonKey =
      "proofreading_line_ending_ignore_colon";
  static const String _lineEndingIgnoreSemicolonKey =
      "proofreading_line_ending_ignore_semicolon";
  static const String _latinAllowCjkQuoteBracketEndingKey =
      "proofreading_latin_allow_cjk_quote_bracket_ending";
  static const String _latinAllowCjkQuestionExclamationEndingKey =
      "proofreading_latin_allow_cjk_question_exclamation_ending";
  static const String _latinAllowCjkPunctuationAroundCjkTextKey =
      "proofreading_latin_allow_cjk_punctuation_around_cjk_text";
  static const bool _numericDetectionAlwaysOn = true;

  // MARK: - Punctuation and Style Detection Logic

  static const Map<String, String> _openingToClosing = <String, String>{
    "(": ")",
    "[": "]",
    "{": "}",
    "（": "）",
    "［": "］",
    "｛": "｝",
    "「": "」",
    "『": "』",
    "【": "】",
    "《": "》",
    "〈": "〉",
    "“": "”",
    "\"": "\"",
    "‘": "’",
  };

  static const Map<String, String> _zhHantPunctuationMap = <String, String>{
    ",": "，",
    ":": "：",
    ";": "；",
    "?": "？",
    "!": "！",
    "(": "（",
    ")": "）",
    "[": "［",
    "]": "］",
    "{": "｛",
    "}": "｝",
    "─": "—",
  };

  static const Map<String, String> _zhHansPunctuationMap = <String, String>{
    ",": "，",
    ".": "。",
    ":": "：",
    ";": "；",
    "?": "？",
    "!": "！",
    "(": "（",
    ")": "）",
    "[": "［",
    "]": "］",
    "{": "｛",
    "}": "｝",
    "「": "“",
    "」": "”",
    "『": "‘",
    "』": "’",
    "─": "—",
  };

  static const Map<String, String> _jpPunctuationMap = <String, String>{
    ",": "、",
    "，": "、",
    ".": "。",
    ":": "：",
    ";": "；",
    "?": "？",
    "!": "！",
    "(": "（",
    ")": "）",
    "[": "［",
    "]": "］",
    "{": "｛",
    "}": "｝",
    "─": "—",
  };

  static const Map<String, String> _latinPunctuationMap = <String, String>{
    "，": ",",
    "。": ".",
    "、": ",",
    "：": ":",
    "；": ";",
    "？": "?",
    "！": "!",
    "（": "(",
    "）": ")",
    "［": "[",
    "］": "]",
    "｛": "{",
    "｝": "}",
    "「": "\"",
    "」": "\"",
    "『": "'",
    "』": "'",
    "“": "\"",
    "”": "\"",
    "‘": "'",
    "’": "'",
  };

  static const Map<String, String> _consecutiveSymbolCategory =
      <String, String>{
        ",": "逗號",
        "，": "逗號",
        ".": "句號",
        "。": "句號",
        "、": "頓號",
        "…": "刪節號",
        "「": "同類引號",
        "」": "同類引號",
        "『": "同類引號",
        "』": "同類引號",
        "“": "同類引號",
        "”": "同類引號",
        "‘": "同類引號",
        "’": "同類引號",
        "\"": "同類引號",
        "'": "同類引號",
      };

  static const Set<String> _cjkLineEndingSymbols = <String>{
    "。",
    "，",
    "…",
    "：",
    "?",
    "？",
    "!",
    "！",
    ")",
    "]",
    "}",
    "）",
    "］",
    "｝",
    "」",
    "』",
    "】",
    "》",
    "〉",
    "”",
    "\"",
    "’",
    "'",
    "—",
  };

  static const Set<String> _latinLineEndingSymbols = <String>{
    ".",
    ",",
    "?",
    "!",
    "…",
    ")",
    "]",
    "}",
    ":",
    "\"",
    "'",
    "”",
    "’",
  };

  static const Set<String> _maskScopedSymbols = <String>{
    "「",
    "」",
    "『",
    "』",
    "（",
    "）",
    "［",
    "］",
    "《",
    "》",
    "〈",
    "〉",
    "｛",
    "｝",
    "(",
    ")",
    "[",
    "]",
    "{",
    "}",
  };

  static const Set<String> _maskQuoteSymbols = <String>{
    "\"",
    "'",
    "「",
    "」",
    "『",
    "』",
    "“",
    "”",
    "‘",
    "’",
  };

  static const Set<String> _latinEndingCjkQuoteBracketSymbols = <String>{
    "（",
    "）",
    "［",
    "］",
    "｛",
    "｝",
    "「",
    "」",
    "『",
    "』",
    "【",
    "】",
    "《",
    "》",
    "〈",
    "〉",
    "“",
    "”",
    "‘",
    "’",
  };

  static const Set<String> _latinEndingCjkQuestionExclamationSymbols = <String>{
    "？",
    "！",
  };

  static const Set<String> _cjkPunctuationSymbols = <String>{
    "，",
    "。",
    "？",
    "！",
    "：",
    "；",
    "、",
    "…",
    "（",
    "）",
    "［",
    "］",
    "｛",
    "｝",
    "「",
    "」",
    "『",
    "』",
    "【",
    "】",
    "《",
    "》",
    "〈",
    "〉",
    "“",
    "”",
    "‘",
    "’",
    "—",
  };

  List<String> _fillerWords = const <String>[];
  String? _loadingError;
  bool _isLoadingFillerWords = true;

  List<_PairIssue> _pairIssues = const <_PairIssue>[];
  List<_ConsecutiveSymbolIssue> _SymbolIssues =
      const <_ConsecutiveSymbolIssue>[];
  List<_SameTypeQuoteIssue> _sameTypeQuoteIssues =
      const <_SameTypeQuoteIssue>[];
  List<_LineEndingIssue> _lineEndingIssues = const <_LineEndingIssue>[];
  _PunctuationProfile _punctuationProfile = _PunctuationProfile.zhTw;
  bool _enableLatinSentenceDetection = true;
  bool _enablePairCheck = true;
  bool _enableSymbolCheck = true;
  bool _enableLineEndingCheck = true;
  bool _enablePunctuationNormalization = true;
  bool _enableFillerWordCheck = true;
  bool _lineEndingIgnoreComma = true;
  bool _lineEndingIgnoreDash = true;
  bool _lineEndingIgnoreEllipsis = true;
  bool _lineEndingIgnoreColon = true;
  bool _lineEndingIgnoreSemicolon = true;
  bool _latinAllowCjkQuoteBracketEnding = true;
  bool _latinAllowCjkQuestionExclamationEnding = true;
  bool _latinAllowCjkPunctuationAroundCjkText = true;
  _PunctuationNormalizationResult? _punctuationResult;
  _FillerWordAnalysis _fillerWordAnalysis = _FillerWordAnalysis.empty();
  Timer? _scheduledAutoCheckTimer;
  ProviderSubscription<String>? _editorContentSubscription;
  late String _lastObservedText;

  @override
  void initState() {
    super.initState();
    _lastObservedText = ref.read(editorContentProvider);
    _editorContentSubscription = ref.listenManual<String>(
      editorContentProvider,
      (previous, next) {
        _onSharedTextChanged(next);
      },
    );
    _loadPunctuationProfile();
    _loadFillerWords();
  }

  @override
  void didUpdateWidget(covariant ProofReadingView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.chapterSwitchVersion != widget.chapterSwitchVersion) {
      _lastObservedText = ref.read(editorContentProvider);
      _scheduledAutoCheckTimer?.cancel();
      _scheduledAutoCheckTimer = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _runProofreading();
      });
    }
  }

  @override
  void dispose() {
    _editorContentSubscription?.close();
    _scheduledAutoCheckTimer?.cancel();
    super.dispose();
  }

  void _onSharedTextChanged(String currentText) {
    if (currentText == _lastObservedText) {
      return;
    }

    _lastObservedText = currentText;
    _scheduleBackgroundProofreading();
  }

  void _scheduleBackgroundProofreading() {
    if (_scheduledAutoCheckTimer?.isActive ?? false) {
      return;
    }

    _scheduledAutoCheckTimer = Timer(const Duration(seconds: 1), () {
      _scheduledAutoCheckTimer = null;
      if (!mounted) {
        return;
      }
      _runProofreading();
    });
  }

  Future<void> _loadFillerWords() async {
    setState(() {
      _isLoadingFillerWords = true;
      _loadingError = null;
    });

    try {
      final String raw = await rootBundle.loadString(_fillerWordAssetPath);
      final dynamic decoded = jsonDecode(raw);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException("贅字詞庫格式錯誤：根節點必須是物件");
      }

      final dynamic zhList = decoded["ZH"];
      if (zhList is! List) {
        throw const FormatException("贅字詞庫缺少 ZH 陣列");
      }

      final List<String> words =
          zhList
              .whereType<String>()
              .map((String e) => e.trim())
              .where((String e) => e.isNotEmpty)
              .toSet()
              .toList()
            ..sort((String a, String b) => b.length.compareTo(a.length));

      setState(() {
        _fillerWords = words;
      });
    } catch (error) {
      setState(() {
        _loadingError = "無法載入贅字詞庫：$error";
      });
    } finally {
      setState(() {
        _isLoadingFillerWords = false;
      });
    }
  }

  Future<void> _loadPunctuationProfile() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? code = prefs.getString(_punctuationProfileKey);
      final _PunctuationProfile loaded = _parsePunctuationProfile(code);
      final bool latinSentenceDetection =
          prefs.getBool(_latinSentenceDetectionKey) ?? true;
      final bool pairCheckEnabled = prefs.getBool(_pairCheckEnabledKey) ?? true;
      final bool symbolCheckEnabled =
          prefs.getBool(_symbolCheckEnabledKey) ?? true;
      final bool lineEndingCheckEnabled =
          prefs.getBool(_lineEndingCheckEnabledKey) ?? true;
      final bool punctuationNormalizationEnabled =
          prefs.getBool(_punctuationNormalizationEnabledKey) ?? true;
      final bool fillerWordCheckEnabled =
          prefs.getBool(_fillerWordCheckEnabledKey) ?? true;
      final bool lineEndingIgnoreComma =
          prefs.getBool(_lineEndingIgnoreCommaKey) ?? true;
      final bool lineEndingIgnoreDash =
          prefs.getBool(_lineEndingIgnoreDashKey) ?? true;
      final bool lineEndingIgnoreEllipsis =
          prefs.getBool(_lineEndingIgnoreEllipsisKey) ?? true;
      final bool lineEndingIgnoreColon =
          prefs.getBool(_lineEndingIgnoreColonKey) ?? true;
      final bool lineEndingIgnoreSemicolon =
          prefs.getBool(_lineEndingIgnoreSemicolonKey) ?? true;
      final bool latinAllowCjkQuoteBracketEnding =
          prefs.getBool(_latinAllowCjkQuoteBracketEndingKey) ?? true;
      final bool latinAllowCjkQuestionExclamationEnding =
          prefs.getBool(_latinAllowCjkQuestionExclamationEndingKey) ?? true;
      final bool latinAllowCjkPunctuationAroundCjkText =
          prefs.getBool(_latinAllowCjkPunctuationAroundCjkTextKey) ?? true;
      if (!mounted) {
        return;
      }

      if (loaded != _punctuationProfile ||
          latinSentenceDetection != _enableLatinSentenceDetection ||
          pairCheckEnabled != _enablePairCheck ||
          symbolCheckEnabled != _enableSymbolCheck ||
          lineEndingCheckEnabled != _enableLineEndingCheck ||
          punctuationNormalizationEnabled != _enablePunctuationNormalization ||
          fillerWordCheckEnabled != _enableFillerWordCheck ||
          lineEndingIgnoreComma != _lineEndingIgnoreComma ||
          lineEndingIgnoreDash != _lineEndingIgnoreDash ||
          lineEndingIgnoreEllipsis != _lineEndingIgnoreEllipsis ||
          lineEndingIgnoreColon != _lineEndingIgnoreColon ||
          lineEndingIgnoreSemicolon != _lineEndingIgnoreSemicolon ||
          latinAllowCjkQuoteBracketEnding != _latinAllowCjkQuoteBracketEnding ||
          latinAllowCjkQuestionExclamationEnding !=
              _latinAllowCjkQuestionExclamationEnding ||
          latinAllowCjkPunctuationAroundCjkText !=
              _latinAllowCjkPunctuationAroundCjkText) {
        setState(() {
          _punctuationProfile = loaded;
          _enableLatinSentenceDetection = latinSentenceDetection;
          _enablePairCheck = pairCheckEnabled;
          _enableSymbolCheck = symbolCheckEnabled;
          _enableLineEndingCheck = lineEndingCheckEnabled;
          _enablePunctuationNormalization = punctuationNormalizationEnabled;
          _enableFillerWordCheck = fillerWordCheckEnabled;
          _lineEndingIgnoreComma = lineEndingIgnoreComma;
          _lineEndingIgnoreDash = lineEndingIgnoreDash;
          _lineEndingIgnoreEllipsis = lineEndingIgnoreEllipsis;
          _lineEndingIgnoreColon = lineEndingIgnoreColon;
          _lineEndingIgnoreSemicolon = lineEndingIgnoreSemicolon;
          _latinAllowCjkQuoteBracketEnding = latinAllowCjkQuoteBracketEnding;
          _latinAllowCjkQuestionExclamationEnding =
              latinAllowCjkQuestionExclamationEnding;
          _latinAllowCjkPunctuationAroundCjkText =
              latinAllowCjkPunctuationAroundCjkText;
        });
      }
    } catch (_) {
      // 保持預設值，不阻斷檢查流程
    }

    if (mounted) {
      _runProofreading();
    }
  }

  _PunctuationProfile _parsePunctuationProfile(String? code) {
    switch (code) {
      case "ZH-TW":
        return _PunctuationProfile.zhTw;
      case "ZH-HK":
        return _PunctuationProfile.zhHk;
      case "ZH-HANS":
        return _PunctuationProfile.zhHans;
      case "JP":
        return _PunctuationProfile.jp;
      case "KR":
        return _PunctuationProfile.kr;
      case "EN/Other":
        return _PunctuationProfile.enOther;
      default:
        return _PunctuationProfile.zhTw;
    }
  }

  String _punctuationProfileCode(_PunctuationProfile profile) {
    switch (profile) {
      case _PunctuationProfile.zhTw:
        return "ZH-TW";
      case _PunctuationProfile.zhHk:
        return "ZH-HK";
      case _PunctuationProfile.zhHans:
        return "ZH-HANS";
      case _PunctuationProfile.jp:
        return "JP";
      case _PunctuationProfile.kr:
        return "KR";
      case _PunctuationProfile.enOther:
        return "EN/Other";
    }
  }

  Future<void> _setPunctuationProfile(_PunctuationProfile profile) async {
    if (profile == _punctuationProfile) {
      return;
    }

    setState(() {
      _punctuationProfile = profile;
    });
    _runProofreading();

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _punctuationProfileKey,
        _punctuationProfileCode(profile),
      );
    } catch (_) {
      // 儲存失敗不影響當前使用
    }
  }

  Future<void> _setLatinSentenceDetection(bool enabled) async {
    if (enabled == _enableLatinSentenceDetection) {
      return;
    }

    setState(() {
      _enableLatinSentenceDetection = enabled;
    });
    _runProofreading();

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_latinSentenceDetectionKey, enabled);
    } catch (_) {
      // 儲存失敗不影響當前使用
    }
  }

  Future<void> _setDetectionSetting({
    required bool enabled,
    required bool currentValue,
    required ValueChanged<bool> stateUpdater,
    required String prefsKey,
  }) async {
    if (enabled == currentValue) {
      return;
    }

    setState(() {
      stateUpdater(enabled);
    });
    _runProofreading();

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsKey, enabled);
    } catch (_) {
      // 儲存失敗不影響當前使用
    }
  }

  bool _usesCjkPunctuationStyle(_PunctuationProfile profile) {
    return profile == _PunctuationProfile.zhTw ||
        profile == _PunctuationProfile.zhHk ||
        profile == _PunctuationProfile.zhHans ||
        profile == _PunctuationProfile.jp;
  }

  Map<String, String> _punctuationMapForProfile(_PunctuationProfile profile) {
    switch (profile) {
      case _PunctuationProfile.zhTw:
      case _PunctuationProfile.zhHk:
        return _zhHantPunctuationMap;
      case _PunctuationProfile.zhHans:
        return _zhHansPunctuationMap;
      case _PunctuationProfile.jp:
        return _jpPunctuationMap;
      case _PunctuationProfile.kr:
      case _PunctuationProfile.enOther:
        return _latinPunctuationMap;
    }
  }

  Set<String> _allowedLineEndingSymbolsForProfile(_PunctuationProfile profile) {
    switch (profile) {
      case _PunctuationProfile.zhTw:
      case _PunctuationProfile.zhHk:
      case _PunctuationProfile.zhHans:
      case _PunctuationProfile.jp:
        return _cjkLineEndingSymbols;
      case _PunctuationProfile.kr:
      case _PunctuationProfile.enOther:
        return _latinLineEndingSymbols;
    }
  }

  bool _containsLatinLetter(String text) {
    for (int i = 0; i < text.length; i++) {
      if (_isAsciiLetter(text[i])) {
        return true;
      }
    }
    return false;
  }

  bool _containsAsciiDigitInText(String text) {
    for (int i = 0; i < text.length; i++) {
      if (_isAsciiDigit(text[i])) {
        return true;
      }
    }
    return false;
  }

  bool _shouldUseLatinStyleForLine(String line) {
    return _enableLatinSentenceDetection && _containsLatinLetter(line);
  }

  List<bool> _buildLatinStyleMaskForLine(
    String line, {
    Set<int>? maskBoundaryIndexes,
  }) {
    final List<bool> mask = List<bool>.filled(line.length, false);
    if (!_enableLatinSentenceDetection || line.isEmpty) {
      return mask;
    }

    final Map<String, String> closingToOpening = <String, String>{
      for (final MapEntry<String, String> entry in _openingToClosing.entries)
        if (entry.key != entry.value) entry.value: entry.key,
    };
    final Set<String> selfPairedSymbols = _openingToClosing.entries
        .where((MapEntry<String, String> entry) => entry.key == entry.value)
        .map((MapEntry<String, String> entry) => entry.key)
        .toSet();

    final List<_StackToken> stack = <_StackToken>[];
    final List<({int start, int end})> ranges = <({int start, int end})>[];

    for (int i = 0; i < line.length; i++) {
      final String char = line[i];

      if (selfPairedSymbols.contains(char)) {
        if (stack.isNotEmpty && stack.last.symbol == char) {
          final _StackToken open = stack.removeLast();
          ranges.add((start: open.index, end: i));
        } else {
          stack.add(_StackToken(symbol: char, index: i));
        }
        continue;
      }

      if (_openingToClosing.containsKey(char)) {
        stack.add(_StackToken(symbol: char, index: i));
        continue;
      }

      if (!closingToOpening.containsKey(char) || stack.isEmpty) {
        continue;
      }

      final String expectedOpening = closingToOpening[char] ?? "";
      if (stack.last.symbol == expectedOpening) {
        final _StackToken open = stack.removeLast();
        ranges.add((start: open.index, end: i));
      }
    }

    for (final ({int start, int end}) range in ranges) {
      bool hasLatin = false;
      bool hasCjk = false;
      for (int i = range.start; i <= range.end; i++) {
        if (_isAsciiLetter(line[i])) {
          hasLatin = true;
        }
        if (_isCjkCharacter(line[i])) {
          hasCjk = true;
        }
        if (hasLatin && hasCjk) {
          break;
        }
      }

      // 僅在成對區段幾乎為純拉丁內容時，才整段套用拉丁語境。
      // 若同時含有 CJK 與拉丁文字，避免把整句 CJK 標點誤判為拉丁標點。
      if (hasLatin && !hasCjk) {
        for (int i = range.start; i <= range.end; i++) {
          mask[i] = true;
        }
        maskBoundaryIndexes?.add(range.start);
        maskBoundaryIndexes?.add(range.end);
      }
    }

    int segmentStart = -1;
    bool segmentHasLatin = false;

    void flushSegment(int endExclusive) {
      if (segmentStart < 0) {
        return;
      }
      if (segmentHasLatin) {
        for (int i = segmentStart; i < endExclusive; i++) {
          if (!mask[i]) {
            mask[i] = true;
          }
        }
      }
      segmentStart = -1;
      segmentHasLatin = false;
    }

    for (int i = 0; i < line.length; i++) {
      final String char = line[i];
      if (mask[i] ||
          _isCjkNonPunctuationMaskCharacter(char) ||
          _isCjkPunctuationLeadingCjkText(line, i) ||
          _isCjkPunctuationInCjkContext(line, i)) {
        flushSegment(i);
        continue;
      }

      if (segmentStart < 0) {
        segmentStart = i;
      }
      if (_isAsciiLetter(char)) {
        segmentHasLatin = true;
      }
    }
    flushSegment(line.length);

    return mask;
  }

  bool _isMathSymbol(String char) {
    return "+-*/%^=<>±×÷~()[]{}（）［］｛｝".contains(char);
  }

  bool _isAllowedNumericContextChar(String char) {
    return _isAsciiDigit(char) || _isMathSymbol(char) || _isWhitespace(char);
  }

  bool _isProtectedNumericDot(String text, int index) {
    if (index < 0 || index >= text.length || text[index] != ".") {
      return false;
    }

    int left = index - 1;
    bool hasLeftDigit = false;
    while (left >= 0 && _isAllowedNumericContextChar(text[left])) {
      if (_isAsciiDigit(text[left])) {
        hasLeftDigit = true;
      }
      left--;
    }

    int right = index + 1;
    bool hasRightDigit = false;
    while (right < text.length && _isAllowedNumericContextChar(text[right])) {
      if (_isAsciiDigit(text[right])) {
        hasRightDigit = true;
      }
      right++;
    }

    if (!hasLeftDigit || !hasRightDigit) {
      return false;
    }

    final String segment = text.substring(left + 1, right);
    if (RegExp(r"[A-Za-z]").hasMatch(segment)) {
      return false;
    }
    if (RegExp(
      r"[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]",
    ).hasMatch(segment)) {
      return false;
    }

    return true;
  }

  void _runProofreading() {
    final String text = widget.textController.text;
    final List<_PairIssue> pairIssues = _enablePairCheck
        ? _checkPairClosures(text)
        : const <_PairIssue>[];
    final List<_ConsecutiveSymbolIssue> SymbolIssues = _enableSymbolCheck
        ? _detectConsecutiveSymbols(text)
        : const <_ConsecutiveSymbolIssue>[];
    final List<_SameTypeQuoteIssue> sameTypeQuoteIssues = _enableSymbolCheck
        ? _detectSameTypeQuoteNesting(text)
        : const <_SameTypeQuoteIssue>[];
    final List<_LineEndingIssue> lineEndingIssues = _enableLineEndingCheck
        ? _detectLineEndingIssues(text)
        : const <_LineEndingIssue>[];
    final _PunctuationNormalizationResult? punctuationResult =
        _enablePunctuationNormalization ? _normalizePunctuation(text) : null;
    final bool requiresFillerAnalysis = _enableFillerWordCheck;
    final _FillerWordAnalysis fillerWordAnalysis = requiresFillerAnalysis
        ? _analyzeFillerWords(text)
        : _FillerWordAnalysis.empty();

    setState(() {
      _pairIssues = pairIssues;
      _SymbolIssues = SymbolIssues;
      _sameTypeQuoteIssues = sameTypeQuoteIssues;
      _lineEndingIssues = lineEndingIssues;
      _punctuationResult = punctuationResult;
      _fillerWordAnalysis = fillerWordAnalysis;
    });
  }

  List<_SameTypeQuoteIssue> _detectSameTypeQuoteNesting(String text) {
    final List<_SameTypeQuoteIssue> issues = <_SameTypeQuoteIssue>[];
    final List<String> lines = text.split("\n");
    int lineStartOffset = 0;

    for (final String line in lines) {
      final _SameTypeQuoteIssue? asciiIssue = _detectAsciiQuoteIssueInLine(
        line,
        lineStartOffset,
      );
      if (asciiIssue != null) {
        issues.add(asciiIssue);
      }

      final _SameTypeQuoteIssue? cjkIssue = _detectCjkQuoteIssueInLine(
        line,
        lineStartOffset,
      );
      if (cjkIssue != null) {
        issues.add(cjkIssue);
      }

      lineStartOffset += line.length + 1;
    }

    return issues;
  }

  _SameTypeQuoteIssue? _detectAsciiQuoteIssueInLine(
    String line,
    int lineStartOffset,
  ) {
    final List<_AsciiQuoteMarker> markers = _collectAsciiQuoteMarkers(line);
    if (markers.length < 2) {
      return null;
    }

    final String? startMessage = markers.first.symbol == "'"
        ? "引號結構應以\" \"開頭，不應以' '開頭。"
        : null;

    int maxDepth = 0;
    for (final _AsciiQuoteMarker marker in markers) {
      if (marker.level > maxDepth) {
        maxDepth = marker.level;
      }
    }

    final String suggested = _applyAsciiQuoteSuggestion(line, markers);
    final bool hasNestedIssue = maxDepth > 1;
    if (!hasNestedIssue && startMessage == null) {
      return null;
    }

    return _SameTypeQuoteIssue(
      index: lineStartOffset + markers.first.index,
      message: startMessage ?? "偵測到引號層級未交錯，建議以\" \"與' '交替。",
      suggestion: suggested,
    );
  }

  String _applyAsciiQuoteSuggestion(
    String text,
    List<_AsciiQuoteMarker> markers,
  ) {
    final List<String> chars = text.split("");
    for (final _AsciiQuoteMarker marker in markers) {
      if (marker.isOpen) {
        chars[marker.index] = marker.level.isOdd ? '"' : "'";
      } else {
        chars[marker.index] = marker.level.isOdd ? '"' : "'";
      }
    }
    return chars.join();
  }

  List<_AsciiQuoteMarker> _collectAsciiQuoteMarkers(String text) {
    final List<int> positions = <int>[];
    final List<String> symbols = <String>[];

    for (int i = 0; i < text.length; i++) {
      final String ch = text[i];
      if (ch == '"' || (ch == "'" && _shouldConvertSingleQuote(text, i))) {
        positions.add(i);
        symbols.add(ch);
      }
    }

    final int usableCount = positions.length.isOdd
        ? positions.length - 1
        : positions.length;
    if (usableCount <= 0) {
      return const <_AsciiQuoteMarker>[];
    }

    final List<_AsciiQuoteMarker> markers = <_AsciiQuoteMarker>[];
    int depth = 0;

    for (int k = 0; k < usableCount; k++) {
      final int index = positions[k];
      final String symbol = symbols[k];
      final int remaining = usableCount - k;

      final String prev = index > 0 ? text[index - 1] : "";
      final String next = index < text.length - 1 ? text[index + 1] : "";
      final bool likelyOpen = _isLikelyQuoteOpeningContext(prev, next);
      final bool likelyClose = _isLikelyQuoteClosingContext(prev, next);

      final bool isOpen;
      if (depth == 0) {
        isOpen = true;
      } else if (likelyClose && !likelyOpen) {
        isOpen = false;
      } else if (likelyOpen && !likelyClose) {
        isOpen = true;
      } else if (remaining == depth) {
        isOpen = false;
      } else {
        isOpen = remaining > depth + 1;
      }

      if (isOpen) {
        final int level = depth + 1;
        markers.add(
          _AsciiQuoteMarker(
            index: index,
            symbol: symbol,
            isOpen: true,
            level: level,
          ),
        );
        depth = level;
      } else {
        final int level = depth == 0 ? 1 : depth;
        markers.add(
          _AsciiQuoteMarker(
            index: index,
            symbol: symbol,
            isOpen: false,
            level: level,
          ),
        );
        if (depth > 0) {
          depth--;
        }
      }
    }

    return markers;
  }

  bool _isLikelyQuoteOpeningContext(String prev, String next) {
    final bool prevAllowsOpen =
        prev.isEmpty ||
        _isWhitespace(prev) ||
        "([{（［｛「『【《〈".contains(prev) ||
        "，。！？；：、,.;:!?".contains(prev);

    final bool nextLooksContent =
        next.isNotEmpty &&
        (_isAsciiLetter(next) || _isAsciiDigit(next) || _isCjkCharacter(next));

    return prevAllowsOpen || nextLooksContent;
  }

  bool _isLikelyQuoteClosingContext(String prev, String next) {
    final bool prevLooksContent =
        prev.isNotEmpty &&
        (_isAsciiLetter(prev) || _isAsciiDigit(prev) || _isCjkCharacter(prev));

    final bool nextAllowsClose =
        next.isEmpty ||
        _isWhitespace(next) ||
        ")]}）］｝」』】》〉，。！？；：、,.;:!?".contains(next);

    return prevLooksContent || nextAllowsClose;
  }

  _SameTypeQuoteIssue? _detectCjkQuoteIssueInLine(
    String line,
    int lineStartOffset,
  ) {
    final List<int> positions = <int>[];
    for (int i = 0; i < line.length; i++) {
      final String ch = line[i];
      if (ch == "「" || ch == "」" || ch == "『" || ch == "』") {
        positions.add(i);
      }
    }

    if (positions.length < 2) {
      return null;
    }

    final String firstQuote = line[positions.first];
    final String? startMessage = firstQuote == "『"
        ? "引號結構應以「」開頭，不應以『』開頭。"
        : null;

    final List<String> chars = line.split("");
    int depth = 0;
    for (final int pos in positions) {
      final String ch = line[pos];
      final bool isOpen = ch == "「" || ch == "『";
      if (isOpen) {
        final int level = depth + 1;
        chars[pos] = level.isOdd ? "「" : "『";
        depth = level;
      } else {
        final int level = depth == 0 ? 1 : depth;
        chars[pos] = level.isOdd ? "」" : "』";
        if (depth > 0) {
          depth--;
        }
      }
    }

    final String suggested = chars.join();
    if (suggested == line && startMessage == null) {
      return null;
    }

    return _SameTypeQuoteIssue(
      index: lineStartOffset + positions.first,
      message: startMessage ?? "偵測到引號層級未交錯，建議以「『』」為一循環交替。",
      suggestion: suggested,
    );
  }

  List<_ConsecutiveSymbolIssue> _detectConsecutiveSymbols(String text) {
    final List<_ConsecutiveSymbolIssue> issues = <_ConsecutiveSymbolIssue>[];
    int i = 0;

    while (i < text.length) {
      final String symbol = text[i];
      int j = i + 1;
      while (j < text.length && text[j] == symbol) {
        j++;
      }

      final int count = j - i;
      final String? category = _consecutiveSymbolCategory[symbol];
      if (_shouldFlagConsecutiveSymbol(symbol, count) && category != null) {
        final String sequence = text.substring(i, j);
        final String message = symbol == "…"
            ? "刪節號建議使用「……」，目前為「$sequence」。"
            : "連續$count個$category「$sequence」。";
        issues.add(
          _ConsecutiveSymbolIssue(
            index: i,
            symbol: symbol,
            count: count,
            category: category,
            sequence: sequence,
            message: message,
          ),
        );
      }

      i = j;
    }

    return issues;
  }

  bool _shouldFlagConsecutiveSymbol(String symbol, int count) {
    if (symbol == "…") {
      return count != 2;
    }

    return count >= 2;
  }

  List<_LineEndingIssue> _detectLineEndingIssues(String text) {
    final List<_LineEndingIssue> issues = <_LineEndingIssue>[];
    final List<String> lines = text.split("\n");
    final String code = _punctuationProfileCode(_punctuationProfile);
    int lineStartOffset = 0;

    for (final String line in lines) {
      final String trimmedRight = line.replaceFirst(RegExp(r"\s+$"), "");
      if (trimmedRight.isNotEmpty) {
        final Set<int> maskBoundaryIndexes = <int>{};
        final List<bool> latinMask = _buildLatinStyleMaskForLine(
          trimmedRight,
          maskBoundaryIndexes: maskBoundaryIndexes,
        );
        final int lastIndex = trimmedRight.length - 1;
        final String endingSymbol = trimmedRight[lastIndex];
        final bool useLatinStyle = latinMask.isNotEmpty && latinMask[lastIndex];
        if (_isMaskedPunctuationCharacter(
          line: trimmedRight,
          char: endingSymbol,
          index: lastIndex,
          useLatinStyle: useLatinStyle,
          maskBoundaryIndexes: maskBoundaryIndexes,
        )) {
          lineStartOffset += line.length + 1;
          continue;
        }

        final Set<String> allowedSymbols = <String>{
          ...useLatinStyle
              ? _latinLineEndingSymbols
              : _allowedLineEndingSymbolsForProfile(_punctuationProfile),
        };
        if (useLatinStyle && _latinAllowCjkQuoteBracketEnding) {
          allowedSymbols.addAll(_latinEndingCjkQuoteBracketSymbols);
        }
        if (useLatinStyle && _latinAllowCjkQuestionExclamationEnding) {
          allowedSymbols.addAll(_latinEndingCjkQuestionExclamationSymbols);
        }
        if (_numericDetectionAlwaysOn &&
            _isProtectedNumericDot(trimmedRight, lastIndex)) {
          allowedSymbols.add(".");
        }

        if (_shouldIgnoreLineEndingWarning(trimmedRight, endingSymbol)) {
          lineStartOffset += line.length + 1;
          continue;
        }

        if (_shouldForceWarnLineEnding(trimmedRight, endingSymbol) ||
            !allowedSymbols.contains(endingSymbol)) {
          issues.add(
            _LineEndingIssue(
              index: lineStartOffset + lastIndex,
              endingSymbol: endingSymbol,
              message: "[$code] 行尾未符合結尾規則，目前為「$endingSymbol」。",
            ),
          );
        }
      }

      lineStartOffset += line.length + 1;
    }

    return issues;
  }

  void _applyPunctuationNormalization() {
    final _PunctuationNormalizationResult? result = _punctuationResult;
    if (result == null) {
      return;
    }

    _applyUpdatedText(
      result.normalizedText,
      caretOffset: result.normalizedText.length,
    );
  }

  void _resolvePunctuationChange(_PunctuationChange change) {
    final String text = widget.textController.text;
    final int start = change.index;
    final int endExclusive = start + change.from.length;
    if (start < 0 || endExclusive > text.length) {
      return;
    }
    if (text.substring(start, endExclusive) != change.from) {
      return;
    }

    final String updated = _replaceTextRange(
      text,
      start,
      endExclusive,
      change.to,
    );
    _applyUpdatedText(updated, caretOffset: start + change.to.length);
  }

  void _resolveConsecutiveIssue(_ConsecutiveSymbolIssue issue) {
    final String text = widget.textController.text;
    if (text.isEmpty) {
      return;
    }

    int start = -1;
    int endExclusive = -1;
    if (issue.index >= 0 &&
        issue.index + issue.sequence.length <= text.length &&
        text.substring(issue.index, issue.index + issue.sequence.length) ==
            issue.sequence) {
      start = issue.index;
      endExclusive = issue.index + issue.sequence.length;
    } else {
      final int pivot = issue.index < 0
          ? 0
          : (issue.index >= text.length ? text.length - 1 : issue.index);
      if (text[pivot] != issue.symbol) {
        return;
      }
      start = pivot;
      while (start > 0 && text[start - 1] == issue.symbol) {
        start--;
      }
      endExclusive = pivot + 1;
      while (endExclusive < text.length && text[endExclusive] == issue.symbol) {
        endExclusive++;
      }
    }

    final String replacement = _normalizedReplacementForConsecutiveIssue(issue);
    final String updated = _replaceTextRange(
      text,
      start,
      endExclusive,
      replacement,
    );
    _applyUpdatedText(updated, caretOffset: start + replacement.length);
  }

  void _resolveSameTypeQuoteIssue(_SameTypeQuoteIssue issue) {
    final String text = widget.textController.text;
    if (text.isEmpty) {
      return;
    }

    final ({int start, int endExclusive}) range = _lineRangeAtIndex(
      text,
      issue.index,
    );
    final String updated = _replaceTextRange(
      text,
      range.start,
      range.endExclusive,
      issue.suggestion,
    );
    _applyUpdatedText(
      updated,
      caretOffset: range.start + issue.suggestion.length,
    );
  }

  void _resolveAllAnomalies() {
    final String text = widget.textController.text;
    if (text.isEmpty) {
      return;
    }

    final List<({int start, int endExclusive})> lineRanges =
        <({int start, int endExclusive})>[];
    final List<
      ({int start, int endExclusive, String replacement, int priority})
    >
    operations =
        <({int start, int endExclusive, String replacement, int priority})>[];

    for (final _SameTypeQuoteIssue issue in _sameTypeQuoteIssues) {
      final ({int start, int endExclusive}) range = _lineRangeAtIndex(
        text,
        issue.index,
      );
      lineRanges.add(range);
      operations.add((
        start: range.start,
        endExclusive: range.endExclusive,
        replacement: issue.suggestion,
        priority: 0,
      ));
    }

    bool overlapsLineRange(int start, int endExclusive) {
      for (final ({int start, int endExclusive}) range in lineRanges) {
        if (start < range.endExclusive && endExclusive > range.start) {
          return true;
        }
      }
      return false;
    }

    for (final _ConsecutiveSymbolIssue issue in _SymbolIssues) {
      final int start = issue.index;
      final int endExclusive = issue.index + issue.sequence.length;
      if (start < 0 || endExclusive > text.length) {
        continue;
      }
      if (overlapsLineRange(start, endExclusive)) {
        continue;
      }
      if (text.substring(start, endExclusive) != issue.sequence) {
        continue;
      }
      operations.add((
        start: start,
        endExclusive: endExclusive,
        replacement: _normalizedReplacementForConsecutiveIssue(issue),
        priority: 1,
      ));
    }

    if (operations.isEmpty) {
      return;
    }

    operations.sort((a, b) {
      final int byStart = b.start.compareTo(a.start);
      if (byStart != 0) {
        return byStart;
      }
      return a.priority.compareTo(b.priority);
    });

    String updated = text;
    for (final ({int start, int endExclusive, String replacement, int priority})
        operation
        in operations) {
      if (operation.start < 0 ||
          operation.endExclusive > updated.length ||
          operation.start > operation.endExclusive) {
        continue;
      }
      updated = _replaceTextRange(
        updated,
        operation.start,
        operation.endExclusive,
        operation.replacement,
      );
    }

    _applyUpdatedText(updated);
  }

  String _normalizedReplacementForConsecutiveIssue(
    _ConsecutiveSymbolIssue issue,
  ) {
    if (issue.symbol == "…") {
      return "……";
    }
    return issue.symbol;
  }

  ({int start, int endExclusive}) _lineRangeAtIndex(String text, int index) {
    final int safeIndex = index < 0
        ? 0
        : (index > text.length ? text.length : index);
    int start = safeIndex;
    while (start > 0 && text[start - 1] != "\n") {
      start--;
    }

    int endExclusive = safeIndex;
    while (endExclusive < text.length && text[endExclusive] != "\n") {
      endExclusive++;
    }

    return (start: start, endExclusive: endExclusive);
  }

  String _replaceTextRange(
    String text,
    int start,
    int endExclusive,
    String replacement,
  ) {
    return text.substring(0, start) +
        replacement +
        text.substring(endExclusive);
  }

  void _applyUpdatedText(String updated, {int? caretOffset}) {
    if (updated == widget.textController.text) {
      return;
    }

    final int requestedOffset =
        caretOffset ?? widget.textController.selection.baseOffset;
    final int safeOffset = requestedOffset < 0
        ? 0
        : (requestedOffset > updated.length ? updated.length : requestedOffset);

    widget.textController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: safeOffset),
    );
    widget.onRequestFocusEditor?.call();
    _runProofreading();
  }

  void _jumpToOffset(int index) {
    final String text = widget.textController.text;
    final int safeIndex = index.clamp(0, text.length);
    widget.textController.selection = TextSelection.collapsed(
      offset: safeIndex,
    );
    widget.onRequestFocusEditor?.call();
  }

  List<_PairIssue> _checkPairClosures(String text) {
    final Map<String, String> closingToOpening = <String, String>{
      for (final MapEntry<String, String> entry in _openingToClosing.entries)
        entry.value: entry.key,
    };
    final Set<String> selfPairedSymbols = _openingToClosing.entries
        .where((MapEntry<String, String> entry) => entry.key == entry.value)
        .map((MapEntry<String, String> entry) => entry.key)
        .toSet();

    final List<_StackToken> stack = <_StackToken>[];
    final List<_PairIssue> issues = <_PairIssue>[];

    for (int i = 0; i < text.length; i++) {
      final String char = text[i];

      if (selfPairedSymbols.contains(char)) {
        if (stack.isNotEmpty && stack.last.symbol == char) {
          stack.removeLast();
        } else {
          stack.add(_StackToken(symbol: char, index: i));
        }
        continue;
      }

      if (_openingToClosing.containsKey(char)) {
        stack.add(_StackToken(symbol: char, index: i));
        continue;
      }

      if (!closingToOpening.containsKey(char)) {
        continue;
      }

      if (stack.isEmpty) {
        issues.add(
          _PairIssue(index: i, symbol: char, message: "出現未配對的右符號「$char」。"),
        );
        continue;
      }

      final _StackToken top = stack.removeLast();
      final String expected = _openingToClosing[top.symbol] ?? "";
      if (char != expected) {
        issues.add(
          _PairIssue(
            index: i,
            symbol: char,
            message: "右符號「$char」與左符號「${top.symbol}」不匹配，預期為「$expected」。",
          ),
        );
      }
    }

    for (final _StackToken token in stack.reversed) {
      final String expected = _openingToClosing[token.symbol] ?? "";
      issues.add(
        _PairIssue(
          index: token.index,
          symbol: token.symbol,
          message: "左符號「${token.symbol}」未閉合，缺少「$expected」。",
        ),
      );
    }

    issues.sort((a, b) => a.index.compareTo(b.index));
    return issues;
  }

  _PunctuationNormalizationResult _normalizePunctuation(String text) {
    final StringBuffer buffer = StringBuffer();
    final List<_PunctuationChange> changes = <_PunctuationChange>[];
    final _PunctuationProfile profile = _punctuationProfile;
    final List<String> lines = text.split("\n");
    int lineStartOffset = 0;

    for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final String line = lines[lineIndex];
      final Set<int> maskBoundaryIndexes = <int>{};
      final List<bool> latinMask = _buildLatinStyleMaskForLine(
        line,
        maskBoundaryIndexes: maskBoundaryIndexes,
      );
      final Map<int, String> quoteReplacementMapDefault =
          _buildQuoteReplacementMap(line, profile);
      final Map<int, String> quoteReplacementMapLatin =
          _buildQuoteReplacementMap(line, _PunctuationProfile.enOther);
      final Map<String, String> punctuationMapDefault =
          _punctuationMapForProfile(profile);

      for (int i = 0; i < line.length; i++) {
        final bool useLatinStyle = latinMask.isNotEmpty && latinMask[i];
        final bool useCjkStyle =
            !useLatinStyle && _usesCjkPunctuationStyle(profile);
        final Map<int, String> quoteReplacementMap = useLatinStyle
            ? quoteReplacementMapLatin
            : quoteReplacementMapDefault;
        final Map<String, String> punctuationMap = useLatinStyle
            ? _latinPunctuationMap
            : punctuationMapDefault;

        if (useCjkStyle) {
          if (line.startsWith("......", i)) {
            buffer.write("……");
            changes.add(
              _PunctuationChange(
                index: lineStartOffset + i,
                from: "......",
                to: "……",
              ),
            );
            i += 5;
            continue;
          } else if (line.startsWith("...", i)) {
            buffer.write("……");
            changes.add(
              _PunctuationChange(
                index: lineStartOffset + i,
                from: "...",
                to: "……",
              ),
            );
            i += 2;
            continue;
          }
        } else {
          if (line.startsWith("……", i)) {
            buffer.write("...");
            changes.add(
              _PunctuationChange(
                index: lineStartOffset + i,
                from: "……",
                to: "...",
              ),
            );
            i += 1;
            continue;
          } else if (line.startsWith("…", i)) {
            buffer.write("...");
            changes.add(
              _PunctuationChange(
                index: lineStartOffset + i,
                from: "…",
                to: "...",
              ),
            );
            continue;
          } else if (line.startsWith("......", i)) {
            buffer.write("...");
            changes.add(
              _PunctuationChange(
                index: lineStartOffset + i,
                from: "......",
                to: "...",
              ),
            );
            i += 5;
            continue;
          }
        }

        final String current = line[i];
        String? replacement;
        if (_isMaskedPunctuationCharacter(
          line: line,
          char: current,
          index: i,
          useLatinStyle: useLatinStyle,
          maskBoundaryIndexes: maskBoundaryIndexes,
        )) {
          replacement = null;
        } else if (current == "." &&
            _numericDetectionAlwaysOn &&
            _isProtectedNumericDot(line, i)) {
          replacement = null;
        } else if (current == "." &&
            useCjkStyle &&
            _shouldConvertPeriod(line, i)) {
          replacement = "。";
        } else if (current == "\"" ||
            (current == "'" && _shouldConvertSingleQuote(line, i))) {
          replacement = quoteReplacementMap[i];
        } else {
          replacement = punctuationMap[current];
        }

        if (replacement != null) {
          buffer.write(replacement);
          changes.add(
            _PunctuationChange(
              index: lineStartOffset + i,
              from: current,
              to: replacement,
            ),
          );
        } else {
          buffer.write(current);
        }
      }

      if (lineIndex < lines.length - 1) {
        buffer.write("\n");
      }
      lineStartOffset += line.length + 1;
    }

    final String normalizedText = buffer.toString();
    return _PunctuationNormalizationResult(
      normalizedText: normalizedText,
      changes: changes,
    );
  }

  Map<int, String> _buildQuoteReplacementMap(
    String text,
    _PunctuationProfile profile,
  ) {
    final Map<int, String> replacements = <int, String>{};
    final List<_AsciiQuoteMarker> markers = _collectAsciiQuoteMarkers(text);
    for (final _AsciiQuoteMarker marker in markers) {
      if (profile == _PunctuationProfile.zhHans) {
        if (marker.isOpen) {
          replacements[marker.index] = marker.level.isOdd ? "“" : "‘";
        } else {
          replacements[marker.index] = marker.level.isOdd ? "”" : "’";
        }
      } else if (profile == _PunctuationProfile.kr ||
          profile == _PunctuationProfile.enOther) {
        if (marker.isOpen) {
          replacements[marker.index] = marker.level.isOdd ? "\"" : "'";
        } else {
          replacements[marker.index] = marker.level.isOdd ? "\"" : "'";
        }
      } else {
        if (marker.isOpen) {
          replacements[marker.index] = marker.level.isOdd ? "「" : "『";
        } else {
          replacements[marker.index] = marker.level.isOdd ? "」" : "』";
        }
      }
    }

    return replacements;
  }

  bool _shouldConvertPeriod(String text, int index) {
    final bool hasPrev = index > 0;
    final bool hasNext = index < text.length - 1;
    if (!hasPrev) {
      return false;
    }

    final String prev = text[index - 1];
    final String next = hasNext ? text[index + 1] : "";

    final bool isDecimal =
        hasNext && _isAsciiDigit(prev) && _isAsciiDigit(next);
    if (isDecimal) {
      return false;
    }

    final bool cjkBefore = _isCjkCharacter(prev);
    final bool cjkOrBoundaryAfter =
        !hasNext || _isCjkCharacter(next) || _isWhitespace(next);
    return cjkBefore && cjkOrBoundaryAfter;
  }

  bool _shouldConvertSingleQuote(String text, int index) {
    final bool hasPrev = index > 0;
    final bool hasNext = index < text.length - 1;
    if (!hasPrev || !hasNext) {
      return false;
    }

    final String prev = text[index - 1];
    final String next = text[index + 1];
    final bool isWordApostrophe = _isAsciiLetter(prev) && _isAsciiLetter(next);
    return !isWordApostrophe;
  }

  bool _isAsciiDigit(String char) {
    if (char.isEmpty) {
      return false;
    }
    final int code = char.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  bool _isAsciiLetter(String char) {
    if (char.isEmpty) {
      return false;
    }
    final int code = char.codeUnitAt(0);
    final bool lower = code >= 97 && code <= 122;
    final bool upper = code >= 65 && code <= 90;
    return lower || upper;
  }

  bool _isWhitespace(String char) {
    return char.trim().isEmpty;
  }

  bool _isCjkCharacter(String char) {
    if (char.isEmpty) {
      return false;
    }
    final int code = char.codeUnitAt(0);
    return (code >= 0x3400 && code <= 0x4DBF) ||
        (code >= 0x4E00 && code <= 0x9FFF) ||
        (code >= 0xF900 && code <= 0xFAFF);
  }

  bool _isCjkNonPunctuationMaskCharacter(String char) {
    if (!_isCjkCharacter(char)) {
      return false;
    }
    return !"，。！？：；、…「」『』（）［］｛｝【】《》〈〉“”‘’".contains(char);
  }

  bool _isCjkPunctuationCharacter(String char) {
    return _cjkPunctuationSymbols.contains(char);
  }

  bool _isCjkPunctuationLeadingCjkText(String line, int index) {
    if (index < 0 || index >= line.length) {
      return false;
    }

    final String char = line[index];
    if (!_isCjkPunctuationCharacter(char)) {
      return false;
    }

    int right = index + 1;
    while (right < line.length && _isCjkPunctuationCharacter(line[right])) {
      right++;
    }

    if (right >= line.length) {
      return false;
    }

    return _isCjkCharacter(line[right]);
  }

  bool _isCjkPunctuationInCjkContext(String line, int index) {
    if (!_latinAllowCjkPunctuationAroundCjkText) {
      return false;
    }
    if (index < 0 || index >= line.length) {
      return false;
    }

    final String char = line[index];
    if (!_isCjkPunctuationCharacter(char)) {
      return false;
    }

    int left = index - 1;
    while (left >= 0 && _isCjkPunctuationCharacter(line[left])) {
      left--;
    }

    int right = index + 1;
    while (right < line.length && _isCjkPunctuationCharacter(line[right])) {
      right++;
    }

    final bool leftInCjkContext = left < 0 || _isCjkCharacter(line[left]);
    final bool rightInCjkContext =
        right >= line.length || _isCjkCharacter(line[right]);

    return leftInCjkContext || rightInCjkContext;
  }

  bool _shouldIgnoreLineEndingWarning(String line, String endingSymbol) {
    if (_lineEndingIgnoreComma &&
        (endingSymbol == "," ||
            endingSymbol == "，" ||
            (_punctuationProfile == _PunctuationProfile.jp &&
                endingSymbol == "、"))) {
      return true;
    }
    if (_lineEndingIgnoreDash && (endingSymbol == "—" || endingSymbol == "-")) {
      return true;
    }
    if (_lineEndingIgnoreColon &&
        (endingSymbol == ":" || endingSymbol == "：")) {
      return true;
    }
    if (_lineEndingIgnoreSemicolon &&
        (endingSymbol == ";" || endingSymbol == "；")) {
      return true;
    }
    if (_lineEndingIgnoreEllipsis &&
        (endingSymbol == "…" || line.endsWith("……") || line.endsWith("..."))) {
      return true;
    }
    return false;
  }

  bool _shouldForceWarnLineEnding(String line, String endingSymbol) {
    if (!_lineEndingIgnoreComma &&
        (endingSymbol == "," ||
            endingSymbol == "，" ||
            (_punctuationProfile == _PunctuationProfile.jp &&
                endingSymbol == "、"))) {
      return true;
    }
    if (!_lineEndingIgnoreDash &&
        (endingSymbol == "—" || endingSymbol == "-")) {
      return true;
    }
    if (!_lineEndingIgnoreColon &&
        (endingSymbol == ":" || endingSymbol == "：")) {
      return true;
    }
    if (!_lineEndingIgnoreSemicolon &&
        (endingSymbol == ";" || endingSymbol == "；")) {
      return true;
    }
    if (!_lineEndingIgnoreEllipsis &&
        (endingSymbol == "…" || line.endsWith("……") || line.endsWith("..."))) {
      return true;
    }

    return false;
  }

  bool _isMaskedPunctuationCharacter({
    required String line,
    required String char,
    required int index,
    required bool useLatinStyle,
    required Set<int> maskBoundaryIndexes,
  }) {
    if (maskBoundaryIndexes.contains(index) &&
        _maskQuoteSymbols.contains(char)) {
      return true;
    }

    if (!useLatinStyle &&
        (_maskScopedSymbols.contains(char) ||
            _isCjkNonPunctuationMaskCharacter(char))) {
      return true;
    }

    if (useLatinStyle &&
        _isAllowedLatinEndingCjkSymbolInMask(line, index, char)) {
      return true;
    }

    return false;
  }

  bool _isAllowedLatinEndingCjkSymbolInMask(
    String line,
    int index,
    String char,
  ) {
    final bool isQuoteBracketAllowed =
        _latinAllowCjkQuoteBracketEnding &&
        _latinEndingCjkQuoteBracketSymbols.contains(char);
    final bool isQuestionExclamationAllowed =
        _latinAllowCjkQuestionExclamationEnding &&
        _latinEndingCjkQuestionExclamationSymbols.contains(char);

    if (!isQuoteBracketAllowed && !isQuestionExclamationAllowed) {
      return false;
    }

    return _isLatinEndingContext(line, index);
  }

  bool _isLatinEndingContext(String line, int index) {
    int left = index - 1;
    while (left >= 0 && _isLatinEndingCjkSymbol(line[left])) {
      left--;
    }

    final bool hasLatinBefore =
        left >= 0 && (_isAsciiLetter(line[left]) || _isAsciiDigit(line[left]));
    if (!hasLatinBefore) {
      return false;
    }

    int right = index + 1;
    while (right < line.length && _isLatinEndingCjkSymbol(line[right])) {
      right++;
    }

    if (right >= line.length) {
      return true;
    }

    final String next = line[right];
    return _isWhitespace(next) ||
        _isCjkPunctuationCharacter(next) ||
        _isCjkCharacter(next);
  }

  bool _isLatinEndingCjkSymbol(String char) {
    return _latinEndingCjkQuoteBracketSymbols.contains(char) ||
        _latinEndingCjkQuestionExclamationSymbols.contains(char);
  }

  _FillerWordAnalysis _analyzeFillerWords(String text) {
    if (text.trim().isEmpty || _fillerWords.isEmpty) {
      return _FillerWordAnalysis.empty();
    }

    final List<_FillerWordHit> hits = <_FillerWordHit>[];
    int totalMatches = 0;

    for (final String word in _fillerWords) {
      final RegExp pattern = RegExp(RegExp.escape(word));
      final List<int> positions = pattern
          .allMatches(text)
          .map((Match match) => match.start)
          .toList();
      final int count = positions.length;
      if (count > 0) {
        hits.add(
          _FillerWordHit(word: word, count: count, positions: positions),
        );
        totalMatches += count;
      }
    }

    hits.sort((a, b) => b.count.compareTo(a.count));
    final int effectiveChars = _countEffectiveChars(text);
    final double ratio = effectiveChars == 0
        ? 0
        : totalMatches / effectiveChars.toDouble();

    return _FillerWordAnalysis(
      totalMatches: totalMatches,
      effectiveChars: effectiveChars,
      ratio: ratio,
      hits: hits,
    );
  }

  int _countEffectiveChars(String text) {
    int count = 0;
    for (int i = 0; i < text.length; i++) {
      final String char = text[i];
      if (_isCjkCharacter(char) ||
          _isAsciiDigit(char) ||
          _isAsciiLetter(char)) {
        count++;
      }
    }
    return count;
  }

  ({int line, int column}) _lineColumnAt(String text, int index) {
    int line = 1;
    int column = 1;

    final int safeIndex = index.clamp(0, text.length);
    for (int i = 0; i < safeIndex; i++) {
      final String current = text[i];
      if (current == "\n") {
        line++;
        column = 1;
      } else {
        column++;
      }
    }

    return (line: line, column: column);
  }

  // 警語元件
  Widget _buildWarningCard() {
    return Card(
      elevation: 0,
      color: Colors.redAccent,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_outlined, color: Colors.yellow),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "本功能正在開發中，使用時可能出現錯誤。",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // MARK: - UI 介面建構
  @override
  Widget build(BuildContext context) {
    final String sourceText = widget.textController.text;
    final _PunctuationNormalizationResult? punctuationResult =
        _punctuationResult;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 標題
            const Align(
              alignment: Alignment.centerLeft,
              child: LargeTitle(icon: Icons.spellcheck, text: "文本校正"),
            ),
            const SizedBox(height: 32),
            // 警語
            _buildWarningCard(),
            const SizedBox(height: 16),

            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      "此處可協助執行文本檢查。",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text("當前文本長度：${sourceText.length} 字元"),
                    if (_isLoadingFillerWords)
                      const Text("載入贅字詞庫中")
                    else if (_loadingError != null)
                      Text(_loadingError!)
                    else
                      Text("贅字詞庫已載入 ${_fillerWords.length} 筆"),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SmallTitle(
                      icon: Icons.data_array_rounded,
                      text: "引號、括號閉合檢查",
                    ),
                    const SizedBox(height: 8),
                    _buildPairCheckResult(sourceText),
                    const Divider(height: 24),
                    SmallTitle(
                      icon: Icons.warning_amber_rounded,
                      text: "標點異常檢測",
                    ),
                    const SizedBox(height: 8),
                    _buildConsecutiveSymbolResult(sourceText),
                    const Divider(height: 24),
                    SmallTitle(icon: Icons.format_line_spacing, text: "行尾辨識"),
                    const SizedBox(height: 8),
                    _buildLineEndingResult(sourceText),
                    const Divider(height: 24),
                    SmallTitle(icon: Icons.edit_note, text: "標點符號格式統一"),
                    const SizedBox(height: 8),
                    _buildPunctuationResult(punctuationResult),
                    const Divider(height: 24),
                    SmallTitle(icon: Icons.grading, text: "贅字檢查"),
                    const SizedBox(height: 8),
                    _buildFillerWordResult(),
                    const Divider(height: 24),
                    SmallTitle(icon: Icons.track_changes_outlined, text: "贅字率計算"),
                    const SizedBox(height: 8),
                    _buildFillerRateResult(),
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
                    SmallTitle(icon: Icons.settings, text: "檢測設定"),
                    const SizedBox(height: 12),
                    _buildPunctuationProfileSetting(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableResultArea({
    required List<Widget> children,
    double maxHeight = 200,
  }) {
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Scrollbar(
        thumbVisibility: true,
        child: ListView(
          primary: false,
          padding: EdgeInsets.zero,
          children: children,
        ),
      ),
    );
  }

  Widget _buildResolveSingleButton({
    required VoidCallback onPressed,
    String tooltip = "解決單項",
  }) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: const Icon(Icons.build_circle_outlined, size: 18),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }

  Widget _buildDetectionToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildPunctuationProfileSetting() {
    final List<DropdownOption<_PunctuationProfile>> options =
        <DropdownOption<_PunctuationProfile>>[
          const DropdownOption<_PunctuationProfile>(
            value: _PunctuationProfile.zhTw,
            label: "ZH-TW",
          ),
          const DropdownOption<_PunctuationProfile>(
            value: _PunctuationProfile.zhHk,
            label: "ZH-HK",
          ),
          const DropdownOption<_PunctuationProfile>(
            value: _PunctuationProfile.zhHans,
            label: "ZH-HANS",
          ),
          const DropdownOption<_PunctuationProfile>(
            value: _PunctuationProfile.jp,
            label: "JP",
          ),
          const DropdownOption<_PunctuationProfile>(
            value: _PunctuationProfile.kr,
            label: "KR",
          ),
          const DropdownOption<_PunctuationProfile>(
            value: _PunctuationProfile.enOther,
            label: "EN/Other",
          ),
        ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetectionToggleTile(
          title: "引號、括號閉合檢查",
          subtitle: "檢查配對與閉合狀態",
          value: _enablePairCheck,
          onChanged: (bool value) {
            unawaited(
              _setDetectionSetting(
                enabled: value,
                currentValue: _enablePairCheck,
                stateUpdater: (bool enabled) => _enablePairCheck = enabled,
                prefsKey: _pairCheckEnabledKey,
              ),
            );
          },
        ),
        _buildDetectionToggleTile(
          title: "標點異常檢測",
          subtitle: "檢查連續標點與引號層級",
          value: _enableSymbolCheck,
          onChanged: (bool value) {
            unawaited(
              _setDetectionSetting(
                enabled: value,
                currentValue: _enableSymbolCheck,
                stateUpdater: (bool enabled) => _enableSymbolCheck = enabled,
                prefsKey: _symbolCheckEnabledKey,
              ),
            );
          },
        ),
        _buildDetectionToggleTile(
          title: "標點符號格式統一",
          subtitle: "檢查可統一的標點替換",
          value: _enablePunctuationNormalization,
          onChanged: (bool value) {
            unawaited(
              _setDetectionSetting(
                enabled: value,
                currentValue: _enablePunctuationNormalization,
                stateUpdater: (bool enabled) =>
                    _enablePunctuationNormalization = enabled,
                prefsKey: _punctuationNormalizationEnabledKey,
              ),
            );
          },
        ),
        _buildDetectionToggleTile(
          title: "贅字檢查",
          subtitle: "檢查詞庫中的贅字出現位置",
          value: _enableFillerWordCheck,
          onChanged: (bool value) {
            unawaited(
              _setDetectionSetting(
                enabled: value,
                currentValue: _enableFillerWordCheck,
                stateUpdater: (bool enabled) =>
                    _enableFillerWordCheck = enabled,
                prefsKey: _fillerWordCheckEnabledKey,
              ),
            );
          },
        ),
        _buildDetectionToggleTile(
          title: "行尾辨識",
          subtitle: "檢查行尾符號是否符合規則",
          value: _enableLineEndingCheck,
          onChanged: (bool value) {
            unawaited(
              _setDetectionSetting(
                enabled: value,
                currentValue: _enableLineEndingCheck,
                stateUpdater: (bool enabled) =>
                    _enableLineEndingCheck = enabled,
                prefsKey: _lineEndingCheckEnabledKey,
              ),
            );
          },
        ),
        if (_enableLineEndingCheck) ...[
          const SizedBox(height: 8),
          Text("行尾辨識細項", style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          _buildDetectionToggleTile(
            title: "行尾逗號不提示",
            subtitle: "行尾為 , 或 ，時不顯示提示",
            value: _lineEndingIgnoreComma,
            onChanged: (bool value) {
              unawaited(
                _setDetectionSetting(
                  enabled: value,
                  currentValue: _lineEndingIgnoreComma,
                  stateUpdater: (bool enabled) =>
                      _lineEndingIgnoreComma = enabled,
                  prefsKey: _lineEndingIgnoreCommaKey,
                ),
              );
            },
          ),
          _buildDetectionToggleTile(
            title: "行尾破折號不提示",
            subtitle: "行尾為 — 或 - 時不顯示提示",
            value: _lineEndingIgnoreDash,
            onChanged: (bool value) {
              unawaited(
                _setDetectionSetting(
                  enabled: value,
                  currentValue: _lineEndingIgnoreDash,
                  stateUpdater: (bool enabled) =>
                      _lineEndingIgnoreDash = enabled,
                  prefsKey: _lineEndingIgnoreDashKey,
                ),
              );
            },
          ),
          _buildDetectionToggleTile(
            title: "行尾刪節號不提示",
            subtitle: "行尾為 … / …… 時不顯示提示",
            value: _lineEndingIgnoreEllipsis,
            onChanged: (bool value) {
              unawaited(
                _setDetectionSetting(
                  enabled: value,
                  currentValue: _lineEndingIgnoreEllipsis,
                  stateUpdater: (bool enabled) =>
                      _lineEndingIgnoreEllipsis = enabled,
                  prefsKey: _lineEndingIgnoreEllipsisKey,
                ),
              );
            },
          ),
          _buildDetectionToggleTile(
            title: "行尾冒號不提示",
            subtitle: "行尾為 : 或 ：時不顯示提示",
            value: _lineEndingIgnoreColon,
            onChanged: (bool value) {
              unawaited(
                _setDetectionSetting(
                  enabled: value,
                  currentValue: _lineEndingIgnoreColon,
                  stateUpdater: (bool enabled) =>
                      _lineEndingIgnoreColon = enabled,
                  prefsKey: _lineEndingIgnoreColonKey,
                ),
              );
            },
          ),
          _buildDetectionToggleTile(
            title: "行尾分號不提示",
            subtitle: "行尾為 ; 或 ；時不顯示提示",
            value: _lineEndingIgnoreSemicolon,
            onChanged: (bool value) {
              unawaited(
                _setDetectionSetting(
                  enabled: value,
                  currentValue: _lineEndingIgnoreSemicolon,
                  stateUpdater: (bool enabled) =>
                      _lineEndingIgnoreSemicolon = enabled,
                  prefsKey: _lineEndingIgnoreSemicolonKey,
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 8),
        SmallTitle(icon: Icons.translate, text: "格式選項"),
        const SizedBox(height: 12),
        AppDropdownField<_PunctuationProfile>(
          value: _punctuationProfile,
          options: options,
          onChanged: (final _PunctuationProfile? value) {
            if (value == null) {
              return;
            }
            unawaited(_setPunctuationProfile(value));
          },
          labelText: "標點符號檢查格式",
          hintText: "請選擇格式",
        ),
        const SizedBox(height: 4),
        Text(
          "目前格式：${_punctuationProfileCode(_punctuationProfile)}",
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text("拉丁文句檢測"),
          subtitle: const Text("偵測到拉丁文字時，自動套用拉丁標點"),
          value: _enableLatinSentenceDetection,
          onChanged: (bool value) {
            unawaited(_setLatinSentenceDetection(value));
          },
        ),
        const SizedBox(height: 8),
        Text("拉丁字母辨識細項", style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        _buildDetectionToggleTile(
          title: "允許字尾使用 CJK 引號/括號",
          subtitle: "拉丁字尾可接受 CJK 引號與括號",
          value: _latinAllowCjkQuoteBracketEnding,
          onChanged: (bool value) {
            unawaited(
              _setDetectionSetting(
                enabled: value,
                currentValue: _latinAllowCjkQuoteBracketEnding,
                stateUpdater: (bool enabled) =>
                    _latinAllowCjkQuoteBracketEnding = enabled,
                prefsKey: _latinAllowCjkQuoteBracketEndingKey,
              ),
            );
          },
        ),
        _buildDetectionToggleTile(
          title: "允許字尾使用 CJK 驚嘆號/問號",
          subtitle: "拉丁字尾可接受 ！與 ？",
          value: _latinAllowCjkQuestionExclamationEnding,
          onChanged: (bool value) {
            unawaited(
              _setDetectionSetting(
                enabled: value,
                currentValue: _latinAllowCjkQuestionExclamationEnding,
                stateUpdater: (bool enabled) =>
                    _latinAllowCjkQuestionExclamationEnding = enabled,
                prefsKey: _latinAllowCjkQuestionExclamationEndingKey,
              ),
            );
          },
        ),
        _buildDetectionToggleTile(
          title: "允許在 CJK 文字前後加入 CJK 標點",
          subtitle: "若任一側語境為行首/CJK/行尾，CJK 標點不視為拉丁延伸",
          value: _latinAllowCjkPunctuationAroundCjkText,
          onChanged: (bool value) {
            unawaited(
              _setDetectionSetting(
                enabled: value,
                currentValue: _latinAllowCjkPunctuationAroundCjkText,
                stateUpdater: (bool enabled) =>
                    _latinAllowCjkPunctuationAroundCjkText = enabled,
                prefsKey: _latinAllowCjkPunctuationAroundCjkTextKey,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPairCheckResult(String sourceText) {
    if (!_enablePairCheck) {
      return Text("此檢測已關閉。", style: Theme.of(context).textTheme.bodySmall);
    }

    if (sourceText.trim().isEmpty) {
      return Text("請先輸入文本。", style: Theme.of(context).textTheme.bodySmall);
    }

    if (_pairIssues.isEmpty) {
      return Text(
        "未發現閉合問題。",
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.green,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return _buildScrollableResultArea(
      children: _pairIssues.map((final _PairIssue issue) {
        final ({int line, int column}) position = _lineColumnAt(
          sourceText,
          issue.index,
        );
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: TextButton.icon(
            onPressed: () => _jumpToOffset(issue.index),
            icon: const Icon(Icons.my_location, size: 16),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              alignment: Alignment.centerLeft,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            label: Text(
              " ${position.line}:${position.column} ｜ ${issue.message}",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPunctuationResult(_PunctuationNormalizationResult? result) {
    final String sourceText = widget.textController.text;
    if (!_enablePunctuationNormalization) {
      return Text("此檢測已關閉。", style: Theme.of(context).textTheme.bodySmall);
    }

    if (sourceText.trim().isEmpty) {
      return Text("請先輸入文本。", style: Theme.of(context).textTheme.bodySmall);
    }

    if (result == null) {
      return Text("尚未執行檢查。", style: Theme.of(context).textTheme.bodySmall);
    }

    if (!result.hasChanges) {
      return Text(
        "格式已一致，無需調整。",
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.green,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("共偵測到 ${result.changes.length} 處可統一的標點。"),
        const SizedBox(height: 6),
        _buildScrollableResultArea(
          children: result.changes.map((final _PunctuationChange change) {
            final ({int line, int column}) position = _lineColumnAt(
              sourceText,
              change.index,
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildResolveSingleButton(
                  onPressed: () => _resolvePunctuationChange(change),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _jumpToOffset(change.index),
                      icon: const Icon(Icons.edit_location_alt, size: 16),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        alignment: Alignment.centerLeft,
                      ),
                      label: Text(
                        " ${position.line}:${position.column} ｜ ${change.from} → ${change.to}",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _applyPunctuationNormalization,
          child: const SmallTitle(icon: Icons.auto_fix_high, text: "全部解決"),
        ),
      ],
    );
  }

  Widget _buildConsecutiveSymbolResult(String sourceText) {
    if (!_enableSymbolCheck) {
      return Text("此檢測已關閉。", style: Theme.of(context).textTheme.bodySmall);
    }

    if (sourceText.trim().isEmpty) {
      return Text("請先輸入文本。", style: Theme.of(context).textTheme.bodySmall);
    }

    if (_SymbolIssues.isEmpty && _sameTypeQuoteIssues.isEmpty) {
      return Text(
        "未發現標點符號異常。",
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.green,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildScrollableResultArea(
          children: [
            ..._SymbolIssues.map((final _ConsecutiveSymbolIssue issue) {
              final ({int line, int column}) position = _lineColumnAt(
                sourceText,
                issue.index,
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildResolveSingleButton(
                    onPressed: () => _resolveConsecutiveIssue(issue),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _jumpToOffset(issue.index),
                        icon: const Icon(Icons.my_location, size: 16),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          alignment: Alignment.centerLeft,
                        ),
                        label: Text(
                          " ${position.line}:${position.column} ｜ ${issue.message}",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
            ..._sameTypeQuoteIssues.map((final _SameTypeQuoteIssue issue) {
              final ({int line, int column}) position = _lineColumnAt(
                sourceText,
                issue.index,
              );
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildResolveSingleButton(
                            onPressed: () => _resolveSameTypeQuoteIssue(issue),
                          ),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () => _jumpToOffset(issue.index),
                              icon: const Icon(Icons.my_location, size: 16),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                alignment: Alignment.centerLeft,
                              ),
                              label: Text(
                                " ${position.line}:${position.column} ｜ ${issue.message}",
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "建議：${issue.suggestion}",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _resolveAllAnomalies,
          child: const SmallTitle(icon: Icons.auto_fix_high, text: "全部解決"),
        ),
      ],
    );
  }

  Widget _buildLineEndingResult(String sourceText) {
    if (!_enableLineEndingCheck) {
      return Text("此檢測已關閉。", style: Theme.of(context).textTheme.bodySmall);
    }

    if (sourceText.trim().isEmpty) {
      return Text("請先輸入文本。", style: Theme.of(context).textTheme.bodySmall);
    }

    if (_lineEndingIssues.isEmpty) {
      return Text(
        "未發現行尾異常。",
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.green,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return _buildScrollableResultArea(
      children: _lineEndingIssues.map((final _LineEndingIssue issue) {
        final ({int line, int column}) position = _lineColumnAt(
          sourceText,
          issue.index,
        );
        return Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _jumpToOffset(issue.index),
            icon: const Icon(Icons.my_location, size: 16),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              alignment: Alignment.centerLeft,
            ),
            label: Text(
              " ${position.line}:${position.column} ｜ ${issue.message}",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFillerWordResult() {
    final String sourceText = widget.textController.text;
    if (!_enableFillerWordCheck) {
      return Text("此檢測已關閉。", style: Theme.of(context).textTheme.bodySmall);
    }

    if (sourceText.trim().isEmpty) {
      return Text("請先輸入文本。", style: Theme.of(context).textTheme.bodySmall);
    }

    if (_fillerWordAnalysis.hits.isEmpty) {
      return Text(
        "未偵測到詞庫中的贅字。",
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.green,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    final List<_FillerWordHit> topHits = _fillerWordAnalysis.hits
        .take(20)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("點擊下列贅字展開位置列表。", style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 280),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Scrollbar(
            thumbVisibility: true,
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: topHits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (BuildContext context, int index) {
                final _FillerWordHit hit = topHits[index];
                return Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 10),
                    childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    dense: true,
                    title: Text(
                      hit.word,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    subtitle: Text(
                      "出現 ${hit.count} 次",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: hit.positions.map((final int pos) {
                          final ({int line, int column}) position =
                              _lineColumnAt(sourceText, pos);
                          return ActionChip(
                            avatar: const Icon(Icons.place, size: 14),
                            label: Text("${position.line}:${position.column}"),
                            onPressed: () => _jumpToOffset(pos),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        if (_fillerWordAnalysis.hits.length > topHits.length)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              "僅顯示前 ${topHits.length} 個高頻贅字。",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _buildFillerRateResult() {
    final String sourceText = widget.textController.text;
    if (!_enableFillerWordCheck) {
      return Text("此檢測已關閉。", style: Theme.of(context).textTheme.bodySmall);
    }

    if (sourceText.trim().isEmpty) {
      return Text("請先輸入文本。", style: Theme.of(context).textTheme.bodySmall);
    }

    final double percent = _fillerWordAnalysis.ratio * 100;
    final double progress = _fillerWordAnalysis.ratio.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("贅字總次數：${_fillerWordAnalysis.totalMatches}"),
        Text("有效字數：${_fillerWordAnalysis.effectiveChars}"),
        Text("贅字率：${percent.toStringAsFixed(2)}%"),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: progress,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _StackToken {
  const _StackToken({required this.symbol, required this.index});

  final String symbol;
  final int index;
}

class _PairIssue {
  const _PairIssue({
    required this.index,
    required this.symbol,
    required this.message,
  });

  final int index;
  final String symbol;
  final String message;
}

class _ConsecutiveSymbolIssue {
  const _ConsecutiveSymbolIssue({
    required this.index,
    required this.symbol,
    required this.count,
    required this.category,
    required this.sequence,
    required this.message,
  });

  final int index;
  final String symbol;
  final int count;
  final String category;
  final String sequence;
  final String message;
}

class _LineEndingIssue {
  const _LineEndingIssue({
    required this.index,
    required this.endingSymbol,
    required this.message,
  });

  final int index;
  final String endingSymbol;
  final String message;
}

class _SameTypeQuoteIssue {
  const _SameTypeQuoteIssue({
    required this.index,
    required this.message,
    required this.suggestion,
  });

  final int index;
  final String message;
  final String suggestion;
}

class _AsciiQuoteMarker {
  const _AsciiQuoteMarker({
    required this.index,
    required this.symbol,
    required this.isOpen,
    required this.level,
  });

  final int index;
  final String symbol;
  final bool isOpen;
  final int level;
}

class _PunctuationChange {
  const _PunctuationChange({
    required this.index,
    required this.from,
    required this.to,
  });

  final int index;
  final String from;
  final String to;
}

class _PunctuationNormalizationResult {
  const _PunctuationNormalizationResult({
    required this.normalizedText,
    required this.changes,
  });

  final String normalizedText;
  final List<_PunctuationChange> changes;

  bool get hasChanges => changes.isNotEmpty;
}

class _FillerWordHit {
  const _FillerWordHit({
    required this.word,
    required this.count,
    required this.positions,
  });

  final String word;
  final int count;
  final List<int> positions;
}

class _FillerWordAnalysis {
  const _FillerWordAnalysis({
    required this.totalMatches,
    required this.effectiveChars,
    required this.ratio,
    required this.hits,
  });

  const _FillerWordAnalysis.empty()
    : totalMatches = 0,
      effectiveChars = 0,
      ratio = 0,
      hits = const <_FillerWordHit>[];

  final int totalMatches;
  final int effectiveChars;
  final double ratio;
  final List<_FillerWordHit> hits;
}
