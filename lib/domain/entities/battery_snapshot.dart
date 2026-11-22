import 'package:equatable/equatable.dart';

enum ChargeStatus { charging, discharging, full, notCharging, unknown }

enum ChargerType { none, ac, usb, wireless, dock }

enum BatteryHealth { good, overheat, dead, overVoltage, failure, cold, unknown }

/// Live stats of the charging session in progress (tracked natively).
class ActiveSession extends Equatable {
  final String id;
  final DateTime start;
  final double startLevel;
  final double avgWatts;
  final double peakWatts;
  final double maxTempC;
  final ChargerType charger;

  const ActiveSession({
    required this.id,
    required this.start,
    required this.startLevel,
    required this.avgWatts,
    required this.peakWatts,
    required this.maxTempC,
    required this.charger,
  });

  Duration get elapsed => DateTime.now().difference(start);

  @override
  List<Object?> get props => [id, start, startLevel, avgWatts, peakWatts, maxTempC, charger];
}

class BatterySnapshot extends Equatable {
  final int level;
  final double percent;
  final ChargeStatus status;
  final ChargerType charger;
  final int voltageMv;

  /// Positive = into the battery (charging), negative = discharging.
  final double currentMa;
  final double temperatureC;
  final String technology;
  final BatteryHealth health;
  final double? chargeCounterMah;
  final double? fullCapacityMah;
  final double? designCapacityMah;
  final int? cycleCount;
  final Duration? systemChargeTimeRemaining;
  final bool screenOn;
  final DateTime timestamp;
  final ActiveSession? session;

  const BatterySnapshot({
    required this.level,
    required this.percent,
    required this.status,
    required this.charger,
    required this.voltageMv,
    required this.currentMa,
    required this.temperatureC,
    required this.technology,
    required this.health,
    required this.timestamp,
    this.chargeCounterMah,
    this.fullCapacityMah,
    this.designCapacityMah,
    this.cycleCount,
    this.systemChargeTimeRemaining,
    this.screenOn = true,
    this.session,
  });

  bool get isPluggedIn => charger != ChargerType.none;
  bool get isCharging => isPluggedIn && currentMa > 0 && status != ChargeStatus.full;
  bool get isFull => status == ChargeStatus.full || (isPluggedIn && level >= 100);
  double get voltage => voltageMv / 1000.0;
  double get currentA => currentMa / 1000.0;
  double get powerW => voltage * currentA.abs();

  @override
  List<Object?> get props => [
        level, percent, status, charger, voltageMv, currentMa, temperatureC, technology, health,
        chargeCounterMah, fullCapacityMah, designCapacityMah, cycleCount, systemChargeTimeRemaining,
        screenOn, timestamp, session,
      ];
}
