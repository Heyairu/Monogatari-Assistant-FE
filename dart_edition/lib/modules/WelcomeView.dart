/************************************************************
 * 
 * Copyright 2025-2026 Heyairu（部屋伊琉）
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * 
 ************************************************************/

import "dart:async";
import "dart:convert";
import "dart:math";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter/services.dart";
import "package:url_launcher/url_launcher.dart";
import "../bin/ui_library.dart";
import "../bin/settings_manager.dart";
import "../data/p2p/p2p_secure_channel.dart";
import "../data/p2p/p2p_snapshot_quarantine.dart";
import "../domain/models/p2p_sync_models.dart";
import "../domain/models/p2p_pairing_models.dart";
import "../domain/models/p2p_revision_models.dart";
import "../domain/models/p2p_snapshot_models.dart";
import "../presentation/providers/global_state_providers.dart";
import "../presentation/providers/p2p_sync_providers.dart";

class WelcomeView extends ConsumerStatefulWidget {
  const WelcomeView({
    super.key,
    this.onNewProject,
    this.onOpenProject,
    this.recentProjects,
    this.onOpenRecentProject,
    this.onDeleteRecentProject,
    this.localP2pProject,
    this.onSaveProject,
    this.onSaveProjectAs,
    this.onChooseSyncProject,
    this.onApplyVerifiedP2pSnapshot,
    this.onResolveConcurrentP2pSnapshot,
  });

  final Future<void> Function()? onNewProject;
  final Future<void> Function()? onOpenProject;
  final List<RecentProjectEntry>? recentProjects;
  final Future<void> Function(RecentProjectEntry entry)? onOpenRecentProject;
  final Future<void> Function(RecentProjectEntry entry)? onDeleteRecentProject;
  final P2pProjectStatus? localP2pProject;
  final Future<void> Function()? onSaveProject;
  final Future<void> Function()? onSaveProjectAs;
  final Future<void> Function()? onChooseSyncProject;
  final Future<bool> Function(P2pVerifiedSnapshot snapshot)?
  onApplyVerifiedP2pSnapshot;
  final Future<bool> Function(P2pVerifiedSnapshot snapshot)?
  onResolveConcurrentP2pSnapshot;

