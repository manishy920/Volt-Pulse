import '../entities/battery_snapshot.dart';
import '../entities/history.dart';
import '../entities/insights.dart';

/// Pure charging maths: speed class, charger rating, time estimates, slow-charge detection.
class ChargingAnalytics {
  const ChargingAnalytics();

  static const slowMaxW = 10.0;
  static const fastMaxW = 25.0;

  ChargingSpeed classifySpeed(double watts) {
    if (watts < slowMaxW) return ChargingSpeed.slow;
    if (watts <= fastMaxW) return ChargingSpeed.fast;
    return ChargingSpeed.superFast;
  }

  ChargerRating rateCharger(double avgWatts) {
    if (avgWatts < 7.5) return ChargerRating.weak;
    if (avgWatts < 18) return ChargerRating.good;
    return ChargerRating.excellent;
  }

  /// Time until [target]% while charging. Uses remaining mAh / current; the last 20% is
  /// slowed down to model the constant-voltage (taper) phase of Li-ion charging.
  Duration? timeToLevel(BatterySnapshot s, double target) {
    if (!s.isPluggedIn) return null;
    if (s.percent >= target) return Duration.zero;
    if (target >= 100 && s.systemChargeTimeRemaining != null) return s.systemChargeTimeRemaining;
    if (s.currentMa <= 20) return null;
    final full = s.fullCapacityMah ?? s.designCapacityMah;
    if (full == null) return null;

    double hours = 0;
    final current = s.currentMa;
    final bulkEnd = target.clamp(0, 80).toDouble();
    if (s.percent < bulkEnd) {
      hours += (bulkEnd - s.percent) / 100 * full / current;
    }
    if (target > 80) {
      final from = s.percent > 80 ? s.percent : 80.0;
      // taper: average current over 80→100 is roughly 45% of the bulk current
      final taperCurrent = s.percent > 80 ? current * 0.7 : current * 0.45;
      hours += (target - from) / 100 * full / taperCurrent;
    }
    return Duration(seconds: (hours * 3600).round());
  }

  /// Remaining runtime on battery, from live discharge current or measured drain rate.
  Duration? dischargeRemaining(BatterySnapshot s, {double? drainPerHour}) {
    if (s.isPluggedIn) return null;
    if (s.currentMa < -20 && s.chargeCounterMah != null) {
      final hours = s.chargeCounterMah! / s.currentMa.abs();
      if (hours < 200) return Duration(minutes: (hours * 60).round());
    }
    if (drainPerHour != null && drainPerHour > 0.1) {
      return Duration(minutes: (s.percent / drainPerHour * 60).round());
    }
    return null;
  }

  /// Warns when the current charger delivers much less than the phone has achieved before.
  /// Returns the best-known watts if the session is slow, otherwise null.
  double? slowChargeBaseline(BatterySnapshot s, List<ChargingSession> history) {
    final session = s.session;
    if (!s.isCharging || session == null || s.percent > 80) return null;
    if (session.elapsed < const Duration(minutes: 2)) return null;
    final sameType = history.where((h) => h.charger == s.charger && h.duration.inMinutes >= 5);
    if (sameType.length < 2) return null;
    final best = sameType.map((h) => h.avgWatts).reduce((a, b) => a > b ? a : b);
    if (best < 5) return null;
    return session.avgWatts < best * 0.5 ? best : null;
  }

  List<ChargerComparison> compareChargers(List<ChargingSession> sessions) {
    final groups = <String, List<ChargingSession>>{};
    for (final s in sessions) {
      if (s.duration.inMinutes < 3) continue;
      final key = s.label ?? s.charger.name.toUpperCase();
      groups.putIfAbsent(key, () => []).add(s);
    }
    final list = groups.entries.map((e) {
      final avg = e.value.map((s) => s.avgWatts).reduce((a, b) => a + b) / e.value.length;
      final peak = e.value.map((s) => s.peakWatts).reduce((a, b) => a > b ? a : b);
      return ChargerComparison(name: e.key, sessions: e.value.length, avgWatts: avg, peakWatts: peak, rating: rateCharger(avg));
    }).toList()
      ..sort((a, b) => b.avgWatts.compareTo(a.avgWatts));
    return list;
  }
}
