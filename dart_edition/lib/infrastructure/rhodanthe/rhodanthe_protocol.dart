import "dart:convert";

const int rhodantheContractVersion = 1;
const int rhodantheAbiVersion = 1;

final class RhodantheCapabilities {
  final int abiVersion;
  final int contractVersion;
  final Set<String> values;

  RhodantheCapabilities({
    required this.abiVersion,
    required this.contractVersion,
    required Iterable<String> values,
  }) : values = Set<String>.unmodifiable(values);

  factory RhodantheCapabilities.fromResponse(RhodantheResponse response) {
    final result = response.requireResult();
    if (_string(result["kind"], "result.kind") != "handshake") {
      throw const FormatException("Rhodanthe result is not a handshake");
    }
    return RhodantheCapabilities(
      abiVersion: _int(result["abiVersion"], "result.abiVersion"),
      contractVersion: _int(
        result["contractVersion"],
        "result.contractVersion",
      ),
      values: _stringList(result["capabilities"], "result.capabilities"),
    );
  }

  bool supportsAll(Iterable<String> required) =>
      required.every(values.contains);

  bool get isVersionCompatible =>
      abiVersion == rhodantheAbiVersion &&
      contractVersion == rhodantheContractVersion;
}

final class RhodantheTextEdit {
  final int startUtf16;
  final int endUtf16;
  final String replacement;

  const RhodantheTextEdit({
    required this.startUtf16,
    required this.endUtf16,
    required this.replacement,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    "startUtf16": startUtf16,
    "endUtf16": endUtf16,
    "replacement": replacement,
  };
}

final class RhodantheSearchOptions {
  final bool matchCase;
  final bool wholeWord;
  final bool useRegexp;
  final bool matchWidth;
  final bool ignorePunctuation;
  final bool ignoreWhitespace;

  const RhodantheSearchOptions({
    this.matchCase = true,
    this.wholeWord = false,
    this.useRegexp = false,
    this.matchWidth = true,
    this.ignorePunctuation = false,
    this.ignoreWhitespace = false,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    "matchCase": matchCase,
    "wholeWord": wholeWord,
    "useRegexp": useRegexp,
    "matchWidth": matchWidth,
    "ignorePunctuation": ignorePunctuation,
    "ignoreWhitespace": ignoreWhitespace,
  };
}

final class RhodantheSearchRequest {
  final String query;
  final int queryRevision;
  final RhodantheSearchOptions options;
  final int? maxResults;
  final int? activeMatchIndex;
  final int? maxInputCodeUnits;
  final int? maxRegexpCodeUnits;

  const RhodantheSearchRequest({
    required this.query,
    required this.queryRevision,
    this.options = const RhodantheSearchOptions(),
    this.maxResults,
    this.activeMatchIndex,
    this.maxInputCodeUnits,
    this.maxRegexpCodeUnits,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    "query": query,
    "queryRevision": queryRevision,
    "options": options.toJson(),
    if (maxResults != null) "maxResults": maxResults,
    if (activeMatchIndex != null) "activeMatchIndex": activeMatchIndex,
    if (maxInputCodeUnits != null) "maxInputCodeUnits": maxInputCodeUnits,
    if (maxRegexpCodeUnits != null) "maxRegexpCodeUnits": maxRegexpCodeUnits,
  };
}

final class RhodantheFillerBudget {
  final int? maxWords;
  final int? maxPositionsPerWord;
  final int? maxPositionsTotal;
  final int? maxAnnotations;
  final int? maxCandidates;

  const RhodantheFillerBudget({
    this.maxWords,
    this.maxPositionsPerWord,
    this.maxPositionsTotal,
    this.maxAnnotations,
    this.maxCandidates,
  });

  bool get isEmpty =>
      maxWords == null &&
      maxPositionsPerWord == null &&
      maxPositionsTotal == null &&
      maxAnnotations == null &&
      maxCandidates == null;

  Map<String, Object?> toJson() => <String, Object?>{
    if (maxWords != null) "maxWords": maxWords,
    if (maxPositionsPerWord != null) "maxPositionsPerWord": maxPositionsPerWord,
    if (maxPositionsTotal != null) "maxPositionsTotal": maxPositionsTotal,
    if (maxAnnotations != null) "maxAnnotations": maxAnnotations,
    if (maxCandidates != null) "maxCandidates": maxCandidates,
  };
}

final class RhodantheFillerRequest {
  final int dictionaryRevision;
  final List<String> words;
  final RhodantheFillerBudget budget;

  const RhodantheFillerRequest({
    required this.dictionaryRevision,
    required this.words,
    this.budget = const RhodantheFillerBudget(),
  });

