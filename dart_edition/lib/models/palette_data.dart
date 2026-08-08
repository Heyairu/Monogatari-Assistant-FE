import "dart:convert";

import "package:characters/characters.dart";
import "package:flutter/foundation.dart";

const int paletteDataVersion = 1;
const int paletteTermMaxLength = 80;

enum PaletteSlotKind { color, gray }

@immutable
class PaletteSvPreset {
  final int saturation;
  final int value;

  const PaletteSvPreset(this.saturation, this.value);
}

const List<PaletteSvPreset> paletteSvPresets = <PaletteSvPreset>[
  PaletteSvPreset(100, 20),
  PaletteSvPreset(50, 20),
  PaletteSvPreset(50, 50),
  PaletteSvPreset(80, 50),
  PaletteSvPreset(100, 50),
  PaletteSvPreset(100, 80),
  PaletteSvPreset(100, 100),
  PaletteSvPreset(80, 100),
  PaletteSvPreset(50, 80),
  PaletteSvPreset(50, 100),
  PaletteSvPreset(20, 80),
  PaletteSvPreset(20, 100),
];

const List<int> paletteGrayValues = <int>[0, 20, 50, 80, 100];

final List<int> paletteHueDegrees = List<int>.unmodifiable(
  List<int>.generate(20, (int index) => index * 18),
);

String _padPaletteValue(int value) => value.toString().padLeft(3, "0");

String paletteColorSlotId({
  required int hue,
  required int saturation,
  required int value,
}) {
  return "h${_padPaletteValue(hue)}-s${_padPaletteValue(saturation)}-v${_padPaletteValue(value)}";
}

String paletteGraySlotId(int value) => "gray-v${_padPaletteValue(value)}";

@immutable
class PaletteSlotDefinition {
  final String id;
  final PaletteSlotKind kind;
  final int hue;
  final int saturation;
  final int value;
  final int sortOrder;

  const PaletteSlotDefinition({
    required this.id,
    required this.kind,
    required this.hue,
    required this.saturation,
    required this.value,
    required this.sortOrder,
  });

  bool get isGray => kind == PaletteSlotKind.gray;

  String get semanticsLabel =>
      isGray ? "灰階，明度 $value%" : "色相 $hue 度，飽和度 $saturation%，明度 $value%";
}

List<PaletteSlotDefinition> _buildPaletteSlots() {
  final List<PaletteSlotDefinition> slots = <PaletteSlotDefinition>[];
  var sortOrder = 0;
  for (final int hue in paletteHueDegrees) {
    for (final PaletteSvPreset preset in paletteSvPresets) {
      slots.add(
        PaletteSlotDefinition(
          id: paletteColorSlotId(
            hue: hue,
            saturation: preset.saturation,
            value: preset.value,
          ),
          kind: PaletteSlotKind.color,
          hue: hue,
          saturation: preset.saturation,
          value: preset.value,
          sortOrder: sortOrder++,
        ),
      );
    }
  }
  for (final int value in paletteGrayValues) {
    slots.add(
      PaletteSlotDefinition(
        id: paletteGraySlotId(value),
        kind: PaletteSlotKind.gray,
        hue: 360,
        saturation: 0,
        value: value,
        sortOrder: sortOrder++,
      ),
    );
  }
  return List<PaletteSlotDefinition>.unmodifiable(slots);
}

final List<PaletteSlotDefinition> allPaletteSlots = _buildPaletteSlots();

final Map<String, PaletteSlotDefinition> paletteSlotById =
    Map<String, PaletteSlotDefinition>.unmodifiable(
      <String, PaletteSlotDefinition>{
        for (final PaletteSlotDefinition slot in allPaletteSlots) slot.id: slot,
      },
    );

List<PaletteSlotDefinition> paletteSlotsForHue(int hue) {
  return allPaletteSlots
      .where(
        (PaletteSlotDefinition slot) =>
            slot.kind == PaletteSlotKind.color && slot.hue == hue,
      )
      .toList(growable: false);
}

