import 'dart:typed_data';

import '../../domain/entities/app_settings.dart';
import '../../domain/entities/battery_snapshot.dart';
import '../../domain/entities/device_info.dart';
import '../../domain/entities/history.dart';
import '../../domain/entities/power_event.dart';
import '../../domain/repositories/repositories.dart';
import '../datasources/battery_native_datasource.dart';
import '../datasources/settings_local_datasource.dart';
import '../models/mappers.dart';

class BatteryRepositoryImpl implements BatteryRepository {
  final BatteryNativeDataSource native;
  BatteryRepositoryImpl(this.native);

  @override
  Stream<BatterySnapshot> watchBattery() => native.batteryStream().map(BatteryMapper.snapshot);

  @override
  Stream<PowerEvent> watchPowerEvents() => native.powerStream().map(BatteryMapper.powerEvent);

  @override
  Future<BatterySnapshot?> currentSnapshot() async {
    final m = await native.snapshot();
    return m == null ? null : BatteryMapper.snapshot(m);
  }

  @override
  Future<void> playPlugFeedback({required bool connected}) => native.playFeedback(connected);

  @override
  Future<void> stopAlarm() => native.stopAlarm();

  @override
  Future<void> setKeepScreenOn(bool on, {double? brightness}) => native.setKeepScreenOn(on, brightness);

  @override
  Future<bool> requestNotificationPermission() => native.requestNotificationPermission();
}

class HistoryRepositoryImpl implements HistoryRepository {
  final BatteryNativeDataSource native;
  HistoryRepositoryImpl(this.native);

  @override
  Future<HistoryBundle> load() async {
    final results = await Future.wait([native.history(), native.sessions(), native.capacity()]);
    return HistoryBundle(
      points: results[0].map(BatteryMapper.point).toList(),
      sessions: results[1].map(BatteryMapper.session).toList()..sort((a, b) => b.start.compareTo(a.start)),
      capacity: results[2].map(BatteryMapper.capacity).toList(),
    );
  }

  @override
  Future<void> labelSession(String id, String? label) => native.labelSession(id, label);

  @override
  Future<void> clear() => native.clearHistory();

  @override
  Future<String> saveCsv(String fileName, String content, {bool share = false}) =>
      native.saveCsv(fileName, content, share);

  @override
  Future<void> shareImage(Uint8List png, String fileName) => native.shareImage(png, fileName);
}

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDataSource local;
  final BatteryNativeDataSource native;
  SettingsRepositoryImpl(this.local, this.native);

  @override
  Future<AppSettings> load() async {
    final s = local.read();
    await _sync(s);
    return s;
  }

  @override
  Future<void> save(AppSettings s) async {
    await local.write(s);
    await _sync(s);
  }

  /// Native side runs the alarms and the live notification, so it needs its own copy.
  Future<void> _sync(AppSettings s) => native.updateSettings({
        'chargeAlarmEnabled': s.chargeAlarmEnabled,
        'chargeAlarmLevel': s.chargeAlarmLevel,
        'fullAlarmEnabled': s.fullAlarmEnabled,
        'overheatEnabled': s.overheatEnabled,
        'overheatThresholdC': s.overheatThresholdC,
        'liveNotification': s.liveNotification,
        'soundEnabled': s.soundEnabled,
        'hapticsEnabled': s.hapticsEnabled,
        'fahrenheit': s.tempUnit == TempUnit.fahrenheit,
      });
}

class DeviceRepositoryImpl implements DeviceRepository {
  final BatteryNativeDataSource native;
  DeviceRepositoryImpl(this.native);

  @override
  Future<DeviceInfo> deviceInfo() async => BatteryMapper.device(await native.deviceInfo() ?? const {});
}