  Map<String, Object?> toJson() => <String, Object?>{
    "dictionaryRevision": dictionaryRevision,
    "words": words,
    if (!budget.isEmpty) "budget": budget.toJson(),
  };
}

final class RhodantheRequest {
  final int contractVersion = rhodantheContractVersion;
  final int? requestId;
  final String command;
  final Map<String, Object?>? arguments;

  const RhodantheRequest._({
    required this.requestId,
    required this.command,
    required this.arguments,
  });

  factory RhodantheRequest.handshake({int? requestId}) => RhodantheRequest._(
    requestId: requestId,
    command: "handshake",
    arguments: null,
  );

  factory RhodantheRequest.openDocument({
    required String documentId,
    required int revision,
    required String fullText,
    int? requestId,
  }) => RhodantheRequest._(
    requestId: requestId,
    command: "openDocument",
    arguments: <String, Object?>{
      "documentId": documentId,
      "revision": revision,
      "fullText": fullText,
    },
  );

  factory RhodantheRequest.applyEdits({
    required String documentId,
    required int baseRevision,
    required int revision,
    required List<RhodantheTextEdit> edits,
    int? requestId,
  }) => RhodantheRequest._(
    requestId: requestId,
    command: "applyEdits",
    arguments: <String, Object?>{
      "documentId": documentId,
      "baseRevision": baseRevision,
      "revision": revision,
      "edits": edits.map((edit) => edit.toJson()).toList(growable: false),
    },
  );

  factory RhodantheRequest.analyze({
    required String documentId,
    required int revision,
    bool compactResponse = true,
    RhodantheSearchRequest? search,
    RhodantheFillerRequest? filler,
    List<RhodantheExternalAnnotation> externalAnnotations =
        const <RhodantheExternalAnnotation>[],
    int? requestId,
  }) => RhodantheRequest._(
    requestId: requestId,
    command: "analyze",
    arguments: <String, Object?>{
      "documentId": documentId,
      "revision": revision,
      "compactResponse": compactResponse,
      if (search != null) "search": search.toJson(),
      if (filler != null) "filler": filler.toJson(),
      if (externalAnnotations.isNotEmpty)
        "externalAnnotations": externalAnnotations
            .map((annotation) => annotation.toJson())
            .toList(growable: false),
    },
  );

  factory RhodantheRequest.closeDocument({
    required String documentId,
    int? requestId,
  }) => RhodantheRequest._(
    requestId: requestId,
    command: "closeDocument",
    arguments: <String, Object?>{"documentId": documentId},
  );

  Map<String, Object?> toJson() => <String, Object?>{
    "contractVersion": contractVersion,
    if (requestId != null) "requestId": requestId,
    "command": command,
    if (arguments != null) "arguments": arguments,
  };

  String encode() => jsonEncode(toJson());
}

final class RhodantheFailure implements Exception {
  final String code;
  final String message;

  const RhodantheFailure({required this.code, required this.message});

  @override
  String toString() => "RhodantheFailure($code): $message";
}

final class RhodantheResponse {
  final bool ok;
  final int contractVersion;
  final int? requestId;
  final Map<String, Object?>? result;
  final RhodantheFailure? error;

  const RhodantheResponse._({
    required this.ok,
    required this.contractVersion,
    required this.requestId,
    required this.result,
    required this.error,
  });

  factory RhodantheResponse.decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException("Rhodanthe response is not valid JSON: $error");
    }
    return RhodantheResponse.fromJson(_objectMap(decoded, "response"));
  }

  factory RhodantheResponse.fromJson(Map<String, Object?> json) {
    final ok = _bool(json["ok"], "ok");
    final contractVersion = _int(json["contractVersion"], "contractVersion");
    final requestId = _nullableInt(json["requestId"], "requestId");
    if (ok) {
      return RhodantheResponse._(
        ok: true,
        contractVersion: contractVersion,
        requestId: requestId,
        result: _objectMap(json["result"], "result"),
        error: null,
      );
    }
    final error = _objectMap(json["error"], "error");
    return RhodantheResponse._(
      ok: false,
      contractVersion: contractVersion,
      requestId: requestId,
      result: null,
      error: RhodantheFailure(
        code: _string(error["code"], "error.code"),
        message: _string(error["message"], "error.message"),
      ),
    );
  }

  Map<String, Object?> requireResult() {
    if (!ok) throw error!;
    if (contractVersion != rhodantheContractVersion) {
      throw RhodantheFailure(
        code: "incompatibleContract",
        message:
            "Response contract $contractVersion does not match "
            "$rhodantheContractVersion",
      );
    }
    return result!;
  }
}

final class RhodantheRange {
  final int start;
  final int end;

  const RhodantheRange(this.start, this.end);

  Map<String, Object?> toJson() => <String, Object?>{
    "start": start,
    "end": end,
  };

