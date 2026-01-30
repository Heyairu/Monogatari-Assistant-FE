/*
 * ものがたり·アシスタント - Monogatari Assistant
 * Copyright (c) 2025 Heyairu（部屋伊琉）
 *
 * Licensed under the Business Source License 1.1 (Modified).
 * You may not use this file except in compliance with the License.
 * Change Date: 2030-11-04 05:14 a.m. (UTC+8)
 * Change License: Apache License 2.0
 *
 * Commercial use allowed under conditions described in Section 1;
 */

import "package:flutter/material.dart";

// 搜尋選項類別
class FindReplaceOptions {
  bool matchCase; // 大小寫相同
  bool wholeWord; // 全字拼寫需相符(限半形字元)
  bool useRegexp; // 使用正則表示(萬用字元)
  bool matchWidth; // 全半形須相符
  bool ignorePunctuation; // 略過標點符號
  bool ignoreWhitespace; // 略過空白字元

  FindReplaceOptions({
    this.matchCase = true,
    this.wholeWord = false,
    this.useRegexp = false,
    this.matchWidth = true,
    this.ignorePunctuation = false,
    this.ignoreWhitespace = false,
  });
}

// ==================== 搜尋功能函數 ====================

/// 找出所有匹配項
List<TextSelection> findAllMatches(String text, String findText, FindReplaceOptions options) {
  final matches = <TextSelection>[];
  
  if (findText.isEmpty) return matches;
  
  // 如果使用正則表達式
  if (options.useRegexp) {
    try {
      // 正則表達式模式固定啟用大小寫和全半形相符
      final regex = RegExp(findText, caseSensitive: true);
      final regexMatches = regex.allMatches(text);
      
      for (final match in regexMatches) {
        matches.add(TextSelection(
          baseOffset: match.start,
          extentOffset: match.end,
        ));
      }
      
      return matches;
    } catch (e) {
      // 如果正則表達式無效，返回空列表
      return matches;
    }
  }
  
  // 一般搜尋模式：支持略過標點符號和空白字元
  int i = 0;
  while (i < text.length) {
    // 嘗試從當前位置開始匹配
    int textIndex = i;
    int patternIndex = 0;
    int matchStart = i;
    
    while (patternIndex < findText.length && textIndex < text.length) {
      final textChar = text[textIndex];
      final patternChar = findText[patternIndex];
      
      // 如果需要略過標點符號，跳過文本中的標點符號
      if (options.ignorePunctuation && isPunctuation(textChar)) {
        textIndex++;
        continue;
      }
      
      // 如果需要略過空白字元，跳過文本中的空白字元
      if (options.ignoreWhitespace && isWhitespace(textChar)) {
        textIndex++;
        continue;
      }
      
      // 如果需要略過標點符號，跳過模式中的標點符號
      if (options.ignorePunctuation && isPunctuation(patternChar)) {
        patternIndex++;
        continue;
      }
      
      // 如果需要略過空白字元，跳過模式中的空白字元
      if (options.ignoreWhitespace && isWhitespace(patternChar)) {
        patternIndex++;
        continue;
      }
      
      // 檢查字元是否匹配
      if (!charsMatch(textChar, patternChar, options)) {
        break;
      }
      
      textIndex++;
      patternIndex++;
    }
    
    // 處理模式結尾可能剩餘的標點符號或空白字元
    while (patternIndex < findText.length) {
      final patternChar = findText[patternIndex];
      if (options.ignorePunctuation && isPunctuation(patternChar)) {
        patternIndex++;
      } else if (options.ignoreWhitespace && isWhitespace(patternChar)) {
        patternIndex++;
      } else {
        break;
      }
    }
    
    // 如果所有字元都匹配
    if (patternIndex == findText.length) {
      // 檢查全字匹配
      if (options.wholeWord) {
        // 檢查前一個字元
        if (matchStart > 0) {
          final prevChar = text[matchStart - 1];
          if (isWordChar(prevChar)) {
            i++;
            continue;
          }
        }
        // 檢查後一個字元
        if (textIndex < text.length) {
          final nextChar = text[textIndex];
          if (isWordChar(nextChar)) {
            i++;
            continue;
          }
        }
      }
      
      matches.add(TextSelection(
        baseOffset: matchStart,
        extentOffset: textIndex,
      ));
      
      // 跳過已匹配的範圍，避免重疊匹配
      i = textIndex;
    } else {
      // 沒有匹配，移動到下一個位置
      i++;
    }
  }
  
  return matches;
}

