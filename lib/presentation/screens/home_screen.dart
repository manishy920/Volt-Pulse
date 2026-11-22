import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/l10n/app_l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/battery_snapshot.dart';
import '../../domain/usecases/charging_analytics.dart';
import '../blocs/battery_bloc.dart';
import '../blocs/history_cubit.dart';
import '../blocs/settings_cubit.dart';
import '../widgets/battery_gauge.dart';
import '../widgets/glass_card.dart';
import '../widgets/labels.dart';
import '../widgets/section_title.dart';
import '../widgets/stat_tile.dart';
import '../widgets/status_chip.dart';
import 'always_on_screen.dart';
import 'charging_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BatteryBloc>().state;
    final settings = context.watch<SettingsCubit>().state;
    final history = context.watch<HistoryCubit>().state;
    final s = state.snapshot;
    final fmt = Fmt(settings);
    final analytics = sl<ChargingAnalytics>();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(slivers: [
        SliverAppBar(
          floating: true,
          title: Row(children: [
            const Icon(Icons.bolt_rounded, color: Neon.cyan),
            const SizedBox(width: 6),
            Text('VoltPulse', style: AppTheme.digits(size: 20, color: Theme.of(context).colorScheme.onSurface)),
          ]),
          actions: [
            IconButton(
              tooltip: context.tr('always_on'),
              icon: const Icon(Icons.nightlight_round),
              onPressed: () => Navigator.of(context).push(AlwaysOnScreen.route()),
            ),
            IconButton(
              tooltip: context.tr('settings'),
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ],
        ),
        if (s == null)
          SliverFillRemaining(
            child: Center(
              child: state.error != null
                  ? Padding(padding: const EdgeInsets.all(24), child: Text('${context.tr('native_error')}\n${state.error}', textAlign: TextAlign.center))
                  : const CircularProgressIndicator(),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList.list(children: [
              _Hero(snapshot: s, hot: s.temperatureC >= settings.overheatThresholdC),
              const SizedBox(height: 16),
              Center(child: _Estimate(snapshot: s, drainPerHour: history.drain.activePerHour)),
              if (s.temperatureC >= settings.overheatThresholdC) ...[
                const SizedBox(height: 16),
                _Warning(
                  icon: Icons.local_fire_department_rounded,
                  color: Neon.red,
                  title: '${context.tr('overheat_title')} · ${fmt.temp(s.temperatureC)}',
                  body: context.tr(s.isPluggedIn ? 'overheat_tip_charging' : 'overheat_tip'),
                ),
              ],
              if (analytics.slowChargeBaseline(s, history.bundle.sessions) case final best?) ...[
                const SizedBox(height: 16),
                _Warning(
                  icon: Icons.cable_rounded,
                  color: Neon.amber,
                  title: context.tr('slow_charge_title'),
                  body: context.tr('slow_charge_body').replaceAll('{best}', Fmt.watts(best)),
                ),
              ],
              SectionTitle(context.tr('live_stats')),
              StatGrid(children: [
                StatTile(icon: Icons.electric_bolt_rounded, label: context.tr('voltage'), value: Fmt.volts(s.voltage), color: Neon.cyan),
                StatTile(
                  icon: Icons.swap_vert_rounded,
                  label: context.tr('current'),
                  value: fmt.current(s.currentMa),
                  color: s.currentMa >= 0 ? Neon.green : Neon.purple,
                  hint: context.tr(s.currentMa >= 0 ? 'into_battery' : 'out_of_battery'),
                ),
                StatTile(icon: Icons.flash_on_rounded, label: context.tr('power'), value: Fmt.watts(state.smoothedWatts), color: Neon.amber),
                StatTile(
                  icon: Icons.thermostat_rounded,
                  label: context.tr('temperature'),
                  value: fmt.temp(s.temperatureC),
                  color: s.temperatureC >= settings.overheatThresholdC ? Neon.red : (s.temperatureC >= 37 ? Neon.orange : Neon.green),
                ),
                StatTile(icon: Icons.science_rounded, label: context.tr('technology'), value: s.technology, color: Neon.purple),
                StatTile(
                  icon: Icons.health_and_safety_rounded,
                  label: context.tr('health'),
                  value: healthLabel(context, s.health),
                  color: s.health == BatteryHealth.good ? Neon.green : Neon.red,
                ),
                StatTile(
                  icon: Icons.battery_charging_full_rounded,
                  label: context.tr('capacity'),
                  value: s.fullCapacityMah != null ? '${s.fullCapacityMah!.round()} mAh' : '--',
                  hint: s.designCapacityMah != null ? '${context.tr('design')}: ${s.designCapacityMah!.round()} mAh' : null,
                  color: Neon.cyan,
                ),
                StatTile(
                  icon: Icons.loop_rounded,
                  label: context.tr('cycle_count'),
                  value: s.cycleCount?.toString() ?? context.tr('not_available'),
                  color: Neon.lime,
                ),
              ]),
              SectionTitle(context.tr('power_trail')),
              _PowerSparkline(trail: state.powerTrail, charging: s.isCharging),
            ]),
          ),
      ]),
    );
  }
}

