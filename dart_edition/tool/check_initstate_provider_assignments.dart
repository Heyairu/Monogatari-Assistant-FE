import 'dart:io';

class _InitStateBlock {
  _InitStateBlock({required this.body, required this.startLine});

  final String body;
  final int startLine;
}

class _Violation {
  _Violation({
    required this.filePath,
    required this.line,
    required this.statement,
  });

  final String filePath;
  final int line;
  final String statement;
}

void main() {
  final Directory libDir = Directory('lib');
  if (!libDir.existsSync()) {
    stderr.writeln('Cannot find lib/ directory from current working directory.');
    exitCode = 2;
    return;
  }

  final List<FileSystemEntity> entities =
      libDir.listSync(recursive: true, followLinks: false);

  final List<File> dartFiles = entities
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) => !file.path.endsWith('.g.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final List<_Violation> violations = <_Violation>[];

  for (final File file in dartFiles) {
    final String content = file.readAsStringSync();
    final List<_InitStateBlock> blocks = _extractInitStateBlocks(content);
    for (final _InitStateBlock block in blocks) {
      violations.addAll(
        _findViolationsInBlock(
          filePath: file.path,
          blockBody: block.body,
          blockStartLine: block.startLine,
        ),
      );
    }
  }

  if (violations.isEmpty) {
    stdout.writeln(
      'check_initstate_provider_assignments: OK (no top-level initState provider assignment patterns found).',
    );
    return;
  }

  stderr.writeln(
    'check_initstate_provider_assignments: found ${violations.length} violation(s):',
  );
  for (final _Violation violation in violations) {
    stderr.writeln('${violation.filePath}:${violation.line}');
    stderr.writeln('  ${violation.statement}');
  }
  exitCode = 1;
}

List<_InitStateBlock> _extractInitStateBlocks(String content) {
  final RegExp initStatePattern = RegExp(r'void\s+initState\s*\(\s*\)\s*\{');
  final List<_InitStateBlock> blocks = <_InitStateBlock>[];

  for (final RegExpMatch match in initStatePattern.allMatches(content)) {
    final int openBraceIndex = content.indexOf('{', match.start);
    if (openBraceIndex < 0) {
      continue;
    }

    int depth = 0;
    int i = openBraceIndex;
    int closeBraceIndex = -1;

    while (i < content.length) {
      final String ch = content[i];
      if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) {
          closeBraceIndex = i;
          break;
        }
      }
      i++;
    }

    if (closeBraceIndex <= openBraceIndex) {
      continue;
    }

    final String body = content.substring(openBraceIndex + 1, closeBraceIndex);
    final int startLine = _lineForOffset(content, openBraceIndex + 1);
    blocks.add(_InitStateBlock(body: body, startLine: startLine));
  }

  return blocks;
}

List<_Violation> _findViolationsInBlock({
  required String filePath,
  required String blockBody,
  required int blockStartLine,
}) {
  final List<_Violation> violations = <_Violation>[];
  final List<_StatementSegment> statements = _splitTopLevelStatements(blockBody);

  for (final _StatementSegment segment in statements) {
    final String statement = segment.text.trim();
    if (statement.isEmpty) {
      continue;
    }
    if (!statement.contains('=')) {
      continue;
    }

    final Iterable<RegExpMatch> providerReads = RegExp(
      r'ref\.(read|watch)\s*\(([^)]*)\)',
      multiLine: true,
      dotAll: true,
    ).allMatches(statement);

    if (providerReads.isEmpty) {
      continue;
    }

    bool hasDisallowedRead = false;
    for (final RegExpMatch match in providerReads) {
      final String argument = (match.group(2) ?? '').replaceAll('\n', ' ').trim();
      if (argument.contains('.notifier') || argument.contains('.future')) {
        continue;
      }
      hasDisallowedRead = true;
      break;
    }

    if (!hasDisallowedRead) {
      continue;
    }

    final int statementLine =
        blockStartLine + _lineDelta(blockBody, segment.startOffset);
    final String normalized = statement.replaceAll(RegExp(r'\s+'), ' ').trim();
    violations.add(
      _Violation(filePath: filePath, line: statementLine, statement: normalized),
    );
  }

  return violations;
}

class _StatementSegment {
  _StatementSegment({required this.text, required this.startOffset});

  final String text;
  final int startOffset;
}

List<_StatementSegment> _splitTopLevelStatements(String body) {
  final List<_StatementSegment> statements = <_StatementSegment>[];

  final StringBuffer buffer = StringBuffer();
  int depth = 0;
  int statementStart = 0;

  for (int i = 0; i < body.length; i++) {
    final String ch = body[i];

    if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      if (depth > 0) {
        depth--;
      }
    }

    buffer.write(ch);

    if (ch == ';' && depth == 0) {
      statements.add(
        _StatementSegment(text: buffer.toString(), startOffset: statementStart),
      );
      buffer.clear();
      statementStart = i + 1;
    }
  }

  return statements;
}

int _lineForOffset(String content, int offset) {
  int line = 1;
  for (int i = 0; i < offset && i < content.length; i++) {
    if (content.codeUnitAt(i) == 10) {
      line++;
    }
  }
  return line;
}

int _lineDelta(String content, int offset) {
  int lines = 0;
  for (int i = 0; i < offset && i < content.length; i++) {
    if (content.codeUnitAt(i) == 10) {
      lines++;
    }
  }
  return lines;
}
