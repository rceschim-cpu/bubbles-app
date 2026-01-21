import 'package:flutter/material.dart';

class BubblesCLiteLogo extends StatelessWidget {
  final double size;
  final Color color;

  const BubblesCLiteLogo({
    super.key,
    this.size = 24,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _BubblesCLitePainter(color),
    );
  }
}

class _BubblesCLitePainter extends CustomPainter {
  final Color color;

  _BubblesCLitePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // ---- BOLHA (círculo externo)
    final Paint bubblePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..color = color.withOpacity(0.9)
      ..isAntiAlias = true;

    final Offset center = Offset(w / 2, h / 2);
    final double radius = w / 2 - bubblePaint.strokeWidth / 2;

    canvas.drawCircle(center, radius, bubblePaint);

    // ---- "B" ORGÂNICO (forma interna)
    final Paint innerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withOpacity(0.85)
      ..isAntiAlias = true;

    final Path bPath = Path();

    bPath.moveTo(w * 0.48, h * 0.18);
    bPath.cubicTo(
      w * 0.30, h * 0.20,
      w * 0.28, h * 0.42,
      w * 0.45, h * 0.46,
    );
    bPath.cubicTo(
      w * 0.65, h * 0.52,
      w * 0.60, h * 0.80,
      w * 0.40, h * 0.82,
    );
    bPath.cubicTo(
      w * 0.55, h * 0.78,
      w * 0.70, h * 0.62,
      w * 0.56, h * 0.48,
    );
    bPath.cubicTo(
      w * 0.70, h * 0.34,
      w * 0.60, h * 0.20,
      w * 0.48, h * 0.18,
    );
    bPath.close();

    canvas.drawPath(bPath, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}