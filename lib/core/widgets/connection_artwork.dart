import 'package:flutter/material.dart';

import '../theme/histae_tokens.dart';

/// Vector interpretation of the site's two threads meeting in a point of light.
class ConnectionArtwork extends StatelessWidget {
  const ConnectionArtwork({super.key, this.height = 160});
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: HistaeTokens.panelGradient(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: const CustomPaint(painter: _ConnectionPainter()),
        ),
      ),
    ),
  );
}

class _ConnectionPainter extends CustomPainter {
  const _ConnectionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.52, size.height * 0.54);
    final rect = Offset.zero & size;
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
    final dots = Paint()..color = HistaeTokens.ink.withValues(alpha: 0.045);
    for (var x = 18.0; x < size.width; x += 19) {
      for (var y = 18.0; y < size.height; y += 19) {
        canvas.drawCircle(Offset(x, y), 0.6, dots);
      }
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
    final frame = RRect.fromRectAndRadius(
      rect.deflate(14),
      const Radius.circular(14),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = HistaeTokens.ink.withValues(alpha: 0.055),
    );
    canvas.drawLine(
      Offset(-10, size.height * 0.17),
      center,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            HistaeTokens.lavender.withValues(alpha: 0.7),
          ],
        ).createShader(rect),
    );
    canvas.drawLine(
      Offset(size.width + 10, size.height * 0.8),
      center,
      Paint()
        ..shader = LinearGradient(
          colors: [HistaeTokens.ink.withValues(alpha: 0.5), Colors.transparent],
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
  bool shouldRepaint(_ConnectionPainter oldDelegate) => false;
}
