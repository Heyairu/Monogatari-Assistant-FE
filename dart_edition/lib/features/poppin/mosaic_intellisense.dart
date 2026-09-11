import "package:flutter/services.dart";

import "../inline_annotations/inline_annotation.dart";
import "../inline_annotations/inline_annotation_syntax.dart";
import "../inline_annotations/inline_annotation_target_resolver.dart";

enum MosaicCompletionKind { target, color, literal }

final class MosaicCompletionCandidate {
  final String id;
  final String label;
  final String detail;
  final String insertText;
  final List<MosaicCompletionCandidate> children;
  final bool submenuOnly;
  final InlineAnnotationKind? createTargetKind;
  final String? createParentId;
  final int createDepth;

  const MosaicCompletionCandidate({
    required this.id,
    required this.label,
    required this.detail,
    required this.insertText,
    this.children = const [],
    this.submenuOnly = false,
    this.createTargetKind,
    this.createParentId,
    this.createDepth = 0,
  });
}

final class MosaicCompletionSession {
  final MosaicCompletionKind kind;
  final TextRange rawReplacementRange;
  final List<MosaicCompletionCandidate> candidates;

  const MosaicCompletionSession({
    required this.kind,
    required this.rawReplacementRange,
    required this.candidates,
  });
}

typedef MosaicTargetCandidateLoader =
    List<InlineAnnotationTargetInfo> Function(InlineAnnotationKind kind);

final class MosaicIntelliSenseEngine {
  static const int maxCandidatesPerLevel = 100;

  static const _colorLabels = <String, String>{
    "0": "自動",
    "A": "綠色",
    "B": "藍色",
    "C": "粉色",
    "D": "紫色",
    "E": "黃色",
    "F": "灰色",
  };

  const MosaicIntelliSenseEngine();

  MosaicCompletionSession? build({
    required String rawText,
    required int rawCaret,
    required MosaicTargetCandidateLoader loadTargets,
  }) {
    final caret = rawCaret.clamp(0, rawText.length);
    final prefix = rawText.substring(0, caret);
    final annotationStart = prefix.lastIndexOf("//");
    if (annotationStart >= 0 && _hasOpenAnnotationDelimiter(prefix)) {
      final draft = prefix.substring(annotationStart);
      final target = _targetSession(draft, annotationStart, caret, loadTargets);
      if (target != null) return target;
      final color = _colorSession(draft, caret);
      if (color != null) return color;
    }
    if (caret == 0) return null;
    final directTarget = _directTargetDraftSession(prefix, caret, loadTargets);
    if (directTarget != null) return directTarget;
    final manual = _manualTriggerSession(prefix, caret, loadTargets);
    if (manual != null) return manual;
    final followsManualSlash =
        caret >= 2 && prefix.codeUnitAt(caret - 2) == 0x2f;
    return switch (rawText[caret - 1]) {
      "^" when !followsManualSlash => _directHighlightSession(caret),
      "<" when !followsManualSlash => _objectBrowserSession(caret, loadTargets),
      _ => null,
    };
  }

  MosaicCompletionSession? _manualTriggerSession(
    String prefix,
    int caret,
    MosaicTargetCandidateLoader loadTargets,
  ) {
    if (prefix.endsWith(r"\//")) {
      return _manualSession(caret, loadTargets, replacementStart: caret - 3);
    }
    if (prefix.endsWith("//")) {
      return _manualSession(caret, loadTargets, replacementStart: caret - 2);
    }
    final last = prefix.codeUnitAt(caret - 1);
    if (last == 0x2f) {
      final precedingBackslashes = _precedingBackslashCount(prefix, caret - 1);
      // A slash immediately following a backslash belongs to literal input.
      // This remains true when an escaped backslash pair is projected into a
      // single visible backslash; the hidden raw unit must not turn the slash
      // into a fresh manual trigger.
      if (precedingBackslashes > 0) return null;
      return _manualSession(caret, loadTargets);
    }
    if (last == 0x5c) {
      if (caret >= 2 && prefix.codeUnitAt(caret - 2) == 0x2f) return null;
      if (_precedingBackslashCount(prefix, caret).isEven) return null;
      return _manualSession(caret, loadTargets);
    }
    return null;
  }

