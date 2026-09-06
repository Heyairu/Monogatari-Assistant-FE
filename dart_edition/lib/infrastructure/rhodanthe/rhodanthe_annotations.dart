import "dart:convert";

import "rhodanthe_protocol.dart";

enum RhodantheMentionResolution { resolved, unresolved }

enum RhodantheMentionAnchorPolicy { expand, shrink, detach }

final class RhodantheMention {
  final String mentionId;
  final String targetId;
  final RhodantheRange range;
  final RhodantheMentionResolution resolution;
  final RhodantheMentionAnchorPolicy anchorPolicy;

  const RhodantheMention({
    required this.mentionId,
    required this.targetId,
    required this.range,
    this.resolution = RhodantheMentionResolution.resolved,
    this.anchorPolicy = RhodantheMentionAnchorPolicy.detach,
  });

  RhodantheExternalAnnotation toAnnotation({required int sourceOrder}) {
    final resolved = resolution == RhodantheMentionResolution.resolved;
    final color = resolved
        ? "mention.resolved.foreground"
        : "mention.unresolved.foreground";
    final decoration = resolved
        ? "mention.resolved.decoration"
        : "mention.unresolved.decoration";
    return RhodantheExternalAnnotation(
      annotationId: "mention:$mentionId",
      source: "mention",
      sourceOrder: sourceOrder,
      ring: 4,
      range: range,
      style: RhodantheStyleTokenSet(
        foreground: color,
        weight: "medium",
        decoration: RhodantheDecoration(
          lines: const <String>["underline"],
          style: resolved ? "solid" : "dashed",
          color: decoration,
          thickness: resolved ? 1 : 2,
        ),
        interaction: "mention:$mentionId",
      ),
      payloadId: targetId,
    );
  }

  /// Rebases this anchor over one edit expressed in the previous revision.
  /// Returns `null` when policy detaches the mention or no text survives.
  RhodantheMention? rebase(RhodantheTextEdit edit) {
    final editStart = edit.startUtf16;
    final editEnd = edit.endUtf16;
    final delta = edit.replacement.length - (editEnd - editStart);
    if (editEnd <= range.start) {
      return copyWith(
        range: RhodantheRange(range.start + delta, range.end + delta),
      );
    }
    if (editStart >= range.end) return this;

    return switch (anchorPolicy) {
      RhodantheMentionAnchorPolicy.detach => null,
      RhodantheMentionAnchorPolicy.expand => copyWith(
        range: RhodantheRange(
          _mapOffset(range.start, edit, trailing: false),
          _mapOffset(range.end, edit, trailing: true),
        ),
      ),
      RhodantheMentionAnchorPolicy.shrink => _shrinkOverEdit(edit, delta),
    };
  }

  RhodantheMention? _shrinkOverEdit(RhodantheTextEdit edit, int delta) {
    final leftEnd = edit.startUtf16.clamp(range.start, range.end);
    final rightStart = edit.endUtf16.clamp(range.start, range.end);
    final leftLength = leftEnd - range.start;
    final rightLength = range.end - rightStart;
    if (leftLength <= 0 && rightLength <= 0) return null;
    if (leftLength >= rightLength) {
      return copyWith(range: RhodantheRange(range.start, leftEnd));
    }
    return copyWith(
      range: RhodantheRange(rightStart + delta, range.end + delta),
    );
  }

  RhodantheMention copyWith({
    RhodantheRange? range,
    RhodantheMentionResolution? resolution,
    RhodantheMentionAnchorPolicy? anchorPolicy,
  }) {
    return RhodantheMention(
      mentionId: mentionId,
      targetId: targetId,
      range: range ?? this.range,
      resolution: resolution ?? this.resolution,
      anchorPolicy: anchorPolicy ?? this.anchorPolicy,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    "mentionId": mentionId,
    "targetId": targetId,
    "range": range.toJson(),
    "resolution": resolution.name,
    "anchorPolicy": anchorPolicy.name,
  };

  factory RhodantheMention.fromJson(Map<String, Object?> json) {
    final rawRange = json["range"];
    if (rawRange is! Map) {
      throw const FormatException("mention.range must be an object");
    }
    final range = Map<String, Object?>.from(rawRange);
    return RhodantheMention(
      mentionId: _requiredString(json, "mentionId"),
      targetId: _requiredString(json, "targetId"),
      range: RhodantheRange(
        _requiredInt(range, "start"),
        _requiredInt(range, "end"),
      ),
      resolution: RhodantheMentionResolution.values.byName(
        _requiredString(json, "resolution"),
      ),
      anchorPolicy: RhodantheMentionAnchorPolicy.values.byName(
        _requiredString(json, "anchorPolicy"),
      ),
    );
  }
}

final class RhodantheMentionDocument {
  final String documentId;
  final List<RhodantheMention> mentions;

  RhodantheMentionDocument({
    required this.documentId,
    required List<RhodantheMention> mentions,
  }) : mentions = List<RhodantheMention>.unmodifiable(mentions);

  String encode() => jsonEncode(<String, Object?>{
    "version": 1,
    "documentId": documentId,
    "mentions": mentions.map((mention) => mention.toJson()).toList(),
  });

  factory RhodantheMentionDocument.decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException("mention document must be an object");
    }
    final json = Map<String, Object?>.from(decoded);
    if (json["version"] != 1) {
      throw FormatException("unsupported mention version ${json['version']}");
    }
    final rawMentions = json["mentions"];
    if (rawMentions is! List) {
      throw const FormatException("mentions must be a list");
    }
    return RhodantheMentionDocument(
      documentId: _requiredString(json, "documentId"),
      mentions: <RhodantheMention>[
        for (final rawMention in rawMentions)
          if (rawMention is Map)
            RhodantheMention.fromJson(Map<String, Object?>.from(rawMention))
          else
            throw const FormatException("mention must be an object"),
      ],
    );
  }

  List<RhodantheExternalAnnotation> toAnnotations() =>
      <RhodantheExternalAnnotation>[
        for (var index = 0; index < mentions.length; index++)
          mentions[index].toAnnotation(sourceOrder: index),
      ];
}

final class RhodantheDiagnostic {
  final String diagnosticId;
  final RhodantheRange range;
  final String? payloadId;

  const RhodantheDiagnostic({
    required this.diagnosticId,
    required this.range,
    this.payloadId,
  });

  RhodantheExternalAnnotation toAnnotation({required int sourceOrder}) {
    return RhodantheExternalAnnotation(
      annotationId: "diagnostic:$diagnosticId",
      source: "diagnostic",
      sourceOrder: sourceOrder,
      ring: 8,
      range: range,
      style: const RhodantheStyleTokenSet(
        decoration: RhodantheDecoration(
          lines: <String>["underline"],
          style: "dotted",
          color: "diagnostic.decoration",
          thickness: 1,
        ),
      ),
      payloadId: payloadId,
    );
  }
}

int _mapOffset(int offset, RhodantheTextEdit edit, {required bool trailing}) {
  if (offset <= edit.startUtf16) return offset;
  if (offset >= edit.endUtf16) {
    return offset + edit.replacement.length - (edit.endUtf16 - edit.startUtf16);
  }
  return trailing ? edit.startUtf16 + edit.replacement.length : edit.startUtf16;
}

String _requiredString(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! String || value.isEmpty) {
    throw FormatException("$field must be a non-empty string");
  }
  return value;
}

int _requiredInt(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! int) throw FormatException("$field must be an integer");
  return value;
}
