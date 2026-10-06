import "package:flutter/material.dart";

/// Shared 16dp corners for cards, lists, and dialogs.
abstract final class AppSurfaceShape {
  static const double radius = 16;
  static const BorderRadius borderRadius = BorderRadius.all(
    Radius.circular(radius),
  );
  static const RoundedRectangleBorder shape = RoundedRectangleBorder(
    borderRadius: borderRadius,
  );
}
