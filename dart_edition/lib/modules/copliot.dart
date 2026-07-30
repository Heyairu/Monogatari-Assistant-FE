/*
 * ものがたり·アシスタント - Monogatari Assistant
 * Copyright (c) 2025 Heyairu（部屋伊琉）
 *
 * Licensed under the Business Source License 1.1 (Modified).
 * You may not use this file except in compliance with the License.
 * Change Date: 2030-11-04 05:14 a.m. (UTC+8)
 * Change License: Apache License 2.0
 *
 * Commercial use allowed under conditions described in Section 1;
 * Competing products (≥3 overlapping modules or similar UI structure)
 * and repackaging without permission are prohibited.
 */

import "dart:async";
import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";

import "../bin/ui_library.dart";

enum CopilotMode { chat, ask, plan, agent }

enum _CopilotRole { user, assistant, system }

enum _CopilotModelReadMethod { openAiCompatible, gemini, anthropic, ollama }

class _ProviderPreset {
  final String name;
  final String apiUrl;
  final List<String> fallbackModels;
  final _CopilotModelReadMethod modelReadMethod;

  const _ProviderPreset({
    required this.name,
    required this.apiUrl,
    required this.fallbackModels,
    required this.modelReadMethod,
  });
}

class _CopilotMessage {
  final _CopilotRole role;
  final String content;
  final DateTime createdAt;

  const _CopilotMessage({
    required this.role,
    required this.content,
    required this.createdAt,
  });
}

class _SendCopilotMessageIntent extends Intent {
  const _SendCopilotMessageIntent();
}

class CopilotView extends StatefulWidget {
  const CopilotView({super.key});

  @override
  State<CopilotView> createState() => _CopilotViewState();
}

class _CopilotViewState extends State<CopilotView> {
  static const String _providerPrefsKey = "copilot_provider";
  static const String _apiUrlPrefsKey = "copilot_api_url";
  static const String _modelPrefsKey = "copilot_model";
  static const String _apiKeyPrefsKey = "copilot_api_key";

  static const List<_ProviderPreset> _providerPresets = [
    _ProviderPreset(
      name: "OpenAI",
      apiUrl: "https://api.openai.com/v1",
      fallbackModels: [""],
      modelReadMethod: _CopilotModelReadMethod.openAiCompatible,
    ),
    _ProviderPreset(
      name: "Gemini",
      apiUrl: "https://generativelanguage.googleapis.com",
      fallbackModels: [""],
      modelReadMethod: _CopilotModelReadMethod.gemini,
    ),
    _ProviderPreset(
      name: "Anthropic",
      apiUrl: "https://api.anthropic.com/v1",
      fallbackModels: [""],
      modelReadMethod: _CopilotModelReadMethod.anthropic,
    ),
    _ProviderPreset(
      name: "Grok",
      apiUrl: "https://api.x.ai/v1",
      fallbackModels: [""],
      modelReadMethod: _CopilotModelReadMethod.openAiCompatible,
    ),
    _ProviderPreset(
      name: "OpenRouter",
      apiUrl: "https://openrouter.ai/api/v1",
      fallbackModels: [""],
      modelReadMethod: _CopilotModelReadMethod.openAiCompatible,
    ),
    _ProviderPreset(
      name: "Ollama",
      apiUrl: "http://localhost:11434/v1",
      fallbackModels: [""],
      modelReadMethod: _CopilotModelReadMethod.ollama,
    ),
    _ProviderPreset(
      name: "自訂",
      apiUrl: "",
      fallbackModels: [],
      modelReadMethod: _CopilotModelReadMethod.openAiCompatible,
    ),
  ];

  final TextEditingController _providerController = TextEditingController();
  final TextEditingController _apiUrlController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _modelFocusNode = FocusNode();
  final ScrollController _conversationScrollController = ScrollController();

