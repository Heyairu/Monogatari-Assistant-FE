import "dart:convert";

final class ReadonlyPlanTarget {
  final String type;
  final String id;
  final String title;

  const ReadonlyPlanTarget({
    required this.type,
    required this.id,
    required this.title,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    "type": type,
    "id": id,
    "title": title,
  };
}

final class ReadonlyPlanContext {
  final String fingerprint;
  final Map<String, ReadonlyPlanTarget> _targets;

  ReadonlyPlanContext({
    required this.fingerprint,
    required Iterable<ReadonlyPlanTarget> targets,
  }) : _targets = Map<String, ReadonlyPlanTarget>.unmodifiable(
         <String, ReadonlyPlanTarget>{
           for (final target in targets) "${target.type}:${target.id}": target,
         },
       );

  ReadonlyPlanTarget? resolve(String type, String? id) =>
      id == null ? null : _targets["$type:$id"];
}

enum ReadonlyPlanErrorCode {
  malformedJson,
  resultTooLarge,
  invalidSchema,
  staleContext,
  invalidField,
  unsupportedTargetType,
  unsupportedAction,
  targetNotInContext,
  duplicateStep,
  unknownDependency,
  cyclicDependency,
}

final class ReadonlyPlanValidationError {
  final ReadonlyPlanErrorCode code;
  final String path;
  final String message;

  const ReadonlyPlanValidationError({
    required this.code,
    required this.path,
    required this.message,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    "code": code.name,
    "path": path,
    "message": message,
  };
}

final class ReadonlyPlanValidationResult {
  final bool valid;
  final bool stale;
  final Map<String, Object?>? canonicalPlan;
  final List<ReadonlyPlanValidationError> errors;
  final List<ReadonlyPlanTarget> resolvedTargets;

  const ReadonlyPlanValidationResult({
    required this.valid,
    required this.stale,
    required this.canonicalPlan,
    required this.errors,
    required this.resolvedTargets,
  });
}

abstract final class ReadonlyPlanValidator {
  static const int maxRawBytes = 128 * 1024;
  static const Set<String> allowedTargetTypes = <String>{
    "chapter",
    "character",
    "location",
    "worldSetting",
    "outlineEvent",
    "glossaryTerm",
    "foreshadow",
    "updatePlan",
    "project",
  };
  static const Set<String> allowedActions = <String>{
    "review",
    "revise",
    "add",
    "create",
    "removeSuggestion",
    "reorderSuggestion",
    "clarify",
    "research",
  };

  static ReadonlyPlanValidationResult validate(
    String source, {
    required ReadonlyPlanContext context,
  }) {
    try {
      final plan = _validate(source, context);
      return ReadonlyPlanValidationResult(
        valid: true,
        stale: false,
        canonicalPlan: plan.plan,
        errors: const <ReadonlyPlanValidationError>[],
        resolvedTargets: plan.targets,
      );
    } on _PlanFailure catch (failure) {
      return ReadonlyPlanValidationResult(
        valid: false,
        stale: failure.error.code == ReadonlyPlanErrorCode.staleContext,
        canonicalPlan: null,
        errors: <ReadonlyPlanValidationError>[failure.error],
        resolvedTargets: const <ReadonlyPlanTarget>[],
      );
    }
  }

  static Map<String, Object?> validateOrThrow(
    String source, {
    required ReadonlyPlanContext context,
  }) {
    final result = validate(source, context: context);
    if (!result.valid) throw FormatException(result.errors.single.message);
    return result.canonicalPlan!;
  }

