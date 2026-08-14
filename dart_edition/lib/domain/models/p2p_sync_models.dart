enum P2pServiceStatus { stopped, starting, listening, stopping, error }

enum P2pConnectionStatus { idle, connecting, reachableUnpaired, error }

enum P2pProjectPreflightIssue {
  noLocalProject,
  localProjectNotPersisted,
  localProjectDirty,
  localProjectUuidInvalid,
  localProjectFormatUnsupported,
  localProjectHasConflict,
  noRemoteProject,
  remoteProjectNotPersisted,
  remoteProjectDirty,
  remoteProjectUuidInvalid,
  remoteProjectNotTrusted,
  remoteProjectFormatUnsupported,
  remoteProjectHasConflict,
  projectUuidMismatch,
}

enum P2pConflictSide { local, remote }

enum P2pFieldConflictChoice { inheritGroup, local, remote }

enum P2pProjectNegotiationKind {
  sameProject,
  localProvides,
  remoteProvides,
  selectionRequired,
}

enum P2pProjectSelectionReason { bothMissing, projectUuidMismatch }

enum P2pProjectSource { local, remote }

class P2pEndpoint {
  final String host;
  final int port;

  const P2pEndpoint({required this.host, required this.port});

  static bool isValidPort(int? port) {
    return port != null && port >= 1 && port <= 65535;
  }

  static int? parsePort(String raw) {
    final value = raw.trim();
    if (!RegExp(r"^[0-9]+$").hasMatch(value)) return null;
    final parsed = int.tryParse(value);
    return isValidPort(parsed) ? parsed : null;
  }

  static bool isPrivateIpv4(String raw) {
    final parts = raw.trim().split(".");
    if (parts.length != 4) return false;
    final octets = <int>[];
    for (final part in parts) {
      if (part.isEmpty || !RegExp(r"^[0-9]+$").hasMatch(part)) return false;
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) return false;
      if (part.length > 1 && part.startsWith("0")) return false;
      octets.add(value);
    }

    if (octets[0] == 10) return true;
    if (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) {
      return true;
    }
    return octets[0] == 192 && octets[1] == 168;
  }

  static P2pEndpoint? tryParse({required String host, required String port}) {
    final normalizedHost = host.trim();
    final parsedPort = parsePort(port);
    if (!isPrivateIpv4(normalizedHost) || parsedPort == null) return null;
    return P2pEndpoint(host: normalizedHost, port: parsedPort);
  }

  @override
  bool operator ==(Object other) {
    return other is P2pEndpoint && other.host == host && other.port == port;
  }

  @override
  int get hashCode => Object.hash(host, port);

  @override
  String toString() => "$host:$port";
}

class P2pProjectStatus {
  static final RegExp _uuidPattern = RegExp(
    r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
  );

  final String fileName;
  final bool hasPersistentLocation;
  final bool hasUnsavedChanges;
  final String? projectUuid;
  final bool isFormatSupported;
  final bool isPersistedSnapshotValidated;
  final bool hasPendingConflict;
  final bool isTrusted;

  const P2pProjectStatus({
    required this.fileName,
    required this.hasPersistentLocation,
    required this.hasUnsavedChanges,
    required this.projectUuid,
    this.isFormatSupported = true,
    this.isPersistedSnapshotValidated = false,
    this.hasPendingConflict = false,
    this.isTrusted = true,
  });

  bool get hasValidUuid {
    return isValidProjectUuid(projectUuid);
  }

  static bool isValidProjectUuid(String? value) {
    final normalized = value?.trim();
    return normalized != null && _uuidPattern.hasMatch(normalized);
  }

  bool get isLocallyReady {
    return hasPersistentLocation &&
        !hasUnsavedChanges &&
        hasValidUuid &&
        isFormatSupported &&
        isPersistedSnapshotValidated &&
        !hasPendingConflict;
  }

  String get shortUuid {
    final value = projectUuid?.trim();
    if (value == null || value.isEmpty) return "—";
    return value.length <= 8 ? value : value.substring(0, 8);
  }
}

class P2pProjectOffer {
  final bool hasProject;
  final bool disconnectRequested;
  final String? projectUuid;
  final String? fileName;

  const P2pProjectOffer._({
    required this.hasProject,
    this.disconnectRequested = false,
    this.projectUuid,
    this.fileName,
  });

  const P2pProjectOffer.none()
    : this._(hasProject: false, projectUuid: null, fileName: null);

