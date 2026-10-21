import 'package:flutter/material.dart';

import '../theme/histae_tokens.dart';

/// Vector interpretation of the site's two threads meeting in a point of light.
class ConnectionArtwork extends StatelessWidget {
  const ConnectionArtwork({super.key, this.height = 160, this.framed = true});
  final double height;
  final bool framed;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: framed ? HistaeTokens.panelGradient(context) : null,
        borderRadius: BorderRadius.circular(24),
        border: framed
            ? Border.all(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: 0.18),
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(painter: _ConnectionPainter(framed: framed)),
        ),
      ),
    ),
  );
}

class _ConnectionPainter extends CustomPainter {
  const _ConnectionPainter({required this.framed});
  final bool framed;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.52, size.height * 0.54);
    final rect = Offset.zero & size;
    if (framed) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.95, 0.95),
            radius: 1.25,
            colors: [
              HistaeTokens.lavender.withValues(alpha: 0.14),
              Colors.transparent,
            ],
          ).createShader(rect),
      );
    }
    final orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = HistaeTokens.lavender.withValues(alpha: 0.18);
    canvas.drawCircle(
      Offset(size.width * 0.04, -size.height * 0.3),
      size.width * 0.4,
      orbit,
    );
    canvas.drawCircle(
      Offset(size.width * 1.05, size.height * 1.25),
      size.width * 0.38,
      orbit,
    );
    final leftThread = Path()
      ..moveTo(-10, size.height * 0.72)
      ..cubicTo(
        size.width * 0.12,
        size.height * 0.82,
        size.width * 0.18,
        size.height * 0.12,
        size.width * 0.33,
        size.height * 0.32,
      )
      ..quadraticBezierTo(
        size.width * 0.43,
        size.height * 0.39,
        center.dx,
        center.dy,
      );
    canvas.drawPath(
      leftThread,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            HistaeTokens.lavender.withValues(alpha: 0.7),
          ],
        ).createShader(rect),
    );
    final rightThread = Path()
      ..moveTo(size.width + 10, size.height * 0.22)
      ..cubicTo(
        size.width * 0.85,
        size.height * 0.12,
        size.width * 0.83,
        size.height * 0.9,
        size.width * 0.66,
        size.height * 0.7,
      )
      ..quadraticBezierTo(
        size.width * 0.58,
        size.height * 0.64,
        center.dx,
        center.dy,
      );
    canvas.drawPath(
      rightThread,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            HistaeTokens.coral.withValues(alpha: 0.8),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
    canvas.drawCircle(
      center,
      50,
      Paint()
        ..shader = RadialGradient(
          colors: [
            HistaeTokens.lavender.withValues(alpha: 0.24),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: 50)),
    );
    canvas.drawCircle(
      center,
      8,
      Paint()..color = HistaeTokens.ink.withValues(alpha: 0.07),
    );
    canvas.drawCircle(center, 3.5, Paint()..color = const Color(0xfff2e4da));
  }

  @override
  bool shouldRepaint(_ConnectionPainter oldDelegate) =>
      framed != oldDelegate.framed;
}
