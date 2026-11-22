import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/l10n/app_l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/battery_snapshot.dart';
import '../../domain/entities/insights.dart';
import '../../domain/usecases/charging_analytics.dart';
import '../blocs/battery_bloc.dart';
import '../blocs/health_cubit.dart';
import '../blocs/history_cubit.dart';
import '../blocs/settings_cubit.dart';
import '../widgets/glass_card.dart';
import '../widgets/labels.dart';
import '../widgets/section_title.dart';
import '../widgets/share_capture.dart';

class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final report = context.watch<HealthCubit>().state;
    final s = context.select((BatteryBloc b) => b.state.snapshot);
    final history = context.watch<HistoryCubit>().state;
    final settings = context.watch<SettingsCubit>().state;
    final fmt = Fmt(settings);

    return SafeArea(
      bottom: false,
      child: report == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
              Row(children: [
                Expanded(child: Text(context.tr('nav_health'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
                IconButton(
                  tooltip: context.tr('share'),
                  icon: const Icon(Icons.ios_share_rounded),
                  onPressed: () => showShareCard(context, _HealthShareCard(report: report, snapshot: s, fmt: fmt)),
                ),
              ]),
              const SizedBox(height: 8),
              _ScoreCard(report: report),
              SectionTitle(context.tr('temperature')),
              if (s != null) _TemperatureCard(snapshot: s, report: report, fmt: fmt, threshold: settings.overheatThresholdC),
              SectionTitle(context.tr('score_breakdown')),
              GlassCard(
                child: Column(children: [
                  for (final f in report.factors) _FactorRow(factor: f),
                ]),
              ),
              if (s != null) ...[
                SectionTitle(context.tr('capacity')),
                _CapacityCard(snapshot: s, report: report),
              ],
              SectionTitle(context.tr('usage')),
              _UsageCard(drain: history.drain, snapshot: s),
              if (history.habits != null) ...[
                SectionTitle(context.tr('weekly_habits')),
                GlassCard(
                  child: Row(children: [
                    const Icon(Icons.insights_rounded, color: Neon.purple, size: 30),
                    const SizedBox(width: 12),
                    Expanded(child: Text(history.habits!.summary)),
                  ]),
                ),
              ],
              SectionTitle(context.tr('advice')),
              for (final a in report.advice) _TipTile(icon: Icons.auto_awesome_rounded, color: Neon.cyan, text: context.tr(a)),
              SectionTitle(context.tr('saver_tips')),
              for (final t in _saverTips(s, history.drain)) _TipTile(icon: Icons.eco_rounded, color: Neon.green, text: context.tr(t)),
              SectionTitle(context.tr('tips')),
              for (final t in const ['tip_heat', 'tip_20_80', 'tip_overnight', 'tip_fast', 'tip_storage'])
                _TipTile(icon: Icons.lightbulb_rounded, color: Neon.amber, text: context.tr(t)),
            ]),
    );
  }

  /// Heuristic battery-saver tips from what the data shows is draining power.
  List<String> _saverTips(BatterySnapshot? s, DrainStats d) {
    final tips = <String>[];
    if ((d.activePerHour ?? 0) > 15) tips.add('saver_active_high');
    if ((d.idlePerHour ?? 0) > 2) tips.add('saver_idle_high');
    if (s != null && s.temperatureC >= 38 && !s.isPluggedIn) tips.add('saver_hot');
    if (s != null && s.currentMa < -800) tips.add('saver_current_high');
    tips.add('saver_dark_mode');
    return tips;
  }
}

class _ScoreCard extends StatelessWidget {
  final HealthReport report;
  const _ScoreCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final color = healthStatusColor(report.status);
    return GlassCard(
      glow: color,
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        SizedBox.square(
          dimension: 120,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: report.score / 100),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Stack(fit: StackFit.expand, children: [
              CircularProgressIndicator(
                value: v,
                strokeWidth: 10,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: color.withValues(alpha: 0.12),
              ),
              Center(child: Text('${(v * 100).round()}', style: AppTheme.digits(size: 34, color: color))),
            ]),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('health_score'), style: TextStyle(color: VoltPalette.of(context).textMuted)),
            const SizedBox(height: 4),
            Text(context.tr('hs_${report.status.name}'), style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(context.tr('health_estimate_note'), style: TextStyle(color: VoltPalette.of(context).textMuted, fontSize: 12)),
          ]),
        ),
      ]),
    ).animate().fadeIn().slideY(begin: 0.1);
  }
}

class _TemperatureCard extends StatelessWidget {
  final BatterySnapshot snapshot;
  final HealthReport report;
  final Fmt fmt;
  final double threshold;
  const _TemperatureCard({required this.snapshot, required this.report, required this.fmt, required this.threshold});