  static ({Map<String, Object?> plan, List<ReadonlyPlanTarget> targets})
  _validate(String source, ReadonlyPlanContext context) {
    if (utf8.encode(source).length > maxRawBytes) {
      _fail(ReadonlyPlanErrorCode.resultTooLarge, r"$", "Plan JSON 超過大小上限。");
    }
    Object? decoded;
    try {
      decoded = jsonDecode(_stripSingleJsonFence(source));
    } on FormatException {
      _fail(
        ReadonlyPlanErrorCode.malformedJson,
        r"$",
        "Plan 必須是有效的 JSON object。",
      );
    }
    if (decoded is! Map<String, Object?>) {
      _fail(ReadonlyPlanErrorCode.malformedJson, r"$", "Plan 必須是 JSON object。");
    }
    _expectKeys(decoded, const <String>{
      "schemaVersion",
      "goal",
      "summary",
      "contextFingerprint",
      "steps",
      "risks",
      "questions",
    }, r"$");
    final schema = _string(decoded, "schemaVersion", 20);
    if (schema != "1") {
      _fail(
        ReadonlyPlanErrorCode.invalidSchema,
        r"$.schemaVersion",
        "不支援的 Plan schema：$schema。",
      );
    }
    final fingerprint = _string(decoded, "contextFingerprint", 256);
    if (fingerprint != context.fingerprint) {
      _fail(
        ReadonlyPlanErrorCode.staleContext,
        r"$.contextFingerprint",
        "Plan 使用的 context 已失效。",
      );
    }
    final rawSteps = decoded["steps"];
    if (rawSteps is! List<Object?> ||
        rawSteps.isEmpty ||
        rawSteps.length > 50) {
      _fail(
        ReadonlyPlanErrorCode.invalidField,
        r"$.steps",
        "Plan steps 必須包含 1～50 個步驟。",
      );
    }
    final ids = <String>{};
    final orders = <int>{};
    final dependencies = <String, Set<String>>{};
    final targets = <String, ReadonlyPlanTarget>{};
    final canonicalSteps = <Map<String, Object?>>[];
    for (var index = 0; index < rawSteps.length; index++) {
      final raw = rawSteps[index];
      final path = "\$.steps[$index]";
      if (raw is! Map<String, Object?>) {
        _fail(
          ReadonlyPlanErrorCode.invalidField,
          path,
          "每個 Plan step 必須是 JSON object。",
        );
      }
      _expectKeys(raw, const <String>{
        "id",
        "order",
        "targetType",
        "targetId",
        "action",
        "reason",
        "proposal",
        "dependsOn",
      }, path);
      final id = _string(raw, "id", 100, path: path);
      final order = raw["order"];
      if (order is! int || order < 1 || order > 1000) {
        _fail(
          ReadonlyPlanErrorCode.invalidField,
          "$path.order",
          "Plan step order 必須是 1～1000 的整數。",
        );
      }
      if (!ids.add(id) || !orders.add(order)) {
        _fail(
          ReadonlyPlanErrorCode.duplicateStep,
          path,
          "Plan step id 與 order 不可重複。",
        );
      }
      final targetType = _string(raw, "targetType", 100, path: path);
      final action = _string(raw, "action", 100, path: path);
      if (!allowedTargetTypes.contains(targetType)) {
        _fail(
          ReadonlyPlanErrorCode.unsupportedTargetType,
          "$path.targetType",
          "未知的 Plan targetType：$targetType。",
        );
      }
      if (!allowedActions.contains(action)) {
        _fail(
          ReadonlyPlanErrorCode.unsupportedAction,
          "$path.action",
          "未知的 Plan action：$action。",
        );
      }
      final rawTargetId = raw["targetId"];
      if (rawTargetId != null &&
          (rawTargetId is! String ||
              rawTargetId.trim().isEmpty ||
              rawTargetId.length > 200)) {
        _fail(
          ReadonlyPlanErrorCode.invalidField,
          "$path.targetId",
          "Plan targetId 必須是 null 或 1～200 字元的字串。",
        );
      }
      final targetId = rawTargetId == null
          ? null
          : (rawTargetId as String).trim();
      final resolved = context.resolve(targetType, targetId);
      if (action != "create" && resolved == null) {
        _fail(
          ReadonlyPlanErrorCode.targetNotInContext,
          "$path.targetId",
          "目前 context 不包含 $targetType 目標。",
        );
      }
      if (resolved != null) {
        targets["${resolved.type}:${resolved.id}"] = resolved;
      }
      final dependsOn = _strings(
        raw["dependsOn"],
        "$path.dependsOn",
        maxItems: 50,
      );
      dependencies[id] = dependsOn.toSet();
      canonicalSteps.add(<String, Object?>{
        "id": id,
        "order": order,
        "targetType": targetType,
        "targetId": targetId,
        "action": action,
        "reason": _string(raw, "reason", 4000, path: path),
        "proposal": _string(raw, "proposal", 12000, path: path),
        "dependsOn": dependsOn,
      });
    }
    for (final entry in dependencies.entries) {
      if (entry.value.any((id) => !ids.contains(id))) {
        _fail(
          ReadonlyPlanErrorCode.unknownDependency,
          r"$.steps",
          "Plan step 引用了未知相依步驟。",
        );
      }
    }
    final visiting = <String>{};
    final visited = <String>{};
    bool visit(String id) {
      if (visiting.contains(id)) return false;
      if (visited.contains(id)) return true;
      visiting.add(id);
      for (final dependency in dependencies[id]!) {
        if (!visit(dependency)) return false;
      }
      visiting.remove(id);
      visited.add(id);
      return true;
    }

    if (ids.any((id) => !visit(id))) {
      _fail(
        ReadonlyPlanErrorCode.cyclicDependency,
        r"$.steps",
        "Plan steps 不可包含循環相依。",
      );
    }
    canonicalSteps.sort(
      (a, b) => (a["order"]! as int).compareTo(b["order"]! as int),
    );
    return (
      plan: <String, Object?>{
        "schemaVersion": schema,
        "goal": _string(decoded, "goal", 500),
        "summary": _string(decoded, "summary", 4000),
        "contextFingerprint": fingerprint,
        "steps": canonicalSteps,
        "risks": _strings(decoded["risks"], r"$.risks"),
        "questions": _strings(decoded["questions"], r"$.questions"),
      },
      targets: targets.values.toList(growable: false),
    );
  }

