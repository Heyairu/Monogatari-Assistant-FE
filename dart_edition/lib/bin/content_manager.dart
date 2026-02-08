import "package:characters/characters.dart";
import "package:flutter/foundation.dart"; // Add foundation for compute
import "settings_manager.dart";

// Helper class for passing parameters to isolate
class _WordCountParams {
  final String content;
  final WordCountMode mode;
  
  _WordCountParams(this.content, this.mode);
}

// Top-level function for compute
int _calculateWordCountTask(_WordCountParams params) {
  return ContentManager.calculateWordCount(params.content, mode: params.mode);
}

// 內容管理器
class ContentManager {
  
  // 異步計算字數 (使用 Isolate)
  static Future<int> calculateWordCountAsync(String content, {WordCountMode mode = WordCountMode.characters}) async {
    if (content.isEmpty) return 0;
    // 使用 compute 在背景 isolate 執行計算
    return await compute(_calculateWordCountTask, _WordCountParams(content, mode));
  }

  // 計算本章字數
  // mode: 計算模式 (預設為混合模式)
  static int calculateWordCount(String content, {WordCountMode mode = WordCountMode.characters}) {
    if (content.isEmpty) return 0;

    if (mode == WordCountMode.characters) {
      // 純字元數計算，使用 characters 套件來正確計算包含 Emoji 或組合與字元的長度
      return content.characters.length;
    } else {
      // 混合模式：全形字元 + 半形單字
      int count = 0;
      bool inWord = false;
      
      for (var char in content.characters) {
        // 判斷是否為 "半形單字字元" (ASCII Alphanumeric + _)
        // 取第一個 rune 判斷 (對於 Grapheme Cluster 來說，通常第一個 rune 決定主要屬性區間)
        final code = char.runes.first;
        final isAscii = code < 128;
        
        final isHalfWidthWordChar = isAscii && (
            (code >= 48 && code <= 57) || // 0-9
            (code >= 65 && code <= 90) || // A-Z
            (code >= 97 && code <= 122) || // a-z
            code == 95 // _
        );
        
        if (isHalfWidthWordChar) {
          // 如果是半形單字的一部分
          if (!inWord) {
            count++;
            inWord = true;
          }
        } else {
          // 遇到非單字字元，重置單字狀態
          inWord = false;
          
          // 如果是非 ASCII (即全形字元、CJK、Emoji 等)，每個算 1 個字數
          // ASCII 的標點符號和空白則不計數
          if (!isAscii) {
            count++;
          }
        }
      }
      return count;
    }
  }
}
