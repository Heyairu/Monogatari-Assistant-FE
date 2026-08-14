import "dart:convert";

import "p2p_sync_models.dart";

enum P2pSnapshotManifestStatus {
  inactive,
  requesting,
  available,
  unavailable,
  error,
}

/// A one-shot request asking the peer that is behind to pull this snapshot.
///
/// The request contains no project content and is only valid when carried by
/// the authenticated encrypted channel alongside the matching revision
/// summary and manifest.
class P2pSnapshotSyncRequest {
  static const int maxEncodedLength = 512;
  static final RegExp _requestIdPattern = RegExp(r"^[A-Za-z0-9_-]{16,64}$");
  static final RegExp _sha256Pattern = RegExp(r"^[0-9a-f]{64}$");

  final String requestId;
  final String projectUuid;
  final String revisionId;
  final String contentSha256;

  factory P2pSnapshotSyncRequest({
    required String requestId,
    required String projectUuid,
    required String revisionId,
    required String contentSha256,
  }) {
    final normalizedRequestId = requestId.trim();
    final normalizedProjectUuid = projectUuid.trim().toLowerCase();
    final normalizedRevisionId = revisionId.trim().toLowerCase();
    final normalizedContentSha256 = contentSha256.trim().toLowerCase();
    if (!_requestIdPattern.hasMatch(normalizedRequestId) ||
        !P2pProjectStatus.isValidProjectUuid(normalizedProjectUuid) ||
        !_sha256Pattern.hasMatch(normalizedRevisionId) ||
        !_sha256Pattern.hasMatch(normalizedContentSha256)) {
      throw const FormatException("P2P snapshot 同步要求無效。");
    }
    return P2pSnapshotSyncRequest._(
      requestId: normalizedRequestId,
      projectUuid: normalizedProjectUuid,
      revisionId: normalizedRevisionId,
      contentSha256: normalizedContentSha256,
    );
  }

  const P2pSnapshotSyncRequest._({
    required this.requestId,
    required this.projectUuid,
    required this.revisionId,
    required this.contentSha256,
  });

  factory P2pSnapshotSyncRequest.fromJson(Map<String, Object?> json) {
    const expectedKeys = <String>{
      "requestId",
      "projectUuid",
      "revisionId",
      "contentSha256",
    };
    if (json.length != expectedKeys.length ||
        !json.keys.every(expectedKeys.contains)) {
      throw const FormatException("P2P snapshot 同步要求欄位集合無效。");
    }
    final requestId = json["requestId"];
    final projectUuid = json["projectUuid"];
    final revisionId = json["revisionId"];
    final contentSha256 = json["contentSha256"];
    if (requestId is! String ||
        projectUuid is! String ||
        revisionId is! String ||
        contentSha256 is! String) {
      throw const FormatException("P2P snapshot 同步要求欄位不完整。");
    }
    final request = P2pSnapshotSyncRequest(
      requestId: requestId,
      projectUuid: projectUuid,
      revisionId: revisionId,
      contentSha256: contentSha256,
    );
    if (jsonEncode(request.toJson()).length > maxEncodedLength) {
      throw const FormatException("P2P snapshot 同步要求超過大小限制。");
    }
    return request;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    "requestId": requestId,
    "projectUuid": projectUuid,
    "revisionId": revisionId,
    "contentSha256": contentSha256,
  };

  bool matches(P2pSnapshotManifest manifest) {
    return projectUuid == manifest.projectUuid &&
        revisionId == manifest.revisionId &&
        contentSha256 == manifest.contentSha256;
  }

  @override
  bool operator ==(Object other) =>
      other is P2pSnapshotSyncRequest &&
      requestId == other.requestId &&
      projectUuid == other.projectUuid &&
      revisionId == other.revisionId &&
      contentSha256 == other.contentSha256;

  @override
  int get hashCode =>
      Object.hash(requestId, projectUuid, revisionId, contentSha256);
}

/// Metadata required to validate and plan a future chunked snapshot download.
///
/// This object never contains XML bytes. It may only be exchanged inside an
/// authenticated encrypted P2P session.
class P2pSnapshotManifest {
  static const int maxEncodedLength = 2048;
  static const int maxSnapshotBytes = 64 * 1024 * 1024;
  static const int chunkSizeBytes = 24 * 1024;
  static final RegExp _sha256Pattern = RegExp(r"^[0-9a-f]{64}$");

  final String projectUuid;
  final String revisionId;
  final String contentSha256;
  final int contentLength;
  final int chunkSize;
  final int chunkCount;
  final String formatVersion;

