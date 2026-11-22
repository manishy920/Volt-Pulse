import 'package:equatable/equatable.dart';

import 'battery_snapshot.dart';

enum PowerEventType { connected, disconnected }

class PowerEvent extends Equatable {
  final PowerEventType type;
  final ChargerType charger;
  final DateTime timestamp;

  const PowerEvent({required this.type, required this.charger, required this.timestamp});

  bool get connected => type == PowerEventType.connected;

  @override
  List<Object?> get props => [type, charger, timestamp];
}
