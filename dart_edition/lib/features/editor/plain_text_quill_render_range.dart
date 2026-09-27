import "package:flutter/material.dart";

@immutable
final class PlainTextQuillRenderRange {
  const PlainTextQuillRenderRange({
    required this.range,
    this.backgroundColor,
    this.decorationColor,
    this.decorationThickness = 1,
    this.doubleUnderline = false,
  });

  final TextRange range;
  final Color? backgroundColor;
  final Color? decorationColor;
  final double decorationThickness;
  final bool doubleUnderline;

  PlainTextQuillRenderRange copyWithRange(TextRange nextRange) =>
      PlainTextQuillRenderRange(
        range: nextRange,
        backgroundColor: backgroundColor,
        decorationColor: decorationColor,
        decorationThickness: decorationThickness,
        doubleUnderline: doubleUnderline,
      );
}
