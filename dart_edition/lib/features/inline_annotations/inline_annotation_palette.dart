/*
 * Copyright 2025-2026 Heyairu（部屋伊琉）
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 ************************************************************/

import "package:flutter/material.dart";

import "inline_annotation.dart";

@immutable
final class InlineAnnotationPalette {
  final Map<String, Color> backgrounds;
  final Map<String, Color> foregrounds;

  const InlineAnnotationPalette({
    required this.backgrounds,
    required this.foregrounds,
  });

  static const light = InlineAnnotationPalette(
    backgrounds: <String, Color>{
      "A": Color(0xffd7f5dd),
      "B": Color(0xffdcebff),
      "C": Color(0xfff8dce3),
      "D": Color(0xffe9ddfb),
      "E": Color(0xfffff1b8),
      "F": Color(0xffe5e7eb),
    },
    foregrounds: <String, Color>{
      "A": Color(0xff14532d),
      "B": Color(0xff183b66),
      "C": Color(0xff6f1d35),
      "D": Color(0xff42216e),
      "E": Color(0xff5f4700),
      "F": Color(0xff30343b),
    },
  );

  static const dark = InlineAnnotationPalette(
    backgrounds: <String, Color>{
      "A": Color(0xff24543a),
      "B": Color(0xff274b73),
      "C": Color(0xff71364b),
      "D": Color(0xff503b72),
      "E": Color(0xff66551f),
      "F": Color(0xff454a52),
    },
    foregrounds: <String, Color>{
      "A": Color(0xffc7f9d4),
      "B": Color(0xffd7eaff),
      "C": Color(0xffffd9e3),
      "D": Color(0xffebddff),
      "E": Color(0xffffefad),
      "F": Color(0xfff1f3f5),
    },
  );

  static const highContrast = InlineAnnotationPalette(
    backgrounds: <String, Color>{
      "A": Color(0xff005c20),
      "B": Color(0xff004c8c),
      "C": Color(0xff8b1740),
      "D": Color(0xff561391),
      "E": Color(0xff705900),
      "F": Color(0xff343a40),
    },
    foregrounds: <String, Color>{
      "A": Colors.white,
      "B": Colors.white,
      "C": Colors.white,
      "D": Colors.white,
      "E": Colors.white,
      "F": Colors.white,
    },
  );

  factory InlineAnnotationPalette.of(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.highContrast ?? false) {
      return highContrast;
    }
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  TextStyle styleFor(InlineAnnotationColorCode colors) {
    return TextStyle(
      backgroundColor: colors.background == "0"
          ? null
          : backgrounds[colors.background],
      color: colors.foreground == "0" ? null : foregrounds[colors.foreground],
    );
  }
}