  factory RhodantheRange.fromJson(Object? value, String field) {
    final json = _objectMap(value, field);
    return RhodantheRange(
      _int(json["start"], "$field.start"),
      _int(json["end"], "$field.end"),
    );
  }
}

final class RhodantheDecoration {
  final List<String> lines;
  final String style;
  final String color;
  final double thickness;

  const RhodantheDecoration({
    required this.lines,
    required this.style,
    required this.color,
    required this.thickness,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    "lines": lines,
    "style": style,
    "color": color,
    "thickness": thickness,
  };

  factory RhodantheDecoration.fromJson(Object? value, String field) {
    final json = _objectMap(value, field);
    return RhodantheDecoration(
      lines: _stringList(json["lines"], "$field.lines"),
      style: _string(json["style"], "$field.style"),
      color: _string(json["color"], "$field.color"),
      thickness: _number(json["thickness"], "$field.thickness"),
    );
  }
}

final class RhodantheStyleTokenSet {
  final String? foreground;
  final String? background;
  final String? weight;
  final String? slant;
  final RhodantheDecoration? decoration;
  final String? interaction;

  const RhodantheStyleTokenSet({
    this.foreground,
    this.background,
    this.weight,
    this.slant,
    this.decoration,
    this.interaction,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    "foreground": foreground,
    "background": background,
    "weight": weight,
    "slant": slant,
    "decoration": decoration?.toJson(),
    "interaction": interaction,
  };

  factory RhodantheStyleTokenSet.fromJson(Object? value, String field) {
    final json = _objectMap(value, field);
    return RhodantheStyleTokenSet(
      foreground: _nullableString(json["foreground"], "$field.foreground"),
      background: _nullableString(json["background"], "$field.background"),
      weight: _nullableString(json["weight"], "$field.weight"),
      slant: _nullableString(json["slant"], "$field.slant"),
      decoration: json["decoration"] == null
          ? null
          : RhodantheDecoration.fromJson(
              json["decoration"],
              "$field.decoration",
            ),
      interaction: _nullableString(json["interaction"], "$field.interaction"),
    );
  }
}

final class RhodantheExternalAnnotation {
  final String annotationId;
  final String source;
  final int sourceOrder;
  final int ring;
  final RhodantheRange range;
  final RhodantheStyleTokenSet style;
  final String? payloadId;

  const RhodantheExternalAnnotation({
    required this.annotationId,
    required this.source,
    required this.sourceOrder,
    required this.ring,
    required this.range,
    required this.style,
    this.payloadId,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    "annotationId": annotationId,
    "source": source,
    "sourceOrder": sourceOrder,
    "ring": ring,
    "range": range.toJson(),
    "style": style.toJson(),
    "payloadId": payloadId,
  };
}

final class RhodantheRenderRun {
  final RhodantheRange range;
  final int styleTokenSetId;
  final List<String> annotationIds;

  const RhodantheRenderRun({
    required this.range,
    required this.styleTokenSetId,
    required this.annotationIds,
  });

  factory RhodantheRenderRun.fromJson(Object? value, String field) {
    final json = _objectMap(value, field);
    return RhodantheRenderRun(
      range: RhodantheRange.fromJson(json["range"], "$field.range"),
      styleTokenSetId: _int(json["styleTokenSetId"], "$field.styleTokenSetId"),
      annotationIds: _stringList(json["annotationIds"], "$field.annotationIds"),
    );
  }
}

final class RhodantheRenderPlan {
  final int contractVersion;
  final int textLenUtf16;
  final List<RhodantheRenderRun> runs;
  final List<RhodantheStyleTokenSet> tokenSets;

  const RhodantheRenderPlan({
    required this.contractVersion,
    required this.textLenUtf16,
    required this.runs,
    required this.tokenSets,
  });

  factory RhodantheRenderPlan.fromJson(Object? value, String field) {
    final json = _objectMap(value, field);
    final tokenSets = _list(json["tokenSets"], "$field.tokenSets");
    final compactRuns = json["runsUtf16"];
    final runs = compactRuns == null
        ? _decodeRenderRuns(json["runs"], "$field.runs")
        : _decodeCompactRenderRuns(compactRuns, "$field.runsUtf16");
    return RhodantheRenderPlan(
      contractVersion: _int(json["contractVersion"], "$field.contractVersion"),
      textLenUtf16: _int(json["textLenUtf16"], "$field.textLenUtf16"),
      runs: runs,
      tokenSets: <RhodantheStyleTokenSet>[
        for (var index = 0; index < tokenSets.length; index++)
          RhodantheStyleTokenSet.fromJson(
            tokenSets[index],
            "$field.tokenSets[$index]",
          ),
      ],
    );
  }
}

final class RhodantheVersionedRenderPlan {
  final String documentId;
  final int revision;
  final RhodantheRenderPlan plan;

