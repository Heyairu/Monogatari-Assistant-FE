# Icon Scaling Implementation

## Overview
Implemented dynamic scaling for Icons throughout the application to ensure they resize proportionally with the global Font Size setting.

## Changes

### 1. Global Theme (`lib/bin/theme_manager.dart`)
- Updated `ThemeData` to include `iconTheme: IconThemeData(size: baseFontSize + 10)`.
- This ensures that by default, all Icons without an explicit size will scale automatically (e.g. 14px font -> 24px icon).

### 2. Main Navigation (`lib/main.dart`)
- **AppBar**: Icons now use `fontSize + 10` (matching the theme default).
- **Mobile Status Bar**: Icons now use `fontSize` (1:1 ratio).
- **Mobile Navigation Chips**: Icons now use `fontSize + 4`.

### 3. Settings View (`lib/modules/settingview.dart`)
- Header Icons: Manually scaled (e.g., `fontSize + 18`).
- List Tiles: Removed hardcoded `size: 20` to allow inheritance from `iconTheme`.

### 4. Module Views
- **BaseInfoView** (`lib/modules/baseinfoview.dart`): Removed hardcoded `size: 20/18` from section headers and chips.
- **ChapterSelectionView** (`lib/modules/chapterselectionview.dart`): Removed hardcoded `size: 20` from Edit/Delete buttons.

## Result
Changing the Font Size in Settings now affects:
- Text throughout the app (via TextTheme).
- AppBar and Toolbar icons.
- Navigation elements.
- Icons in forms and lists.
