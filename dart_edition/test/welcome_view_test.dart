import "package:flutter/material.dart";
import "dart:async";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/ui_library.dart";
import "package:monogatari_assistant/domain/models/p2p_sync_models.dart";
import "package:monogatari_assistant/domain/models/p2p_pairing_models.dart";
import "package:monogatari_assistant/domain/models/p2p_revision_models.dart";
import "package:monogatari_assistant/domain/models/p2p_snapshot_models.dart";
import "package:monogatari_assistant/data/p2p/p2p_secure_channel.dart";
import "package:monogatari_assistant/data/p2p/p2p_snapshot_quarantine.dart";
import "package:monogatari_assistant/modules/WelcomeView.dart";
import "package:monogatari_assistant/presentation/providers/p2p_sync_providers.dart";

class _FakeP2pSyncNotifier extends P2pSyncNotifier {
  @override
  P2pSyncState build() => const P2pSyncState();

  @override
  void updateLocalProjectStatus(P2pProjectStatus? status) {
    state = state.copyWith(
      localProjectOffer: P2pProjectOffer.fromStatus(status),
    );
  }

  void emitNegotiation({
    required P2pProjectOffer local,
    required P2pProjectOffer remote,
  }) {
    state = state.copyWith(
      connectionStatus: P2pConnectionStatus.reachableUnpaired,
      reachablePeer: const P2pEndpoint(host: "192.168.1.30", port: 45510),
      localProjectOffer: local,
      remoteProjectOffer: remote,
      projectNegotiation: P2pProjectNegotiationResult.evaluate(
        local: local,
        remote: remote,
      ),
      negotiationGeneration: state.negotiationGeneration + 1,
    );
  }

  void emitPairingCode(String code) {
    state = state.copyWith(
      connectionStatus: P2pConnectionStatus.reachableUnpaired,
      localIdentity: const P2pDeviceIdentity(
        deviceId: "123e4567-e89b-12d3-a456-426614174000",
        publicKeyBase64: "local-public-key",
        fingerprint: "AA:BB:CC:DD:EE:FF:00:11",
      ),
      pairingStatus: P2pPairingStatus.comparisonRequired,
      pairingCode: code,
    );
  }

  void emitMutuallyConfirmed() {
    state = state.copyWith(
      pairingStatus: P2pPairingStatus.mutuallyConfirmed,
      pairingCode: null,
    );
  }

  void emitRemoteProvider(P2pSnapshotManifest manifest) {
    final remote = P2pProjectOffer.project(
      projectUuid: manifest.projectUuid,
      fileName: "remote.mnproj",
    );
    state = state.copyWith(
      connectionStatus: P2pConnectionStatus.reachableUnpaired,
      reachablePeer: const P2pEndpoint(host: "192.168.1.30", port: 45510),
      localProjectOffer: const P2pProjectOffer.none(),
      remoteProjectOffer: remote,
      projectNegotiation: P2pProjectNegotiationResult.evaluate(
        local: const P2pProjectOffer.none(),
        remote: remote,
      ),
      selectedProjectSource: P2pProjectSource.remote,
      sessionProjectUuid: manifest.projectUuid,
      secureTransportStatus: P2pSecureTransportStatus.authenticated,
      trustedPeer: const P2pTrustedPeer(
        deviceId: "223e4567-e89b-12d3-a456-426614174000",
        publicKeyBase64: "peer-public-key",
        fingerprint: "11:22:33:44:55:66:77:88",
        trustedAtEpochSeconds: 1,
      ),
      revisionSummaryRelation: P2pRevisionSummaryRelation.remoteAhead,
      remoteSnapshotManifest: manifest,
      snapshotManifestStatus: P2pSnapshotManifestStatus.available,
    );
  }

  void emitIncomingSyncRequest() {
    final manifest = state.remoteSnapshotManifest!;
    state = state.copyWith(
      incomingSnapshotSyncRequest: P2pSnapshotSyncRequest(
        requestId: "widget-sync-request-0001",
        projectUuid: manifest.projectUuid,
        revisionId: manifest.revisionId,
        contentSha256: manifest.contentSha256,
      ),
      incomingSnapshotSyncRequestGeneration:
          state.incomingSnapshotSyncRequestGeneration + 1,
    );
  }

