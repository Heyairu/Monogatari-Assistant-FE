// Copyright 2025-2026 Heyairu（部屋伊琉）
// Licensed under the Apache License, Version 2.0.

import 'dart:async';
import 'package:flutter/gestures.dart' show GestureBinding;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../ui_library/dialogs.dart';
import 'help_catalog.dart';
import 'help_scope.dart';
import 'help_topic.dart';
import 'help_viewer.dart';

class HelpController extends ChangeNotifier {
  HelpController({
    required this.navigatorKey,
    Future<HelpCatalog> Function()? loadCatalog,
  }) : loadCatalog = loadCatalog ?? HelpCatalog.load;
  final GlobalKey<NavigatorState> navigatorKey;
  final Future<HelpCatalog> Function() loadCatalog;
  final selectedTopic = ValueNotifier(HelpTopicId.home);
  final pickerFocus = FocusNode(debugLabel: 'Help picker', skipTraversal: true);
  final viewerFocus = FocusNode(debugLabel: 'Help viewer', skipTraversal: true);
  String pageTopic = HelpTopicId.home;
  bool _menuOpen = false;
  bool get ownsFocus => _menuOpen || isPicking || isShowing;
  void beginMenu() {
    captureContext();
    _menuOpen = true;
  }

  void endMenu() {
    _menuOpen = false;
  }

  bool isPicking = false;
  bool isShowing = false;
  bool _disposed = false;
  ModalRoute<void>? _viewerRoute;
  FocusNode? _originFocus;
  String _originTopic = HelpTopicId.home;
  Future<HelpCatalog>? _catalog;

  static HelpController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_HelpAccess>()?.controller;

  String resolveContext([FocusNode? node]) {
    final focus = node ?? FocusManager.instance.primaryFocus;
    final context = focus?.context;
    final scoped = HelpScope.topicOf(context);
    if (scoped != null) return scoped;
    // An unannotated modal must never inherit the underlying page's context.
    final route = context == null ? null : ModalRoute.of(context);
    if (route != null && !route.isFirst) {
      String? topic;
      void visit(Element element) {
        if (topic != null) return;
        final widget = element.widget;
        if (widget is HelpScope && widget is! HelpTarget) {
          topic = widget.topicId;
          return;
        }
        element.visitChildren(visit);
      }

      route.subtreeContext?.visitChildElements(visit);
      return topic ?? HelpTopicId.dialog;
    }
    return pageTopic;
  }

  void captureContext() {
    if (isPicking || isShowing) return;
    _originFocus = FocusManager.instance.primaryFocus;
    _originTopic = resolveContext(_originFocus);
  }

  void showHome() {
    captureContext();
    unawaited(showTopic(HelpTopicId.home));
  }

  void showContext() {
    captureContext();
    unawaited(showTopic(_originTopic));
  }

  void showCapturedContext() => unawaited(showTopic(_originTopic));

  void togglePicking({bool useCapturedContext = false}) {
    if (isShowing) {
      viewerFocus.requestFocus();
      return;
    }
    if (isPicking) {
      cancelPicking();
      return;
    }
    if (!useCapturedContext) captureContext();
    isPicking = true;
    pickerFocus.requestFocus(); // Disconnect text input/IME while choosing.
    notifyListeners();
  }

  void cancelPicking({bool restoreFocus = true}) {
    if (!isPicking) return;
    isPicking = false;
    notifyListeners();
    if (restoreFocus) _restoreFocus();
  }

  void _restoreFocus() {
    final node = _originFocus;
    if (node != null && node.context?.mounted == true && node.canRequestFocus) {
      node.requestFocus();
    }
  }

