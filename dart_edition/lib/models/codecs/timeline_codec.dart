import "package:xml/xml.dart" as xml;

import "../timeline_data.dart";

abstract final class TimelineCodec {
  static const int schemaVersion = 1;

  static String? saveXML(
    TimelineDocumentData document,
    List<OutlineChapterLinkData> chapterLinks,
  ) {
    final builder = xml.XmlBuilder();
    builder.element(
      "Type",
      nest: () {
        builder.element("Name", nest: "Timeline");
        builder.element(
          "Timeline",
          attributes: {"SchemaVersion": schemaVersion.toString()},
          nest: () {
            final grid = document.grid;
            builder.element(
              "Grid",
              attributes: {
                "TickValue": grid.ticksPerLittleBox.value.toString(),
                "TickUnit": grid.ticksPerLittleBox.unit.name,
                "CustomLabel": grid.ticksPerLittleBox.customLabel,
                "TicksPerSmallBox": grid.ticksPerSmallBox.toString(),
                "TicksPerMiddleBox": grid.ticksPerMiddleBox.toString(),
                "MiddleBoxesPerLargeBox": grid.middleBoxesPerLargeBox
                    .toString(),
                "AutoSortOutline": grid.autoSortOutline.toString(),
                "OriginLabel": grid.originLabel,
                if (grid.originIso8601 != null)
                  "OriginIso8601": grid.originIso8601!,
              },
            );
            builder.element(
              "Tracks",
              nest: () {
                for (final track in document.tracks) {
                  builder.element(
                    "Track",
                    attributes: {
                      "UUID": track.trackUUID,
                      "Name": track.name,
                      "Order": track.order.toString(),
                      "Collapsed": track.isCollapsed.toString(),
                      if (track.colorToken != null)
                        "ColorToken": track.colorToken!,
                    },
                  );
                }
              },
            );
            builder.element(
              "Placements",
              nest: () {
                for (final placement in document.placements) {
                  builder.element(
                    "Placement",
                    attributes: {
                      "UUID": placement.placementUUID,
                      if (placement.storylineUUID != null)
                        "StorylineUUID": placement.storylineUUID!,
                      if (placement.eventUUID != null)
                        "EventUUID": placement.eventUUID!,
                      if (placement.sceneUUID != null)
                        "SceneUUID": placement.sceneUUID!,
                      if (placement.parentPlacementUUID != null)
                        "ParentUUID": placement.parentPlacementUUID!,
                      "Level": placement.level.name,
                      "TrackUUID": placement.trackUUID,
                      "StartTick": placement.startTick.toString(),
                      "DurationTicks": placement.durationTicks.toString(),
                      "Order": placement.order.toString(),
                      "Label": placement.label,
                    },
                  );
                }
              },
            );
            builder.element(
              "ChapterLinks",
              nest: () {
                for (final link in chapterLinks) {
                  builder.element(
                    "Link",
                    attributes: {
                      "UUID": link.linkUUID,
                      "SceneUUID": link.sceneUUID,
                      "ChapterUUID": link.chapterUUID,
                      "Sequence": link.sequence.toString(),
                      "Coverage": link.coverage.name,
                      if (link.note != null) "Note": link.note!,
                    },
                  );
                }
              },
            );
          },
        );
      },
    );
    return builder.buildDocument().rootElement.toXmlString(pretty: true);
  }