  void emitLocalProvider(P2pSnapshotManifest manifest) {
    final local = P2pProjectOffer.project(
      projectUuid: manifest.projectUuid,
      fileName: "local.mnproj",
    );
    state = state.copyWith(
      connectionStatus: P2pConnectionStatus.reachableUnpaired,
      reachablePeer: const P2pEndpoint(host: "192.168.1.30", port: 45510),
      localProjectOffer: local,
      remoteProjectOffer: const P2pProjectOffer.none(),
      projectNegotiation: P2pProjectNegotiationResult.evaluate(
        local: local,
        remote: const P2pProjectOffer.none(),
      ),
      selectedProjectSource: P2pProjectSource.local,
      sessionProjectUuid: manifest.projectUuid,
      secureTransportStatus: P2pSecureTransportStatus.authenticated,
      trustedPeer: const P2pTrustedPeer(
        deviceId: "223e4567-e89b-12d3-a456-426614174000",
        publicKeyBase64: "peer-public-key",
        fingerprint: "11:22:33:44:55:66:77:88",
        trustedAtEpochSeconds: 1,
      ),
      revisionSummaryRelation: P2pRevisionSummaryRelation.localAhead,
      localSnapshotManifest: manifest,
    );
  }

  void emitRemoteSnapshotUnavailable(P2pSnapshotManifest manifest) {
    final local = P2pProjectOffer.project(
      projectUuid: manifest.projectUuid,
      fileName: "local.mnproj",
    );
    final remote = P2pProjectOffer.project(
      projectUuid: manifest.projectUuid,
      fileName: "remote.mnproj",
    );
    state = state.copyWith(
      connectionStatus: P2pConnectionStatus.reachableUnpaired,
      reachablePeer: const P2pEndpoint(host: "192.168.1.30", port: 45510),
      localProjectOffer: local,
      remoteProjectOffer: remote,
      projectNegotiation: P2pProjectNegotiationResult.evaluate(
        local: local,
        remote: remote,
      ),
      selectedProjectSource: P2pProjectSource.local,
      sessionProjectUuid: manifest.projectUuid,
      secureTransportStatus: P2pSecureTransportStatus.authenticated,
      trustedPeer: const P2pTrustedPeer(
        deviceId: "223e4567-e89b-12d3-a456-426614174000",
        publicKeyBase64: "peer-public-key",
        fingerprint: "11:22:33:44:55:66:77:88",
        trustedAtEpochSeconds: 1,
      ),
      revisionSummaryRelation: P2pRevisionSummaryRelation.remoteAhead,
      snapshotManifestStatus: P2pSnapshotManifestStatus.unavailable,
    );
  }

  void emitConcurrent(P2pSnapshotManifest manifest) {
    emitRemoteProvider(manifest);
    final local = P2pProjectOffer.project(
      projectUuid: manifest.projectUuid,
      fileName: "local.mnproj",
    );
    final remote = P2pProjectOffer.project(
      projectUuid: manifest.projectUuid,
      fileName: "remote.mnproj",
    );
    state = state.copyWith(
      localProjectOffer: local,
      remoteProjectOffer: remote,
      projectNegotiation: P2pProjectNegotiationResult.evaluate(
        local: local,
        remote: remote,
      ),
      selectedProjectSource: P2pProjectSource.local,
      revisionSummaryRelation: P2pRevisionSummaryRelation.concurrent,
    );
  }
}

class _FakeP2pSnapshotTransferNotifier extends P2pSnapshotTransferNotifier {
  int downloadCount = 0;
  P2pVerifiedSnapshot? nextVerifiedSnapshot;

  @override
  P2pSnapshotTransferState build() => const P2pSnapshotTransferState();

