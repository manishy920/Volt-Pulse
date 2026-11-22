import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_theme.dart';
import 'glass_card.dart';

class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? hint;

  const StatTile({super.key, required this.icon, required this.label, required this.value, this.color = Neon.cyan, this.hint});

  @override
  Widget build(BuildContext context) {
    final muted = VoltPalette.of(context).textMuted;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(color: muted, fontSize: 12), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(value, key: ValueKey(value), style: AppTheme.digits(size: 18, color: Theme.of(context).colorScheme.onSurface)),
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(hint!, style: TextStyle(color: muted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ]),
    );
  }
}

/// Grid that adapts columns to the available width.
class StatGrid extends StatelessWidget {
  final List<Widget> children;
  const StatGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth > 900 ? 4 : (c.maxWidth > 560 ? 3 : 2);
        const gap = 12.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < children.length; i++)
              SizedBox(width: w, child: children[i])
                  .animate(delay: (40 * i).ms)
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.15, curve: Curves.easeOutCubic),
          ],
        );
      });
}
