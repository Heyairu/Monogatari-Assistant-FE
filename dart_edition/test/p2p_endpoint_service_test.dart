import "dart:convert";
import "dart:io";

import "package:cryptography/cryptography.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/data/p2p/p2p_android_probe_gateway.dart";
import "package:monogatari_assistant/data/p2p/p2p_endpoint_service.dart";
import "package:monogatari_assistant/data/p2p/p2p_identity_store.dart";
import "package:monogatari_assistant/data/p2p/p2p_secure_channel.dart";
import "package:monogatari_assistant/data/p2p/p2p_snapshot_download.dart";
import "package:monogatari_assistant/data/p2p/p2p_snapshot_endpoint_gateway.dart";
import "package:monogatari_assistant/data/p2p/p2p_snapshot_quarantine.dart";
import "package:monogatari_assistant/domain/collaboration/collaboration_document.dart";
import "package:monogatari_assistant/domain/collaboration/collaboration_protocol.dart";
import "package:monogatari_assistant/domain/models/p2p_revision_models.dart";
import "package:monogatari_assistant/domain/models/p2p_resolution_models.dart";
import "package:monogatari_assistant/domain/models/p2p_snapshot_models.dart";
import "package:monogatari_assistant/domain/models/p2p_sync_models.dart";

class _MemorySecureStore implements P2pSecureKeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _FakeAndroidProbeGateway implements P2pAndroidProbeGateway {
  @override
  bool isSupported = true;
  int callCount = 0;
  Object? error;
  String exchangeResponse = "";
  Future<String> Function(String requestLine)? exchangeHandler;
  int multiLineCallCount = 0;

  @override
  Future<void> probe({
    required String host,
    required int port,
    required Duration connectTimeout,
    required Duration readTimeout,
  }) async {
    callCount++;
    final probeError = error;
    if (probeError != null) throw probeError;
  }

  @override
  Future<String> exchangeLine({
    required String host,
    required int port,
    required String requestLine,
    required int maxResponseBytes,
    required Duration connectTimeout,
    required Duration readTimeout,
  }) async {
    callCount++;
    final probeError = error;
    if (probeError != null) throw probeError;
    final handler = exchangeHandler;
    if (handler != null) return handler(requestLine);
    return exchangeResponse;
  }

  @override
  Future<List<String>> exchangeLines({
    required String host,
    required int port,
    required List<String> requestLines,
    required int maxResponseBytes,
    required Duration connectTimeout,
    required Duration readTimeout,
  }) async {
    callCount++;
    multiLineCallCount++;
    final probeError = error;
    if (probeError != null) throw probeError;
    final handler = exchangeHandler;
    if (handler == null) {
      return List<String>.filled(requestLines.length, exchangeResponse);
    }
    final responses = <String>[];
    for (final requestLine in requestLines) {
      responses.add(await handler(requestLine));
    }
    return responses;
  }
}

({P2pSecureSessionKeys client, P2pSecureSessionKeys server})
_testSessionKeys() {
  const clientId = "123e4567-e89b-12d3-a456-426614174000";
  const serverId = "223e4567-e89b-12d3-a456-426614174000";
  final clientToServer = List<int>.filled(32, 0x11);
  final serverToClient = List<int>.filled(32, 0x22);
  final sessionId = List<String>.filled(64, "a").join();
  return (
    client: P2pSecureSessionKeys(
      sessionId: sessionId,
      localDeviceId: clientId,
      remoteDeviceId: serverId,
      sendKey: SecretKeyData(clientToServer, overwriteWhenDestroyed: true),
      receiveKey: SecretKeyData(serverToClient, overwriteWhenDestroyed: true),
    ),
    server: P2pSecureSessionKeys(
      sessionId: sessionId,
      localDeviceId: serverId,
      remoteDeviceId: clientId,
      sendKey: SecretKeyData(serverToClient, overwriteWhenDestroyed: true),
      receiveKey: SecretKeyData(clientToServer, overwriteWhenDestroyed: true),
    ),
  );
}

String _hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, "0")).join();

P2pRevisionMetadata _testRevision({
  required String projectUuid,
  required String authorDeviceId,
  required String revisionHex,
  required String contentHex,
  List<String> parents = const <String>[],
  int clockCounter = 1,
}) {
  return P2pRevisionMetadata(
    revisionId: List<String>.filled(64, revisionHex).join(),
    projectUuid: projectUuid,
    parents: parents,
    clock: P2pVersionVector(<String, int>{authorDeviceId: clockCounter}),
    authorDeviceId: authorDeviceId,
    createdAtEpochSeconds: 1,
    contentSha256: List<String>.filled(64, contentHex).join(),
    formatVersion: "1.0",
  );
}