  const P2pProjectOffer.disconnect()
    : this._(
        hasProject: false,
        disconnectRequested: true,
        projectUuid: null,
        fileName: null,
      );

  factory P2pProjectOffer.project({
    required String projectUuid,
    required String fileName,
  }) {
    final normalizedUuid = projectUuid.trim();
    final normalizedName = fileName.trim();
    if (!P2pProjectStatus.isValidProjectUuid(normalizedUuid)) {
      throw const FormatException("P2P project offer 的 UUID 無效。");
    }
    if (normalizedName.isEmpty || normalizedName.length > 260) {
      throw const FormatException("P2P project offer 的檔名無效。");
    }
    return P2pProjectOffer._(
      hasProject: true,
      projectUuid: normalizedUuid.toLowerCase(),
      fileName: normalizedName,
    );
  }

  factory P2pProjectOffer.fromStatus(P2pProjectStatus? status) {
    if (status == null || !status.isLocallyReady) {
      return const P2pProjectOffer.none();
    }
    return P2pProjectOffer.project(
      projectUuid: status.projectUuid!,
      fileName: status.fileName,
    );
  }

  factory P2pProjectOffer.fromJson(Map<String, Object?> json) {
    if (json["disconnectRequested"] == true) {
      return const P2pProjectOffer.disconnect();
    }
    final hasProject = json["hasProject"];
    if (hasProject is! bool) {
      throw const FormatException("P2P project offer 缺少 hasProject。");
    }
    if (!hasProject) return const P2pProjectOffer.none();
    final projectUuid = json["projectUuid"];
    final fileName = json["fileName"];
    if (projectUuid is! String || fileName is! String) {
      throw const FormatException("P2P project offer 缺少檔案資訊。");
    }
    return P2pProjectOffer.project(
      projectUuid: projectUuid,
      fileName: fileName,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    "hasProject": hasProject,
    if (disconnectRequested) "disconnectRequested": true,
    if (hasProject) "projectUuid": projectUuid,
    if (hasProject) "fileName": fileName,
  };

  String get shortUuid {
    final value = projectUuid;
    if (value == null) return "—";
    return value.length <= 8 ? value : value.substring(0, 8);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is P2pProjectOffer &&
            hasProject == other.hasProject &&
            disconnectRequested == other.disconnectRequested &&
            projectUuid == other.projectUuid &&
            fileName == other.fileName;
  }

  @override
  int get hashCode =>
      Object.hash(hasProject, disconnectRequested, projectUuid, fileName);
}

class P2pProjectNegotiationResult {
  final P2pProjectNegotiationKind kind;
  final P2pProjectSelectionReason? selectionReason;
  final P2pProjectSource? automaticSource;

  const P2pProjectNegotiationResult._({
    required this.kind,
    this.selectionReason,
    this.automaticSource,
  });

  bool get requiresDialog =>
      kind == P2pProjectNegotiationKind.selectionRequired;

  static P2pProjectNegotiationResult evaluate({
    required P2pProjectOffer local,
    required P2pProjectOffer remote,
  }) {
    if (local.disconnectRequested || remote.disconnectRequested) {
      throw StateError("中斷訊息不能用於文件協商。");
    }
    if (!local.hasProject && !remote.hasProject) {
      return const P2pProjectNegotiationResult._(
        kind: P2pProjectNegotiationKind.selectionRequired,
        selectionReason: P2pProjectSelectionReason.bothMissing,
      );
    }
    if (local.hasProject && !remote.hasProject) {
      return const P2pProjectNegotiationResult._(
        kind: P2pProjectNegotiationKind.localProvides,
        automaticSource: P2pProjectSource.local,
      );
    }
    if (!local.hasProject && remote.hasProject) {
      return const P2pProjectNegotiationResult._(
        kind: P2pProjectNegotiationKind.remoteProvides,
        automaticSource: P2pProjectSource.remote,
      );
    }
    if (local.projectUuid == remote.projectUuid) {
      return const P2pProjectNegotiationResult._(
        kind: P2pProjectNegotiationKind.sameProject,
      );
    }
    return const P2pProjectNegotiationResult._(
      kind: P2pProjectNegotiationKind.selectionRequired,
      selectionReason: P2pProjectSelectionReason.projectUuidMismatch,
    );
  }
}

class P2pProjectPreflightResult {
  final Set<P2pProjectPreflightIssue> issues;

  const P2pProjectPreflightResult(this.issues);

