import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/l10n/app_l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/battery_snapshot.dart';
import '../../domain/usecases/charging_analytics.dart';
import '../blocs/battery_bloc.dart';
import '../blocs/history_cubit.dart';
import '../blocs/settings_cubit.dart';
import '../widgets/battery_gauge.dart';
import '../widgets/charging_effects.dart';
import '../widgets/glass_card.dart';
import '../widgets/labels.dart';
import '../widgets/speed_meter.dart';
import '../widgets/status_chip.dart';
import 'always_on_screen.dart';

/// Full-screen charging experience shown when the cable is plugged in.
class ChargingScreen extends StatefulWidget {
  const ChargingScreen({super.key});

  static bool isOpen = false;

  static Route<void> route() => PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 650),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) => const ChargingScreen(),
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: a,
          child: ScaleTransition(scale: Tween(begin: 1.08, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
        ),
      );

  @override
  State<ChargingScreen> createState() => _ChargingScreenState();
}

class _ChargingScreenState extends State<ChargingScreen> {
  bool _unplugged = false;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    ChargingScreen.isOpen = true;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    ChargingScreen.isOpen = false;
    _closeTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onBattery(BuildContext context, BatteryState s) {
    final plugged = s.snapshot?.isPluggedIn ?? false;
    if (!plugged && !_unplugged) {
      setState(() => _unplugged = true);
      _closeTimer = Timer(const Duration(milliseconds: 1700), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    } else if (plugged && _unplugged) {
      _closeTimer?.cancel();
      setState(() => _unplugged = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BatteryBloc>().state;
    final settings = context.watch<SettingsCubit>().state;
    final sessions = context.select((HistoryCubit c) => c.state.bundle.sessions);
    final s = state.snapshot;
    if (s == null) return const Scaffold(backgroundColor: Colors.black);

    final hot = s.temperatureC >= settings.overheatThresholdC;
    final accent = _unplugged ? Neon.red : (hot ? Neon.red : Neon.green);
    final gradient = _unplugged ? Neon.hot : (hot ? Neon.hot : Neon.charging);
    final theme = settings.animationTheme;
    final analytics = sl<ChargingAnalytics>();
    final watts = state.smoothedWatts;
    final speed = analytics.classifySpeed(watts);
    final fmt = Fmt(settings);
    final slowBaseline = analytics.slowChargeBaseline(s, sessions);

    return BlocListener<BatteryBloc, BatteryState>(
      listener: _onBattery,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          // Background
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.3),
                  radius: 1.2,
                  colors: [accent.withValues(alpha: 0.18), Colors.black],
                ),
              ),
            ),
          ),
          if (theme == AnimationTheme.lightning || theme == AnimationTheme.liquid)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _unplugged ? 0.25 : 1,
                duration: const Duration(milliseconds: 600),
                child: LiquidFill(level: s.percent / 100, colors: gradient.colors),
              ),
            ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(children: [
                Row(children: [
                  IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close_rounded, color: Colors.white)),
                  const Spacer(),
                  StatusChip(
                    label: _unplugged ? context.tr('unplugged') : chargerLabel(context, s.charger),
                    icon: _unplugged ? Icons.power_off_rounded : chargerIcon(s.charger),
                    color: accent,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: context.tr('always_on'),
                    onPressed: () => Navigator.of(context).push(AlwaysOnScreen.route()),
                    icon: const Icon(Icons.nightlight_round, color: Colors.white),
                  ),
                ]),
                const SizedBox(height: 8),
                _Centerpiece(snapshot: s, theme: theme, accent: accent, unplugged: _unplugged, hot: hot),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _unplugged
                      ? Text(context.tr('unplugged_msg'), key: const ValueKey('u'),
                          style: const TextStyle(color: Colors.white70, fontSize: 16))
                      : Text(s.isFull ? context.tr('full_unplug') : s.statusLabel(context), key: ValueKey(s.isFull),
                          style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1)),
                ),
                if (!_unplugged) ...[
                  const SizedBox(height: 20),
                  Theme(
                    data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(onSurface: Colors.white)),
                    child: Column(children: [
                      Badge2(speedLabel(context, speed).toUpperCase(), speedColor(speed))
                          .animate(key: ValueKey(speed))
                          .scale(duration: 400.ms, curve: Curves.elasticOut),
                      const SizedBox(height: 8),
                      SpeedMeter(watts: watts, width: MediaQuery.sizeOf(context).width.clamp(0, 420) * 0.75),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _LiveValue(label: context.tr('voltage'), value: Fmt.volts(s.voltage), color: Neon.cyan)),
                    const SizedBox(width: 10),
                    Expanded(child: _LiveValue(label: context.tr('current'), value: fmt.current(s.currentMa), color: Neon.green)),
                    const SizedBox(width: 10),
                    Expanded(child: _LiveValue(label: context.tr('power'), value: Fmt.watts(watts), color: Neon.amber)),
                  ]),
                  const SizedBox(height: 12),
                  _DarkCard(children: [
                    _Row(context.tr('time_to_full'), s.isFull ? '✓' : Fmt.duration(analytics.timeToLevel(s, 100))),
                    _Row(context.tr('time_to_80'), s.percent >= 80 ? '✓' : Fmt.duration(analytics.timeToLevel(s, 80))),
                    _Row(context.tr('temperature'), fmt.temp(s.temperatureC), color: hot ? Neon.red : null),
                  ]),
                  if (s.session case final sess?) ...[
                    const SizedBox(height: 12),
                    _DarkCard(children: [
                      _Row(context.tr('session'), '${Fmt.time(sess.start)} · ${Fmt.duration(sess.elapsed)}'),
                      _Row(context.tr('gained'), '+${(s.percent - sess.startLevel).clamp(0, 100).toStringAsFixed(1)}%'),
                      _Row(context.tr('avg_peak'), '${Fmt.watts(sess.avgWatts)} / ${Fmt.watts(sess.peakWatts)}'),
                      _Row(context.tr('charger_rating'), ratingLabel(context, analytics.rateCharger(sess.avgWatts)),
                          color: ratingColor(analytics.rateCharger(sess.avgWatts))),
                    ]),
                  ],
                  if (slowBaseline != null) ...[
                    const SizedBox(height: 12),
                    GlassCard(
                      glow: Neon.amber,
                      child: Row(children: [
                        const Icon(Icons.cable_rounded, color: Neon.amber),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(context.tr('slow_charge_body').replaceAll('{best}', Fmt.watts(slowBaseline)),
                              style: const TextStyle(color: Colors.white70)),
                        ),
                      ]),
                    ),
                  ],
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Centerpiece extends StatelessWidget {
  final BatterySnapshot snapshot;
  final AnimationTheme theme;
  final Color accent;
  final bool unplugged;
  final bool hot;

  const _Centerpiece({required this.snapshot, required this.theme, required this.accent, required this.unplugged, required this.hot});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context).width.clamp(0, 420) * 0.85;
    return SizedBox.square(
      dimension: size,
      child: Stack(alignment: Alignment.center, children: [
        if (theme == AnimationTheme.lightning && !unplugged) EnergyPulse(size: size, color: accent),
        if (theme == AnimationTheme.cyberRing) CyberRings(size: size, color: accent),
        Hero(
          tag: 'battery-gauge',
          child: Theme(
            data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(onSurface: Colors.white)),
            child: BatteryGauge(
              percent: snapshot.percent,
              charging: !unplugged && snapshot.isCharging,
              hot: hot || unplugged,
              size: theme == AnimationTheme.cyberRing ? size * 0.62 : size * 0.78,
            ),
          ),
        ),
        if (theme == AnimationTheme.lightning || theme == AnimationTheme.liquid)
          Align(
            alignment: const Alignment(0, -0.36),
            child: LightningBolt(size: size * 0.11, color: accent, connected: !unplugged),
          ),
      ]),
    );
  }
}

