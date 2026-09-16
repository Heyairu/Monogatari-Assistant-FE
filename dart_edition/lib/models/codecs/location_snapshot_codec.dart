import 'package:xml/xml.dart' as xml;
import '../location_snapshot_data.dart';
import 'item_codec.dart';

class LocationSnapshotCodec {
  static String? saveChanges(List<LocationStateChange> values) =>
      ItemXmlValues.save(
        'LocationStateChanges',
        values.map((v) => v.toJson()),
        'Change',
      );
  static List<LocationStateChange>? loadChanges(xml.XmlElement root) {
    final values = ItemXmlValues.load(root, 'LocationStateChanges', 'Change');
    return values == null
        ? null
        : List.unmodifiable(values.map(LocationStateChange.fromJson));
  }
}
