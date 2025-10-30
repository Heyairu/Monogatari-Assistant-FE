# 物語Assistant 檔案操作說明

## 檔案系統API實作

### 主要功能

#### 1. **檔案操作類別 (FileService)**
- 位於 `lib/file.dart`
- 提供完整的檔案存取、讀取功能

#### 2. **支援的檔案格式**
- `.mnproj` - 物語Assistant專案檔案（XML格式）
- `.txt` - 純文字匯出
- `.md` - Markdown格式匯出

#### 3. **主要API方法**

##### 專案操作
```dart
// 創建新專案
ProjectFile newProject = await FileService.createNewProject();

// 開啟專案
ProjectFile? project = await FileService.openProject();

// 儲存專案
ProjectFile savedProject = await FileService.saveProject(currentProject);

// 另存新檔
ProjectFile savedProject = await FileService.saveProjectAs(currentProject);
```

##### 文字匯出
```dart
// 匯出為TXT
await FileService.exportText(
  content: allChapterContent,
  fileName: 'MyNovel',
  extension: '.txt',
);

// 匯出為Markdown
await FileService.exportText(
  content: allChapterContent,
  fileName: 'MyNovel', 
  extension: '.md',
);
```

##### 本地檔案操作
```dart
// 讀取應用程式內部檔案
String content = await FileService.readLocalFile('settings.json');

// 寫入應用程式內部檔案
await FileService.writeLocalFile('settings.json', jsonContent);

// 獲取應用程式文件目錄
String appPath = await FileService.getAppDocumentsPath();
```

### 使用範例

#### 完整的存檔流程
```dart
// 1. 準備數據
_syncEditorToSelectedChapter();

// 2. 生成XML內容
String xmlContent = _generateProjectXML();

// 3. 創建或更新專案檔案
if (currentProject == null) {
  currentProject = await FileService.createNewProject();
}
currentProject!.content = xmlContent;

// 4. 儲存檔案
ProjectFile savedProject = await FileService.saveProject(currentProject!);

// 5. 更新狀態
setState(() {
  currentProject = savedProject;
});
```

#### 完整的讀檔流程
```dart
// 1. 開啟檔案選擇器
ProjectFile? projectFile = await FileService.openProject();

if (projectFile != null) {
  // 2. 解析XML內容
  await _loadProjectFromXML(projectFile);
  
  // 3. 更新UI狀態
  setState(() {
    currentProject = projectFile;
  });
}
```

### 專案檔案結構 (XML)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Project>
  <Type>BaseInfo</Type>
  <BaseInfo>
    <Title>作品標題</Title>
    <Author>作者姓名</Author>
    <Description>作品描述</Description>
    <LatestSave>2025-09-30T12:00:00.000Z</LatestSave>
  </BaseInfo>
  
  <Type>ChapterSelection</Type>
  <ChapterSelection>
    <Segment>
      <SegmentName>第一部</SegmentName>
      <SegmentUUID>1696060800000</SegmentUUID>
      <Chapter>
        <ChapterName>第一章</ChapterName>
        <ChapterContent>章節內容...</ChapterContent>
        <ChapterUUID>1696060801000</ChapterUUID>
      </Chapter>
    </Segment>
  </ChapterSelection>
  
  <!-- 其他數據區塊... -->
</Project>
```

### 錯誤處理

```dart
try {
  await FileService.saveProject(currentProject!);
  _showMessage("儲存成功！");
} catch (e) {
  if (e is FileException) {
    _showError("檔案操作失敗：${e.message}");
  } else {
    _showError("未知錯誤：${e.toString()}");
  }
}
```

### 平台支援

- ✅ **Windows**: 完整支援所有檔案操作
- ✅ **macOS**: 完整支援所有檔案操作  
- ✅ **Linux**: 完整支援所有檔案操作
- ⚠️ **Web**: 限制檔案系統存取，僅支援下載
- ⚠️ **Mobile**: 需要權限管理，儲存到應用程式沙盒

### 設定檔案權限 (Android)

在 `android/app/src/main/AndroidManifest.xml` 添加：

```xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

### 依賴套件

```yaml
dependencies:
  file_picker: ^8.1.2      # 檔案選擇器
  path_provider: ^2.1.4    # 路徑提供者
  path: ^1.9.0            # 路徑操作工具
```

### 進階功能

#### 自動儲存
```dart
Timer.periodic(Duration(minutes: 5), (timer) {
  if (currentProject != null && !isLoading) {
    _autoSave();
  }
});
```

#### 檔案備份
```dart
// 在儲存前創建備份
String backupContent = currentProject!.content;
await FileService.writeLocalFile(
  'backup_${DateTime.now().millisecondsSinceEpoch}.mga',
  backupContent,
);
```

#### 檔案歷史記錄
```dart
// 儲存最近開啟的檔案列表
List<String> recentFiles = await _getRecentFiles();
recentFiles.insert(0, projectFile.filePath!);
await _saveRecentFiles(recentFiles.take(10).toList());
```