  @override
  Future<bool> downloadRemoteSnapshot() async {
    downloadCount++;
    final verified = nextVerifiedSnapshot;
    if (verified == null) return false;
    state = P2pSnapshotTransferState(
      status: P2pSnapshotTransferStatus.verified,
      manifest: verified.manifest,
      verifiedSnapshot: verified,
    );
    return true;
  }

  void markApplied(P2pSnapshotManifest manifest) {
    state = P2pSnapshotTransferState(
      status: P2pSnapshotTransferStatus.applied,
      manifest: manifest,
      message: "遠端 snapshot 已另存並開啟。",
    );
  }
}

P2pSnapshotManifest _snapshotManifest() {
  return P2pSnapshotManifest(
    projectUuid: "123e4567-e89b-12d3-a456-426614174000",
    revisionId: List<String>.filled(64, "a").join(),
    contentSha256: List<String>.filled(64, "b").join(),
    contentLength: 128,
    formatVersion: "1.0",
  );
}

void main() {
  test(
    "stale remote download failure clears when local becomes provider",
    () async {
      final manifest = _snapshotManifest();
      final syncNotifier = _FakeP2pSyncNotifier();
      final container = ProviderContainer(
        overrides: [p2pSyncProvider.overrideWith(() => syncNotifier)],
      );
      addTearDown(container.dispose);
      container.read(p2pSyncProvider);
      final transferNotifier = container.read(
        p2pSnapshotTransferProvider.notifier,
      );
      syncNotifier.emitRemoteSnapshotUnavailable(manifest);

      expect(await transferNotifier.downloadRemoteSnapshot(), isFalse);
      expect(
        container.read(p2pSnapshotTransferProvider).status,
        P2pSnapshotTransferStatus.failed,
      );

      syncNotifier.emitLocalProvider(manifest);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(p2pSnapshotTransferProvider).status,
        P2pSnapshotTransferStatus.idle,
      );
    },
  );

  testWidgets("WelcomeView keeps spacing around every section card", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: WelcomeView(recentProjects: [])),
      ),
    );

    final Finder sectionCards = find.byType(AppSectionCard);
    expect(sectionCards, findsNWidgets(5));

    for (final Element element in sectionCards.evaluate()) {
      final AppSectionCard sectionCard = element.widget as AppSectionCard;
      expect(sectionCard.margin, const EdgeInsets.all(4));
    }
  });

  testWidgets("WelcomeView exposes P2P endpoint controls and project status", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: WelcomeView(
            recentProjects: [],
            localP2pProject: P2pProjectStatus(
              fileName: "story.mnproj",
              hasPersistentLocation: true,
              hasUnsavedChanges: false,
              projectUuid: "123e4567-e89b-12d3-a456-426614174000",
              isPersistedSnapshotValidated: true,
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key("p2p-peer-ip-field")));
    expect(find.byKey(const Key("p2p-local-port-field")), findsOneWidget);
    expect(find.byKey(const Key("p2p-peer-ip-field")), findsOneWidget);
    expect(find.byKey(const Key("p2p-peer-port-field")), findsOneWidget);
    expect(find.byKey(const Key("p2p-toggle-service-button")), findsOneWidget);
    expect(find.byKey(const Key("p2p-connect-button")), findsOneWidget);
    expect(
      find.byKey(const Key("p2p-snapshot-manifest-status")),
      findsOneWidget,
    );
    expect(find.text("已儲存；等待連線協商與安全配對"), findsOneWidget);
    expect(find.text("立即同步"), findsOneWidget);
  });

  testWidgets("invalid peer endpoint is rejected inline", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: WelcomeView(recentProjects: [])),
      ),
    );

    final ipField = find.byKey(const Key("p2p-peer-ip-field"));
    final portField = find.byKey(const Key("p2p-peer-port-field"));
    final connectButton = find.byKey(const Key("p2p-connect-button"));
    await tester.ensureVisible(ipField);
    await tester.enterText(ipField, "8.8.8.8");
    await tester.enterText(portField, "70000");
    await tester.tap(connectButton);
    await tester.pump();

    expect(find.text("請輸入有效的內網 IPv4 位址"), findsOneWidget);
    expect(find.text("Port 必須是 1–65535 的整數"), findsOneWidget);
  });

  testWidgets(
    "receiver without a local file can immediately sync the remote project",
    (WidgetTester tester) async {
      final notifier = _FakeP2pSyncNotifier();
      final container = ProviderContainer(
        overrides: [p2pSyncProvider.overrideWith(() => notifier)],
      );
      addTearDown(container.dispose);
      container.read(p2pSyncProvider);
      notifier.emitRemoteProvider(_snapshotManifest());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: WelcomeView(
              recentProjects: const [],
              onApplyVerifiedP2pSnapshot: (_) async => true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key("p2p-immediate-sync-button")),
      );

      expect(find.text("將由對方提供記憶體專案；不必先選擇儲存位置"), findsOneWidget);
      expect(find.text("請先儲存同步文件"), findsNothing);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key("p2p-immediate-sync-button")),
      );
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets("provider with a newer snapshot can request immediate sync", (
    WidgetTester tester,
  ) async {
    final manifest = _snapshotManifest();
    final notifier = _FakeP2pSyncNotifier();
    final container = ProviderContainer(
      overrides: [p2pSyncProvider.overrideWith(() => notifier)],
    );
    addTearDown(container.dispose);
    container.read(p2pSyncProvider);
    notifier.emitLocalProvider(manifest);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: WelcomeView(
            recentProjects: const [],
            localP2pProject: const P2pProjectStatus(
              fileName: "local.mnproj",
              hasPersistentLocation: true,
              hasUnsavedChanges: false,
              projectUuid: "123e4567-e89b-12d3-a456-426614174000",
              isPersistedSnapshotValidated: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key("p2p-immediate-sync-button")),
    );

    final button = tester.widget<FilledButton>(
      find.byKey(const Key("p2p-immediate-sync-button")),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets("concurrent revisions invoke field conflict resolver", (
    WidgetTester tester,
  ) async {
    final manifest = _snapshotManifest();
    final notifier = _FakeP2pSyncNotifier();
    final transferNotifier = _FakeP2pSnapshotTransferNotifier()
      ..nextVerifiedSnapshot = P2pVerifiedSnapshot(
        manifest: manifest,
        xmlContent:
            '<Project UUID="${manifest.projectUuid}"><ver>1.0</ver></Project>',
      );
    final container = ProviderContainer(
      overrides: [
        p2pSyncProvider.overrideWith(() => notifier),
        p2pSnapshotTransferProvider.overrideWith(() => transferNotifier),
      ],
    );
    addTearDown(container.dispose);
    container.read(p2pSyncProvider);
    notifier.emitConcurrent(manifest);
    var resolveCount = 0;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: WelcomeView(
            recentProjects: const [],
            localP2pProject: const P2pProjectStatus(
              fileName: "local.mnproj",
              hasPersistentLocation: true,
              hasUnsavedChanges: false,
              projectUuid: "123e4567-e89b-12d3-a456-426614174000",
              isPersistedSnapshotValidated: true,
            ),
            onResolveConcurrentP2pSnapshot: (_) async {
              resolveCount++;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    final button = find.byKey(const Key("p2p-immediate-sync-button"));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    expect(transferNotifier.downloadCount, 1);
    expect(resolveCount, 1);
  });

  testWidgets("concurrent sync serializes duplicate resolver taps", (
    WidgetTester tester,
  ) async {
    final manifest = _snapshotManifest();
    final notifier = _FakeP2pSyncNotifier();
    final transferNotifier = _FakeP2pSnapshotTransferNotifier()
      ..nextVerifiedSnapshot = P2pVerifiedSnapshot(
        manifest: manifest,
        xmlContent:
            '<Project UUID="${manifest.projectUuid}"><ver>1.0</ver></Project>',
      );
    final resolveCompleter = Completer<bool>();
    final container = ProviderContainer(
      overrides: [
        p2pSyncProvider.overrideWith(() => notifier),
        p2pSnapshotTransferProvider.overrideWith(() => transferNotifier),
      ],
    );
    addTearDown(container.dispose);
    container.read(p2pSyncProvider);
    notifier.emitConcurrent(manifest);
    var resolveCount = 0;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: WelcomeView(
            recentProjects: const [],
            localP2pProject: const P2pProjectStatus(
              fileName: "local.mnproj",
              hasPersistentLocation: true,
              hasUnsavedChanges: false,
              projectUuid: "123e4567-e89b-12d3-a456-426614174000",
              isPersistedSnapshotValidated: true,
            ),
            onResolveConcurrentP2pSnapshot: (_) {
              resolveCount++;
              return resolveCompleter.future;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    final button = find.byKey(const Key("p2p-immediate-sync-button"));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();

    expect(transferNotifier.downloadCount, 1);
    expect(resolveCount, 1);

    resolveCompleter.complete(true);
    await tester.pump();
  });

  testWidgets(
    "an applied transfer does not block a later concurrent resolution",
    (WidgetTester tester) async {
      final manifest = _snapshotManifest();
      final notifier = _FakeP2pSyncNotifier();
      final transferNotifier = _FakeP2pSnapshotTransferNotifier()
        ..nextVerifiedSnapshot = P2pVerifiedSnapshot(
          manifest: manifest,
          xmlContent:
              '<Project UUID="${manifest.projectUuid}"><ver>1.0</ver></Project>',
        );
      final container = ProviderContainer(
        overrides: [
          p2pSyncProvider.overrideWith(() => notifier),
          p2pSnapshotTransferProvider.overrideWith(() => transferNotifier),
        ],
      );
      addTearDown(container.dispose);
      container.read(p2pSyncProvider);
      notifier.emitConcurrent(manifest);
      container.read(p2pSnapshotTransferProvider);
      transferNotifier.markApplied(manifest);
      var resolveCount = 0;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: WelcomeView(
              recentProjects: const [],
              localP2pProject: const P2pProjectStatus(
                fileName: "local.mnproj",
                hasPersistentLocation: true,
                hasUnsavedChanges: false,
                projectUuid: "123e4567-e89b-12d3-a456-426614174000",
                isPersistedSnapshotValidated: true,
              ),
              onResolveConcurrentP2pSnapshot: (_) async {
                resolveCount++;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      final button = find.byKey(const Key("p2p-immediate-sync-button"));
      await tester.ensureVisible(button);

      expect(find.text("已儲存；可進行欄位級衝突合併"), findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      await tester.tap(button);
      await tester.pump();

      expect(transferNotifier.downloadCount, 1);
      expect(resolveCount, 1);
    },
  );

  testWidgets("encrypted provider request starts receiver pull after build", (
    WidgetTester tester,
  ) async {
    final notifier = _FakeP2pSyncNotifier();
    final transferNotifier = _FakeP2pSnapshotTransferNotifier();
    final container = ProviderContainer(
      overrides: [
        p2pSyncProvider.overrideWith(() => notifier),
        p2pSnapshotTransferProvider.overrideWith(() => transferNotifier),
      ],
    );
    addTearDown(container.dispose);
    container.read(p2pSyncProvider);
    notifier.emitRemoteProvider(_snapshotManifest());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: WelcomeView(
            recentProjects: const [],
            onApplyVerifiedP2pSnapshot: (_) async => true,
          ),
        ),
      ),
    );
    await tester.pump();

    notifier.emitIncomingSyncRequest();
    await tester.pump();
    await tester.pump();

    expect(transferNotifier.downloadCount, 1);
  });

  testWidgets("different UUIDs open the project selection dialog", (
    WidgetTester tester,
  ) async {
    final notifier = _FakeP2pSyncNotifier();
    final container = ProviderContainer(
      overrides: [p2pSyncProvider.overrideWith(() => notifier)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: WelcomeView(
            recentProjects: [],
            localP2pProject: P2pProjectStatus(
              fileName: "local.mnproj",
              hasPersistentLocation: true,
              hasUnsavedChanges: false,
              projectUuid: "123e4567-e89b-12d3-a456-426614174000",
              isPersistedSnapshotValidated: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    notifier.emitNegotiation(
      local: P2pProjectOffer.project(
        projectUuid: "123e4567-e89b-12d3-a456-426614174000",
        fileName: "local.mnproj",
      ),
      remote: P2pProjectOffer.project(
        projectUuid: "223e4567-e89b-12d3-a456-426614174000",
        fileName: "remote.mnproj",
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("同步文件不同"), findsOneWidget);
    expect(find.text("使用本機文件"), findsOneWidget);
    expect(find.text("使用對方文件"), findsOneWidget);

    await tester.tap(find.text("使用對方文件"));
    await tester.pumpAndSettle();
    expect(
      container.read(p2pSyncProvider).selectedProjectSource,
      P2pProjectSource.remote,
    );
  });

  testWidgets("both missing projects open only the preparation dialog", (
    WidgetTester tester,
  ) async {
    final notifier = _FakeP2pSyncNotifier();
    final container = ProviderContainer(
      overrides: [p2pSyncProvider.overrideWith(() => notifier)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WelcomeView(recentProjects: [])),
      ),
    );
    await tester.pump();

    notifier.emitNegotiation(
      local: const P2pProjectOffer.none(),
      remote: const P2pProjectOffer.none(),
    );
    await tester.pumpAndSettle();

    expect(find.text("雙方都沒有同步文件"), findsOneWidget);
    expect(find.text("建立本機專案"), findsOneWidget);
    expect(find.text("使用本機文件"), findsNothing);
    expect(find.text("使用對方文件"), findsNothing);
  });

  testWidgets("opening a file closes the both-missing dialog immediately", (
    WidgetTester tester,
  ) async {
    final notifier = _FakeP2pSyncNotifier();
    final container = ProviderContainer(
      overrides: [p2pSyncProvider.overrideWith(() => notifier)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WelcomeView(recentProjects: [])),
      ),
    );
    await tester.pump();

    notifier.emitNegotiation(
      local: const P2pProjectOffer.none(),
      remote: const P2pProjectOffer.none(),
    );
    await tester.pumpAndSettle();
    expect(find.text("雙方都沒有同步文件"), findsOneWidget);

    notifier.emitNegotiation(
      local: P2pProjectOffer.project(
        projectUuid: "123e4567-e89b-12d3-a456-426614174000",
        fileName: "local.mnproj",
      ),
      remote: const P2pProjectOffer.none(),
    );
    await tester.pumpAndSettle();

    expect(find.text("雙方都沒有同步文件"), findsNothing);
  });

  testWidgets("pairing panel shows the signed comparison code", (
    WidgetTester tester,
  ) async {
    final notifier = _FakeP2pSyncNotifier();
    final container = ProviderContainer(
      overrides: [p2pSyncProvider.overrideWith(() => notifier)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WelcomeView(recentProjects: [])),
      ),
    );
    await tester.pump();

    notifier.emitPairingCode("123456");
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key("p2p-pairing-panel")));

    expect(find.byKey(const Key("p2p-local-fingerprint")), findsOneWidget);
    expect(find.byKey(const Key("p2p-revision-status")), findsOneWidget);
    expect(find.byKey(const Key("p2p-pairing-code")), findsOneWidget);
    expect(find.text("123456"), findsOneWidget);
    expect(find.byKey(const Key("p2p-confirm-pairing-button")), findsOneWidget);
    expect(find.byKey(const Key("p2p-cancel-pairing-button")), findsOneWidget);

    notifier.emitMutuallyConfirmed();
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key("p2p-mutually-confirmed-notice")),
    );
    expect(find.text("雙端已確認同一配對 transcript"), findsOneWidget);
    expect(
      find.byKey(const Key("p2p-mutually-confirmed-notice")),
      findsOneWidget,
    );
  });
}
