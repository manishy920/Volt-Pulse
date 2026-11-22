import 'package:equatable/equatable.dart';

import 'battery_snapshot.dart';

class HistoryPoint extends Equatable {
  final DateTime time;
  final double level;
  final double temperatureC;
  final int currentMa;
  final bool charging;
  final bool screenOn;

  const HistoryPoint({
    required this.time,
    required this.level,
    required this.temperatureC,
    required this.currentMa,
    required this.charging,
    required this.screenOn,
  });

  @override
  List<Object?> get props => [time, level, temperatureC, currentMa, charging, screenOn];
}

class ChargingSession extends Equatable {
  final String id;
  final DateTime start;
  final DateTime end;
  final double startLevel;
  final double endLevel;
  final double avgWatts;
  final double peakWatts;
  final double maxTempC;
  final ChargerType charger;

  /// User-given name of the charger/cable combo, used for comparisons.
  final String? label;

  const ChargingSession({
    required this.id,
    required this.start,
    required this.end,
    required this.startLevel,
    required this.endLevel,
    required this.avgWatts,
    required this.peakWatts,
    required this.maxTempC,
    required this.charger,
    this.label,
  });

  Duration get duration => end.difference(start);
  double get gained => endLevel - startLevel;

  @override
  List<Object?> get props => [id, start, end, startLevel, endLevel, avgWatts, peakWatts, maxTempC, charger, label];
}

class CapacitySample extends Equatable {
  final DateTime time;
  final double mah;

  const CapacitySample(this.time, this.mah);

  @override
  List<Object?> get props => [time, mah];
}

class HistoryBundle extends Equatable {
  final List<HistoryPoint> points;
  final List<ChargingSession> sessions;
  final List<CapacitySample> capacity;

  const HistoryBundle({this.points = const [], this.sessions = const [], this.capacity = const []});

  @override
  List<Object?> get props => [points, sessions, capacity];
}