  int _precedingBackslashCount(String text, int end) {
    var count = 0;
    for (var index = end - 1; index >= 0; index--) {
      if (text.codeUnitAt(index) != 0x5c) break;
      count++;
    }
    return count;
  }

  MosaicCompletionSession _objectBrowserSession(
    int caret,
    MosaicTargetCandidateLoader loadTargets,
  ) {
    MosaicCompletionCandidate category(
      InlineAnnotationKind kind,
      String symbol,
    ) {
      return MosaicCompletionCandidate(
        id: "object-${kind.name}",
        label: "$symbol ${_kindLabel(kind)}",
        detail: "瀏覽${_kindLabel(kind)}對象",
        insertText: symbol,
        children: _targetCandidates(
          kind: kind,
          state: InlineAnnotationState.none,
          colors: const InlineAnnotationColorCode(
            background: "B",
            foreground: "0",
          ),
          query: "",
          loadTargets: loadTargets,
        ),
        submenuOnly: true,
      );
    }

    return MosaicCompletionSession(
      kind: MosaicCompletionKind.target,
      rawReplacementRange: TextRange(start: caret - 1, end: caret),
      candidates: [
        category(InlineAnnotationKind.character, "@"),
        category(InlineAnnotationKind.location, "!"),
        category(InlineAnnotationKind.event, "#"),
        category(InlineAnnotationKind.foreshadowing, "?"),
        category(InlineAnnotationKind.plan, "&"),
      ],
    );
  }

  MosaicCompletionSession? _directTargetDraftSession(
    String prefix,
    int caret,
    MosaicTargetCandidateLoader loadTargets,
  ) {
    const symbols = "@!#?&";
    const maxQueryLength = 128;
    final scanStart = (caret - maxQueryLength - 1).clamp(0, caret);
    for (var index = caret - 1; index >= scanStart; index--) {
      final character = prefix[index];
      if (symbols.contains(character)) {
        if (index > 0 && prefix.codeUnitAt(index - 1) == 0x2f) return null;
        final draft = prefix.substring(index + 1, caret);
        final state = switch (draft.isEmpty ? null : draft[0]) {
          "+" => InlineAnnotationState.start,
          "-" => InlineAnnotationState.end,
          _ => InlineAnnotationState.none,
        };
        final query = state == InlineAnnotationState.none
            ? draft
            : draft.substring(1);
        if (_endsDirectTargetDraft(query)) {
          return _directTargetSession(
            character,
            index,
            caret,
            query.trim().toLowerCase(),
            state,
            loadTargets,
          );
        }
        return null;
      }
      if (_isDirectDraftBoundary(character)) return null;
    }
    return null;
  }

  bool _endsDirectTargetDraft(String query) {
    for (var index = 0; index < query.length; index++) {
      if (_isDirectDraftBoundary(query[index]) ||
          query[index] == "+" ||
          query[index] == "-") {
        return false;
      }
    }
    return true;
  }

  bool _isDirectDraftBoundary(String character) {
    return character.trim().isEmpty ||
        r"/\<>[]{}()，。！？；：,.;:".contains(character) ||
        character == "^";
  }

