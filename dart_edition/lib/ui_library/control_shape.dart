import "package:flutter/material.dart";

/// Shared corner radius for noncircular controls.
abstract final class AppControlShape {
  static const borderRadius = BorderRadius.all(Radius.circular(12));
}
