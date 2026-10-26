import 'package:flutter/material.dart';

/// Scales the Navigator and all its routes together, including keyboard insets.
class InterfaceScale extends StatelessWidget {
  const InterfaceScale({super.key, required this.scale, required this.child});
  final double scale;
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final media = MediaQuery.of(context);
      final factor = scale.clamp(.8, 1.2);
      final size = Size(bounds.maxWidth / factor, bounds.maxHeight / factor);
      return FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(
          size: size,
          child: MediaQuery(
            data: media.copyWith(
              size: size,
              devicePixelRatio: media.devicePixelRatio * factor,
              padding: media.padding / factor,
              viewPadding: media.viewPadding / factor,
              viewInsets: media.viewInsets / factor,
              systemGestureInsets: media.systemGestureInsets / factor,
            ),
            child: child,
          ),
        ),
      );
    },
  );
}
