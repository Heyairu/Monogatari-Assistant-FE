// Copyright 2025-2026 Heyairu（部屋伊琉）
// Licensed under the Apache License, Version 2.0.

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../ui_library/forms.dart';
import 'help_catalog.dart';
import 'help_scope.dart';
import 'help_topic.dart';

class HelpViewer extends StatefulWidget {
  const HelpViewer({
    super.key,
    required this.topic,
    required this.focusNode,
    required this.loadCatalog,
    required this.retryCatalog,
    required this.onTopic,
  });
  final ValueListenable<String> topic;
  final FocusNode focusNode;
  final Future<HelpCatalog> Function() loadCatalog;
  final VoidCallback retryCatalog;
  final ValueChanged<String> onTopic;
  @override
  State<HelpViewer> createState() => _HelpViewerState();
}

class _HelpViewerState extends State<HelpViewer> {
  final _query = TextEditingController();
  final _articleScroll = ScrollController();
  final _history = <String>[];
  int _historyIndex = -1;
  bool _narrowDirectory = false;
  late Future<HelpCatalog> _catalog;
  @override
  void initState() {
    super.initState();
    _catalog = widget.loadCatalog();
    widget.topic.addListener(_topicChanged);
    _record(widget.topic.value);
  }

  void _record(String id) {
    if (_historyIndex >= 0 && _history[_historyIndex] == id) return;
    _history.removeRange(_historyIndex + 1, _history.length);
    _history.add(id);
    _historyIndex = _history.length - 1;
  }

  void _topicChanged() {
    setState(() {
      _record(widget.topic.value);
      _narrowDirectory = false;
    });
    if (_articleScroll.hasClients) _articleScroll.jumpTo(0);
  }

  void _move(int delta) {
    final next = _historyIndex + delta;
    if (next < 0 || next >= _history.length) return;
    widget.topic.removeListener(_topicChanged);
    setState(() {
      _historyIndex = next;
      _narrowDirectory = false;
    });
    widget.onTopic(_history[next]);
    widget.topic.addListener(_topicChanged);
    if (_articleScroll.hasClients) _articleScroll.jumpTo(0);
  }

  @override
  void dispose() {
    widget.topic.removeListener(_topicChanged);
    _query.dispose();
    _articleScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final fullscreen = size.width < 700;
    final body = HelpScope(
      topicId: HelpTopicId.usingHelp,
      child: Focus(
        focusNode: widget.focusNode,
        autofocus: true,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('說明中心', style: TextStyle(fontSize: 22)),
                  ),
                  IconButton(
                    tooltip: '關閉說明（Esc）',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    tooltip: '說明首頁',
                    onPressed: () => widget.onTopic(HelpTopicId.home),
                    icon: const Icon(Icons.home_outlined),
                  ),
                  IconButton(
                    tooltip: '上一頁',
                    onPressed: _historyIndex > 0 ? () => _move(-1) : null,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  IconButton(
                    tooltip: '下一頁',
                    onPressed: _historyIndex + 1 < _history.length
                        ? () => _move(1)
                        : null,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                  if (fullscreen)
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _narrowDirectory = !_narrowDirectory),
                      icon: Icon(
                        _narrowDirectory ? Icons.article_outlined : Icons.list,
                      ),
                      label: Text(_narrowDirectory ? '閱讀文章' : '目錄與搜尋'),
                    ),
                ],
              ),
              AppTextField(
                controller: _query,
                labelText: '搜尋說明',
                prefixIcon: const Icon(Icons.search),
                onChanged: (_) => setState(() => _narrowDirectory = true),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<HelpCatalog>(
                  future: _catalog,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('無法載入內建說明，請重試。'),
                              TextButton(
                                onPressed: () => setState(() {
                                  widget.retryCatalog();
                                  _catalog = widget.loadCatalog();
                                }),
                                child: const Text('重試'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final catalog = snapshot.data!;
                    if (fullscreen) {
                      return _narrowDirectory
                          ? _directory(catalog)
                          : _article(catalog);
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 240, child: _directory(catalog)),
                        const VerticalDivider(width: 24),
                        Expanded(child: _article(catalog)),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return fullscreen
        ? Dialog.fullscreen(child: SafeArea(child: body))
        : Dialog(
            child: SizedBox(
              width: math.min(960, size.width - 48),
              height: math.min(720, size.height - 48),
              child: body,
            ),
          );
  }

  Widget _directory(HelpCatalog catalog) {
    final topics = catalog.search(_query.text);
    if (topics.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('找不到符合的說明'),
            TextButton(
              onPressed: () => setState(() {
                _query.clear();
                _narrowDirectory = true;
              }),
              child: const Text('返回目錄'),
            ),
          ],
        ),
      );
    }
    String? category;
    return ListView(
      children: [
        for (final topic in topics) ...[
          if (_query.text.trim().isEmpty && category != topic.category)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4, left: 8),
              child: Text(
                category = topic.category,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ListTile(
            dense: true,
            selected: topic.id == widget.topic.value,
            title: Text(topic.title),
            onTap: () {
              widget.onTopic(topic.id);
              setState(() => _narrowDirectory = false);
            },
          ),
        ],
      ],
    );
  }

  Widget _article(HelpCatalog catalog) {
    final topic = catalog.topic(widget.topic.value);
    return SingleChildScrollView(
      controller: _articleScroll,
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(topic.title, style: Theme.of(context).textTheme.headlineSmall),
            for (final section in topic.sections) ...[
              if (section.heading.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Text(
                    section.heading,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              for (final text in section.paragraphs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(text),
                ),
              for (var i = 0; i < section.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${i + 1}. ${section.steps[i]}'),
                ),
            ],
            if (topic.relatedIds.isNotEmpty) ...[
              const Divider(),
              Text('相關說明', style: Theme.of(context).textTheme.titleSmall),
              Wrap(
                spacing: 8,
                children: [
                  for (final id in topic.relatedIds)
                    TextButton(
                      onPressed: () => widget.onTopic(id),
                      child: Text(catalog.topic(id).title),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