  factory P2pSnapshotManifest({
    required String projectUuid,
    required String revisionId,
    required String contentSha256,
    required int contentLength,
    int chunkSize = chunkSizeBytes,
    required String formatVersion,
  }) {
    final normalizedProjectUuid = projectUuid.trim().toLowerCase();
    final normalizedRevisionId = revisionId.trim().toLowerCase();
    final normalizedContentSha256 = contentSha256.trim().toLowerCase();
    final normalizedFormatVersion = formatVersion.trim();
    if (!P2pProjectStatus.isValidProjectUuid(normalizedProjectUuid) ||
        !_sha256Pattern.hasMatch(normalizedRevisionId) ||
        !_sha256Pattern.hasMatch(normalizedContentSha256) ||
        contentLength < 1 ||
        contentLength > maxSnapshotBytes ||
        chunkSize != chunkSizeBytes ||
        normalizedFormatVersion.isEmpty ||
        normalizedFormatVersion.length > 32) {
      throw const FormatException("P2P snapshot manifest 無效。");
    }
    return P2pSnapshotManifest._(
      projectUuid: normalizedProjectUuid,
      revisionId: normalizedRevisionId,
      contentSha256: normalizedContentSha256,
      contentLength: contentLength,
      chunkSize: chunkSize,
      chunkCount: (contentLength + chunkSize - 1) ~/ chunkSize,
      formatVersion: normalizedFormatVersion,
    );
  }

  const P2pSnapshotManifest._({
    required this.projectUuid,
    required this.revisionId,
    required this.contentSha256,
    required this.contentLength,
    required this.chunkSize,
    required this.chunkCount,
    required this.formatVersion,
  });

  factory P2pSnapshotManifest.fromJson(Map<String, Object?> json) {
    const expectedKeys = <String>{
      "projectUuid",
      "revisionId",
      "contentSha256",
      "contentLength",
      "chunkSize",
      "chunkCount",
      "formatVersion",
    };
    if (json.length != expectedKeys.length ||
        !json.keys.every(expectedKeys.contains)) {
      throw const FormatException("P2P snapshot manifest 欄位集合無效。");
    }
    final projectUuid = json["projectUuid"];
    final revisionId = json["revisionId"];
    final contentSha256 = json["contentSha256"];
    final contentLength = json["contentLength"];
    final chunkSize = json["chunkSize"];
    final chunkCount = json["chunkCount"];
    final formatVersion = json["formatVersion"];
    if (projectUuid is! String ||
        revisionId is! String ||
        contentSha256 is! String ||
        contentLength is! int ||
        chunkSize is! int ||
        chunkCount is! int ||
        formatVersion is! String) {
      throw const FormatException("P2P snapshot manifest 欄位不完整。");
    }
    final manifest = P2pSnapshotManifest(
      projectUuid: projectUuid,
      revisionId: revisionId,
      contentSha256: contentSha256,
      contentLength: contentLength,
      chunkSize: chunkSize,
      formatVersion: formatVersion,
    );
    if (manifest.chunkCount != chunkCount ||
        jsonEncode(manifest.toJson()).length > maxEncodedLength) {
      throw const FormatException("P2P snapshot manifest chunk 資訊無效。");
    }
    return manifest;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    "projectUuid": projectUuid,
    "revisionId": revisionId,
    "contentSha256": contentSha256,
    "contentLength": contentLength,
    "chunkSize": chunkSize,
    "chunkCount": chunkCount,
    "formatVersion": formatVersion,
  };

  bool matchesRevision({
    required String revisionProjectUuid,
    required String revisionId,
    required String revisionContentSha256,
    required String revisionFormatVersion,
  }) {
    return projectUuid == revisionProjectUuid.trim().toLowerCase() &&
        this.revisionId == revisionId.trim().toLowerCase() &&
        contentSha256 == revisionContentSha256.trim().toLowerCase() &&
        formatVersion == revisionFormatVersion.trim();
  }

  @override
  bool operator ==(Object other) =>
      other is P2pSnapshotManifest &&
      projectUuid == other.projectUuid &&
      revisionId == other.revisionId &&
      contentSha256 == other.contentSha256 &&
      contentLength == other.contentLength &&
      chunkSize == other.chunkSize &&
      chunkCount == other.chunkCount &&
      formatVersion == other.formatVersion;

  @override
  int get hashCode => Object.hash(
    projectUuid,
    revisionId,
    contentSha256,
    contentLength,
    chunkSize,
    chunkCount,
    formatVersion,
  );
}

