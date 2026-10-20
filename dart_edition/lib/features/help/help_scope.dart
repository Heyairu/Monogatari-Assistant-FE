// Copyright 2025-2026 Heyairu（部屋伊琉）
// Licensed under the Apache License, Version 2.0.

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';

/// A region's fallback help topic. The nearest scope wins for keyboard focus.
class HelpScope extends StatelessWidget {
  const HelpScope({super.key, required this.topicId, required this.child});
  final String topicId;
  final Widget child;

  static String? topicOf(BuildContext? context) =>
      context?.getInheritedWidgetOfExactType<_HelpTopicScope>()?.topicId;

  @override
  Widget build(BuildContext context) => _HelpTopicScope(
    topicId: topicId,
    child: _HelpRegion(topicId: topicId, child: child),
  );
}

/// A control-level scope; no additional focus node or gesture recognizer.
class HelpTarget extends HelpScope {
  const HelpTarget({super.key, required super.topicId, required super.child});
}

class _HelpTopicScope extends InheritedWidget {
  const _HelpTopicScope({required this.topicId, required super.child});
  final String topicId;
  @override
  bool updateShouldNotify(_HelpTopicScope oldWidget) =>
      topicId != oldWidget.topicId;
}

class _HelpRegion extends SingleChildRenderObjectWidget {
  const _HelpRegion({required this.topicId, required super.child});
  final String topicId;
  @override
  HelpRegionRenderObject createRenderObject(BuildContext context) =>
      HelpRegionRenderObject(topicId);
  @override
  void updateRenderObject(
    BuildContext context,
    HelpRegionRenderObject renderObject,
  ) => renderObject.topicId = topicId;
}

/// An actual hit-test entry, including blank space and disabled controls.
/// Using the hit path respects clipping, transforms, offstage pages and modals.
class HelpRegionRenderObject extends RenderProxyBox {
  HelpRegionRenderObject(this.topicId);
  String topicId;
  @override
  bool hitTestSelf(Offset position) => true;
}

/// A popup entry whose complete hit area and keyboard focus share a topic.
/// Wrapping only PopupMenuItem.child would leave the item's Focus unannotated.
class HelpPopupMenuItem<T> extends PopupMenuItem<T> {
  const HelpPopupMenuItem({
    super.key,
    required this.topicId,
    super.value,
    super.enabled,
    super.onTap,
    required super.child,
  });
  final String topicId;
  @override
  PopupMenuItemState<T, HelpPopupMenuItem<T>> createState() =>
      _HelpPopupMenuItemState<T>();
}

class _HelpPopupMenuItemState<T>
    extends PopupMenuItemState<T, HelpPopupMenuItem<T>> {
  @override
  Widget build(BuildContext context) =>
      HelpTarget(topicId: widget.topicId, child: super.build(context));
}