  static void _expectKeys(
    Map<String, Object?> value,
    Set<String> allowed,
    String path,
  ) {
    final unknown = value.keys.where((key) => !allowed.contains(key)).toList();
    if (unknown.isNotEmpty) {
      _fail(
        ReadonlyPlanErrorCode.invalidField,
        path,
        "Plan 包含未預期欄位：${unknown.first}。",
      );
    }
  }

  static String _string(
    Map<String, Object?> value,
    String key,
    int maxLength, {
    String path = r"$",
  }) {
    final raw = value[key];
    if (raw is! String || raw.trim().isEmpty || raw.length > maxLength) {
      _fail(
        ReadonlyPlanErrorCode.invalidField,
        "$path.$key",
        "Plan.$key 必須是 1～$maxLength 字元的字串。",
      );
    }
    return raw.trim();
  }

  static List<String> _strings(
    Object? value,
    String path, {
    int maxItems = 20,
  }) {
    if (value is! List<Object?> || value.length > maxItems) {
      _fail(ReadonlyPlanErrorCode.invalidField, path, "Plan 字串陣列格式無效。");
    }
    final result = <String>[];
    for (final item in value) {
      if (item is! String || item.trim().isEmpty || item.length > 4000) {
        _fail(ReadonlyPlanErrorCode.invalidField, path, "Plan 字串陣列包含無效項目。");
      }
      result.add(item.trim());
    }
    return List<String>.unmodifiable(result);
  }

  static Never _fail(ReadonlyPlanErrorCode code, String path, String message) =>
      throw _PlanFailure(
        ReadonlyPlanValidationError(code: code, path: path, message: message),
      );

  static String _stripSingleJsonFence(String source) {
    final trimmed = source.trim();
    if (!trimmed.startsWith("```") || !trimmed.endsWith("```")) return trimmed;
    final newline = trimmed.indexOf("\n");
    if (newline < 0) return trimmed;
    final language = trimmed.substring(3, newline).trim().toLowerCase();
    if (language.isNotEmpty && language != "json") return trimmed;
    return trimmed.substring(newline + 1, trimmed.length - 3).trim();
  }
}

final class _PlanFailure implements Exception {
  final ReadonlyPlanValidationError error;
  const _PlanFailure(this.error);
}
