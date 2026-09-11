import "dart:math" as math;

import "package:flutter/material.dart";

abstract final class InlineAnnotationAnchoredPopup {
  static Future<T?> show<T>({
    required BuildContext context,
    required Rect? anchor,
    required double width,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    if (anchor == null) {
      return showDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (dialogContext) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: builder(dialogContext),
          ),
        ),
      );
    }
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (popupContext, animation, secondaryAnimation) {
        return _AnchoredPopupLayout(
          anchor: anchor,
          preferredWidth: width,
          child: builder(popupContext),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
            alignment: Alignment.topLeft,
            child: child,
          ),
        );
      },
    );
  }
}

class _AnchoredPopupLayout extends StatelessWidget {
  final Rect anchor;
  final double preferredWidth;
  final Widget child;

  const _AnchoredPopupLayout({
    required this.anchor,
    required this.preferredWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final safeLeft = media.padding.left + 8;
    final safeTop = media.padding.top + 8;
    final safeRight = media.size.width - media.padding.right - 8;
    final safeBottom =
        media.size.height -
        math.max(media.padding.bottom, media.viewInsets.bottom) -
        8;
    final width = math.min(preferredWidth, safeRight - safeLeft);
    final rightSideLeft = anchor.right + 8;
    final left = rightSideLeft + width <= safeRight
        ? rightSideLeft
        : math.max(safeLeft, anchor.left - width - 8);
    final maxHeight = math.max(120.0, safeBottom - safeTop);
    final top = anchor.top
        .clamp(safeTop, math.max(safeTop, safeBottom - 240))
        .toDouble();

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: width,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