final List<PaletteSlotDefinition> paletteGraySlots = List.unmodifiable(
  allPaletteSlots.where(
    (PaletteSlotDefinition slot) => slot.kind == PaletteSlotKind.gray,
  ),
);

@immutable
class PaletteEntry {
  final String id;
  final String text;
  final String createdAt;
  final String updatedAt;

  const PaletteEntry({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
  });

  PaletteEntry copyWith({
    String? id,
    String? text,
    String? createdAt,
    String? updatedAt,
  }) {
    return PaletteEntry(
      id: id ?? this.id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    "id": id,
    "text": text,
    "createdAt": createdAt,
    "updatedAt": updatedAt,
  };
}

@immutable
class PaletteStateData {
  final Map<String, List<String>> slotEntryIds;
  final Map<String, PaletteEntry> entryIndex;
  final String? persistenceError;

  const PaletteStateData({
    required this.slotEntryIds,
    required this.entryIndex,
    this.persistenceError,
  });

  factory PaletteStateData.empty() {
    return const PaletteStateData(
      slotEntryIds: <String, List<String>>{},
      entryIndex: <String, PaletteEntry>{},
    );
  }

  PaletteStateData copyWith({
    Map<String, List<String>>? slotEntryIds,
    Map<String, PaletteEntry>? entryIndex,
    String? persistenceError,
    bool clearPersistenceError = false,
  }) {
    return PaletteStateData(
      slotEntryIds: slotEntryIds ?? this.slotEntryIds,
      entryIndex: entryIndex ?? this.entryIndex,
      persistenceError: clearPersistenceError
          ? null
          : (persistenceError ?? this.persistenceError),
    );
  }
}

@immutable
class PaletteDecodeResult {
  final PaletteStateData data;
  final List<String> warnings;

  const PaletteDecodeResult({required this.data, required this.warnings});
}

String normalizePaletteTerm(String value) => value.trim().toLowerCase();

String? validatePaletteTerm(String value) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) {
    return "詞條不可為空白";
  }
  if (trimmed.characters.length > paletteTermMaxLength) {
    return "詞條不可超過 $paletteTermMaxLength 個字元";
  }
  return null;
}

abstract final class PaletteDataCodec {
  static PaletteDecodeResult decode(String raw, {DateTime? now}) {
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException("Palettes.json 不是合法物件格式");
    }

    final dynamic rawVersion = decoded["version"];
    if (rawVersion is! int) {
      throw const FormatException("Palettes.json 缺少有效的 version");
    }
    if (rawVersion > paletteDataVersion) {
      throw FormatException(
        "Palettes.json 版本 $rawVersion 高於目前支援版本 $paletteDataVersion",
      );
    }
    if (rawVersion < 1) {
      throw FormatException("不支援的 Palettes.json 版本：$rawVersion");
    }

    final List<String> warnings = <String>[];
    final String fallbackTimestamp = (now ?? DateTime.now())
        .toUtc()
        .toIso8601String();
    final Map<String, PaletteEntry> parsedEntries = <String, PaletteEntry>{};
    final dynamic rawEntries = decoded["entries"];
    if (rawEntries != null && rawEntries is! Map<String, dynamic>) {
      throw const FormatException("Palettes.json 的 entries 必須是物件");
    }
    if (rawEntries is Map<String, dynamic>) {
      for (final MapEntry<String, dynamic> item in rawEntries.entries) {
        if (item.value is! Map<String, dynamic>) {
          warnings.add("忽略格式錯誤的詞條：${item.key}");
          continue;
        }
        final Map<String, dynamic> value = item.value as Map<String, dynamic>;
        final String text = (value["text"] as String? ?? "").trim();
        if (item.key.trim().isEmpty || text.isEmpty) {
          warnings.add("忽略缺少 ID 或文字的詞條：${item.key}");
          continue;
        }
        final String innerId = value["id"] as String? ?? item.key;
        if (innerId != item.key) {
          warnings.add("詞條 ${item.key} 的內外 ID 不一致，採用外層 ID");
        }
        parsedEntries[item.key] = PaletteEntry(
          id: item.key,
          text: text,
          createdAt: _validTimestamp(value["createdAt"], fallbackTimestamp),
          updatedAt: _validTimestamp(value["updatedAt"], fallbackTimestamp),
        );
      }
    }