  Future<void> showTopic(String topicId) async {
    if (_disposed) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    if (isPicking) cancelPicking(restoreFocus: false);
    selectedTopic.value = topicId;
    if (isShowing) {
      viewerFocus.requestFocus();
      return;
    }
    isShowing = true;
    notifyListeners();
    try {
      await AppDialog.showCustom<void>(
        context: navigator.overlay!.context,
        barrierDismissible: false,
        routeSettings: const RouteSettings(name: 'help'),
        builder: (context) {
          _viewerRoute = ModalRoute.of<void>(context);
          return HelpViewer(
            topic: selectedTopic,
            focusNode: viewerFocus,
            loadCatalog: () => _catalog ??= loadCatalog(),
            retryCatalog: () {
              _catalog = null;
            },
            onTopic: (id) => selectedTopic.value = id,
          );
        },
      );
    } finally {
      if (!_disposed) {
        _viewerRoute = null;
        isShowing = false;
        notifyListeners();
        _restoreFocus();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    selectedTopic.dispose();
    pickerFocus.dispose();
    viewerFocus.dispose();
    super.dispose();
  }
}

class _HelpAccess extends InheritedWidget {
  const _HelpAccess({required this.controller, required super.child});
  final HelpController controller;
  @override
  bool updateShouldNotify(_HelpAccess oldWidget) =>
      controller != oldWidget.controller;
}

/// Install in MaterialApp.builder, outside its Navigator and all route overlays.
class AppHelpHost extends StatefulWidget {
  const AppHelpHost({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.loadCatalog,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final Future<HelpCatalog> Function()? loadCatalog;
  @override
  State<AppHelpHost> createState() => _AppHelpHostState();
}

class _AppHelpHostState extends State<AppHelpHost> with WidgetsBindingObserver {
  final _gateKey = GlobalKey();
  late final HelpController controller = HelpController(
    navigatorKey: widget.navigatorKey,
    loadCatalog: widget.loadCatalog,
  );
  @override
  void initState() {
    super.initState();
    controller.addListener(_changed);
    FocusManager.instance.addEarlyKeyEventHandler(_onKey);
    WidgetsBinding.instance.addObserver(this);
  }

  void _changed() {
    // Input protection must change immediately, before the next rendered frame.
    final gate = _gateKey.currentContext?.findRenderObject();
    if (gate is _HelpGateRender) {
      gate.fallbackTopic = controller._originTopic;
      gate.picking = controller.isPicking;
    }
    if (mounted) setState(() {});
  }

  KeyEventResult _onKey(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    final plainModifiers =
        !keyboard.isControlPressed &&
        !keyboard.isAltPressed &&
        !keyboard.isMetaPressed;
    if (event.logicalKey == LogicalKeyboardKey.f1 && plainModifiers) {
      if (event is KeyDownEvent) {
        if (keyboard.isShiftPressed) {
          controller.togglePicking();
        } else if (controller.isShowing) {
          controller.viewerFocus.requestFocus();
        } else {
          controller.showContext();
        }
      }
      return KeyEventResult.handled;
    }
    if (controller.isShowing && event.logicalKey == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) navigatorCloseHelp();
      return KeyEventResult.handled;
    }
    if (controller.isPicking) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        controller.cancelPicking();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void navigatorCloseHelp() {
    final navigator = widget.navigatorKey.currentState;
    if (navigator != null && controller._viewerRoute?.isCurrent == true) {
      navigator.pop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      controller.cancelPicking(restoreFocus: false);
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_changed);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _HelpAccess(
    controller: controller,
    child: Focus(
      focusNode: controller.pickerFocus,
      skipTraversal: true,
      child: _HelpInputGate(
        key: _gateKey,
        picking: controller.isPicking,
        fallbackTopic: controller._originTopic,
        onSelected: (id) => unawaited(controller.showTopic(id)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (controller.isPicking)
              const Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: IgnorePointer(
                  child: Material(
                    elevation: 6,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        '點選項目查看說明，Esc 取消',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _HelpInputGate extends SingleChildRenderObjectWidget {
  const _HelpInputGate({
    super.key,
    required this.picking,
    required this.fallbackTopic,
    required this.onSelected,
    required super.child,
  });
  final bool picking;
  final String fallbackTopic;
  final ValueChanged<String> onSelected;
  @override
  _HelpGateRender createRenderObject(BuildContext context) =>
      _HelpGateRender(picking, fallbackTopic, onSelected);
  @override
  void updateRenderObject(BuildContext context, _HelpGateRender renderObject) {
    renderObject
      ..picking = picking
      ..fallbackTopic = fallbackTopic
      ..onSelected = onSelected;
  }
}

class _HelpGateRender extends RenderProxyBox implements MouseTrackerAnnotation {
  _HelpGateRender(this._picking, this.fallbackTopic, this.onSelected);
  bool _picking;
  bool get picking => _picking;
  set picking(bool value) {
    if (value == _picking) return;
    if (value) {
      // Cancel gestures started before Shift+F1 so their later pointer-up
      // cannot execute the original button, drag, or selection operation.
      for (final pointer in _pointers.keys.toList()) {
        GestureBinding.instance.cancelPointer(pointer);
      }
      _pointers.clear();
    }
    _picking = value;
  }

  String fallbackTopic;
  ValueChanged<String> onSelected;
  String? _candidate;
  final _pointers = <int, String>{};
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!picking) return super.hitTest(result, position: position);
    if (!size.contains(position)) return false;
    final probe = BoxHitTestResult();
    child?.hitTest(probe, position: position);
    _candidate = null;
    for (final entry in probe.path) {
      if (entry.target case final HelpRegionRenderObject region) {
        _candidate = region.topicId;
        break;
      }
    }
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      _pointers[event.pointer] = _candidate ?? fallbackTopic;
    }
    if (event is PointerCancelEvent) _pointers.remove(event.pointer);
    if (event is PointerUpEvent) {
      final topic = _pointers.remove(event.pointer);
      if (picking && topic != null) onSelected(topic);
    }
  }

  @override
  MouseCursor get cursor =>
      picking ? SystemMouseCursors.help : MouseCursor.defer;
  @override
  PointerEnterEventListener? get onEnter => null;
  @override
  PointerExitEventListener? get onExit => null;
  @override
  bool get validForMouseTracker => true;
}