/// 判斷字元是否為單字字元（用於全字匹配）
bool isWordChar(String char) {
  if (char.isEmpty) return false;
  final code = char.codeUnitAt(0);
  // 字母和數字
  return (code >= 0x0030 && code <= 0x0039) || // 0-9
         (code >= 0x0041 && code <= 0x005A) || // A-Z
         (code >= 0x0061 && code <= 0x007A) || // a-z
         (code >= 0x00C0 && code <= 0x00FF) || // 擴展拉丁字母
         (code == 0x005F);                      // 底線
}

/// 判斷字元是否為標點符號
bool isPunctuation(String char) {
  if (char.isEmpty) return false;
  final punctuation = RegExp(r"""[!"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~、。，！？；：「」『』（）《》〈〉【】〔〕…—～·．｜／－＿＼]""");
  return punctuation.hasMatch(char);
}

/// 判斷字元是否為空白字元
bool isWhitespace(String char) {
  if (char.isEmpty) return false;
  return RegExp(r"\s").hasMatch(char);
}

/// 檢查兩個字元是否匹配（考慮搜尋選項）
bool charsMatch(String char1, String char2, FindReplaceOptions options) {
  String c1 = char1;
  String c2 = char2;
  
  // 大小寫正規化
  if (!options.matchCase) {
    c1 = normalizeCase(c1);
    c2 = normalizeCase(c2);
  }
  
  // 全半形正規化
  if (!options.matchWidth) {
    c1 = normalizeWidth(c1);
    c2 = normalizeWidth(c2);
  }
  
  return c1 == c2;
}

/// 檢查文字是否匹配（考慮所有選項）
bool textMatches(String text, String pattern, FindReplaceOptions options) {
  String processedText = text;
  String processedPattern = pattern;
  
  if (options.ignoreWhitespace) {
    processedText = processedText.replaceAll(RegExp(r"""\s+"""), "");
    processedPattern = processedPattern.replaceAll(RegExp(r"""\s+"""), "");
  }
  
  if (options.ignorePunctuation) {
    final punctuation = RegExp(r"""[!"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~、。，！？；：「」『』（）《》〈〉【】〔〕…—～·．｜／－＿＼]""");
    processedText = processedText.replaceAll(punctuation, "");
    processedPattern = processedPattern.replaceAll(punctuation, "");
  }
  
  if (!options.matchCase) {
    processedText = normalizeCase(processedText);
    processedPattern = normalizeCase(processedPattern);
  }
  
  // 全半形正規化（當不需要嚴格匹配時）
  if (!options.matchWidth) {
    processedText = normalizeWidth(processedText);
    processedPattern = normalizeWidth(processedPattern);
  }
  
  // 如果需要嚴格匹配全半形，額外檢查
  if (options.matchWidth && !checkWidthMatch(text, pattern)) {
    return false;
  }
  
  return processedText == processedPattern;
}

/// 檢查全半形是否匹配
bool checkWidthMatch(String text, String pattern) {
  if (text.length != pattern.length) return false;
  
  for (int i = 0; i < text.length; i++) {
    final textChar = text[i];
    final patternChar = pattern[i];
    
    final textIsFullWidth = isFullWidth(textChar);
    final patternIsFullWidth = isFullWidth(patternChar);
    
    if (textIsFullWidth != patternIsFullWidth) {
      return false;
    }
  }
  
  return true;
}

/// 判斷字元是否為全形
bool isFullWidth(String char) {
  if (char.isEmpty) return false;
  final code = char.codeUnitAt(0);
  // 全形字元範圍：0xFF00-0xFFEF (全形ASCII)
  // CJK字元範圍：0x4E00-0x9FFF
  return (code >= 0xFF00 && code <= 0xFFEF) || (code >= 0x4E00 && code <= 0x9FFF);
}

