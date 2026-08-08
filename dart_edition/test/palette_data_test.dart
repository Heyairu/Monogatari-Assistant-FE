import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/models/palette_data.dart";

void main() {
  group("Palette definitions", () {
    test("builds the required hue, SV, and gray slots", () {
      expect(paletteHueDegrees, hasLength(20));
      expect(paletteHueDegrees.first, 0);
      expect(paletteHueDegrees.last, 342);
      for (var index = 1; index < paletteHueDegrees.length; index++) {
        expect(paletteHueDegrees[index] - paletteHueDegrees[index - 1], 18);
      }

      expect(paletteSvPresets, hasLength(12));
      expect(paletteGrayValues, <int>[0, 20, 50, 80, 100]);
      expect(allPaletteSlots, hasLength(245));
      expect(paletteSlotById, hasLength(245));
      expect(paletteSlotById, contains("h000-s100-v020"));
      expect(paletteSlotById, contains("h342-s020-v100"));
      expect(paletteSlotById, contains("gray-v000"));
      expect(paletteSlotById, contains("gray-v100"));
      expect(paletteGraySlots.every((slot) => slot.saturation == 0), isTrue);
    });
  });

  group("PaletteDataCodec", () {
    test("round trips entries while preserving slot order", () {
      const PaletteEntry first = PaletteEntry(
        id: "entry-1",
        text: "焦灼",
        createdAt: "2026-08-08T12:00:00.000Z",
        updatedAt: "2026-08-08T12:00:00.000Z",
      );
      const PaletteEntry second = PaletteEntry(
        id: "entry-2",
        text: "緋紅",
        createdAt: "2026-08-08T12:01:00.000Z",
        updatedAt: "2026-08-08T12:01:00.000Z",
      );
      final PaletteStateData source = immutablePaletteState(
        slotEntryIds: <String, List<String>>{
          "h000-s100-v020": <String>[second.id, first.id],
        },
        entryIndex: <String, PaletteEntry>{first.id: first, second.id: second},
      );

      final PaletteDecodeResult decoded = PaletteDataCodec.decode(
        PaletteDataCodec.encode(source),
      );

      expect(decoded.data.slotEntryIds["h000-s100-v020"], <String>[
        second.id,
        first.id,
      ]);
      expect(decoded.data.entryIndex[first.id]?.text, "焦灼");
      expect(decoded.warnings, isEmpty);
    });

    test("drops unknown slots, bad references, duplicates, and orphans", () {
      const String raw = """
{
  "version": 1,
  "slotEntryIds": {
    "h000-s100-v020": ["entry-1", "missing", "entry-1"],
    "unknown-slot": ["entry-2"]
  },
  "entries": {
    "entry-1": {
      "id": "entry-1",
      "text": "焦灼",
      "createdAt": "2026-08-08T12:00:00.000Z",
      "updatedAt": "2026-08-08T12:00:00.000Z"
    },
    "entry-2": {
      "id": "entry-2",
      "text": "孤立",
      "createdAt": "2026-08-08T12:00:00.000Z",
      "updatedAt": "2026-08-08T12:00:00.000Z"
    }
  }
}
""";

      final PaletteDecodeResult decoded = PaletteDataCodec.decode(raw);

      expect(decoded.data.slotEntryIds["h000-s100-v020"], <String>["entry-1"]);
      expect(decoded.data.entryIndex.keys, <String>["entry-1"]);
      expect(decoded.warnings, isNotEmpty);
    });

    test("rejects unsupported newer files", () {
      expect(
        () => PaletteDataCodec.decode(
          '{"version": 99, "slotEntryIds": {}, "entries": {}}',
        ),
        throwsFormatException,
      );
    });
  });

  group("Palette term validation", () {
    test("rejects blank and overlong entries", () {
      expect(validatePaletteTerm("   "), isNotNull);
      expect(
        validatePaletteTerm(List<String>.filled(81, "字").join()),
        isNotNull,
      );
      expect(validatePaletteTerm("焦灼"), isNull);
    });
  });
}
