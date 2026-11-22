import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/di/injection.dart';
import '../../core/l10n/app_l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/history.dart';
import '../../domain/entities/insights.dart';
import '../../domain/usecases/charging_analytics.dart';
import '../blocs/history_cubit.dart';
import '../blocs/settings_cubit.dart';
import '../widgets/glass_card.dart';
import '../widgets/labels.dart';
import '../widgets/section_title.dart';
import '../widgets/share_capture.dart';
import '../widgets/status_chip.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    context.read<HistoryCubit>().load();
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = context.tr('csv_saved');
    try {
      final path = await context.read<HistoryCubit>().exportCsv();
      messenger.showSnackBar(SnackBar(content: Text('$saved $path')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HistoryCubit>().state;
    return SafeArea(
      bottom: false,
      child: DefaultTabController(
        length: 3,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(children: [
              Expanded(child: Text(context.tr('nav_history'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
              IconButton(tooltip: context.tr('export_csv'), onPressed: _export, icon: const Icon(Icons.file_download_outlined)),
              IconButton(onPressed: () => context.read<HistoryCubit>().load(), icon: const Icon(Icons.refresh_rounded)),
            ]),
          ),
          TabBar(
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [Tab(text: context.tr('charts')), Tab(text: context.tr('sessions')), Tab(text: context.tr('chargers'))],
          ),
          Expanded(
            child: state.status == LoadStatus.loading || state.status == LoadStatus.initial
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => context.read<HistoryCubit>().load(),
                    child: TabBarView(children: [
                      _ChartsTab(state: state),
                      _SessionsTab(sessions: state.bundle.sessions),
                      _ChargersTab(chargers: state.chargers),
                    ]),
                  ),
          ),
        ]),
      ),
    );
  }
}

// ---------------- Charts ----------------

class _ChartsTab extends StatefulWidget {
  final HistoryState state;
  const _ChartsTab({required this.state});

  @override
  State<_ChartsTab> createState() => _ChartsTabState();
}

class _ChartsTabState extends State<_ChartsTab> {
  int _hours = 24;

  @override
  Widget build(BuildContext context) {
    final fmt = Fmt(context.watch<SettingsCubit>().state);
    final since = DateTime.now().subtract(Duration(hours: _hours));
    final points = widget.state.bundle.points.where((p) => p.time.isAfter(since)).toList();
    final habits = widget.state.habits;

    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
      Wrap(spacing: 8, children: [
        for (final h in const [6, 24, 168])
          ChoiceChip(
            label: Text(h == 168 ? '7d' : '${h}h'),
            selected: _hours == h,
            onSelected: (_) => setState(() => _hours = h),
          ),
      ]),
      const SizedBox(height: 12),
      GlassCard(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _legend(Neon.cyan, context.tr('battery_pct')),
            const SizedBox(width: 16),
            _legend(Neon.orange, '${context.tr('temperature')} (${fmt.tempUnit})'),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: points.length < 2
                ? Center(child: Text(context.tr('collecting_history'), textAlign: TextAlign.center))
                : _LevelTempChart(points: points, since: since, hours: _hours, fmt: fmt),
          ),
        ]),
      ).animate().fadeIn(),
      SectionTitle(context.tr('wear_tracker')),
      GlassCard(
        padding: const EdgeInsets.fromLTRB(4, 16, 12, 8),
        child: SizedBox(
          height: 180,
          child: widget.state.bundle.capacity.length < 2
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(context.tr('wear_collecting'), textAlign: TextAlign.center),
                  ),
                )
              : _CapacityChart(samples: widget.state.bundle.capacity),
        ),
      ),
      if (habits != null) ...[
        SectionTitle(context.tr('weekly_habits')),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(habits.summary),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _pill('${habits.sessions} ${context.tr('sessions').toLowerCase()}', Neon.cyan),
              _pill('${habits.fullCharges}× 100%', habits.fullCharges > 0 ? Neon.amber : Neon.green),
              _pill('${habits.deepDischarges}× ≤5%', habits.deepDischarges > 0 ? Neon.red : Neon.green),
              _pill('${context.tr('avg_end')} ${habits.avgEndLevel.toStringAsFixed(0)}%', Neon.purple),
            ]),
          ]),
        ),
      ],
    ]);
  }

  Widget _legend(Color c, String t) => Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(t, style: const TextStyle(fontSize: 12)),
      ]);

  Widget _pill(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
      );
}

class _LevelTempChart extends StatelessWidget {
  final List<HistoryPoint> points;
  final DateTime since;
  final int hours;
  final Fmt fmt;
  const _LevelTempChart({required this.points, required this.since, required this.hours, required this.fmt});

