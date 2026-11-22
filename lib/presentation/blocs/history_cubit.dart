import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/history.dart';
import '../../domain/entities/insights.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/usecases/charging_analytics.dart';
import '../../domain/usecases/usage_analytics.dart';
import '../../domain/usecases/usecases.dart';

enum LoadStatus { initial, loading, loaded, failure }

class HistoryState extends Equatable {
  final LoadStatus status;
  final HistoryBundle bundle;
  final HabitsReport? habits;
  final DrainStats drain;
  final List<ChargerComparison> chargers;
  final String? message;

  const HistoryState({
    this.status = LoadStatus.initial,
    this.bundle = const HistoryBundle(),
    this.habits,
    this.drain = const DrainStats(),
    this.chargers = const [],
    this.message,
  });

  HistoryState copyWith({LoadStatus? status, HistoryBundle? bundle, HabitsReport? habits, DrainStats? drain,
          List<ChargerComparison>? chargers, String? message}) =>
      HistoryState(
        status: status ?? this.status,
        bundle: bundle ?? this.bundle,
        habits: habits ?? this.habits,
        drain: drain ?? this.drain,
        chargers: chargers ?? this.chargers,
        message: message,
      );

  @override
  List<Object?> get props => [status, bundle, habits, drain, chargers, message];
}

class HistoryCubit extends Cubit<HistoryState> {
  final LoadHistory _load;
  final ExportHistoryCsv _export;
  final HistoryRepository _repo;
  final UsageAnalytics _usage;
  final ChargingAnalytics _charging;

  HistoryCubit(this._load, this._export, this._repo, this._usage, this._charging) : super(const HistoryState());

  Future<void> load() async {
    if (state.status == LoadStatus.initial) emit(state.copyWith(status: LoadStatus.loading));
    try {
      final bundle = await _load();
      emit(state.copyWith(
        status: LoadStatus.loaded,
        bundle: bundle,
        habits: _usage.weekly(bundle),
        drain: _usage.drain(bundle.points),
        chargers: _charging.compareChargers(bundle.sessions),
      ));
    } catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, message: '$e'));
    }
  }

  Future<void> labelSession(String id, String? label) async {
    await _repo.labelSession(id, label);
    await load();
  }

  Future<void> clear() async {
    await _repo.clear();
    await load();
  }

  Future<String> exportCsv() => _export(state.bundle);
}
