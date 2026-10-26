import 'package:flutter/material.dart';

/// A squared 1+ monogram with a VPN padlock, shared with the Android vector icon.
class PlusLogo extends StatelessWidget {
  const PlusLogo({super.key, this.size = 32, this.color});
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'PlusVPN',
    image: true,
    child: CustomPaint(
      size: Size.square(size),
      painter: _PlusMark(color ?? Theme.of(context).colorScheme.primary),
    ),
  );
}

class _PlusMark extends CustomPainter {
  const _PlusMark(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48, size.height / 48);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.miter;
    canvas.drawPath(
      Path()
        ..moveTo(30, 6)
        ..lineTo(6, 6)
        ..lineTo(6, 40)
        ..lineTo(27, 40),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(11, 19)
        ..lineTo(18, 13)
        ..lineTo(18, 33)
        ..moveTo(12, 33)
        ..lineTo(24, 33),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(35, 3)
        ..lineTo(35, 17)
        ..moveTo(28, 10)
        ..lineTo(42, 10),
      stroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(29, 29, 16, 14),
        const Radius.circular(3),
      ),
      Paint()..color = color,
    );
    canvas.drawArc(
      const Rect.fromLTWH(33, 21, 8, 14),
      3.14159265,
      3.14159265,
      false,
      stroke,
    );
    canvas.drawCircle(
      const Offset(37, 35),
      1.5,
      Paint()
        ..color =
            ThemeData.estimateBrightnessForColor(color) == Brightness.light
            ? Colors.black87
            : Colors.white,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PlusMark oldDelegate) =>
      oldDelegate.color != color;
}