/// 正規化文字大小寫（支援多語言）
/// 支援：拉丁字母、全形字母、希臘語、西里爾字母等
String normalizeCase(String text) {
  if (text.isEmpty) return text;
  
  final buffer = StringBuffer();
  
  for (int i = 0; i < text.length; i++) {
    final char = text[i];
    final code = char.codeUnitAt(0);
    String normalized = char;
    
    // 1. 基本拉丁字母大寫 A-Z (U+0041-U+005A) -> 小寫 a-z
    if (code >= 0x0041 && code <= 0x005A) {
      normalized = String.fromCharCode(code + 32);
    }
    // 2. 拉丁字母補充-1 大寫 (U+00C0-U+00DE，含西歐語言重音符號)
    else if (code >= 0x00C0 && code <= 0x00DE && code != 0x00D7) {
      // 跳過 × (乘號，U+00D7)
      normalized = String.fromCharCode(code + 32);
    }
    // 3. 希臘字母大寫 Α-Ω (U+0391-U+03A9) -> 小寫 α-ω
    else if (code >= 0x0391 && code <= 0x03A9) {
      normalized = String.fromCharCode(code + 32);
    }
    // 4. 希臘字母帶重音符號大寫 (U+0386, U+0388-U+038F)
    else if (code == 0x0386) {
      normalized = "\u03AC"; // Ά -> ά
    }
    else if (code >= 0x0388 && code <= 0x038A) {
      normalized = String.fromCharCode(code + 37); // Έ-Ί -> έ-ί
    }
    else if (code == 0x038C) {
      normalized = "\u03CC"; // Ό -> ό
    }
    else if (code >= 0x038E && code <= 0x038F) {
      normalized = String.fromCharCode(code + 63); // Ύ-Ώ -> ύ-ώ
    }
    // 5. 西里爾字母大寫 А-Я (U+0410-U+042F) -> 小寫 а-я
    else if (code >= 0x0410 && code <= 0x042F) {
      normalized = String.fromCharCode(code + 32);
    }
    // 6. 全形拉丁字母大寫 Ａ-Ｚ (U+FF21-U+FF3A) -> 小寫 ａ-ｚ
    else if (code >= 0xFF21 && code <= 0xFF3A) {
      normalized = String.fromCharCode(code + 32);
    }
    // 7. 拉丁擴展-A 區域的大寫字母 (U+0100-U+017F)
    // 這個區域包含中歐、東歐語言的字母
    else if (code >= 0x0100 && code <= 0x017F) {
      // 偶數碼點通常是大寫，奇數是小寫
      if (code % 2 == 0) {
        normalized = String.fromCharCode(code + 1);
      }
    }
    // 8. 土耳其語特殊字母
    else if (code == 0x0130) { // İ -> i
      normalized = "i";
    }
    else if (code == 0x0049 && i + 1 < text.length && text.codeUnitAt(i + 1) == 0x0307) {
      // I with dot above -> i
      normalized = "i";
    }
    
    buffer.write(normalized);
  }
  
  return buffer.toString();
}

/// 正規化全半形字元（統一轉為半形）
/// 支援：全形ASCII、全形標點、全形假名、半形假名
String normalizeWidth(String text) {
  if (text.isEmpty) return text;
  
  final buffer = StringBuffer();
  
  for (int i = 0; i < text.length; i++) {
    final char = text[i];
    final code = char.codeUnitAt(0);
    String normalized = char;
    
    // 1. 全形ASCII字元 (U+FF01-U+FF5E) -> 半形 (U+0021-U+007E)
    // 包含：！"＃＄％＆'（）＊＋，－．／０-９：；＜＝＞？＠Ａ-Ｚ［＼］＾＿｀ａ-ｚ｛｜｝～
    if (code >= 0xFF01 && code <= 0xFF5E) {
      normalized = String.fromCharCode(code - 0xFEE0);
    }
    // 2. 全形空格 (U+3000) -> 半形空格 (U+0020)
    else if (code == 0x3000) {
      normalized = " ";
    }
    // 3. 全形片假名 (U+30A1-U+30FE) -> 半形片假名 (U+FF66-U+FF9F)
    // 這個轉換比較複雜，需要特別處理濁音、半濁音
    else if (code >= 0x30A1 && code <= 0x30FE) {
      normalized = convertFullKatakanaToHalf(char, text, i);
    }
    // 4. 半形片假名 (U+FF61-U+FF9F) 保持不變（已經是半形）
    // 包含：｡｢｣､･ｦ-ﾟ
    else if (code >= 0xFF61 && code <= 0xFF9F) {
      normalized = char;
    }
    // 5. 全形平假名 (U+3041-U+309F) -> 先轉為片假名再轉半形
    else if (code >= 0x3041 && code <= 0x309F) {
      // 平假名 -> 片假名：+0x0060
      final katakanaCode = code + 0x0060;
      final katakana = String.fromCharCode(katakanaCode);
      normalized = convertFullKatakanaToHalf(katakana, text, i);
    }
    // 6. 全形中文標點符號轉換
    else if (code == 0x3001) { // 、-> ,
      normalized = ",";
    }
    else if (code == 0x3002) { // 。-> .
      normalized = ".";
    }
    else if (code == 0x300C) { // 「-> "
      normalized = "\"";
    }
    else if (code == 0x300D) { // 」-> "
      normalized = "\"";
    }
    else if (code == 0x300E) { // 『-> '
      normalized = "'";
    }
    else if (code == 0x300F) { // 』-> '
      normalized = "'";
    }
    else if (code == 0x3014) { // 〔-> [
      normalized = "[";
    }
    else if (code == 0x3015) { // 〕-> ]
      normalized = "]";
    }
    
    buffer.write(normalized);
  }
  
  return buffer.toString();
}