  @override
  Widget build(BuildContext context) {
    final t = snapshot.temperatureC;
    final (key, color) = t >= threshold
        ? ('temp_hot', Neon.red)
        : t >= 37
            ? ('temp_warm', Neon.orange)
            : t < 5
                ? ('temp_cold', Neon.cyan)
                : ('temp_normal', Neon.green);
    return GlassCard(
      glow: t >= threshold ? Neon.red : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.thermostat_rounded, color: color, size: 32),
          const SizedBox(width: 8),
          Text(fmt.temp(t), style: AppTheme.digits(size: 26, color: color)),
          const Spacer(),
          Text(context.tr(key), style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 8,
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Neon.cyan, Neon.green, Neon.amber, Neon.red])),
            child: Align(
              alignment: Alignment(((t - 15) / 35).clamp(0.0, 1.0) * 2 - 1, 0),
              child: Container(width: 4, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${context.tr('avg')}: ${fmt.temp(report.avgTempC)}   ·   ${context.tr('max')}: ${fmt.temp(report.maxTempC)}   ·   '
          '${context.tr('time_hot')}: ${(report.hotFraction * 100).toStringAsFixed(0)}%',
          style: TextStyle(color: VoltPalette.of(context).textMuted, fontSize: 12),
        ),
        if (t >= threshold) ...[
          const SizedBox(height: 8),
          Text(context.tr(snapshot.isPluggedIn ? 'overheat_tip_charging' : 'overheat_tip'), style: const TextStyle(color: Neon.red)),
        ],
      ]),
    );
  }
}

class _FactorRow extends StatelessWidget {
  final HealthFactor factor;
  const _FactorRow({required this.factor});

  @override
  Widget build(BuildContext context) {
    final color = factor.score >= 0.8 ? Neon.green : (factor.score >= 0.55 ? Neon.amber : Neon.red);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(context.tr(factor.key), style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(factor.detail, style: TextStyle(color: VoltPalette.of(context).textMuted, fontSize: 12)),
        ]),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: factor.score),
          duration: const Duration(milliseconds: 900),
          builder: (context, v, _) => LinearProgressIndicator(
            value: v,
            minHeight: 6,
            borderRadius: BorderRadius.circular(6),
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
        ),
      ]),
    );
  }
}

class _CapacityCard extends StatelessWidget {
  final BatterySnapshot snapshot;
  final HealthReport report;
  const _CapacityCard({required this.snapshot, required this.report});

  @override
  Widget build(BuildContext context) {
    final muted = VoltPalette.of(context).textMuted;
    return GlassCard(
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('design'), style: TextStyle(color: muted, fontSize: 12)),
            Text(snapshot.designCapacityMah != null ? '${snapshot.designCapacityMah!.round()} mAh' : '--', style: AppTheme.digits(size: 18)),
          ]),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('current_capacity'), style: TextStyle(color: muted, fontSize: 12)),
            Text(snapshot.fullCapacityMah != null ? '${snapshot.fullCapacityMah!.round()} mAh' : '--', style: AppTheme.digits(size: 18)),
          ]),
        ),
        if (report.capacityRatio != null)
          Text('${(report.capacityRatio! * 100).toStringAsFixed(0)}%',
              style: AppTheme.digits(size: 22, color: report.capacityRatio! >= 0.8 ? Neon.green : Neon.amber)),
      ]),
    );
  }
}

class _UsageCard extends StatelessWidget {
  final DrainStats drain;
  final BatterySnapshot? snapshot;
  const _UsageCard({required this.drain, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final muted = VoltPalette.of(context).textMuted;
    String rate(double? v) => v == null ? context.tr('collecting') : '${v.toStringAsFixed(1)}%/h';
    final remaining = snapshot == null ? null : sl<ChargingAnalytics>().dischargeRemaining(snapshot!, drainPerHour: drain.activePerHour);
    Widget cell(String label, String value, Color c) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: muted, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: AppTheme.digits(size: 15, color: c)),
          ]),
        );
    return GlassCard(
      child: Column(children: [
        Row(children: [
          cell(context.tr('drain_active'), rate(drain.activePerHour), Neon.purple),
          cell(context.tr('drain_idle'), rate(drain.idlePerHour), Neon.cyan),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          cell(context.tr('remaining'), snapshot?.isPluggedIn ?? false ? context.tr('charging_now') : Fmt.duration(remaining), Neon.green),
          cell(context.tr('screen_on_since_unplug'), Fmt.duration(drain.screenOnSinceUnplug), Neon.amber),
        ]),
      ]),
    );
  }
}

class _TipTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _TipTile({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ]),
        ),
      );
}

class _HealthShareCard extends StatelessWidget {
  final HealthReport report;
  final BatterySnapshot? snapshot;
  final Fmt fmt;
  const _HealthShareCard({required this.report, required this.snapshot, required this.fmt});

  @override
  Widget build(BuildContext context) => ShareFrame(title: context.tr('health_report'), children: [
        Row(children: [
          Text('${report.score}', style: AppTheme.digits(size: 54, color: healthStatusColor(report.status))),
          const SizedBox(width: 12),
          Text(context.tr('hs_${report.status.name}'), style: TextStyle(color: healthStatusColor(report.status), fontSize: 20, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        if (report.capacityRatio != null) ShareRow(context.tr('factor_capacity'), '${(report.capacityRatio! * 100).toStringAsFixed(0)}%'),
        ShareRow(context.tr('avg'), fmt.temp(report.avgTempC)),
        if (snapshot?.cycleCount != null) ShareRow(context.tr('cycle_count'), '${snapshot!.cycleCount}'),
        if (snapshot != null) ShareRow(context.tr('technology'), snapshot!.technology),
      ]);
}