  const RhodantheVersionedRenderPlan({
    required this.documentId,
    required this.revision,
    required this.plan,
  });

  factory RhodantheVersionedRenderPlan.fromJson(Object? value, String field) {
    final json = _objectMap(value, field);
    return RhodantheVersionedRenderPlan(
      documentId: _string(json["documentId"], "$field.documentId"),
      revision: _int(json["revision"], "$field.revision"),
      plan: RhodantheRenderPlan.fromJson(json["plan"], "$field.plan"),
    );
  }
}

final class RhodantheAnalysisResult {
  final Map<String, Object?>? search;
  final Map<String, Object?>? filler;
  final RhodantheVersionedRenderPlan renderPlan;

  const RhodantheAnalysisResult({
    required this.search,
    required this.filler,
    required this.renderPlan,
  });

  List<RhodantheRange> get searchRanges {
    final search = this.search;
    if (search == null) return const <RhodantheRange>[];
    final compactRanges = search["rangesUtf16"];
    if (compactRanges != null) {
      final values = _intList(compactRanges, "result.search.rangesUtf16");
      if (values.length.isOdd) {
        throw const FormatException(
          "result.search.rangesUtf16 must contain start/end pairs",
        );
      }
      return <RhodantheRange>[
        for (var index = 0; index < values.length; index += 2)
          RhodantheRange(values[index], values[index + 1]),
      ];
    }
    final annotations = _list(
      search["annotations"],
      "result.search.annotations",
    );
    return <RhodantheRange>[
      for (var index = 0; index < annotations.length; index++)
        RhodantheRange.fromJson(
          _objectMap(
            annotations[index],
            "result.search.annotations[$index]",
          )["range"],
          "result.search.annotations[$index].range",
        ),
    ];
  }

  factory RhodantheAnalysisResult.fromResponse(RhodantheResponse response) {
    final result = response.requireResult();
    if (_string(result["kind"], "result.kind") != "analysis") {
      throw const FormatException("Rhodanthe result is not an analysis");
    }
    return RhodantheAnalysisResult(
      search: result["search"] == null
          ? null
          : _objectMap(result["search"], "result.search"),
      filler: result["filler"] == null
          ? null
          : _objectMap(result["filler"], "result.filler"),
      renderPlan: RhodantheVersionedRenderPlan.fromJson(
        result["renderPlan"],
        "result.renderPlan",
      ),
    );
  }
}

List<RhodantheRenderRun> _decodeRenderRuns(Object? value, String field) {
  final runs = _list(value, field);
  return <RhodantheRenderRun>[
    for (var index = 0; index < runs.length; index++)
      RhodantheRenderRun.fromJson(runs[index], "$field[$index]"),
  ];
}

List<RhodantheRenderRun> _decodeCompactRenderRuns(Object? value, String field) {
  final values = _intList(value, field);
  if (values.length % 3 != 0) {
    throw FormatException("$field must contain start/end/token triples");
  }
  return <RhodantheRenderRun>[
    for (var index = 0; index < values.length; index += 3)
      RhodantheRenderRun(
        range: RhodantheRange(values[index], values[index + 1]),
        styleTokenSetId: values[index + 2],
        annotationIds: const <String>[],
      ),
  ];
}

Map<String, Object?> _objectMap(Object? value, String field) {
  if (value is! Map) throw FormatException("$field must be an object");
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException("$field contains a non-string key");
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

List<Object?> _list(Object? value, String field) {
  if (value is! List) throw FormatException("$field must be a list");
  return value.cast<Object?>();
}

List<String> _stringList(Object? value, String field) {
  final values = _list(value, field);
  return <String>[
    for (var index = 0; index < values.length; index++)
      _string(values[index], "$field[$index]"),
  ];
}

List<int> _intList(Object? value, String field) {
  final values = _list(value, field);
  return <int>[
    for (var index = 0; index < values.length; index++)
      _int(values[index], "$field[$index]"),
  ];
}

String _string(Object? value, String field) {
  if (value is! String) throw FormatException("$field must be a string");
  return value;
}

String? _nullableString(Object? value, String field) {
  if (value == null) return null;
  return _string(value, field);
}

int _int(Object? value, String field) {
  if (value is! int) throw FormatException("$field must be an integer");
  return value;
}

int? _nullableInt(Object? value, String field) {
  if (value == null) return null;
  return _int(value, field);
}

bool _bool(Object? value, String field) {
  if (value is! bool) throw FormatException("$field must be a boolean");
  return value;
}

double _number(Object? value, String field) {
  if (value is! num) throw FormatException("$field must be a number");
  return value.toDouble();
}
