import "package:code_text_field/code_text_field.dart";
import "package:flutter/material.dart";

import "findreplace.dart";

@immutable
class EditorHighlightPalette {
  final Color? currentMatchBackground;
  final Color? currentMatchForeground;
  final Color? otherMatchBackground;
  final Color? otherMatchForeground;

  const EditorHighlightPalette({
    this.currentMatchBackground,
    this.currentMatchForeground,
    this.otherMatchBackground,
    this.otherMatchForeground,
  });

  const EditorHighlightPalette.empty()
    : currentMatchBackground = null,
      currentMatchForeground = null,
      otherMatchBackground = null,
      otherMatchForeground = null;
}

@immutable
class EditorHighlightState {
  final List<TextSelection> matches;
  final int currentIndex;
  final EditorHighlightPalette palette;

  const EditorHighlightState({
    required this.matches,
    required this.currentIndex,
    this.palette = const EditorHighlightPalette.empty(),
  });

  const EditorHighlightState.empty()
    : matches = const <TextSelection>[],
      currentIndex = -1,
      palette = const EditorHighlightPalette.empty();

  bool get hasMatches => matches.isNotEmpty;

  Color? backgroundForIndex(int index) {
    return index == currentIndex
        ? palette.currentMatchBackground
        : palette.otherMatchBackground;
  }

  Color? foregroundForIndex(int index) {
    return index == currentIndex
        ? palette.currentMatchForeground
        : palette.otherMatchForeground;
  }
}

abstract class EditorControllerAdapter {
  TextEditingController get rawController;

  String get text;
  set text(String value);

  TextSelection get selection;
  set selection(TextSelection value);

  TextEditingValue get value;
  set value(TextEditingValue value);

  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);

  void updateSearchHighlights(EditorHighlightState state);
  void clearSearchHighlights();

  void dispose();
}

class LegacyHighlightEditorAdapter implements EditorControllerAdapter {
  LegacyHighlightEditorAdapter(this._controller);

  final HighlightTextEditingController _controller;

  @override
  TextEditingController get rawController => _controller;

  @override
  String get text => _controller.text;

  @override
  set text(String value) => _controller.text = value;

  @override
  TextSelection get selection => _controller.selection;

  @override
  set selection(TextSelection value) => _controller.selection = value;

  @override
  TextEditingValue get value => _controller.value;

  @override
  set value(TextEditingValue value) => _controller.value = value;

  @override
  void addListener(VoidCallback listener) {
    _controller.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _controller.removeListener(listener);
  }

  @override
  void updateSearchHighlights(EditorHighlightState state) {
    _controller.updateSearchHighlights(
      matches: state.matches,
      currentIndex: state.currentIndex,
      otherMatch: state.palette.otherMatchBackground,
      currentMatch: state.palette.currentMatchBackground,
    );
  }

  @override
  void clearSearchHighlights() {
    _controller.clearSearchHighlights();
  }

  @override
  void dispose() {
    _controller.dispose();
  }
}

class CodeTextFieldEditorAdapter implements EditorControllerAdapter {
  CodeTextFieldEditorAdapter(this._controller);

  final CodeController _controller;
  final ValueNotifier<EditorHighlightState> highlightStateListenable =
      ValueNotifier<EditorHighlightState>(const EditorHighlightState.empty());

  @override
  TextEditingController get rawController => _controller;

  @override
  String get text => _controller.text;

  @override
  set text(String value) => _controller.text = value;

  @override
  TextSelection get selection => _controller.selection;

  @override
  set selection(TextSelection value) => _controller.selection = value;

  @override
  TextEditingValue get value => _controller.value;

  @override
  set value(TextEditingValue value) => _controller.value = value;

  @override
  void addListener(VoidCallback listener) {
    _controller.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _controller.removeListener(listener);
  }

  @override
  void updateSearchHighlights(EditorHighlightState state) {
    highlightStateListenable.value = state;
  }

  @override
  void clearSearchHighlights() {
    highlightStateListenable.value = const EditorHighlightState.empty();
  }

  @override
  void dispose() {
    highlightStateListenable.dispose();
    _controller.dispose();
  }
}
