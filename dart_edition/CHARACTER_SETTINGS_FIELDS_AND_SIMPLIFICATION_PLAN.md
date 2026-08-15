# 角色設定欄位盤點與簡化計畫

> 盤點日期：2026-08-01  
> 盤點範圍：`dart_edition/lib/models/character_data.dart`、`dart_edition/lib/modules/characterview.dart`、`dart_edition/CHARACTER_SAVE_FEATURE.md`、`BETA8_DEVELOPMENT_PLAN.md`  
> 目的：完整列出現有角色資料，並提出不遺失舊專案內容的表單與資料模型簡化方案。

## 1. 結論摘要

目前角色設定提供非常完整的角色問卷，但同一頁同時承擔「人物卡」、「性格測驗」、「故事狀態」與「社交／戀愛偏好」四種用途，造成初次建立角色的成本偏高。

現況規模：

- `CharacterDataKeys` 登記 48 個文字 key；其中 `alignment` 實際由獨立選擇器儲存，形成重複表示。
- 11 組可新增多筆內容的清單。
- 1 組「阻礙事件／解決方式」配對清單。
- 4 組共 53 個 0–100 滑桿。
- 3 組共 17 個社交行為勾選項。
- 1 個戀愛狀態單選與 2 個戀愛相關布林值。
- 展開 `textFields` 並扣除重複的 `alignment` 後，舊格式共有 70 個頂層資料 key，另有各清單項目、事件子欄位與滑桿位置。

建議方向：

1. 預設表單縮成「基本識別、外觀摘要、性格與故事核心、關係摘要、備註」五區。
2. 預設只保留 1 個必填欄位與約 14 個常用選填欄位。
3. 詳細外觀、MBTI、陣營、量表、喜惡清單與戀愛問卷移入可折疊的「進階設定」。
4. 以 UUID 作為角色主鍵，名稱只作顯示與搜尋用途。
5. 舊欄位先完整遷移到結構化進階欄位或 `legacyFields`，不可直接刪除。

## 2. 現有資料結構

### 2.1 頂層結構

```dart
Map<String, CharacterEntryData> characterData;
```

目前 `Map` 的 key 是角色名稱；角色改名時必須重建 Map 項目。`CharacterEntryData` 內含：

| 欄位 | 型別 | 用途 |
| --- | --- | --- |
| `textFields` | `Map<String, String>` | 48 個登記中的文字欄位 |
| `alignment` | `String?` | 九宮格陣營 |
| `hinderEvents` | `List<CharacterHinderEvent>` | 阻礙事件與解法 |
| 6 組能力／行動清單 | `List<String>` | 喜歡、討厭、想做、害怕、擅長、不擅長 |
| `commonAbilityValues` | `List<double>` | 16 個生活技能滑桿 |
| 3 組社交行為 | `Map<String, bool>` | 表達喜歡、表達好意、應對討厭的人 |
| `socialItemValues` | `List<double>` | 10 個社交傾向滑桿 |
| `relationship` | `String?` | 戀愛狀態 |
| `isFindNewLove`、`isHarem` | `bool` | 戀愛附加選項 |
| `approachValues` | `List<double>` | 12 個行事作風滑桿 |
| `traitsValues` | `List<double>` | 15 個性格特質滑桿 |
| 5 組人事物清單 | `List<String>` | 喜歡、憧憬、討厭、害怕、習慣 |

### 2.2 XML 分區

角色存於：

```text
Type(Name=Characters)
└─ Character @Name
   ├─ BasicInfo
   ├─ Appearance
   ├─ Personality
   ├─ Ability
   ├─ Social
   └─ Other
```

注意：`Character @Name`、`BasicInfo/name` 與外層 Map key 都表示角色名稱，現在存在三份需同步的名稱資料。

## 3. 詳細欄位清單

以下「建議層級」定義：

- **核心**：新建角色時預設顯示。
- **進階**：保留，但預設折疊。
- **合併**：新 UI 併入摘要欄位，原值仍需保留。
- **相容**：不再作為固定問卷呈現，遷入自訂／舊資料區。

### 3.1 基本資料

XML：`Character/BasicInfo`

