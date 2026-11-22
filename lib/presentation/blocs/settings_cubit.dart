import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/usecases/usecases.dart';

class SettingsCubit extends Cubit<AppSettings> {
  final LoadSettings _load;
  final SaveSettings _save;

  SettingsCubit(this._load, this._save) : super(const AppSettings());

  Future<void> init() async {
    try {
      emit(await _load());
    } catch (_) {
      // Native side unavailable (e.g. tests) — keep defaults.
    }
  }

  Future<void> update(AppSettings Function(AppSettings s) change) async {
    final next = change(state);
    emit(next);
    try {
      await _save(next);
    } catch (_) {}
  }
}
