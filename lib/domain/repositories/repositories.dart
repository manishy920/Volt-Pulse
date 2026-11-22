import 'dart:typed_data';

import '../entities/app_settings.dart';
import '../entities/battery_snapshot.dart';
import '../entities/device_info.dart';
import '../entities/history.dart';
import '../entities/power_event.dart';

abstract class BatteryRepository {
  Stream<BatterySnapshot> watchBattery();
  Stream<PowerEvent> watchPowerEvents();
  Future<BatterySnapshot?> currentSnapshot();
  Future<void> playPlugFeedback({required bool connected});
  Future<void> stopAlarm();
  Future<void> setKeepScreenOn(bool on, {double? brightness});
  Future<bool> requestNotificationPermission();
}

abstract class HistoryRepository {
  Future<HistoryBundle> load();
  Future<void> labelSession(String id, String? label);
  Future<void> clear();
  Future<String> saveCsv(String fileName, String content, {bool share = false});
  Future<void> shareImage(Uint8List png, String fileName);
}

abstract class SettingsRepository {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

abstract class DeviceRepository {
  Future<DeviceInfo> deviceInfo();
}