/// 將全形片假名轉為半形片假名
String convertFullKatakanaToHalf(String char, String text, int index) {
  final code = char.codeUnitAt(0);
  
  // 全形片假名 -> 半形片假名映射表
  final Map<int, String> fullToHalfKatakana = {
    0x30A1: "ｧ", 0x30A2: "ｱ", 0x30A3: "ｨ", 0x30A4: "ｲ", 0x30A5: "ｩ",
    0x30A6: "ｳ", 0x30A7: "ｪ", 0x30A8: "ｴ", 0x30A9: "ｫ", 0x30AA: "ｵ",
    0x30AB: "ｶ", 0x30AC: "ｶﾞ", 0x30AD: "ｷ", 0x30AE: "ｷﾞ", 0x30AF: "ｸ",
    0x30B0: "ｸﾞ", 0x30B1: "ｹ", 0x30B2: "ｹﾞ", 0x30B3: "ｺ", 0x30B4: "ｺﾞ",
    0x30B5: "ｻ", 0x30B6: "ｻﾞ", 0x30B7: "ｼ", 0x30B8: "ｼﾞ", 0x30B9: "ｽ",
    0x30BA: "ｽﾞ", 0x30BB: "ｾ", 0x30BC: "ｾﾞ", 0x30BD: "ｿ", 0x30BE: "ｿﾞ",
    0x30BF: "ﾀ", 0x30C0: "ﾀﾞ", 0x30C1: "ﾁ", 0x30C2: "ﾁﾞ", 0x30C3: "ｯ",
    0x30C4: "ﾂ", 0x30C5: "ﾂﾞ", 0x30C6: "ﾃ", 0x30C7: "ﾃﾞ", 0x30C8: "ﾄ",
    0x30C9: "ﾄﾞ", 0x30CA: "ﾅ", 0x30CB: "ﾆ", 0x30CC: "ﾇ", 0x30CD: "ﾈ",
    0x30CE: "ﾉ", 0x30CF: "ﾊ", 0x30D0: "ﾊﾞ", 0x30D1: "ﾊﾟ", 0x30D2: "ﾋ",
    0x30D3: "ﾋﾞ", 0x30D4: "ﾋﾟ", 0x30D5: "ﾌ", 0x30D6: "ﾌﾞ", 0x30D7: "ﾌﾟ",
    0x30D8: "ﾍ", 0x30D9: "ﾍﾞ", 0x30DA: "ﾍﾟ", 0x30DB: "ﾎ", 0x30DC: "ﾎﾞ",
    0x30DD: "ﾎﾟ", 0x30DE: "ﾏ", 0x30DF: "ﾐ", 0x30E0: "ﾑ", 0x30E1: "ﾒ",
    0x30E2: "ﾓ", 0x30E3: "ｬ", 0x30E4: "ﾔ", 0x30E5: "ｭ", 0x30E6: "ﾕ",
    0x30E7: "ｮ", 0x30E8: "ﾖ", 0x30E9: "ﾗ", 0x30EA: "ﾘ", 0x30EB: "ﾙ",
    0x30EC: "ﾚ", 0x30ED: "ﾛ", 0x30EE: "ﾜ", 0x30EF: "ﾜ", 0x30F0: "ｲ",
    0x30F1: "ｴ", 0x30F2: "ｦ", 0x30F3: "ﾝ", 0x30F4: "ｳﾞ", 0x30F5: "ｶ",
    0x30F6: "ｹ", 0x30FB: "･", 0x30FC: "ｰ",
  };
  
  return fullToHalfKatakana[code] ?? char;
}

// ==================== UI 組件 ====================

