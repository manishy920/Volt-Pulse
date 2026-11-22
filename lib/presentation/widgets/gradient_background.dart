import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Themed background with two slowly drifting neon blobs.
class GradientBackground extends StatefulWidget {
  final Widget child;
  final Color accent;

  const GradientBackground({super.key, required this.child, this.accent = Neon.cyan});

  @override
  State<GradientBackground> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends State<GradientBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = VoltPalette.of(context);
    final light = Theme.of(context).brightness == Brightness.light;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: p.background),
      ),
      child: Stack(children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value * 2 * math.pi;
            return Stack(children: [
              _blob(Alignment(-0.8 + 0.3 * math.sin(t), -0.7 + 0.2 * math.cos(t)), widget.accent, light),
              _blob(Alignment(0.9 - 0.25 * math.cos(t), 0.6 + 0.25 * math.sin(t)), Neon.purple, light),
            ]);
          },
        ),
        widget.child,
      ]),
    );
  }

  Widget _blob(Alignment a, Color c, bool light) => Align(
        alignment: a,
        child: IgnorePointer(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [c.withValues(alpha: light ? 0.18 : 0.22), c.withValues(alpha: 0)]),
            ),
          ),
        ),
      );
}
