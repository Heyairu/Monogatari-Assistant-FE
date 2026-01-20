# 角色存檔功能說明

## 功能概述

已為 `CharacterView` 模組新增完整的 XML 存檔/讀檔功能,與 `main.dart`、`chapterselectionview.dart` 等其他模組保持一致的存檔格式。

## 主要變更

### 1. 新增 `CharacterCodec` 類

位置: `lib/modules/characterview.dart` (檔案開頭)

提供兩個靜態方法:
- `saveXML(Map<String, Map<String, dynamic>> characterData)` - 將角色資料序列化為 XML
- `loadXML(String xml)` - 從 XML 反序列化角色資料

### 2. XML 存儲格式

```xml
<Type>
  <Name>Characters</Name>
  <Character Name="角色名稱">
    <BasicInfo>
      <name>姓名</name>
      <nickname>暱稱</nickname>
      <!-- 更多基本資料欄位 -->
    </BasicInfo>
    <Appearance>
      <height>身高</height>
      <!-- 更多外觀欄位 -->
    </Appearance>
    <Personality>
      <mbti>MBTI</mbti>
      <personality>個性</personality>
      <hinderEvents>
        <event>
          <name>阻礙事件</name>
          <solve>解決方式</solve>
        </event>
      </hinderEvents>
    </Personality>
    <Ability>
      <loveToDoList>
        <item>項目1</item>
        <item>項目2</item>
      </loveToDoList>
      <commonAbilitySliders>
        <slider Title="料理" leftTag="不擅長" rightTag="擅長">5.0</slider>
        <slider Title="清潔" leftTag="不擅長" rightTag="擅長">7.0</slider>
        <!-- 更多滑桿 -->
      </commonAbilitySliders>
    </Ability>
    <Social>
      <howToShowLove>
        <item key="直接告白">true</item>
        <item key="送禮物">false</item>
      </howToShowLove>
      <socialItemSliders>
        <slider Title="" leftTag="內向" rightTag="外向">6.0</slider>
        <!-- 更多滑桿 -->
      </socialItemSliders>
      <approachSliders>
        <slider Title="" leftTag="低調" rightTag="高調">50.0</slider>
        <!-- 更多滑桿 -->
      </approachSliders>
      <traitsSliders>
        <slider Title="態度" leftTag="悲觀" rightTag="樂觀">50.0</slider>
        <!-- 更多滑桿 -->
      </traitsSliders>
    </Social>
    <Other>
      <originalName>原文姓名</originalName>
      <likeItemList>
        <item>項目1</item>
      </likeItemList>
      <!-- 更多列表 -->
    </Other>
  </Character>
</Type>
```

### 3. 滑桿存儲格式

按照需求文件頂部註釋的格式:
```xml
<slider Title="標題" leftTag="左標籤" rightTag="右標籤">數值</slider>
```

例如:
- `<slider Title="料理" leftTag="不擅長" rightTag="擅長">5.0</slider>`
- `<slider Title="態度" leftTag="悲觀" rightTag="樂觀">75.0</slider>`

### 4. 鍵值全部使用英文

所有資料鍵值都使用英文,例如:
- `'name'` (姓名)
- `'nickname'` (暱稱)
- `'personality'` (個性)
- `'loveToDoList'` (熱愛做的事情)
- `'howToShowLove'` (如何表達「喜歡」)
- `'commonAbilityValues'` (生活常用技能值)
- `'socialItemValues'` (社交相關項目值)
- `'approachValues'` (行事作風值)
- `'traitsValues'` (性格特質值)

### 5. CharacterView 介面更新

```dart
CharacterView(
  initialData: characterData,  // 初始資料
  onDataChanged: (updatedData) {  // 資料變更回調
    // 處理資料變更
  },
)
```

### 6. main.dart 整合

- 將 `List<CharacterProfile> characterData` 改為 `Map<String, Map<String, dynamic>> characterData`
- 移除了 `CharacterProfile` 類別(不再需要)
- 在 `_generateProjectXML()` 中使用 `CharacterCodec.saveXML()` 存檔
- 在 `_loadProjectFromXML()` 中使用 `CharacterCodec.loadXML()` 讀檔
- 更新 `_buildCharacterSettingsView()` 以傳遞初始資料和監聽資料變更

## 使用方式

### 存檔
1. 使用者在角色編輯頁面編輯角色資料
2. 每次編輯時自動調用 `_saveCurrentCharacterData()`
3. 資料變更時觸發 `onDataChanged` 回調
4. 用戶點擊「儲存檔案」時,`main.dart` 調用 `CharacterCodec.saveXML()` 生成 XML

### 讀檔
1. 用戶開啟專案檔案
2. `main.dart` 調用 `CharacterCodec.loadXML()` 解析 XML
3. 解析後的資料傳遞給 `CharacterView` 的 `initialData` 參數
4. `CharacterView` 在 `initState()` 中載入初始資料

## 資料結構

### characterData 結構
```dart
Map<String, Map<String, dynamic>> {
  "角色名稱1": {
    'name': String,
    'nickname': String,
    'age': String,
    // ... 更多字串欄位
    'loveToDoList': List<String>,
    'hinderEvents': List<Map<String, String>>,
    'howToShowLove': Map<String, bool>,
    'commonAbilityValues': List<double>,
    'socialItemValues': List<double>,
    'approachValues': List<double>,
    'traitsValues': List<double>,
    // ... 更多欄位
  },
  "角色名稱2": {
    // 相同結構
  }
}
```

## 注意事項

1. 所有 XML 特殊字元會自動轉義(`&`, `<`, `>`, `"`, `'`)
2. 滑桿數值以浮點數格式存儲,保留一位小數
3. 布林值以 `true`/`false` 字串存儲
4. 空列表和空 Map 不會在 XML 中生成對應標籤
5. 資料變更時會自動通知外部(透過 `onDataChanged` 回調)
