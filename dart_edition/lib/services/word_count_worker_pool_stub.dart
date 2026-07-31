import "package:flutter/foundation.dart";

import "../bin/content_manager.dart";
import "../bin/settings_manager.dart";

class WordCountWorkerPool {
  WordCountWorkerPool({int size = 2});

  Future<int> calculate(String content, int modeIndex) {
    return compute<List<Object?>, int>(_calculate, <Object?>[
      content,
      modeIndex,
    ]);
  }

  void dispose() {}
}

int _calculate(List<Object?> request) {
  return ContentManager.calculateWordCount(
    request[0] as String,
    mode: WordCountMode.values[request[1] as int],
  );
}