void main() {
  test(
    "IO P2P endpoint completes only the bounded compatibility probe",
    () async {
      final reservation = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final port = reservation.port;
      await reservation.close();
      final service = IoP2pEndpointService();
      addTearDown(service.dispose);
      final listening = await service.start(port: port);
      expect(listening.port, port);
      final inboundProbe = service.inboundProbes.first;

      await service.probe(
        P2pEndpoint(host: InternetAddress.loopbackIPv4.address, port: port),
      );
      expect((await inboundProbe).remoteAddress, "127.0.0.1");
    },
  );

  test("IO P2P endpoint exchanges bounded project offers", () async {
    final reservation = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final port = reservation.port;
    await reservation.close();

    final server = IoP2pEndpointService();
    final client = IoP2pEndpointService();
    addTearDown(server.dispose);
    addTearDown(client.dispose);
    final serverOffer = P2pProjectOffer.project(
      projectUuid: "123e4567-e89b-12d3-a456-426614174000",
      fileName: "server.mnproj",
    );
    final clientOffer = P2pProjectOffer.project(
      projectUuid: "223e4567-e89b-12d3-a456-426614174000",
      fileName: "client.mnproj",
    );
    server.updateLocalProjectOffer(serverOffer);
    await server.start(port: port);
    final inboundOffer = server.inboundProjectOffers.first;

    final response = await client.negotiateProjectOffer(
      P2pEndpoint(host: InternetAddress.loopbackIPv4.address, port: port),
      clientOffer,
    );

    expect(response.projectUuid, serverOffer.projectUuid);
    expect((await inboundOffer).offer.projectUuid, clientOffer.projectUuid);
  });

  test("IO P2P endpoint exchanges an explicit disconnect notice", () async {
    final reservation = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final port = reservation.port;
    await reservation.close();

    final server = IoP2pEndpointService();
    final client = IoP2pEndpointService();
    addTearDown(server.dispose);
    addTearDown(client.dispose);
    await server.start(port: port);
    final inboundOffer = server.inboundProjectOffers.first;

    await client.notifyDisconnect(
      P2pEndpoint(host: InternetAddress.loopbackIPv4.address, port: port),
    );

    expect((await inboundOffer).offer.disconnectRequested, isTrue);
  });

  test(
    "IO P2P endpoint can end an inbound session on its next refresh",
    () async {
      final reservation = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final port = reservation.port;
      await reservation.close();
      final server = IoP2pEndpointService();
      final client = IoP2pEndpointService();
      addTearDown(server.dispose);
      addTearDown(client.dispose);
      await server.start(port: port);
      server.requestDisconnectOnNextExchange();

      final response = await client.negotiateProjectOffer(
        P2pEndpoint(host: InternetAddress.loopbackIPv4.address, port: port),
        const P2pProjectOffer.none(),
      );

      expect(response.disconnectRequested, isTrue);
    },
  );

  test("IO P2P endpoint exchanges bounded signed pairing challenges", () async {
    final reservation = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final port = reservation.port;
    await reservation.close();

    final server = IoP2pEndpointService();
    final client = IoP2pEndpointService();
    addTearDown(server.dispose);
    addTearDown(client.dispose);
    final serverChallenge = await P2pIdentityStore(
      storage: _MemorySecureStore(),
    ).createPairingChallenge();
    final clientChallenge = await P2pIdentityStore(
      storage: _MemorySecureStore(),
    ).createPairingChallenge();
    server.updateLocalPairingChallenge(serverChallenge);
    await server.start(port: port);
    final inbound = server.inboundPairingChallenges.first;

    final response = await client.negotiatePairingChallenge(
      P2pEndpoint(host: InternetAddress.loopbackIPv4.address, port: port),
      clientChallenge,
    );

    expect(response?.deviceId, serverChallenge.deviceId);
    expect((await inbound).challenge.deviceId, clientChallenge.deviceId);
  });

  test("IO P2P endpoint exchanges signed pairing confirmations", () async {
    final reservation = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final port = reservation.port;
    await reservation.close();

    final server = IoP2pEndpointService();
    final client = IoP2pEndpointService();
    addTearDown(server.dispose);
    addTearDown(client.dispose);
    final serverIdentity = P2pIdentityStore(storage: _MemorySecureStore());
    final clientIdentity = P2pIdentityStore(storage: _MemorySecureStore());
    final serverChallenge = await serverIdentity.createPairingChallenge();
    final clientChallenge = await clientIdentity.createPairingChallenge();
    final serverConfirmation = await serverIdentity.createPairingConfirmation(
      serverChallenge,
      clientChallenge,
    );
    final clientConfirmation = await clientIdentity.createPairingConfirmation(
      clientChallenge,
      serverChallenge,
    );
    server.updateLocalPairingConfirmation(serverConfirmation);
    await server.start(port: port);
    final inbound = server.inboundPairingConfirmations.first;

    final response = await client.negotiatePairingConfirmation(
      P2pEndpoint(host: InternetAddress.loopbackIPv4.address, port: port),
      clientConfirmation,
    );

    expect(response?.deviceId, serverChallenge.deviceId);
    expect((await inbound).confirmation.deviceId, clientChallenge.deviceId);
  });

  test(
    "IO P2P endpoint can poll a peer confirmation before confirming locally",
    () async {
      final reservation = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final port = reservation.port;
      await reservation.close();

      final server = IoP2pEndpointService();
      final client = IoP2pEndpointService();
      addTearDown(server.dispose);
      addTearDown(client.dispose);
      final serverIdentity = P2pIdentityStore(storage: _MemorySecureStore());
      final clientIdentity = P2pIdentityStore(storage: _MemorySecureStore());
      final serverChallenge = await serverIdentity.createPairingChallenge();
      final clientChallenge = await clientIdentity.createPairingChallenge();
      final serverConfirmation = await serverIdentity.createPairingConfirmation(
        serverChallenge,
        clientChallenge,
      );
      server.updateLocalPairingConfirmation(serverConfirmation);
      await server.start(port: port);

      final response = await client.negotiatePairingConfirmation(
        P2pEndpoint(host: InternetAddress.loopbackIPv4.address, port: port),
        null,
      );

      expect(response?.canonicalPayload, serverConfirmation.canonicalPayload);
    },
  );

  test(
    "IO P2P endpoint exchanges revision summaries only inside the authenticated channel",
    () async {
      final reservation = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final port = reservation.port;
      await reservation.close();
      final clientReservation = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final clientPort = clientReservation.port;
      await clientReservation.close();

      final server = IoP2pEndpointService();
      final client = IoP2pEndpointService();
      addTearDown(server.dispose);
      addTearDown(client.dispose);
      final keys = _testSessionKeys();
      server.installAuthenticatedSession(keys.server);
      client.installAuthenticatedSession(keys.client);
      const projectUuid = "323e4567-e89b-12d3-a456-426614174000";
      final serverRevision = _testRevision(
        projectUuid: projectUuid,
        authorDeviceId: keys.server.localDeviceId,
        revisionHex: "b",
        contentHex: "c",
      );
      final clientBaseRevision = _testRevision(
        projectUuid: projectUuid,
        authorDeviceId: keys.client.localDeviceId,
        revisionHex: "a",
        contentHex: "f",
      );
      final clientRevision = _testRevision(
        projectUuid: projectUuid,
        authorDeviceId: keys.client.localDeviceId,
        revisionHex: "d",
        contentHex: "e",
        parents: <String>[clientBaseRevision.revisionId],
        clockCounter: 2,
      );
      final serverSummary = P2pRevisionSummary(
        projectUuid: projectUuid,
        heads: <P2pRevisionMetadata>[serverRevision],
      );
      final clientSummary = P2pRevisionSummary(
        projectUuid: projectUuid,
        heads: <P2pRevisionMetadata>[clientRevision],
        draftHeadIds: <String>{clientRevision.revisionId},
        delta: P2pRevisionDelta.tryCreate(
          baseRevision: clientBaseRevision,
          targetRevision: clientRevision,
          baseBytes: "before".codeUnits,
          targetBytes: "before!".codeUnits,
        ),
      );
      final serverManifest = P2pSnapshotManifest(
        projectUuid: projectUuid,
        revisionId: serverRevision.revisionId,
        contentSha256: serverRevision.contentSha256,
        contentLength: 1024,
        formatVersion: serverRevision.formatVersion,
      );
      final clientManifest = P2pSnapshotManifest(
        projectUuid: projectUuid,
        revisionId: clientRevision.revisionId,
        contentSha256: clientRevision.contentSha256,
        contentLength: 2048,
        formatVersion: clientRevision.formatVersion,
      );
      server.updateLocalRevisionSummary(serverSummary);
      client.updateLocalRevisionSummary(clientSummary);
      server.updateLocalSnapshotManifests(<P2pSnapshotManifest>[
        serverManifest,
      ]);
      client.updateLocalSnapshotManifests(<P2pSnapshotManifest>[
        clientManifest,
      ]);
      final serverSyncRequest = P2pSnapshotSyncRequest(
        requestId: "server-sync-request-0001",
        projectUuid: projectUuid,
        revisionId: serverManifest.revisionId,
        contentSha256: serverManifest.contentSha256,
      );
      final clientSyncRequest = P2pSnapshotSyncRequest(
        requestId: "client-sync-request-0001",
        projectUuid: projectUuid,
        revisionId: clientManifest.revisionId,
        contentSha256: clientManifest.contentSha256,
      );
      server.updateLocalSnapshotSyncRequest(serverSyncRequest);
      client.updateLocalSnapshotSyncRequest(clientSyncRequest);
      await server.start(port: port);
      await client.start(port: clientPort);
      final inbound = server.inboundRevisionSummaries.first;

      final response = await client.negotiateRevisionSummary(
        P2pEndpoint(host: InternetAddress.loopbackIPv4.address, port: port),
        clientSummary,
      );

      expect(response.summary.toJson(), serverSummary.toJson());
      expect(response.remoteServicePort, port);
      expect(response.headManifest, serverManifest);
      expect(response.syncRequest, serverSyncRequest);
      final inboundExchange = await inbound;
      expect(inboundExchange.summary.toJson(), clientSummary.toJson());
      expect(inboundExchange.remoteServicePort, clientPort);
      expect(inboundExchange.headManifest, clientManifest);
      expect(inboundExchange.syncRequest, clientSyncRequest);
      expect(
        await client.negotiateSnapshotManifest(
          P2pEndpoint(host: InternetAddress.loopbackIPv4.address, port: port),
          projectUuid: projectUuid,
          revisionId: serverRevision.revisionId,
        ),
        serverManifest,
      );
    },
  );

  test("authenticated endpoint exchanges realtime operation batches", () async {
    final reservation = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final port = reservation.port;
    await reservation.close();
    final server = IoP2pEndpointService();
    final client = IoP2pEndpointService();
    addTearDown(server.dispose);
    addTearDown(client.dispose);
    final keys = _testSessionKeys();
    server.installAuthenticatedSession(keys.server);
    client.installAuthenticatedSession(keys.client);
    const projectUuid = "323e4567-e89b-12d3-a456-426614174000";
    final offer = P2pProjectOffer.project(
      projectUuid: projectUuid,
      fileName: "realtime.mnproj",
    );
    server.updateLocalProjectOffer(offer);
    client.updateLocalProjectOffer(offer);
    final serverDocument = CollaborationDocument.seeded(
      projectUuid: projectUuid,
      replicaId: keys.server.localDeviceId,
      chapterTexts: const <String, String>{"chapter-1": "a"},
    ).createLocalTextEdit(documentId: "chapter-1", nextText: "as");
    final clientDocument = CollaborationDocument.seeded(
      projectUuid: projectUuid,
      replicaId: keys.client.localDeviceId,
      chapterTexts: const <String, String>{"chapter-1": "a"},
    ).createLocalTextEdit(documentId: "chapter-1", nextText: "ac");
    final serverChapter = serverDocument.chapter("chapter-1")!;
    final serverBatch = serverDocument.buildBatch(
      remoteAcknowledgedSequences: const <String, int>{},
      presence: CollaboratorPresence(
        replicaId: keys.server.localDeviceId,
        ipAddress: "192.168.1.10",
        target: ChapterTextCursorTarget(
          chapterId: "chapter-1",
          anchor: serverChapter.anchorAtOffset(2),
          focus: serverChapter.anchorAtOffset(2),
        ),
        presenceSequence: 1,
        sentAtEpochMs: 1,
      ),
    );
    final clientBatch = clientDocument.buildBatch(
      remoteAcknowledgedSequences: const <String, int>{},
    );
    server.updateLocalCollaborationBatch(serverBatch);
    client.updateLocalCollaborationBatch(clientBatch);
    await server.start(port: port);
    final inbound = server.inboundCollaborationBatches.first;

    final response = await client.negotiateCollaborationBatch(
      P2pEndpoint(host: InternetAddress.loopbackIPv4.address, port: port),
      clientBatch,
    );

    expect(response.operations, hasLength(1));
    expect(response.presence?.ipAddress, InternetAddress.loopbackIPv4.address);
    final received = await inbound;
    expect(received.batch.operations, hasLength(1));
    expect(received.batch.senderReplicaId, keys.client.localDeviceId);
    expect(jsonEncode(response.toJson()), isNot(contains("xmlContent")));
  });

  test("authenticated collaboration stream pushes batches both ways", () async {
    final reservation = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final port = reservation.port;
    await reservation.close();
    final server = IoP2pEndpointService();
    final client = IoP2pEndpointService();
    addTearDown(server.dispose);
    addTearDown(client.dispose);
    final keys = _testSessionKeys();
    server.installAuthenticatedSession(keys.server);
    client.installAuthenticatedSession(keys.client);
    const projectUuid = "323e4567-e89b-12d3-a456-426614174000";
    final offer = P2pProjectOffer.project(
      projectUuid: projectUuid,
      fileName: "stream.mnproj",
    );
    server.updateLocalProjectOffer(offer);
    client.updateLocalProjectOffer(offer);
    final serverDocument = CollaborationDocument.seeded(
      projectUuid: projectUuid,
      replicaId: keys.server.localDeviceId,
      chapterTexts: const <String, String>{"chapter-1": "a"},
    ).createLocalTextEdit(documentId: "chapter-1", nextText: "as");
    final clientDocument = CollaborationDocument.seeded(
      projectUuid: projectUuid,
      replicaId: keys.client.localDeviceId,
      chapterTexts: const <String, String>{"chapter-1": "a"},
    ).createLocalTextEdit(documentId: "chapter-1", nextText: "ac");
    server.updateLocalCollaborationBatch(
      serverDocument.buildBatch(
        remoteAcknowledgedSequences: const <String, int>{},
      ),
    );
    client.updateLocalCollaborationBatch(
      clientDocument.buildBatch(
        remoteAcknowledgedSequences: const <String, int>{},
      ),
    );
    await server.start(port: port);
    final serverInitial = server.inboundCollaborationBatches.first;
    final clientInitial = client.inboundCollaborationBatches.first;

    expect(
      await client.openCollaborationStream(
        P2pEndpoint(host: InternetAddress.loopbackIPv4.address, port: port),
      ),
      isTrue,
    );
    expect(client.hasActiveCollaborationStream, isTrue);
    expect(
      (await serverInitial.timeout(
        const Duration(seconds: 3),
      )).batch.senderReplicaId,
      keys.client.localDeviceId,
    );
    expect(
      (await clientInitial.timeout(
        const Duration(seconds: 3),
      )).batch.senderReplicaId,
      keys.server.localDeviceId,
    );

    final nextClientDocument = clientDocument.createLocalTextEdit(
      documentId: "chapter-1",
      nextText: "ac!",
    );
    final serverPush = server.inboundCollaborationBatches.firstWhere(
      (event) => event.batch.operations.length == 2,
    );
    client.updateLocalCollaborationBatch(
      nextClientDocument.buildBatch(
        remoteAcknowledgedSequences: const <String, int>{},
        presence: CollaboratorPresence(
          replicaId: keys.client.localDeviceId,
          ipAddress: "203.0.113.99",
          target: const ProjectFieldCursorTarget(
            fieldId: "baseInfo.toRecap",
            anchorOffset: 3,
            focusOffset: 3,
          ),
          presenceSequence: 2,
          sentAtEpochMs: 2,
        ),
      ),
    );
    final receivedByServer = await serverPush.timeout(
      const Duration(seconds: 3),
    );
    expect(receivedByServer.batch.senderReplicaId, keys.client.localDeviceId);
    expect(
      receivedByServer.batch.presence?.ipAddress,
      InternetAddress.loopbackIPv4.address,
    );
    expect(
      receivedByServer.batch.presence?.target,
      isA<ProjectFieldCursorTarget>(),
    );

    final nextServerDocument = serverDocument.createLocalTextEdit(
      documentId: "chapter-1",
      nextText: "as!",
    );
    final clientPush = client.inboundCollaborationBatches.firstWhere(
      (event) => event.batch.operations.length == 2,
    );
    server.updateLocalCollaborationBatch(
      nextServerDocument.buildBatch(
        remoteAcknowledgedSequences: const <String, int>{},
      ),
    );
    final receivedByClient = await clientPush.timeout(
      const Duration(seconds: 3),
    );
    expect(receivedByClient.batch.senderReplicaId, keys.server.localDeviceId);
  });

  test(
    "IO P2P endpoint exchanges bounded snapshot chunks only when explicitly enabled",
    () async {
      final reservation = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final port = reservation.port;
      await reservation.close();
      final server = IoP2pEndpointService();
      final client = IoP2pEndpointService();
      addTearDown(server.dispose);
      addTearDown(client.dispose);
      final keys = _testSessionKeys();
      server.installAuthenticatedSession(keys.server);
      client.installAuthenticatedSession(keys.client);
      const projectUuid = "323e4567-e89b-12d3-a456-426614174000";
      final revisionId = List<String>.filled(64, "b").join();
      final payload = utf8.encode(
        '<Project UUID="$projectUuid"><ver>1.0</ver><Data>'
        '${List<String>.filled(25000, "x").join()}'
        "</Data></Project>",
      );
      final manifest = P2pSnapshotManifest(
        projectUuid: projectUuid,
        revisionId: revisionId,
        contentSha256: _hex((await Sha256().hash(payload)).bytes),
        contentLength: payload.length,
        formatVersion: "1.0",
      );
      server.updateLocalSnapshotManifests(<P2pSnapshotManifest>[manifest]);
      server.configureSnapshotContentTransfer(
        enabled: true,
        loader: (requestedManifest, chunkIndex) async {
          final start = chunkIndex * requestedManifest.chunkSize;
          final end = (start + requestedManifest.chunkSize) < payload.length
              ? start + requestedManifest.chunkSize
              : payload.length;
          return P2pSnapshotChunk(
            projectUuid: requestedManifest.projectUuid,
            revisionId: requestedManifest.revisionId,
            chunkIndex: chunkIndex,
            chunkCount: requestedManifest.chunkCount,
            bytes: payload.sublist(start, end),
          );
        },
      );
      client.configureSnapshotContentTransfer(
        enabled: true,
        loader: (_, _) async => null,
      );
      await server.start(port: port);
      final endpoint = P2pEndpoint(
        host: InternetAddress.loopbackIPv4.address,
        port: port,
      );

      final quarantineRoot = await Directory.systemTemp.createTemp(
        "monogatari-p2p-wire-quarantine-",
      );
      addTearDown(() async {
        if (await quarantineRoot.exists()) {
          await quarantineRoot.delete(recursive: true);
        }
      });
      final quarantineStorage = FileSystemP2pSnapshotQuarantineStorage(
        baseDirectory: () async => quarantineRoot,
      );
      final coordinator = P2pSnapshotDownloadCoordinator(
        gateway: AuthenticatedP2pSnapshotChunkGateway(
          endpointService: client,
          endpoint: endpoint,
        ),
        quarantineStorage: quarantineStorage,
        retryDelay: (_) async {},
      );
      addTearDown(coordinator.dispose);
      addTearDown(quarantineStorage.dispose);

      final verified = await coordinator.download(manifest);

      expect(verified.xmlContent, utf8.decode(payload));
      expect(coordinator.progress, 1);

      final forgedManifest = P2pSnapshotManifest(
        projectUuid: manifest.projectUuid,
        revisionId: manifest.revisionId,
        contentSha256: List<String>.filled(64, "f").join(),
        contentLength: manifest.contentLength,
        formatVersion: manifest.formatVersion,
      );
      expect(
        await client.negotiateSnapshotChunk(
          endpoint,
          P2pSnapshotChunkRequest(manifest: forgedManifest, chunkIndex: 0),
        ),
        isNull,
      );
    },
  );

  test("authenticated endpoint exchanges revision graph pages", () async {
    final reservation = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final port = reservation.port;
    await reservation.close();
    final server = IoP2pEndpointService();
    final client = IoP2pEndpointService();
    addTearDown(server.dispose);
    addTearDown(client.dispose);
    final keys = _testSessionKeys();
    server.installAuthenticatedSession(keys.server);
    client.installAuthenticatedSession(keys.client);
    const projectUuid = "323e4567-e89b-12d3-a456-426614174000";
    final serverRevision = _testRevision(
      projectUuid: projectUuid,
      authorDeviceId: keys.server.localDeviceId,
      revisionHex: "b",
      contentHex: "c",
    );
    final clientRevision = _testRevision(
      projectUuid: projectUuid,
      authorDeviceId: keys.client.localDeviceId,
      revisionHex: "d",
      contentHex: "e",
    );
    final serverGraph = P2pRevisionGraph.empty(
      projectUuid,
    ).append(serverRevision);
    final clientGraph = P2pRevisionGraph.empty(
      projectUuid,
    ).append(clientRevision);
    server.updateLocalRevisionGraph(serverGraph);
    client.updateLocalRevisionGraph(clientGraph);
    await server.start(port: port);
    final inbound = server.inboundRevisionGraphs.first;

    final exchange = await client.negotiateRevisionGraphPage(
      P2pEndpoint(host: InternetAddress.loopbackIPv4.address, port: port),
      localPageIndex: 0,
      remotePageIndex: 0,
    );

    expect(exchange.acknowledgedLocalPageIndex, 0);
    expect(
      exchange.remotePage.revisions.single.revisionId,
      serverRevision.revisionId,
    );
    expect(
      (await inbound).graph.singleHead?.revisionId,
      clientRevision.revisionId,
    );
  });

  test(
    "resolution ACK is exchanged only inside revision summary frame",
    () async {
      final reservation = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final port = reservation.port;
      await reservation.close();
      final server = IoP2pEndpointService();
      final client = IoP2pEndpointService();
      addTearDown(server.dispose);
      addTearDown(client.dispose);
      final keys = _testSessionKeys();
      server.installAuthenticatedSession(keys.server);
      client.installAuthenticatedSession(keys.client);
      const projectUuid = "323e4567-e89b-12d3-a456-426614174000";
      final parentA = _testRevision(
        projectUuid: projectUuid,
        authorDeviceId: keys.server.localDeviceId,
        revisionHex: "a",
        contentHex: "1",
      );
      final parentB = _testRevision(
        projectUuid: projectUuid,
        authorDeviceId: keys.client.localDeviceId,
        revisionHex: "b",
        contentHex: "2",
      );
      final resolution = P2pRevisionMetadata(
        revisionId: List<String>.filled(64, "c").join(),
        projectUuid: projectUuid,
        parents: <String>[parentA.revisionId, parentB.revisionId],
        clock: P2pVersionVector(<String, int>{
          keys.server.localDeviceId: 2,
          keys.client.localDeviceId: 1,
        }),
        authorDeviceId: keys.server.localDeviceId,
        createdAtEpochSeconds: 2,
        contentSha256: List<String>.filled(64, "3").join(),
        formatVersion: "1.0",
      );
      final graph = P2pRevisionGraph.empty(
        projectUuid,
      ).append(parentA).append(parentB).append(resolution);
      final serverSummary = P2pRevisionSummary.fromGraph(graph);
      final clientSummary = P2pRevisionSummary(
        projectUuid: projectUuid,
        heads: const <P2pRevisionMetadata>[],
      );
      final ack = P2pResolutionAck(
        projectUuid: projectUuid,
        resolutionRevisionId: resolution.revisionId,
        contentSha256: resolution.contentSha256,
        acceptedByDeviceId: keys.server.localDeviceId,
        acceptedAtEpochSeconds: 3,
      );
      server.updateLocalRevisionGraph(graph);
      server.updateLocalResolutionAck(ack);
      server.updateLocalRevisionSummary(serverSummary);
      client.updateLocalRevisionSummary(clientSummary);
      await server.start(port: port);

      final response = await client.negotiateRevisionSummary(
        P2pEndpoint(host: InternetAddress.loopbackIPv4.address, port: port),
        clientSummary,
      );

      expect(
        response.resolutionAck?.resolutionRevisionId,
        resolution.revisionId,
      );
      expect(
        response.resolutionAck?.acceptedByDeviceId,
        keys.server.localDeviceId,
      );
    },
  );

  test("snapshot chunk transport is disabled by default", () async {
    final service = IoP2pEndpointService();
    addTearDown(service.dispose);
    final keys = _testSessionKeys();
    service.installAuthenticatedSession(keys.client);
    addTearDown(keys.server.destroy);
    final manifest = P2pSnapshotManifest(
      projectUuid: "323e4567-e89b-12d3-a456-426614174000",
      revisionId: List<String>.filled(64, "b").join(),
      contentSha256: List<String>.filled(64, "c").join(),
      contentLength: 1,
      formatVersion: "1.0",
    );

    await expectLater(
      service.negotiateSnapshotChunk(
        const P2pEndpoint(host: "127.0.0.1", port: 42942),
        P2pSnapshotChunkRequest(manifest: manifest, chunkIndex: 0),
      ),
      throwsStateError,
    );
  });

  test("snapshot chunk client rejects an encrypted mismatched ACK", () async {
    const prefix = "MONOGATARI_P2P_SECURE/1 ";
    final keys = _testSessionKeys();
    final serverChannel = P2pSecureChannel(keys.server);
    addTearDown(serverChannel.destroy);
    final gateway = _FakeAndroidProbeGateway();
    final client = IoP2pEndpointService(androidProbeGateway: gateway);
    addTearDown(client.dispose);
    client.installAuthenticatedSession(keys.client);
    client.configureSnapshotContentTransfer(
      enabled: true,
      loader: (_, _) async => null,
    );
    final manifest = P2pSnapshotManifest(
      projectUuid: "323e4567-e89b-12d3-a456-426614174000",
      revisionId: List<String>.filled(64, "b").join(),
      contentSha256: List<String>.filled(64, "c").join(),
      contentLength: P2pSnapshotManifest.chunkSizeBytes + 1,
      formatVersion: "1.0",
    );
    gateway.exchangeHandler = (requestLine) async {
      final requestFrame = P2pEncryptedFrame.fromJson(
        jsonDecode(requestLine.substring(prefix.length))
            as Map<String, Object?>,
      );
      final clearRequest = await serverChannel.decryptJson(requestFrame);
      final responseFrame = await serverChannel.encryptJson(<String, Object?>{
        "type": "snapshotChunkResponse",
        "requestId": clearRequest["requestId"],
        "available": false,
        "ack": P2pSnapshotChunkAck(
          projectUuid: manifest.projectUuid,
          revisionId: manifest.revisionId,
          contentSha256: manifest.contentSha256,
          chunkIndex: 1,
        ).toJson(),
      });
      return "$prefix${jsonEncode(responseFrame.toJson())}";
    };

    await expectLater(
      client.negotiateSnapshotChunk(
        const P2pEndpoint(host: "192.168.1.20", port: 42942),
        P2pSnapshotChunkRequest(manifest: manifest, chunkIndex: 0),
      ),
      throwsFormatException,
    );
  });

  test("Android snapshot chunks share one Wi-Fi-bound TCP exchange", () async {
    const prefix = "MONOGATARI_P2P_SECURE/1 ";
    final keys = _testSessionKeys();
    final serverChannel = P2pSecureChannel(keys.server);
    addTearDown(serverChannel.destroy);
    final gateway = _FakeAndroidProbeGateway();
    final client = IoP2pEndpointService(androidProbeGateway: gateway);
    addTearDown(client.dispose);
    client.installAuthenticatedSession(keys.client);
    client.configureSnapshotContentTransfer(
      enabled: true,
      loader: (_, _) async => null,
    );
    final manifest = P2pSnapshotManifest(
      projectUuid: "323e4567-e89b-12d3-a456-426614174000",
      revisionId: List<String>.filled(64, "b").join(),
      contentSha256: List<String>.filled(64, "c").join(),
      contentLength: P2pSnapshotManifest.chunkSizeBytes + 1,
      formatVersion: "1.0",
    );
    gateway.exchangeHandler = (requestLine) async {
      final requestFrame = P2pEncryptedFrame.fromJson(
        jsonDecode(requestLine.substring(prefix.length))
            as Map<String, Object?>,
      );
      final clearRequest = await serverChannel.decryptJson(requestFrame);
      final requestPayload = clearRequest["request"]! as Map;
      final request = P2pSnapshotChunkRequest.fromJson(
        requestPayload.map((key, value) => MapEntry(key.toString(), value)),
      );
      final chunk = P2pSnapshotChunk(
        projectUuid: manifest.projectUuid,
        revisionId: manifest.revisionId,
        chunkIndex: request.chunkIndex,
        chunkCount: manifest.chunkCount,
        bytes: List<int>.filled(
          request.chunkIndex == 0 ? P2pSnapshotManifest.chunkSizeBytes : 1,
          request.chunkIndex + 1,
        ),
      );
      final responseFrame = await serverChannel.encryptJson(<String, Object?>{
        "type": "snapshotChunkResponse",
        "requestId": clearRequest["requestId"],
        "available": true,
        "ack": P2pSnapshotChunkAck(
          projectUuid: manifest.projectUuid,
          revisionId: manifest.revisionId,
          contentSha256: manifest.contentSha256,
          chunkIndex: request.chunkIndex,
        ).toJson(),
        "chunk": chunk.toJson(),
      });
      return "$prefix${jsonEncode(responseFrame.toJson())}";
    };

    final chunks = await client.negotiateSnapshotChunks(
      const P2pEndpoint(host: "192.168.1.20", port: 42942),
      <P2pSnapshotChunkRequest>[
        P2pSnapshotChunkRequest(manifest: manifest, chunkIndex: 0),
        P2pSnapshotChunkRequest(manifest: manifest, chunkIndex: 1),
      ],
    );

    expect(chunks.map((chunk) => chunk?.chunkIndex), <int?>[0, 1]);
    expect(gateway.multiLineCallCount, 1);
    expect(gateway.callCount, 1);
  });

  test(
    "snapshot gateway adapts its batch window to response pressure",
    () async {
      const prefix = "MONOGATARI_P2P_SECURE/1 ";
      final keys = _testSessionKeys();
      final serverChannel = P2pSecureChannel(keys.server);
      addTearDown(serverChannel.destroy);
      final androidGateway = _FakeAndroidProbeGateway();
      final client = IoP2pEndpointService(androidProbeGateway: androidGateway);
      addTearDown(client.dispose);
      client.installAuthenticatedSession(keys.client);
      client.configureSnapshotContentTransfer(
        enabled: true,
        loader: (_, _) async => null,
      );
      final manifest = P2pSnapshotManifest(
        projectUuid: "323e4567-e89b-12d3-a456-426614174000",
        revisionId: List<String>.filled(64, "d").join(),
        contentSha256: List<String>.filled(64, "e").join(),
        contentLength: P2pSnapshotManifest.chunkSizeBytes * 5 + 1,
        formatVersion: "1.0",
      );
      final gateway = AuthenticatedP2pSnapshotChunkGateway(
        endpointService: client,
        endpoint: const P2pEndpoint(host: "192.168.1.20", port: 42942),
        initialBatchSize: 4,
        maxBatchSize: 8,
      );

      androidGateway.error = const P2pAndroidProbeException(
        failure: P2pAndroidProbeFailure.connect,
        message: "connect failed",
      );
      await expectLater(
        gateway.requestChunk(manifest, 0),
        throwsA(
          isA<P2pSnapshotChunkTransportException>().having(
            (error) => error.isTransient,
            "isTransient",
            isTrue,
          ),
        ),
      );
      expect(gateway.currentBatchSize, 4);

      androidGateway.error = const P2pAndroidProbeException(
        failure: P2pAndroidProbeFailure.response,
        message: "response timeout",
      );
      await expectLater(
        gateway.requestChunk(manifest, 0),
        throwsA(isA<P2pSnapshotChunkTransportException>()),
      );
      expect(gateway.currentBatchSize, 2);

      androidGateway.error = null;
      androidGateway.exchangeHandler = (requestLine) async {
        final requestFrame = P2pEncryptedFrame.fromJson(
          jsonDecode(requestLine.substring(prefix.length))
              as Map<String, Object?>,
        );
        final clearRequest = await serverChannel.decryptJson(requestFrame);
        final requestPayload = clearRequest["request"]! as Map;
        final request = P2pSnapshotChunkRequest.fromJson(
          requestPayload.map((key, value) => MapEntry(key.toString(), value)),
        );
        final start = request.chunkIndex * manifest.chunkSize;
        final remaining = manifest.contentLength - start;
        final length = remaining < manifest.chunkSize
            ? remaining
            : manifest.chunkSize;
        final chunk = P2pSnapshotChunk(
          projectUuid: manifest.projectUuid,
          revisionId: manifest.revisionId,
          chunkIndex: request.chunkIndex,
          chunkCount: manifest.chunkCount,
          bytes: List<int>.filled(length, request.chunkIndex + 1),
        );
        final responseFrame = await serverChannel.encryptJson(<String, Object?>{
          "type": "snapshotChunkResponse",
          "requestId": clearRequest["requestId"],
          "available": true,
          "ack": P2pSnapshotChunkAck(
            projectUuid: manifest.projectUuid,
            revisionId: manifest.revisionId,
            contentSha256: manifest.contentSha256,
            chunkIndex: request.chunkIndex,
          ).toJson(),
          "chunk": chunk.toJson(),
        });
        return "$prefix${jsonEncode(responseFrame.toJson())}";
      };

      expect((await gateway.requestChunk(manifest, 0)).chunkIndex, 0);
      expect(gateway.currentBatchSize, 2);
      expect((await gateway.requestChunk(manifest, 1)).chunkIndex, 1);
      expect(androidGateway.multiLineCallCount, 3);
      expect((await gateway.requestChunk(manifest, 2)).chunkIndex, 2);
      expect(gateway.currentBatchSize, 4);
      expect(androidGateway.multiLineCallCount, 4);
    },
  );

  test("production snapshot capability validates and revokes its session", () {
    final controller = P2pSnapshotTransferSessionController();
    const endpoint = P2pEndpoint(host: "192.168.1.20", port: 42942);
    const projectUuid = "323e4567-e89b-12d3-a456-426614174000";
    final manifest = P2pSnapshotManifest(
      projectUuid: projectUuid,
      revisionId: List<String>.filled(64, "a").join(),
      contentSha256: List<String>.filled(64, "b").join(),
      contentLength: 1,
      formatVersion: "1.0",
    );

    final authorization = controller.authorize(
      endpoint: endpoint,
      projectUuid: projectUuid,
      remoteManifest: manifest,
    );
    expect(controller.current, same(authorization));
    expect(
      controller.authorize(
        endpoint: endpoint,
        projectUuid: projectUuid,
        remoteManifest: manifest,
      ),
      same(authorization),
    );
    expect(controller.isCurrent(authorization), isTrue);

    controller.revoke();
    expect(controller.current, isNull);
    expect(controller.isCurrent(authorization), isFalse);
    expect(
      () => controller.authorize(
        endpoint: const P2pEndpoint(host: "8.8.8.8", port: 42942),
        projectUuid: projectUuid,
        remoteManifest: manifest,
      ),
      throwsFormatException,
    );
  });

  test("revision summary exchange has no unauthenticated fallback", () async {
    final service = IoP2pEndpointService();
    addTearDown(service.dispose);
    final summary = P2pRevisionSummary(
      projectUuid: "323e4567-e89b-12d3-a456-426614174000",
      heads: const <P2pRevisionMetadata>[],
    );
    service.updateLocalRevisionSummary(summary);

    expect(
      () => service.negotiateRevisionSummary(
        const P2pEndpoint(host: "127.0.0.1", port: 42942),
        summary,
      ),
      throwsStateError,
    );
    expect(
      () => service.negotiateSnapshotManifest(
        const P2pEndpoint(host: "127.0.0.1", port: 42942),
        projectUuid: summary.projectUuid,
        revisionId: List<String>.filled(64, "a").join(),
      ),
      throwsStateError,
    );
    service.configureSnapshotContentTransfer(
      enabled: true,
      loader: (_, _) async => null,
    );
    final manifest = P2pSnapshotManifest(
      projectUuid: summary.projectUuid,
      revisionId: List<String>.filled(64, "a").join(),
      contentSha256: List<String>.filled(64, "b").join(),
      contentLength: 1,
      formatVersion: "1.0",
    );
    expect(
      () => service.negotiateSnapshotChunk(
        const P2pEndpoint(host: "127.0.0.1", port: 42942),
        P2pSnapshotChunkRequest(manifest: manifest, chunkIndex: 0),
      ),
      throwsStateError,
    );
  });

  test("IO P2P endpoint rejects an unrelated TCP service", () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((socket) {
      socket.write("not-monogatari\n");
      socket.destroy();
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close();
    });

    final service = IoP2pEndpointService();
    addTearDown(service.dispose);
    expect(
      () => service.probe(
        P2pEndpoint(
          host: InternetAddress.loopbackIPv4.address,
          port: server.port,
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test("IO P2P endpoint classifies a missing probe response", () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((socket) {
      socket.listen((_) {});
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close();
    });

    final service = IoP2pEndpointService();
    addTearDown(service.dispose);
    await expectLater(
      service.probe(
        P2pEndpoint(
          host: InternetAddress.loopbackIPv4.address,
          port: server.port,
        ),
        timeout: const Duration(milliseconds: 100),
      ),
      throwsA(
        isA<P2pProbeException>().having(
          (error) => error.stage,
          "stage",
          P2pProbeFailureStage.response,
        ),
      ),
    );
  });

  test("IO P2P endpoint closes only after its response is readable", () async {
    final reservation = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final port = reservation.port;
    await reservation.close();

    final service = IoP2pEndpointService();
    addTearDown(service.dispose);
    await service.start(port: port);

    final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
    socket.add(utf8.encode("MONOGATARI_P2P_PROBE/1\n"));
    await socket.flush();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final response = await utf8.decoder.bind(socket).join();

    expect(response, "MONOGATARI_P2P_REACHABLE/1\n");
  });

  test("Android P2P probe is delegated to a Wi-Fi-bound socket", () async {
    final gateway = _FakeAndroidProbeGateway();
    final service = IoP2pEndpointService(androidProbeGateway: gateway);
    addTearDown(service.dispose);

    await service.probe(const P2pEndpoint(host: "192.168.1.20", port: 42942));

    expect(gateway.callCount, 1);
  });

  test("Android response timeout keeps its probe stage", () async {
    final gateway = _FakeAndroidProbeGateway()
      ..error = const P2pAndroidProbeException(
        failure: P2pAndroidProbeFailure.response,
        message: "response timeout",
      );
    final service = IoP2pEndpointService(androidProbeGateway: gateway);
    addTearDown(service.dispose);

    await expectLater(
      service.probe(const P2pEndpoint(host: "192.168.1.20", port: 42942)),
      throwsA(
        isA<P2pProbeException>().having(
          (error) => error.stage,
          "stage",
          P2pProbeFailureStage.response,
        ),
      ),
    );
  });
}
