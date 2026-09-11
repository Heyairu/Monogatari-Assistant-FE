import "package:flutter/material.dart";

final class PoppinPanel<T> extends StatefulWidget {
  final List<T> items;
  final int selectedIndex;
  final String? parentLabel;
  final String keyPrefix;
  final String Function(T item) idOf;
  final String Function(T item) labelOf;
  final String Function(T item) detailOf;
  final bool Function(T item) hasChildren;
  final VoidCallback onBack;
  final ValueChanged<int> onExpanded;
  final ValueChanged<int> onSelected;

  const PoppinPanel({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.parentLabel,
    required this.idOf,
    required this.labelOf,
    required this.detailOf,
    required this.hasChildren,
    required this.onBack,
    required this.onExpanded,
    required this.onSelected,
    this.keyPrefix = "poppin",
  });

  @override
  State<PoppinPanel<T>> createState() => _PoppinPanelState<T>();
}

final class _PoppinPanelState<T> extends State<PoppinPanel<T>> {
  static const double _itemExtent = 56;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scheduleSelectedItemVisibility();
  }

  @override
  void didUpdateWidget(covariant PoppinPanel<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.items != widget.items) {
      _scheduleSelectedItemVisibility();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleSelectedItemVisibility() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      final itemTop = widget.selectedIndex * _itemExtent;
      final itemBottom = itemTop + _itemExtent;
      final visibleTop = position.pixels;
      final visibleBottom = visibleTop + position.viewportDimension;
      if (itemTop < visibleTop) {
        _scrollController.jumpTo(itemTop.clamp(0, position.maxScrollExtent));
      } else if (itemBottom > visibleBottom) {
        _scrollController.jumpTo(
          (itemBottom - position.viewportDimension).clamp(
            0,
            position.maxScrollExtent,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: widget.items.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: Text("找不到符合的候選項目"),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.parentLabel != null) _buildBackButton(),
                  Flexible(
                    child: ListView.builder(
                      key: ValueKey("${widget.keyPrefix}-list"),
                      controller: _scrollController,
                      itemExtent: _itemExtent,
                      shrinkWrap: true,
                      itemCount: widget.items.length,
                      itemBuilder: _buildItem,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Semantics(
      key: ValueKey("${widget.keyPrefix}-back"),
      button: true,
      label: "返回 ${widget.parentLabel}",
      onTap: widget.onBack,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: widget.onBack,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.chevron_left, size: 18),
                Expanded(
                  child: Text(
                    widget.parentLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final item = widget.items[index];
    final id = widget.idOf(item);
    final label = widget.labelOf(item);
    final detail = widget.detailOf(item);
    final expandable = widget.hasChildren(item);
    final selected = index == widget.selectedIndex;
    final colors = Theme.of(context).colorScheme;
    final semanticLabel = detail.isEmpty ? label : "$label，$detail";
    return ColoredBox(
      color: selected ? colors.secondaryContainer : Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              key: ValueKey("${widget.keyPrefix}-$id"),
              button: true,
              selected: selected,
              label: semanticLabel,
              hint: expandable ? "按 Enter 選取，按向右鍵展開下一層" : "按 Enter 或 Tab 選取",
              onTap: () => widget.onSelected(index),
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: () => widget.onSelected(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (detail.isNotEmpty)
                          Text(
                            detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (expandable)
            IconButton(
              key: ValueKey("${widget.keyPrefix}-expand-$id"),
              tooltip: "展開 $label 的下一層",
              onPressed: () => widget.onExpanded(index),
              icon: const Icon(Icons.chevron_right, size: 18),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }
}