  MosaicCompletionSession _manualSession(
    int caret,
    MosaicTargetCandidateLoader loadTargets, {
    int? replacementStart,
  }) {
    List<MosaicCompletionCandidate> targetChildren(InlineAnnotationKind kind) =>
        _targetCandidates(
          kind: kind,
          state: InlineAnnotationState.none,
          colors: const InlineAnnotationColorCode(
            background: "B",
            foreground: "0",
          ),
          query: "",
          loadTargets: loadTargets,
        );

    return MosaicCompletionSession(
      kind: MosaicCompletionKind.literal,
      rawReplacementRange: TextRange(
        start: replacementStart ?? caret - 1,
        end: caret,
      ),
      candidates: [
        MosaicCompletionCandidate(
          id: "manual-character",
          label: "@",
          detail: "人物候選",
          insertText: "@",
          children: targetChildren(InlineAnnotationKind.character),
          submenuOnly: true,
        ),
        MosaicCompletionCandidate(
          id: "manual-location",
          label: "!",
          detail: "地點候選",
          insertText: "!",
          children: targetChildren(InlineAnnotationKind.location),
          submenuOnly: true,
        ),
        MosaicCompletionCandidate(
          id: "manual-event",
          label: "#",
          detail: "事件候選",
          insertText: "#",
          children: targetChildren(InlineAnnotationKind.event),
          submenuOnly: true,
        ),
        MosaicCompletionCandidate(
          id: "manual-foreshadowing",
          label: "?",
          detail: "伏筆候選",
          insertText: "?",
          children: targetChildren(InlineAnnotationKind.foreshadowing),
          submenuOnly: true,
        ),
        MosaicCompletionCandidate(
          id: "manual-plan",
          label: "&",
          detail: "計畫候選",
          insertText: "&",
          children: targetChildren(InlineAnnotationKind.plan),
          submenuOnly: true,
        ),
        MosaicCompletionCandidate(
          id: "manual-highlight",
          label: "^",
          detail: "高亮色彩候選",
          insertText: "^",
          children: _directHighlightSession(caret).candidates,
          submenuOnly: true,
        ),
        const MosaicCompletionCandidate(
          id: "template-character",
          label: "@<>",
          detail: "人物標記骨架",
          insertText: "//@<",
        ),
        const MosaicCompletionCandidate(
          id: "template-location",
          label: "!<>",
          detail: "地點標記骨架",
          insertText: "//!<",
        ),
        const MosaicCompletionCandidate(
          id: "template-event",
          label: "#<>",
          detail: "事件標記骨架",
          insertText: "//#<",
        ),
        const MosaicCompletionCandidate(
          id: "template-foreshadowing",
          label: "?<>",
          detail: "伏筆標記骨架",
          insertText: "//?<",
        ),
        const MosaicCompletionCandidate(
          id: "template-plan",
          label: "&<>",
          detail: "計畫標記骨架",
          insertText: "//&<",
        ),
        const MosaicCompletionCandidate(
          id: "template-highlight",
          label: "^<>",
          detail: "高亮標記骨架",
          insertText: "//^<",
        ),
        const MosaicCompletionCandidate(
          id: "literal-slash",
          label: "插入字面 /",
          detail: r"以 \/ 寫入，避免被解析為語法界線",
          insertText: r"\/",
        ),
        const MosaicCompletionCandidate(
          id: "literal-backslash",
          label: "插入字面 \\",
          detail: r"以 \\ 寫入",
          insertText: r"\\",
        ),
      ],
    );
  }

  MosaicCompletionSession? _targetSession(
    String draft,
    int annotationStart,
    int caret,
    MosaicTargetCandidateLoader loadTargets,
  ) {
    final match = RegExp(
      r"^//([@!#?&])([+-])?(?:\^([A-F0])([A-F0])?)?(?:<([^|<>]*))?$",
    ).firstMatch(draft);
    if (match == null) return null;
    final kind = _kind(match.group(1)!);
    final state = switch (match.group(2)) {
      "+" => InlineAnnotationState.start,
      "-" => InlineAnnotationState.end,
      _ => InlineAnnotationState.none,
    };
    final background = match.group(3) ?? "B";
    final foreground = match.group(4) ?? "0";
    final query = (match.group(5) ?? "").trim().toLowerCase();
    return MosaicCompletionSession(
      kind: MosaicCompletionKind.target,
      rawReplacementRange: TextRange(start: annotationStart, end: caret),
      candidates: _targetCandidates(
        kind: kind,
        state: state,
        colors: InlineAnnotationColorCode(
          background: background,
          foreground: foreground,
        ),
        query: query,
        loadTargets: loadTargets,
      ),
    );
  }

