import "dart:async";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:path_provider/path_provider.dart";

import "../../features/mcp/application/mcp_bridge_server.dart";
import "../../features/mcp/application/mcp_host_configuration.dart";
import "../../features/story_read/application/project_read_snapshot_builder.dart";
import "../../models/project_data.dart";
import "project_state_providers.dart";

final mcpBridgeProvider =
    StateNotifierProvider<McpBridgeNotifier, McpBridgeState>((ref) {
      final notifier = McpBridgeNotifier(ref);
      ref.onDispose(() => unawaited(notifier.shutdown()));
      ref.listen<String>(projectUuidProvider, (previous, next) {
        if (previous != null && previous != next) {
          unawaited(notifier.handleProjectSwitch());
        }
      });
      ref.listen<ProjectData>(projectDataProvider, (previous, next) {
        if (previous != null && previous.projectUUID == next.projectUUID) {
          notifier.scheduleSnapshotRefresh();
        }
      });
      ref.listen<GlossaryStateData>(glossaryStateProvider, (previous, next) {
        notifier.scheduleSnapshotRefresh();
      });
      return notifier;
    });

final class McpBridgeNotifier extends StateNotifier<McpBridgeState> {
  final Ref _ref;
  McpBridgeServer? _server;
  Timer? _snapshotRefreshTimer;
  int _operation = 0;

  McpBridgeNotifier(this._ref) : super(McpBridgeState.stopped);

  bool get isDesktopSupported =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  Future<void> enable() async {
    if (!isDesktopSupported || state.status == McpBridgeStatus.starting) return;
    final operation = ++_operation;
    final directory = await getApplicationSupportDirectory();
    if (operation != _operation) return;
    final project = _ref.read(projectDataProvider);
    final glossary = _ref.read(glossaryStateProvider).entryIndex;
    late final McpBridgeServer server;
    server = McpBridgeServer(
      descriptorFile: File(
        "${directory.path}${Platform.pathSeparator}mcp${Platform.pathSeparator}session.json",
      ),
      onStateChanged: (value) {
        if (identical(_server, server) && mounted) state = value;
      },
    );
    final previous = _server;
    _server = server;
    await previous?.stop();
    try {
      await server.start(
        snapshot: ProjectReadSnapshotBuilder.build(
          project,
          glossaryEntries: glossary,
        ),
        projectTitle: _projectTitle(project),
      );
      if (operation != _operation || !identical(_server, server)) {
        await server.stop();
      }
    } on Object {
      if (operation == _operation && mounted) {
        state = const McpBridgeState(
          status: McpBridgeStatus.failed,
          failure: "無法啟動本機 MCP bridge。",
        );
      }
    }
  }

  Future<void> handleProjectSwitch() async {
    _snapshotRefreshTimer?.cancel();
    _snapshotRefreshTimer = null;
    if (state.status != McpBridgeStatus.active) return;
    // Project scope changes always rotate both tokens and generation. A host
    // must perform a new, explicit handshake with the replacement descriptor.
    final server = _server;
    if (server == null) return;
    final operation = ++_operation;
    final project = _ref.read(projectDataProvider);
    final glossary = _ref.read(glossaryStateProvider).entryIndex;
    try {
      await server.rotate(
        snapshot: ProjectReadSnapshotBuilder.build(
          project,
          glossaryEntries: glossary,
        ),
        projectTitle: _projectTitle(project),
      );
      if (operation != _operation || !identical(_server, server)) {
        await server.stop();
      }
    } on Object {
      if (operation == _operation && mounted) {
        state = const McpBridgeState(
          status: McpBridgeStatus.failed,
          failure: "專案切換後無法更新 MCP 授權。",
        );
      }
    }
  }

  void scheduleSnapshotRefresh() {
    if (state.status != McpBridgeStatus.active) return;
    _snapshotRefreshTimer?.cancel();
    _snapshotRefreshTimer = Timer(
      const Duration(milliseconds: 250),
      _refreshSnapshot,
    );
  }

  void _refreshSnapshot() {
    _snapshotRefreshTimer = null;
    if (state.status != McpBridgeStatus.active) return;
    final server = _server;
    if (server == null) return;
    final project = _ref.read(projectDataProvider);
    final glossary = _ref.read(glossaryStateProvider).entryIndex;
    server.updateSnapshot(
      ProjectReadSnapshotBuilder.build(project, glossaryEntries: glossary),
    );
  }

  Future<void> stop() async {
    ++_operation;
    _snapshotRefreshTimer?.cancel();
    _snapshotRefreshTimer = null;
    final server = _server;
    _server = null;
    await server?.stop();
    if (mounted) state = McpBridgeState.stopped;
  }

  Future<void> shutdown() => stop();

  Future<String> hostConfiguration() async {
    final descriptorPath = state.descriptorPath;
    if (state.status != McpBridgeStatus.active ||
        !state.descriptorAvailable ||
        descriptorPath == null) {
      throw StateError("MCP 連線設定目前不可用。");
    }
    final sidecarPath = await McpHostConfiguration.locateSidecar();
    if (sidecarPath == null) {
      throw StateError("找不到 monoashi-mcp sidecar；開發版請先執行建置工具，正式版請重新安裝桌面應用程式。");
    }
    return McpHostConfiguration.encode(
      sidecarPath: sidecarPath,
      descriptorPath: descriptorPath,
    );
  }

  static String _projectTitle(ProjectData project) {
    final title = project.baseInfoData.bookName.trim();
    return title.isEmpty ? "未命名專案" : title;
  }
}