    final dynamic rawSlots = decoded["slotEntryIds"];
    if (rawSlots != null && rawSlots is! Map<String, dynamic>) {
      throw const FormatException("Palettes.json 的 slotEntryIds 必須是物件");
    }

    final Map<String, List<String>> normalizedSlots = <String, List<String>>{};
    final Set<String> referencedIds = <String>{};
    if (rawSlots is Map<String, dynamic>) {
      for (final PaletteSlotDefinition slot in allPaletteSlots) {
        final dynamic rawIds = rawSlots[slot.id];
        if (rawIds == null) {
          continue;
        }
        if (rawIds is! List<dynamic>) {
          warnings.add("忽略非陣列的 slot：${slot.id}");
          continue;
        }
        final List<String> ids = <String>[];
        final Set<String> seen = <String>{};
        for (final dynamic rawId in rawIds) {
          if (rawId is! String ||
              !parsedEntries.containsKey(rawId) ||
              !seen.add(rawId)) {
            warnings.add("忽略 ${slot.id} 中無效或重複的詞條引用");
            continue;
          }
          ids.add(rawId);
          referencedIds.add(rawId);
        }
        if (ids.isNotEmpty) {
          normalizedSlots[slot.id] = List<String>.unmodifiable(ids);
        }
      }
      for (final String rawSlotId in rawSlots.keys) {
        if (!paletteSlotById.containsKey(rawSlotId)) {
          warnings.add("忽略未知的 slot：$rawSlotId");
        }
      }
    }

    final Map<String, PaletteEntry> normalizedEntries = <String, PaletteEntry>{
      for (final String id in referencedIds) id: parsedEntries[id]!,
    };
    final int orphanCount = parsedEntries.length - normalizedEntries.length;
    if (orphanCount > 0) {
      warnings.add("移除 $orphanCount 筆未被任何 slot 參照的詞條");
    }

    return PaletteDecodeResult(
      data: immutablePaletteState(
        slotEntryIds: normalizedSlots,
        entryIndex: normalizedEntries,
      ),
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  static String encode(PaletteStateData data) {
    final Map<String, dynamic> slots = <String, dynamic>{};
    final Set<String> referencedIds = <String>{};
    for (final PaletteSlotDefinition slot in allPaletteSlots) {
      final List<String> ids = data.slotEntryIds[slot.id] ?? const <String>[];
      final List<String> validIds = <String>[];
      final Set<String> seen = <String>{};
      for (final String id in ids) {
        if (data.entryIndex.containsKey(id) && seen.add(id)) {
          validIds.add(id);
          referencedIds.add(id);
        }
      }
      if (validIds.isNotEmpty) {
        slots[slot.id] = validIds;
      }
    }

    final Map<String, dynamic> entries = <String, dynamic>{};
    for (final String id in referencedIds) {
      final PaletteEntry? entry = data.entryIndex[id];
      if (entry != null) {
        entries[id] = entry.copyWith(id: id).toJson();
      }
    }

    return jsonEncode(<String, dynamic>{
      "version": paletteDataVersion,
      "slotEntryIds": slots,
      "entries": entries,
    });
  }

  static String _validTimestamp(dynamic raw, String fallback) {
    if (raw is String && DateTime.tryParse(raw) != null) {
      return raw;
    }
    return fallback;
  }
}

PaletteStateData immutablePaletteState({
  required Map<String, List<String>> slotEntryIds,
  required Map<String, PaletteEntry> entryIndex,
  String? persistenceError,
}) {
  return PaletteStateData(
    slotEntryIds: Map<String, List<String>>.unmodifiable(<String, List<String>>{
      for (final MapEntry<String, List<String>> item in slotEntryIds.entries)
        item.key: List<String>.unmodifiable(item.value),
    }),
    entryIndex: Map<String, PaletteEntry>.unmodifiable(entryIndex),
    persistenceError: persistenceError,
  );
}
