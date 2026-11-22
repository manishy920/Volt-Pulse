import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/l10n/app_l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../blocs/battery_bloc.dart';
import '../blocs/device_cubit.dart';
import '../blocs/history_cubit.dart';
import '../widgets/glass_card.dart';
import '../widgets/section_title.dart';

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  late final DeviceCubit _cubit = context.read<DeviceCubit>();

  @override
  void initState() {
    super.initState();
    _cubit.startPolling();
  }

  @override
  void dispose() {
    _cubit.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DeviceCubit>().state;
    final s = context.select((BatteryBloc b) => b.state.snapshot);
    final drain = context.select((HistoryCubit c) => c.state.drain);
    if (d == null) return const Center(child: CircularProgressIndicator());

    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        Text(context.tr('nav_device'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        GlassCard(
          glow: Neon.purple,
          child: Row(children: [
            const Icon(Icons.phone_android_rounded, size: 44, color: Neon.purple),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${d.manufacturer} ${d.model}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text('Android ${d.androidVersion} (API ${d.sdkInt})', style: TextStyle(color: VoltPalette.of(context).textMuted)),
              ]),
            ),
          ]),
        ).animate().fadeIn().slideY(begin: 0.1),
        SectionTitle(context.tr('hardware')),
        _InfoCard(rows: [
          (context.tr('processor'), d.processor),
          (context.tr('cores'), '${d.cores}'),
          ('ABI', d.abi),
        ]),
        SectionTitle(context.tr('memory')),
        GlassCard(
          child: Column(children: [
            _UsageBar(label: 'RAM', used: d.totalRam - d.availRam, total: d.totalRam, color: Neon.cyan),
            const SizedBox(height: 16),
            _UsageBar(label: context.tr('storage'), used: d.totalStorage - d.freeStorage, total: d.totalStorage, color: Neon.purple),
          ]),
        ),
        if (s != null) ...[
          SectionTitle(context.tr('battery')),
          _InfoCard(rows: [
            (context.tr('technology'), s.technology),
            (context.tr('design'), s.designCapacityMah != null ? '${s.designCapacityMah!.round()} mAh' : context.tr('not_available')),
            (context.tr('current_capacity'), s.fullCapacityMah != null ? '${s.fullCapacityMah!.round()} mAh' : context.tr('collecting')),
            (context.tr('cycle_count'), s.cycleCount?.toString() ?? context.tr('not_available')),
          ]),
        ],
        SectionTitle(context.tr('system')),
        _InfoCard(rows: [
          (context.tr('network'), d.network),
          (context.tr('uptime'), Fmt.duration(d.uptime)),
          (context.tr('screen_on_since_unplug'), Fmt.duration(drain.screenOnSinceUnplug)),
        ]),
        const SizedBox(height: 8),
        Text(context.tr('screen_on_note'), style: TextStyle(color: VoltPalette.of(context).textMuted, fontSize: 11)),
      ]),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<(String, String)> rows;
  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Text(rows[i].$1, style: TextStyle(color: VoltPalette.of(context).textMuted)),
                const SizedBox(width: 12),
                Expanded(child: Text(rows[i].$2, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600))),
              ]),
            ),
            if (i < rows.length - 1) Divider(height: 1, color: VoltPalette.of(context).glassBorder),
          ],
        ]),
      );
}

class _UsageBar extends StatelessWidget {
  final String label;
  final int used;
  final int total;
  final Color color;
  const _UsageBar({required this.label, required this.used, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final frac = total == 0 ? 0.0 : used / total;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const Spacer(),
        Text('${Fmt.bytes(used)} / ${Fmt.bytes(total)}', style: AppTheme.digits(size: 12)),
      ]),
      const SizedBox(height: 8),
      TweenAnimationBuilder<double>(
        tween: Tween(end: frac),
        duration: const Duration(milliseconds: 700),
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: 10,
          borderRadius: BorderRadius.circular(8),
          color: frac > 0.85 ? Neon.red : color,
          backgroundColor: color.withValues(alpha: 0.12),
        ),
      ),
    ]);
  }
}
