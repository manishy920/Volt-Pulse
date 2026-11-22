import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/di/injection.dart';
import '../../core/l10n/app_l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/repositories/repositories.dart';
import '../blocs/battery_bloc.dart';

/// Dim AMOLED clock for night charging. Moves slightly every minute to avoid burn-in.
class AlwaysOnScreen extends StatefulWidget {
  const AlwaysOnScreen({super.key});

  static Route<void> route() => PageRouteBuilder(
        pageBuilder: (_, _, _) => const AlwaysOnScreen(),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 800),
      );

  @override
  State<AlwaysOnScreen> createState() => _AlwaysOnScreenState();
}

class _AlwaysOnScreenState extends State<AlwaysOnScreen> {
  late Timer _timer;
  DateTime _now = DateTime.now();
  Alignment _pos = Alignment.center;
  final _rand = math.Random();
  final _repo = sl<BatteryRepository>();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _repo.setKeepScreenOn(true, brightness: 0.05).catchError((_) {});
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      setState(() {
        if (now.minute != _now.minute) {
          _pos = Alignment(_rand.nextDouble() * 0.6 - 0.3, _rand.nextDouble() * 0.8 - 0.4);
        }
        _now = now;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _repo.setKeepScreenOn(false).catchError((_) {});
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BatteryBloc>().state;
    final s = state.snapshot;
    final color = (s?.isCharging ?? false) ? Neon.green : Neon.cyan;
    return GestureDetector(
      onDoubleTap: () => Navigator.of(context).maybePop(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AnimatedAlign(
          alignment: _pos,
          duration: const Duration(seconds: 3),
          curve: Curves.easeInOut,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(DateFormat('HH:mm').format(_now),
                style: AppTheme.digits(size: 72, weight: FontWeight.w400, color: Colors.white.withValues(alpha: 0.75))),
            Text(DateFormat('EEE, d MMM').format(_now), style: const TextStyle(color: Colors.white38, fontSize: 16)),
            const SizedBox(height: 28),
            if (s != null) ...[
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(s.isPluggedIn ? Icons.bolt_rounded : Icons.battery_std_rounded, color: color.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                Text(Fmt.percent(s.percent), style: AppTheme.digits(size: 26, color: color.withValues(alpha: 0.8))),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                width: 180,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: s.percent / 100,
                    minHeight: 4,
                    backgroundColor: Colors.white10,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
              ),
              if (s.isPluggedIn) ...[
                const SizedBox(height: 8),
                Text(Fmt.watts(state.smoothedWatts), style: const TextStyle(color: Colors.white38)),
              ],
            ],
            const SizedBox(height: 40),
            Text(context.tr('aod_exit'), style: const TextStyle(color: Colors.white24, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}
