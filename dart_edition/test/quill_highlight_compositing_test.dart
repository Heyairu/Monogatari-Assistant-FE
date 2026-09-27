import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monogatari_assistant/features/editor/plain_text_quill_editor_poc.dart';
import 'package:monogatari_assistant/features/editor/plain_text_quill_render_range.dart';

void main() {
  testWidgets('highlights change the background without dimming white glyphs', (
    tester,
  ) async {
    final search = PlainTextQuillSearchController();
    final boundaryKey = GlobalKey();
    addTearDown(search.dispose);
    final font = FontLoader('PreviewNoto')
      ..addFont(rootBundle.load('assets/fonts/NotoSansTC-Variable.ttf'));
    await font.load();
    // An explicit text color allows pixel comparisons to catch any overlay
    // that tints glyphs, even when the chosen theme tokens pass contrast tests.
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        home: Scaffold(
          body: RepaintBoundary(
            key: boundaryKey,
            child: ColoredBox(
              color: const Color(0xFF0C1009),
              child: DefaultTextStyle(
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'PreviewNoto',
                ),
                child: PlainTextQuillEditorPoc(
                  content:
                      'MATCH RED MENTION\n如羽站在客廳中央，這裡寬敞、乾淨。\n「真的搬家了啊。」她嘆口氣，聲音在空曠的客廳裡迴盪。',
                  onChanged: (_) {},
                  searchController: search,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    Future<List<int>> pixels() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final bytes = data!.buffer.asUint8List().toList();
      image.dispose();
      return bytes;
    }

    final before = (await tester.runAsync(pixels))!;
    search.showHostResults(
      query: 'test',
      matches: const [
        TextRange(start: 0, end: 5),
        TextRange(start: 6, end: 9),
        TextRange(start: 22, end: 25),
        TextRange(start: 45, end: 46),
      ],
      currentMatchIndex: 1,
      selectCurrent: false,
    );
    search.setRenderRanges(const [
      PlainTextQuillRenderRange(
        range: TextRange(start: 10, end: 17),
        backgroundColor: Color(0xFF274B73),
      ),
    ]);
    await tester.pump();
    await tester.pump();
    final after = (await tester.runAsync(pixels))!;
    if (Platform.environment['QUILL_VISUAL_PREVIEW'] == '1') {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File('build/quill-highlight-preview.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
    }
    var whitePixels = 0;
    var changedPixels = 0;
    for (var i = 0; i < before.length; i += 4) {
      if (before[i] == 255 && before[i + 1] == 255 && before[i + 2] == 255) {
        whitePixels++;
        expect(
          after.sublist(i, i + 3),
          [255, 255, 255],
          reason: 'Highlights must not tint the foreground glyph at byte $i',
        );
      }
      if (before[i] != after[i] ||
          before[i + 1] != after[i + 1] ||
          before[i + 2] != after[i + 2]) {
        changedPixels++;
      }
    }
    expect(whitePixels, greaterThan(50));
    expect(changedPixels, greaterThan(50));
  });
}