  static TimelineProjectData? loadElement(xml.XmlElement typeElement) {
    final name = typeElement.getElement("Name")?.innerText.trim();
    if (name != "Timeline") return null;
    final timeline = typeElement.getElement("Timeline");
    if (timeline == null) return null;

    final defaultDocument = TimelineDocumentData.initial();
    final gridElement = timeline.getElement("Grid");
    final defaultGrid = defaultDocument.grid;
    final tickUnit = _enumByName(
      TickDurationUnit.values,
      gridElement?.getAttribute("TickUnit"),
      TickDurationUnit.day,
    );
    final grid = TimelineGridConfig(
      ticksPerLittleBox: TickDurationData(
        value: _positiveInt(
          gridElement?.getAttribute("TickValue"),
          defaultGrid.ticksPerLittleBox.value,
        ),
        unit: tickUnit,
        customLabel: gridElement?.getAttribute("CustomLabel") ?? "",
      ),
      ticksPerSmallBox: _positiveInt(
        gridElement?.getAttribute("TicksPerSmallBox"),
        defaultGrid.ticksPerSmallBox,
      ),
      ticksPerMiddleBox: _positiveInt(
        gridElement?.getAttribute("TicksPerMiddleBox"),
        defaultGrid.ticksPerMiddleBox,
      ),
      middleBoxesPerLargeBox: _positiveInt(
        gridElement?.getAttribute("MiddleBoxesPerLargeBox"),
        defaultGrid.middleBoxesPerLargeBox,
      ),
      autoSortOutline: gridElement?.getAttribute("AutoSortOutline") == "true",
      originLabel:
          gridElement?.getAttribute("OriginLabel") ?? defaultGrid.originLabel,
      originIso8601: gridElement?.getAttribute("OriginIso8601"),
    );

    final tracks = <TimelineTrackData>[];
    for (final node in timeline.findAllElements("Track")) {
      final uuid = node.getAttribute("UUID")?.trim() ?? "";
      if (uuid.isEmpty) continue;
      tracks.add(
        TimelineTrackData(
          trackUUID: uuid,
          name: node.getAttribute("Name") ?? "未命名軌道",
          order: int.tryParse(node.getAttribute("Order") ?? "") ?? 0,
          colorToken: node.getAttribute("ColorToken"),
          isCollapsed: node.getAttribute("Collapsed") == "true",
        ),
      );
    }
    if (tracks.isEmpty) tracks.addAll(defaultDocument.tracks);

    final placements = <TimelinePlacementData>[];
    for (final node in timeline.findAllElements("Placement")) {
      final uuid = node.getAttribute("UUID")?.trim() ?? "";
      final trackUUID = node.getAttribute("TrackUUID")?.trim() ?? "";
      if (uuid.isEmpty || trackUUID.isEmpty) continue;
      placements.add(
        TimelinePlacementData(
          placementUUID: uuid,
          storylineUUID: _nullable(node.getAttribute("StorylineUUID")),
          eventUUID: _nullable(node.getAttribute("EventUUID")),
          sceneUUID: _nullable(node.getAttribute("SceneUUID")),
          parentPlacementUUID: _nullable(node.getAttribute("ParentUUID")),
          level: _enumByName(
            TimelineElementLevel.values,
            node.getAttribute("Level"),
            TimelineElementLevel.small,
          ),
          trackUUID: trackUUID,
          startTick: int.tryParse(node.getAttribute("StartTick") ?? "") ?? 0,
          durationTicks: _positiveInt(node.getAttribute("DurationTicks"), 1),
          order: int.tryParse(node.getAttribute("Order") ?? "") ?? 0,
          label: node.getAttribute("Label") ?? "",
        ),
      );
    }

    final links = <OutlineChapterLinkData>[];
    final seenPairs = <String>{};
    for (final node in timeline.findAllElements("Link")) {
      final uuid = node.getAttribute("UUID")?.trim() ?? "";
      final sceneUUID = node.getAttribute("SceneUUID")?.trim() ?? "";
      final chapterUUID = node.getAttribute("ChapterUUID")?.trim() ?? "";
      final pair = "$sceneUUID\u0000$chapterUUID";
      if (uuid.isEmpty ||
          sceneUUID.isEmpty ||
          chapterUUID.isEmpty ||
          !seenPairs.add(pair)) {
        continue;
      }
      links.add(
        OutlineChapterLinkData(
          linkUUID: uuid,
          sceneUUID: sceneUUID,
          chapterUUID: chapterUUID,
          sequence: int.tryParse(node.getAttribute("Sequence") ?? "") ?? 0,
          coverage: _enumByName(
            ChapterLinkCoverage.values,
            node.getAttribute("Coverage"),
            ChapterLinkCoverage.full,
          ),
          note: _nullable(node.getAttribute("Note")),
        ),
      );
    }

    return TimelineProjectData(
      document: TimelineDocumentData(
        grid: grid,
        tracks: tracks,
        placements: placements,
      ),
      chapterLinks: links,
    );
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  static int _positiveInt(String? text, int fallback) {
    final value = int.tryParse(text ?? "");
    return value == null || value < 1 ? fallback : value;
  }

  static String? _nullable(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