| UI 名稱 | key | 型別 | 建議層級 | 簡化處理 |
| --- | --- | --- | --- | --- |
| 姓名 | `name` | String | 核心、必填 | 改名為 `displayName`；不得再作主鍵 |
| 暱稱 | `nickname` | String | 核心 | 與原文姓名合併成可多筆的 `aliases` |
| 年齡 | `age` | String | 核心 | 保留自由文字，允許「約 20 歲／不詳」 |
| 性別 | `gender` | String | 核心 | 保留自由文字或可輸入下拉選單 |
| 職業 | `occupation` | String | 核心 | UI 改稱「身份／職業」，新 key 建議 `roleOrOccupation` |
| 生日 | `birthday` | String | 進階 | 保留自由文字；不要強制真實日期格式 |
| 出生地 | `native` | String | 進階 | 更名 `birthplace` |
| 居住地 | `live` | String | 進階 | 更名 `residence`；若導入時間軸，動態所在地另存 |
| 住址 | `address` | String | 相容 | 低頻且與居住地重疊，轉進自訂欄位 |

### 3.2 外觀

XML：`Character/Appearance`

| UI 名稱 | key | 型別 | 建議層級 | 簡化處理 |
| --- | --- | --- | --- | --- |
| 外觀摘要 | 新增 `appearanceSummary` | String | 核心 | 新 UI 的主要外觀欄位，不覆寫下列舊值 |
| 身高 | `height` | String | 進階 | 保留 |
| 體重 | `weight` | String | 進階 | 保留 |
| 血型 | `blood` | String | 相容 | 移入自訂欄位 |
| 髮色 | `hair` | String | 進階 | 可顯示於外觀詳細資料 |
| 瞳色 | `eye` | String | 進階 | 可顯示於外觀詳細資料 |
| 膚色 | `skin` | String | 進階 | 保留 |
| 臉型 | `faceFeatures` | String | 合併 | 收進外觀細節或摘要 |
| 眼型 | `eyeFeatures` | String | 合併 | 收進外觀細節或摘要 |
| 耳型 | `earFeatures` | String | 相容 | 移入自訂欄位 |
| 鼻型 | `noseFeatures` | String | 合併 | 收進外觀細節或摘要 |
| 嘴型 | `mouthFeatures` | String | 合併 | 收進外觀細節或摘要 |
| 眉型 | `eyebrowFeatures` | String | 相容 | 移入自訂欄位 |
| 體格 | `body` | String | 進階 | 保留 |
| 服裝 | `dress` | String | 進階 | 改稱「常見服裝／造型」 |

### 3.3 故事核心與阻礙

`intention` 雖顯示於「基本資料」，XML 實際位於 `Character/Personality`。

| UI 名稱 | key | 型別 | 建議層級 | 簡化處理 |
| --- | --- | --- | --- | --- |
| 故事中的動機、目標 | `intention` | String | 核心 | 建議拆成 `motivation` 與 `goal`；舊值先放入 `goal` 或遷移備註 |
| 阻礙事件 | `hinderEvents[].event` | String | 核心 | 新模型改稱 `conflicts[].obstacle` |
| 解決方式 | `hinderEvents[].solve` | String | 進階 | 改稱 `conflicts[].resolution`；允許空白，避免未完故事無法輸入 |

### 3.4 個性與價值觀文字欄位

XML：`Character/Personality`

| UI 名稱 | key | 型別 | 建議層級 | 簡化處理 |
| --- | --- | --- | --- | --- |
| MBTI | `mbti` | String | 進階 | 保留，但不作角色建立必要條件 |
| 個性 | `personality` | String | 核心 | 更名 `personalitySummary`，使用多行文字 |
| 口頭禪、慣用語 | `language` | String | 核心 | 更名 `speechStyle`，可包含語氣、稱謂、口頭禪 |
| 興趣 | `interest` | String | 合併 | 併入「喜好／興趣」摘要，舊值保留 |
| 習慣、癖好 | `habit` | String | 進階 | 保留 |
| 陣營 | `alignment` | String? | 進階 | 保留九宮格；移除 `textFields` 中的重複 key |
| 信仰 | `belief` | String | 合併 | 併入 `valuesAndBeliefs` |
| 底線 | `limit` | String | 核心 | 併入價值觀區，但保持獨立資料較利於寫作提示 |
| 將來想變得如何 | `future` | String | 合併 | 併入目標／角色弧線 |
| 最珍視的事物 | `cherish` | String | 合併 | 併入價值觀／重要事物 |
| 最厭惡的事物 | `disgust` | String | 合併 | 併入喜惡摘要 |
| 最害怕的事物 | `fear` | String | 核心 | 保留為故事衝突常用欄位 |
| 最好奇的事物 | `curious` | String | 相容 | 移入進階或自訂欄位 |
| 最期待的事物 | `expect` | String | 合併 | 併入目標／慾望 |
| 其他補充 | `otherValues` | String | 合併 | 併入通用 `notes`，原始 key 保留供遷移 |