  @override
  ConsumerState<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends ConsumerState<WelcomeView> {
  static const String _didYouKnowAssetPath = "assets/jsons/didyouknow.json";
  static const String _eastAsiaNameAssetPath =
      "assets/jsons/name_eastAsia.json";
  static const _DidYouKnowData _fallbackDidYouKnowData = _DidYouKnowData(
    content: "中國最偉大、最永久的藝術，就是男人扮女人",
    source: "—— 魯迅（1881-1936）",
  );
  static final Uri _projectRepoUri = Uri.parse(
    "https://github.com/heyairu/Monogatari-Assistant-FE",
  );
  static final Uri _KadoURL = Uri.parse(
    "https://www.kadokado.com.tw/user/167702",
  );
  static final Uri _KoFiURL = Uri.parse("https://ko-fi.com/heyairu");
  static final Random _random = Random();

  late Future<_DidYouKnowData> _didYouKnowFuture;
  Map<String, dynamic>? _eastAsiaNameData;
  bool _isGeneratingNames = false;
  String _selectedLanguage = "JP";
  String _selectedGender = "female";
  int _generateCount = 5;
  List<String> _generatedNames = const [];
  final TextEditingController _localPortController = TextEditingController(
    text: "$defaultP2pPort",
  );
  final TextEditingController _peerIpController = TextEditingController();
  final TextEditingController _peerPortController = TextEditingController(
    text: "$defaultP2pPort",
  );
  String? _localPortError;
  String? _peerIpError;
  String? _peerPortError;
  int _lastHandledNegotiationGeneration = 0;
  int _lastHandledSnapshotSyncRequestGeneration = 0;
  Future<void>? _immediateP2pSyncOperation;
  bool _negotiationDialogVisible = false;
  BuildContext? _negotiationDialogContext;

  @override
  void initState() {
    super.initState();
    _didYouKnowFuture = _loadDidYouKnowData();
    _scheduleLocalProjectOfferUpdate();
  }

  @override
  void didUpdateWidget(covariant WelcomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleLocalProjectOfferUpdate();
  }

  @override
  void dispose() {
    _localPortController.dispose();
    _peerIpController.dispose();
    _peerPortController.dispose();
    super.dispose();
  }

  void _reloadDidYouKnow() {
    setState(() {
      _didYouKnowFuture = _loadDidYouKnowData();
    });
  }

  void _scheduleLocalProjectOfferUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(p2pSyncProvider.notifier)
          .updateLocalProjectStatus(widget.localP2pProject);
    });
  }

  Future<_DidYouKnowData> _loadDidYouKnowData() async {
    try {
      final String rawJson = await rootBundle.loadString(_didYouKnowAssetPath);
      if (rawJson.trim().isEmpty) {
        return _fallbackDidYouKnowData;
      }

      final dynamic decoded = jsonDecode(rawJson);
      final List<_DidYouKnowData> candidates = [];

      void collectFromList(List<dynamic> list) {
        for (final dynamic item in list) {
          if (item is Map<String, dynamic>) {
            final _DidYouKnowData? parsed = _parseDidYouKnowMap(item);
            if (parsed != null) {
              candidates.add(parsed);
            }
          }
        }
      }

      if (decoded is Map<String, dynamic>) {
        final _DidYouKnowData? fromDirectMap = _parseDidYouKnowMap(decoded);
        if (fromDirectMap != null) {
          candidates.add(fromDirectMap);
        }

        final dynamic items = decoded["items"];
        if (items is List) {
          collectFromList(items);
        }
      }

      if (decoded is List) {
        collectFromList(decoded);
      }

      if (candidates.isNotEmpty) {
        final int randomIndex = _random.nextInt(candidates.length);
        return candidates[randomIndex];
      }
    } catch (error) {
      debugPrint("Failed to load Did You Know JSON: $error");
    }

    return _fallbackDidYouKnowData;
  }

  _DidYouKnowData? _parseDidYouKnowMap(Map<String, dynamic> map) {
    final dynamic content = map["content"];
    final dynamic source = map["source"];
    if (content is String &&
        content.trim().isNotEmpty &&
        source is String &&
        source.trim().isNotEmpty) {
      return _DidYouKnowData(content: content, source: source);
    }
    return null;
  }

  Future<void> _ensureEastAsiaNameDataLoaded() async {
    if (_eastAsiaNameData != null) {
      return;
    }

    final String rawJson = await rootBundle.loadString(_eastAsiaNameAssetPath);
    final dynamic decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException("Invalid East Asia name JSON format");
    }
    _eastAsiaNameData = decoded;
  }

  List<String> _extractSurnamePool(String languageCode) {
    if (_eastAsiaNameData == null) {
      return const [];
    }

    if (languageCode == "ZH" || languageCode == "KR") {
      final String key = languageCode == "ZH" ? "Surname_ZH" : "Surname_KR";
      final dynamic raw = _eastAsiaNameData![key];
      if (raw is List) {
        return raw.whereType<String>().where((s) => s.isNotEmpty).toList();
      }
      return const [];
    }

    if (languageCode == "JP") {
      final dynamic raw = _eastAsiaNameData!["Surname_JP"];
      if (raw is! List || raw.isEmpty || raw.first is! Map<String, dynamic>) {
        return const [];
      }

      final Map<String, dynamic> grouped = raw.first as Map<String, dynamic>;
      final List<String> flattened = [];
      for (final dynamic value in grouped.values) {
        if (value is List) {
          flattened.addAll(
            value.whereType<String>().where((s) => s.isNotEmpty).toList(),
          );
        }
      }
      return flattened;
    }

    return const [];
  }

  List<String> _extractGivenNamePool(String languageCode, String genderCode) {
    if (_eastAsiaNameData == null) {
      return const [];
    }

    List<String> collectPoolByRootKey(String rootKey) {
      final dynamic raw = _eastAsiaNameData![rootKey];
      if (raw is! List || raw.isEmpty || raw.first is! Map<String, dynamic>) {
        return const [];
      }

      final Map<String, dynamic> grouped = raw.first as Map<String, dynamic>;
      final List<String> pool = [];

      for (final dynamic value in grouped.values) {
        if (value is! List ||
            value.isEmpty ||
            value.first is! Map<String, dynamic>) {
          continue;
        }

        final Map<String, dynamic> namesByLanguage =
            value.first as Map<String, dynamic>;
        for (final MapEntry<String, dynamic> entry in namesByLanguage.entries) {
          final dynamic languages = entry.value;
          if (languages is List &&
              languages.whereType<String>().contains(languageCode)) {
            pool.add(entry.key);
          }
        }
      }

      return pool;
    }

    if (genderCode == "male") {
      return collectPoolByRootKey("Name_Man");
    }

    if (genderCode == "all" || genderCode == "neutral") {
      return <String>{
        ...collectPoolByRootKey("Name_Lady"),
        ...collectPoolByRootKey("Name_Man"),
      }.toList();
    }

    return collectPoolByRootKey("Name_Lady");
  }

  Future<void> _generateNames() async {
    setState(() {
      _isGeneratingNames = true;
    });

    try {
      await _ensureEastAsiaNameDataLoaded();

      final List<String> surnamePool = _extractSurnamePool(_selectedLanguage);
      final List<String> givenNamePool = _extractGivenNamePool(
        _selectedLanguage,
        _selectedGender,
      );
      if (surnamePool.isEmpty || givenNamePool.isEmpty) {
        throw const FormatException("Name data pool is empty");
      }

      final List<String> results = List<String>.generate(_generateCount, (_) {
        final String surname = surnamePool[_random.nextInt(surnamePool.length)];
        final String given =
            givenNamePool[_random.nextInt(givenNamePool.length)];
        return "$surname$given";
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _generatedNames = results;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppFeedback.error(context, "載入姓名資料失敗，請稍後再試。");
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isGeneratingNames = false;
      });
    }
  }

  Future<void> _copyGeneratedNames() async {
    if (_generatedNames.isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: _generatedNames.join("\n")));
    if (!mounted) {
      return;
    }
    AppFeedback.success(context, "已複製姓名結果");
  }

  Future<void> _handleNewProject() async {
    final onNewProject = widget.onNewProject;
    if (onNewProject == null) {
      _showMessage("目前尚未連接新建專案功能");
      return;
    }

    await onNewProject();
  }

  Future<void> _handleOpenProject() async {
    final onOpenProject = widget.onOpenProject;
    if (onOpenProject == null) {
      _showMessage("目前尚未連接開啟檔案功能");
      return;
    }

    await onOpenProject();
  }

  Future<void> _handleOpenRecentProject(RecentProjectEntry entry) async {
    final onOpenRecentProject = widget.onOpenRecentProject;
    if (onOpenRecentProject == null) {
      _showMessage("目前尚未連接最近檔案功能");
      return;
    }

    await onOpenRecentProject(entry);
  }

  Future<void> _handleDeleteRecentProject(RecentProjectEntry entry) async {
    final onDeleteRecentProject = widget.onDeleteRecentProject;
    if (onDeleteRecentProject == null) {
      _showMessage("目前尚未連接刪除最近檔案功能");
      return;
    }

    await onDeleteRecentProject(entry);
  }

  Future<void> _handleToggleP2pService() async {
    final notifier = ref.read(p2pSyncProvider.notifier);
    final state = ref.read(p2pSyncProvider);
    if (state.isListening) {
      await notifier.stopService();
      return;
    }

    final port = P2pEndpoint.parsePort(_localPortController.text);
    setState(() {
      _localPortError = port == null ? "Port 必須是 1–65535 的整數" : null;
    });
    if (port == null) return;
    notifier.updateLocalProjectStatus(widget.localP2pProject);
    await notifier.startService(port);
  }

  Future<void> _handleP2pConnect() async {
    final host = _peerIpController.text.trim();
    final port = P2pEndpoint.parsePort(_peerPortController.text);
    final endpoint = P2pEndpoint.tryParse(
      host: host,
      port: _peerPortController.text,
    );
    setState(() {
      _peerIpError = P2pEndpoint.isPrivateIpv4(host)
          ? null
          : "請輸入有效的內網 IPv4 位址";
      _peerPortError = port == null ? "Port 必須是 1–65535 的整數" : null;
    });
    if (endpoint == null) return;

    await ref
        .read(p2pSyncProvider.notifier)
        .connectAndNegotiate(endpoint, widget.localP2pProject);
  }

  Future<void> _showP2pNegotiationDialog(P2pSyncState state) async {
    if (_negotiationDialogVisible || !mounted) return;
    final negotiation = state.projectNegotiation;
    final remote = state.remoteProjectOffer;
    if (negotiation == null || remote == null || !negotiation.requiresDialog) {
      return;
    }

    _negotiationDialogVisible = true;
    try {
      final local = state.localProjectOffer;
      final bothMissing =
          negotiation.selectionReason == P2pProjectSelectionReason.bothMissing;
      final action = await showDialog<_P2pSelectionAction>(
        context: context,
        builder: (dialogContext) {
          _negotiationDialogContext = dialogContext;
          return AlertDialog(
            title: Text(bothMissing ? "雙方都沒有同步文件" : "同步文件不同"),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bothMissing
                        ? "本機與對方都沒有記憶體中的目標專案；建立新專案後即可直接協作，不必先儲存檔案。"
                        : "雙方的 Project UUID 不同，請決定本次同步應採用哪一份文件。",
                  ),
                  if (!bothMissing) ...[
                    const SizedBox(height: 16),
                    _buildP2pOfferPreview("本機", local),
                    const SizedBox(height: 8),
                    _buildP2pOfferPreview("對方", remote),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text("取消"),
              ),
              if (bothMissing)
                FilledButton(
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).pop(_P2pSelectionAction.prepareLocal),
                  child: const Text("建立本機專案"),
                )
              else ...[
                if (widget.onChooseSyncProject != null ||
                    widget.onOpenProject != null)
                  TextButton(
                    onPressed: () => Navigator.of(
                      dialogContext,
                    ).pop(_P2pSelectionAction.chooseOther),
                    child: const Text("開啟其他文件"),
                  ),
                OutlinedButton(
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).pop(_P2pSelectionAction.remote),
                  child: const Text("使用對方文件"),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(
                    dialogContext,
                  ).pop(_P2pSelectionAction.local),
                  child: const Text("使用本機文件"),
                ),
              ],
            ],
          );
        },
      );
      if (!mounted || action == null) return;
      switch (action) {
        case _P2pSelectionAction.local:
          ref
              .read(p2pSyncProvider.notifier)
              .selectProjectSource(P2pProjectSource.local);
          break;
        case _P2pSelectionAction.remote:
          ref
              .read(p2pSyncProvider.notifier)
              .selectProjectSource(P2pProjectSource.remote);
          break;
        case _P2pSelectionAction.prepareLocal:
          await _handlePrepareP2pProject();
          break;
        case _P2pSelectionAction.chooseOther:
          final callback = widget.onChooseSyncProject ?? widget.onOpenProject;
          await callback?.call();
          break;
      }
    } finally {
      _negotiationDialogContext = null;
      _negotiationDialogVisible = false;
    }
  }

  void _dismissP2pNegotiationDialog() {
    final dialogContext = _negotiationDialogContext;
    if (!_negotiationDialogVisible ||
        dialogContext == null ||
        !dialogContext.mounted) {
      return;
    }
    final navigator = Navigator.of(dialogContext);
    if (navigator.canPop()) navigator.pop();
  }

  Widget _buildP2pOfferPreview(String label, P2pProjectOffer offer) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(offer.fileName ?? "沒有可同步文件"),
          Text(
            "UUID：${offer.shortUuid}",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _handlePrepareP2pProject() async {
    final localPreflight = P2pProjectPreflight.evaluate(
      local: widget.localP2pProject,
      requireRemote: false,
    );
    if (localPreflight.canCollaborate) {
      if (!localPreflight.canSync) {
        _showMessage("目前記憶體專案已可即時同步；儲存只用來建立 XML checkpoint。");
        return;
      }
      final onChooseSyncProject = widget.onChooseSyncProject;
      if (onChooseSyncProject != null) {
        await onChooseSyncProject();
      } else {
        _showMessage("目前專案已儲存且 UUID 有效，等待安全配對。");
      }
      return;
    }
    await _showP2pProjectPreparationDialog(localPreflight);
  }

  Future<void> _showP2pProjectPreparationDialog(
    P2pProjectPreflightResult preflight,
  ) async {
    final issues = _describeP2pPreflightIssues(preflight);
    final action = await showDialog<_P2pPreparationAction>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("準備同步專案"),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("即時協作只需要記憶體中的有效 Project UUID，不要求先寫入檔案。"),
                const SizedBox(height: 12),
                ...issues.map(
                  (issue) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(issue)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("取消"),
            ),
            if (preflight.issues.contains(
                  P2pProjectPreflightIssue.noLocalProject,
                ) &&
                widget.onNewProject != null)
              FilledButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_P2pPreparationAction.createNew),
                child: const Text("建立記憶體專案"),
              ),
            if (widget.onChooseSyncProject != null ||
                widget.onOpenProject != null)
              TextButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_P2pPreparationAction.chooseProject),
                child: const Text("開啟已儲存文件"),
              ),
            if (widget.onSaveProjectAs != null)
              TextButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_P2pPreparationAction.saveAs),
                child: const Text("另存為新作品"),
              ),
            if (widget.onSaveProject != null)
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(_P2pPreparationAction.save),
                child: const Text("儲存"),
              ),
          ],
        );
      },
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _P2pPreparationAction.save:
        await widget.onSaveProject?.call();
        break;
      case _P2pPreparationAction.saveAs:
        await widget.onSaveProjectAs?.call();
        break;
      case _P2pPreparationAction.chooseProject:
        final callback = widget.onChooseSyncProject ?? widget.onOpenProject;
        await callback?.call();
        break;
      case _P2pPreparationAction.createNew:
        await widget.onNewProject?.call();
        break;
    }
  }

  List<String> _describeP2pPreflightIssues(
    P2pProjectPreflightResult preflight,
  ) {
    final messages = <String>[];
    final issues = preflight.issues;
    if (issues.contains(P2pProjectPreflightIssue.noLocalProject)) {
      messages.add("尚未開啟專案。");
    }
    if (issues.contains(P2pProjectPreflightIssue.localProjectNotPersisted)) {
      messages.add("目前專案尚未儲存到可重新開啟的位置。");
    }
    if (issues.contains(P2pProjectPreflightIssue.localProjectDirty)) {
      messages.add("目前專案仍有未儲存修改。");
    }
    if (issues.contains(P2pProjectPreflightIssue.localProjectUuidInvalid)) {
      messages.add("目前專案沒有有效的 Project UUID。");
    }
    if (issues.contains(
      P2pProjectPreflightIssue.localProjectFormatUnsupported,
    )) {
      messages.add("目前專案格式尚不支援 P2P 同步。");
    }
    if (issues.contains(P2pProjectPreflightIssue.localProjectHasConflict)) {
      messages.add("目前專案仍有尚未解決的同步衝突。");
    }
    return messages;
  }

  String _p2pServiceStatusText(P2pSyncState state) {
    return switch (state.serviceStatus) {
      P2pServiceStatus.stopped => "服務未開啟",
      P2pServiceStatus.starting => "正在開啟服務",
      P2pServiceStatus.listening => "服務中",
      P2pServiceStatus.stopping => "正在停止服務",
      P2pServiceStatus.error => "服務錯誤",
    };
  }

  bool _isReceivingRemoteProject(P2pSyncState state) {
    return state.projectNegotiation?.kind ==
            P2pProjectNegotiationKind.remoteProvides &&
        state.selectedProjectSource == P2pProjectSource.remote &&
        state.sessionProjectUuid != null;
  }

  String _p2pProjectStatusText(
    P2pProjectPreflightResult preflight,
    P2pSyncState state,
  ) {
    if (_isReceivingRemoteProject(state)) {
      return "將由對方提供記憶體專案；不必先選擇儲存位置";
    }
    if (preflight.canCollaborate && !preflight.canSync) {
      return "記憶體專案可即時同步；尚未建立 XML checkpoint";
    }
    if (preflight.requiresSave) return "請先建立或開啟一個專案";
    if (preflight.issues.contains(
      P2pProjectPreflightIssue.localProjectHasConflict,
    )) {
      return "有尚未解決的同步衝突";
    }
    if (preflight.canSync) {
      return switch (state.revisionSummaryRelation) {
        P2pRevisionSummaryRelation.equal => "已儲存；revision 已同步",
        P2pRevisionSummaryRelation.localAhead => "已儲存；可通知對方同步",
        P2pRevisionSummaryRelation.remoteAhead => "已儲存；可下載並套用對方版本",
        P2pRevisionSummaryRelation.concurrent => "已儲存；可進行欄位級衝突合併",
        null when state.hasAuthenticatedTransport => "已儲存；等待 revision 協商",
        null => "已儲存；等待連線協商與安全配對",
      };
    }
    return "同步文件尚未就緒";
  }

  String _p2pPairingStatusText(P2pPairingStatus status) {
    return switch (status) {
      P2pPairingStatus.idle => "尚未配對",
      P2pPairingStatus.waitingForPeer => "等待對方建立配對 challenge",
      P2pPairingStatus.comparisonRequired => "等待人工比對配對碼",
      P2pPairingStatus.trustedLocally => "已加入本機信任清單",
      P2pPairingStatus.waitingForPeerConfirmation => "本機已確認；等待對方簽章確認",
      P2pPairingStatus.mutuallyConfirmed => "雙端已確認同一配對 transcript",
      P2pPairingStatus.error => "配對錯誤",
    };
  }

  String? _p2pPersistentVerificationText(P2pSyncState state) {
    if (!state.isPersistentVerificationNegotiated) return null;
    final untilSeconds =
        state.trustedPeer?.persistentVerificationUntilEpochSeconds;
    if (untilSeconds == null) {
      return "持久驗證：雙方皆已開啟，配對成功後有效 14 天";
    }
    final until = DateTime.fromMillisecondsSinceEpoch(
      untilSeconds * 1000,
      isUtc: true,
    ).toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, "0");
    final formatted =
        "${until.year}/${twoDigits(until.month)}/${twoDigits(until.day)} "
        "${twoDigits(until.hour)}:${twoDigits(until.minute)}";
    return state.trustedPeer!.hasPersistentVerificationAt(DateTime.now())
        ? "持久驗證有效至 $formatted；成功連線會再續簽 14 天"
        : "持久驗證已到期；本次需重新確認配對碼";
  }

  String _p2pRevisionStatusText(P2pSyncState state) {
    if (state.isRevisionMetadataLoading) return "本機 revision：載入中…";
    if (state.revisionMetadataError != null) {
      return "本機 revision：metadata 錯誤";
    }
    final graph = state.localRevisionGraph;
    if (graph == null || graph.revisions.isEmpty) {
      return "本機 revision：尚未建立（成功儲存後建立）";
    }
    if (graph.hasConflict) {
      return "本機 revision：${graph.headIds.length} 個 concurrent heads";
    }
    final head = graph.singleHead!;
    return "本機 revision：${head.shortRevisionId}  ·  ${head.clock.displayLabel}";
  }

  String _p2pSecureTransportStatusText(P2pSyncState state) {
    final transport = switch (state.secureTransportStatus) {
      P2pSecureTransportStatus.inactive => "加密通道：尚未建立",
      P2pSecureTransportStatus.establishing => "加密通道：正在驗證身分與派生 session key…",
      P2pSecureTransportStatus.authenticated => "加密通道：已驗證並加密",
      P2pSecureTransportStatus.error => "加密通道：建立失敗",
    };
    final relation = switch (state.revisionSummaryRelation) {
      P2pRevisionSummaryRelation.equal => "；revision heads 相同",
      P2pRevisionSummaryRelation.localAhead => "；本機 revision 較新",
      P2pRevisionSummaryRelation.remoteAhead => "；對方 revision 較新",
      P2pRevisionSummaryRelation.concurrent => "；偵測到 concurrent revisions",
      null => "",
    };
    final content = state.hasSnapshotContentTransfer
        ? "；snapshot chunk gate 已啟用"
        : "";
    return "$transport$relation$content";
  }

  String _p2pSnapshotManifestStatusText(P2pSyncState state) {
    final local = state.localSnapshotManifest;
    final localText = local == null
        ? "本機 manifest：尚未建立"
        : "本機 manifest：${local.contentLength} bytes／${local.chunkCount} chunks";
    final remoteText = switch (state.snapshotManifestStatus) {
      P2pSnapshotManifestStatus.inactive => "對方 manifest：尚未協商",
      P2pSnapshotManifestStatus.requesting => "對方 manifest：要求中…",
      P2pSnapshotManifestStatus.available =>
        "對方 manifest：已驗證（${state.remoteSnapshotManifest?.contentLength ?? 0} bytes）",
      P2pSnapshotManifestStatus.unavailable => "對方 manifest：目前不可用",
      P2pSnapshotManifestStatus.error => "對方 manifest：驗證失敗",
    };
    return "$localText；$remoteText";
  }

  String _p2pRevisionDagStatusText(P2pSyncState state) {
    if (state.isRevisionGraphLoading) return "Revision DAG：正在交換 graph pages…";
    if (state.revisionGraphError != null) {
      return "Revision DAG：${state.revisionGraphError}";
    }
    final remote = state.remoteRevisionGraph;
    if (remote == null) return "Revision DAG：尚未交換完整歷史";
    final ancestors = state.commonAncestorRevisionIds.length;
    final ack = state.remoteResolutionAck;
    return ack == null
        ? "Revision DAG：遠端 ${remote.revisions.length} revisions；$ancestors 個 maximal common ancestors；等待 resolve/ACK"
        : "Revision DAG：對方已 ACK resolve ${ack.resolutionRevisionId.substring(0, 8)}";
  }

  Future<void> _openExternalLink(Uri uri) async {
    try {
      final bool didLaunch = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!didLaunch) {
        throw const FormatException("Unable to launch external link");
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: uri.toString()));
      if (!mounted) {
        return;
      }
      _showMessage("無法直接開啟連結，已複製到剪貼簿");
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    AppFeedback.info(context, message);
  }

  Future<void> _handleImmediateP2pSync() async {
    final activeOperation = _immediateP2pSyncOperation;
    if (activeOperation != null) {
      return activeOperation;
    }
    late final Future<void> operation;
    operation = _performImmediateP2pSync().whenComplete(() {
      if (identical(_immediateP2pSyncOperation, operation)) {
        _immediateP2pSyncOperation = null;
      }
    });
    _immediateP2pSyncOperation = operation;
    return operation;
  }

  Future<void> _performImmediateP2pSync() async {
    var syncState = ref.read(p2pSyncProvider);
    if (syncState.revisionSummaryRelation ==
        P2pRevisionSummaryRelation.localAhead) {
      await ref.read(p2pSyncProvider.notifier).requestImmediateSync();
      return;
    }
    if (syncState.revisionSummaryRelation ==
            P2pRevisionSummaryRelation.concurrent &&
        syncState.remoteRevisionGraph == null) {
      await ref.read(p2pSyncProvider.notifier).refreshRevisionGraph();
      if (!mounted) return;
      syncState = ref.read(p2pSyncProvider);
    }
    final notifier = ref.read(p2pSnapshotTransferProvider.notifier);
    var transfer = ref.read(p2pSnapshotTransferProvider);
    if (!transfer.hasVerifiedSnapshot) {
      final downloaded = await notifier.downloadRemoteSnapshot();
      if (!downloaded || !mounted) return;
      transfer = ref.read(p2pSnapshotTransferProvider);
    }
    syncState = ref.read(p2pSyncProvider);
    final apply = widget.onApplyVerifiedP2pSnapshot;
    final verified = transfer.verifiedSnapshot;
    if (verified == null) return;
    if (syncState.revisionSummaryRelation ==
        P2pRevisionSummaryRelation.concurrent) {
      final resolve = widget.onResolveConcurrentP2pSnapshot;
      if (resolve != null && await resolve(verified)) {
        notifier.completeConcurrentResolution(verified);
      }
      return;
    }
    if (apply == null) return;
    await notifier.applyVerifiedSnapshot(apply);
  }

  // MARK: - UI 介面建構
  @override
  Widget build(BuildContext context) {
    final p2pState = ref.watch(p2pSyncProvider);
    final p2pTransferState = ref.watch(p2pSnapshotTransferProvider);
    ref.listen<int>(
      p2pSyncProvider.select((state) => state.negotiationGeneration),
      (previous, next) {
        if (next <= _lastHandledNegotiationGeneration) return;
        _lastHandledNegotiationGeneration = next;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final latest = ref.read(p2pSyncProvider);
          if (latest.negotiationGeneration == next) {
            if (latest.projectNegotiation?.requiresDialog ?? false) {
              unawaited(_showP2pNegotiationDialog(latest));
            } else {
              _dismissP2pNegotiationDialog();
            }
          }
        });
      },
    );
    ref.listen<int>(
      p2pSyncProvider.select(
        (state) => state.incomingSnapshotSyncRequestGeneration,
      ),
      (previous, next) {
        if (next <= _lastHandledSnapshotSyncRequestGeneration) return;
        _lastHandledSnapshotSyncRequestGeneration = next;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final latest = ref.read(p2pSyncProvider);
          if (latest.incomingSnapshotSyncRequestGeneration == next &&
              (latest.revisionSummaryRelation ==
                      P2pRevisionSummaryRelation.remoteAhead ||
                  latest.revisionSummaryRelation ==
                      P2pRevisionSummaryRelation.concurrent) &&
              latest.snapshotManifestStatus ==
                  P2pSnapshotManifestStatus.available) {
            unawaited(_handleImmediateP2pSync());
          }
        });
      },
    );
    final localP2pPreflight = P2pProjectPreflight.evaluate(
      local: widget.localP2pProject,
      requireRemote: false,
    );
    final List<RecentProjectEntry> recentProjects =
        widget.recentProjects ??
        ref.watch(
          settingsStateProvider.select(
            (state) =>
                state.valueOrNull?.recentProjects ??
                const <RecentProjectEntry>[],
          ),
        );

    final Set<String> supportedGenderValues = <String>{
      "all",
      "male",
      "neutral",
      "female",
    };
    final String effectiveGenderValue =
        supportedGenderValues.contains(_selectedGender)
        ? _selectedGender
        : "female";

    final ButtonStyle TextButtonStyle =
        (Theme.of(context).textButtonTheme.style ?? const ButtonStyle())
            .copyWith(
              textStyle: WidgetStatePropertyAll<TextStyle?>(
                Theme.of(context).textTheme.labelSmall,
              ),
            );
    final TextStyle? dropdownTextStyle = Theme.of(context).textTheme.bodyMedium;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 標題
            Text(
              "Welcome to",
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              "ものがたり·アシスタント",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "—— For Refined Editing. Powered by Heyairu.",
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Start
            AppSectionCard(
              margin: const EdgeInsets.all(4),
              padding: EdgeInsets.zero,
              useSectionLayout: false,
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SmallTitle(
                      icon: Icons.format_list_bulleted,
                      text: "Start",
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      style: TextButtonStyle,
                      onPressed: _handleNewProject,
                      child: Row(
                        children: const [
                          Icon(Icons.create_outlined, size: 18),
                          SizedBox(width: 4),
                          Text("New Project"),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButtonStyle,
                      onPressed: _handleOpenProject,
                      child: Row(
                        children: const [
                          Icon(Icons.folder_open, size: 18),
                          SizedBox(width: 4),
                          Text("Open File"),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButtonStyle,
                      onPressed: () => _openExternalLink(_projectRepoUri),
                      child: Row(
                        children: const [
                          Icon(Icons.code, size: 18),
                          SizedBox(width: 4),
                          Text("Open GitHub Repo for This Project"),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButtonStyle,
                      onPressed: () => _openExternalLink(_KadoURL),
                      child: Row(
                        children: const [
                          Icon(Icons.person_pin, size: 18),
                          SizedBox(width: 4),
                          Text("Heyairu's Profile on KadoKado"),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButtonStyle,
                      onPressed: () => _openExternalLink(_KoFiURL),
                      child: Row(
                        children: const [
                          Icon(Icons.coffee, size: 18),
                          SizedBox(width: 4),
                          Text("Heyairu's Ko-fi"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Did you know?
            AppSectionCard(
              margin: const EdgeInsets.all(4),
              padding: EdgeInsets.zero,
              useSectionLayout: false,
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _reloadDidYouKnow,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SmallTitle(
                        icon: Icons.info_outline,
                        text: "Did you know?",
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<_DidYouKnowData>(
                        future: _didYouKnowFuture,
                        builder: (context, snapshot) {
                          final _DidYouKnowData didYouKnowData =
                              snapshot.data ?? _fallbackDidYouKnowData;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                didYouKnowData.content, //Content
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              Text(
                                "——" + didYouKnowData.source, //Source
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Recent Files
            AppSectionCard(
              margin: const EdgeInsets.all(4),
              padding: EdgeInsets.zero,
              useSectionLayout: false,
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SmallTitle(icon: Icons.folder, text: "Recent"),
                    const SizedBox(height: 12),
                    if (recentProjects.isEmpty)
                      const AppEmptyState(
                        title: "尚無最近開啟檔案",
                        description: "開啟專案後會顯示在這裡",
                        icon: Icons.history_outlined,
                        compact: true,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      )
                    else
                      ...recentProjects.take(5).map((entry) {
                        final subtitle = entry.filePath ?? entry.uri ?? "無可用路徑";
                        return Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                style: TextButtonStyle,
                                onPressed: () =>
                                    _handleOpenRecentProject(entry),
                                child: Row(
                                  children: [
                                    const Icon(Icons.history, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.fileName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: "從最近清單移除",
                              onPressed: () =>
                                  _handleDeleteRecentProject(entry),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        );
                      }),
                  ],
                ),
              ),
            ),
            // Features
            AppSectionCard(
              margin: const EdgeInsets.all(4),
              padding: EdgeInsets.zero,
              useSectionLayout: false,
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SmallTitle(icon: Icons.person_outline, text: "姓名產生器"),
                    const SizedBox(height: 16),
                    // Col 1: language, gender, count, generate button.
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "語言",
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: 6),
                            AppDropdownField<String>(
                              value: _selectedLanguage,
                              textStyle: dropdownTextStyle,
                              options: const [
                                DropdownOption<String>(
                                  value: "JP",
                                  label: "日式",
                                ),
                                DropdownOption<String>(
                                  value: "ZH",
                                  label: "中式",
                                ),
                                DropdownOption<String>(
                                  value: "KR",
                                  label: "韓式",
                                ),
                              ],
                              onChanged: (String? value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  _selectedLanguage = value;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "性別",
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: 6),
                            AppDropdownField<String>(
                              value: effectiveGenderValue,
                              textStyle: dropdownTextStyle,
                              options: const [
                                DropdownOption<String>(
                                  value: "all",
                                  enabled: false,
                                  label: "全部（目前不可用）",
                                ),
                                DropdownOption<String>(
                                  value: "male",
                                  label: "男性",
                                ),
                                DropdownOption<String>(
                                  value: "neutral",
                                  enabled: false,
                                  label: "中性（目前不可用）",
                                ),
                                DropdownOption<String>(
                                  value: "female",
                                  label: "女性",
                                ),
                              ],
                              onChanged: (String? value) {
                                if (value == null ||
                                    value == "all" ||
                                    value == "neutral") {
                                  return;
                                }
                                setState(() {
                                  _selectedGender = value;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "生成數",
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: 6),
                            AppDropdownField<int>(
                              value: _generateCount,
                              textStyle: dropdownTextStyle,
                              options: const [1, 3, 5, 10, 20]
                                  .map(
                                    (int value) => DropdownOption<int>(
                                      value: value,
                                      label: "$value",
                                    ),
                                  )
                                  .toList(),
                              onChanged: (int? value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  _generateCount = value;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          style: TextButtonStyle,
                          onPressed: _isGeneratingNames ? null : _generateNames,
                          child: Row(
                            children: [
                              MediumTitle(icon: Icons.east, text: "生成"),
                              const Spacer(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Col 2: selectable and copyable generated results.
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "結果",
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium,
                                ),
                                IconButton(
                                  tooltip: "複製結果",
                                  onPressed: _generatedNames.isEmpty
                                      ? null
                                      : _copyGeneratedNames,
                                  icon: const Icon(Icons.copy_all_outlined),
                                ),
                              ],
                            ),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              constraints: const BoxConstraints(minHeight: 120),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                ),
                              ),
                              child: SelectionArea(
                                child: Text(
                                  _generatedNames.isEmpty
                                      ? "按下「生成」來產生姓名"
                                      : _generatedNames.join("\n"),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Sync
            AppSectionCard(
              margin: const EdgeInsets.all(4),
              padding: EdgeInsets.zero,
              useSectionLayout: false,
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: SmallTitle(
                            icon: Icons.sync_alt_outlined,
                            text: "內容同步",
                          ),
                        ),
                        Container(
                          key: const Key("p2p-service-status"),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: p2pState.isListening
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _p2pServiceStatusText(p2pState),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "完成簽章配對與 authenticated transport 後，可交換加密 revision、manifest 與 snapshot chunks；接收內容只會進入隔離驗證區。",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text("本機服務", style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (p2pState.localAddresses.isEmpty)
                          const Chip(
                            avatar: Icon(Icons.lan_outlined, size: 16),
                            label: Text("尚未找到可用 LAN IPv4"),
                          )
                        else
                          ...p2pState.localAddresses.map(
                            (address) => Chip(
                              avatar: const Icon(Icons.lan_outlined, size: 16),
                              label: Text(address),
                            ),
                          ),
                        if (p2pState.listeningPort != null)
                          Chip(
                            avatar: const Icon(
                              Icons.settings_ethernet,
                              size: 16,
                            ),
                            label: Text("Port ${p2pState.listeningPort}"),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 180,
                          child: AppTextField(
                            key: const Key("p2p-local-port-field"),
                            controller: _localPortController,
                            enabled:
                                !p2pState.isListening &&
                                !p2pState.isServiceBusy,
                            labelText: "本機 Port",
                            errorText: _localPortError,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ),
                        FilledButton.tonalIcon(
                          key: const Key("p2p-toggle-service-button"),
                          onPressed:
                              p2pState.isServiceBusy || p2pState.isConnecting
                              ? null
                              : _handleToggleP2pService,
                          icon: Icon(
                            p2pState.isListening
                                ? Icons.stop_circle_outlined
                                : Icons.play_circle_outline,
                          ),
                          label: Text(p2pState.isListening ? "中斷服務" : "開啟服務"),
                        ),
                        IconButton(
                          tooltip: "重新偵測本機 IP",
                          onPressed: () => ref
                              .read(p2pSyncProvider.notifier)
                              .refreshLocalAddresses(),
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "連線至裝置",
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 250,
                          child: AppTextField(
                            key: const Key("p2p-peer-ip-field"),
                            controller: _peerIpController,
                            labelText: "對方 IP",
                            hintText: "例如 192.168.1.23",
                            errorText: _peerIpError,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        SizedBox(
                          width: 160,
                          child: AppTextField(
                            key: const Key("p2p-peer-port-field"),
                            controller: _peerPortController,
                            labelText: "對方 Port",
                            errorText: _peerPortError,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onSubmitted: (_) => _handleP2pConnect(),
                          ),
                        ),
                        FilledButton.icon(
                          key: const Key("p2p-connect-button"),
                          onPressed:
                              p2pState.isConnecting ||
                                  p2pState.isServiceBusy ||
                                  p2pState.connectionStatus ==
                                      P2pConnectionStatus.reachableUnpaired
                              ? null
                              : _handleP2pConnect,
                          icon: Icon(
                            p2pState.connectionStatus ==
                                    P2pConnectionStatus.reachableUnpaired
                                ? Icons.link_outlined
                                : Icons.link,
                          ),
                          label: Text(
                            p2pState.connectionStatus ==
                                    P2pConnectionStatus.reachableUnpaired
                                ? "端點已驗證"
                                : p2pState.isConnecting
                                ? "連線中…"
                                : "連線",
                          ),
                        ),
                        if (p2pState.hasReachablePeer)
                          OutlinedButton.icon(
                            key: const Key("p2p-disconnect-peer-button"),
                            onPressed: p2pState.isServiceBusy
                                ? null
                                : () => ref
                                      .read(p2pSyncProvider.notifier)
                                      .disconnectPeer(),
                            icon: const Icon(Icons.link_off),
                            label: const Text("中斷連線"),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      key: const Key("p2p-pairing-panel"),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "裝置身分與配對",
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "本機指紋：${p2pState.localIdentity?.shortFingerprint ?? '初始化中…'}",
                            key: const Key("p2p-local-fingerprint"),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            _p2pPairingStatusText(p2pState.pairingStatus),
                            key: const Key("p2p-pairing-status"),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (p2pState.localPairingChallenge != null &&
                              p2pState.remotePairingChallenge != null)
                            Text(
                              p2pState.isSingleDeviceConfirmationNegotiated
                                  ? "確認模式：單端確認（雙方設定皆已開啟）"
                                  : "確認模式：雙端各自確認（至少一方已關閉單端確認）",
                              key: const Key("p2p-pairing-confirmation-mode"),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (_p2pPersistentVerificationText(p2pState)
                              case final persistentText?)
                            Text(
                              persistentText,
                              key: const Key(
                                "p2p-persistent-verification-status",
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          Text(
                            _p2pRevisionStatusText(p2pState),
                            key: const Key("p2p-revision-status"),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            _p2pSecureTransportStatusText(p2pState),
                            key: const Key("p2p-secure-transport-status"),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            _p2pSnapshotManifestStatusText(p2pState),
                            key: const Key("p2p-snapshot-manifest-status"),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            _p2pRevisionDagStatusText(p2pState),
                            key: const Key("p2p-revision-dag-status"),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (p2pState.revisionMetadataError != null)
                            Text(
                              p2pState.revisionMetadataError!,
                              key: const Key("p2p-revision-error"),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                            ),
                          if (p2pState.secureTransportError != null)
                            Text(
                              p2pState.secureTransportError!,
                              key: const Key("p2p-secure-transport-error"),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                            ),
                          if (p2pState.snapshotManifestError != null)
                            Text(
                              p2pState.snapshotManifestError!,
                              key: const Key("p2p-snapshot-manifest-error"),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                            ),
                          if (p2pState.pairingCode != null) ...[
                            const SizedBox(height: 12),
                            const Text("請確認兩台裝置顯示完全相同的配對碼："),
                            const SizedBox(height: 6),
                            SelectableText(
                              p2pState.pairingCode!,
                              key: const Key("p2p-pairing-code"),
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    letterSpacing: 6,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              p2pState.isSingleDeviceConfirmationNegotiated
                                  ? "若數字不同請取消配對；任一端確認後，另一端會驗證簽章並自動回簽。"
                                  : "若數字不同請取消配對；目前需兩端各自確認，完成後才會開啟加密內容通道。",
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                            ),
                          ],
                          if (p2pState.hasReachablePeer) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (p2pState.pairingStatus ==
                                        P2pPairingStatus.idle ||
                                    (p2pState.pairingStatus ==
                                            P2pPairingStatus.waitingForPeer &&
                                        p2pState.localPairingChallenge ==
                                            null) ||
                                    p2pState.pairingStatus ==
                                        P2pPairingStatus.error)
                                  FilledButton.tonalIcon(
                                    key: const Key("p2p-begin-pairing-button"),
                                    onPressed: p2pState.localIdentity == null
                                        ? null
                                        : () {
                                            final settings = ref
                                                .read(settingsStateProvider)
                                                .valueOrNull;
                                            unawaited(
                                              ref
                                                  .read(
                                                    p2pSyncProvider.notifier,
                                                  )
                                                  .beginPairing(
                                                    allowSingleDeviceConfirmation:
                                                        settings
                                                            ?.allowSingleDevicePairingConfirmation ??
                                                        true,
                                                    allowPersistentVerification:
                                                        settings
                                                            ?.allowPersistentP2pVerification ??
                                                        false,
                                                  ),
                                            );
                                          },
                                    icon: const Icon(Icons.key_outlined),
                                    label: const Text("開始安全配對"),
                                  ),
                                if (p2pState.pairingStatus ==
                                    P2pPairingStatus.comparisonRequired)
                                  FilledButton.icon(
                                    key: const Key(
                                      "p2p-confirm-pairing-button",
                                    ),
                                    onPressed: () => ref
                                        .read(p2pSyncProvider.notifier)
                                        .confirmPairingCode(),
                                    icon: const Icon(
                                      Icons.verified_user_outlined,
                                    ),
                                    label: const Text("確認配對碼相同"),
                                  ),
                                if (p2pState.pairingStatus ==
                                        P2pPairingStatus.waitingForPeer ||
                                    p2pState.pairingStatus ==
                                        P2pPairingStatus.comparisonRequired ||
                                    p2pState.pairingStatus ==
                                        P2pPairingStatus
                                            .waitingForPeerConfirmation)
                                  TextButton(
                                    key: const Key("p2p-cancel-pairing-button"),
                                    onPressed: () => ref
                                        .read(p2pSyncProvider.notifier)
                                        .cancelPairing(),
                                    child: const Text("取消配對"),
                                  ),
                              ],
                            ),
                          ],
                          if (p2pState.pairingStatus ==
                              P2pPairingStatus.mutuallyConfirmed) ...[
                            const SizedBox(height: 10),
                            Text(
                              p2pState.hasAuthenticatedTransport
                                  ? "雙方身分與短期 ECDH key 已綁定至同一 transcript；相同 project session 可交換加密 snapshot chunks，接收後仍須通過 quarantine 驗證。"
                                  : "雙方已簽署同一組 challenge，正在建立 authenticated encrypted transport；建立前不交換 revision summary 或內容。",
                              key: const Key("p2p-mutually-confirmed-notice"),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "同步文件",
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.localP2pProject?.fileName ?? "尚未開啟專案",
                            key: const Key("p2p-project-file-name"),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "UUID：${widget.localP2pProject?.shortUuid ?? '—'}",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (p2pState.remoteProjectOffer != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              "對方文件：${p2pState.remoteProjectOffer!.fileName ?? '沒有可同步文件'}",
                              key: const Key("p2p-remote-project-file-name"),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              "對方 UUID：${p2pState.remoteProjectOffer!.shortUuid}",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            _p2pProjectStatusText(localP2pPreflight, p2pState),
                            key: const Key("p2p-project-status"),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color:
                                      localP2pPreflight.canSync ||
                                          localP2pPreflight.canCollaborate ||
                                          _isReceivingRemoteProject(p2pState)
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.error,
                                ),
                          ),
                          if (p2pTransferState.message != null ||
                              p2pTransferState.errorMessage != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              p2pTransferState.errorMessage ??
                                  p2pTransferState.message!,
                              key: const Key("p2p-snapshot-transfer-status"),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: p2pTransferState.errorMessage == null
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant
                                        : Theme.of(context).colorScheme.error,
                                  ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                key: const Key("p2p-prepare-project-button"),
                                onPressed: _handlePrepareP2pProject,
                                icon: const Icon(Icons.description_outlined),
                                label: Text(
                                  localP2pPreflight.canCollaborate ||
                                          _isReceivingRemoteProject(p2pState)
                                      ? "更換同步文件"
                                      : "準備同步文件",
                                ),
                              ),
                              Tooltip(
                                message:
                                    p2pState.revisionSummaryRelation ==
                                        P2pRevisionSummaryRelation.concurrent
                                    ? "雙方 revision 並行，必須先進入欄位級衝突處理"
                                    : p2pState.revisionSummaryRelation ==
                                          P2pRevisionSummaryRelation.localAhead
                                    ? "透過 authenticated transport 要求接收端下載目前 snapshot"
                                    : "僅接受 authenticated transport 中與目前 session 完全相符的遠端 snapshot",
                                child: FilledButton.icon(
                                  key: const Key("p2p-immediate-sync-button"),
                                  onPressed:
                                      !p2pTransferState.isBusy &&
                                          (localP2pPreflight.canSync ||
                                              _isReceivingRemoteProject(
                                                p2pState,
                                              )) &&
                                          ((p2pState.canDownloadRemoteSnapshot &&
                                                  (p2pState.revisionSummaryRelation ==
                                                          P2pRevisionSummaryRelation
                                                              .concurrent
                                                      ? widget.onResolveConcurrentP2pSnapshot !=
                                                            null
                                                      : widget.onApplyVerifiedP2pSnapshot !=
                                                            null)) ||
                                              p2pState
                                                  .canRequestPeerSnapshotSync)
                                      ? _handleImmediateP2pSync
                                      : null,
                                  icon: p2pTransferState.isBusy
                                      ? const SizedBox.square(
                                          dimension: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.sync),
                                  label: Text(
                                    p2pTransferState.status ==
                                            P2pSnapshotTransferStatus.applying
                                        ? "正在套用"
                                        : p2pTransferState.status ==
                                              P2pSnapshotTransferStatus
                                                  .downloading
                                        ? "正在下載"
                                        : "立即同步",
                                  ),
                                ),
                              ),
                              if (p2pTransferState.isBusy)
                                TextButton(
                                  key: const Key(
                                    "p2p-cancel-snapshot-transfer-button",
                                  ),
                                  onPressed: () => ref
                                      .read(
                                        p2pSnapshotTransferProvider.notifier,
                                      )
                                      .cancel(),
                                  child: const Text("取消傳輸"),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (p2pState.message != null ||
                        p2pState.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        p2pState.errorMessage ?? p2pState.message!,
                        key: const Key("p2p-operation-message"),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: p2pState.errorMessage == null
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DidYouKnowData {
  const _DidYouKnowData({required this.content, required this.source});

  final String content;
  final String source;
}

enum _P2pPreparationAction { save, saveAs, chooseProject, createNew }

enum _P2pSelectionAction { local, remote, prepareLocal, chooseOther }
