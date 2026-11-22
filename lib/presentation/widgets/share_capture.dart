import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/di/injection.dart';
import '../../core/l10n/app_l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/usecases/usecases.dart';

/// Shows [card] in a dialog and shares it as a PNG.
Future<void> showShareCard(BuildContext context, Widget card) {
  final key = GlobalKey();
  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        RepaintBoundary(key: key, child: card),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.share_rounded),
          label: Text(ctx.tr('share')),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final nav = Navigator.of(ctx);
            try {
              final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 3);
              final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
              await sl<ShareImage>()(bytes!.buffer.asUint8List());
              nav.pop();
            } catch (e) {
              messenger.showSnackBar(SnackBar(content: Text('$e')));
            }
          },
        ),
      ]),
    ),
  );
}

/// Branded frame used for share images.
class ShareFrame extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const ShareFrame({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        width: 340,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1024), Color(0xFF1C0D35)],
          ),
          border: Border.all(color: Neon.cyan.withValues(alpha: 0.4)),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Icon(Icons.bolt_rounded, color: Neon.cyan),
              const SizedBox(width: 4),
              Text('VoltPulse', style: AppTheme.digits(size: 16, color: Colors.white)),
              const Spacer(),
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
            const SizedBox(height: 18),
            ...children,
          ]),
        ),
      );
}

class ShareRow extends StatelessWidget {
  final String label;
  final String value;
  const ShareRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Text(label, style: const TextStyle(color: Colors.white60)),
          const Spacer(),
          Text(value, style: AppTheme.digits(size: 14, color: Colors.white)),
        ]),
      );
}
