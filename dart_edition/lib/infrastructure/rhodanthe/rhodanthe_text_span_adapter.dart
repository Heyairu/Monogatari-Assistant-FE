import "package:flutter/material.dart";

import "rhodanthe_protocol.dart";
import "rhodanthe_theme.dart";

enum RhodantheSpanBuildStatus {
  applied,
  staleRevision,
  textLengthMismatch,
  invalidContract,
  invalidPlan,
  invalidThemeToken,
}

final class RhodantheSpanBuildFailure {
  final RhodantheSpanBuildStatus status;
  final String message;

  const RhodantheSpanBuildFailure({
    required this.status,
    required this.message,
  });
}

final class RhodantheSpanMetadata {
  final RhodantheRange range;
  final List<String> annotationIds;
  final String? interaction;

  const RhodantheSpanMetadata({
    required this.range,
    required this.annotationIds,
    required this.interaction,
  });
}

final class RhodantheSpanBuildResult {
  final RhodantheSpanBuildStatus status;
  final TextSpan span;
  final List<RhodantheSpanMetadata> metadata;
  final RhodantheSpanBuildFailure? failure;

  const RhodantheSpanBuildResult._({
    required this.status,
    required this.span,
    required this.metadata,
    required this.failure,
  });

  bool get applied => status == RhodantheSpanBuildStatus.applied;
}

final class RhodantheTextSpanAdapter {
  const RhodantheTextSpanAdapter();

  RhodantheSpanBuildResult build({
    required String text,
    required int currentRevision,
    required RhodantheVersionedRenderPlan renderPlan,
    required RhodantheTheme theme,
    TextStyle? baseStyle,
    TextRange composing = TextRange.empty,
    bool withComposing = true,
    TextStyle composingStyle = const TextStyle(
      decoration: TextDecoration.underline,
    ),
  }) {
    if (renderPlan.revision != currentRevision) {
      return _fallback(
        text,
        baseStyle,
        RhodantheSpanBuildStatus.staleRevision,
        "Render revision ${renderPlan.revision} does not match $currentRevision",
      );
    }
    final plan = renderPlan.plan;
    if (plan.contractVersion != rhodantheContractVersion) {
      return _fallback(
        text,
        baseStyle,
        RhodantheSpanBuildStatus.invalidContract,
        "Render contract ${plan.contractVersion} is unsupported",
      );
    }
    if (plan.textLenUtf16 != text.length) {
      return _fallback(
        text,
        baseStyle,
        RhodantheSpanBuildStatus.textLengthMismatch,
        "Render text length ${plan.textLenUtf16} does not match ${text.length}",
      );
    }

    try {
      final tokenStyles = <TextStyle>[
        for (var index = 0; index < plan.tokenSets.length; index++)
          _tokenStyle(plan.tokenSets[index], theme, index),
      ];
      _validateRuns(text, plan);
      final effectiveComposing = _effectiveComposing(
        text,
        composing,
        withComposing,
      );
      final span = _buildSpan(
        text: text,
        plan: plan,
        tokenStyles: tokenStyles,
        baseStyle: baseStyle,
        composing: effectiveComposing,
        composingStyle: composingStyle,
      );
      return RhodantheSpanBuildResult._(
        status: RhodantheSpanBuildStatus.applied,
        span: span,
        metadata: <RhodantheSpanMetadata>[
          for (final run in plan.runs)
            RhodantheSpanMetadata(
              range: run.range,
              annotationIds: List<String>.unmodifiable(run.annotationIds),
              interaction: plan.tokenSets[run.styleTokenSetId].interaction,
            ),
        ],
        failure: null,
      );
    } on _SpanAdapterException catch (error) {
      return _fallback(text, baseStyle, error.status, error.message);
    }
  }

  RhodantheSpanBuildResult _fallback(
    String text,
    TextStyle? baseStyle,
    RhodantheSpanBuildStatus status,
    String message,
  ) {
    return RhodantheSpanBuildResult._(
      status: status,
      span: TextSpan(text: text, style: baseStyle),
      metadata: const <RhodantheSpanMetadata>[],
      failure: RhodantheSpanBuildFailure(status: status, message: message),
    );
  }
}