  MosaicCompletionSession _directTargetSession(
    String symbol,
    int triggerStart,
    int caret,
    String query,
    InlineAnnotationState state,
    MosaicTargetCandidateLoader loadTargets,
  ) {
    final kind = _kind(symbol);
    return MosaicCompletionSession(
      kind: MosaicCompletionKind.target,
      rawReplacementRange: TextRange(start: triggerStart, end: caret),
      candidates: _targetCandidates(
        kind: kind,
        state: state,
        colors: const InlineAnnotationColorCode(
          background: "B",
          foreground: "0",
        ),
        query: query,
        loadTargets: loadTargets,
      ),
    );
  }

  List<MosaicCompletionCandidate> _targetCandidates({
    required InlineAnnotationKind kind,
    required InlineAnnotationState state,
    required InlineAnnotationColorCode colors,
    required String query,
    required MosaicTargetCandidateLoader loadTargets,
  }) {
    final candidates = <MosaicCompletionCandidate>[];
    final loadedTargets = loadTargets(kind);
    final nestedTargetIds = <String>{
      for (final target in loadedTargets)
        for (final child in target.children) child.id,
    };
    final visibleTargets =
        (query.isEmpty
                ? loadedTargets.where(
                    (target) => !nestedTargetIds.contains(target.id),
                  )
                : loadedTargets)
            .toList(growable: false);
    visibleTargets.sort((left, right) {
      final byName = left.primaryName.compareTo(right.primaryName);
      return byName != 0 ? byName : left.id.compareTo(right.id);
    });
    final targetsToBuild = query.isEmpty
        ? visibleTargets.take(maxCandidatesPerLevel - 1)
        : visibleTargets;
    for (final target in targetsToBuild) {
      final metadataMatches =
          query.isNotEmpty &&
          (target.id.toLowerCase().contains(query) ||
              (target.path?.toLowerCase().contains(query) ?? false));
      final primaryNameMatches = target.primaryName.toLowerCase().contains(
        query,
      );
      final primaryMatches =
          query.isEmpty || metadataMatches || primaryNameMatches;
      if (primaryMatches) {
        candidates.add(
          _targetCandidate(
            target: target,
            kind: kind,
            state: state,
            colors: colors,
            includeHierarchy: query.isEmpty,
          ),
        );
      }
      if (primaryMatches && kind == InlineAnnotationKind.character) continue;
      for (
        var aliasIndex = 0;
        aliasIndex < target.aliases.length;
        aliasIndex++
      ) {
        final alias = target.aliases[aliasIndex];
        if (query.isNotEmpty &&
            !metadataMatches &&
            !alias.toLowerCase().contains(query)) {
          continue;
        }
        candidates.add(
          MosaicCompletionCandidate(
            id: "${target.id}:alias:$aliasIndex",
            label: alias,
            detail: "${_kindLabel(kind)} · ${target.primaryName}的別名",
            insertText: InlineAnnotationSyntax.format(
              kind: kind,
              state: state,
              colors: colors,
              targetId: target.id,
              displayText: alias,
            ),
          ),
        );
      }
    }
    candidates.sort((left, right) => left.label.compareTo(right.label));
    if (query.isNotEmpty) {
      return List.unmodifiable(candidates.take(maxCandidatesPerLevel));
    }
    return List.unmodifiable([...candidates, _createCandidate(kind: kind)]);
  }

