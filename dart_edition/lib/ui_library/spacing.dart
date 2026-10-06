import "package:flutter/material.dart";

/// Fixed design padding uses multiples of 4 logical pixels (dp).
/// Text metrics and system insets keep their calculated values.
abstract final class AppSpacing {
  static const unit = 4.0;
  static const xs = unit;
  static const sm = unit * 2;
  static const md = unit * 3;
  static const lg = unit * 4;
  static const space20 = unit * 5;
  static const xl = unit * 6;
  static const xxl = unit * 8;
  static const space40 = unit * 10;

  static const controlVertical = sm;
  static const formPadding = EdgeInsets.symmetric(vertical: xs);
  static const badgePadding = EdgeInsets.symmetric(
    horizontal: sm,
    vertical: xs,
  );
  static const iconButtonPadding = EdgeInsets.all(controlVertical);
  static const fieldPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: controlVertical,
  );
  static const buttonPadding = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: controlVertical,
  );
  static const cellPadding = EdgeInsets.all(md);
  static const listPadding = EdgeInsets.all(sm);
  static const compactSection = EdgeInsets.all(lg);
  static const regularSection = EdgeInsets.all(xl);
  static const dialogInset = EdgeInsets.symmetric(
    horizontal: space40,
    vertical: xl,
  );
  static const dialogContent = EdgeInsets.fromLTRB(xl, space20, xl, 0);
  static const dialogTitle = EdgeInsets.fromLTRB(xl, xl, xl, 0);
  static const dialogActions = EdgeInsets.fromLTRB(xl, sm, xl, xl);
  static const checkboxTile = EdgeInsets.symmetric(horizontal: md);
}