/// One bounded snapshot payload fragment.
///
/// Chunks are not enabled on the network transport yet. This model defines the
/// strict validation boundary used by the quarantine receiver and future AEAD
/// frames.
class P2pSnapshotChunk {
  static const int maxEncodedLength = 36 * 1024;

  final String projectUuid;
  final String revisionId;
  final int chunkIndex;
  final int chunkCount;
  final List<int> bytes;

  factory P2pSnapshotChunk({
    required String projectUuid,
    required String revisionId,
    required int chunkIndex,
    required int chunkCount,
    required List<int> bytes,
  }) {
    final normalizedProjectUuid = projectUuid.trim().toLowerCase();
    final normalizedRevisionId = revisionId.trim().toLowerCase();
    if (!P2pProjectStatus.isValidProjectUuid(normalizedProjectUuid) ||
        !P2pSnapshotManifest._sha256Pattern.hasMatch(normalizedRevisionId) ||
        chunkIndex < 0 ||
        chunkCount < 1 ||
        chunkIndex >= chunkCount ||
        bytes.isEmpty ||
        bytes.length > P2pSnapshotManifest.chunkSizeBytes ||
        bytes.any((byte) => byte < 0 || byte > 255)) {
      throw const FormatException("P2P snapshot chunk 無效。");
    }
    return P2pSnapshotChunk._(
      projectUuid: normalizedProjectUuid,
      revisionId: normalizedRevisionId,
      chunkIndex: chunkIndex,
      chunkCount: chunkCount,
      bytes: List<int>.unmodifiable(bytes),
    );
  }

  const P2pSnapshotChunk._({
    required this.projectUuid,
    required this.revisionId,
    required this.chunkIndex,
    required this.chunkCount,
    required this.bytes,
  });

  factory P2pSnapshotChunk.fromJson(Map<String, Object?> json) {
    const expectedKeys = <String>{
      "projectUuid",
      "revisionId",
      "chunkIndex",
      "chunkCount",
      "body",
    };
    if (json.length != expectedKeys.length ||
        !json.keys.every(expectedKeys.contains)) {
      throw const FormatException("P2P snapshot chunk 欄位集合無效。");
    }
    final projectUuid = json["projectUuid"];
    final revisionId = json["revisionId"];
    final chunkIndex = json["chunkIndex"];
    final chunkCount = json["chunkCount"];
    final body = json["body"];
    if (projectUuid is! String ||
        revisionId is! String ||
        chunkIndex is! int ||
        chunkCount is! int ||
        body is! String ||
        body.length > maxEncodedLength) {
      throw const FormatException("P2P snapshot chunk 欄位不完整。");
    }
    List<int> decoded;
    try {
      decoded = base64Decode(body);
    } on FormatException {
      throw const FormatException("P2P snapshot chunk body 不是有效 Base64。");
    }
    final chunk = P2pSnapshotChunk(
      projectUuid: projectUuid,
      revisionId: revisionId,
      chunkIndex: chunkIndex,
      chunkCount: chunkCount,
      bytes: decoded,
    );
    if (jsonEncode(chunk.toJson()).length > maxEncodedLength) {
      throw const FormatException("P2P snapshot chunk 超過大小限制。");
    }
    return chunk;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    "projectUuid": projectUuid,
    "revisionId": revisionId,
    "chunkIndex": chunkIndex,
    "chunkCount": chunkCount,
    "body": base64Encode(bytes),
  };

  void validateAgainst(P2pSnapshotManifest manifest) {
    final isLast = chunkIndex == manifest.chunkCount - 1;
    final expectedLength = isLast
        ? manifest.contentLength -
              (manifest.chunkCount - 1) * manifest.chunkSize
        : manifest.chunkSize;
    if (projectUuid != manifest.projectUuid ||
        revisionId != manifest.revisionId ||
        chunkCount != manifest.chunkCount ||
        chunkIndex >= manifest.chunkCount ||
        bytes.length != expectedLength) {
      throw const FormatException("P2P snapshot chunk 與 manifest 不符。");
    }
  }
}

class P2pSnapshotChunkRequest {
  static const int maxEncodedLength = 3072;

  final P2pSnapshotManifest manifest;
  final int chunkIndex;

  factory P2pSnapshotChunkRequest({
    required P2pSnapshotManifest manifest,
    required int chunkIndex,
  }) {
    if (chunkIndex < 0 || chunkIndex >= manifest.chunkCount) {
      throw const FormatException("P2P snapshot chunk request index 無效。");
    }
    return P2pSnapshotChunkRequest._(
      manifest: manifest,
      chunkIndex: chunkIndex,
    );
  }

