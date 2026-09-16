import 'package:xml/xml.dart' as xml;
import '../item_data.dart';
import 'xml_text_codec.dart';

/// Typed XML values preserve nulls, unknown quantities and omitted patch fields.
abstract final class ItemXmlValues {
  static String? save(
    String name,
    Iterable<Map<String, dynamic>> records,
    String recordName,
  ) {
    final values = records.toList();
    if (values.isEmpty) return null;
    final b = xml.XmlBuilder();
    b.element(
      'Type',
      nest: () {
        b.element('Name', nest: name);
        for (final record in values) {
          b.element(
            recordName,
            nest: () {
              for (final e in record.entries) {
                _write(b, 'Field', e.value, {'Name': e.key});
              }
            },
          );
        }
      },
    );
    return b.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

  static List<Map<String, dynamic>>? load(
    xml.XmlElement root,
    String name,
    String recordName,
  ) {
    if (root.getElement('Name')?.innerText != name) return null;
    return List.unmodifiable(
      root
          .findElements(recordName)
          .map(
            (r) => {
              for (final f in r.findElements('Field'))
                f.getAttribute('Name')!: _read(f),
            },
          ),
    );
  }

  static void _write(
    xml.XmlBuilder b,
    String tag,
    Object? v,
    Map<String, String> attrs,
  ) {
    final type = v == null
        ? 'null'
        : v is bool
        ? 'bool'
        : v is int
        ? 'int'
        : v is Map
        ? 'map'
        : v is List
        ? 'list'
        : 'string';
    b.element(
      tag,
      attributes: {...attrs, 'Type': type},
      nest: () {
        if (v is Map) {
          for (final e in v.entries) {
            _write(b, 'Field', e.value, {'Name': e.key as String});
          }
        } else if (v is List) {
          for (final e in v) {
            _write(b, 'Value', e, {});
          }
        } else if (v != null) {
          b.text(XmlTextCodec.encodeNewlines(v.toString()));
        }
      },
    );
  }

  static Object? _read(xml.XmlElement e) {
    switch (e.getAttribute('Type')) {
      case 'null':
        return null;
      case 'bool':
        final text = e.innerText;
        if (text != 'true' && text != 'false')
          throw FormatException('Invalid boolean: $text');
        return text == 'true';
      case 'int':
        return int.parse(e.innerText);
      case 'map':
        return {
          for (final f in e.findElements('Field'))
            f.getAttribute('Name')!: _read(f),
        };
      case 'list':
        return e.findElements('Value').map(_read).toList();
      case 'string':
        return XmlTextCodec.readElementText(e);
      default:
        throw FormatException('Unknown XML value type');
    }
  }
}

class ItemCodec {
  static String? saveClasses(Map<String, ItemClassData> values) {
    final keys = values.keys.toList()..sort();
    for (final key in keys) {
      if (values[key]!.classId != key)
        throw ArgumentError('Map key must match classId');
    }
    return ItemXmlValues.save(
      'ItemClasses',
      keys.map((k) => values[k]!.toJson()),
      'Class',
    );
  }

  static Map<String, ItemClassData>? loadClasses(xml.XmlElement root) {
    final values = ItemXmlValues.load(root, 'ItemClasses', 'Class');
    if (values == null) return null;
    final result = <String, ItemClassData>{};
    for (final v in values) {
      final item = ItemClassData.fromJson(v);
      if (result.containsKey(item.classId))
        throw FormatException('Duplicate classId');
      result[item.classId] = item;
    }
    return Map.unmodifiable(result);
  }

  static String? saveInstances(Map<String, ItemInstanceData> values) {
    final keys = values.keys.toList()..sort();
    for (final key in keys) {
      if (values[key]!.instanceId != key)
        throw ArgumentError('Map key must match instanceId');
    }
    return ItemXmlValues.save(
      'ItemInstances',
      keys.map((k) => values[k]!.toJson()),
      'Instance',
    );
  }

  static Map<String, ItemInstanceData>? loadInstances(xml.XmlElement root) {
    final values = ItemXmlValues.load(root, 'ItemInstances', 'Instance');
    if (values == null) return null;
    final result = <String, ItemInstanceData>{};
    for (final v in values) {
      final item = ItemInstanceData.fromJson(v);
      if (result.containsKey(item.instanceId))
        throw FormatException('Duplicate instanceId');
      result[item.instanceId] = item;
    }
    return Map.unmodifiable(result);
  }

  static String? saveRelations(List<ItemRelationData> values) =>
      ItemXmlValues.save(
        'ItemRelations',
        values.map((v) => v.toJson()),
        'Relation',
      );
  static List<ItemRelationData>? loadRelations(xml.XmlElement root) {
    final values = ItemXmlValues.load(root, 'ItemRelations', 'Relation');
    return values == null
        ? null
        : List.unmodifiable(values.map(ItemRelationData.fromJson));
  }
}