class _LiveValue extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _LiveValue({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 6),
          FittedBox(child: Text(value, style: AppTheme.digits(size: 15, color: color))),
        ]),
      );
}

class _DarkCard extends StatelessWidget {
  final List<Widget> children;
  const _DarkCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(children: children),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Row(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Text(label, style: const TextStyle(color: Colors.white60)),
          const Spacer(),
          Text(value, style: AppTheme.digits(size: 14, color: color ?? Colors.white)),
        ]),
      );
}

/// Short "unplugged" animation shown when the cable is removed and the charging screen is not open.
class DisconnectFlash extends StatefulWidget {
  const DisconnectFlash({super.key});

  static Route<void> route() => PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        pageBuilder: (_, _, _) => const DisconnectFlash(),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      );

  @override
  State<DisconnectFlash> createState() => _DisconnectFlashState();
}

class _DisconnectFlashState extends State<DisconnectFlash> {
  bool _out = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 150), () => mounted ? setState(() => _out = true) : null);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pct = context.select((BatteryBloc b) => b.state.snapshot?.percent ?? 0);
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            LightningBolt(size: 110, color: Neon.red, connected: !_out),
            const SizedBox(height: 16),
            Text(context.tr('unplugged'), style: AppTheme.digits(size: 22, color: Colors.white)),
            const SizedBox(height: 6),
            Text(Fmt.percent(pct), style: const TextStyle(color: Colors.white70, fontSize: 16)),
          ]).animate().scale(begin: const Offset(1.2, 1.2), duration: 350.ms, curve: Curves.easeOut).fadeIn(),
        ),
      ),
    );
  }
}