  bool get canSync => issues.isEmpty;

  bool get requiresSave {
    return issues.contains(P2pProjectPreflightIssue.noLocalProject) ||
        issues.contains(P2pProjectPreflightIssue.localProjectNotPersisted) ||
        issues.contains(P2pProjectPreflightIssue.localProjectDirty);
  }

  bool get requiresProjectSelection {
    return requiresSave ||
        issues.contains(P2pProjectPreflightIssue.localProjectUuidInvalid) ||
        issues.contains(P2pProjectPreflightIssue.noRemoteProject) ||
        issues.contains(P2pProjectPreflightIssue.projectUuidMismatch);
  }
}

class P2pProjectPreflight {
  const P2pProjectPreflight._();

  static P2pProjectPreflightResult evaluate({
    required P2pProjectStatus? local,
    P2pProjectStatus? remote,
    bool requireRemote = true,
  }) {
    final issues = <P2pProjectPreflightIssue>{};
    if (local == null) {
      issues.add(P2pProjectPreflightIssue.noLocalProject);
    } else {
      if (!local.hasPersistentLocation) {
        issues.add(P2pProjectPreflightIssue.localProjectNotPersisted);
      }
      if (local.hasUnsavedChanges) {
        issues.add(P2pProjectPreflightIssue.localProjectDirty);
      }
      if (!local.hasValidUuid) {
        issues.add(P2pProjectPreflightIssue.localProjectUuidInvalid);
      }
      if (!local.isFormatSupported) {
        issues.add(P2pProjectPreflightIssue.localProjectFormatUnsupported);
      }
      if (!local.isPersistedSnapshotValidated) {
        issues.add(P2pProjectPreflightIssue.localProjectNotPersisted);
      }
      if (local.hasPendingConflict) {
        issues.add(P2pProjectPreflightIssue.localProjectHasConflict);
      }
    }

    if (!requireRemote) return P2pProjectPreflightResult(issues);

    if (remote == null) {
      issues.add(P2pProjectPreflightIssue.noRemoteProject);
      return P2pProjectPreflightResult(issues);
    }
    if (!remote.hasPersistentLocation) {
      issues.add(P2pProjectPreflightIssue.remoteProjectNotPersisted);
    }
    if (remote.hasUnsavedChanges) {
      issues.add(P2pProjectPreflightIssue.remoteProjectDirty);
    }
    if (!remote.hasValidUuid) {
      issues.add(P2pProjectPreflightIssue.remoteProjectUuidInvalid);
    }
    if (!remote.isTrusted) {
      issues.add(P2pProjectPreflightIssue.remoteProjectNotTrusted);
    }
    if (!remote.isFormatSupported) {
      issues.add(P2pProjectPreflightIssue.remoteProjectFormatUnsupported);
    }
    if (!remote.isPersistedSnapshotValidated) {
      issues.add(P2pProjectPreflightIssue.remoteProjectNotPersisted);
    }
    if (remote.hasPendingConflict) {
      issues.add(P2pProjectPreflightIssue.remoteProjectHasConflict);
    }
    if (local != null &&
        local.hasValidUuid &&
        remote.hasValidUuid &&
        local.projectUuid!.toLowerCase() != remote.projectUuid!.toLowerCase()) {
      issues.add(P2pProjectPreflightIssue.projectUuidMismatch);
    }
    return P2pProjectPreflightResult(issues);
  }
}

class P2pFieldValue {
  final bool exists;
  final Object? value;

  const P2pFieldValue.present(this.value) : exists = true;
  const P2pFieldValue.absent() : exists = false, value = null;
}

class P2pFieldConflictItem {
  final String groupId;
  final String groupType;
  final String groupLabel;
  final List<String> fieldPathSegments;
  final P2pFieldValue base;
  final P2pFieldValue local;
  final P2pFieldValue remote;

  P2pFieldConflictItem({
    required this.groupId,
    required this.groupType,
    required this.groupLabel,
    required List<String> fieldPathSegments,
    required this.base,
    required this.local,
    required this.remote,
  }) : fieldPathSegments = List.unmodifiable(fieldPathSegments);

  String get fieldPath => fieldPathSegments.join(" > ");

  String get conflictId {
    final encodedPath = fieldPathSegments
        .map((segment) => "${segment.length}:$segment")
        .join("/");
    return "$groupType:${groupId.length}:$groupId/$encodedPath";
  }
}

class P2pKeyedTableMergeResult {
  final Map<String, Object?> mergedValues;
  final List<P2pFieldConflictItem> conflicts;

