import 'package:characters/characters.dart';
import 'settings_manager.dart';

// 內容管理器
class ContentManager {
  
  // 計算本章字數
  // mode: 計算模式 (預設為字元數)
  static int calculateWordCount(String content, {WordCountMode mode = WordCountMode.characters}) {
    if (content.isEmpty) return 0;

    if (mode == WordCountMode.characters) {
      // 純字元數 गणना (Grapheme Clusters)
      // 使用 characters 套件來正確計算包含 Emoji 或組合與字元的長度
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
