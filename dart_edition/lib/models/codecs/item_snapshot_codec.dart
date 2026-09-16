import 'package:xml/xml.dart' as xml;
import '../item_snapshot_data.dart';
import 'item_codec.dart';

class ItemSnapshotCodec {
  static String? saveClassChanges(List<ItemClassStateChange> values) =>
      ItemXmlValues.save(
        'ItemClassStateChanges',
        values.map((v) => v.toJson()),
        'Change',
      );
  static List<ItemClassStateChange>? loadClassChanges(xml.XmlElement root) {
    final values = ItemXmlValues.load(root, 'ItemClassStateChanges', 'Change');
    return values == null
        ? null
        : List.unmodifiable(values.map(ItemClassStateChange.fromJson));
  }

  static String? saveInstanceChanges(List<ItemInstanceStateChange> values) =>
      ItemXmlValues.save(
        'ItemInstanceStateChanges',
        values.map((v) => v.toJson()),
        'Change',
      );
  static List<ItemInstanceStateChange>? loadInstanceChanges(
    xml.XmlElement root,
  ) {
    final values = ItemXmlValues.load(
      root,
      'ItemInstanceStateChanges',
      'Change',
    );
    return values == null
        ? null
        : List.unmodifiable(values.map(ItemInstanceStateChange.fromJson));
  }
}