  const P2pSnapshotChunkRequest._({
    required this.manifest,
    required this.chunkIndex,
  });

  factory P2pSnapshotChunkRequest.fromJson(Map<String, Object?> json) {
    const expectedKeys = <String>{"manifest", "chunkIndex"};
    if (json.length != expectedKeys.length ||
        !json.keys.every(expectedKeys.contains)) {
      throw const FormatException("P2P snapshot chunk request 欄位集合無效。");
    }
    final manifestJson = json["manifest"];
    final chunkIndex = json["chunkIndex"];
    if (manifestJson is! Map || chunkIndex is! int) {
      throw const FormatException("P2P snapshot chunk request 欄位不完整。");
    }
    final mappedManifest = <String, Object?>{};
    for (final entry in manifestJson.entries) {
      if (entry.key is! String) {
        throw const FormatException(
          "P2P snapshot chunk request manifest key 無效。",
        );
      }
      mappedManifest[entry.key as String] = entry.value;
    }
    final manifest = P2pSnapshotManifest.fromJson(mappedManifest);
    final request = P2pSnapshotChunkRequest(
      manifest: manifest,
      chunkIndex: chunkIndex,
    );
    if (jsonEncode(request.toJson()).length > maxEncodedLength) {
      throw const FormatException("P2P snapshot chunk request 超過大小限制。");
    }
    return request;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    "manifest": manifest.toJson(),
    "chunkIndex": chunkIndex,
  };
}

class P2pSnapshotChunkAck {
  static const int maxEncodedLength = 1024;

  final String projectUuid;
  final String revisionId;
  final String contentSha256;
  final int chunkIndex;

  factory P2pSnapshotChunkAck({
    required String projectUuid,
    required String revisionId,
    required String contentSha256,
    required int chunkIndex,
  }) {
    final normalizedProjectUuid = projectUuid.trim().toLowerCase();
    final normalizedRevisionId = revisionId.trim().toLowerCase();
    final normalizedContentSha256 = contentSha256.trim().toLowerCase();
    if (!P2pProjectStatus.isValidProjectUuid(normalizedProjectUuid) ||
        !P2pSnapshotManifest._sha256Pattern.hasMatch(normalizedRevisionId) ||
        !P2pSnapshotManifest._sha256Pattern.hasMatch(normalizedContentSha256) ||
        chunkIndex < 0) {
      throw const FormatException("P2P snapshot chunk ACK 無效。");
    }
    return P2pSnapshotChunkAck._(
      projectUuid: normalizedProjectUuid,
      revisionId: normalizedRevisionId,
      contentSha256: normalizedContentSha256,
      chunkIndex: chunkIndex,
    );
  }

  const P2pSnapshotChunkAck._({
    required this.projectUuid,
    required this.revisionId,
    required this.contentSha256,
    required this.chunkIndex,
  });

  factory P2pSnapshotChunkAck.fromJson(Map<String, Object?> json) {
    const expectedKeys = <String>{
      "projectUuid",
      "revisionId",
      "contentSha256",
      "chunkIndex",
    };
    if (json.length != expectedKeys.length ||
        !json.keys.every(expectedKeys.contains)) {
      throw const FormatException("P2P snapshot chunk ACK 欄位集合無效。");
    }
    final projectUuid = json["projectUuid"];
    final revisionId = json["revisionId"];
    final contentSha256 = json["contentSha256"];
    final chunkIndex = json["chunkIndex"];
    if (projectUuid is! String ||
        revisionId is! String ||
        contentSha256 is! String ||
        chunkIndex is! int) {
      throw const FormatException("P2P snapshot chunk ACK 欄位不完整。");
    }
    final ack = P2pSnapshotChunkAck(
      projectUuid: projectUuid,
      revisionId: revisionId,
      contentSha256: contentSha256,
      chunkIndex: chunkIndex,
    );
    if (jsonEncode(ack.toJson()).length > maxEncodedLength) {
      throw const FormatException("P2P snapshot chunk ACK 超過大小限制。");
    }
    return ack;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    "projectUuid": projectUuid,
    "revisionId": revisionId,
    "contentSha256": contentSha256,
    "chunkIndex": chunkIndex,
  };

  bool matches(P2pSnapshotManifest manifest, int requestedChunkIndex) {
    return projectUuid == manifest.projectUuid &&
        revisionId == manifest.revisionId &&
        contentSha256 == manifest.contentSha256 &&
        chunkIndex == requestedChunkIndex &&
        chunkIndex < manifest.chunkCount;
  }
}
