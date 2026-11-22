import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/battery_snapshot.dart';
import '../../domain/entities/power_event.dart';
import '../../domain/usecases/usecases.dart';

sealed class BatteryEvent {
  const BatteryEvent();
}

class BatteryStarted extends BatteryEvent {
  const BatteryStarted();
}

class _SnapshotReceived extends BatteryEvent {
  final BatterySnapshot snapshot;
  const _SnapshotReceived(this.snapshot);
}

class _PowerEventReceived extends BatteryEvent {
  final PowerEvent event;
  const _PowerEventReceived(this.event);
}

class _StreamFailed extends BatteryEvent {
  final Object error;
  const _StreamFailed(this.error);
}

class BatteryState extends Equatable {
  final BatterySnapshot? snapshot;
  final PowerEvent? lastPowerEvent;

  /// Recent wattage readings (1 per second) for sparkline / speed meter smoothing.
  final List<double> powerTrail;
  final String? error;

  const BatteryState({this.snapshot, this.lastPowerEvent, this.powerTrail = const [], this.error});

  /// Wattage smoothed over the last 5 readings — raw current_now is noisy.
  double get smoothedWatts {
    if (powerTrail.isEmpty) return snapshot?.powerW ?? 0;
    final tail = powerTrail.length > 5 ? powerTrail.sublist(powerTrail.length - 5) : powerTrail;
    return tail.reduce((a, b) => a + b) / tail.length;
  }

  BatteryState copyWith({BatterySnapshot? snapshot, PowerEvent? lastPowerEvent, List<double>? powerTrail, String? error}) =>
      BatteryState(
        snapshot: snapshot ?? this.snapshot,
        lastPowerEvent: lastPowerEvent ?? this.lastPowerEvent,
        powerTrail: powerTrail ?? this.powerTrail,
        error: error,
      );

  @override
  List<Object?> get props => [snapshot, lastPowerEvent, powerTrail, error];
}

class BatteryBloc extends Bloc<BatteryEvent, BatteryState> {
  final WatchBattery _watchBattery;
  final WatchPowerEvents _watchPower;
  StreamSubscription<BatterySnapshot>? _batterySub;
  StreamSubscription<PowerEvent>? _powerSub;

  BatteryBloc(this._watchBattery, this._watchPower) : super(const BatteryState()) {
    on<BatteryStarted>(_onStarted);
    on<_SnapshotReceived>(_onSnapshot);
    on<_PowerEventReceived>((e, emit) => emit(state.copyWith(lastPowerEvent: e.event)));
    on<_StreamFailed>((e, emit) => emit(state.copyWith(error: '${e.error}')));
  }

  Future<void> _onStarted(BatteryStarted event, Emitter<BatteryState> emit) async {
    await _batterySub?.cancel();
    await _powerSub?.cancel();
    _batterySub = _watchBattery().listen((s) => add(_SnapshotReceived(s)), onError: (Object e) => add(_StreamFailed(e)));
    _powerSub = _watchPower().listen((p) => add(_PowerEventReceived(p)), onError: (Object e) => add(_StreamFailed(e)));
  }

  void _onSnapshot(_SnapshotReceived e, Emitter<BatteryState> emit) {
    final pluggedChanged = state.snapshot?.isPluggedIn != e.snapshot.isPluggedIn;
    final trail = pluggedChanged ? <double>[] : [...state.powerTrail];
    trail.add(e.snapshot.powerW);
    if (trail.length > 90) trail.removeRange(0, trail.length - 90);
    emit(state.copyWith(snapshot: e.snapshot, powerTrail: trail));
  }

  @override
  Future<void> close() async {
    await _batterySub?.cancel();
    await _powerSub?.cancel();
    return super.close();
  }
}
