import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

abstract final class PhraseTransferIo {
  static Future<String?> importText() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null) return null;
    final file = result.files.single;
    if (file.bytes != null) return utf8.decode(file.bytes!);
    if (!kIsWeb && file.path != null) {
      return File(file.path!).readAsString();
    }
    throw const FormatException('無法讀取短語檔案');
  }

  static Future<bool> exportText(String content) async {
    final output = await FilePicker.platform.saveFile(
      dialogTitle: '匯出短語庫',
      fileName: 'monogatari-phrases.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: kIsWeb || Platform.isAndroid || Platform.isIOS
          ? utf8.encode(content)
          : null,
    );
    if (output == null) return false;
    if (!kIsWeb && !(Platform.isAndroid || Platform.isIOS)) {
      await File(output).writeAsString(content);
    }
    return true;
  }
}
