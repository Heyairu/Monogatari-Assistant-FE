// Copyright 2025-2026 Heyairu（部屋伊琉）
// Licensed under the Apache License, Version 2.0.

/// Stable identifiers shared by assets, focus scopes and pointer targets.
abstract final class HelpTopicId {
  static const home = 'help.home';
  static const usingHelp = 'help.using';
  static const shortcuts = 'help.shortcuts';
  static const recovery = 'files.recovery';
  static const faq = 'help.faq';
  static const editor = 'editor.body';
  static const punctuation = 'editor.punctuation';
  static const annotations = 'editor.annotations';
  static const phrases = 'editor.phrases';
  static const search = 'search.overview';
  static const findInput = 'search.input';
  static const replaceInput = 'search.replacement';
  static const previous = 'search.previous';
  static const next = 'search.next';
  static const replace = 'search.replace';
  static const replaceAll = 'search.replaceAll';
  static const toolbar = 'toolbar.overview';
  static const toolbarMode = 'toolbar.mode';
  static const autoSave = 'settings.autoSave';
  static const backup = 'settings.backup';
  static const backupDirectory = 'settings.backupDirectory';
  static const backupCapacity = 'settings.backupCapacity';
  static const dialog = 'dialogs.overview';
  static const importFiles = 'files.import_selective';
  static const exportFiles = 'files.export_selective';

  /// Matches ContentView's actual page switch, rather than historical comments.
  static const pages = <String>[
    'pages.welcome',
    'pages.story',
    'pages.chapters',
    'pages.outline',
    'pages.timeline',
    'pages.characters',
    'pages.relationships',
    'pages.world',
    'pages.items',
    'pages.plans',
    'pages.glossary',
    'pages.palettes',
    'pages.proofreading',
    'pages.copilot',
    'pages.settings',
    'pages.about',
  ];

  static const commands = <String, String>{
    'save': 'files.save',
    'new': 'files.new',
    'open': 'files.open',
    'saveAs': 'files.saveAs',
    'import_selective': importFiles,
    'export_selective': exportFiles,
    'selectAll': 'editor.selectAll',
    'cut': 'editor.cut',
    'copy': 'editor.copy',
    'paste': 'editor.paste',
    'undo': 'editor.undo',
    'redo': 'editor.redo',
    'punctuation': punctuation,
    'find': search,
    'search.matchCase': 'search.matchCase',
    'search.wholeWord': 'search.wholeWord',
    'search.useRegexp': 'search.useRegexp',
    'search.matchWidth': 'search.matchWidth',
    'search.ignorePunctuation': 'search.ignorePunctuation',
    'search.ignoreWhitespace': 'search.ignoreWhitespace',
  };

  static String forPage(int index) =>
      index >= 0 && index < pages.length ? pages[index] : editor;
  static String forCommand(String id) => commands[id] ?? toolbar;
}
