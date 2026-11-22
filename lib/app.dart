import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/di/injection.dart';
import 'core/l10n/app_l10n.dart';
import 'core/theme/app_theme.dart';
import 'domain/entities/app_settings.dart';
import 'domain/repositories/repositories.dart';
import 'domain/usecases/charging_analytics.dart';
import 'domain/usecases/health_calculator.dart';
import 'domain/usecases/usage_analytics.dart';
import 'domain/usecases/usecases.dart';
import 'presentation/blocs/battery_bloc.dart';
import 'presentation/blocs/device_cubit.dart';
import 'presentation/blocs/health_cubit.dart';
import 'presentation/blocs/history_cubit.dart';
import 'presentation/blocs/settings_cubit.dart';
import 'presentation/screens/shell_screen.dart';

class VoltPulseApp extends StatelessWidget {
  const VoltPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => SettingsCubit(sl<LoadSettings>(), sl<SaveSettings>())..init()),
        BlocProvider(create: (_) => BatteryBloc(sl<WatchBattery>(), sl<WatchPowerEvents>())..add(const BatteryStarted())),
        BlocProvider(
          create: (_) => HistoryCubit(sl<LoadHistory>(), sl<ExportHistoryCsv>(), sl<HistoryRepository>(), sl<UsageAnalytics>(),
              sl<ChargingAnalytics>())
            ..load(),
        ),
        BlocProvider(create: (c) => HealthCubit(sl<HealthCalculator>(), c.read<BatteryBloc>(), c.read<HistoryCubit>())),
        BlocProvider(create: (_) => DeviceCubit(sl<GetDeviceInfo>())),
      ],
      child: const _PeriodicHistoryRefresh(child: _ThemedApp()),
    );
  }
}

class _ThemedApp extends StatelessWidget {
  const _ThemedApp();

  @override
  Widget build(BuildContext context) {
    final mode = context.select((SettingsCubit c) => c.state.themeMode);
    final lang = context.select((SettingsCubit c) => c.state.language);
    final dark = mode != AppThemeMode.light;
    SystemChrome.setSystemUIOverlayStyle(dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark);
    return MaterialApp(
      title: 'VoltPulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(mode),
      locale: Locale(lang.name),
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: const [
        AppL10nDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const ShellScreen(),
    );
  }
}

/// Reloads history every 2 minutes and when the app returns to the foreground.
class _PeriodicHistoryRefresh extends StatefulWidget {
  final Widget child;
  const _PeriodicHistoryRefresh({required this.child});

  @override
  State<_PeriodicHistoryRefresh> createState() => _PeriodicHistoryRefreshState();
}

class _PeriodicHistoryRefreshState extends State<_PeriodicHistoryRefresh> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (mounted) context.read<HistoryCubit>().load();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) context.read<HistoryCubit>().load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
