# 大小寫不敏感搜尋實作說明

## 功能概述

當「大小寫需相同」選項設為 `false` 時，搜尋功能將使用自訂的 `_normalizeCase()` 函數來處理多語言大小寫轉換，而不是簡單的 `toLowerCase()`。

## 支援的語言和字元

### 1. 拉丁字母 (Latin)
- **基本拉丁字母**: A-Z → a-z
- **範圍**: U+0041-U+005A → U+0061-U+007A
- **範例**: `ABC` → `abc`, `Hello` → `hello`

### 2. 西歐語言重音符號 (Western European)
- **法語**: `ÉCOLE` → `école`, `CAFÉ` → `café`
- **德語**: `ÜBER` → `über`, `ÄÖÜ` → `äöü`
- **西班牙語**: `NIÑO` → `niño`, `ESPAÑA` → `españa`
- **葡萄牙語**: `AÇÃO` → `ação`, `PORTUGUÊS` → `português`
- **範圍**: U+00C0-U+00DE → U+00E0-U+00FE (跳過 U+00D7 乘號)

### 3. 希臘字母 (Greek)
- **基本希臘字母**: Α-Ω → α-ω
- **範圍**: U+0391-U+03A9 → U+03B1-U+03C9
- **範例**: `ΕΛΛΑΣ` → `ελλασ`, `ΑΒΓΔ` → `αβγδ`

#### 帶重音符號的希臘字母
- `Ά` (U+0386) → `ά` (U+03AC)
- `Έ` (U+0388) → `έ` (U+03AD)
- `Ή` (U+0389) → `ή` (U+03AE)
- `Ί` (U+038A) → `ί` (U+03AF)
- `Ό` (U+038C) → `ό` (U+03CC)
- `Ύ` (U+038E) → `ύ` (U+03CD)
- `Ώ` (U+038F) → `ώ` (U+03CE)

### 4. 西里爾字母 (Cyrillic - 俄語等)
- **俄語字母**: А-Я → а-я
- **範圍**: U+0410-U+042F → U+0430-U+044F
- **範例**: `ПРИВЕТ` → `привет`, `МОСКВА` → `москва`

### 5. 全形拉丁字母 (Fullwidth Latin)
- **全形英文**: Ａ-Ｚ → ａ-ｚ
- **範圍**: U+FF21-U+FF3A → U+FF41-U+FF5A
- **範例**: `ＡＢＣ` → `ａｂｃ`

### 6. 中歐和東歐語言 (Central/Eastern European)
- **波蘭語**: `ŁÓDŹ` → `łódź`
- **捷克語**: `ČESKÝ` → `český`
- **匈牙利語**: `MAGYÁR` → `magyár`
- **範圍**: U+0100-U+017F (拉丁擴展-A)
- **規則**: 偶數碼點為大寫，+1 為對應小寫

### 7. 土耳其語特殊字元 (Turkish)
- **大寫 İ**: `İ` (U+0130) → `i`
- **說明**: 土耳其語的大寫 İ (帶點的 I) 轉為小寫 i

## 實作細節

### 函數簽名
```dart
String _normalizeCase(String text)
```

### 轉換邏輯
函數逐字元檢查並轉換：

1. 檢查字元的 Unicode 碼點
2. 根據碼點範圍判斷語言類型
3. 應用對應的大小寫轉換規則
4. 將轉換後的字元加入結果緩衝區

### 不受影響的字元
- **中文字元**: 漢字、假名等不受影響
- **數字**: 0-9 保持不變
- **符號**: 標點符號、數學符號等保持不變

## 使用範例

### 在 main.dart 中的使用

```dart
// 在 _performFind 函數中
if (!options.matchCase) {
  processedText = _normalizeCase(processedText);
  processedFindText = _normalizeCase(processedFindText);
}

// 在 _textMatches 函數中
if (!options.matchCase) {
  processedText = _normalizeCase(processedText);
  processedPattern = _normalizeCase(processedPattern);
}
```

### 搜尋範例

| 搜尋文字 | 可匹配的內容 | 語言 |
|---------|------------|------|
| `hello` | Hello, HELLO, hello | 英語 |
| `école` | École, ÉCOLE, école | 法語 |
| `über` | Über, ÜBER, über | 德語 |
| `αλφα` | ΑΛΦΑ, Αλφα, αλφα | 希臘語 |
| `привет` | ПРИВЕТ, Привет, привет | 俄語 |

## 性能考量

- 函數使用字元級迭代，效率較高
- 使用 `StringBuffer` 避免字串連接開銷
- 只在 `matchCase = false` 時執行轉換
- 對於 CJK 字元等不需轉換的字元，直接保留原值

## 未來擴展

如需支援更多語言，可以添加以下範圍：

- **阿拉伯字母**: U+0621-U+064A
- **希伯來字母**: U+05D0-U+05EA
- **亞美尼亞字母**: U+0531-U+0556
- **格魯吉亞字母**: U+10A0-U+10C5
- **泰語**: U+0E01-U+0E3A

## 相關文件

- `lib/main.dart`: 主要實作位置
- `lib/bin/findreplace.dart`: 搜尋選項定義