class _Hero extends StatelessWidget {
  final BatterySnapshot snapshot;
  final bool hot;
  const _Hero({required this.snapshot, required this.hot});

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    final color = hot ? Neon.red : (s.isFull ? Neon.lime : (s.isCharging ? Neon.green : Neon.cyan));
    return Column(children: [
      GestureDetector(
        onTap: s.isPluggedIn ? () => Navigator.of(context).push(ChargingScreen.route()) : null,
        child: Hero(
          tag: 'battery-gauge',
          child: BatteryGauge(
            percent: s.percent,
            charging: s.isCharging,
            hot: hot,
            size: MediaQuery.sizeOf(context).width.clamp(0, 420) * 0.72,
            label: s.isPluggedIn ? chargerLabel(context, s.charger).toUpperCase() : context.tr('battery').toUpperCase(),
          ),
        ),
      ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.92, 0.92), curve: Curves.easeOutBack),
      const SizedBox(height: 12),
      StatusChip(label: s.statusLabel(context), color: color, icon: s.statusIcon, pulse: s.isCharging),
    ]);
  }
}

class _Estimate extends StatelessWidget {
  final BatterySnapshot snapshot;
  final double? drainPerHour;
  const _Estimate({required this.snapshot, this.drainPerHour});

  @override
  Widget build(BuildContext context) {
    final a = sl<ChargingAnalytics>();
    final muted = VoltPalette.of(context).textMuted;
    final style = TextStyle(color: muted, fontSize: 14);
    if (snapshot.isPluggedIn) {
      if (snapshot.isFull) return Text(context.tr('full_unplug'), style: style);
      final full = a.timeToLevel(snapshot, 100);
      final to80 = a.timeToLevel(snapshot, 80);
      return Text(
        '${context.tr('full_in')} ${Fmt.duration(full)}'
        '${snapshot.percent < 80 ? '  ·  80% ${context.tr('in')} ${Fmt.duration(to80)}' : ''}',
        style: style,
      );
    }
    final left = a.dischargeRemaining(snapshot, drainPerHour: drainPerHour);
    return Text(
      left == null ? context.tr('estimating') : context.tr('remaining_usage').replaceAll('{t}', Fmt.duration(left)),
      style: style,
    );
  }
}

class _Warning extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _Warning({required this.icon, required this.color, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => GlassCard(
        glow: color,
        child: Row(children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(body, style: TextStyle(color: VoltPalette.of(context).textMuted, fontSize: 13)),
            ]),
          ),
        ]),
      ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 2.seconds, color: color.withValues(alpha: 0.2));
}

class _PowerSparkline extends StatelessWidget {
  final List<double> trail;
  final bool charging;
  const _PowerSparkline({required this.trail, required this.charging});

  @override
  Widget build(BuildContext context) {
    final color = charging ? Neon.green : Neon.cyan;
    final spots = [for (var i = 0; i < trail.length; i++) FlSpot(i.toDouble(), trail[i])];
    final maxY = trail.isEmpty ? 5.0 : (trail.reduce((a, b) => a > b ? a : b) * 1.25).clamp(1.0, 200.0);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      child: SizedBox(
        height: 120,
        child: spots.length < 2
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : LineChart(
                duration: Duration.zero,
                LineChartData(
                  minX: 0,
                  maxX: 89,
                  minY: 0,
                  maxY: maxY,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  lineTouchData: const LineTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    bottomTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        interval: maxY / 2,
                        getTitlesWidget: (v, meta) => Text('${v.toStringAsFixed(0)}W', style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
