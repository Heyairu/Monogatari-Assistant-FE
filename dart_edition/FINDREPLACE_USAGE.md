# 查找/取代浮動視窗使用說明

## 功能概述

這個查找/取代浮動視窗提供了完整的文本搜尋和取代功能，包含多種搜尋選項。

## 使用方法

### 方法 1: 使用全域函數（推薦）

```dart
import 'package:your_app/bin/findreplace.dart';

// 最簡單的呼叫方式
showFindReplaceWindow(context);

// 帶回調函數的呼叫方式
showFindReplaceWindow(
  context,
  onFindNext: (findText, replaceText, options) {
    // 實現尋找下一個的邏輯
    print('尋找: $findText');
    if (options.matchCase) {
      print('區分大小寫');
    }
  },
  onFindPrevious: (findText, replaceText, options) {
    // 實現尋找上一個的邏輯
  },
  onReplace: (findText, replaceText, options) {
    // 實現取代的邏輯
  },
  onReplaceAll: (findText, replaceText, options) {
    // 實現全部取代的邏輯
  },
);

// 使用自訂的 TextEditingController
final myFindController = TextEditingController(text: '預設搜尋文字');
final myReplaceController = TextEditingController();
final myOptions = FindReplaceOptions(matchCase: true);

showFindReplaceWindow(
  context,
  findController: myFindController,
  replaceController: myReplaceController,
  options: myOptions,
  onFindNext: (findText, replaceText, options) {
    // 你的邏輯
  },
);
```

### 方法 2: 直接使用 Widget

```dart
import 'package:your_app/bin/findreplace.dart';

// 在 State 中定義
final findController = TextEditingController();
final replaceController = TextEditingController();
final options = FindReplaceOptions();
bool showWindow = false;

// 在 build 方法中
Stack(
  children: [
    // 你的主要內容
    YourMainContent(),
    
    // 浮動視窗
    if (showWindow)
      FindReplaceFloatingWindow(
        findController: findController,
        replaceController: replaceController,
        options: options,
        onFindNext: (findText, replaceText, options) {
          // 實現尋找邏輯
        },
        onClose: () {
          setState(() => showWindow = false);
        },
      ),
  ],
)
```

## 搜尋選項說明

`FindReplaceOptions` 類別包含以下選項：

### 1. matchCase (大小寫相同)
- 預設值：`false`
- 說明：是否區分大小寫進行搜尋
- 範例：
  ```dart
  options.matchCase = true;
  // 搜尋 "Hello" 不會匹配 "hello"
  ```

### 2. wholeWord (全字拼寫需相符)
- 預設值：`false`
- 說明：僅匹配完整單字（限半形字元）
- 範例：
  ```dart
  options.wholeWord = true;
  // 搜尋 "cat" 不會匹配 "category" 中的 "cat"
  ```

### 3. useWildcard (使用萬用字元)
- 預設值：`false`
- 說明：啟用萬用字元搜尋（* 和 ?）
- 範例：
  ```dart
  options.useWildcard = true;
  // 搜尋 "test*" 可匹配 "test", "testing", "tester"
  ```

### 4. matchWidth (全半形須相符)
- 預設值：`false`
- 說明：全形和半形字元必須完全相符
- 範例：
  ```dart
  options.matchWidth = true;
  // 搜尋 "123" 不會匹配 "１２３"
  ```

### 5. ignorePunctuation (略過標點符號)
- 預設值：`false`
- 說明：搜尋時忽略標點符號
- 範例：
  ```dart
  options.ignorePunctuation = true;
  // 搜尋 "hello" 可匹配 "hello!", "hello?", "hello,"
  ```

### 6. ignoreWhitespace (略過空白字元)
- 預設值：`false`
- 說明：搜尋時忽略空白字元
- 範例：
  ```dart
  options.ignoreWhitespace = true;
  // 搜尋 "helloworld" 可匹配 "hello world", "hello  world"
  ```

## 完整範例

```dart
import 'package:flutter/material.dart';
import 'package:your_app/bin/findreplace.dart';

class MyEditorPage extends StatefulWidget {
  @override
  _MyEditorPageState createState() => _MyEditorPageState();
}

class _MyEditorPageState extends State<MyEditorPage> {
  final TextEditingController editorController = TextEditingController();
  
  void _openFindReplace() {
    showFindReplaceWindow(
      context,
      onFindNext: (findText, replaceText, options) {
        // 實現尋找下一個
        final text = editorController.text;
        int currentPos = editorController.selection.baseOffset;
        
        // 根據選項進行搜尋
        String searchText = options.matchCase ? findText : findText.toLowerCase();
        String contentText = options.matchCase ? text : text.toLowerCase();
        
        int foundPos = contentText.indexOf(searchText, currentPos + 1);
        if (foundPos != -1) {
          editorController.selection = TextSelection(
            baseOffset: foundPos,
            extentOffset: foundPos + findText.length,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('找不到: $findText')),
          );
        }
      },
      onReplace: (findText, replaceText, options) {
        // 實現取代當前選取
        final selection = editorController.selection;
        if (selection.isValid && !selection.isCollapsed) {
          final selectedText = editorController.text.substring(
            selection.start,
            selection.end,
          );
          
          bool matches = options.matchCase 
            ? selectedText == findText
            : selectedText.toLowerCase() == findText.toLowerCase();
          
          if (matches) {
            editorController.text = editorController.text.replaceRange(
              selection.start,
              selection.end,
              replaceText,
            );
          }
        }
      },
      onReplaceAll: (findText, replaceText, options) {
        // 實現全部取代
        String text = editorController.text;
        String searchText = options.matchCase ? findText : findText.toLowerCase();
        String contentText = options.matchCase ? text : text.toLowerCase();
        
        int count = 0;
        int pos = 0;
        while ((pos = contentText.indexOf(searchText, pos)) != -1) {
          text = text.replaceRange(pos, pos + findText.length, replaceText);
          contentText = options.matchCase ? text : text.toLowerCase();
          pos += replaceText.length;
          count++;
        }
        
        editorController.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已取代 $count 個項目')),
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('編輯器'),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: _openFindReplace,
          ),
        ],
      ),
      body: TextField(
        controller: editorController,
        maxLines: null,
        expands: true,
      ),
    );
  }
}
```

## UI 說明

### 折疊功能
- 預設狀態：只顯示「尋找內容」列
- 點擊 ▼ 按鈕：展開顯示「取代為」區域
- 點擊 ▲ 按鈕：摺疊隱藏「取代為」區域

### 選項按鈕
- 點擊 ⚙️ 圖標：顯示/隱藏搜尋選項區域
- 選項以晶片（Chip）形式呈現，可快速切換

### 按鈕說明
- ⬆️：尋找上一個
- ⬇️：尋找下一個
- 取代：取代當前選取的項目
- 全部取代：取代所有匹配項目
- ✕：關閉視窗

## 注意事項

1. 所有回調函數都是可選的，不提供時按鈕仍可點擊但無動作
2. `FindReplaceOptions` 是可變物件，在回調中可以讀取最新的選項狀態
3. 視窗會記住展開/摺疊和選項顯示的狀態
4. 關閉視窗不會清空輸入框內容（除非使用臨時 controller）
