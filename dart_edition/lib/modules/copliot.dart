/*
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

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter/services.dart";
import "package:http/http.dart" as http;

import "../bin/file.dart";
import "../bin/ui_library.dart";
import "../features/copilot/application/copilot_conversation_buffer.dart";
import "../features/copilot/application/copilot_conversation_controller.dart";
import "../features/copilot/application/copilot_project_context_builder.dart";
import "../features/copilot/application/copilot_request_coordinator.dart";
import "../features/copilot/data/copilot_http_transport.dart";
import "../features/copilot/data/copilot_provider_adapter.dart";
import "../features/copilot/data/copilot_settings_store.dart";
import "../features/copilot/domain/copilot_errors.dart";
import "../features/copilot/domain/copilot_models.dart";
import "../models/chapter_selection_data.dart" as chapter_model;
import "../presentation/providers/project_state_providers.dart";

class _ProviderPreset {
  final String name;
  final String apiUrl;
  final List<String> fallbackModels;
  final CopilotProviderProtocol protocol;

  const _ProviderPreset({
    required this.name,
    required this.apiUrl,
    required this.fallbackModels,
    required this.protocol,
  });
}

class _CopilotSettingsSnapshot {
  final String provider;
  final String apiUrl;
  final String model;
  final String apiKey;

  const _CopilotSettingsSnapshot({
    required this.provider,
    required this.apiUrl,
    required this.model,
    required this.apiKey,
  });

  @override
  bool operator ==(Object other) {
    return other is _CopilotSettingsSnapshot &&
        other.provider == provider &&
        other.apiUrl == apiUrl &&
        other.model == model &&
        other.apiKey == apiKey;
  }

  @override
  int get hashCode => Object.hash(provider, apiUrl, model, apiKey);
}

class _SendCopilotMessageIntent extends Intent {
  const _SendCopilotMessageIntent();
}

class CopilotView extends ConsumerStatefulWidget {
  final ValueChanged<String>? onOpenChapter;
  final void Function(String resourceType, String resourceId)? onOpenResource;
  final bool askEnabled;
  final bool planEnabled;
  final CopilotSettingsStore settingsStore;
  final CopilotHttpTransport? transport;
  final CopilotConversationBuffer? conversationBuffer;
  final List<CopilotSelectableResource>? selectableResources;

  const CopilotView({
    super.key,
    this.onOpenChapter,
    this.onOpenResource,
    this.askEnabled = const bool.fromEnvironment(
      "COPILOT_ASK_ENABLED",
      defaultValue: false,
    ),
    this.planEnabled = const bool.fromEnvironment(
      "COPILOT_PLAN_ENABLED",
      defaultValue: false,
    ),
    this.settingsStore = const CopilotSettingsStore(),
    this.transport,
    this.conversationBuffer,
    this.selectableResources,
  });

  @override
  ConsumerState<CopilotView> createState() => _CopilotViewState();
}

class _CopilotViewState extends ConsumerState<CopilotView> {
  static const int _maxUiMessages = 200;
  static const int _maxUiHistoryBytes = 1024 * 1024;
  static const int _maxContextMessages = 24;
  static const int _maxContextBytes = 128 * 1024;
  static const int _maxRequestBytes = 256 * 1024;
  static const int _maxModelResponseBytes = 1024 * 1024;
  static const int _maxChatResponseBytes = 2 * 1024 * 1024;
  static const int _maxOutputTokens = 4096;
  static const Duration _settingsDebounce = Duration(milliseconds: 350);

  static const List<_ProviderPreset> _providerPresets = [
    _ProviderPreset(
      name: "OpenAI",
      apiUrl: "https://api.openai.com/v1",
      fallbackModels: [""],
      protocol: CopilotProviderProtocol.openAiCompatible,
    ),
    _ProviderPreset(
      name: "Gemini",
      apiUrl: "https://generativelanguage.googleapis.com",
      fallbackModels: [""],
      protocol: CopilotProviderProtocol.gemini,
    ),
    _ProviderPreset(
      name: "Anthropic",
      apiUrl: "https://api.anthropic.com/v1",
      fallbackModels: [""],
      protocol: CopilotProviderProtocol.anthropic,
    ),
    _ProviderPreset(
      name: "Grok",
      apiUrl: "https://api.x.ai/v1",
      fallbackModels: [""],
      protocol: CopilotProviderProtocol.openAiCompatible,
    ),
    _ProviderPreset(
      name: "OpenRouter",
      apiUrl: "https://openrouter.ai/api/v1",
      fallbackModels: [""],
      protocol: CopilotProviderProtocol.openAiCompatible,
    ),
    _ProviderPreset(
      name: "Ollama",
      apiUrl: "http://localhost:11434/v1",
      fallbackModels: [""],
      protocol: CopilotProviderProtocol.ollama,
    ),
    _ProviderPreset(
      name: "自訂",
      apiUrl: "",
      fallbackModels: [],
      protocol: CopilotProviderProtocol.openAiCompatible,
    ),
  ];

  final TextEditingController _providerController = TextEditingController();
  final TextEditingController _apiUrlController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _modelFocusNode = FocusNode();
  final ScrollController _conversationScrollController = ScrollController();
  late final CopilotSettingsStore _settingsStore;
  late final CopilotHttpTransport _transport;
  final CopilotRequestCoordinator<_CopilotSettingsSnapshot>
  _requestCoordinator = CopilotRequestCoordinator<_CopilotSettingsSnapshot>();

  late final CopilotConversationBuffer _conversation;
  late final CopilotConversationController<_CopilotSettingsSnapshot>
  _conversationController;
  Future<String>? _mnprojStructureReference;

  List<CopilotConversationMessage> get _messages => _conversation.messages;
  bool get _isSending => _conversationController.isSending;
  List<String> _availableModels = [];
  CopilotMode _selectedMode = CopilotMode.chat;
  CopilotContextScope _selectedContextScope =
      CopilotContextScope.currentChapter;
  Set<String> _selectedResourceKeys = <String>{};
  bool _modelPanelExpanded = true;
  bool _isLoadingModels = false;
  bool _showApiKey = false;
  String? _statusMessage;
  String? _errorMessage;
  Timer? _settingsSaveTimer;
  Future<void> _settingsWrite = Future<void>.value();
  String? _confirmedContextHost;
  String? _confirmedCredentialHost;

  @override
  void initState() {
    super.initState();
    _settingsStore = widget.settingsStore;
    _transport =
        widget.transport ??
        CopilotHttpTransport(maxRequestBytes: _maxRequestBytes);
    _conversation =
        widget.conversationBuffer ??
        CopilotConversationBuffer(
          maxUiMessages: _maxUiMessages,
          maxUiHistoryBytes: _maxUiHistoryBytes,
          maxContextMessages: _maxContextMessages,
          maxContextBytes: _maxContextBytes,
        );
    _conversationController =
        CopilotConversationController<_CopilotSettingsSnapshot>(
          buffer: _conversation,
          requestCoordinator: _requestCoordinator,
        );
    _loadSettings();
  }

  Future<String> _getMnprojStructureReference() {
    return _mnprojStructureReference ??= _loadMnprojStructureReference();
  }

  Future<String> _loadMnprojStructureReference() async {
    final reference = await rootBundle.loadString(
      CopilotPromptPolicy.mnprojStructureAsset,
    );
    if (reference.trim().isEmpty) {
      throw const FormatException(".mnproj 結構參考檔是空白的。");
    }
    if (utf8.encode(reference).length >
        CopilotPromptPolicy.maxMnprojStructureBytes) {
      throw const FormatException(".mnproj 結構參考檔超過 64 KiB 上限。");
    }
    return reference.trim();
  }

  @override
  void dispose() {
    _requestCoordinator.cancelAll();
    _settingsSaveTimer?.cancel();
    final _CopilotSettingsSnapshot settingsSnapshot = _settingsSnapshot();
    unawaited(_enqueueSettingsWrite(settingsSnapshot));
    _transport.dispose();
    _providerController.dispose();
    _apiUrlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    _messageController.dispose();
    _modelFocusNode.dispose();
    _conversationScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final _ProviderPreset defaultPreset = _providerPresets.first;
    try {
      final settings = await _settingsStore.load();
      if (!mounted) return;
      final selectedPreset = _providerPresets.firstWhere(
        (preset) => preset.name == settings.provider,
        orElse: () => defaultPreset,
      );
      setState(() {
        _providerController.text = settings.provider ?? selectedPreset.name;
        _apiUrlController.text = settings.apiUrl ?? selectedPreset.apiUrl;
        _modelController.text =
            settings.model ??
            (selectedPreset.fallbackModels.isEmpty
                ? ""
                : selectedPreset.fallbackModels.first);
        _apiKeyController.text = settings.apiKey;
        _availableModels = selectedPreset.fallbackModels;
      });
    } catch (error, stackTrace) {
      debugPrint("Copilot secure settings load failed: $error\n$stackTrace");
      if (!mounted) return;
      setState(() {
        _providerController.text = defaultPreset.name;
        _apiUrlController.text = defaultPreset.apiUrl;
        _modelController.text = defaultPreset.fallbackModels.first;
        _availableModels = defaultPreset.fallbackModels;
        _errorMessage = "Copilot 安全設定無法載入；API Key 未載入。";
      });
    }
  }

  _CopilotSettingsSnapshot _settingsSnapshot() {
    return _CopilotSettingsSnapshot(
      provider: _providerController.text.trim(),
      apiUrl: _apiUrlController.text.trim(),
      model: _modelController.text.trim(),
      apiKey: _apiKeyController.text,
    );
  }

  void _scheduleSettingsSave() {
    final snapshot = _settingsSnapshot();
    _settingsSaveTimer?.cancel();
    _settingsSaveTimer = Timer(
      _settingsDebounce,
      () => unawaited(_enqueueSettingsWrite(snapshot)),
    );
  }

  Future<void> _persistSettingsNow() {
    _settingsSaveTimer?.cancel();
    _settingsSaveTimer = null;
    return _enqueueSettingsWrite(_settingsSnapshot());
  }

  Future<void> _enqueueSettingsWrite(_CopilotSettingsSnapshot snapshot) {
    final operation = _settingsWrite
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint("Copilot settings write failed: $error\n$stackTrace");
        })
        .then((_) async {
          await _settingsStore.save(
            provider: snapshot.provider,
            apiUrl: snapshot.apiUrl,
            model: snapshot.model,
            apiKey: snapshot.apiKey,
          );
        });
    _settingsWrite = operation.catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      debugPrint("Copilot settings write failed: $error\n$stackTrace");
    });
    return operation;
  }

  void _selectProvider(String providerName) {
    final _ProviderPreset preset = _providerPresets.firstWhere(
      (preset) => preset.name == providerName,
      orElse: () => _providerPresets.last,
    );

    setState(() {
      _providerController.text = preset.name;
      if (preset.apiUrl.isNotEmpty) {
        _apiUrlController.text = preset.apiUrl;
      }
      _availableModels = preset.fallbackModels;
      if (preset.fallbackModels.isNotEmpty) {
        _modelController.text = preset.fallbackModels.first;
      }
      _statusMessage = null;
      _errorMessage = null;
    });
    _scheduleSettingsSave();
  }

  String _normalizeApiUrl(String apiUrl) {
    final String trimmed = apiUrl.trim();
    if (trimmed.endsWith("/")) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Uri _buildEndpointUri(String path) {
    final String baseUrl = _normalizeApiUrl(_apiUrlController.text);
    if (baseUrl.isEmpty) {
      throw const FormatException("請先輸入 API URL。");
    }
    final baseUri = Uri.parse(baseUrl);
    if (!baseUri.hasScheme ||
        baseUri.host.isEmpty ||
        baseUri.userInfo.isNotEmpty) {
      throw const FormatException("API URL 格式無效。");
    }
    if (baseUri.scheme != "https" &&
        !(baseUri.scheme == "http" && _isLoopbackHost(baseUri.host))) {
      throw const FormatException("雲端 API URL 必須使用 HTTPS；HTTP 僅允許本機 Ollama。");
    }
    return Uri.parse("$baseUrl$path");
  }

  bool _isLoopbackHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == "localhost" ||
        normalized == "127.0.0.1" ||
        normalized == "::1";
  }

  Uri _buildProviderEndpointUri(String path, {Map<String, String>? query}) {
    final Uri uri = _buildEndpointUri(path);
    if (query == null || query.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  _ProviderPreset _selectedProviderPreset() {
    return _providerPresets.firstWhere(
      (preset) => preset.name == _providerController.text,
      orElse: () => _providerPresets.last,
    );
  }

  bool get _isOllamaV1Url {
    final String apiUrl = _normalizeApiUrl(_apiUrlController.text);
    return apiUrl.endsWith("/v1");
  }

  List<CopilotProviderMessage> _providerMessages() {
    return _conversation
        .modelContext(_selectedMode)
        .where((message) => message.role != CopilotConversationRole.system)
        .map(
          (message) => CopilotProviderMessage(
            role: message.role == CopilotConversationRole.user
                ? CopilotProviderMessageRole.user
                : CopilotProviderMessageRole.assistant,
            content: message.modelContent ?? message.content,
          ),
        )
        .toList(growable: false);
  }

  Future<http.Response> _sendBoundedJsonRequest(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    Object? jsonBody,
    required Duration timeout,
    required int maxResponseBytes,
  }) async {
    return _transport.sendJson(
      method,
      uri,
      headers: headers,
      jsonBody: jsonBody,
      timeout: timeout,
      maxResponseBytes: maxResponseBytes,
    );
  }

  Future<http.Response> _readModelsResponse() {
    final _ProviderPreset preset = _selectedProviderPreset();
    final String apiKey = _apiKeyController.text.trim();
    final request = CopilotProviderAdapter.modelsRequest(
      protocol: preset.protocol,
      apiKey: apiKey,
      ollamaUsesOpenAiApi: _isOllamaV1Url,
    );
    return _sendBoundedJsonRequest(
      request.method,
      _buildProviderEndpointUri(
        request.path,
        query: request.query.isEmpty ? null : request.query,
      ),
      headers: request.headers,
      jsonBody: request.body,
      timeout: const Duration(seconds: 30),
      maxResponseBytes: _maxModelResponseBytes,
    );
  }

  Future<void> _fetchModels() async {
    if (_isLoadingModels) return;

    setState(() {
      _isLoadingModels = true;
      _statusMessage = null;
      _errorMessage = null;
    });

    final ticket = _requestCoordinator.beginModelRequest(_settingsSnapshot());
    try {
      if (!await _confirmCredentialTransmission()) return;
      await _persistSettingsNow();
      if (!mounted ||
          !_requestCoordinator.canPublishModelRequest(
            ticket,
            currentConfiguration: _settingsSnapshot(),
          )) {
        return;
      }
      final _ProviderPreset preset = _selectedProviderPreset();
      final http.Response response = await _readModelsResponse();
      if (!mounted ||
          !_requestCoordinator.canPublishModelRequest(
            ticket,
            currentConfiguration: _settingsSnapshot(),
          )) {
        return;
      }

      CopilotErrorPolicy.ensureSuccessfulStatus(
        response.statusCode,
        operation: CopilotOperation.listModels,
      );

      final Object? decoded = jsonDecode(response.body);
      final List<String> models = CopilotProviderAdapter.extractModelIds(
        decoded,
        preset.protocol,
      );
      if (models.isEmpty) {
        throw const CopilotFailure(
          code: CopilotFailureCode.invalidResponse,
          userMessage: "回應中沒有可用模型。",
        );
      }

      setState(() {
        _availableModels = models;
        if (!_availableModels.contains(_modelController.text.trim())) {
          _modelController.text = _availableModels.first;
        }
        _statusMessage = "已抓取 ${_availableModels.length} 個模型。";
      });
      await _persistSettingsNow();
    } catch (e) {
      if (mounted &&
          _requestCoordinator.canPublishModelRequest(
            ticket,
            currentConfiguration: _settingsSnapshot(),
          )) {
        setState(() => _errorMessage = _describeCopilotError(e));
      }
    } finally {
      if (mounted && _requestCoordinator.ownsModelRequest(ticket)) {
        setState(() => _isLoadingModels = false);
      }
    }
  }

  Future<http.Response> _readChatResponse(
    String model, {
    required CopilotMode requestMode,
    String mnprojStructureReference = "",
  }) {
    final _ProviderPreset preset = _selectedProviderPreset();
    final String apiKey = _apiKeyController.text.trim();
    final request = CopilotProviderAdapter.chatRequest(
      protocol: preset.protocol,
      apiKey: apiKey,
      model: model,
      systemInstruction: CopilotPromptPolicy.systemInstruction(
        requestMode,
        mnprojStructureReference: mnprojStructureReference,
      ),
      messages: _providerMessages(),
      ollamaUsesOpenAiApi: _isOllamaV1Url,
      maxOutputTokens: _maxOutputTokens,
    );
    return _sendBoundedJsonRequest(
      request.method,
      _buildProviderEndpointUri(
        request.path,
        query: request.query.isEmpty ? null : request.query,
      ),
      headers: request.headers,
      jsonBody: request.body,
      timeout: const Duration(seconds: 60),
      maxResponseBytes: _maxChatResponseBytes,
    );
  }

  CopilotContextSnapshot _captureCurrentChapterContext({
    CopilotContextScope scope = CopilotContextScope.currentChapter,
  }) {
    final selection = ref.read(editorSelectionProvider);
    final chapterId = selection.selectedChapID;
    if (chapterId == null) {
      throw const FormatException("請先選擇章節，再使用 Ask／Plan 模式。");
    }
    final location = chapter_model.ChapterTree.findChapter(
      ref.read(segmentsDataProvider),
      folderId: selection.selectedSegID,
      chapterId: chapterId,
    );
    if (location == null) {
      throw const FormatException("找不到目前章節，請重新選擇章節。");
    }
    final supplementalResources = switch (scope) {
      CopilotContextScope.currentChapter => const <CopilotContextResource>[],
      CopilotContextScope.currentChapterWithProjectOverview =>
        <CopilotContextResource>[
          CopilotProjectContextBuilder.buildOverview(
            ref.read(projectDataProvider),
          ),
        ],
      CopilotContextScope.currentChapterWithSelectedResources =>
        CopilotProjectContextBuilder.buildSelectedResources(
          ref.read(projectDataProvider),
          selectionKeys: _selectedResourceKeys,
          glossaryEntries: ref.read(glossaryStateProvider).entryIndex,
        ),
    };
    if (scope == CopilotContextScope.currentChapterWithSelectedResources &&
        supplementalResources.isEmpty) {
      throw const FormatException("請至少選擇一個仍存在的補充資源。");
    }
    return CopilotContextSnapshot.currentChapter(
      chapterId: chapterId,
      title: location.chapter.chapterName,
      content: ref.read(selectedChapterStoredContentProvider) ?? "",
      supplementalResources: supplementalResources,
    );
  }

  Future<bool> _confirmContextTransmission(
    CopilotContextSnapshot context,
  ) async {
    final uri = _buildEndpointUri("");
    final destination = "${uri.scheme}://${uri.authority}";
    if (_confirmedContextHost == destination) return true;
    final supplementalDescription = context.supplementalResources.isEmpty
        ? ""
        : "，以及${context.supplementalResources.map((resource) => resource.title).join("、")}";
    final approved = await showDialog<bool>(
      context: this.context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("傳送作品內容？"),
        content: Text(
          "此模式會將目前章節「${context.title}」$supplementalDescription傳送到 "
          "$destination。資料會直接送往你選擇的模型服務。"
          "另會附帶 App 內建的 .mnproj 結構說明（不含作品內容）。"
          "${_apiKeyController.text.trim().isEmpty ? "" : "已設定的 API Key 也會一併傳送。"}",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("取消"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text("允許本次連線"),
          ),
        ],
      ),
    );
    if (approved == true) {
      _confirmedContextHost = destination;
      if (_apiKeyController.text.trim().isNotEmpty) {
        _confirmedCredentialHost = destination;
      }
      return true;
    }
    return false;
  }

  Future<bool> _confirmCredentialTransmission() async {
    if (_apiKeyController.text.trim().isEmpty) return true;
    final uri = _buildEndpointUri("");
    final destination = "${uri.scheme}://${uri.authority}";
    if (_confirmedCredentialHost == destination) return true;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("傳送 API Key？"),
        content: Text("API Key 將直接傳送到 $destination。請確認這是你信任的模型服務。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("取消"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text("允許本次連線"),
          ),
        ],
      ),
    );
    if (approved == true) {
      _confirmedCredentialHost = destination;
      return true;
    }
    return false;
  }

  void _cancelActiveRequest() {
    if (!_isSending) return;
    _transport.cancel();
    setState(() {
      final restoredPrompt = _conversationController.cancel();
      if (restoredPrompt != null) {
        _messageController.text = restoredPrompt;
      }
      _statusMessage = "已取消請求。";
      _errorMessage = null;
    });
  }

  Future<void> _sendMessage() async {
    if (_isSending || _selectedMode == CopilotMode.agent) return;

    final String prompt = _messageController.text.trim();
    final String model = _modelController.text.trim();
    if (prompt.isEmpty) return;

    if (model.isEmpty) {
      setState(() => _errorMessage = "請先選擇或輸入使用模型。");
      return;
    }

    final requestMode = _selectedMode;
    CopilotContextSnapshot? requestContext;
    String mnprojStructureReference = "";
    String modelContent;
    try {
      if (requestMode == CopilotMode.ask || requestMode == CopilotMode.plan) {
        mnprojStructureReference = await _getMnprojStructureReference();
        requestContext = _captureCurrentChapterContext(
          scope: requestMode == CopilotMode.ask
              ? _selectedContextScope
              : CopilotContextScope.currentChapter,
        );
        if (!await _confirmContextTransmission(requestContext)) return;
      }
      if (!await _confirmCredentialTransmission()) return;
      modelContent = CopilotPromptPolicy.buildUserContent(
        mode: requestMode,
        prompt: prompt,
        context: requestContext,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _describeCopilotError(error));
      }
      return;
    }

    late final CopilotConversationOperation<_CopilotSettingsSnapshot> operation;
    setState(() {
      operation = _conversationController.begin(
        configuration: _settingsSnapshot(),
        mode: requestMode,
        prompt: prompt,
        modelContent: modelContent,
        createdAt: DateTime.now(),
        contextSnapshot: requestContext,
      );
      _messageController.clear();
      _statusMessage = null;
      _errorMessage = null;
    });
    _scrollConversationToBottom();

    try {
      await _persistSettingsNow();
      if (!mounted) return;
      if (!_conversationController.canPublish(
        operation,
        currentConfiguration: _settingsSnapshot(),
        currentMode: _selectedMode,
      )) {
        if (_conversationController.owns(operation)) {
          setState(() {
            final restoredPrompt = _conversationController.rollbackIfStale(
              operation,
              currentConfiguration: _settingsSnapshot(),
              currentMode: _selectedMode,
            );
            if (restoredPrompt != null) {
              _messageController.text = restoredPrompt;
              _statusMessage = "設定已變更，已取消舊請求。";
            }
          });
        }
        return;
      }
      final _ProviderPreset preset = _selectedProviderPreset();
      final http.Response response = await _readChatResponse(
        model,
        requestMode: requestMode,
        mnprojStructureReference: mnprojStructureReference,
      );
      if (!mounted ||
          !_conversationController.canPublish(
            operation,
            currentConfiguration: _settingsSnapshot(),
            currentMode: _selectedMode,
          )) {
        if (mounted && _conversationController.owns(operation)) {
          setState(() {
            final restoredPrompt = _conversationController.rollbackIfStale(
              operation,
              currentConfiguration: _settingsSnapshot(),
              currentMode: _selectedMode,
            );
            if (restoredPrompt != null) {
              _messageController.text = restoredPrompt;
              _statusMessage = "設定已變更，已取消舊請求結果。";
            }
          });
        }
        return;
      }

      CopilotErrorPolicy.ensureSuccessfulStatus(
        response.statusCode,
        operation: CopilotOperation.conversation,
      );

      final String reply = CopilotProviderAdapter.extractAssistantReply(
        jsonDecode(response.body),
        preset.protocol,
        ollamaUsesOpenAiApi: _isOllamaV1Url,
      );
      if (utf8.encode(reply).length > _maxUiHistoryBytes) {
        throw const FormatException("模型回覆超過 UI history 的 1 MiB 上限。");
      }
      final askResponse = requestMode == CopilotMode.ask
          ? CopilotAskResponse.tryParse(reply, context: requestContext!)
          : null;
      CopilotPlan? plan;
      String? planValidationError;
      if (requestMode == CopilotMode.plan) {
        try {
          plan = CopilotPlan.parse(reply, context: requestContext!);
        } on FormatException catch (error) {
          planValidationError = error.message;
        }
      }
      final assistantMessage = CopilotConversationMessage(
        role: CopilotConversationRole.assistant,
        content: askResponse?.answer ?? plan?.summary ?? reply,
        modelContent: reply,
        createdAt: DateTime.now(),
        mode: requestMode,
        contextSnapshot: requestContext,
        askResponse: askResponse,
        plan: plan,
        planValidationError: planValidationError,
      );
      setState(() {
        _conversationController.publish(
          operation,
          assistantMessage,
          currentConfiguration: _settingsSnapshot(),
          currentMode: _selectedMode,
        );
      });
      _scrollConversationToBottom();
    } catch (e) {
      if (mounted && _conversationController.owns(operation)) {
        setState(() {
          final failure = _conversationController.fail(
            operation,
            currentConfiguration: _settingsSnapshot(),
            currentMode: _selectedMode,
          );
          if (failure == null) return;
          _messageController.text = failure.restoredPrompt;
          if (failure.canReportError) {
            _errorMessage = _describeCopilotError(e);
          } else {
            _statusMessage = "設定已變更，已取消舊請求結果。";
          }
        });
      }
    } finally {
      if (mounted && _conversationController.owns(operation)) {
        setState(() => _conversationController.complete(operation));
      }
    }
  }

  String _describeCopilotError(Object error) =>
      CopilotErrorPolicy.describe(error);

  void _clearConversation() {
    setState(() {
      _conversation.clear();
      _statusMessage = null;
      _errorMessage = null;
    });
  }

  Future<void> _clearStoredApiKey() async {
    if (_apiKeyController.text.isEmpty) {
      setState(() {
        _statusMessage = "目前沒有已儲存的 API Key。";
        _errorMessage = null;
      });
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("清除 API Key？"),
        content: const Text("這會從此裝置的安全儲存空間移除 API Key。作品與對話內容不會受影響。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("取消"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text("清除 Key"),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() {
      _apiKeyController.clear();
      _confirmedCredentialHost = null;
      _statusMessage = null;
      _errorMessage = null;
    });
    try {
      await _persistSettingsNow();
      if (!mounted) return;
      setState(() => _statusMessage = "API Key 已從此裝置移除。");
    } catch (error, stackTrace) {
      debugPrint("Copilot API key removal failed: $error\n$stackTrace");
      if (!mounted) return;
      setState(() => _errorMessage = "無法從此裝置移除 API Key，請稍後再試。");
    }
  }

  void _scrollConversationToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_conversationScrollController.hasClients) return;
      _conversationScrollController.animateTo(
        _conversationScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildWarningCard() {
    return const AppNoticeBanner(
      message: "Ask／Plan Beta 已納入功能旗標，只讀取目前章節且不會修改專案；Agent 模式暫不可用。",
      tone: AppFeedbackTone.warning,
    );
  }

  Widget _buildModelPanel() {
    return AppSectionCard(
      padding: EdgeInsets.zero,
      useSectionLayout: false,
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ExpansionTile(
        initiallyExpanded: _modelPanelExpanded,
        onExpansionChanged: (expanded) =>
            setState(() => _modelPanelExpanded = expanded),
        leading: const Icon(Icons.tune),
        title: Text("模型選擇", style: Theme.of(context).textTheme.titleMedium),
        childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          Column(
            children: [
              const SizedBox(height: 16),
              ResponsiveSplitView(
                primary: _buildProviderField(),
                secondary: _buildApiUrlField(),
              ),
              const SizedBox(height: 16),
              ResponsiveSplitView(
                primary: _buildModelField(),
                secondary: _buildApiKeyField(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProviderField() {
    final String selectedProvider =
        _providerPresets.any(
          (preset) => preset.name == _providerController.text,
        )
        ? _providerController.text
        : "自訂";

    return AppDropdownField<String>(
      value: selectedProvider,
      labelText: "供應商",
      options: _providerPresets
          .map(
            (preset) => DropdownOption(value: preset.name, label: preset.name),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) _selectProvider(value);
      },
    );
  }

  Widget _buildApiUrlField() {
    return AppTextField(
      key: const ValueKey<String>("copilot-api-url-field"),
      controller: _apiUrlController,
      labelText: "API URL",
      hintText: "https://api.openai.com/v1",
      prefixIcon: const Icon(Icons.link),
      onChanged: (_) => _scheduleSettingsSave(),
    );
  }

  Widget _buildModelField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: RawAutocomplete<String>(
            textEditingController: _modelController,
            focusNode: _modelFocusNode,
            optionsBuilder: (TextEditingValue value) {
              final String query = value.text.trim().toLowerCase();
              if (query.isEmpty) return _availableModels;
              return _availableModels.where(
                (model) => model.toLowerCase().contains(query),
              );
            },
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
                  return AppTextField(
                    key: const ValueKey<String>("copilot-model-field"),
                    controller: controller,
                    focusNode: focusNode,
                    labelText: "使用模型",
                    hintText: "選擇或輸入模型 ID",
                    prefixIcon: const Icon(Icons.memory),
                    onChanged: (_) => _scheduleSettingsSave(),
                  );
                },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 260,
                      maxWidth: 520,
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final String option = options.elementAt(index);
                        return ListTile(
                          dense: true,
                          title: Text(option),
                          onTap: () {
                            onSelected(option);
                            _scheduleSettingsSave();
                          },
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: _isLoadingModels
              ? CircularProgressIndicator()
              : const Icon(Icons.refresh),
          tooltip: "抓取",
          onPressed: _isLoadingModels ? null : _fetchModels,
          style: IconButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ],
    );
  }

  Widget _buildApiKeyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          key: const ValueKey<String>("copilot-api-key-field"),
          controller: _apiKeyController,
          obscureText: !_showApiKey,
          labelText: "API Key",
          prefixIcon: const Icon(Icons.key),
          suffixIcon: IconButton(
            tooltip: _showApiKey ? "隱藏 API Key" : "顯示 API Key",
            onPressed: () => setState(() => _showApiKey = !_showApiKey),
            icon: Icon(_showApiKey ? Icons.visibility_off : Icons.visibility),
          ),
          onChanged: (_) => _scheduleSettingsSave(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const ValueKey<String>("copilot-clear-api-key"),
            onPressed: _isSending ? null : _clearStoredApiKey,
            icon: const Icon(Icons.key_off_outlined),
            label: const Text("清除已儲存 Key"),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyAndLimitationsPanel() {
    return AppSectionCard(
      padding: EdgeInsets.zero,
      useSectionLayout: false,
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ExpansionTile(
        key: const ValueKey<String>("copilot-privacy-limitations-panel"),
        leading: const Icon(Icons.privacy_tip_outlined),
        title: const Text("隱私、第三方服務與已知限制"),
        childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: const [
          SizedBox(height: 8),
          _CopilotDisclosureItem(
            icon: Icons.cloud_upload_outlined,
            text:
                "Chat 會傳送你輸入的訊息；Ask／Plan 另會傳送畫面標示的作品上下文。資料直接送往你設定的 provider 與 API URL，不經 Monogatari Assistant 伺服器。",
          ),
          _CopilotDisclosureItem(
            icon: Icons.policy_outlined,
            text:
                "第三方 provider 是否保存或使用資料，依該服務的條款與帳號設定決定。localhost Ollama 可留在本機，但其他自訂 URL 不一定私密。",
          ),
          _CopilotDisclosureItem(
            icon: Icons.history_outlined,
            text: "對話與 Plan 目前只保留在本次畫面工作階段，不會寫入專案，也不會跨啟動還原。",
          ),
          _CopilotDisclosureItem(
            icon: Icons.warning_amber_outlined,
            text: "AI 回覆可能不正確。Plan 僅供檢視與匯出，不會自動修改作品；Agent 模式目前停用。",
          ),
        ],
      ),
    );
  }

  Widget _buildConversationPanel() {
    return AppSectionCard(
      padding: EdgeInsets.zero,
      useSectionLayout: false,
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const MediumTitle(icon: Icons.forum_outlined, text: "對話紀錄"),
                const Spacer(),
                TextButton.icon(
                  onPressed: _messages.isEmpty || _isSending
                      ? null
                      : _clearConversation,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text("清空"),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CollectionPanel.custom(
              title: "對話紀錄",
              showSectionCard: false,
              minHeight: 420,
              maxHeight: 420,
              content: _messages.isEmpty
                  ? const AppEmptyState(
                      title: "尚無對話紀錄",
                      description: "送出訊息後會顯示在這裡",
                      icon: Icons.chat_bubble_outline,
                      compact: true,
                    )
                  : ListView.separated(
                      controller: _conversationScrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _buildMessageBubble(_messages[index]),
                    ),
            ),
            if (_statusMessage != null || _errorMessage != null) ...[
              const SizedBox(height: 12),
              _buildStatusMessage(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusMessage() {
    final bool hasError = _errorMessage != null;
    final Color color = hasError
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          hasError ? Icons.error_outline : Icons.check_circle_outline,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            hasError ? _errorMessage! : _statusMessage!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(CopilotConversationMessage message) {
    final bool isUser = message.role == CopilotConversationRole.user;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color bubbleColor = isUser
        ? colorScheme.primaryContainer
        : colorScheme.secondaryContainer;
    final Color textColor = isUser
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSecondaryContainer;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUser ? Icons.person_outline : Icons.auto_awesome,
                    size: 18,
                    color: textColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isUser ? "你" : "Copilot",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(
                message.content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  height: 1.45,
                ),
              ),
              if (message.askResponse case final response?) ...[
                const SizedBox(height: 12),
                _buildAskDetails(response, message.contextSnapshot, textColor),
              ] else if (!isUser && message.mode == CopilotMode.ask) ...[
                const SizedBox(height: 8),
                Text(
                  "模型未提供可驗證的結構化來源。",
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: textColor),
                ),
              ],
              if (message.plan case final plan?) ...[
                const SizedBox(height: 12),
                _buildPlanDetails(plan, message.contextSnapshot, textColor),
              ] else if (message.planValidationError case final error?) ...[
                const SizedBox(height: 8),
                Text(
                  "無法驗證 Plan：$error\n已保留模型原始回覆，未套用任何變更。",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAskDetails(
    CopilotAskResponse response,
    CopilotContextSnapshot? contextSnapshot,
    Color textColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (response.citations.isEmpty)
          Text(
            "模型未提供可驗證來源。",
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: textColor),
          )
        else ...[
          Text(
            "來源",
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final citation in response.citations)
                _buildCitationChip(citation, contextSnapshot),
            ],
          ),
        ],
        if (response.uncertainties.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            "不確定：${response.uncertainties.join("；")}",
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: textColor),
          ),
        ],
        if (response.discardedInvalidCitations) ...[
          const SizedBox(height: 6),
          Text(
            "已忽略模型提供的無效來源。",
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: textColor),
          ),
        ],
      ],
    );
  }

  Widget _buildCitationChip(
    CopilotCitation citation,
    CopilotContextSnapshot? contextSnapshot,
  ) {
    final resource = contextSnapshot?.resourceById(citation.resourceId);
    VoidCallback? onOpen;
    if (resource?.resourceType == "chapter" && widget.onOpenChapter != null) {
      onOpen = () => widget.onOpenChapter!(citation.resourceId);
    } else if (resource != null &&
        resource.resourceType != "project" &&
        widget.onOpenResource != null) {
      onOpen = () =>
          widget.onOpenResource!(resource.resourceType, resource.resourceId);
    }
    return Tooltip(
      message: citation.quoteHint,
      child: onOpen == null
          ? Chip(
              avatar: const Icon(Icons.menu_book_outlined, size: 16),
              label: Text(citation.resourceTitle),
            )
          : ActionChip(
              avatar: const Icon(Icons.open_in_new_outlined, size: 16),
              label: Text(citation.resourceTitle),
              tooltip: "開啟來源：${citation.quoteHint}",
              onPressed: onOpen,
            ),
    );
  }

  bool _isContextStale(CopilotContextSnapshot? original) {
    if (original == null) return true;
    try {
      final current = _captureCurrentChapterContext();
      return current.resourceId != original.resourceId ||
          current.fingerprint != original.fingerprint;
    } on FormatException {
      return true;
    }
  }

  Future<void> _copyPlan(CopilotPlan plan) async {
    const encoder = JsonEncoder.withIndent("  ");
    await Clipboard.setData(
      ClipboardData(text: encoder.convert(plan.toJson())),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("已複製 Plan JSON。")));
  }

  String _planExportBaseName(CopilotPlan plan) {
    final sanitized = plan.goal
        .trim()
        .replaceAll(RegExp(r"[^\p{L}\p{N}_-]+", unicode: true), "_")
        .replaceAll(RegExp(r"_+"), "_")
        .replaceAll(RegExp(r"^_+|_+$"), "");
    final slug = sanitized.isEmpty
        ? "plan"
        : sanitized.substring(0, sanitized.length.clamp(0, 48));
    return "copilot_plan_$slug";
  }

  Future<void> _exportPlan(CopilotPlan plan) async {
    const encoder = JsonEncoder.withIndent("  ");
    try {
      final exported = await FileService.exportTextWithResult(
        content: encoder.convert(plan.toJson()),
        fileName: _planExportBaseName(plan),
        extension: ".json",
      );
      if (!mounted || !exported) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Plan JSON 匯出完成。")));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Plan JSON 匯出失敗，請確認儲存位置與檔案權限。")),
      );
    }
  }

  Widget _buildPlanDetails(
    CopilotPlan plan,
    CopilotContextSnapshot? originalContext,
    Color textColor,
  ) {
    final orderedSteps = [...plan.steps]
      ..sort((left, right) => left.order.compareTo(right.order));
    final isStale = _isContextStale(originalContext);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.goal,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _copyPlan(plan),
                icon: const Icon(Icons.copy_outlined),
                tooltip: "複製 Plan JSON",
                color: textColor,
              ),
              IconButton(
                onPressed: () => _exportPlan(plan),
                icon: const Icon(Icons.download_outlined),
                tooltip: "匯出 Plan JSON",
                color: textColor,
              ),
            ],
          ),
          if (isStale) ...[
            const SizedBox(height: 4),
            Text(
              "目前章節已變更，這份計畫可能已過期。",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 8),
          for (final step in orderedSteps)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                "${step.order}. ${step.proposal}\n${step.reason}",
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: textColor),
              ),
            ),
          if (plan.risks.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              "風險：${plan.risks.join("；")}",
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: textColor),
            ),
          ],
          if (plan.questions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              "待確認：${plan.questions.join("；")}",
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: textColor),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            "唯讀計畫・尚未套用任何變更",
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _transmittedContextLabel() {
    if (_selectedMode != CopilotMode.ask) return "目前章節";
    return switch (_selectedContextScope) {
      CopilotContextScope.currentChapter => "目前章節",
      CopilotContextScope.currentChapterWithProjectOverview => "目前章節與專案索引摘要",
      CopilotContextScope.currentChapterWithSelectedResources => "目前章節與勾選的補充資源",
    };
  }

  Widget _buildComposerPanel() {
    return AppSectionCard(
      padding: EdgeInsets.zero,
      useSectionLayout: false,
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedMode == CopilotMode.ask ||
                _selectedMode == CopilotMode.plan) ...[
              AppNoticeBanner(
                message:
                    "${_selectedMode == CopilotMode.ask ? "Ask" : "Plan"} "
                    "會把${_transmittedContextLabel()}"
                    "直接傳送到你設定的模型服務；不會修改專案。",
                tone: AppFeedbackTone.info,
              ),
              if (_selectedMode == CopilotMode.ask) ...[
                const SizedBox(height: 12),
                _buildContextScopeSelector(),
                if (_selectedContextScope ==
                    CopilotContextScope
                        .currentChapterWithSelectedResources) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: _isSending ? null : _selectContextResources,
                      icon: const Icon(Icons.library_add_check_outlined),
                      label: Text(
                        "選擇補充資源（${_selectedResourceKeys.length}/"
                        "${CopilotProjectContextBuilder.maxSelectedResources}）",
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 8),
              Text(
                _currentContextSummary(),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 16),
            ],
            Shortcuts(
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.enter):
                    _SendCopilotMessageIntent(),
              },
              child: Actions(
                actions: {
                  _SendCopilotMessageIntent:
                      CallbackAction<_SendCopilotMessageIntent>(
                        onInvoke: (_) {
                          unawaited(_sendMessage());
                          return null;
                        },
                      ),
                },
                child: AppTextField(
                  key: const ValueKey<String>("copilot-message-field"),
                  controller: _messageController,
                  enabled: _selectedMode != CopilotMode.agent && !_isSending,
                  minLines: 3,
                  maxLines: 8,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: switch (_selectedMode) {
                      CopilotMode.chat => "輸入訊息，Shift+Enter 換行，Enter 發送",
                      CopilotMode.ask => "詢問目前章節內容",
                      CopilotMode.plan => "描述希望規劃的修改目標",
                      CopilotMode.agent => "Agent 模式暫不可用",
                    },
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 56),
                      child: Icon(Icons.chat_bubble_outline),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildModeSelector(),
                const Spacer(),
                IconButton(
                  icon: _isSending
                      ? const Icon(Icons.stop_circle_outlined)
                      : const Icon(Icons.send),
                  tooltip: _isSending ? "取消請求" : "發送",
                  onPressed: _isSending
                      ? _cancelActiveRequest
                      : _selectedMode == CopilotMode.agent
                      ? null
                      : _sendMessage,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              "Shift+Enter 換行、Enter 發送",
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return SizedBox(
      width: 180,
      child: AppDropdownField<CopilotMode>(
        key: const ValueKey<String>("copilot-mode-selector"),
        value: _selectedMode,
        labelText: "模式選擇",
        options: [
          const DropdownOption<CopilotMode>(
            value: CopilotMode.chat,
            label: "Chat",
          ),
          DropdownOption<CopilotMode>(
            value: CopilotMode.ask,
            label: "Ask (Beta)",
            enabled: widget.askEnabled,
          ),
          DropdownOption<CopilotMode>(
            value: CopilotMode.plan,
            label: "Plan (Beta)",
            enabled: widget.planEnabled,
          ),
          const DropdownOption<CopilotMode>(
            value: CopilotMode.agent,
            label: "Agent (暫不可用)",
            enabled: false,
          ),
        ],
        onChanged: _isSending
            ? null
            : (value) {
                if (value == null) return;
                setState(() {
                  _selectedMode = value;
                  _statusMessage = null;
                  _errorMessage = null;
                });
              },
      ),
    );
  }

  Widget _buildContextScopeSelector() {
    return AppDropdownField<CopilotContextScope>(
      key: const ValueKey<String>("copilot-context-scope-selector"),
      value: _selectedContextScope,
      labelText: "Ask 上下文",
      options: const [
        DropdownOption<CopilotContextScope>(
          value: CopilotContextScope.currentChapter,
          label: "目前章節",
        ),
        DropdownOption<CopilotContextScope>(
          value: CopilotContextScope.currentChapterWithProjectOverview,
          label: "目前章節＋專案摘要",
        ),
        DropdownOption<CopilotContextScope>(
          value: CopilotContextScope.currentChapterWithSelectedResources,
          label: "目前章節＋選取資源",
        ),
      ],
      onChanged: _isSending
          ? null
          : (value) {
              if (value == null) return;
              setState(() => _selectedContextScope = value);
            },
    );
  }

  IconData _resourceIcon(String resourceType) {
    return switch (resourceType) {
      "character" => Icons.person_outline,
      "worldSetting" => Icons.public_outlined,
      "outlineEvent" => Icons.account_tree_outlined,
      "glossaryTerm" => Icons.menu_book_outlined,
      _ => Icons.description_outlined,
    };
  }

  Future<void> _selectContextResources() async {
    final options =
        widget.selectableResources ??
        CopilotProjectContextBuilder.selectableResources(
          ref.read(projectDataProvider),
          glossaryEntries: ref.read(glossaryStateProvider).entryIndex,
        );
    final availableKeys = options
        .map((resource) => resource.selectionKey)
        .toSet();
    final selected = _selectedResourceKeys
        .where(availableKeys.contains)
        .toSet();
    String query = "";
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final normalizedQuery = query.trim().toLowerCase();
          final filtered = normalizedQuery.isEmpty
              ? options
              : options
                    .where(
                      (resource) =>
                          resource.title.toLowerCase().contains(
                            normalizedQuery,
                          ) ||
                          resource.description.toLowerCase().contains(
                            normalizedQuery,
                          ),
                    )
                    .toList(growable: false);
          final dialogHeight = (MediaQuery.sizeOf(dialogContext).height * 0.62)
              .clamp(280.0, 520.0);
          return AlertDialog(
            title: const Text("選擇 Ask 補充資源"),
            content: SizedBox(
              width: 620,
              height: dialogHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const ValueKey<String>(
                      "copilot-resource-search-field",
                    ),
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: "搜尋角色、世界觀、大綱或詞語",
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setDialogState(() => query = value),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "已選 ${selected.length}/"
                    "${CopilotProjectContextBuilder.maxSelectedResources}；"
                    "只會傳送勾選項目的內容。",
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text("沒有符合的資源。"))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final resource = filtered[index];
                              final isSelected = selected.contains(
                                resource.selectionKey,
                              );
                              final canSelect =
                                  isSelected ||
                                  selected.length <
                                      CopilotProjectContextBuilder
                                          .maxSelectedResources;
                              return CheckboxListTile(
                                key: ValueKey<String>(
                                  "copilot-resource-${resource.selectionKey}",
                                ),
                                value: isSelected,
                                dense: true,
                                secondary: Icon(
                                  _resourceIcon(resource.resourceType),
                                ),
                                title: Text(resource.title),
                                subtitle: Text(resource.description),
                                onChanged: !canSelect
                                    ? null
                                    : (checked) {
                                        setDialogState(() {
                                          if (checked == true) {
                                            selected.add(resource.selectionKey);
                                          } else {
                                            selected.remove(
                                              resource.selectionKey,
                                            );
                                          }
                                        });
                                      },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => setDialogState(selected.clear),
                child: const Text("清除"),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text("取消"),
              ),
              FilledButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(Set<String>.unmodifiable(selected)),
                child: const Text("使用選取項目"),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _selectedResourceKeys = result);
  }

  String _currentContextSummary() {
    try {
      final snapshot = _captureCurrentChapterContext();
      final bytes = utf8.encode(snapshot.content).length;
      final suffix = snapshot.truncated ? "，已截斷" : "";
      final overviewLabel =
          _selectedMode == CopilotMode.ask &&
              _selectedContextScope ==
                  CopilotContextScope.currentChapterWithProjectOverview
          ? "＋專案索引摘要（上限 24 KiB）"
          : _selectedMode == CopilotMode.ask &&
                _selectedContextScope ==
                    CopilotContextScope.currentChapterWithSelectedResources
          ? "＋已選 ${_selectedResourceKeys.length} 個補充資源（上限 32 KiB）"
          : "";
      return "上下文：${snapshot.title}（$bytes bytes$suffix）$overviewLabel";
    } on FormatException {
      return "上下文：尚未選擇章節";
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(editorSelectionProvider);
    ref.watch(segmentsDataProvider);
    ref.watch(selectedChapterStoredContentProvider);
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: LargeTitle(icon: Icons.auto_awesome, text: "Copilot"),
            ),
            const SizedBox(height: 32),
            _buildWarningCard(),
            const SizedBox(height: 16),
            _buildModelPanel(),
            const SizedBox(height: 16),
            _buildPrivacyAndLimitationsPanel(),
            const SizedBox(height: 16),
            _buildConversationPanel(),
            const SizedBox(height: 16),
            _buildComposerPanel(),
          ],
        ),
      ),
    );
  }
}

class _CopilotDisclosureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CopilotDisclosureItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
