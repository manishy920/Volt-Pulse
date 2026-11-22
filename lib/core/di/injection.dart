import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/battery_native_datasource.dart';
import '../../data/datasources/settings_local_datasource.dart';
import '../../data/repositories/repositories_impl.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/usecases/charging_analytics.dart';
import '../../domain/usecases/health_calculator.dart';
import '../../domain/usecases/usage_analytics.dart';
import '../../domain/usecases/usecases.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  final prefs = await SharedPreferences.getInstance();

  // data
  sl
    ..registerLazySingleton(BatteryNativeDataSource.new)
    ..registerLazySingleton(() => SettingsLocalDataSource(prefs))
    ..registerLazySingleton<BatteryRepository>(() => BatteryRepositoryImpl(sl()))
    ..registerLazySingleton<HistoryRepository>(() => HistoryRepositoryImpl(sl()))
    ..registerLazySingleton<SettingsRepository>(() => SettingsRepositoryImpl(sl(), sl()))
    ..registerLazySingleton<DeviceRepository>(() => DeviceRepositoryImpl(sl()))
    // domain
    ..registerLazySingleton(() => const ChargingAnalytics())
    ..registerLazySingleton(() => const HealthCalculator())
    ..registerLazySingleton(() => const UsageAnalytics())
    ..registerLazySingleton(() => WatchBattery(sl()))
    ..registerLazySingleton(() => WatchPowerEvents(sl()))
    ..registerLazySingleton(() => LoadHistory(sl()))
    ..registerLazySingleton(() => ExportHistoryCsv(sl(), sl()))
    ..registerLazySingleton(() => ShareImage(sl()))
    ..registerLazySingleton(() => LoadSettings(sl()))
    ..registerLazySingleton(() => SaveSettings(sl()))
    ..registerLazySingleton(() => GetDeviceInfo(sl()));
}
