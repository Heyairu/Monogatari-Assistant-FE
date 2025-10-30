# OutlineAdjustView 快速上手指南

## ✅ 已完成的遷移

從 SwiftUI 的 `OutlineAdjustView.swift` 已成功遷移到 Flutter/Dart!

### 📁 新增的文件

1. **lib/modules/outlineview.dart** - 主要實作
   - `StorylineData` - 大箱(故事線)資料結構
   - `StoryEventData` - 中箱(事件)資料結構  
   - `SceneData` - 小箱(場景)資料結構
   - `OutlineCodec` - XML 編解碼器
   - `OutlineAdjustView` - 主要 UI Widget

2. **lib/modules/outlineview_example.dart** - 使用範例

3. **test/outlineview_test.dart** - 單元測試 (✅ 全部通過!)

4. **lib/modules/OUTLINE_README.md** - 詳細文檔

## 🚀 快速使用

### 方法 1: 在現有應用中整合

```dart
import 'package:flutter/material.dart';
import 'modules/outlineview.dart';

class MyOutlinePage extends StatefulWidget {
  @override
  State<MyOutlinePage> createState() => _MyOutlinePageState();
}

class _MyOutlinePageState extends State<MyOutlinePage> {
  List<StorylineData> storylines = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('大綱編輯')),
      body: OutlineAdjustView(
        storylines: storylines,
        onChanged: (updated) {
          setState(() {
            storylines = updated;
          });
        },
      ),
    );
  }
}
```

### 方法 2: 運行範例

```dart
import 'package:flutter/material.dart';
import 'modules/outlineview_example.dart';

void main() {
  runApp(MaterialApp(
    home: OutlineViewExample(),
  ));
}
```

## 🎯 核心功能

### 三層結構管理

```
大箱(故事線)
  └─ 中箱(事件)
      └─ 小箱(場景)
```

- **大箱**: 故事的主線,可標記「起承轉合」等結構
- **中箱**: 具體事件,繼承上層人物/物件
- **小箱**: 詳細場景,包含時間、地點、行動

### XML 儲存與讀取

```dart
// 保存
final xml = OutlineCodec.saveXML(storylines);
await File('outline.xml').writeAsString(xml!);

// 讀取
final xmlString = await File('outline.xml').readAsString();
final loaded = OutlineCodec.loadXML(xmlString);
if (loaded != null) {
  setState(() => storylines = loaded);
}
```

## 🎨 UI 功能

### 已實作

- ✅ 新增/刪除/編輯 (三個層級)
- ✅ 拖拽重新排序
- ✅ 選擇狀態高亮
- ✅ 展開/收合詳細資訊
- ✅ 標籤列表管理 (人物/物件/行動)
- ✅ 繼承機制 (子層自動繼承父層)
- ✅ 備註功能

### 與原 SwiftUI 版本的差異

| 功能 | SwiftUI | Flutter | 狀態 |
|-----|---------|---------|------|
| 三層結構 | ✅ | ✅ | 完全對應 |
| 拖拽排序 | ✅ | ✅ | 使用 ReorderableListView |
| 跨層拖放 | ✅ | 🔄 | 簡化為同層排序 |
| 雙擊編輯 | ✅ | 🔄 | 改為編輯按鈕 |
| XML 儲存 | ✅ | ✅ | 完全對應 |

## 🧪 測試結果

```bash
$ flutter test test/outlineview_test.dart
+9: All tests passed! ✅
```

測試涵蓋:
- ✅ XML 編解碼
- ✅ 特殊字元轉義
- ✅ 資料結構初始化
- ✅ copyWith 功能
- ✅ 邊界情況處理

## 📦 依賴項

已添加到 `pubspec.yaml`:

```yaml
dependencies:
  xml: ^6.5.0  # XML 解析
```

## 🔧 進階使用

### 整合檔案儲存

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class OutlineStorage {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final localPath = await _localPath;
    return File(path.join(localPath, 'outline.xml'));
  }

  Future<void> save(List<StorylineData> storylines) async {
    final xml = OutlineCodec.saveXML(storylines);
    if (xml != null) {
      final file = await _localFile;
      await file.writeAsString(xml);
    }
  }

  Future<List<StorylineData>?> load() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        return OutlineCodec.loadXML(contents);
      }
    } catch (e) {
      debugPrint('Error loading: $e');
    }
    return null;
  }
}
```

### 整合到主應用

在你的 `lib/main.dart` 中添加路由:

```dart
import 'modules/outlineview_example.dart';

// 在你的 MaterialApp 中
routes: {
  '/outline': (context) => OutlineViewExample(),
},
```

## 📝 注意事項

1. **UUID 生成**: 目前使用時間戳,可考慮使用 `uuid` package 改進
2. **性能**: 大量資料時考慮分頁或虛擬滾動
3. **自動儲存**: 建議實作定時自動儲存功能
4. **備份**: 重要資料應有備份機制

## 🆘 常見問題

### Q: 如何連接到主應用的檔案系統?

A: 參考 `lib/bin/file.dart` 中的檔案操作方法。

### Q: 資料不會自動更新?

A: 記得在 `onChanged` 回調中調用 `setState()`。

### Q: 如何添加更多欄位?

A: 編輯資料類別(如 `SceneData`),然後更新:
   - XML 編解碼邏輯
   - UI 編輯表單
   - 測試檔案

## 🎓 下一步

1. 查看 `OUTLINE_README.md` 獲取完整文檔
2. 運行 `outlineview_example.dart` 體驗功能
3. 閱讀測試文件了解所有功能
4. 根據需求自訂 UI 樣式

## 🤝 貢獻

如有問題或建議,請參考專案的貢獻指南。

---

**遷移完成! 🎉** 所有核心功能已完整實作並通過測試!
