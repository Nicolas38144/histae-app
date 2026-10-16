import 'package:flutter/material.dart';

class EditorialDivider extends StatelessWidget {
  const EditorialDivider({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          const Expanded(child: Divider(height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: CustomPaint(
              size: const Size(12, 20),
              painter: _SparklePainter(Theme.of(context).colorScheme.primary),
            ),
          ),
          const Expanded(child: Divider(height: 1)),
        ],
      ),
    ),
  );
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w / 2, 0)
      ..quadraticBezierTo(w / 2, h / 2, w, h / 2)
      ..quadraticBezierTo(w / 2, h / 2, w / 2, h)
      ..quadraticBezierTo(w / 2, h / 2, 0, h / 2)
      ..quadraticBezierTo(w / 2, h / 2, w / 2, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => color != oldDelegate.color;
}

class EditorialCard extends StatelessWidget {
  const EditorialCard({
    super.key,
    required this.title,
    required this.body,
    this.eyebrow,
  });
  final String title;
  final String body;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (eyebrow != null) ...[
            Text(
              eyebrow!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 22),
          ],
          Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          const EditorialDivider(),
          Text(body, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    ),
  );
}
