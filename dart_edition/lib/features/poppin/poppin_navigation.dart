final class PoppinNavigation<T> {
  final List<T> Function(T item) childrenOf;
  final String Function(T item) labelOf;

  List<T>? _rootItems;
  final List<_PoppinLevel<T>> _levels = [];
  int _selectedIndex = 0;

  PoppinNavigation({required this.childrenOf, required this.labelOf});

  List<T>? get activeItems => _levels.isEmpty ? _rootItems : _levels.last.items;

  int get selectedIndex => _selectedIndex;

  bool get canGoBack => _levels.isNotEmpty;

  bool get canEnterSelected {
    final items = activeItems;
    return items != null &&
        items.isNotEmpty &&
        childrenOf(items[_selectedIndex]).isNotEmpty;
  }

  String? get parentPath => _levels.isEmpty
      ? null
      : _levels.map((level) => level.parentLabel).join(" › ");

  void reset(List<T>? items, {bool preserveSelection = true}) {
    final previousIndex = preserveSelection ? _selectedIndex : 0;
    _rootItems = items;
    _levels.clear();
    _selectedIndex = _clampIndex(previousIndex, items);
  }

  void dismiss() {
    _rootItems = null;
    _levels.clear();
    _selectedIndex = 0;
  }

  bool move(int delta) {
    final items = activeItems;
    if (items == null || items.isEmpty) return false;
    _selectedIndex = (_selectedIndex + delta) % items.length;
    return true;
  }

  bool enter([int? index]) {
    final items = activeItems;
    if (items == null || items.isEmpty) return false;
    final parentIndex = index ?? _selectedIndex;
    if (parentIndex < 0 || parentIndex >= items.length) return false;
    final parent = items[parentIndex];
    final children = childrenOf(parent);
    if (children.isEmpty) return false;
    _levels.add(
      _PoppinLevel<T>(
        items: children,
        parentLabel: labelOf(parent),
        parentIndex: parentIndex,
      ),
    );
    _selectedIndex = 0;
    return true;
  }

  bool exit() {
    if (_levels.isEmpty) return false;
    final level = _levels.removeLast();
    _selectedIndex = level.parentIndex;
    return true;
  }

  static int _clampIndex<T>(int index, List<T>? items) {
    if (items == null || items.isEmpty) return 0;
    return index.clamp(0, items.length - 1).toInt();
  }
}

final class _PoppinLevel<T> {
  final List<T> items;
  final String parentLabel;
  final int parentIndex;

  const _PoppinLevel({
    required this.items,
    required this.parentLabel,
    required this.parentIndex,
  });
}