  const P2pKeyedTableMergeResult({
    required this.mergedValues,
    required this.conflicts,
  });
}

class P2pThreeWayMerge {
  const P2pThreeWayMerge._();

  static P2pKeyedTableMergeResult mergeKeyedTable({
    required String groupId,
    required String groupType,
    required String groupLabel,
    required String fieldPrefix,
    required Map<String, Object?> base,
    required Map<String, Object?> local,
    required Map<String, Object?> remote,
  }) {
    return _mergeKeyedMap(
      groupId: groupId,
      groupType: groupType,
      groupLabel: groupLabel,
      fieldPathPrefix: <String>[fieldPrefix],
      base: base,
      local: local,
      remote: remote,
      hasBase: true,
    );
  }

  static P2pKeyedTableMergeResult mergeKeyedTableWithoutBase({
    required String groupId,
    required String groupType,
    required String groupLabel,
    required String fieldPrefix,
    required Map<String, Object?> local,
    required Map<String, Object?> remote,
  }) {
    return _mergeKeyedMap(
      groupId: groupId,
      groupType: groupType,
      groupLabel: groupLabel,
      fieldPathPrefix: <String>[fieldPrefix],
      base: const <String, Object?>{},
      local: local,
      remote: remote,
      hasBase: false,
    );
  }

  static P2pKeyedTableMergeResult _mergeKeyedMap({
    required String groupId,
    required String groupType,
    required String groupLabel,
    required List<String> fieldPathPrefix,
    required Map<String, Object?> base,
    required Map<String, Object?> local,
    required Map<String, Object?> remote,
    required bool hasBase,
  }) {
    final merged = <String, Object?>{};
    final conflicts = <P2pFieldConflictItem>[];
    final keys = <String>{...base.keys, ...local.keys, ...remote.keys}.toList()
      ..sort();

    for (final key in keys) {
      final baseValue = _valueFor(base, key);
      final localValue = _valueFor(local, key);
      final remoteValue = _valueFor(remote, key);

      if (_fieldValuesEqual(localValue, remoteValue)) {
        if (localValue.exists) merged[key] = localValue.value;
        continue;
      }
      if (hasBase) {
        if (_fieldValuesEqual(localValue, baseValue)) {
          if (remoteValue.exists) merged[key] = remoteValue.value;
          continue;
        }
        if (_fieldValuesEqual(remoteValue, baseValue)) {
          if (localValue.exists) merged[key] = localValue.value;
          continue;
        }
      } else {
        if (!localValue.exists) {
          merged[key] = remoteValue.value;
          continue;
        }
        if (!remoteValue.exists) {
          merged[key] = localValue.value;
          continue;
        }
      }

      final baseRow = baseValue.exists ? _asStringMap(baseValue.value) : null;
      final localRow = localValue.exists
          ? _asStringMap(localValue.value)
          : null;
      final remoteRow = remoteValue.exists
          ? _asStringMap(remoteValue.value)
          : null;
      if (localRow != null && remoteRow != null) {
        final nested = _mergeKeyedMap(
          groupId: groupId,
          groupType: groupType,
          groupLabel: groupLabel,
          fieldPathPrefix: <String>[...fieldPathPrefix, key],
          base: baseRow ?? const <String, Object?>{},
          local: localRow,
          remote: remoteRow,
          hasBase: hasBase && baseRow != null,
        );
        merged[key] = nested.mergedValues;
        conflicts.addAll(nested.conflicts);
        continue;
      }

      conflicts.add(
        P2pFieldConflictItem(
          groupId: groupId,
          groupType: groupType,
          groupLabel: groupLabel,
          fieldPathSegments: <String>[...fieldPathPrefix, key],
          base: baseValue,
          local: localValue,
          remote: remoteValue,
        ),
      );
    }

    return P2pKeyedTableMergeResult(
      mergedValues: Map.unmodifiable(merged),
      conflicts: List.unmodifiable(conflicts),
    );
  }

  static Map<String, Object?>? _asStringMap(Object? value) {
    if (value is! Map) return null;
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) return null;
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  static P2pFieldValue _valueFor(Map<String, Object?> source, String key) {
    return source.containsKey(key)
        ? P2pFieldValue.present(source[key])
        : const P2pFieldValue.absent();
  }

