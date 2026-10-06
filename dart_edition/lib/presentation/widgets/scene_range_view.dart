import "package:flutter/material.dart";

import "../../bin/ui_library.dart";
import "../../models/outline_data.dart";

class SceneRangeSegment {
  final String name;
  final int firstBox;
  final int count;
  final int weight;

  const SceneRangeSegment({
    required this.name,
    required this.firstBox,
    required this.count,
    required this.weight,
  });
}

/// Groups adjacent large-box types, weighted by all descendant boxes plus itself.
List<SceneRangeSegment> buildSceneRangeSegments(Iterable<StorylineData> boxes) {
  final segments = <SceneRangeSegment>[];
  var boxNumber = 0;
  for (final box in boxes) {
    boxNumber++;
    final name = box.storylineType.trim();
    final weight =
        1 +
        box.scenes.length +
        box.scenes.fold<int>(0, (sum, event) => sum + event.scenes.length);
    if (segments.isNotEmpty && segments.last.name == name) {
      final previous = segments.removeLast();
      segments.add(
        SceneRangeSegment(
          name: name,
          firstBox: previous.firstBox,
          count: previous.count + 1,
          weight: previous.weight + weight,
        ),
      );
    } else {
      segments.add(
        SceneRangeSegment(
          name: name,
          firstBox: boxNumber,
          count: 1,
          weight: weight,
        ),
      );
    }
  }
  return segments;
}

class SceneRangeView extends StatelessWidget {
  final List<StorylineData> storylines;

  const SceneRangeView({super.key, required this.storylines});

  static const _colors = <Color>[
    Color(0xFF56B69A),
    Color(0xFFE7A66E),
    Color(0xFFAA87DF),
    Color(0xFFF06D91),
    Color(0xFF75ADD4),
    Color(0xFFE9C86A),
    Color(0xFFDE7970),
    Color(0xFF8CBA76),
  ];

  static String _label(String name) => name.isEmpty ? "未設定類型" : name;

  @override
  Widget build(BuildContext context) {
    final segments = buildSceneRangeSegments(storylines);
    final totalWeight = segments.fold<int>(
      0,
      (sum, segment) => sum + segment.weight,
    );
    final counts = <String, int>{};
    for (final segment in segments) {
      counts.update(
        segment.name,
        (value) => value + segment.weight,
        ifAbsent: () => segment.weight,
      );
    }
    final colors = <String, Color>{};
    for (final name in counts.keys) {
      final index = colors.length;
      colors[name] = index < _colors.length
          ? _colors[index]
          : HSLColor.fromAHSL(1, (index * 137.508) % 360, .55, .6).toColor();
    }
    final theme = Theme.of(context);
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("場次範圍", style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            "依大箱類型與順序 · 權重＝1＋中箱數＋小箱數",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (segments.isEmpty)
            Text("新增大箱後，會在這裡顯示場次範圍。", style: theme.textTheme.bodySmall)
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    for (var index = 0; index < segments.length; index++)
                      Expanded(
                        flex: segments[index].weight,
                        child: Tooltip(
                          key: ValueKey("scene-range-segment-$index"),
                          message: _label(segments[index].name),
                          child: Semantics(
                            label:
                                "${_label(segments[index].name)}，"
                                "第 ${segments[index].firstBox} 至 "
                                "${segments[index].firstBox + segments[index].count - 1} 個大箱，"
                                "權重 ${segments[index].weight}",
                            child: Container(
                              decoration: BoxDecoration(
                                color: colors[segments[index].name],
                                border: index == 0
                                    ? null
                                    : Border(
                                        left: BorderSide(
                                          color: theme.colorScheme.surface,
                                          width: 1,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final entry in counts.entries)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: "● ",
                          style: TextStyle(color: colors[entry.key]),
                        ),
                        TextSpan(text: _label(entry.key)),
                        TextSpan(
                          text:
                              " ${(entry.value / totalWeight * 100).toStringAsFixed(1)}%",
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