// 全域函數:顯示查找取代浮動視窗
void showFindReplaceWindow(
  BuildContext context, {
  TextEditingController? findController,
  TextEditingController? replaceController,
  FindReplaceOptions? options,
  Function(String findText, String replaceText, FindReplaceOptions options)? onFindNext,
  Function(String findText, String replaceText, FindReplaceOptions options)? onFindPrevious,
  Function(String findText, String replaceText, FindReplaceOptions options)? onReplace,
  Function(String findText, String replaceText, FindReplaceOptions options)? onReplaceAll,
  Function(String findText, FindReplaceOptions options)? onSearchChanged,
  int? currentMatchIndex,
  int? totalMatches,
}) {
  // 如果沒有提供 controller，創建臨時的
  final tempFindController = findController ?? TextEditingController();
  final tempReplaceController = replaceController ?? TextEditingController();
  final tempOptions = options ?? FindReplaceOptions();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => FindReplaceFloatingWindow(
      findController: tempFindController,
      replaceController: tempReplaceController,
      options: tempOptions,
      onFindNext: onFindNext,
      onFindPrevious: onFindPrevious,
      onReplace: onReplace,
      onReplaceAll: onReplaceAll,
      onSearchChanged: onSearchChanged,
      currentMatchIndex: currentMatchIndex,
      totalMatches: totalMatches,
      onClose: () => Navigator.of(context).pop(),
    ),
  );
}

// 新的 Bar 樣式搜尋取代組件
class FindReplaceBar extends StatefulWidget {
  final TextEditingController findController;
  final TextEditingController replaceController;
  final FindReplaceOptions options;
  final Function(String findText, String replaceText, FindReplaceOptions options)? onFindNext;
  final Function(String findText, String replaceText, FindReplaceOptions options)? onFindPrevious;
  final Function(String findText, String replaceText, FindReplaceOptions options)? onReplace;
  final Function(String findText, String replaceText, FindReplaceOptions options)? onReplaceAll;
  final Function(String findText, FindReplaceOptions options)? onSearchChanged;
  final int? currentMatchIndex;
  final int? totalMatches;
  final VoidCallback? onClose;

  const FindReplaceBar({
    super.key,
    required this.findController,
    required this.replaceController,
    required this.options,
    this.onFindNext,
    this.onFindPrevious,
    this.onReplace,
    this.onReplaceAll,
    this.onSearchChanged,
    this.currentMatchIndex,
    this.totalMatches,
    this.onClose,
  });

  @override
  State<FindReplaceBar> createState() => _FindReplaceBarState();
}

class _FindReplaceBarState extends State<FindReplaceBar> {
  bool _isExpanded = false;
  bool _showOptions = false;

  @override
  void initState() {
    super.initState();
    // 監聽搜尋框內容變化
    widget.findController.addListener(_onFindTextChanged);
  }

  @override
  void dispose() {
    widget.findController.removeListener(_onFindTextChanged);
    super.dispose();
  }

  void _onFindTextChanged() {
    // 當搜尋框內容變化時，檢查是否需要禁用某些選項
    final findText = widget.findController.text;
    final hasFullWidth = _containsFullWidth(findText);
    final hasPunctuationOrSpace = _containsPunctuationOrSpace(findText);
    
    // 如果包含全形字元、標點符號或空格，自動禁用全字拼寫選項
    if ((hasFullWidth || hasPunctuationOrSpace) && widget.options.wholeWord) {
      setState(() {
        widget.options.wholeWord = false;
      });
    }
    
    // 通知搜尋內容變化，讓主視窗更新高亮顯示
    widget.onSearchChanged?.call(findText, widget.options);
    
    // 強制刷新 UI
    if (mounted) {
      setState(() {});
    }
  }

  void _notifySearchChanged() {
    // 通知搜尋選項變化
    widget.onSearchChanged?.call(widget.findController.text, widget.options);
  }