### 3.5 陣營選項

`alignment: String?`，單選：

| 守序／善惡 | 中立／善惡 | 混亂／善惡 |
| --- | --- | --- |
| 守序善良 | 中立善良 | 混亂善良 |
| 守序中立 | 絕對中立 | 混亂中立 |
| 守序邪惡 | 中立邪惡 | 絕對邪惡 |

> 現有最後一項是「絕對邪惡」，不是常見九宮格用語「混亂邪惡」。若不是產品刻意定義，實作前應確認是否要修正；遷移時不可擅自改舊值。

### 3.6 性格特質滑桿

欄位：`traitsValues: List<double>`；XML：`Personality` 資料載入後實際存於 `Social/traitsSliders`；預設值 50，範圍 0–100。

| index | XML Title | 左端 | 右端 | 建議 |
| ---: | --- | --- | --- | --- |
| 0 | `attitude` | 悲觀 | 樂觀 | 進階 |
| 1 | `expression` | 面癱 | 生動 | 進階 |
| 2 | `aptitude` | 笨蛋 | 天才 | 相容；措辭可改為「不擅思考／思考敏捷」 |
| 3 | `mindset` | 單純 | 複雜 | 進階 |
| 4 | `shamelessness` | 臉薄 | 厚顏 | 進階 |
| 5 | `temper` | 溫和 | 火爆 | 進階 |
| 6 | `manners` | 粗魯 | 斯文 | 進階 |
| 7 | `willpower` | 軟弱 | 堅定 | 進階 |
| 8 | `desire` | 無慾 | 強烈 | 進階 |
| 9 | `courage` | 膽小 | 勇敢 | 進階 |
| 10 | `eloquence` | 木訥 | 風趣 | 進階 |
| 11 | `vigilance` | 輕信 | 多疑 | 進階 |
| 12 | `self-esteem` | 自卑 | 自信 | 進階 |
| 13 | `confidence` | 退縮 | 果敢 | 進階；名稱容易與上一項混淆 |
| 14 | `archetype` | 陰角 | 陽角 | 相容；文化語意較強，適合自訂屬性 |

### 3.7 行事作風滑桿

欄位：`approachValues: List<double>`；XML：`Social/approachSliders`；預設值 50，範圍 0–100。

| index | XML 左／右標籤 | UI 左端 | UI 右端 | 建議 |
| ---: | --- | --- | --- | --- |
| 0 | `low-key` / `high-profile` | 低調 | 高調 | 進階 |
| 1 | `passive` / `proactive` | 消極 | 積極 | 進階 |
| 2 | `cunning` / `honest` | 狡猾 | 老實 | 進階 |
| 3 | `immature` / `mature` | 幼稚 | 成熟 | 進階 |
| 4 | `calm` / `impulsive` | 冷靜 | 衝動 | 進階 |
| 5 | `taciturn` / `talkative` | 寡言 | 多話 | 進階 |
| 6 | `obstinate` / `obedient` | 執拗 | 順從 | 進階 |
| 7 | `unrestrained` / `disciplined` | 奔放 | 自律 | 進階 |
| 8 | `serious` / `frivolous` | 嚴肅 | 輕浮 | 進階 |
| 9 | `reserved` / `frank` | 彆扭 | 坦率 | 進階 |
| 10 | `indifferent` / `curious` | 淡漠 | 好奇 | 進階 |
| 11 | `dull` / `perceptive` | 遲鈍 | 敏銳 | 進階 |