  // Temperature (15–55 °C) is mapped onto the 0–100 axis so both series share a chart.
  static double _t2y(double c) => ((c - 15) / 40 * 100).clamp(0, 100);
  static double _y2t(double y) => y / 100 * 40 + 15;

  @override
  Widget build(BuildContext context) {
    double x(DateTime t) => t.difference(since).inMinutes / 60;
    final muted = VoltPalette.of(context).textMuted;
    final level = points.map((p) => FlSpot(x(p.time), p.level)).toList();
    final temp = points.map((p) => FlSpot(x(p.time), _t2y(p.temperatureC))).toList();
    final interval = hours <= 6 ? 1.0 : (hours <= 24 ? 4.0 : 24.0);
    final style = TextStyle(fontSize: 10, color: muted);

    return LineChart(LineChartData(
      minX: 0,
      maxX: hours.toDouble(),
      minY: 0,
      maxY: 100,
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        drawVerticalLine: false,
        horizontalInterval: 25,
        getDrawingHorizontalLine: (_) => FlLine(color: muted.withValues(alpha: 0.12), strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 34,
            interval: 25,
            getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: style),
          ),
        ),
        rightTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 34,
            interval: 25,
            getTitlesWidget: (v, _) => Text(fmt.tempValue(_y2t(v)).toStringAsFixed(0), style: style.copyWith(color: Neon.orange)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            interval: interval,
            getTitlesWidget: (v, _) {
              final t = since.add(Duration(minutes: (v * 60).round()));
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(hours > 24 ? DateFormat('E').format(t) : DateFormat('HH:mm').format(t), style: style),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => Colors.black87,
          getTooltipItems: (spots) => spots
              .map((s) => LineTooltipItem(
                    s.barIndex == 0 ? '${s.y.toStringAsFixed(1)}%' : fmt.temp(_y2t(s.y)),
                    TextStyle(color: s.barIndex == 0 ? Neon.cyan : Neon.orange, fontWeight: FontWeight.w700),
                  ))
              .toList(),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: level,
          isCurved: true,
          preventCurveOverShooting: true,
          barWidth: 2.5,
          gradient: const LinearGradient(colors: [Neon.cyan, Neon.purple]),
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Neon.cyan.withValues(alpha: 0.3), Neon.cyan.withValues(alpha: 0)],
            ),
          ),
        ),
        LineChartBarData(
          spots: temp,
          isCurved: true,
          preventCurveOverShooting: true,
          barWidth: 2,
          color: Neon.orange,
          dashArray: const [6, 4],
          dotData: const FlDotData(show: false),
        ),
      ],
    ));
  }
}

class _CapacityChart extends StatelessWidget {
  final List<CapacitySample> samples;
  const _CapacityChart({required this.samples});

  @override
  Widget build(BuildContext context) {
    final first = samples.first.time;
    final spots = samples.map((s) => FlSpot(s.time.difference(first).inHours / 24, s.mah)).toList();
    final minY = samples.map((s) => s.mah).reduce((a, b) => a < b ? a : b) * 0.95;
    final maxY = samples.map((s) => s.mah).reduce((a, b) => a > b ? a : b) * 1.03;
    final style = TextStyle(fontSize: 10, color: VoltPalette.of(context).textMuted);
    return LineChart(LineChartData(
      minY: minY,
      maxY: maxY,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            interval: (maxY - minY) / 3,
            getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0), style: style),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            interval: (spots.last.x / 4).clamp(1, 1000),
            getTitlesWidget: (v, _) => Text(DateFormat('d MMM').format(first.add(Duration(hours: (v * 24).round()))), style: style),
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Neon.green,
          barWidth: 2.5,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(show: true, color: Neon.green.withValues(alpha: 0.12)),
        ),
      ],
    ));
  }
}

// ---------------- Sessions ----------------

