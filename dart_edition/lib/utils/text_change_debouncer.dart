import 'dart:async';

class TextChangeDebouncer {
  Timer? _wordCountDebounce;
  Timer? _contentCommitDebounce;
  String? _pendingContentCommit;

  final Duration wordCountDelay;
  final Duration contentCommitDelay;

  final void Function(String text) onWordCountTrigger;
  final void Function(String text) onContentCommitTrigger;

  TextChangeDebouncer({
    this.wordCountDelay = const Duration(milliseconds: 500),
    this.contentCommitDelay = const Duration(milliseconds: 200),
    required this.onWordCountTrigger,
    required this.onContentCommitTrigger,
  });

  void onTextChanged(String nextContent) {
    _scheduleWordCountUpdate(nextContent);
    _scheduleContentCommit(nextContent);
  }

  void _scheduleWordCountUpdate(String nextContent) {
    _wordCountDebounce?.cancel();
    _wordCountDebounce = Timer(wordCountDelay, () {
      onWordCountTrigger(nextContent);
    });
  }

  void _scheduleContentCommit(String nextContent) {
    _pendingContentCommit = nextContent;
    _contentCommitDebounce?.cancel();
    _contentCommitDebounce = Timer(contentCommitDelay, () {
      if (_pendingContentCommit != null) {
        onContentCommitTrigger(_pendingContentCommit!);
        _pendingContentCommit = null;
      }
    });
  }

  void flushPendingContentCommit() {
    if (_contentCommitDebounce?.isActive ?? false) {
      _contentCommitDebounce!.cancel();
      if (_pendingContentCommit != null) {
        onContentCommitTrigger(_pendingContentCommit!);
        _pendingContentCommit = null;
      }
    }
  }

  void cancelAll() {
    _wordCountDebounce?.cancel();
    _wordCountDebounce = null;

    _contentCommitDebounce?.cancel();
    _contentCommitDebounce = null;
    _pendingContentCommit = null;
  }
}