  MosaicCompletionCandidate _targetCandidate({
    required InlineAnnotationTargetInfo target,
    required InlineAnnotationKind kind,
    required InlineAnnotationState state,
    required InlineAnnotationColorCode colors,
    required bool includeHierarchy,
    int depth = 0,
  }) {
    final hasCreateAction =
        includeHierarchy &&
        (kind == InlineAnnotationKind.location ||
            (kind == InlineAnnotationKind.event && depth <= 1));
    final childLimit = maxCandidatesPerLevel - (hasCreateAction ? 1 : 0);
    final children = kind == InlineAnnotationKind.character
        ? target.aliases.isEmpty
              ? const <MosaicCompletionCandidate>[]
              : <MosaicCompletionCandidate>[
                  MosaicCompletionCandidate(
                    id: "${target.id}:primary",
                    label: target.primaryName,
                    detail: "人物 · 主名稱",
                    insertText: InlineAnnotationSyntax.format(
                      kind: kind,
                      state: state,
                      colors: colors,
                      targetId: target.id,
                      displayText: target.primaryName,
                    ),
                  ),
                  for (
                    var aliasIndex = 0;
                    aliasIndex < target.aliases.length &&
                        aliasIndex < maxCandidatesPerLevel - 1;
                    aliasIndex++
                  )
                    MosaicCompletionCandidate(
                      id: "${target.id}:alias:$aliasIndex",
                      label: target.aliases[aliasIndex],
                      detail: "人物 · ${target.primaryName}的別名",
                      insertText: InlineAnnotationSyntax.format(
                        kind: kind,
                        state: state,
                        colors: colors,
                        targetId: target.id,
                        displayText: target.aliases[aliasIndex],
                      ),
                    ),
                ]
        : includeHierarchy
        ? <MosaicCompletionCandidate>[
            for (final child in target.children.take(childLimit))
              _targetCandidate(
                target: child,
                kind: kind,
                state: state,
                colors: colors,
                includeHierarchy: true,
                depth: depth + 1,
              ),
          ]
        : const <MosaicCompletionCandidate>[];
    final hierarchicalChildren = <MosaicCompletionCandidate>[
      ...children,
      if (includeHierarchy && kind == InlineAnnotationKind.location)
        _createCandidate(
          kind: kind,
          parentId: target.id,
          depth: depth + 1,
          label: "新增子地點…",
        ),
      if (includeHierarchy && kind == InlineAnnotationKind.event && depth == 0)
        _createCandidate(
          kind: kind,
          parentId: target.id,
          depth: 1,
          label: "新增事件…",
        ),
      if (includeHierarchy && kind == InlineAnnotationKind.event && depth == 1)
        _createCandidate(
          kind: kind,
          parentId: target.id,
          depth: 2,
          label: "新增場景…",
        ),
    ];

    return MosaicCompletionCandidate(
      id: target.id,
      label: target.primaryName.isEmpty ? "（未命名）" : target.primaryName,
      detail: _targetDetail(target, kind, depth),
      insertText: InlineAnnotationSyntax.format(
        kind: kind,
        state: state,
        colors: colors,
        targetId: target.id,
        displayText: target.primaryName,
      ),
      children: hierarchicalChildren,
    );
  }

  String _targetDetail(
    InlineAnnotationTargetInfo target,
    InlineAnnotationKind kind,
    int depth,
  ) {
    final path = target.path?.isNotEmpty == true ? target.path! : target.id;
    if (kind != InlineAnnotationKind.event) {
      return "${_kindLabel(kind)} · $path";
    }
    final scope = switch (depth) {
      0 => "大箱",
      1 => "中箱",
      _ => "小箱",
    };
    return "${_kindLabel(kind)} · $scope · $path";
  }

  MosaicCompletionCandidate _createCandidate({
    required InlineAnnotationKind kind,
    String? parentId,
    int depth = 0,
    String? label,
  }) {
    return MosaicCompletionCandidate(
      id: parentId == null && depth == 0
          ? "create-${kind.name}"
          : "create-${kind.name}-$parentId-$depth",
      label: label ?? "新增${_kindLabel(kind)}…",
      detail: "建立後立即插入標記",
      insertText: "",
      createTargetKind: kind,
      createParentId: parentId,
      createDepth: depth,
    );
  }