> 此組 XML `Title` 目前全部為空字串，只能靠陣列順序辨識；應優先補上穩定 ID。

### 3.8 能力與才華清單

XML：`Character/Ability`

| UI 名稱 | key | 型別 | 建議層級 | 簡化處理 |
| --- | --- | --- | --- | --- |
| 熱愛做的事情 | `loveToDoList` | List<String> | 合併 | 與興趣／喜歡的人事物合併顯示 |
| 想要做還沒做的事情 | `wantToDoList` | List<String> | 合併 | 併入目標／願望 |
| 討厭做的事情 | `hateToDoList` | List<String> | 進階 | 併入喜惡清單 |
| 害怕做的事情 | `fearToDoList` | List<String> | 進階 | 與 `fear` 同區呈現 |
| 擅長做的事情 | `proficientToDoList` | List<String> | 核心 | 合併成 `skills`，每筆可標熟練度 |
| 不擅長做的事情 | `unProficientToDoList` | List<String> | 進階 | 合併成 `skills`，熟練度設低值 |

### 3.9 生活常用技能滑桿

欄位：`commonAbilityValues: List<double>`；XML：`Ability/commonAbilitySliders`；預設值 50，範圍 0–100，左右皆為「不擅長／擅長」。

| index | XML Title | UI 名稱 | 建議 |
| ---: | --- | --- | --- |
| 0 | `cooking` | 料理 | 進階 |
| 1 | `cleaning` | 清潔 | 進階 |
| 2 | `finance` | 理財 | 進階 |
| 3 | `fitness` | 體能 | 進階 |
| 4 | `art` | 藝術 | 進階 |
| 5 | `music` | 音樂 | 進階 |
| 6 | `dance` | 舞蹈 | 進階 |
| 7 | `handicraft` | 手工 | 進階 |
| 8 | `social` | 社交 | 進階 |
| 9 | `leadership` | 領導 | 進階 |
| 10 | `analysis` | 分析 | 進階 |
| 11 | `creativity` | 創意 | 進階 |
| 12 | `memory` | 記憶 | 進階 |
| 13 | `observation` | 觀察 | 進階 |
| 14 | `adaptability` | 應變 | 進階 |
| 15 | `learning` | 學習 | 進階 |

建議以可新增的通用 `skills[]` 取代固定 16 軸；舊滑桿仍保留於進階相容區。

### 3.10 社交文字欄位

XML：`Character/Social`

| UI 名稱 | key | 型別 | 建議層級 | 簡化處理 |
| --- | --- | --- | --- | --- |
| 來自他人的印象 | `impression` | String | 核心 | 保留 |
| 最受他人欣賞／喜愛的特點 | `likable` | String | 進階 | 可併入他人印象 |
| 簡述原生家庭 | `family` | String | 核心 | 改稱「家庭／重要背景」 |
| 表達喜歡－其他 | `otherShowLove` | String | 進階 | 隨問卷折疊 |
| 表達好意－其他 | `otherGoodwill` | String | 進階 | 隨問卷折疊 |
| 應對討厭的人－其他 | `otherHatePeople` | String | 進階 | 隨問卷折疊 |
| 戀愛關係－其他 | `otherRelationship` | String | 進階 | 只在選「其他」時顯示 |

### 3.11 社交行為勾選

| 群組 key | 選項 key | UI 文字 |
| --- | --- | --- |
| `howToShowLove` | `confess_directly` | 直接告白 |
| `howToShowLove` | `give_gift` | 送禮物 |
| `howToShowLove` | `talk_often` | 常常找對方講話 |
| `howToShowLove` | `get_attention` | 做些小動作引起注意 |
| `howToShowLove` | `watch_silently` | 默默關注對方 |
| `howToShowGoodwill` | `smile` | 微笑 |
| `howToShowGoodwill` | `greet_actively` | 主動打招呼 |
| `howToShowGoodwill` | `help_actively` | 主動幫忙 |
| `howToShowGoodwill` | `give_small_gift` | 送小禮物 |
| `howToShowGoodwill` | `invite` | 邀請對方 |
| `howToShowGoodwill` | `share_things` | 分享自己的事 |
| `handleHatePeople` | `ignore_directly` | 直接無視 |
| `handleHatePeople` | `keep_distance` | 保持距離 |
| `handleHatePeople` | `be_polite` | 禮貌應對 |
| `handleHatePeople` | `sarcastic` | 冷嘲熱諷 |
| `handleHatePeople` | `confront` | 正面衝突 |
| `handleHatePeople` | `ask_for_help` | 找人幫忙 |