void _validateRuns(String text, RhodantheRenderPlan plan) {
  var previousEnd = 0;
  for (var index = 0; index < plan.runs.length; index++) {
    final run = plan.runs[index];
    if (run.range.start < 0 ||
        run.range.end <= run.range.start ||
        run.range.end > text.length) {
      throw _SpanAdapterException(
        RhodantheSpanBuildStatus.invalidPlan,
        "Run $index has invalid range ${run.range.start}..${run.range.end}",
      );
    }
    if (run.range.start < previousEnd) {
      throw _SpanAdapterException(
        RhodantheSpanBuildStatus.invalidPlan,
        "Run $index overlaps or is not sorted",
      );
    }
    if (run.styleTokenSetId < 0 ||
        run.styleTokenSetId >= plan.tokenSets.length) {
      throw _SpanAdapterException(
        RhodantheSpanBuildStatus.invalidPlan,
        "Run $index references token set ${run.styleTokenSetId}",
      );
    }
    if (!_isUtf16Boundary(text, run.range.start) ||
        !_isUtf16Boundary(text, run.range.end)) {
      throw _SpanAdapterException(
        RhodantheSpanBuildStatus.invalidPlan,
        "Run $index splits a UTF-16 surrogate pair",
      );
    }
    previousEnd = run.range.end;
  }
}

TextStyle _tokenStyle(
  RhodantheStyleTokenSet tokenSet,
  RhodantheTheme theme,
  int index,
) {
  final foreground = _resolveColor(
    tokenSet.foreground,
    theme,
    "tokenSets[$index].foreground",
  );
  final background = _resolveColor(
    tokenSet.background,
    theme,
    "tokenSets[$index].background",
  );
  final weight = switch (tokenSet.weight) {
    null => null,
    "regular" => FontWeight.w400,
    "medium" => FontWeight.w500,
    "semibold" => FontWeight.w600,
    "bold" => FontWeight.w700,
    final value => throw _SpanAdapterException(
      RhodantheSpanBuildStatus.invalidPlan,
      "Unknown font weight $value",
    ),
  };
  final slant = switch (tokenSet.slant) {
    null => null,
    "normal" => FontStyle.normal,
    "italic" => FontStyle.italic,
    final value => throw _SpanAdapterException(
      RhodantheSpanBuildStatus.invalidPlan,
      "Unknown font slant $value",
    ),
  };
  final decoration = tokenSet.decoration;
  if (decoration == null) {
    return TextStyle(
      color: foreground,
      backgroundColor: background,
      fontWeight: weight,
      fontStyle: slant,
    );
  }
  if (decoration.lines.isEmpty) {
    throw _SpanAdapterException(
      RhodantheSpanBuildStatus.invalidPlan,
      "Decoration in token set $index has no lines",
    );
  }
  final lines = <TextDecoration>[
    for (final line in decoration.lines)
      switch (line) {
        "underline" => TextDecoration.underline,
        "overline" => TextDecoration.overline,
        "lineThrough" => TextDecoration.lineThrough,
        final value => throw _SpanAdapterException(
          RhodantheSpanBuildStatus.invalidPlan,
          "Unknown decoration line $value",
        ),
      },
  ];
  final decorationStyle = switch (decoration.style) {
    "solid" => TextDecorationStyle.solid,
    "double" => TextDecorationStyle.double,
    "dotted" => TextDecorationStyle.dotted,
    "dashed" => TextDecorationStyle.dashed,
    "wavy" => TextDecorationStyle.wavy,
    final value => throw _SpanAdapterException(
      RhodantheSpanBuildStatus.invalidPlan,
      "Unknown decoration style $value",
    ),
  };
  return TextStyle(
    color: foreground,
    backgroundColor: background,
    fontWeight: weight,
    fontStyle: slant,
    decoration: TextDecoration.combine(lines),
    decorationStyle: decorationStyle,
    decorationColor: _resolveColor(
      decoration.color,
      theme,
      "tokenSets[$index].decoration.color",
    ),
    decorationThickness: decoration.thickness.clamp(1.0, 3.0),
  );
}

