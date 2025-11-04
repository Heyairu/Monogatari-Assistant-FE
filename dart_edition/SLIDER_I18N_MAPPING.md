# 滑桿標籤國際化對照表

## 滑桿儲存格式
```xml
<slider Title="title" leftTag="leftTag" rightTag="rightTag">數值</slider>
```

範例：
```xml
<slider Title="courage" leftTag="cowardly" rightTag="brave">30.0</slider>
```

## Common Ability Sliders (生活常用技能)

| Title | 中文 | leftTag | 中文 | rightTag | 中文 |
|-------|------|---------|------|----------|------|
| cooking | 料理 | poor | 不擅長 | good | 擅長 |
| cleaning | 清潔 | poor | 不擅長 | good | 擅長 |
| finance | 理財 | poor | 不擅長 | good | 擅長 |
| fitness | 體能 | poor | 不擅長 | good | 擅長 |
| art | 藝術 | poor | 不擅長 | good | 擅長 |
| music | 音樂 | poor | 不擅長 | good | 擅長 |
| dance | 舞蹈 | poor | 不擅長 | good | 擅長 |
| handicraft | 手工 | poor | 不擅長 | good | 擅長 |
| social | 社交 | poor | 不擅長 | good | 擅長 |
| leadership | 領導 | poor | 不擅長 | good | 擅長 |
| analysis | 分析 | poor | 不擅長 | good | 擅長 |
| creativity | 創意 | poor | 不擅長 | good | 擅長 |
| memory | 記憶 | poor | 不擅長 | good | 擅長 |
| observation | 觀察 | poor | 不擅長 | good | 擅長 |
| adaptability | 應變 | poor | 不擅長 | good | 擅長 |
| learning | 學習 | poor | 不擅長 | good | 擅長 |

## Social Item Sliders (社交相關項目)

| Title | leftTag | 中文 | rightTag | 中文 |
|-------|---------|------|----------|------|
| (空) | introverted | 內向 | extroverted | 外向 |
| (空) | emotional | 感性 | rational | 理性 |
| (空) | passive | 被動 | active | 主動 |
| (空) | conservative | 保守 | open | 開放 |
| (空) | cautious | 謹慎 | adventurous | 冒險 |
| (空) | dependent | 依賴 | independent | 獨立 |
| (空) | compliant | 柔順 | stubborn | 固執 |
| (空) | pessimistic | 悲觀 | optimistic | 樂觀 |
| (空) | serious | 嚴肅 | humorous | 幽默 |
| (空) | shy | 害羞 | outgoing | 大方 |

## Approach Style Sliders (行事作風)

| Title | leftTag | 中文 | rightTag | 中文 |
|-------|---------|------|----------|------|
| (空) | low-key | 低調 | high-profile | 高調 |
| (空) | passive | 消極 | proactive | 積極 |
| (空) | cunning | 狡猾 | honest | 老實 |
| (空) | immature | 幼稚 | mature | 成熟 |
| (空) | calm | 冷靜 | impulsive | 衝動 |
| (空) | taciturn | 寡言 | talkative | 多話 |
| (空) | obstinate | 執拗 | obedient | 順從 |
| (空) | unrestrained | 奔放 | disciplined | 自律 |
| (空) | serious | 嚴肅 | frivolous | 輕浮 |
| (空) | reserved | 彆扭 | frank | 坦率 |
| (空) | indifferent | 淡漠 | curious | 好奇 |
| (空) | dull | 遲鈍 | perceptive | 敏銳 |

## Traits Sliders (性格特質)

| Title | 中文 | leftTag | 中文 | rightTag | 中文 |
|-------|------|---------|------|----------|------|
| attitude | 態度 | pessimistic | 悲觀 | optimistic | 樂觀 |
| expression | 表情 | expressionless | 面癱 | vivid | 生動 |
| aptitude | 資質 | dull | 笨蛋 | genius | 天才 |
| mindset | 思想 | simple | 單純 | complex | 複雜 |
| shamelessness | 臉皮 | thin-skinned | 極薄 | thick-skinned | 極厚 |
| temper | 脾氣 | gentle | 溫和 | hot-tempered | 火爆 |
| manners | 舉止 | rude | 粗魯 | refined | 斯文 |
| willpower | 意志 | fragile | 易碎 | strong | 堅強 |
| desire | 慾望 | ascetic | 無慾 | intense | 強烈 |
| courage | 膽量 | cowardly | 膽小 | brave | 勇敢 |
| eloquence | 談吐 | inarticulate | 木訥 | witty | 風趣 |
| vigilance | 戒心 | gullible | 輕信 | suspicious | 多疑 |
| self-esteem | 自尊 | low | 低下 | high | 高亢 |
| confidence | 自信 | low | 低下 | high | 高亢 |
| archetype | 陰陽 | antagonist | 陰角 | protagonist | 陽角 |

## XML 範例

### Common Ability Slider
```xml
<slider Title="cooking" leftTag="poor" rightTag="good">7.5</slider>
```

### Social Item Slider
```xml
<slider Title="" leftTag="introverted" rightTag="extroverted">6.0</slider>
```

### Approach Style Slider
```xml
<slider Title="" leftTag="calm" rightTag="impulsive">45.0</slider>
```

### Traits Slider
```xml
<slider Title="courage" leftTag="cowardly" rightTag="brave">30.0</slider>
```

## 國際化建議

在實現國際化時，可以使用這些英文鍵值來查找對應的翻譯文本：

### 範例 i18n 配置 (JSON 格式)

```json
{
  "en": {
    "cooking": "Cooking",
    "poor": "Poor",
    "good": "Good",
    "courage": "Courage",
    "cowardly": "Cowardly",
    "brave": "Brave"
  },
  "zh-TW": {
    "cooking": "料理",
    "poor": "不擅長",
    "good": "擅長",
    "courage": "膽量",
    "cowardly": "膽小",
    "brave": "勇敢"
  },
  "ja": {
    "cooking": "料理",
    "poor": "不得手",
    "good": "得意",
    "courage": "勇気",
    "cowardly": "臆病",
    "brave": "勇敢"
  }
}
```

## 讀取範例

```dart
// 從 XML 讀取
final titleAttr = element.getAttribute('Title'); // "courage"
final leftAttr = element.getAttribute('leftTag'); // "cowardly"
final rightAttr = element.getAttribute('rightTag'); // "brave"

// 查找翻譯
final titleText = i18n.translate(titleAttr); // "膽量"
final leftText = i18n.translate(leftAttr);   // "膽小"
final rightText = i18n.translate(rightAttr); // "勇敢"
```
