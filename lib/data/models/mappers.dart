import '../../domain/entities/battery_snapshot.dart';
import '../../domain/entities/device_info.dart';
import '../../domain/entities/history.dart';
import '../../domain/entities/power_event.dart';

/// Converts platform-channel maps into domain entities.
class BatteryMapper {
  static double _d(Object? v, [double fallback = 0]) => v is num ? v.toDouble() : fallback;
  static double? _dn(Object? v) => v is num ? v.toDouble() : null;
  static int _i(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;
  static DateTime _t(Object? v) => DateTime.fromMillisecondsSinceEpoch(_i(v, DateTime.now().millisecondsSinceEpoch));

  static ChargerType charger(Object? v) => switch (v) {
        'ac' => ChargerType.ac,
        'usb' => ChargerType.usb,
        'wireless' => ChargerType.wireless,
        'dock' => ChargerType.dock,
        _ => ChargerType.none,
      };

  static ChargeStatus status(Object? v) => switch (v) {
        'charging' => ChargeStatus.charging,
        'discharging' => ChargeStatus.discharging,
        'full' => ChargeStatus.full,
        'not_charging' => ChargeStatus.notCharging,
        _ => ChargeStatus.unknown,
      };

  static BatteryHealth health(Object? v) => switch (v) {
        'good' => BatteryHealth.good,
        'overheat' => BatteryHealth.overheat,
        'dead' => BatteryHealth.dead,
        'over_voltage' => BatteryHealth.overVoltage,
        'failure' => BatteryHealth.failure,
        'cold' => BatteryHealth.cold,
        _ => BatteryHealth.unknown,
      };

  static BatterySnapshot snapshot(Map<Object?, Object?> m) {
    final sess = m['session'];
    final remaining = _dn(m['chargeTimeRemainingMs']);
    return BatterySnapshot(
      level: _i(m['level']),
      percent: _d(m['percent'], _d(m['level'])),
      status: status(m['status']),
      charger: charger(m['charger']),
      voltageMv: _i(m['voltageMv']),
      currentMa: _d(m['currentMa']),
      temperatureC: _d(m['temperatureC']),
      technology: (m['technology'] as String?) ?? 'Unknown',
      health: health(m['health']),
      chargeCounterMah: _dn(m['chargeCounterMah']),
      fullCapacityMah: _dn(m['fullCapacityMah']),
      designCapacityMah: _dn(m['designCapacityMah']),
      cycleCount: m['cycleCount'] is num ? (m['cycleCount'] as num).toInt() : null,
      systemChargeTimeRemaining: remaining == null ? null : Duration(milliseconds: remaining.toInt()),
      screenOn: m['screenOn'] as bool? ?? true,
      timestamp: _t(m['timestamp']),
      session: sess is Map
          ? ActiveSession(
              id: '${sess['id']}',
              start: _t(sess['start']),
              startLevel: _d(sess['startLevel']),
              avgWatts: _d(sess['avgW']),
              peakWatts: _d(sess['peakW']),
              maxTempC: _d(sess['maxTemp']),
              charger: charger(sess['charger']),
            )
          : null,
    );
  }

  static PowerEvent powerEvent(Map<Object?, Object?> m) => PowerEvent(
        type: m['type'] == 'connected' ? PowerEventType.connected : PowerEventType.disconnected,
        charger: charger(m['charger']),
        timestamp: _t(m['timestamp']),
      );

  static HistoryPoint point(Map<Object?, Object?> m) => HistoryPoint(
        time: _t(m['t']),
        level: _d(m['level']),
        temperatureC: _d(m['temp']),
        currentMa: _i(m['currentMa']),
        charging: m['charging'] as bool? ?? false,
        screenOn: m['screenOn'] as bool? ?? false,
      );

  static ChargingSession session(Map<Object?, Object?> m) => ChargingSession(
        id: '${m['id']}',
        start: _t(m['start']),
        end: _t(m['end']),
        startLevel: _d(m['startLevel']),
        endLevel: _d(m['endLevel']),
        avgWatts: _d(m['avgW']),
        peakWatts: _d(m['peakW']),
        maxTempC: _d(m['maxTemp']),
        charger: charger(m['charger']),
        label: m['label'] as String?,
      );

  static CapacitySample capacity(Map<Object?, Object?> m) => CapacitySample(_t(m['t']), _d(m['mah']));

  static DeviceInfo device(Map<Object?, Object?> m) => DeviceInfo(
        manufacturer: '${m['manufacturer'] ?? ''}',
        model: '${m['model'] ?? ''}',
        androidVersion: '${m['androidVersion'] ?? ''}',
        sdkInt: _i(m['sdkInt']),
        processor: '${m['processor'] ?? ''}',
        cores: _i(m['cores']),
        abi: '${m['abi'] ?? ''}',
        totalRam: _i(m['totalRam']),
        availRam: _i(m['availRam']),
        totalStorage: _i(m['totalStorage']),
        freeStorage: _i(m['freeStorage']),
        uptime: Duration(milliseconds: _i(m['uptimeMs'])),
        network: '${m['network'] ?? ''}',
      );
}