  static bool _fieldValuesEqual(P2pFieldValue a, P2pFieldValue b) {
    return a.exists == b.exists && (!a.exists || deepEquals(a.value, b.value));
  }

  static bool deepEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var index = 0; index < a.length; index++) {
        if (!deepEquals(a[index], b[index])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final entry in a.entries) {
        if (!b.containsKey(entry.key) ||
            !deepEquals(entry.value, b[entry.key])) {
          return false;
        }
      }
      return true;
    }
    if (a is Set && b is Set) {
      if (a.length != b.length) return false;
      return a.every((item) => b.any((other) => deepEquals(item, other)));
    }
    return a == b;
  }

  /// Applies every explicit conflict choice to the automatically merged map.
  ///
  /// The first path segment is the table label supplied to [mergeKeyedTable],
  /// so it is intentionally excluded from the keyed document path. An absent
  /// chosen value deletes the key instead of turning it into a present `null`.
  static Map<String, Object?> applyResolutions(
    P2pKeyedTableMergeResult merge,
    P2pConflictResolutionResult resolutions,
  ) {
    final result = _mutableMapCopy(merge.mergedValues);
    for (final conflict in merge.conflicts) {
      final side = resolutions.sideFor(conflict);
      final chosen = side == P2pConflictSide.local
          ? conflict.local
          : conflict.remote;
      final path = conflict.fieldPathSegments.skip(1).toList(growable: false);
      if (path.isEmpty) {
        throw const FormatException("P2P conflict 欄位路徑不可為空。");
      }
      _writeFieldValue(result, path, chosen);
    }
    return Map.unmodifiable(result);
  }

  static Map<String, Object?> _mutableMapCopy(Map<String, Object?> source) {
    return <String, Object?>{
      for (final entry in source.entries)
        entry.key: entry.value is Map
            ? _mutableMapCopy(_asStringMap(entry.value)!)
            : entry.value is List
            ? List<Object?>.from(entry.value as List)
            : entry.value,
    };
  }

  static void _writeFieldValue(
    Map<String, Object?> target,
    List<String> path,
    P2pFieldValue value,
  ) {
    var current = target;
    for (var index = 0; index < path.length - 1; index++) {
      final key = path[index];
      final existing = _asStringMap(current[key]);
      final next = existing == null
          ? <String, Object?>{}
          : _mutableMapCopy(existing);
      current[key] = next;
      current = next;
    }
    final leaf = path.last;
    if (value.exists) {
      current[leaf] = value.value;
    } else {
      current.remove(leaf);
    }
  }
}

class P2pConflictGroupResolution {
  final P2pConflictSide? defaultSide;
  final Map<String, P2pFieldConflictChoice> fieldChoices;

  const P2pConflictGroupResolution({
    this.defaultSide,
    this.fieldChoices = const <String, P2pFieldConflictChoice>{},
  });

  P2pConflictSide? effectiveSide(P2pFieldConflictItem conflict) {
    return switch (fieldChoices[conflict.conflictId] ??
        P2pFieldConflictChoice.inheritGroup) {
      P2pFieldConflictChoice.inheritGroup => defaultSide,
      P2pFieldConflictChoice.local => P2pConflictSide.local,
      P2pFieldConflictChoice.remote => P2pConflictSide.remote,
    };
  }

  bool areAllResolved(Iterable<P2pFieldConflictItem> conflicts) {
    return conflicts.every((item) => effectiveSide(item) != null);
  }

  P2pConflictGroupResolution copyWith({
    Object? defaultSide = _unsetP2pValue,
    Map<String, P2pFieldConflictChoice>? fieldChoices,
  }) {
    return P2pConflictGroupResolution(
      defaultSide: identical(defaultSide, _unsetP2pValue)
          ? this.defaultSide
          : defaultSide as P2pConflictSide?,
      fieldChoices: fieldChoices ?? this.fieldChoices,
    );
  }
}

class P2pConflictResolutionResult {
  final Map<String, P2pConflictSide> fieldSides;

  P2pConflictResolutionResult(Map<String, P2pConflictSide> fieldSides)
    : fieldSides = Map.unmodifiable(fieldSides);

  P2pConflictSide sideFor(P2pFieldConflictItem conflict) {
    final side = fieldSides[conflict.conflictId];
    if (side == null) {
      throw StateError("Conflict ${conflict.conflictId} is unresolved.");
    }
    return side;
  }
}

const Object _unsetP2pValue = Object();
