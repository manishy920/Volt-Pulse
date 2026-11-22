import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Large animated circular gauge with a glowing gradient arc and a decimal percentage.
class BatteryGauge extends StatefulWidget {
  final double percent;
  final bool charging;
  final bool hot;
  final double size;
  final String label;

  const BatteryGauge({super.key, required this.percent, required this.charging, required this.hot, this.size = 260, this.label = ''});

  @override
  State<BatteryGauge> createState() => _BatteryGaugeState();
}

class _BatteryGaugeState extends State<BatteryGauge> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = Neon.forState(charging: widget.charging, hot: widget.hot);
    final textColor = Theme.of(context).colorScheme.onSurface;
    return SizedBox.square(
      dimension: widget.size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: widget.percent),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => AnimatedBuilder(
          animation: _spin,
          builder: (context, _) => CustomPaint(
            painter: _GaugePainter(
              value: value / 100,
              colors: gradient.colors,
              spin: widget.charging ? _spin.value : null,
              track: textColor.withValues(alpha: 0.08),
            ),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                FittedBox(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: widget.size * 0.14),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                      Text(value.toStringAsFixed(2), style: AppTheme.digits(size: widget.size * 0.17, color: textColor)),
                      Padding(
                        padding: EdgeInsets.only(bottom: widget.size * 0.03, left: 2),
                        child: Text('%', style: AppTheme.digits(size: widget.size * 0.07, color: gradient.colors.first)),
                      ),
                    ]),
                  ),
                ),
                if (widget.label.isNotEmpty)
                  Text(widget.label,
                      style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: widget.size * 0.05, letterSpacing: 2)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final List<Color> colors;
  final double? spin;
  final Color track;

  _GaugePainter({required this.value, required this.colors, required this.spin, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = size.width * 0.07;
    final radius = size.width / 2 - stroke;
    const start = math.pi * 0.75;
    const sweepMax = math.pi * 1.5;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // tick marks
    final tick = Paint()
      ..color = track.withValues(alpha: track.a * 2.5)
      ..strokeWidth = 2;
    for (var i = 0; i <= 40; i++) {
      final a = start + sweepMax * i / 40;
      final inner = radius - stroke * (i % 5 == 0 ? 1.4 : 1.0);
      final outer = radius - stroke * 0.75;
      canvas.drawLine(center + Offset(math.cos(a), math.sin(a)) * inner, center + Offset(math.cos(a), math.sin(a)) * outer, tick);
    }

    canvas.drawArc(rect, start, sweepMax, false,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round);

    if (value <= 0) return;
    final sweep = sweepMax * value.clamp(0.0, 1.0);
    final shader = SweepGradient(
      startAngle: start,
      endAngle: start + sweepMax,
      colors: colors,
      transform: const GradientRotation(0),
    ).createShader(rect);

    // glow
    canvas.drawArc(rect, start, sweep, false,
        Paint()
          ..shader = shader
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 1.6
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    canvas.drawArc(rect, start, sweep, false,
        Paint()
          ..shader = shader
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round);

    // energy dot running along the arc while charging
    if (spin != null) {
      final a = start + sweep * spin!;
      final p = center + Offset(math.cos(a), math.sin(a)) * radius;
      canvas.drawCircle(p, stroke * 0.55,
          Paint()
            ..color = Colors.white
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawCircle(p, stroke * 0.28, Paint()..color = Colors.white);
    }

    // end cap knob
    final endA = start + sweep;
    canvas.drawCircle(center + Offset(math.cos(endA), math.sin(endA)) * radius, stroke * 0.32, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.value != value || old.spin != spin || old.colors != colors || old.track != track;
}
