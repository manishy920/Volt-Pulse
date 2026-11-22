import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../core/theme/app_theme.dart';

/// Rising liquid with two phase-shifted sine waves and bubbles.
class LiquidFill extends StatefulWidget {
  final double level; // 0..1
  final List<Color> colors;
  final bool animateRise;

  const LiquidFill({super.key, required this.level, this.colors = const [Neon.green, Neon.cyan], this.animateRise = true});

  @override
  State<LiquidFill> createState() => _LiquidFillState();
}

class _LiquidFillState extends State<LiquidFill> with TickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  late final AnimationController _rise = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..forward();

  @override
  void dispose() {
    _wave.dispose();
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([_wave, _rise]),
        builder: (context, _) {
          final rise = widget.animateRise ? Curves.easeOutCubic.transform(_rise.value) : 1.0;
          return CustomPaint(
            size: Size.infinite,
            painter: _LiquidPainter(level: widget.level * rise, phase: _wave.value, colors: widget.colors),
          );
        },
      );
}

class _LiquidPainter extends CustomPainter {
  final double level;
  final double phase;
  final List<Color> colors;
  _LiquidPainter({required this.level, required this.phase, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final baseY = size.height * (1 - level.clamp(0.0, 1.0));
    Path wave(double amp, double shift, double freq) {
      final p = Path()..moveTo(0, size.height);
      for (double x = 0; x <= size.width; x += 4) {
        final y = baseY + math.sin((x / size.width * freq * 2 * math.pi) + (phase * 2 * math.pi) + shift) * amp;
        p.lineTo(x, y);
      }
      return p
        ..lineTo(size.width, size.height)
        ..close();
    }

    final rect = Offset.zero & size;
    canvas.drawPath(
        wave(14, math.pi, 1.3),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.last.withValues(alpha: 0.25), colors.first.withValues(alpha: 0.08)],
          ).createShader(rect));
    canvas.drawPath(
        wave(10, 0, 1.0),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.first.withValues(alpha: 0.45), colors.last.withValues(alpha: 0.12)],
          ).createShader(rect));

    // bubbles
    final bubble = Paint()..color = Colors.white.withValues(alpha: 0.25);
    for (var i = 0; i < 14; i++) {
      final seed = i * 97.0;
      final x = (seed * 13) % size.width;
      final travel = size.height - baseY;
      if (travel <= 0) continue;
      final y = size.height - ((phase + i / 14) % 1.0) * travel;
      canvas.drawCircle(Offset(x + math.sin(phase * 6 + i) * 6, y), 2.0 + (i % 3), bubble);
    }
  }

  @override
  bool shouldRepaint(_LiquidPainter old) => true;
}

/// Glowing lightning bolt that pulses; [connected]=false plays a fade/shrink "discharge".
class LightningBolt extends StatefulWidget {
  final double size;
  final Color color;
  final bool connected;

  const LightningBolt({super.key, this.size = 120, this.color = Neon.green, this.connected = true});

  @override
  State<LightningBolt> createState() => _LightningBoltState();
}

class _LightningBoltState extends State<LightningBolt> with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);
  late final AnimationController _strike = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
    ..forward();

  @override
  void didUpdateWidget(LightningBolt old) {
    super.didUpdateWidget(old);
    if (old.connected != widget.connected) _strike.forward(from: 0);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _strike.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([_pulse, _strike]),
        builder: (context, _) {
          final strike = Curves.elasticOut.transform(_strike.value);
          final scale = widget.connected ? (0.4 + 0.6 * strike) * (1 + 0.06 * _pulse.value) : 1 - 0.6 * _strike.value;
          final opacity = widget.connected ? 1.0 : (1 - _strike.value).clamp(0.0, 1.0);
          return Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: CustomPaint(size: Size.square(widget.size), painter: _BoltPainter(widget.color, 0.5 + 0.5 * _pulse.value)),
            ),
          );
        },
      );
}

class _BoltPainter extends CustomPainter {
  final Color color;
  final double glow;
  _BoltPainter(this.color, this.glow);

  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(s.width * 0.58, 0)
      ..lineTo(s.width * 0.16, s.height * 0.58)
      ..lineTo(s.width * 0.46, s.height * 0.58)
      ..lineTo(s.width * 0.38, s.height)
      ..lineTo(s.width * 0.86, s.height * 0.38)
      ..lineTo(s.width * 0.54, s.height * 0.38)
      ..close();
    canvas.drawPath(
        p,
        Paint()
          ..color = color.withValues(alpha: 0.7 * glow)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18 + 10 * glow));
    canvas.drawPath(
        p,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, color],
          ).createShader(Offset.zero & s));
  }

  @override
  bool shouldRepaint(_BoltPainter old) => old.glow != glow || old.color != color;
}

/// Lottie energy-pulse rings (bundled asset) tinted to the accent color.
class EnergyPulse extends StatelessWidget {
  final double size;
  final Color color;
  const EnergyPulse({super.key, this.size = 360, this.color = Neon.green});

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(color, BlendMode.srcATop),
          child: Lottie.asset('assets/lottie/energy_pulse.json', repeat: true, fit: BoxFit.contain),
        ),
      );
}

/// Counter-rotating segmented neon rings ("cyber ring" theme).
class CyberRings extends StatefulWidget {
  final double size;
  final Color color;
  const CyberRings({super.key, this.size = 300, this.color = Neon.cyan});

  @override
  State<CyberRings> createState() => _CyberRingsState();
}

class _CyberRingsState extends State<CyberRings> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(size: Size.square(widget.size), painter: _RingsPainter(_c.value, widget.color)),
      );
}

class _RingsPainter extends CustomPainter {
  final double t;
  final Color color;
  _RingsPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var r = 0; r < 3; r++) {
      final radius = size.width / 2 - r * 26 - 6;
      final segments = 12 + r * 6;
      final dir = r.isEven ? 1 : -1;
      final rot = dir * t * 2 * math.pi * (1 + r * 0.4);
      final paint = Paint()
        ..color = (r == 1 ? Neon.purple : color).withValues(alpha: 0.8 - r * 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0 - r
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3);
      for (var i = 0; i < segments; i++) {
        final a = rot + i * 2 * math.pi / segments;
        canvas.drawArc(Rect.fromCircle(center: c, radius: radius), a, (2 * math.pi / segments) * 0.55, false, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.t != t;
}