三組皆建議移入「進階設定／社交問卷」。核心表單可用一個 `socialStyleSummary` 多行文字取代，但不可在遷移時丟棄原勾選值。

### 3.12 社交傾向滑桿

欄位：`socialItemValues: List<double>`；XML：`Social/socialItemSliders`；預設值 50，範圍 0–100。

| index | XML 左／右標籤 | UI 左端 | UI 右端 | 建議 |
| ---: | --- | --- | --- | --- |
| 0 | `introverted` / `extroverted` | 內向 | 外向 | 進階 |
| 1 | `emotional` / `rational` | 感性 | 理性 | 進階 |
| 2 | `passive` / `active` | 被動 | 主動 | 進階 |
| 3 | `conservative` / `open` | 保守 | 開放 | 進階 |
| 4 | `cautious` / `adventurous` | 謹慎 | 冒險 | 進階 |
| 5 | `dependent` / `independent` | 依賴 | 獨立 | 進階 |
| 6 | `compliant` / `stubborn` | 柔順 | 固執 | 進階 |
| 7 | `pessimistic` / `optimistic` | 悲觀 | 樂觀 | 進階；與性格特質 index 0 重複 |
| 8 | `serious` / `humorous` | 嚴肅 | 幽默 | 進階 |
| 9 | `shy` / `outgoing` | 害羞 | 大方 | 進階 |

> 此組 XML `Title` 目前也全部為空字串，只能靠順序辨識；應改成有穩定 ID 的物件或 Map。

### 3.13 戀愛關係

| UI 名稱 | key | 型別／選項 | 建議層級 | 簡化處理 |
| --- | --- | --- | --- | --- |
| 戀愛關係 | `relationship` | 單身、已婚／準備結婚、戀愛中／準備戀愛、喪偶、其他 | 進階 | 與角色關係圖分離；這裡只表示個人概況 |
| 另尋新歡 | `isFindNewLove` | bool | 相容 | 特定題材欄位，移入自訂／進階問卷 |
| 后宮型作品 | `isHarem` | bool | 相容 | 這較像作品設定而非角色屬性，建議移至作品設定 |

### 3.14 其他資料

XML：`Character/Other`

| UI 名稱 | key | 型別 | 建議層級 | 簡化處理 |
| --- | --- | --- | --- | --- |
| 原文姓名 | `originalName` | String | 核心 | 與暱稱合併為 `aliases`，保留類型「原文名」 |
| 喜歡的人事物 | `likeItemList` | List<String> | 進階 | 與興趣、熱愛做的事合併顯示 |
| 憧憬的人事物 | `admireItemList` | List<String> | 進階 | 併入價值觀／重要事物 |
| 討厭的人事物 | `hateItemList` | List<String> | 進階 | 與 `disgust`、討厭做的事同區 |
| 害怕的人事物 | `fearItemList` | List<String> | 進階 | 與 `fear`、害怕做的事同區 |
| 習慣的人事物 | `familiarItemList` | List<String> | 相容 | 與 `habit` 語意重疊，移入進階或自訂欄位 |
| 其他補充 | `otherText` | String | 核心 | 與 `otherValues` 統一成 `notes` |

## 4. 現況問題

### 4.1 資料一致性風險

1. **名稱被當作主鍵**：Map key、XML `Character@Name`、`textFields.name` 三處必須同步，改名流程複雜。
2. **陣營重複表示**：`CharacterDataKeys.personalityKeys` 含 `alignment`，模型又有獨立 `alignment`；目前序列化時後者覆蓋前者。
3. **滑桿依賴 index**：四組滑桿都以 `List<double>` 儲存；插入、刪除或改排序可能讓舊值對到錯誤項目。
4. **兩組滑桿缺少 Title**：`socialItems` 與 `approaches` 的 XML `Title` 為空，只能依 left/right 標籤及順序理解。
5. **空值也產生認知負擔**：即使使用者只想寫姓名與動機，仍會看到完整問卷。

