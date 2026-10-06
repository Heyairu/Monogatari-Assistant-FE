import '../../../domain/collaboration/collaboration_operation.dart';

enum RevisionSidebarPage {
  baseInfo,
  chapters,
  outline,
  characters,
  world,
  items,
}

/// Phase 1 navigation/schema contract. Widget navigation and mutation are
/// intentionally left to the later provider/UI integration.
abstract final class RevisionFieldRegistry {
  static const supportedKinds = {
    ProjectRecordKind.baseInfo,
    ProjectRecordKind.chapterFolder,
    ProjectRecordKind.chapterMetadata,
    ProjectRecordKind.character,
    ProjectRecordKind.worldNode,
    ProjectRecordKind.outlineStoryline,
    ProjectRecordKind.outlineEvent,
    ProjectRecordKind.outlineScene,
    ProjectRecordKind.outlineChapterLink,
    ProjectRecordKind.itemClass,
    ProjectRecordKind.itemInstance,
    ProjectRecordKind.itemRelation,
    ProjectRecordKind.itemClassStateChange,
    ProjectRecordKind.itemInstanceStateChange,
  };
  static RevisionSidebarPage? pageFor(ProjectRecordKind kind) => switch (kind) {
    ProjectRecordKind.baseInfo => RevisionSidebarPage.baseInfo,
    ProjectRecordKind.chapterFolder ||
    ProjectRecordKind.chapterMetadata => RevisionSidebarPage.chapters,
    ProjectRecordKind.character => RevisionSidebarPage.characters,
    ProjectRecordKind.worldNode => RevisionSidebarPage.world,
    ProjectRecordKind.outlineStoryline ||
    ProjectRecordKind.outlineEvent ||
    ProjectRecordKind.outlineScene ||
    ProjectRecordKind.outlineChapterLink => RevisionSidebarPage.outline,
    ProjectRecordKind.itemClass ||
    ProjectRecordKind.itemInstance ||
    ProjectRecordKind.itemRelation ||
    ProjectRecordKind.itemClassStateChange ||
    ProjectRecordKind.itemInstanceStateChange => RevisionSidebarPage.items,
    _ => null,
  };
  static String pageLabel(RevisionSidebarPage page) => switch (page) {
    RevisionSidebarPage.baseInfo => '作品資訊',
    RevisionSidebarPage.chapters => '章節',
    RevisionSidebarPage.characters => '角色設定',
    RevisionSidebarPage.world => '世界設定',
    RevisionSidebarPage.outline => '大綱調整',
    RevisionSidebarPage.items => '物品設定',
  };
  static const _labels = <String, String>{
    'bookName': '書名',
    'author': '作者',
    'purpose': '創作目的',
    'toRecap': '摘要',
    'storyType': '故事類型',
    'intro': '簡介',
    'tags': '標籤',
    'name': '名稱',
    'displayName': '名稱',
    'age': '年齡',
    'gender': '性別',
    'roleOrOccupation': '角色／職業',
    'appearanceSummary': '外觀',
    'personalitySummary': '性格',
    'speechStyle': '說話方式',
    'motivation': '動機',
    'goal': '目標',
    'notes': '備註',
    'note': '備註',
    'customFields': '自訂欄位',
    'customValues': '自訂欄位',
    'key': '欄位名稱',
    'val': '欄位值',
    'value': '欄位值',
    'localType': '地點類型',
    'nodeType': '節點類型',
    'type': '類型',
    'event': '事件',
    'memo': '備註',
    'conflictPoint': '衝突',
    'people': '人物',
    'items': '物品',
    'doingThings': '行動',
    'time': '時間',
    'location': '地點',
    'focusPoint': '重點',
    'description': '設定說明',
    'category': '分類',
    'unit': '數量單位',
    'mode': '管理模式',
    'defaultState': '預設狀態',
    'archived': '封存',
    'patch': '狀態變更',
    r'$parent': '所屬',
    r'$order': '排序',
  };

  /// Unknown fields remain visible under their source name, never omitted.
  static String labelFor(Iterable<String> path) =>
      path.map((part) => _labels[part] ?? part).join('／');

  static bool excluded(String field) =>
      field == 'schemaVersion' || field == 'order';

  /// World custom values are an unordered, stable-ID field collection.
  /// Other lists remain atomic until a domain-specific adapter is registered.
  static Object? comparableField(String field, Object? value) {
    if (field == 'customValues' && value is List) {
      final ids = <String>{};
      if (value.every(
        (item) =>
            item is Map &&
            item['id'] is String &&
            ids.add(item['id'] as String),
      )) {
        return <String, Object?>{
          for (final item in value.cast<Map>())
            item['id'] as String: comparableValue(
              Map<String, Object?>.from(item)..remove('id'),
            ),
        };
      }
    }
    return comparableValue(value);
  }

  static Object? comparableValue(Object? value) {
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key as String, comparableValue(item)),
      );
    }
    if (value is List) {
      return value.map(comparableValue).toList();
    }
    return value;
  }
}