  MosaicCompletionSession _directHighlightSession(int caret) {
    return MosaicCompletionSession(
      kind: MosaicCompletionKind.color,
      rawReplacementRange: TextRange(start: caret - 1, end: caret),
      candidates: [
        for (final background in _colorLabels.entries)
          MosaicCompletionCandidate(
            id: "highlight-${background.key}",
            label: "${background.key} · ${background.value}",
            detail: "高亮背景色 · 文字色自動",
            insertText: _highlightSkeleton(background.key, "0"),
            children: [
              for (final foreground in _colorLabels.entries)
                MosaicCompletionCandidate(
                  id: "highlight-${background.key}-foreground-${foreground.key}",
                  label: "${foreground.key} · ${foreground.value}",
                  detail: "高亮文字色 · 背景 ${background.value}",
                  insertText: _highlightSkeleton(
                    background.key,
                    foreground.key,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  MosaicCompletionSession? _colorSession(String draft, int caret) {
    final match = RegExp(r"^//(?:[@!#?&])?[+-]?\^([A-F0]?)$").firstMatch(draft);
    if (match == null) return null;
    final query = match.group(1) ?? "";
    return MosaicCompletionSession(
      kind: MosaicCompletionKind.color,
      rawReplacementRange: TextRange(start: caret - query.length, end: caret),
      candidates: [
        for (final background in _colorLabels.entries)
          if (query.isEmpty || background.key == query)
            MosaicCompletionCandidate(
              id: "color-${background.key}",
              label: "${background.key} · ${background.value}",
              detail: "標記背景色碼 · 文字色自動",
              insertText: background.key,
              children: [
                for (final foreground in _colorLabels.entries)
                  MosaicCompletionCandidate(
                    id: "color-${background.key}-foreground-${foreground.key}",
                    label: "${foreground.key} · ${foreground.value}",
                    detail: "標記文字色碼 · 背景 ${background.value}",
                    insertText: "${background.key}${foreground.key}",
                  ),
              ],
            ),
      ],
    );
  }

  String _highlightSkeleton(String background, String foreground) {
    final colorCode = foreground == "0"
        ? background == "B"
              ? ""
              : background
        : "$background$foreground";
    return "//^$colorCode<";
  }

  bool _hasOpenAnnotationDelimiter(String prefix) {
    var delimiterCount = 0;
    for (var index = 0; index + 1 < prefix.length; index++) {
      if (prefix.codeUnitAt(index) != 0x2f ||
          prefix.codeUnitAt(index + 1) != 0x2f) {
        continue;
      }
      var slashEscapes = 0;
      for (
        var before = index - 1;
        before >= 0 && prefix.codeUnitAt(before) == 0x5c;
        before--
      ) {
        slashEscapes++;
      }
      if (slashEscapes.isEven) {
        delimiterCount++;
        index++;
      }
    }
    return delimiterCount.isOdd;
  }

  InlineAnnotationKind _kind(String symbol) => switch (symbol) {
    "@" => InlineAnnotationKind.character,
    "!" => InlineAnnotationKind.location,
    "#" => InlineAnnotationKind.event,
    "?" => InlineAnnotationKind.foreshadowing,
    "&" => InlineAnnotationKind.plan,
    _ => throw StateError("Unsupported annotation kind: $symbol"),
  };

  String _kindLabel(InlineAnnotationKind kind) => switch (kind) {
    InlineAnnotationKind.character => "人物",
    InlineAnnotationKind.location => "地點",
    InlineAnnotationKind.event => "事件",
    InlineAnnotationKind.foreshadowing => "伏筆",
    InlineAnnotationKind.plan => "計畫",
    InlineAnnotationKind.emphasis => "高亮",
  };
}
