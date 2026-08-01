import "package:xml/xml.dart" as xml;

import "../character_data.dart";
import "xml_text_codec.dart";

class CharacterStateCodec {
  static String? saveXML(List<CharacterState> states) {
    if (states.isEmpty) return null;
    final builder = xml.XmlBuilder();
    builder.element(
      "Type",
      nest: () {
        builder.element("Name", nest: "CharacterStates");
        for (final state in states) {
          builder.element(
            "State",
            attributes: {
              "CharacterId": state.characterId,
              if (state.storyTimePointId?.isNotEmpty == true)
                "StoryTimePointId": state.storyTimePointId!,
            },
            nest: () {
              XmlTextCodec.writeTextElement(
                builder,
                "Location",
                state.location,
              );
              XmlTextCodec.writeTextElement(
                builder,
                "HealthStatus",
                state.healthStatus,
              );
              XmlTextCodec.writeTextElement(builder, "Emotion", state.emotion);
              XmlTextCodec.writeTextElement(
                builder,
                "Alignment",
                state.alignment,
              );
              if (state.possessions.isNotEmpty) {
                builder.element(
                  "Possessions",
                  nest: () {
                    for (final item in state.possessions) {
                      XmlTextCodec.writeTextElement(builder, "Item", item);
                    }
                  },
                );
              }
            },
          );
        }
      },
    );
    return builder.buildDocument().toXmlString(pretty: true, indent: "  ");
  }

  static List<CharacterState>? loadElement(xml.XmlElement typeElement) {
    final name = typeElement.findElements("Name").firstOrNull?.innerText;
    if (name != "CharacterStates") return null;
    return typeElement
        .findElements("State")
        .map((node) {
          String read(String name) =>
              XmlTextCodec.readElementText(node.findElements(name).firstOrNull);

          return CharacterState(
            characterId: node.getAttribute("CharacterId") ?? "",
            storyTimePointId: node.getAttribute("StoryTimePointId"),
            location: read("Location"),
            healthStatus: read("HealthStatus"),
            emotion: read("Emotion"),
            alignment: read("Alignment"),
            possessions: node
                .findElements("Possessions")
                .expand((parent) => parent.findElements("Item"))
                .map(XmlTextCodec.readElementText)
                .toList(growable: false),
          );
        })
        .where((state) => state.characterId.isNotEmpty)
        .toList(growable: false);
  }
}
