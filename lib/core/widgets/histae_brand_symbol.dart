import 'package:flutter/material.dart';

import '../theme/histae_tokens.dart';

/// The original 02 / Les pages symbol, in its 128-unit SVG coordinate system.
class HistaeBrandSymbol extends StatelessWidget {
  const HistaeBrandSymbol({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _PagesPainter());
}

class _PagesPainter extends CustomPainter {
  const _PagesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 128, size.height / 128);
    final left = Path()
      ..moveTo(64, 104)
      ..cubicTo(50, 91, 31, 85, 17, 87)
      ..lineTo(17, 26)
      ..cubicTo(35, 23, 52, 30, 64, 43)
      ..close();
    final right = Path()
      ..moveTo(64, 104)
      ..cubicTo(78, 91, 97, 85, 111, 87)
      ..lineTo(111, 26)
      ..cubicTo(93, 23, 76, 30, 64, 43)
      ..close();
    final lines = Path()
      ..moveTo(28, 45)
      ..cubicTo(38, 45, 46, 49, 53, 55)
      ..moveTo(75, 55)
      ..cubicTo(82, 49, 90, 45, 100, 45);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      left,
      Paint()..color = HistaeTokens.lavender.withValues(alpha: 0.1),
    );
    canvas.drawPath(left, stroke..color = HistaeTokens.lavender);
    canvas.drawPath(
      right,
      Paint()..color = HistaeTokens.ink.withValues(alpha: 0.035),
    );
    canvas.drawPath(right, stroke..color = HistaeTokens.ink);
    canvas.drawPath(
      lines,
      stroke
        ..strokeWidth = 3.5
        ..color = HistaeTokens.lavender.withValues(alpha: 0.65),
    );
    canvas.drawCircle(
      const Offset(64, 17),
      5,
      Paint()..color = HistaeTokens.coral,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PagesPainter oldDelegate) => false;
}
