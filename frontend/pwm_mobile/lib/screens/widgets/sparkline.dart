import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

/// The little trend line on each My Hours metric card.
///
/// Hand-painted rather than drawn with `fl_chart`, which is what the desktop
/// uses: this has no axes, no labels, no tooltip and no interaction — it is a
/// shape, not a chart — and a charting package for one polyline would be a
/// dependency the mobile app does not otherwise need.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.width = 56,
    this.height = 26,
  });

  /// One point per day of the period, oldest first.
  final List<double> values;

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          colour: AppColors.accent,
          // A flat run still has to read as a line rather than as nothing.
          flatColour: AppColors.fieldBorder,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.colour,
    required this.flatColour,
  });

  final List<double> values;
  final Color colour;
  final Color flatColour;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final highest = values.reduce((a, b) => a > b ? a : b);
    final lowest = values.reduce((a, b) => a < b ? a : b);
    final span = highest - lowest;

    // Every day the same (a flat week, or none at all): a mid-height rule, so
    // the card does not look broken.
    if (span == 0) {
      final paint = Paint()
        ..color = flatColour
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
      return;
    }

    // Inset by the stroke so the peaks are not clipped by the box.
    const inset = 2.0;
    final usableHeight = size.height - inset * 2;
    final step = values.length == 1
        ? 0.0
        : size.width / (values.length - 1);

    final path = Path();

    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? size.width / 2 : step * i;
      // Canvas y grows downward, so the tallest value sits at the smallest y.
      final y = inset + (1 - (values[i] - lowest) / span) * usableHeight;

      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = colour
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.colour != colour ||
      old.flatColour != flatColour ||
      !identical(old.values, values);
}
