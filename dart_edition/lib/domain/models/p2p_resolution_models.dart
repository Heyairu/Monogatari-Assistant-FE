import "dart:convert";

import "p2p_revision_models.dart";

class P2pResolutionAck {
  static const int maxEncodedLength = 1024;
  static final RegExp _sha256Pattern = RegExp(r"^[0-9a-f]{64}$");
  static final RegExp _uuidPattern = RegExp(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
  );

  final String projectUuid;
  final String resolutionRevisionId;
  final String contentSha256;
  final String acceptedByDeviceId;
  final int acceptedAtEpochSeconds;

  P2pResolutionAck({
    required String projectUuid,
    required String resolutionRevisionId,
    required String contentSha256,
    required String acceptedByDeviceId,
    required this.acceptedAtEpochSeconds,
  }) : projectUuid = _normalizeUuid(projectUuid, "project UUID"),
       resolutionRevisionId = _normalizeHash(
         resolutionRevisionId,
         "resolution revision ID",
       ),
       contentSha256 = _normalizeHash(contentSha256, "content SHA-256"),
       acceptedByDeviceId = _normalizeUuid(
         acceptedByDeviceId,
         "accepted device ID",
       ) {
    if (acceptedAtEpochSeconds < 0) {
      throw const FormatException("P2P resolution ACK 時間無效。");
    }
  }

  factory P2pResolutionAck.fromJson(Map<String, Object?> json) {
    const expectedKeys = <String>{
      "projectUuid",
      "resolutionRevisionId",
      "contentSha256",
      "acceptedByDeviceId",
      "acceptedAt",
    };
    if (json.length != expectedKeys.length ||
        !json.keys.every(expectedKeys.contains)) {
      throw const FormatException("P2P resolution ACK 欄位集合無效。");
    }
    final projectUuid = json["projectUuid"];
    final resolutionRevisionId = json["resolutionRevisionId"];
    final contentSha256 = json["contentSha256"];
    final acceptedByDeviceId = json["acceptedByDeviceId"];
    final acceptedAt = json["acceptedAt"];
    if (projectUuid is! String ||
        resolutionRevisionId is! String ||
        contentSha256 is! String ||
        acceptedByDeviceId is! String ||
        acceptedAt is! int) {
      throw const FormatException("P2P resolution ACK 欄位不完整。");
    }
    final ack = P2pResolutionAck(
      projectUuid: projectUuid,
      resolutionRevisionId: resolutionRevisionId,
      contentSha256: contentSha256,
      acceptedByDeviceId: acceptedByDeviceId,
      acceptedAtEpochSeconds: acceptedAt,
    );
    if (jsonEncode(ack.toJson()).length > maxEncodedLength) {
      throw const FormatException("P2P resolution ACK 超過大小限制。");
    }
    return ack;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    "projectUuid": projectUuid,
    "resolutionRevisionId": resolutionRevisionId,
    "contentSha256": contentSha256,
    "acceptedByDeviceId": acceptedByDeviceId,
    "acceptedAt": acceptedAtEpochSeconds,
  };

  bool matchesRevision(P2pRevisionMetadata revision) {
    return revision.projectUuid == projectUuid &&
        revision.revisionId == resolutionRevisionId &&
        revision.contentSha256 == contentSha256 &&
        revision.parents.length >= 2;
  }

  static String _normalizeHash(String value, String label) {
    final normalized = value.trim().toLowerCase();
    if (!_sha256Pattern.hasMatch(normalized)) {
      throw FormatException("P2P $label 無效。");
    }
    return normalized;
  }

  static String _normalizeUuid(String value, String label) {
    final normalized = value.trim().toLowerCase();
    if (!_uuidPattern.hasMatch(normalized)) {
      throw FormatException("P2P $label 無效。");
    }
    return normalized;
  }
}
