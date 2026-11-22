import 'dart:typed_data';

import '../entities/app_settings.dart';
import '../entities/battery_snapshot.dart';
import '../entities/device_info.dart';
import '../entities/history.dart';
import '../entities/power_event.dart';
import '../repositories/repositories.dart';
import 'usage_analytics.dart';

class WatchBattery {
  final BatteryRepository repo;
  const WatchBattery(this.repo);
  Stream<BatterySnapshot> call() => repo.watchBattery();
}

class WatchPowerEvents {
  final BatteryRepository repo;
  const WatchPowerEvents(this.repo);
  Stream<PowerEvent> call() => repo.watchPowerEvents();
}

class LoadHistory {
  final HistoryRepository repo;
  const LoadHistory(this.repo);
  Future<HistoryBundle> call() => repo.load();
}

class ExportHistoryCsv {
  final HistoryRepository repo;
  final UsageAnalytics analytics;
  const ExportHistoryCsv(this.repo, this.analytics);

  Future<String> call(HistoryBundle bundle, {bool share = true}) {
    final stamp = DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-');
    return repo.saveCsv('voltpulse_$stamp.csv', analytics.toCsv(bundle), share: share);
  }
}

class ShareImage {
  final HistoryRepository repo;
  const ShareImage(this.repo);
  Future<void> call(Uint8List png) => repo.shareImage(png, 'voltpulse_${DateTime.now().millisecondsSinceEpoch}.png');
}

class LoadSettings {
  final SettingsRepository repo;
  const LoadSettings(this.repo);
  Future<AppSettings> call() => repo.load();
}

class SaveSettings {
  final SettingsRepository repo;
  const SaveSettings(this.repo);
  Future<void> call(AppSettings s) => repo.save(s);
}

class GetDeviceInfo {
  final DeviceRepository repo;
  const GetDeviceInfo(this.repo);
  Future<DeviceInfo> call() => repo.deviceInfo();
}
