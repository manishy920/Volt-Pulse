import 'dart:math' as math;

import '../entities/battery_snapshot.dart';
import '../entities/history.dart';
import '../entities/insights.dart';

/// Combines capacity wear, temperature history, charge habits and the system health flag
/// into a friendly 0–100 score. This is an estimate — Android exposes no official SoH.
class HealthCalculator {
  const HealthCalculator();

  HealthReport compute(BatterySnapshot? s, HistoryBundle h) {
    final factors = <HealthFactor>[];
    final advice = <String>[];

    // 1. Capacity vs design (weight 45%)
    double? capacityRatio;
    final latestCapacity = h.capacity.isNotEmpty ? h.capacity.last.mah : s?.fullCapacityMah;
    if (latestCapacity != null && s?.designCapacityMah != null && s!.designCapacityMah! > 0) {
      capacityRatio = (latestCapacity / s.designCapacityMah!).clamp(0.0, 1.05);
    }
    final capScore = capacityRatio == null ? 0.9 : ((capacityRatio - 0.6) / 0.4).clamp(0.0, 1.0);
    factors.add(HealthFactor('factor_capacity', capScore,
        capacityRatio == null ? 'n/a' : '${(capacityRatio * 100).toStringAsFixed(0)}%'));
    if (capacityRatio != null && capacityRatio < 0.8) advice.add('advice_capacity_low');

    // 2. Temperature (weight 25%)
    final temps = h.points.map((p) => p.temperatureC).toList();
    if (s != null) temps.add(s.temperatureC);
    final avgTemp = temps.isEmpty ? 0.0 : temps.reduce((a, b) => a + b) / temps.length;
    final maxTemp = temps.isEmpty ? 0.0 : temps.reduce(math.max);
    final hotFraction = temps.isEmpty ? 0.0 : temps.where((t) => t >= 40).length / temps.length;
    final tempScore = (1 - hotFraction * 4 - math.max(0, avgTemp - 35) / 15).clamp(0.0, 1.0);
    factors.add(HealthFactor('factor_temperature', tempScore, '${avgTemp.toStringAsFixed(1)}°C avg'));
    if (hotFraction > 0.05 || maxTemp >= 43) advice.add('advice_heat');

    // 3. Charging habits (weight 20%)
    final recent = h.sessions.where((x) => x.end.isAfter(DateTime.now().subtract(const Duration(days: 30)))).toList();
    final full = recent.where((x) => x.endLevel >= 99).length;
    final lowStarts = recent.where((x) => x.startLevel <= 10).length;
    final habitScore = recent.isEmpty ? 0.85 : (1 - (full + lowStarts * 1.5) / (recent.length * 2)).clamp(0.0, 1.0);
    factors.add(HealthFactor('factor_habits', habitScore, '${recent.length} sessions / 30d'));
    if (full > recent.length / 2 && recent.isNotEmpty) advice.add('advice_stop_80');
    if (lowStarts > 1) advice.add('advice_avoid_low');

    // 4. Cycles & system flag (weight 10%)
    final cycles = s?.cycleCount;
    var sysScore = cycles == null ? 0.9 : (1 - cycles / 1000).clamp(0.0, 1.0);
    if (s != null && s.health != BatteryHealth.good && s.health != BatteryHealth.unknown) {
      sysScore = math.min(sysScore, 0.2);
      advice.add('advice_system_flag');
    }
    factors.add(HealthFactor('factor_cycles', sysScore, cycles == null ? 'n/a' : '$cycles cycles'));

    final score = ((capScore * 0.45 + tempScore * 0.25 + habitScore * 0.2 + sysScore * 0.1) * 100).round().clamp(0, 100);
    final status = score >= 85
        ? HealthStatus.excellent
        : score >= 70
            ? HealthStatus.good
            : score >= 50
                ? HealthStatus.fair
                : HealthStatus.poor;
    if (advice.isEmpty) advice.add('advice_all_good');

    return HealthReport(
      score: score,
      status: status,
      factors: factors,
      advice: advice,
      capacityRatio: capacityRatio,
      avgTempC: avgTemp,
      maxTempC: maxTemp,
      hotFraction: hotFraction,
    );
  }
}
