import "package:flutter/widgets.dart";

final class PoppinMoveIntent extends Intent {
  final int delta;

  const PoppinMoveIntent(this.delta);
}

final class PoppinAcceptIntent extends Intent {
  const PoppinAcceptIntent();
}

final class PoppinLevelIntent extends Intent {
  final int direction;

  const PoppinLevelIntent(this.direction);
}

final class PoppinDismissIntent extends Intent {
  const PoppinDismissIntent();
}
