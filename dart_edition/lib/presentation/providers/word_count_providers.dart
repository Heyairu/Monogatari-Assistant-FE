import "package:flutter_riverpod/flutter_riverpod.dart";

class ActiveChapterWordCountState {
  final int count;
  final bool isComputing;
  final Object? error;
  final DateTime? lastUpdatedAt;

  const ActiveChapterWordCountState({
    required this.count,
    required this.isComputing,
    this.error,
    this.lastUpdatedAt,
  });

  const ActiveChapterWordCountState.initial()
    : count = 0,
      isComputing = false,
      error = null,
      lastUpdatedAt = null;

  ActiveChapterWordCountState copyWith({
    int? count,
    bool? isComputing,
    Object? error,
    DateTime? lastUpdatedAt,
  }) {
    return ActiveChapterWordCountState(
      count: count ?? this.count,
      isComputing: isComputing ?? this.isComputing,
      error: error,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}

final activeChapterWordCountProvider =
    AutoDisposeNotifierProvider<
      ActiveChapterWordCountNotifier,
      ActiveChapterWordCountState
    >(ActiveChapterWordCountNotifier.new);

class ActiveChapterWordCountNotifier
    extends AutoDisposeNotifier<ActiveChapterWordCountState> {
  bool _isDisposed = false;

  @override
  ActiveChapterWordCountState build() {
    ref.onDispose(() {
      _isDisposed = true;
    });
    return const ActiveChapterWordCountState.initial();
  }

  void refreshFromCount({required String? chapterId, required int count}) {
    if (chapterId == null || chapterId.trim().isEmpty) {
      reset();
      return;
    }

    if (_isDisposed) return;
    state = state.copyWith(
      count: count,
      isComputing: false,
      error: null,
      lastUpdatedAt: DateTime.now(),
    );
  }

  void markComputing({required String? chapterId}) {
    if (chapterId == null || chapterId.trim().isEmpty) {
      reset();
      return;
    }

    if (_isDisposed) return;
    state = state.copyWith(isComputing: true, error: null);
  }

  void reset() {
    if (_isDisposed) return;
    state = state.copyWith(
      count: 0,
      isComputing: false,
      error: null,
      lastUpdatedAt: DateTime.now(),
    );
  }
}