### 4.2 使用體驗問題

1. 「興趣／熱愛做的事／喜歡的人事物」高度重疊。
2. 「恐懼／害怕做的事／害怕的人事物」高度重疊。
3. 「個性文字＋37 個性格／社交／作風滑桿」輸入成本過高。
4. 戀愛問卷與一般角色設定耦合，對非戀愛題材形成噪音。
5. 固定資料與隨劇情變化的資料尚未完全分開，例如居住地、陣營與關係狀態可能隨時間改變。

## 5. 簡化後的預設角色表單

### 5.1 預設顯示欄位

建議只有 `displayName` 必填，其餘皆可留空。

| 區塊 | 新欄位 | 來源／說明 |
| --- | --- | --- |
| 基本識別 | `displayName` | 來源 `name`；必填 |
| 基本識別 | `aliases[]` | 合併 `nickname`、`originalName`，每筆可標記類型 |
| 基本識別 | `roleOrOccupation` | 來源 `occupation`，表示身份、職業或故事角色定位 |
| 基本識別 | `age` | 來源 `age` |
| 基本識別 | `gender` | 來源 `gender` |
| 外觀 | `appearanceSummary` | 新增多行摘要；舊外觀細項保留於進階區 |
| 性格 | `personalitySummary` | 來源 `personality` |
| 性格 | `speechStyle` | 來源 `language` |
| 故事核心 | `motivation` | 從 `intention` 人工或半自動拆分，不確定時保留原文 |
| 故事核心 | `goal` | 來源 `intention`、`future`、`expect`、`wantToDoList` |
| 故事核心 | `conflicts[]` | 來源 `hinderEvents`，包含 obstacle／resolution |
| 故事核心 | `valuesAndBeliefs` | 來源 `belief`、`cherish`、`limit` |
| 故事核心 | `fear` | 來源 `fear`，相關清單留在進階區 |
| 關係 | `relationshipSummary` | 來源 `family`、`impression` 與必要的社交概況 |
| 備註 | `notes` | 合併顯示 `otherValues`、`otherText`，遷移時保存來源 |

### 5.2 進階設定

預設折疊，只有區內存在資料時顯示「已填 N 項」：

- 詳細基本資料：生日、出生地、居住地、住址。
- 詳細外觀：身高、體重、血型、髮色、瞳色、膚色、五官、體格、服裝。
- 性格工具：MBTI、陣營、性格特質滑桿、行事作風滑桿。
- 喜好與能力：整合後的喜歡／討厭／害怕／擅長項目與舊生活技能滑桿。
- 社交問卷：17 個勾選、10 個社交滑桿、戀愛狀態。
- 自訂屬性：使用者自行建立 `key/value`，可選文字、數字、布林或清單型別。
- 舊資料相容區：尚未有新欄位可承接的值；唯讀顯示也必須可匯出與再次儲存。

### 5.3 建議資料模型草案

```dart
class CharacterProfile {
  String id; // UUID，永久主鍵
  String displayName;
  List<CharacterAlias> aliases;

  String roleOrOccupation;
  String age;
  String gender;
  String appearanceSummary;
  String personalitySummary;
  String speechStyle;

  String motivation;
  String goal;
  List<CharacterConflict> conflicts;
  String valuesAndBeliefs;
  String fear;
  String relationshipSummary;
  String notes;

  CharacterAdvancedProfile advanced;
  Map<String, CustomFieldValue> customFields;
  Map<String, dynamic> legacyFields;
}
```

動態狀態不要直接塞回 `CharacterProfile`，另建：

```dart
class CharacterState {
  String characterId;
  String? storyTimePointId;
  String location;
  String healthStatus;
  String emotion;
  String alignment;
  List<String> possessions;
}
```

這與 Beta 8 計畫中的「固定角色資料與會隨劇情改變的狀態分離」一致。

## 6. 舊欄位遷移策略

### 6.1 原則