  final List<_CopilotMessage> _messages = [];
  List<String> _availableModels = [];
  CopilotMode _selectedMode = CopilotMode.chat;
  bool _modelPanelExpanded = true;
  bool _isLoadingModels = false;
  bool _isSending = false;
  bool _showApiKey = false;
  String? _statusMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
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
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final _ProviderPreset defaultPreset = _providerPresets.first;

    if (!mounted) return;
    setState(() {
      _providerController.text =
          prefs.getString(_providerPrefsKey) ?? defaultPreset.name;
      _apiUrlController.text =
          prefs.getString(_apiUrlPrefsKey) ?? defaultPreset.apiUrl;
      _modelController.text =
          prefs.getString(_modelPrefsKey) ?? defaultPreset.fallbackModels.first;
      _apiKeyController.text = prefs.getString(_apiKeyPrefsKey) ?? "";
      _availableModels = defaultPreset.fallbackModels;
    });
  }

  Future<void> _saveSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerPrefsKey, _providerController.text.trim());
    await prefs.setString(_apiUrlPrefsKey, _apiUrlController.text.trim());
    await prefs.setString(_modelPrefsKey, _modelController.text.trim());
    await prefs.setString(_apiKeyPrefsKey, _apiKeyController.text);
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
    unawaited(_saveSettings());
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
    return Uri.parse("$baseUrl$path");
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

  Map<String, String> _buildHeaders({_CopilotModelReadMethod? readMethod}) {
    final String apiKey = _apiKeyController.text.trim();
    if (readMethod == _CopilotModelReadMethod.gemini) {
      return {"Content-Type": "application/json"};
    }

    if (readMethod == _CopilotModelReadMethod.ollama) {
      return {"Content-Type": "application/json"};
    }

    if (readMethod == _CopilotModelReadMethod.anthropic) {
      return {
        "Content-Type": "application/json",
        "anthropic-version": "2023-06-01",
        if (apiKey.isNotEmpty) "x-api-key": apiKey,
      };
    }

    return {
      "Content-Type": "application/json",
      if (apiKey.isNotEmpty) "Authorization": "Bearer $apiKey",
    };
  }

  List<Map<String, String>> _buildOpenAiCompatibleMessages() {
    return _messages
        .where((message) => message.role != _CopilotRole.system)
        .map(
          (message) => {
            "role": message.role == _CopilotRole.user ? "user" : "assistant",
            "content": message.content,
          },
        )
        .toList();
  }

  List<Map<String, Object>> _buildGeminiContents() {
    return _messages
        .where((message) => message.role != _CopilotRole.system)
        .map(
          (message) => {
            "role": message.role == _CopilotRole.user ? "user" : "model",
            "parts": [
              {"text": message.content},
            ],
          },
        )
        .toList();
  }

  String _normalizeGeminiModelName(String model) {
    final String trimmed = model.trim();
    if (trimmed.startsWith("models/")) {
      return trimmed.substring("models/".length);
    }
    return trimmed;
  }

  Future<http.Response> _readModelsResponse() {
    final _ProviderPreset preset = _selectedProviderPreset();
    final _CopilotModelReadMethod method = preset.modelReadMethod;
    final String apiKey = _apiKeyController.text.trim();

    switch (method) {
      case _CopilotModelReadMethod.gemini:
        return http
            .get(
              _buildProviderEndpointUri(
                "/v1beta/models",
                query: apiKey.isEmpty ? null : {"key": apiKey},
              ),
              headers: _buildHeaders(readMethod: method),
            )
            .timeout(const Duration(seconds: 30));
      case _CopilotModelReadMethod.anthropic:
        return http
            .get(
              _buildProviderEndpointUri("/models"),
              headers: _buildHeaders(readMethod: method),
            )
            .timeout(const Duration(seconds: 30));
      case _CopilotModelReadMethod.ollama:
        if (_isOllamaV1Url) {
          return http
              .get(
                _buildProviderEndpointUri("/models"),
                headers: _buildHeaders(readMethod: method),
              )
              .timeout(const Duration(seconds: 30));
        }
        return http
            .get(
              _buildProviderEndpointUri("/api/tags"),
              headers: _buildHeaders(readMethod: method),
            )
            .timeout(const Duration(seconds: 30));
      case _CopilotModelReadMethod.openAiCompatible:
        return http
            .get(
              _buildProviderEndpointUri("/models"),
              headers: _buildHeaders(readMethod: method),
            )
            .timeout(const Duration(seconds: 30));
    }
  }

  Future<void> _fetchModels() async {
    if (_isLoadingModels) return;

    setState(() {
      _isLoadingModels = true;
      _statusMessage = null;
      _errorMessage = null;
    });

    try {
      await _saveSettings();
      final _ProviderPreset preset = _selectedProviderPreset();
      final http.Response response = await _readModelsResponse();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception("模型抓取失敗 (${response.statusCode})：${response.body}");
      }

      final Object? decoded = jsonDecode(response.body);
      final List<String> models = _extractModelIds(
        decoded,
        preset.modelReadMethod,
      );
      if (models.isEmpty) {
        throw Exception("回應中沒有可用模型。");
      }

      setState(() {
        _availableModels = models;
        if (!_availableModels.contains(_modelController.text.trim())) {
          _modelController.text = _availableModels.first;
        }
        _statusMessage = "已抓取 ${_availableModels.length} 個模型。";
      });
      await _saveSettings();
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoadingModels = false);
      }
    }
  }

  List<String> _extractModelIds(
    Object? decoded,
    _CopilotModelReadMethod readMethod,
  ) {
    if (decoded is Map<String, Object?>) {
      if (readMethod == _CopilotModelReadMethod.gemini) {
        final Object? models = decoded["models"];
        if (models is List<Object?>) {
          return models
              .whereType<Map<String, Object?>>()
              .map((item) => item["name"])
              .whereType<String>()
              .map(
                (name) => name.startsWith("models/")
                    ? name.substring("models/".length)
                    : name,
              )
              .where((id) => id.trim().isNotEmpty)
              .toSet()
              .toList()
            ..sort();
        }
      }

      final Object? data = decoded["data"];
      if (data is List<Object?>) {
        return data
            .whereType<Map<String, Object?>>()
            .map((item) => item["id"])
            .whereType<String>()
            .where((id) => id.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
      }

      final Object? models = decoded["models"];
      if (models is List<Object?>) {
        return models
            .map((item) {
              if (item is String) return item;
              if (item is Map<String, Object?>) return item["name"] as String?;
              return null;
            })
            .whereType<String>()
            .where((id) => id.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
      }
    }
    return [];
  }

  Future<http.Response> _readOpenAiCompatibleChatResponse(
    String model,
    _CopilotModelReadMethod method,
  ) {
    return http
        .post(
          _buildProviderEndpointUri("/chat/completions"),
          headers: _buildHeaders(readMethod: method),
          body: jsonEncode({
            "model": model,
            "messages": _buildOpenAiCompatibleMessages(),
            "temperature": 0.7,
          }),
        )
        .timeout(const Duration(seconds: 60));
  }

  Future<http.Response> _readChatResponse(String model) {
    final _ProviderPreset preset = _selectedProviderPreset();
    final _CopilotModelReadMethod method = preset.modelReadMethod;
    final String apiKey = _apiKeyController.text.trim();

    switch (method) {
      case _CopilotModelReadMethod.gemini:
        return http
            .post(
              _buildProviderEndpointUri(
                "/v1beta/models/${Uri.encodeComponent(_normalizeGeminiModelName(model))}:generateContent",
                query: apiKey.isEmpty ? null : {"key": apiKey},
              ),
              headers: _buildHeaders(readMethod: method),
              body: jsonEncode({
                "contents": _buildGeminiContents(),
                "generationConfig": {"temperature": 0.7},
              }),
            )
            .timeout(const Duration(seconds: 60));
      case _CopilotModelReadMethod.anthropic:
        return http
            .post(
              _buildProviderEndpointUri("/messages"),
              headers: _buildHeaders(readMethod: method),
              body: jsonEncode({
                "model": model,
                "max_tokens": 4096,
                "messages": _buildOpenAiCompatibleMessages(),
              }),
            )
            .timeout(const Duration(seconds: 60));
      case _CopilotModelReadMethod.ollama:
        if (_isOllamaV1Url) {
          return _readOpenAiCompatibleChatResponse(model, method);
        }
        return http
            .post(
              _buildProviderEndpointUri("/api/chat"),
              headers: _buildHeaders(readMethod: method),
              body: jsonEncode({
                "model": model,
                "messages": _buildOpenAiCompatibleMessages(),
                "stream": false,
                "options": {"temperature": 0.7},
              }),
            )
            .timeout(const Duration(seconds: 60));
      case _CopilotModelReadMethod.openAiCompatible:
        return _readOpenAiCompatibleChatResponse(model, method);
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending || _selectedMode != CopilotMode.chat) return;

    final String prompt = _messageController.text.trim();
    final String model = _modelController.text.trim();
    if (prompt.isEmpty) return;

    if (model.isEmpty) {
      setState(() => _errorMessage = "請先選擇或輸入使用模型。");
      return;
    }

    final _CopilotMessage userMessage = _CopilotMessage(
      role: _CopilotRole.user,
      content: prompt,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _messageController.clear();
      _isSending = true;
      _statusMessage = null;
      _errorMessage = null;
    });
    _scrollConversationToBottom();

    try {
      await _saveSettings();
      final _ProviderPreset preset = _selectedProviderPreset();
      final http.Response response = await _readChatResponse(model);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception("對話請求失敗 (${response.statusCode})：${response.body}");
      }

      final String reply = _extractAssistantReply(
        jsonDecode(response.body),
        preset.modelReadMethod,
      );
      setState(() {
        _messages.add(
          _CopilotMessage(
            role: _CopilotRole.assistant,
            content: reply,
            createdAt: DateTime.now(),
          ),
        );
      });
      _scrollConversationToBottom();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _messageController.text = prompt;
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _extractAssistantReply(
    Object? decoded,
    _CopilotModelReadMethod readMethod,
  ) {
    if (decoded is Map<String, Object?>) {
      if (readMethod == _CopilotModelReadMethod.gemini) {
        final Object? candidates = decoded["candidates"];
        if (candidates is List<Object?> && candidates.isNotEmpty) {
          final Object? first = candidates.first;
          if (first is Map<String, Object?>) {
            final String text = _extractGeminiText(first["content"]);
            if (text.isNotEmpty) {
              return text;
            }
          }
        }
      }

      if (readMethod == _CopilotModelReadMethod.anthropic) {
        final String text = _extractAnthropicText(decoded["content"]);
        if (text.isNotEmpty) {
          return text;
        }
      }

      if (readMethod == _CopilotModelReadMethod.ollama && !_isOllamaV1Url) {
        final Object? message = decoded["message"];
        if (message is Map<String, Object?>) {
          final Object? content = message["content"];
          if (content is String && content.trim().isNotEmpty) {
            return content.trim();
          }
        }

        final Object? response = decoded["response"];
        if (response is String && response.trim().isNotEmpty) {
          return response.trim();
        }
      }

      final Object? choices = decoded["choices"];
      if (choices is List<Object?> && choices.isNotEmpty) {
        final Object? first = choices.first;
        if (first is Map<String, Object?>) {
          final Object? message = first["message"];
          if (message is Map<String, Object?>) {
            final Object? content = message["content"];
            if (content is String && content.trim().isNotEmpty) {
              return content.trim();
            }
          }
          final Object? text = first["text"];
          if (text is String && text.trim().isNotEmpty) {
            return text.trim();
          }
        }
      }
    }
    return "模型已回應，但無法解析文字內容。";
  }

  String _extractGeminiText(Object? content) {
    if (content is! Map<String, Object?>) {
      return "";
    }

    final Object? parts = content["parts"];
    if (parts is! List<Object?>) {
      return "";
    }

    return parts
        .whereType<Map<String, Object?>>()
        .map((part) => part["text"])
        .whereType<String>()
        .where((text) => text.trim().isNotEmpty)
        .join("\n")
        .trim();
  }

  String _extractAnthropicText(Object? content) {
    if (content is! List<Object?>) {
      return "";
    }

    return content
        .whereType<Map<String, Object?>>()
        .where((part) => part["type"] == "text")
        .map((part) => part["text"])
        .whereType<String>()
        .where((text) => text.trim().isNotEmpty)
        .join("\n")
        .trim();
  }

  void _clearConversation() {
    setState(() {
      _messages.clear();
      _statusMessage = null;
      _errorMessage = null;
    });
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
      message: "本功能正在開發中，Ask / Plan / Agent 模式暫不可用。",
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
      controller: _apiUrlController,
      labelText: "API URL",
      hintText: "https://api.openai.com/v1",
      prefixIcon: const Icon(Icons.link),
      onChanged: (_) => unawaited(_saveSettings()),
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
                    controller: controller,
                    focusNode: focusNode,
                    labelText: "使用模型",
                    hintText: "選擇或輸入模型 ID",
                    prefixIcon: const Icon(Icons.memory),
                    onChanged: (_) => unawaited(_saveSettings()),
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
                            unawaited(_saveSettings());
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
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: _isLoadingModels ? null : _fetchModels,
            icon: _isLoadingModels
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: const Text("抓取"),
          ),
        ),
      ],
    );
  }

  Widget _buildApiKeyField() {
    return AppTextField(
      controller: _apiKeyController,
      obscureText: !_showApiKey,
      labelText: "API Key",
      prefixIcon: const Icon(Icons.key),
      suffixIcon: IconButton(
        tooltip: _showApiKey ? "隱藏 API Key" : "顯示 API Key",
        onPressed: () => setState(() => _showApiKey = !_showApiKey),
        icon: Icon(_showApiKey ? Icons.visibility_off : Icons.visibility),
      ),
      onChanged: (_) => unawaited(_saveSettings()),
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
                  onPressed: _messages.isEmpty ? null : _clearConversation,
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

  Widget _buildMessageBubble(_CopilotMessage message) {
    final bool isUser = message.role == _CopilotRole.user;
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
            ],
          ),
        ),
      ),
    );
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
                  controller: _messageController,
                  enabled: _selectedMode == CopilotMode.chat && !_isSending,
                  minLines: 3,
                  maxLines: 8,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: _selectedMode == CopilotMode.chat
                        ? "輸入訊息，Shift+Enter 換行，Enter 發送"
                        : "此模式暫不可用",
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 56),
                      child: Icon(Icons.chat_bubble_outline),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Shift+Enter 換行、Enter 發送",
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildModeSelector(),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _isSending || _selectedMode != CopilotMode.chat
                      ? null
                      : _sendMessage,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isSending ? "發送中" : "發送"),
                ),
              ],
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
        value: _selectedMode,
        labelText: "模式選擇",
        options: const [
          DropdownOption<CopilotMode>(value: CopilotMode.chat, label: "Chat"),
          DropdownOption<CopilotMode>(
            value: CopilotMode.ask,
            label: "Ask (暫不可用)",
            enabled: false,
          ),
          DropdownOption<CopilotMode>(
            value: CopilotMode.plan,
            label: "Plan (暫不可用)",
            enabled: false,
          ),
          DropdownOption<CopilotMode>(
            value: CopilotMode.agent,
            label: "Agent (暫不可用)",
            enabled: false,
          ),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() => _selectedMode = value);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            _buildConversationPanel(),
            const SizedBox(height: 16),
            _buildComposerPanel(),
          ],
        ),
      ),
    );
  }
}
