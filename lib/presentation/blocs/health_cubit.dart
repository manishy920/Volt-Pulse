import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/insights.dart';
import '../../domain/usecases/health_calculator.dart';
import 'battery_bloc.dart';
import 'history_cubit.dart';

/// Derives the health report from live battery data + recorded history.
class HealthCubit extends Cubit<HealthReport?> {
  final HealthCalculator _calc;
  final BatteryBloc _battery;
  final HistoryCubit _history;
  late final StreamSubscription<BatteryState> _bSub;
  late final StreamSubscription<HistoryState> _hSub;
  String _lastKey = '';

  HealthCubit(this._calc, this._battery, this._history) : super(null) {
    _bSub = _battery.stream.listen((_) => _recompute());
    _hSub = _history.stream.listen((_) => _recompute(force: true));
    _recompute(force: true);
  }

  void _recompute({bool force = false}) {
    final s = _battery.state.snapshot;
    final key = '${s?.level}-${s?.temperatureC}-${s?.health}';
    if (!force && key == _lastKey) return;
    _lastKey = key;
    emit(_calc.compute(s, _history.state.bundle));
  }

  @override
  Future<void> close() async {
    await _bSub.cancel();
    await _hSub.cancel();
    return super.close();
  }
}
