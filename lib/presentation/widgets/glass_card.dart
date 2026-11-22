import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Frosted-glass card with a subtle gradient border.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? glow;
  final VoidCallback? onTap;

  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 22, this.glow, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = VoltPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: glow == null ? null : [BoxShadow(color: glow!.withValues(alpha: 0.25), blurRadius: 24, spreadRadius: -6)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [p.glass, p.glass.withValues(alpha: p.glass.a * 0.4)],
                  ),
                  border: Border.all(color: (glow ?? p.glassBorder).withValues(alpha: glow == null ? p.glassBorder.a : 0.45)),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