  // 檢查文字中是否包含全形字元
  bool _containsFullWidth(String text) {
    if (text.isEmpty) return false;
    
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if ((code >= 0xFF00 && code <= 0xFFEF) ||
          (code >= 0x4E00 && code <= 0x9FFF) ||
          (code >= 0x3000 && code <= 0x303F)) {
        return true;
      }
    }
    return false;
  }

  // 檢查文字中是否包含標點符號或空格
  bool _containsPunctuationOrSpace(String text) {
    if (text.isEmpty) return false;
    
    if (RegExp(r"\s").hasMatch(text)) {
      return true;
    }
    
    final punctuation = RegExp(r"""[!"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~、。，！？；：「」『』（）《》〈〉【】〔〕…—～·．｜／－＿＼]""");
    return punctuation.hasMatch(text);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 主搜尋列
            Row(
              children: [
                // 尋找輸入框
                Container(
                  child: Text("搜尋："),
                ),
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: widget.findController,
                      decoration: InputDecoration(
                        // labelText: "尋找",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // 匹配數量顯示
                if (widget.totalMatches != null && widget.totalMatches! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${(widget.currentMatchIndex ?? -1) + 1}/${widget.totalMatches}",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                
                const SizedBox(width: 2),
                
                // 導航按鈕組
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 16),
                  onPressed: () {
                    widget.onFindPrevious?.call(
                      widget.findController.text,
                      widget.replaceController.text,
                      widget.options,
                    );
                  },
                  tooltip: "上一個",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward, size: 16),
                  onPressed: () {
                    widget.onFindNext?.call(
                      widget.findController.text,
                      widget.replaceController.text,
                      widget.options,
                    );
                  },
                  tooltip: "下一個",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                
                // 展開/收合取代欄
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                  ),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  tooltip: _isExpanded ? "收合" : "展開取代",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                
                // 選項按鈕
                IconButton(
                  icon: const Icon(Icons.tune, size: 16),
                  onPressed: () {
                    setState(() {
                      _showOptions = !_showOptions;
                    });
                  },
                  tooltip: "搜尋選項",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            
            // 取代列（可展開）
            if (_isExpanded) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    child: Text("取代："),
                  ),
                  // 取代輸入框
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        controller: widget.replaceController,
                        decoration: InputDecoration(
                          // labelText: "取代為",
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // 取代按鈕
                  ElevatedButton.icon(
                    onPressed: () {
                      widget.onReplace?.call(
                        widget.findController.text,
                        widget.replaceController.text,
                        widget.options,
                      );
                    },
                    icon: const Icon(Icons.find_replace, size: 16),
                    label: const Text("取代", style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                      foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 4),
                  
                  // 全部取代按鈕
                  ElevatedButton.icon(
                    onPressed: () {
                      widget.onReplaceAll?.call(
                        widget.findController.text,
                        widget.replaceController.text,
                        widget.options,
                      );
                    },
                    icon: const Icon(Icons.library_add_check, size: 16),
                    label: const Text("全部", style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                      foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ],
            
            // 選項區域（可展開）
            if (_showOptions) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final findText = widget.findController.text;
                  final hasFullWidth = _containsFullWidth(findText);
                  final hasPunctuationOrSpace = _containsPunctuationOrSpace(findText);
                  final useRegexp = widget.options.useRegexp;
                  
                  final disableWholeWord = hasFullWidth || hasPunctuationOrSpace || useRegexp;
                  final disableMatchCase = useRegexp;
                  final disableMatchWidth = useRegexp;
                  
                  return Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildOptionChip(
                        label: "大小寫需相同",
                        tooltip: "大小寫需相同",
                        value: useRegexp ? true : widget.options.matchCase,
                        enabled: !disableMatchCase,
                        onChanged: (value) {
                          setState(() {
                            widget.options.matchCase = value;
                          });
                          _notifySearchChanged();
                        },
                      ),
                      _buildOptionChip(
                        label: "全字拼寫相符",
                        tooltip: "全字拼寫相符",
                        value: widget.options.wholeWord,
                        enabled: !disableWholeWord,
                        onChanged: (value) {
                          setState(() {
                            widget.options.wholeWord = value;
                          });
                          _notifySearchChanged();
                        },
                      ),
                      _buildOptionChip(
                        label: "使用正則表示",
                        tooltip: "使用正則表示",
                        value: widget.options.useRegexp,
                        onChanged: (value) {
                          setState(() {
                            widget.options.useRegexp = value;
                            if (value) {
                              widget.options.matchCase = true;
                              widget.options.wholeWord = false;
                              widget.options.matchWidth = true;
                            }
                          });
                          _notifySearchChanged();
                        },
                      ),
                      _buildOptionChip(
                        label: "全半形須相符",
                        tooltip: "全半形須相符",
                        value: useRegexp ? true : widget.options.matchWidth,
                        enabled: !disableMatchWidth,
                        onChanged: (value) {
                          setState(() {
                            widget.options.matchWidth = value;
                          });
                          _notifySearchChanged();
                        },
                      ),
                      _buildOptionChip(
                        label: "略過標點符號",
                        tooltip: "略過標點符號",
                        value: widget.options.ignorePunctuation,
                        onChanged: (value) {
                          setState(() {
                            widget.options.ignorePunctuation = value;
                          });
                          _notifySearchChanged();
                        },
                      ),
                      _buildOptionChip(
                        label: "略過空白字元",
                        tooltip: "略過空白字元",
                        value: widget.options.ignoreWhitespace,
                        onChanged: (value) {
                          setState(() {
                            widget.options.ignoreWhitespace = value;
                          });
                          _notifySearchChanged();
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildOptionChip({
    required String label,
    String? tooltip,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    final chip = FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: enabled ? null : Theme.of(context).disabledColor,
        ),
      ),
      selected: value,
      onSelected: enabled ? onChanged : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      labelPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
    
    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        child: chip,
      );
    }
    return chip;
  }
}

// 保留舊的浮動視窗組件以供桌面版使用（可選）
class FindReplaceFloatingWindow extends StatefulWidget {
  final TextEditingController findController;
  final TextEditingController replaceController;
  final FindReplaceOptions options;
  final Function(String findText, String replaceText, FindReplaceOptions options)? onFindNext;
  final Function(String findText, String replaceText, FindReplaceOptions options)? onFindPrevious;
  final Function(String findText, String replaceText, FindReplaceOptions options)? onReplace;
  final Function(String findText, String replaceText, FindReplaceOptions options)? onReplaceAll;
  final Function(String findText, FindReplaceOptions options)? onSearchChanged;
  final int? currentMatchIndex;
  final int? totalMatches;
  final VoidCallback? onClose;

  const FindReplaceFloatingWindow({
    super.key,
    required this.findController,
    required this.replaceController,
    required this.options,
    this.onFindNext,
    this.onFindPrevious,
    this.onReplace,
    this.onReplaceAll,
    this.onSearchChanged,
    this.currentMatchIndex,
    this.totalMatches,
    this.onClose,
  });

  @override
  State<FindReplaceFloatingWindow> createState() => _FindReplaceFloatingWindowState();
}

class _FindReplaceFloatingWindowState extends State<FindReplaceFloatingWindow> {
  bool _isExpanded = false;
  bool _showOptions = false;

  @override
  void initState() {
    super.initState();
    // 監聽搜尋框內容變化
    widget.findController.addListener(_onFindTextChanged);
  }

  @override
  void dispose() {
    widget.findController.removeListener(_onFindTextChanged);
    super.dispose();
  }

  void _onFindTextChanged() {
    // 當搜尋框內容變化時，檢查是否需要禁用某些選項
    final findText = widget.findController.text;
    final hasFullWidth = _containsFullWidth(findText);
    final hasPunctuationOrSpace = _containsPunctuationOrSpace(findText);
    
    // 如果包含全形字元、標點符號或空格，自動禁用全字拼寫選項
    if ((hasFullWidth || hasPunctuationOrSpace) && widget.options.wholeWord) {
      setState(() {
        widget.options.wholeWord = false;
      });
    }
    
    // 通知搜尋內容變化，讓主視窗更新高亮顯示
    widget.onSearchChanged?.call(findText, widget.options);
    
    // 強制刷新 UI
    if (mounted) {
      setState(() {});
    }
  }

  void _notifySearchChanged() {
    // 通知搜尋選項變化
    widget.onSearchChanged?.call(widget.findController.text, widget.options);
  }

  // 檢查文字中是否包含全形字元
  bool _containsFullWidth(String text) {
    if (text.isEmpty) return false;
    
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      // 全形字元的 Unicode 範圍
      // 全形標點符號和符號：0xFF00-0xFFEF
      // CJK 統一表意文字：0x4E00-0x9FFF
      // 全形數字和字母：0xFF01-0xFF5E
      if ((code >= 0xFF00 && code <= 0xFFEF) ||
          (code >= 0x4E00 && code <= 0x9FFF) ||
          (code >= 0x3000 && code <= 0x303F)) {
        return true;
      }
    }
    return false;
  }

  // 檢查文字中是否包含標點符號或空格
  bool _containsPunctuationOrSpace(String text) {
    if (text.isEmpty) return false;
    
    // 檢查是否包含空白字元
    if (RegExp(r"\s").hasMatch(text)) {
      return true;
    }
    
    // 檢查是否包含標點符號（半形和全形）
    final punctuation = RegExp(r"""[!"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~、。，！？；：「」『』（）《》〈〉【】〔〕…—～·．｜／－＿＼]""");
    return punctuation.hasMatch(text);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          right: 40,
          top: 40,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(4),
            color: Theme.of(context).colorScheme.surface,
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 尋找內容列
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          "尋找內容:",
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 32,
                          child: TextField(
                            controller: widget.findController,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              isDense: true,
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 顯示匹配數量
                      if (widget.totalMatches != null && widget.totalMatches! > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${(widget.currentMatchIndex ?? -1) + 1}/${widget.totalMatches}",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      // 尋找上一個按鈕
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: ElevatedButton(
                          onPressed: () {
                            widget.onFindPrevious?.call(
                              widget.findController.text,
                              widget.replaceController.text,
                              widget.options,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Icon(Icons.arrow_upward, size: 16),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 尋找下一個按鈕
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: ElevatedButton(
                          onPressed: () {
                            widget.onFindNext?.call(
                              widget.findController.text,
                              widget.replaceController.text,
                              widget.options,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Icon(Icons.arrow_downward, size: 16),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 折疊/展開按鈕
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            _isExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 20,
                          ),
                          tooltip: _isExpanded ? "摺疊" : "展開取代",
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 選項按鈕
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              _showOptions = !_showOptions;
                            });
                          },
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.tune,
                            size: 18,
                          ),
                          tooltip: "搜尋選項",
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 關閉按鈕
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  
                  // 可折疊的取代區域
                  if (_isExpanded) ...[
                    const SizedBox(height: 12),
                    
                    // 取代為列
                    Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            "取代為:",
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: TextField(
                              controller: widget.replaceController,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                isDense: true,
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 取代按鈕（圖標）
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: ElevatedButton(
                            onPressed: () {
                              widget.onReplace?.call(
                                widget.findController.text,
                                widget.replaceController.text,
                                widget.options,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                              foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                            ),
                            child: Tooltip(
                              message: "取代",
                              child: const Icon(Icons.find_replace, size: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // 全部取代按鈕（圖標）
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: ElevatedButton(
                            onPressed: () {
                              widget.onReplaceAll?.call(
                                widget.findController.text,
                                widget.replaceController.text,
                                widget.options,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                              foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
                            ),
                            child: Tooltip(
                              message: "全部取代",
                              child: const Icon(Icons.library_add_check, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  // 搜尋選項區域
                  if (_showOptions) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        // 檢查搜尋框內容
                        final findText = widget.findController.text;
                        final hasFullWidth = _containsFullWidth(findText);
                        final hasPunctuationOrSpace = _containsPunctuationOrSpace(findText);
                        final useRegexp = widget.options.useRegexp;
                        
                        // 計算禁用狀態
                        final disableWholeWord = hasFullWidth || hasPunctuationOrSpace || useRegexp;
                        final disableMatchCase = useRegexp;
                        final disableMatchWidth = useRegexp;
                        
                        return Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _buildOptionChip(
                              label: "大小寫需相同",
                              value: useRegexp ? true : widget.options.matchCase,
                              enabled: !disableMatchCase,
                              onChanged: (value) {
                                setState(() {
                                  widget.options.matchCase = value;
                                });
                                _notifySearchChanged();
                              },
                            ),
                            _buildOptionChip(
                              label: "全字拼寫相符",
                              value: widget.options.wholeWord,
                              enabled: !disableWholeWord,
                              onChanged: (value) {
                                setState(() {
                                  widget.options.wholeWord = value;
                                });
                                _notifySearchChanged();
                              },
                            ),
                            _buildOptionChip(
                              label: "使用正則表示",
                              value: widget.options.useRegexp,
                              onChanged: (value) {
                                setState(() {
                                  widget.options.useRegexp = value;
                                  // 當啟用正則表示時，強制啟用大小寫和全半形相符選項
                                  if (value) {
                                    widget.options.matchCase = true;
                                    widget.options.wholeWord = false;
                                    widget.options.matchWidth = true;
                                  }
                                });
                                _notifySearchChanged();
                              },
                            ),
                            _buildOptionChip(
                              label: "全半形須相符",
                              value: useRegexp ? true : widget.options.matchWidth,
                              enabled: !disableMatchWidth,
                              onChanged: (value) {
                                setState(() {
                                  widget.options.matchWidth = value;
                                });
                                _notifySearchChanged();
                              },
                            ),
                            _buildOptionChip(
                              label: "略過標點符號",
                              value: widget.options.ignorePunctuation,
                              onChanged: (value) {
                                setState(() {
                                  widget.options.ignorePunctuation = value;
                                });
                                _notifySearchChanged();
                              },
                            ),
                            _buildOptionChip(
                              label: "略過空白字元",
                              value: widget.options.ignoreWhitespace,
                              onChanged: (value) {
                                setState(() {
                                  widget.options.ignoreWhitespace = value;
                                });
                                _notifySearchChanged();
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildOptionChip({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: enabled ? null : Theme.of(context).disabledColor,
        ),
      ),
      selected: value,
      onSelected: enabled ? onChanged : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      labelPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