1. 載入舊 XML 時只在記憶體遷移；使用者明確儲存前不覆寫原檔。
2. 每名角色先產生 UUID，再把舊 Map key 與 `name` 轉為 `displayName`。
3. 能一對一映射的欄位直接搬移。
4. 多欄合併時保留來源標記，不用字串拼接後刪除原欄位。
5. 無法可靠判斷的內容進入 `legacyFields`，並在進階相容區可見。
6. 新格式仍須能完整 round-trip：開啟舊檔、未編輯、另存後不得遺失資料。

### 6.2 合併欄位的安全做法

例如 `aliases` 不應只存字串：

```json
[
  { "type": "nickname", "value": "小羽" },
  { "type": "originalName", "value": "桜田如羽" }
]
```

`notes` 可在 UI 合併顯示，但底層遷移資料應保留來源：

```json
{
  "notes": "……",
  "legacyFields": {
    "otherValues": "原個性頁補充",
    "otherText": "原其他頁補充"
  }
}
```

### 6.3 滑桿遷移

所有 index-based 滑桿應轉成 ID-based Map：

```json
{
  "cooking": 75.0,
  "cleaning": 40.0,
  "social.introversion_extroversion": 62.0
}
```

在完成新舊 codec 與 round-trip 測試前，不移除原本的陣列資料。

## 7. 精簡實作計畫

### Phase 1：模型與相容層

- 新增 `CharacterProfile`、`CharacterAlias`、`CharacterConflict`、`CharacterAdvancedProfile`。
- 角色集合改以 UUID 索引，名稱改為一般可編輯欄位。
- 建立舊 `CharacterEntryData` → 新模型的純函式遷移器。
- 先保留舊 `CharacterCodec`，補上新舊格式 round-trip fixture。

完成條件：舊專案所有角色值皆可在新模型或 `legacyFields` 找到。

### Phase 2：簡化表單

- 預設只呈現第 5.1 節欄位。
- 增加「進階設定」折疊區與已填項目計數。
- 把戀愛問卷、量表與詳細五官移入進階區。
- 改名只更新 `displayName`，不搬移資料節點。

完成條件：使用者只填姓名、個性、目標即可完成一張可用角色卡。

### Phase 3：XML 與穩定 ID

- 新 XML 寫入角色 UUID。
- 所有滑桿寫入穩定 ID，不再依賴 index；保留舊格式讀取器。
- 移除 `alignment` 的重複儲存來源。
- 將 `isHarem` 移至作品設定；舊值載入時仍能顯示與保存。

完成條件：新增、改名、重排、存檔、讀檔後資料一致。

### Phase 4：清理與回歸測試

- 測試空值、特殊字元、重複名稱、同名角色、缺失節點與較舊版本。
- 測試舊 53 個滑桿值逐項對應正確。
- 測試 undo／redo、dirty state、搜尋與 Markdown 匯出。
- 至少保留一個含所有舊欄位的黃金測試檔。

完成條件：舊檔另存後沒有不可解釋的欄位遺失，簡化頁也不因空進階欄位產生噪音。

## 8. 驗收清單

- [ ] 新角色只輸入姓名即可建立。
- [ ] 核心表單不顯示 53 個滑桿與 17 個社交勾選。
- [ ] 有舊進階資料時，畫面能提示並展開查看。
- [ ] 角色改名不會改變角色 ID 或建立重複資料。
- [ ] `alignment` 只有一個權威資料來源。
- [ ] 滑桿以穩定 ID 儲存，重新排序不會錯位。
- [ ] 舊 XML 的 70 個頂層 key 均有明確去向。
- [ ] 未能自動合併的欄位會進入 `legacyFields`，而非被捨棄。
- [ ] 開啟舊檔並另存後，所有非空內容都能再次讀回。
- [ ] 角色固定資料與故事時間點狀態分開保存。

## 9. 建議優先決策

在開始改程式前，只需先確定三件事：

1. 核心表單是否採第 5.1 節的 15 個欄位。
2. 性格／能力滑桿是「完整保留在進階區」，還是後續允許使用者自行新增量表。
3. 新 XML 是否直接升版並寫入 UUID，或先在現有格式中加入可選 `UUID` 屬性作過渡。

若希望低風險漸進交付，建議先做「UI 折疊＋欄位摘要」，再做 UUID 與 XML 格式升版；兩者可拆成獨立版本。
