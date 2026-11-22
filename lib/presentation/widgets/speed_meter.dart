import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Animated semicircular speedometer for charging watts (0 – [maxWatts]).
/// Colored zones: slow (<10 W), fast (10–25 W), super fast (>25 W).
class SpeedMeter extends StatelessWidget {
  final double watts;
  final double maxWatts;
  final double width;

  const SpeedMeter({super.key, required this.watts, this.maxWatts = 45, this.width = 260});

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: watts.clamp(0, maxWatts)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      builder: (context, w, _) => SizedBox(
        width: width,
        height: width * 0.62,
        child: CustomPaint(
          painter: _MeterPainter(value: w / maxWatts, max: maxWatts, fg: fg),
          child: Align(
            alignment: const Alignment(0, 0.75),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(w.toStringAsFixed(1), style: AppTheme.digits(size: width * 0.13, color: fg)),
              Text('WATTS', style: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 11, letterSpacing: 3)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MeterPainter extends CustomPainter {
  final double value;
  final double max;
  final Color fg;
  _MeterPainter({required this.value, required this.max, required this.fg});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.92);
    final radius = size.width / 2 - 14;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = math.pi;
    const sweep = math.pi;
    final stroke = size.width * 0.05;

    void zone(double from, double to, Color c) => canvas.drawArc(
        rect, start + sweep * from / max, sweep * (to - from) / max, false,
        Paint()
          ..color = c.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);
    zone(0, 10, Neon.amber);
    zone(10, 25, Neon.green);
    zone(25, max, Neon.purple);

    final active = Paint()
      ..shader = const SweepGradient(
        startAngle: math.pi,
        endAngle: math.pi * 2,
        colors: [Neon.amber, Neon.green, Neon.cyan, Neon.purple],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep * value.clamp(0.0, 1.0), false, active);

    // labels
    for (final w in [0, 10, 25, max.round()]) {
      final a = start + sweep * w / max;
      final p = center + Offset(math.cos(a), math.sin(a)) * (radius - stroke * 1.9);
      final tp = TextPainter(
        text: TextSpan(text: '$w', style: TextStyle(color: fg.withValues(alpha: 0.55), fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }

    // needle
    final a = start + sweep * value.clamp(0.0, 1.0);
    final tip = center + Offset(math.cos(a), math.sin(a)) * (radius - stroke);
    canvas.drawLine(center, tip,
        Paint()
          ..color = fg
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(center, 7, Paint()..color = fg);
    canvas.drawCircle(center, 3, Paint()..color = Neon.cyan);
  }

  @override
  bool shouldRepaint(_MeterPainter old) => old.value != value || old.fg != fg;
}