Color? _resolveColor(String? token, RhodantheTheme theme, String field) {
  if (token == null) return null;
  final color = theme.resolveColor(token);
  if (color == null) {
    throw _SpanAdapterException(
      RhodantheSpanBuildStatus.invalidThemeToken,
      "$field references unknown semantic color $token",
    );
  }
  return color;
}

TextRange _effectiveComposing(
  String text,
  TextRange composing,
  bool withComposing,
) {
  if (!withComposing ||
      !composing.isValid ||
      composing.isCollapsed ||
      composing.start < 0 ||
      composing.end > text.length ||
      !_isUtf16Boundary(text, composing.start) ||
      !_isUtf16Boundary(text, composing.end)) {
    return TextRange.empty;
  }
  return composing;
}

TextSpan _buildSpan({
  required String text,
  required RhodantheRenderPlan plan,
  required List<TextStyle> tokenStyles,
  required TextStyle? baseStyle,
  required TextRange composing,
  required TextStyle composingStyle,
}) {
  if (text.isEmpty) return TextSpan(text: text, style: baseStyle);
  final boundaries = <int>{0, text.length};
  for (final run in plan.runs) {
    boundaries
      ..add(run.range.start)
      ..add(run.range.end);
  }
  if (!composing.isCollapsed) {
    boundaries
      ..add(composing.start)
      ..add(composing.end);
  }
  final sorted = boundaries.toList()..sort();
  final children = <InlineSpan>[];
  var runIndex = 0;
  for (var index = 0; index < sorted.length - 1; index++) {
    final start = sorted[index];
    final end = sorted[index + 1];
    if (end <= start) continue;
    while (runIndex < plan.runs.length &&
        plan.runs[runIndex].range.end <= start) {
      runIndex++;
    }
    TextStyle? style;
    String? semanticsIdentifier;
    if (runIndex < plan.runs.length) {
      final run = plan.runs[runIndex];
      if (run.range.start <= start && end <= run.range.end) {
        style = tokenStyles[run.styleTokenSetId];
        semanticsIdentifier = plan.tokenSets[run.styleTokenSetId].interaction;
      }
    }
    if (!composing.isCollapsed &&
        composing.start <= start &&
        end <= composing.end) {
      style = _mergeComposing(style, composingStyle);
    }
    children.add(
      TextSpan(
        text: text.substring(start, end),
        style: style,
        semanticsIdentifier: semanticsIdentifier,
      ),
    );
  }
  return TextSpan(style: baseStyle, children: children);
}

TextStyle _mergeComposing(TextStyle? style, TextStyle composingStyle) {
  final base = style ?? const TextStyle();
  final merged = base.merge(composingStyle);
  final baseDecoration = base.decoration;
  final composingDecoration = composingStyle.decoration;
  if (baseDecoration == null || composingDecoration == null) return merged;
  return merged.copyWith(
    decoration: TextDecoration.combine(<TextDecoration>[
      baseDecoration,
      composingDecoration,
    ]),
  );
}

bool _isUtf16Boundary(String text, int offset) {
  if (offset <= 0 || offset >= text.length) return true;
  final previous = text.codeUnitAt(offset - 1);
  final next = text.codeUnitAt(offset);
  final previousIsHighSurrogate = previous >= 0xD800 && previous <= 0xDBFF;
  final nextIsLowSurrogate = next >= 0xDC00 && next <= 0xDFFF;
  return !(previousIsHighSurrogate && nextIsLowSurrogate);
}

final class _SpanAdapterException implements Exception {
  final RhodantheSpanBuildStatus status;
  final String message;

  const _SpanAdapterException(this.status, this.message);
}
