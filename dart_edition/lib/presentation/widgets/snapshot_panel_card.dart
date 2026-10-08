import "package:flutter/material.dart";

import "../../bin/ui_library.dart";

/// Shared surface for timeline navigation and snapshot operations.
class SnapshotPanelCard extends StatefulWidget {
  final Widget child;
  final bool collapsible;
  final bool initiallyExpanded;
  final List<Widget> actions;

  const SnapshotPanelCard({
    super.key,
    required this.child,
    this.collapsible = true,
    this.initiallyExpanded = true,
    this.actions = const [],
  });

  @override
  State<SnapshotPanelCard> createState() => _SnapshotPanelCardState();
}

class _SnapshotPanelCardState extends State<SnapshotPanelCard> {
  late bool _expanded = widget.initiallyExpanded;

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final expanded = !widget.collapsible || _expanded;
    return AppSectionCard(
      header: Semantics(
        button: widget.collapsible,
        expanded: widget.collapsible ? expanded : null,
        child: InkWell(
          onTap: widget.collapsible ? _toggleExpanded : null,
          child: MediumTitle(icon: Icons.view_timeline_rounded, text: "時間軸與快照"),
        ),
      ),
      actions: [
        ...widget.actions,
        if (widget.collapsible)
          IconButton(
            key: const ValueKey("snapshot-panel-expand-toggle"),
            tooltip: expanded ? "收合" : "展開",
            icon: expanded
                ? Icon(Icons.expand_less_rounded)
                : Icon(Icons.expand_more_rounded),
            onPressed: _toggleExpanded,
          ),
      ],
      showDivider: expanded,
      headerSpacing: expanded ? AppSpacing.lg : 0,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Visibility(
        visible: expanded,
        maintainState: true,
        child: widget.child,
      ),
    );
  }
}

/// List, timeline and details stacked in reading order at every width.
class SnapshotWorkspaceLayout extends StatelessWidget {
  final Widget collection;
  final Widget timeline;
  final Widget details;

  const SnapshotWorkspaceLayout({
    super.key,
    required this.collection,
    required this.timeline,
    required this.details,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      collection,
      const SizedBox(height: AppSpacing.lg),
      timeline,
      const SizedBox(height: AppSpacing.lg),
      details,
    ],
  );
}

/// Keeps a preview readable while blocking pointer and keyboard edits.
class SnapshotEditorGuard extends StatelessWidget {
  final bool enabled;
  final Widget child;

  const SnapshotEditorGuard({
    super.key,
    required this.enabled,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => ExcludeFocus(
    excluding: !enabled,
    child: IgnorePointer(
      ignoring: !enabled,
      child: Opacity(opacity: enabled ? 1 : 0.5, child: child),
    ),
  );
}
