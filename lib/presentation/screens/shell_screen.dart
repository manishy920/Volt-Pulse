import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/l10n/app_l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/power_event.dart';
import '../../domain/repositories/repositories.dart';
import '../blocs/battery_bloc.dart';
import '../blocs/history_cubit.dart';
import '../blocs/settings_cubit.dart';
import '../widgets/gradient_background.dart';
import 'charging_screen.dart';
import 'device_screen.dart';
import 'health_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => sl<BatteryRepository>().requestNotificationPermission().catchError((_) => false));
  }

  void _onPowerEvent(BuildContext context, PowerEvent e) {
    final settings = context.read<SettingsCubit>().state;
    sl<BatteryRepository>().playPlugFeedback(connected: e.connected).catchError((_) {});
    if (settings.hapticsEnabled) HapticFeedback.heavyImpact();

    final nav = Navigator.of(context);
    if (e.connected) {
      if (settings.showOverlayOnPlug && !ChargingScreen.isOpen) nav.push(ChargingScreen.route());
    } else {
      if (!ChargingScreen.isOpen) nav.push(DisconnectFlash.route());
      Future.delayed(const Duration(seconds: 2), () {
        if (context.mounted) context.read<HistoryCubit>().load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final snap = context.select((BatteryBloc b) => b.state.snapshot);
    final threshold = context.select((SettingsCubit c) => c.state.overheatThresholdC);
    final accent = Neon.accent(charging: snap?.isCharging ?? false, hot: (snap?.temperatureC ?? 0) >= threshold);

    final pages = const [HomeScreen(), HealthScreen(), HistoryScreen(), DeviceScreen()];
    return BlocListener<BatteryBloc, BatteryState>(
      listenWhen: (a, b) => b.lastPowerEvent != null && a.lastPowerEvent != b.lastPowerEvent,
      listener: (context, s) => _onPowerEvent(context, s.lastPowerEvent!),
      child: GradientBackground(
        accent: accent,
        child: Scaffold(
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(a), child: child),
            ),
            child: KeyedSubtree(key: ValueKey(_index), child: pages[_index]),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) {
              HapticFeedback.selectionClick();
              setState(() => _index = i);
            },
            destinations: [
              NavigationDestination(icon: const Icon(Icons.bolt_outlined), selectedIcon: const Icon(Icons.bolt_rounded), label: context.tr('nav_home')),
              NavigationDestination(icon: const Icon(Icons.favorite_outline_rounded), selectedIcon: const Icon(Icons.favorite_rounded), label: context.tr('nav_health')),
              NavigationDestination(icon: const Icon(Icons.show_chart_rounded), label: context.tr('nav_history')),
              NavigationDestination(icon: const Icon(Icons.phone_android_outlined), selectedIcon: const Icon(Icons.phone_android_rounded), label: context.tr('nav_device')),
            ],
          ),
        ),
      ),
    );
  }
}
