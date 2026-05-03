import "dart:async";

import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../bin/content_manager.dart";
import "../../bin/settings_manager.dart";

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

final activeChapterWordCountProvider = AutoDisposeNotifierProvider<
  ActiveChapterWordCountNotifier,
  ActiveChapterWordCountState
>(ActiveChapterWordCountNotifier.new);

class ActiveChapterWordCountNotifier
    extends AutoDisposeNotifier<ActiveChapterWordCountState> {
  static const Duration _debounceDuration = Duration(milliseconds: 50);

  Timer? _debounce;
  int _revision = 0;
  bool _isDisposed = false;

  @override
  ActiveChapterWordCountState build() {
    ref.onDispose(() {
      _isDisposed = true;
      _debounce?.cancel();
      _debounce = null;
    });
    return const ActiveChapterWordCountState.initial();
  }

  void onTextChanged({
    required String? chapterId,
    required String text,
    required WordCountMode mode,
  }) {
    if (chapterId == null || chapterId.trim().isEmpty) {
      _debounce?.cancel();
      _debounce = null;
      state = state.copyWith(
        count: 0,
        isComputing: false,
        error: null,
        lastUpdatedAt: DateTime.now(),
      );
      return;
    }

    final int nextRevision = ++_revision;
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () async {
      // Mark computing (keep previous count to avoid flicker).
      state = state.copyWith(isComputing: true, error: null);
      try {
        final int count = await ContentManager.calculateWordCountAsync(
          text,
          mode: mode,
        );

        if (_isDisposed || nextRevision != _revision) {
          return;
        }

        state = state.copyWith(
          count: count,
          isComputing: false,
          error: null,
          lastUpdatedAt: DateTime.now(),
        );
      } catch (e) {
        if (_isDisposed || nextRevision != _revision) {
          return;
        }
        state = state.copyWith(
          isComputing: false,
          error: e,
          lastUpdatedAt: DateTime.now(),
        );
      }
    });
  }
}

