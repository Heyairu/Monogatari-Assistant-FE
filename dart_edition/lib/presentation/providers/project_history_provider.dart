import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../bin/file.dart" as file_module;
import "project_snapshot_utils.dart";

class ProjectHistoryEntry {
  final file_module.ProjectData data;
  final String xmlContent;
  final String xmlComparisonKey;
  final int pageIndex;
  final String? selectedSegID;
  final String? selectedChapID;
  final int cursorOffset;

  ProjectHistoryEntry({
    required file_module.ProjectData data,
    required this.pageIndex,
    required this.selectedSegID,
    required this.selectedChapID,
    required this.cursorOffset,
  }) : data = snapshotProjectData(data),
       xmlContent = file_module.FileService.generateProjectXML(
         snapshotProjectData(data),
       ),
       xmlComparisonKey = _normalizeHistoryXml(
         file_module.FileService.generateProjectXML(snapshotProjectData(data)),
       );
}

String _normalizeHistoryXml(String xmlContent) {
  return xmlContent.replaceAll(
    RegExp(r"<LatestSave>[^<]*</LatestSave>"),
    "<LatestSave></LatestSave>",
  );
}

class ProjectHistoryState {
  final List<ProjectHistoryEntry> undoStack;
  final List<ProjectHistoryEntry> redoStack;

  const ProjectHistoryState({
    this.undoStack = const [],
    this.redoStack = const [],
  });

  bool get canUndo => undoStack.length > 1;
  bool get canRedo => redoStack.isNotEmpty;
}

class ProjectHistoryNotifier extends Notifier<ProjectHistoryState> {
  static const int _maxEntries = 50;

  @override
  ProjectHistoryState build() {
    return const ProjectHistoryState();
  }

  void reset(ProjectHistoryEntry entry) {
    state = ProjectHistoryState(undoStack: [entry], redoStack: const []);
  }

  bool record(ProjectHistoryEntry entry) {
    final currentStack = state.undoStack;
    final nextUndo = [...currentStack, entry];
    final trimmedUndo = nextUndo.length > _maxEntries
        ? nextUndo.sublist(nextUndo.length - _maxEntries)
        : nextUndo;
    state = ProjectHistoryState(undoStack: trimmedUndo, redoStack: const []);
    return true;
  }

  ProjectHistoryEntry? undo(ProjectHistoryEntry currentEntry) {
    if (state.undoStack.isEmpty) {
      reset(currentEntry);
      return null;
    }

    final undoStack = [...state.undoStack];
    if (undoStack.last.xmlComparisonKey != currentEntry.xmlComparisonKey) {
      undoStack.add(currentEntry);
    }

    if (undoStack.length <= 1) {
      state = ProjectHistoryState(
        undoStack: undoStack,
        redoStack: state.redoStack,
      );
      return null;
    }

    final current = undoStack.removeLast();
    final target = undoStack.last;
    final nextRedo = [current, ...state.redoStack];
    final trimmedRedo = nextRedo.length > _maxEntries
        ? nextRedo.sublist(0, _maxEntries)
        : nextRedo;
    state = ProjectHistoryState(undoStack: undoStack, redoStack: trimmedRedo);
    return target;
  }

  ProjectHistoryEntry? redo(ProjectHistoryEntry currentEntry) {
    if (state.redoStack.isEmpty) {
      if (state.undoStack.isEmpty) {
        reset(currentEntry);
      }
      return null;
    }

    final redoStack = [...state.redoStack];
    final target = redoStack.removeAt(0);
    final undoStack = [...state.undoStack];
    if (undoStack.isEmpty ||
        undoStack.last.xmlComparisonKey != currentEntry.xmlComparisonKey) {
      undoStack.add(currentEntry);
    }
    undoStack.add(target);
    final trimmedUndo = undoStack.length > _maxEntries
        ? undoStack.sublist(undoStack.length - _maxEntries)
        : undoStack;

    state = ProjectHistoryState(undoStack: trimmedUndo, redoStack: redoStack);
    return target;
  }
}

final projectHistoryProvider =
    NotifierProvider<ProjectHistoryNotifier, ProjectHistoryState>(
      ProjectHistoryNotifier.new,
    );
