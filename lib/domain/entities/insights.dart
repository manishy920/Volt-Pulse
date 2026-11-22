import 'package:equatable/equatable.dart';

enum ChargingSpeed { slow, fast, superFast }

enum ChargerRating { weak, good, excellent }

enum HealthStatus { excellent, good, fair, poor }

class HealthFactor extends Equatable {
  /// l10n key for the factor name.
  final String key;
  final double score; // 0..1
  final String detail;

  const HealthFactor(this.key, this.score, this.detail);

  @override
  List<Object?> get props => [key, score, detail];
}

class HealthReport extends Equatable {
  final int score;
  final HealthStatus status;
  final List<HealthFactor> factors;
  final List<String> advice;
  final double? capacityRatio;
  final double avgTempC;
  final double maxTempC;
  final double hotFraction;

  const HealthReport({
    required this.score,
    required this.status,
    required this.factors,
    required this.advice,
    required this.capacityRatio,
    required this.avgTempC,
    required this.maxTempC,
    required this.hotFraction,
  });

  @override
  List<Object?> get props => [score, status, factors, advice, capacityRatio, avgTempC, maxTempC, hotFraction];
}

class HabitsReport extends Equatable {
  final int sessions;
  final int fullCharges;
  final int deepDischarges;
  final int healthyRangeSessions;
  final double avgEndLevel;
  final Duration totalChargeTime;
  final String summary;

  const HabitsReport({
    required this.sessions,
    required this.fullCharges,
    required this.deepDischarges,
    required this.healthyRangeSessions,
    required this.avgEndLevel,
    required this.totalChargeTime,
    required this.summary,
  });

  @override
  List<Object?> get props => [sessions, fullCharges, deepDischarges, healthyRangeSessions, avgEndLevel, totalChargeTime, summary];
}

class DrainStats extends Equatable {
  /// %/hour while screen on and discharging, null if not enough data.
  final double? activePerHour;

  /// %/hour while screen off (idle).
  final double? idlePerHour;
  final Duration screenOnSinceUnplug;

  const DrainStats({this.activePerHour, this.idlePerHour, this.screenOnSinceUnplug = Duration.zero});

  @override
  List<Object?> get props => [activePerHour, idlePerHour, screenOnSinceUnplug];
}

class ChargerComparison extends Equatable {
  final String name;
  final int sessions;
  final double avgWatts;
  final double peakWatts;
  final ChargerRating rating;

  const ChargerComparison({required this.name, required this.sessions, required this.avgWatts, required this.peakWatts, required this.rating});

  @override
  List<Object?> get props => [name, sessions, avgWatts, peakWatts, rating];
}