class _SessionsTab extends StatelessWidget {
  final List<ChargingSession> sessions;
  const _SessionsTab({required this.sessions});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 120),
        Center(child: Text(context.tr('no_sessions'), textAlign: TextAlign.center)),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _SessionCard(session: sessions[i])
          .animate(delay: (30 * i.clamp(0, 10)).ms)
          .fadeIn()
          .slideX(begin: 0.05),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final ChargingSession session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final s = session;
    final fmt = Fmt(context.watch<SettingsCubit>().state);
    final rating = sl<ChargingAnalytics>().rateCharger(s.avgWatts);
    final muted = VoltPalette.of(context).textMuted;
    return GlassCard(
      onTap: () => _openDetails(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(chargerIcon(s.charger), color: Neon.cyan, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(s.label ?? chargerLabel(context, s.charger), style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
          ),
          Badge2(ratingLabel(context, rating), ratingColor(rating)),
        ]),
        const SizedBox(height: 4),
        Text('${Fmt.dateTime(s.start)} · ${Fmt.duration(s.duration)}', style: TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 12),
        Row(children: [
          Text('${s.startLevel.toStringAsFixed(0)}%', style: AppTheme.digits(size: 16)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Stack(children: [
                Container(height: 6, decoration: BoxDecoration(color: muted.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6))),
                FractionallySizedBox(
                  widthFactor: (s.endLevel / 100).clamp(0, 1),
                  child: Container(
                    height: 6,
                    margin: EdgeInsets.zero,
                    decoration: BoxDecoration(gradient: Neon.charging, borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ]),
            ),
          ),
          Text('${s.endLevel.toStringAsFixed(0)}%', style: AppTheme.digits(size: 16, color: Neon.green)),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _kv(context, context.tr('avg'), Fmt.watts(s.avgWatts)),
          _kv(context, context.tr('peak'), Fmt.watts(s.peakWatts)),
          _kv(context, context.tr('max_temp'), fmt.temp(s.maxTempC)),
        ]),
      ]),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: TextStyle(color: VoltPalette.of(context).textMuted, fontSize: 11)),
        Text(v, style: AppTheme.digits(size: 13)),
      ]);

  void _openDetails(BuildContext context) {
    final cubit = context.read<HistoryCubit>();
    final fmt = Fmt(context.read<SettingsCubit>().state);
    final controller = TextEditingController(text: session.label ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(ctx.tr('charger_test'), style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(ctx.tr('charger_test_hint'), style: TextStyle(color: VoltPalette.of(ctx).textMuted)),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: ctx.tr('charger_name'),
              hintText: ctx.tr('charger_name_hint'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(ctx.tr('share')),
                onPressed: () {
                  Navigator.pop(ctx);
                  showShareCard(context, _SessionShareCard(session: session, fmt: fmt));
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  cubit.labelSession(session.id, controller.text.trim());
                  Navigator.pop(ctx);
                },
                child: Text(ctx.tr('save')),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _SessionShareCard extends StatelessWidget {
  final ChargingSession session;
  final Fmt fmt;
  const _SessionShareCard({required this.session, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final rating = sl<ChargingAnalytics>().rateCharger(session.avgWatts);
    return ShareFrame(title: context.tr('charging_session'), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${session.startLevel.toStringAsFixed(0)}% → ${session.endLevel.toStringAsFixed(0)}%',
            style: AppTheme.digits(size: 28, color: Neon.green)),
      ]),
      const SizedBox(height: 6),
      Badge2(ratingLabel(context, rating), ratingColor(rating)),
      const SizedBox(height: 12),
      ShareRow(context.tr('charger'), session.label ?? chargerLabel(context, session.charger)),
      ShareRow(context.tr('duration'), Fmt.duration(session.duration)),
      ShareRow(context.tr('avg'), Fmt.watts(session.avgWatts)),
      ShareRow(context.tr('peak'), Fmt.watts(session.peakWatts)),
      ShareRow(context.tr('max_temp'), fmt.temp(session.maxTempC)),
    ]);
  }
}

// ---------------- Chargers ----------------

class _ChargersTab extends StatelessWidget {
  final List<ChargerComparison> chargers;
  const _ChargersTab({required this.chargers});

  @override
  Widget build(BuildContext context) {
    final best = chargers.isEmpty ? 1.0 : chargers.first.avgWatts.clamp(1, 1000).toDouble();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
      GlassCard(
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, color: Neon.cyan),
          const SizedBox(width: 10),
          Expanded(child: Text(context.tr('chargers_hint'))),
        ]),
      ),
      const SizedBox(height: 12),
      if (chargers.isEmpty) Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(context.tr('no_sessions')))),
      for (final c in chargers)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                Badge2(ratingLabel(context, c.rating), ratingColor(c.rating)),
              ]),
              const SizedBox(height: 10),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: c.avgWatts / best),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(8),
                  color: ratingColor(c.rating),
                  backgroundColor: ratingColor(c.rating).withValues(alpha: 0.12),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${context.tr('avg')} ${Fmt.watts(c.avgWatts)} · ${context.tr('peak')} ${Fmt.watts(c.peakWatts)} · ${c.sessions} ${context.tr('sessions').toLowerCase()}',
                style: TextStyle(color: VoltPalette.of(context).textMuted, fontSize: 12),
              ),
            ]),
          ),
        ),
    ]);
  }
}
